"""Fortezza del Novecento ("Bunker"): la casamatta di cemento che il nemico difende sul match point.

Riferimenti: le casematte di fanteria della linea Maginot (blocco di calcestruzzo mezzo interrato nel terrapieno,
facciata con la visiera sporgente sopra le feritoie a gradini, mitragliatrici binate, campane d'acciaio GFM e
d'osservazione sul tetto, rotaie anticarro piantate davanti, reticolati di filo spinato) e i fortini della
Grande Guerra con le postazioni di sacchetti di sabbia ai lati.
Pianta circa 10 × 9 m con il terrapieno: davanti verso -Y.
"""

import math

import bmesh
from mathutils import Vector

import fortezze as F
import vestiti as V

NOME = "FortezzaNovecento"
SIGLA = "FN"

X = 3.0                  # mezza larghezza della casamatta
Y0, Y1 = -2.4, 1.2       # facciata e retro
ALTO = 2.4
FERITOIE = (-1.45, 1.45)
Z_FERITOIA = 1.35
CAMPANA = Vector((1.5, -0.3, 2.95))
OSSERVA = Vector((-1.6, 0.2, 2.95))
TIRI = [(-1.45, -2.95, 1.35), (1.45, -2.95, 1.35), (1.5, -1.0, 3.5), (-3.9, -2.2, 1.0), (3.9, -2.2, 1.0)]

U = None


def materiali(u):
    F.materiale_tex(u, "Cemento", F.tex_cemento(SIGLA + "_Cemento", base=(0.46, 0.45, 0.41),
                                                mimetica=((0.30, 0.31, 0.19), (0.30, 0.23, 0.15))),
                    3.0)
    F.materiale_tex(u, "CementoLiscio", F.tex_cemento(SIGLA + "_CementoLiscio", base=(0.55, 0.54, 0.50), seme=14), 3.0)
    F.materiale_tex(u, "Terra", F.tex_terra(SIGLA + "_Terra", erba=(0.24, 0.29, 0.12), terra=(0.30, 0.23, 0.15),
                                            quanta=0.6), 3.0)
    F.materiale_tex(u, "Sacchetti", F.tex_sacchetti(SIGLA + "_Sacchetti"), 1.2)
    F.materiale_tex(u, "Casse", F.tex_assi(SIGLA + "_Casse", n=6, base=(0.38, 0.30, 0.17), seme=21, giunti=1), 1.0)
    u.materiale("Buio", (0.02, 0.02, 0.02), ruvidita=0.9)
    u.materiale("Acciaio", (0.17, 0.18, 0.17), metallo=1.0, ruvidita=0.55)
    u.materiale("Ruggine", (0.17, 0.10, 0.07), metallo=0.6, ruvidita=0.8)
    u.materiale("Canne", (0.07, 0.07, 0.07), metallo=1.0, ruvidita=0.4)
    u.materiale("Legno", (0.30, 0.21, 0.12), ruvidita=0.8)
    u.materiale("Filo", (0.30, 0.29, 0.27), metallo=1.0, ruvidita=0.6)
    u.materiale("Bandiera", (1.0, 1.0, 1.0), ruvidita=0.9, immagine=F.tex_drappo(SIGLA + "_Bandiera", emblema=None))


def liscio(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def terrapieno(u):
    """Il terrapieno erboso che copre i fianchi e il retro della casamatta e lascia libera la facciata."""
    x0, x1, y0, y1 = -5.8, 5.8, -3.4, 5.6
    nx, ny = 30, 24
    bm = bmesh.new()
    righe = []
    for j in range(ny + 1):
        y = y0 + (y1 - y0) * j / ny
        riga = []
        for i in range(nx + 1):
            x = x0 + (x1 - x0) * i / nx
            r = math.hypot(x / 5.4, (y - 1.0) / 4.3)
            h = 2.75 * max(0.0, 1 - r * r) ** 0.6
            h *= 0.25 + 0.75 * liscio(-2.9, -1.0, y) if abs(x) < X + 0.6 else 0.55 + 0.45 * liscio(-3.2, -1.0, y)
            h += 0.08 * math.sin(x * 2.1 + y * 1.3) * math.sin(y * 1.7)
            riga.append(bm.verts.new((x, y, h - 0.35)))
        righe.append(riga)
    for j in range(ny):
        for i in range(nx):
            bm.faces.new((righe[j][i], righe[j][i + 1], righe[j + 1][i + 1], righe[j + 1][i]))
    u.oggetto("Terrapieno", bm, "Terra")


def casamatta(u):
    corpo = F.scatola((0, (Y0 + Y1) / 2, (ALTO - 0.4) / 2), (2 * X, Y1 - Y0, ALTO + 0.4))
    bmesh.ops.bevel(corpo, geom=[e for e in corpo.edges], offset=0.12, segments=1, affect="EDGES", profile=0.5)
    # Visiera: la soletta del tetto sporge sopra la facciata.
    soletta = F.scatola((0, (Y0 - 0.45 + Y1 + 0.2) / 2, ALTO + 0.27), (2 * X + 0.5, Y1 - Y0 + 0.65, 0.55))
    bmesh.ops.bevel(soletta, geom=[e for e in soletta.edges], offset=0.08, segments=1, affect="EDGES", profile=0.5)
    u.oggetto("Casamatta", V.unisci(corpo, soletta), "Cemento", liscio=False)
    # Feritoie a gradini (contro i rimbalzi): due cornici sporgenti attorno al vano scuro.
    cornici, vani, canne, rotule = [], [], [], []
    for x in FERITOIE:
        c = Vector((x, Y0, Z_FERITOIA))
        for larga, alta, fuori in ((1.75, 1.05, 0.04), (1.42, 0.76, 0.09)):
            s = 0.13
            cornici += [F.scatola(c + Vector((0, -fuori / 2, alta / 2 - s / 2)), (larga, fuori + 0.02, s)),
                        F.scatola(c + Vector((0, -fuori / 2, -alta / 2 + s / 2)), (larga, fuori + 0.02, s)),
                        F.scatola(c + Vector((-larga / 2 + s / 2, -fuori / 2, 0)), (s, fuori + 0.02, alta)),
                        F.scatola(c + Vector((larga / 2 - s / 2, -fuori / 2, 0)), (s, fuori + 0.02, alta))]
        vani.append(F.scatola(c + Vector((0, -0.02, 0)), (1.18, 0.06, 0.52)))
        rotule.append(V.sfera(c + Vector((0, -0.06, 0)), (0.24, 0.1, 0.2), 10, 6))
        for dx in (-0.08, 0.08):
            canne.append(V.cilindro(c + Vector((dx, -0.1, 0.02)), c + Vector((dx, -0.75, 0.02)), 0.035, n=8))
            canne.append(V.cilindro(c + Vector((dx, -0.6, 0.02)), c + Vector((dx, -0.78, 0.02)), 0.05, n=8))
    u.oggetto("Feritoie_Cornici", V.unisci(*cornici), "CementoLiscio", liscio=False)
    u.oggetto("Feritoie_Vani", V.unisci(*vani), "Buio", liscio=False)
    u.oggetto("Feritoie_Rotule", V.unisci(*rotule), "Acciaio")
    u.oggetto("Feritoie_Canne", V.unisci(*canne), "Canne")
    # Scritta di casamatta: numeri dipinti no; un gradino di cemento sotto la facciata (fosso di scarico).
    u.oggetto("Casamatta_Zoccolo", F.prisma_lungo((-X - 0.2, Y0, 0), (X + 0.2, Y0, 0),
                                                 [(-0.45, -0.4), (0.0, 0.35), (0.05, 0.35), (0.05, -0.4)]),
              "CementoLiscio", liscio=False)


def campane(u):
    """Campana GFM (mitragliatrice e vedetta) e campana d'osservazione, d'acciaio su collari di cemento."""
    collari, cupole, fessure, extra = [], [], [], []
    for c, r, n_fessure in ((CAMPANA, 0.72, 5), (OSSERVA, 0.5, 3)):
        collari.append(F.cilindro_z(c, r + 0.28, 0.32, n=20, r_cima=r + 0.18))
        cupole.append(V.sfera(c + Vector((0, 0, 0.32)), (r, r, r * 0.85), 18, 10))
        for k in range(n_fessure):
            a = -math.pi / 2 + (k - (n_fessure - 1) / 2) * 0.62
            d = Vector((math.cos(a), math.sin(a), 0))
            p = c + Vector((0, 0, 0.32 + r * 0.42)) + d * (r * 0.9)
            fessure.append(F.scatola(p, (0.08, 0.26, 0.09), rot=math.degrees(a)))
    # Periscopio sulla campana d'osservazione e la canna che spunta dalla GFM.
    extra.append(V.cilindro(OSSERVA + Vector((0.12, 0.05, 0.6)), OSSERVA + Vector((0.12, 0.05, 1.15)), 0.05, n=8))
    extra.append(F.scatola(OSSERVA + Vector((0.12, 0.0, 1.17)), (0.12, 0.2, 0.1)))
    extra.append(V.cilindro(CAMPANA + Vector((0.0, -0.55, 0.62)), CAMPANA + Vector((0.0, -1.05, 0.6)), 0.035, n=8))
    u.oggetto("Campane_Collari", V.unisci(*collari), "CementoLiscio")
    u.oggetto("Campane", V.unisci(*cupole), "Acciaio")
    u.oggetto("Campane_Fessure", V.unisci(*fessure), "Buio", liscio=False)
    u.oggetto("Campane_Periscopio", V.unisci(*extra), "Canne")


def sacchetti(u):
    """Due postazioni di sacchetti di sabbia ai lati della facciata, a mezzaluna."""
    pezzi = []
    profilo = [(-0.3, -0.3), (0.3, -0.3), (0.24, 0.75), (0.0, 0.86), (-0.24, 0.75)]
    for s in (-1, 1):
        c = Vector((s * 3.9, -2.1, 0))
        punti = []
        for k in range(6):
            a = math.radians(-160 + 140 * k / 5) if s > 0 else math.radians(-20 - 140 * k / 5)
            punti.append(c + Vector((math.cos(a), math.sin(a), 0)) * 1.25)
        for a, b in zip(punti, punti[1:]):
            pezzi.append(F.prisma_lungo(a, b, profilo))
    u.oggetto("Sacchetti", V.unisci(*pezzi), "Sacchetti", liscio=False)
    # Casse di munizioni dentro le postazioni.
    casse = [F.scatola((3.9, -1.75, 0.2), (0.7, 0.4, 0.4), rot=12), F.scatola((-4.0, -1.8, 0.2), (0.7, 0.4, 0.4), rot=-8),
             F.scatola((-3.75, -1.6, 0.55), (0.6, 0.35, 0.3), rot=20)]
    u.oggetto("Casse", V.unisci(*casse), "Casse", liscio=False)


def ostacoli(u):
    """Rotaie anticarro piantate in fila davanti e un reticolato su cavalli di frisia."""
    rotaie = []
    for i in range(10):
        x = -3.9 + 0.87 * i
        y = -5.0 + 0.25 * ((i * 3) % 2)
        base = Vector((x, y, -0.3))
        cima = base + Vector((0.05 * ((i % 3) - 1), -0.45, 1.55))
        d = (cima - base).normalized()
        lato = Vector((1, 0, 0))
        n = d.cross(lato).normalized()
        # Rotaia a doppia T: anima e due ali.
        rotaie.append(V.cilindro(base, cima, 0.035, n=4))
        rotaie.append(V.cilindro(base + n * 0.07, cima + n * 0.07, 0.05, 0.05, n=4))
        rotaie.append(V.cilindro(base - n * 0.07, cima - n * 0.07, 0.05, 0.05, n=4))
    u.oggetto("Rotaie", V.unisci(*rotaie), "Ruggine", liscio=False)
    pali, fili = [], []
    xs = [-4.4, -2.6, -0.8, 0.8, 2.6, 4.4]
    for x in xs:
        for s in (-1, 1):
            pali.append(V.cilindro((x - 0.4 * s, -3.75, -0.1), (x + 0.4 * s, -3.75, 1.15), 0.045, n=5))
    for a, b in zip(xs, xs[1:]):
        for z, dy in ((0.35, 0.0), (0.7, 0.05), (1.0, -0.04)):
            mezzo = Vector(((a + b) / 2, -3.75 + dy, z - 0.12))
            fili.append(V.tubo_lungo([Vector((a, -3.75, z)), mezzo, Vector((b, -3.75, z))], 0.016, n=4, tappi=False))
    u.oggetto("Reticolato_Pali", V.unisci(*pali), "Legno")
    u.oggetto("Reticolato_Fili", V.unisci(*fili), "Filo")


def bandiera(u):
    p = Vector((0.6, 2.0, 2.3))
    u.oggetto("Bandiera_Asta", V.cilindro(p, p + Vector((0, 0, 2.6)), 0.04, n=8), "Legno")
    u.oggetto("Bandiera_Drappo", F.drappo(p + Vector((0.04, 0, 2.55)), 1.3, 0.85, (1, 0.3, 0), onde=0.08), "Bandiera",
              spessore=0.01)


def costruisci():
    global U
    u = V.Unita(NOME, SIGLA)
    U = u
    materiali(u)
    terrapieno(u)
    casamatta(u)
    campane(u)
    sacchetti(u)
    ostacoli(u)
    bandiera(u)
    return F.conta(u)


def esporta(triangoli=6500, lato=1024):
    return F.esporta(NOME, TIRI, triangoli, quote={"Terrapieno*": 900, "Reticolato_Fili*": 120, "Rotaie*": 360,
                                                     "Feritoie_Canne*": 160, "Bandiera_Drappo*": 40,
                                                     "Campane_Periscopio*": 60}, lato=lato)
