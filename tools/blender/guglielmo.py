"""Guglielmo il Conquistatore a Hastings (1066): il comandante "Guglielmo" del Medioevo.

Riferimenti: l'arazzo di Bayeux (Guglielmo a cavallo su un destriero nero, con l'usbergo, l'elmo conico con il
nasale e lo scudo a mandorla; il vessillo benedetto dal papa portato in battaglia) e le ricostruzioni moderne.
Rispetto al cavaliere normanno (cavaliere.py, da cui vengono corpo, usbergo, sella e posa): elmo con la fascia
d'oro, mantello rosso fermato sulla spalla che scende sulla groppa, scudo d'oro con la croce rossa e il bordo
blu, e in mano la lancia con il vessillo papale (bianco con la croce d'oro, tre code). Rasato come sull'arazzo.
"""

import math

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

import cavaliere as K
import cavallo as C
import compagno as Co
import spadaccino as S
import umano
import vestiti as V

NOME = "Guglielmo"
SIGLA = "GU"

U = None
CV = None


def materiali(u):
    u.materiale("Tunica", (0.08, 0.10, 0.28), ruvidita=0.9)
    u.materiale("Calze", (0.30, 0.05, 0.04), ruvidita=0.9)
    u.materiale("Maglia", (0.44, 0.45, 0.47), metallo=1.0, ruvidita=0.5)
    S._grana_maglia(u.mat["Maglia"])
    u.materiale("Ferro", (0.55, 0.55, 0.57), metallo=1.0, ruvidita=0.3)
    u.materiale("FerroScuro", (0.28, 0.28, 0.30), metallo=1.0, ruvidita=0.45)
    u.materiale("Oro", (0.85, 0.63, 0.25), metallo=1.0, ruvidita=0.3)
    u.materiale("Cuoio", (0.20, 0.10, 0.045), ruvidita=0.65)
    u.materiale("CuoioRosso", (0.30, 0.06, 0.04), ruvidita=0.65)
    u.materiale("Suola", (0.07, 0.04, 0.02), ruvidita=0.8)
    u.materiale("Frassino", (0.55, 0.40, 0.22), ruvidita=0.6)
    u.materiale("Legno", (0.38, 0.22, 0.10), ruvidita=0.6)
    u.materiale("Ottone", (0.80, 0.58, 0.24), metallo=1.0, ruvidita=0.35)
    u.materiale("Telo", (0.30, 0.03, 0.03), ruvidita=0.9)
    u.materiale("Porpora", (0.30, 0.025, 0.025), ruvidita=0.9)
    u.materiale("Crini", (0.03, 0.02, 0.015), ruvidita=0.8)
    u.materiale("Briglie", (0.10, 0.05, 0.025), ruvidita=0.6)
    u.materiale("Scudo", (1.0, 1.0, 1.0), ruvidita=0.7, immagine=immagine_scudo())
    u.materiale("ScudoRetro", (0.36, 0.24, 0.12), ruvidita=0.8)
    u.materiale("Vessillo", (1.0, 1.0, 1.0), ruvidita=0.9, immagine=immagine_vessillo())


def _immagine(nome, rgb):
    vecchia = bpy.data.images.get(nome)
    if vecchia:
        bpy.data.images.remove(vecchia)
    lato = rgb.shape[0]
    img = bpy.data.images.new(nome, lato, lato, alpha=False)
    rgba = np.concatenate([np.clip(rgb, 0, 1), np.ones((lato, lato, 1))], axis=2).astype(np.float32)
    img.pixels.foreach_set(rgba.ravel())
    img.pack()
    return img


def immagine_scudo(lato=512):
    """Oro, con la croce rossa a braccia allargate, il bordo blu e i chiodi."""
    yy, xx = np.mgrid[0:lato, 0:lato]
    u = (xx + 0.5) / lato * 2 - 1
    v = (yy + 0.5) / lato
    oro = np.array([0.80, 0.58, 0.16])
    rosso = np.array([0.55, 0.06, 0.05])
    blu = np.array([0.07, 0.12, 0.38])
    rgb = np.ones((lato, lato, 3)) * oro
    rgb *= (0.94 + 0.08 * np.sin(u * 4 + v * 9))[..., None]
    cy = 0.6
    asta = np.abs(u) < 0.06 + 0.07 * np.abs(v - cy) ** 1.5
    traversa = np.abs(v - cy) < 0.04 + 0.05 * np.abs(u) ** 1.5
    rgb[(asta & (v > 0.2) & (v < 0.93)) | (traversa & (np.abs(u) < 0.82))] = rosso
    rgb[(np.abs(u) > 0.88) | (v > 0.955)] = blu
    chiodi = (np.abs(np.abs(u) - 0.78) < 0.035) & (np.cos(v * 2 * math.pi * 7) > 0.85)
    rgb[chiodi] = np.array([0.75, 0.75, 0.72])
    return _immagine(SIGLA + "_Scudo", rgb)


def immagine_vessillo(lato=256):
    """Vessillo papale: campo bianco, croce d'oro bordata di rosso, orlo rosso."""
    yy, xx = np.mgrid[0:lato, 0:lato]
    u = (xx + 0.5) / lato      # lungo l'asta
    v = (yy + 0.5) / lato      # dall'asta verso le code
    rgb = np.ones((lato, lato, 3)) * np.array([0.88, 0.86, 0.80])
    rgb *= (0.95 + 0.06 * np.sin(u * 11 + v * 5))[..., None]
    cx, cv_ = 0.5, 0.36
    bordo_croce = (np.abs(u - cx) < 0.085) | (np.abs(v - cv_) < 0.085)
    croce = (np.abs(u - cx) < 0.06) | (np.abs(v - cv_) < 0.06)
    rgb[bordo_croce & (v < 0.72)] = np.array([0.55, 0.06, 0.05])
    rgb[croce & (v < 0.70)] = np.array([0.85, 0.63, 0.20])
    rgb[(u < 0.04) | (u > 0.96) | (v > 0.95)] = np.array([0.55, 0.06, 0.05])
    return _immagine(SIGLA + "_Vessillo", rgb)


def vessillo(u):
    """Lancia di frassino con il vessillo a tre code sotto la punta, che pende indietro e ondeggia."""
    coda = K.PRESA - K.LANCIA * K.DIETRO
    cima = coda + K.LANCIA * K.LUNGHEZZA
    u.oggetto("Lancia_Asta", V.cilindro(coda, cima, 0.016, 0.014, n=10), "Frassino")
    lato = K.LANCIA.cross(Vector((0, 0, 1))).normalized()
    su = lato.cross(K.LANCIA).normalized()
    m = Matrix((lato, K.LANCIA, su)).transposed().to_4x4()
    lama = V.lama(0.24, 0.035, 0.0, spessore=0.008, foglia=0.03)
    V.trasforma(lama, Matrix.Translation(cima) @ m @ Matrix.Rotation(math.radians(-90), 4, "X"))
    u.oggetto("Lancia_Ferro", V.unisci(lama, V.cilindro(cima - K.LANCIA * 0.08, cima + K.LANCIA * 0.01, 0.02, 0.016,
                                                        n=10)), "Ferro")
    attacco = cima - K.LANCIA * 0.1
    via = (su * 0.15 - K.LANCIA * 0.35 - su).normalized()      # pende giù e indietro
    lungo, alto = 0.46, 0.50
    ni, nk = 12, 10
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    vv = []
    for i in range(ni + 1):
        fi = i / ni
        riga = []
        for k in range(nk + 1):
            fk = k / nk
            onda = 0.035 * math.sin(math.pi * 2.0 * fi + fk * 2.5) * fk
            p = attacco - K.LANCIA * lungo * fi + via * alto * fk + lato * onda
            riga.append(bm.verts.new(p))
        vv.append(riga)
    for i in range(ni):
        for k in range(nk):
            # Le tre code: oltre il 70% si tagliano due tacche.
            if k >= 7 and (i in (3, 4) or i in (7, 8)):
                continue
            f = bm.faces.new((vv[i][k], vv[i + 1][k], vv[i + 1][k + 1], vv[i][k + 1]))
            for loop in f.loops:
                ii = next(a for a in range(ni + 1) if loop.vert in vv[a])
                kk = vv[ii].index(loop.vert)
                loop[uv].uv = (ii / ni, kk / nk)
    u.oggetto("Lancia_Vessillo", bm, "Vessillo", spessore=0.004)


def elmo(u):
    S.elmo(u)
    # Fascia d'oro attorno alla base dell'elmo.
    anello = V.anello_sul_corpo(u, (0, -0.02, 1.705), (0, 0.15, 1), 0.024, 0.022, n=48, portata=0.2)
    u.oggetto("Elmo_Oro", anello, "Oro", spessore=0.004)


def costruisci():
    global U, CV
    u = V.Unita(NOME, SIGLA)
    U = u
    K.U = u
    Co.U = u
    materiali(u)
    u.costruisci_corpo(K.posa, barba=0.3)
    cv = C.Cavallo(u, scala=0.235, snello=0.8, sella=(0.0, 0.03, 0.86), manto=(0.08, 0.065, 0.06))
    CV = cv
    K.CV = cv
    K.vestiti(u)
    elmo(u)
    K.scudo(u)
    vessillo(u)
    K.spada(u)
    Co.mantello(u, cv)
    K.sella(u, cv)
    K.bardatura(cv)
    triangoli = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in u.col.objects if o.type == "MESH")
    return {"oggetti": len(u.col.objects), "triangoli": triangoli}


def esporta(triangoli=7800, lato=1024):
    import esporta as E
    r = E.prepara(NOME, U.giunti,
                  rigidi={"Lancia_*": "mano.R", "Occhio*": "testa", "Elmo_*": "testa",
                          "Spada_*": "bacino", "Scudo_*": "avambraccio.L", "Staffe_*": "cavallo",
                          "CV_Coda*": "cavallo.coda", "CV_Morso*": "cavallo.muso", "CV_Ciuffo*": "cavallo.muso"},
                  escludi=["Scarpe", "Scarpe.0*", "Elmo_Nervature*"],
                  quote={"CV_Corpo*": 2600, "Scarpe*": 200, "Occhio*": 60, "Lancia_Asta*": 40, "Lancia_Ferro*": 80,
                         "Lancia_Vessillo*": 160, "Usbergo.*": 400, "Usbergo": 400, "Usbergo_Maniche*": 280,
                         "Usbergo_Falde*": 240, "Scudo_Fronte*": 200, "Scudo_Retro*": 120, "Scudo_Bordo*": 100,
                         "Mantello*": 300, "CV_Sottosella*": 240, "CV_Sella*": 200, "CV_Arcioni*": 120,
                         "CV_Coda*": 260, "CV_Criniera*": 300, "CV_Redini*": 120, "Staffe_*": 120,
                         "Elmo_Calotta*": 220, "Elmo_Oro*": 60},
                  togli_dal_corpo=[SIGLA + "_Nascosta"], triangoli=triangoli, corpo=U.corpo.name,
                  extra=CV.perni(), padri={"bacino": "cavallo"}, cavallo=CV.esporta_cavallo())
    E.cuoci(lato=lato)
    return r
