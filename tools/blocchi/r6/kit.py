"""Pezzi in comune delle truppe R6 (vedi r6.py): vestiti con spessore, elmi e cappelli, armi, scudi, il cavallo.

Coordinate come in Roblox (X destra del soldato, Y su, il davanti è -Z), in metri.
Gli strati sopra il busto: T1 per i vestiti, T2 per le armature, le cinghie appena sopra.
I colori si passano come "#RRGGBB" (stoffa), come (colore, tipo) o come materiale già fatto.
"""
import json
import math
import os

import bmesh
import bpy
import numpy as np

import r6
from r6 import (ARTO, BUSTO_A, BUSTO_L, BUSTO_P, COLLO, GAMBE, MANO, PELLI, S, TESTA_D, TESTA_H, TESTA_Y,
                X_BRACCIO, X_GAMBA, Modello, anello, braccio, busto, disegno, gamba, mat, norm, testa)

QUI = os.path.dirname(os.path.abspath(__file__))
RADICE = os.path.dirname(os.path.dirname(os.path.dirname(QUI)))

H = [("testa", 1.0)]
B = [("torace", 0.75), ("spina", 0.25)]
BAC = [("bacino", 1.0)]
LATI = (("L", -1), ("R", 1))
MANO_CENTRO = 0.2 * S  # dal polso al centro del pugno
GIRO = TESTA_Y + 0.27 * S  # bordo degli elmi: sopra le sopracciglia, la faccia resta libera
R_TESTA = TESTA_D / 2
R_ELMO = R_TESTA + 0.022
T1 = 0.016
T2 = 0.034

LEGNO = "#80562F"
FERRO = "#A4ACB6"
FERRO_SCURO = "#6C747E"
ACCIAIO = "#B8BEC6"
OTTONE = "#D2A548"
ORO = "#D8B048"
BRONZO = "#B8843C"
CUOIO = "#6E4A2C"
CUOIO_SCURO = "#4A3020"
NERO = "#1E1C1A"
BIANCO = "#ECE8DC"

# Assi già pronti (colonne = dove vanno x, y, z locali).
ASSE_Z = np.column_stack([[1.0, 0, 0], [0, 0, -1.0], [0, 1.0, 0]])  # cilindri con l'asse verso il davanti
ASSE_X = np.column_stack([[0, 1.0, 0], [1.0, 0, 0], [0, 0, -1.0]])  # cilindri di traverso


def M(x, tipo="stoffa"):
    """Materiale da "#colore" (del tipo dato), da (colore, tipo) o già fatto."""
    if x is None or isinstance(x, bpy.types.Material):
        return x
    if isinstance(x, tuple):
        return mat(*x)
    return mat(x, tipo)


def rot_y(a):
    return np.array([[math.cos(a), 0, math.sin(a)], [0, 1, 0], [-math.sin(a), 0, math.cos(a)]])


def rot_x(a):
    return np.array([[1, 0, 0], [0, math.cos(a), -math.sin(a)], [0, math.sin(a), math.cos(a)]])


def rot_z(a):
    return np.array([[math.cos(a), -math.sin(a), 0], [math.sin(a), math.cos(a), 0], [0, 0, 1]])


def assi_lungo(direzione, alto=(1.0, 0, 0)):
    """Assi con la y lungo "direzione" e la x verso "alto" (come Modello.segmento)."""
    y = norm(direzione)
    r = np.asarray(alto, float)
    x = r - y * r.dot(y)
    if np.linalg.norm(x) < 1e-5:
        x = np.array([0, 0, 1.0]) - y * y[2]
    x = norm(x)
    return np.column_stack([x, y, np.cross(x, y)])


def tubo(m, nome, da, a, raggio, materiale, pesi, lati=8, raggio_fine=None, smusso=0.0):
    """Cilindro da "da" (raggio) ad "a" (raggio_fine): aste, canne, rotoli."""
    da, a = np.asarray(da, float), np.asarray(a, float)
    return m.cilindro(nome, (da + a) / 2, raggio if raggio_fine is None else raggio_fine, np.linalg.norm(a - da),
                      M(materiale), pesi, lati=lati, assi=assi_lungo(a - da), raggio_sotto=raggio, smusso=smusso,
                      segmenti=1)


def pugno(m, lato):
    """Centro del pugno e direzione dell'avambraccio."""
    gomito, polso = m.P("avambraccio." + lato), m.P("mano." + lato)
    d = norm(polso - gomito)
    return polso + d * MANO_CENTRO, d


def anello_tondo(m, nome, centro, raggio, spessore, larghezza, materiale, pesi, assi=None, lati=24):
    """Cerchio pieno (bordo degli scudi tondi, fasce): asse lungo Y locale."""
    ri, ro, h = raggio - larghezza / 2, raggio + larghezza / 2, spessore / 2
    bm = r6.tornio([(ri, -h), (ro, -h), (ro, h), (ri, h), (ri, -h + 1e-4)], lati)
    for f in bm.faces:
        f.smooth = True
    return m._oggetto(nome, bm, [M(materiale)], pesi, assi, centro)


def fascia_arco(m, nome, y0, y1, raggio, a0, a1, spessore, materiale, pesi, lati=8, rastrema=1.0, z=0.0):
    """Pezzo di tubo attorno alla testa tra gli angoli a0 e a1 (gradi; 0 = davanti, positivi verso la destra
    del soldato, +X), da y0 a y1: paraguance, frontali, nuche. rastrema: raggio in basso / raggio in alto."""
    bm = bmesh.new()
    anelli = []
    for i in range(lati + 1):
        a = math.radians(a0 + (a1 - a0) * i / lati)
        dx, dz = math.sin(a), -math.cos(a)
        q = []
        for r, y in ((raggio * rastrema, y0), (raggio, y1)):
            for rr in (r, r + spessore):
                q.append(bm.verts.new((dx * rr, y, dz * rr + z)))
        anelli.append(q)  # [interno basso, esterno basso, interno alto, esterno alto]
    for a, b in zip(anelli, anelli[1:]):
        for i, j in ((0, 1), (1, 3), (3, 2), (2, 0)):
            bm.faces.new((a[i], b[i], b[j], a[j]))
    bm.faces.new((anelli[0][0], anelli[0][1], anelli[0][3], anelli[0][2]))
    bm.faces.new((anelli[-1][2], anelli[-1][3], anelli[-1][1], anelli[-1][0]))
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    for f in bm.faces:
        f.smooth = abs(f.normal.y) < 0.5
    return m._oggetto(nome, bm, [M(materiale)], pesi, None, (0, 0, 0))


def sagoma(m, nome, centro, punti, spessore, materiale, pesi, fronte=None, assi=None):
    """Lastra con il contorno "punti" [(x, y)] (locali), spessa "spessore" lungo Z; il davanti (-Z) può essere
    dipinto (fronte) con la proiezione sul riquadro del contorno."""
    p = np.asarray(punti, float)
    cx, cy = (p[:, 0].min() + p[:, 0].max()) / 2, (p[:, 1].min() + p[:, 1].max()) / 2
    lw, lh = p[:, 0].max() - p[:, 0].min(), p[:, 1].max() - p[:, 1].min()
    bm = bmesh.new()
    davanti = [bm.verts.new((x - cx, y - cy, -spessore / 2)) for x, y in p]
    dietro = [bm.verts.new((x - cx, y - cy, spessore / 2)) for x, y in p]
    bm.faces.new(davanti)
    bm.faces.new(dietro[::-1])
    n = len(p)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((davanti[i], davanti[j], dietro[j], dietro[i]))
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    materiali = [M(materiale)]
    if fronte is not None:
        materiali.append(fronte)
        for f in bm.faces:
            if f.normal.z < -0.5:
                f.material_index = 1
    c = np.asarray(centro, float)
    a = np.eye(3) if assi is None else np.asarray(assi, float)
    return m._oggetto(nome, bm, materiali, pesi, a, c + a @ np.array([cx, cy, 0.0]), uv_piano=(lw, lh))


def dipinto(m, nome, pittore, sotto, tipo="stoffa"):
    return disegno(m.cartella, m.nome + "_" + nome, pittore, sotto, tipo)


# -- Soldato --------------------------------------------------------------------------------------------

def fante(nome, faccia, cartella, pelle=PELLI[0], mano_r=(0, 0.05, -1), mano_l=(0.25, 0.1, -1), posa="piedi"):
    """Soldato con lo scheletro e la testa. posa: "piedi" o "ginocchio" (mitraglieri)."""
    m = Modello(nome)
    m.cartella, m.pelle, m.faccia, m.posa = cartella, pelle, faccia, posa
    if posa == "ginocchio":
        dy = GAMBE * 0.62 - GAMBE
        m.trasforma = lambda p, dy=dy: np.asarray(p, float) + np.array([0, dy, 0])
        r6.scheletro(m, mano_r, mano_l)
        # Le due ginocchia a terra, gli stinchi indietro (posizioni prima dello spostamento in giù).
        for lato, s in LATI:
            m.osso("stinco." + lato, "coscia." + lato, (s * X_GAMBA, 0.1 - dy, -0.06))
            m.osso("piede." + lato, "stinco." + lato, (s * X_GAMBA, 0.08 - dy, 0.36))
    else:
        r6.scheletro(m, mano_r, mano_l)
    testa(m, pelle, faccia)
    return m


def finale(m, p):
    """Dove va il punto p dopo lo spostamento della posa (in ginocchio, in sella)."""
    return m.trasforma(p) if m.trasforma else np.asarray(p, float)


class senza_posa:
    """Pezzi costruiti nelle coordinate finali (cose a terra, il cavallo)."""

    def __init__(self, m):
        self.m = m

    def __enter__(self):
        self.t, self.m.trasforma = self.m.trasforma, None

    def __exit__(self, *a):
        self.m.trasforma = self.t


def vesti(m, busto_m, manica=None, manica_fino=None, avambraccio=None, mano=None, coscia=None, stinco=None,
          taglio=None):
    """Il corpo a blocchi: busto, braccia (manica fino a "manica_fino" sotto la spalla), gambe."""
    P = mat(m.pelle, "pelle")
    busto(m, M(busto_m))
    for lato, _ in LATI:
        braccio(m, lato, M(manica) or P, P, manica_fino, M(avambraccio), M(mano))
    if m.posa == "piedi":
        for lato, _ in LATI:
            gamba(m, lato, M(coscia) or P, M(stinco) or P, taglio)
    else:
        gambe_piegate(m, M(coscia) or P, M(stinco) or P)


def gambe_piegate(m, sopra, sotto):
    """Gambe a blocchi lungo le ossa (in ginocchio, in sella)."""
    for lato, s in LATI:
        anca, gin, cav = m.P("coscia." + lato), m.P("stinco." + lato), m.P("piede." + lato)
        m.segmento("coscia." + lato, anca + np.array([0, 0.25 * S, 0]), gin, ARTO, ARTO, sopra,
                   [("coscia." + lato, 1.0)], oltre=(0, ARTO / 2), alto=(1, 0, 0))
        d = norm(cav - gin)
        m.segmento("stinco." + lato, gin, cav + d * 0.07, ARTO * 0.99, ARTO * 0.99, sotto,
                   [("stinco." + lato, 1.0)], oltre=(ARTO / 2 - 0.004, 0), alto=(1, 0, 0))


def _stinco(m, lato):
    """Ginocchio, fondo del piede e direzione dello stinco (verso il basso)."""
    gin, cav = m.P("stinco." + lato), m.P("piede." + lato)
    if m.posa == "piedi":
        x = gin[0]
        return np.array([x, GAMBE * 0.5, 0]), np.array([x, 0.0, 0]), np.array([0, -1.0, 0])
    d = norm(cav - gin)
    return gin, cav + d * 0.07, d


# -- Vestiti -------------------------------------------------------------------------------------------

def strato(m, nome, alto, basso, materiale, t=T1, pesi=None, smusso=0.005, rastrema=None):
    """Fascia attorno al busto (giubbe, tuniche, corazze) da "alto" a "basso", spessa t."""
    return anello(m, nome, (0, (alto + basso) / 2, 0), (BUSTO_L, alto - basso, BUSTO_P), t, M(materiale),
                  pesi or B, smusso=smusso, rastrema=rastrema)


def gonna(m, materiale, basso=GAMBE - 0.6 * S, alto=GAMBE + 0.02 * S, t=0.02, svasa=(1.1, 1.18), orlo=None,
          segue=0.6, nome="gonna"):
    """Gonna, falde o tunica sotto la cintura: due metà, ognuna segue la sua coscia in fondo."""
    for lato, s in LATI:
        def pesi(p, mondo, lato=lato):
            f = np.clip((alto - mondo[1]) / (alto - basso), 0, 1) * segue
            return [("bacino", 1 - f), ("coscia." + lato, f)] if f > 0 else [("bacino", 1.0)]
        m.scatola(f"{nome}{lato}", (s * BUSTO_L / 4, (alto + basso) / 2, 0), (BUSTO_L / 2 + t, alto - basso,
                  BUSTO_P + 2 * t), M(materiale), pesi, smusso=0.006, rastrema=svasa)
        if orlo:
            m.scatola(f"orlo_{nome}{lato}", (s * (BUSTO_L / 4 + 0.012), basso + 0.04 * S, 0),
                      (BUSTO_L / 2 + t + 0.03, 0.08 * S, (BUSTO_P + 2 * t) * svasa[1] + 0.02), M(orlo),
                      [("bacino", 1 - segue), ("coscia." + lato, segue)], smusso=0.004)


def cintura(m, materiale, y=GAMBE + 0.06 * S, alta=0.17 * S, t=T2 + 0.006, fibbia=None, pesi=None):
    anello(m, "cintura", (0, y, 0), (BUSTO_L, alta, BUSTO_P), t, M(materiale, "cuoio"), pesi or BAC)
    if fibbia:
        m.scatola("fibbia", (0, y, -(BUSTO_P / 2 + t + 0.006)), (0.32 * S, alta * 1.15, 0.016), M(fibbia, "ottone"),
                  pesi or BAC, smusso=0.004)


def fascia_vita(m, materiale, y=GAMBE + 0.1 * S, alta=0.3 * S, t=T1 + 0.012, nodo=True):
    """Fascia di stoffa avvolta in vita (sash), col nodo e i lembi che pendono sul fianco."""
    anello(m, "fascia_vita", (0, y, 0), (BUSTO_L, alta, BUSTO_P), t, M(materiale), BAC, smusso=0.01)
    if nodo:
        x = -0.6 * S
        m.scatola("nodo_fascia", (x, y, -(BUSTO_P / 2 + t + 0.01)), (0.3 * S, alta * 0.9, 0.03), M(materiale), BAC,
                  smusso=0.01)
        for k, dx in enumerate((-0.06, 0.05)):
            m.scatola(f"lembo{k}", (x + dx, y - 0.32 * S, -(BUSTO_P / 2 + t + 0.004)), (0.16 * S, 0.55 * S, 0.016),
                      M(materiale), BAC, smusso=0.005, rastrema=(1.3, 1.0))


def bandoliera(m, materiale, spalla="L", t=T1 + 0.01, larga=0.24 * S, spessa=0.012, fronte=True, retro=True,
               nome="bandoliera", basso=GAMBE + 0.02 * S):
    """Cinghia di traverso dalla spalla al fianco opposto, davanti e dietro, sopra la spalla."""
    s = -1 if spalla == "L" else 1
    for z, si in ((-1, fronte), (1, retro)):
        if not si:
            continue
        zz = z * (BUSTO_P / 2 + t)
        m.segmento(f"{nome}{z}", (s * 0.62 * S, COLLO + 0.02, zz), (-s * 0.9 * S, basso, zz), larga, spessa,
                   M(materiale, "cuoio"), B, alto=(1, 0, 0), smusso=0.004)
    m.scatola(f"{nome}_spalla", (s * 0.62 * S, COLLO + t / 2, 0), (larga, t, BUSTO_P + 2 * t), M(materiale, "cuoio"),
              B, smusso=0.004)


def bottoni(m, materiale, ys, x=0.0, t=T1, r=0.045 * S, nome="bottone"):
    for i, y in enumerate(ys):
        m.cilindro(f"{nome}{i}", (x, y, -(BUSTO_P / 2 + t + 0.006)), r, 0.012, M(materiale, "ottone"), B, lati=8,
                   assi=ASSE_Z)


def colletto(m, materiale, alto=0.16 * S, t=0.014, smusso=0.01):
    m.cilindro("colletto", (0, COLLO + alto / 2 - 0.01, 0), R_TESTA + t, alto, M(materiale), [("torace", 1.0)],
               lati=16, smusso=smusso, segmenti=1)


def sciarpa(m, materiale, nodo=True):
    colletto(m, M(materiale, "lana"), alto=0.16 * S, t=0.014, smusso=0.02)
    if nodo:
        m.scatola("nodo_sciarpa", (0.12 * S, COLLO - 0.04 * S, -(R_TESTA + 0.006)), (0.14 * S, 0.24 * S, 0.04),
                  M(materiale, "lana"), [("torace", 1.0)], smusso=0.012, segmenti=1)


def mantello(m, materiale, basso=GAMBE * 0.3, bordo=None, t=0.024, largo=BUSTO_L + 0.05, spilla=ORO, pieghe=3):
    """Mantello dietro le spalle, fermato da una spilla sulla spalla destra, con le pieghe in rilievo."""
    mm = M(materiale)
    z = BUSTO_P / 2 + t / 2 + 0.012
    alto = COLLO + 0.01

    def pesi(p, mondo):
        if mondo[1] >= GAMBE:
            return B
        f = np.clip((GAMBE - mondo[1]) / (GAMBE - basso + 1e-6), 0, 1)
        return [("spina", 0.5 - 0.3 * f), ("bacino", 0.5 + 0.3 * f)]
    m.scatola("mantello", (0, (alto + basso) / 2, z), (largo, alto - basso, t), mm, pesi, smusso=0.006,
              rastrema=(1.18, 1.0))
    m.scatola("mantello_spalle", (0, COLLO + t / 2, BUSTO_P / 4 + 0.006), (largo, t, BUSTO_P / 2 + 0.03), mm, B,
              smusso=0.006)
    for x in (-1, 1):  # i lembi che girano sopra le spalle fin davanti
        m.scatola(f"mantello_lembo{x}", (x * 0.72 * S, COLLO - 0.12 * S, -(BUSTO_P / 2 + t / 2 + 0.004)),
                  (0.42 * S, 0.3 * S, t * 0.7), mm, B, smusso=0.005)
    for i in range(pieghe):
        x = (i - (pieghe - 1) / 2) * largo / (pieghe + 0.6)
        m.cilindro(f"piega{i}", (x, (COLLO - 0.25 * S + basso) / 2, z + t / 2), 0.028,
                   COLLO - 0.25 * S - basso, mm, pesi, lati=8, parte="retro")
    if bordo:
        m.scatola("bordo_mantello", (0, basso + 0.03, z + 0.004), (largo * 1.18 + 0.006, 0.06, t + 0.008), M(bordo),
                  pesi, smusso=0.004)
    if spilla:
        m.cilindro("spilla", (0.72 * S, COLLO - 0.1 * S, -(BUSTO_P / 2 + t + 0.01)), 0.035, 0.018,
                   M(spilla, "ottone"), B, lati=10, assi=ASSE_Z)


def manica(m, lato, materiale, da=0.0, a=1.1 * S, t=0.012, nome="manica", smusso=0.004):
    """Fascia attorno all'omero, da "da" ad "a" sotto la cima della spalla."""
    s = -1 if lato == "L" else 1
    return anello(m, f"{nome}{lato}", (s * X_BRACCIO, COLLO - (da + a) / 2, 0), (ARTO, a - da, ARTO), t, M(materiale),
                  [("braccio." + lato, 1.0)], smusso=smusso)


def polsino(m, lato, materiale, da=0.0, a=0.3 * S, t=0.012, nome="polsino"):
    """Fascia attorno all'avambraccio, da "da" ad "a" prima del polso."""
    gomito, polso = m.P("avambraccio." + lato), m.P("mano." + lato)
    d = norm(polso - gomito)
    return m.segmento(f"{nome}{lato}", polso - d * a, polso - d * da, ARTO + 2 * t, ARTO + 2 * t, M(materiale),
                      [("avambraccio." + lato, 1.0)], smusso=0.004)


def guanto(m, lato, materiale, risvolto=True):
    gomito, polso = m.P("avambraccio." + lato), m.P("mano." + lato)
    d = norm(polso - gomito)
    m.segmento(f"guanto{lato}", polso - d * 0.01, polso + d * (MANO + 0.006), ARTO + 0.014, ARTO + 0.014,
               M(materiale, "cuoio"), [("mano." + lato, 1.0)], smusso=0.005)
    if risvolto:
        m.segmento(f"risvolto{lato}", polso - d * 0.24 * S, polso + d * 0.02, ARTO + 0.04, ARTO + 0.04,
                   M(materiale, "cuoio"), [("avambraccio." + lato, 1.0)], smusso=0.006)


def spallacci(m, materiale, n=3, t=0.024, passo=0.24 * S):
    """Lamine a gradini sopra le spalle (si muovono col braccio)."""
    for lato, s in LATI:
        for k in range(n):
            sp = t + 0.005 * k
            m.scatola(f"spallaccio{lato}{k}", (s * (X_BRACCIO + 0.006 * k), COLLO + 0.024 - 0.13 * S - k * passo, 0),
                      (ARTO + 2 * sp, 0.26 * S, ARTO + 2 * sp), M(materiale, "ferro"), [("braccio." + lato, 1.0)],
                      smusso=0.006)


def spalline(m, materiale, frange=None):
    """Spalline da uniforme sopra le spalle, con la frangia."""
    for lato, s in LATI:
        m.scatola(f"spallina{lato}", (s * (X_BRACCIO - 0.1 * S), COLLO + 0.012, 0), (0.75 * S, 0.03, 0.62 * S),
                  M(materiale), [("braccio." + lato, 0.5), ("torace", 0.5)], smusso=0.008)
        if frange:
            m.scatola(f"frangia{lato}", (s * (X_BRACCIO + 0.3 * S), COLLO - 0.06 * S, 0), (0.06, 0.16 * S, 0.6 * S),
                      M(frange, "crine"), [("braccio." + lato, 1.0)])


def stivale(m, lato, materiale, alto=0.9 * S, t=0.014, risvolto=None, suola=CUOIO_SCURO, nome="stivale"):
    """Stivale attorno allo stinco, dal piede in su, con la suola e il risvolto."""
    gin, fondo, d = _stinco(m, lato)
    su = -d
    W = [("stinco." + lato, 1.0)]
    m.segmento(f"{nome}{lato}", fondo, fondo + su * alto, ARTO + 2 * t, ARTO + 2 * t, M(materiale, "cuoio"), W,
               alto=(1, 0, 0), smusso=0.005)
    if suola:
        avanti = np.array([0, 0, -1.0]) if m.posa == "piedi" else norm(np.cross(np.array([1.0, 0, 0]), d))
        m.segmento(f"suola{lato}", fondo - su * 0.0, fondo + su * 0.035, ARTO + 2 * t + 0.01, ARTO + 2 * t + 0.05,
                   M(suola, "cuoio"), W, alto=(1, 0, 0), smusso=0.006)
    if risvolto:
        m.segmento(f"risvolto{lato}", fondo + su * (alto - 0.12 * S), fondo + su * (alto + 0.04 * S), ARTO + 2 * t + 0.016,
                   ARTO + 2 * t + 0.016, M(risvolto, "cuoio"), W, alto=(1, 0, 0), smusso=0.005)


def fasce(m, lato, materiale, alto=0.8 * S, t=0.01):
    """Mollettiere: giri di fascia sovrapposti, un po' inclinati."""
    gin, fondo, d = _stinco(m, lato)
    su = -d
    n = 5
    # Sotto, la fascia continua (niente fessure scure tra un giro e l'altro); sopra, i giri appena inclinati.
    m.scatola(f"fascia{lato}_sotto", fondo + su * (0.06 * S + alto / 2), (ARTO + t, alto - 0.12 * S, ARTO + t),
              M(materiale, "lana"), [("stinco." + lato, 1.0)], assi=assi_lungo(su))
    for k in range(n):
        c = fondo + su * (0.12 * S + (k + 0.5) * (alto - 0.12 * S) / n)
        a = rot_x(0.05 * (1 if k % 2 else -1))
        m.scatola(f"fascia{lato}{k}", c, (ARTO + 2 * t, (alto - 0.12 * S) / n + 0.006, ARTO + 2 * t),
                  M(materiale, "lana"), [("stinco." + lato, 1.0)], assi=assi_lungo(su) @ a, smusso=0.004)


def calzari(m, lato, materiale):
    """Sandali chiusi: suola, lacci sopra il piede e attorno alla caviglia."""
    gin, fondo, d = _stinco(m, lato)
    su = -d
    W = [("stinco." + lato, 1.0)]
    mm = M(materiale, "cuoio")
    m.segmento(f"suola{lato}", fondo, fondo + su * 0.03, ARTO + 0.03, ARTO + 0.08, mm, W, alto=(1, 0, 0), smusso=0.006)
    for k, h in enumerate((0.12 * S, 0.35 * S, 0.55 * S)):
        m.segmento(f"laccio{lato}{k}", fondo + su * (h - 0.03 * S), fondo + su * (h + 0.03 * S), ARTO + 0.014,
                   ARTO + 0.014, mm, W, alto=(1, 0, 0))


def schinieri(m, materiale):
    for lato, _ in LATI:
        gin, fondo, d = _stinco(m, lato)
        su = -d
        avanti = norm(np.cross(np.array([1.0, 0, 0]), su))
        c = fondo + su * (0.5 * (np.linalg.norm(gin - fondo) + 0.08 * S)) + avanti * (ARTO / 2 + 0.01)
        m.scatola(f"schiniere{lato}", c, (ARTO + 0.02, np.linalg.norm(gin - fondo) - 0.1 * S, 0.022),
                  M(materiale, "ottone"), [("stinco." + lato, 1.0)], assi=assi_lungo(su, (1, 0, 0)), smusso=0.008)


def pantaloni_larghi(m, materiale, basso=0.3 * S, t=0.02):
    """Calzoni ampi (alla turca): fascia larga attorno a ogni coscia e stinco fino a "basso"."""
    for lato, s in LATI:
        x = s * X_GAMBA
        anello(m, f"calzone{lato}", (x, (GAMBE + basso) / 2 + 0.1 * S, 0), (ARTO, GAMBE - basso - 0.2 * S, ARTO), t,
               M(materiale), [("coscia." + lato, 0.6), ("stinco." + lato, 0.4)], smusso=0.01, rastrema=(0.9, 0.9))


# -- Armature ----------------------------------------------------------------------------------------------

def corazza(m, materiale, alto=COLLO, basso=GAMBE + 0.12 * S, t=T2, muscoli=False, spalle=True, nome="corazza"):
    mm = M(materiale, "ferro")
    strato(m, nome, alto, basso, mm, t, smusso=0.008)
    if spalle:
        m.scatola(f"{nome}_spalle", (0, COLLO + t / 2, 0), (BUSTO_L + 2 * t, t, BUSTO_P + 2 * t), mm, B, smusso=0.008)
    if muscoli:
        z = -(BUSTO_P / 2 + t)
        for x in (-1, 1):
            m.sfera(f"pettorale{x}", (x * 0.42 * S, COLLO - 0.5 * S, z), 0.36 * S, mm, B, anelli=5, lati=10,
                    schiaccia=(1.0, 0.62, 0.22))
        for k in range(3):
            for x in (-1, 1):
                m.sfera(f"addome{k}{x}", (x * 0.2 * S, COLLO - 1.0 * S - k * 0.24 * S, z), 0.15 * S, mm, B, anelli=4,
                        lati=8, schiaccia=(1.0, 0.75, 0.25))


def cotta(m, materiale="#8A9098", basso=GAMBE - 0.85 * S, maniche="intere", t=T1, cappuccio=False):
    """Usbergo di maglia: busto, gonna spaccata fino al ginocchio, maniche."""
    mm = M(materiale, "maglia")
    strato(m, "cotta", COLLO, GAMBE - 0.02, mm, t)
    gonna(m, mm, basso=basso, alto=GAMBE + 0.04 * S, t=t + 0.004, svasa=(1.08, 1.12), nome="cotta_gonna")
    if maniche:
        for lato, _ in LATI:
            manica(m, lato, mm, a=1.3 * S, t=0.012, nome="manica_maglia")
            if maniche == "intere":
                polsino(m, lato, mm, da=0.02, a=0.62 * S, t=0.01, nome="maglia_avambraccio")
    if cappuccio:
        camaglio(m, mm)


def camaglio(m, materiale, basso=TESTA_Y - 0.62 * S):
    """Cappuccio di maglia sotto l'elmo: copre nuca e collo, la faccia resta libera."""
    mm = M(materiale, "maglia")
    m.cilindro("camaglio", (0, (GIRO + basso) / 2, 0), R_TESTA + 0.012, GIRO - basso, mm, H, lati=18, parte="retro")
    m.cilindro("camaglio_collo", (0, COLLO + 0.05 * S, 0), R_TESTA + 0.02, 0.2 * S, mm, [("torace", 1.0)], lati=16,
               smusso=0.02, segmenti=1)
    for x in (-1, 1):
        m.scatola(f"camaglio_guancia{x}", (x * (R_TESTA + 0.008), TESTA_Y - 0.15 * S, -0.02),
                  (0.02, GIRO - TESTA_Y + 0.6 * S, 0.5 * S), mm, H, smusso=0.006)


def lamelle(m, materiale, file=5, alto=COLLO - 0.15 * S, basso=GAMBE - 0.3 * S, t=T2, nome="lamelle"):
    """Corazza a lamelle o a squame: file sovrapposte, ognuna un poco più larga di quella sopra."""
    mm = M(materiale, "squame")
    h = (alto - basso) / file
    for i in range(file):
        y = alto - (i + 0.5) * h
        pesi = B if y > GAMBE else BAC
        anello(m, f"{nome}{i}", (0, y, 0), (BUSTO_L, h + 0.012, BUSTO_P), t + i * 0.004, mm, pesi, smusso=0.005,
               rastrema=(1.01, 1.03))
    m.scatola(f"{nome}_spalle", (0, COLLO + t / 2, 0), (BUSTO_L + 2 * t, t, BUSTO_P + 2 * t), mm, B, smusso=0.006)


def pteruges(m, materiale, y=GAMBE - 0.02 * S, n=10, lungo=0.55 * S, t=T2 + 0.012, retro=True, larghi=0.17 * S):
    """Strisce di cuoio che pendono dalla vita (davanti, ai lati e dietro)."""
    mm = M(materiale, "cuoio")
    for lato, s in LATI:
        def pesi(p, mondo, lato=lato):
            f = np.clip((y - mondo[1]) / lungo, 0, 1) * 0.5
            return [("bacino", 1 - f), ("coscia." + lato, f)]
        for i in range(n // 2):
            x = s * (i + 0.5) * BUSTO_L / n
            for z in ((-1, 1) if retro else (-1,)):
                m.scatola(f"pterugia{lato}{i}{z}", (x, y - lungo / 2, z * (BUSTO_P / 2 + t)), (larghi, lungo, 0.016),
                          mm, pesi, smusso=0.004)
        m.scatola(f"pterugia_lato{lato}", (s * (BUSTO_L / 2 + t), y - lungo / 2, 0), (0.016, lungo, BUSTO_P * 0.8),
                  mm, pesi, smusso=0.004)


def sopravveste(m, colore, pittore=None, retro=True, basso=GAMBE - 0.8 * S, t=T2 + 0.006, tipo="stoffa", nome="sopravveste"):
    """Sopravveste senza maniche sopra l'armatura, col disegno dipinto davanti (e dietro)."""
    mm = M(colore, tipo)
    fronte = dipinto(m, nome, pittore, colore, tipo) if pittore else None
    # La cima sale di mezzo spessore: sullo stesso piano del busto diventerebbe nera nel bake.
    m.scatola(nome, (0, (COLLO + GAMBE) / 2 + t / 4, 0), (BUSTO_L + 2 * t, BUSTO_A + t / 2, BUSTO_P + 2 * t), mm, B,
              smusso=0.006, fronte=fronte, uv=fronte is not None)
    if pittore and retro:
        m.scatola(nome + "_retro", (0, (COLLO + GAMBE) / 2, BUSTO_P / 2 + t + 0.002), (BUSTO_L + 2 * t - 0.01,
                  BUSTO_A - 0.01, 0.004), mm, B, fronte=fronte, uv=True, assi=rot_y(math.pi))
    gonna(m, mm, basso=basso, alto=GAMBE + 0.02 * S, t=t, svasa=(1.08, 1.14), nome=nome + "_gonna")


def pannello(m, nome, centro, larghezza, altezza, pittore, sotto, pesi, tipo="stoffa", spessore=0.006, retro=False):
    """Toppa sottile con il disegno (stemmi, croci, insegne)."""
    fronte = dipinto(m, nome, pittore, sotto, tipo)
    return m.scatola(nome, centro, (larghezza, altezza, spessore), M(sotto, tipo), pesi, fronte=fronte, uv=True,
                     assi=rot_y(math.pi) if retro else None)


# -- Teste: capelli, barbe, elmi, cappelli ---------------------------------------------------------------

def capelli(m, colore, lunghi=0.0, frangia=False, sopra=True, basso=None):
    """Capelli a calotta (come gli accessori di Roblox): sopra, dietro fino alla nuca (o più giù se lunghi)."""
    c = M(colore, "crine")
    r = R_TESTA + 0.012
    if sopra:
        m.cupola("capelli", (0, TESTA_Y + 0.3 * S, 0), r, 0.36 * S, c, H, anelli=4, lati=18)
    fondo = (TESTA_Y - 0.4 * S if basso is None else basso) - lunghi
    m.cilindro("capelli_dietro", (0, (TESTA_Y + 0.32 * S + fondo) / 2, 0), r, TESTA_Y + 0.32 * S - fondo, c, H,
               lati=18, parte="retro")
    for x in (-1, 1):  # basette
        m.scatola(f"basetta{x}", (x * (R_TESTA + 0.004), TESTA_Y + 0.14 * S, -0.05 * S), (0.018, 0.36 * S, 0.3 * S), c,
                  H)
    if frangia:
        m.cilindro("frangia", (0, TESTA_Y + 0.33 * S, 0), r + 0.004, 0.1 * S, c, H, lati=18, parte="fronte")


def barba(m, colore, baffi=True, piena=True, lunga=0.0, pizzo=False):
    """Barba a blocco sulla mascella (sotto la bocca), baffi sopra la bocca."""
    c = M(colore, "crine")
    if piena:
        # Sul davanti e sui lati della mascella (dietro resta la nuca), basette fino alle orecchie.
        fascia_arco(m, "barba", TESTA_Y - 0.6 * S - lunga, TESTA_Y - 0.27 * S, R_TESTA - 0.004, -100, 100, 0.026, c, H,
                    lati=12, rastrema=0.9 if lunga else 1.0)
        for x in (-1, 1):
            fascia_arco(m, f"basetta_barba{x}", TESTA_Y - 0.3 * S, TESTA_Y + 0.12 * S, R_TESTA - 0.004, x * 62, x * 100,
                        0.02, c, H, lati=3)
    if pizzo:
        m.scatola("pizzo", (0, TESTA_Y - 0.45 * S, -(R_TESTA + 0.006)), (0.3 * S, 0.3 * S, 0.03), c, H, smusso=0.01)
    if baffi:
        m.scatola("baffi", (0, TESTA_Y - 0.115 * S, -(R_TESTA + 0.012)), (0.46 * S, 0.075 * S, 0.035), c, H, smusso=0.01,
                  rastrema=(1.15, 1.0))


def benda_occhio(m):
    """Benda sull'occhio perso (Annibale): toppa e laccio."""
    nero = M(NERO, "cuoio")
    m.scatola("benda", (-0.17 * S, TESTA_Y + 0.07 * S, -(R_TESTA + 0.006)), (0.24 * S, 0.22 * S, 0.016), nero, H,
              smusso=0.004)
    m.cilindro("laccio_benda", (0, TESTA_Y + 0.13 * S, 0), R_TESTA + 0.004, 0.035 * S, nero, H, lati=20,
               assi=rot_z(0.18))


def fascia_testa(m, materiale, y=GIRO - 0.02 * S, alta=0.1 * S):
    m.cilindro("fascia_testa", (0, y, 0), R_TESTA + 0.008, alta, M(materiale), H, lati=20)


def calotta(m, materiale, alto=0.5 * S, giro=GIRO, r=R_ELMO, nuca=True, fascia=None, nome="calotta"):
    """Elmo a cupola: calotta, nuca dietro fino alle orecchie, fascia attorno."""
    mm = M(materiale, "ferro")
    m.cupola(nome, (0, giro, 0), r, alto, mm, H)
    if nuca:
        basso = TESTA_Y - 0.2 * S if nuca is True else nuca
        m.cilindro(nome + "_nuca", (0, (giro + basso) / 2 + 0.002, 0), r, giro - basso + 0.004, mm, H, lati=18,
                   parte="retro")
    if fascia:
        m.cilindro(nome + "_fascia", (0, giro + 0.03 * S, 0), r + 0.006, 0.06 * S, M(fascia, "ottone"), H, lati=18)
    return mm


def tesa(m, materiale, raggio, y, spessore=0.018, scala=(1.0, 1.0), giu=0.0, nome="tesa", lati=24, z=0.0):
    """Tesa (falda) piatta attorno al cappello; giu > 0 la piega in giù ai bordi (elmi)."""
    mm = M(materiale)
    if giu <= 0:
        return m.cilindro(nome, (0, y, z), raggio, spessore, mm, H, lati=lati, assi=np.diag([scala[0], 1, scala[1]]))
    r0 = R_TESTA + 0.01
    prof = [(r0, -spessore / 2), (raggio, -spessore / 2 - giu), (raggio, spessore / 2 - giu), (r0, spessore / 2),
            (r0, -spessore / 2 + 1e-4)]
    bm = r6.tornio(prof, lati)
    for f in bm.faces:
        f.smooth = True
    return m._oggetto(nome, bm, [mm], H, np.diag([scala[0], 1, scala[1]]), (0, y, z))


def cresta_elmo(m, materiale, giro=GIRO, alto=0.5 * S, r=R_ELMO, h=0.22 * S, larga=0.12 * S, tipo="crine", traverso=False,
                nome="cresta"):
    """Cresta sopra l'elmo, da davanti a dietro (o di traverso), seguendo la calotta."""
    mm = M(materiale, tipo)
    n = 13
    for i in range(n):
        a = math.radians(-70 + 140 * i / (n - 1))
        punto = np.array([0, giro + alto * math.cos(a), -r * math.sin(a)])
        su = norm(np.array([0, math.cos(a) / alto, -math.sin(a) / r]))
        hh = h * (0.75 + 0.25 * math.cos(a))
        assi = np.column_stack([[1.0, 0, 0], su, np.cross([1.0, 0, 0], su)])
        if traverso:
            punto = rot_y(math.pi / 2) @ punto
            assi = rot_y(math.pi / 2) @ assi
        m.scatola(f"{nome}{i}", punto + su * (hh / 2 - 0.01), (larga, hh, 2 * r * math.pi * 140 / 360 / n + 0.004), mm, H,
                  assi=assi, rastrema=(0.85, 1.0))


def elmo_conico(m, materiale=FERRO, nasale=True, fascia=None, camaglio_m=None, alto=0.75 * S):
    mm = M(materiale, "ferro")
    # Profilo a ogiva: dritto sul giro, poi curvo verso la punta, così copre tutta la cima della testa.
    R = R_ELMO
    profilo = [(0, 0), (R, 0), (R, 0.12 * S), (R * 0.93, 0.3 * S), (R * 0.72, 0.48 * S), (R * 0.36, alto * 0.82),
               (0.012, alto), (0, alto)]
    bm = r6.tornio(profilo, 12)
    for f in bm.faces:
        f.smooth = len(f.verts) < 5
    m._oggetto("elmo_cono", bm, [mm], H, None, (0, GIRO, 0))
    m.cilindro("elmo_giro", (0, GIRO + 0.03 * S, 0), R_ELMO + 0.006, 0.08 * S, M(fascia or materiale, "ferro"), H, lati=12)
    if nasale:
        m.scatola("nasale", (0, GIRO - 0.2 * S, -(R_ELMO + 0.004)), (0.11 * S, 0.5 * S, 0.02), mm, H, smusso=0.004,
                  rastrema=(0.8, 1.0))
    if camaglio_m:
        camaglio(m, camaglio_m)
    else:
        m.cilindro("elmo_nuca", (0, (GIRO + TESTA_Y - 0.15 * S) / 2, 0), R_ELMO - 0.004, GIRO - TESTA_Y + 0.15 * S, mm, H,
                   lati=12, parte="retro")


def turbante(m, colore, elmo=None, alto=0.42 * S, giri=3, punta=True):
    """Turbante: giri di stoffa avvolti; con elmo, la cupola di ferro col puntale sopra."""
    mm = M(colore, "stoffa")
    h = alto / giri
    for k in range(giri):
        r = R_TESTA + 0.04 - 0.008 * k + (0.008 if k % 2 else 0)
        m.cilindro(f"turbante{k}", (0, GIRO - 0.06 * S + (k + 0.5) * h, 0), r, h + 0.01, mm, H, lati=18,
                   smusso=h * 0.45, segmenti=2, assi=rot_z(0.08 * (1 if k % 2 else -1)))
    cima = GIRO - 0.06 * S + alto
    if elmo:
        em = M(elmo, "ferro" if elmo not in (ORO, OTTONE) else "ottone")
        m.cupola("turbante_elmo", (0, cima - 0.04, 0), R_TESTA * 0.8, 0.42 * S, em, H)
        if punta:
            tubo(m, "puntale", (0, cima + 0.3 * S, 0), (0, cima + 0.62 * S, 0), 0.03, em, H, raggio_fine=0.006)
    else:
        m.cupola("turbante_cima", (0, cima - 0.01, 0), R_TESTA * 0.85, 0.22 * S, mm, H)
        m.scatola("turbante_coda", (0.1 * S, cima - 0.1 * S, R_TESTA + 0.02), (0.22 * S, 0.5 * S, 0.03), mm, H,
                  smusso=0.008, assi=rot_x(-0.25))


def cappello_tesa(m, colore, alto=0.5 * S, larga=0.33 * S, piuma=None, rialzo=None, tipo="feltro"):
    mm = M(colore, tipo)
    y0 = GIRO - 0.04 * S
    m.cilindro("cappello", (0, y0 + alto / 2, 0), R_TESTA + 0.03, alto, mm, H, lati=18, smusso=0.05, segmenti=2,
               smussa_sotto=False)
    tesa(m, mm, R_TESTA + larga, y0, spessore=0.022, giu=0.03)
    m.cilindro("nastro", (0, y0 + 0.1 * S, 0), R_TESTA + 0.036, 0.1 * S, M(NERO, "stoffa"), H, lati=18)
    if piuma:
        pm = M(piuma, "crine")
        for k in range(4):
            a = -0.6 + 0.35 * k
            c = np.array([R_TESTA * 0.7, y0 + alto + 0.05, 0.1 * S]) + np.array([0.05 * math.sin(a), 0.08 * k * 0.4, 0.04 * k])
            m.scatola(f"piuma{k}", c, (0.08 * S, 0.5 * S, 0.035), pm, H, assi=rot_z(-0.5 - 0.1 * k) @ rot_x(0.6),
                      rastrema=(0.4, 1.0), smusso=0.006)


def kepi(m, colore, fascia=None, alto=0.42 * S, visiera=NERO, oro=None, stelle=0, tipo="feltro"):
    """Kepi o berretto con la visiera: corona un poco inclinata in avanti, fascia, visiera di cuoio lucido."""
    mm = M(colore, tipo)
    y0 = GIRO - 0.05 * S
    a = rot_x(-0.12)
    m.cilindro("kepi", (0, y0 + alto / 2, 0.01), R_TESTA + 0.022, alto, mm, H, lati=18, assi=a,
               raggio_sotto=R_TESTA + 0.012, smusso=0.012, segmenti=1)
    if fascia:
        m.cilindro("kepi_fascia", (0, y0 + 0.13 * S, 0.0), R_TESTA + 0.02, 0.2 * S, M(fascia, tipo), H, lati=18, assi=a)
    if oro:
        m.cilindro("kepi_gallone", (0, y0 + 0.25 * S, 0.0), R_TESTA + 0.024, 0.035 * S, M(oro, "ottone"), H, lati=18,
                   assi=a)
    for i in range(stelle):
        x = (i - (stelle - 1) / 2) * 0.22 * S
        m.cilindro(f"stella{i}", (x, y0 + 0.13 * S, -(R_TESTA + 0.03)), 0.05 * S, 0.012, M(oro or ORO, "ottone"), H,
                   lati=5, assi=ASSE_Z)
    m.scatola("visiera", (0, y0 + 0.01, -(R_TESTA + 0.1 * S)), (TESTA_D * 0.8, 0.02, 0.32 * S), M(visiera, "cuoio"), H,
              assi=rot_x(0.25), smusso=0.006, rastrema=(0.8, 1.0))


def berretto(m, colore, fascia, stella=None, visiera=NERO, alto=0.32 * S, tipo="feltro", occhiali=False):
    """Berretto da ufficiale: corona larga e piatta sopra, fascia, visiera, fregio."""
    mm = M(colore, tipo)
    y0 = GIRO - 0.06 * S
    m.cilindro("berretto_fascia", (0, y0 + 0.1 * S, 0), R_TESTA + 0.016, 0.2 * S, M(fascia, tipo), H, lati=18)
    m.cilindro("berretto", (0, y0 + 0.2 * S + alto / 2, 0.02), R_TESTA + 0.07, alto, mm, H, lati=18,
               raggio_sotto=R_TESTA + 0.02, smusso=0.02, segmenti=1)
    m.scatola("visiera", (0, y0 + 0.01, -(R_TESTA + 0.09 * S)), (TESTA_D * 0.8, 0.02, 0.3 * S), M(visiera, "cuoio"), H,
              assi=rot_x(0.3), smusso=0.006, rastrema=(0.8, 1.0))
    if stella:
        m.cilindro("fregio", (0, y0 + 0.24 * S, -(R_TESTA + 0.035)), 0.07 * S, 0.012, M(stella, "ottone"), H, lati=5,
                   assi=ASSE_Z)
    if occhiali:  # occhiali da sabbia sopra la visiera
        for x in (-1, 1):
            m.cilindro(f"occhiale{x}", (x * 0.24 * S, y0 + 0.45 * S, -(R_TESTA + 0.06)), 0.14 * S, 0.05,
                       M("#2A2A2E", "cuoio"), H, lati=12, assi=ASSE_Z)
            m.cilindro(f"lente{x}", (x * 0.24 * S, y0 + 0.45 * S, -(R_TESTA + 0.088)), 0.1 * S, 0.008,
                       M("#4A5A62", "ferro"), H, lati=12, assi=ASSE_Z)


def shako(m, colore=NERO, alto=0.85 * S, fregio=OTTONE, pennacchio=None, pompon=None, cordone=None):
    mm = M(colore, "feltro")
    y0 = GIRO - 0.06 * S
    m.cilindro("shako", (0, y0 + alto / 2, 0), R_TESTA + 0.05, alto, mm, H, lati=18, raggio_sotto=R_TESTA + 0.018)
    m.cilindro("shako_cima", (0, y0 + alto + 0.008, 0), R_TESTA + 0.056, 0.03, M(NERO, "cuoio"), H, lati=18)
    m.cilindro("shako_fondo", (0, y0 + 0.04 * S, 0), R_TESTA + 0.024, 0.08 * S, M(NERO, "cuoio"), H, lati=18)
    m.scatola("visiera", (0, y0 + 0.01, -(R_TESTA + 0.09 * S)), (TESTA_D * 0.8, 0.02, 0.3 * S), M(NERO, "cuoio"), H,
              assi=rot_x(0.25), smusso=0.006, rastrema=(0.8, 1.0))
    if fregio:
        m.scatola("fregio", (0, y0 + alto * 0.5, -(R_TESTA + 0.04)), (0.36 * S, 0.4 * S, 0.012), M(fregio, "ottone"), H,
                  assi=rot_x(-0.05), smusso=0.005, rastrema=(0.7, 1.0))
    if cordone:
        m.scatola("cordone", (0, y0 + alto * 0.3, -(R_TESTA + 0.035)), (TESTA_D * 0.9, 0.04, 0.02), M(cordone), H)
    if pompon:
        m.sfera("pompon", (0, y0 + alto + 0.06 * S, -(R_TESTA + 0.01)), 0.1 * S, M(pompon, "lana"), H, anelli=5, lati=8)
    if pennacchio:
        tubo(m, "pennacchio", (0, y0 + alto, -(R_TESTA + 0.01)), (0, y0 + alto + 0.7 * S, -(R_TESTA - 0.02)), 0.07 * S,
             M(pennacchio, "crine"), H, lati=8, raggio_fine=0.1 * S)


def colbacco(m, pelo, stella=None, paraorecchie=True, alto=0.5 * S):
    """Colbacco di pelo (ushanka): corona tonda, risvolto davanti, paraorecchie, stella rossa."""
    pm = M(pelo, "pelliccia")
    y0 = GIRO - 0.12 * S
    m.cilindro("colbacco", (0, y0 + alto / 2, 0), R_TESTA + 0.05, alto, pm, H, lati=18, smusso=0.05, segmenti=2)
    m.scatola("risvolto", (0, y0 + 0.16 * S, -(R_TESTA + 0.05)), (TESTA_D * 0.95, 0.3 * S, 0.06), pm, H, smusso=0.02)
    if paraorecchie:
        for x in (-1, 1):
            m.scatola(f"paraorecchie{x}", (x * (R_TESTA + 0.04), TESTA_Y - 0.05 * S, 0.02), (0.06, 0.55 * S, 0.5 * S),
                      pm, H, smusso=0.02)
    if stella:
        m.cilindro("stella", (0, y0 + 0.18 * S, -(R_TESTA + 0.085)), 0.08 * S, 0.012, M(stella, "ottone"), H, lati=5,
                   assi=ASSE_Z)


def berretto_frigio(m, colore, bordo=None):
    """Berretto frigio: calotta morbida con la punta piegata in avanti e i lembi sulle guance."""
    mm = M(colore, "lana")
    m.cupola("frigio", (0, GIRO - 0.05 * S, 0.02), R_TESTA + 0.03, 0.7 * S, mm, H)
    m.sfera("frigio_punta", (0, GIRO + 0.55 * S, -0.2 * S), 0.22 * S, mm, H, anelli=5, lati=10, schiaccia=(1, 0.8, 1.2))
    for x in (-1, 1):
        m.scatola(f"frigio_lembo{x}", (x * (R_TESTA + 0.02), TESTA_Y - 0.2 * S, 0.03), (0.03, 0.75 * S, 0.45 * S), mm, H,
                  smusso=0.01, rastrema=(1.0, 0.7))
    m.cilindro("frigio_nuca", (0, (GIRO + TESTA_Y - 0.5 * S) / 2, 0), R_TESTA + 0.03, GIRO - TESTA_Y + 0.5 * S, mm, H,
               lati=18, parte="retro")
    if bordo:
        m.cilindro("frigio_bordo", (0, GIRO - 0.05 * S, 0), R_TESTA + 0.034, 0.08 * S, M(bordo), H, lati=18)


def cappuccio(m, colore, sotto_mento=True):
    """Cappuccio di stoffa che copre testa, nuca e mento (lascia libera la faccia)."""
    mm = M(colore, "stoffa")
    m.cupola("cappuccio", (0, GIRO - 0.05 * S, 0), R_TESTA + 0.03, 0.5 * S, mm, H)
    m.cilindro("cappuccio_dietro", (0, (GIRO + TESTA_Y - 0.7 * S) / 2, 0.005), R_TESTA + 0.03, GIRO - TESTA_Y + 0.7 * S,
               mm, H, lati=18, parte="retro")
    for x in (-1, 1):
        m.scatola(f"cappuccio_lato{x}", (x * (R_TESTA + 0.02), TESTA_Y - 0.1 * S, -0.04), (0.03, 0.9 * S, 0.55 * S), mm,
                  H, smusso=0.01)
    if sotto_mento:
        m.cilindro("cappuccio_mento", (0, TESTA_Y - 0.56 * S, -0.01), R_TESTA + 0.03, 0.22 * S, mm, H, lati=18,
                   smusso=0.02, segmenti=1)


def corona_alloro(m):
    foglia = [M(c, "pelle") for c in ("#4E7A32", "#5E8A3C", "#44702C")]
    n = 22
    for i in range(n):
        a = 2 * math.pi * i / n
        if abs(math.sin(a / 2)) < 0.14:  # davanti si chiude con un piccolo spazio
            continue
        p = np.array([math.sin(a) * (R_TESTA + 0.012), GIRO - 0.02 * S, -math.cos(a) * (R_TESTA + 0.012)])
        assi = rot_y(-a) @ rot_z(0.5 if math.sin(a) > 0 else -0.5)
        m.scatola(f"foglia{i}", p, (0.11 * S, 0.24 * S, 0.02), foglia[i % 3], H, assi=assi, rastrema=(0.3, 1.0))


def elmo_chiuso(m, materiale, pittore, alto=None, cima="piatta", nome="elmo_chiuso"):
    """Elmo che copre tutta la testa (grande elmo, bacinetto con la visiera abbassata): faccia dipinta col pittore."""
    mm = M(materiale, "ferro")
    h = TESTA_H + 0.06 if alto is None else alto
    fronte = dipinto(m, nome, pittore, materiale if isinstance(materiale, str) else materiale["colore"], "ferro")
    m.cilindro(nome, (0, TESTA_Y + 0.02, 0), R_TESTA + 0.03, h, mm, H, lati=18, fronte=fronte, uv=(TESTA_D + 0.06, h))
    if cima == "piatta":
        m.cilindro(nome + "_cima", (0, TESTA_Y + 0.02 + h / 2 + 0.01, 0), R_TESTA + 0.02, 0.025, mm, H, lati=18)
    elif cima == "punta":
        m.cilindro(nome + "_cima", (0, TESTA_Y + 0.02 + h / 2 + 0.25 * S, 0), 0.015, 0.5 * S, mm, H, lati=12,
                   raggio_sotto=R_TESTA + 0.03)


# -- Armi -------------------------------------------------------------------------------------------------

def punta_lancia(m, nome, base, direzione, lunga, larga, materiale, pesi):
    """Punta a foglia: doppio cono schiacciato."""
    d = norm(direzione)
    mm = M(materiale, "ferro")
    pancia = base + d * lunga * 0.3
    assi = assi_lungo(d) @ np.diag([1.0, 1.0, 0.35])
    m.cilindro(nome + "_a", base + d * lunga * 0.15, larga / 2, lunga * 0.3, mm, pesi, lati=4, assi=assi,
               raggio_sotto=0.012)
    m.cilindro(nome + "_b", pancia + d * lunga * 0.35, 0.002, lunga * 0.7, mm, pesi, lati=4, assi=assi,
               raggio_sotto=larga / 2)


def lancia(m, alto=0.95, basso=0.6, legno=LEGNO, punta=FERRO, contrappeso=None, lunga_punta=0.24, osso=True,
           pennone=None):
    """Lancia ritta nella destra, punta in alto (osso "lancia" figlio della mano, come prima)."""
    p, _ = pugno(m, "R")
    if osso:
        m.osso("lancia", "mano.R", m.P("mano.R"))
    L = [("lancia" if osso else "mano.R", 1.0)]
    a = p + np.array([0, alto, -0.05])
    b = p + np.array([0, -basso, 0.05])
    tubo(m, "asta", b, a, 0.022, M(legno, "legno"), L, lati=8)
    punta_lancia(m, "punta", a, a - b, lunga_punta, 0.07, punta, L)
    if contrappeso:
        tubo(m, "tallone", b - norm(a - b) * 0.04, b + norm(a - b) * 0.08, 0.032, M(contrappeso, "ottone"), L, lati=8)
        m.sfera("tallone_pomo", b - norm(a - b) * 0.05, 0.04, M(contrappeso, "ottone"), L, anelli=4, lati=8)
    if pennone:
        pennoncello(m, a - norm(a - b) * 0.12, a - b, pennone, L)


def pennoncello(m, cima, lungo_asta, pittore, pesi, larga=0.4, alta=0.24, coda=True, nome="pennone"):
    """Banderuola appesa sotto la punta: lastra dipinta sui due lati, a coda di rondine."""
    d = norm(lungo_asta)
    # piano della banderuola: contiene l'asta e la direzione indietro (+Z) del soldato
    indietro = np.array([0, 0, 1.0])
    x = norm(indietro - d * indietro.dot(d)) if abs(d[2]) < 0.9 else norm(np.cross(d, [1.0, 0, 0]))
    z = np.cross(x, d)
    punti = [(0, 0), (larga, 0), (larga * (0.8 if coda else 1.0), -alta / 2), (larga, -alta), (0, -alta)]
    fronte = dipinto(m, nome, pittore, "#ECE8DC")
    # Due lastre schiena contro schiena, così il disegno si vede dai due lati.
    sagoma(m, f"{nome}0", cima - z * 0.004, punti, 0.006, M("#ECE8DC"), pesi, fronte=fronte,
           assi=np.column_stack([x, d, z]))
    sagoma(m, f"{nome}1", cima + z * 0.004, [(-px, py) for px, py in punti], 0.006, M("#ECE8DC"), pesi, fronte=fronte,
           assi=np.column_stack([-x, d, -z]))


def lancia_resta(m, avanti=2.0, dietro=0.9, legno="#8A6238", punta=FERRO, pennone=None):
    """Lancia in resta del cavaliere, lungo la direzione dell'affondo (pesi sulla mano destra)."""
    p, _ = pugno(m, "R")
    L = [("mano.R", 1.0)]
    a = p + DIREZIONE_LANCIA * avanti
    b = p - DIREZIONE_LANCIA * dietro
    tubo(m, "asta", b, a, 0.026, M(legno, "legno"), L, lati=8, raggio_fine=0.02)
    punta_lancia(m, "punta", a, DIREZIONE_LANCIA, 0.3, 0.07, punta, L)
    tubo(m, "rotella", p - DIREZIONE_LANCIA * 0.12, p - DIREZIONE_LANCIA * 0.06, 0.05, M(FERRO, "ferro"), L, lati=10)
    if pennone:
        pennoncello(m, a - DIREZIONE_LANCIA * 0.08, DIREZIONE_LANCIA, pennone, L, larga=0.42, alta=0.26)


def picca(m, legno=LEGNO, direzione=None):
    """Picca lunghissima tenuta con le due mani, inclinata in avanti (o lungo "direzione")."""
    pr, _ = pugno(m, "R")
    pl, _ = pugno(m, "L")
    d = norm(pl - pr) if direzione is None else norm(np.asarray(direzione, float))
    tubo(m, "picca", pr - d * 0.5, pr + d * 2.6, 0.022, M(legno, "legno"), [("mano.R", 1.0)], lati=8)
    punta_lancia(m, "punta", pr + d * 2.6, d, 0.22, 0.05, FERRO, [("mano.R", 1.0)])


def spada(m, lunga=0.75, lama=ACCIAIO, elsa=ORO, impugnatura=CUOIO_SCURO, curva=False, guardia=0.18):
    """Spada sguainata nella destra, lungo l'avambraccio."""
    p, d = pugno(m, "R")
    L = [("mano.R", 1.0)]
    ml = M(lama, "ferro")
    if curva:
        su = np.array([0, 1.0, 0])
        a = p + d * 0.1
        b = p + d * (0.1 + lunga * 0.55) + su * 0.04
        e = b + norm(d + su * 0.4) * lunga * 0.45
        m.segmento("lama1", a, b, 0.055, 0.012, ml, L, alto=su)
        m.segmento("lama2", b, e, 0.05, 0.012, ml, L, alto=norm(np.cross(np.cross(e - b, su), e - b)), oltre=(0.01, 0))
    else:
        m.segmento("lama", p + d * 0.1, p + d * lunga, 0.055, 0.012, ml, L, alto=(0, 1, 0))
        m.segmento("lama_punta", p + d * lunga, p + d * (lunga + 0.07), 0.055, 0.012, ml, L, alto=(0, 1, 0))
    m.segmento("guardia", p + d * 0.06, p + d * 0.1, guardia, 0.035, M(elsa, "ottone"), L, alto=(0, 1, 0), smusso=0.006)
    m.sfera("pomo", p - d * 0.09, 0.03, M(elsa, "ottone"), L, anelli=4, lati=8)
    tubo(m, "impugnatura", p - d * 0.08, p + d * 0.06, 0.018, M(impugnatura, "cuoio"), L, lati=8)


def fodero(m, lato="L", lungo=0.6, materiale=CUOIO_SCURO, puntale=OTTONE, elsa=OTTONE, osso=None):
    """Spada nel fodero appesa al fianco (inclinata indietro)."""
    s = -1 if lato == "L" else 1
    attacco = np.array([s * (BUSTO_L / 2 + 0.05), GAMBE + 0.05 * S, -0.02])
    if osso:
        m.osso(osso, "bacino", attacco)
    W = [(osso or "bacino", 1.0)]
    giu = norm(np.array([0, -1.0, 0.45]))
    m.segmento("fodero", attacco, attacco + giu * lungo, 0.06, 0.035, M(materiale, "cuoio"), W, alto=(0, 0, 1),
               smusso=0.008)
    m.segmento("puntale_fodero", attacco + giu * (lungo - 0.06), attacco + giu * (lungo + 0.01), 0.07, 0.042,
               M(puntale, "ottone"), W, alto=(0, 0, 1), smusso=0.006)
    m.segmento("elsa_fodero", attacco - giu * 0.03, attacco + giu * 0.01, 0.15, 0.03, M(elsa, "ottone"), W,
               alto=(0, 0, 1), smusso=0.006)
    tubo(m, "manico_fodero", attacco - giu * 0.16, attacco - giu * 0.03, 0.018, M(CUOIO_SCURO, "cuoio"), W)


def ascia(m, lunga=1.3, testa_c=FERRO, legno=LEGNO, becco=False):
    """Ascia (danese o d'arme) a due mani nella destra, ritta."""
    p, _ = pugno(m, "R")
    L = [("mano.R", 1.0)]
    alto = p + np.array([0, lunga * 0.65, -0.02])
    basso = p - np.array([0, lunga * 0.35, -0.02])
    tubo(m, "manico", basso, alto, 0.022, M(legno, "legno"), L)
    tm = M(testa_c, "ferro")
    sagoma(m, "lama_ascia", alto + np.array([0, -0.12, -0.03]), [(0, 0.06), (0, -0.06), (-0.04, -0.13), (-0.2, -0.16),
           (-0.24, 0.0), (-0.2, 0.16), (-0.04, 0.12)], 0.016, tm, L, assi=rot_y(-math.pi / 2))
    if becco:
        m.segmento("becco", alto + np.array([0, -0.12, 0.0]), alto + np.array([0, -0.15, 0.16]), 0.03, 0.02, tm, L)
        punta_lancia(m, "punta", alto, np.array([0, 1.0, 0]), 0.16, 0.04, testa_c, L)


def arco(m, altezza=1.2, curva=0.16, legno="#6A4424", corda="#E8E0C8", ricurvo=False):
    """Arco nella sinistra (osso "arco"), la pancia in avanti, la corda tesa tra le punte."""
    p, d = pugno(m, "L")
    m.osso("arco", "mano.L", p)
    A = [("arco", 1.0)]
    p = p + d * 0.12 + np.array([0, 0, -0.03])  # davanti al pugno: le braccia R6 sono grosse e lo nasconderebbero
    avanti = np.array([0, 0, -1.0])
    ts = np.linspace(-1, 1, 11)
    punti = [p + np.array([0, t * altezza / 2, 0]) - avanti * (curva * t * t) for t in ts]
    if ricurvo:
        punti[0] = punti[0] + avanti * 0.06
        punti[-1] = punti[-1] + avanti * 0.06
    lm = M(legno, "legno")
    for i, (a, b) in enumerate(zip(punti[:-1], punti[1:])):
        t = abs(ts[i] + ts[i + 1]) / 2
        tubo(m, f"arco{i}", a, b, 0.024 - 0.01 * t, lm, A, lati=6, raggio_fine=0.024 - 0.01 * t)
    tubo(m, "impugnatura_arco", p - np.array([0, 0.07, 0]), p + np.array([0, 0.07, 0]), 0.03, M(CUOIO_SCURO, "cuoio"), A)
    tubo(m, "corda", punti[0], punti[-1], 0.004, M(corda, "stoffa"), A, lati=4)


def faretra(m, centro=None, lunga=0.62, inclinazione=-25, colore=CUOIO, penne=("#E8E2D0", "#B03028", "#E8E2D0"),
            fianco=False):
    """Faretra sulla schiena (o al fianco destro) con le penne che spuntano."""
    if centro is None:
        centro = (-0.1, GAMBE + BUSTO_A * 0.6, BUSTO_P / 2 + 0.09) if not fianco else (BUSTO_L / 2 + 0.1, GAMBE - 0.04, 0.12)
    a = math.radians(inclinazione)
    asse = np.array([math.sin(a), math.cos(a), 0.0])
    c = np.asarray(centro, float)
    W = B if not fianco else BAC
    alto, basso = c + asse * lunga / 2, c - asse * lunga / 2
    tubo(m, "faretra", basso, alto, 0.06, M(colore, "cuoio"), W, lati=10, raggio_fine=0.065)
    tubo(m, "bordo_faretra", alto - asse * 0.03, alto, 0.07, M(CUOIO_SCURO, "cuoio"), W, lati=10)
    for k, (dx, pc) in enumerate(zip((-0.025, 0.0, 0.025), penne)):
        base = alto + np.array([dx, 0, (k - 1) * 0.015])
        tubo(m, f"freccia{k}", alto - asse * 0.05 + np.array([dx, 0, 0]), base + asse * 0.08, 0.006, M(LEGNO, "legno"),
             W, lati=4)
        m.scatola(f"penna{k}", base + asse * 0.12, (0.006, 0.1, 0.035), M(pc, "crine"), W, assi=assi_lungo(asse))
    if not fianco:
        bandoliera(m, CUOIO_SCURO, spalla="R", larga=0.12 * S, nome="cinghia_faretra")


def fucile(m, lungo=1.05, legno="#6A4428", metallo="#3A3C40", baionetta=True, canna=True, cinghia=CUOIO):
    """Fucile basso e pronto, dal pugno destro verso il sinistro (osso "canna" alla bocca)."""
    pr, _ = pugno(m, "R")
    pl, _ = pugno(m, "L")
    d = norm(pl - pr)
    W = [("mano.R", 1.0)]
    su = np.array([0, 1.0, 0])
    calcio = pr - d * 0.3
    m.segmento("calcio", calcio, pr + d * 0.05, 0.05, 0.11, M(legno, "legno"), W, alto=(1, 0, 0), smusso=0.008)
    m.segmento("cassa", pr + d * 0.02, pr + d * (lungo - 0.12), 0.05, 0.06, M(legno, "legno"), W, alto=(1, 0, 0),
               smusso=0.006)
    bocca = pr + d * lungo + su * 0.015
    tubo(m, "canna_fucile", pr + d * 0.05 + su * 0.035, bocca, 0.012, M(metallo, "ferro"), W, lati=8)
    m.segmento("acciarino", pr + d * 0.02 + su * 0.02, pr + d * 0.14 + su * 0.02, 0.06, 0.05, M(metallo, "ferro"), W,
               alto=(1, 0, 0))
    for k in (0.4, 0.7):
        tubo(m, f"fascetta{k}", pr + d * (k * lungo - 0.012), pr + d * (k * lungo + 0.012), 0.032, M(OTTONE, "ottone"),
             W, lati=8)
    if baionetta:
        m.segmento("baionetta", bocca, bocca + d * 0.4, 0.02, 0.008, M(ACCIAIO, "ferro"), W, alto=(1, 0, 0))
    if canna:
        m.osso("canna", "mano.R", bocca)
    if cinghia:
        tubo(m, "cinghia_fucile", calcio + d * 0.1 - su * 0.06, pr + d * (lungo * 0.6) - su * 0.04, 0.008,
             M(cinghia, "cuoio"), W, lati=4)


def fucile_assalto(m, legno="#2A2A2C", metallo="#2A2C30", curvo=False, caricatore=None, lungo=0.95):
    """M16 (nero, caricatore dritto) o AK (legno, caricatore curvo)."""
    pr, _ = pugno(m, "R")
    pl, _ = pugno(m, "L")
    d = norm(pl - pr)
    W = [("mano.R", 1.0)]
    su = np.array([0, 1.0, 0])
    tipo = "cuoio" if legno == "#2A2A2C" else "legno"
    m.segmento("calcio", pr - d * 0.32, pr + d * 0.02, 0.05, 0.1, M(legno, tipo), W, alto=(1, 0, 0), smusso=0.008)
    m.segmento("castello", pr, pr + d * 0.36, 0.055, 0.08, M(metallo, "ferro"), W, alto=(1, 0, 0), smusso=0.006)
    m.segmento("guardamano", pr + d * 0.34, pr + d * 0.62, 0.06, 0.07, M(legno, tipo), W, alto=(1, 0, 0), smusso=0.008)
    bocca = pr + d * lungo + su * 0.02
    tubo(m, "canna_fucile", pr + d * 0.5 + su * 0.02, bocca, 0.012, M(metallo, "ferro"), W)
    if not curvo:
        m.segmento("maniglia", pr + d * 0.05 + su * 0.06, pr + d * 0.3 + su * 0.06, 0.02, 0.03, M(metallo, "ferro"), W,
                   alto=(1, 0, 0))
    c = caricatore or ("#5A3A20" if curvo else "#2A2A2C")
    base = pr + d * 0.2 - su * 0.04
    fondo = base - su * 0.18 + (d * 0.08 if curvo else d * 0.0)
    m.segmento("caricatore", base, fondo, 0.03, 0.07, M(c, "ferro"), W, alto=(1, 0, 0), smusso=0.004)
    m.osso("canna", "mano.R", bocca)


def balestra(m):
    pr, _ = pugno(m, "R")
    pl, _ = pugno(m, "L")
    d = norm(pl - pr)
    W = [("mano.R", 1.0)]
    testa_b = pr + d * 0.7
    m.segmento("teniere", pr - d * 0.25, testa_b, 0.06, 0.08, M("#6A4428", "legno"), W, alto=(1, 0, 0), smusso=0.008)
    lato = norm(np.cross(d, [0, 1, 0]))
    archetto = [testa_b + lato * t * 0.36 - d * (0.08 * t * t) for t in np.linspace(-1, 1, 7)]
    for i, (a, b) in enumerate(zip(archetto[:-1], archetto[1:])):
        tubo(m, f"archetto{i}", a, b, 0.016, M("#5A5E66", "ferro"), W, lati=6)
    for k in (0, -1):
        tubo(m, f"corda{k}", archetto[k], pr + d * 0.12, 0.004, M("#E8E0C8", "stoffa"), W, lati=4)
    m.segmento("staffa", testa_b, testa_b + d * 0.1, 0.1, 0.012, M(FERRO, "ferro"), W, alto=(0, 1, 0))
    m.osso("canna", "mano.R", testa_b)


def pistola(m, lato="R"):
    p, d = pugno(m, lato)
    W = [("mano." + lato, 1.0)]
    bocca = p + d * 0.2
    m.segmento("pistola", p - d * 0.02 + np.array([0, 0.02, 0]), bocca + np.array([0, 0.02, 0]), 0.035, 0.05,
               M("#2A2C30", "ferro"), W, alto=(1, 0, 0), smusso=0.005)
    m.segmento("calcio_pistola", p + np.array([0, 0.03, 0]), p - np.array([0, 0.05, 0]) - d * 0.03, 0.03, 0.05,
               M("#3A2A20", "legno"), W, alto=(1, 0, 0), smusso=0.006)
    m.osso("canna", "mano." + lato, bocca)


def fondina(m, lato="R"):
    s = -1 if lato == "L" else 1
    m.scatola("fondina", (s * (BUSTO_L / 2 + 0.04), GAMBE - 0.05 * S, -0.04), (0.05, 0.2, 0.12), M(CUOIO_SCURO, "cuoio"),
              BAC, smusso=0.01)


def binocolo(m):
    for x in (-1, 1):
        tubo(m, f"binocolo{x}", (-0.35 * S + x * 0.035, COLLO - 0.7 * S, -(BUSTO_P / 2 + 0.05)),
             (-0.35 * S + x * 0.035, COLLO - 0.45 * S, -(BUSTO_P / 2 + 0.05)), 0.03, M("#1E1E20", "cuoio"), B, lati=8)


def giberne(m, materiale=CUOIO_SCURO, xs=(-0.75, -0.4, 0.4, 0.75), y=GAMBE + 0.06 * S, t=T2 + 0.006):
    for i, x in enumerate(xs):
        m.scatola(f"giberna{i}", (x * S, y, -(BUSTO_P / 2 + t + 0.03)), (0.3 * S, 0.3 * S, 0.06), M(materiale, "cuoio"),
                  BAC, smusso=0.008)


def zaino(m, colore, rotolo=None, alto=0.85 * S):
    m.scatola("zaino", (0, COLLO - 0.55 * S, BUSTO_P / 2 + 0.09), (1.3 * S, alto, 0.15), M(colore, "stoffa"), B,
              smusso=0.02, segmenti=2)
    if rotolo:
        tubo(m, "rotolo", (-0.7 * S, COLLO + 0.02, BUSTO_P / 2 + 0.1), (0.7 * S, COLLO + 0.02, BUSTO_P / 2 + 0.1), 0.055,
             M(rotolo, "lana"), B, lati=10)
    for x in (-1, 1):
        m.segmento(f"spallaccio_zaino{x}", (x * 0.5 * S, COLLO + 0.01, -(BUSTO_P / 2 + T1 + 0.008)),
                   (x * 0.45 * S, GAMBE + 0.3 * S, -(BUSTO_P / 2 + T1 + 0.008)), 0.18 * S, 0.012, M(CUOIO, "cuoio"), B,
                   alto=(1, 0, 0))


def borraccia(m, colore="#4A4E3A"):
    m.cilindro("borraccia", (-(BUSTO_L / 2 + 0.03), GAMBE - 0.1 * S, 0.08), 0.06, 0.16, M(colore, "stoffa"), BAC, lati=10,
               smusso=0.02, segmenti=1, assi=ASSE_X)


def granate(m, n=2):
    for i in range(n):
        x = (0.3 + 0.25 * i) * S
        tubo(m, f"granata{i}", (x, GAMBE - 0.1, -(BUSTO_P / 2 + 0.06)), (x, GAMBE + 0.16, -(BUSTO_P / 2 + 0.06)), 0.018,
             M("#5A4A30", "legno"), BAC, lati=6)
        m.cilindro(f"granata_testa{i}", (x, GAMBE + 0.2, -(BUSTO_P / 2 + 0.06)), 0.035, 0.1, M("#4A5040", "ferro"), BAC,
                   lati=8)


# -- Scudi -------------------------------------------------------------------------------------------------

def assi_scudo(angolo):
    """Scudo davanti a sinistra, girato in fuori di "angolo" (gradi)."""
    return rot_y(math.radians(angolo))


def scudo(m, forma, colore, pittore=None, larga=0.6, alta=0.6, tipo="legno_dipinto", bordo=None, umbone=None,
          retro=CUOIO, angolo=25, spessore=0.035, avanti=0.12, bombato=0.03, giu=0.04, schiena=False):
    """Scudo sul braccio sinistro (davanti, girato in fuori) o sulla schiena. forma: tondo, ovale,
    rettangolo, mandorla, pavese."""
    if schiena:
        A = rot_y(math.pi)
        c = np.array([0, COLLO - 0.95 * S, BUSTO_P / 2 + 0.08])
        W = B
    else:
        p, _ = pugno(m, "L")
        A = assi_scudo(angolo)
        c = p + A @ np.array([-0.04, -giu, -avanti])
        W = [("mano.L", 1.0)]
    fronte = dipinto(m, "scudo", pittore, colore, tipo) if pittore else None
    mm = M(colore, tipo)
    if forma in ("tondo", "ovale"):
        r = larga / 2
        scala = (1.0, alta / larga)
        m.disco("scudo", c, r, spessore, mm, W, fronte=fronte, assi=A, scala=scala, bombato=bombato)
        if bordo:
            anello_tondo(m, "bordo_scudo", c + A @ np.array([0, 0, -0.004]), r, spessore + 0.012, 0.03, M(bordo, "ottone"),
                         W, assi=A @ np.column_stack([[1.0, 0, 0], [0, 0, -1.0], [0, scala[1], 0]]))
    elif forma == "mandorla":
        w, h = larga, alta
        punti = [(-w / 2, h * 0.3), (-w * 0.46, h * 0.42), (-w * 0.3, h / 2), (w * 0.3, h / 2), (w * 0.46, h * 0.42),
                 (w / 2, h * 0.3), (w * 0.4, -h * 0.05), (w * 0.22, -h * 0.32), (0, -h / 2), (-w * 0.22, -h * 0.32),
                 (-w * 0.4, -h * 0.05)]
        sagoma(m, "scudo", c, punti, spessore, mm, W, fronte=fronte, assi=A)
        if bordo:
            sagoma(m, "bordo_scudo", c + A @ np.array([0, 0, 0.003]), [(x * 1.06, y * 1.04) for x, y in punti],
                   spessore * 0.8, M(bordo, "ottone"), W, assi=A)
    elif forma == "pavese":
        w, h = larga, alta
        punti = [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h * 0.38), (w * 0.3, h / 2), (-w * 0.3, h / 2), (-w / 2, h * 0.38)]
        sagoma(m, "scudo", c, punti, spessore, mm, W, fronte=fronte, assi=A)
    else:  # rettangolo (curvo)
        m.lastra_curva("scudo", c, larga, alta, spessore, 0.9, mm, W, fronte=fronte, assi=A)
        if bordo:
            for v in (-1, 1):
                m.lastra_curva(f"bordo_scudo{v}", c + A @ np.array([0, v * (alta / 2 - 0.012), -0.004]), larga + 0.01,
                               0.03, spessore + 0.015, 0.9, M(bordo, "ottone"), W, fette=6, assi=A)
    if umbone:
        m.sfera("umbone", c + A @ np.array([0, 0, -spessore / 2 - bombato]), 0.075, M(umbone, "ferro"), W, anelli=4,
                lati=10, schiaccia=(1, 1, 0.8), meta=True)
        # la sfera "meta" guarda -Z locale del mondo: va bene per scudi quasi frontali
    if retro and not schiena:
        m.scatola("imbracatura", c + A @ np.array([0.0, 0, spessore / 2 + 0.012]), (0.04, 0.2, 0.02), M(retro, "cuoio"), W)


# -- Mitragliatrici ------------------------------------------------------------------------------------------

def mitragliatrice(m, tipo="maxim", scudo_ferro=False, sacchi=False, ruote=False):
    """L'arma a terra davanti al mitragliere in ginocchio (ossa "mitragliatrice", "canna", "terra")."""
    pr_f, pl_f = finale(m, pugno(m, "R")[0]), finale(m, pugno(m, "L")[0])
    y = (pr_f[1] + pl_f[1]) / 2 + 0.03
    culatta = np.array([0.0, y, (pr_f[2] + pl_f[2]) / 2 - 0.05])
    with senza_posa(m):
        m.osso("terra", None, (0, 0, 0))
        m.osso("mitragliatrice", None, culatta)
        bocca = culatta + np.array([0, 0.02, -0.95])
        m.osso("canna", "mitragliatrice", bocca)
        G = [("mitragliatrice", 1.0)]
        T = [("terra", 1.0)]
        nero = M("#2E3034", "ferro")
        if tipo == "mg42":
            m.segmento("castello", culatta + np.array([0, 0, -0.45]), culatta + np.array([0, 0, 0.12]), 0.07, 0.11, nero, G,
                       alto=(1, 0, 0), smusso=0.006)
            m.segmento("calcio_mg", culatta + np.array([0, -0.02, 0.1]), culatta + np.array([0, -0.04, 0.32]), 0.05, 0.1,
                       M("#2A2A2C", "cuoio"), G, alto=(1, 0, 0), smusso=0.008)
            tubo(m, "manicotto", culatta + np.array([0, 0.0, -0.75]), culatta + np.array([0, 0.0, -0.42]), 0.035,
                 M("#3A3C40", "ferro"), G, lati=10)
            tubo(m, "canna_mg", culatta + np.array([0, 0.0, -0.95]), culatta + np.array([0, 0.0, -0.74]), 0.014, nero, G)
            for x in (-0.12, 0.12):
                tubo(m, f"bipiede{x}", culatta + np.array([0, -0.02, -0.68]), np.array([x, 0.0, culatta[2] - 0.78]), 0.012,
                     nero, T, lati=6)
            m.segmento("nastro", culatta + np.array([0.04, 0.0, -0.3]), culatta + np.array([0.25, -0.2, -0.28]), 0.06, 0.02,
                       M(OTTONE, "ottone"), G, alto=(0, 0, 1))
        else:
            # Maxim o Hotchkiss: castello, camicia d'acqua (o alette), impugnature, treppiede o ruote.
            m.segmento("castello", culatta + np.array([0, 0, -0.32]), culatta + np.array([0, 0, 0.06]), 0.13, 0.15, nero,
                       G, alto=(1, 0, 0), smusso=0.008)
            tubo(m, "camicia", culatta + np.array([0, 0.02, -0.78]), culatta + np.array([0, 0.02, -0.3]), 0.065,
                 M("#4A4E44", "ferro"), G, lati=12)
            tubo(m, "canna_mg", culatta + np.array([0, 0.02, -0.95]), culatta + np.array([0, 0.02, -0.76]), 0.02, nero, G)
            for x in (-1, 1):
                tubo(m, f"impugnatura{x}", culatta + np.array([x * 0.08, 0, 0.06]),
                     culatta + np.array([x * 0.08, 0, 0.14]), 0.016, M("#5A3A20", "legno"), G)
            m.segmento("nastro", culatta + np.array([0.07, 0.0, -0.15]), culatta + np.array([0.3, -0.18, -0.12]), 0.07,
                       0.015, M("#B8A070", "stoffa"), G, alto=(0, 0, 1))
            if scudo_ferro:
                m.scatola("scudo_mg", culatta + np.array([0, 0.06, -0.42]), (0.52, 0.44, 0.02), M("#4A5A3A", "ferro"), G,
                          smusso=0.006)
            if ruote:
                for x in (-0.28, 0.28):
                    m.cilindro(f"ruota{x}", (x, 0.2, culatta[2] - 0.3), 0.2, 0.04, M("#3A3A3A", "ferro"), T, lati=16,
                               assi=ASSE_X)
                tubo(m, "assale", (-0.28, 0.2, culatta[2] - 0.3), (0.28, 0.2, culatta[2] - 0.3), 0.02, nero, T)
                tubo(m, "affusto", (0, 0.2, culatta[2] - 0.3), culatta + np.array([0, -0.08, -0.2]), 0.03, nero, T)
            else:
                perno = culatta + np.array([0, -0.08, -0.25])
                for dx, dz in ((0.0, -0.75), (-0.32, 0.05), (0.32, 0.05)):
                    tubo(m, f"treppiede{dx}{dz}", perno, np.array([perno[0] + dx, 0.0, perno[2] + dz]), 0.02, nero, T,
                         lati=6)
        if sacchi:
            sacco = M("#B8A478", "stoffa")
            for fila, (yy, n) in enumerate(((0.09, 4), (0.26, 3))):
                for i in range(n):
                    x = (i - (n - 1) / 2) * 0.33
                    m.scatola(f"sacco{fila}{i}", (x, yy, -1.05 + fila * 0.03), (0.31, 0.17, 0.24), sacco, T, smusso=0.05,
                              segmenti=2)


# -- Cavalieri ---------------------------------------------------------------------------------------------

SELLA = 0.93  # altezza del bacino del cavaliere (come nei vecchi modelli)
SEDUTA = np.array([0, SELLA, 0.02])
SCALA_CAVALIERE = 0.8  # il cavaliere R6 è un po' più piccolo del soldato a piedi, per stare in sella
DIREZIONE_LANCIA = norm(np.array([0, -0.2, -1.0]))  # come POSE.cavalleriaMesh


def _fbx_cavallo(origine):
    """Il modello di prima da cui si prende il cavallo (copiato in assets-truppe/_vecchi_r6)."""
    for cartella in (os.path.join(RADICE, "assets-truppe", "_vecchi_r6", origine),
                     os.path.join(RADICE, "assets-truppe", origine)):
        f = os.path.join(cartella, origine + ".fbx")
        if os.path.exists(f):
            return f, json.load(open(os.path.join(cartella, origine + ".json")))["metri"]
    raise FileNotFoundError(origine)


def importa_cavallo(m, origine, liscio=True):
    """Il cavallo del modello di prima: ossa e mesh (solo i triangoli del cavallo), vertici saldati e normali
    lisce (prima era tutto a faccette), una passata di levigatura che conserva il volume, pelo opaco."""
    fbx, metri = _fbx_cavallo(origine)
    prima = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=fbx)
    nuovi = [o for o in bpy.data.objects if o not in prima]
    arm = [o for o in nuovi if o.type == "ARMATURE"][0]
    ob = [o for o in nuovi if o.type == "MESH"][0]
    with senza_posa(m):
        for b in arm.data.bones:  # i padri vengono prima dei figli
            if b.name.startswith(("cavallo", "zampa")):
                h = arm.matrix_world @ b.head_local / metri
                m.osso(b.name, b.parent.name if b.parent else None, (-h.x, h.z, h.y))
    mw = ob.matrix_world.copy()
    ob.modifiers.clear()
    ob.parent = None
    ob.matrix_world = mw
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    gruppi = {g.index: g.name for g in ob.vertex_groups}
    via = set()
    for v in ob.data.vertices:
        g = max(v.groups, key=lambda g: g.weight) if v.groups else None
        if g is None or not gruppi[g.group].startswith(("cavallo", "zampa")):
            via.add(v.index)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.verts[i] for i in via], context="VERTS")
    for v in bm.verts:
        v.co /= metri
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.002)
    if liscio:
        bmesh.ops.smooth_laplacian_vert(bm, verts=[v for v in bm.verts if not v.is_boundary], lambda_factor=0.25,
                                        lambda_border=0.0, use_x=True, use_y=True, use_z=True, preserve_volume=True)
    for f in bm.faces:
        f.smooth = True
    bm.to_mesh(ob.data)
    bm.free()
    for g in list(ob.vertex_groups):  # via i gruppi del cavaliere di prima
        if not g.name.startswith(("cavallo", "zampa")):
            ob.vertex_groups.remove(g)
    # Materiale: la texture di prima con la grana del pelo, opaca.
    img = None
    for mt in ob.data.materials:
        for n in mt.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image:
                img = n.image
    ob.data.uv_layers[0].name = "UV"
    pelo = bpy.data.materials.new("cavallo_" + origine)
    pelo.use_nodes = True
    nn, ll = pelo.node_tree.nodes, pelo.node_tree.links
    t = nn.new("ShaderNodeTexImage")
    t.image = img
    uv = nn.new("ShaderNodeUVMap")
    uv.uv_map = "UV"
    ll.new(uv.outputs["UV"], t.inputs["Vector"])
    r6._grana(pelo, "pelle", t.outputs["Color"])
    pelo["colore"], pelo["tipo"], pelo["cavallo"] = "#5A3A28", "pelle", 1
    ob.data.materials.clear()
    ob.data.materials.append(pelo)
    ob.name = "cavallo"
    for c in ob.users_collection:
        c.objects.unlink(ob)
    m.coll.objects.link(ob)
    m.pezzi.append(ob)
    bpy.data.objects.remove(arm)
    return ob


def cavaliere(nome, faccia, cartella, origine, pelle=PELLI[0], mano_r=(0, -0.2, -1), mano_l=(0.05, -0.6, -1),
              seduta=SEDUTA, liscio=True):
    """Cavaliere R6 seduto sul cavallo di "origine": il bacino è figlio dell'osso "cavallo"."""
    m = Modello(nome)
    m.cartella, m.pelle, m.faccia, m.posa = cartella, pelle, faccia, "sella"
    importa_cavallo(m, origine, liscio)
    k = SCALA_CAVALIERE
    seduta = np.asarray(seduta, float)
    m.trasforma = lambda p: seduta + (np.asarray(p, float) - np.array([0, GAMBE, 0])) * k
    r6.scheletro(m, mano_r, mano_l)
    m.ossa["bacino"] = ("cavallo", m.ossa["bacino"][1])
    for lato, s in LATI:
        anca = np.array([s * X_GAMBA, GAMBE, 0])
        gin = anca + 0.95 * S * norm(np.array([s * 0.6, -0.45, -0.75]))
        cav = gin + 1.0 * S * norm(np.array([s * 0.12, -1.0, 0.14]))
        m.osso("stinco." + lato, "coscia." + lato, gin)
        m.osso("piede." + lato, "stinco." + lato, cav)
    testa(m, pelle, faccia)
    return m


def gualdrappa(m, colore, pittore=None, lunga=1.2, alta=0.42, nome="gualdrappa", tipo="stoffa"):
    """Coperta sulla groppa: sopra il dorso e giù sui fianchi, col bordo; il disegno sui fianchi."""
    mm = M(colore, tipo)
    fronte = dipinto(m, nome, pittore, colore, tipo) if pittore else None
    W = [("cavallo", 1.0)]
    with senza_posa(m):
        zc, y_dorso = 0.32, 0.9
        m.scatola(nome + "_dorso", (0, y_dorso, zc), (0.64, 0.04, lunga * 0.85), mm, W, smusso=0.01)
        for s in (-1, 1):
            # Fianco: lastra verticale lungo il cavallo, il davanti dipinto verso fuori.
            c = np.array([s * 0.33, y_dorso - alta / 2, zc])
            m.scatola(f"{nome}{s}", c, (lunga, alta, 0.025), mm, W, assi=rot_y(-s * math.pi / 2) @ rot_x(0.08),
                      smusso=0.008, fronte=fronte, uv=fronte is not None)
