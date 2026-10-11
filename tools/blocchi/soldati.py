"""I soldati a blocchi di Evolve Your Army: corpo come i personaggi di Roblox (un po' più stretto),
vestiti, armature e armi disegnati qui. Scrive i modelli in src/shared/MeshDati con le stesse ossa dei
vecchi modelli Blender, così le animazioni restano quelle.

Uso: python3 tools/blocchi/soldati.py [Nome ...] [--glb cartella]   (senza nomi: tutti)
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import meshdati  # noqa: E402
from costruttore import Modello, chiaro, colore, mescola, scuro  # noqa: E402

# Misure del corpo (metri). Un personaggio di Roblox ha busto 2x2x1, braccia e gambe 1x2x1, testa ~1,2:
# qui le stesse proporzioni, un po' più strette, e alto circa 1,86 m (4,3 studs nel gioco).
GAMBE = 0.74
BUSTO_A = 0.70
BUSTO_L = 0.58
BUSTO_P = 0.31
BRACCIO_L = 0.26
BRACCIO_P = 0.29
GAMBA_L = 0.28
GAMBA_P = 0.29
TESTA = 0.40
SPALLA = GAMBE + BUSTO_A - 0.08
COLLO = GAMBE + BUSTO_A
X_BRACCIO = BUSTO_L / 2 + BRACCIO_L / 2 + 0.005
X_GAMBA = GAMBA_L / 2 + 0.005
OMERO = 0.36  # spalla -> gomito
AVAMBRACCIO = 0.28  # gomito -> polso

PELLI = ["#E8B48C", "#D9A27A", "#C98E64", "#F0C49E", "#B97F58"]


# -- Pittori di base -------------------------------------------------------------------------------------

def tinta(c, materiale="stoffa"):
    def p(pen):
        pen.riempi(c, materiale)
    return p


def viso(pelle, occhi="#1C1A1E", sopracciglia=None, bocca="seria", baffi=None, benda=False, barba=None, capelli=None,
         frangia=0.0):
    """Faccia alla Roblox: occhi ovali scuri con un punto di luce, sopracciglia, bocca semplice."""
    sopracciglia = sopracciglia or scuro(pelle, 0.6)

    def p(pen):
        pen.riempi(pelle, "pelle")
        if capelli:
            pen.rett(0, 0, 1, 0.12 + frangia, capelli)
        if barba:
            pen.poligono([(0, 0.62), (1, 0.62), (1, 0.85), (0.75, 1), (0.25, 1), (0, 0.85)], barba)
        for u in (0.3, 0.7):
            pen.ellisse(u - 0.075, 0.38, u + 0.075, 0.56, occhi)
            pen.ellisse(u - 0.035, 0.40, u + 0.005, 0.46, "#FFFFFF")
            pen.rett(u - 0.11, 0.30, u + 0.11, 0.34, sopracciglia)
        if benda:
            pen.linea([(0.0, 0.22), (1.0, 0.36)], "#1A1410", 0.012)
            pen.ellisse(0.18, 0.34, 0.42, 0.6, "#1A1410")
        if baffi:
            pen.poligono([(0.3, 0.66), (0.5, 0.63), (0.7, 0.66), (0.72, 0.72), (0.5, 0.69), (0.28, 0.72)], baffi)
        if bocca == "seria":
            pen.rett(0.38, 0.75, 0.62, 0.78, scuro(pelle, 0.55))
        elif bocca == "decisa":
            pen.poligono([(0.36, 0.77), (0.64, 0.74), (0.64, 0.77), (0.36, 0.8)], scuro(pelle, 0.55))
        elif bocca == "sorriso":
            pen.poligono([(0.34, 0.72), (0.66, 0.72), (0.6, 0.79), (0.4, 0.79)], scuro(pelle, 0.6))
            pen.rett(0.4, 0.72, 0.6, 0.745, "#F4F0E8")
    return p


def capelli_lati(pelle, capelli, altezza=0.35):
    def p(pen):
        pen.riempi(pelle, "pelle")
        pen.rett(0, 0, 1, altezza, capelli)
        pen.rett(0.55, altezza, 1.0, altezza + 0.12, capelli)
        pen.ellisse(0.35, 0.45, 0.55, 0.65, scuro(pelle, 0.15))  # orecchio
    return p


def capelli_retro(capelli, pelle, altezza=0.7):
    def p(pen):
        pen.riempi(pelle, "pelle")
        pen.rett(0, 0, 1, altezza, capelli)
    return p


# -- Corpo -----------------------------------------------------------------------------------------------

def scheletro(m, mano_r, mano_l, bacino_y=GAMBE, ginocchia=None):
    """Ossa del soldato in piedi. mano_r/mano_l: direzione dell'avambraccio (dal gomito al polso).
    In ginocchio: bacino_y più basso e ginocchia = (ginocchio, caviglia) del lato destro."""
    dy = bacino_y - GAMBE
    m.osso("bacino", None, (0, bacino_y, 0))
    m.osso("spina", "bacino", (0, bacino_y + 0.12, 0))
    m.osso("torace", "spina", (0, bacino_y + 0.34, 0))
    m.osso("testa", "torace", (0, COLLO + dy, 0))
    for lato, segno, direzione in (("L", -1, mano_l), ("R", 1, mano_r)):
        spalla = np.array([segno * X_BRACCIO, SPALLA + dy, 0])
        gomito = spalla + np.array([0, -OMERO, 0])
        d = np.array(direzione, float)
        d = d / np.linalg.norm(d)
        polso = gomito + d * AVAMBRACCIO
        m.osso("braccio." + lato, "torace", spalla)
        m.osso("avambraccio." + lato, "braccio." + lato, gomito)
        m.osso("mano." + lato, "avambraccio." + lato, polso)
    for lato, segno in (("L", -1), ("R", 1)):
        m.osso("coscia." + lato, "bacino", (segno * X_GAMBA, bacino_y, 0))
        if ginocchia:
            g, c = ginocchia
            m.osso("stinco." + lato, "coscia." + lato, (segno * X_GAMBA, g[1], g[2]))
            m.osso("piede." + lato, "stinco." + lato, (segno * X_GAMBA, c[1], c[2]))
        else:
            m.osso("stinco." + lato, "coscia." + lato, (segno * X_GAMBA, bacino_y * 0.52, 0))
            m.osso("piede." + lato, "stinco." + lato, (segno * X_GAMBA, 0.07, 0))


def corpo(m, abito, braccia=True, gambe=True, testa=True):
    """Le scatole del corpo, dipinte con i pittori di "abito":
    busto, busto_retro, busto_lati, busto_sopra, coscia, stinco, piede, omero, avambraccio, mano, testa_* ."""
    P = m.posizione_osso
    g = lambda chiave, alt=None: abito.get(chiave, abito.get(alt) if alt else None)
    dy = P("bacino")[1] - GAMBE  # in ginocchio il busto scende
    # Busto
    m.scatola("torace", (0, GAMBE + BUSTO_A / 2 + dy, 0), (BUSTO_L, BUSTO_A, BUSTO_P), {
        "fronte": g("busto"), "retro": g("busto_retro", "busto"), "destra": g("busto_lati", "busto"),
        "sinistra": g("busto_lati", "busto"), "sopra": g("busto_sopra", "busto_lati"), "sotto": g("busto_sotto", "busto_lati"),
    }, pesi=[("torace", 0.75), ("spina", 0.25)])
    if testa:
        m.scatola("testa", (0, COLLO + TESTA / 2 + dy, 0), (TESTA, TESTA, TESTA), {
            "fronte": g("testa"), "retro": g("testa_retro"), "destra": g("testa_lati"), "sinistra": g("testa_lati"),
            "sopra": g("testa_sopra", "testa_retro"), "sotto": g("testa_sotto", "testa_retro"),
        })
    if braccia:
        for lato in ("L", "R"):
            spalla, gomito, polso = P("braccio." + lato), P("avambraccio." + lato), P("mano." + lato)
            # Omero: dal sopra della spalla (in pari col busto) al gomito.
            m.segmento("braccio." + lato, (spalla[0], COLLO + dy, spalla[2]), gomito, BRACCIO_L, BRACCIO_P,
                       {"tutte": g("omero"), "sopra": g("omero_sopra", "omero")}, oltre=(0, 0.04))
            m.segmento("avambraccio." + lato, gomito, polso, BRACCIO_L * 0.98, BRACCIO_P * 0.98,
                       {"tutte": g("avambraccio", "omero")}, oltre=(0.06, 0.0))
            d = (polso - gomito) / np.linalg.norm(polso - gomito)
            m.segmento("mano." + lato, polso, polso + d * 0.11, BRACCIO_L * 0.96, BRACCIO_P * 0.96,
                       {"tutte": g("mano")}, oltre=(0.0, 0.0))
    if gambe:
        for lato in ("L", "R"):
            anca, ginocchio, caviglia = P("coscia." + lato), P("stinco." + lato), P("piede." + lato)
            m.segmento("coscia." + lato, (anca[0], anca[1] + 0.02, anca[2]), ginocchio, GAMBA_L, GAMBA_P,
                       {"tutte": g("coscia"), "fronte": g("coscia_fronte", "coscia")}, oltre=(0, 0.02))
            m.segmento("stinco." + lato, ginocchio, (caviglia[0], 0.07, caviglia[2]), GAMBA_L * 0.99, GAMBA_P * 0.99,
                       {"tutte": g("stinco"), "fronte": g("stinco_fronte", "stinco")}, oltre=(0.02, 0))
            m.scatola("piede." + lato, (caviglia[0], 0.04, caviglia[2] - 0.025), (GAMBA_L * 0.99, 0.08, GAMBA_P + 0.05),
                      {"tutte": g("piede"), "sotto": tinta(scuro(colore("#3A2A1C"), 0.3), "cuoio")})


# -- Pezzi comuni ---------------------------------------------------------------------------------------

def elmo_scatola(m, alto, basso, sporgenza, pittori, osso="testa", y_extra=0.0, z=0.0):
    y_extra += m.posizione_osso("testa")[1] - COLLO
    """Calotta a scatola sopra la testa: da "basso" (altezza sul collo) fino a "alto" sopra la testa."""
    lato = TESTA + 2 * sporgenza
    y0 = COLLO + basso
    y1 = COLLO + TESTA + alto
    m.scatola(osso, (0, (y0 + y1) / 2 + y_extra, z), (lato, y1 - y0, lato), pittori)


def asta(m, osso, da, a, spessore, c, materiale="legno", **kw):
    m.segmento(osso, da, a, spessore, spessore, {"tutte": tinta(c, materiale)}, **kw)


def lama(m, osso, da, a, larghezza, spessore, c="#B8BCC4", piatto=(1, 0, 0)):
    m.segmento(osso, da, a, larghezza, spessore, {"tutte": tinta(c, "metallo")}, alto=piatto)


def punto_mano(m, lato, avanti=0.06):
    """Centro del pugno: poco oltre il polso lungo l'avambraccio."""
    gomito, polso = m.posizione_osso("avambraccio." + lato), m.posizione_osso("mano." + lato)
    d = (polso - gomito) / np.linalg.norm(polso - gomito)
    return polso + d * avanti, d


# -- Soldati ---------------------------------------------------------------------------------------------

ROSSO_ROMANO = "#9E2626"
BRONZO = "#B07A3A"
FERRO = "#8E949C"
CUOIO = "#6E4A2C"
LEGNO = "#7A5232"


def tunica_gambe(tunica, pelle, calzari="#5A3A22", orlo=0.45):
    """Coscia con la tunica fino a metà e la pelle sotto."""
    def coscia(pen):
        pen.riempi(pelle, "pelle")
        pen.rett(0, 0, 1, orlo, tunica)
        pen.rett(0, orlo - 0.04, 1, orlo, scuro(tunica, 0.3))

    def stinco(pen):
        pen.riempi(pelle, "pelle")
        for v in (0.55, 0.7, 0.85):
            pen.rett(0, v, 1, v + 0.05, calzari)
    return coscia, stinco


def Legionario():
    m = Modello("Legionario")
    scheletro(m, mano_r=(0, 0.05, -1), mano_l=(0.25, 0.1, -1))
    pelle = PELLI[0]
    tun = ROSSO_ROMANO
    coscia, stinco = tunica_gambe(tun, pelle)

    def lorica(pen):
        pen.riempi("#8C929A", "metallo")
        pen.righe_v(5, "#5C6168", 0.025, 0.25, 1.0)
        pen.rett(0, 0, 1, 0.22, "#9AA0A8")
        pen.rett(0.46, 0.0, 0.54, 0.22, "#C8A050")  # fibbie
        pen.rett(0, 0.9, 1, 1.0, "#6E4A2C")  # cingulum
        for u in (0.3, 0.4, 0.5, 0.6, 0.7):
            pen.rett(u - 0.015, 0.9, u + 0.015, 1.0, "#C8A050")

    def omero(pen):
        pen.riempi(pelle, "pelle")
        pen.rett(0, 0, 1, 0.45, "#8C929A")
        pen.righe_v(2, "#5C6168", 0.04, 0.0, 0.45)
        pen.materiale = "metallo"

    abito = {
        "busto": lorica, "busto_lati": lorica, "busto_retro": lorica,
        "omero": omero, "avambraccio": tinta(pelle, "pelle"), "mano": tinta(pelle, "pelle"),
        "coscia": coscia, "stinco": stinco, "piede": tinta("#5A3A22", "cuoio"),
        "testa": viso(pelle, bocca="decisa"), "testa_lati": capelli_lati(pelle, "#3A2A1E"),
        "testa_retro": capelli_retro("#3A2A1E", pelle),
    }
    corpo(m, abito)
    # Galea: calotta di bronzo con paranuca, guanciali e cresta rossa.
    elmo = tinta("#9AA0A8", "metallo")
    elmo_scatola(m, 0.04, 0.24, 0.02, {"tutte": elmo, "fronte": elmo})
    m.scatola("testa", (0, COLLO + 0.12, 0.2), (TESTA + 0.04, 0.1, 0.06), {"tutte": elmo})  # paranuca
    for x in (-1, 1):
        m.scatola("testa", (x * (TESTA / 2 + 0.02), COLLO + 0.13, -0.08), (0.025, 0.2, 0.18), {"tutte": elmo})
    m.scatola("testa", (0, COLLO + TESTA + 0.12, 0), (0.08, 0.13, TESTA + 0.02), {"tutte": tinta("#B22A22")})
    m.scatola("testa", (0, COLLO + TESTA * 0.62, -TESTA / 2 - 0.03), (TESTA + 0.04, 0.035, 0.03), {"tutte": elmo})  # visiera
    # Scudo (scutum) rettangolare e curvo sul braccio sinistro: tre pannelli.
    pugno_l, d_l = punto_mano(m, "L")
    centro_scudo = pugno_l + np.array([0.02, -0.06, -0.07])
    rosso_scudo = "#A8282A"

    def scutum(pen):
        pen.riempi(rosso_scudo, "cuoio")
        pen.rett(0, 0, 1, 0.04, "#C8A050")
        pen.rett(0, 0.96, 1, 1, "#C8A050")
        pen.ellisse(0.36, 0.42, 0.64, 0.58, "#C8A050")  # umbone
        pen.ellisse(0.42, 0.46, 0.58, 0.54, "#E0C070")
        for v in (0.2, 0.8):
            pen.rett(0.15, v - 0.012, 0.85, v + 0.012, "#E0C070")
        pen.poligono([(0.5, 0.06), (0.62, 0.3), (0.5, 0.36), (0.38, 0.3)], "#E0C070")  # ali di Giove
        pen.poligono([(0.5, 0.94), (0.62, 0.7), (0.5, 0.64), (0.38, 0.7)], "#E0C070")
    m.scatola("mano.L", centro_scudo, (0.6, 0.95, 0.05), {
        "fronte": scutum, "retro": tinta(scuro(rosso_scudo, 0.35), "cuoio"), "tutte": tinta("#C8A050", "metallo")})
    # Pilum nella destra: asta di legno e lungo ferro sottile.
    pugno_r, _ = punto_mano(m, "R")
    m.osso("lancia", "mano.R", m.posizione_osso("mano.R"))
    basso = pugno_r + np.array([0, -0.55, 0.05])
    alto = pugno_r + np.array([0, 0.75, -0.05])
    asta(m, "lancia", alto, basso, 0.04, LEGNO)
    lama(m, "lancia", alto + np.array([0, 0.55, -0.02]), alto, 0.025, 0.025, "#9AA0A8")
    m.scatola("lancia", alto, (0.06, 0.08, 0.06), {"tutte": tinta("#5C6168", "metallo")})
    m.scatola("lancia", alto + np.array([0, 0.58, -0.02]), (0.05, 0.08, 0.02), {"tutte": tinta("#B8BCC4", "metallo")})
    # Gladio al fianco destro (lo sguaina dopo il lancio).
    fianco = np.array([BUSTO_L / 2 + 0.03, GAMBE + 0.12, -0.02])
    m.osso("gladio", "bacino", fianco)
    m.scatola("gladio", fianco + np.array([0, -0.18, 0]), (0.05, 0.4, 0.09), {"tutte": tinta("#6E4A2C", "cuoio")})
    m.scatola("gladio", fianco + np.array([0, 0.06, 0]), (0.06, 0.1, 0.06), {"tutte": tinta("#C8A050", "metallo")})
    return m


def scudo_tondo(m, osso, centro, diametro, spessore, pittore_fronte, retro, assi=None):
    """Scudo rotondo a blocchi: tre lastre (larga, alta, media) che insieme fanno un ottagono.
    pittore_fronte(pen, cx, cy, r) dipinge in coordinate dello scudo (0-1 su tutto il diametro)."""
    for k, (fu, fv, dz) in enumerate(((1.0, 0.62, 0.0), (0.62, 1.0, 0.002), (0.86, 0.86, 0.004))):
        def pittore(pen, fu=fu, fv=fv):
            # Riquadro della lastra dentro il cerchio intero: si dipinge il disegno intero spostato.
            pen_scudo = _Sotto(pen, fu, fv)
            pittore_fronte(pen_scudo)
        locale = np.array([0, 0, -dz])
        c = np.array(centro, float) + (assi @ locale if assi is not None else locale)
        m.scatola(osso, c, (diametro * fu, diametro * fv, spessore), {"fronte": pittore, "retro": retro, "tutte": retro}, assi=assi)


class _Sotto:
    """Pennello che disegna su una lastra come se fosse tutto il disco (coordinate 0-1 del diametro)."""

    def __init__(self, pen, fu, fv):
        self.pen, self.fu, self.fv = pen, fu, fv

    def _uv(self, u, v):
        return (u - (1 - self.fu) / 2) / self.fu, (v - (1 - self.fv) / 2) / self.fv

    def riempi(self, c, materiale="stoffa"):
        self.pen.riempi(c, materiale)

    def ellisse(self, u0, v0, u1, v1, c):
        a, b = self._uv(u0, v0)
        d, e = self._uv(u1, v1)
        self.pen.ellisse(a, b, d, e, c)

    def rett(self, u0, v0, u1, v1, c):
        a, b = self._uv(u0, v0)
        d, e = self._uv(u1, v1)
        self.pen.rett(a, b, d, e, c)

    def poligono(self, punti, c):
        self.pen.poligono([self._uv(u, v) for u, v in punti], c)

    def linea(self, punti, c, spessore_m=0.01):
        self.pen.linea([self._uv(u, v) for u, v in punti], c, spessore_m)


def arco(m, osso, presa, altezza, curva, c="#6A4424", corda="#E8E0C8", avanti=(0, 0, -1), spessore=0.05):
    """Arco verticale tenuto per il centro: il centro sta avanti, le punte tornano verso l'arciere e la
    corda le unisce."""
    avanti = np.array(avanti, float)
    presa = np.array(presa, float)
    punti = [presa + np.array([0, t * altezza / 2, 0]) - avanti * (curva * t * t) for t in np.linspace(-1, 1, 7)]
    for a, b in zip(punti[:-1], punti[1:]):
        asta(m, osso, b, a, spessore, c, oltre=(0.012, 0.012))
    m.scatola(osso, presa, (spessore + 0.02, 0.13, spessore + 0.02), {"tutte": tinta("#3A2618", "cuoio")})
    asta(m, osso, punti[-1], punti[0], 0.012, corda, materiale="liscio")


def faretra(m, osso, centro, lunghezza, inclinazione_z, c="#6E4A2C"):
    """Faretra sulla schiena con le penne delle frecce che spuntano."""
    ang = np.radians(inclinazione_z)
    asse = np.array([np.sin(ang), np.cos(ang), 0])
    centro = np.array(centro, float)
    alto = centro + asse * lunghezza / 2
    basso = centro - asse * lunghezza / 2
    m.segmento(osso, alto, basso, 0.11, 0.11, {"tutte": tinta(c, "cuoio"), "sopra": tinta("#2A1E14", "cuoio")})
    for dx, colore_penna in ((-0.025, "#E8E2D0"), (0.0, "#B03028"), (0.025, "#E8E2D0")):
        punta = alto + asse * 0.1 + np.array([dx, 0, 0])
        m.segmento(osso, punta, alto, 0.025, 0.04, {"tutte": tinta(colore_penna)})


def mantello(m, colore_m, alto_y=COLLO - 0.02, basso_y=GAMBE * 0.35, largo=BUSTO_L + 0.06, bordo=None):
    """Mantello dietro le spalle, fino alle ginocchia."""
    def p(pen):
        pen.riempi(colore_m)
        if bordo:
            pen.rett(0, 0.94, 1, 1, bordo)
            pen.rett(0, 0, 0.05, 1, bordo)
            pen.rett(0.95, 0, 1, 1, bordo)
        for u in (0.25, 0.5, 0.75):  # pieghe
            pen.rett(u - 0.02, 0.15, u + 0.02, 1, scuro(colore_m, 0.18))
    m.scatola("torace", (0, (alto_y + basso_y) / 2, BUSTO_P / 2 + 0.03), (largo, alto_y - basso_y, 0.04), {"tutte": p},
              pesi=[("torace", 0.7), ("spina", 0.3)])


def pantaloni(c, fasce=None, stivali="#3A2A1C", altezza_stivale=0.25):
    def coscia(pen):
        pen.riempi(c)

    def stinco(pen):
        pen.riempi(c)
        if fasce:
            pen.rett(0, 0.1, 1, 1 - altezza_stivale, fasce)
            for v in np.linspace(0.15, 0.7, 6):
                pen.linea([(0, v), (1, v - 0.08)], scuro(fasce, 0.3), 0.006)
        pen.rett(0, 1 - altezza_stivale, 1, 1, stivali)
    return coscia, stinco


def ArciereCretese():
    m = Modello("ArciereCretese")
    scheletro(m, mano_r=(0.2, -1, -0.25), mano_l=(0.1, -0.75, -1))
    pelle = PELLI[2]
    tunica, bordo = "#E8DFC8", "#2E5A8C"
    coscia, stinco = tunica_gambe(tunica, pelle, calzari="#6A4628", orlo=0.4)

    def busto(pen):
        pen.riempi(tunica)
        pen.rett(0, 0, 1, 0.08, bordo)
        pen.poligono([(0.35, 0), (0.5, 0.18), (0.65, 0)], scuro(pelle, 0.05))
        pen.rett(0, 0.82, 1, 0.9, "#7A5232")  # cintura
        pen.linea([(0.0, 0.05), (1.0, 0.75)], "#5A3A22", 0.03)  # tracolla della faretra

    def busto_retro(pen):
        pen.riempi(tunica)
        pen.rett(0, 0.82, 1, 0.9, "#7A5232")
        pen.linea([(1.0, 0.05), (0.0, 0.75)], "#5A3A22", 0.03)

    def omero(pen):
        pen.riempi(pelle, "pelle")
        pen.rett(0, 0, 1, 0.35, tunica)
        pen.rett(0, 0.3, 1, 0.35, bordo)

    abito = {
        "busto": busto, "busto_retro": busto_retro, "busto_lati": tinta(tunica),
        "omero": omero, "avambraccio": tinta(pelle, "pelle"), "mano": tinta(pelle, "pelle"),
        "coscia": coscia, "stinco": stinco, "piede": tinta("#6A4628", "cuoio"),
        "testa": viso(pelle, bocca="seria", capelli="#2A1C14", frangia=0.04),
        "testa_lati": capelli_lati(pelle, "#2A1C14", 0.4), "testa_retro": capelli_retro("#2A1C14", pelle, 0.8),
        "testa_sopra": tinta("#2A1C14"),
    }
    corpo(m, abito)
    # Fascia sulla fronte
    m.scatola("testa", (0, COLLO + TESTA * 0.82, 0), (TESTA + 0.02, 0.05, TESTA + 0.02), {"tutte": tinta(bordo)})
    pugno, _ = punto_mano(m, "L")
    m.osso("arco", "mano.L", pugno)
    arco(m, "arco", pugno, 1.15, 0.16)
    faretra(m, "torace", (-0.08, GAMBE + BUSTO_A * 0.6, BUSTO_P / 2 + 0.07), 0.62, -25)
    return m


def Spadaccino():
    m = Modello("Spadaccino")
    scheletro(m, mano_r=(-0.1, -0.75, -1), mano_l=(-0.2, -1, -0.25))
    pelle = PELLI[3]
    capelli = "#B88A4A"

    def maglia(pen):
        pen.riempi("#7E848C", "metallo")
        pen.maglia("#B0B6BE", "#4E545C")

    def busto(pen):
        maglia(pen)
        pen.rett(0, 0.84, 1, 0.92, "#4A3020")  # cintura
        pen.rett(0.44, 0.83, 0.56, 0.93, "#C8A050")

    def omero(pen):
        maglia(pen)

    abito = {
        "busto": busto, "busto_retro": busto, "busto_lati": busto,
        "omero": omero, "avambraccio": tinta("#6A5A44"), "mano": tinta(pelle, "pelle"),
        "coscia": tinta("#6A5A44"), "stinco": pantaloni("#6A5A44", fasce="#8C7A5A", stivali="#3A2A1C", altezza_stivale=0.15)[1],
        "piede": tinta("#3A2A1C", "cuoio"),
        "testa": viso(pelle, bocca="decisa", barba=capelli, baffi=capelli),
        "testa_lati": capelli_lati(pelle, capelli, 0.5), "testa_retro": capelli_retro(capelli, pelle, 0.9),
    }
    corpo(m, abito)
    # Elmo conico con il nasale.
    elmo = tinta("#8A9098", "metallo")
    elmo_scatola(m, 0.02, 0.2, 0.02, {"tutte": elmo})
    m.scatola("testa", (0, COLLO + TESTA + 0.07, 0), (TESTA * 0.7, 0.07, TESTA * 0.7), {"tutte": elmo})
    m.scatola("testa", (0, COLLO + TESTA + 0.12, 0), (TESTA * 0.38, 0.05, TESTA * 0.38), {"tutte": elmo})
    m.scatola("testa", (0, COLLO + TESTA * 0.55, -TESTA / 2 - 0.03), (0.05, 0.18, 0.03), {"tutte": elmo})
    # Scudo rotondo dipinto (giallo e rosso, umbone di ferro) sul braccio sinistro, di lato.
    pugno_l, _ = punto_mano(m, "L")

    def disegno(pen):
        pen.riempi("#C8A040")
        for i in range(4):
            a0 = i * np.pi / 2
            pts = [(0.5, 0.5)] + [(0.5 + 0.5 * np.cos(a0 + t), 0.5 + 0.5 * np.sin(a0 + t)) for t in np.linspace(0, np.pi / 4, 6)]
            pen.poligono(pts, "#A02822")
        pen.ellisse(0.0, 0.0, 1.0, 1.0, "#A02822") if False else None
        pen.ellisse(0.38, 0.38, 0.62, 0.62, "#7E848C")
        pen.ellisse(0.44, 0.44, 0.56, 0.56, "#B0B6BE")
    assi = np.column_stack([[0, 0, 1], [0, 1, 0], [-1, 0, 0]])  # lo scudo guarda a sinistra (fuori)
    scudo_tondo(m, "mano.L", pugno_l + np.array([-0.08, 0.05, 0]), 0.78, 0.04, disegno, tinta("#6A4A2A", "legno"), assi=assi)
    # Ascia danese a due mani nella destra.
    pugno_r, _ = punto_mano(m, "R")
    alto = pugno_r + np.array([0, 0.85, -0.02])
    basso = pugno_r + np.array([0, -0.45, 0.02])
    asta(m, "mano.R", alto, basso, 0.045, LEGNO)
    m.scatola("mano.R", alto + np.array([0, -0.08, -0.12]), (0.03, 0.26, 0.22), {"tutte": tinta("#9AA0A8", "metallo")})
    return m


def Arciere():
    m = Modello("Arciere")
    scheletro(m, mano_r=(0.2, -1, -0.25), mano_l=(0.1, -0.75, -1))
    pelle = PELLI[3]
    giaco = "#E6DEC8"

    def busto(pen):
        pen.riempi(giaco)
        for u in np.linspace(0.1, 0.9, 6):  # trapuntatura
            pen.rett(u - 0.008, 0, u + 0.008, 0.82, scuro(giaco, 0.12))
        pen.rett(0.42, 0.08, 0.58, 0.7, "#B82820")  # croce di San Giorgio
        pen.rett(0.2, 0.25, 0.8, 0.37, "#B82820")
        pen.rett(0, 0.82, 1, 0.9, "#5A3A22")

    def lati(pen):
        pen.riempi(giaco)
        pen.rett(0, 0.82, 1, 0.9, "#5A3A22")

    def omero(pen):
        pen.riempi(giaco)
        pen.righe_v(3, scuro(giaco, 0.12), 0.03)

    calze, calze_s = "#4E6A3A", "#3A2A1C"
    abito = {
        "busto": busto, "busto_retro": lati, "busto_lati": lati,
        "omero": omero, "avambraccio": tinta("#4E6A3A"), "mano": tinta(pelle, "pelle"),
        "coscia": tinta(calze), "stinco": pantaloni(calze, stivali=calze_s, altezza_stivale=0.3)[1], "piede": tinta(calze_s, "cuoio"),
        "testa": viso(pelle, bocca="seria", capelli="#6A4424"),
        "testa_lati": capelli_lati(pelle, "#6A4424", 0.45), "testa_retro": capelli_retro("#6A4424", pelle, 0.85),
    }
    corpo(m, abito)
    # Cappello di ferro a tesa larga.
    elmo = tinta("#7E848C", "metallo")
    elmo_scatola(m, 0.04, 0.26, 0.015, {"tutte": elmo})
    m.scatola("testa", (0, COLLO + TESTA * 0.68, 0), (TESTA + 0.2, 0.03, TESTA + 0.2), {"tutte": elmo})
    pugno, _ = punto_mano(m, "L")
    m.osso("arco", "mano.L", pugno)
    arco(m, "arco", pugno, 1.5, 0.12, c="#7A5232")
    faretra(m, "bacino", (BUSTO_L / 2 + 0.07, GAMBE - 0.05, 0.05), 0.5, 12, c="#5A3A22")
    return m


def Fante():
    m = Modello("Fante")
    scheletro(m, mano_r=(-0.6, -0.45, -1), mano_l=(0.55, -0.5, -0.8))
    pelle = PELLI[1]
    blu = "#7A92B0"

    def cappotto(pen):
        pen.riempi(blu)
        pen.rett(0.47, 0, 0.53, 1, scuro(blu, 0.15))
        for v in (0.15, 0.35, 0.55):
            pen.ellisse(0.36, v, 0.42, v + 0.05, "#C8B070")
            pen.ellisse(0.58, v, 0.64, v + 0.05, "#C8B070")
        pen.rett(0, 0.7, 1, 0.78, "#4A3A28")  # cinturone
        for u in (0.12, 0.3, 0.7, 0.88):
            pen.rett(u - 0.07, 0.62, u + 0.07, 0.8, "#5A4430")  # giberne
        pen.rett(0.44, 0, 0.56, 0.08, "#2C3A5A")  # colletto

    def lati(pen):
        pen.riempi(blu)
        pen.rett(0, 0.7, 1, 0.78, "#4A3A28")

    coscia_c, stinco_c = pantaloni(blu, fasce="#6A7E96", stivali="#2E2218", altezza_stivale=0.2)

    def coscia(pen):  # le falde del cappotto coprono metà coscia
        pen.riempi(scuro(blu, 0.05))
        pen.rett(0, 0.55, 1, 1, mescola(blu, "#556070", 0.4))

    abito = {
        "busto": cappotto, "busto_retro": lati, "busto_lati": lati,
        "omero": tinta(blu), "avambraccio": tinta(blu), "mano": tinta(pelle, "pelle"),
        "coscia": coscia, "stinco": stinco_c, "piede": tinta("#2E2218", "cuoio"),
        "testa": viso(pelle, bocca="seria", baffi="#3A2A1E"),
        "testa_lati": capelli_lati(pelle, "#3A2A1E", 0.4), "testa_retro": capelli_retro("#3A2A1E", pelle, 0.75),
    }
    corpo(m, abito)
    # Elmo Adrian: calotta, tesa e cresta.
    elmo = tinta("#6E8098", "metallo")
    elmo_scatola(m, 0.04, 0.26, 0.015, {"tutte": elmo})
    m.scatola("testa", (0, COLLO + TESTA * 0.66, 0.02), (TESTA + 0.12, 0.025, TESTA + 0.16), {"tutte": elmo})
    m.scatola("testa", (0, COLLO + TESTA + 0.07, 0), (0.04, 0.05, TESTA * 0.8), {"tutte": elmo})
    m.scatola("testa", (0, COLLO + TESTA * 0.86, -TESTA / 2 - 0.02), (0.07, 0.07, 0.01), {"tutte": tinta("#C8B070", "metallo")})
    # Fucile Lebel con la baionetta, basso e pronto: dal calcio vicino alla mano destra in avanti.
    pugno_r, _ = punto_mano(m, "R")
    pugno_l, _ = punto_mano(m, "L")
    direzione = pugno_l - pugno_r
    direzione = direzione / np.linalg.norm(direzione)
    calcio = pugno_r - direzione * 0.3
    bocca = pugno_r + direzione * 1.05
    m.segmento("mano.R", bocca, calcio, 0.06, 0.09, {"tutte": tinta("#6A4428", "legno")}, alto=(0, 1, 0))
    m.segmento("mano.R", bocca + direzione * 0.05, pugno_r + direzione * 0.5, 0.03, 0.03, {"tutte": tinta("#3A3C40", "metallo")})
    m.segmento("mano.R", bocca + direzione * 0.45, bocca, 0.012, 0.025, {"tutte": tinta("#B8BCC4", "metallo")})
    return m


SOLDATI = {"Legionario": Legionario, "ArciereCretese": ArciereCretese, "Spadaccino": Spadaccino, "Arciere": Arciere, "Fante": Fante}


def pistola(m, lato="R"):
    """Pistola nel pugno, puntata lungo il braccio (in basso a riposo, avanti quando il braccio si alza)."""
    pugno, d = punto_mano(m, lato, 0.08)
    bocca = pugno + d * 0.2
    m.segmento("mano." + lato, bocca, pugno - d * 0.02, 0.05, 0.1, {"tutte": tinta("#2A2C30", "metallo")})
    m.osso("canna", "mano." + lato, bocca)


def kepi(m, corona, fascia, alto=0.16, oro="#D8B048", stelle=0):
    y0 = m.posizione_osso("testa")[1] + TESTA * 0.78

    def lati(pen):
        pen.riempi(corona)
        pen.rett(0, 0.55, 1, 1, fascia)
        pen.rett(0, 0.5, 1, 0.56, oro)
        for i in range(stelle):
            u = 0.5 + (i - (stelle - 1) / 2) * 0.16
            pen.ellisse(u - 0.05, 0.66, u + 0.05, 0.8, oro)
    m.scatola("testa", (0, y0 + alto / 2, 0), (TESTA * 0.94, alto, TESTA * 0.94), {"tutte": lati, "sopra": tinta(corona)})
    m.scatola("testa", (0, y0 + 0.01, -TESTA / 2 - 0.05), (TESTA * 0.8, 0.02, 0.12), {"tutte": tinta("#18181C", "cuoio")})


def Cesare():
    m = Modello("Cesare")
    scheletro(m, mano_r=(-0.1, -0.55, -1), mano_l=(0.05, -1, 0.05))
    pelle = PELLI[3]
    oro, rosso = "#C89A3C", "#9A1E22"
    coscia, stinco = tunica_gambe(rosso, pelle, calzari="#6A4628", orlo=0.4)

    def corazza(pen):
        pen.riempi(oro, "metallo")
        pen.linea([(0.5, 0.2), (0.5, 0.75)], scuro(oro, 0.3), 0.012)
        for u in (0.3, 0.7):  # pettorali
            pen.linea([(u - 0.15, 0.35), (u, 0.42), (u + 0.15, 0.35)], scuro(oro, 0.3), 0.012)
        for v in (0.55, 0.65):
            pen.linea([(0.3, v), (0.7, v)], scuro(oro, 0.25), 0.008)
        pen.rett(0, 0.78, 1, 0.84, "#E8D8B0")  # fascia del comando
        pen.rett(0, 0.84, 1, 1, "#6E4A2C")
        for u in np.linspace(0.06, 0.94, 9):  # pteruges
            pen.rett(u - 0.03, 0.86, u + 0.03, 1, "#8A6A3C")

    def omero(pen):
        pen.riempi(pelle, "pelle")
        pen.rett(0, 0, 1, 0.3, oro)
        for u in np.linspace(0.1, 0.9, 4):
            pen.rett(u - 0.06, 0.3, u + 0.06, 0.5, "#8A6A3C")

    abito = {
        "busto": corazza, "busto_retro": tinta(oro, "metallo"), "busto_lati": tinta(oro, "metallo"),
        "omero": omero, "avambraccio": tinta(pelle, "pelle"), "mano": tinta(pelle, "pelle"),
        "coscia": coscia, "stinco": stinco, "piede": tinta("#6A4628", "cuoio"),
        "testa": viso(pelle, bocca="decisa", capelli="#4A3A2E", frangia=-0.04),
        "testa_lati": capelli_lati(pelle, "#4A3A2E", 0.25), "testa_retro": capelli_retro("#4A3A2E", pelle, 0.55),
        "testa_sopra": tinta("#4A3A2E"),
    }
    corpo(m, abito)
    mantello(m, rosso, bordo="#C89A3C")
    # Corona d'alloro.
    def alloro(pen):
        pen.riempi("#4E7A32")
        for u in np.linspace(0.05, 0.95, 8):
            pen.poligono([(u - 0.06, 0.9), (u, 0.05), (u + 0.06, 0.9)], "#6E9A44")
    m.scatola("testa", (0, COLLO + TESTA * 0.85, 0), (TESTA + 0.03, 0.06, TESTA + 0.03), {"tutte": alloro})
    # Gladio sguainato nella destra.
    pugno, d = punto_mano(m, "R", 0.06)
    lama(m, "mano.R", pugno + d * 0.62, pugno + d * 0.1, 0.06, 0.015, "#C8CCD4", piatto=(1, 0, 0))
    m.segmento("mano.R", pugno + d * 0.1, pugno + d * 0.06, 0.16, 0.05, {"tutte": tinta(oro, "metallo")})
    return m


def Giovanna():
    m = Modello("Giovanna")
    scheletro(m, mano_r=(-0.1, -0.55, -1), mano_l=(0.05, -0.6, -1))
    pelle = PELLI[3]
    acciaio = "#C4CAD2"
    capelli = "#6A4424"

    def piastre(pen):
        pen.riempi(acciaio, "metallo")
        pen.righe_v(4, scuro(acciaio, 0.3), 0.02, 0.45, 1.0)
        pen.linea([(0.5, 0.05), (0.5, 0.45)], chiaro(acciaio, 0.3), 0.01)

    def busto(pen):
        piastre(pen)
        pen.rett(0, 0.0, 1, 0.07, scuro(acciaio, 0.2))

    def gamba(pen):
        pen.riempi(acciaio, "metallo")
        pen.righe_v(2, scuro(acciaio, 0.3), 0.025)

    abito = {
        "busto": busto, "busto_retro": piastre, "busto_lati": piastre,
        "omero": gamba, "avambraccio": gamba, "mano": tinta(scuro(acciaio, 0.15), "metallo"),
        "coscia": gamba, "stinco": gamba, "piede": tinta(scuro(acciaio, 0.2), "metallo"),
        "testa": viso(pelle, bocca="decisa", capelli=capelli, frangia=0.1, sopracciglia="#4A2E18"),
        "testa_lati": capelli_lati(pelle, capelli, 0.62), "testa_retro": capelli_retro(capelli, pelle, 0.85),
        "testa_sopra": tinta(capelli),
    }
    corpo(m, abito)
    # Spada nella destra.
    pugno, d = punto_mano(m, "R", 0.06)
    lama(m, "mano.R", pugno + d * 0.85, pugno + d * 0.1, 0.06, 0.015, "#D0D4DC")
    m.segmento("mano.R", pugno + d * 0.1, pugno + d * 0.06, 0.2, 0.04, {"tutte": tinta("#C8A050", "metallo")})
    # Stendardo bianco con i gigli nella sinistra.
    pugno_l, _ = punto_mano(m, "L", 0.06)
    alto = pugno_l + np.array([0, 1.25, 0])
    basso = pugno_l + np.array([0, -0.6, 0])
    asta(m, "mano.L", alto, basso, 0.04, "#7A5232")

    def bandiera(pen):
        pen.riempi("#F2EEE2")
        for u, v in ((0.25, 0.3), (0.6, 0.25), (0.4, 0.62), (0.75, 0.6)):
            pen.poligono([(u, v - 0.12), (u + 0.05, v), (u, v + 0.1), (u - 0.05, v)], "#D4A838")
            pen.ellisse(u - 0.09, v - 0.02, u - 0.02, v + 0.05, "#D4A838")
            pen.ellisse(u + 0.02, v - 0.02, u + 0.09, v + 0.05, "#D4A838")
        pen.rett(0, 0.9, 1, 1, "#2A4A8A")
    m.scatola("mano.L", alto + np.array([0, -0.32, 0.36]), (0.02, 0.6, 0.7), {"tutte": bandiera})
    return m


def Foch():
    m = Modello("Foch")
    scheletro(m, mano_r=(0.15, -1, -0.25), mano_l=(0.1, -0.7, -1))
    pelle = PELLI[3]
    blu = "#7088A6"

    def giacca(pen):
        pen.riempi(blu)
        for v in (0.1, 0.25, 0.4, 0.55):
            pen.ellisse(0.47, v, 0.53, v + 0.05, "#D8B048")
        pen.rett(0, 0.68, 1, 0.75, "#3A2A1C")
        pen.rett(0.06, 0.15, 0.3, 0.3, "#C8303A")  # nastrini
        pen.rett(0.06, 0.15, 0.3, 0.19, "#2A4A9A")
        pen.rett(0.4, 0, 0.6, 0.07, "#1E2A44")

    calzoni, stivali = "#5E7494", "#1E1814"
    abito = {
        "busto": giacca, "busto_retro": tinta(blu), "busto_lati": tinta(blu),
        "omero": tinta(blu), "avambraccio": tinta(blu), "mano": tinta("#E8E2D6"),
        "coscia": tinta(calzoni), "stinco": pantaloni(calzoni, stivali=stivali, altezza_stivale=0.9)[1], "piede": tinta(stivali, "cuoio"),
        "testa": viso(pelle, bocca="seria", baffi="#E6E2DA", sopracciglia="#BCB6AA"),
        "testa_lati": capelli_lati(pelle, "#D8D4CC", 0.35), "testa_retro": capelli_retro("#D8D4CC", pelle, 0.6),
    }
    corpo(m, abito)
    kepi(m, "#B02A2A", "#1E2A44", stelle=0)
    pistola(m, "R")
    return m


def DeGaulle():
    m = Modello("DeGaulle")
    scheletro(m, mano_r=(0.15, -1, -0.25), mano_l=(0.05, -1, 0.1))
    pelle = PELLI[3]
    kaki = "#8C8058"

    def giacca(pen):
        pen.riempi(kaki)
        pen.linea([(0.95, 0.0), (0.05, 0.7)], "#5A3E24", 0.03)  # bandoliera
        pen.rett(0, 0.68, 1, 0.75, "#5A3E24")
        for v in (0.12, 0.3, 0.48):
            pen.ellisse(0.47, v, 0.53, v + 0.05, "#C8B070")
        # croce di Lorena
        pen.rett(0.2, 0.15, 0.24, 0.45, "#C8303A")
        pen.rett(0.15, 0.2, 0.29, 0.23, "#C8303A")
        pen.rett(0.13, 0.29, 0.31, 0.32, "#C8303A")

    calzoni, stivali = "#7E7250", "#4A3020"
    abito = {
        "busto": giacca, "busto_retro": tinta(kaki), "busto_lati": tinta(kaki),
        "omero": tinta(kaki), "avambraccio": tinta(kaki), "mano": tinta(pelle, "pelle"),
        "coscia": tinta(calzoni), "stinco": pantaloni(calzoni, stivali=stivali, altezza_stivale=0.9)[1], "piede": tinta(stivali, "cuoio"),
        "testa": viso(pelle, bocca="seria", baffi="#2A2018"),
        "testa_lati": capelli_lati(pelle, "#2A2018", 0.35), "testa_retro": capelli_retro("#2A2018", pelle, 0.6),
    }
    corpo(m, abito)
    kepi(m, "#2A2A30", "#2A2A30", alto=0.2, stelle=2)
    pistola(m, "R")
    return m


def Mitragliere():
    m = Modello("Mitragliere")
    # In ginocchio dietro la mitragliatrice Hotchkiss: le mani sulle impugnature.
    scheletro(m, mano_r=(-0.3, 0.2, -1), mano_l=(0.3, 0.25, -1), bacino_y=0.5, ginocchia=((0, 0.1, -0.06), (0, 0.08, 0.36)))
    m.osso("terra", None, (0, 0, 0))
    pelle = PELLI[0]
    blu = "#7A92B0"

    def cappotto(pen):
        pen.riempi(blu)
        for v in (0.15, 0.35, 0.55):
            pen.ellisse(0.36, v, 0.42, v + 0.05, "#C8B070")
            pen.ellisse(0.58, v, 0.64, v + 0.05, "#C8B070")
        pen.rett(0, 0.7, 1, 0.78, "#4A3A28")

    abito = {
        "busto": cappotto, "busto_retro": tinta(blu), "busto_lati": tinta(blu),
        "omero": tinta(blu), "avambraccio": tinta(blu), "mano": tinta(pelle, "pelle"),
        "coscia": tinta(scuro(blu, 0.05)), "stinco": tinta("#6A7E96"), "piede": tinta("#2E2218", "cuoio"),
        "testa": viso(pelle, bocca="decisa", baffi="#2A2018"),
        "testa_lati": capelli_lati(pelle, "#2A2018", 0.4), "testa_retro": capelli_retro("#2A2018", pelle, 0.75),
    }
    corpo(m, abito)
    elmo = tinta("#6E8098", "metallo")
    elmo_scatola(m, 0.04, 0.26, 0.015, {"tutte": elmo})
    yt = m.posizione_osso("testa")[1]
    m.scatola("testa", (0, yt + TESTA * 0.66, 0.02), (TESTA + 0.12, 0.025, TESTA + 0.16), {"tutte": elmo})
    m.scatola("testa", (0, yt + TESTA + 0.07, 0), (0.04, 0.05, TESTA * 0.8), {"tutte": elmo})
    # Mitragliatrice: castello, canna con le alette di raffreddamento d'ottone, nastro, treppiede.
    pugno_r, _ = punto_mano(m, "R")
    pugno_l, _ = punto_mano(m, "L")
    y = (pugno_r[1] + pugno_l[1]) / 2 + 0.03
    culatta = np.array([0.0, y, (pugno_r[2] + pugno_l[2]) / 2 - 0.05])
    m.osso("mitragliatrice", None, culatta)
    bocca = culatta + np.array([0, 0.02, -0.95])
    m.osso("canna", "mitragliatrice", bocca)
    m.segmento("mitragliatrice", culatta + np.array([0, 0, -0.36]), culatta + np.array([0, 0, 0.02]), 0.12, 0.14,
               {"tutte": tinta("#3A3C40", "metallo")}, alto=(0, 1, 0))
    m.segmento("mitragliatrice", bocca, culatta + np.array([0, 0.02, -0.3]), 0.045, 0.045, {"tutte": tinta("#2A2C30", "metallo")}, alto=(0, 1, 0))
    for k in range(5):
        z = -0.38 - k * 0.06
        m.scatola("mitragliatrice", culatta + np.array([0, 0.02, z]), (0.11, 0.11, 0.025), {"tutte": tinta("#B08A44", "metallo")})
    m.scatola("mitragliatrice", culatta + np.array([-0.16, 0.0, -0.15]), (0.22, 0.02, 0.06), {"tutte": tinta("#C8A050", "metallo")})
    perno = culatta + np.array([0, -0.08, -0.25])
    for punta in ((0.0, 0.0, -0.75), (-0.32, 0.0, 0.05), (0.32, 0.0, 0.05)):
        piede = np.array([perno[0] + punta[0], 0.0, perno[2] + punta[2]])
        asta(m, "terra", perno, piede, 0.04, "#2E3034", "metallo")
    # Sacchetti di sabbia davanti.
    def sacco(pen):
        pen.riempi("#B8A478")
        pen.rett(0, 0, 1, 0.12, scuro("#B8A478", 0.15))
        pen.rett(0.45, 0, 0.55, 1, scuro("#B8A478", 0.1))
    for fila, (yy, n) in enumerate(((0.09, 4), (0.26, 3))):
        for i in range(n):
            x = (i - (n - 1) / 2) * 0.33
            m.scatola("terra", (x, yy, -1.05 + fila * 0.03), (0.31, 0.17, 0.24), {"tutte": sacco})
    return m


SOLDATI.update({"Cesare": Cesare, "Giovanna": Giovanna, "Foch": Foch, "DeGaulle": DeGaulle, "Mitragliere": Mitragliere})


def main():
    argomenti = [a for a in sys.argv[1:] if not a.startswith("--")]
    glb = None
    if "--glb" in sys.argv:
        glb = sys.argv[sys.argv.index("--glb") + 1]
        argomenti = [a for a in argomenti if a != glb]
    nomi = argomenti or list(SOLDATI)
    for nome in nomi:
        modello = SOLDATI[nome]()
        dati = modello.costruisci(seme=hash(nome) % 1000)
        meshdati.scrivi(nome, dati, "soldato a blocchi")
        print(nome, len(dati["pos"]), "vertici", len(dati["triangoli"]), "triangoli")
        if glb:
            os.makedirs(glb, exist_ok=True)
            meshdati.glb(dati, os.path.join(glb, nome + ".glb"))
            dati["texture"].save(os.path.join(glb, nome + ".png"))


if __name__ == "__main__":
    main()
