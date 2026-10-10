"""Arciere cretese (età ellenistica, III-II secolo a.C.), sullo stesso corpo realistico del legionario.

Riferimenti: mercenari cretesi nelle fonti antiche e nelle ricostruzioni (tunica rossa corta con
cintura, benda sulla fronte, arco composito ricurvo, faretra sulla schiena, piccolo scudo tondo di
bronzo appeso a tracolla per avere le mani libere, spada corta, stivaletti allacciati). Lo scudo porta
il labirinto di Cnosso, come sulle monete cretesi.

Posa: la sinistra regge l'arco in verticale davanti al fianco (avambraccio in avanti, come il legionario
con la lancia), la destra pende rilassata. Nel gioco l'arco ha un osso suo ("arco") figlio della mano.
"""

import math

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

import umano
import vestiti as V

NOME = "ArciereCretese"
SIGLA = "AC"

IMPUGNATURA = Vector((0.255, -0.235, 1.0))   # centro del pugno sinistro sull'arco
META_ARCO = 0.575                            # mezza lunghezza dell'arco (1,15 m in tutto)
INCLINAZIONE_ARCO = 4                        # gradi: la cima un poco in avanti

U = None


def materiali(u):
    u.materiale("Tunica", (0.48, 0.055, 0.04), ruvidita=0.9)
    u.materiale("Bordo", (0.62, 0.50, 0.30), ruvidita=0.85)
    u.materiale("Benda", (0.78, 0.72, 0.60), ruvidita=0.9)
    u.materiale("Cuoio", (0.22, 0.11, 0.05), ruvidita=0.65)
    u.materiale("CuoioChiaro", (0.30, 0.17, 0.08), ruvidita=0.7)
    u.materiale("Stivali", (0.17, 0.085, 0.04), ruvidita=0.7)
    u.materiale("Lacci", (0.07, 0.035, 0.015), ruvidita=0.7)
    u.materiale("Suola", (0.07, 0.04, 0.02), ruvidita=0.8)
    u.materiale("Bronzo", (0.80, 0.52, 0.24), metallo=1.0, ruvidita=0.35)
    u.materiale("Ferro", (0.42, 0.42, 0.44), metallo=1.0, ruvidita=0.4)
    u.materiale("Legno", (0.36, 0.20, 0.09), ruvidita=0.6)
    u.materiale("Corno", (0.12, 0.08, 0.05), ruvidita=0.45)
    u.materiale("Corda", (0.80, 0.74, 0.60), ruvidita=0.8)
    u.materiale("Piume", (0.85, 0.82, 0.74), ruvidita=0.9)
    u.materiale("PiumeRosse", (0.55, 0.08, 0.05), ruvidita=0.9)
    u.materiale("Scudo", (0.80, 0.52, 0.24), metallo=1.0, ruvidita=0.35, immagine=immagine_labirinto())


# Posa ----------------------------------------------------------------------------------------------

def posa(sch):
    for s in (1, -1):
        k = umano.sigla(s)
        umano.ruota_mondo(sch, "coscia" + k, (0, 1, 0), 2.5 * s)
        umano.ruota_mondo(sch, "piede" + k, (0, 1, 0), -2.5 * s)
    # Sinistra: pugno chiuso sull'impugnatura verticale dell'arco (come la destra del legionario sulla lancia).
    avanti = Vector((-0.15, -1, 0)).normalized()
    su = Vector((0, 0, 1))
    phi = math.radians(15)
    radiale = su * math.cos(phi) - avanti * math.sin(phi)
    y = avanti * math.cos(phi) + su * math.sin(phi)
    dorso = radiale.cross(y).normalized()
    umano.posa_braccio(sch, 1, IMPUGNATURA - y * 0.09 + dorso * 0.028, y, dorso, (0.5, 0.7, -0.3))
    umano.chiudi_dita(sch, 1, {"indice": (70, 95, 50), "medio": (75, 95, 50), "anulare": (80, 95, 50),
                               "mignolo": (85, 90, 50), "pollice": (35, 45, 35)})
    # Destra: lungo il fianco, un poco staccata, dita appena chiuse.
    umano.ruota_mondo(sch, "braccio.R", (0, 1, 0), 4)
    umano.piega(sch, "avambraccio.R", -12)
    umano.chiudi_dita(sch, -1, {"indice": (20, 35, 20), "medio": (25, 40, 20), "anulare": (30, 40, 20),
                                "mignolo": (35, 40, 20), "pollice": (10, 15, 10)})


# Vestiti -------------------------------------------------------------------------------------------

def vestiti(u):
    V.veste(u, "Tunica", 1.43, 0.60, "Tunica", margine=0.013, svasatura=0.06, pieghe=0.007, n_pieghe=14)
    V.maniche(u, "Tunica_Maniche", "Tunica", t_inizio=-0.15, t_fine=0.42, margine=0.011)
    # Orlo chiaro in fondo alla tunica.
    tunica = bpy.data.objects["Tunica"]
    zs = [v.co.z for v in tunica.data.vertices]
    fondo = min(zs)
    bm = bmesh.new()
    bm.from_mesh(tunica.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z > fondo + 0.035], context="VERTS")
    for v in bm.verts:
        v.co += v.normal * 0.0025
    u.oggetto("Tunica_Orlo", bm, "Bordo")
    # Cintura di cuoio sopra la tunica.
    u.oggetto("Cintura", V.anello_sul_corpo(u, (0, 0.01, 1.0), (0, 0, 1), 0.03, 0.04, n=64, portata=0.3), "Cuoio",
              spessore=0.004)
    # Benda sulla fronte, più alta davanti.
    benda = V.anello_sul_corpo(u, (0, -0.01, 1.675), (0, 0.3, 1), 0.004, 0.02, n=48, portata=0.2)
    u.oggetto("Benda", benda, "Benda", spessore=0.003)
    # Stivaletti allacciati (krepides): scarpa chiusa fin sopra la caviglia, lacci sullo stinco.
    V.calzature(u, "Calzari", "Stivali", "Suola", taglio=0.135, inclinazione=0.2)
    V.lacci_gamba(u, "Calzari_Lacci", "Lacci", [0.13, 0.2, 0.27, 0.34, 0.41], distacco=0.003, larghezza=0.011)
    u.nascondi_pelle()


def tracolle(u):
    # Tracolla dello scudo: spalla destra -> fianco sinistro (davanti e dietro).
    u.oggetto("Tracolla_Scudo", V.unisci(_cinghia(u, (-0.13, -0.07, 1.43), (0.16, -0.08, 0.96)),
                                          _cinghia(u, (-0.13, 0.07, 1.43), (0.16, 0.09, 0.96))), "Cuoio", spessore=0.003)
    # Balteo della spada: spalla sinistra -> fianco destro, solo davanti (dietro passa sotto la faretra).
    u.oggetto("Balteo", V.unisci(_cinghia(u, (0.13, -0.07, 1.43), (-0.16, -0.08, 0.96)),
                                  _cinghia(u, (0.13, 0.07, 1.43), (-0.16, 0.09, 0.96))), "CuoioChiaro", spessore=0.003)


def _cinghia(u, da, a, larghezza=0.034, distacco=0.024, passi=24):
    da, a = Vector(da), Vector(a)
    punti, normali = [], []
    for i in range(passi + 1):
        p = da.lerp(a, i / passi)
        d = Vector((p.x, p.y, 0)).normalized()
        punti.append(u.sulla_pelle(Vector((0, 0.0, p.z)), d, distacco, 0.35))
        normali.append(d)
    return V.striscia(punti, normali, larghezza)


# Arco ----------------------------------------------------------------------------------------------

def profilo_arco(s):
    """Arco teso: dall'impugnatura (s=0) alla punta (s=1); y verso l'arciere (+Y), le punte ricurve in avanti."""
    y = 0.15 * s ** 1.8 - 1.0 * max(0.0, s - 0.8) ** 2
    return y


def matrice_arco():
    return Matrix.Translation(IMPUGNATURA) @ Matrix.Rotation(math.radians(INCLINAZIONE_ARCO), 4, "X")


def arco(u):
    m = matrice_arco()
    flettenti, corna = [], []
    for segno in (1, -1):
        punti, raggi = [], []
        for i in range(25):
            s = i / 24
            punti.append(m @ Vector((0, profilo_arco(s), segno * s * META_ARCO)))
            raggi.append(0.0135 * (1 - s) + 0.0065 * s + (0.004 if s < 0.12 else 0.0))
        flettenti.append(V.tubo_lungo(punti, raggi, n=8))
        # Punte di corno (le orecchie dell'arco composito).
        punta = [m @ Vector((0, profilo_arco(s), segno * s * META_ARCO)) for s in (0.9, 0.95, 1.0)]
        punta.append(m @ Vector((0, profilo_arco(1.0) - 0.02, segno * (META_ARCO + 0.03))))
        corna.append(V.tubo_lungo(punta, [0.0075, 0.007, 0.0065, 0.004], n=8))
    u.oggetto("Arco_Legno", V.unisci(*flettenti), "Legno")
    u.oggetto("Arco_Corno", V.unisci(*corna), "Corno")
    # Impugnatura fasciata di cuoio.
    u.oggetto("Arco_Impugnatura", V.cilindro(m @ Vector((0, 0.002, -0.06)), m @ Vector((0, 0.002, 0.06)), 0.0185, n=12),
              "Cuoio")
    # Corda tra le punte.
    alto = m @ Vector((0, profilo_arco(1.0) - 0.005, META_ARCO - 0.005))
    basso = m @ Vector((0, profilo_arco(1.0) - 0.005, -META_ARCO + 0.005))
    u.oggetto("Arco_Corda", V.cilindro(basso, alto, 0.0022, n=6), "Corda")


# Faretra --------------------------------------------------------------------------------------------

def faretra(u):
    """Sulla schiena in diagonale: fondo al fianco sinistro, bocca sopra la spalla destra."""
    fondo = u.sulla_pelle(Vector((-0.01, 0.0, 0.95)), Vector((0.2, 1, 0)).normalized(), 0.085, 0.35)
    bocca = u.sulla_pelle(Vector((-0.06, 0.0, 1.44)), Vector((-0.35, 1, 0)).normalized(), 0.09, 0.35)
    asse = (bocca - fondo).normalized()
    bocca = bocca + asse * 0.05
    corpo = V.tubo_lungo([fondo, fondo.lerp(bocca, 0.5), bocca], [0.048, 0.055, 0.06], n=16)
    u.oggetto("Faretra_Corpo", corpo, "Cuoio")
    # Bordi e fasce di cuoio chiaro.
    fasce = []
    for t, l in ((0.02, 0.02), (0.35, 0.015), (0.7, 0.015), (0.985, 0.025)):
        c = fondo.lerp(bocca, t)
        r = 0.048 + (0.06 - 0.048) * t + 0.003
        fasce.append(V.cilindro(c - asse * l / 2, c + asse * l / 2, r, n=16, tappi=False))
    u.oggetto("Faretra_Fasce", V.unisci(*fasce), "CuoioChiaro", spessore=0.002)
    # Frecce che escono dalla bocca, a ventaglio.
    aste, piume = [], []
    base = asse.orthogonal().normalized()
    for j in range(9):
        a = 2 * math.pi * j / 9
        off = (Matrix.Rotation(a, 3, asse) @ base) * (0.028 if j else 0.0) * (1 if j % 2 else 0.6)
        inclina = (Matrix.Rotation(a, 3, asse) @ base) * 0.06
        p0 = bocca - asse * 0.25 + off
        p1 = bocca + asse * (0.14 + 0.025 * (j % 3)) + off + inclina * 0.4
        aste.append(V.cilindro(p0, p1, 0.0045, n=6))
        d = (p1 - p0).normalized()
        for k in range(3):
            lato = Matrix.Rotation(2 * math.pi * k / 3 + j, 3, d) @ d.orthogonal().normalized()
            q0 = p1 - d * 0.11
            pts = [q0 + lato * 0.004, p1 - d * 0.015 + lato * 0.004, p1 - d * 0.02 + lato * 0.018, q0 + d * 0.01 + lato * 0.014]
            bm = bmesh.new()
            vs = [bm.verts.new(p) for p in pts]
            bm.faces.new(vs)
            piume.append(bm)
    u.oggetto("Faretra_Frecce", V.unisci(*aste), "Legno")
    pm = V.unisci(*piume)
    u.oggetto("Faretra_Piume", pm, "Piume", spessore=0.0015)


# Scudo ----------------------------------------------------------------------------------------------

def immagine_labirinto(lato=512):
    """Bronzo con il labirinto quadrato di Cnosso inciso in scuro, e un bordo a puntini."""
    nome = SIGLA + "_Labirinto"
    vecchia = bpy.data.images.get(nome)
    if vecchia:
        bpy.data.images.remove(vecchia)
    img = bpy.data.images.new(nome, lato, lato, alpha=False)
    yy, xx = np.mgrid[0:lato, 0:lato]
    u = (xx + 0.5) / lato * 2 - 1
    v = (yy + 0.5) / lato * 2 - 1
    r = np.hypot(u, v)
    bronzo = np.array([0.80, 0.52, 0.24])
    scuro = np.array([0.16, 0.07, 0.03])
    rgb = np.ones((lato, lato, 3)) * bronzo
    # Leggera patina più chiara verso il centro (lucidato), più scura ai bordi.
    rgb *= (1.08 - 0.18 * r)[..., None]
    # Labirinto: meandro quadrato a spirale con le quattro "porte" (come sulle monete di Cnosso).
    linee = np.zeros((lato, lato), dtype=bool)
    lato_l = 0.52
    passo = lato_l / 4.5
    w = passo * 0.36
    au, av = np.abs(u), np.abs(v)
    m = np.maximum(au, av)
    for k in range(5):
        s = lato_l - k * passo
        anello = np.abs(m - s) < w / 2
        # Aperture alternate: un varco per lato, che ruota anello dopo anello.
        varco = np.zeros_like(anello)
        lati = [(v > 0) & (av >= au), (u > 0) & (au > av), (v < 0) & (av >= au), (u < 0) & (au > av)]
        quale = lati[k % 4]
        lungo = np.where((k % 2) == 0, u, v)
        varco = quale & (np.abs(lungo - (0.18 if k % 2 else -0.18)) < passo * 0.45)
        linee |= anello & ~varco
    # Croce centrale.
    linee |= (m < passo * 0.9) & ((au < w / 2) | (av < w / 2))
    rgb[linee] = scuro
    # Bordo: cerchio scuro e puntini sbalzati.
    rgb[np.abs(r - 0.9) < 0.012] = scuro
    angolo = np.arctan2(v, u)
    punti = (np.abs(r - 0.95) < 0.022) & (np.cos(angolo * 36) > 0.55)
    rgb[punti] = bronzo * 1.25
    rgba = np.concatenate([np.clip(rgb, 0, 1), np.ones((lato, lato, 1))], axis=2).astype(np.float32)
    img.pixels.foreach_set(rgba.ravel())
    img.pack()
    return img


def scudo(u):
    """Piccolo scudo tondo di bronzo appeso al fianco sinistro, il fronte verso l'esterno (+X)."""
    raggio = 0.21
    fianco = u.sulla_pelle(Vector((0.0, 0.04, 0.80)), Vector((1, 0, 0)), 0.0, 0.4)
    centro = Vector((fianco.x + 0.075, 0.14, 0.80))
    m = Matrix.Translation(centro) @ Matrix.Rotation(math.radians(-8), 4, "Y") @ Matrix.Rotation(math.radians(90), 4, "Z")
    fronte, retro, bordo = V.scudo_tondo(raggio, 0.045, spessore=0.012)
    for b in (fronte, retro, bordo):
        V.trasforma(b, m)
    u.oggetto("Scudo_Fronte", fronte, "Scudo")
    u.oggetto("Scudo_Retro", retro, "Cuoio")
    u.oggetto("Scudo_Bordo", bordo, "Bronzo")
    # Anello e cinghia di sospensione in cima.
    cima = m @ Vector((0, 0.01, raggio))
    u.oggetto("Scudo_Cinghia", V.tubo_lungo([cima, cima + Vector((-0.03, -0.02, 0.10)), Vector((0.16, -0.0, 0.97))],
                                            0.006, n=6), "Cuoio")


# Spada corta (xiphos) al fianco destro --------------------------------------------------------------

def spada(u):
    base = Matrix.Translation((-0.205, -0.03, 1.03)) @ Matrix.Rotation(math.radians(18), 4, "X") @ \
        Matrix.Rotation(math.radians(5), 4, "Y")
    fodero = bmesh.new()
    sezioni = [(0.0, 0.032), (-0.12, 0.034), (-0.30, 0.03), (-0.40, 0.016), (-0.43, 0.0)]
    anelli = []
    for z, mezza in sezioni:
        anelli.append([fodero.verts.new((mezza * math.cos(math.radians(a)) * 0.33, mezza * math.sin(math.radians(a)), z))
                       for a in range(0, 360, 30)])
    for a, b in zip(anelli, anelli[1:]):
        V.unisci_anelli(fodero, a, b)
    V.trasforma(fodero, base)
    u.oggetto("Spada_Fodero", fodero, "Cuoio")
    metallo = [V.cilindro((0, 0, -0.395), (0, 0, -0.44), 0.016, 0.003, n=10),
               V.scatola((0, 0, -0.02), (0.022, 0.07, 0.016))]
    for b in metallo:
        V.trasforma(b, base)
    u.oggetto("Spada_Puntali", V.unisci(*metallo), "Bronzo")
    elsa = [V.scatola((0, 0, 0.012), (0.02, 0.085, 0.016)),
            V.cilindro((0, 0, 0.02), (0, 0, 0.105), 0.013, 0.015, n=10),
            V.sfera((0, 0, 0.115), (0.02, 0.022, 0.014), 10, 6)]
    for b in elsa:
        V.trasforma(b, base)
    u.oggetto("Spada_Elsa", V.unisci(*elsa), "Bronzo")


# Tutto ---------------------------------------------------------------------------------------------

def costruisci():
    global U
    u = V.Unita(NOME, SIGLA)
    U = u
    materiali(u)
    u.costruisci_corpo(posa, barba=0.85)
    vestiti(u)
    tracolle(u)
    arco(u)
    faretra(u)
    scudo(u)
    spada(u)
    triangoli = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in u.col.objects if o.type == "MESH")
    return {"oggetti": len(u.col.objects), "triangoli": triangoli}


def esporta(triangoli=4200, lato=512):
    """Versione da gioco (dopo costruisci())."""
    import esporta as E
    r = E.prepara(NOME, U.giunti,
                  rigidi={"Arco_*": "arco", "Scudo_*": "bacino", "Spada_*": "bacino", "Faretra_*": "torace",
                          "Occhio*": "testa", "Benda": "testa"},
                  escludi=["Calzari_Lacci", "Faretra_Fasce", "Tunica_Orlo"],
                  togli_dal_corpo=[SIGLA + "_Nascosta"], triangoli=triangoli, corpo=U.corpo.name,
                  extra={"arco": ("mano.L", IMPUGNATURA)})
    E.cuoci(lato=lato)
    return r
