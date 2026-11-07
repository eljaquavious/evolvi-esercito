"""Truppe R6 dalla polvere da sparo a oggi (stessi disegni di nuove.py e soldati.py)."""
import math

import numpy as np

from kit import (ACCIAIO, ASSE_Z, B, BAC, CUOIO, CUOIO_SCURO, FERRO, GIRO, H, LATI, NERO, ORO, OTTONE, R_ELMO,
                 R_TESTA, T1, T2, M, bandoliera, barba, berretto, binocolo, bottoni, calotta, capelli, cappello_tesa,
                 cavaliere, cintura, colbacco, colletto, corazza, cotta, cresta_elmo, fante, fascia_arco, fascia_vita,
                 fasce, fondina, fucile, fucile_assalto, gonna, granate, gualdrappa, giberne, guanto, kepi,
                 lancia, lancia_resta, mantello, manica, mitragliatrice, pannello, picca, pistola, polsino, sagoma, sciarpa,
                 shako, spada, spalline, stivale, strato, tesa, tubo, turbante, vesti, zaino, borraccia, rot_x, rot_y)
from r6 import BUSTO_A, BUSTO_L, BUSTO_P, COLLO, GAMBE, PELLI, S, TESTA_D, TESTA_Y

FUCILE = dict(mano_r=(-0.6, -0.45, -1), mano_l=(0.55, -0.5, -0.8))
MITRAGLIA = dict(mano_r=(-0.3, 0.2, -1), mano_l=(0.3, 0.25, -1), posa="ginocchio")
GENERALE = dict(mano_r=(0.15, -1, -0.25), mano_l=(0.1, -0.7, -1))


def scuro(c, f):
    r, g, b = (int(c.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4))
    return "#%02X%02X%02X" % tuple(int(v * (1 - f)) for v in (r, g, b))


def stella5(pen, u, v, r, c):
    pts = []
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5
        rr = r if k % 2 == 0 else r * 0.42
        pts.append((u + rr * math.cos(a), v + rr * math.sin(a)))
    pen.poligono(pts, c)


def distintivo(m, nome, centro, r, pittore, pesi, fondo="#D8B048", tipo="ottone"):
    """Dischetto dipinto rivolto in avanti (coccarde, stelle sui caschi)."""
    pannello(m, nome, centro, 2 * r, 2 * r, pittore, fondo, pesi, tipo=tipo, spessore=0.01)


# -- Elmi e cappelli ---------------------------------------------------------------------------------------

def stahlhelm(colore="#5E6650"):
    """Elmetto tedesco: cupola alta, visiera corta, falde che scendono sulle orecchie e si allargano."""
    def elmo(m):
        mm = M(colore, "ferro")
        calotta(m, mm, alto=0.55 * S, nuca=False)
        fascia_arco(m, "stahl_falde", TESTA_Y - 0.12 * S, GIRO + 0.02, R_ELMO - 0.004, 35, 325, 0.014, mm, H, lati=14,
                    rastrema=1.16)
        fascia_arco(m, "stahl_visiera", GIRO - 0.06 * S, GIRO + 0.02, R_ELMO - 0.004, -40, 40, 0.014, mm, H, lati=6,
                    rastrema=1.14)
    return elmo


def brodie(colore="#6A6A4A"):
    """Elmetto inglese a scodella, con la tesa larga."""
    def elmo(m):
        mm = M(colore, "ferro")
        calotta(m, mm, alto=0.42 * S, giro=GIRO + 0.06 * S, nuca=False)
        tesa(m, mm, R_ELMO + 0.3 * S, GIRO + 0.06 * S, spessore=0.012, giu=0.025)
    return elmo


def adrian(colore="#6E8098"):
    """Elmo Adrian francese: calotta, tesa lunga davanti e dietro, cresta in cima, fregio sul davanti."""
    def elmo(m):
        mm = M(colore, "ferro")
        calotta(m, mm, alto=0.5 * S, nuca=False)
        tesa(m, mm, R_ELMO + 0.16 * S, GIRO + 0.01, spessore=0.012, scala=(0.82, 1.3), giu=0.02)
        m.scatola("adrian_cresta", (0, GIRO + 0.5 * S, 0), (0.07 * S, 0.16 * S, TESTA_D * 0.82), mm, H, smusso=0.01,
                  rastrema=(1.6, 1.0))
        m.cilindro("adrian_fregio", (0, GIRO + 0.22 * S, -(R_ELMO + 0.012)), 0.1 * S, 0.012, M("#C8B070", "ottone"),
                   H, lati=10, assi=rot_x(-0.5) @ ASSE_Z)
    return elmo


def elmo_m1(colore="#5E6644", mimetica=True):
    """Elmetto M1 con la copertura mimetica a macchie e l'elastico."""
    def elmo(m):
        mm = M(colore, "stoffa")
        calotta(m, mm, alto=0.56 * S, nuca=TESTA_Y - 0.08 * S)
        tesa(m, mm, R_ELMO + 0.07 * S, GIRO - 0.01, spessore=0.014, giu=0.02)
        if mimetica:
            for i, (a, h, c) in enumerate(((-40, 0.25, "#4A4E30"), (60, 0.35, "#7A6E48"), (160, 0.2, "#3E4228"),
                                           (250, 0.3, "#4A4E30"), (10, 0.48, "#7A6E48"))):
                r = math.radians(a)
                fy = h / 0.56
                rr = (R_ELMO + 0.003) * math.sqrt(max(0.0, 1 - fy * fy))
                c0 = np.array([math.sin(r) * rr, GIRO + h * S, -math.cos(r) * rr])
                m.sfera(f"macchia{i}", c0, 0.16 * S, M(c, "stoffa"), H, anelli=4, lati=8, schiaccia=(1.0, 0.7, 1.0))
        m.cilindro("elastico", (0, GIRO + 0.16 * S, 0), R_ELMO + 0.006, 0.06 * S, M("#2A2A22", "stoffa"), H, lati=18)
    return elmo


def casco_coloniale(colore="#7A7A4A", stella="#C82828"):
    """Casco di sughero nordvietnamita, con la stella sul davanti."""
    def elmo(m):
        mm = M(colore, "feltro")
        calotta(m, mm, alto=0.62 * S, r=R_ELMO + 0.02, nuca=False)
        tesa(m, mm, R_ELMO + 0.2 * S, GIRO, spessore=0.016, scala=(0.92, 1.12), giu=0.04)

        def p(pen):
            pen.riempi("#D8B048")
            stella5(pen, 0.5, 0.52, 0.4, stella)
        distintivo(m, "casco_stella", (0, GIRO + 0.26 * S, -(R_ELMO + 0.03)), 0.11 * S, p, H)
    return elmo


def ushanka(colore="#7A6A5A", stella="#C82828"):
    def elmo(m):
        colbacco(m, colore, stella=stella)
    return elmo


def turbante_cachi(colore="#8A7A4A"):
    def elmo(m):
        turbante(m, colore, alto=0.36 * S)
    return elmo


def bicorno(m, colore="#141416", R=None, coccarda=True):
    """Bicorno di traverso (en bataille): mezzaluna larga con le punte che salgono, coccarda tricolore a sinistra."""
    mm = M(colore, "feltro")
    R = R or (TESTA_D + 0.5) / 2
    base = GIRO - 0.02 * S
    pts_su, pts_giu = [], []
    for i in range(17):
        x = -R + 2 * R * i / 16
        q = (x / R) ** 2
        fondo = base + 0.11 * q
        pts_giu.append((x, fondo))
        pts_su.append((x, fondo + 0.045 + 0.29 * max(0.0, 1 - q) ** 0.75))
    sagoma(m, "bicorno", (0, 0, 0.01), pts_giu + pts_su[::-1], 0.17, mm, H)
    m.cilindro("bicorno_calotta", (0, GIRO + 0.12 * S, 0), R_TESTA + 0.02, 0.36 * S, mm, H, lati=18)
    if coccarda:
        xc = -R * 0.45

        def p(pen):
            pen.riempi(colore)
            pen.ellisse(0.05, 0.05, 0.95, 0.95, "#B82820")
            pen.ellisse(0.22, 0.22, 0.78, 0.78, "#ECEAE2")
            pen.ellisse(0.38, 0.38, 0.62, 0.62, "#2A4E9A")
        yc = base + 0.11 * 0.2 + 0.17
        distintivo(m, "coccarda", (xc, yc, 0.01 - 0.085 - 0.006), 0.07, p, H, fondo=colore, tipo="feltro")
        m.scatola("cordoncino", (xc, yc, 0.01 - 0.085 - 0.012), (0.018, 0.2, 0.006), M(ORO, "ottone"), H)


def bork(m):
    """Börk dei giannizzeri: alto cappello di feltro bianco col lembo che ricade dietro, porta-cucchiaio d'ottone."""
    mm = M("#ECEAE2", "feltro")
    y0 = GIRO - 0.08 * S
    m.cilindro("bork", (0, y0 + 0.42 * S, 0.02), R_TESTA + 0.07, 0.84 * S, mm, H, lati=18,
               raggio_sotto=R_TESTA + 0.025, smusso=0.03, segmenti=1)
    m.scatola("bork_lembo", (0, TESTA_Y + 0.1 * S, R_TESTA + 0.06), (0.7 * S, 1.3 * S, 0.035), mm, H, smusso=0.01,
              assi=rot_x(-0.18), rastrema=(1.2, 1.0))
    m.scatola("bork_fregio", (0, y0 + 0.32 * S, -(R_TESTA + 0.05)), (0.2 * S, 0.5 * S, 0.03), M(OTTONE, "ottone"), H,
              smusso=0.008, rastrema=(0.6, 1.0))


def morione(m, colore):
    mm = M(colore, "ferro")
    calotta(m, mm, alto=0.55 * S, nuca=False)
    tesa(m, mm, R_ELMO + 0.2 * S, GIRO, spessore=0.012, scala=(0.72, 1.35), giu=-0.03)
    cresta_elmo(m, colore, alto=0.55 * S, h=0.26 * S, larga=0.04, tipo="ferro")


def aragosta(m, colore):
    """Elmo a coda d'aragosta: calotta, nasale, paraguance, lame sulla nuca."""
    mm = M(colore, "ferro")
    calotta(m, mm, alto=0.55 * S, nuca=False)
    tesa(m, mm, R_ELMO + 0.1 * S, GIRO + 0.01, spessore=0.012, scala=(0.8, 1.0), giu=0.0, nome="visiera")
    for k in range(3):
        fascia_arco(m, f"coda{k}", GIRO - (0.25 + 0.22 * k) * S, GIRO - (0.03 + 0.22 * k) * S, R_ELMO + 0.004 + 0.012 * k,
                    120, 240, 0.014, mm, H, lati=6, rastrema=1.06)
    for x in (-1, 1):
        fascia_arco(m, f"paraguancia{x}", TESTA_Y - 0.5 * S, GIRO - 0.02, R_ELMO - 0.002, x * 50, x * 105, 0.014, mm, H,
                    lati=4)
    m.scatola("nasale", (0, TESTA_Y + 0.1 * S, -(R_ELMO + 0.01)), (0.08 * S, 0.5 * S, 0.016), mm, H)


# -- Soldato col fucile e mitraglieri ----------------------------------------------------------------------

def giubba_base(m, divisa, cinghie, bottoni_c=None, gonne=True, colletto_c=None):
    strato(m, "giubba", COLLO, GAMBE - 0.02, divisa, T1)
    if gonne:
        gonna(m, divisa, basso=GAMBE - 0.45 * S, t=0.02, svasa=(1.06, 1.1), nome="falde")
    colletto(m, colletto_c or divisa)
    bottoni(m, bottoni_c or scuro(divisa, 0.4), [COLLO - (0.3 + 0.4 * k) * S for k in range(4)], t=T1)
    cintura(m, cinghie, fibbia=OTTONE)


def soldato(nome, faccia, cartella, divisa, pantaloni_c, fasce_c, stivali, elmo, pelle=PELLI[1], baffi=None, extra=None,
            lungo=1.05, baionetta=True, cinghie="#4A3A28", arma=None, capelli_c="#3A2A1E"):
    m = fante(nome, faccia, cartella, pelle, **FUCILE)
    vesti(m, divisa, manica=divisa, manica_fino=2 * S, avambraccio=divisa, coscia=pantaloni_c, stinco=pantaloni_c)
    giubba_base(m, divisa, cinghie)
    giberne(m, scuro(cinghie, 0.1))
    for lato, _ in LATI:
        if fasce_c:
            fasce(m, lato, fasce_c, alto=0.8 * S)
            stivale(m, lato, stivali, alto=0.22 * S)
        else:
            stivale(m, lato, stivali, alto=0.65 * S)
    if baffi:
        barba(m, baffi, piena=False)
    capelli(m, capelli_c, sopra=False)
    elmo(m)
    if extra:
        extra(m)
    if arma:
        arma(m)
    else:
        fucile(m, lungo=lungo, baionetta=baionetta)
    return m


def squadra(nome, faccia, cartella, divisa, elmo, arma="maxim", pelle=PELLI[0], baffi=None, scudo=False, ruote=False,
            sacchi=False, cinghie="#4A3A28"):
    """Mitragliere in ginocchio dietro l'arma: Maxim su treppiede o su ruote, MG 42 sul bipiede."""
    m = fante(nome, faccia, cartella, pelle, **MITRAGLIA)
    vesti(m, divisa, manica=divisa, manica_fino=2 * S, avambraccio=divisa, coscia=scuro(divisa, 0.05),
          stinco=scuro(divisa, 0.15))
    giubba_base(m, divisa, cinghie, gonne=False)
    for lato, _ in LATI:
        stivale(m, lato, "#2E2218", alto=0.4 * S)
    if baffi:
        barba(m, baffi, piena=False)
    capelli(m, "#2A2018", sopra=False)
    elmo(m)
    mitragliatrice(m, tipo=arma, scudo_ferro=scudo, ruote=ruote, sacchi=sacchi)
    return m


# -- Polvere da sparo --------------------------------------------------------------------------------------

def Giannizzero(faccia, cartella):
    """Giannizzero: caftano blu aperto sul rosso, börk bianco, stivali gialli, moschetto."""
    blu, rosso = "#2A4E8A", "#A02828"
    m = fante("Giannizzero", faccia, cartella, PELLI[2], **FUCILE)
    vesti(m, rosso, manica=rosso, manica_fino=2 * S, avambraccio=rosso, coscia=blu, stinco=blu)
    for x in (-1, 1):  # i due lembi del caftano blu, aperti sul davanti rosso
        m.scatola(f"caftano{x}", (x * 0.62 * S, (COLLO + GAMBE) / 2 + 0.006, 0), (0.78 * S, BUSTO_A + 0.012, BUSTO_P + 0.04),
                  M(blu), B, smusso=0.006)
    gonna(m, blu, basso=GAMBE - 1.1 * S, t=0.022, svasa=(1.1, 1.16), nome="caftano_falde")
    fascia_vita(m, "#D8A830")
    for lato, _ in LATI:
        stivale(m, lato, "#C8A030", alto=0.6 * S)
    barba(m, "#1A1410", piena=False)
    capelli(m, "#1A1410", sopra=False)
    bork(m)
    fucile(m, lungo=1.1, baionetta=False)
    return m


def Sipahi(faccia, cartella):
    rosso = "#A02828"
    m = cavaliere("Sipahi", faccia, cartella, "Annibale", PELLI[2])
    vesti(m, rosso, manica=rosso, manica_fino=2 * S, avambraccio=rosso, coscia=rosso, stinco=rosso)
    cotta(m, "#8A8E96", basso=GAMBE - 0.3 * S, maniche="omero")
    fascia_vita(m, "#D8A830", nodo=False)
    for lato, _ in LATI:
        stivale(m, lato, "#C8A030", alto=0.6 * S)
    mantello(m, rosso, basso=GAMBE - 0.05, bordo="#D8A830")
    barba(m, "#1A1410", piena=False)
    turbante(m, "#ECEAE2", elmo="#B8BCC4")
    gualdrappa(m, rosso, lambda pen: pen.rett(0, 0.72, 1, 0.82, "#D8A830"))

    def pennone(pen):
        pen.riempi(rosso)
        pen.ellisse(0.3, 0.2, 0.7, 0.8, "#ECEAE2")
    lancia_resta(m, 2.0, 0.9, pennone=pennone)
    return m


def MoschettiereSvedese(faccia, cartella):
    giubba_c = "#2A4E8A"
    biondo = "#B88A4A"
    m = fante("MoschettiereSvedese", faccia, cartella, PELLI[0], **FUCILE)
    vesti(m, giubba_c, manica=giubba_c, manica_fino=2 * S, avambraccio=giubba_c, coscia="#4A4A50", stinco="#4A4A50")
    strato(m, "giubba", COLLO, GAMBE - 0.02, giubba_c, T1)
    gonna(m, giubba_c, basso=GAMBE - 0.5 * S, t=0.02, nome="falde")
    colletto(m, "#ECEAE2", alto=0.1 * S)
    fascia_vita(m, "#D8B048")
    bandoliera(m, "#7A5232", spalla="R")
    for i, k in enumerate(np.linspace(0.15, 0.85, 5)):  # gli "apostoli": le cariche di polvere appese
        x = 0.62 * S - k * 1.52 * S
        y = COLLO + 0.02 - k * (COLLO - GAMBE)
        tubo(m, f"apostolo{i}", (x, y - 0.02, -(BUSTO_P / 2 + T1 + 0.03)), (x, y - 0.2 * S, -(BUSTO_P / 2 + T1 + 0.03)),
             0.025, M("#C8A050", "legno"), B, lati=8)
    for lato, _ in LATI:
        stivale(m, lato, "#3A2A1C", alto=0.6 * S, risvolto="#4A3424")
    capelli(m, biondo, sopra=False, lunghi=0.25 * S)
    barba(m, biondo, piena=False, pizzo=True)
    cappello_tesa(m, "#2A2A2E", piuma="#D8B048")
    fucile(m, lungo=1.2, baionetta=False)
    return m


def PicchiereSvedese(faccia, cartella):
    acciaio = "#9AA0A8"
    biondo = "#B88A4A"
    m = fante("PicchiereSvedese", faccia, cartella, PELLI[0], mano_r=(0, 0.05, -1), mano_l=(0.25, 0.1, -1))
    vesti(m, "#2A4E8A", manica="#2A4E8A", manica_fino=2 * S, avambraccio="#2A4E8A", coscia="#4A4A50",
          stinco="#4A4A50")
    corazza(m, acciaio, basso=GAMBE - 0.02)
    for lato, s in LATI:  # scarselle sulle cosce
        m.scatola(f"scarsella{lato}", (s * BUSTO_L / 4, GAMBE - 0.3 * S, 0), (BUSTO_L / 2 + 0.03, 0.6 * S, BUSTO_P + 0.06),
                  M(acciaio, "ferro"), [("bacino", 0.6), ("coscia." + lato, 0.4)], smusso=0.008, rastrema=(1.06, 1.1))
    fascia_vita(m, "#D8B048", nodo=False)
    for lato, _ in LATI:
        stivale(m, lato, "#3A2A1C", alto=0.5 * S)
    capelli(m, biondo, sopra=False)
    barba(m, biondo, piena=False)
    morione(m, acciaio)
    lancia(m, alto=2.1, basso=0.9, lunga_punta=0.2)  # la picca ritta, il tallone a terra
    return m


def CorazziereSvedese(faccia, cartella):
    """Corazziere svedese: giaco di bufalo, corazza, elmo a coda d'aragosta, sciabola."""
    acciaio, bufalo = "#8A9098", "#C8A870"
    biondo = "#B88A4A"
    m = cavaliere("CorazziereSvedese", faccia, cartella, "Guglielmo", PELLI[0])
    vesti(m, (bufalo, "cuoio"), manica=(bufalo, "cuoio"), manica_fino=2 * S, avambraccio=(bufalo, "cuoio"),
          mano=("#8A6A40", "cuoio"), coscia=(bufalo, "cuoio"), stinco="#3A2A1C")
    corazza(m, acciaio, basso=GAMBE - 0.02)
    fascia_vita(m, "#D8B048", nodo=False)
    for lato, _ in LATI:
        stivale(m, lato, "#3A2A1C", alto=1.0 * S, risvolto="#4A3424")
    barba(m, biondo, piena=False, pizzo=True)
    aragosta(m, acciaio)
    gualdrappa(m, "#2A4E8A", lambda pen: pen.rett(0, 0.75, 1, 0.85, "#D8B048"))
    spada(m, 0.85, elsa=OTTONE, curva=True)
    return m


def GustavoAdolfo(faccia, cartella):
    """Gustavo II Adolfo, il Leone del Nord: giaco di bufalo, fascia gialla, colletto di pizzo, cappello piumato."""
    bufalo, blu, giallo = "#C8A870", "#2A4E8A", "#E8C030"
    biondo = "#C89A50"
    m = cavaliere("GustavoAdolfo", faccia, cartella, "Guglielmo", PELLI[0])
    vesti(m, (bufalo, "cuoio"), manica=(bufalo, "cuoio"), manica_fino=2 * S, avambraccio=(bufalo, "cuoio"),
          mano=("#8A6A40", "cuoio"), coscia="#2A2A2E", stinco="#3A2A1C")
    strato(m, "giaco", COLLO, GAMBE - 0.02, (bufalo, "cuoio"), T1)
    bandoliera(m, giallo, spalla="R", larga=0.34 * S, nome="fascia")
    m.cilindro("pizzo", (0, COLLO + 0.03 * S, 0), R_TESTA + 0.08, 0.06 * S, M("#ECEAE2", "stoffa"), [("torace", 1.0)],
               lati=18)
    for lato, _ in LATI:
        stivale(m, lato, "#3A2A1C", alto=1.0 * S, risvolto="#4A3424")
    mantello(m, blu, basso=GAMBE - 0.05, bordo=giallo)
    capelli(m, biondo, sopra=False, lunghi=0.2 * S)
    barba(m, biondo, piena=False, pizzo=True)
    cappello_tesa(m, "#2A2A2E", piuma="#ECEAE2")
    gualdrappa(m, blu, lambda pen: pen.rett(0, 0.7, 1, 0.82, giallo))
    spada(m, 0.85, elsa=ORO)
    return m


def FanteriaDiLinea(faccia, cartella):
    """Fante di linea di Napoleone: giubba blu coi risvolti bianchi, cinghie bianche incrociate, shako."""
    blu, bianco = "#2A3E8A", "#ECEAE2"
    m = fante("FanteriaDiLinea", faccia, cartella, PELLI[1], **FUCILE)
    vesti(m, blu, manica=blu, manica_fino=2 * S, avambraccio=blu, coscia=bianco, stinco=bianco)
    strato(m, "giubba", COLLO, GAMBE - 0.02, blu, T1)
    m.scatola("risvolti", (0, COLLO - 0.55 * S, -(BUSTO_P / 2 + T1 + 0.004)), (0.8 * S, 1.1 * S, 0.008),
              M(bianco), B, rastrema=(0.6, 1.0))
    bottoni(m, ORO, [COLLO - (0.2 + 0.25 * k) * S for k in range(4)], x=-0.25 * S, t=T1 + 0.008)
    bottoni(m, ORO, [COLLO - (0.2 + 0.25 * k) * S for k in range(4)], x=0.25 * S, t=T1 + 0.008, nome="bottone_r")
    colletto(m, "#B82820", alto=0.14 * S)
    for x in (-1, 1):  # le code della giubba dietro
        m.scatola(f"coda{x}", (x * 0.3 * S, GAMBE - 0.35 * S, BUSTO_P / 2 + 0.03), (0.5 * S, 0.9 * S, 0.02), M(blu),
                  [("bacino", 1.0)], smusso=0.005, rastrema=(0.7, 1.0))
    bandoliera(m, bianco, spalla="L", t=T1 + 0.012)
    bandoliera(m, bianco, spalla="R", t=T1 + 0.02, nome="bandoliera2")
    spalline(m, "#B82820")
    for lato, _ in LATI:
        stivale(m, lato, "#1A1A1E", alto=0.5 * S)
    capelli(m, "#3A2A1E", sopra=False)
    barba(m, "#3A2A1E", piena=False)
    shako(m, pennacchio="#B82820")
    fucile(m, lungo=1.15)
    return m


def Corazziere(faccia, cartella):
    """Corazziere francese: corazza d'acciaio coi chiodi d'ottone, elmo con la cresta e la criniera nera."""
    acciaio = "#C4CAD2"
    blu = "#2A3E8A"
    m = cavaliere("Corazziere", faccia, cartella, "Cavaliere", PELLI[1])
    vesti(m, blu, manica=blu, manica_fino=2 * S, avambraccio=blu, mano="#ECEAE2", coscia="#ECEAE2", stinco="#1A1A1E")
    corazza(m, acciaio, basso=GAMBE + 0.05 * S)
    for x, y in ((-0.7, 0.2), (0.7, 0.2), (-0.7, 1.4), (0.7, 1.4)):
        m.sfera(f"chiodo{x}{y}", (x * S, COLLO - y * S, -(BUSTO_P / 2 + T2 + 0.004)), 0.05 * S, M(OTTONE, "ottone"), B,
                anelli=4, lati=6, schiaccia=(1, 1, 0.5))
    cintura(m, "#ECEAE2", y=GAMBE - 0.02 * S)
    spalline(m, "#B82820", frange="#B82820")
    for lato, _ in LATI:
        guanto(m, lato, "#ECEAE2")
        stivale(m, lato, "#1A1A1E", alto=1.0 * S)
    barba(m, "#2A2018", piena=False)
    calotta(m, (acciaio, "ferro"), alto=0.58 * S, fascia=OTTONE, nuca=TESTA_Y - 0.1 * S)
    cresta_elmo(m, OTTONE, alto=0.58 * S, h=0.2 * S, larga=0.07 * S, tipo="ottone")
    m.scatola("criniera", (0, TESTA_Y + 0.0 * S, R_ELMO + 0.05), (0.2 * S, 1.2 * S, 0.06), M(NERO, "crine"), H,
              smusso=0.01, assi=rot_x(-0.12), rastrema=(1.3, 1.0))
    gualdrappa(m, blu, lambda pen: pen.rett(0, 0.75, 1, 0.85, "#ECEAE2"))
    spada(m, 0.9, elsa=OTTONE)
    return m


def Napoleone(faccia, cartella):
    """Napoleone: bicorno di traverso, redingote grigia aperta sull'uniforme verde della Guardia (colletto rosso,
    panciotto bianco, Legion d'onore), calzoni bianchi, stivali alti, la mano sinistra nel panciotto, spada."""
    grigio, verde, rosso = "#808286", "#24503A", "#B82820"
    m = fante("Napoleone", faccia, cartella, PELLI[3], mano_r=(-0.1, -0.55, -1), mano_l=(0.95, 0.4, -0.42))
    vesti(m, grigio, manica=grigio, manica_fino=2 * S, avambraccio=grigio, mano="#ECEAE2", coscia="#F0EEE6",
          stinco="#F0EEE6")

    def davanti(pen):
        pen.riempi(verde)
        pen.rett(0.0, 0.0, 1.0, 0.1, rosso)
        pen.rett(0.2, 0.1, 0.8, 0.82, "#F0EEE6")  # panciotto
        for v in (0.2, 0.33, 0.46, 0.59):
            pen.ellisse(0.46, v, 0.54, v + 0.05, ORO)
        pen.rett(0.0, 0.82, 1.0, 1.0, "#F0EEE6")
    pannello(m, "uniforme", (0, COLLO - BUSTO_A / 2, -(BUSTO_P / 2 + 0.006)), 0.9 * S, BUSTO_A, davanti, verde, B)
    for x in (-1, 1):  # la redingote aperta: due lembi grigi ai lati del petto
        m.scatola(f"redingote{x}", (x * 0.78 * S, (COLLO + GAMBE) / 2, 0.01), (0.46 * S, BUSTO_A + 0.012, BUSTO_P + 0.05),
                  M(grigio), B, smusso=0.006)
        m.scatola(f"bavero{x}", (x * 0.6 * S, COLLO - 0.35 * S, -(BUSTO_P / 2 + 0.028)), (0.2 * S, 0.7 * S, 0.012),
                  M(scuro(grigio, 0.3)), B, smusso=0.004)
    m.scatola("redingote_dietro", (0, (COLLO + GAMBE) / 2 + 0.006, 0.03), (BUSTO_L + 0.05, BUSTO_A + 0.012, BUSTO_P - 0.0),
              M(grigio), B, smusso=0.006)
    gonna(m, grigio, basso=0.35 * S, t=0.022, svasa=(1.12, 1.22), nome="falde")
    colletto(m, rosso, alto=0.14 * S)
    # Legion d'onore: nastro rosso e stella d'argento.
    m.scatola("nastro_legion", (-0.42 * S, COLLO - 0.45 * S, -(BUSTO_P / 2 + 0.014)), (0.1 * S, 0.12 * S, 0.006),
              M(rosso), B)
    m.cilindro("legion", (-0.42 * S, COLLO - 0.6 * S, -(BUSTO_P / 2 + 0.016)), 0.07 * S, 0.008, M("#D8DCE2", "ferro"),
               B, lati=5, assi=ASSE_Z)
    for lato, _ in LATI:
        stivale(m, lato, "#141416", alto=1.05 * S, risvolto="#2A2420")
    capelli(m, "#2A1E16", sopra=False)
    bicorno(m)
    spada(m, 0.7, elsa=ORO)
    return m


# -- Novecento ---------------------------------------------------------------------------------------------

def Fante(faccia, cartella):
    """Poilu della Grande Guerra: cappotto blu orizzonte coi bottoni, elmo Adrian, Lebel con la baionetta."""
    blu = "#7A92B0"
    m = fante("Fante", faccia, cartella, PELLI[1], **FUCILE)
    vesti(m, blu, manica=blu, manica_fino=2 * S, avambraccio=blu, coscia=blu, stinco=blu)
    strato(m, "cappotto", COLLO, GAMBE - 0.02, blu, T1 + 0.004)
    gonna(m, blu, basso=GAMBE - 1.0 * S, t=0.024, svasa=(1.1, 1.16), nome="falde")
    bottoni(m, "#C8B070", [COLLO - (0.3 + 0.35 * k) * S for k in range(3)], x=-0.4 * S, t=T1 + 0.004)
    bottoni(m, "#C8B070", [COLLO - (0.3 + 0.35 * k) * S for k in range(3)], x=0.4 * S, t=T1 + 0.004, nome="bottone_r")
    colletto(m, "#2C3A5A", alto=0.14 * S)
    cintura(m, "#4A3A28")
    giberne(m, "#5A4430")
    for lato, _ in LATI:
        fasce(m, lato, "#6A7E96", alto=0.8 * S)
        stivale(m, lato, "#2E2218", alto=0.22 * S)
    barba(m, "#3A2A1E", piena=False)
    capelli(m, "#3A2A1E", sopra=False)
    adrian()(m)
    fucile(m, lungo=1.05)
    return m


def Mitragliere(faccia, cartella):
    return squadra("Mitragliere", faccia, cartella, "#7A92B0", adrian(), pelle=PELLI[0], baffi="#2A2018", sacchi=True)


def FanteOttomano(faccia, cartella):
    return soldato("FanteOttomano", faccia, cartella, "#9A8A5A", "#9A8A5A", "#7A6A4A", "#3A2A1C", turbante_cachi(),
                   pelle=PELLI[2], baffi="#1A1410", capelli_c="#1A1410")


def MitraglieriOttomani(faccia, cartella):
    return squadra("MitraglieriOttomani", faccia, cartella, "#9A8A5A", turbante_cachi(), pelle=PELLI[2],
                   baffi="#1A1410")


def Stosstruppen(faccia, cartella):
    return soldato("Stosstruppen", faccia, cartella, "#6E7468", "#5E6458", None, "#2A2018", stahlhelm(),
                   pelle=PELLI[0], extra=lambda m: granate(m, 2))


def MitraglieriTedeschi(faccia, cartella):
    return squadra("MitraglieriTedeschi", faccia, cartella, "#6E7468", stahlhelm(), pelle=PELLI[0], baffi="#3A2A1E")


def FanteBritannico(faccia, cartella):
    return soldato("FanteBritannico", faccia, cartella, "#7A6E48", "#7A6E48", "#6A5E40", "#3A2A1C", brodie(),
                   pelle=PELLI[0], baffi="#5A3A22", extra=lambda m: zaino(m, "#8A7E58"))


def FucilieriSovietici(faccia, cartella):
    return soldato("FucilieriSovietici", faccia, cartella, "#7A6A48", "#5A5040", None, "#2A2018", ushanka(),
                   pelle=PELLI[0], lungo=1.0)


def MitraglieriSovietici(faccia, cartella):
    return squadra("MitraglieriSovietici", faccia, cartella, "#7A6A48", ushanka(), pelle=PELLI[0], scudo=True,
                   ruote=True)


def Granatieri(faccia, cartella):
    return soldato("Granatieri", faccia, cartella, "#5E6458", "#4E5448", None, "#1E1A16", stahlhelm("#6A7050"),
                   pelle=PELLI[3], baionetta=False, extra=lambda m: borraccia(m))


def MG42(faccia, cartella):
    return squadra("MG42", faccia, cartella, "#5E6458", stahlhelm("#6A7050"), arma="mg42", pelle=PELLI[3])


def FanteFranciaLibera(faccia, cartella):
    def lorena(m):
        def p(pen):
            pen.rett(0.44, 0.1, 0.56, 0.9, "#C8303A")
            pen.rett(0.25, 0.22, 0.75, 0.32, "#C8303A")
            pen.rett(0.18, 0.45, 0.82, 0.55, "#C8303A")
        pannello(m, "lorena", (0.5 * S, COLLO - 0.5 * S, -(BUSTO_P / 2 + T1 + 0.004)), 0.4 * S, 0.5 * S, p, "#6A6A44", B)
    return soldato("FanteFranciaLibera", faccia, cartella, "#6A6A44", "#5A5A3E", None, "#4A3020",
                   elmo_m1("#5A5E44", mimetica=False), pelle=PELLI[1], extra=lorena, baionetta=False)


def MarineUSA(faccia, cartella):
    def giubbotto(m):
        c = "#4A4E36"
        strato(m, "giubbotto", COLLO, GAMBE + 0.25 * S, c, T2 + 0.006, smusso=0.01)
        for k in range(3):
            strato(m, f"giubbotto_riga{k}", COLLO - (0.5 + 0.4 * k) * S, COLLO - (0.56 + 0.4 * k) * S, scuro(c, 0.2),
                   T2 + 0.01, smusso=0.004)
        m.scatola("giubbotto_zip", (0, (COLLO + GAMBE + 0.25 * S) / 2, -(BUSTO_P / 2 + T2 + 0.01)),
                  (0.12 * S, COLLO - GAMBE - 0.25 * S, 0.008), M(scuro(c, 0.35)), B)
    return soldato("MarineUSA", faccia, cartella, "#5A5E3E", "#4E5236", None, "#1E1A16", elmo_m1(), pelle=PELLI[0],
                   extra=giubbotto, cinghie="#3E4228", arma=lambda m: fucile_assalto(m))


def MitraglieriM60(faccia, cartella):
    return squadra("MitraglieriM60", faccia, cartella, "#5A5E3E", elmo_m1(), arma="mg42", pelle=PELLI[3],
                   cinghie="#3E4228")


def FanteNVA(faccia, cartella):
    return soldato("FanteNVA", faccia, cartella, "#6E7448", "#6E7448", None, "#3A3A2A", casco_coloniale(),
                   pelle=PELLI[1], cinghie="#4A4A30", capelli_c="#1A1410",
                   arma=lambda m: fucile_assalto(m, legno="#7A4A28", curvo=True))


def MitraglieriNVA(faccia, cartella):
    return squadra("MitraglieriNVA", faccia, cartella, "#6E7448", casco_coloniale(), pelle=PELLI[1], scudo=True,
                   ruote=True, cinghie="#4A4A30")


def FantePVA(faccia, cartella):
    def trapunta(m):
        for k in range(4):
            y = COLLO - (0.35 + 0.4 * k) * S
            strato(m, f"trapunta{k}", y + 0.02, y - 0.02, "#7A6E44", T1 + 0.006, smusso=0.0)
    return soldato("FantePVA", faccia, cartella, "#9A8C58", "#8E8050", "#7A6E44", "#3A3024",
                   ushanka("#9A8C5E"), pelle=PELLI[3], extra=trapunta, cinghie="#5A4A30", lungo=1.0,
                   capelli_c="#1A1410")


def MitraglieriPVA(faccia, cartella):
    return squadra("MitraglieriPVA", faccia, cartella, "#9A8C58", ushanka("#9A8C5E"), pelle=PELLI[3],
                   cinghie="#5A4A30")


# -- Generali del Novecento --------------------------------------------------------------------------------

def nastrini(m, colori, x=-0.55 * S, y=COLLO - 0.45 * S):
    for i, c in enumerate(colori):
        m.scatola(f"nastrino{i}", (x + (i - (len(colori) - 1) / 2) * 0.16 * S, y, -(BUSTO_P / 2 + T1 + 0.006)),
                  (0.15 * S, 0.1 * S, 0.008), M(c), B)


def generale(nome, faccia, cartella, divisa, calzoni, pelle, capelli_c, stivali="#1E1814", mano=None, baffi=None,
             mostrine=None, posa=None):
    m = fante(nome, faccia, cartella, pelle, **(posa or GENERALE))
    vesti(m, divisa, manica=divisa, manica_fino=2 * S, avambraccio=divisa, mano=mano, coscia=calzoni, stinco=calzoni)
    strato(m, "giacca", COLLO, GAMBE - 0.02, divisa, T1)
    gonna(m, divisa, basso=GAMBE - 0.4 * S, t=0.02, svasa=(1.05, 1.08), nome="falde")
    colletto(m, divisa, alto=0.14 * S)
    bottoni(m, ORO, [COLLO - (0.3 + 0.35 * k) * S for k in range(4)], t=T1)
    cintura(m, "#3A2A1C", fibbia=OTTONE)
    if mostrine:
        for x in (-1, 1):
            m.scatola(f"mostrina{x}", (x * 0.3 * S, COLLO - 0.1 * S, -(BUSTO_P / 2 + T1 + 0.006)), (0.22 * S, 0.14 * S, 0.008),
                      M(mostrine), B)
    for lato, _ in LATI:
        stivale(m, lato, stivali, alto=1.0 * S)
    capelli(m, capelli_c, sopra=False)
    if baffi:
        barba(m, baffi, piena=False)
    pistola(m, "R")
    fondina(m, "L")
    return m


def Foch(faccia, cartella):
    """Ferdinand Foch: giubba blu orizzonte, kepi rosso col gallone d'oro, baffi bianchi."""
    m = generale("Foch", faccia, cartella, "#7088A6", "#5E7494", PELLI[3], "#D8D4CC", mano="#E8E2D6", baffi="#E6E2DA")
    nastrini(m, ("#C8303A", "#2A4A9A", "#D8B048"))
    kepi(m, "#B02A2A", fascia="#1E2A44", oro=ORO)
    return m


def DeGaulle(faccia, cartella):
    """Charles de Gaulle: divisa cachi, bandoliera, kepi con le due stelle, croce di Lorena."""
    m = generale("DeGaulle", faccia, cartella, "#8C8058", "#7E7250", PELLI[3], "#2A2018", stivali="#4A3020",
                 baffi="#2A2018", posa=dict(mano_r=(0.15, -1, -0.25), mano_l=(0.05, -1, 0.1)))
    bandoliera(m, "#5A3E24", spalla="R", larga=0.16 * S)

    def lorena(pen):
        pen.rett(0.44, 0.1, 0.56, 0.9, "#C8303A")
        pen.rett(0.25, 0.22, 0.75, 0.32, "#C8303A")
        pen.rett(0.18, 0.45, 0.82, 0.55, "#C8303A")
    pannello(m, "lorena", (-0.55 * S, COLLO - 0.6 * S, -(BUSTO_P / 2 + T1 + 0.006)), 0.35 * S, 0.45 * S, lorena,
             "#8C8058", B)
    kepi(m, "#2A2A30", fascia="#2A2A30", alto=0.36 * S, oro=ORO, stelle=2)
    return m


def Rommel(faccia, cartella):
    """Erwin Rommel, la Volpe del deserto: berretto con gli occhiali, sciarpa, croce di cavaliere, binocolo."""
    grigio = "#5E6458"
    m = generale("Rommel", faccia, cartella, grigio, "#4E5448", PELLI[0], "#5A4A3A", stivali="#1E1A16",
                 mano=("#5A4030", "cuoio"))
    sciarpa(m, "#ECEAE2")
    m.cilindro("croce_cavaliere", (0, COLLO - 0.22 * S, -(R_TESTA + 0.03)), 0.09 * S, 0.012, M(NERO, "ferro"),
               [("torace", 1.0)], lati=4, assi=ASSE_Z)
    binocolo(m)
    berretto(m, grigio, NERO, stella="#B8BCC4", occhiali=True)
    return m


def Giap(faccia, cartella):
    """Vo Nguyen Giap: divisa cachi dell'Esercito popolare, mostrine rosse, berretto con la stella."""
    m = generale("Giap", faccia, cartella, "#8A8656", "#7A7648", PELLI[1], "#1A1410", mostrine="#B82820")
    nastrini(m, ("#C82828", "#D8B048", "#2E5AA8"))
    binocolo(m)
    berretto(m, "#8A8656", "#B82820", stella="#E8C048")
    return m


def PengDehuai(faccia, cartella):
    """Peng Dehuai: divisa cachi dei volontari cinesi, mostrine rosse, berretto con la stella rossa."""
    m = generale("PengDehuai", faccia, cartella, "#8E8456", "#7E7448", PELLI[3], "#2A2420", mostrine="#B82820")
    nastrini(m, ("#C82828", "#D8B048", "#2E5AA8"))
    binocolo(m)
    berretto(m, "#8E8456", "#8E8456", stella="#C82828")
    return m


TRUPPE = {f.__name__: f for f in (
    Giannizzero, Sipahi, MoschettiereSvedese, PicchiereSvedese, CorazziereSvedese, GustavoAdolfo, FanteriaDiLinea,
    Corazziere, Napoleone, Fante, Mitragliere, FanteOttomano, MitraglieriOttomani, Stosstruppen, MitraglieriTedeschi,
    FanteBritannico, FucilieriSovietici, MitraglieriSovietici, Granatieri, MG42, FanteFranciaLibera, MarineUSA,
    MitraglieriM60, FanteNVA, MitraglieriNVA, FantePVA, MitraglieriPVA, Foch, DeGaulle, Rommel, Giap, PengDehuai)}
