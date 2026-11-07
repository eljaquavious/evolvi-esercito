"""Truppe R6 dell'antichità (stessi disegni delle truppe a blocchi di nuove.py, soldati.py e cavalieri.py)."""
import math

import numpy as np

from kit import (ACCIAIO, B, BAC, BRONZO, CUOIO, CUOIO_SCURO, FERRO, GIRO, H, LATI, LEGNO, ORO, OTTONE, R_ELMO,
                 R_TESTA, T1, T2, M, arco, barba, benda_occhio, calotta, capelli, cappuccio, cavaliere, cintura,
                 colletto, corazza, corona_alloro, cresta_elmo, fante, faretra, fascia_arco, fascia_testa, fodero,
                 gonna, gualdrappa, lamelle, lancia, lancia_resta, mantello, manica, pteruges, rot_x, schinieri,
                 scudo, spada, stivale, strato, tesa, tubo, vesti, calzari, berretto_frigio, sopravveste, pugno,
                 polsino, bandoliera, anello_tondo, ASSE_Z, pannello, turbante)
from r6 import BUSTO_L, BUSTO_P, COLLO, GAMBE, PELLI, S, TESTA_Y, X_BRACCIO, anello

ARCIERE = dict(mano_r=(0.2, -1, -0.25), mano_l=(0.1, -0.75, -1))
LANCIERE = dict(mano_r=(0, 0.05, -1), mano_l=(0.25, 0.1, -1))


def elmo_corinzio(m, colore=BRONZO, cresta="#A82424"):
    """Elmo corinzio: calotta che scende sulla nuca, paraguance davanti con la fessura a T, cresta di crine."""
    b = M(colore, "ottone")
    calotta(m, b, alto=0.55 * S, nuca=TESTA_Y - 0.5 * S)
    fascia_arco(m, "frontale", GIRO - 0.12 * S, GIRO + 0.02, R_ELMO - 0.004, -100, 100, 0.012, b, H, lati=12)
    for s in (-1, 1):
        fascia_arco(m, f"paraguancia{s}", TESTA_Y - 0.6 * S, TESTA_Y - 0.03 * S, R_ELMO - 0.002,
                    s * 34, s * 105, 0.016, b, H, lati=6, rastrema=0.92)
    m.scatola("nasale", (0, TESTA_Y + 0.08 * S, -(R_ELMO + 0.004)), (0.12 * S, 0.3 * S, 0.016), b, H, smusso=0.004)
    if cresta:
        tubo(m, "portacresta", (0, GIRO + 0.5 * S, 0), (0, GIRO + 0.62 * S, 0), 0.02, b, H)
        cresta_elmo(m, cresta, alto=0.62 * S, h=0.38 * S, larga=0.13 * S)


def Immortale(faccia, cartella):
    """Immortale persiano: veste ricamata, cappuccio bianco, lancia col contrappeso d'oro, scudo di vimini."""
    pelle = PELLI[2]
    veste, ricamo = "#C8A030", "#5A2A6A"
    m = fante("Immortale", faccia, cartella, pelle, **LANCIERE)
    vesti(m, veste, manica=veste, manica_fino=1.4 * S, avambraccio=ricamo, coscia=veste, stinco=ricamo)

    def ricami(pen):
        for u in np.linspace(0.1, 0.9, 5):
            for v in np.linspace(0.1, 0.7, 4):
                pen.rett(u - 0.04, v - 0.03, u + 0.04, v + 0.03, ricamo)
    sopravveste(m, veste, ricami, basso=GAMBE - 1.25 * S, t=T1, nome="veste")
    manica(m, "L", ricamo, da=1.3 * S, a=1.45 * S, t=0.016, nome="orlo_manica")
    manica(m, "R", ricamo, da=1.3 * S, a=1.45 * S, t=0.016, nome="orlo_manica")
    cintura(m, "#7A2A2A", t=T1 + 0.012, fibbia=ORO)
    for lato, _ in LATI:
        stivale(m, lato, "#C89A30", alto=0.3 * S)
    barba(m, "#1E1612")
    cappuccio(m, "#ECE2C8", sotto_mento=False)
    lancia(m, contrappeso=ORO)

    def vimini(pen):
        for v in np.linspace(0.05, 0.95, 10):
            pen.rett(0, v - 0.025, 1, v + 0.025, "#A88A4A")
        pen.rett(0, 0, 1, 0.05, "#7A5A2A")
        pen.rett(0, 0.95, 1, 1, "#7A5A2A")
    scudo(m, "rettangolo", "#C8AA6A", vimini, larga=0.5, alta=0.72, tipo="vimini")
    faretra(m, centro=(0.12, GAMBE + 0.6 * 2 * S, BUSTO_P / 2 + 0.1), lunga=0.5, inclinazione=20)
    return m


def Oplita(faccia, cartella):
    """Oplita spartano: elmo corinzio crestato, corazza di bronzo, mantello rosso, schinieri, aspis con la lambda."""
    pelle = PELLI[3]
    rosso = "#A82424"
    m = fante("Oplita", faccia, cartella, pelle, **LANCIERE)
    vesti(m, rosso, coscia=None, stinco=None)
    barba(m, "#2A1C14", baffi=True)
    gonna(m, rosso, basso=GAMBE - 0.45 * S, orlo="#7A1A1A")
    corazza(m, BRONZO, muscoli=True)
    pteruges(m, "#E8DFC8", lungo=0.4 * S, n=10)
    cintura(m, CUOIO, y=GAMBE + 0.2 * S, alta=0.12 * S, t=T2 + 0.01)
    mantello(m, rosso, basso=GAMBE * 0.25)
    schinieri(m, BRONZO)
    for lato, _ in LATI:
        calzari(m, lato, "#5A3A22")
    elmo_corinzio(m, cresta=rosso)
    lancia(m, alto=1.1, basso=0.7)

    def lambda_(pen):
        pen.poligono([(0.5, 0.2), (0.8, 0.8), (0.66, 0.8), (0.5, 0.42), (0.34, 0.8), (0.2, 0.8)], rosso)
    scudo(m, "tondo", BRONZO, lambda_, larga=0.86, alta=0.86, tipo="ottone", bordo="#8A5A28", angolo=20, avanti=0.14,
          bombato=0.05)
    return m


def ArcierePersiano(faccia, cartella):
    pelle = PELLI[2]
    tunica = "#9A3A2A"
    m = fante("ArcierePersiano", faccia, cartella, pelle, **ARCIERE)
    vesti(m, tunica, manica=tunica, manica_fino=2 * S, avambraccio=tunica, coscia="#3A5A7A", stinco="#3A5A7A")
    strato(m, "tunica", COLLO, GAMBE, tunica, T1)
    gonna(m, tunica, basso=GAMBE - 0.55 * S, orlo="#E0C060")
    colletto(m, "#E0C060", alto=0.1 * S)
    cintura(m, "#C89A30", t=T1 + 0.012)
    for lato, _ in LATI:
        polsino(m, lato, "#E0C060", a=0.12 * S)
        stivale(m, lato, "#5A3A22", alto=0.45 * S)
    barba(m, "#1E1612")
    capelli(m, "#1E1612", sopra=False)
    berretto_frigio(m, "#E6D6AA")
    arco(m, 1.15, 0.18, legno="#4A2E1A", ricurvo=True)
    faretra(m, fianco=True, colore="#7A3A2A", inclinazione=12)
    return m


def LanciereLibico(faccia, cartella):
    """Fante libico di Annibale: elmo di bronzo col bottone, cotta di lino, scudo ovale bianco col segno di Tanit."""
    pelle = PELLI[4]
    lino = "#E8DFC8"
    m = fante("LanciereLibico", faccia, cartella, pelle, **LANCIERE)
    vesti(m, lino, manica=lino, manica_fino=0.8 * S)
    strato(m, "linothorax", COLLO, GAMBE + 0.1 * S, (lino, "cuoio_dipinto"), T2)
    m.scatola("spalle_lino", (0, COLLO + T2 / 2, 0), (BUSTO_L + 2 * T2, T2, BUSTO_P + 2 * T2), M(lino, "cuoio_dipinto"),
              B, smusso=0.006)
    strato(m, "bordo_lino", COLLO - 0.02 * S, COLLO - 0.22 * S, "#A02828", T2 + 0.006)
    gonna(m, lino, basso=GAMBE - 0.5 * S)
    pteruges(m, lino, lungo=0.38 * S, n=10)
    cintura(m, CUOIO, y=GAMBE + 0.14 * S, alta=0.12 * S)
    for lato, _ in LATI:
        calzari(m, lato, "#5A3A22")
    barba(m, "#1A1410", baffi=False)
    capelli(m, "#1A1410", sopra=False)
    b = M(BRONZO, "ottone")
    calotta(m, b, alto=0.5 * S)
    m.sfera("bottone_elmo", (0, GIRO + 0.52 * S, 0), 0.05, b, H, anelli=4, lati=8)
    for s in (-1, 1):
        fascia_arco(m, f"paraguancia{s}", TESTA_Y - 0.45 * S, GIRO, R_ELMO - 0.002, s * 55, s * 100, 0.014, b, H, lati=4)
    lancia(m)

    def tanit(pen):
        pen.poligono([(0.5, 0.35), (0.65, 0.75), (0.35, 0.75)], "#A02828")
        pen.ellisse(0.42, 0.18, 0.58, 0.34, "#A02828")
        pen.rett(0.3, 0.36, 0.7, 0.41, "#A02828")
    scudo(m, "ovale", "#ECE6D6", tanit, larga=0.56, alta=0.86, umbone=None, bordo="#8A6A40")
    return m


def FrombolieroBaleare(faccia, cartella):
    """Frombolieri delle Baleari: tunica corta, la fionda nella destra, un'altra in testa, la sacca delle pietre."""
    pelle = PELLI[2]
    tunica = "#D8CCA8"
    capelli_c = "#2A1C14"
    m = fante("FrombolieroBaleare", faccia, cartella, pelle, mano_r=(0.3, -1, -0.2), mano_l=(0.1, -0.8, -0.8))
    vesti(m, tunica, manica=tunica, manica_fino=0.55 * S)
    strato(m, "tunica", COLLO, GAMBE, tunica, T1)
    gonna(m, tunica, basso=GAMBE - 0.45 * S)
    cintura(m, "#5A3A22", t=T1 + 0.012)
    for lato, _ in LATI:
        calzari(m, lato, "#5A3A22")
    capelli(m, capelli_c, lunghi=0.1 * S)
    barba(m, capelli_c, baffi=True)
    fascia_testa(m, "#8A6A3A", y=GIRO + 0.02 * S, alta=0.07 * S)  # la fionda di riserva legata in testa
    p, d = pugno(m, "R")
    W = [("mano.R", 1.0)]
    tubo(m, "fionda", p, p + np.array([0, -0.45, 0]), 0.006, M("#8A6A3A", "stoffa"), W, lati=4)
    m.scatola("tasca_fionda", p + np.array([0, -0.48, 0]), (0.07, 0.05, 0.05), M("#6A4A2A", "cuoio"), W, smusso=0.01)
    m.sfera("sacca", (-(BUSTO_L / 2 + 0.07), GAMBE - 0.06, 0), 0.1, M("#7A5A3A", "cuoio"), BAC, anelli=5, lati=10,
            schiaccia=(0.8, 1.1, 0.9))
    bandoliera(m, "#6A4A2A", spalla="R", larga=0.1 * S, nome="cinghia_sacca")
    return m


def GuerrieroGallico(faccia, cartella):
    """Guerriero gallo: brache a quadri, torso nudo col torques, capelli lunghi e baffi, spada lunga, scudo verde."""
    pelle = PELLI[3]
    capelli_c = "#C89A50"
    m = fante("GuerrieroGallico", faccia, cartella, pelle, mano_r=(-0.1, -0.55, -1), mano_l=(0.25, 0.1, -1))

    def quadri(pen):
        pen.riempi("#3A6A3A")
        for u in np.linspace(0, 1, 6):
            pen.rett(u - 0.04, 0, u + 0.04, 1, "#B83A2A")
        for v in np.linspace(0, 1, 6):
            pen.rett(0, v - 0.03, 1, v + 0.03, "#C8A040")
    from kit import dipinto
    brache = dipinto(m, "brache", quadri, "#3A6A3A", "lana")
    vesti(m, M(pelle, "pelle"))
    # Brache a quadri: blocchi di lana attorno alle gambe con la trama dipinta su tutti i lati.
    for lato, s in LATI:
        x = s * 0.5 * S
        for k, (y0, y1) in enumerate(((GAMBE + 0.05, GAMBE * 0.5), (GAMBE * 0.5, 0.06))):
            osso = "coscia." + lato if k == 0 else "stinco." + lato
            for a in range(4):  # ogni lato del blocco con la sua proiezione
                assi = np.array([[math.cos(a * math.pi / 2), 0, math.sin(a * math.pi / 2)], [0, 1, 0],
                                 [-math.sin(a * math.pi / 2), 0, math.cos(a * math.pi / 2)]])
                c = np.array([x, (y0 + y1) / 2, 0]) + assi @ np.array([0, 0, -(0.5 * S + 0.012)])
                m.scatola(f"brache{lato}{k}{a}", c, (S + 0.024, y0 - y1, 0.012), M("#3A6A3A", "lana"), [(osso, 1.0)],
                          fronte=brache, uv=True, assi=assi)
        stivale(m, lato, "#5A3A22", alto=0.12 * S)
    cintura(m, "#5A3A22", t=0.02, fibbia=ORO)
    tubo(m, "torques", (-0.42 * S, COLLO + 0.02, -0.1 * S), (0.42 * S, COLLO + 0.02, -0.1 * S), 0.022, M(ORO, "ottone"),
         [("torace", 1.0)], lati=8)
    for x in (-1, 1):
        m.sfera(f"torques_capo{x}", (x * 0.44 * S, COLLO + 0.02, -0.1 * S), 0.035, M(ORO, "ottone"), [("torace", 1.0)],
                anelli=4, lati=8)
    capelli(m, capelli_c, lunghi=0.45 * S, frangia=True)
    barba(m, capelli_c, piena=False, baffi=True)
    m.scatola("baffi_lunghi", (0, TESTA_Y - 0.2 * S, -(R_TESTA + 0.01)), (0.62 * S, 0.06 * S, 0.03), M(capelli_c, "crine"),
              H, rastrema=(0.6, 1.0))
    spada(m, 0.85, elsa="#8A6A3A")

    def disegno(pen):
        pen.rett(0.46, 0.0, 0.54, 1.0, "#C8A040")
        pen.ellisse(0.38, 0.4, 0.62, 0.6, "#C8A040")
    scudo(m, "ovale", "#2E5A3A", disegno, larga=0.5, alta=0.92, umbone=FERRO, bordo="#5A4A3A")
    return m


def ArciereGallico(faccia, cartella):
    pelle = PELLI[3]
    capelli_c = "#8A5A2A"
    tunica = "#7A6A3A"
    m = fante("ArciereGallico", faccia, cartella, pelle, **ARCIERE)
    vesti(m, tunica, manica=tunica, manica_fino=1.0 * S, coscia="#8A3A2A", stinco="#8A3A2A")
    strato(m, "tunica", COLLO, GAMBE, tunica, T1)
    gonna(m, tunica, basso=GAMBE - 0.5 * S)
    cintura(m, "#4A3020", t=T1 + 0.012)
    for lato, _ in LATI:
        stivale(m, lato, "#4A3020", alto=0.3 * S)
    mantello(m, "#4A6A3A", basso=GAMBE * 0.35, bordo="#C8A040")
    capelli(m, capelli_c, lunghi=0.3 * S, frangia=True)
    barba(m, capelli_c, piena=False, baffi=True)
    arco(m, 1.3, 0.12)
    faretra(m, fianco=True, inclinazione=12)
    return m


def ArciereCretese(faccia, cartella):
    pelle = PELLI[2]
    tunica, bordo = "#E8DFC8", "#2E5A8C"
    m = fante("ArciereCretese", faccia, cartella, pelle, **ARCIERE)
    vesti(m, tunica, manica=tunica, manica_fino=0.6 * S)
    strato(m, "tunica", COLLO, GAMBE, tunica, T1)
    gonna(m, tunica, basso=GAMBE - 0.45 * S, orlo=bordo)
    colletto(m, bordo, alto=0.08 * S)
    cintura(m, "#7A5232", t=T1 + 0.012)
    for lato, _ in LATI:
        manica(m, lato, bordo, da=0.5 * S, a=0.6 * S, t=0.016, nome="orlo_manica")
        calzari(m, lato, "#6A4628")
    capelli(m, "#2A1C14", frangia=True)
    fascia_testa(m, bordo, y=GIRO - 0.02 * S)
    arco(m, 1.15, 0.16)
    faretra(m, inclinazione=-25)
    return m


# -- A cavallo --------------------------------------------------------------------------------------------

def CavalleriaPersiana(faccia, cartella):
    pelle = PELLI[2]
    m = cavaliere("CavalleriaPersiana", faccia, cartella, "Compagno", pelle)
    vesti(m, "#6A2A6A", manica="#6A2A6A", manica_fino=2 * S, avambraccio="#6A2A6A", coscia="#3A5A7A", stinco="#3A5A7A")
    lamelle(m, "#A88A4A", file=5, basso=GAMBE - 0.15 * S)
    cintura(m, "#7A2A2A", t=T2 + 0.03)
    for lato, _ in LATI:
        stivale(m, lato, "#5A3A22", alto=0.4 * S)
    barba(m, "#1E1612")
    cappuccio(m, "#D8C8A0", sotto_mento=False)
    gualdrappa(m, "#6A2A6A", lambda pen: pen.rett(0, 0.75, 1, 0.85, "#C89A30"))
    lancia_resta(m, 1.8, 0.8)
    return m


def CavalleriaNumidica(faccia, cartella):
    """Cavalieri numidi: senza armatura, tunica corta, scudo tondo di cuoio e giavellotto."""
    pelle = PELLI[4]
    m = cavaliere("CavalleriaNumidica", faccia, cartella, "Annibale", pelle, mano_l=(0.05, -0.65, -1))
    vesti(m, "#E8E0C8", manica="#E8E0C8", manica_fino=0.5 * S)
    strato(m, "tunica", COLLO, GAMBE, "#E8E0C8", T1)
    gonna(m, "#E8E0C8", basso=GAMBE - 0.3 * S)
    cintura(m, "#7A4A2A", t=T1 + 0.012)
    capelli(m, "#1A1410")
    barba(m, "#1A1410", baffi=False)
    gualdrappa(m, "#C8A060", lambda pen: pen.rett(0, 0.8, 1, 0.88, "#7A3A2A"), lunga=0.9, tipo="pelliccia")
    scudo(m, "tondo", "#8A5A30", lambda pen: pen.ellisse(0.4, 0.4, 0.6, 0.6, "#C8A060"), larga=0.5, alta=0.5,
          tipo="cuoio", angolo=60, avanti=0.08, bordo="#5A3A20")
    lancia_resta(m, 1.2, 0.6)
    return m


def CavalleriaGallica(faccia, cartella):
    pelle = PELLI[3]
    capelli_c = "#B88A4A"
    m = cavaliere("CavalleriaGallica", faccia, cartella, "Cavaliere", pelle)
    vesti(m, M("#7E848C", "maglia"), manica=M("#7E848C", "maglia"), manica_fino=1.1 * S, coscia="#8A3A2A",
          stinco="#8A3A2A")
    strato(m, "cotta", COLLO, GAMBE - 0.02, M("#7E848C", "maglia"), T1)
    gonna(m, M("#7E848C", "maglia"), basso=GAMBE - 0.3 * S, nome="cotta_gonna")
    cintura(m, "#4A3020", t=T1 + 0.012, fibbia=ORO)
    for lato, _ in LATI:
        stivale(m, lato, "#4A3020", alto=0.3 * S)
    capelli(m, capelli_c, lunghi=0.25 * S)
    barba(m, capelli_c, piena=False)
    b = M(BRONZO, "ottone")
    calotta(m, b, alto=0.5 * S)
    cresta_elmo(m, BRONZO, h=0.16 * S, larga=0.06 * S, tipo="ottone")
    gualdrappa(m, "#2E5A3A", lambda pen: pen.rett(0, 0.8, 1, 0.88, "#C8A040"))
    lancia_resta(m, 1.8, 0.8)
    return m


def CavalleriaGermanica(faccia, cartella):
    """Cavalieri germanici di Cesare: pelliccia sulle spalle, nodo svevo, barba bionda, lancia."""
    pelle = PELLI[3]
    capelli_c = "#D8B060"
    m = cavaliere("CavalleriaGermanica", faccia, cartella, "Compagno", pelle)
    vesti(m, "#5A4A3A", coscia="#5A4A3A", stinco="#5A4A3A")
    strato(m, "pelliccia", COLLO, GAMBE - 0.05, M("#6A4A2E", "pelliccia"), 0.04, smusso=0.02)
    for lato, _ in LATI:
        manica(m, lato, M("#6A4A2E", "pelliccia"), a=0.45 * S, t=0.03, nome="pelliccia_spalla")
        stivale(m, lato, "#3A2A1C", alto=0.35 * S)
    cintura(m, CUOIO, t=0.05)
    capelli(m, capelli_c)
    m.sfera("nodo_svevo", (0.28 * S, GIRO + 0.25 * S, 0.12 * S), 0.11, M(capelli_c, "crine"), H, anelli=5, lati=10)
    barba(m, capelli_c, lunga=0.12 * S)
    gualdrappa(m, "#5A4A3A", lunga=0.9)
    lancia_resta(m, 1.8, 0.8, legno="#7A5232")
    return m


def Compagno(faccia, cartella):
    """Compagno di Alessandro: elmo beotico di bronzo, linothorax bianco con la piastra di squame, clamide di porpora,
    xyston."""
    pelle = PELLI[2]
    bronzo, porpora = "#B88A44", "#7A2A5A"
    m = cavaliere("Compagno", faccia, cartella, "Compagno", pelle, mano_l=(0.05, -0.65, -1))
    vesti(m, "#ECE4CC", manica="#ECE4CC", manica_fino=0.5 * S)
    strato(m, "linothorax", COLLO, GAMBE + 0.1 * S, ("#ECE4CC", "cuoio_dipinto"), T2)
    m.scatola("squame", (0, COLLO - 0.85 * S, -(BUSTO_P / 2 + T2 + 0.006)), (1.4 * S, 0.75 * S, 0.012),
              M(bronzo, "squame"), B, smusso=0.004)
    strato(m, "fascia_porpora", GAMBE + 0.35 * S, GAMBE + 0.2 * S, porpora, T2 + 0.006)
    pteruges(m, "#D8CCA8", lungo=0.35 * S)
    for lato, _ in LATI:
        stivale(m, lato, "#7A5232", alto=0.65 * S, risvolto="#5A3A22")
    barba(m, "#3A2A1E")
    mantello(m, porpora, basso=GAMBE - 0.05, bordo="#E0B848")
    b = M(bronzo, "ottone")
    calotta(m, b, alto=0.55 * S)
    tesa(m, b, R_TESTA + 0.17, GIRO - 0.04 * S, spessore=0.02, giu=0.06)
    lancia_resta(m, 2.2, 1.1, legno="#9A7448", punta="#C8A060")
    return m


def Annibale(faccia, cartella):
    """Annibale: benda sull'occhio perso, barba, corazza di bronzo, elmo con la cresta bianca, mantello di porpora."""
    pelle = PELLI[4]
    bronzo, porpora, oro = "#B8843C", "#5E2470", "#E0B848"
    m = cavaliere("Annibale", faccia, cartella, "Annibale", pelle)
    vesti(m, "#A02828", manica="#A02828", manica_fino=0.55 * S)
    corazza(m, bronzo, muscoli=True)
    m.cilindro("tanit", (0, COLLO - 0.35 * S, -(BUSTO_P / 2 + T2 + 0.006)), 0.06, 0.012, M(oro, "ottone"), B, lati=12,
               assi=ASSE_Z)
    gonna(m, "#A02828", basso=GAMBE - 0.3 * S)
    pteruges(m, "#A02828", lungo=0.3 * S)
    schinieri(m, bronzo)
    for lato, _ in LATI:
        stivale(m, lato, "#5A3A22", alto=0.15 * S)
    mantello(m, porpora, basso=GAMBE - 0.05, bordo=oro)
    barba(m, "#1E1612")
    capelli(m, "#1E1612", sopra=False)
    benda_occhio(m)
    b = M(bronzo, "ottone")
    calotta(m, b, alto=0.5 * S)
    cresta_elmo(m, "#ECE8DC", h=0.3 * S, larga=0.12 * S)
    for s in (-1, 1):
        fascia_arco(m, f"paraguancia{s}", TESTA_Y - 0.4 * S, GIRO, R_ELMO - 0.002, s * 60, s * 100, 0.014, b, H, lati=4)
    lancia_resta(m, 2.0, 1.0, legno="#7A5232", punta="#C8A060")
    return m


def Cesare(faccia, cartella):
    """Giulio Cesare a cavallo: corazza muscolare dorata, tunica e paludamentum rossi, corona d'alloro, gladio alzato;
    gualdrappa rossa col bordo d'oro."""
    pelle = PELLI[1]
    oro, rosso = "#C89A40", "#A02828"
    m = cavaliere("Cesare", faccia, cartella, "Guglielmo", pelle)
    vesti(m, rosso, manica=rosso, manica_fino=0.55 * S)
    corazza(m, oro, muscoli=True)
    strato(m, "fascia_comando", GAMBE + 0.5 * S, GAMBE + 0.4 * S, "#ECEAE2", T2 + 0.008)
    gonna(m, rosso, basso=GAMBE - 0.3 * S)
    pteruges(m, "#8A6A3C", lungo=0.3 * S)
    for lato, _ in LATI:
        stivale(m, lato, "#5A3A20", alto=0.6 * S)
    mantello(m, rosso, basso=GAMBE - 0.05, bordo="#D8B048")
    capelli(m, "#3A2A1E", frangia=True)
    corona_alloro(m)
    gualdrappa(m, rosso, lambda pen: pen.rett(0, 0.72, 1, 0.84, "#D8B048"))
    spada(m, 0.55, elsa=oro)  # il gladio sguainato, puntato in avanti
    return m


TRUPPE = {f.__name__: f for f in (Immortale, Oplita, ArcierePersiano, LanciereLibico, FrombolieroBaleare,
                                  GuerrieroGallico, ArciereGallico, ArciereCretese, CavalleriaPersiana,
                                  CavalleriaNumidica, CavalleriaGallica, CavalleriaGermanica, Compagno, Annibale,
                                  Cesare)}


def Elefante(faccia, cartella):
    """Elefante da guerra di Zama: l'elefante di prima (stesse ossa del cavallo) col conducente R6 sul dorso,
    tunica chiara, turbante, il pungolo."""
    pelle = PELLI[4]
    m = cavaliere("Elefante", faccia, cartella, "Elefante", pelle, seduta=(0, 2.45, 0.0))
    vesti(m, "#E8E0C8", manica=None, coscia="#E8E0C8")
    strato(m, "tunica", COLLO, GAMBE - 0.02, "#E8E0C8", T1)
    cintura(m, "#7A4A2A")
    barba(m, "#1A1410")
    capelli(m, "#1A1410", sopra=False)
    turbante(m, "#ECE6D6", alto=0.36 * S)
    lancia(m, 1.0, 0.4, legno="#7A5232")
    return m


TRUPPE["Elefante"] = Elefante
