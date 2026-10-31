"""Forzieri delle casse dello shop (Config/Casse): sei modelli, più la cassa costa più è decorata.

Ogni forziere ha due pezzi: "Base" (il baule, cavo dentro, con il fondo di velluto) e "Coperchio" (a botte, con
la cerniera dietro), così nel gioco il coperchio si apre. Tutti gli spigoli sono smussati, le borchie e le sfere
lisce; le gemme sono sfaccettate. Una sola texture (atlante 1024 a celle da 256): legno con le venature,
metallo, gemme, velluto.

Uso:
  blender --background --factory-startup --python tools/blender/forzieri.py -- [Nome ...] [--anteprime]
Scrive assets-forzieri/<Nome>/<Nome>.fbx (texture dentro), assets-forzieri/<Nome>/<Nome>.png e
assets-forzieri/forzieri.json (misure e cerniera di ogni forziere, per tools/forzieri_luau.py).
Con --anteprime fa anche i render di prova (chiuso e aperto) e le icone dello shop (assets/gui/<icona>.png).

Assi di Blender: Z in alto, il davanti verso -Y, origine a terra al centro. Misure in studs.
"""
import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

RADICE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
USCITA = os.path.join(RADICE, "assets-forzieri")

# Misure comuni (studs).
W = 4.0     # larghezza (X)
D = 2.6     # profondità (Y)
HB = 2.0    # altezza del baule
HL = 0.95   # altezza del coperchio a botte
PARETE = 0.2

LATO_ATLANTE = 1024
CELLA = 256
MARGINE = 10


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])


# Forzieri ------------------------------------------------------------------------------------------

FORZIERI = {
    # Truppe: legno e ferro, poi acciaio brunito, poi rosso e oro.
    "CassaPiccola": dict(icona="crate_small", legno="#A8743F", legno_scuro="#5E3A1C", metallo="#6B7079",
                         metallo_scuro="#2C2F35", velluto="#6B2420", gemma=None, fasce=2, piedi=False,
                         maniglie=False, angoli="semplici", emblema=None, gemme_coperchio=0, borchie=True),
    "CassaMedia": dict(icona="crate_medium", legno="#7C4A25", legno_scuro="#3E2412", metallo="#5679B0",
                       metallo_scuro="#1F2C44", velluto="#20345E", gemma="#4FB6FF", fasce=3, piedi=False,
                       maniglie=True, angoli="borchiati", emblema="spade", gemme_coperchio=0, borchie=True),
    "CassaGrande": dict(icona="crate_big", legno="#A3202E", legno_scuro="#4E0C15", metallo="#E8B53E",
                        metallo_scuro="#7A4E0E", velluto="#7A0E20", gemma="#FF3B55", fasce=3, piedi=True,
                        maniglie=True, angoli="ornati", emblema="stella", gemme_coperchio=3, borchie=True),
    # Armeria: verde acqua e argento, poi viola e oro, poi notte e oro con gemme rosa.
    "ArmeriaPiccola": dict(icona="chest_small", legno="#1F8A92", legno_scuro="#0D3F45", metallo="#C3CBD6",
                           metallo_scuro="#4A5361", velluto="#0E4F57", gemma=None, fasce=2, piedi=False,
                           maniglie=True, angoli="semplici", emblema=None, gemme_coperchio=0, borchie=True),
    "ArmeriaMedia": dict(icona="chest_medium", legno="#5B2A8E", legno_scuro="#25103D", metallo="#E2B23F",
                         metallo_scuro="#76500F", velluto="#3A1466", gemma="#C77DFF", fasce=3, piedi=False,
                         maniglie=True, angoli="borchiati", emblema="spade", gemme_coperchio=1, borchie=True),
    "ArmeriaGrande": dict(icona="chest_big", legno="#262046", legno_scuro="#0E0B1E", metallo="#F0C24A",
                          metallo_scuro="#7E560F", velluto="#5A0E48", gemma="#FF4FD8", fasce=3, piedi=True,
                          maniglie=True, angoli="ornati", emblema="corona", gemme_coperchio=3, borchie=True),
}

# Materiali = celle dell'atlante (in ordine).
MATERIALI = ["legno", "legno_scuro", "metallo", "metallo_scuro", "velluto", "gemma", "buio", "lama"]
MAT = {n: i for i, n in enumerate(MATERIALI)}


# Texture -------------------------------------------------------------------------------------------

def rumore(lato, celle, seme):
    rng = np.random.default_rng(seme)
    g = rng.random((celle + 1, celle + 1))
    g[-1, :] = g[0, :]
    g[:, -1] = g[:, 0]
    t = np.linspace(0, celle, lato, endpoint=False)
    i = t.astype(int)
    f = t - i
    f = f * f * (3 - 2 * f)
    a = g[np.ix_(i, i)]
    b = g[np.ix_(i, i + 1)]
    c = g[np.ix_(i + 1, i)]
    d = g[np.ix_(i + 1, i + 1)]
    fx = f[None, :]
    fy = f[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def cella_legno(colore, seme):
    """Venature lungo u (orizzontali): righe ondulate più scure, nodi qua e là."""
    n = CELLA
    y, x = np.mgrid[0:n, 0:n] / n
    onda = rumore(n, 4, seme) * 0.08 + rumore(n, 9, seme + 1) * 0.02
    righe = np.sin((y + onda) * math.pi * 26) * 0.5 + 0.5
    righe = righe ** 3
    fibre = rumore(n, 32, seme + 2)
    fibre = np.repeat(fibre[:, :1], n, axis=1) * 0.6 + fibre * 0.4
    chiaro = 1.0 - righe * 0.22 - (fibre - 0.5) * 0.12 + (rumore(n, 3, seme + 3) - 0.5) * 0.1
    return np.clip(colore[None, None, :] * chiaro[..., None], 0, 1)


def cella_metallo(colore, seme, ruvido=0.06):
    n = CELLA
    y = np.mgrid[0:n, 0:n][0] / n
    chiaro = 1.04 - y * 0.1 + (rumore(n, 24, seme) - 0.5) * ruvido + (rumore(n, 6, seme + 1) - 0.5) * ruvido
    return np.clip(colore[None, None, :] * chiaro[..., None], 0, 1)


def cella_gemma(colore):
    n = CELLA
    y, x = np.mgrid[0:n, 0:n] / n
    chiaro = 0.75 + 0.55 * (1 - y) + 0.15 * np.sin(x * 9)
    return np.clip(colore[None, None, :] * chiaro[..., None] + (1 - y[..., None]) * 0.12, 0, 1)


def cella_velluto(colore, seme):
    n = CELLA
    chiaro = 0.9 + (rumore(n, 40, seme) - 0.5) * 0.18
    return np.clip(colore[None, None, :] * chiaro[..., None], 0, 1)


def atlante(conf, file):
    img = np.zeros((LATO_ATLANTE, LATO_ATLANTE, 3))
    celle = {
        "legno": cella_legno(hexc(conf["legno"]), 1),
        "legno_scuro": cella_legno(hexc(conf["legno_scuro"]), 7),
        "metallo": cella_metallo(hexc(conf["metallo"]), 3),
        "metallo_scuro": cella_metallo(hexc(conf["metallo_scuro"]), 4, 0.1),
        "velluto": cella_velluto(hexc(conf["velluto"]), 5),
        "gemma": cella_gemma(hexc(conf["gemma"] or "#FFFFFF")),
        "buio": cella_metallo(hexc("#141210"), 6, 0.02),
        "lama": cella_metallo(hexc("#D9DEE6"), 8, 0.04),
    }
    per_riga = LATO_ATLANTE // CELLA
    for nome, c in celle.items():
        i = MAT[nome]
        r, k = divmod(i, per_riga)
        img[r * CELLA:(r + 1) * CELLA, k * CELLA:(k + 1) * CELLA] = c
    im = bpy.data.images.new("atlante", LATO_ATLANTE, LATO_ATLANTE, alpha=False)
    pixel = np.ones((LATO_ATLANTE, LATO_ATLANTE, 4))
    pixel[..., :3] = img[::-1]  # Blender: la riga 0 è in basso
    im.pixels.foreach_set(pixel.astype(np.float32).ravel())
    im.filepath_raw = file
    im.file_format = "PNG"
    im.save()
    return im


# Geometria -----------------------------------------------------------------------------------------

class Pezzo:
    """Raccoglie le forme di un pezzo del forziere (Base o Coperchio) in un solo bmesh."""

    def __init__(self, nome):
        self.nome = nome
        self.bm = bmesh.new()

    def aggiungi(self, bm, mat, matrice=None):
        if matrice is not None:
            bm.transform(matrice)
        for f in bm.faces:
            f.material_index = MAT[mat]
        me = bpy.data.meshes.new("tmp")
        bm.to_mesh(me)
        bm.free()
        self.bm.from_mesh(me)
        bpy.data.meshes.remove(me)


def smussa(bm, larghezza, segmenti=3, angolo=30):
    spigoli = [e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0) > math.radians(angolo)]
    if spigoli:
        bmesh.ops.bevel(bm, geom=spigoli, offset=larghezza, offset_type="OFFSET", segments=segmenti,
                        profile=0.5, affect="EDGES", clamp_overlap=True)
    return bm


def scatola(misure, smusso=0.04, segmenti=2):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(misure), verts=bm.verts)
    s = min(smusso, min(misure) * 0.45)
    return smussa(bm, s, segmenti) if s > 0.001 else bm


def cilindro(r, alto, lati=20, smusso=0.02, r2=None):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=lati, radius1=r,
                          radius2=r if r2 is None else r2, depth=alto)
    return smussa(bm, min(smusso, r * 0.4, alto * 0.4), 2, 40) if smusso else bm


def sfera(r, schiaccia=1.0):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=7, radius=r)
    if schiaccia != 1.0:
        bmesh.ops.scale(bm, vec=Vector((1, 1, schiaccia)), verts=bm.verts)
    return bm


def gemma(r, alto=0.6):
    """Gemma a taglio brillante: corona bassa, padiglione appuntito (asse Z)."""
    bm = bmesh.new()
    n = 8
    tavola = [bm.verts.new((math.cos(a) * r * 0.55, math.sin(a) * r * 0.55, r * alto * 0.45))
              for a in (2 * math.pi * i / n for i in range(n))]
    cintura = [bm.verts.new((math.cos(a) * r, math.sin(a) * r, 0))
               for a in (2 * math.pi * (i + 0.5) / n for i in range(n))]
    punta = bm.verts.new((0, 0, -r * alto))
    bm.faces.new(tavola)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((tavola[i], cintura[i], tavola[j]))
        bm.faces.new((cintura[i], cintura[j], tavola[j]))
        bm.faces.new((cintura[j], cintura[i], punta))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def toro(r, spessore, lati=24, sezione=10):
    bm = bmesh.new()
    anelli = []
    for i in range(lati):
        a = 2 * math.pi * i / lati
        c = Vector((math.cos(a) * r, math.sin(a) * r, 0))
        dirz = Vector((math.cos(a), math.sin(a), 0))
        anelli.append([bm.verts.new(c + dirz * math.cos(b) * spessore + Vector((0, 0, math.sin(b) * spessore)))
                       for b in (2 * math.pi * k / sezione for k in range(sezione))])
    for i in range(lati):
        a, b = anelli[i], anelli[(i + 1) % lati]
        for k in range(sezione):
            k2 = (k + 1) % sezione
            bm.faces.new((a[k], b[k], b[k2], a[k2]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def prisma(profilo, x0, x1, smusso=0.03):
    """Profilo convesso (lista di (y, z)) estruso lungo X da x0 a x1."""
    bm = bmesh.new()
    a = [bm.verts.new((x0, y, z)) for y, z in profilo]
    b = [bm.verts.new((x1, y, z)) for y, z in profilo]
    n = len(profilo)
    bm.faces.new(a[::-1])
    bm.faces.new(b)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return smussa(bm, smusso, 3) if smusso else bm


def nastro(esterno, interno, x0, x1, smusso=0.02):
    """Striscia curva tra due archi (liste di (y, z) della stessa lunghezza) estrusa lungo X: le fasce del
    coperchio. Costruita a quadrilateri, senza poligoni concavi."""
    bm = bmesh.new()
    n = len(esterno)
    ea = [bm.verts.new((x0, y, z)) for y, z in esterno]
    eb = [bm.verts.new((x1, y, z)) for y, z in esterno]
    ia = [bm.verts.new((x0, y, z)) for y, z in interno]
    ib = [bm.verts.new((x1, y, z)) for y, z in interno]
    for i in range(n - 1):
        bm.faces.new((ea[i], ea[i + 1], eb[i + 1], eb[i]))      # fuori
        bm.faces.new((ib[i], ib[i + 1], ia[i + 1], ia[i]))      # dentro
        bm.faces.new((ia[i], ia[i + 1], ea[i + 1], ea[i]))      # fianco x0
        bm.faces.new((eb[i], eb[i + 1], ib[i + 1], ib[i]))      # fianco x1
    bm.faces.new((ea[0], eb[0], ib[0], ia[0]))
    bm.faces.new((ia[-1], ib[-1], eb[-1], ea[-1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return smussa(bm, smusso, 2) if smusso else bm


def stella(r, spessore, punte=5, rapporto=0.45):
    """Stella in piano XZ (davanti verso -Y), spessore lungo Y; costruita a spicchi convessi."""
    bm = bmesh.new()
    pts = []
    for i in range(punte * 2):
        a = math.pi / 2 + math.pi * i / punte
        rr = r if i % 2 == 0 else r * rapporto
        pts.append((math.cos(a) * rr, math.sin(a) * rr))
    fa = [bm.verts.new((x, -spessore / 2, z)) for x, z in pts]
    fb = [bm.verts.new((x, spessore / 2, z)) for x, z in pts]
    ca = bm.verts.new((0, -spessore / 2 - spessore * 0.6, 0))
    cb = bm.verts.new((0, spessore / 2, 0))
    m = len(pts)
    for i in range(m):
        j = (i + 1) % m
        bm.faces.new((fa[i], fa[j], ca))
        bm.faces.new((fb[j], fb[i], cb))
        bm.faces.new((fa[i], fb[i], fb[j], fa[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def T(x=0, y=0, z=0):
    return Matrix.Translation((x, y, z))


def R(asse, gradi):
    return Matrix.Rotation(math.radians(gradi), 4, asse)


def S(x, y, z):
    return Matrix.Diagonal((x, y, z, 1))


# Arco del coperchio: ellisse da davanti (y = -a, z = 0) a dietro (y = +a, z = 0), in alto z = h.
def arco(a, h, n=24, da=0.0, a_=math.pi):
    return [(-a * math.cos(t), h * math.sin(t)) for t in np.linspace(da, a_, n)]


# Costruzione ---------------------------------------------------------------------------------------

def normale_arco(t, a, h):
    """Inclinazione (gradi, attorno a X) della normale dell'arco del coperchio nel punto t."""
    return math.degrees(math.atan2(math.cos(t) * h, math.sin(t) * a))


def foglia(lungo=0.45, largo=0.3, spessore=0.07):
    """Punta a foglia piatta che va verso +Y (piano YZ, spessore lungo X)."""
    return prisma([(0.0, -largo / 2), (lungo * 0.55, -largo * 0.42), (lungo, 0.0), (lungo * 0.55, largo * 0.42),
                   (0.0, largo / 2)], -spessore / 2, spessore / 2, 0.015)


def costruisci(conf):
    base = Pezzo("Base")
    cop = Pezzo("Coperchio")
    z0 = 0.32 if conf["piedi"] else 0.0
    zt = z0 + HB             # bordo superiore del baule = altezza della cerniera
    ricco = conf["angoli"] != "semplici"
    oro = conf["angoli"] == "ornati"
    borchia = "metallo" if oro else "metallo_scuro"
    davanti = R("X", 90)     # una forma con l'asse Z verso -Y (davanti)
    fianco = R("Y", 90)      # una forma con l'asse Z lungo X (fianchi)

    # --- Baule cavo: fondo e quattro pareti scure dentro, velluto sul fondo, doghe chiare fuori.
    base.aggiungi(scatola((W - 0.1, D - 0.1, PARETE), 0.03), "legno_scuro", T(0, 0, z0 + PARETE / 2 + 0.02))
    base.aggiungi(scatola((W - 2 * PARETE - 0.12, D - 2 * PARETE - 0.12, 0.06), 0.02), "velluto",
                  T(0, 0, z0 + PARETE + 0.05))
    for s in (-1, 1):
        base.aggiungi(scatola((W - 0.1, PARETE, HB - 0.04), 0.03), "legno_scuro",
                      T(0, s * (D / 2 - PARETE / 2 - 0.05), z0 + HB / 2))
        base.aggiungi(scatola((PARETE, D - 0.1, HB - 0.04), 0.03), "legno_scuro",
                      T(s * (W / 2 - PARETE / 2 - 0.05), 0, z0 + HB / 2))
    doghe = 4
    alta = HB / doghe
    for k in range(doghe):
        zc = z0 + alta * (k + 0.5)
        for s in (-1, 1):
            base.aggiungi(scatola((W - 0.08, 0.1, alta - 0.035), 0.035), "legno", T(0, s * (D / 2 - 0.05), zc))
            base.aggiungi(scatola((0.1, D - 0.08, alta - 0.035), 0.035), "legno", T(s * (W / 2 - 0.05), 0, zc))
    # Bordo in alto (dove poggia il coperchio) e zoccolo in basso.
    orlo = "metallo" if ricco else "legno_scuro"
    for s in (-1, 1):
        base.aggiungi(scatola((W + 0.04, 0.16, 0.14), 0.04), orlo, T(0, s * (D / 2 - 0.02), zt - 0.07))
        base.aggiungi(scatola((0.16, D + 0.04, 0.14), 0.04), orlo, T(s * (W / 2 - 0.02), 0, zt - 0.07))
    base.aggiungi(scatola((W + 0.16, D + 0.16, 0.2), 0.06), "legno_scuro", T(0, 0, z0 + 0.1))
    if ricco:
        base.aggiungi(scatola((W + 0.2, D + 0.2, 0.08), 0.03), "metallo", T(0, 0, z0 + 0.22))

    # --- Fasce di metallo verticali davanti e dietro (con borchie), due orizzontali sui fianchi.
    xs = [-W * 0.3, W * 0.3] if conf["fasce"] == 2 else [-W * 0.34, W * 0.34]
    larga = 0.26
    for x in xs:
        for s in (-1, 1):
            base.aggiungi(scatola((larga, 0.07, HB + 0.02), 0.025), "metallo", T(x, s * (D / 2 + 0.02), z0 + HB / 2))
            if conf["borchie"]:
                for zz in np.linspace(z0 + 0.3, zt - 0.3, 4 if ricco else 3):
                    base.aggiungi(sfera(0.055, 0.7), borchia, T(x, s * (D / 2 + 0.06), zz) @ davanti)
    for s in (-1, 1):
        for zz in (z0 + HB * 0.28, z0 + HB * 0.72):
            base.aggiungi(scatola((0.07, D + 0.04, larga), 0.025), "metallo", T(s * (W / 2 + 0.02), 0, zz))

    # --- Angoli: squadrette a L su ogni spigolo verticale; borchie; negli ornati punte a foglia.
    lato_ang = 0.42 if ricco else 0.34
    for sx in (-1, 1):
        for sy in (-1, 1):
            cx, cy = sx * (W / 2 + 0.035), sy * (D / 2 + 0.035)
            bordo_x = sx * (W / 2 + 0.07 - lato_ang)   # bordo interno della squadretta sul davanti/dietro
            bordo_y = sy * (D / 2 + 0.07 - lato_ang)   # bordo interno sul fianco
            base.aggiungi(scatola((lato_ang, 0.07, HB + 0.04), 0.025), "metallo",
                          T(sx * (W / 2 + 0.07 - lato_ang / 2), cy, z0 + HB / 2))
            base.aggiungi(scatola((0.07, lato_ang, HB + 0.04), 0.025), "metallo",
                          T(cx, sy * (D / 2 + 0.07 - lato_ang / 2), z0 + HB / 2))
            if ricco:
                for zz in (z0 + 0.3, z0 + HB / 2, zt - 0.3):
                    base.aggiungi(sfera(0.06, 0.7), borchia,
                                  T(sx * (W / 2 + 0.07 - lato_ang / 2), sy * (D / 2 + 0.08), zz) @ davanti)
                    base.aggiungi(sfera(0.06, 0.7), borchia,
                                  T(sx * (W / 2 + 0.08), sy * (D / 2 + 0.07 - lato_ang / 2), zz) @ fianco)
            if oro:
                # Punte a foglia verso l'interno, in alto e in basso, sul davanti/dietro e sul fianco.
                for zz in (z0 + 0.4, zt - 0.4):
                    base.aggiungi(foglia(), "metallo", T(bordo_x, cy, zz) @ R("Z", 90 * sx))
                    base.aggiungi(foglia(), "metallo", T(cx, bordo_y, zz) @ R("Z", 0 if sy < 0 else 180))

    # --- Piedi a cipolla.
    if conf["piedi"]:
        for sx in (-1, 1):
            for sy in (-1, 1):
                px, py = sx * (W / 2 - 0.3), sy * (D / 2 - 0.3)
                base.aggiungi(sfera(0.22, 0.85), "metallo", T(px, py, 0.17))
                base.aggiungi(cilindro(0.14, 0.12, 20, 0.03), "metallo_scuro", T(px, py, 0.33))

    # --- Maniglie sui fianchi: piastra, perno e anello.
    if conf["maniglie"]:
        for s in (-1, 1):
            base.aggiungi(scatola((0.06, 0.5, 0.36), 0.025), "metallo", T(s * (W / 2 + 0.09), 0, z0 + HB * 0.62))
            base.aggiungi(sfera(0.07), "metallo_scuro", T(s * (W / 2 + 0.14), 0, z0 + HB * 0.66))
            base.aggiungi(toro(0.24, 0.045), "metallo", T(s * (W / 2 + 0.17), 0, z0 + HB * 0.66 - 0.24) @ fianco)

    # --- Spade incrociate dietro la serratura (casse medie).
    yf = -D / 2 - 0.05
    if conf["emblema"] == "spade":
        for ang in (-38, 38):
            m = T(0, yf - 0.03, z0 + HB * 0.5) @ R("Y", ang)
            base.aggiungi(scatola((0.13, 0.04, 1.3), 0.02), "lama", m @ T(0, 0, 0.25))
            base.aggiungi(prisma([(-0.065, 0), (0.065, 0), (0, 0.16)], -0.02, 0.02, 0.0), "lama",
                          m @ T(0, 0, 0.9) @ R("Z", 90))
            base.aggiungi(scatola((0.44, 0.07, 0.08), 0.025), "metallo", m @ T(0, -0.02, -0.42))
            base.aggiungi(scatola((0.09, 0.06, 0.3), 0.02), "legno_scuro", m @ T(0, -0.02, -0.61))
            base.aggiungi(sfera(0.07), "metallo", m @ T(0, -0.02, -0.8))

    # --- Serratura: piastra a tre strati con la toppa; nelle casse grandi uno scudo dietro.
    piastra_l, piastra_a = (0.78, 0.98) if ricco else (0.62, 0.8)
    zp = zt - 0.12 - piastra_a / 2
    if conf["emblema"] in ("stella", "corona"):
        scudo = prisma([(-0.62, 0.38), (0.62, 0.38), (0.6, -0.25), (0.0, -0.8), (-0.6, -0.25)], -0.03, 0.03, 0.025)
        base.aggiungi(scudo, "metallo", T(0, yf - 0.01, zp) @ R("Z", 90))
    base.aggiungi(scatola((piastra_l, 0.08, piastra_a), 0.035), "metallo", T(0, yf - 0.04, zp))
    base.aggiungi(scatola((piastra_l - 0.14, 0.04, piastra_a - 0.14), 0.02), "metallo_scuro", T(0, yf - 0.08, zp))
    base.aggiungi(scatola((piastra_l - 0.26, 0.05, piastra_a - 0.26), 0.02), "metallo", T(0, yf - 0.09, zp))
    ztoppa = zp - 0.14
    base.aggiungi(cilindro(0.075, 0.06, 16, 0.0), "buio", T(0, yf - 0.12, ztoppa) @ davanti)
    base.aggiungi(prisma([(-0.05, 0.0), (0.05, 0.0), (0.035, -0.2), (-0.035, -0.2)], -0.03, 0.03, 0.0), "buio",
                  T(0, yf - 0.12, ztoppa) @ R("Z", 90))
    for sx in (-1, 1):
        for sz in (-1, 1):
            base.aggiungi(sfera(0.045, 0.7), borchia,
                          T(sx * (piastra_l / 2 - 0.075), yf - 0.08, zp + sz * (piastra_a / 2 - 0.075)) @ davanti)
    zgemma = zp + 0.17
    if conf["emblema"] == "stella":
        base.aggiungi(stella(0.2, 0.05), "metallo", T(0, yf - 0.14, zgemma))
        base.aggiungi(gemma(0.08), "gemma", T(0, yf - 0.2, zgemma) @ davanti)
    elif conf["emblema"] == "corona":
        base.aggiungi(cilindro(0.17, 0.05, 20, 0.015), "metallo", T(0, yf - 0.13, zgemma) @ davanti)
        base.aggiungi(gemma(0.13), "gemma", T(0, yf - 0.17, zgemma) @ davanti)
        for x in (-0.44, 0.44):
            base.aggiungi(gemma(0.08), "gemma", T(x, yf - 0.06, zp + 0.1) @ davanti)
    elif conf["gemma"]:
        base.aggiungi(gemma(0.09), "gemma", T(0, yf - 0.14, zgemma) @ davanti)
    if conf["gemma"] and oro:
        # Due gemme incastonate sul davanti, tra la serratura e le fasce.
        for x in (-W * 0.17, W * 0.17):
            base.aggiungi(cilindro(0.15, 0.05, 20, 0.015), "metallo", T(x, yf + 0.0, z0 + HB * 0.45) @ davanti)
            base.aggiungi(gemma(0.1), "gemma", T(x, yf - 0.04, z0 + HB * 0.45) @ davanti)

    # --- Cardini dietro (metà sul baule, metà sul coperchio).
    for x in (-W * 0.2, W * 0.2):
        base.aggiungi(scatola((0.32, 0.06, 0.3), 0.02), "metallo", T(x, D / 2 + 0.07, zt - 0.17))
        base.aggiungi(cilindro(0.06, 0.34, 14, 0.015), "metallo_scuro", T(x, D / 2 + 0.1, zt) @ fianco)

    # --- Coperchio a botte: anima scura, doghe curve, testate ai lati con il bordo, fasce, chiavistello.
    a, h = D / 2, HL
    cop.aggiungi(prisma(arco(a - 0.08, h - 0.08, 24), -W / 2 + 0.06, W / 2 - 0.06, 0.03), "legno_scuro", T(0, 0, zt))
    pts = arco(a, h, 7)
    for k in range(len(pts) - 1):
        p0, p1 = Vector((0, *pts[k])), Vector((0, *pts[k + 1]))
        mezzo = (p0 + p1) / 2
        tang = p1 - p0
        ang = math.degrees(math.atan2(tang.z, tang.y))
        cop.aggiungi(scatola((W - 0.3, tang.length - 0.035, 0.11), 0.035), "legno",
                     T(0, mezzo.y, zt + mezzo.z) @ R("X", ang) @ T(0, 0, -0.04))
    for s in (-1, 1):
        x_in, x_out = sorted((s * (W / 2 - 0.16), s * (W / 2 - 0.02)))
        cop.aggiungi(prisma(arco(a + 0.02, h + 0.02, 24), x_in, x_out, 0.035), "legno", T(0, 0, zt))
        x_in, x_out = sorted((s * (W / 2 + 0.03), s * (W / 2 - 0.06)))
        cop.aggiungi(nastro(arco(a + 0.07, h + 0.07, 26), arco(a - 0.12, h - 0.12, 26), x_in, x_out), "metallo",
                     T(0, 0, zt))
    for x in xs:
        cop.aggiungi(nastro(arco(a + 0.1, h + 0.1, 26), arco(a - 0.02, h - 0.02, 26), x - larga / 2, x + larga / 2),
                     "metallo", T(0, 0, zt))
        if conf["borchie"]:
            for t in np.linspace(0.35, math.pi - 0.35, 5):
                y, z = -(a + 0.11) * math.cos(t), (h + 0.11) * math.sin(t)
                cop.aggiungi(sfera(0.055, 0.7), borchia, T(x, y, zt + z) @ R("X", normale_arco(t, a, h)))
    if conf["fasce"] == 3:
        # Fascia centrale, che parte da dietro il chiavistello.
        t0 = 0.5
        cop.aggiungi(nastro(arco(a + 0.1, h + 0.1, 26, t0, math.pi), arco(a - 0.02, h - 0.02, 26, t0, math.pi),
                            -0.2, 0.2), "metallo", T(0, 0, zt))
    if conf["gemme_coperchio"]:
        posti = [0.0] if conf["gemme_coperchio"] == 1 else [-W * 0.34, 0.0, W * 0.34]
        t = math.pi * 0.5
        for x in posti:
            y, z = -(a + 0.1) * math.cos(t), (h + 0.1) * math.sin(t)
            m = T(x, y, zt + z) @ R("X", normale_arco(t, a, h))
            cop.aggiungi(cilindro(0.17, 0.06, 20, 0.02), "metallo", m @ T(0, 0, 0.02))
            cop.aggiungi(gemma(0.13), "gemma", m @ T(0, 0, 0.09))
    # Orli lunghi davanti e dietro, chiavistello che scende sulla serratura, cardini.
    cop.aggiungi(scatola((W - 0.1, 0.14, 0.14), 0.04), orlo, T(0, -a + 0.02, zt + 0.07))
    cop.aggiungi(scatola((W - 0.1, 0.14, 0.14), 0.04), orlo, T(0, a - 0.02, zt + 0.07))
    lc = 0.36 if ricco else 0.3
    yc = -D / 2 - 0.22
    cop.aggiungi(scatola((lc + 0.14, 0.26, 0.16), 0.035), "metallo", T(0, -D / 2 - 0.1, zt + 0.1))
    cop.aggiungi(scatola((lc, 0.07, 0.46), 0.03), "metallo", T(0, yc, zt - 0.05))
    cop.aggiungi(toro(0.07, 0.025, 16, 8), "metallo_scuro", T(0, yc - 0.05, zt - 0.18) @ davanti)
    for zz in (zt + 0.1, zt - 0.05):
        cop.aggiungi(sfera(0.04, 0.7), borchia, T(0, yc - 0.04, zz) @ davanti)
    for x in (-W * 0.2, W * 0.2):
        cop.aggiungi(scatola((0.32, 0.06, 0.3), 0.02), "metallo", T(x, D / 2 + 0.07, zt + 0.15))
    return base, cop, zt


# Mesh finale, UV, normali --------------------------------------------------------------------------

def finisci(pezzo, materiale):
    bm = pezzo.bm
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    # Liscio dove gli spigoli sono morbidi; le gemme sempre sfaccettate.
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        if len(e.link_faces) != 2:
            e.smooth = False
            continue
        gem = all(f.material_index == MAT["gemma"] for f in e.link_faces)
        diverso = e.link_faces[0].material_index != e.link_faces[1].material_index
        e.smooth = not (gem or diverso or e.calc_face_angle(0) > math.radians(50))
    # UV: proiezione sull'asse dominante della normale, dentro la cella del materiale.
    uv = bm.loops.layers.uv.new("UVMap")
    per_riga = LATO_ATLANTE // CELLA
    ampio = 6.4  # studs coperti da una cella
    for f in bm.faces:
        r, k = divmod(f.material_index, per_riga)
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for l in f.loops:
            p = l.vert.co
            if ax == 0:
                u, v = p.y, p.z
            elif ax == 1:
                u, v = p.x, p.z
            else:
                u, v = p.x, p.y
            u = min(max(0.5 + u / ampio, 0), 1)
            v = min(max(0.5 + (v - 1.4) / ampio, 0), 1)
            px = k * CELLA + MARGINE + u * (CELLA - 2 * MARGINE)
            py = r * CELLA + MARGINE + v * (CELLA - 2 * MARGINE)
            l[uv].uv = (px / LATO_ATLANTE, 1 - py / LATO_ATLANTE)
    me = bpy.data.meshes.new(pezzo.nome)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.material_index = 0
    me.materials.append(materiale)
    ob = bpy.data.objects.new(pezzo.nome, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def materiale(img):
    mat = bpy.data.materials.new("Forziere")
    mat.use_nodes = True
    nodi = mat.node_tree.nodes
    bsdf = nodi.get("Principled BSDF")
    tex = nodi.new("ShaderNodeTexImage")
    tex.image = img
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.55
    return mat


def ingombro(ob):
    vs = np.array([ob.matrix_world @ v.co for v in ob.data.vertices])
    return vs.min(0), vs.max(0)


def roblox(v):
    """Da Blender a Roblox: x = -x, y = z, z = y (come tools/blocchi/esporta_fbx.py)."""
    return [-v[0], v[2], v[1]]


def fai(nome, anteprime):
    conf = FORZIERI[nome]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    cartella = os.path.join(USCITA, nome)
    os.makedirs(cartella, exist_ok=True)
    png = os.path.join(cartella, nome + ".png")
    img = atlante(conf, png)
    mat = materiale(img)
    base, cop, zt = costruisci(conf)
    ob_base = finisci(base, mat)
    ob_cop = finisci(cop, mat)

    # Cerniera: dietro, in cima al baule. In frazioni dell'ingombro del coperchio (assi di Roblox), così il
    # gioco la ritrova qualunque scala abbia il modello.
    mn, mx = ingombro(ob_cop)
    centro = (mn + mx) / 2
    misura = mx - mn
    cerniera = np.array([0.0, D / 2 + 0.1, zt])
    frazione = (cerniera - centro) / misura
    bmn, bmx = ingombro(ob_base)
    tutto_mn = np.minimum(mn, bmn)
    tutto_mx = np.maximum(mx, bmx)
    tri = sum(len(o.data.polygons) for o in (ob_base, ob_cop))
    info = {
        "cerniera": [-frazione[0], frazione[2], frazione[1]],
        "misure": [float(x) for x in np.abs(roblox(tutto_mx - tutto_mn))],
        "triangoli": tri,
    }

    fbx = os.path.join(cartella, nome + ".fbx")
    bpy.ops.export_scene.fbx(filepath=fbx, use_selection=False, object_types={"MESH"}, mesh_smooth_type="OFF",
                             path_mode="COPY", embed_textures=True, axis_forward="-Z", axis_up="Y",
                             apply_scale_options="FBX_SCALE_ALL")
    print("esportato", fbx, [len(o.data.polygons) for o in (ob_base, ob_cop)], "triangoli")
    if anteprime:
        anteprima(nome, conf, ob_base, ob_cop, cerniera, cartella)
    return info


# Anteprime e icone ---------------------------------------------------------------------------------

def anteprima(nome, conf, ob_base, ob_cop, cerniera, cartella):
    scena = bpy.context.scene
    scena.render.engine = "BLENDER_EEVEE"
    scena.view_settings.view_transform = "Standard"
    scena.render.resolution_x = 900
    scena.render.resolution_y = 900
    mondo = bpy.data.worlds.new("Mondo")
    scena.world = mondo
    mondo.use_nodes = True
    mondo.node_tree.nodes["Background"].inputs["Color"].default_value = (0.5, 0.55, 0.62, 1)
    mondo.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
    sole = bpy.data.objects.new("Sole", bpy.data.lights.new("Sole", "SUN"))
    sole.data.energy = 3.2
    sole.rotation_euler = (math.radians(48), 0, math.radians(-35))
    scena.collection.objects.link(sole)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = 70
    scena.collection.objects.link(cam)
    scena.camera = cam
    bersaglio = Vector((0, 0, 1.45))

    def scatta(az, el, dist, file, trasparente=False):
        scena.render.film_transparent = trasparente
        d = Vector((math.sin(math.radians(az)) * math.cos(math.radians(el)),
                    -math.cos(math.radians(az)) * math.cos(math.radians(el)),
                    math.sin(math.radians(el)))) * dist
        cam.location = bersaglio + d
        cam.rotation_euler = (bersaglio - cam.location).to_track_quat("-Z", "Y").to_euler()
        scena.render.filepath = file
        bpy.ops.render.render(write_still=True)

    scatta(-30, 22, 16, os.path.join(cartella, "anteprima_chiuso.png"))
    scatta(150, 25, 16, os.path.join(cartella, "anteprima_retro.png"))
    # Icona: 3/4 dall'alto, sfondo trasparente.
    scena.render.resolution_x = 1024
    scena.render.resolution_y = 1024
    icona = os.path.join(cartella, "icona_grezza.png")
    bersaglio = Vector((0, 0, 1.35))
    scatta(-28, 24, 15.5, icona, True)
    # Aperto: coperchio ruotato sulla cerniera.
    scena.render.resolution_x = 900
    scena.render.resolution_y = 900
    bersaglio = Vector((0, 0, 1.6))
    ob_cop.matrix_world = Matrix.Translation(Vector(cerniera)) @ Matrix.Rotation(math.radians(-105), 4, "X") @ Matrix.Translation(-Vector(cerniera))
    scatta(-25, 30, 16, os.path.join(cartella, "anteprima_aperto.png"))


def main():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    anteprime = "--anteprime" in a
    nomi = [x for x in a if not x.startswith("--")] or list(FORZIERI)
    file_info = os.path.join(USCITA, "forzieri.json")
    tutti = {}
    if os.path.exists(file_info):
        with open(file_info, encoding="utf-8") as f:
            tutti = json.load(f)
    for nome in nomi:
        tutti[nome] = fai(nome, anteprime)
    with open(file_info, "w", encoding="utf-8") as f:
        json.dump(tutti, f, indent=1)


main()
