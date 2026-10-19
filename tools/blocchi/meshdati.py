"""Legge e scrive i modelli di src/shared/MeshDati (lo stesso formato di tools/converti_mesh.py).

Un modello è un dict: minimo, massimo (3 float), ossa [{nome, padre, posizione}], vertici: liste parallele
pos (Nx3 metri), uv (Nx2), normali (Nx3), ossa_v (Nx4 indici nella lista ossa), pesi (Nx4 0-1),
triangoli (Mx3), texture (immagine PIL RGB quadrata).
"""
import base64
import os
import re
import struct

import numpy as np
import zstandard
from PIL import Image

RADICE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CARTELLA = os.path.join(RADICE, "src", "shared", "MeshDati")


def _stringhe(percorso):
    testo = open(percorso).read()
    return "".join(re.findall(r'"([A-Za-z0-9+/=]+)"', testo))


def _decomprimi(b64):
    return zstandard.ZstdDecompressor().decompress(base64.b64decode(b64))


def leggi(nome, radice=CARTELLA):
    cartella = os.path.join(radice, nome)
    init = open(os.path.join(cartella, "init.luau")).read()
    numeri = lambda chiave: [float(x) for x in re.search(chiave + r" = \{ ([^}]*) \}", init).group(1).split(",")]
    minimo, massimo = np.array(numeri("minimo")), np.array(numeri("massimo"))
    ossa = []
    for m in re.finditer(r'\{ nome = "([^"]+)", padre = (nil|"[^"]+"), posizione = \{ ([^}]*) \} \}', init):
        padre = None if m.group(2) == "nil" else m.group(2).strip('"')
        ossa.append({"nome": m.group(1), "padre": padre, "posizione": [float(x) for x in m.group(3).split(",")]})
    lato = int(re.search(r"lato = (\d+)", init).group(1))

    def pezzi(parte):
        file = sorted(f for f in os.listdir(cartella) if re.fullmatch(parte + r"\d*\.luau", f))
        file.sort(key=lambda f: int(re.sub(r"\D", "", f) or 0))
        return "".join(_stringhe(os.path.join(cartella, f)) for f in file)

    # Ogni pezzo è base64 a sé (i moduli si concatenano dopo la decodifica in Luau? no: prima). Si concatena il testo.
    g = _decomprimi(pezzi("Geometria"))
    t = _decomprimi(pezzi("Texture"))
    nv, nt = struct.unpack_from("<II", g, 0)
    dt = np.dtype([("q", "<u2", 3), ("uv", "<u2", 2), ("n", "i1", 3), ("b", "u1", 4), ("w", "u1", 4)])
    v = np.frombuffer(g, dtype=dt, count=nv, offset=8)
    tri = np.frombuffer(g, dtype="<u2", count=nt * 3, offset=8 + nv * 21).reshape(-1, 3).astype(np.int64)
    pos = minimo + v["q"] / 65535.0 * (massimo - minimo)
    texture = Image.frombytes("RGB", (lato, lato), t)
    return {
        "minimo": minimo, "massimo": massimo, "ossa": ossa,
        "pos": pos, "uv": v["uv"] / 65535.0, "normali": v["n"].astype(np.float64) / 127.0,
        "ossa_v": v["b"].astype(np.int64), "pesi": v["w"] / 255.0, "triangoli": tri, "texture": texture,
    }


def _stringa_luau(testo, pezzo=60000):
    parti = [testo[i:i + pezzo] for i in range(0, len(testo), pezzo)]
    return "table.concat({\n" + "".join('\t\t"%s",\n' % p for p in parti) + "\t})"


def scrivi(nome, m, nota, radice=CARTELLA):
    pos = np.asarray(m["pos"], dtype=np.float64)
    minimo, massimo = pos.min(0), pos.max(0)
    estensione = np.maximum(massimo - minimo, 1e-6)
    nv, nt = len(pos), len(m["triangoli"])
    assert nv < 65536, "troppi vertici"
    dt = np.dtype([("q", "<u2", 3), ("uv", "<u2", 2), ("n", "i1", 3), ("b", "u1", 4), ("w", "u1", 4)])
    v = np.zeros(nv, dtype=dt)
    v["q"] = np.round((pos - minimo) / estensione * 65535).clip(0, 65535)
    v["uv"] = np.round(np.asarray(m["uv"]) * 65535).clip(0, 65535)
    n = np.asarray(m["normali"], dtype=np.float64)
    n = n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-9)
    v["n"] = np.round(n * 127).clip(-127, 127)
    v["b"] = np.asarray(m["ossa_v"])
    pesi = np.asarray(m["pesi"], dtype=np.float64)
    pesi = pesi / np.maximum(pesi.sum(1, keepdims=True), 1e-9)
    w = np.round(pesi * 255).astype(np.int64)
    w[:, 0] += 255 - w.sum(1)  # la somma resta 255
    v["w"] = w.clip(0, 255)
    geometria = struct.pack("<II", nv, nt) + v.tobytes() + np.asarray(m["triangoli"], dtype="<u2").tobytes()
    img = m["texture"].convert("RGB")
    lato = img.size[0]
    texture = img.tobytes()
    comp = lambda b: base64.b64encode(zstandard.ZstdCompressor(level=19).compress(b)).decode()
    g64, t64 = comp(geometria), comp(texture)
    cartella = os.path.join(radice, nome)
    os.makedirs(cartella, exist_ok=True)
    for vecchia in os.listdir(cartella):
        os.remove(os.path.join(cartella, vecchia))
    richieste = {}
    for parte, contenuto in (("Geometria", g64), ("Texture", t64)):
        pezzi = [contenuto[i:i + 180000] for i in range(0, len(contenuto), 180000)]
        if len(pezzi) == 1:
            nomi = [parte]
            richieste[parte] = "require(script.%s)" % parte
        else:
            nomi = ["%s%d" % (parte, k) for k in range(1, len(pezzi) + 1)]
            richieste[parte] = "table.concat({ %s })" % ", ".join("require(script.%s)" % x for x in nomi)
        for nomeFile, pezzo in zip(nomi, pezzi):
            open(os.path.join(cartella, nomeFile + ".luau"), "w").write(
                "-- Generato da tools/blocchi: non modificare a mano.\nreturn " + _stringa_luau(pezzo) + "\n")
    ossa = "\n".join(
        '\t\t{ nome = "%s", padre = %s, posizione = { %.5f, %.5f, %.5f } },'
        % (o["nome"], ('"%s"' % o["padre"]) if o["padre"] else "nil", *o["posizione"]) for o in m["ossa"])
    testo = f"""-- Generato da tools/blocchi ({nota}): non modificare a mano.
-- {nv} vertici, {nt} triangoli, texture {lato}x{lato}. Misure in metri, assi di Roblox.
return {{
	versione = 1,
	minimo = {{ {", ".join("%.5f" % x for x in minimo)} }},
	massimo = {{ {", ".join("%.5f" % x for x in massimo)} }},
	ossa = {{
{ossa}
	}},
	vertici = {nv},
	triangoli = {nt},
	lunghezzaGeometria = {len(geometria)},
	geometria = {richieste["Geometria"]},
	lato = {lato},
	lunghezzaTexture = {len(texture)},
	texture = {richieste["Texture"]},
}}
"""
    open(os.path.join(cartella, "init.luau"), "w").write(testo)


def glb(m, percorso):
    """Esporta in GLB (per le anteprime in three.js), nella posa di riposo."""
    import trimesh
    from trimesh.visual import TextureVisuals
    from trimesh.visual.material import PBRMaterial
    # In Roblox il fronte è -Z; uv con v verso il basso come in Roblox.
    uv = np.asarray(m["uv"]).copy()
    uv[:, 1] = 1 - uv[:, 1]
    mesh = trimesh.Trimesh(vertices=m["pos"], faces=m["triangoli"], vertex_normals=m["normali"], process=False)
    mesh.visual = TextureVisuals(uv=uv, material=PBRMaterial(baseColorTexture=m["texture"], roughnessFactor=0.9, metallicFactor=0.0))
    mesh.export(percorso)
