"""Charles de Gaulle nel 1940, generale di brigata: il comandante "DeGaulle" del Novecento.

Riferimenti: le foto di maggio-giugno 1940 (Montcornet, Londra, l'appello del 18 giugno). Vareuse kaki
modello 1938 a un petto con il colletto aperto, camicia e cravatta kaki, quattro tasche; cinturone di cuoio
con la bretella a tracolla (Sam Browne) e la fondina; calzoni da cavallerizzo kaki e gambali di cuoio marrone
lucido sopra gli stivaletti; il képi da generale (fascia nera con una fila di foglie di quercia d'oro, calotta
rossa, due stelle d'argento davanti, visiera nera); baffetti corti. Nella destra la pistola tenuta bassa (nel
gioco il braccio la alza e la bocca è l'osso "canna"), nella sinistra i guanti di cuoio.
Il corpo, i baffi, il képi e la pistola vengono da foch.py.
"""

import math

from mathutils import Matrix, Vector

import cavallo as C
import foch as Fo
import umano
import vestiti as V

NOME = "DeGaulle"
SIGLA = "DG"

GUANTI = Vector((0.2, -0.06, 0.86))

U = None


def materiali(u):
    u.materiale("Kaki", (0.15, 0.12, 0.065), ruvidita=0.9)
    u.materiale("KakiChiaro", (0.26, 0.21, 0.12), ruvidita=0.85)
    u.materiale("Rosso", (0.42, 0.03, 0.03), ruvidita=0.85)
    u.materiale("NeroVelluto", (0.02, 0.02, 0.025), ruvidita=0.95)
    u.materiale("Oro", (0.85, 0.63, 0.25), metallo=1.0, ruvidita=0.3)
    u.materiale("Argento", (0.85, 0.86, 0.88), metallo=1.0, ruvidita=0.25)
    u.materiale("Nero", (0.025, 0.022, 0.02), ruvidita=0.35)
    u.materiale("Cuoio", (0.30, 0.15, 0.06), ruvidita=0.4)
    u.materiale("Suola", (0.05, 0.035, 0.02), ruvidita=0.8)
    u.materiale("Brunito", (0.12, 0.12, 0.13), metallo=1.0, ruvidita=0.4)
    u.materiale("Noce", (0.30, 0.17, 0.08), ruvidita=0.5)
    u.materiale("Peli", (0.12, 0.08, 0.05), ruvidita=0.8)
    u.materiale("Guanti", (0.40, 0.25, 0.12), ruvidita=0.6)


def posa(sch):
    for s in (1, -1):
        k = umano.sigla(s)
        umano.ruota_mondo(sch, "coscia" + k, (0, 1, 0), 3.0 * s)
        umano.ruota_mondo(sch, "piede" + k, (0, 1, 0), -3.0 * s)
    asse_calcio = Vector((0, -0.98, 0.2)).normalized()
    C.impugna(sch, -1, Fo.PISTOLA, asse_calcio, (1, -0.2, 0), (-0.7, 0.5, -0.4))
    # Sinistra: i guanti stretti nel pugno davanti al fianco.
    C.impugna(sch, 1, GUANTI, (0, -0.3, 1), (-1, 0, -0.2), (0.7, 0.5, -0.4), chiusura=0.85)


def uniforme(u):
    V.pantaloni(u, "Calzoni", "Kaki", t_inizio=0.0, t_fine=1.25, margine=0.02, spessore=0.004)
    V.pantaloni(u, "Gambali", "Cuoio", t_inizio=1.18, t_fine=1.9, margine=0.013, spessore=0.005)
    V.calzature(u, "Stivaletti", "Cuoio", "Suola", taglio=0.13, inclinazione=0.2)
    u.nascondi_pelle()
    V.veste(u, "Vareuse", 1.44, 0.80, "Kaki", margine=0.017, svasatura=0.05, pieghe=0.004, n_pieghe=8,
            spessore=0.007)
    V.maniche(u, "Vareuse_Maniche", "Kaki", t_inizio=-0.15, t_fine=1.9, margine=0.010, spessore=0.005)
    u.nascondi_pelle()
    # Colletto aperto: la camicia in alto e la cravatta che scende nello scollo a V.
    collo = V.anello_sul_corpo(u, (0, -0.005, 1.48), (0, 0.12, 1), 0.006, 0.035, n=40, portata=0.2)
    u.oggetto("Camicia_Colletto", collo, "KakiChiaro", spessore=0.004)
    punti, normali = [], []
    for i in range(8):
        z = 1.46 - i * 0.022
        d = Vector((0, -1, 0))
        punti.append(u.sulla_pelle(Vector((0, 0, z)), d, 0.02, 0.35))
        normali.append(d)
    u.oggetto("Cravatta", V.striscia(punti, normali, 0.03), "Kaki", spessore=0.004)
    revers = []
    for s in (1, -1):
        punti, normali = [], []
        for i in range(7):
            t = i / 6
            z = 1.45 - t * 0.17
            d = Vector((s * (0.45 - 0.4 * t), -1, 0)).normalized()
            punti.append(u.sulla_pelle(Vector((0, 0, z)), d, 0.025, 0.35))
            normali.append(d)
        revers.append(V.striscia(punti, normali, 0.045))
    u.oggetto("Revers", V.unisci(*revers), "Kaki", spessore=0.004)
    # Bottoni e pattine delle tasche.
    bottoni, pattine = [], []
    for z in (1.24, 1.13, 0.92, 0.84):
        p = u.sulla_pelle(Vector((0, 0, z)), Vector((0, -1, 0)), 0.031, 0.35)
        bottoni.append(V.sfera(p, (0.009, 0.006, 0.009), 8, 5))
    for z, x, largo in ((1.33, 0.085, 0.10), (0.90, 0.11, 0.13)):
        for s in (1, -1):
            d = Vector((s * x, -0.17, 0)).normalized()
            p = u.sulla_pelle(Vector((0, 0, z)), d, 0.029, 0.35)
            m = Matrix.Rotation(math.atan2(d.x, -d.y), 4, "Z")
            pattine.append(V.scatola(p, (largo, 0.008, 0.035), m))
            bottoni.append(V.sfera(p + Vector((0, -0.006, -0.005)), (0.007, 0.005, 0.007), 8, 5))
    u.oggetto("Bottoni", V.unisci(*bottoni), "Oro")
    u.oggetto("Tasche", V.unisci(*pattine), "Kaki")
    # Cinturone con la bretella a tracolla (dalla spalla destra al fianco sinistro, davanti e dietro).
    u.oggetto("Cinturone", V.anello_sul_corpo(u, (0, 0.01, 1.0), (0, 0, 1), 0.05, 0.045, n=64, portata=0.3),
              "Cuoio", spessore=0.005)
    V.cinghia_busto(u, "Bretella", "Cuoio", (-0.13, -0.06, 1.43), (0.13, -0.10, 1.01), larghezza=0.03,
                    distacco=0.03)
    V.cinghia_busto(u, "Bretella_Dietro", "Cuoio", (-0.13, 0.06, 1.43), (0.13, 0.10, 1.01), larghezza=0.03,
                    distacco=0.03)
    p = u.sulla_pelle(Vector((0, 0, 1.0)), Vector((0, -1, 0)), 0.056, 0.35)
    u.oggetto("Fibbia", V.scatola(p, (0.05, 0.008, 0.05)), "Oro")
    # Fondina al fianco destro.
    p = u.sulla_pelle(Vector((0, 0, 0.94)), Vector((-1, 0.15, 0)).normalized(), 0.05, 0.35)
    u.oggetto("Fondina", V.scatola(p, (0.04, 0.10, 0.15), Matrix.Rotation(math.radians(10), 4, "X")), "Cuoio")


def guanti(u):
    pezzi = []
    for k in range(2):
        a = GUANTI + Vector((0.0, -0.01 * k, 0.11))
        b = GUANTI + Vector((0.01, -0.02 + 0.02 * k, -0.11))
        pezzi.append(V.tubo_lungo([a, GUANTI + Vector((0.012, -0.01 * k, 0)), b], [0.018, 0.016, 0.012], n=8))
    u.oggetto("Guanti", V.unisci(*pezzi), "Guanti")


def costruisci():
    global U
    u = V.Unita(NOME, SIGLA)
    U = u
    Fo.U = u
    materiali(u)
    u.costruisci_corpo(posa, barba=0.3)
    uniforme(u)
    Fo.baffi(u, scala=0.55, fino=0.45)
    Fo.kepi(u, fascia_mat="NeroVelluto", calotta_mat="Rosso", foglie="Oro", stelle=2)
    Fo.revolver(u)
    guanti(u)
    triangoli = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in u.col.objects if o.type == "MESH")
    return {"oggetti": len(u.col.objects), "triangoli": triangoli}


def esporta(triangoli=5200, lato=512):
    import esporta as E
    r = E.prepara(NOME, U.giunti,
                  rigidi={"Pistola_*": "mano.R", "Guanti*": "mano.L", "Occhio*": "testa", "Kepi_*": "testa",
                          "Baffi*": "testa"},
                  escludi=["Stivaletti", "Stivaletti.0*", "Bottoni*", "Tasche*", "Fibbia*", "Cravatta*", "Revers*",
                           "Kepi_Galloni*", "Kepi_Bordo*", "Kepi_Foglie*", "Kepi_Stelle*", "Camicia_Colletto*"],
                  quote={"Stivaletti*": 240, "Occhio*": 60, "Vareuse.*": 520, "Vareuse": 520,
                         "Vareuse_Maniche*": 300, "Calzoni*": 200, "Gambali*": 200, "Cinturone*": 80,
                         "Bretella*": 60, "Fondina*": 12, "Kepi_Fascia*": 120, "Kepi_Calotta*": 140,
                         "Kepi_Visiera*": 60, "Baffi*": 40, "Pistola_*": 80, "Guanti*": 60},
                  togli_dal_corpo=[SIGLA + "_Nascosta"], triangoli=triangoli, corpo=U.corpo.name,
                  extra={"canna": ("mano.R", Fo.BOCCA)})
    E.cuoci(lato=lato)
    return r
