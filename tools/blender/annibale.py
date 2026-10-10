"""Annibale Barca (247-183 a.C.) a cavallo: il comandante "Annibale" dell'Antichità.

Riferimenti: il busto di Capua (elmo, barba riccia), le monete barcidi di Cartagena, le ricostruzioni degli
ufficiali cartaginesi del periodo ellenistico. Elmo frigio-tracio di bronzo con la cima piegata in avanti, le
paragnatidi e la cresta di crine rossa; corazza anatomica di bronzo con la Gorgone, pteruges bianchi sulle
cosce, chitone bianco, mantello di porpora di Tiro sulla groppa, stivaletti; barba scura corta; la benda
sull'occhio destro (lo perse nelle paludi dell'Arno nel 217 a.C.). Lancia lunga nella destra, redini nella
sinistra, come i Compagni. Cavallo morello con la gualdrappa rossa a frange d'oro e le borchie.
Posa, mantello, lancia e cavallo vengono da compagno.py.
"""

import math

import bmesh
from mathutils import Matrix, Vector

import cavallo as C
import compagno as Co
import umano
import vestiti as V

NOME = "Annibale"
SIGLA = "AN"

U = None
CV = None


def materiali(u):
    u.materiale("Chitone", (0.78, 0.74, 0.64), ruvidita=0.9)
    u.materiale("Lino", (0.85, 0.82, 0.72), ruvidita=0.85)
    u.materiale("Porpora", (0.20, 0.02, 0.09), ruvidita=0.9)
    u.materiale("Rosso", (0.45, 0.04, 0.03), ruvidita=0.85)
    u.materiale("Cuoio", (0.24, 0.12, 0.05), ruvidita=0.65)
    u.materiale("Stivali", (0.20, 0.10, 0.045), ruvidita=0.7)
    u.materiale("Suola", (0.07, 0.04, 0.02), ruvidita=0.8)
    u.materiale("Bronzo", (0.62, 0.40, 0.15), metallo=1.0, ruvidita=0.32)
    u.materiale("Oro", (0.85, 0.63, 0.25), metallo=1.0, ruvidita=0.3)
    u.materiale("Ferro", (0.45, 0.45, 0.47), metallo=1.0, ruvidita=0.35)
    u.materiale("Corniolo", (0.50, 0.32, 0.16), ruvidita=0.55)
    u.materiale("Crini", (0.03, 0.025, 0.02), ruvidita=0.8)
    u.materiale("Briglie", (0.12, 0.06, 0.03), ruvidita=0.6)
    u.materiale("Benda", (0.03, 0.025, 0.02), ruvidita=0.7)


def vestiti(u):
    V.veste(u, "Chitone", 1.43, 0.90, "Chitone", margine=0.012, svasatura=0.0, pieghe=0.004, n_pieghe=14)
    V.maniche(u, "Chitone_Maniche", "Chitone", t_inizio=-0.15, t_fine=0.40, margine=0.011)
    V.pantaloni(u, "Chitone_Orlo", "Chitone", t_inizio=0.0, t_fine=0.42, margine=0.012, spessore=0.004)
    u.nascondi_pelle()
    # Corazza anatomica di bronzo che segue i muscoli, con l'orlo sopra i fianchi.
    V.veste(u, "Corazza", 1.43, 0.97, "Bronzo", margine=0.022, svasatura=0.0, pieghe=0.0, n_pieghe=4,
            spessore=0.007)
    V.pantaloni(u, "Pteruges", "Lino", t_inizio=0.02, t_fine=0.32, margine=0.026, spessore=0.006, n=24)
    # Gorgone d'oro sul petto e cintura rossa.
    p = u.sulla_pelle(Vector((0, 0, 1.30)), Vector((0, -1, 0)), 0.038, 0.35)
    u.oggetto("Corazza_Gorgone", V.sfera(p, (0.04, 0.01, 0.04), 12, 6), "Oro")
    u.oggetto("Cintura", V.anello_sul_corpo(u, (0, 0.0, 1.0), (0, 0, 1), 0.035, 0.03, n=64, portata=0.3),
              "Rosso", spessore=0.005)
    V.calzature(u, "Calzari", "Stivali", "Suola", taglio=0.16, inclinazione=0.2)
    u.nascondi_pelle()


def elmo(u):
    """Elmo frigio-tracio: calotta alta con la cima piegata in avanti, visierina, paragnatidi, cresta rossa."""
    _, bordo, anelli = V.calotta(u, "Elmo_Calotta", "Bronzo", 1.70, 1.655, (0, -0.075, 1.90),
                                 lambda t: 0.028 * math.sin(math.pi * min(1.0, t * 1.1)), distacco=0.015)
    centro = Vector((0, -0.02, 0))
    # Visierina sporgente davanti e paranuca svasato dietro.
    giri = []
    for f in (0.0, 0.5, 1.0):
        giro = []
        for p in bordo:
            radiale = Vector((p.x - centro.x, p.y - centro.y, 0)).normalized()
            davanti = max(0.0, -radiale.y)
            dietro = max(0.0, radiale.y)
            larga = 0.012 + 0.03 * davanti ** 3 + 0.035 * dietro ** 2
            giro.append(p + radiale * larga * f - Vector((0, 0, 0.02 * dietro * f)))
        giri.append(giro)
    tesa = V.griglia(giri, chiusa=True)
    V._verso_fuori(tesa)
    u.oggetto("Elmo_Tesa", tesa, "Bronzo", spessore=0.003)
    # Paragnatidi: due piastre sulle guance, dalla tempia alla mascella.
    pezzi = []
    for s in (1, -1):
        righe = []
        for z in (1.70, 1.64, 1.58, 1.54):
            riga = []
            for a in (-0.55, -0.25, 0.05):
                d = Vector((s * math.cos(a), math.sin(a) - 0.35, 0)).normalized()
                riga.append(u.sulla_pelle(Vector((0, -0.02, z)), d, 0.016, 0.2))
            righe.append(riga)
        pezzi.append(V.griglia(righe))
    paragnatidi = V.unisci(*pezzi)
    V._verso_fuori(paragnatidi)
    u.oggetto("Elmo_Guance", paragnatidi, "Bronzo", spessore=0.003)
    # Cresta di crine rossa dalla fronte alla nuca, sopra la cima.
    n = len(bordo)
    davanti, dietro = 3 * n // 4, n // 4
    punti = [anelli[k][davanti] for k in range(4, len(anelli) - 1)] + \
            [anelli[k][dietro] for k in range(len(anelli) - 2, 3, -1)]
    punti = [p + Vector((0, 0, 0.035)) for p in punti]
    raggi = [0.012 + 0.022 * math.sin(math.pi * i / (len(punti) - 1)) for i in range(len(punti))]
    u.oggetto("Elmo_Cresta", V.tubo_lungo(punti, raggi, n=8), "Rosso")


def benda(u):
    """Benda nera sull'occhio destro, con il laccio che gira attorno alla testa sotto l'elmo."""
    occhio = next(o for o in u.col.objects if o.name.startswith("Occhio.R"))
    c = occhio.matrix_world @ (sum((Vector(v) for v in occhio.bound_box), Vector()) / 8)
    p = u.sulla_pelle(c + Vector((0, 0.05, 0)), Vector((0, -1, 0)), 0.006, 0.2)
    u.oggetto("Benda", V.sfera(p, (0.024, 0.008, 0.02), 12, 6), "Benda")
    laccio = V.anello_sul_corpo(u, (0, -0.02, c.z + 0.035), (-0.3, -0.35, 1), 0.004, 0.008, n=40, portata=0.2)
    u.oggetto("Benda_Laccio", laccio, "Benda", spessore=0.002)


def bardatura(cv):
    cv.criniera_lunga("Crini")
    cv.coda("Crini", lunghezza=1.0)
    estremi = cv.briglie("Briglie", "Bronzo", mano=Co.REDINI)
    borchie = []
    for p in estremi:
        q = cv._fuori(p + Vector((0, 0.08, 0.10)), 0.012)
        borchie.append(V.sfera(q, (0.022, 0.022, 0.022), 10, 6))
    if borchie:
        cv.u.oggetto("CV_Borchie", V.unisci(*borchie), "Oro")
    cv.gualdrappa("CV_Gualdrappa", "Rosso", davanti=-0.04, dietro=0.40, angolo=75, cade=0.26)


def costruisci():
    global U, CV
    u = V.Unita(NOME, SIGLA)
    U = u
    Co.U = u
    materiali(u)
    u.costruisci_corpo(Co.posa, barba=1.0)
    cv = C.Cavallo(u, scala=0.24, snello=0.82, sella=(0.0, 0.02, 0.86), manto=(0.16, 0.13, 0.12))
    CV = cv
    vestiti(u)
    Co.mantello(u, cv)
    elmo(u)
    benda(u)
    Co.lancia(u)
    bardatura(cv)
    triangoli = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in u.col.objects if o.type == "MESH")
    return {"oggetti": len(u.col.objects), "triangoli": triangoli}


def esporta(triangoli=7600, lato=1024):
    import esporta as E
    r = E.prepara(NOME, U.giunti,
                  rigidi={"Lancia_*": "mano.R", "Occhio*": "testa", "Elmo_*": "testa", "Benda*": "testa",
                          "CV_Coda*": "cavallo.coda", "CV_Morso*": "cavallo.muso", "CV_Borchie*": "cavallo.muso"},
                  escludi=["Calzari", "Calzari.0*", "Corazza_Gorgone*", "Benda_Laccio*", "Cintura*"],
                  quote={"CV_Corpo*": 2600, "Calzari*": 200, "Occhio*": 60, "Lancia_Asta*": 40, "Lancia_Ferro*": 120,
                         "CV_Gualdrappa*": 300, "Mantello*": 320, "CV_Coda*": 260, "CV_Criniera*": 200,
                         "CV_Ciuffo*": 60, "CV_Redini*": 120, "Elmo_Calotta*": 240, "Elmo_Tesa*": 120,
                         "Elmo_Guance*": 60, "Elmo_Cresta*": 120, "Benda*": 40},
                  togli_dal_corpo=[SIGLA + "_Nascosta"], triangoli=triangoli, corpo=U.corpo.name,
                  extra=CV.perni(), padri={"bacino": "cavallo"}, cavallo=CV.esporta_cavallo())
    E.cuoci(lato=lato)
    return r
