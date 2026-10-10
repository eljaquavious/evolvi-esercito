"""Converte l'uscita di tools/blender/esporta.py (JSON) in un modulo Luau per il gioco.

Uso: python3 tools/converti_mesh.py <uscita.json> <Nome> [--png anteprima.png]
Scrive la cartella src/shared/MeshDati/<Nome>/ (init.luau con ossa e misure, Geometria.luau e
Texture.luau con i dati compressi zstd + base64, che src/shared/Mesh.luau decomprime con EncodingService).
I dati stanno in moduli separati perché uno script di Roblox oltre i 200.000 caratteri non si può scrivere.
"""
import base64
import json
import os
import sys

import zstandard

RADICE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def comprimi(b64):
    grezzi = base64.b64decode(b64)
    return base64.b64encode(zstandard.ZstdCompressor(level=19).compress(grezzi)).decode(), len(grezzi)


def stringa_luau(testo, pezzo=60000):
    # Stringhe lunghe spezzate in più righe concatenate (base64 non contiene ] né virgolette).
    parti = [testo[i:i + pezzo] for i in range(0, len(testo), pezzo)]
    return "table.concat({\n" + "".join('\t\t"%s",\n' % p for p in parti) + "\t})"


def main():
    sorgente, nome = sys.argv[1], sys.argv[2]
    dati = json.load(open(sorgente))
    dati = dati.get("result", dati)
    geometria, lg = comprimi(dati["geometria"])
    texture, lt = comprimi(dati["texture"]["rgb"])
    ossa = "\n".join(
        '\t\t{ nome = "%s", padre = %s, posizione = { %.5f, %.5f, %.5f } },'
        % (o["nome"], ('"%s"' % o["padre"]) if o["padre"] else "nil", *o["posizione"])
        for o in dati["ossa"]
    )
    testo = f"""-- Generato da tools/converti_mesh.py dal modello Blender: non modificare a mano.
-- {dati["vertici"]} vertici, {dati["triangoli"]} triangoli, texture {dati["texture"]["lato"]}x{dati["texture"]["lato"]}. Misure in metri, assi di Roblox.
return {{
	versione = 1,
	minimo = {{ {", ".join("%.5f" % x for x in dati["minimo"])} }},
	massimo = {{ {", ".join("%.5f" % x for x in dati["massimo"])} }},
	ossa = {{
{ossa}
	}},
	vertici = {dati["vertici"]},
	triangoli = {dati["triangoli"]},
	lunghezzaGeometria = {lg},
	geometria = require(script.Geometria),
	lato = {dati["texture"]["lato"]},
	lunghezzaTexture = {lt},
	texture = require(script.Texture),
}}
"""
    cartella = os.path.join(RADICE, "src", "shared", "MeshDati", nome)
    vecchio = cartella + ".luau"
    if os.path.exists(vecchio):
        os.remove(vecchio)
    os.makedirs(cartella, exist_ok=True)
    open(os.path.join(cartella, "init.luau"), "w").write(testo)
    for parte, contenuto in (("Geometria", geometria), ("Texture", texture)):
        assert len(contenuto) < 190000, parte + " troppo lunga per un solo modulo"
        open(os.path.join(cartella, parte + ".luau"), "w").write(
            "-- Generato da tools/converti_mesh.py: non modificare a mano.\nreturn " + stringa_luau(contenuto) + "\n")
    print(f"{cartella}: geometria {len(geometria) // 1024} KB, texture {len(texture) // 1024} KB (compressi, base64)")
    if "--png" in sys.argv:
        from PIL import Image
        lato = dati["texture"]["lato"]
        Image.frombytes("RGB", (lato, lato), base64.b64decode(dati["texture"]["rgb"])).save(sys.argv[sys.argv.index("--png") + 1])


if __name__ == "__main__":
    main()
