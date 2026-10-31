"""Mappa della campagna a pixel (Mattia, 31/10/2026: "a pixel e monocolore, non una cartina con i rilievi";
1/11/2026: "niente spazio tra i quadratini, verde tinta unita, bordo nero non troppo spesso").

Ogni cella di terra della griglia di src/shared/Config/MappaEuropaDati.luau (240 x 200, 4 studs) diventa una
piastrella quadrata alta 0.8, attaccata alle vicine; il mare è il piano scuro sotto (lo mette il server).
Il colore e il bordo nero stanno in una texture (assets-mappa/piastrelle.png): a sinistra la piastrella di
terra (verde), a destra quella dei sentieri tra le battaglie (terra battuta), entrambe con il bordo nero; i
fianchi delle piastrelle (solo sulle coste) prendono il nero del bordo.

Pezzi da 60 x 60 celle (sotto i 20.000 triangoli di Roblox per mesh).

Uso:
  blender --background --factory-startup --python tools/blender/mappa_pixel.py
Scrive assets-mappa/MappaPixel.fbx (texture dentro) e assets-mappa/pezzi.json (centro di ogni pezzo rispetto al
centro della mappa, assi di Roblox), da cui si scrive a mano src/shared/Config/AssetMappa.luau.
"""
import json
import os
import re

import bpy
import numpy as np

RADICE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATI = os.path.join(RADICE, "src", "shared", "Config", "MappaEuropaDati.luau")
USCITA = os.path.join(RADICE, "assets-mappa")

CELLA = 4.0      # studs, anche il lato della piastrella: nessuna fessura
ALTO = 0.8       # altezza delle piastrelle sul mare
BLOCCO = 60      # celle per lato di ogni pezzo

# Texture: due quadrati da LATO_TEX pixel affiancati, bordo nero di BORDO pixel.
LATO_TEX = 128
BORDO = 5        # su 128 pixel = 0.16 studs per lato: tra due piastrelle una riga di circa 0.3 studs
VERDE = (96, 172, 72)
SENTIERO = (178, 150, 98)
NERO = (16, 18, 14)


def leggi():
    testo = open(DATI, encoding="utf-8").read()
    alfabeto = re.search(r'Dati\.ALFABETO = "(.*)"', testo).group(1)
    valori = {c: i for i, c in enumerate(alfabeto)}
    griglia_testo = testo.split("Dati.Griglia = {", 1)[1].split("\n}", 1)[0]
    righe = re.findall(r'^\t"(.*)",?$', griglia_testo, re.M)
    terra = np.array([[valori.get(c, 0) >= 10 for c in r] for r in righe])
    sentieri_testo = testo.split("Dati.Sentieri = {", 1)[1].split("\n}", 1)[0]
    sentieri = [[int(x) for x in re.findall(r"-?\d+", riga)] for riga in sentieri_testo.splitlines() if "{" in riga]
    return terra, sentieri


def celle_sentiero(terra, sentieri):
    """Come faceva il server col Terrain: largo 3 celle a croce, e gli angoli dei passi in diagonale."""
    righe, colonne = terra.shape
    celle = set()

    def segna(c, r):
        for dc, dr in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            cc, rr = c + dc, r + dr
            if 0 <= cc < colonne and 0 <= rr < righe and terra[rr, cc]:
                celle.add((cc, rr))

    for s in sentieri:
        for i in range(0, len(s) - 1, 2):
            c, r = s[i], s[i + 1]
            segna(c, r)
            if i + 3 < len(s) and s[i + 2] != c and s[i + 3] != r:
                segna(s[i + 2], r)
    return celle


def texture():
    """Le due piastrelle (terra, sentiero) con il bordo nero, affiancate."""
    img = np.zeros((LATO_TEX, LATO_TEX * 2, 3))
    for k, colore in enumerate((VERDE, SENTIERO)):
        cella = np.ones((LATO_TEX, LATO_TEX, 3)) * np.array(NERO) / 255
        cella[BORDO:-BORDO, BORDO:-BORDO] = np.array(colore) / 255
        img[:, k * LATO_TEX:(k + 1) * LATO_TEX] = cella
    im = bpy.data.images.new("piastrelle", LATO_TEX * 2, LATO_TEX, alpha=False)
    pixel = np.ones((LATO_TEX, LATO_TEX * 2, 4), dtype=np.float32)
    pixel[..., :3] = img[::-1]
    im.pixels.foreach_set(pixel.ravel())
    im.filepath_raw = os.path.join(USCITA, "piastrelle.png")
    im.file_format = "PNG"
    im.save()
    mat = bpy.data.materials.new("Piastrelle")
    mat.use_nodes = True
    nodi = mat.node_tree.nodes
    tex = nodi.new("ShaderNodeTexImage")
    tex.image = im
    mat.node_tree.links.new(tex.outputs["Color"], nodi.get("Principled BSDF").inputs["Base Color"])
    return mat


def piastrelle(celle, colonne, righe, terra, quale):
    """Mesh (in coordinate di Roblox, rispetto al centro della mappa) delle piastrelle di un elenco di celle.
    quale = 0 terra, 1 sentiero (la metà della texture). Restituisce vertici, facce e UV per ogni angolo."""
    verts, facce, uv = [], [], []
    h = CELLA / 2
    u0 = quale * 0.5
    sopra_uv = [(u0, 0), (u0 + 0.5, 0), (u0 + 0.5, 1), (u0, 1)]
    nero = (u0 + 0.5 * BORDO / LATO_TEX / 2, 0.5)  # un punto in mezzo al bordo nero

    def quad(a, b, c, d, normale, uvs):
        p = [np.array(v, float) for v in (a, b, c, d)]
        n = np.cross(p[1] - p[0], p[2] - p[0])
        if np.dot(n, normale) < 0:
            p = p[::-1]
            uvs = uvs[::-1]
        i = len(verts)
        verts.extend(p)
        facce.append((i, i + 1, i + 2, i + 3))
        uv.extend(uvs)

    def mare(c, r):
        return not (0 <= r < righe and 0 <= c < colonne and terra[r, c])

    for c, r in celle:
        # Come MappaEuropa.posizioneCella: l'est verso -X, il nord verso +Z.
        x = -(c + 0.5 - colonne / 2) * CELLA
        z = (righe / 2 - r - 0.5) * CELLA
        x0, x1, z0, z1 = x - h, x + h, z - h, z + h
        # Sopra: la x di Roblox cresce verso ovest, quindi la u va da x1 a x0 (la texture non si specchia).
        quad((x1, ALTO, z0), (x0, ALTO, z0), (x0, ALTO, z1), (x1, ALTO, z1), (0, 1, 0), sopra_uv)
        fianco = [nero] * 4
        if mare(c, r + 1):   # sud (riga dopo)
            quad((x0, 0, z0), (x1, 0, z0), (x1, ALTO, z0), (x0, ALTO, z0), (0, 0, -1), fianco)
        if mare(c, r - 1):   # nord
            quad((x0, 0, z1), (x1, 0, z1), (x1, ALTO, z1), (x0, ALTO, z1), (0, 0, 1), fianco)
        if mare(c + 1, r):   # est (-X)
            quad((x0, 0, z0), (x0, 0, z1), (x0, ALTO, z1), (x0, ALTO, z0), (-1, 0, 0), fianco)
        if mare(c - 1, r):   # ovest (+X)
            quad((x1, 0, z0), (x1, 0, z1), (x1, ALTO, z1), (x1, ALTO, z0), (1, 0, 0), fianco)
    return np.array(verts), facce, uv


def oggetto(nome, verts, facce, uv, materiale):
    # Da Roblox a Blender: x = -x, y = z, z = y (come tools/blocchi/esporta_fbx.py).
    b = np.stack([-verts[:, 0], verts[:, 2], verts[:, 1]], axis=1)
    me = bpy.data.meshes.new(nome)
    me.from_pydata(b.tolist(), [], facce)
    me.update()
    strato = me.uv_layers.new(name="UVMap")
    for poligono in me.polygons:
        for indice_loop in poligono.loop_indices:
            strato.data[indice_loop].uv = uv[me.loops[indice_loop].vertex_index]
    me.materials.append(materiale)
    ob = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(ob)
    mn, mx = verts.min(0), verts.max(0)
    return [float(v) for v in (mn + mx) / 2], [float(v) for v in mx - mn], len(facce) * 2


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(USCITA, exist_ok=True)
    terra, sentieri = leggi()
    righe, colonne = terra.shape
    sentiero = celle_sentiero(terra, sentieri)
    materiale = texture()
    pezzi = {}

    def aggiungi(nome, celle, quale):
        verts, facce, uv = piastrelle(celle, colonne, righe, terra, quale)
        centro, misure, tri = oggetto(nome, verts, facce, uv, materiale)
        pezzi[nome] = {"centro": centro, "misure": misure, "triangoli": tri}

    for bc in range(0, colonne, BLOCCO):
        for br in range(0, righe, BLOCCO):
            celle = [(c, r) for r in range(br, min(br + BLOCCO, righe)) for c in range(bc, min(bc + BLOCCO, colonne))
                     if terra[r, c] and (c, r) not in sentiero]
            if celle:
                aggiungi(f"Terra_{bc // BLOCCO}_{br // BLOCCO}", celle, 0)
    # Il sentiero: un pezzo solo se ci sta, altrimenti a metà.
    celle = sorted(sentiero)
    gruppi = [celle] if len(celle) * 6 < 19000 else [celle[: len(celle) // 2], celle[len(celle) // 2:]]
    for i, g in enumerate(gruppi):
        aggiungi(f"Sentiero_{i}", g, 1)
    fbx = os.path.join(USCITA, "MappaPixel.fbx")
    bpy.ops.export_scene.fbx(filepath=fbx, use_selection=False, object_types={"MESH"}, mesh_smooth_type="FACE",
                             path_mode="COPY", embed_textures=True,
                             axis_forward="-Z", axis_up="Y", apply_scale_options="FBX_SCALE_ALL")
    with open(os.path.join(USCITA, "pezzi.json"), "w", encoding="utf-8") as f:
        json.dump(pezzi, f, indent=1)
    print("pezzi", len(pezzi), "triangoli", sum(p["triangoli"] for p in pezzi.values()),
          "massimo", max(p["triangoli"] for p in pezzi.values()), "celle di terra", int(terra.sum()),
          "sentiero", len(sentiero))


main()
