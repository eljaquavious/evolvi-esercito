"""Carro armato M4 Sherman (1944): la carta "CarroArmato" del Novecento.

Riferimenti: M4A2/M4A3 a scafo saldato con il cannone da 75 mm, come quelli della 2e Division blindée di
Leclerc che entrò a Parigi nell'agosto 1944. Scafo con lo spalto inclinato e il muso arrotondato (la scatola
del differenziale), fiancate dritte sopra i cingoli, torretta fusa tonda con la culla del cannone davanti e
il "bustle" dietro, tre carrelli VVSS per lato (due ruote ciascuno e il rullo sopra), ruota motrice davanti,
ruota tenditrice dietro; mitragliatrice in casamatta sullo spalto e la .50 sul tetto della torretta, portelli,
fari con le protezioni, stella bianca dell'Alleanza sui fianchi e sulla torretta, verde oliva.

Nel gioco: ossa "bacino" (scafo), "torretta" (gira), "cannone" (alza e rincula) e "canna" (bocca del cannone).
Le misure sono quelle vere (5,9 m di lunghezza); il gioco lo scala con TIPI.CarroArmato.metri.
"""

import math

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

import vestiti as V

NOME = "CarroArmato"
SIGLA = "SH"

CENTRO_TORRETTA = Vector((0.0, -0.15, 1.88))
ORECCHIONI = Vector((0.0, -1.02, 2.28))          # perno del cannone (davanti alla torretta)
CANNA = 2.55

U = None
BOCCA = None


def materiali(u):
    u.materiale("Oliva", (0.17, 0.18, 0.09), ruvidita=0.75)
    u.materiale("OlivaScuro", (0.11, 0.12, 0.06), ruvidita=0.75)
    u.materiale("Cingolo", (0.08, 0.075, 0.07), metallo=0.6, ruvidita=0.6)
    u.materiale("Gomma", (0.04, 0.04, 0.04), ruvidita=0.8)
    u.materiale("Acciaio", (0.20, 0.20, 0.21), metallo=1.0, ruvidita=0.45)
    u.materiale("Bianco", (0.80, 0.80, 0.76), ruvidita=0.7)
    u.materiale("Vetro", (0.55, 0.60, 0.55), metallo=0.5, ruvidita=0.2)
    u.materiale("Tela", (0.32, 0.29, 0.18), ruvidita=0.9)
    u.materiale("Legno", (0.38, 0.24, 0.12), ruvidita=0.7)


def prisma(profilo, x0, x1, smusso=0.0):
    """Profilo (y, z) chiuso estruso tra x0 e x1."""
    bm = bmesh.new()
    a = [bm.verts.new((x0, y, z)) for y, z in profilo]
    b = [bm.verts.new((x1, y, z)) for y, z in profilo]
    bm.faces.new(a[::-1])
    bm.faces.new(b)
    n = len(profilo)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if smusso:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=smusso, segments=2, affect="EDGES", profile=0.5)
    return bm


def ruota_x(centro, raggio, larghezza, n=20):
    """Ruota con l'asse lungo X."""
    c = Vector(centro)
    return V.cilindro(c - Vector((larghezza / 2, 0, 0)), c + Vector((larghezza / 2, 0, 0)), raggio, n=n)


# Scafo ---------------------------------------------------------------------------------------------

def scafo(u):
    # Parte bassa tra i cingoli, con il muso tondo del differenziale.
    muso = [(-2.70 + 0.28 * (1 - math.cos(a)), 0.80 + 0.30 * math.sin(a)) for a in np.linspace(-math.pi / 2, math.pi / 2, 7)]
    basso = [(-2.42, 0.50)] + muso[1:] + [(-2.62, 1.18), (2.70, 1.18), (2.78, 0.80), (2.55, 0.52)]
    u.oggetto("Scafo_Basso", prisma(basso, -0.88, 0.88, 0.03), "Oliva", liscio=False)
    # Parte alta larga quanto il carro: spalto inclinato, ponte motore, piastra dietro.
    alto = [(-2.66, 1.12), (-1.62, 1.86), (2.30, 1.86), (2.80, 1.66), (2.80, 1.12)]
    u.oggetto("Scafo_Alto", prisma(alto, -1.31, 1.31, 0.035), "Oliva", liscio=False)
    # Griglie del motore e portelli sul ponte posteriore.
    griglie = [V.scatola((0, 1.6 + 0.12 * k, 1.875), (1.5, 0.05, 0.02)) for k in range(6)]
    u.oggetto("Scafo_Griglie", V.unisci(*griglie), "OlivaScuro", liscio=False)
    # Portelli del pilota e del mitragliere sullo spalto, con i periscopi.
    portelli = []
    for x in (-0.48, 0.48):
        portelli.append(V.cilindro((x, -1.45, 1.86), (x, -1.45, 1.91), 0.30, n=20))
        portelli.append(V.scatola((x, -1.70, 1.93), (0.16, 0.06, 0.07)))
    u.oggetto("Scafo_Portelli", V.unisci(*portelli), "Oliva")
    # Mitragliatrice di prua in casamatta (a destra) e fari con le protezioni.
    spalto = Vector((0, -0.95, 0.74)).normalized()   # direzione in salita lungo lo spalto
    perno = Vector((-0.55, -2.25, 1.43))
    u.oggetto("Scafo_Casamatta", V.sfera(perno, (0.16, 0.12, 0.16), 14, 8), "Oliva")
    u.oggetto("Scafo_Mitragliatrice", V.cilindro(perno, perno + Vector((0, -0.55, -0.12)), 0.025, n=8), "Acciaio")
    fari = []
    for x in (-1.0, 1.0):
        p = Vector((x, -2.62, 1.22))
        fari.append(V.cilindro(p, p + Vector((0, -0.10, 0)), 0.08, n=12))
        fari.append(V.tubo_lungo([p + Vector((-0.12, 0.05, -0.02)), p + Vector((-0.12, -0.16, 0.06)),
                                  p + Vector((0.12, -0.16, 0.06)), p + Vector((0.12, 0.05, -0.02))], 0.012, n=6))
    u.oggetto("Scafo_Fari", V.unisci(*fari), "Acciaio")
    # Ganci di traino davanti e attrezzi sul fianco (badile e piccone).
    ganci = [V.tubo_lungo([(x, -2.78, 0.90), (x, -2.95, 0.90), (x, -2.95, 0.72), (x, -2.80, 0.72)], 0.03, n=6)
             for x in (-0.55, 0.55)]
    u.oggetto("Scafo_Ganci", V.unisci(*ganci), "Acciaio")
    attrezzi = [V.cilindro((1.33, 0.3, 1.55), (1.33, 1.5, 1.55), 0.025, n=6),
                V.cilindro((1.33, -0.6, 1.40), (1.33, 0.4, 1.40), 0.025, n=6)]
    u.oggetto("Scafo_Attrezzi", V.unisci(*attrezzi), "Legno")
    # Taniche e telo arrotolato dietro.
    u.oggetto("Scafo_Telo", V.cilindro((-0.9, 2.86, 1.55), (0.9, 2.86, 1.55), 0.14, n=12), "Tela")


# Cingoli e carrelli ------------------------------------------------------------------------------------

def _giro_cingolo():
    """Percorso del cingolo (y, z) attorno alla ruota motrice davanti, alla tenditrice dietro e sopra i rulli."""
    motrice, rm = (-2.55, 0.80), 0.36
    tenditrice, rt = (2.62, 0.52), 0.30
    punti = []
    # Sotto, da dietro a davanti, a terra.
    for y in np.linspace(2.30, -2.10, 22):
        punti.append((y, 0.04))
    # Risalita davanti attorno alla motrice.
    for a in np.linspace(-math.pi * 0.62, -math.pi * 1.5, 10):
        punti.append((motrice[0] + rm * math.cos(a), motrice[1] - rm * math.sin(a)))
    # Ritorno sopra i rulli, un poco cadente.
    for y in np.linspace(-2.45, 2.40, 22):
        t = (y + 2.45) / 4.85
        punti.append((y, 1.16 - 0.05 * math.sin(math.pi * t * 3) ** 2))
    # Giù dietro attorno alla tenditrice.
    for a in np.linspace(math.pi / 2, -math.pi * 0.35, 8):
        punti.append((tenditrice[0] + rt * math.cos(a), tenditrice[1] + rt * math.sin(a)))
    return punti


def cingoli(u):
    percorso = _giro_cingolo()
    n = len(percorso)
    centro = Vector((0, 0.1, 0.6))
    nastri, ruote, gomme, rulli = [], [], [], []
    for x in (-1.10, 1.10):
        bm = bmesh.new()
        anelli = []
        for i, (y, z) in enumerate(percorso):
            p = Vector((0, y, z))
            q = Vector((0, *percorso[(i + 1) % n]))
            r = Vector((0, *percorso[i - 1]))
            tangente = (q - r).normalized()
            fuori = Vector((0, -tangente.z, tangente.y))
            if fuori.dot(p - centro) < 0:
                fuori = -fuori
            spesso = 0.07 + (0.03 if i % 2 == 0 else 0.0)        # costole (ramponi) alternate
            anelli.append([bm.verts.new((x + dx, *(p + fuori * dz).yz)) for dx, dz in
                           ((-0.21, 0.0), (0.21, 0.0), (0.21, spesso), (-0.21, spesso))])
        for i in range(n):
            a, b = anelli[i], anelli[(i + 1) % n]
            for k in range(4):
                bm.faces.new((a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        nastri.append(bm)
        # Ruota motrice dentata e tenditrice.
        ruote.append(ruota_x((x, -2.55, 0.80), 0.30, 0.36, 18))
        for k in range(13):
            a = 2 * math.pi * k / 13
            ruote.append(V.scatola((x, -2.55 + 0.33 * math.cos(a), 0.80 + 0.33 * math.sin(a)), (0.30, 0.06, 0.06)))
        ruote.append(ruota_x((x, 2.62, 0.52), 0.25, 0.34, 18))
        # Tre carrelli VVSS: staffa, due ruote gommate, rullo di ritorno sopra.
        for y in (-1.45, 0.05, 1.55):
            ruote.append(V.scatola((x, y, 0.55), (0.22, 0.55, 0.32)))
            ruote.append(V.scatola((x, y + 0.05, 0.85), (0.16, 0.18, 0.35)))
            for dy in (-0.32, 0.32):
                gomme.append(ruota_x((x, y + dy, 0.30), 0.26, 0.30, 20))
                ruote.append(ruota_x((x * 1.0 + (0.16 if x > 0 else -0.16), y + dy, 0.30), 0.12, 0.03, 12))
            rulli.append(ruota_x((x, y + 0.12, 1.06), 0.09, 0.24, 12))
    u.oggetto("Cingoli", V.unisci(*nastri), "Cingolo", liscio=False)
    u.oggetto("Ruote_Ferro", V.unisci(*ruote, *rulli), "Acciaio", liscio=False)
    u.oggetto("Ruote_Gomma", V.unisci(*gomme), "Gomma")


# Torretta e cannone ----------------------------------------------------------------------------------

def torretta(u):
    """Torretta fusa: anelli sempre più stretti verso l'alto, allungata dietro (bustle), piatta davanti."""
    c = CENTRO_TORRETTA
    anelli = []
    n = 40
    for h, scala in ((0.0, 1.0), (0.10, 1.02), (0.25, 1.0), (0.42, 0.95), (0.55, 0.86), (0.62, 0.70), (0.66, 0.4)):
        anello = []
        for j in range(n):
            a = 2 * math.pi * j / n
            dx, dy = math.cos(a), math.sin(a)
            r = 0.92
            if dy > 0:               # dietro: il bustle si allunga
                r = 0.92 + 0.32 * dy ** 2
            else:                    # davanti: un poco schiacciata
                r = 0.92 - 0.12 * dy ** 2
            anello.append(Vector((c.x + dx * r * scala, c.y + dy * r * scala, c.z + h)))
        anelli.append(anello)
    bm = V.griglia(anelli, chiusa=True)
    bm.verts.ensure_lookup_table()
    bm.faces.new([bm.verts[len(bm.verts) - n + j] for j in range(n)])
    bm.faces.new([bm.verts[j] for j in range(n)][::-1])
    V._verso_fuori(bm)
    u.oggetto("Torretta_Fusa", bm, "Oliva")
    # Botole del capocarro e del servente, cupola, periscopi.
    pezzi = [V.cilindro((0.38, 0.25, c.z + 0.64), (0.38, 0.25, c.z + 0.70), 0.26, n=20),
             V.cilindro((-0.36, 0.05, c.z + 0.64), (-0.36, 0.05, c.z + 0.69), 0.22, n=20),
             V.scatola((0.10, -0.45, c.z + 0.66), (0.10, 0.08, 0.10))]
    u.oggetto("Torretta_Botole", V.unisci(*pezzi), "Oliva")
    # Mitragliatrice .50 sul tetto, dietro la botola.
    mg = [V.cilindro((0.55, 0.62, c.z + 0.70), (0.55, 0.62, c.z + 0.98), 0.025, n=8),
          V.scatola((0.55, 0.55, c.z + 1.0), (0.10, 0.30, 0.12)),
          V.cilindro((0.55, 0.40, c.z + 1.01), (0.55, -0.55, c.z + 1.01), 0.022, n=8)]
    u.oggetto("Torretta_MG", V.unisci(*mg), "Acciaio")
    # Antenna dietro.
    u.oggetto("Torretta_Antenna", V.cilindro((-0.55, 0.95, c.z + 0.6), (-0.55, 0.95, c.z + 2.0), 0.008, n=6), "Acciaio")


def cannone(u):
    o = ORECCHIONI
    # Culla (mantelletto) arrotondata davanti alla torretta.
    culla = V.scatola(o + Vector((0, -0.06, 0)), (0.78, 0.22, 0.40))
    bmesh.ops.bevel(culla, geom=culla.edges[:], offset=0.06, segments=3, affect="EDGES", profile=0.5)
    pezzi = [culla, V.cilindro(o + Vector((0, -0.10, 0)), o + Vector((0, -0.42, 0)), 0.11, 0.09, n=16),
             V.cilindro(o + Vector((0, -0.40, 0)), o + Vector((0, -CANNA, 0)), 0.065, 0.06, n=16),
             V.cilindro(o + Vector((0, -CANNA + 0.15, 0)), o + Vector((0, -CANNA - 0.02, 0)), 0.075, n=16),
             V.cilindro(o + Vector((0.24, -0.15, 0.04)), o + Vector((0.24, -0.38, 0.04)), 0.03, n=8)]
    u.oggetto("Cannone", V.unisci(*pezzi), "Oliva")
    return o + Vector((0, -CANNA - 0.02, 0))


# Insegne ---------------------------------------------------------------------------------------------

def stella(centro, normale, raggio, su=Vector((0, 0, 1))):
    """Stella bianca a cinque punte dentro un cerchio (piatta, appena fuori dalla superficie)."""
    normale = Vector(normale).normalized()
    x = su.cross(normale).normalized()
    y = normale.cross(x)
    bm = bmesh.new()
    c = Vector(centro) + normale * 0.006
    punte = []
    for k in range(10):
        a = math.pi / 2 + k * math.pi / 5
        r = raggio * (0.78 if k % 2 == 0 else 0.30)
        punte.append(bm.verts.new(c + (x * math.cos(a) + y * math.sin(a)) * r))
    mezzo = bm.verts.new(c)
    for k in range(10):
        bm.faces.new((mezzo, punte[k], punte[(k + 1) % 10]))
    # Cerchio attorno.
    dentro = [bm.verts.new(c + (x * math.cos(2 * math.pi * k / 40) + y * math.sin(2 * math.pi * k / 40)) * raggio * 0.90)
              for k in range(40)]
    fuori = [bm.verts.new(c + (x * math.cos(2 * math.pi * k / 40) + y * math.sin(2 * math.pi * k / 40)) * raggio)
             for k in range(40)]
    for k in range(40):
        bm.faces.new((dentro[k], dentro[(k + 1) % 40], fuori[(k + 1) % 40], fuori[k]))
    for f in bm.faces:
        if f.normal.dot(normale) < 0:
            f.normal_flip()
    return bm


def insegne(u):
    pezzi = [stella((s * 1.315, 0.45, 1.50), (s, 0, 0), 0.32) for s in (1, -1)]
    pezzi.append(stella((0, 2.82, 1.40), (0, 1, 0), 0.24))
    u.oggetto("Insegne_Scafo", V.unisci(*pezzi), "Bianco", liscio=False)
    c = CENTRO_TORRETTA
    torretta = [stella((s * 0.94, c.y + 0.15, c.z + 0.30), (s, 0.1, 0), 0.20) for s in (1, -1)]
    u.oggetto("Torretta_Insegne", V.unisci(*torretta), "Bianco", liscio=False)


# Tutto ---------------------------------------------------------------------------------------------

def costruisci():
    global U, BOCCA
    u = V.Unita(NOME, SIGLA)
    U = u
    materiali(u)
    scafo(u)
    cingoli(u)
    torretta(u)
    BOCCA = cannone(u)
    insegne(u)
    triangoli = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in u.col.objects if o.type == "MESH")
    return {"oggetti": len(u.col.objects), "triangoli": triangoli}


def esporta(triangoli=5200, lato=512):
    import esporta as E
    r = E.prepara(NOME, {"bacino": ((0, 0, 1.0), (0, 0, 1.2))},
                  rigidi={"Cannone*": "cannone", "Torretta_*": "torretta", "*": "bacino"},
                  quote={"Cingoli*": 1200, "Ruote_Ferro*": 900, "Ruote_Gomma*": 600, "Torretta_Fusa*": 500,
                         "Cannone*": 300, "Insegne*": 200, "Torretta_Insegne*": 120},
                  triangoli=triangoli, corpo="(nessuno)", umano=False,
                  extra={"torretta": ("bacino", CENTRO_TORRETTA), "cannone": ("torretta", ORECCHIONI),
                         "canna": ("cannone", BOCCA)})
    E.cuoci(lato=lato)
    return r
