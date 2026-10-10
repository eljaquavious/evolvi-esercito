"""Ferdinand Foch (1851-1929), maresciallo di Francia: il comandante "Foch" del Novecento.

Riferimenti: le foto del 1918 (Compiègne, Senlis) e i ritratti ufficiali. Vareuse blu orizzonte a un petto
con i bottoni dorati, colletto in piedi e quattro tasche con la pattina, cinturone di cuoio marrone con la
fibbia; calzoni da cavallerizzo blu orizzonte e alti stivali neri; il képi da maresciallo (calotta rossa,
fascia coperta da tre file di foglie di quercia ricamate in oro, visiera nera bordata d'oro); baffi grigi
folti, le nastrine delle decorazioni sul petto. Nella sinistra il bastone da maresciallo (velluto blu con le
stelle d'oro), nella destra la pistola d'ordinanza (revolver Mle 1892) tenuta bassa lungo il fianco: nel
gioco il braccio la alza per sparare e la bocca della canna è l'osso "canna".
"""

import math

import bmesh
from mathutils import Matrix, Vector

import cavallo as C
import umano
import vestiti as V

NOME = "Foch"
SIGLA = "FO"

PISTOLA = Vector((-0.215, -0.10, 0.86))                  # pugno destro sul calcio del revolver
CANNA = Vector((0.0, -0.2, -0.98)).normalized()          # verso della canna (giù lungo il fianco)
BASTONE = Vector((0.215, -0.12, 0.88))                   # pugno sinistro sul bastone
VERSO_BASTONE = Vector((0.1, -0.75, -0.65)).normalized()

U = None
BOCCA = None


def materiali(u):
    u.materiale("Blu", (0.24, 0.32, 0.43), ruvidita=0.9)
    u.materiale("BluScuro", (0.15, 0.20, 0.28), ruvidita=0.9)
    u.materiale("Rosso", (0.42, 0.03, 0.03), ruvidita=0.85)
    u.materiale("Oro", (0.85, 0.63, 0.25), metallo=1.0, ruvidita=0.3)
    u.materiale("Nero", (0.025, 0.022, 0.02), ruvidita=0.35)
    u.materiale("Suola", (0.05, 0.035, 0.02), ruvidita=0.8)
    u.materiale("Cuoio", (0.30, 0.16, 0.07), ruvidita=0.55)
    u.materiale("Velluto", (0.06, 0.09, 0.30), ruvidita=0.95)
    u.materiale("Brunito", (0.12, 0.12, 0.13), metallo=1.0, ruvidita=0.4)
    u.materiale("Noce", (0.30, 0.17, 0.08), ruvidita=0.5)
    u.materiale("Peli", (0.62, 0.60, 0.57), ruvidita=0.8)
    for nome, colore in (("NastroRosso", (0.55, 0.03, 0.03)), ("NastroVerde", (0.05, 0.30, 0.08)),
                         ("NastroGiallo", (0.75, 0.55, 0.08)), ("NastroBlu", (0.05, 0.12, 0.45))):
        u.materiale(nome, colore, ruvidita=0.7)


# Posa ----------------------------------------------------------------------------------------------

def posa(sch):
    for s in (1, -1):
        k = umano.sigla(s)
        umano.ruota_mondo(sch, "coscia" + k, (0, 1, 0), 3.5 * s)
        umano.ruota_mondo(sch, "piede" + k, (0, 1, 0), -3.5 * s)
    # Il mento un po' su, lo sguardo fiero.
    umano.ruota_mondo(sch, "testa", (1, 0, 0), -5)
    # Destra: revolver basso, il pollice lungo il calcio verso l'alto, le dita attorno.
    asse_calcio = Vector((0, -0.98, 0.2)).normalized()
    C.impugna(sch, -1, PISTOLA, asse_calcio, (1, -0.2, 0), (-0.7, 0.5, -0.4))
    # Sinistra: il bastone stretto nel pugno, in avanti e in basso.
    C.impugna(sch, 1, BASTONE, VERSO_BASTONE, (-0.25, 0, -1), (0.7, 0.5, -0.4))


# Uniforme ------------------------------------------------------------------------------------------

def uniforme(u):
    V.pantaloni(u, "Calzoni", "Blu", t_inizio=0.0, t_fine=1.2, margine=0.02, spessore=0.004)
    V.pantaloni(u, "Stivali", "Nero", t_inizio=1.02, t_fine=1.94, margine=0.012, spessore=0.005)
    V.calzature(u, "Stivali_Piede", "Nero", "Suola", taglio=0.16, inclinazione=0.2)
    u.nascondi_pelle()
    V.veste(u, "Vareuse", 1.46, 0.80, "Blu", margine=0.026, svasatura=0.05, pieghe=0.004, n_pieghe=8,
            spessore=0.007)
    V.maniche(u, "Vareuse_Maniche", "Blu", t_inizio=-0.15, t_fine=1.9, margine=0.016, spessore=0.005)
    u.nascondi_pelle()
    collo = V.anello_sul_corpo(u, (0, -0.005, 1.475), (0, 0.12, 1), 0.012, 0.045, n=40, portata=0.2)
    u.oggetto("Vareuse_Colletto", collo, "Blu", spessore=0.006)
    # Bottoni dorati a un petto e le pattine delle quattro tasche.
    bottoni, pattine = [], []
    for z in (1.40, 1.31, 1.22, 1.13, 1.05, 0.95, 0.87):
        if abs(z - 1.0) < 0.03:
            continue
        p = u.sulla_pelle(Vector((0, 0, z)), Vector((0, -1, 0)), 0.04, 0.35)
        bottoni.append(V.sfera(p, (0.009, 0.006, 0.009), 8, 5))
    for z, x, largo in ((1.33, 0.085, 0.10), (0.90, 0.11, 0.13)):
        for s in (1, -1):
            d = Vector((s * x, -0.17, 0)).normalized()
            p = u.sulla_pelle(Vector((0, 0, z)), d, 0.038, 0.35)
            m = Matrix.Rotation(math.atan2(d.x, -d.y), 4, "Z")
            pattine.append(V.scatola(p, (largo, 0.008, 0.035), m))
            bottoni.append(V.sfera(p + Vector((0, -0.006, -0.005)), (0.007, 0.005, 0.007), 8, 5))
    u.oggetto("Bottoni", V.unisci(*bottoni), "Oro")
    u.oggetto("Tasche", V.unisci(*pattine), "Blu")
    # Nastrine delle decorazioni sul petto sinistro, sopra la tasca.
    righe = [("NastroRosso", "NastroVerde", "NastroGiallo"), ("NastroBlu", "NastroRosso", "NastroVerde")]
    for i, riga in enumerate(righe):
        for j, mat in enumerate(riga):
            x = 0.055 + j * 0.028
            d = Vector((x, -0.17, 0)).normalized()
            p = u.sulla_pelle(Vector((0, 0, 1.40 - i * 0.016)), d, 0.036, 0.35)
            u.oggetto("Nastrine_%d%d" % (i, j), V.scatola(p, (0.027, 0.006, 0.014),
                                                          Matrix.Rotation(math.atan2(d.x, -d.y), 4, "Z")), mat)
    # Cinturone marrone con la fibbia dorata.
    u.oggetto("Cinturone", V.anello_sul_corpo(u, (0, 0.01, 1.0), (0, 0, 1), 0.05, 0.045, n=64, portata=0.3),
              "Cuoio", spessore=0.005)
    p = u.sulla_pelle(Vector((0, 0, 1.0)), Vector((0, -1, 0)), 0.056, 0.35)
    u.oggetto("Fibbia", V.scatola(p, (0.05, 0.008, 0.05)), "Oro")


def kepi(u):
    """Képi da maresciallo: fascia d'oro (le foglie di quercia), calotta rossa inclinata in avanti, visiera."""
    n = 40
    centro_y = -0.02
    bordo = []
    for j in range(n):
        a = 2 * math.pi * j / n
        d = Vector((math.cos(a), math.sin(a), 0))
        z = 1.725 - 0.025 * max(0.0, d.y)
        bordo.append(u.sulla_pelle(Vector((0, centro_y, z)), d, 0.012, 0.2))
    centro = sum(bordo, Vector()) / n

    def anello(t):
        # t = 0 sul bordo, 1 in cima; la cima è più stretta, spostata in avanti e più bassa davanti.
        out = []
        for p in bordo:
            r = p - Vector((centro.x, centro.y, p.z))
            dietro = max(0.0, r.normalized().y)
            alto = 0.085 + 0.03 * dietro
            q = Vector((centro.x, centro.y - 0.018 * t, p.z)) + r * (1 - 0.1 * t)
            out.append(q + Vector((0, 0, alto * t)))
        return out

    fascia = V.griglia([anello(t) for t in (0.0, 0.25, 0.48)], chiusa=True)
    V._verso_fuori(fascia)
    u.oggetto("Kepi_Fascia", fascia, "Oro", spessore=0.003)
    calotta = V.griglia([anello(t) for t in (0.48, 0.75, 1.0)], chiusa=True)
    calotta.verts.ensure_lookup_table()
    calotta.faces.new([calotta.verts[len(calotta.verts) - n + j] for j in range(n)])
    V._verso_fuori(calotta)
    u.oggetto("Kepi_Calotta", calotta, "Rosso", spessore=0.003)
    # Visiera nera piatta, appena calata, con il bordo dorato.
    davanti = [p for p in bordo if (p - centro).normalized().y < -0.25]
    davanti.sort(key=lambda p: p.x)
    dentro, fuori = [], []
    for p in davanti:
        r = Vector((p.x - centro.x, p.y - centro.y, 0)).normalized()
        dentro.append(p + Vector((0, 0, 0.004)))
        fuori.append(p + r * 0.06 + Vector((0, -0.02, -0.025)))
    u.oggetto("Kepi_Visiera", V.griglia([dentro, fuori]), "Nero", spessore=0.004)
    u.oggetto("Kepi_Bordo", V.tubo_lungo(fuori, 0.004, n=6), "Oro")
    # Galloni d'oro sulla calotta (le soutaches): una croce sulla cima e i montanti.
    cima = anello(1.0)
    croce = [V.tubo_lungo([cima[0] + Vector((0, 0, 0.002)), cima[n // 2] + Vector((0, 0, 0.002))], 0.003, n=5),
             V.tubo_lungo([cima[n // 4] + Vector((0, 0, 0.002)), cima[3 * n // 4] + Vector((0, 0, 0.002))], 0.003, n=5)]
    for j in (0, n // 4, n // 2, 3 * n // 4):
        croce.append(V.tubo_lungo([anello(0.5)[j], anello(0.97)[j]], 0.0035, n=5))
    u.oggetto("Kepi_Galloni", V.unisci(*croce), "Oro")


# Pistola e bastone ---------------------------------------------------------------------------------

def revolver(u):
    global BOCCA
    lato = CANNA.cross(Vector((1, 0, 0))).normalized()     # perpendicolare alla canna, verso l'alto del calcio
    su = -lato if lato.dot(Vector((0, -1, 0))) < 0 else lato
    m = Matrix((CANNA.cross(su), CANNA, su)).transposed().to_4x4()
    m.translation = PISTOLA

    def P(x, y, z):
        return m @ Vector((x, y, z))

    calcio = V.trasforma(V.scatola((0, 0, 0), (0.026, 0.035, 0.09)), m @ Matrix.Rotation(math.radians(-15), 4, "X"))
    u.oggetto("Pistola_Calcio", calcio, "Noce")
    ferro = [V.scatola(P(0, 0.03, 0.06), (0.026, 0.06, 0.04)),                     # castello
             V.cilindro(P(0, 0.035, 0.055), P(0, 0.075, 0.055), 0.021, n=10),       # tamburo
             V.cilindro(P(0, 0.07, 0.07), P(0, 0.20, 0.07), 0.008, n=8),            # canna
             V.cilindro(P(0, 0.07, 0.055), P(0, 0.16, 0.055), 0.006, n=6),          # bacchetta
             V.cilindro(P(0, 0.0, 0.01), P(0, 0.04, 0.0), 0.004, n=6)]              # ponticello
    u.oggetto("Pistola_Ferro", V.unisci(*ferro), "Brunito", liscio=False)
    BOCCA = P(0, 0.20, 0.07)


def bastone(u):
    coda = BASTONE - VERSO_BASTONE * 0.12
    cima = BASTONE + VERSO_BASTONE * 0.34
    u.oggetto("Bastone", V.cilindro(coda, cima, 0.021, n=14), "Velluto")
    capi = [V.cilindro(coda - VERSO_BASTONE * 0.018, coda + VERSO_BASTONE * 0.02, 0.024, n=14),
            V.cilindro(cima - VERSO_BASTONE * 0.02, cima + VERSO_BASTONE * 0.018, 0.024, n=14)]
    lato = VERSO_BASTONE.cross(Vector((0, 0, 1))).normalized()
    for i in range(5):
        t = 0.06 + i * 0.065
        for k in range(4):
            d = Matrix.Rotation(math.pi / 2 * k + i * 0.7, 3, VERSO_BASTONE) @ lato
            capi.append(V.sfera(BASTONE + VERSO_BASTONE * t + d * 0.021, (0.008, 0.008, 0.008), 6, 4))
    u.oggetto("Bastone_Oro", V.unisci(*capi), "Oro")


# Tutto ---------------------------------------------------------------------------------------------

def costruisci():
    global U
    u = V.Unita(NOME, SIGLA)
    U = u
    materiali(u)
    u.costruisci_corpo(posa, barba=0.2)
    uniforme(u)
    V.baffi(u, "Baffi", "Peli", folti=1.5)
    kepi(u)
    revolver(u)
    bastone(u)
    triangoli = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in u.col.objects if o.type == "MESH")
    return {"oggetti": len(u.col.objects), "triangoli": triangoli}


def esporta(triangoli=5200, lato=512):
    import esporta as E
    r = E.prepara(NOME, U.giunti,
                  rigidi={"Pistola_*": "mano.R", "Bastone*": "mano.L", "Occhio*": "testa", "Kepi_*": "testa",
                          "Baffi*": "testa"},
                  escludi=["Stivali_Piede", "Stivali_Piede.0*", "Bottoni*", "Tasche*", "Nastrine_*", "Fibbia*",
                           "Kepi_Galloni*", "Kepi_Bordo*", "Bastone_Oro*"],
                  quote={"Stivali_Piede*": 240, "Occhio*": 60, "Vareuse.*": 520, "Vareuse": 520,
                         "Vareuse_Maniche*": 300, "Vareuse_Colletto*": 60, "Calzoni*": 200, "Stivali*": 220,
                         "Cinturone*": 80, "Kepi_Fascia*": 120, "Kepi_Calotta*": 140, "Kepi_Visiera*": 60,
                         "Baffi*": 100, "Pistola_*": 80, "Bastone*": 60},
                  togli_dal_corpo=[SIGLA + "_Nascosta"], triangoli=triangoli, corpo=U.corpo.name,
                  extra={"canna": ("mano.R", BOCCA)})
    E.cuoci(lato=lato)
    return r
