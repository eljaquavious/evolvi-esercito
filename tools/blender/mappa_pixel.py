"""Mappa della campagna a pixel (Mattia, 31/10/2026: "a pixel e monocolore, non una cartina con i rilievi").

Ogni cella di terra della griglia di src/shared/Config/MappaEuropaDati.luau (240 x 200, 4 studs) diventa una
piastrella quadrata in rilievo, tutte alla stessa altezza, con una fessura tra l'una e l'altra; il mare è il
piano scuro sotto (lo mette il server). Le celle dei sentieri tra le battaglie sono un pezzo a parte, così il
gioco le colora di un'altra tinta dello stesso colore.

Si vede solo da sud e dall'alto (la telecamera della mappa sta sempre a sud del punto guardato): solo la faccia
sopra e quella a sud, 4 triangoli a piastrella (con i fianchi erano 256.000 triangoli in tutto).
Pezzi da 60 x 60 celle (sotto i 20.000 triangoli di Roblox per mesh).

Uso:
  blender --background --factory-startup --python tools/blender/mappa_pixel.py
Scrive assets-mappa/MappaPixel.fbx e assets-mappa/pezzi.json (centro di ogni pezzo rispetto al centro della
mappa, assi di Roblox), da cui si scrive a mano src/shared/Config/AssetMappa.luau.
"""
import json
import os
import re

import bpy
import numpy as np

RADICE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATI = os.path.join(RADICE, "src", "shared", "Config", "MappaEuropaDati.luau")
USCITA = os.path.join(RADICE, "assets-mappa")

CELLA = 4.0      # studs
LATO = 3.3       # piastrella (la fessura è CELLA - LATO)
ALTO = 0.8       # altezza delle piastrelle sul mare
BLOCCO = 60      # celle per lato di ogni pezzo (60 x 60 x 4 triangoli = 14.400 al massimo)


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


def quad(verts, facce, a, b, c, d, normale):
    """Aggiunge un quadrilatero orientato verso "normale" (assi di Roblox)."""
    p = [np.array(v, float) for v in (a, b, c, d)]
    n = np.cross(p[1] - p[0], p[2] - p[0])
    if np.dot(n, normale) < 0:
        p = p[::-1]
    i = len(verts)
    verts.extend(p)
    facce.append((i, i + 1, i + 2, i + 3))


def piastrelle(celle, colonne, righe):
    """Mesh (in coordinate di Roblox, rispetto al centro della mappa) delle piastrelle di un elenco di celle."""
    verts, facce = [], []
    h = LATO / 2
    for c, r in celle:
        # Come MappaEuropa.posizioneCella: l'est verso -X, il nord verso +Z.
        x = -(c + 0.5 - colonne / 2) * CELLA
        z = (righe / 2 - r - 0.5) * CELLA
        x0, x1, z0, z1 = x - h, x + h, z - h, z + h
        quad(verts, facce, (x0, ALTO, z0), (x1, ALTO, z0), (x1, ALTO, z1), (x0, ALTO, z1), (0, 1, 0))   # sopra
        quad(verts, facce, (x0, 0, z0), (x1, 0, z0), (x1, ALTO, z0), (x0, ALTO, z0), (0, 0, -1))       # sud
    return np.array(verts), facce


def oggetto(nome, verts, facce):
    # Da Roblox a Blender: x = -x, y = z, z = y (come tools/blocchi/esporta_fbx.py).
    b = np.stack([-verts[:, 0], verts[:, 2], verts[:, 1]], axis=1)
    me = bpy.data.meshes.new(nome)
    me.from_pydata(b.tolist(), [], facce)
    me.update()
    ob = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(ob)
    mn, mx = verts.min(0), verts.max(0)
    return [float(v) for v in (mn + mx) / 2], [float(v) for v in mx - mn], len(facce) * 2


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    terra, sentieri = leggi()
    righe, colonne = terra.shape
    sentiero = celle_sentiero(terra, sentieri)
    pezzi = {}
    for bc in range(0, colonne, BLOCCO):
        for br in range(0, righe, BLOCCO):
            celle = [(c, r) for r in range(br, min(br + BLOCCO, righe)) for c in range(bc, min(bc + BLOCCO, colonne))
                     if terra[r, c] and (c, r) not in sentiero]
            if not celle:
                continue
            nome = f"Terra_{bc // BLOCCO}_{br // BLOCCO}"
            verts, facce = piastrelle(celle, colonne, righe)
            centro, misure, tri = oggetto(nome, verts, facce)
            pezzi[nome] = {"centro": centro, "misure": misure, "triangoli": tri}
    # Il sentiero: un pezzo solo se ci sta, altrimenti a metà.
    celle = sorted(sentiero)
    gruppi = [celle] if len(celle) * 4 < 19000 else [celle[: len(celle) // 2], celle[len(celle) // 2:]]
    for i, g in enumerate(gruppi):
        nome = f"Sentiero_{i}"
        verts, facce = piastrelle(g, colonne, righe)
        centro, misure, tri = oggetto(nome, verts, facce)
        pezzi[nome] = {"centro": centro, "misure": misure, "triangoli": tri}
    os.makedirs(USCITA, exist_ok=True)
    fbx = os.path.join(USCITA, "MappaPixel.fbx")
    bpy.ops.export_scene.fbx(filepath=fbx, use_selection=False, object_types={"MESH"}, mesh_smooth_type="FACE",
                             axis_forward="-Z", axis_up="Y", apply_scale_options="FBX_SCALE_ALL")
    with open(os.path.join(USCITA, "pezzi.json"), "w", encoding="utf-8") as f:
        json.dump(pezzi, f, indent=1)
    print("pezzi", len(pezzi), "triangoli", sum(p["triangoli"] for p in pezzi.values()),
          "massimo", max(p["triangoli"] for p in pezzi.values()), "celle di terra", int(terra.sum()),
          "sentiero", len(sentiero))


main()
