"""Cavaliere dei Compagni (hetairoi) di Alessandro Magno, 334-323 a.C.: la carta "Compagno" dell'Antichità.

Riferimenti: mosaico di Alessandro (Pompei, Casa del Fauno), sarcofago di Alessandro (Istanbul) e le
ricostruzioni moderne. Elmo beotico di bronzo (calotta tonda e tesa larga ripiegata in giù), corazza di
lino (linothorax) bianca con le bande colorate e gli spallacci, pteruges sulle cosce, chitone rosso, mantello
(clamide) di porpora che scende sulla groppa, stivaletti; lancia lunga (xyston) di corniolo con la punta a
foglia e il puntale, spada ricurva (kopis) al fianco. Si cavalcava senza staffe né sella: un telo di pelle di
pantera sul dorso, le gambe lunghe lungo i fianchi del cavallo, le punte dei piedi in giù.
Cavallo baio con la criniera tagliata dritta, briglie con le borchie di bronzo.

Posa: seduto, la destra tiene la lancia bassa lungo il fianco destro (punta in avanti e un poco in giù),
la sinistra tiene le redini sopra il garrese.
Nel gioco: le ossa del cavallo (vedi cavallo.py) e il bacino del cavaliere figlio di "cavallo".
"""

import math

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

import cavallo as C
import umano
import vestiti as V

NOME = "Compagno"
SIGLA = "CO"

PRESA = Vector((-0.27, -0.10, 1.00))                 # pugno destro sulla lancia
LANCIA = Vector((0.0, -1.0, -0.20)).normalized()     # verso della punta
LUNGHEZZA = 3.2                                       # lancia (le vere erano 3,5-4 m)
DIETRO = 1.25                                         # tratto dietro la mano
REDINI = Vector((0.07, -0.30, 1.03))                  # pugno sinistro con le redini

U = None
CV = None


def materiali(u):
    u.materiale("Chitone", (0.50, 0.07, 0.05), ruvidita=0.9)
    u.materiale("Lino", (0.80, 0.76, 0.64), ruvidita=0.85)
    u.materiale("Banda", (0.42, 0.05, 0.10), ruvidita=0.85)
    u.materiale("Porpora", (0.17, 0.025, 0.075), ruvidita=0.9)
    u.materiale("Cuoio", (0.24, 0.12, 0.05), ruvidita=0.65)
    u.materiale("Stivali", (0.20, 0.10, 0.045), ruvidita=0.7)
    u.materiale("Suola", (0.07, 0.04, 0.02), ruvidita=0.8)
    u.materiale("Bronzo", (0.55, 0.33, 0.12), metallo=1.0, ruvidita=0.35)
    u.materiale("Ferro", (0.45, 0.45, 0.47), metallo=1.0, ruvidita=0.35)
    u.materiale("Corniolo", (0.50, 0.32, 0.16), ruvidita=0.55)
    u.materiale("Crini", (0.05, 0.03, 0.02), ruvidita=0.8)
    u.materiale("Briglie", (0.12, 0.06, 0.03), ruvidita=0.6)
    u.materiale("Pantera", (1.0, 1.0, 1.0), ruvidita=0.9, immagine=immagine_pantera())


# Posa ----------------------------------------------------------------------------------------------

def punta(sch, nome, bersaglio):
    """Gira un osso attorno alla sua testa finché la coda guarda verso il bersaglio."""
    pb = sch.pose.bones[nome]
    a = (pb.tail - pb.head).normalized()
    b = (Vector(bersaglio) - pb.head).normalized()
    asse = a.cross(b)
    if asse.length < 1e-6:
        return
    umano.ruota_mondo(sch, nome, tuple(asse.normalized()), math.degrees(a.angle(b)))


def impugna(sch, s, punto, pollice, dita, polo, chiusura=1.0):
    """Pugno chiuso su un'asta (o sulle redini) che passa per 'punto': il pollice guarda lungo 'pollice',
    le dita girano attorno all'asta partendo verso 'dita'. È vestiti.impugna_verticale per un'asta qualsiasi."""
    su = Vector(pollice).normalized()
    avanti = Vector(dita)
    avanti = (avanti - su * avanti.dot(su)).normalized()
    phi = math.radians(15)
    radiale = su * math.cos(phi) - avanti * math.sin(phi)
    y = avanti * math.cos(phi) + su * math.sin(phi)
    dorso = (y.cross(radiale) if s < 0 else radiale.cross(y)).normalized()
    umano.posa_braccio(sch, s, Vector(punto) - y * 0.09 + dorso * 0.028, y, dorso, polo)
    umano.chiudi_dita(sch, s, {d: tuple(a * chiusura for a in g) for d, g in
                               {"indice": (70, 95, 50), "medio": (75, 95, 50), "anulare": (80, 95, 50),
                                "mignolo": (85, 90, 50), "pollice": (35, 45, 35)}.items()})


def posa(sch):
    # In sella senza staffe: cosce aperte attorno al corpo del cavallo, gambe giù lungo i fianchi.
    for s in (1, -1):
        k = umano.sigla(s)
        punta(sch, "coscia" + k, (s * 0.31, -0.21, 0.62))
        punta(sch, "stinco" + k, (s * 0.335, -0.10, 0.24))
        pb = sch.pose.bones["stinco" + k]
        caviglia = pb.tail.copy()
        punta(sch, "piede" + k, caviglia + Vector((s * 0.03, -0.55, -0.8)))
    # Busto un poco indietro, come chi cavalca, e la testa dritta.
    umano.ruota_mondo(sch, "spina", (1, 0, 0), 4)
    umano.ruota_mondo(sch, "testa", (1, 0, 0), -4)
    # Destra sulla lancia bassa: dita in giù attorno all'asta, pollice verso la punta.
    impugna(sch, -1, PRESA, LANCIA, (0.25, 0, -1), (-0.6, 0.6, -0.3))
    # Sinistra con le redini: pugno chiuso, pollice in su, nocche in avanti.
    impugna(sch, 1, REDINI, (0, -0.25, 1), (-1, 0, -0.35), (0.6, 0.5, -0.5), chiusura=0.9)


# Vestiti -------------------------------------------------------------------------------------------

def vestiti(u):
    # Chitone: busto e un orlo corto sulle cosce.
    V.veste(u, "Chitone", 1.43, 0.90, "Chitone", margine=0.012, svasatura=0.0, pieghe=0.004, n_pieghe=14)
    V.maniche(u, "Chitone_Maniche", "Chitone", t_inizio=-0.15, t_fine=0.40, margine=0.011)
    V.pantaloni(u, "Chitone_Orlo", "Chitone", t_inizio=0.0, t_fine=0.42, margine=0.012, spessore=0.004)
    u.nascondi_pelle()
    # Corazza di lino sopra: busto, bande rosse in basso e in alto, pteruges sulle cosce.
    V.veste(u, "Corazza", 1.40, 0.95, "Lino", margine=0.028, svasatura=0.0, pieghe=0.0015, n_pieghe=10,
            spessore=0.008)
    for z, nome in ((0.985, "Corazza_Banda"), (1.18, "Corazza_Banda2")):
        u.oggetto(nome, V.anello_sul_corpo(u, (0, 0.01, z), (0, 0, 1), 0.04, 0.035, n=64, portata=0.3), "Banda",
                  spessore=0.003)
    V.pantaloni(u, "Pteruges", "Lino", t_inizio=0.02, t_fine=0.30, margine=0.024, spessore=0.006, n=24)
    # Spallacci: due fasce dalla schiena al petto sopra le spalle.
    pezzi = []
    for s in (1, -1):
        punti, normali = [], []
        for i in range(17):
            t = i / 16
            a = math.pi * t
            d = Vector((s * 0.35 * math.sin(a), -math.cos(a), math.sin(a) * 1.2)).normalized()
            centro = Vector((s * 0.12, 0.0, 1.30))
            punti.append(u.sulla_pelle(centro, d, 0.04, 0.4))
            normali.append(d)
        pezzi.append(V.striscia(punti, normali, 0.09))
    u.oggetto("Corazza_Spallacci", V.unisci(*pezzi), "Lino", spessore=0.007)
    # Borchia con la Gorgone sul petto (un disco di bronzo).
    p = u.sulla_pelle(Vector((0, 0, 1.25)), Vector((0, -1, 0)), 0.05, 0.35)
    u.oggetto("Corazza_Gorgone", V.sfera(p, (0.035, 0.008, 0.035), 12, 6), "Bronzo")
    # Stivaletti allacciati.
    V.calzature(u, "Calzari", "Stivali", "Suola", taglio=0.16, inclinazione=0.2)
    u.nascondi_pelle()


def mantello(u, cv):
    """Clamide di porpora: dalle spalle giù per la schiena, poi distesa sulla groppa del cavallo."""
    colonne = 20
    angoli = np.linspace(0.3, math.pi - 0.3, colonne)
    righe = []
    for z in np.linspace(1.43, 1.0, 9):
        riga = []
        for a in angoli:
            d = Vector((math.cos(a), math.sin(a), 0))
            fuori = 0.035 + 0.03 * (1.43 - z)
            riga.append(u.sulla_pelle(Vector((0, 0.0, z)), d, fuori, 0.4))
        righe.append(riga)
    ultima = righe[-1]
    for t in np.linspace(0.15, 1.0, 6):
        riga = []
        for p in ultima:
            x = p.x * (1 + 0.35 * t)
            y = max(p.y, 0.05) + 0.06 + 0.32 * t
            q = cv.sulla_pelle((x, y, 2.5), (0, 0, -1), 0.025, 3.0)
            riga.append(q if q is not None else Vector((x, y, p.z - 0.1 * t)))
        righe.append(riga)
    bm = V.griglia(righe)
    V._verso_fuori(bm)
    return u.oggetto("Mantello", bm, "Porpora", spessore=0.006)


def elmo(u):
    """Elmo beotico: calotta tonda e tesa larga, ondulata e ripiegata in giù (più corta davanti)."""
    _, bordo, _ = V.calotta(u, "Elmo_Calotta", "Bronzo", 1.70, 1.665, (0, -0.02, 1.85),
                            lambda t: 0.02 * math.sin(math.pi * min(1.0, t * 1.05)), distacco=0.015)
    centro = Vector((0, -0.02, 0))
    giri = []
    for f in (0.0, 0.35, 0.7, 1.0):
        giro = []
        for j, p in enumerate(bordo):
            radiale = Vector((p.x - centro.x, p.y - centro.y, 0)).normalized()
            davanti = max(0.0, -radiale.y)
            onda = 1 + 0.18 * math.sin(j * 2 * math.pi * 7 / len(bordo))
            larga = (0.105 - 0.06 * davanti ** 2) * onda
            giu = (0.085 - 0.06 * davanti) * f ** 1.6
            giro.append(p + radiale * larga * f - Vector((0, 0, giu)))
        giri.append(giro)
    tesa = V.griglia(giri, chiusa=True)
    V._verso_fuori(tesa)
    u.oggetto("Elmo_Tesa", tesa, "Bronzo", spessore=0.003)


def lancia(u):
    """Xyston: asta di corniolo, punta di ferro a foglia, puntale dietro (per colpire anche con quello)."""
    coda = PRESA - LANCIA * DIETRO
    cima = coda + LANCIA * LUNGHEZZA
    u.oggetto("Lancia_Asta", V.cilindro(coda, cima, 0.015, 0.013, n=10), "Corniolo")
    lato = LANCIA.cross(Vector((0, 0, 1))).normalized()
    su = lato.cross(LANCIA).normalized()
    m = Matrix((lato, LANCIA, su)).transposed().to_4x4()
    pezzi = []
    # Punta a foglia: una lama corta e larga.
    lama = V.lama(0.28, 0.03, 0.0, spessore=0.008, foglia=0.08)
    # vestiti.lama è lungo +Z nel piano XZ: va girata lungo la lancia.
    V.trasforma(lama, Matrix.Translation(cima) @ m @ Matrix.Rotation(math.radians(-90), 4, "X"))
    pezzi.append(lama)
    pezzi.append(V.cilindro(cima - LANCIA * 0.08, cima + LANCIA * 0.01, 0.019, 0.015, n=10))
    pezzi.append(V.cilindro(coda + LANCIA * 0.12, coda - LANCIA * 0.10, 0.017, 0.004, n=10))
    u.oggetto("Lancia_Ferro", V.unisci(*pezzi), "Ferro")


def spada(u):
    """Kopis nel fodero al fianco sinistro, appesa all'indietro."""
    base = Matrix.Translation((0.20, 0.02, 1.0)) @ Matrix.Rotation(math.radians(60), 4, "X") @ \
        Matrix.Rotation(math.radians(-8), 4, "Y")
    fodero = bmesh.new()
    sezioni = [(0.0, 0.03), (-0.15, 0.036), (-0.42, 0.042), (-0.55, 0.02), (-0.58, 0.0)]
    anelli = []
    for z, mezza in sezioni:
        anelli.append([fodero.verts.new((mezza * math.cos(math.radians(a)) * 0.3, mezza * math.sin(math.radians(a)), z))
                       for a in range(0, 360, 30)])
    for a, b in zip(anelli, anelli[1:]):
        V.unisci_anelli(fodero, a, b)
    V.trasforma(fodero, base)
    u.oggetto("Spada_Fodero", fodero, "Cuoio")
    elsa = [V.scatola((0, 0, 0.012), (0.02, 0.06, 0.016)),
            V.tubo_lungo([(0, 0, 0.02), (0, -0.01, 0.07), (0, -0.035, 0.11)], 0.013, n=8)]
    for b in elsa:
        V.trasforma(b, base)
    u.oggetto("Spada_Elsa", V.unisci(*elsa), "Bronzo")
    # Balteo: dalla spalla destra al fianco sinistro.
    punti, normali = [], []
    for i in range(25):
        t = i / 24
        p = Vector((-0.13, -0.07, 1.43)).lerp(Vector((0.17, -0.06, 0.98)), t)
        d = Vector((p.x, p.y, 0)).normalized()
        punti.append(u.sulla_pelle(Vector((0, 0, p.z)), d, 0.045, 0.35))
        normali.append(d)
    u.oggetto("Balteo", V.striscia(punti, normali, 0.03), "Cuoio", spessore=0.003)


def immagine_pantera(lato=512, seme=5):
    """Pelle di pantera: fondo fulvo con le rosette scure, orlo rosso con un filo d'oro."""
    nome = SIGLA + "_Pantera"
    vecchia = bpy.data.images.get(nome)
    if vecchia:
        bpy.data.images.remove(vecchia)
    img = bpy.data.images.new(nome, lato, lato, alpha=False)
    rng = np.random.default_rng(seme)
    celle = 11
    jit = rng.uniform(0.2, 0.8, (celle + 2, celle + 2, 2))
    fase = rng.uniform(0, 2 * math.pi, (celle + 2, celle + 2))
    yy, xx = np.mgrid[0:lato, 0:lato]
    uu = (xx + 0.5) / lato
    vv = (yy + 0.5) / lato
    u = uu * celle
    v = vv * celle * 1.3
    ci, cj = np.floor(u).astype(int), np.clip(np.floor(v).astype(int), 0, celle)
    macchie = np.zeros((lato, lato), dtype=bool)
    centri = np.zeros((lato, lato), dtype=bool)
    for di in (-1, 0, 1):
        for dj in (-1, 0, 1):
            i = np.clip(ci + di, -1, celle)
            j = np.clip(cj + dj, -1, celle)
            cx = i + jit[j + 1, i + 1, 0]
            cy = j + jit[j + 1, i + 1, 1]
            dx, dy = u - cx, v - cy
            r = np.hypot(dx, dy)
            a = np.arctan2(dy, dx)
            macchie |= (r > 0.2) & (r < 0.33) & (np.cos(a * 4 + fase[j + 1, i + 1]) > -0.35)
            centri |= r < 0.2
    fondo = np.array([0.80, 0.56, 0.26])
    rgb = np.ones((lato, lato, 3)) * fondo
    rgb *= (0.92 + 0.12 * np.sin(uu * 7 + vv * 3))[..., None]
    rgb[centri] *= 0.82
    rgb[macchie] = np.array([0.09, 0.055, 0.03])
    bordo = np.minimum(np.minimum(uu, 1 - uu), np.minimum(vv, 1 - vv))
    rgb[bordo < 0.045] = np.array([0.40, 0.05, 0.06])
    rgb[np.abs(bordo - 0.03) < 0.004] = np.array([0.85, 0.66, 0.28])
    rgba = np.concatenate([np.clip(rgb, 0, 1), np.ones((lato, lato, 1))], axis=2).astype(np.float32)
    img.pixels.foreach_set(rgba.ravel())
    img.pack()
    return img


def bardatura(cv):
    cv.criniera_rasata("Crini")
    cv.coda("Crini", lunghezza=0.9)
    estremi = cv.briglie("Briglie", "Bronzo", mano=REDINI)
    # Borchie di bronzo sui montanti e sulla fronte.
    borchie = []
    for p in estremi:
        su = p + Vector((0, 0.08, 0.10))
        q = cv._fuori(su, 0.012)
        borchie.append(V.sfera(q, (0.022, 0.022, 0.022), 10, 6))
    fronte = cv.sulla_pelle(cv.osso("Bone.002", 0.35), Vector((0, -0.4, 1)), 0.012, 0.5)
    if fronte is not None:
        borchie.append(V.sfera(fronte, (0.03, 0.03, 0.03), 12, 6))
    if borchie:
        cv.u.oggetto("CV_Borchie", V.unisci(*borchie), "Bronzo")
    cv.gualdrappa("CV_Gualdrappa", "Pantera", davanti=-0.02, dietro=0.36, angolo=70, cade=0.20)


# Tutto ---------------------------------------------------------------------------------------------

def costruisci():
    global U, CV
    u = V.Unita(NOME, SIGLA)
    U = u
    materiali(u)
    u.costruisci_corpo(posa, barba=0.35)
    cv = C.Cavallo(u, scala=0.23, snello=0.78, sella=(0.0, 0.02, 0.86), manto=(0.62, 0.42, 0.32))
    CV = cv
    vestiti(u)
    mantello(u, cv)
    elmo(u)
    lancia(u)
    spada(u)
    bardatura(cv)
    triangoli = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in u.col.objects if o.type == "MESH")
    return {"oggetti": len(u.col.objects), "triangoli": triangoli}


def esporta(triangoli=7600, lato=1024):
    """Versione da gioco (dopo costruisci())."""
    import esporta as E
    r = E.prepara(NOME, U.giunti,
                  rigidi={"Lancia_*": "mano.R", "Occhio*": "testa", "Elmo_*": "testa", "Spada_*": "bacino",
                          "CV_Coda*": "cavallo.coda", "CV_Morso*": "cavallo.muso", "CV_Borchie*": "cavallo.muso"},
                  escludi=["Calzari", "Calzari.0*", "Corazza_Gorgone*"],
                  quote={"CV_Corpo*": 2600, "Calzari*": 200, "Occhio*": 60, "Lancia_Asta*": 40, "Lancia_Ferro*": 120,
                         "CV_Gualdrappa*": 300, "Mantello*": 320, "CV_Coda*": 260, "CV_Criniera*": 160,
                         "CV_Redini*": 120, "Elmo_Calotta*": 240, "Elmo_Tesa*": 240},
                  togli_dal_corpo=[SIGLA + "_Nascosta"], triangoli=triangoli, corpo=U.corpo.name,
                  extra=CV.perni(), padri={"bacino": "cavallo"}, cavallo=CV.esporta_cavallo())
    E.cuoci(lato=lato)
    return r
