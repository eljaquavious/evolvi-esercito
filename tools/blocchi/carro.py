"""Sherman M4 (carro armato del Novecento) con forme arrotondate e smussate.

Le parti sono solidi veri: scafo e torretta come inviluppi convessi con gli spigoli smussati, ruote e
canna cilindriche, cingoli ad anello. Poi un atlante uv (xatlas) e una texture cotta con il colore di
ogni parte, il battistrada, un po' di grana e l'occlusione ambientale. Misure vere (5,9 x 2,6 x 2,7 m),
assi di Roblox. Ossa come il vecchio modello: bacino (scafo), torretta, cannone (mantello) e canna (bocca).

Uso: python3 tools/blocchi/carro.py [--glb cartella] [--prova]   (--prova: non scrive in MeshDati)
"""
import os
import sys

import numpy as np
import shapely.geometry as sg
import trimesh
import xatlas
from PIL import Image
from scipy.spatial import ConvexHull

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cavalli  # noqa: E402  (occlusione ambientale)
import meshdati  # noqa: E402
from costruttore import colore  # noqa: E402

LATO = 1024
OSSA = [
    {"nome": "bacino", "padre": None, "posizione": [0, 1.0, 0]},
    {"nome": "torretta", "padre": "bacino", "posizione": [0, 1.86, 0.25]},
    {"nome": "cannone", "padre": "torretta", "posizione": [0, 2.2, -0.62]},
    {"nome": "canna", "padre": "cannone", "posizione": [0, 2.2, -3.35]},
]
INDICE = {o["nome"]: i for i, o in enumerate(OSSA)}


def rgb(c):
    return np.array(colore(c), float)


OLIVA = rgb("#5E6236")
OLIVA_SCURO = rgb("#4C502E")
ACCIAIO = rgb("#3E4042")
CINGOLO = rgb("#3C3834")
GOMMA = rgb("#24221F")
BIANCO = rgb("#E8E6DA")
LEGNO = rgb("#7A5A34")
TELA = rgb("#6E6A4A")

parti = []  # (mesh, osso, colore o funzione(pos, normali) -> colori, angolo oltre il quale lo spigolo resta vivo)


def aggiungi(mesh, osso, tinta, angolo=40):
    parti.append((mesh, osso, tinta, angolo))


def inviluppo(punti, smusso=0.0):
    """Solido convesso dei punti, con gli spigoli arrotondati di "smusso" metri."""
    punti = np.asarray(punti, float)
    if smusso > 0:
        sfera = trimesh.creation.icosphere(subdivisions=1, radius=smusso).vertices
        punti = (punti[:, None, :] + sfera[None, :, :]).reshape(-1, 3)
    return trimesh.convex.convex_hull(punti)


def scatola_tonda(centro, misure, r):
    c, m = np.array(centro, float), np.array(misure, float) / 2 - r
    angoli = np.array([[sx, sy, sz] for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]) * m + c
    return inviluppo(angoli, r)


def cilindro(da, a, r, sezioni=24):
    return trimesh.creation.cylinder(radius=r, segment=np.array([da, a], float), sections=sezioni)


def anello_cingolo(x, larghezza, spessore=0.08):
    """Cingolo ad anello: profilo nel piano z-y (ruota motrice davanti, di rinvio dietro) estruso in x."""
    pts = []
    for c, r in (((-2.6, 0.74), 0.36), ((2.62, 0.56), 0.31)):
        for t in np.linspace(0, 2 * np.pi, 48, endpoint=False):
            pts.append([c[0] + r * np.cos(t), c[1] + r * np.sin(t)])
    for z in np.linspace(-2.05, 2.1, 12):
        pts.append([z, 0.0])
    zy = np.array(pts)
    giro = zy[ConvexHull(zy).vertices]
    chiuso = np.vstack([giro, giro[:1]])
    lun = np.r_[0, np.cumsum(np.linalg.norm(np.diff(chiuso, axis=0), axis=1))]
    s = np.linspace(0, lun[-1], 160, endpoint=False)
    est = np.c_[np.interp(s, lun, chiuso[:, 0]), np.interp(s, lun, chiuso[:, 1])]
    tang = np.roll(est, -1, 0) - np.roll(est, 1, 0)
    norm = np.c_[tang[:, 1], -tang[:, 0]]
    norm /= np.linalg.norm(norm, axis=1, keepdims=True)
    if np.mean(np.sum(norm * (est - est.mean(0)), 1)) < 0:
        norm = -norm
    inn = est - norm * spessore
    n = len(est)
    V = []
    for xx in (x - larghezza / 2, x + larghezza / 2):
        V += [[xx, p[1], p[0]] for p in est]
        V += [[xx, p[1], p[0]] for p in inn]
    E0, I0, E1, I1 = 0, n, 2 * n, 3 * n
    F = []
    for i in range(n):
        j = (i + 1) % n
        F += [[E0 + i, E0 + j, E1 + j], [E0 + i, E1 + j, E1 + i]]
        F += [[I0 + i, I1 + j, I0 + j], [I0 + i, I1 + i, I1 + j]]
        F += [[E0 + i, I0 + i, I0 + j], [E0 + i, I0 + j, E0 + j]]
        F += [[E1 + i, E1 + j, I1 + j], [E1 + i, I1 + j, I1 + i]]
    mesh = trimesh.Trimesh(np.array(V), F, process=False)
    mesh.fix_normals()
    return mesh


def stella(centro, verso, r, cerchio=None):
    """Stella a cinque punte in rilievo sul fianco rivolto verso x = verso (con il cerchio, se dato)."""
    punte = [[np.cos(np.pi / 2 + k * np.pi / 5) * (r if k % 2 == 0 else r * 0.4),
              np.sin(np.pi / 2 + k * np.pi / 5) * (r if k % 2 == 0 else r * 0.4)] for k in range(10)]
    forme = [sg.Polygon(punte)]
    if cerchio:
        forme.append(sg.Point(0, 0).buffer(cerchio, 32).difference(sg.Point(0, 0).buffer(cerchio * 0.86, 32)))
    pezzi = []
    for forma in forme:
        m = trimesh.creation.extrude_polygon(forma, 0.012)
        T = np.eye(4)
        T[:3, :3] = np.column_stack([[0, 0, -verso], [0, 1, 0], [verso, 0, 0]])
        m.apply_transform(T)
        m.apply_translation(centro)
        pezzi.append(m)
    return trimesh.util.concatenate(pezzi)


def tinta_unita(c):
    return lambda pos, normali: np.tile(c, (len(pos), 1))


def battistrada(pos, normali):
    """Cingolo: piastre e solchi lungo il giro (z sui tratti dritti, y sulle ruote)."""
    giro = np.where(np.abs(normali[:, 1]) > 0.5, pos[:, 2], pos[:, 1] + pos[:, 2] * 0.3)
    col = np.where(((giro * 7.0) % 1.0 < 0.32)[:, None], GOMMA, CINGOLO)
    col[np.abs(normali[:, 0]) > 0.7] = CINGOLO * 0.8
    return col


def ruota_portante(pos, normali):
    """Ruota: gomma sul battistrada, disco d'acciaio verniciato sul fianco."""
    return np.where((np.abs(normali[:, 0]) > 0.7)[:, None], OLIVA_SCURO, GOMMA)


def griglia(pos, normali):
    return np.where((((pos[:, 2] * 12) % 1 < 0.45) & (normali[:, 1] > 0.9))[:, None], OLIVA_SCURO * 0.55, OLIVA_SCURO)


def fanale(pos, normali):
    return np.where((normali[:, 2] < -0.9)[:, None], BIANCO * 0.9, ACCIAIO)


def costruisci_sherman():
    parti.clear()
    # -- Scafo: parte alta sopra i cingoli, piastra frontale inclinata, muso arrotondato, parte bassa.
    punti = []
    for x in (-1.24, 1.24):
        punti += [[x, 1.0, -1.45], [x, 1.78, -1.45], [x, 1.78, 2.4], [x, 1.0, 2.55], [x, 1.62, 2.58],
                  [x * 0.97, 1.12, -2.3]]
    for x in (-0.96, 0.96):  # scatola del cambio arrotondata sul davanti
        for a in np.linspace(np.radians(80), np.radians(-90), 9):
            punti.append([x, 0.82 + 0.42 * np.sin(a), -2.22 - 0.42 * np.cos(a)])
    for x in (-0.86, 0.86):
        punti += [[x, 0.45, -2.0], [x, 0.45, 2.5]]
    aggiungi(inviluppo(punti, 0.06), "bacino", tinta_unita(OLIVA), 30)

    # Portelli del pilota e del mitragliere, sfera della mitragliatrice di prua, fanali.
    for x in (-0.55, 0.55):
        aggiungi(cilindro([x, 1.8, -1.05], [x, 1.87, -1.05], 0.3, 28), "bacino", tinta_unita(OLIVA_SCURO))
        aggiungi(cilindro([x, 1.87, -1.05], [x, 1.91, -1.05], 0.08, 12), "bacino", tinta_unita(OLIVA_SCURO))
    aggiungi(trimesh.creation.icosphere(2, 0.14).apply_translation([0.5, 1.48, -1.95]), "bacino", tinta_unita(OLIVA_SCURO))
    aggiungi(cilindro([0.5, 1.45, -2.0], [0.5, 1.38, -2.4], 0.03, 10), "bacino", tinta_unita(ACCIAIO))
    for x in (-0.92, 0.92):
        aggiungi(cilindro([x, 1.24, -2.38], [x, 1.24, -2.52], 0.08, 16), "bacino", fanale)
    # Cingoli di ricambio sulla piastra frontale.
    asse = np.array([0, 1.78 - 1.12, -1.45 + 2.3])
    asse /= np.linalg.norm(asse)
    normale = np.cross([1, 0, 0], asse)
    for k in range(5):
        box = scatola_tonda([0, 0, 0], [0.44, 0.15, 0.06], 0.02)
        rot = np.eye(4)
        rot[:3, :3] = np.column_stack([[1, 0, 0], asse, normale])
        box.apply_transform(rot)
        box.apply_translation(np.array([-0.4, 1.12, -2.25]) + asse * (0.14 + 0.17 * k) + normale * 0.08)
        aggiungi(box, "bacino", battistrada)
    # Griglie del motore, cassa, pala, telo; retro con scarichi e ganci.
    for x in (-0.6, 0.6):
        aggiungi(scatola_tonda([x, 1.83, 1.55], [0.9, 0.06, 1.3], 0.02), "bacino", griglia)
    aggiungi(scatola_tonda([0, 1.86, 0.95], [1.6, 0.08, 0.35], 0.03), "bacino", tinta_unita(OLIVA_SCURO))
    aggiungi(scatola_tonda([1.05, 1.88, 1.6], [0.14, 0.1, 1.2], 0.04), "bacino", tinta_unita(LEGNO))
    aggiungi(scatola_tonda([-1.0, 1.92, 2.05], [0.42, 0.24, 0.6], 0.09), "bacino", tinta_unita(TELA))
    for x in (-0.55, 0.55):
        aggiungi(scatola_tonda([x, 1.0, 2.68], [0.42, 0.3, 0.16], 0.05), "bacino", tinta_unita(ACCIAIO))
    for x in (-0.95, 0.95):
        aggiungi(cilindro([x, 0.62, 2.6], [x, 0.62, 2.78], 0.06, 12), "bacino", tinta_unita(ACCIAIO))

    # -- Cingoli, ruote, carrelli.
    for x in (-1.1, 1.1):
        aggiungi(anello_cingolo(x, 0.42), "bacino", battistrada, 25)
        for z in (-1.72, -1.12, -0.32, 0.28, 1.08, 1.68):  # ruote portanti a coppie
            aggiungi(cilindro([x - 0.19, 0.36, z], [x + 0.19, 0.36, z], 0.27, 28), "bacino", ruota_portante)
            aggiungi(cilindro([x * 1.17, 0.36, z], [x * 1.19, 0.36, z], 0.1, 16), "bacino", tinta_unita(OLIVA_SCURO))
        for z in (-1.42, 0.0, 1.38):  # carrelli e rulli di ritorno
            aggiungi(scatola_tonda([x * 0.8, 0.52, z], [0.22, 0.42, 0.7], 0.07), "bacino", tinta_unita(OLIVA))
            aggiungi(cilindro([x - 0.12, 0.98, z + 0.1], [x + 0.12, 0.98, z + 0.1], 0.08, 14), "bacino", tinta_unita(OLIVA_SCURO))
        aggiungi(cilindro([x - 0.2, 0.74, -2.6], [x + 0.2, 0.74, -2.6], 0.3, 24), "bacino", tinta_unita(OLIVA_SCURO))
        aggiungi(cilindro([x - 0.2, 0.56, 2.62], [x + 0.2, 0.56, 2.62], 0.26, 24), "bacino", tinta_unita(OLIVA_SCURO))

    # -- Torretta fusa: anelli a superellisse (con la sporgenza dietro) in un inviluppo arrotondato.
    anelli = []
    for y, sx, sf, sb in ((1.86, 0.98, 0.9, 1.05), (2.08, 0.99, 0.92, 1.12), (2.38, 0.9, 0.82, 1.05),
                          (2.56, 0.74, 0.62, 0.86)):
        for t in np.linspace(0, 2 * np.pi, 40, endpoint=False):
            c, s = np.cos(t), np.sin(t)
            rx = sx * np.sign(c) * abs(c) ** (2 / 2.6)
            rz = (sb if s > 0 else sf) * np.sign(s) * abs(s) ** (2 / 2.6)
            anelli.append([rx, y, 0.25 + rz])
    aggiungi(inviluppo(anelli, 0.04), "torretta", tinta_unita(OLIVA), 50)
    aggiungi(cilindro([0, 1.78, 0.25], [0, 1.87, 0.25], 1.0, 40), "torretta", tinta_unita(OLIVA_SCURO))
    # Cupola del capocarro, portello del servente, periscopi, mitragliatrice .50, antenna.
    aggiungi(cilindro([0.38, 2.5, 0.6], [0.38, 2.72, 0.6], 0.32, 28), "torretta", tinta_unita(OLIVA))
    aggiungi(cilindro([0.38, 2.72, 0.6], [0.38, 2.76, 0.6], 0.27, 28), "torretta", tinta_unita(OLIVA_SCURO))
    aggiungi(cilindro([-0.38, 2.52, 0.5], [-0.38, 2.63, 0.5], 0.24, 24), "torretta", tinta_unita(OLIVA_SCURO))
    for x, z in ((0.1, -0.12), (-0.5, -0.02)):
        aggiungi(scatola_tonda([x, 2.6, z], [0.16, 0.12, 0.12], 0.025), "torretta", tinta_unita(ACCIAIO))
    aggiungi(cilindro([0.38, 2.76, 0.95], [0.38, 2.98, 0.95], 0.03, 8), "torretta", tinta_unita(ACCIAIO))
    aggiungi(scatola_tonda([0.38, 3.0, 0.85], [0.12, 0.14, 0.32], 0.03), "torretta", tinta_unita(ACCIAIO))
    aggiungi(cilindro([0.38, 3.02, 0.7], [0.38, 3.02, -0.25], 0.035, 10), "torretta", tinta_unita(ACCIAIO))
    aggiungi(cilindro([-0.6, 2.4, 1.15], [-0.6, 3.3, 1.15], 0.012, 6), "torretta", tinta_unita(ACCIAIO))
    # Stelle bianche sui fianchi della torretta e dello scafo.
    for x in (-1, 1):
        aggiungi(stella([x * 1.035, 2.18, 0.3], x, 0.2), "torretta", tinta_unita(BIANCO), 5)
        aggiungi(stella([x * 1.31, 1.42, 0.55], x, 0.24, cerchio=0.31), "bacino", tinta_unita(BIANCO), 5)

    # -- Mantello e cannone da 75 mm (con la mitragliatrice coassiale).
    aggiungi(scatola_tonda([0, 2.18, -0.72], [0.95, 0.56, 0.32], 0.11), "cannone", tinta_unita(OLIVA))
    aggiungi(scatola_tonda([0, 2.2, -0.92], [0.42, 0.34, 0.2], 0.08), "cannone", tinta_unita(OLIVA))
    aggiungi(cilindro([0, 2.2, -0.95], [0, 2.2, -3.2], 0.075, 20), "cannone", tinta_unita(OLIVA))
    aggiungi(cilindro([0, 2.2, -3.12], [0, 2.2, -3.35], 0.1, 20), "cannone", tinta_unita(OLIVA_SCURO))
    aggiungi(cilindro([0.24, 2.2, -0.88], [0.24, 2.2, -1.1], 0.035, 10), "cannone", tinta_unita(ACCIAIO))


def _rasterizza(uv_px, tri, colore_punti, lato):
    """Per ogni triangolo: pixel dentro, coordinate baricentriche -> colore (callback). Poi allarga i bordi."""
    img = np.zeros((lato, lato, 3), np.float32)
    pieno = np.zeros((lato, lato), bool)
    for f, (a, b, c) in enumerate(tri):
        T = uv_px[[a, b, c]]
        x0, y0 = np.maximum(np.floor(T.min(0)).astype(int), 0)
        x1, y1 = np.minimum(np.ceil(T.max(0)).astype(int), lato - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        v0, v1 = T[1] - T[0], T[2] - T[0]
        den = v0[0] * v1[1] - v1[0] * v0[1]
        if abs(den) < 1e-12:
            continue
        dx, dy = xs - T[0][0], ys - T[0][1]
        l1 = (dx * v1[1] - v1[0] * dy) / den
        l2 = (v0[0] * dy - dx * v0[1]) / den
        l0 = 1 - l1 - l2
        dentro = (l0 >= -0.03) & (l1 >= -0.03) & (l2 >= -0.03)
        if not dentro.any():
            continue
        L = np.stack([l0, l1, l2], -1)[dentro]
        yy, xx = ys[dentro].astype(int), xs[dentro].astype(int)
        img[yy, xx] = colore_punti(f, (a, b, c), L, yy, xx)
        pieno[yy, xx] = True
    for _ in range(4):
        somma = np.zeros_like(img)
        conta = np.zeros(pieno.shape, np.float32)
        for sx, sy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sp = np.roll(np.roll(pieno, sy, 0), sx, 1)
            somma += np.roll(np.roll(img, sy, 0), sx, 1) * sp[..., None]
            conta += sp
        nuovi = ~pieno & (conta > 0)
        img[nuovi] = somma[nuovi] / conta[nuovi][:, None]
        pieno |= nuovi
    return img


def cuoci():
    """Unisce le parti, apre l'atlante uv, cuoce colori e ombre. Restituisce il modello per meshdati."""
    P, N, F, O, tinte = [], [], [], [], []
    base = 0
    for mesh, osso, tinta, angolo in parti:
        m = trimesh.graph.smooth_shade(mesh, angle=np.radians(angolo), facet_minarea=1e9)
        P.append(m.vertices)
        N.append(m.vertex_normals)
        F.append(m.faces + base)
        O += [INDICE[osso]] * len(m.vertices)
        tinte += [tinta] * len(m.faces)
        base += len(m.vertices)
    pos, nor, tri = np.vstack(P), np.vstack(N), np.vstack(F)
    ossa = np.array(O)
    atlante = xatlas.Atlas()
    atlante.add_mesh(pos.astype(np.float32), tri.astype(np.uint32), nor.astype(np.float32))
    tpu = 260.0
    while True:
        opz = xatlas.PackOptions()
        opz.padding = 3
        opz.bilinear = True
        opz.texels_per_unit = tpu
        opz.resolution = 0
        atlante.generate(xatlas.ChartOptions(), opz)
        if atlante.width <= LATO and atlante.height <= LATO:
            break
        tpu *= 0.94
    vmap, tri_n, uv_n = atlante[0]  # i triangoli restano nello stesso ordine
    pos, nor, ossa = pos[vmap], nor[vmap], ossa[vmap]
    tri = tri_n.astype(np.int64)
    uv_px = uv_n * np.array([atlante.width, atlante.height])

    luce = cavalli._occlusione(pos, nor, tri, raggi=40)
    alto = np.clip((pos[:, 1] - pos[:, 1].min()) / np.ptp(pos[:, 1]), 0, 1)
    ombra = np.clip(np.clip(luce, 0, 1) ** 0.85 * (0.82 + 0.18 * alto) * (0.92 + 0.1 * nor[:, 1]), 0.35, 1.08)
    rng = np.random.default_rng(5)
    rumore = Image.fromarray((rng.normal(size=(LATO // 4, LATO // 4)) * 30 + 128).clip(0, 255).astype(np.uint8))
    rumore = np.asarray(rumore.resize((LATO, LATO), Image.BICUBIC), float) / 255 - 0.5

    def colore_punti(f, abc, L, yy, xx):
        abc = list(abc)
        p3, n3 = L @ pos[abc], L @ nor[abc]
        col = tinte[f](p3, n3)
        return col * (L @ ombra[abc] * (1 + 0.12 * rumore[yy, xx]))[:, None]
    img = _rasterizza(uv_px, tri, colore_punti, LATO)
    n = len(pos)
    ossa_v = np.zeros((n, 4), np.int64)
    ossa_v[:, 0] = ossa
    pesi = np.zeros((n, 4))
    pesi[:, 0] = 1
    return {"pos": pos, "uv": uv_px / LATO, "normali": nor, "ossa_v": ossa_v, "pesi": pesi, "triangoli": tri,
            "texture": Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)), "ossa": OSSA}


def main():
    costruisci_sherman()
    dati = cuoci()
    if "--prova" not in sys.argv:
        meshdati.scrivi("CarroArmato", dati, "Sherman con forme arrotondate")
    print("CarroArmato", len(dati["pos"]), "vertici", len(dati["triangoli"]), "triangoli")
    if "--glb" in sys.argv:
        cartella = sys.argv[sys.argv.index("--glb") + 1]
        meshdati.glb(dati, os.path.join(cartella, "CarroArmato.glb"))
        dati["texture"].save(os.path.join(cartella, "CarroArmato.png"))


if __name__ == "__main__":
    main()
