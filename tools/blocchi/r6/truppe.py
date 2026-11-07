"""Le truppe col corpo R6 (vedi r6.py). Ogni funzione riceve il percorso della faccia e restituisce il Modello."""
import numpy as np

from r6 import (ARTO, BUSTO_L, BUSTO_P, COLLO, GAMBE, PELLI, S, TESTA_D, TESTA_H, TESTA_Y, X_BRACCIO,
                Modello, anello, braccio, busto, gamba, mat, mat_immagine, norm, scheletro, testa)

ROSSO = "#A3262A"
FERRO = "#A4ACB6"
FERRO_SCURO = "#6C747E"
OTTONE = "#D2A548"
CUOIO = "#6E4A2C"
CUOIO_SCURO = "#4A3020"
LEGNO = "#80562F"


def scudo_png(percorso, lato=512):
    """Disegno dello scutum: campo rosso, ali e fulmini di Giove dorati (la cornice e l'umbone sono pezzi veri)."""
    from PIL import Image, ImageDraw
    k = 4
    L = lato * k
    img = Image.new("RGBA", (L, L), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    P = lambda u, v: (u * L, v * L)
    oro = (232, 190, 84, 255)
    for v0, s in ((0.07, 1), (0.93, -1)):
        # Ala: tre penne a ventaglio sopra e sotto l'umbone.
        for i, du in enumerate((-0.22, 0.0, 0.22)):
            d.polygon([P(0.5, v0 + s * 0.30), P(0.5 + du - 0.06, v0 + s * (0.02 + abs(du) * 0.3)),
                       P(0.5 + du + 0.06, v0 + s * (0.02 + abs(du) * 0.3))], fill=oro)
    # Fulmini ai lati.
    for u, s in ((0.2, 1), (0.8, -1)):
        d.polygon([P(u - 0.04 * s, 0.36), P(u + 0.05 * s, 0.47), P(u - 0.01 * s, 0.49), P(u + 0.04 * s, 0.64),
                   P(u - 0.06 * s, 0.51), P(u + 0.0 * s, 0.49)], fill=oro)
    img = img.resize((lato, lato), Image.LANCZOS)
    img.save(percorso)
    return percorso


CRESTA_STILE = "spazzola"  # "mezzaluna", "spazzola" o "pomello" (scelta di Mattia)


def _sulla_calotta(giro, alt_cupola, r, a):
    """Punto e normale della calotta (mezzo ellissoide) all'angolo a nel piano di mezzo (a>0 davanti)."""
    punto = np.array([0, giro + alt_cupola * np.cos(a), -r * np.sin(a)])
    su = np.array([0, np.cos(a) / alt_cupola, -np.sin(a) / r])
    return punto, su / np.linalg.norm(su)


def cresta(m, giro, alt_cupola, r, ottone, H, stile=None):
    """Cresta di crine sopra la galea, da davanti a dietro."""
    stile = stile or CRESTA_STILE
    rossi = [mat(c, "crine") for c in ("#C42A2A", "#A82224", "#D23A34")]
    cima = np.array([0, giro + alt_cupola, 0])
    if stile == "pomello":
        # Niente crine: solo il pomello d'ottone in cima (galea da marcia).
        m.cilindro("pomello_base", cima + np.array([0, 0.012, 0]), 0.05, 0.03, ottone, H, lati=10)
        m.sfera("pomello", cima + np.array([0, 0.045, 0]), 0.035, ottone, H, anelli=4, lati=10)
        return
    m.scatola("portacresta", cima + np.array([0, 0.005, 0]), (0.1 * S, 0.06, 0.4 * S), ottone, H, smusso=0.004)
    if stile == "mezzaluna":
        # Un solo blocco di crine a mezzaluna, col dorso arrotondato, più alto in mezzo.
        angoli = np.radians(np.linspace(-68, 68, 15))
        vertici, facce = [], []
        for a in angoli:
            punto, su = _sulla_calotta(giro, alt_cupola, r, a)
            h = (0.2 + 0.17 * np.cos(a * 1.25)) * S
            w = (0.16 - 0.03 * abs(a)) * S
            base = punto - su * 0.012
            x = np.array([1.0, 0, 0])
            vertici += [base - x * w / 2, base - x * w / 2 + su * h * 0.72, base + su * h,
                        base + x * w / 2 + su * h * 0.72, base + x * w / 2]
        k = 5
        for i in range(len(angoli) - 1):
            for j in range(k - 1):
                facce.append([i * k + j, i * k + j + 1, (i + 1) * k + j + 1, (i + 1) * k + j])
            facce.append([i * k + k - 1, i * k, (i + 1) * k, (i + 1) * k + k - 1])  # sotto
        facce.append(list(range(k))[::-1])
        ultimo = (len(angoli) - 1) * k
        facce.append([ultimo + j for j in range(k)])
        m.maglia("cresta", vertici, facce, rossi[0], H)
        return
    # Spazzola: tante ciocche sottili e fitte, altezze un po' irregolari, tre rossi.
    rng = np.random.default_rng(7)
    n = 23
    for i in range(n):
        a = np.radians(-66 + 132 * i / (n - 1))
        punto, su = _sulla_calotta(giro, alt_cupola, r, a)
        avanti = np.cross(np.array([1.0, 0, 0]), su)
        lungo = (0.2 + 0.17 * np.cos(a * 1.25)) * S * rng.uniform(0.9, 1.08)
        m.scatola(f"ciocca{i}", punto + su * (lungo / 2 - 0.012), (0.15 * S, lungo, 0.085 * S),
                  rossi[i % 3], H, assi=np.column_stack([[1.0, 0, 0], su, avanti]), rastrema=(0.8, 0.8))


def Legionario(faccia, cartella):
    m = Modello("Legionario")
    scheletro(m, mano_r=(0, 0.05, -1), mano_l=(0.25, 0.1, -1))
    pelle = PELLI[0]
    PELLE = mat(pelle, "pelle")
    TUNICA = mat(ROSSO, "stoffa")
    TUNICA_S = mat("#7E1A1E", "stoffa")
    LAMINA = mat(FERRO, "ferro")
    LAMINA_S = mat(FERRO_SCURO, "ferro")
    OT = mat(OTTONE, "ottone")
    PELLE_C = mat(CUOIO, "cuoio")
    PELLE_CS = mat(CUOIO_SCURO, "cuoio")
    B = BUSTO_PESI = [("torace", 0.75), ("spina", 0.25)]

    # Corpo: sotto l'armatura il busto è cuoio scuro (si vede solo nelle fessure tra le lamine).
    busto(m, PELLE_CS)
    testa(m, pelle, faccia)
    for lato in ("L", "R"):
        braccio(m, lato, TUNICA, PELLE, manica_fino=1.05 * S)
        gamba(m, lato, PELLE, PELLE)

    t = 0.032  # spessore delle lamine sopra il busto
    # Lorica segmentata: quattro cerchi attorno alla pancia, ognuno più largo di quello sopra.
    for i in range(4):
        y = GAMBE + 0.2 * S + i * 0.215 * S
        extra = (3 - i) * 0.006
        anello(m, f"cerchio{i}", (0, y, 0), (BUSTO_L, 0.2 * S, BUSTO_P), t + extra, LAMINA, B, smusso=0.006,
               rastrema=(1.0 + 0.01, 1.0 + 0.02))
    # Petto e schiena: fascia intera attorno al busto, sopra due piastre per lato con la fessura in mezzo.
    y_petto = GAMBE + 1.5 * S
    anello(m, "lorica_alta", (0, y_petto + 0.03 * S, 0), (BUSTO_L, 1.05 * S, BUSTO_P), t - 0.006, LAMINA_S, B,
           smusso=0.004)
    for z, nome in ((-1, "petto"), (1, "schiena")):
        for x in (-1, 1):
            m.scatola(f"{nome}{x}", (x * BUSTO_L / 4 + x * 0.006, y_petto, z * (BUSTO_P / 2 + t / 2)),
                      (BUSTO_L / 2 + t - 0.012, 0.95 * S, t), LAMINA, B, smusso=0.006)
    # Spalle coperte e collare rialzato.
    m.scatola("spalle", (0, COLLO + t / 2, 0), (BUSTO_L + 2 * t, t, BUSTO_P + 2 * t), LAMINA, B, smusso=0.006)
    m.scatola("collare_av", (0, COLLO - 0.06 * S, -(BUSTO_P / 2 + t + 0.004)), (0.95 * S, 0.2 * S, 0.02),
              LAMINA_S, B, smusso=0.004)
    # Fibbie e cerniere d'ottone sul petto.
    for x in (-1, 1):
        for y in (y_petto - 0.25 * S, y_petto + 0.2 * S):
            m.scatola(f"fibbia{x}{y:.2f}", (x * 0.13 * S, y, -(BUSTO_P / 2 + t + 0.006)), (0.16 * S, 0.1 * S, 0.016),
                      OT, B, smusso=0.003)
        m.cilindro(f"borchia{x}", (x * 0.65 * S, y_petto + 0.32 * S, -(BUSTO_P / 2 + t + 0.004)), 0.035, 0.016, OT, B,
                   lati=8, assi=np.array([[1, 0, 0], [0, 0, 1], [0, -1, 0]], float))
    # Spallacci: quattro lamine a gradini sopra ogni braccio, si muovono col braccio.
    for lato, segno in (("L", -1), ("R", 1)):
        for k in range(3):
            spess = 0.024 + 0.005 * k
            y = COLLO + 0.024 - 0.13 * S - k * 0.24 * S
            m.scatola(f"spallaccio{lato}{k}", (segno * (X_BRACCIO + 0.006 * k), y, 0),
                      (ARTO + 2 * spess, 0.26 * S, ARTO + 2 * spess), LAMINA,
                      [("braccio." + lato, 1.0)], smusso=0.006)
        # Orlo della manica rossa e polsiera di cuoio.
        anello(m, f"orlo{lato}", (segno * X_BRACCIO, COLLO - 1.05 * S + 0.04 * S, 0), (ARTO, 0.08 * S, ARTO), 0.008,
               TUNICA_S, [("braccio." + lato, 1.0)])
        gomito, polso = m.P("avambraccio." + lato), m.P("mano." + lato)
        d = norm(polso - gomito)
        m.segmento(f"polsiera{lato}", polso - d * 0.22 * S, polso - d * 0.02 * S, ARTO + 0.02, ARTO + 0.02, PELLE_C,
                   [("avambraccio." + lato, 1.0)], smusso=0.004)

    # Cingulum: cintura con placche d'ottone e grembiule di strisce chiodate.
    y_cinta = GAMBE + 0.06 * S
    anello(m, "cintura", (0, y_cinta, 0), (BUSTO_L, 0.17 * S, BUSTO_P), t + 0.02, PELLE_C, [("bacino", 1.0)])
    z_cinta = -(BUSTO_P / 2 + t + 0.02)
    for i in range(6):
        x = (i - 2.5) * 0.3 * S
        m.scatola(f"placca{i}", (x, y_cinta, z_cinta - 0.006), (0.2 * S, 0.13 * S, 0.014), OT, [("bacino", 1.0)],
                  smusso=0.003)
    for i in range(4):
        x = (i - 1.5) * 0.17 * S
        alto, basso = y_cinta - 0.05 * S, GAMBE - 0.75 * S
        m.scatola(f"striscia{i}", (x, (alto + basso) / 2, z_cinta - 0.002), (0.11 * S, alto - basso, 0.012), PELLE_CS,
                  [("bacino", 1.0)])
        for j in range(3):
            y = alto - (j + 0.6) * (alto - basso) / 3.3
            m.scatola(f"chiodo{i}{j}", (x, y, z_cinta - 0.01), (0.07 * S, 0.07 * S, 0.012), OT, [("bacino", 1.0)])
        m.scatola(f"pendente{i}", (x, basso - 0.05 * S, z_cinta - 0.004), (0.12 * S, 0.12 * S, 0.02), OT,
                  [("bacino", 1.0)], smusso=0.004)

    # Tunica: gonna svasata in due metà (ognuna segue la sua coscia in fondo), orlo più scuro.
    alto, basso = GAMBE + 0.02 * S, GAMBE - 0.6 * S
    for lato, segno in (("L", -1), ("R", 1)):
        def pesi(p, mondo, lato=lato, alto=alto, basso=basso):
            f = np.clip((alto - mondo[1]) / (alto - basso), 0, 1) * 0.6
            return [("bacino", 1 - f), ("coscia." + lato, f)] if f > 0 else [("bacino", 1.0)]
        m.scatola(f"gonna{lato}", (segno * BUSTO_L / 4, (alto + basso) / 2, 0),
                  (BUSTO_L / 2 + 0.02, alto - basso, BUSTO_P + 0.04), TUNICA, pesi, smusso=0.006, rastrema=(1.1, 1.18))
        m.scatola(f"orlo_gonna{lato}", (segno * (BUSTO_L / 4 + 0.012), basso + 0.04 * S, 0),
                  (BUSTO_L / 2 + 0.06, 0.08 * S, BUSTO_P + 0.1), TUNICA_S,
                  [("bacino", 0.4), ("coscia." + lato, 0.6)], smusso=0.004)
        # Caligae: suola, stivaletto a lacci e due lacci sopra la caviglia.
        x = segno * 0.5 * S
        m.scatola(f"suola{lato}", (x, 0.025, -0.03), (ARTO + 0.03, 0.05, ARTO + 0.1), PELLE_CS, [("piede." + lato, 1.0)],
                  smusso=0.008)
        anello(m, f"calzare{lato}", (x, 0.05 + 0.18 * S, -0.005), (ARTO, 0.36 * S, ARTO), 0.012, PELLE_C,
               [("stinco." + lato, 1.0)])
        for k, y in enumerate((0.6 * S, 0.78 * S)):
            anello(m, f"laccio{lato}{k}", (x, y, 0), (ARTO * 0.99, 0.06 * S, ARTO * 0.99), 0.007, PELLE_C,
                   [("stinco." + lato, 1.0)])
        m.scatola(f"linguetta{lato}", (x, 0.12 * S, -(ARTO / 2 + 0.02)), (0.5 * S, 0.3 * S, 0.02), PELLE_C,
                  [("stinco." + lato, 1.0)], smusso=0.004)

    # Focale: sciarpa chiara attorno al collo, col nodo davanti.
    SCIARPA = mat("#E6DCC4", "lana")
    m.cilindro("sciarpa", (0, COLLO + 0.07 * S, 0), TESTA_D / 2 + 0.012, 0.15 * S, SCIARPA, [("torace", 1.0)],
               lati=16, smusso=0.02, segmenti=1)
    m.scatola("nodo", (0.12 * S, COLLO - 0.04 * S, -(TESTA_D / 2 + 0.005)), (0.14 * S, 0.22 * S, 0.04), SCIARPA,
              [("torace", 1.0)], smusso=0.012, segmenti=1)

    # Galea: calotta a cupola, fascia d'ottone, rinforzo sulla fronte, nuca e paranuca inclinato, guanciali,
    # cresta rossa a ventaglio da davanti a dietro. Sta sopra le sopracciglia: la faccia resta tutta libera.
    ELMO = mat("#B4BBC4", "ferro")
    OT_E = mat(OTTONE, "ottone")
    H = [("testa", 1.0)]
    r = TESTA_D / 2 + 0.022
    giro = TESTA_Y + 0.27 * S
    alt_cupola = 0.5 * S
    m.cupola("calotta", (0, giro, 0), r, alt_cupola, ELMO, H)
    m.cilindro("fascia", (0, giro + 0.05 * S, 0), r + 0.006, 0.05 * S, OT_E, H, lati=18)
    m.cilindro("rinforzo", (0, giro + 0.005 * S, 0), r + 0.012, 0.05 * S, ELMO, H, lati=18, parte="fronte")
    m.cilindro("nuca", (0, (giro + TESTA_Y - 0.2 * S) / 2, 0), r, giro - TESTA_Y + 0.2 * S, ELMO, H, lati=18,
               parte="retro")
    paranuca_assi = np.array([[1, 0, 0], [0, np.cos(0.32), np.sin(0.32)], [0, -np.sin(0.32), np.cos(0.32)]])
    m.scatola("paranuca", (0, TESTA_Y - 0.2 * S, r + 0.025), (TESTA_D * 0.95, 0.26 * S, 0.026), ELMO, H, smusso=0.006,
              assi=paranuca_assi)
    for x in (-1, 1):
        m.scatola(f"guanciale{x}", (x * (r + 0.004), TESTA_Y - 0.02 * S, 0.035), (0.026, 0.55 * S, 0.3 * S), ELMO, H,
                  smusso=0.008, rastrema=(1.0, 0.7))
        m.cilindro(f"borchia_elmo{x}", (x * (r + 0.02), TESTA_Y + 0.12 * S, 0.035), 0.022, 0.012, OT_E, H,
                   lati=8, assi=np.array([[0, 1, 0], [1, 0, 0], [0, 0, 1]], float))
    cresta(m, giro, alt_cupola, r, OT_E, H)

    # Scutum curvo sul braccio sinistro: campo dipinto, cornice d'ottone, umbone.
    gomito, polso = m.P("avambraccio.L"), m.P("mano.L")
    d = norm(polso - gomito)
    pugno = polso + d * MANO_CENTRO
    c = pugno + np.array([-0.05, -0.04, -0.12])
    larg, alt = 0.62, 0.94
    disegno = scudo_png(f"{cartella}/scudo_legionario.png")
    CAMPO = mat("#A32226", "cuoio_dipinto")
    m.lastra_curva("scudo", c, larg, alt, 0.045, 0.75, CAMPO, [("mano.L", 1.0)],
                   fronte=mat_immagine("scudo_disegno", disegno, "#A32226", "cuoio_dipinto"))
    import math
    for v in (-1, 1):
        m.lastra_curva(f"cornice{v}", c + np.array([0, v * (alt / 2 - 0.015), -0.006]), larg + 0.01, 0.04, 0.06, 0.75,
                       OT, [("mano.L", 1.0)], fette=6)
    for u in (-1, 1):
        x = u * (larg / 2)
        dz = 0.75 - math.sqrt(0.75 ** 2 - x ** 2)
        ang = math.asin(x / 0.75)
        assi = np.array([[math.cos(ang), 0, -math.sin(ang)], [0, 1, 0], [math.sin(ang), 0, math.cos(ang)]])
        m.scatola(f"cornice_lato{u}", c + np.array([x, 0, dz - 0.006]), (0.035, alt, 0.06), OT, [("mano.L", 1.0)],
                  assi=assi, smusso=0.004)
    m.scatola("piastra_umbone", c + np.array([0, 0, -0.03]), (0.22, 0.24, 0.02), OT, [("mano.L", 1.0)], smusso=0.006)
    m.sfera("umbone", c + np.array([0, 0, -0.04]), 0.085, OT, [("mano.L", 1.0)], anelli=4, lati=10,
            schiaccia=(1, 1, 0.8), meta=True)

    # Pilum nella destra: asta, peso di piombo, lungo ferro sottile con la punta.
    gomito, polso = m.P("avambraccio.R"), m.P("mano.R")
    d = norm(polso - gomito)
    pugno = polso + d * MANO_CENTRO
    m.osso("lancia", "mano.R", m.P("mano.R"))
    L = [("lancia", 1.0)]
    basso = pugno + np.array([0, -0.6, 0.05])
    alto = pugno + np.array([0, 0.8, -0.05])
    m.segmento("asta", basso, alto, 0.045, 0.045, mat(LEGNO, "legno"), L, smusso=0.008)
    asse = norm(alto - basso)
    m.segmento("piombo", alto - asse * 0.02, alto + asse * 0.1, 0.075, 0.075, mat("#5C6168", "piombo"), L, smusso=0.01)
    ferro_fine = alto + asse * 0.62
    m.segmento("ferro", alto + asse * 0.1, ferro_fine, 0.022, 0.022, mat(FERRO, "ferro"), L)
    m.segmento("punta", ferro_fine, ferro_fine + asse * 0.09, 0.05, 0.05, mat("#C8CED6", "ferro"), L, smusso=0.012)
    m.segmento("puntale", basso - asse * 0.04, basso + asse * 0.04, 0.055, 0.055, mat(FERRO_SCURO, "ferro"), L,
               smusso=0.006)

    # Gladio nel fodero al fianco destro (lo sguaina dopo il lancio).
    fianco = np.array([BUSTO_L / 2 + 0.06, GAMBE + 0.1 * S, -0.03])
    m.osso("gladio", "bacino", fianco)
    G = [("gladio", 1.0)]
    m.scatola("fodero", fianco + np.array([0, -0.2, 0]), (0.05, 0.42, 0.1), mat(CUOIO, "cuoio"), G, smusso=0.01)
    for y in (-0.04, -0.2, -0.36):
        m.scatola(f"fascia_fodero{y}", fianco + np.array([0, y, 0]), (0.058, 0.03, 0.108), OT, G, smusso=0.004)
    m.scatola("puntale_fodero", fianco + np.array([0, -0.41, 0]), (0.06, 0.05, 0.08), OT, G, smusso=0.01)
    m.scatola("guardia", fianco + np.array([0, 0.03, 0]), (0.07, 0.035, 0.13), mat(LEGNO, "legno"), G, smusso=0.008)
    m.scatola("impugnatura", fianco + np.array([0, 0.1, 0]), (0.04, 0.1, 0.045), mat(CUOIO_SCURO, "cuoio"), G,
              smusso=0.008)
    m.sfera("pomo", fianco + np.array([0, 0.17, 0]), 0.04, mat(OTTONE, "ottone"), G, anelli=4, lati=8)
    return m


MANO_CENTRO = 0.2 * S  # dal polso al centro del pugno

TRUPPE = {"Legionario": Legionario}

import antichi  # noqa: E402

TRUPPE.update(antichi.TRUPPE)

import medievali  # noqa: E402

TRUPPE.update(medievali.TRUPPE)

import moderni  # noqa: E402

TRUPPE.update(moderni.TRUPPE)

import cannoni  # noqa: E402

TRUPPE.update(cannoni.TRUPPE)
