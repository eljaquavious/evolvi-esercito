"""Mappa della campagna a pixel (Mattia, 31/10/2026: "a pixel e monocolore, non una cartina con i rilievi";
1/11/2026: "tra i quadrati non voglio ALCUN bordo, come se non fossero quadratini", verde più scuro, niente
sentieri, bordi più spessi).

Ogni cella di terra della griglia di src/shared/Config/MappaEuropaDati.luau (240 x 200, 4 studs) diventa una
piastrella quadrata alta 0.8, attaccata alle vicine: la terra è una macchia sola di un colore (lo mette il server).
Il contorno nero sta solo sulla costa: una fascia larga BORDO studs appoggiata sul mare attorno alle piastrelle
che lo toccano (verso fuori, così le isole di una cella restano verdi), con i quadratini negli angoli, in pezzi a
parte "Bordo_<x>_<y>". Il mare è il piano scuro sotto (lo mette il server). La mappa si guarda dritta dall'alto.

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

CELLA = 4.0      # studs, anche il lato della piastrella: nessuna fessura
ALTO = 0.8       # altezza delle piastrelle sul mare
BORDO = 1.8      # larghezza del contorno nero della costa, in studs (verso il mare)
SOPRA = 0.03     # il contorno sta appena sopra le piastrelle
BLOCCO = 60      # celle per lato di ogni pezzo


def leggi():
    testo = open(DATI, encoding="utf-8").read()
    alfabeto = re.search(r'Dati\.ALFABETO = "(.*)"', testo).group(1)
    valori = {c: i for i, c in enumerate(alfabeto)}
    griglia_testo = testo.split("Dati.Griglia = {", 1)[1].split("\n}", 1)[0]
    righe = re.findall(r'^\t"(.*)",?$', griglia_testo, re.M)
    return np.array([[valori.get(c, 0) >= 10 for c in r] for r in righe])


class Mesh:
    def __init__(self):
        self.verts, self.facce = [], []

    def quad(self, a, b, c, d, normale):
        p = [np.array(v, float) for v in (a, b, c, d)]
        n = np.cross(p[1] - p[0], p[2] - p[0])
        if np.dot(n, normale) < 0:
            p = p[::-1]
        i = len(self.verts)
        self.verts.extend(p)
        self.facce.append((i, i + 1, i + 2, i + 3))

    def piatto(self, x0, x1, z0, z1, y):
        self.quad((x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1), (0, 1, 0))


def pezzi_blocco(celle, colonne, righe, terra):
    """Le piastrelle (sopra) e il contorno della costa di un elenco di celle, in coordinate di Roblox rispetto
    al centro della mappa."""
    sopra, bordo = Mesh(), Mesh()
    h, w, yb = CELLA / 2, BORDO, ALTO + SOPRA

    def mare(c, r):
        return not (0 <= r < righe and 0 <= c < colonne and terra[r, c])

    for c, r in celle:
        # Come MappaEuropa.posizioneCella: l'est verso -X, il nord verso +Z.
        x = -(c + 0.5 - colonne / 2) * CELLA
        z = (righe / 2 - r - 0.5) * CELLA
        x0, x1, z0, z1 = x - h, x + h, z - h, z + h
        sopra.piatto(x0, x1, z0, z1, ALTO)
        if len(sopra.facce) == 1:
            # Un quadratino sotto la prima piastrella: il pezzo ha uno spessore (Roblox non vuole mesh piatte).
            sopra.quad((x - 0.1, 0, z - 0.1), (x + 0.1, 0, z - 0.1), (x + 0.1, 0, z + 0.1), (x - 0.1, 0, z + 0.1),
                       (0, -1, 0))
        # Lati sul mare: fianco nero e fascia nera fuori dalla piastrella. Sud = riga dopo (z0), est = colonna
        # dopo (-X, x0).
        if mare(c, r + 1):
            bordo.piatto(x0, x1, z0 - w, z0, yb)
            bordo.quad((x0, 0, z0), (x1, 0, z0), (x1, ALTO, z0), (x0, ALTO, z0), (0, 0, -1))
        if mare(c, r - 1):
            bordo.piatto(x0, x1, z1, z1 + w, yb)
            bordo.quad((x0, 0, z1), (x1, 0, z1), (x1, ALTO, z1), (x0, ALTO, z1), (0, 0, 1))
        if mare(c + 1, r):
            bordo.piatto(x0 - w, x0, z0, z1, yb)
            bordo.quad((x0, 0, z0), (x0, 0, z1), (x0, ALTO, z1), (x0, ALTO, z0), (-1, 0, 0))
        if mare(c - 1, r):
            bordo.piatto(x1, x1 + w, z0, z1, yb)
            bordo.quad((x1, 0, z0), (x1, 0, z1), (x1, ALTO, z1), (x1, ALTO, z0), (1, 0, 0))
        # Angoli sporgenti: mare sui due lati, il contorno gira senza buchi.
        for dc, dr in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
            if mare(c + dc, r) and mare(c, r + dr):
                ax = (x0 - w, x0) if dc == 1 else (x1, x1 + w)
                az = (z0 - w, z0) if dr == 1 else (z1, z1 + w)
                bordo.piatto(ax[0], ax[1], az[0], az[1], yb)
    return sopra, bordo


def oggetto(nome, mesh):
    verts = np.array(mesh.verts)
    # Da Roblox a Blender: x = -x, y = z, z = y (come tools/blocchi/esporta_fbx.py).
    b = np.stack([-verts[:, 0], verts[:, 2], verts[:, 1]], axis=1)
    me = bpy.data.meshes.new(nome)
    me.from_pydata(b.tolist(), [], mesh.facce)
    me.update()
    ob = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(ob)
    mn, mx = verts.min(0), verts.max(0)
    return [float(v) for v in (mn + mx) / 2], [float(v) for v in mx - mn], len(mesh.facce) * 2


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(USCITA, exist_ok=True)
    terra = leggi()
    righe, colonne = terra.shape
    pezzi = {}
    for bc in range(0, colonne, BLOCCO):
        for br in range(0, righe, BLOCCO):
            celle = [(c, r) for r in range(br, min(br + BLOCCO, righe)) for c in range(bc, min(bc + BLOCCO, colonne))
                     if terra[r, c]]
            if not celle:
                continue
            sopra, bordo = pezzi_blocco(celle, colonne, righe, terra)
            for nome, mesh in ((f"Terra_{bc // BLOCCO}_{br // BLOCCO}", sopra), (f"Bordo_{bc // BLOCCO}_{br // BLOCCO}", bordo)):
                if mesh.facce:
                    centro, misure, tri = oggetto(nome, mesh)
                    pezzi[nome] = {"centro": centro, "misure": misure, "triangoli": tri}
    fbx = os.path.join(USCITA, "MappaPixel.fbx")
    bpy.ops.export_scene.fbx(filepath=fbx, use_selection=False, object_types={"MESH"}, mesh_smooth_type="FACE",
                             axis_forward="-Z", axis_up="Y", apply_scale_options="FBX_SCALE_ALL")
    with open(os.path.join(USCITA, "pezzi.json"), "w", encoding="utf-8") as f:
        json.dump(pezzi, f, indent=1)
    print("pezzi", len(pezzi), "triangoli", sum(p["triangoli"] for p in pezzi.values()),
          "massimo", max(p["triangoli"] for p in pezzi.values()), "celle di terra", int(terra.sum()))
    print("Terra_0_0", pezzi.get("Terra_0_0"))


main()
