"""Le truppe delle armate nemiche (una armata fedele per ogni battaglia) e i comandanti nuovi, a blocchi come
quelle di soldati.py e cavalieri.py. Scrive i dati in assets-truppe/_dati/<Nome>: da lì tools/blocchi/esporta_fbx.py
li esporta in FBX per caricarli su Roblox (tools/truppe.ps1 fa tutto il giro).

Uso: python tools/blocchi/nuove.py [Nome ...]   (senza nomi: tutte)
"""
import os
import pickle
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cavalli  # noqa: E402
import meshdati  # noqa: E402
from cavalieri import (  # noqa: E402
    BANDA_CAVALLO, LATO, SCALA, SEDUTA, Porzione, base, gambe, lancia, mantello_cavaliere, maglia, scudo_a_gradini,
    testa_y, vecchio_modello,
)
from costruttore import Modello, chiaro, mescola, scuro, unisci  # noqa: E402
from soldati import (  # noqa: E402
    BUSTO_A, BUSTO_L, BUSTO_P, COLLO, GAMBE, PELLI, TESTA, arco, asta, capelli_lati, capelli_retro, corpo,
    elmo_scatola, faretra, kepi, lama, mantello, pantaloni, pistola, punto_mano, scheletro, scudo_tondo, tinta,
    tunica_gambe, viso,
)

RADICE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
USCITA = os.path.join(RADICE, "assets-truppe", "_dati")
CACHE = os.path.join(RADICE, "assets-truppe", "_cache")

FANTI = {}
CAVALIERI = {}  # nome -> (funzione(vecchio), cavallo di partenza)
SPECIALI = {}  # nome -> funzione() che restituisce già i dati (elefante, veicoli)

LEGNO = "#7A5232"
FERRO = "#8E949C"
BRONZO = "#B07A3A"
CUOIO = "#6E4A2C"
ORO = "#D8B048"

# Assi per uno scudo sul braccio sinistro che guarda in fuori (a sinistra del soldato).
FUORI = np.column_stack([[0, 0, 1], [0, 1, 0], [-1, 0, 0]])


def fante(f):
    FANTI[f.__name__] = f
    return f


def a_cavallo(cavallo):
    def dec(f):
        CAVALIERI[f.__name__] = (f, cavallo)
        return f
    return dec


# -- Pezzi in comune ---------------------------------------------------------------------------------------

def busto_semplice(c, cintura=None, bordo=None, scollo=None):
    def p(pen):
        pen.riempi(c)
        if bordo:
            pen.rett(0, 0, 1, 0.07, bordo)
        if scollo:
            pen.poligono([(0.36, 0), (0.5, 0.16), (0.64, 0)], scollo)
        if cintura:
            pen.rett(0, 0.82, 1, 0.9, cintura)
    return p


def lancia_fante(m, alto=0.95, basso=0.6, c=LEGNO, punta="#B8BCC4", contrappeso=None):
    """Lancia verticale nella destra, con la punta in alto (come il pilum del legionario)."""
    pugno, _ = punto_mano(m, "R")
    m.osso("lancia", "mano.R", m.posizione_osso("mano.R"))
    a = pugno + np.array([0, alto, -0.05])
    b = pugno + np.array([0, -basso, 0.05])
    asta(m, "lancia", a, b, 0.04, c)
    lama(m, "lancia", a + np.array([0, 0.28, -0.01]), a, 0.06, 0.02, punta)
    if contrappeso:
        m.scatola("lancia", b, (0.08, 0.1, 0.08), {"tutte": tinta(contrappeso, "metallo")})


def picca(m, c=LEGNO):
    """Picca lunghissima tenuta con due mani, inclinata in avanti."""
    pugno_r, _ = punto_mano(m, "R")
    pugno_l, _ = punto_mano(m, "L")
    d = pugno_l - pugno_r
    d = d / np.linalg.norm(d)
    punta = pugno_r + d * 2.6
    coda = pugno_r - d * 0.5
    asta(m, "mano.R", punta, coda, 0.04, c)
    lama(m, "mano.R", punta + d * 0.22, punta, 0.05, 0.02)


def fucile(m, lungo=1.05, legno="#6A4428", metallo="#3A3C40", baionetta=True, canna=True):
    """Fucile (o moschetto) basso e pronto come quello del Fante, dalla destra verso la sinistra."""
    pugno_r, _ = punto_mano(m, "R")
    pugno_l, _ = punto_mano(m, "L")
    d = pugno_l - pugno_r
    d = d / np.linalg.norm(d)
    calcio = pugno_r - d * 0.3
    bocca = pugno_r + d * lungo
    m.segmento("mano.R", bocca, calcio, 0.06, 0.09, {"tutte": tinta(legno, "legno")}, alto=(0, 1, 0))
    m.segmento("mano.R", bocca + d * 0.05, pugno_r + d * 0.5, 0.03, 0.03, {"tutte": tinta(metallo, "metallo")})
    if baionetta:
        m.segmento("mano.R", bocca + d * 0.42, bocca, 0.012, 0.025, {"tutte": tinta("#B8BCC4", "metallo")})
    if canna:
        m.osso("canna", "mano.R", bocca)


def balestra(m):
    """Balestra puntata, tenuta come un fucile, con l'arco d'acciaio in fondo."""
    pugno_r, _ = punto_mano(m, "R")
    pugno_l, _ = punto_mano(m, "L")
    d = pugno_l - pugno_r
    d = d / np.linalg.norm(d)
    testa = pugno_r + d * 0.7
    m.segmento("mano.R", testa, pugno_r - d * 0.25, 0.07, 0.08, {"tutte": tinta("#6A4428", "legno")}, alto=(0, 1, 0))
    lato = np.cross(d, [0, 1, 0])
    lato = lato / np.linalg.norm(lato)
    m.segmento("mano.R", testa + lato * 0.36 - d * 0.08, testa - lato * 0.36 - d * 0.08, 0.04, 0.04, {"tutte": tinta("#5A5E66", "metallo")})
    m.segmento("mano.R", testa + lato * 0.34 - d * 0.1, pugno_r + d * 0.1, 0.008, 0.008, {"tutte": tinta("#E8E0C8", "liscio")})
    m.segmento("mano.R", testa - lato * 0.34 - d * 0.1, pugno_r + d * 0.1, 0.008, 0.008, {"tutte": tinta("#E8E0C8", "liscio")})
    m.osso("canna", "mano.R", testa)


def spada_dritta(m, lunga=0.75, c="#C8CCD4", elsa=ORO, curva=False):
    pugno, d = punto_mano(m, "R", 0.06)
    if curva:
        a = pugno + d * 0.1
        b = pugno + d * (0.1 + lunga * 0.6) + np.array([0, 0.06, 0])
        e = b + (d + np.array([0, 0.35, 0])) / np.linalg.norm(d + np.array([0, 0.35, 0])) * lunga * 0.45
        lama(m, "mano.R", b, a, 0.06, 0.015, c)
        lama(m, "mano.R", e, b, 0.055, 0.015, c)
    else:
        lama(m, "mano.R", pugno + d * lunga, pugno + d * 0.1, 0.06, 0.015, c)
    m.segmento("mano.R", pugno + d * 0.1, pugno + d * 0.06, 0.18, 0.04, {"tutte": tinta(elsa, "metallo")})


def scudo_ovale(m, c, retro="#6A4A2A", disegno=None, larghezza=0.52, altezza=0.82):
    """Scudo ovale (a lastre) sul braccio sinistro, rivolto in fuori."""
    pugno_l, _ = punto_mano(m, "L")

    def fronte(pen):
        pen.riempi(c, "legno")
        if disegno:
            disegno(pen)
    centro = pugno_l + np.array([-0.08, 0.04, 0])
    for k, (fu, fv) in enumerate(((1.0, 0.72), (0.74, 1.0), (0.9, 0.9))):
        def pit(pen, fu=fu, fv=fv):
            from soldati import _Sotto
            fronte(_Sotto(pen, fu, fv))
        c_k = centro + FUORI @ np.array([0, 0, -0.002 * k])
        m.scatola("mano.L", c_k, (larghezza * fu, altezza * fv, 0.04), {"fronte": pit, "tutte": tinta(retro, "legno")}, assi=FUORI)


def scudo_rotondo(m, c, disegno=None, diametro=0.7, retro="#6A4A2A"):
    pugno_l, _ = punto_mano(m, "L")

    def p(pen):
        pen.riempi(c, "legno")
        if disegno:
            disegno(pen)
        pen.ellisse(0.4, 0.4, 0.6, 0.6, "#8A8E96")
    scudo_tondo(m, "mano.L", pugno_l + np.array([-0.08, 0.05, 0]), diametro, 0.04, p, tinta(retro, "legno"), assi=FUORI)


def scudo_rettangolo(m, c, disegno=None, larghezza=0.5, altezza=0.8):
    pugno_l, _ = punto_mano(m, "L")

    def p(pen):
        pen.riempi(c, "legno")
        if disegno:
            disegno(pen)
    m.scatola("mano.L", pugno_l + np.array([-0.08, 0.02, 0]), (larghezza, altezza, 0.04),
              {"fronte": p, "tutte": tinta(scuro(c, 0.35), "legno")}, assi=FUORI)


def elmo_conico(m, c=FERRO, nasale=True, y=None):
    H = m.posizione_osso("testa")[1] if y is None else y
    e = tinta(c, "metallo")
    elmo_scatola(m, 0.02, 0.2, 0.02, {"tutte": e})
    m.scatola("testa", (0, H + TESTA + 0.07, 0), (TESTA * 0.7, 0.07, TESTA * 0.7), {"tutte": e})
    m.scatola("testa", (0, H + TESTA + 0.12, 0), (TESTA * 0.38, 0.05, TESTA * 0.38), {"tutte": e})
    if nasale:
        m.scatola("testa", (0, H + TESTA * 0.55, -TESTA / 2 - 0.03), (0.05, 0.18, 0.03), {"tutte": e})


def turbante(m, c="#ECE6D6", altezza=0.16, elmo=None):
    H = m.posizione_osso("testa")[1]

    def p(pen):
        pen.riempi(c)
        for v in (0.3, 0.65):
            pen.linea([(0, v), (1, v + 0.15)], scuro(c, 0.15), 0.01)
    m.scatola("testa", (0, H + TESTA * 0.82 + altezza / 2, 0.01), (TESTA + 0.08, altezza, TESTA + 0.08), {"tutte": p})
    if elmo:
        m.scatola("testa", (0, H + TESTA * 0.82 + altezza + 0.05, 0.01), (TESTA * 0.55, 0.1, TESTA * 0.55), {"tutte": tinta(elmo, "metallo")})
        m.scatola("testa", (0, H + TESTA * 0.82 + altezza + 0.13, 0.01), (0.03, 0.1, 0.03), {"tutte": tinta(elmo, "metallo")})


def cappello_tesa(m, c, alto=0.14, tesa=0.2, piuma=None, y_extra=0.0):
    H = m.posizione_osso("testa")[1]
    m.scatola("testa", (0, H + TESTA + alto / 2 - 0.02 + y_extra, 0), (TESTA * 0.95, alto, TESTA * 0.95), {"tutte": tinta(c, "cuoio")})
    m.scatola("testa", (0, H + TESTA - 0.03 + y_extra, 0), (TESTA + tesa, 0.03, TESTA + tesa), {"tutte": tinta(c, "cuoio")})
    if piuma:
        m.scatola("testa", (0.12, H + TESTA + alto + 0.02 + y_extra, 0.05), (0.06, 0.2, 0.22), {"tutte": tinta(piuma)})


def gualdrappa(m, c, disegno=None, lunga=1.15):
    """Coperta sulla groppa del cavallo (copre la sella del cavallo vecchio), con le misure finali del modello."""
    finale_c = np.array([0.0, 0.6, 0.42])
    finale_m = np.array([0.66, 0.5, lunga])
    centro = SEDUTA + (finale_c - SEDUTA) / SCALA
    misure = finale_m / SCALA

    def p(pen):
        pen.riempi(c)
        pen.rett(0, 0.88, 1, 1, scuro(c, 0.3))
        if disegno:
            disegno(pen)
    m.scatola("cavallo", centro, misure, {"tutte": p, "sopra": tinta(c), "sotto": tinta(scuro(c, 0.3))})


def busto_squame(c, sotto=None, cintura=CUOIO):
    def p(pen):
        pen.riempi(c, "metallo")
        for v in np.linspace(0.06, 0.78, 9):
            for u in np.linspace(0.04, 0.96, 9):
                pen.ellisse(u - 0.05, v - 0.03, u + 0.05, v + 0.05, scuro(c, 0.18))
        pen.rett(0, 0.82, 1, 0.9, cintura)
        if sotto:
            pen.rett(0, 0.9, 1, 1, sotto)
    return p


# == ANTICHITÀ =============================================================================================

@fante
def Immortale():
    """Immortale persiano: veste ricamata, cappuccio di stoffa che copre il mento, lancia col contrappeso
    d'oro, scudo di vimini."""
    m = Modello("Immortale")
    scheletro(m, mano_r=(0, 0.05, -1), mano_l=(0.25, 0.1, -1))
    pelle = PELLI[2]
    veste, ricamo = "#C8A030", "#5A2A6A"

    def busto(pen):
        pen.riempi(veste)
        for u in np.linspace(0.1, 0.9, 5):
            for v in np.linspace(0.1, 0.7, 4):
                pen.rett(u - 0.04, v - 0.03, u + 0.04, v + 0.03, ricamo)
        pen.rett(0, 0.82, 1, 0.9, "#7A2A2A")

    def gambe_veste(pen):
        pen.riempi(veste)
        pen.rett(0, 0.7, 1, 1, ricamo)

    abito = {
        "busto": busto, "busto_retro": busto, "busto_lati": tinta(veste),
        "omero": tinta(veste), "avambraccio": tinta(ricamo), "mano": tinta(pelle, "pelle"),
        "coscia": gambe_veste, "stinco": tinta(ricamo), "piede": tinta("#C89A30", "cuoio"),
        "testa": viso(pelle, bocca="seria", barba="#1E1612", baffi="#1E1612"),
        "testa_lati": tinta("#ECE2C8"), "testa_retro": tinta("#ECE2C8"), "testa_sopra": tinta("#ECE2C8"),
    }
    corpo(m, abito)
    # Cappuccio bianco che avvolge la testa.
    H = m.posizione_osso("testa")[1]
    m.scatola("testa", (0, H + TESTA + 0.04, 0.02), (TESTA + 0.05, 0.09, TESTA + 0.05), {"tutte": tinta("#ECE2C8")})
    lancia_fante(m, contrappeso=ORO)

    def vimini(pen):
        for v in np.linspace(0.05, 0.95, 10):
            pen.rett(0, v - 0.035, 1, v + 0.035, "#B89A5A")
        pen.rett(0, 0, 1, 0.05, "#7A5A2A")
        pen.rett(0, 0.95, 1, 1, "#7A5A2A")
    scudo_rettangolo(m, "#C8AA6A", vimini, 0.48, 0.7)
    faretra(m, "torace", (0.1, GAMBE + BUSTO_A * 0.6, BUSTO_P / 2 + 0.07), 0.5, 20)
    return m


@fante
def Oplita():
    """Oplita spartano delle Termopili: elmo corinzio di bronzo con la cresta, aspis di bronzo con la lambda,
    mantello rosso, schinieri, lancia."""
    m = Modello("Oplita")
    scheletro(m, mano_r=(0, 0.05, -1), mano_l=(0.25, 0.1, -1))
    pelle = PELLI[3]
    rosso = "#A82424"
    coscia, stinco = tunica_gambe(rosso, pelle, calzari="#5A3A22", orlo=0.35)

    def corazza(pen):
        pen.riempi(BRONZO, "metallo")
        pen.linea([(0.5, 0.15), (0.5, 0.7)], scuro(BRONZO, 0.3), 0.012)
        for u in (0.3, 0.7):
            pen.linea([(u - 0.15, 0.3), (u, 0.38), (u + 0.15, 0.3)], scuro(BRONZO, 0.3), 0.012)
        pen.rett(0, 0.82, 1, 0.9, CUOIO)

    def gamba_bronzo(pen):  # schinieri
        pen.riempi(pelle, "pelle")
        pen.rett(0, 0.05, 1, 0.85, BRONZO)
    abito = {
        "busto": corazza, "busto_retro": corazza, "busto_lati": tinta(BRONZO, "metallo"),
        "omero": tinta(pelle, "pelle"), "avambraccio": tinta(pelle, "pelle"), "mano": tinta(pelle, "pelle"),
        "coscia": coscia, "stinco": gamba_bronzo, "piede": tinta("#5A3A22", "cuoio"),
        "testa": viso(pelle, bocca="decisa", barba="#2A1C14"),
        "testa_lati": tinta(BRONZO, "metallo"), "testa_retro": tinta(BRONZO, "metallo"), "testa_sopra": tinta(BRONZO, "metallo"),
    }
    corpo(m, abito)
    mantello(m, rosso)
    # Elmo corinzio: calotta che scende sulle guance, fessura a T davanti, cresta di crine.
    H = m.posizione_osso("testa")[1]

    def fronte(pen):
        pen.riempi(BRONZO, "metallo")
        pen.rett(0.1, 0.4, 0.9, 0.52, "#1A1410")
        pen.rett(0.42, 0.5, 0.58, 1.0, "#1A1410")
    elmo_scatola(m, 0.06, 0.02, 0.025, {"fronte": fronte, "tutte": tinta(BRONZO, "metallo")})
    m.scatola("testa", (0, H + TESTA + 0.16, 0.0), (0.07, 0.16, TESTA + 0.14), {"tutte": tinta(rosso)})
    lancia_fante(m)

    def lambda_(pen):
        pen.ellisse(0.05, 0.05, 0.95, 0.95, scuro(BRONZO, 0.2))
        pen.ellisse(0.1, 0.1, 0.9, 0.9, BRONZO)
        pen.poligono([(0.5, 0.22), (0.78, 0.8), (0.66, 0.8), (0.5, 0.42), (0.34, 0.8), (0.22, 0.8)], rosso)
    pugno_l, _ = punto_mano(m, "L")
    scudo_tondo(m, "mano.L", pugno_l + np.array([-0.08, 0.05, 0]), 0.82, 0.05, lambda pen: (pen.riempi(BRONZO, "metallo"), lambda_(pen)),
                tinta("#6A4A2A", "legno"), assi=FUORI)
    return m


@fante
def ArcierePersiano():
    m = Modello("ArcierePersiano")
    scheletro(m, mano_r=(0.2, -1, -0.25), mano_l=(0.1, -0.75, -1))
    pelle = PELLI[2]
    tunica = "#9A3A2A"
    abito = {
        "busto": busto_semplice(tunica, cintura="#C89A30", bordo="#E0C060"), "busto_retro": busto_semplice(tunica, cintura="#C89A30"),
        "busto_lati": tinta(tunica), "omero": tinta(tunica), "avambraccio": tinta(tunica), "mano": tinta(pelle, "pelle"),
        "coscia": tinta("#3A5A7A"), "stinco": pantaloni("#3A5A7A", stivali="#5A3A22", altezza_stivale=0.25)[1],
        "piede": tinta("#5A3A22", "cuoio"),
        "testa": viso(pelle, bocca="seria", barba="#1E1612", baffi="#1E1612"),
        "testa_lati": capelli_lati(pelle, "#1E1612", 0.45), "testa_retro": capelli_retro("#1E1612", pelle, 0.85),
    }
    corpo(m, abito)
    # Berretto frigio di feltro.
    H = m.posizione_osso("testa")[1]
    feltro = tinta("#E6D6AA")
    m.scatola("testa", (0, H + TESTA + 0.03, 0.01), (TESTA + 0.04, 0.08, TESTA + 0.04), {"tutte": feltro})
    m.scatola("testa", (0, H + TESTA + 0.1, -0.06), (TESTA * 0.6, 0.1, TESTA * 0.6), {"tutte": feltro})
    pugno, _ = punto_mano(m, "L")
    m.osso("arco", "mano.L", pugno)
    arco(m, "arco", pugno, 1.15, 0.18, c="#4A2E1A")
    faretra(m, "bacino", (BUSTO_L / 2 + 0.07, GAMBE - 0.05, 0.05), 0.5, 12, c="#7A3A2A")
    return m


@a_cavallo("Compagno")
def CavalleriaPersiana(vecchio):
    m = base("CavalleriaPersiana", vecchio, mano_l=(0.05, -0.6, -1))
    pelle = PELLI[2]
    corpo(m, {
        "busto": busto_squame("#A88A4A", cintura="#7A2A2A"), "busto_retro": busto_squame("#A88A4A"), "busto_lati": tinta("#A88A4A", "metallo"),
        "omero": tinta("#6A2A6A"), "avambraccio": tinta("#6A2A6A"), "mano": tinta(pelle, "pelle"),
        "testa": viso(pelle, bocca="decisa", barba="#1E1612", baffi="#1E1612"),
        "testa_lati": tinta("#D8C8A0"), "testa_retro": tinta("#D8C8A0"),
    }, gambe=False)
    gambe(m, tinta("#3A5A7A"), tinta("#3A5A7A"), tinta("#5A3A22", "cuoio"))
    H = testa_y(m)
    m.scatola("testa", (0, H + TESTA + 0.04, 0.01), (TESTA + 0.05, 0.1, TESTA + 0.05), {"tutte": tinta("#D8C8A0")})
    gualdrappa(m, "#6A2A6A", lambda pen: pen.rett(0, 0.7, 1, 0.8, "#C89A30"))
    lancia(m, 1.8, 0.8, "#8A6238")
    return m


@fante
def LanciereLibico():
    """Fante libico di Annibale: elmo di bronzo, cotta di lino, scudo ovale bianco col segno di Tanit."""
    m = Modello("LanciereLibico")
    scheletro(m, mano_r=(0, 0.05, -1), mano_l=(0.25, 0.1, -1))
    pelle = PELLI[4]
    coscia, stinco = tunica_gambe("#E8DFC8", pelle, calzari="#5A3A22", orlo=0.45)

    def lino(pen):
        pen.riempi("#E8DFC8")
        pen.rett(0, 0, 1, 0.1, "#A02828")
        pen.rett(0.15, 0.2, 0.85, 0.6, scuro("#E8DFC8", 0.08))
        pen.rett(0, 0.82, 1, 0.9, CUOIO)
    abito = {
        "busto": lino, "busto_retro": lino, "busto_lati": tinta("#E8DFC8"),
        "omero": tinta("#E8DFC8"), "avambraccio": tinta(pelle, "pelle"), "mano": tinta(pelle, "pelle"),
        "coscia": coscia, "stinco": stinco, "piede": tinta("#5A3A22", "cuoio"),
        "testa": viso(pelle, bocca="decisa", barba="#1A1410"), "testa_lati": capelli_lati(pelle, "#1A1410", 0.4),
        "testa_retro": capelli_retro("#1A1410", pelle, 0.8),
    }
    corpo(m, abito)
    H = m.posizione_osso("testa")[1]
    b = tinta(BRONZO, "metallo")
    elmo_scatola(m, 0.04, 0.24, 0.02, {"tutte": b})
    m.scatola("testa", (0, H + TESTA + 0.09, 0), (0.06, 0.08, 0.06), {"tutte": b})  # bottone in cima
    for x in (-1, 1):
        m.scatola("testa", (x * (TESTA / 2 + 0.02), H + 0.13, -0.08), (0.025, 0.2, 0.18), {"tutte": b})
    lancia_fante(m)

    def tanit(pen):
        pen.poligono([(0.5, 0.35), (0.65, 0.75), (0.35, 0.75)], "#A02828")
        pen.ellisse(0.42, 0.18, 0.58, 0.34, "#A02828")
        pen.rett(0.32, 0.36, 0.68, 0.41, "#A02828")
    scudo_ovale(m, "#ECE6D6", disegno=tanit)
    return m


@fante
def FrombolieroBaleare():
    """Frombolieri delle Baleari: tunica corta, niente armatura, fionda nella destra e sacca delle pietre."""
    m = Modello("FrombolieroBaleare")
    scheletro(m, mano_r=(0.3, -1, -0.2), mano_l=(0.1, -0.8, -0.8))
    pelle = PELLI[2]
    coscia, stinco = tunica_gambe("#D8CCA8", pelle, calzari="#5A3A22", orlo=0.35)
    abito = {
        "busto": busto_semplice("#D8CCA8", cintura="#5A3A22", scollo=pelle), "busto_retro": busto_semplice("#D8CCA8", cintura="#5A3A22"),
        "busto_lati": tinta("#D8CCA8"), "omero": tinta(pelle, "pelle"), "avambraccio": tinta(pelle, "pelle"), "mano": tinta(pelle, "pelle"),
        "coscia": coscia, "stinco": stinco, "piede": tinta("#5A3A22", "cuoio"),
        "testa": viso(pelle, bocca="decisa", capelli="#2A1C14", barba="#2A1C14"),
        "testa_lati": capelli_lati(pelle, "#2A1C14", 0.5), "testa_retro": capelli_retro("#2A1C14", pelle, 0.9), "testa_sopra": tinta("#2A1C14"),
    }
    corpo(m, abito)
    H = m.posizione_osso("testa")[1]
    m.scatola("testa", (0, H + TESTA * 0.8, 0), (TESTA + 0.02, 0.05, TESTA + 0.02), {"tutte": tinta("#2A1C14")})  # fionda di riserva in testa
    pugno, d = punto_mano(m, "R")
    m.segmento("mano.R", pugno + np.array([0, -0.45, 0]), pugno, 0.015, 0.015, {"tutte": tinta("#8A6A3A")})
    m.scatola("mano.R", pugno + np.array([0, -0.48, 0]), (0.08, 0.06, 0.05), {"tutte": tinta("#6A4A2A", "cuoio")})
    m.scatola("bacino", (-BUSTO_L / 2 - 0.08, GAMBE - 0.05, 0), (0.16, 0.2, 0.12), {"tutte": tinta("#7A5A3A", "cuoio")})  # sacca
    return m


@a_cavallo("Annibale")
def CavalleriaNumidica(vecchio):
    """Cavalieri numidi: senza armatura, tunica corta, scudo tondo di cuoio e giavellotti."""
    m = base("CavalleriaNumidica", vecchio, mano_l=(0.05, -0.65, -1))
    pelle = PELLI[4]
    corpo(m, {
        "busto": busto_semplice("#E8E0C8", cintura="#7A4A2A", scollo=pelle), "busto_retro": busto_semplice("#E8E0C8", cintura="#7A4A2A"),
        "busto_lati": tinta("#E8E0C8"), "omero": tinta(pelle, "pelle"), "avambraccio": tinta(pelle, "pelle"), "mano": tinta(pelle, "pelle"),
        "testa": viso(pelle, bocca="decisa", barba="#1A1410", capelli="#1A1410"),
        "testa_lati": capelli_lati(pelle, "#1A1410", 0.5), "testa_retro": capelli_retro("#1A1410", pelle, 0.85), "testa_sopra": tinta("#1A1410"),
    }, gambe=False)
    gambe(m, tinta(pelle, "pelle"), tinta(pelle, "pelle"), tinta(pelle, "pelle"))
    gualdrappa(m, "#C8A060", lambda pen: pen.rett(0, 0.8, 1, 0.88, "#7A3A2A"), lunga=0.8)
    pugno_l, _ = punto_mano(m, "L")
    scudo_tondo(m, "mano.L", pugno_l + np.array([-0.08, 0.05, 0]), 0.5, 0.04,
                lambda pen: (pen.riempi("#8A5A30", "cuoio"), pen.ellisse(0.4, 0.4, 0.6, 0.6, "#C8A060")),
                tinta("#5A3A20", "cuoio"), assi=FUORI)
    lancia(m, 1.2, 0.6, "#8A6238")
    return m


@fante
def GuerrieroGallico():
    """Guerriero gallo: brache a quadri, torso nudo col torques, capelli lunghi e baffi, spada lunga e scudo."""
    m = Modello("GuerrieroGallico")
    scheletro(m, mano_r=(-0.1, -0.55, -1), mano_l=(0.25, 0.1, -1))
    pelle = PELLI[3]
    capelli = "#C89A50"

    def quadri(pen):
        pen.riempi("#3A6A3A")
        for u in np.linspace(0, 1, 6):
            pen.rett(u - 0.04, 0, u + 0.04, 1, "#B83A2A")
        for v in np.linspace(0, 1, 6):
            pen.rett(0, v - 0.03, 1, v + 0.03, "#C8A040")

    def torso(pen):
        pen.riempi(pelle, "pelle")
        pen.rett(0.46, 0.25, 0.54, 0.45, scuro(pelle, 0.08))
        pen.rett(0, 0.84, 1, 0.92, "#5A3A22")
        pen.rett(0.44, 0.83, 0.56, 0.93, ORO)
    abito = {
        "busto": torso, "busto_retro": torso, "busto_lati": tinta(pelle, "pelle"),
        "omero": tinta(pelle, "pelle"), "avambraccio": tinta(pelle, "pelle"), "mano": tinta(pelle, "pelle"),
        "coscia": quadri, "stinco": quadri, "piede": tinta("#5A3A22", "cuoio"),
        "testa": viso(pelle, bocca="decisa", baffi=capelli, capelli=capelli, frangia=0.08),
        "testa_lati": capelli_lati(pelle, capelli, 0.8), "testa_retro": capelli_retro(capelli, pelle, 1.0), "testa_sopra": tinta(capelli),
    }
    corpo(m, abito)
    H = m.posizione_osso("testa")[1]
    m.scatola("torace", (0, COLLO - 0.02, -0.02), (TESTA * 0.8, 0.05, TESTA * 0.7), {"tutte": tinta(ORO, "metallo")})  # torques
    m.scatola("testa", (0, H + TESTA * 0.35, TESTA / 2 + 0.06), (TESTA, TESTA * 0.7, 0.1), {"tutte": tinta(capelli)})  # chioma
    spada_dritta(m, 0.85)

    def disegno(pen):
        pen.rett(0.46, 0.0, 0.54, 1.0, "#C8A040")
        pen.ellisse(0.38, 0.4, 0.62, 0.6, "#C8A040")
    scudo_ovale(m, "#2E5A3A", disegno=disegno, larghezza=0.5, altezza=0.9)
    return m


@fante
def ArciereGallico():
    m = Modello("ArciereGallico")
    scheletro(m, mano_r=(0.2, -1, -0.25), mano_l=(0.1, -0.75, -1))
    pelle = PELLI[3]
    capelli = "#8A5A2A"
    abito = {
        "busto": busto_semplice("#7A6A3A", cintura="#4A3020"), "busto_retro": busto_semplice("#7A6A3A", cintura="#4A3020"),
        "busto_lati": tinta("#7A6A3A"), "omero": tinta("#7A6A3A"), "avambraccio": tinta(pelle, "pelle"), "mano": tinta(pelle, "pelle"),
        "coscia": tinta("#8A3A2A"), "stinco": pantaloni("#8A3A2A", stivali="#4A3020", altezza_stivale=0.2)[1], "piede": tinta("#4A3020", "cuoio"),
        "testa": viso(pelle, bocca="seria", baffi=capelli, capelli=capelli, frangia=0.06),
        "testa_lati": capelli_lati(pelle, capelli, 0.7), "testa_retro": capelli_retro(capelli, pelle, 0.95), "testa_sopra": tinta(capelli),
    }
    corpo(m, abito)
    mantello(m, "#4A6A3A", bordo="#C8A040")
    pugno, _ = punto_mano(m, "L")
    m.osso("arco", "mano.L", pugno)
    arco(m, "arco", pugno, 1.3, 0.12)
    faretra(m, "bacino", (BUSTO_L / 2 + 0.07, GAMBE - 0.05, 0.05), 0.5, 12)
    return m


@a_cavallo("Cavaliere")
def CavalleriaGallica(vecchio):
    m = base("CavalleriaGallica", vecchio, mano_l=(0.05, -0.6, -1))
    pelle = PELLI[3]
    capelli = "#B88A4A"
    corpo(m, {
        "busto": maglia("#7E848C"), "busto_retro": maglia("#7E848C"), "busto_lati": maglia("#7E848C"),
        "omero": maglia("#7E848C"), "avambraccio": tinta(pelle, "pelle"), "mano": tinta(pelle, "pelle"),
        "testa": viso(pelle, bocca="decisa", baffi=capelli), "testa_lati": capelli_lati(pelle, capelli, 0.6),
        "testa_retro": capelli_retro(capelli, pelle, 0.9),
    }, gambe=False)

    def quadri(pen):
        pen.riempi("#8A3A2A")
        for u in np.linspace(0, 1, 5):
            pen.rett(u - 0.04, 0, u + 0.04, 1, "#C8A040")
    gambe(m, quadri, quadri, tinta("#4A3020", "cuoio"))
    H = testa_y(m)
    b = tinta(BRONZO, "metallo")
    elmo_scatola(m, 0.04, 0.24, 0.02, {"tutte": b})
    m.scatola("testa", (0, H + TESTA + 0.1, 0), (0.05, 0.12, TESTA * 0.8), {"tutte": b})
    gualdrappa(m, "#2E5A3A", lambda pen: pen.rett(0, 0.8, 1, 0.88, "#C8A040"))
    lancia(m, 1.8, 0.8, "#8A6238")
    return m


@a_cavallo("Compagno")
def CavalleriaGermanica(vecchio):
    """Cavalieri germanici di Cesare: torso coperto da una pelliccia, capelli raccolti nel nodo svevo, lancia."""
    m = base("CavalleriaGermanica", vecchio, mano_l=(0.05, -0.6, -1))
    pelle = PELLI[3]
    capelli = "#D8B060"

    def pelliccia(pen):
        pen.riempi("#6A4A2E")
        for u in np.linspace(0.05, 0.95, 8):
            pen.linea([(u, 0), (u + 0.03, 1)], "#4A3220", 0.01)
    corpo(m, {
        "busto": pelliccia, "busto_retro": pelliccia, "busto_lati": pelliccia,
        "omero": tinta(pelle, "pelle"), "avambraccio": tinta(pelle, "pelle"), "mano": tinta(pelle, "pelle"),
        "testa": viso(pelle, bocca="decisa", barba=capelli, baffi=capelli),
        "testa_lati": capelli_lati(pelle, capelli, 0.5), "testa_retro": capelli_retro(capelli, pelle, 0.8), "testa_sopra": tinta(capelli),
    }, gambe=False)
    gambe(m, tinta("#5A4A3A"), tinta("#5A4A3A"), tinta("#3A2A1C", "cuoio"))
    H = testa_y(m)
    m.scatola("testa", (0.1, H + TESTA + 0.04, 0.05), (0.14, 0.12, 0.14), {"tutte": tinta(capelli)})  # nodo svevo
    gualdrappa(m, "#5A4A3A", lunga=0.8)
    lancia(m, 1.8, 0.8, "#7A5232")
    return m


# == MEDIOEVO ==============================================================================================

def croce(c, larga=0.12):
    def p(pen):
        pen.rett(0.5 - larga / 2, 0.08, 0.5 + larga / 2, 0.75, c)
        pen.rett(0.22, 0.25, 0.78, 0.25 + larga, c)
    return p


def sopravveste(c, disegno=None, cintura="#4A3020"):
    def p(pen):
        pen.riempi(c)
        if disegno:
            disegno(pen)
        pen.rett(0, 0.82, 1, 0.9, cintura)
    return p


def cappello_ferro(m, c="#7E848C", tesa=0.2):
    """Cappello di ferro (kettle hat) a tesa larga."""
    H = m.posizione_osso("testa")[1]
    e = tinta(c, "metallo")
    elmo_scatola(m, 0.04, 0.26, 0.015, {"tutte": e})
    m.scatola("testa", (0, H + TESTA * 0.68, 0), (TESTA + tesa, 0.03, TESTA + tesa), {"tutte": e})


def elmo_grande(m, c="#A4AAB2", croce_c=None, y=None):
    """Elmo a secchiello che copre la testa con la fessura degli occhi."""
    H = m.posizione_osso("testa")[1] if y is None else y

    def fronte(pen):
        pen.riempi(c, "metallo")
        pen.rett(0.08, 0.36, 0.92, 0.44, "#1A1C20")
        pen.rett(0.47, 0.44, 0.53, 0.8, croce_c or scuro(c, 0.35))
        pen.rett(0.3, 0.55, 0.7, 0.6, croce_c or scuro(c, 0.35))
    elmo_scatola(m, 0.05, -0.01, 0.02, {"fronte": fronte, "tutte": tinta(c, "metallo")})


def scudo_mandorla(m, c, disegno=None):
    """Scudo a mandorla (normanno, teutonico) sul braccio sinistro, a lastre sempre più strette."""
    pugno, _ = punto_mano(m, "L")

    def pittore(pen, u0, u1, v0, v1):
        q = Porzione(pen, u0, u1, v0, v1)
        q.riempi(c, "legno")
        if disegno:
            disegno(q)
    larghezze = [0.46, 0.44, 0.38, 0.3, 0.22, 0.13]
    n, altezza = len(larghezze), 0.86
    h = altezza / n
    for i, lw in enumerate(larghezze):
        v0, v1 = i / n, (i + 1) / n
        u0, u1 = (0.46 - lw) / 2 / 0.46, 1 - (0.46 - lw) / 2 / 0.46

        def pit(pen, u0=u0, u1=u1, v0=v0, v1=v1):
            pittore(pen, u0, u1, v0, v1)
        y = altezza / 2 - (i + 0.5) * h
        m.scatola("mano.L", pugno + np.array([-0.1 - 0.002 * i, y, 0]), (lw, h + 0.002, 0.04),
                  {"fronte": pit, "tutte": tinta("#6A4A2A", "legno")}, assi=FUORI)


@fante
def FanteUmayyade():
    m = Modello("FanteUmayyade")
    scheletro(m, mano_r=(0, 0.05, -1), mano_l=(0.25, 0.1, -1))
    pelle = PELLI[4]
    abito = {
        "busto": maglia("#7E848C"), "busto_retro": maglia("#7E848C"), "busto_lati": maglia("#7E848C"),
        "omero": maglia("#7E848C"), "avambraccio": tinta("#ECE6D6"), "mano": tinta(pelle, "pelle"),
        "coscia": tinta("#ECE6D6"), "stinco": pantaloni("#ECE6D6", stivali="#5A3A22", altezza_stivale=0.3)[1], "piede": tinta("#5A3A22", "cuoio"),
        "testa": viso(pelle, bocca="decisa", barba="#1A1410", baffi="#1A1410"),
        "testa_lati": capelli_lati(pelle, "#1A1410", 0.4), "testa_retro": capelli_retro("#1A1410", pelle, 0.7),
    }
    corpo(m, abito)
    turbante(m, "#ECE6D6", elmo=FERRO)
    lancia_fante(m)
    scudo_rotondo(m, "#2E6A3A", lambda pen: pen.ellisse(0.15, 0.15, 0.85, 0.85, "#C8A040") or pen.ellisse(0.22, 0.22, 0.78, 0.78, "#2E6A3A"))
    return m


@fante
def ArciereArabo():
    m = Modello("ArciereArabo")
    scheletro(m, mano_r=(0.2, -1, -0.25), mano_l=(0.1, -0.75, -1))
    pelle = PELLI[4]
    veste = "#E8DCC0"
    abito = {
        "busto": sopravveste(veste, cintura="#2E6A3A"), "busto_retro": sopravveste(veste, cintura="#2E6A3A"), "busto_lati": tinta(veste),
        "omero": tinta(veste), "avambraccio": tinta(veste), "mano": tinta(pelle, "pelle"),
        "coscia": tinta(veste), "stinco": tinta(veste), "piede": tinta("#6A4628", "cuoio"),
        "testa": viso(pelle, bocca="seria", barba="#1A1410"), "testa_lati": capelli_lati(pelle, "#1A1410", 0.4),
        "testa_retro": capelli_retro("#1A1410", pelle, 0.7),
    }
    corpo(m, abito)
    turbante(m, "#2E6A3A")
    pugno, _ = punto_mano(m, "L")
    m.osso("arco", "mano.L", pugno)
    arco(m, "arco", pugno, 1.05, 0.2, c="#4A2E1A")
    faretra(m, "bacino", (BUSTO_L / 2 + 0.07, GAMBE - 0.05, 0.05), 0.5, 12, c="#5A3A22")
    return m


@a_cavallo("Annibale")
def CavalleriaAraba(vecchio):
    m = base("CavalleriaAraba", vecchio, mano_l=(0.05, -0.6, -1))
    pelle = PELLI[4]
    corpo(m, {
        "busto": maglia("#7E848C"), "busto_retro": maglia("#7E848C"), "busto_lati": maglia("#7E848C"),
        "omero": maglia("#7E848C"), "avambraccio": tinta("#ECE6D6"), "mano": tinta(pelle, "pelle"),
        "testa": viso(pelle, bocca="decisa", barba="#1A1410", baffi="#1A1410"),
        "testa_lati": capelli_lati(pelle, "#1A1410", 0.4), "testa_retro": capelli_retro("#1A1410", pelle, 0.7),
    }, gambe=False)
    gambe(m, tinta("#ECE6D6"), tinta("#5A3A22", "cuoio"), tinta("#5A3A22", "cuoio"))
    mantello_cavaliere(m, "#ECE6D6")
    turbante(m, "#ECE6D6", elmo=FERRO)
    gualdrappa(m, "#2E6A3A", lambda pen: pen.rett(0, 0.75, 1, 0.82, "#C8A040"))
    lancia(m, 1.9, 0.8, "#8A6238")
    return m


@a_cavallo("Guglielmo")
def CavaliereNormanno(vecchio):
    """Cavaliere normanno di Hastings: elmo conico col nasale, usbergo, scudo a mandorla, lancia."""
    m = base("CavaliereNormanno", vecchio, mano_l=(0.1, -0.55, -1))
    pelle = PELLI[0]
    capelli = "#6A4A2A"
    usbergo = maglia("#828890")
    corpo(m, {
        "busto": usbergo, "busto_retro": usbergo, "busto_lati": usbergo, "omero": usbergo, "avambraccio": usbergo,
        "mano": tinta("#5A4030", "cuoio"), "testa": viso(pelle, bocca="decisa"),
        "testa_lati": capelli_lati(pelle, capelli, 0.5), "testa_retro": capelli_retro(capelli, pelle, 0.8),
    }, gambe=False)
    gambe(m, usbergo, tinta("#5A4A3A"), tinta("#3A2A1C", "cuoio"))
    H = testa_y(m)
    elmo_conico(m, y=H)

    def stemma(q):
        q.rett(0.0, 0.0, 1.0, 1.0, "#C8A040")
        for v in (0.2, 0.5, 0.8):
            q.rett(0.0, v - 0.06, 1.0, v + 0.06, "#A0201E")
    scudo_mandorla(m, "#C8A040", stemma)

    def banderuola(pen):
        pen.riempi("#C8A040")
        pen.rett(0, 0.5, 1, 1, "#A0201E")
    lancia(m, 2.0, 0.9, "#8A6238", pennone=banderuola)
    return m


@fante
def FanteNormanno():
    m = Modello("FanteNormanno")
    scheletro(m, mano_r=(0, 0.05, -1), mano_l=(0.25, 0.1, -1))
    pelle = PELLI[0]
    usbergo = maglia("#828890")
    abito = {
        "busto": usbergo, "busto_retro": usbergo, "busto_lati": usbergo, "omero": usbergo, "avambraccio": tinta("#6A5A44"),
        "mano": tinta(pelle, "pelle"), "coscia": usbergo, "stinco": pantaloni("#6A5A44", fasce="#8C7A5A", altezza_stivale=0.15)[1],
        "piede": tinta("#3A2A1C", "cuoio"), "testa": viso(pelle, bocca="decisa"),
        "testa_lati": capelli_lati(pelle, "#6A4A2A", 0.5), "testa_retro": capelli_retro("#6A4A2A", pelle, 0.8),
    }
    corpo(m, abito)
    elmo_conico(m)
    lancia_fante(m)
    scudo_mandorla(m, "#A0201E", lambda q: (q.rett(0.42, 0.0, 0.58, 1.0, "#C8A040"), q.rett(0.1, 0.25, 0.9, 0.35, "#C8A040")))
    return m


@fante
def ArciereNormanno():
    m = Modello("ArciereNormanno")
    scheletro(m, mano_r=(0.2, -1, -0.25), mano_l=(0.1, -0.75, -1))
    pelle = PELLI[0]
    giaco = "#8A7A5A"
    abito = {
        "busto": sopravveste(giaco), "busto_retro": sopravveste(giaco), "busto_lati": tinta(giaco),
        "omero": tinta(giaco), "avambraccio": tinta(giaco), "mano": tinta(pelle, "pelle"),
        "coscia": tinta("#5A4A3A"), "stinco": pantaloni("#5A4A3A", fasce="#7A6A4A", altezza_stivale=0.15)[1], "piede": tinta("#3A2A1C", "cuoio"),
        "testa": viso(pelle, bocca="seria"), "testa_lati": capelli_lati(pelle, "#5A3A22", 0.5),
        "testa_retro": capelli_retro("#5A3A22", pelle, 0.8),
    }
    corpo(m, abito)
    H = m.posizione_osso("testa")[1]
    m.scatola("testa", (0, H + TESTA + 0.03, 0), (TESTA + 0.04, 0.08, TESTA + 0.04), {"tutte": tinta("#6A5A3A", "cuoio")})
    pugno, _ = punto_mano(m, "L")
    m.osso("arco", "mano.L", pugno)
    arco(m, "arco", pugno, 1.3, 0.13)
    faretra(m, "bacino", (BUSTO_L / 2 + 0.07, GAMBE - 0.05, 0.05), 0.5, 12)
    return m


@a_cavallo("Annibale")
def Mamelucco(vecchio):
    """Mamelucco di Saladino: lamelle, sopravveste gialla, turbante sull'elmo, scudo tondo e lancia."""
    m = base("Mamelucco", vecchio, mano_l=(0.05, -0.6, -1))
    pelle = PELLI[4]
    giallo = "#D8A830"

    def lamelle(pen):
        pen.riempi(giallo)
        pen.rett(0.1, 0.1, 0.9, 0.7, "#8A8E96")
        for v in np.linspace(0.12, 0.68, 7):
            pen.rett(0.1, v, 0.9, v + 0.015, "#5A5E66")
        pen.rett(0, 0.82, 1, 0.9, "#7A2A2A")
    corpo(m, {
        "busto": lamelle, "busto_retro": lamelle, "busto_lati": tinta(giallo),
        "omero": tinta(giallo), "avambraccio": tinta("#7A2A2A"), "mano": tinta(pelle, "pelle"),
        "testa": viso(pelle, bocca="decisa", barba="#1A1410", baffi="#1A1410"),
        "testa_lati": capelli_lati(pelle, "#1A1410", 0.4), "testa_retro": capelli_retro("#1A1410", pelle, 0.7),
    }, gambe=False)
    gambe(m, tinta("#7A2A2A"), tinta("#5A3A22", "cuoio"), tinta("#5A3A22", "cuoio"))
    turbante(m, "#ECE6D6", elmo="#B8BCC4")
    gualdrappa(m, "#D8A830", lambda pen: pen.rett(0, 0.7, 1, 0.8, "#7A2A2A"))
    pugno_l, _ = punto_mano(m, "L")
    scudo_tondo(m, "mano.L", pugno_l + np.array([-0.08, 0.05, 0]), 0.5, 0.04,
                lambda pen: (pen.riempi("#D8A830", "legno"), pen.ellisse(0.25, 0.25, 0.75, 0.75, "#7A2A2A"), pen.ellisse(0.4, 0.4, 0.6, 0.6, "#C8CCD4")),
                tinta("#5A3A20", "legno"), assi=FUORI)
    lancia(m, 1.9, 0.8, "#8A6238")
    return m


@fante
def FanteAyyubide():
    m = Modello("FanteAyyubide")
    scheletro(m, mano_r=(0, 0.05, -1), mano_l=(0.25, 0.1, -1))
    pelle = PELLI[4]
    imbottito = "#C8A050"

    def gambesone(pen):
        pen.riempi(imbottito)
        for u in np.linspace(0.1, 0.9, 6):
            pen.rett(u - 0.008, 0, u + 0.008, 0.82, scuro(imbottito, 0.15))
        pen.rett(0, 0.82, 1, 0.9, "#2E6A3A")
    abito = {
        "busto": gambesone, "busto_retro": gambesone, "busto_lati": tinta(imbottito),
        "omero": tinta(imbottito), "avambraccio": tinta(imbottito), "mano": tinta(pelle, "pelle"),
        "coscia": tinta("#ECE6D6"), "stinco": tinta("#ECE6D6"), "piede": tinta("#6A4628", "cuoio"),
        "testa": viso(pelle, bocca="decisa", barba="#1A1410"), "testa_lati": capelli_lati(pelle, "#1A1410", 0.4),
        "testa_retro": capelli_retro("#1A1410", pelle, 0.7),
    }
    corpo(m, abito)
    turbante(m, "#ECE6D6")
    lancia_fante(m)
    scudo_rotondo(m, "#D8A830", lambda pen: pen.ellisse(0.2, 0.2, 0.8, 0.8, "#2E6A3A"))
    return m


@fante
def ArciereAyyubide():
    m = Modello("ArciereAyyubide")
    scheletro(m, mano_r=(0.2, -1, -0.25), mano_l=(0.1, -0.75, -1))
    pelle = PELLI[4]
    veste = "#D8A830"
    abito = {
        "busto": sopravveste(veste, cintura="#7A2A2A"), "busto_retro": sopravveste(veste, cintura="#7A2A2A"), "busto_lati": tinta(veste),
        "omero": tinta(veste), "avambraccio": tinta(veste), "mano": tinta(pelle, "pelle"),
        "coscia": tinta("#7A2A2A"), "stinco": pantaloni("#7A2A2A", stivali="#5A3A22", altezza_stivale=0.4)[1], "piede": tinta("#5A3A22", "cuoio"),
        "testa": viso(pelle, bocca="seria", barba="#1A1410", baffi="#1A1410"), "testa_lati": capelli_lati(pelle, "#1A1410", 0.4),
        "testa_retro": capelli_retro("#1A1410", pelle, 0.7),
    }
    corpo(m, abito)
    turbante(m, "#ECE6D6")
    pugno, _ = punto_mano(m, "L")
    m.osso("arco", "mano.L", pugno)
    arco(m, "arco", pugno, 1.0, 0.2, c="#4A2E1A")
    faretra(m, "bacino", (BUSTO_L / 2 + 0.07, GAMBE - 0.05, 0.05), 0.5, 12, c="#7A2A2A")
    return m


@a_cavallo("Cavaliere")
def CavaliereTeutonico(vecchio):
    """Cavaliere dell'Ordine Teutonico: mantello bianco con la croce nera, elmo grande, scudo e lancia."""
    m = base("CavaliereTeutonico", vecchio, mano_l=(0.1, -0.55, -1))
    pelle = PELLI[3]
    bianco = "#ECEAE2"
    corpo(m, {
        "busto": sopravveste(bianco, croce("#1A1A1E")), "busto_retro": sopravveste(bianco, croce("#1A1A1E")), "busto_lati": tinta(bianco),
        "omero": maglia(), "avambraccio": maglia(), "mano": tinta("#5A4030", "cuoio"),
        "testa": viso(pelle), "testa_lati": capelli_lati(pelle, "#6A4A2A"), "testa_retro": capelli_retro("#6A4A2A", pelle),
    }, gambe=False)
    gambe(m, maglia(), maglia(), tinta("#3A2A1C", "cuoio"))
    mantello_cavaliere(m, bianco)
    elmo_grande(m, y=testa_y(m))
    gualdrappa(m, bianco, croce("#1A1A1E", 0.1))
    scudo_mandorla(m, bianco, lambda q: (q.rett(0.42, 0.05, 0.58, 0.85, "#1A1A1E"), q.rett(0.15, 0.25, 0.85, 0.38, "#1A1A1E")))
    lancia(m, 2.0, 0.9, "#8A6238", pennone=lambda pen: (pen.riempi(bianco), pen.rett(0.4, 0.2, 0.6, 0.8, "#1A1A1E")))
    return m


@fante
def BalestriereTeutonico():
    m = Modello("BalestriereTeutonico")
    scheletro(m, mano_r=(-0.6, -0.45, -1), mano_l=(0.55, -0.5, -0.8))
    pelle = PELLI[3]
    grigio = "#8A8678"

    def tau(pen):
        pen.rett(0.44, 0.15, 0.56, 0.7, "#1A1A1E")
        pen.rett(0.25, 0.15, 0.75, 0.25, "#1A1A1E")
    abito = {
        "busto": sopravveste(grigio, tau), "busto_retro": sopravveste(grigio), "busto_lati": tinta(grigio),
        "omero": maglia(), "avambraccio": maglia(), "mano": tinta("#5A4030", "cuoio"),
        "coscia": tinta("#5A5448"), "stinco": pantaloni("#5A5448", stivali="#3A2A1C", altezza_stivale=0.3)[1], "piede": tinta("#3A2A1C", "cuoio"),
        "testa": viso(pelle, bocca="seria"), "testa_lati": capelli_lati(pelle, "#7A5A3A", 0.5),
        "testa_retro": capelli_retro("#7A5A3A", pelle, 0.8),
    }
    corpo(m, abito)
    cappello_ferro(m)
    balestra(m)
    return m


@fante
def SergenteTeutonico():
    m = Modello("SergenteTeutonico")
    scheletro(m, mano_r=(-0.1, -0.55, -1), mano_l=(0.25, 0.1, -1))
    pelle = PELLI[3]
    grigio = "#8A8678"

    def tau(pen):
        pen.rett(0.44, 0.15, 0.56, 0.7, "#1A1A1E")
        pen.rett(0.25, 0.15, 0.75, 0.25, "#1A1A1E")
    abito = {
        "busto": sopravveste(grigio, tau), "busto_retro": sopravveste(grigio, tau), "busto_lati": tinta(grigio),
        "omero": maglia(), "avambraccio": maglia(), "mano": tinta("#5A4030", "cuoio"),
        "coscia": maglia(), "stinco": maglia(), "piede": tinta("#3A2A1C", "cuoio"),
        "testa": viso(pelle, bocca="decisa", barba="#7A5A3A"), "testa_lati": capelli_lati(pelle, "#7A5A3A", 0.5),
        "testa_retro": capelli_retro("#7A5A3A", pelle, 0.8),
    }
    corpo(m, abito)
    cappello_ferro(m)
    spada_dritta(m, 0.7)
    scudo_mandorla(m, "#ECEAE2", lambda q: (q.rett(0.42, 0.05, 0.58, 0.85, "#1A1A1E"), q.rett(0.15, 0.25, 0.85, 0.38, "#1A1A1E")))
    return m


@fante
def BalestriereGenovese():
    """Balestriere genovese di Crécy: sopravveste bianca con la croce rossa di San Giorgio, pavese sulla schiena."""
    m = Modello("BalestriereGenovese")
    scheletro(m, mano_r=(-0.6, -0.45, -1), mano_l=(0.55, -0.5, -0.8))
    pelle = PELLI[1]
    abito = {
        "busto": sopravveste("#ECEAE2", croce("#B82820")), "busto_retro": sopravveste("#ECEAE2"), "busto_lati": tinta("#ECEAE2"),
        "omero": tinta("#B82820"), "avambraccio": tinta("#B82820"), "mano": tinta(pelle, "pelle"),
        "coscia": tinta("#B82820"), "stinco": pantaloni("#ECEAE2", stivali="#3A2A1C", altezza_stivale=0.25)[1], "piede": tinta("#3A2A1C", "cuoio"),
        "testa": viso(pelle, bocca="seria", baffi="#3A2A1E"), "testa_lati": capelli_lati(pelle, "#3A2A1E", 0.5),
        "testa_retro": capelli_retro("#3A2A1E", pelle, 0.8),
    }
    corpo(m, abito)
    cappello_ferro(m, tesa=0.14)
    balestra(m)

    def pavese(pen):
        pen.riempi("#ECEAE2", "legno")
        pen.rett(0.44, 0.05, 0.56, 0.95, "#B82820")
        pen.rett(0.1, 0.3, 0.9, 0.42, "#B82820")
    m.scatola("torace", (0, GAMBE + BUSTO_A * 0.45, BUSTO_P / 2 + 0.06), (0.6, 0.95, 0.05), {"retro": pavese, "tutte": tinta("#6A4A2A", "legno")})
    return m


@fante
def UomoDArme():
    """Uomo d'arme francese della Guerra dei Cent'anni: armatura a piastre, bacinetto con la visiera, sopravveste
    blu coi gigli, azza (ascia d'arme)."""
    m = Modello("UomoDArme")
    scheletro(m, mano_r=(-0.1, -0.75, -1), mano_l=(-0.2, -1, -0.25))
    acciaio = "#B4BAC2"
    from cavalieri import giglio

    def gigli(pen):
        pen.riempi("#2A4E9A")
        for u, v in ((0.28, 0.2), (0.72, 0.2), (0.5, 0.48)):
            giglio(pen, u, v, 0.09, "#E0B848")
        pen.rett(0, 0.82, 1, 0.9, "#4A3020")
    piastre = tinta(acciaio, "metallo")
    abito = {
        "busto": gigli, "busto_retro": gigli, "busto_lati": tinta("#2A4E9A"),
        "omero": piastre, "avambraccio": piastre, "mano": tinta(scuro(acciaio, 0.2), "metallo"),
        "coscia": piastre, "stinco": piastre, "piede": tinta(scuro(acciaio, 0.2), "metallo"),
        "testa": tinta(acciaio, "metallo"), "testa_lati": tinta(acciaio, "metallo"), "testa_retro": tinta(acciaio, "metallo"),
    }
    corpo(m, abito)
    H = m.posizione_osso("testa")[1]

    def visiera(pen):
        pen.riempi(acciaio, "metallo")
        pen.rett(0.1, 0.4, 0.9, 0.46, "#1A1C20")
        for u in (0.3, 0.4, 0.5, 0.6, 0.7):
            pen.ellisse(u - 0.015, 0.6, u + 0.015, 0.63, "#1A1C20")
    m.scatola("testa", (0, H + TESTA * 0.45, -TESTA / 2 - 0.06), (TESTA * 0.8, TESTA * 0.6, 0.12), {"fronte": visiera, "tutte": tinta(acciaio, "metallo")})
    m.scatola("testa", (0, H + TESTA + 0.06, 0), (TESTA * 0.7, 0.1, TESTA * 0.7), {"tutte": tinta(acciaio, "metallo")})
    pugno_r, _ = punto_mano(m, "R")
    alto = pugno_r + np.array([0, 0.9, -0.02])
    asta(m, "mano.R", alto, pugno_r + np.array([0, -0.45, 0.02]), 0.045, LEGNO)
    m.scatola("mano.R", alto + np.array([0, -0.1, -0.1]), (0.03, 0.22, 0.2), {"tutte": tinta("#9AA0A8", "metallo")})
    m.scatola("mano.R", alto + np.array([0, -0.1, 0.07]), (0.03, 0.06, 0.12), {"tutte": tinta("#9AA0A8", "metallo")})
    lama(m, "mano.R", alto + np.array([0, 0.18, 0]), alto, 0.04, 0.02)
    return m


@a_cavallo("Cavaliere")
def Saladino(vecchio):
    """Saladino, sultano d'Egitto e di Siria: veste verde e bianca, turbante con l'elmo dorato, lancia col vessillo giallo."""
    m = base("Saladino", vecchio, mano_l=(0.05, -0.6, -1))
    pelle = PELLI[4]
    verde, oro = "#2E6A3A", "#E0B848"

    def veste(pen):
        pen.riempi(verde)
        pen.rett(0.42, 0, 0.58, 1, oro)
        pen.rett(0, 0.82, 1, 0.9, oro)
        pen.rett(0.1, 0.1, 0.35, 0.5, "#8A8E96")
        pen.rett(0.65, 0.1, 0.9, 0.5, "#8A8E96")
    corpo(m, {
        "busto": veste, "busto_retro": tinta(verde), "busto_lati": tinta(verde),
        "omero": tinta(verde), "avambraccio": tinta("#ECE6D6"), "mano": tinta(pelle, "pelle"),
        "testa": viso(pelle, bocca="decisa", barba="#2A2018", baffi="#2A2018"),
        "testa_lati": capelli_lati(pelle, "#2A2018", 0.4), "testa_retro": capelli_retro("#2A2018", pelle, 0.7),
    }, gambe=False)
    gambe(m, tinta("#ECE6D6"), tinta("#5A3A22", "cuoio"), tinta("#5A3A22", "cuoio"))
    mantello_cavaliere(m, "#ECE6D6", bordo=oro)
    turbante(m, "#ECE6D6", altezza=0.2, elmo=oro)
    gualdrappa(m, verde, lambda pen: pen.rett(0, 0.72, 1, 0.82, oro))
    lancia(m, 2.0, 0.9, "#8A6238", c_punta="#E0C060", pennone=lambda pen: (pen.riempi("#E0B848"), pen.rett(0, 0.8, 1, 1, verde)))
    return m


# == POLVERE DA SPARO ======================================================================================

def shako(m, c="#1A1A1E", alto=0.24, fregio=ORO, pennacchio=None):
    H = m.posizione_osso("testa")[1]

    def lati(pen):
        pen.riempi(c, "cuoio")
        pen.rett(0, 0.85, 1, 1, scuro(c, 0.3))
        pen.ellisse(0.4, 0.3, 0.6, 0.6, fregio)
    m.scatola("testa", (0, H + TESTA + alto / 2 - 0.04, 0), (TESTA * 0.95, alto, TESTA * 0.95), {"tutte": lati, "sopra": tinta(c, "cuoio")})
    m.scatola("testa", (0, H + TESTA - 0.04, -TESTA / 2 - 0.05), (TESTA * 0.8, 0.02, 0.12), {"tutte": tinta("#18181C", "cuoio")})
    if pennacchio:
        m.scatola("testa", (0, H + TESTA + alto + 0.06, -0.02), (0.06, 0.16, 0.06), {"tutte": tinta(pennacchio)})


def bicorno(m, c="#18181C", bordo=ORO, coccarda=True, traverso=True):
    H = m.posizione_osso("testa")[1]

    def p(pen):
        pen.riempi(c, "cuoio")
        pen.rett(0, 0.0, 1, 0.08, bordo)
        if coccarda:
            pen.ellisse(0.62, 0.25, 0.78, 0.55, "#2A4E9A")
            pen.ellisse(0.65, 0.3, 0.75, 0.5, "#ECEAE2")
            pen.ellisse(0.68, 0.35, 0.72, 0.45, "#B82820")
    misure = (TESTA + 0.5, 0.2, 0.14) if traverso else (0.14, 0.2, TESTA + 0.5)
    m.scatola("testa", (0, H + TESTA + 0.07, 0), misure, {"tutte": p})
    m.scatola("testa", (0, H + TESTA - 0.0, 0), (TESTA * 0.95, 0.1, TESTA * 0.95), {"tutte": tinta(c, "cuoio")})


def giubba(c, risvolti, bottoni=ORO, cinghie="#ECEAE2", cintura=None):
    def p(pen):
        pen.riempi(c)
        pen.rett(0.3, 0.0, 0.7, 0.55, risvolti)
        for v in (0.1, 0.22, 0.34, 0.46):
            pen.ellisse(0.36, v, 0.41, v + 0.04, bottoni)
            pen.ellisse(0.59, v, 0.64, v + 0.04, bottoni)
        if cinghie:
            pen.linea([(0.0, 0.0), (1.0, 0.8)], cinghie, 0.03)
            pen.linea([(1.0, 0.0), (0.0, 0.8)], cinghie, 0.03)
        if cintura:
            pen.rett(0, 0.82, 1, 0.9, cintura)
    return p


@fante
def Giannizzero():
    """Giannizzero: caftano blu e rosso, il börk bianco col lembo che ricade dietro, moschetto e yatagan."""
    m = Modello("Giannizzero")
    scheletro(m, mano_r=(-0.6, -0.45, -1), mano_l=(0.55, -0.5, -0.8))
    pelle = PELLI[2]
    blu, rosso = "#2A4E8A", "#A02828"

    def caftano(pen):
        pen.riempi(blu)
        pen.rett(0.42, 0, 0.58, 1, rosso)
        pen.rett(0, 0.78, 1, 0.88, "#D8A830")
    abito = {
        "busto": caftano, "busto_retro": tinta(blu), "busto_lati": tinta(blu),
        "omero": tinta(rosso), "avambraccio": tinta(rosso), "mano": tinta(pelle, "pelle"),
        "coscia": tinta(blu), "stinco": pantaloni(blu, stivali="#C8A030", altezza_stivale=0.4)[1], "piede": tinta("#C8A030", "cuoio"),
        "testa": viso(pelle, bocca="decisa", baffi="#1A1410"), "testa_lati": capelli_lati(pelle, "#1A1410", 0.3),
        "testa_retro": capelli_retro("#1A1410", pelle, 0.5),
    }
    corpo(m, abito)
    H = m.posizione_osso("testa")[1]
    bork = tinta("#ECEAE2")
    m.scatola("testa", (0, H + TESTA + 0.12, 0.02), (TESTA * 0.9, 0.3, TESTA * 0.9), {"tutte": bork})
    m.scatola("testa", (0, H + TESTA * 0.6, TESTA / 2 + 0.1), (TESTA * 0.7, 0.6, 0.04), {"tutte": bork})
    m.scatola("testa", (0, H + TESTA - 0.03, -TESTA / 2 - 0.01), (0.12, 0.14, 0.03), {"tutte": tinta("#D8A830", "metallo")})
    fucile(m, lungo=1.1, baionetta=False)
    return m


@a_cavallo("Annibale")
def Sipahi(vecchio):
    m = base("Sipahi", vecchio, mano_l=(0.05, -0.6, -1))
    pelle = PELLI[2]
    rosso = "#A02828"
    corpo(m, {
        "busto": maglia("#8A8E96"), "busto_retro": maglia("#8A8E96"), "busto_lati": maglia("#8A8E96"),
        "omero": tinta(rosso), "avambraccio": tinta(rosso), "mano": tinta(pelle, "pelle"),
        "testa": viso(pelle, bocca="decisa", baffi="#1A1410"), "testa_lati": capelli_lati(pelle, "#1A1410", 0.3),
        "testa_retro": capelli_retro("#1A1410", pelle, 0.5),
    }, gambe=False)
    gambe(m, tinta(rosso), tinta("#C8A030", "cuoio"), tinta("#C8A030", "cuoio"))
    mantello_cavaliere(m, rosso, bordo="#D8A830")
    turbante(m, "#ECEAE2", elmo="#B8BCC4")
    gualdrappa(m, rosso, lambda pen: pen.rett(0, 0.72, 1, 0.82, "#D8A830"))
    lancia(m, 2.0, 0.9, "#8A6238", pennone=lambda pen: (pen.riempi(rosso), pen.ellisse(0.3, 0.2, 0.7, 0.8, "#ECEAE2")))
    return m


@fante
def MoschettiereSvedese():
    m = Modello("MoschettiereSvedese")
    scheletro(m, mano_r=(-0.6, -0.45, -1), mano_l=(0.55, -0.5, -0.8))
    pelle = PELLI[0]
    giubba_c = "#2A4E8A"

    def busto(pen):
        pen.riempi(giubba_c)
        pen.linea([(0.0, 0.0), (1.0, 0.8)], "#7A5232", 0.04)  # bandoliera degli apostoli
        for u in np.linspace(0.2, 0.8, 5):
            pen.rett(u - 0.025, 0.2 + u * 0.5, u + 0.025, 0.28 + u * 0.5, "#C8A050")
        pen.rett(0, 0.82, 1, 0.9, "#D8B048")
    abito = {
        "busto": busto, "busto_retro": tinta(giubba_c), "busto_lati": tinta(giubba_c),
        "omero": tinta(giubba_c), "avambraccio": tinta(giubba_c), "mano": tinta(pelle, "pelle"),
        "coscia": tinta("#D8B048"), "stinco": pantaloni("#4A4A50", stivali="#3A2A1C", altezza_stivale=0.4)[1], "piede": tinta("#3A2A1C", "cuoio"),
        "testa": viso(pelle, bocca="seria", baffi="#B88A4A", barba="#B88A4A"), "testa_lati": capelli_lati(pelle, "#B88A4A", 0.6),
        "testa_retro": capelli_retro("#B88A4A", pelle, 0.9),
    }
    corpo(m, abito)
    cappello_tesa(m, "#2A2A2E", piuma="#D8B048")
    fucile(m, lungo=1.2, baionetta=False)
    return m


@fante
def PicchiereSvedese():
    m = Modello("PicchiereSvedese")
    scheletro(m, mano_r=(-0.3, 0.2, -1), mano_l=(0.3, 0.3, -1))
    pelle = PELLI[0]
    acciaio = "#9AA0A8"

    def corazza(pen):
        pen.riempi(acciaio, "metallo")
        pen.linea([(0.5, 0.05), (0.5, 0.7)], chiaro(acciaio, 0.3), 0.012)
        pen.rett(0, 0.82, 1, 0.9, "#D8B048")
    abito = {
        "busto": corazza, "busto_retro": corazza, "busto_lati": tinta(acciaio, "metallo"),
        "omero": tinta("#2A4E8A"), "avambraccio": tinta("#2A4E8A"), "mano": tinta(pelle, "pelle"),
        "coscia": tinta(acciaio, "metallo"), "stinco": pantaloni("#4A4A50", stivali="#3A2A1C", altezza_stivale=0.35)[1], "piede": tinta("#3A2A1C", "cuoio"),
        "testa": viso(pelle, bocca="decisa", baffi="#B88A4A"), "testa_lati": capelli_lati(pelle, "#B88A4A", 0.5),
        "testa_retro": capelli_retro("#B88A4A", pelle, 0.85),
    }
    corpo(m, abito)
    # Morione: calotta con la cresta e la tesa a barca.
    H = m.posizione_osso("testa")[1]
    e = tinta(acciaio, "metallo")
    elmo_scatola(m, 0.04, 0.26, 0.015, {"tutte": e})
    m.scatola("testa", (0, H + TESTA * 0.68, 0), (TESTA + 0.08, 0.03, TESTA + 0.3), {"tutte": e})
    m.scatola("testa", (0, H + TESTA + 0.1, 0), (0.04, 0.1, TESTA * 0.8), {"tutte": e})
    picca(m)
    return m


@a_cavallo("Guglielmo")
def CorazziereSvedese(vecchio):
    """Corazziere svedese (hakkapeliitta): giaco di bufalo, corazza, elmo a coda d'aragosta, sciabola."""
    m = base("CorazziereSvedese", vecchio, mano_l=(0.05, -0.6, -1))
    pelle = PELLI[0]
    acciaio = "#8A9098"

    def corazza(pen):
        pen.riempi(acciaio, "metallo")
        pen.rett(0, 0.82, 1, 0.9, "#D8B048")
    corpo(m, {
        "busto": corazza, "busto_retro": corazza, "busto_lati": tinta(acciaio, "metallo"),
        "omero": tinta("#C8A870"), "avambraccio": tinta("#C8A870"), "mano": tinta("#8A6A40", "cuoio"),
        "testa": viso(pelle, bocca="decisa", baffi="#B88A4A", barba="#B88A4A"), "testa_lati": capelli_lati(pelle, "#B88A4A", 0.5),
        "testa_retro": capelli_retro("#B88A4A", pelle, 0.8),
    }, gambe=False)
    gambe(m, tinta("#C8A870"), tinta("#3A2A1C", "cuoio"), tinta("#3A2A1C", "cuoio"))
    H = testa_y(m)
    e = tinta(acciaio, "metallo")
    elmo_scatola(m, 0.04, 0.26, 0.02, {"tutte": e})
    m.scatola("testa", (0, H + 0.12, TESTA / 2 + 0.06), (TESTA, 0.2, 0.1), {"tutte": e})  # coda d'aragosta
    m.scatola("testa", (0, H + TESTA * 0.6, -TESTA / 2 - 0.06), (0.04, 0.3, 0.03), {"tutte": e})  # nasale
    gualdrappa(m, "#2A4E8A", lambda pen: pen.rett(0, 0.75, 1, 0.85, "#D8B048"))
    lancia(m, 0.9, 0.2, "#C8CCD4", c_punta="#C8CCD4")  # sciabola puntata
    return m


@a_cavallo("Guglielmo")
def GustavoAdolfo(vecchio):
    """Gustavo II Adolfo di Svezia, il Leone del Nord: giaco di bufalo, fascia gialla, cappello piumato, spada."""
    m = base("GustavoAdolfo", vecchio, mano_l=(0.05, -0.6, -1))
    pelle = PELLI[0]
    bufalo = "#C8A870"

    def giaco(pen):
        pen.riempi(bufalo, "cuoio")
        pen.linea([(0.0, 0.05), (1.0, 0.85)], "#E8C030", 0.06)  # fascia
        pen.rett(0.46, 0, 0.54, 0.8, scuro(bufalo, 0.2))
        pen.rett(0.3, 0, 0.7, 0.08, "#ECEAE2")  # colletto di pizzo
    corpo(m, {
        "busto": giaco, "busto_retro": tinta(bufalo, "cuoio"), "busto_lati": tinta(bufalo, "cuoio"),
        "omero": tinta(bufalo, "cuoio"), "avambraccio": tinta(bufalo, "cuoio"), "mano": tinta("#8A6A40", "cuoio"),
        "testa": viso(pelle, bocca="decisa", baffi="#C89A50", barba="#C89A50"), "testa_lati": capelli_lati(pelle, "#C89A50", 0.6),
        "testa_retro": capelli_retro("#C89A50", pelle, 0.9),
    }, gambe=False)
    gambe(m, tinta("#2A2A2E"), tinta("#3A2A1C", "cuoio"), tinta("#3A2A1C", "cuoio"))
    mantello_cavaliere(m, "#2A4E8A", bordo="#E8C030")
    cappello_tesa(m, "#2A2A2E", piuma="#ECEAE2")
    gualdrappa(m, "#2A4E8A", lambda pen: pen.rett(0, 0.7, 1, 0.82, "#E8C030"))
    lancia(m, 0.95, 0.2, "#D0D4DC", c_punta="#D0D4DC")
    return m


@fante
def FanteriaDiLinea():
    """Fante di linea francese di Napoleone: giubba blu coi risvolti bianchi, shako, moschetto con la baionetta."""
    m = Modello("FanteriaDiLinea")
    scheletro(m, mano_r=(-0.6, -0.45, -1), mano_l=(0.55, -0.5, -0.8))
    pelle = PELLI[1]
    abito = {
        "busto": giubba("#2A3E8A", "#ECEAE2", cintura=None), "busto_retro": tinta("#2A3E8A"), "busto_lati": tinta("#2A3E8A"),
        "omero": tinta("#2A3E8A"), "avambraccio": tinta("#2A3E8A"), "mano": tinta(pelle, "pelle"),
        "coscia": tinta("#ECEAE2"), "stinco": pantaloni("#ECEAE2", stivali="#1A1A1E", altezza_stivale=0.45)[1], "piede": tinta("#1A1A1E", "cuoio"),
        "testa": viso(pelle, bocca="decisa", baffi="#3A2A1E"), "testa_lati": capelli_lati(pelle, "#3A2A1E", 0.4),
        "testa_retro": capelli_retro("#3A2A1E", pelle, 0.75),
    }
    corpo(m, abito)
    shako(m, pennacchio="#B82820")
    fucile(m, lungo=1.15)
    return m


@a_cavallo("Cavaliere")
def Corazziere(vecchio):
    """Corazziere francese: corazza d'acciaio, elmo con la criniera nera, spada dritta."""
    m = base("Corazziere", vecchio, mano_l=(0.05, -0.6, -1))
    pelle = PELLI[1]
    acciaio = "#C4CAD2"

    def corazza(pen):
        pen.riempi(acciaio, "metallo")
        for u, v in ((0.2, 0.1), (0.8, 0.1), (0.2, 0.6), (0.8, 0.6)):
            pen.ellisse(u - 0.03, v - 0.03, u + 0.03, v + 0.03, "#D8B048")
        pen.rett(0, 0.82, 1, 0.9, "#ECEAE2")
    corpo(m, {
        "busto": corazza, "busto_retro": corazza, "busto_lati": tinta(acciaio, "metallo"),
        "omero": tinta("#2A3E8A"), "avambraccio": tinta("#2A3E8A"), "mano": tinta("#ECEAE2"),
        "testa": viso(pelle, bocca="decisa", baffi="#2A2018"), "testa_lati": capelli_lati(pelle, "#2A2018", 0.4),
        "testa_retro": capelli_retro("#2A2018", pelle, 0.7),
    }, gambe=False)
    gambe(m, tinta("#ECEAE2"), tinta("#1A1A1E", "cuoio"), tinta("#1A1A1E", "cuoio"))
    H = testa_y(m)
    e = tinta(acciaio, "metallo")
    elmo_scatola(m, 0.06, 0.26, 0.02, {"tutte": e})
    m.scatola("testa", (0, H + TESTA + 0.12, 0.02), (0.06, 0.12, TESTA * 0.9), {"tutte": tinta("#D8B048", "metallo")})
    m.scatola("testa", (0, H + TESTA * 0.5, TESTA / 2 + 0.08), (0.12, 0.6, 0.1), {"tutte": tinta("#1A1A1E")})  # criniera
    gualdrappa(m, "#2A3E8A", lambda pen: pen.rett(0, 0.75, 1, 0.85, "#ECEAE2"))
    lancia(m, 0.95, 0.2, "#D0D4DC", c_punta="#D0D4DC")
    return m


@fante
def Napoleone():
    """Napoleone Bonaparte: bicorno di traverso, redingote grigia sopra l'uniforme verde dei cacciatori, spada."""
    m = Modello("Napoleone")
    scheletro(m, mano_r=(-0.1, -0.55, -1), mano_l=(0.05, -1, 0.05))
    pelle = PELLI[3]
    grigio, verde = "#7A7A78", "#2E5A3A"

    def redingote(pen):
        pen.riempi(grigio)
        pen.rett(0.32, 0, 0.68, 0.75, verde)
        pen.rett(0.38, 0.05, 0.62, 0.7, "#ECEAE2")  # panciotto
        for v in (0.15, 0.3, 0.45):
            pen.ellisse(0.47, v, 0.53, v + 0.04, ORO)
        pen.rett(0.18, 0.2, 0.28, 0.3, "#B82820")  # Legion d'onore
    abito = {
        "busto": redingote, "busto_retro": tinta(grigio), "busto_lati": tinta(grigio),
        "omero": tinta(grigio), "avambraccio": tinta(grigio), "mano": tinta("#ECEAE2"),
        "coscia": tinta("#ECEAE2"), "stinco": pantaloni("#ECEAE2", stivali="#1A1A1E", altezza_stivale=0.9)[1], "piede": tinta("#1A1A1E", "cuoio"),
        "testa": viso(pelle, bocca="decisa", capelli="#3A2A1E", frangia=0.02), "testa_lati": capelli_lati(pelle, "#3A2A1E", 0.4),
        "testa_retro": capelli_retro("#3A2A1E", pelle, 0.7),
    }
    corpo(m, abito)
    mantello(m, grigio, basso_y=GAMBE * 0.25)
    bicorno(m)
    spada_dritta(m, 0.7, elsa=ORO)
    return m


# == NOVECENTO =============================================================================================

def elmo_stahlhelm(m, c="#5E6650"):
    H = m.posizione_osso("testa")[1]
    e = tinta(c, "metallo")
    elmo_scatola(m, 0.05, 0.2, 0.025, {"tutte": e})
    for x in (-1, 1):  # le falde che scendono sulle orecchie
        m.scatola("testa", (x * (TESTA / 2 + 0.04), H + 0.12, 0.02), (0.03, 0.12, TESTA * 0.8), {"tutte": e})
    m.scatola("testa", (0, H + 0.12, TESTA / 2 + 0.04), (TESTA + 0.05, 0.12, 0.03), {"tutte": e})


def elmo_brodie(m, c="#6A6A4A"):
    H = m.posizione_osso("testa")[1]
    e = tinta(c, "metallo")
    elmo_scatola(m, 0.03, 0.3, 0.0, {"tutte": e})
    m.scatola("testa", (0, H + TESTA * 0.78, 0), (TESTA + 0.22, 0.025, TESTA + 0.22), {"tutte": e})


def colbacco_ushanka(m, c="#5A4A3A", pelo="#7A6A5A", stella=True):
    H = m.posizione_osso("testa")[1]

    def fronte(pen):
        pen.riempi(pelo)
        if stella:
            pen.poligono([(0.5, 0.25), (0.56, 0.45), (0.74, 0.45), (0.6, 0.57), (0.66, 0.77), (0.5, 0.65), (0.34, 0.77), (0.4, 0.57), (0.26, 0.45), (0.44, 0.45)], "#C82828")
    m.scatola("testa", (0, H + TESTA + 0.06, 0), (TESTA + 0.08, 0.16, TESTA + 0.08), {"fronte": fronte, "tutte": tinta(pelo)})
    for x in (-1, 1):
        m.scatola("testa", (x * (TESTA / 2 + 0.05), H + TESTA * 0.62, 0), (0.05, 0.2, TESTA * 0.7), {"tutte": tinta(pelo)})


def soldato_fucile(nome, divisa, pantaloni_c, fasce, stivali, elmo, pelle=PELLI[1], baffi=None, extra=None, lungo=1.05,
                   baionetta=True, cinghie="#4A3A28"):
    m = Modello(nome)
    scheletro(m, mano_r=(-0.6, -0.45, -1), mano_l=(0.55, -0.5, -0.8))

    def busto(pen):
        pen.riempi(divisa)
        for v in (0.15, 0.35, 0.55):
            pen.ellisse(0.47, v, 0.53, v + 0.05, scuro(divisa, 0.4))
        pen.rett(0, 0.7, 1, 0.78, cinghie)
        for u in (0.12, 0.3, 0.7, 0.88):
            pen.rett(u - 0.07, 0.62, u + 0.07, 0.8, scuro(cinghie, 0.1))
        if extra:
            extra(pen)

    def lati(pen):
        pen.riempi(divisa)
        pen.rett(0, 0.7, 1, 0.78, cinghie)
    abito = {
        "busto": busto, "busto_retro": lati, "busto_lati": lati,
        "omero": tinta(divisa), "avambraccio": tinta(divisa), "mano": tinta(pelle, "pelle"),
        "coscia": tinta(pantaloni_c), "stinco": pantaloni(pantaloni_c, fasce=fasce, stivali=stivali, altezza_stivale=0.2 if fasce else 0.45)[1],
        "piede": tinta(stivali, "cuoio"),
        "testa": viso(pelle, bocca="seria", baffi=baffi), "testa_lati": capelli_lati(pelle, "#3A2A1E", 0.4),
        "testa_retro": capelli_retro("#3A2A1E", pelle, 0.75),
    }
    corpo(m, abito)
    elmo(m)
    fucile(m, lungo=lungo, baionetta=baionetta)
    return m


def squadra_mitraglia(nome, divisa, elmo, arma="maxim", pelle=PELLI[0], baffi=None, scudo=False):
    """Mitraglieri in ginocchio dietro l'arma (come il Mitragliere): Maxim su treppiede o su ruote (sovietica),
    MG 42 sul bipiede."""
    m = Modello(nome)
    scheletro(m, mano_r=(-0.3, 0.2, -1), mano_l=(0.3, 0.25, -1), bacino_y=0.5, ginocchia=((0, 0.1, -0.06), (0, 0.08, 0.36)))
    m.osso("terra", None, (0, 0, 0))
    abito = {
        "busto": busto_semplice(divisa, cintura="#4A3A28"), "busto_retro": tinta(divisa), "busto_lati": tinta(divisa),
        "omero": tinta(divisa), "avambraccio": tinta(divisa), "mano": tinta(pelle, "pelle"),
        "coscia": tinta(scuro(divisa, 0.05)), "stinco": tinta(scuro(divisa, 0.15)), "piede": tinta("#2E2218", "cuoio"),
        "testa": viso(pelle, bocca="decisa", baffi=baffi), "testa_lati": capelli_lati(pelle, "#2A2018", 0.4),
        "testa_retro": capelli_retro("#2A2018", pelle, 0.75),
    }
    corpo(m, abito)
    elmo(m)
    pugno_r, _ = punto_mano(m, "R")
    pugno_l, _ = punto_mano(m, "L")
    y = (pugno_r[1] + pugno_l[1]) / 2 + 0.03
    culatta = np.array([0.0, y, (pugno_r[2] + pugno_l[2]) / 2 - 0.05])
    m.osso("mitragliatrice", None, culatta)
    bocca = culatta + np.array([0, 0.02, -0.95])
    m.osso("canna", "mitragliatrice", bocca)
    ferro = tinta("#2E3034", "metallo")
    if arma == "mg42":
        m.segmento("mitragliatrice", culatta + np.array([0, 0, -0.45]), culatta + np.array([0, 0, 0.2]), 0.09, 0.11, {"tutte": ferro}, alto=(0, 1, 0))
        m.segmento("mitragliatrice", bocca, culatta + np.array([0, 0, -0.45]), 0.06, 0.06, {"tutte": tinta("#3A3C40", "metallo")}, alto=(0, 1, 0))
        for x in (-0.12, 0.12):
            asta(m, "terra", culatta + np.array([0, -0.02, -0.7]), np.array([x, 0.0, culatta[2] - 0.8]), 0.025, "#2E3034", "metallo")
    else:
        # Maxim: camicia d'acqua grossa, scudo d'acciaio, treppiede o ruote.
        m.segmento("mitragliatrice", culatta + np.array([0, 0, -0.3]), culatta + np.array([0, 0, 0.05]), 0.14, 0.16, {"tutte": ferro}, alto=(0, 1, 0))
        m.segmento("mitragliatrice", culatta + np.array([0, 0.02, -0.75]), culatta + np.array([0, 0.02, -0.3]), 0.13, 0.13,
                   {"tutte": tinta("#4A4E44", "metallo")}, alto=(0, 1, 0))
        m.segmento("mitragliatrice", bocca, culatta + np.array([0, 0.02, -0.75]), 0.04, 0.04, {"tutte": ferro}, alto=(0, 1, 0))
        if scudo:
            m.scatola("mitragliatrice", culatta + np.array([0, 0.05, -0.42]), (0.5, 0.42, 0.03), {"tutte": tinta("#4A5A3A", "metallo")})
            for x in (-0.28, 0.28):
                m.scatola("terra", (x, 0.18, culatta[2] - 0.3), (0.05, 0.36, 0.36), {"tutte": tinta("#3A3A3A", "metallo")})
        else:
            perno = culatta + np.array([0, -0.08, -0.25])
            for punta in ((0.0, 0.0, -0.75), (-0.32, 0.0, 0.05), (0.32, 0.0, 0.05)):
                piede = np.array([perno[0] + punta[0], 0.0, perno[2] + punta[2]])
                asta(m, "terra", perno, piede, 0.04, "#2E3034", "metallo")
    return m


@fante
def FanteOttomano():
    return soldato_fucile("FanteOttomano", "#9A8A5A", "#9A8A5A", "#7A6A4A", "#3A2A1C",
                          lambda m: turbante(m, "#8A7A4A", altezza=0.14), pelle=PELLI[2], baffi="#1A1410")


@fante
def MitraglieriOttomani():
    return squadra_mitraglia("MitraglieriOttomani", "#9A8A5A", lambda m: turbante(m, "#8A7A4A", altezza=0.14), pelle=PELLI[2], baffi="#1A1410")


@fante
def Stosstruppen():
    def granate(pen):
        for u in (0.25, 0.75):
            pen.rett(u - 0.03, 0.4, u + 0.03, 0.7, "#5A4A30")
    return soldato_fucile("Stosstruppen", "#6E7468", "#5E6458", None, "#2A2018", elmo_stahlhelm, pelle=PELLI[0], extra=granate)


@fante
def MitraglieriTedeschi():
    return squadra_mitraglia("MitraglieriTedeschi", "#6E7468", elmo_stahlhelm, pelle=PELLI[0], baffi="#3A2A1E")


@fante
def FanteBritannico():
    return soldato_fucile("FanteBritannico", "#7A6E48", "#7A6E48", "#6A5E40", "#3A2A1C", elmo_brodie, pelle=PELLI[0], baffi="#5A3A22")


@fante
def FucilieriSovietici():
    return soldato_fucile("FucilieriSovietici", "#7A6A48", "#5A5040", None, "#2A2018", colbacco_ushanka, pelle=PELLI[0], lungo=1.0)


@fante
def MitraglieriSovietici():
    return squadra_mitraglia("MitraglieriSovietici", "#7A6A48", colbacco_ushanka, pelle=PELLI[0], scudo=True)


@fante
def Granatieri():
    return soldato_fucile("Granatieri", "#5E6458", "#4E5448", None, "#1E1A16", lambda m: elmo_stahlhelm(m, "#6A7050"), pelle=PELLI[3],
                          baionetta=False)


@fante
def MG42():
    return squadra_mitraglia("MG42", "#5E6458", lambda m: elmo_stahlhelm(m, "#6A7050"), arma="mg42", pelle=PELLI[3])


@fante
def FanteFranciaLibera():
    def lorena(pen):
        pen.rett(0.2, 0.15, 0.24, 0.45, "#C8303A")
        pen.rett(0.15, 0.2, 0.29, 0.23, "#C8303A")
        pen.rett(0.13, 0.29, 0.31, 0.32, "#C8303A")
    def elmo_m1(m):  # la 2e DB di Leclerc vestiva all'americana: elmetto M1
        elmo_scatola(m, 0.05, 0.22, 0.03, {"tutte": tinta("#5A5E44", "metallo")})
    return soldato_fucile("FanteFranciaLibera", "#6A6A44", "#5A5A3E", None, "#4A3020", elmo_m1,
                          pelle=PELLI[1], extra=lorena, baionetta=False)


@fante
def Rommel():
    """Erwin Rommel, la Volpe del deserto: berretto con gli occhiali, sciarpa, binocolo, pistola."""
    m = Modello("Rommel")
    scheletro(m, mano_r=(0.15, -1, -0.25), mano_l=(0.1, -0.7, -1))
    pelle = PELLI[0]
    grigio = "#5E6458"

    def giacca(pen):
        pen.riempi(grigio)
        for v in (0.12, 0.3, 0.48):
            pen.ellisse(0.47, v, 0.53, v + 0.05, "#B8BCC4")
        pen.rett(0.3, 0, 0.7, 0.1, "#ECEAE2")  # sciarpa
        pen.rett(0.4, 0.06, 0.6, 0.14, "#1A1A1E")  # croce di cavaliere
        pen.rett(0, 0.68, 1, 0.75, "#3A2A1C")
        pen.rett(0.15, 0.2, 0.3, 0.35, "#1A1A1E")  # binocolo
    abito = {
        "busto": giacca, "busto_retro": tinta(grigio), "busto_lati": tinta(grigio),
        "omero": tinta(grigio), "avambraccio": tinta(grigio), "mano": tinta("#5A4030", "cuoio"),
        "coscia": tinta("#4E5448"), "stinco": pantaloni("#4E5448", stivali="#1E1A16", altezza_stivale=0.9)[1], "piede": tinta("#1E1A16", "cuoio"),
        "testa": viso(pelle, bocca="decisa"), "testa_lati": capelli_lati(pelle, "#5A4A3A", 0.35), "testa_retro": capelli_retro("#5A4A3A", pelle, 0.6),
    }
    corpo(m, abito)
    kepi(m, grigio, "#1A1A1E", alto=0.13)
    H = m.posizione_osso("testa")[1]
    m.scatola("testa", (0, H + TESTA + 0.12, -0.05), (TESTA * 0.8, 0.06, 0.1), {"tutte": tinta("#2A2A2A", "liscio")})  # occhiali
    pistola(m, "R")
    return m


# == SPECIALI: elefante, carri armati, cannoni ==============================================================

def speciale(f):
    SPECIALI[f.__name__] = lambda: f().costruisci(seme=sum(map(ord, f.__name__)) % 1000)
    return f


def pittore_pelle_elefante(c):
    def p(pen):
        pen.riempi(c, "pelle")
        for v in np.linspace(0.1, 0.9, 7):
            pen.linea([(0, v), (1, v + 0.04)], scuro(c, 0.12), 0.01)
    return p


@speciale
def Elefante():
    """Elefante da guerra cartaginese (Zama): stesse ossa del cavallo (così l'Animatore lo fa camminare e
    caricare come la cavalleria), coperta rossa e un conducente seduto sul dorso con il pungolo."""
    m = Modello("Elefante")
    grigio = "#8A8680"
    pelle_e = pittore_pelle_elefante(grigio)
    m.osso("cavallo", None, (0, 1.75, 0.2))
    m.osso("cavallo.collo", "cavallo", (0, 2.05, -0.85))
    m.osso("cavallo.muso", "cavallo.collo", (0, 1.95, -1.45))
    m.osso("cavallo.coda", "cavallo", (0, 2.0, 1.35))
    zampe = {"AR": (0.42, -0.55), "AL": (-0.42, -0.55), "PR": (0.42, 0.95), "PL": (-0.42, 0.95)}
    for nome, (x, z) in zampe.items():
        m.osso("zampa.%s1" % nome, "cavallo", (x, 1.3, z))
        m.osso("zampa.%s2" % nome, "zampa.%s1" % nome, (x, 0.72, z))
        m.osso("zampa.%s3" % nome, "zampa.%s2" % nome, (x, 0.15, z))
    # Corpo, testa, orecchie, proboscide, zanne, coda.
    m.scatola("cavallo", (0, 1.8, 0.2), (1.25, 1.2, 2.2), {"tutte": pelle_e})
    m.scatola("cavallo.collo", (0, 2.1, -1.1), (0.9, 0.95, 0.7), {"tutte": pelle_e, "fronte": pittore_pelle_elefante(grigio)})
    for x in (-1, 1):
        m.scatola("cavallo.collo", (x * 0.62, 2.15, -0.95), (0.08, 0.8, 0.6), {"tutte": tinta(scuro(grigio, 0.08), "pelle")})
        m.segmento("cavallo.collo", (x * 0.25, 1.85, -1.4), (x * 0.32, 1.6, -1.9), 0.09, 0.09, {"tutte": tinta("#F0EADA", "liscio")})
        # occhi
        m.scatola("cavallo.collo", (x * 0.3, 2.25, -1.46), (0.08, 0.08, 0.02), {"tutte": tinta("#1A1410")})
    m.segmento("cavallo.muso", (0, 1.95, -1.45), (0, 1.25, -1.7), 0.32, 0.3, {"tutte": pelle_e})
    m.segmento("cavallo.muso", (0, 1.25, -1.7), (0, 0.65, -1.62), 0.24, 0.22, {"tutte": pelle_e})
    m.segmento("cavallo.coda", (0, 2.0, 1.32), (0, 1.3, 1.45), 0.06, 0.06, {"tutte": tinta(scuro(grigio, 0.2))})
    for nome, (x, z) in zampe.items():
        m.segmento("zampa.%s1" % nome, (x, 1.45, z), (x, 0.72, z), 0.42, 0.42, {"tutte": pelle_e})
        m.segmento("zampa.%s2" % nome, (x, 0.72, z), (x, 0.15, z), 0.4, 0.4, {"tutte": pelle_e})
        m.scatola("zampa.%s3" % nome, (x, 0.08, z), (0.44, 0.16, 0.44), {"tutte": tinta(scuro(grigio, 0.15), "pelle")})

    def coperta(pen):
        pen.riempi("#A02828")
        pen.rett(0, 0.85, 1, 1, "#D8B048")
        pen.rett(0, 0, 1, 0.06, "#D8B048")
    m.scatola("cavallo", (0, 2.2, 0.15), (1.32, 0.6, 1.3), {"tutte": coperta, "sopra": tinta("#A02828")})
    # Conducente seduto sul dorso.
    seduta = 2.45
    scheletro(m, mano_r=(0, -0.2, -1), mano_l=(0.05, -0.6, -1), bacino_y=seduta)
    m.ossa[m.indice_ossa["bacino"]]["padre"] = "cavallo"
    for lato, s in (("L", -1), ("R", 1)):
        m.ossa[m.indice_ossa["coscia." + lato]]["posizione"] = [s * 0.15, seduta, 0.0]
        m.ossa[m.indice_ossa["stinco." + lato]]["posizione"] = [s * 0.6, seduta - 0.15, -0.2]
        m.ossa[m.indice_ossa["piede." + lato]]["posizione"] = [s * 0.68, seduta - 0.5, -0.1]
    pelle = PELLI[4]
    corpo(m, {
        "busto": busto_semplice("#E8E0C8", cintura="#7A4A2A"), "busto_retro": busto_semplice("#E8E0C8", cintura="#7A4A2A"),
        "busto_lati": tinta("#E8E0C8"), "omero": tinta(pelle, "pelle"), "avambraccio": tinta(pelle, "pelle"), "mano": tinta(pelle, "pelle"),
        "testa": viso(pelle, bocca="decisa", barba="#1A1410"), "testa_lati": capelli_lati(pelle, "#1A1410", 0.5),
        "testa_retro": capelli_retro("#1A1410", pelle, 0.8),
    }, gambe=False)
    gambe(m, tinta("#E8E0C8"), tinta(pelle, "pelle"), tinta(pelle, "pelle"))
    turbante(m, "#ECE6D6", altezza=0.12)
    lancia(m, 1.2, 0.4, "#7A5232")
    return m


def cingoli(m, x, lunghezza, alto, y, larghezza=0.55, c="#2E2C28"):
    def lato(pen):
        pen.riempi(c, "metallo")
        for u in np.linspace(0.02, 0.98, 28):
            pen.rett(u - 0.008, 0, u + 0.008, 1, scuro(c, 0.4))
        for u in np.linspace(0.1, 0.9, 6):  # ruote
            pen.ellisse(u - 0.06, 0.25, u + 0.06, 0.85, "#4A4A44")
            pen.ellisse(u - 0.02, 0.45, u + 0.02, 0.65, "#2A2A26")
    m.scatola("bacino", (x, y, 0), (larghezza, alto, lunghezza), {"destra": lato, "sinistra": lato, "tutte": tinta(c, "metallo")})


def pannello(c, righe=0, stella=None, croce_c=None, numero=None):
    def p(pen):
        pen.riempi(c, "metallo")
        for v in np.linspace(0.15, 0.85, righe) if righe else []:
            pen.rett(0, v - 0.01, 1, v + 0.01, scuro(c, 0.2))
        if stella:
            pen.poligono([(0.5, 0.2), (0.57, 0.42), (0.8, 0.42), (0.62, 0.56), (0.69, 0.8), (0.5, 0.66), (0.31, 0.8), (0.38, 0.56), (0.2, 0.42), (0.43, 0.42)], stella)
        if croce_c:
            pen.rett(0.42, 0.2, 0.58, 0.8, croce_c)
            pen.rett(0.25, 0.42, 0.75, 0.58, croce_c)
            pen.rett(0.45, 0.23, 0.55, 0.77, "#ECEAE2")
            pen.rett(0.28, 0.45, 0.72, 0.55, "#ECEAE2")
    return p


def ossa_carro(m, torretta_y, torretta_z, cannone_y, cannone_z, canna_z):
    m.osso("bacino", None, (0, 1.0, 0))
    m.osso("torretta", "bacino", (0, torretta_y, torretta_z))
    m.osso("cannone", "torretta", (0, cannone_y, cannone_z))
    m.osso("canna", "cannone", (0, cannone_y, canna_z))


@speciale
def T34():
    """T-34/76 di Stalingrado: scafo inclinato, torretta esagonale, cingoli larghi, verde con la stella rossa."""
    m = Modello("T34")
    verde = "#4E5A34"
    ossa_carro(m, 1.9, -0.3, 2.05, -1.1, -3.5)
    for x in (-1.25, 1.25):
        cingoli(m, x, 6.2, 1.05, 0.52)
    m.scatola("bacino", (0, 1.2, 0.1), (2.0, 0.75, 5.6), {"tutte": pannello(verde), "sopra": pannello(verde, 3)})
    # piastra frontale inclinata
    assi = np.column_stack([[1, 0, 0], [0, np.cos(1.0), -np.sin(1.0)], [0, np.sin(1.0), np.cos(1.0)]])
    m.scatola("bacino", (0, 1.2, -2.85), (2.0, 0.95, 0.12), {"tutte": pannello(verde)}, assi=assi)
    m.scatola("bacino", (0, 1.62, 0.4), (2.6, 0.12, 5.0), {"tutte": tinta(scuro(verde, 0.1), "metallo")})  # parafanghi
    m.scatola("torretta", (0, 1.95, -0.3), (1.7, 0.6, 1.9), {"tutte": pannello(verde, stella="#B82820"), "sopra": tinta(verde, "metallo")})
    m.scatola("torretta", (0, 2.3, -0.1), (0.5, 0.14, 0.5), {"tutte": tinta(scuro(verde, 0.2), "metallo")})
    m.segmento("cannone", (0, 2.05, -3.5), (0, 2.05, -1.2), 0.13, 0.13, {"tutte": tinta(scuro(verde, 0.25), "metallo")}, alto=(0, 1, 0))
    m.scatola("cannone", (0, 2.05, -1.25), (0.35, 0.3, 0.2), {"tutte": tinta(verde, "metallo")})
    # serbatoi sul retro
    for x in (-0.6, 0.6):
        m.segmento("bacino", (x, 1.35, 3.0), (x, 1.35, 2.5), 0.3, 0.3, {"tutte": tinta(scuro(verde, 0.15), "metallo")}, alto=(0, 1, 0))
    return m


@speciale
def Panzer():
    """Panzer IV di Normandia: scafo squadrato, torretta con le minigonne d'acciaio, cannone lungo, mimetica."""
    m = Modello("Panzer")
    sabbia = "#B8A26A"

    def mimetica(pen):
        pen.riempi(sabbia, "metallo")
        for (u0, v0, u1, v1, c) in ((0.05, 0.1, 0.35, 0.5, "#5E6A3A"), (0.45, 0.4, 0.8, 0.9, "#6A4A30"), (0.7, 0.05, 0.95, 0.35, "#5E6A3A")):
            pen.ellisse(u0, v0, u1, v1, c)
    ossa_carro(m, 1.95, 0.0, 2.15, -1.0, -4.2)
    for x in (-1.2, 1.2):
        cingoli(m, x, 5.8, 1.0, 0.5, larghezza=0.5)
    m.scatola("bacino", (0, 1.25, 0), (1.9, 0.9, 5.6), {"tutte": mimetica})
    for x in (-1.5, 1.5):  # minigonne laterali
        m.scatola("bacino", (x, 1.1, 0.2), (0.06, 0.8, 4.6), {"tutte": mimetica})
    m.scatola("torretta", (0, 2.05, 0.0), (1.8, 0.7, 2.2), {"tutte": pannello(sabbia, croce_c="#1A1A1E"), "sopra": mimetica})
    for x in (-1.0, 1.0):  # schermi della torretta
        m.scatola("torretta", (x, 2.0, 0.2), (0.05, 0.6, 2.2), {"tutte": mimetica})
    m.segmento("cannone", (0, 2.15, -4.2), (0, 2.15, -1.1), 0.12, 0.12, {"tutte": tinta("#3A3C34", "metallo")}, alto=(0, 1, 0))
    m.scatola("cannone", (0, 2.15, -4.25), (0.22, 0.2, 0.2), {"tutte": tinta("#3A3C34", "metallo")})  # freno di bocca
    m.scatola("torretta", (0, 2.5, 0.6), (0.6, 0.25, 0.6), {"tutte": mimetica})
    return m


@speciale
def CarroMarkV():
    """Mark V britannico del 1918 (Amiens): carro a rombo, cingoli che girano attorno a tutto lo scafo,
    casematte laterali con i cannoni, cabina di guida davanti."""
    m = Modello("CarroMarkV")
    oliva = "#6A6A44"
    m.osso("bacino", None, (0, 1.0, 0))
    m.osso("torretta", "bacino", (0, 2.4, -1.0))
    m.osso("cannone", "torretta", (0, 1.45, -0.6))
    m.osso("canna", "cannone", (0, 1.45, -1.9))

    def rombo(pen):
        pen.riempi(oliva, "metallo")
        for u in np.linspace(0.02, 0.98, 30):
            pen.rett(u - 0.006, 0, u + 0.006, 1, scuro(oliva, 0.35))
        for u in np.linspace(0.1, 0.9, 5):
            pen.ellisse(u - 0.02, 0.48, u + 0.02, 0.52, "#3A3A30")
    for x in (-1.05, 1.05):
        m.scatola("bacino", (x, 1.25, 0), (0.6, 2.4, 7.4), {"destra": rombo, "sinistra": rombo, "tutte": tinta(scuro(oliva, 0.2), "metallo")})
        # punte del rombo
        for z, s in ((-3.9, -1), (3.9, 1)):
            assi = np.column_stack([[1, 0, 0], [0, np.cos(0.6), s * np.sin(0.6)], [0, -s * np.sin(0.6), np.cos(0.6)]])
            m.scatola("bacino", (x, 1.25, z), (0.6, 1.8, 0.8), {"tutte": tinta(scuro(oliva, 0.2), "metallo")}, assi=assi)
    m.scatola("bacino", (0, 1.3, 0.3), (1.5, 1.6, 5.4), {"tutte": pannello(oliva, 3)})
    m.scatola("torretta", (0, 2.4, -1.0), (1.2, 0.6, 1.4), {"tutte": pannello(oliva)})  # cabina
    for x in (-1.55, 1.55):  # casematte
        m.scatola("cannone", (x, 1.45, -0.6), (0.5, 0.9, 1.4), {"tutte": pannello(oliva)})
        m.segmento("cannone", (x * 1.15, 1.45, -1.9), (x * 1.15, 1.45, -1.0), 0.12, 0.12, {"tutte": tinta("#3A3A30", "metallo")}, alto=(0, 1, 0))

    def bande(pen):
        pen.riempi("#ECEAE2")
        pen.rett(0.33, 0, 0.66, 1, "#B82820")
    m.scatola("bacino", (0, 1.9, -2.7), (1.5, 0.3, 0.05), {"tutte": bande})
    return m


# -- Cannoni dell'età della polvere da sparo ------------------------------------------------------------
# Tutto a scatole come il resto: le canne "tonde" sono due prismi quadrati uno dentro l'altro, girati di 45°
# (sezione a otto lati); le ruote hanno il cerchione a dodici pezzi, il cerchio di ferro e i raggi.
# Accanto al pezzo ci sono i serventi, costruiti a parte come i fanti e uniti al modello (legati al bacino).

ALTEZZA_PEZZO = 320  # righe dell'atlante per il cannone; sotto, la striscia dei serventi
BANDA_SERVENTI = LATO_SERVENTI = 192


def _perpendicolare(asse, preferito=(0.0, 1.0, 0.0)):
    rif = np.array(preferito, float)
    if abs(asse @ rif) > 0.9:
        rif = np.array([1.0, 0, 0])
    rif = rif - asse * (asse @ rif)
    return rif / np.linalg.norm(rif)


def prisma(m, osso, da, a, lato, pittori):
    """Cilindro a blocchi da "da" a "a", di diametro "lato": sezione a otto lati fatta da quattro tavole
    (larghe quanto il diametro, spesse 0,41 volte) girate di 45° l'una. Due quadrati girati farebbero una
    stella; le tavole invece riempiono l'ottagono giusto. Ognuna è appena più corta della precedente, così
    le facce in fondo non si sovrappongono."""
    da, a = np.array(da, float), np.array(a, float)
    asse = (da - a) / np.linalg.norm(da - a)
    rif = _perpendicolare(asse)
    altro = np.cross(asse, rif)
    for k in range(4):
        t = k * np.pi / 4
        verso = rif * np.cos(t) + altro * np.sin(t)
        m.segmento(osso, da - asse * 0.003 * k, a + asse * 0.003 * k, lato * 0.414, lato, pittori, alto=tuple(verso))


def palla_blocchi(m, osso, centro, d, pittori):
    """Palla (di pietra o di ferro): tre dischi a otto lati impilati, quasi tonda."""
    c = np.array(centro, float)
    su = np.array([0, 1.0, 0])
    prisma(m, osso, c + su * d * 0.2, c - su * d * 0.2, d, pittori)
    prisma(m, osso, c + su * d * 0.42, c - su * d * 0.42, d * 0.72, pittori)


def ruota_raggi(m, osso, centro, r, larghezza, legno, ferro, raggi=12):
    """Ruota di legno con l'asse lungo x: cerchione a pezzi, cerchio di ferro, raggi e mozzo."""
    c = np.array(centro, float)
    lg, fe = tinta(legno, "legno"), tinta(ferro, "metallo")
    for k in range(raggi):
        a0, a1 = 2 * np.pi * k / raggi, 2 * np.pi * (k + 1) / raggi
        for raggio, spessore, largo, colore in ((r - 0.05, 0.09, larghezza, lg), (r - 0.005, 0.025, larghezza + 0.012, fe)):
            p0 = c + np.array([0, raggio * np.cos(a0), raggio * np.sin(a0)])
            p1 = c + np.array([0, raggio * np.cos(a1), raggio * np.sin(a1)])
            m.segmento(osso, p0, p1, spessore, largo, {"tutte": colore}, oltre=(0.015, 0.015), alto=(1, 0, 0))
        am = (a0 + a1) / 2
        punta = c + np.array([0, (r - 0.08) * np.cos(am), (r - 0.08) * np.sin(am)])
        m.segmento(osso, punta, c, 0.045, 0.04, {"tutte": lg}, alto=(1, 0, 0))
    prisma(m, osso, c + np.array([0.13, 0, 0]), c - np.array([0.13, 0, 0]), 0.2, {"tutte": lg})
    prisma(m, osso, c + np.array([0.17, 0, 0]), c + np.array([0.12, 0, 0]), 0.13, {"tutte": fe})
    prisma(m, osso, c - np.array([0.12, 0, 0]), c - np.array([0.17, 0, 0]), 0.13, {"tutte": fe})


def bocca(m, osso, punto, diametro, colore, foro=0.62):
    """Il foro della bocca: una lastra sottile appena davanti alla canna (verso -z), col cerchio nero dipinto.
    Sta dentro l'ottagono della canna (lato 0,74 del diametro), così gli angoli non sporgono."""
    def p(pen):
        pen.riempi(scuro(colore, 0.12), "metallo")
        k = (1 - foro / 0.74) / 2
        pen.ellisse(k, k, 1 - k, 1 - k, "#141210")
    lato = diametro * 0.74
    m.scatola(osso, np.array(punto, float) + np.array([0, 0, -0.006]), (lato, lato, 0.01), {"fronte": p, "tutte": tinta(scuro(colore, 0.12), "metallo")})


def ossa_pezzo(m, cannone_y, cannone_z, canna_z):
    m.osso("bacino", None, (0, 0.6, 0))
    m.osso("torretta", "bacino", (0, 0.9, 0))
    m.osso("cannone", "torretta", (0, cannone_y, cannone_z))
    m.osso("canna", "cannone", (0, cannone_y, canna_z))


def con_serventi(dati, figura, posti, seme):
    """Unisce al cannone i serventi: "figura" è un Modello di soldato (con altezza_utile = BANDA_SERVENTI),
    "posti" una lista di (x, z, gradi) dove metterlo. La sua texture va nella striscia in basso dell'atlante."""
    fd = figura.costruisci(seme=seme)
    lato = dati["texture"].size[1]
    y0 = ALTEZZA_PEZZO
    dati["texture"].paste(fd["texture"].crop((0, 0, lato, BANDA_SERVENTI)), (0, y0))
    for x, z, gradi in posti:
        t = np.radians(gradi)
        R = np.array([[np.cos(t), 0, np.sin(t)], [0, 1, 0], [-np.sin(t), 0, np.cos(t)]])
        n = len(fd["pos"])
        parte = {
            "pos": fd["pos"] @ R.T + np.array([x, 0, z]), "normali": fd["normali"] @ R.T,
            "triangoli": fd["triangoli"], "uv": fd["uv"] + np.array([0, y0 / lato]),
            "ossa_v": np.zeros((n, 4), dtype=int), "pesi": np.tile([1.0, 0, 0, 0], (n, 1)),
        }
        dati = unisci(dati, parte)
    return dati


def servente(nome, abito, cappello, attrezzo, mano_r, mano_l):
    """Un artigliere in piedi con il suo attrezzo (scovolo, calcatoio o buttafuoco)."""
    m = Modello(nome)
    m.altezza_utile = BANDA_SERVENTI
    scheletro(m, mano_r=mano_r, mano_l=mano_l)
    corpo(m, abito)
    cappello(m)
    attrezzo(m)
    return m


def scovolo(c_testa="#2A2420", lungo=1.9):
    """Asta lunga tenuta di traverso con le due mani, con la testa di setole (o il calcatoio) in cima."""
    def f(m):
        pugno_r, _ = punto_mano(m, "R")
        pugno_l, _ = punto_mano(m, "L")
        d = pugno_l - pugno_r
        d = d / np.linalg.norm(d)
        cima = pugno_r + d * (lungo * 0.62)
        fondo = pugno_r - d * (lungo * 0.38)
        asta(m, "mano.R", cima, fondo, 0.04, LEGNO)
        prisma(m, "mano.R", cima + d * 0.22, cima - d * 0.02, 0.13, {"tutte": tinta(c_testa)})
    return f


def buttafuoco(lungo=1.3):
    """Asta del buttafuoco ritta nella mano destra, con la miccia accesa in cima."""
    def f(m):
        pugno_r, _ = punto_mano(m, "R")
        cima = pugno_r + np.array([0.02, lungo * 0.7, -0.08])
        asta(m, "mano.R", cima, pugno_r - np.array([0, lungo * 0.3, 0]), 0.035, LEGNO)
        m.segmento("mano.R", cima + np.array([0.12, 0.05, 0]), cima, 0.03, 0.03, {"tutte": tinta("#3A2A1A", "cuoio")})
        m.scatola("mano.R", cima + np.array([0.13, 0.06, 0]), (0.05, 0.05, 0.05), {"tutte": tinta("#FF8A2A", "liscio")})
    return f


def pallottola(m):
    """Una palla di ferro tenuta davanti con due mani (per caricare)."""
    pugno_r, _ = punto_mano(m, "R")
    pugno_l, _ = punto_mano(m, "L")
    palla_blocchi(m, "mano.R", (pugno_r + pugno_l) / 2 + np.array([0, 0.05, -0.04]), 0.15, {"tutte": tinta("#2A2A2C", "metallo")})


# -- Bombarda ottomana di Costantinopoli ------------------------------------------------------------------

BRONZO_OTTOMANO = "#B4843E"


def _bombarda():
    m = Modello("CannoneOttomano")
    m.altezza_utile = ALTEZZA_PEZZO
    Y = 0.8
    ossa_pezzo(m, Y, 0.2, -2.2)
    br = BRONZO_OTTOMANO
    bronzo = tinta(br, "metallo")
    scuro_b = tinta(scuro(br, 0.22), "metallo")

    def scritta(pen):
        # fascia con l'iscrizione incisa (segni corti, come una riga di scrittura)
        pen.riempi(br, "metallo")
        pen.rett(0, 0.25, 1, 0.75, scuro(br, 0.12))
        for k in range(22):
            u = 0.03 + k * 0.044
            pen.rett(u, 0.38, u + 0.025, 0.62 if k % 3 else 0.5, scuro(br, 0.45))

    # Camera della polvere (dietro, più stretta) e tromba (davanti, larga per la palla di pietra).
    prisma(m, "cannone", (0, Y, 0.3), (0, Y, 1.45), 0.62, {"tutte": bronzo})
    prisma(m, "cannone", (0, Y, 1.45), (0, Y, 1.6), 0.5, {"tutte": scuro_b})
    prisma(m, "cannone", (0, Y, -2.0), (0, Y, 0.3), 0.86, {"tutte": bronzo})
    prisma(m, "cannone", (0, Y, -2.2), (0, Y, -1.95), 0.98, {"tutte": scuro_b})
    bocca(m, "cannone", (0, Y, -2.2), 0.98, br, 0.72)
    # Il manicotto della vite che univa le due metà, con le prese per girarle.
    prisma(m, "cannone", (0, Y, 0.48), (0, Y, 0.18), 0.84, {"tutte": scuro_b})
    for k in range(8):
        a = k * np.pi / 4
        m.scatola("cannone", (0.43 * np.cos(a), Y + 0.43 * np.sin(a), 0.33), (0.12, 0.12, 0.26), {"tutte": scuro_b},
                  assi=np.array([[np.cos(a), -np.sin(a), 0], [np.sin(a), np.cos(a), 0], [0, 0, 1]]))
    # Anelli e la fascia con l'iscrizione.
    for z in (-1.55, -0.65, -0.15):
        prisma(m, "cannone", (0, Y, z - 0.05), (0, Y, z + 0.05), 0.91, {"tutte": scuro_b})
    prisma(m, "cannone", (0, Y, -1.4), (0, Y, -0.8), 0.875, {"tutte": scritta})

    # Il letto di travi: due longheroni, le traverse sotto, le sponde che tengono la canna, i cunei.
    legno = "#6A4A2A"
    lg, lg_s = tinta(legno, "legno"), tinta(scuro(legno, 0.25), "legno")
    for x in (-0.42, 0.42):
        m.scatola("bacino", (x, 0.17, -0.2), (0.3, 0.32, 3.9), {"tutte": lg})
        m.scatola("bacino", (x * 1.15, 0.52, -0.2), (0.12, 0.4, 3.2), {"tutte": lg})
    for z in (-1.9, -0.8, 0.4, 1.5):
        m.scatola("bacino", (0, 0.06, z), (1.5, 0.12, 0.26), {"tutte": lg_s})
    for z in (-1.6, 0.9):
        m.scatola("bacino", (0, 0.36, z), (0.75, 0.16, 0.5), {"tutte": lg_s})
    m.scatola("bacino", (0, 0.42, -1.6), (0.45, 0.1, 0.42), {"tutte": lg}, assi=np.array([[1, 0, 0], [0, 0.97, 0.24], [0, -0.24, 0.97]]))
    # Dietro, la palizzata di pali e il terrapieno che reggevano il rinculo.
    for x in (-0.55, -0.18, 0.18, 0.55):
        m.scatola("bacino", (x, 0.65, 1.95), (0.26, 1.3, 0.26), {"tutte": lg})
    m.scatola("bacino", (0, 1.15, 1.85), (1.5, 0.22, 0.2), {"tutte": lg_s})
    m.scatola("bacino", (0, 0.3, 2.25), (1.7, 0.6, 0.5), {"tutte": tinta("#7A6448", "cuoio")})
    # Le palle di pietra pronte, a mucchio sul lato.
    pietra = {"tutte": tinta("#9C968A", "liscio")}
    for x, y, z in ((1.05, 0.3, -0.4), (1.05, 0.3, 0.25), (1.05, 0.82, -0.08), (-1.05, 0.3, 0.6)):
        palla_blocchi(m, "bacino", (x, y, z), 0.56, pietra)

    pelle = PELLI[2]
    rosso, blu = "#A02828", "#2A4E8A"
    abito = {
        "busto": tinta(rosso), "busto_retro": tinta(rosso), "busto_lati": tinta(rosso),
        "omero": tinta(rosso), "avambraccio": tinta(rosso), "mano": tinta(pelle, "pelle"),
        "coscia": tinta(blu), "stinco": pantaloni(blu, stivali="#C8A030", altezza_stivale=0.4)[1], "piede": tinta("#C8A030", "cuoio"),
        "testa": viso(pelle, bocca="decisa", baffi="#1A1410"), "testa_lati": capelli_lati(pelle, "#1A1410", 0.3),
        "testa_retro": capelli_retro("#1A1410", pelle, 0.5),
    }

    def cappello(f):
        turbante(f, "#ECE6D6", altezza=0.18)
        H = f.posizione_osso("testa")[1]
        f.scatola("testa", (0, H + TESTA * 0.82 + 0.22, 0.01), (TESTA * 0.5, 0.12, TESTA * 0.5), {"tutte": tinta(rosso)})
        f.scatola("busto" if "busto" in f.indice_ossa else "torace", (0, GAMBE + 0.05, 0), (BUSTO_L + 0.03, 0.09, BUSTO_P + 0.03), {"tutte": tinta("#D8A830")})

    topci = servente("Topci", abito, cappello, scovolo("#3A2E24", lungo=2.2), mano_r=(-0.5, -0.2, -1), mano_l=(0.5, 0.1, -1))
    dati = m.costruisci(seme=sum(map(ord, "CannoneOttomano")) % 1000)
    return con_serventi(dati, topci, [(1.4, -1.6, 35), (-1.25, -0.6, -20)], seme=77)


# -- Cannone da 12 libbre di Gribeauval (Austerlitz, Borodino, Waterloo) -----------------------------------

def _gribeauval():
    m = Modello("Artiglieria")
    m.altezza_utile = ALTEZZA_PEZZO
    Y = 1.02
    ossa_pezzo(m, Y, -0.25, -2.0)
    br = "#B88A44"
    bronzo, scuro_b = tinta(br, "metallo"), tinta(scuro(br, 0.2), "metallo")
    # Canna: culatta e primo rinforzo, secondo rinforzo, volata, gioia della bocca.
    prisma(m, "cannone", (0, Y, -0.35), (0, Y, 0.45), 0.27, {"tutte": bronzo})
    prisma(m, "cannone", (0, Y, -0.95), (0, Y, -0.35), 0.235, {"tutte": bronzo})
    prisma(m, "cannone", (0, Y, -1.78), (0, Y, -0.95), 0.2, {"tutte": bronzo})
    prisma(m, "cannone", (0, Y, -2.0), (0, Y, -1.78), 0.26, {"tutte": scuro_b})
    bocca(m, "cannone", (0, Y, -2.0), 0.26, br, 0.55)
    for z in (0.45, -0.35, -0.95):
        prisma(m, "cannone", (0, Y, z - 0.03), (0, Y, z + 0.03), 0.29 if z > 0 else 0.255, {"tutte": scuro_b})
    prisma(m, "cannone", (0, Y, 0.62), (0, Y, 0.45), 0.12, {"tutte": scuro_b})  # bottone di culatta
    palla_blocchi(m, "cannone", (0, Y, 0.68), 0.13, {"tutte": scuro_b})
    # Orecchioni e i due "delfini" (maniglie) sopra.
    prisma(m, "cannone", (0.24, Y, -0.25), (-0.24, Y, -0.25), 0.09, {"tutte": scuro_b})
    for x in (-0.07, 0.07):
        m.scatola("cannone", (x, Y + 0.17, -0.45), (0.04, 0.05, 0.22), {"tutte": scuro_b})
        m.scatola("cannone", (x, Y + 0.13, -0.36), (0.04, 0.07, 0.04), {"tutte": scuro_b})
        m.scatola("cannone", (x, Y + 0.13, -0.54), (0.04, 0.07, 0.04), {"tutte": scuro_b})

    # Affusto verde: le due cosce dalla sala fino alla coda a terra, le traverse, le ferramenta nere.
    verde, ferro = "#4E6A3A", "#26282A"
    vd, fe = tinta(verde, "legno"), tinta(ferro, "metallo")
    for x in (-0.2, 0.2):
        m.segmento("bacino", (x, 0.98, -0.32), (x * 0.7, 0.16, 2.15), 0.3, 0.1, {"tutte": vd}, alto=(1, 0, 0))
        for t in (0.15, 0.45, 0.75):
            p = np.array([x, 0.98, -0.32]) + t * (np.array([x * 0.7, 0.16, 2.15]) - np.array([x, 0.98, -0.32]))
            m.scatola("bacino", p, (0.115, 0.32, 0.05), {"tutte": fe})
    m.scatola("bacino", (0, 0.72, 0), (1.26, 0.14, 0.14), {"tutte": fe})  # sala delle ruote
    for z, y in ((0.35, 0.82), (1.2, 0.5)):
        m.scatola("bacino", (0, y, z), (0.34, 0.12, 0.16), {"tutte": vd})
    m.scatola("bacino", (0, 0.13, 2.18), (0.32, 0.18, 0.2), {"tutte": vd})
    m.scatola("bacino", (0, 0.2, 2.3), (0.14, 0.14, 0.05), {"tutte": fe})  # occhione della coda
    m.scatola("bacino", (0, 0.86, 0.32), (0.22, 0.1, 0.34), {"tutte": tinta("#5A3A22", "legno")})  # cuneo di mira
    for x in (-0.68, 0.68):
        ruota_raggi(m, "bacino", (x, 0.72, 0.0), 0.72, 0.09, verde, ferro)
    # Le palle impilate dietro e il secchio.
    for i, (x, z) in enumerate(((0.75, 1.3), (0.9, 1.3), (0.825, 1.43))):
        palla_blocchi(m, "bacino", (x, 0.07, z), 0.14, {"tutte": tinta("#2A2A2C", "metallo")})
    palla_blocchi(m, "bacino", (0.825, 0.19, 1.34), 0.14, {"tutte": tinta("#2A2A2C", "metallo")})
    prisma(m, "bacino", (-0.8, 0.3, 1.4), (-0.8, 0.0, 1.4), 0.24, {"tutte": tinta("#6A4428", "legno")})

    pelle = PELLI[1]
    blu, rosso = "#22305E", "#B82820"
    abito = {
        "busto": giubba(blu, rosso, cintura=None), "busto_retro": tinta(blu), "busto_lati": tinta(blu),
        "omero": tinta(blu), "avambraccio": tinta(blu), "mano": tinta(pelle, "pelle"),
        "coscia": tinta(blu), "stinco": pantaloni(blu, stivali="#1A1A1E", altezza_stivale=0.45)[1], "piede": tinta("#1A1A1E", "cuoio"),
        "testa": viso(pelle, bocca="decisa", baffi="#3A2A1E"), "testa_lati": capelli_lati(pelle, "#3A2A1E", 0.4),
        "testa_retro": capelli_retro("#3A2A1E", pelle, 0.75),
    }

    def cappello(f):
        shako(f, pennacchio=rosso)
        for x in (-1, 1):  # spalline rosse
            f.scatola("torace", (x * (BUSTO_L / 2 + 0.02), COLLO - 0.04, 0), (0.16, 0.05, 0.2), {"tutte": tinta(rosso)})

    cannoniere = servente("Cannoniere", abito, cappello, scovolo("#2A2420", lungo=2.0), mano_r=(-0.5, -0.2, -1), mano_l=(0.5, 0.1, -1))
    dati = m.costruisci(seme=sum(map(ord, "Artiglieria")) % 1000)
    return con_serventi(dati, cannoniere, [(0.85, -1.35, 40), (-0.85, 1.0, -15)], seme=55)


SPECIALI["CannoneOttomano"] = _bombarda
SPECIALI["Artiglieria"] = _gribeauval


# == COSTRUZIONE ===========================================================================================

def costruisci_cavaliere(nome, funzione, cavallo):
    vecchio = vecchio_modello(cavallo)
    m = funzione(vecchio)
    dati = m.costruisci(seme=sum(map(ord, nome)) % 1000)
    dati["pos"] = SEDUTA + (dati["pos"] - SEDUTA) * SCALA
    for o in dati["ossa"]:
        if not cavalli._cavallo(o["nome"]):
            o["posizione"] = list(SEDUTA + (np.array(o["posizione"]) - SEDUTA) * SCALA)
    os.makedirs(CACHE, exist_ok=True)
    cache = os.path.join(CACHE, cavallo + ".pickle")
    if os.path.exists(cache):
        cav, img = pickle.load(open(cache, "rb"))
    else:
        cav, img = cavalli.cuoci(vecchio, LATO, BANDA_CAVALLO)
        pickle.dump((cav, img), open(cache, "wb"))
    y0 = LATO - BANDA_CAVALLO
    dati["texture"].paste(img, (0, y0))
    nomi_vecchi = [o["nome"] for o in vecchio["ossa"]]
    mappa = np.array([m.indice_ossa.get(n, 0) for n in nomi_vecchi])
    parte = {
        "pos": cav["pos"], "normali": cav["normali"], "triangoli": cav["triangoli"],
        "uv": (cav["uv_px"] + np.array([0, y0])) / LATO,
        "ossa_v": mappa[cav["ossa_v"]], "pesi": cav["pesi"],
    }
    return unisci(dati, parte)


def costruisci(nome):
    if nome in FANTI:
        return FANTI[nome]().costruisci(seme=sum(map(ord, nome)) % 1000)
    if nome in CAVALIERI:
        funzione, cavallo = CAVALIERI[nome]
        return costruisci_cavaliere(nome, funzione, cavallo)
    return SPECIALI[nome]()


def main():
    nomi = [a for a in sys.argv[1:] if not a.startswith("--")] or list(FANTI) + list(CAVALIERI) + list(SPECIALI)
    for nome in nomi:
        dati = costruisci(nome)
        meshdati.scrivi(nome, dati, "truppa nuova a blocchi", radice=USCITA)
        print(nome, len(dati["pos"]), "vertici")


if __name__ == "__main__":
    main()
