"""Mitragliere francese (1916-1918): la carta "Mitragliere" del Novecento.

Riferimenti: le squadre di mitragliatrici Hotchkiss Mle 1914 a Verdun (foto d'epoca e ricostruzioni). La
Hotchkiss: canna lunga con le cinque grandi alette di raffreddamento d'ottone vicino alla culatta, castello
squadrato, impugnatura a pistola, nastro rigido di caricatori (le "bande") infilato dal lato sinistro,
treppiede basso Mle 1916. Il tiratore è un poilu con la stessa uniforme del Fante (fante.py: cappotto blu
orizzonte, elmo Adrian, giberne), in ginocchio dietro l'arma: il ginocchio destro a terra, il sinistro su,
la destra sull'impugnatura, la sinistra che guida il nastro.

Il corpo si costruisce in piedi all'altezza solita (i vestiti di fante.py hanno le quote del soldato in piedi)
con le gambe piegate in ginocchio sotto di lui, poi tutto scende di ABBASSA. Nel gioco l'arma ha un osso suo
("mitragliatrice", radice a parte: se il tiratore cade, l'arma resta) e la bocca della canna l'osso "canna".
"""

import math

import bmesh
import bpy
from mathutils import Matrix, Vector

import cavallo as C
import fante as F
import umano
import vestiti as V

NOME = "Mitragliere"
SIGLA = "MI"
ABBASSA = 0.43

# Arma (quote finali, dopo l'abbassamento): asse della canna, dalla culatta in avanti.
CULATTA = Vector((-0.02, -0.30, 0.80))
AVANTI = Vector((0, -1, 0))
IMPUGNATURA = CULATTA + Vector((-0.06, 0.03, -0.09))
NASTRO = CULATTA + Vector((0.13, -0.15, 0.02))

U = None


def materiali(u):
    F.materiali(u)
    u.materiale("Brunito", (0.10, 0.10, 0.11), metallo=1.0, ruvidita=0.45)
    u.materiale("Ottone", (0.80, 0.58, 0.24), metallo=1.0, ruvidita=0.35)


def _su(v):
    return Vector(v) + Vector((0, 0, ABBASSA))


def posa(sch):
    # Gambe in ginocchio (quote prima dell'abbassamento): destro a terra con lo stinco disteso indietro,
    # sinistro su con il piede piantato davanti.
    for s, ginocchio, caviglia, piede in ((-1, (-0.13, -0.06, 0.07), (-0.14, 0.34, 0.09), (0.0, 0.25, -0.9)),
                                          (1, (0.15, -0.36, 0.45), (0.16, -0.24, 0.06), (0.03, -1.0, -0.12))):
        k = umano.sigla(s)
        C.punta(sch, "coscia" + k, _su(ginocchio))
        C.punta(sch, "stinco" + k, _su(caviglia))
        coda = sch.pose.bones["stinco" + k].tail.copy()
        C.punta(sch, "piede" + k, coda + Vector(piede))
    # Busto un poco in avanti sull'arma.
    umano.ruota_mondo(sch, "spina", (1, 0, 0), -10)
    umano.ruota_mondo(sch, "testa", (1, 0, 0), 8)
    # Destra sull'impugnatura a pistola (pollice in su, dita attorno); sinistra sul nastro, palmo in giù.
    C.impugna(sch, -1, _su(IMPUGNATURA), (0, -0.25, 1), (1, -0.2, 0), (-0.7, 0.5, -0.4))
    y = Vector((-0.3, -0.9, -0.3)).normalized()
    dorso = Vector((0.3, 0, 1))
    dorso = (dorso - y * dorso.dot(y)).normalized()
    umano.posa_braccio(sch, 1, _su(NASTRO) - y * 0.06 + dorso * 0.03, y, dorso, (0.7, 0.4, -0.5))
    umano.chiudi_dita(sch, 1, {"indice": (25, 35, 20), "medio": (30, 40, 20), "anulare": (35, 40, 20),
                               "mignolo": (40, 40, 20), "pollice": (10, 15, 10)})


def abbassa(u, dz):
    """Porta giù tutto il soldato (pezzi e articolazioni)."""
    for o in u.col.objects:
        if o.type == "MESH":
            o.data.transform(Matrix.Translation((0, 0, -dz)))
    u.giunti = {k: (Vector(a) - Vector((0, 0, dz)), Vector(b) - Vector((0, 0, dz))) for k, (a, b) in u.giunti.items()}
    u.albero = umano.albero(u.corpo.data)


# Hotchkiss Mle 1914 ---------------------------------------------------------------------------------

def mitragliatrice(u):
    lato = AVANTI.cross(Vector((0, 0, 1))).normalized()
    m = Matrix((-lato, AVANTI, Vector((0, 0, 1)))).transposed().to_4x4()
    m.translation = CULATTA

    def P(x, y, z):
        return m @ Vector((x, y, z))

    ferro = []
    # Castello squadrato e calcio corto con l'impugnatura.
    ferro.append(V.scatola(P(0, -0.13, 0), (0.07, 0.30, 0.10)))
    ferro.append(V.scatola(P(0, 0.06, -0.01), (0.05, 0.10, 0.07)))
    ferro.append(V.trasforma(V.scatola((0, 0, 0), (0.03, 0.04, 0.11)),
                             Matrix.Translation(_su(IMPUGNATURA) - Vector((0, 0, ABBASSA)) + Vector((0, 0, 0.03))) @
                             Matrix.Rotation(math.radians(-20), 4, "X")))
    # Canna con la bocca a tromba e il tubo del gas sotto.
    ferro.append(V.cilindro(P(0, -0.28, 0.01), P(0, -1.02, 0.01), 0.016, 0.014, n=12))
    ferro.append(V.cilindro(P(0, -1.0, 0.01), P(0, -1.08, 0.01), 0.022, 0.03, n=12))
    ferro.append(V.cilindro(P(0, -0.30, -0.035), P(0, -0.80, -0.035), 0.011, n=8))
    # Mirino e alzo.
    ferro.append(V.scatola(P(0, -0.98, 0.04), (0.006, 0.01, 0.03)))
    ferro.append(V.scatola(P(0, -0.08, 0.07), (0.03, 0.04, 0.04)))
    u.oggetto("Arma_Ferro", V.unisci(*ferro), "Brunito", liscio=False)
    # Le cinque alette d'ottone attorno alla canna, vicino alla culatta.
    alette = [V.cilindro(P(0, -0.33 - 0.045 * k, 0.01), P(0, -0.345 - 0.045 * k, 0.01), 0.055, n=16) for k in range(5)]
    u.oggetto("Arma_Alette", V.unisci(*alette), "Ottone")
    # Nastro rigido di caricatori dal lato sinistro, con le cartucce in fila.
    nastro = [V.scatola(P(0.12, -0.16, 0.0), (0.18, 0.045, 0.004))]
    for k in range(9):
        nastro.append(V.cilindro(P(0.05 + 0.018 * k, -0.18, 0.004), P(0.05 + 0.018 * k, -0.12, 0.004), 0.0055, n=6))
    u.oggetto("Arma_Nastro", V.unisci(*nastro), "Ottone")
    # Treppiede basso: testa sotto il castello, una gamba avanti e due dietro aperte.
    testa = P(0, -0.20, -0.07)
    gambe = [V.cilindro(testa, Vector((0, -1.0, 0.02)), 0.017, 0.013, n=8)]
    for s in (1, -1):
        gambe.append(V.cilindro(testa, Vector((s * 0.42, -0.05, 0.02)), 0.017, 0.013, n=8))
    gambe.append(V.cilindro(testa + Vector((0, 0, -0.02)), testa + Vector((0, 0, 0.06)), 0.03, n=10))
    u.oggetto("Arma_Treppiede", V.unisci(*gambe), "Brunito")
    return P(0, -1.08, 0.01)


# Tutto ---------------------------------------------------------------------------------------------

BOCCA = None


def costruisci():
    global U, BOCCA
    u = V.Unita(NOME, SIGLA)
    U = u
    materiali(u)
    u.costruisci_corpo(posa, barba=0.8)
    F.uniforme(u)
    F.equipaggiamento(u)
    V.baffi(u, "Baffi", "Peli", folti=1.2)
    F.elmo(u)
    abbassa(u, ABBASSA)
    BOCCA = mitragliatrice(u)
    triangoli = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in u.col.objects if o.type == "MESH")
    return {"oggetti": len(u.col.objects), "triangoli": triangoli}


def esporta(triangoli=5200, lato=512):
    import esporta as E
    r = E.prepara(NOME, U.giunti,
                  rigidi={"Arma_*": "mitragliatrice", "Occhio*": "testa", "Elmo_*": "testa", "Baffi*": "testa"},
                  escludi=["Scarponi", "Scarponi.0*", "Mollettiere_Giri*", "Bottoni*", "Elmo_Fregio*"],
                  quote={"Scarponi*": 240, "Occhio*": 60, "Cappotto.*": 520, "Cappotto": 520,
                         "Cappotto_Maniche*": 300, "Pantaloni*": 160, "Mollettiere*": 200,
                         "Elmo_Calotta*": 260, "Elmo_Tesa*": 200, "Elmo_Cresta*": 80, "Baffi*": 100,
                         "Arma_Ferro*": 200, "Arma_Alette*": 160, "Arma_Nastro*": 120, "Arma_Treppiede*": 100},
                  togli_dal_corpo=[SIGLA + "_Nascosta"], triangoli=triangoli, corpo=U.corpo.name,
                  extra={"mitragliatrice": (None, CULATTA + Vector((0, -0.2, -0.07))),
                         "canna": ("mitragliatrice", BOCCA)})
    E.cuoci(lato=lato)
    return r
