"""Truppe R6 del medioevo (stessi disegni di nuove.py, soldati.py e cavalieri.py)."""
import numpy as np

from kit import (ACCIAIO, B, BAC, CUOIO, CUOIO_SCURO, FERRO, GIRO, H, LATI, LEGNO, NERO, ORO, R_ELMO, R_TESTA, T1, T2,
                 M, arco, ascia, balestra, barba, calotta, camaglio, capelli, cavaliere, cintura, corazza, cotta,
                 elmo_chiuso, elmo_conico, fante, faretra, fodero, gonna, gualdrappa, lamelle, lancia, lancia_resta,
                 mantello, manica, polsino, guanto, scudo, sopravveste, spada, spallacci, stivale, strato, tesa,
                 turbante, vesti, fasce, colletto, dipinto, rot_y, ASSE_Z)
from r6 import BUSTO_L, BUSTO_P, COLLO, GAMBE, PELLI, S, TESTA_D, TESTA_Y

ARCIERE = dict(mano_r=(0.2, -1, -0.25), mano_l=(0.1, -0.75, -1))
LANCIERE = dict(mano_r=(0, 0.05, -1), mano_l=(0.25, 0.1, -1))
BALESTRA = dict(mano_r=(-0.6, -0.45, -1), mano_l=(0.55, -0.5, -0.8))
SPADA = dict(mano_r=(-0.1, -0.55, -1), mano_l=(0.25, 0.1, -1))
MAGLIA = ("#8A9098", "maglia")


def giglio(pen, u, v, r, c):
    """Fiordaliso stilizzato centrato in (u, v), alto circa 2r."""
    pen.poligono([(u, v - r), (u + r * 0.35, v), (u, v + r * 0.6), (u - r * 0.35, v)], c)
    pen.poligono([(u - r * 0.9, v - r * 0.4), (u - r * 0.3, v - r * 0.05), (u - r * 0.3, v + r * 0.3)], c)
    pen.poligono([(u + r * 0.9, v - r * 0.4), (u + r * 0.3, v - r * 0.05), (u + r * 0.3, v + r * 0.3)], c)
    pen.rett(u - r * 0.6, v + r * 0.25, u + r * 0.6, v + r * 0.42, c)


def croce(c, larga=0.12, alto=0.08, basso=0.75, braccio=0.25):
    def p(pen):
        pen.rett(0.5 - larga / 2, alto, 0.5 + larga / 2, basso, c)
        pen.rett(0.22, braccio, 0.78, braccio + larga, c)
    return p


def cappello_ferro(m, colore="#7E848C", larga=0.3 * S):
    """Cappello di ferro (kettle hat): calotta e tesa larga piegata in giù."""
    mm = M(colore, "ferro")
    calotta(m, mm, alto=0.5 * S, nuca=False)
    tesa(m, mm, R_ELMO + larga, GIRO - 0.01, spessore=0.014, giu=0.05)


def grande_elmo(colore=ACCIAIO, croce_c=None):
    def p(pen):
        pen.riempi(colore)
        pen.rett(0.08, 0.36, 0.92, 0.43, "#141618")  # la fessura degli occhi
        pen.rett(0.47, 0.43, 0.53, 0.8, croce_c or "#6C727A")
        pen.rett(0.32, 0.56, 0.68, 0.61, croce_c or "#6C727A")
        for u in (0.3, 0.38, 0.62, 0.7):
            for v in (0.66, 0.74):
                pen.ellisse(u - 0.014, v - 0.014, u + 0.014, v + 0.014, "#141618")
    return p


def piastre_gambe(m, colore=ACCIAIO):
    """Cosciali e schinieri d'acciaio a piastre."""
    for lato, _ in LATI:
        stivale(m, lato, (colore, "ferro"), alto=1.0 * S, t=0.018, suola=None, nome="schiniere")
        stivale(m, lato, ("#8A9098", "ferro"), alto=0.16 * S, t=0.022, suola="#4A4E54", nome="scarpa")


def piastre_braccia(m, colore=ACCIAIO):
    for lato, _ in LATI:
        manica(m, lato, (colore, "ferro"), a=1.2 * S, t=0.018, nome="bracciale")
        polsino(m, lato, (colore, "ferro"), a=0.55 * S, t=0.016, nome="avambracciale")
        guanto(m, lato, ("#8A9098", "ferro"))


# -- Mondo islamico ---------------------------------------------------------------------------------------

def FanteUmayyade(faccia, cartella):
    pelle = PELLI[4]
    m = fante("FanteUmayyade", faccia, cartella, pelle, **LANCIERE)
    vesti(m, "#ECE6D6", manica="#ECE6D6", manica_fino=2 * S, avambraccio="#ECE6D6", coscia="#ECE6D6", stinco="#ECE6D6")
    cotta(m, MAGLIA, basso=GAMBE - 0.6 * S, maniche="omero")
    cintura(m, CUOIO, t=T1 + 0.016)
    for lato, _ in LATI:
        stivale(m, lato, "#5A3A22", alto=0.5 * S)
    barba(m, "#1A1410")
    turbante(m, "#ECE6D6", elmo=FERRO)
    lancia(m)

    def anelli(pen):
        pen.ellisse(0.15, 0.15, 0.85, 0.85, "#C8A040")
        pen.ellisse(0.22, 0.22, 0.78, 0.78, "#2E6A3A")
    scudo(m, "tondo", "#2E6A3A", anelli, larga=0.7, alta=0.7, umbone=FERRO, bordo="#6A4A2A")
    return m


def ArciereArabo(faccia, cartella):
    pelle = PELLI[4]
    veste = "#E8DCC0"
    m = fante("ArciereArabo", faccia, cartella, pelle, **ARCIERE)
    vesti(m, veste, manica=veste, manica_fino=2 * S, avambraccio=veste, coscia=veste, stinco=veste)
    strato(m, "veste", COLLO, GAMBE, veste, T1)
    gonna(m, veste, basso=GAMBE - 1.3 * S, svasa=(1.12, 1.2))
    cintura(m, "#2E6A3A", t=T1 + 0.012)
    for lato, _ in LATI:
        stivale(m, lato, "#6A4628", alto=0.2 * S)
    barba(m, "#1A1410")
    turbante(m, "#2E6A3A")
    arco(m, 1.05, 0.2, legno="#4A2E1A", ricurvo=True)
    faretra(m, fianco=True, colore="#5A3A22", inclinazione=12)
    return m


def CavalleriaAraba(faccia, cartella):
    pelle = PELLI[4]
    m = cavaliere("CavalleriaAraba", faccia, cartella, "Annibale", pelle)
    vesti(m, "#ECE6D6", manica="#ECE6D6", manica_fino=2 * S, avambraccio="#ECE6D6", coscia="#ECE6D6",
          stinco="#ECE6D6")
    cotta(m, MAGLIA, basso=GAMBE - 0.3 * S, maniche="omero")
    cintura(m, CUOIO, t=T1 + 0.016)
    for lato, _ in LATI:
        stivale(m, lato, "#5A3A22", alto=0.5 * S)
    mantello(m, "#ECE6D6", basso=GAMBE - 0.05, spilla=None)
    barba(m, "#1A1410")
    turbante(m, "#ECE6D6", elmo=FERRO)
    gualdrappa(m, "#2E6A3A", lambda pen: pen.rett(0, 0.75, 1, 0.82, "#C8A040"))
    lancia_resta(m, 1.9, 0.8)
    return m


def Mamelucco(faccia, cartella):
    """Mamelucco di Saladino: lamelle, veste gialla, turbante sull'elmo, scudo tondo e lancia."""
    pelle = PELLI[4]
    giallo = "#D8A830"
    m = cavaliere("Mamelucco", faccia, cartella, "Annibale", pelle)
    vesti(m, giallo, manica=giallo, manica_fino=1.3 * S, avambraccio="#7A2A2A", coscia="#7A2A2A", stinco="#7A2A2A")
    strato(m, "veste", COLLO, GAMBE, giallo, T1)
    lamelle(m, "#8A8E96", file=4, alto=COLLO - 0.2 * S, basso=GAMBE + 0.25 * S, t=T2)
    gonna(m, giallo, basso=GAMBE - 0.3 * S)
    cintura(m, "#7A2A2A", t=T2 + 0.02)
    for lato, _ in LATI:
        stivale(m, lato, "#5A3A22", alto=0.6 * S)
    barba(m, "#1A1410")
    turbante(m, "#ECE6D6", elmo="#B8BCC4")
    gualdrappa(m, giallo, lambda pen: pen.rett(0, 0.7, 1, 0.8, "#7A2A2A"))

    def tondo(pen):
        pen.ellisse(0.22, 0.22, 0.78, 0.78, "#7A2A2A")
    scudo(m, "tondo", giallo, tondo, larga=0.52, alta=0.52, umbone="#C8CCD4", angolo=60, avanti=0.08)
    lancia_resta(m, 1.9, 0.8)
    return m


def FanteAyyubide(faccia, cartella):
    pelle = PELLI[4]
    imbottito = "#C8A050"
    m = fante("FanteAyyubide", faccia, cartella, pelle, **LANCIERE)
    vesti(m, imbottito, manica=imbottito, manica_fino=2 * S, avambraccio=imbottito, coscia="#ECE6D6", stinco="#ECE6D6")
    # Gambesone trapuntato: file di cuscinetti cuciti.
    for i in range(5):
        y = COLLO - (i + 0.5) * BUSTO_L / 5
        strato(m, f"trapunta{i}", y + 0.19 * S, y - 0.19 * S, imbottito, T1 + 0.01, smusso=0.012)
    gonna(m, imbottito, basso=GAMBE - 0.55 * S)
    cintura(m, "#2E6A3A", t=T1 + 0.03)
    for lato, _ in LATI:
        stivale(m, lato, "#6A4628", alto=0.25 * S)
    barba(m, "#1A1410", baffi=False)
    turbante(m, "#ECE6D6")
    lancia(m)
    scudo(m, "tondo", "#D8A830", lambda pen: pen.ellisse(0.2, 0.2, 0.8, 0.8, "#2E6A3A"), larga=0.68, alta=0.68,
          umbone=FERRO)
    return m


def ArciereAyyubide(faccia, cartella):
    pelle = PELLI[4]
    veste = "#D8A830"
    m = fante("ArciereAyyubide", faccia, cartella, pelle, **ARCIERE)
    vesti(m, veste, manica=veste, manica_fino=2 * S, avambraccio=veste, coscia="#7A2A2A", stinco="#7A2A2A")
    strato(m, "veste", COLLO, GAMBE, veste, T1)
    gonna(m, veste, basso=GAMBE - 0.65 * S)
    cintura(m, "#7A2A2A", t=T1 + 0.012)
    for lato, _ in LATI:
        stivale(m, lato, "#5A3A22", alto=0.8 * S)
    barba(m, "#1A1410")
    turbante(m, "#ECE6D6")
    arco(m, 1.0, 0.2, legno="#4A2E1A", ricurvo=True)
    faretra(m, fianco=True, colore="#7A2A2A", inclinazione=12)
    return m


def Saladino(faccia, cartella):
    """Saladino: veste verde con la fascia d'oro, turbante bianco con l'elmo dorato, mantello bianco, lancia col
    vessillo giallo; gualdrappa verde."""
    pelle = PELLI[4]
    verde, oro = "#2E6A3A", "#E0B848"
    m = cavaliere("Saladino", faccia, cartella, "Cavaliere", pelle)
    vesti(m, verde, manica=verde, manica_fino=1.2 * S, avambraccio="#ECE6D6", coscia="#ECE6D6", stinco="#ECE6D6")

    def veste(pen):
        pen.rett(0.43, 0, 0.57, 1, oro)
    sopravveste(m, verde, veste, basso=GAMBE - 0.3 * S, t=T1, nome="veste")
    lamelle(m, "#8A8E96", file=2, alto=COLLO - 0.15 * S, basso=COLLO - 0.95 * S, t=T1 + 0.012, nome="pettorale")
    cintura(m, oro, t=T1 + 0.02, fibbia=oro)
    for lato, _ in LATI:
        stivale(m, lato, "#5A3A22", alto=0.6 * S)
    mantello(m, "#ECE6D6", basso=GAMBE - 0.05, bordo=oro)
    barba(m, "#2A2018")
    turbante(m, "#ECE6D6", elmo=ORO, alto=0.5 * S)
    gualdrappa(m, verde, lambda pen: pen.rett(0, 0.72, 1, 0.82, oro))

    def vessillo(pen):
        pen.riempi("#E0B848")
        pen.rett(0, 0.8, 1, 1, verde)
    lancia_resta(m, 2.0, 0.9, punta="#E0C060", pennone=vessillo)
    return m


# -- Normanni ---------------------------------------------------------------------------------------------

def FanteNormanno(faccia, cartella):
    pelle = PELLI[0]
    m = fante("FanteNormanno", faccia, cartella, pelle, **LANCIERE)
    vesti(m, "#6A5A44", manica="#6A5A44", manica_fino=2 * S, avambraccio="#6A5A44", coscia="#6A5A44", stinco="#6A5A44")
    cotta(m, MAGLIA, maniche="omero")
    cintura(m, CUOIO_SCURO, t=T1 + 0.016)
    for lato, _ in LATI:
        fasce(m, lato, "#8C7A5A", alto=0.85 * S)
    capelli(m, "#6A4A2A", sopra=False)
    elmo_conico(m)
    lancia(m)

    def croce_oro(pen):
        pen.rett(0.42, 0.0, 0.58, 1.0, "#C8A040")
        pen.rett(0.1, 0.25, 0.9, 0.35, "#C8A040")
    scudo(m, "mandorla", "#A0201E", croce_oro, larga=0.5, alta=0.95, angolo=20, giu=0.14, bordo="#5A3A20")
    return m


def ArciereNormanno(faccia, cartella):
    pelle = PELLI[0]
    giaco = "#8A7A5A"
    m = fante("ArciereNormanno", faccia, cartella, pelle, **ARCIERE)
    vesti(m, giaco, manica=giaco, manica_fino=2 * S, avambraccio=giaco, coscia="#5A4A3A", stinco="#5A4A3A")
    strato(m, "giaco", COLLO, GAMBE, giaco, T1)
    gonna(m, giaco, basso=GAMBE - 0.5 * S)
    cintura(m, "#4A3020", t=T1 + 0.012)
    for lato, _ in LATI:
        fasce(m, lato, "#7A6A4A", alto=0.8 * S)
    capelli(m, "#5A3A22", sopra=False)
    calotta(m, ("#6A5A3A", "cuoio"), alto=0.45 * S)
    arco(m, 1.3, 0.13)
    faretra(m, fianco=True, inclinazione=12)
    return m


def CavaliereNormanno(faccia, cartella):
    """Cavaliere normanno di Hastings: elmo conico col nasale, usbergo, scudo a mandorla giallo e rosso, lancia."""
    pelle = PELLI[0]
    m = cavaliere("CavaliereNormanno", faccia, cartella, "Guglielmo", pelle, mano_l=(0.1, -0.55, -1))
    vesti(m, M(*MAGLIA), manica=M(*MAGLIA), manica_fino=2 * S, avambraccio=M(*MAGLIA), mano="#5A4030",
          coscia=M(*MAGLIA), stinco="#5A4A3A")
    cotta(m, MAGLIA, basso=GAMBE - 0.35 * S, maniche=None)
    cintura(m, CUOIO_SCURO, t=T1 + 0.016)
    for lato, _ in LATI:
        stivale(m, lato, "#3A2A1C", alto=0.3 * S)
    capelli(m, "#6A4A2A", sopra=False)
    elmo_conico(m)

    def stemma(pen):
        for v in (0.2, 0.5, 0.8):
            pen.rett(0.0, v - 0.06, 1.0, v + 0.06, "#A0201E")
    scudo(m, "mandorla", "#C8A040", stemma, larga=0.46, alta=0.86, angolo=55, avanti=0.06, giu=0.05)

    def banderuola(pen):
        pen.riempi("#C8A040")
        pen.rett(0, 0.5, 1, 1, "#A0201E")
    lancia_resta(m, 2.0, 0.9, pennone=banderuola)
    return m


def Guglielmo(faccia, cartella):
    """Guglielmo il Conquistatore: elmo conico col cerchio d'oro, usbergo, mantello rosso, scudo rosso con la croce
    d'oro, il vessillo del papa."""
    pelle = PELLI[0]
    rosso, oro = "#A0201E", "#E0B848"
    m = cavaliere("Guglielmo", faccia, cartella, "Guglielmo", pelle, mano_l=(0.1, -0.55, -1))
    vesti(m, M(*MAGLIA), manica=M(*MAGLIA), manica_fino=2 * S, avambraccio=M(*MAGLIA), mano="#5A4030",
          coscia=M(*MAGLIA), stinco="#5A4A3A")
    cotta(m, MAGLIA, basso=GAMBE - 0.35 * S, maniche=None)
    cintura(m, "#4A3020", t=T1 + 0.016, fibbia=oro)
    for lato, _ in LATI:
        stivale(m, lato, "#3A2A1C", alto=0.35 * S)
    mantello(m, rosso, basso=GAMBE - 0.05, bordo=oro)
    capelli(m, "#6A4A2A", sopra=False)
    barba(m, "#6A4A2A", piena=False)
    elmo_conico(m, fascia=oro)

    def stemma(pen):
        pen.rett(0.44, 0.0, 0.56, 1.0, oro)
        pen.rett(0.1, 0.24, 0.9, 0.34, oro)
    scudo(m, "mandorla", rosso, stemma, larga=0.46, alta=0.86, angolo=55, avanti=0.06, giu=0.05, umbone="#B0B6BE")

    def vessillo(pen):  # il vessillo del papa: bianco con la croce rossa
        pen.riempi("#F0ECE0")
        pen.rett(0.4, 0, 0.55, 1, rosso)
        pen.rett(0, 0.4, 1, 0.58, rosso)
    lancia_resta(m, 2.0, 0.9, pennone=vessillo)
    return m


# -- Ordini e regni -------------------------------------------------------------------------------------

def CavaliereTeutonico(faccia, cartella):
    """Cavaliere teutonico: sopravveste bianca con la croce nera, elmo grande, mantello bianco, scudo e lancia."""
    pelle = PELLI[3]
    bianco = "#ECEAE2"
    m = cavaliere("CavaliereTeutonico", faccia, cartella, "Cavaliere", pelle, mano_l=(0.1, -0.55, -1))
    vesti(m, M(*MAGLIA), manica=M(*MAGLIA), manica_fino=2 * S, avambraccio=M(*MAGLIA), mano="#5A4030",
          coscia=M(*MAGLIA), stinco=M(*MAGLIA))
    sopravveste(m, bianco, croce(NERO), basso=GAMBE - 0.3 * S)
    cintura(m, "#4A3020", t=T2 + 0.02)
    for lato, _ in LATI:
        stivale(m, lato, "#3A2A1C", alto=0.2 * S)
    mantello(m, bianco, basso=GAMBE - 0.05, spilla=NERO)
    elmo_chiuso(m, ACCIAIO, grande_elmo())
    gualdrappa(m, bianco, croce(NERO, 0.1, 0.1, 0.9, 0.3))
    scudo(m, "mandorla", bianco, croce(NERO, 0.14, 0.05, 0.85, 0.25), larga=0.46, alta=0.8, angolo=55, avanti=0.06,
          giu=0.05)

    def pennone(pen):
        pen.riempi(bianco)
        pen.rett(0.4, 0.2, 0.6, 0.8, NERO)
    lancia_resta(m, 2.0, 0.9, pennone=pennone)
    return m


def _tau(pen):
    pen.rett(0.44, 0.15, 0.56, 0.7, NERO)
    pen.rett(0.25, 0.15, 0.75, 0.25, NERO)


def BalestriereTeutonico(faccia, cartella):
    pelle = PELLI[3]
    grigio = "#8A8678"
    m = fante("BalestriereTeutonico", faccia, cartella, pelle, **BALESTRA)
    vesti(m, M(*MAGLIA), manica=M(*MAGLIA), manica_fino=2 * S, avambraccio=M(*MAGLIA), mano="#5A4030",
          coscia="#5A5448", stinco="#5A5448")
    sopravveste(m, grigio, _tau, retro=False, basso=GAMBE - 0.7 * S, t=T1)
    cintura(m, "#4A3020", t=T1 + 0.016)
    for lato, _ in LATI:
        stivale(m, lato, "#3A2A1C", alto=0.55 * S)
    capelli(m, "#7A5A3A", sopra=False)
    cappello_ferro(m)
    balestra(m)
    return m


def SergenteTeutonico(faccia, cartella):
    pelle = PELLI[3]
    grigio = "#8A8678"
    m = fante("SergenteTeutonico", faccia, cartella, pelle, **SPADA)
    vesti(m, M(*MAGLIA), manica=M(*MAGLIA), manica_fino=2 * S, avambraccio=M(*MAGLIA), mano="#5A4030",
          coscia=M(*MAGLIA), stinco=M(*MAGLIA))
    sopravveste(m, grigio, _tau, basso=GAMBE - 0.75 * S)
    cintura(m, "#4A3020", t=T2 + 0.02)
    for lato, _ in LATI:
        stivale(m, lato, "#3A2A1C", alto=0.25 * S)
    capelli(m, "#7A5A3A", sopra=False)
    barba(m, "#7A5A3A")
    cappello_ferro(m)
    spada(m, 0.7)
    scudo(m, "mandorla", "#ECEAE2", croce(NERO, 0.14, 0.05, 0.85, 0.25), larga=0.5, alta=0.85, angolo=20, giu=0.1)
    return m


def BalestriereGenovese(faccia, cartella):
    """Balestriere genovese di Crécy: sopravveste bianca con la croce rossa di San Giorgio, pavese sulla schiena."""
    pelle = PELLI[1]
    rosso = "#B82820"
    m = fante("BalestriereGenovese", faccia, cartella, pelle, **BALESTRA)
    vesti(m, rosso, manica=rosso, manica_fino=2 * S, avambraccio=rosso, coscia=rosso, stinco="#ECEAE2")
    sopravveste(m, "#ECEAE2", croce(rosso), retro=False, basso=GAMBE - 0.55 * S, t=T1)
    cintura(m, "#4A3020", t=T1 + 0.016)
    for lato, _ in LATI:
        stivale(m, lato, "#3A2A1C", alto=0.45 * S)
    capelli(m, "#3A2A1E", sopra=False)
    barba(m, "#3A2A1E", piena=False)
    cappello_ferro(m, larga=0.22 * S)
    balestra(m)

    def pavese(pen):
        pen.rett(0.44, 0.05, 0.56, 0.95, rosso)
        pen.rett(0.1, 0.3, 0.9, 0.42, rosso)
    scudo(m, "pavese", "#ECEAE2", pavese, larga=0.62, alta=1.0, schiena=True)
    return m


def UomoDArme(faccia, cartella):
    """Uomo d'arme della Guerra dei Cent'anni: armatura a piastre, bacinetto con la visiera, sopravveste blu coi
    gigli, azza."""
    acciaio = "#B4BAC2"
    blu = "#2A4E9A"
    m = fante("UomoDArme", faccia, cartella, PELLI[0], mano_r=(-0.1, -0.75, -1), mano_l=(-0.2, -1, -0.25))
    vesti(m, M(*MAGLIA), manica=M(acciaio, "ferro"), manica_fino=2 * S, avambraccio=M(acciaio, "ferro"),
          mano=M("#8A9098", "ferro"), coscia=M(acciaio, "ferro"), stinco=M(acciaio, "ferro"))

    def gigli(pen):
        for u, v in ((0.28, 0.2), (0.72, 0.2), (0.5, 0.48)):
            giglio(pen, u, v, 0.09, "#E0B848")
    sopravveste(m, blu, gigli, basso=GAMBE - 0.6 * S)
    cintura(m, "#4A3020", t=T2 + 0.02, fibbia=ORO)
    spallacci(m, acciaio, n=2)
    piastre_gambe(m, acciaio)
    for lato, _ in LATI:
        polsino(m, lato, (acciaio, "ferro"), a=0.5 * S, t=0.016, nome="avambracciale")

    def visiera(pen):
        pen.riempi(acciaio)
        pen.rett(0.1, 0.4, 0.9, 0.46, "#141618")
        for u in (0.3, 0.4, 0.5, 0.6, 0.7):
            pen.ellisse(u - 0.015, 0.6, u + 0.015, 0.63, "#141618")
    elmo_chiuso(m, acciaio, visiera, cima="punta")
    camaglio(m, MAGLIA, basso=TESTA_Y - 0.62 * S)
    m.scatola("visiera_becco", (0, TESTA_Y - 0.02 * S, -(R_TESTA + 0.06)), (0.5 * S, 0.5 * S, 0.12), M(acciaio, "ferro"),
              H, smusso=0.02, rastrema=(0.6, 0.5))
    ascia(m, lunga=1.35, becco=True)
    return m


def Cavaliere(faccia, cartella):
    """Cavaliere francese del Trecento: elmo a secchiello, sopravveste blu coi gigli d'oro, scudo e lancia."""
    blu, oro = "#2A4E9A", "#E0B848"
    m = cavaliere("Cavaliere", faccia, cartella, "Cavaliere", PELLI[1], mano_l=(0.1, -0.55, -1))
    vesti(m, M(*MAGLIA), manica=M(*MAGLIA), manica_fino=2 * S, avambraccio=M(*MAGLIA), mano="#5A4030",
          coscia=M(*MAGLIA), stinco=M(*MAGLIA))

    def gigli(pen):
        for u, v in ((0.28, 0.25), (0.72, 0.25), (0.5, 0.5)):
            giglio(pen, u, v, 0.09, oro)
    sopravveste(m, blu, gigli, basso=GAMBE - 0.3 * S)
    cintura(m, "#4A3020", t=T2 + 0.02, fibbia="#C8A050")
    for lato, _ in LATI:
        stivale(m, lato, "#3A2A1C", alto=0.45 * S)
    elmo_chiuso(m, ACCIAIO, grande_elmo())

    def stemma(pen):
        for u, v in ((0.3, 0.22), (0.7, 0.22), (0.5, 0.55)):
            giglio(pen, u, v, 0.1, oro)
    scudo(m, "mandorla", blu, stemma, larga=0.5, alta=0.68, angolo=55, avanti=0.06, giu=0.0)

    def banderuola(pen):
        pen.riempi(blu)
        pen.rett(0, 0, 1, 0.5, "#F0ECE0")
    lancia_resta(m, 2.0, 0.9, pennone=banderuola)
    return m


def Giovanna(faccia, cartella):
    """Giovanna d'Arco a cavallo: armatura bianca a piastre, capelli corti a caschetto, lo stendardo bianco con i
    gigli d'oro; gualdrappa blu di Francia coi gigli."""
    acciaio = "#C4CAD2"
    blu, oro = "#1E3A8A", "#D8B048"
    capelli_c = "#4A2E1A"
    m = cavaliere("Giovanna", faccia, cartella, "Guglielmo", PELLI[3])
    vesti(m, M(acciaio, "ferro"), manica=M(acciaio, "ferro"), manica_fino=2 * S, avambraccio=M(acciaio, "ferro"),
          mano=M("#9AA0A8", "ferro"), coscia=M(acciaio, "ferro"), stinco=M(acciaio, "ferro"))
    corazza(m, acciaio, t=T2)
    for i in range(3):  # la panciera a lame
        strato(m, f"lama{i}", GAMBE + (0.5 - i * 0.18) * S, GAMBE + (0.33 - i * 0.18) * S, (acciaio, "ferro"),
               T2 + 0.01 + i * 0.004, smusso=0.006)
    spallacci(m, acciaio, n=2)
    for lato, _ in LATI:
        polsino(m, lato, (acciaio, "ferro"), a=0.5 * S, t=0.016, nome="avambracciale")
        stivale(m, lato, (acciaio, "ferro"), alto=0.9 * S, t=0.016, suola="#5A5E64", nome="schiniere")
    capelli(m, capelli_c, frangia=True, basso=TESTA_Y - 0.25 * S)

    def gigli(pen):
        pen.rett(0, 0.72, 1, 0.84, oro)
        for u in (0.2, 0.5, 0.8):
            giglio(pen, u, 0.38, 0.08, oro)
    gualdrappa(m, blu, gigli)

    def stendardo(pen):
        pen.riempi("#ECEAE2")
        for u, v in ((0.3, 0.3), (0.65, 0.55), (0.35, 0.75)):
            giglio(pen, u, v, 0.1, oro)
    lancia_resta(m, 1.05, 0.3, legno="#7A5232", pennone=stendardo)
    return m


# -- Inghilterra e vichinghi -------------------------------------------------------------------------------

def Spadaccino(faccia, cartella):
    """Guerriero con l'ascia danese: maglia, elmo conico col nasale, scudo tondo giallo e rosso."""
    capelli_c = "#B88A4A"
    m = fante("Spadaccino", faccia, cartella, PELLI[3], mano_r=(-0.1, -0.75, -1), mano_l=(-0.2, -1, -0.25))
    vesti(m, "#6A5A44", manica="#6A5A44", manica_fino=2 * S, avambraccio="#6A5A44", coscia="#6A5A44", stinco="#6A5A44")
    cotta(m, MAGLIA, basso=GAMBE - 0.5 * S, maniche="omero")
    cintura(m, "#4A3020", t=T1 + 0.016, fibbia="#C8A050")
    for lato, _ in LATI:
        fasce(m, lato, "#8C7A5A", alto=0.8 * S)
    capelli(m, capelli_c, sopra=False, lunghi=0.15 * S)
    barba(m, capelli_c, lunga=0.1 * S)
    elmo_conico(m)

    def disegno(pen):
        import math
        for i in range(4):
            a0 = i * math.pi / 2
            pts = [(0.5, 0.5)] + [(0.5 + 0.55 * math.cos(a0 + t), 0.5 + 0.55 * math.sin(a0 + t))
                                  for t in np.linspace(0, math.pi / 4, 6)]
            pen.poligono(pts, "#A02822")
    scudo(m, "tondo", "#C8A040", disegno, larga=0.78, alta=0.78, umbone="#7E848C", angolo=70, avanti=0.04,
          bordo="#6A4A2A")
    ascia(m, lunga=1.3)
    return m


def Arciere(faccia, cartella):
    """Arciere inglese col longbow: giaco imbottito bianco con la croce di San Giorgio, cappello di ferro."""
    giaco = "#E6DEC8"
    m = fante("Arciere", faccia, cartella, PELLI[3], **ARCIERE)
    vesti(m, giaco, manica=giaco, manica_fino=2 * S, avambraccio="#4E6A3A", coscia="#4E6A3A", stinco="#4E6A3A")
    sopravveste(m, giaco, croce("#B82820", 0.16, 0.08, 0.7, 0.25), retro=False, basso=GAMBE - 0.4 * S, t=T1 + 0.008)
    for i in range(4):
        tubo_y = GAMBE + (0.3 + i * 0.4) * S
        strato(m, f"trapunta{i}", tubo_y + 0.03, tubo_y - 0.03, giaco, T1 + 0.012, smusso=0.01)
    cintura(m, "#5A3A22", t=T1 + 0.02)
    for lato, _ in LATI:
        stivale(m, lato, "#3A2A1C", alto=0.4 * S)
    capelli(m, "#6A4424", sopra=False)
    cappello_ferro(m, larga=0.33 * S)
    arco(m, 1.5, 0.12, legno="#7A5232")
    faretra(m, fianco=True, colore="#5A3A22", inclinazione=12)
    return m


TRUPPE = {f.__name__: f for f in (FanteUmayyade, ArciereArabo, CavalleriaAraba, Mamelucco, FanteAyyubide,
                                  ArciereAyyubide, Saladino, FanteNormanno, ArciereNormanno, CavaliereNormanno,
                                  Guglielmo, CavaliereTeutonico, BalestriereTeutonico, SergenteTeutonico,
                                  BalestriereGenovese, UomoDArme, Cavaliere, Giovanna, Spadaccino, Arciere)}
