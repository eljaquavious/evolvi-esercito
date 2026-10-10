"""Cavaliere normanno (Hastings, 1066): la carta "Cavaliere" del Medioevo.

Riferimenti: arazzo di Bayeux e ricostruzioni. Elmo conico con nasale (come l'huscarl) sopra il cappuccio di
maglia, usbergo di maglia lungo fino al ginocchio, spaccato per cavalcare, con le maniche lunghe; tunica sotto,
calze di lana e scarpe di cuoio; grande scudo a mandorla dipinto (croce e borchie) sul braccio sinistro;
lancia di frassino con il gonfalone a code sotto la punta, spada alla cintura. Il cavallo morello ha la sella
alta davanti e dietro, le staffe, il pettorale e la criniera lunga.

Posa: seduto con i piedi nelle staffe (gambe lunghe e quasi dritte), la destra tiene la lancia bassa lungo il
fianco, la sinistra le redini, con lo scudo appeso all'avambraccio.
"""

import math

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

import cavallo as C
import spadaccino as S
import umano
import vestiti as V

NOME = "Cavaliere"
SIGLA = "CN"

PRESA = Vector((-0.27, -0.10, 1.00))
LANCIA = Vector((0.0, -1.0, -0.18)).normalized()
LUNGHEZZA = 3.0
DIETRO = 1.2
REDINI = Vector((0.15, -0.27, 1.02))
SCUDO = Vector((0.30, -0.10, 0.97))              # centro dello scudo
FRONTE_SCUDO = Vector((1.0, -0.35, 0.0)).normalized()

U = None
CV = None


def materiali(u):
    u.materiale("Tunica", (0.30, 0.20, 0.07), ruvidita=0.9)
    u.materiale("Calze", (0.12, 0.14, 0.20), ruvidita=0.9)
    u.materiale("Maglia", (0.42, 0.43, 0.45), metallo=1.0, ruvidita=0.55)
    S._grana_maglia(u.mat["Maglia"])
    u.materiale("Ferro", (0.50, 0.50, 0.52), metallo=1.0, ruvidita=0.35)
    u.materiale("FerroScuro", (0.28, 0.28, 0.30), metallo=1.0, ruvidita=0.45)
    u.materiale("Cuoio", (0.20, 0.10, 0.045), ruvidita=0.65)
    u.materiale("CuoioRosso", (0.30, 0.06, 0.04), ruvidita=0.65)
    u.materiale("Suola", (0.07, 0.04, 0.02), ruvidita=0.8)
    u.materiale("Frassino", (0.55, 0.40, 0.22), ruvidita=0.6)
    u.materiale("Legno", (0.38, 0.22, 0.10), ruvidita=0.6)
    u.materiale("Ottone", (0.80, 0.58, 0.24), metallo=1.0, ruvidita=0.35)
    u.materiale("Telo", (0.08, 0.16, 0.36), ruvidita=0.9)
    u.materiale("Gonfalone", (0.62, 0.06, 0.05), ruvidita=0.9)
    u.materiale("Crini", (0.03, 0.02, 0.015), ruvidita=0.8)
    u.materiale("Briglie", (0.10, 0.05, 0.025), ruvidita=0.6)
    u.materiale("Scudo", (1.0, 1.0, 1.0), ruvidita=0.7, immagine=immagine_scudo())
    u.materiale("ScudoRetro", (0.36, 0.24, 0.12), ruvidita=0.8)


# Posa ----------------------------------------------------------------------------------------------

def posa(sch):
    # Nelle staffe: gambe lunghe, il piede un poco avanti sotto il ginocchio.
    C.seduto(sch, (0.30, -0.17, 0.57), (0.33, -0.21, 0.16), (0.06, -1.0, -0.05))
    umano.ruota_mondo(sch, "spina", (1, 0, 0), 3)
    umano.ruota_mondo(sch, "testa", (1, 0, 0), -3)
    C.impugna(sch, -1, PRESA, LANCIA, (0.25, 0, -1), (-0.6, 0.6, -0.3))
    C.impugna(sch, 1, REDINI, (0, -0.25, 1), (-1, 0, -0.35), (0.8, 0.4, -0.5), chiusura=0.9)


# Vestiti -------------------------------------------------------------------------------------------

def vestiti(u):
    V.veste(u, "Tunica", 1.44, 0.88, "Tunica", margine=0.010, svasatura=0.0, pieghe=0.004)
    V.maniche(u, "Tunica_Maniche", "Tunica", t_inizio=-0.15, t_fine=1.9, margine=0.008)
    V.pantaloni(u, "Calze", "Calze", t_inizio=0.0, t_fine=1.92, margine=0.006, spessore=0.003)
    V.calzature(u, "Scarpe", "Cuoio", "Suola", taglio=0.12, inclinazione=0.25)
    u.nascondi_pelle()
    # Usbergo: busto, maniche lunghe e le due falde spaccate sulle cosce fino al ginocchio.
    V.veste(u, "Usbergo", 1.46, 0.90, "Maglia", margine=0.026, svasatura=0.0, pieghe=0.003, n_pieghe=10,
            spessore=0.006)
    V.maniche(u, "Usbergo_Maniche", "Maglia", t_inizio=-0.15, t_fine=1.82, margine=0.018, spessore=0.005)
    V.pantaloni(u, "Usbergo_Falde", "Maglia", t_inizio=0.0, t_fine=0.92, margine=0.026, spessore=0.006)
    # Cappuccio di maglia: attorno al collo e ai lati del viso, sotto l'elmo.
    pezzi = []
    for z, largo in ((1.50, 0.07), (1.57, 0.06)):
        pezzi.append(V.anello_sul_corpo(u, (0, -0.005, z), (0, 0.2, 1), 0.018, largo, n=48, portata=0.2))
    u.oggetto("Cappuccio", V.unisci(*pezzi), "Maglia", spessore=0.006)
    u.oggetto("Cintura", V.anello_sul_corpo(u, (0, 0.01, 1.0), (0, 0, 1), 0.05, 0.04, n=64, portata=0.3), "Cuoio",
              spessore=0.004)


def scudo(u):
    """Scudo a mandorla: curvo, tondo in alto e a punta in basso; fronte verso fuori e un poco in avanti."""
    alto, largo, curva = 0.98, 0.23, 0.06
    def mezza(t):
        if t > 0.8:
            return largo * math.sqrt(max(0.0, 1 - ((t - 0.8) / 0.2) ** 2)) * 0.98 + 0.02 * largo
        return largo * math.sin(math.pi / 2 * min(1.0, t / 0.8)) ** 0.75
    n, righe = 16, 24
    fronte = bmesh.new()
    livello = fronte.loops.layers.uv.new("UVMap")
    griglia = []
    for i in range(righe + 1):
        t = i / righe
        w = max(mezza(t), 0.004)
        griglia.append([fronte.verts.new((s * w, -curva * (1 - s * s * (w / largo) ** 2), (t - 0.5) * alto))
                        for s in np.linspace(-1, 1, n + 1)])
    for a, b in zip(griglia, griglia[1:]):
        for k in range(n):
            fronte.faces.new((a[k], a[k + 1], b[k + 1], b[k]))
    for f in fronte.faces:
        for loop in f.loops:
            co = loop.vert.co
            loop[livello].uv = (0.5 + co.x / (2 * largo), co.z / alto + 0.5)
    bmesh.ops.recalc_face_normals(fronte, faces=fronte.faces)
    for f in fronte.faces:
        if f.normal.y > 0:
            f.normal_flip()
    retro = fronte.copy()
    for v in retro.verts:
        v.co.y += 0.014
    for f in retro.faces:
        f.normal_flip()
    bordo = [griglia[i][0].co.copy() for i in range(righe + 1)] + [griglia[i][n].co.copy() for i in range(righe, -1, -1)]
    bordo = V.tubo_lungo([p + Vector((0, 0.007, 0)) for p in bordo], 0.009, n=6, tappi=False)
    # Fronte locale -Y verso FRONTE_SCUDO; la punta un poco in fuori (lo scudo sta fuori dal fianco del cavallo).
    x = Vector((0, 0, 1)).cross(FRONTE_SCUDO).normalized()
    m = Matrix((x, -FRONTE_SCUDO, Vector((0, 0, 1)))).transposed().to_4x4()
    m = Matrix.Translation(SCUDO) @ Matrix.Rotation(math.radians(-12), 4, x) @ m
    for b in (fronte, retro, bordo):
        V.trasforma(b, m)
    u.oggetto("Scudo_Fronte", fronte, "Scudo")
    u.oggetto("Scudo_Retro", retro, "ScudoRetro")
    u.oggetto("Scudo_Bordo", bordo, "Cuoio")
    u.oggetto("Scudo_Umbone", V.sfera(m @ Vector((0, -curva - 0.012, 0.12)), (0.05, 0.05, 0.05), 12, 6), "Ferro")


def immagine_scudo(lato=512):
    """Rosso con la croce gialla dalle braccia allargate e i chiodi del bordo, come sull'arazzo di Bayeux."""
    nome = SIGLA + "_Scudo"
    vecchia = bpy.data.images.get(nome)
    if vecchia:
        bpy.data.images.remove(vecchia)
    img = bpy.data.images.new(nome, lato, lato, alpha=False)
    yy, xx = np.mgrid[0:lato, 0:lato]
    u = (xx + 0.5) / lato * 2 - 1          # -1 sinistra, 1 destra
    v = (yy + 0.5) / lato                  # 0 punta, 1 cima
    rosso = np.array([0.58, 0.07, 0.05])
    giallo = np.array([0.86, 0.66, 0.18])
    rgb = np.ones((lato, lato, 3)) * rosso
    rgb *= (0.95 + 0.08 * np.sin(u * 3 + v * 7))[..., None]
    # Croce: asta verticale e traversa alta, che si allargano verso le estremità.
    cy = 0.62
    asta = np.abs(u) < 0.07 + 0.08 * np.abs(v - cy) ** 1.5
    traversa = np.abs(v - cy) < 0.045 + 0.06 * np.abs(u) ** 1.5
    rgb[(asta & (v > 0.18) & (v < 0.95)) | (traversa & (np.abs(u) < 0.85))] = giallo
    # Bordo e chiodi.
    rgb[(np.abs(u) > 0.9) | (v > 0.965)] = giallo * 0.8
    chiodi = ((np.abs(np.abs(u) - 0.8) < 0.035) & (np.cos(v * 2 * math.pi * 7) > 0.85))
    rgb[chiodi] = np.array([0.75, 0.75, 0.72])
    rgba = np.concatenate([np.clip(rgb, 0, 1), np.ones((lato, lato, 1))], axis=2).astype(np.float32)
    img.pixels.foreach_set(rgba.ravel())
    img.pack()
    return img


def lancia(u):
    coda = PRESA - LANCIA * DIETRO
    cima = coda + LANCIA * LUNGHEZZA
    u.oggetto("Lancia_Asta", V.cilindro(coda, cima, 0.016, 0.014, n=10), "Frassino")
    lato = LANCIA.cross(Vector((0, 0, 1))).normalized()
    su = lato.cross(LANCIA).normalized()
    m = Matrix((lato, LANCIA, su)).transposed().to_4x4()
    lama = V.lama(0.24, 0.035, 0.0, spessore=0.008, foglia=0.03)
    V.trasforma(lama, Matrix.Translation(cima) @ m @ Matrix.Rotation(math.radians(-90), 4, "X"))
    u.oggetto("Lancia_Ferro", V.unisci(lama, V.cilindro(cima - LANCIA * 0.08, cima + LANCIA * 0.01, 0.02, 0.016, n=10)),
              "Ferro")
    # Gonfalone a due code, attaccato sotto la punta: pende all'indietro e in giù, un poco ondulato.
    attacco = cima - LANCIA * 0.12
    via = (-su * 0.85 - LANCIA * 0.5).normalized()
    bm = bmesh.new()
    vv = []
    for i in range(7):
        f = i / 6
        base = attacco - LANCIA * 0.28 * f
        lungo = 0.36 - 0.13 * math.sin(math.pi * f)      # tacca in mezzo: due code
        vv.append([bm.verts.new(base + via * lungo * (k / 4) + lato * 0.02 * math.sin(math.pi * 1.5 * k / 4))
                   for k in range(5)])
    for a, b in zip(vv, vv[1:]):
        for k in range(4):
            bm.faces.new((a[k], a[k + 1], b[k + 1], b[k]))
    u.oggetto("Lancia_Gonfalone", bm, "Gonfalone", spessore=0.004)


def spada(u):
    """Spada nel fodero alla cintura, a sinistra, che pende indietro."""
    base = Matrix.Translation((0.20, 0.03, 1.0)) @ Matrix.Rotation(math.radians(62), 4, "X") @ \
        Matrix.Rotation(math.radians(-6), 4, "Y")
    fodero = bmesh.new()
    sezioni = [(0.0, 0.03), (-0.6, 0.026), (-0.78, 0.014), (-0.8, 0.0)]
    anelli = []
    for z, mezza in sezioni:
        anelli.append([fodero.verts.new((mezza * math.cos(math.radians(a)) * 0.35, mezza * math.sin(math.radians(a)), z))
                       for a in range(0, 360, 30)])
    for a, b in zip(anelli, anelli[1:]):
        V.unisci_anelli(fodero, a, b)
    V.trasforma(fodero, base)
    u.oggetto("Spada_Fodero", fodero, "Cuoio")
    elsa = [V.scatola((0, 0, 0.012), (0.03, 0.17, 0.018)), V.cilindro((0, 0, 0.02), (0, 0, 0.12), 0.014, n=10),
            V.sfera((0, 0, 0.135), (0.026, 0.026, 0.02), 10, 6)]
    for b in elsa:
        V.trasforma(b, base)
    u.oggetto("Spada_Elsa", V.unisci(*elsa), "Ferro")


def sella(u, cv):
    """Sella alta: seduta di cuoio, arcione davanti e paletta dietro, sottosella blu, staffe e pettorale."""
    cv.gualdrappa("CV_Sottosella", "Telo", davanti=-0.05, dietro=0.34, angolo=58, cade=0.16)
    cv.gualdrappa("CV_Sella", "Cuoio", davanti=0.02, dietro=0.26, angolo=40, cade=0.03, distacco=0.03, spessore=0.02)
    garrese, groppa = cv.ossa["Bone"][1], cv.ossa["Bone"][0]
    pezzi = []
    for f, alto, nome in ((0.0, 0.16, "davanti"), (0.30, 0.20, "dietro")):
        centro = garrese.lerp(groppa, f) + Vector((0, 0, -0.12))
        punti = []
        for j in range(15):
            a = math.radians(-60 + 120 * j / 14)
            d = Vector((math.sin(a), 0, math.cos(a)))
            p = cv.sulla_pelle(centro, d, 0.03, 1.2) or centro + d * 0.3
            p = p + Vector((0, 0, alto * math.cos(a) ** 2))
            punti.append(p)
        pezzi.append(V.tubo_lungo(punti, 0.035, n=8))
    u.oggetto("CV_Arcioni", V.unisci(*pezzi), "Legno")
    # Staffe: cinghia dalla sella al piede e la staffa di ferro sotto la pianta.
    cinghie, staffe = [], []
    for lato in ("s", "d"):
        caviglia, punta_piede = u.P("caviglia_" + lato), u.P("punta_" + lato)
        pianta = caviglia.lerp(punta_piede, 0.55) + Vector((0, 0, -0.06))
        s = 1 if lato == "s" else -1
        alto = cv.sulla_pelle(garrese.lerp(groppa, 0.1) + Vector((0, 0, -0.1)), Vector((s * 0.8, 0, 0.6)), 0.03, 1.0)
        if alto is None:
            continue
        cinghie.append(V.tubo_lungo([alto, alto.lerp(pianta, 0.5) + Vector((s * 0.03, 0, 0)), pianta + Vector((0, 0, 0.1))],
                                    0.012, n=6))
        anello = [pianta + Vector((0.05 * math.cos(2 * math.pi * k / 16), 0, 0.06 * math.sin(2 * math.pi * k / 16) + 0.04))
                  for k in range(17)]
        staffe.append(V.tubo_lungo(anello, 0.008, n=6, tappi=False))
    if cinghie:
        u.oggetto("Staffe_Cinghie", V.unisci(*cinghie), "Cuoio")
        u.oggetto("Staffe_Ferro", V.unisci(*staffe), "Ferro")
    # Pettorale: una fascia davanti al petto del cavallo, da un lato all'altro della sella.
    a, b = cv.ossa["Bone_L"][0], cv.ossa["Bone_R"][0]
    petto = cv.osso("Bone.001", 0.12) + Vector((0, 0, -0.18))
    punti, normali = [], []
    for j in range(21):
        ang = math.radians(-100 + 200 * j / 20)
        d = Vector((math.sin(ang), -math.cos(ang) * 0.9, -0.25)).normalized()
        p = cv.sulla_pelle(petto, d, 0.012, 1.0)
        if p is not None:
            punti.append(p)
            normali.append(d)
    if len(punti) > 3:
        u.oggetto("CV_Pettorale", V.striscia(punti, normali, 0.04), "CuoioRosso", spessore=0.005)


def bardatura(cv):
    cv.criniera_lunga("Crini", lato=-1)
    cv.coda("Crini", lunghezza=1.0)
    cv.briglie("Briglie", "Ferro", mano=REDINI)


# Tutto ---------------------------------------------------------------------------------------------

def costruisci():
    global U, CV
    u = V.Unita(NOME, SIGLA)
    U = u
    materiali(u)
    u.costruisci_corpo(posa, barba=0.6)
    cv = C.Cavallo(u, scala=0.235, snello=0.8, sella=(0.0, 0.03, 0.86), manto=(0.32, 0.25, 0.22))
    CV = cv
    vestiti(u)
    S.elmo(u)
    S.baffi(u)
    scudo(u)
    lancia(u)
    spada(u)
    sella(u, cv)
    bardatura(cv)
    triangoli = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in u.col.objects if o.type == "MESH")
    return {"oggetti": len(u.col.objects), "triangoli": triangoli}


def esporta(triangoli=7800, lato=1024):
    import esporta as E
    r = E.prepara(NOME, U.giunti,
                  rigidi={"Lancia_*": "mano.R", "Occhio*": "testa", "Elmo_*": "testa", "Baffi*": "testa",
                          "Spada_*": "bacino", "Scudo_*": "avambraccio.L", "Staffe_*": "cavallo",
                          "CV_Coda*": "cavallo.coda", "CV_Morso*": "cavallo.muso", "CV_Ciuffo*": "cavallo.muso"},
                  escludi=["Scarpe", "Scarpe.0*", "Elmo_Nervature*"],
                  quote={"CV_Corpo*": 2600, "Scarpe*": 200, "Occhio*": 60, "Lancia_Asta*": 40, "Lancia_Ferro*": 80,
                         "Lancia_Gonfalone*": 60, "Usbergo.*": 420, "Usbergo": 420, "Usbergo_Maniche*": 300,
                         "Usbergo_Falde*": 260, "Scudo_Fronte*": 200, "Scudo_Retro*": 120, "Scudo_Bordo*": 100,
                         "CV_Sottosella*": 260, "CV_Sella*": 220, "CV_Arcioni*": 120, "CV_Coda*": 260,
                         "CV_Criniera*": 300, "CV_Redini*": 120, "Staffe_*": 120, "Elmo_Calotta*": 220},
                  togli_dal_corpo=[SIGLA + "_Nascosta"], triangoli=triangoli, corpo=U.corpo.name,
                  extra=CV.perni(), padri={"bacino": "cavallo"}, cavallo=CV.esporta_cavallo())
    E.cuoci(lato=lato)
    return r
