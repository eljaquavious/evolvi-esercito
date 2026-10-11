"""Cavalieri a blocchi sui cavalli dei vecchi modelli (Compagno, Cavaliere, Annibale, Guglielmo).

Il cavallo resta quello di prima (geometria e ossa), con la texture ricotta da cavalli.py in fondo
all'atlante; sopra siede un personaggio a blocchi come quelli di soldati.py. L'osso "bacino" del
cavaliere è figlio di "cavallo", come prima, così l'Animatore lo muove insieme al cavallo.

Uso: python3 tools/blocchi/cavalieri.py [Nome ...] [--glb cartella]
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cavalli  # noqa: E402
import meshdati  # noqa: E402
from costruttore import Modello, chiaro, scuro, unisci  # noqa: E402
from soldati import (  # noqa: E402
    BRACCIO_L, BUSTO_L, BUSTO_P, GAMBA_L, GAMBA_P, GAMBE, PELLI, TESTA, asta, capelli_lati, capelli_retro,
    corpo, elmo_scatola, lama, punto_mano, scheletro, tinta, viso,
)

LATO = 512
BANDA_CAVALLO = 232  # pixel in fondo all'atlante per il cavallo
SELLA = 0.93  # altezza del bacino del cavaliere (come nei vecchi modelli)
SCALA = 0.84  # il cavaliere a blocchi è un po' più piccolo del soldato a piedi, per stare in sella
SEDUTA = np.array([0, SELLA, 0.02])
LANCIA = np.array([0, -0.2, -1.0]) / np.linalg.norm([0, -0.2, -1.0])  # come POSE.cavalleriaMesh


def base(nome, vecchio, mano_l=(0.05, -0.6, -1)):
    m = Modello(nome, LATO)
    m.altezza_utile = LATO - BANDA_CAVALLO - 2
    for o in cavalli.ossa_cavallo(vecchio):
        m.osso(o["nome"], o["padre"], o["posizione"])
    # Avambraccio destro in avanti, lungo la lancia in resta; il sinistro tiene le redini (o lo scudo).
    scheletro(m, mano_r=(0, -0.2, -1), mano_l=mano_l, bacino_y=SELLA)
    m.ossa[m.indice_ossa["bacino"]]["padre"] = "cavallo"
    m.ossa[m.indice_ossa["bacino"]]["posizione"][2] = 0.02
    # Gambe a cavalcioni: le cosce si aprono attorno al dorso, gli stinchi scendono lungo i fianchi.
    # Le posizioni sono quelle finali, dopo il rimpicciolimento attorno alla seduta (vedi costruisci).
    prima = lambda p: list(SEDUTA + (np.array(p) - SEDUTA) / SCALA)
    for lato, s in (("L", -1), ("R", 1)):
        m.ossa[m.indice_ossa["coscia." + lato]]["posizione"] = prima([s * 0.15, SELLA, 0.02])
        m.ossa[m.indice_ossa["stinco." + lato]]["posizione"] = prima([s * 0.38, 0.76, -0.25])
        m.ossa[m.indice_ossa["piede." + lato]]["posizione"] = prima([s * 0.40, 0.38, -0.16])
    return m


def gambe(m, coscia, stinco, piede):
    P = m.posizione_osso
    for lato in ("L", "R"):
        anca, ginocchio, caviglia = P("coscia." + lato), P("stinco." + lato), P("piede." + lato)
        m.segmento("coscia." + lato, anca + np.array([0, 0.03, 0.06]), ginocchio, GAMBA_L, GAMBA_P,
                   {"tutte": coscia}, oltre=(0, 0.06))
        m.segmento("stinco." + lato, ginocchio, caviglia, GAMBA_L * 0.98, GAMBA_P * 0.98, {"tutte": stinco},
                   oltre=(0.04, 0.02))
        m.scatola("piede." + lato, caviglia + np.array([0, -0.06, -0.04]), (GAMBA_L * 0.98, 0.09, GAMBA_P + 0.06),
                  {"tutte": piede})


def testa_y(m):
    return m.posizione_osso("testa")[1]


def lancia(m, avanti, dietro, c_asta, c_punta="#B8BCC4", pennone=None):
    """Lancia in resta nel pugno destro, lungo la direzione dell'affondo."""
    pugno, _ = punto_mano(m, "R")
    punta = pugno + LANCIA * avanti
    coda = pugno - LANCIA * dietro
    asta(m, "mano.R", punta, coda, 0.045, c_asta)
    lama(m, "mano.R", punta + LANCIA * 0.3, punta, 0.06, 0.02, c_punta, piatto=(1, 0, 0))
    if pennone:
        # Banderuola dietro la punta, appesa sotto l'asta.
        centro = punta - LANCIA * 0.22 + np.array([0, -0.1, 0])
        m.scatola("mano.R", centro, (0.015, 0.2, 0.36), {"tutte": pennone})


def scudo_a_gradini(m, larghezze, altezza, pittore, retro, centro_y=0.0, avanti=0.0):
    """Scudo sul braccio sinistro, rivolto in fuori: lastre sovrapposte sempre più strette verso il basso
    (scudo a mandorla o a triangolo, a blocchi). pittore(pen, u0, u1, v0, v1) dipinge la lastra nella
    porzione u0-u1 / v0-v1 dello scudo intero."""
    pugno, _ = punto_mano(m, "L")
    assi = np.column_stack([[0, 0, 1], [0, 1, 0], [-1, 0, 0]])  # fronte dello scudo verso -X (fuori)
    n = len(larghezze)
    h = altezza / n
    massima = max(larghezze)
    for i, lw in enumerate(larghezze):
        v0, v1 = i / n, (i + 1) / n
        u0, u1 = (massima - lw) / 2 / massima, 1 - (massima - lw) / 2 / massima
        y = centro_y + altezza / 2 - (i + 0.5) * h

        def pit(pen, u0=u0, u1=u1, v0=v0, v1=v1):
            pittore(pen, u0, u1, v0, v1)
        locale = np.array([-0.1 - 0.002 * i, y, avanti])
        m.scatola("mano.L", pugno + locale, (lw, h + 0.002, 0.04), {"fronte": pit, "tutte": retro}, assi=assi)


class Porzione:
    """Pennello che disegna sulla porzione (u0-u1, v0-v1) di un disegno intero."""

    def __init__(self, pen, u0, u1, v0, v1):
        self.pen, self.u0, self.u1, self.v0, self.v1 = pen, u0, u1, v0, v1

    def _uv(self, u, v):
        return (u - self.u0) / (self.u1 - self.u0), (v - self.v0) / (self.v1 - self.v0)

    def riempi(self, c, materiale="stoffa"):
        self.pen.riempi(c, materiale)

    def rett(self, u0, v0, u1, v1, c):
        a, b = self._uv(u0, v0)
        d, e = self._uv(u1, v1)
        self.pen.rett(a, b, d, e, c)

    def ellisse(self, u0, v0, u1, v1, c):
        a, b = self._uv(u0, v0)
        d, e = self._uv(u1, v1)
        self.pen.ellisse(a, b, d, e, c)

    def poligono(self, punti, c):
        self.pen.poligono([self._uv(u, v) for u, v in punti], c)


def giglio(pen, u, v, r, c):
    """Fiordaliso stilizzato centrato in (u, v), alto circa 2r."""
    pen.poligono([(u, v - r), (u + r * 0.35, v), (u, v + r * 0.6), (u - r * 0.35, v)], c)
    pen.poligono([(u - r * 0.9, v - r * 0.4), (u - r * 0.3, v - r * 0.05), (u - r * 0.3, v + r * 0.3)], c)
    pen.poligono([(u + r * 0.9, v - r * 0.4), (u + r * 0.3, v - r * 0.05), (u + r * 0.3, v + r * 0.3)], c)
    pen.rett(u - r * 0.6, v + r * 0.25, u + r * 0.6, v + r * 0.42, c)


def mantello_cavaliere(m, c, bordo=None, basso=SELLA - 0.05):
    alto = testa_y(m) - 0.02

    def p(pen):
        pen.riempi(c)
        if bordo:
            pen.rett(0, 0.93, 1, 1, bordo)
        for u in (0.25, 0.5, 0.75):
            pen.rett(u - 0.02, 0.12, u + 0.02, 1, scuro(c, 0.18))
    m.scatola("torace", (0, (alto + basso) / 2, BUSTO_P / 2 + 0.03), (BUSTO_L + 0.06, alto - basso, 0.04), {"tutte": p},
              pesi=[("torace", 0.7), ("spina", 0.3)])


def maglia(c="#7E848C"):
    def p(pen):
        pen.riempi(c, "metallo")
        pen.maglia(chiaro(c, 0.3), scuro(c, 0.35))
    return p


# -- I quattro cavalieri ---------------------------------------------------------------------------------

def Cavaliere(vecchio):
    """Cavaliere francese del Trecento: elmo a secchiello, sopravveste blu coi gigli, scudo e lancia."""
    m = base("Cavaliere", vecchio, mano_l=(0.1, -0.55, -1))
    blu, oro = "#2A4E9A", "#E0B848"
    pelle = PELLI[1]

    def sopravveste(pen):
        pen.riempi(blu)
        for u, v in ((0.28, 0.25), (0.72, 0.25), (0.5, 0.5)):
            giglio(pen, u, v, 0.09, oro)
        pen.rett(0, 0.8, 1, 0.87, "#4A3020")  # cintura
        pen.rett(0.45, 0.79, 0.55, 0.88, "#C8A050")

    def lati(pen):
        pen.riempi(blu)

    corpo(m, {
        "busto": sopravveste, "busto_retro": sopravveste, "busto_lati": lati,
        "omero": maglia(), "avambraccio": maglia(), "mano": tinta("#5A4030", "cuoio"),
        "testa": viso(pelle), "testa_lati": capelli_lati(pelle, "#5A3A22"), "testa_retro": capelli_retro("#5A3A22", pelle),
    }, gambe=False)

    def stinco(pen):
        maglia()(pen)
        pen.rett(0, 0.55, 1, 1, "#3A2A1C")
        pen.materiale = "metallo"
    gambe(m, maglia(), stinco, tinta("#3A2A1C", "cuoio"))
    # Elmo a secchiello che copre la testa, con la fessura degli occhi e la croce dei fori.
    acciaio = "#A4AAB2"

    def grande_elmo(pen):
        pen.riempi(acciaio, "metallo")
        pen.rett(0.08, 0.36, 0.92, 0.44, "#1A1C20")
        pen.rett(0.47, 0.44, 0.53, 0.8, scuro(acciaio, 0.35))
        for u in (0.3, 0.38, 0.62, 0.7):
            for v in (0.6, 0.7):
                pen.ellisse(u - 0.015, v - 0.015, u + 0.015, v + 0.015, "#1A1C20")
    elmo_scatola(m, 0.05, -0.01, 0.02, {"fronte": grande_elmo, "tutte": tinta(acciaio, "metallo")})
    m.scatola("testa", (0, testa_y(m) + TESTA + 0.075, 0), (TESTA * 0.7, 0.03, TESTA * 0.7), {"tutte": tinta(acciaio, "metallo")})

    def stemma(pen, u0, u1, v0, v1):
        q = Porzione(pen, u0, u1, v0, v1)
        q.riempi(blu, "legno")
        for u, v in ((0.3, 0.22), (0.7, 0.22), (0.5, 0.55)):
            giglio(q, u, v, 0.1, oro)
    scudo_a_gradini(m, [0.5, 0.48, 0.42, 0.32, 0.2], 0.62, stemma, tinta("#6A4A2A", "legno"), centro_y=0.08)

    def banderuola(pen):
        pen.riempi(blu)
        pen.rett(0, 0, 1, 0.5, "#F0ECE0")
    lancia(m, 2.0, 0.9, "#8A6238", pennone=banderuola)
    return m


def Guglielmo(vecchio):
    """Guglielmo il Conquistatore: elmo conico col nasale, usbergo lungo, scudo a mandorla, mantello."""
    m = base("Guglielmo", vecchio, mano_l=(0.1, -0.55, -1))
    pelle = PELLI[0]
    capelli = "#6A4A2A"
    rosso, oro = "#A0201E", "#E0B848"

    def usbergo(pen):
        maglia("#828890")(pen)
        pen.rett(0, 0.82, 1, 0.9, "#4A3020")
        pen.rett(0.44, 0.81, 0.56, 0.91, oro)

    corpo(m, {
        "busto": usbergo, "busto_retro": usbergo, "busto_lati": usbergo,
        "omero": maglia("#828890"), "avambraccio": maglia("#828890"), "mano": tinta("#5A4030", "cuoio"),
        "testa": viso(pelle, bocca="decisa", baffi=capelli), "testa_lati": capelli_lati(pelle, capelli, 0.5),
        "testa_retro": capelli_retro(capelli, pelle, 0.8),
    }, gambe=False)

    def coscia(pen):  # l'usbergo arriva al ginocchio
        maglia("#828890")(pen)

    def stinco(pen):
        pen.riempi("#5A4A3A")
        for v in np.linspace(0.1, 0.8, 6):  # fasce incrociate
            pen.linea([(0, v), (1, v + 0.1)], "#3A2E22", 0.008)
        pen.rett(0, 0.82, 1, 1, "#3A2A1C")
    gambe(m, coscia, stinco, tinta("#3A2A1C", "cuoio"))
    mantello_cavaliere(m, rosso, bordo=oro)
    # Elmo conico col nasale e una corona sottile d'oro (è il duca).
    elmo = tinta("#8A9098", "metallo")
    H = testa_y(m)
    elmo_scatola(m, 0.02, 0.2, 0.02, {"tutte": elmo})
    m.scatola("testa", (0, H + TESTA + 0.07, 0), (TESTA * 0.7, 0.07, TESTA * 0.7), {"tutte": elmo})
    m.scatola("testa", (0, H + TESTA + 0.12, 0), (TESTA * 0.38, 0.05, TESTA * 0.38), {"tutte": elmo})
    m.scatola("testa", (0, H + TESTA * 0.55, -TESTA / 2 - 0.03), (0.05, 0.18, 0.03), {"tutte": elmo})
    m.scatola("testa", (0, H + TESTA * 0.82, 0), (TESTA + 0.06, 0.04, TESTA + 0.06), {"tutte": tinta(oro, "metallo")})

    def stemma(pen, u0, u1, v0, v1):
        q = Porzione(pen, u0, u1, v0, v1)
        q.riempi(rosso, "legno")
        q.rett(0.44, 0.0, 0.56, 1.0, oro)
        q.rett(0.1, 0.24, 0.9, 0.34, oro)
        q.ellisse(0.4, 0.22, 0.6, 0.36, "#B0B6BE")
    scudo_a_gradini(m, [0.46, 0.44, 0.38, 0.3, 0.22, 0.13], 0.86, stemma, tinta("#6A4A2A", "legno"), centro_y=0.0)

    def banderuola(pen):  # il vessillo del papa: bianco con la croce rossa
        pen.riempi("#F0ECE0")
        pen.rett(0.4, 0, 0.55, 1, rosso)
        pen.rett(0, 0.4, 1, 0.58, rosso)
    lancia(m, 2.0, 0.9, "#8A6238", pennone=banderuola)
    return m


def Compagno(vecchio):
    """Compagno di Alessandro: elmo beotico di bronzo, linothorax bianco, clamide e xyston."""
    m = base("Compagno", vecchio, mano_l=(0.05, -0.65, -1))
    pelle = PELLI[2]
    bronzo, porpora = "#B88A44", "#7A2A5A"

    def linothorax(pen):
        pen.riempi("#ECE4CC")
        pen.rett(0, 0.0, 1, 0.08, "#C8B88A")
        pen.rett(0.15, 0.25, 0.85, 0.62, bronzo)  # piastra di squame
        for v in np.linspace(0.3, 0.58, 5):
            for u in np.linspace(0.2, 0.8, 7):
                pen.ellisse(u - 0.04, v - 0.025, u + 0.04, v + 0.035, scuro(bronzo, 0.2))
        pen.rett(0, 0.72, 1, 0.78, porpora)
        for u in np.linspace(0.06, 0.94, 9):  # pteruges
            pen.rett(u - 0.04, 0.8, u + 0.04, 1, "#D8CCA8")

    def lati(pen):
        pen.riempi("#ECE4CC")
        pen.rett(0, 0.72, 1, 0.78, porpora)

    def omero(pen):
        pen.riempi(pelle, "pelle")
        pen.rett(0, 0, 1, 0.35, "#ECE4CC")
        for u in np.linspace(0.12, 0.88, 4):
            pen.rett(u - 0.08, 0.35, u + 0.08, 0.5, "#D8CCA8")

    corpo(m, {
        "busto": linothorax, "busto_retro": lati, "busto_lati": lati,
        "omero": omero, "avambraccio": tinta(pelle, "pelle"), "mano": tinta(pelle, "pelle"),
        "testa": viso(pelle, bocca="decisa", barba="#3A2A1E"), "testa_lati": capelli_lati(pelle, "#3A2A1E", 0.5),
        "testa_retro": capelli_retro("#3A2A1E", pelle, 0.8),
    }, gambe=False)

    def coscia(pen):
        pen.riempi(pelle, "pelle")
        pen.rett(0, 0, 1, 0.3, "#D8CCA8")

    def stinco(pen):  # stivali di cuoio alti
        pen.riempi(pelle, "pelle")
        pen.rett(0, 0.3, 1, 1, "#7A5232")
        pen.rett(0, 0.3, 1, 0.38, "#5A3A22")
    gambe(m, coscia, stinco, tinta("#6A4628", "cuoio"))
    mantello_cavaliere(m, porpora, bordo="#E0B848", basso=SELLA + 0.15)
    # Elmo beotico: calotta con la tesa larga e ondulata.
    H = testa_y(m)
    b = tinta(bronzo, "metallo")
    elmo_scatola(m, 0.06, 0.3, 0.015, {"tutte": b})
    m.scatola("testa", (0, H + 0.3, 0), (TESTA + 0.16, 0.035, TESTA + 0.16), {"tutte": b})
    m.scatola("testa", (0, H + 0.24, 0.04), (TESTA + 0.1, 0.08, TESTA + 0.06), {"tutte": tinta(scuro(bronzo, 0.12), "metallo")})
    lancia(m, 2.2, 1.1, "#9A7448", c_punta="#C8A060")
    return m


def Annibale(vecchio):
    """Annibale: benda sull'occhio perso, barba, corazza di bronzo, elmo crestato, mantello di porpora."""
    m = base("Annibale", vecchio, mano_l=(0.05, -0.6, -1))
    pelle = PELLI[4]
    bronzo, porpora, oro = "#B8843C", "#5E2470", "#E0B848"

    def corazza(pen):
        pen.riempi(bronzo, "metallo")
        pen.linea([(0.5, 0.15), (0.5, 0.7)], scuro(bronzo, 0.3), 0.012)
        for u in (0.3, 0.7):
            pen.linea([(u - 0.15, 0.32), (u, 0.4), (u + 0.15, 0.32)], scuro(bronzo, 0.3), 0.012)
        pen.ellisse(0.42, 0.16, 0.58, 0.28, oro)  # testa di Tanit
        pen.rett(0, 0.74, 1, 0.8, "#A02828")
        for u in np.linspace(0.06, 0.94, 9):
            pen.rett(u - 0.035, 0.82, u + 0.035, 1, "#A02828")

    def omero(pen):
        pen.riempi(pelle, "pelle")
        pen.rett(0, 0, 1, 0.3, bronzo)
        pen.rett(0, 0.3, 1, 0.48, "#A02828")

    corpo(m, {
        "busto": corazza, "busto_retro": tinta(bronzo, "metallo"), "busto_lati": tinta(bronzo, "metallo"),
        "omero": omero, "avambraccio": tinta(pelle, "pelle"), "mano": tinta(pelle, "pelle"),
        "testa": viso(pelle, bocca="decisa", benda=True, barba="#1E1612", baffi="#1E1612"),
        "testa_lati": capelli_lati(pelle, "#1E1612", 0.5), "testa_retro": capelli_retro("#1E1612", pelle, 0.85),
    }, gambe=False)

    def coscia(pen):
        pen.riempi(pelle, "pelle")
        pen.rett(0, 0, 1, 0.35, "#A02828")

    def stinco(pen):  # schinieri di bronzo
        pen.riempi(bronzo, "metallo")
        pen.rett(0, 0, 1, 0.08, scuro(bronzo, 0.3))
    gambe(m, coscia, stinco, tinta("#5A3A22", "cuoio"))
    mantello_cavaliere(m, porpora, bordo=oro)
    # Elmo di bronzo con la cresta bianca.
    H = testa_y(m)
    elmo_scatola(m, 0.05, 0.26, 0.02, {"tutte": tinta(bronzo, "metallo")})
    m.scatola("testa", (0, H + TESTA + 0.11, 0.02), (0.08, 0.14, TESTA + 0.08), {"tutte": tinta("#ECE8DC")})
    for x in (-1, 1):  # paraguance
        m.scatola("testa", (x * (TESTA / 2 + 0.025), H + 0.12, -0.08), (0.025, 0.2, 0.18), {"tutte": tinta(bronzo, "metallo")})
    lancia(m, 2.0, 1.0, "#7A5232", c_punta="#C8A060")
    return m


CAVALIERI = {"Compagno": Compagno, "Cavaliere": Cavaliere, "Annibale": Annibale, "Guglielmo": Guglielmo}
ORIGINALI = os.path.join(os.path.dirname(os.path.abspath(__file__)), "originali")


def vecchio_modello(nome):
    """Il modello Blender di partenza, copiato in tools/blocchi/originali/ (src/shared/MeshDati/<nome>
    ora contiene il cavaliere nuovo)."""
    return meshdati.leggi(nome, ORIGINALI)


def costruisci(nome):
    vecchio = vecchio_modello(nome)
    m = CAVALIERI[nome](vecchio)
    dati = m.costruisci(seme=hash(nome) % 1000)
    dati["pos"] = SEDUTA + (dati["pos"] - SEDUTA) * SCALA
    for o in dati["ossa"]:
        if not cavalli._cavallo(o["nome"]):
            o["posizione"] = list(SEDUTA + (np.array(o["posizione"]) - SEDUTA) * SCALA)
    cache = os.environ.get("CACHE_CAVALLI")  # cartella per non ricuocere il cavallo a ogni prova
    if cache and os.path.exists(os.path.join(cache, nome + ".pickle")):
        import pickle
        cav, img = pickle.load(open(os.path.join(cache, nome + ".pickle"), "rb"))
    else:
        cav, img = cavalli.cuoci(vecchio, LATO, BANDA_CAVALLO)
        if cache:
            import pickle
            os.makedirs(cache, exist_ok=True)
            pickle.dump((cav, img), open(os.path.join(cache, nome + ".pickle"), "wb"))
    y0 = LATO - BANDA_CAVALLO
    dati["texture"].paste(img, (0, y0))
    nomi_vecchi = [o["nome"] for o in vecchio["ossa"]]
    mappa = np.array([m.indice_ossa.get(n, 0) for n in nomi_vecchi])
    cavallo = {
        "pos": cav["pos"], "normali": cav["normali"], "triangoli": cav["triangoli"],
        "uv": (cav["uv_px"] + np.array([0, y0])) / LATO,
        "ossa_v": mappa[cav["ossa_v"]], "pesi": cav["pesi"],
    }
    return unisci(dati, cavallo)


def main():
    argomenti = [a for a in sys.argv[1:] if not a.startswith("--")]
    glb = None
    if "--glb" in sys.argv:
        glb = sys.argv[sys.argv.index("--glb") + 1]
        argomenti = [a for a in argomenti if a != glb]
    for nome in argomenti or list(CAVALIERI):
        dati = costruisci(nome)
        meshdati.scrivi(nome, dati, "cavaliere a blocchi sul cavallo del vecchio modello")
        print(nome, len(dati["pos"]), "vertici", len(dati["triangoli"]), "triangoli")
        if glb:
            meshdati.glb(dati, os.path.join(glb, nome + ".glb"))
            dati["texture"].save(os.path.join(glb, nome + ".png"))


if __name__ == "__main__":
    main()
