"""Fortezza del Medioevo ("Castle"): il castello che il nemico difende sul match point.

Riferimenti: i castelli francesi della Guerra dei Cent'anni (Vincennes, Chinon, Tarascon, Pierrefonds): cortine
di pietra squadrata con la scarpa alla base, torri tonde agli angoli con il ballatoio dei piombatoi e il tetto
conico d'ardesia, il castelletto della porta con l'arco acuto, la saracinesca e il ponte levatoio abbassato,
il mastio quadrato con i contrafforti, le finestre a croce, i piombatoi in cima e la torretta di guardia;
stendardi rossi appesi ai merli.
Pianta circa 9 × 9 m: davanti verso -Y.
"""

import math

import bmesh
from mathutils import Vector

import fortezze as F
import vestiti as V

NOME = "FortezzaMedievale"
SIGLA = "FM"

L = 3.2             # linea mediana delle cortine
RT = 1.1            # raggio delle torri d'angolo
ALTO_MURA = 4.0
ALTO_TORRI = 5.4
MASTIO = Vector((0.0, 0.7, 0.0))
LATO_MASTIO = 3.0
ALTO_MASTIO = 8.2
TIRI = [(-L, -L, 5.9), (L, -L, 5.9), (-L, L, 5.9), (L, L, 5.9), (0.0, -L - 0.9, 6.3), (0.0, 0.7, 8.9)]

U = None


def materiali(u):
    F.materiale_tex(u, "Pietra", F.tex_pietra(SIGLA + "_Pietra", base=(0.60, 0.56, 0.48), righe=8), 2.0)
    F.materiale_tex(u, "PietraScura", F.tex_pietra(SIGLA + "_PietraScura", base=(0.46, 0.43, 0.38),
                                                   malta=(0.32, 0.30, 0.27), righe=6, seme=11), 2.0)
    F.materiale_tex(u, "Ardesia", F.tex_ardesia(SIGLA + "_Ardesia"), 1.6)
    F.materiale_tex(u, "Assi", F.tex_assi(SIGLA + "_Assi", n=8, base=(0.36, 0.25, 0.15)), 1.6)
    u.materiale("Buio", (0.025, 0.02, 0.02), ruvidita=0.9)
    u.materiale("Ferro", (0.13, 0.13, 0.14), metallo=1.0, ruvidita=0.5)
    u.materiale("Piombo", (0.45, 0.46, 0.48), metallo=1.0, ruvidita=0.4)
    u.materiale("Oro", (0.80, 0.60, 0.22), metallo=1.0, ruvidita=0.35)
    u.materiale("Legno", (0.30, 0.20, 0.12), ruvidita=0.7)
    u.materiale("Stendardo", (1.0, 1.0, 1.0), ruvidita=0.9, immagine=F.tex_drappo(SIGLA + "_Stendardo"))


# Cortine -------------------------------------------------------------------------------------------

def cortine(u):
    """Quattro cortine con la scarpa; davanti, sotto i merli, il ballatoio dei piombatoi su beccatelli."""
    profilo = [(-0.8, -0.5), (-0.45, 0.9), (-0.45, ALTO_MURA), (0.45, ALTO_MURA), (0.45, -0.5)]
    # In senso antiorario: il laterale negativo è fuori.
    lati = [((-L, -L), (L, -L)), ((L, -L), (L, L)), ((L, L), (-L, L)), ((-L, L), (-L, -L))]
    muri, merlature, mensole = [], [], []
    for k, (a, b) in enumerate(lati):
        a, b = Vector((*a, 0)), Vector((*b, 0))
        muri.append(F.prisma_lungo(a, b, profilo))
        davanti = k == 0
        fuori = -0.62 if davanti else -0.3
        merlature += F.merli(a, b, ALTO_MURA + (0.3 if davanti else 0.0), 0.75, 0.3, largo=0.55, passo=0.95, fuori=fuori)
        if davanti:
            # Ballatoio sporgente (piano dei piombatoi) e i beccatelli sotto.
            muri.append(F.prisma_lungo(a, b, [(-0.8, ALTO_MURA - 0.05), (-0.3, ALTO_MURA - 0.05),
                                              (-0.3, ALTO_MURA + 0.3), (-0.8, ALTO_MURA + 0.3)]))
            d = (b - a).normalized()
            mensole += F.lungo(a, b, 0.45, lambda p, d: F.scatola(p + Vector((0, -0.6, ALTO_MURA - 0.3)), (0.16, 0.42, 0.5)))
    u.oggetto("Cortine", V.unisci(*muri), "Pietra", liscio=False)
    u.oggetto("Cortine_Merli", V.unisci(*merlature), "Pietra", liscio=False)
    u.oggetto("Cortine_Beccatelli", V.unisci(*mensole), "PietraScura", liscio=False)
    # Feritoie a croce sulle cortine di lato e dietro.
    fori = []
    for x in (-1.2, 1.2):
        for y, verso in ((L, 1),):
            fori += feritoia(Vector((x, y + verso * 0.46, 2.2)), (0, verso))
    for y in (-1.2, 1.2):
        for x, verso in ((-L, -1), (L, 1)):
            fori += feritoia(Vector((x + verso * 0.46, y, 2.2)), (verso, 0))
    u.oggetto("Cortine_Feritoie", V.unisci(*fori), "Buio", liscio=False)


def feritoia(c, verso):
    """Arciera a croce: una fessura alta e la traversa, scure, appena fuori dal muro."""
    vx, vy = verso
    sx = 0.06 if vx else 0.1
    sy = 0.1 if vx else 0.06
    lx = 0.06 if vx else 0.36
    ly = 0.36 if vx else 0.06
    return [F.scatola(c, (sx, sy, 0.95)), F.scatola(c + Vector((0, 0, 0.12)), (lx, ly, 0.08))]


# Torri ---------------------------------------------------------------------------------------------

def torri(u):
    fusti, scuri, ballatoi, mensole, tetti, cime, fori = [], [], [], [], [], [], []
    for sx in (-1, 1):
        for sy in (-1, 1):
            c = Vector((sx * L, sy * L, 0))
            fusti.append(F.cono(c + Vector((0, 0, -0.5)), RT + 0.35, 1.6, n=20, r_cima=RT))      # scarpa
            fusti.append(F.cilindro_z(c + Vector((0, 0, 1.0)), RT, ALTO_TORRI - 1.0, n=20))
            ballatoi.append(F.cilindro_z(c + Vector((0, 0, ALTO_TORRI)), RT + 0.25, 0.75, n=20))
            mensole += F.mensole_anello(c, RT, ALTO_TORRI - 0.4, 14, alto=0.42, fuori=0.27)
            tetti.append(F.cono(c + Vector((0, 0, ALTO_TORRI + 0.72)), RT + 0.42, 3.0, n=20))
            cime.append(V.cilindro(c + Vector((0, 0, ALTO_TORRI + 3.6)), c + Vector((0, 0, ALTO_TORRI + 4.4)), 0.03, n=6))
            cime.append(V.sfera(c + Vector((0, 0, ALTO_TORRI + 3.75)), (0.08, 0.08, 0.1), 8, 6))
            # Finestrelle del ballatoio e arciere sul fusto, verso fuori.
            for a in (-40, 0, 40, 90 if sy > 0 else -90):
                ang = math.atan2(sy, sx) + math.radians(a)
                d = Vector((math.cos(ang), math.sin(ang), 0))
                p = c + d * (RT + 0.24) + Vector((0, 0, ALTO_TORRI + 0.4))
                scuri.append(F.scatola(p, (0.06, 0.3, 0.4), rot=math.degrees(ang)))
            for a, z in ((0, 2.2), (35, 3.9), (-35, 3.9)):
                ang = math.atan2(sy, sx) + math.radians(a)
                d = Vector((math.cos(ang), math.sin(ang), 0))
                p = c + d * (RT - 0.01) + Vector((0, 0, z))
                fori.append(F.scatola(p, (0.06, 0.09, 0.85), rot=math.degrees(ang)))
                fori.append(F.scatola(p + Vector((0, 0, 0.12)), (0.06, 0.32, 0.07), rot=math.degrees(ang)))
    u.oggetto("Torri", V.unisci(*fusti), "Pietra")
    u.oggetto("Torri_Ballatoi", V.unisci(*ballatoi), "Pietra")
    u.oggetto("Torri_Beccatelli", V.unisci(*mensole), "PietraScura", liscio=False)
    u.oggetto("Torri_Tetti", V.unisci(*tetti), "Ardesia")
    u.oggetto("Torri_Cime", V.unisci(*cime), "Piombo")
    u.oggetto("Torri_Finestre", V.unisci(*scuri + fori), "Buio", liscio=False)


# Porta ---------------------------------------------------------------------------------------------

def arco_acuto(larghezza, imposta, freccia, n=6):
    """Profilo (x, z) di un arco acuto chiuso in basso: piedritti fino a "imposta", punta a imposta+freccia."""
    m = larghezza / 2
    r = (m * m + freccia * freccia) / (2 * m)          # raggio degli archi che si incontrano in punta
    punti = [(-m, 0.0), (-m, imposta)]
    for i in range(1, n):
        t = i / n
        # Arco di sinistra: centro in (r - m, imposta), da (-m, imposta) alla punta (0, imposta + freccia).
        cx = r - m
        a0 = math.pi
        a1 = math.atan2(freccia, -cx)
        a = a0 + (a1 - a0) * t
        punti.append((cx + r * math.cos(a), imposta + r * math.sin(a)))
    punti.append((0.0, imposta + freccia))
    destra = [(-x, z) for x, z in reversed(punti[1:-1])]
    return punti + destra + [(m, 0.0)]


def lastra_profilo(profilo, y0, y1, x0=0.0):
    """Profilo (x, z) estruso lungo y tra y0 e y1."""
    bm = bmesh.new()
    A = [bm.verts.new((x0 + x, y0, z)) for x, z in profilo]
    B = [bm.verts.new((x0 + x, y1, z)) for x, z in profilo]
    bm.faces.new(A[::-1])
    bm.faces.new(B)
    n = len(profilo)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((A[i], A[j], B[j], B[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def porta(u):
    """Castelletto della porta sporgente, arco acuto con la saracinesca, piombatoi, merli e ponte levatoio."""
    y0, y1 = -L - 1.55, -L + 0.2          # davanti e dietro del castelletto
    alto = 5.6
    pietra = [F.scatola((0, (y0 + y1) / 2, (alto - 0.5) / 2), (2.9, y1 - y0, alto + 0.5)),
              F.prisma_lungo((-1.45, y0, 0), (1.45, y0, 0), [(-0.35, -0.5), (0.0, 0.9), (0.1, 0.9), (0.1, -0.5)]),
              # ballatoio dei piombatoi sui tre lati di fuori
              F.scatola((0, y0 - 0.15, alto + 0.15), (3.3, 0.5, 0.3))]
    merli = []
    merli += F.merli(Vector((-1.6, y0 - 0.3, 0)), Vector((1.6, y0 - 0.3, 0)), alto + 0.3, 0.75, 0.3, passo=0.95)
    merli += F.merli(Vector((-1.45, y1, 0)), Vector((-1.45, y0, 0)), alto, 0.75, 0.3, passo=0.95, fuori=-0.15)
    merli += F.merli(Vector((1.45, y0, 0)), Vector((1.45, y1, 0)), alto, 0.75, 0.3, passo=0.95, fuori=-0.15)
    mensole = F.lungo(Vector((-1.5, y0, 0)), Vector((1.5, y0, 0)), 0.42,
                      lambda p, d: F.scatola(p + Vector((0, -0.2, alto - 0.3)), (0.16, 0.4, 0.5)))
    u.oggetto("Porta", V.unisci(*pietra), "Pietra", liscio=False)
    u.oggetto("Porta_Merli", V.unisci(*merli), "Pietra", liscio=False)
    u.oggetto("Porta_Beccatelli", V.unisci(*mensole), "PietraScura", liscio=False)
    # L'arco: il vano scuro, la ghiera di conci attorno e la saracinesca di ferro.
    vano = arco_acuto(1.5, 1.9, 1.0)
    ghiera = [(x * 1.28, z * 1.12) for x, z in vano]
    u.oggetto("Porta_Vano", lastra_profilo(vano, y0 - 0.08, y0 + 0.6), "Buio", liscio=False)
    u.oggetto("Porta_Ghiera", lastra_profilo(ghiera, y0 - 0.05, y0 + 0.02), "PietraScura", liscio=False)
    sbarre = []
    for i in range(7):
        x = -0.6 + 0.2 * i
        cima = 1.9 + 1.0 * (1 - (abs(x) / 0.75) ** 1.6) - 0.08
        sbarre.append(F.scatola((x, y0 - 0.11, cima / 2), (0.05, 0.05, cima)))
        sbarre.append(F.cono((x, y0 - 0.11, -0.12), 0.04, 0.14, n=4))
    for z in (0.5, 1.0, 1.5, 2.0, 2.4):
        larga = 1.4 if z < 1.95 else 1.4 * (1 - ((z - 1.9) / 1.0) ** 0.9 * 0.7)
        sbarre.append(F.scatola((0, y0 - 0.11, z), (larga, 0.05, 0.05)))
    u.oggetto("Porta_Saracinesca", V.unisci(*sbarre), "Ferro", liscio=False)
    # Ponte levatoio abbassato, con le catene che salgono alle fessure dei bolzoni.
    lungo = 2.2
    ponte = F.prisma_lungo((0, y0 - 0.05, 0), (0, y0 - lungo, 0), [(-0.78, 0.18), (0.78, 0.18), (0.78, 0.32), (-0.78, 0.32)])
    for v in ponte.verts:
        t = (y0 - 0.05 - v.co.y) / (lungo - 0.05)
        v.co.z -= 0.22 * t
    u.oggetto("Porta_Ponte", ponte, "Assi", liscio=False)
    catene, bolzoni = [], []
    for sx in (-1, 1):
        catene.append(V.cilindro((sx * 0.72, y0 - lungo + 0.12, 0.12), (sx * 0.9, y0 - 0.08, 3.4), 0.025, n=5))
        bolzoni.append(F.scatola((sx * 0.9, y0 - 0.02, 3.6), (0.12, 0.06, 1.3)))
    u.oggetto("Porta_Catene", V.unisci(*catene), "Ferro")
    u.oggetto("Porta_Bolzoni", V.unisci(*bolzoni), "Buio", liscio=False)


# Mastio --------------------------------------------------------------------------------------------

def mastio(u):
    c = MASTIO
    m = LATO_MASTIO / 2
    pietra = [F.scatola(c + Vector((0, 0, (ALTO_MASTIO - 0.3) / 2)), (LATO_MASTIO, LATO_MASTIO, ALTO_MASTIO + 0.3))]
    # Contrafforti d'angolo che si rastremano verso l'alto.
    for sx in (-1, 1):
        for sy in (-1, 1):
            for dx, dy in ((0.25 * sx, 0.0), (0.0, 0.25 * sy)):
                p = c + Vector((sx * (m - 0.2) + dx, sy * (m - 0.2) + dy, 0))
                pietra.append(F.scatola(p + Vector((0, 0, 3.0)), (0.55, 0.55, 6.3)))
    # Ballatoio sporgente in cima, beccatelli, merli; torretta di guardia sull'angolo davanti a destra.
    pietra.append(F.scatola(c + Vector((0, 0, ALTO_MASTIO + 0.15)), (LATO_MASTIO + 0.5, LATO_MASTIO + 0.5, 0.3)))
    b = m + 0.25
    lati = [((-b, -b), (b, -b)), ((b, -b), (b, b)), ((b, b), (-b, b)), ((-b, b), (-b, -b))]
    merlature, mensole = [], []
    for a, z in lati:
        pa, pb = c + Vector((*a, 0)), c + Vector((*z, 0))
        merlature += F.merli(pa, pb, ALTO_MASTIO + 0.3, 0.75, 0.3, passo=0.95, fuori=0.15)
        d = (pb - pa).normalized()
        fuori = Vector((d.y, -d.x, 0))
        mensole += F.lungo(pa, pb, 0.42, lambda p, d, f=fuori: F.scatola(p - f * 0.1 + Vector((0, 0, ALTO_MASTIO - 0.25)),
                                                                     (0.16 if abs(d.x) > 0.5 else 0.4,
                                                                      0.4 if abs(d.x) > 0.5 else 0.16, 0.5)))
    u.oggetto("Mastio", V.unisci(*pietra), "Pietra", liscio=False)
    u.oggetto("Mastio_Merli", V.unisci(*merlature), "Pietra", liscio=False)
    u.oggetto("Mastio_Beccatelli", V.unisci(*mensole), "PietraScura", liscio=False)
    t = c + Vector((m + 0.05, -m - 0.05, ALTO_MASTIO + 0.3))
    u.oggetto("Mastio_Torretta", F.cilindro_z(t, 0.48, 1.5, n=14), "Pietra")
    u.oggetto("Mastio_Torretta_Tetto", F.cono(t + Vector((0, 0, 1.5)), 0.68, 1.6, n=14), "Ardesia")
    # Finestre a croce (crociere) con la cornice chiara, sui tre lati che si vedono.
    finestre, cornici = [], []
    for z in (3.4, 5.6):
        for verso in ((0, -1), (1, 0), (-1, 0)):
            vx, vy = verso
            p = c + Vector((vx * (m + 0.01), vy * (m + 0.01), z))
            dim = (0.06, 0.5, 0.85) if vx else (0.5, 0.06, 0.85)
            cornice = (0.08, 0.68, 1.03) if vx else (0.68, 0.08, 1.03)
            cornici.append(F.scatola(p, cornice))
            finestre.append(F.scatola(p + Vector((vx * 0.02, vy * 0.02, 0)), dim))
            # La croce di pietra (montante e traversa) davanti al vano.
            q = p + Vector((vx * 0.04, vy * 0.04, 0))
            cornici.append(F.scatola(q, (0.05, 0.07, 0.85) if vx else (0.07, 0.05, 0.85)))
            cornici.append(F.scatola(q + Vector((0, 0, 0.15)), (0.05, 0.5, 0.07) if vx else (0.5, 0.05, 0.07)))
    u.oggetto("Mastio_Cornici", V.unisci(*cornici), "PietraScura", liscio=False)
    u.oggetto("Mastio_Finestre", V.unisci(*finestre), "Buio", liscio=False)
    # Stendardo sul mastio.
    asta = c + Vector((-0.6, 0.4, ALTO_MASTIO + 0.3))
    u.oggetto("Mastio_Asta", V.cilindro(asta, asta + Vector((0, 0, 3.0)), 0.045, n=8), "Legno")
    u.oggetto("Mastio_Stendardo", F.drappo(asta + Vector((0.04, 0, 2.95)), 1.6, 1.0, (1, 0.25, 0), onde=0.1),
              "Stendardo", spessore=0.01)


def stendardi(u):
    """Due stendardi lunghi appesi ai merli della cortina davanti, ai lati della porta."""
    pezzi = []
    for x in (-1.98, 1.98):
        bm = F.drappo((x - 0.35, -L - 0.82, ALTO_MURA + 0.3), 0.7, 2.2, (1, 0, 0), onde=0.02, n=4)
        pezzi.append(bm)
    u.oggetto("Stendardi", V.unisci(*pezzi), "Stendardo", spessore=0.01)


def cortile(u):
    """Una tettoia di legno contro la cortina di sinistra (stalla e magazzino) e un pozzo."""
    pezzi = [F.prisma_lungo((-L + 0.45, 1.6, 0), (-L + 0.45, -1.4, 0),
                            [(1.5, 1.9), (0.0, 2.9), (0.0, 3.1), (1.5, 2.1)])]
    pali = [V.cilindro((-L + 0.45 + 1.4, y, 0), (-L + 0.45 + 1.4, y, 2.0), 0.08, n=6) for y in (-1.3, 0.1, 1.5)]
    u.oggetto("Cortile_Tettoia", V.unisci(*pezzi), "Assi", liscio=False)
    u.oggetto("Cortile_Pali", V.unisci(*pali), "Legno")
    pozzo = [F.cilindro_z((1.6, -1.6, 0), 0.55, 0.8, n=12)]
    u.oggetto("Cortile_Pozzo", V.unisci(*pozzo), "PietraScura")
    u.oggetto("Cortile_Pozzo_Buio", F.cilindro_z((1.6, -1.6, 0.6), 0.42, 0.22, n=12), "Buio")


def costruisci():
    global U
    u = V.Unita(NOME, SIGLA)
    U = u
    materiali(u)
    cortine(u)
    torri(u)
    porta(u)
    mastio(u)
    stendardi(u)
    cortile(u)
    return F.conta(u)


def esporta(triangoli=7500, lato=1024):
    return F.esporta(NOME, TIRI, triangoli, quote={"Porta_Catene*": 40, "Torri_Cime*": 120, "Porta_Saracinesca*": 300,
                                                     "Mastio_Stendardo*": 40, "Stendardi*": 40}, lato=lato)
