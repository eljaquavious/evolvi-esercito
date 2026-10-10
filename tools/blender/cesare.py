"""Gaio Giulio Cesare (100-44 a.C.): il comandante "Cesare" dell'Antichità.

Riferimenti: il ritratto di Tusculum (volto magro, fronte alta, rasato), statue di generali in corazza
(Augusto di Prima Porta) e le ricostruzioni dell'abito del comandante romano. Corazza anatomica di bronzo
dorato modellata sui muscoli, cingulum rosso annodato sotto il petto (il segno del comando), pteruges di cuoio
bianco con le frange ai fianchi e alle spalle, tunica rossa, paludamentum (il mantello scarlatto del
generale) fermato sulla spalla con una fibbia d'oro e che cade dietro fino ai polpacci, calcei di cuoio rosso,
corona d'alloro. In mano il gladio sguainato, alzato in avanti per guidare i suoi.
"""

import math

import bmesh
import bpy
from mathutils import Matrix, Vector

import cavallo as C
import umano
import vestiti as V

NOME = "Cesare"
SIGLA = "CE"

PRESA = Vector((-0.26, -0.24, 1.04))                    # pugno destro sull'elsa
LAMA = Vector((-0.05, -0.55, 0.83)).normalized()        # verso della punta

U = None


def materiali(u):
    u.materiale("Tunica", (0.42, 0.04, 0.03), ruvidita=0.9)
    u.materiale("Mantello", (0.50, 0.035, 0.03), ruvidita=0.92)
    u.materiale("Oro", (0.85, 0.62, 0.25), metallo=1.0, ruvidita=0.3)
    u.materiale("Cingulum", (0.60, 0.05, 0.04), ruvidita=0.8)
    u.materiale("Pteruges", (0.82, 0.78, 0.68), ruvidita=0.8)
    u.materiale("Cuoio", (0.40, 0.08, 0.05), ruvidita=0.65)
    u.materiale("Suola", (0.07, 0.04, 0.02), ruvidita=0.8)
    u.materiale("Ferro", (0.62, 0.63, 0.65), metallo=1.0, ruvidita=0.25)
    u.materiale("Avorio", (0.85, 0.80, 0.68), ruvidita=0.5)
    u.materiale("Alloro", (0.18, 0.32, 0.08), ruvidita=0.6)


def posa(sch):
    for s in (1, -1):
        k = umano.sigla(s)
        umano.ruota_mondo(sch, "coscia" + k, (0, 1, 0), 4.0 * s)
        umano.ruota_mondo(sch, "piede" + k, (0, 1, 0), -4.0 * s)
    # Il piede sinistro un passo avanti, il peso sul destro.
    umano.ruota_mondo(sch, "coscia.L", (1, 0, 0), -12)
    umano.ruota_mondo(sch, "stinco.L", (1, 0, 0), 10)
    umano.ruota_mondo(sch, "testa", (0, 0, 1), -6)
    # Destra: il gladio alzato in avanti; pollice verso la punta, dita attorno all'elsa.
    C.impugna(sch, -1, PRESA, LAMA, (0.3, -0.2, -0.4), (-0.7, 0.4, -0.5))
    # Sinistra: tiene il lembo del mantello davanti al fianco.
    umano.ruota_mondo(sch, "braccio.L", (0, 1, 0), -10)
    umano.ruota_mondo(sch, "avambraccio.L", (1, 0, 0), -55)
    umano.chiudi_dita(sch, 1, {"indice": (55, 80, 40), "medio": (60, 85, 40), "anulare": (65, 85, 40),
                               "mignolo": (70, 80, 40), "pollice": (20, 30, 20)})


def vestiti(u):
    V.veste(u, "Tunica", 1.44, 0.58, "Tunica", margine=0.010, svasatura=0.06, pieghe=0.006)
    V.maniche(u, "Tunica_Maniche", "Tunica", t_inizio=-0.15, t_fine=0.45, margine=0.009)
    V.calzature(u, "Calcei", "Cuoio", "Suola", taglio=0.16, inclinazione=0.2)
    V.lacci_gamba(u, "Calcei_Lacci", "Cuoio", [0.14, 0.24], distacco=0.004, larghezza=0.012)
    u.nascondi_pelle()
    # Corazza anatomica: segue i muscoli veri del busto con un margine; orlo che si apre sul ventre.
    V.veste(u, "Corazza", 1.43, 0.96, "Oro", margine=0.022, svasatura=0.0, pieghe=0.0, n_pieghe=4, spessore=0.007)
    V.pteruges(u, "Pteruges", "Pteruges", z_alto=0.99, lunghezza=0.22, n=20, distacco=0.035,
               lunghezza_spalle=0.15, n_spalle=8)
    # Cingulum: fascia rossa annodata sotto il petto, con il nodo e i due capi davanti.
    u.oggetto("Cingulum", V.anello_sul_corpo(u, (0, 0.0, 1.17), (0, 0, 1), 0.036, 0.032, n=64, portata=0.3),
              "Cingulum", spessore=0.006)
    nodo = u.sulla_pelle(Vector((0, 0, 1.17)), Vector((0, -1, 0)), 0.05, 0.35)
    capi = [V.sfera(nodo, (0.03, 0.02, 0.022), 10, 6)]
    for s in (1, -1):
        capi.append(V.tubo_lungo([nodo, nodo + Vector((s * 0.03, -0.02, -0.05)), nodo + Vector((s * 0.045, -0.025, -0.13))],
                                 [0.014, 0.012, 0.008], n=6))
    u.oggetto("Cingulum_Nodo", V.unisci(*capi), "Cingulum")
    # Spallacci della corazza con la Gorgone d'oro sul petto.
    p = u.sulla_pelle(Vector((0, 0, 1.30)), Vector((0, -1, 0)), 0.038, 0.35)
    u.oggetto("Corazza_Gorgone", V.sfera(p, (0.045, 0.01, 0.045), 12, 6), "Oro")


def paludamento(u):
    """Mantello scarlatto: dietro, dalla spalla sinistra alla destra, fino ai polpacci; fibbia sulla spalla destra."""
    V.mantello_dietro(u, "Mantello", "Mantello", z_alto=1.44, z_basso=0.42, da=0.15, a=math.pi - 0.05,
                      svasatura=0.22, distacco=0.04, pieghe=0.016)
    # Il drappo sopra la spalla sinistra, che scende davanti sul petto.
    punti, normali = [], []
    for i in range(10):
        t = i / 9
        a = math.radians(90 - 120 * t)
        d = Vector((0.35, math.sin(a) * 0.9, math.cos(a))).normalized()
        punti.append(u.sulla_pelle(Vector((0.12, 0.0, 1.32)), d, 0.05, 0.4))
        normali.append(d)
    u.oggetto("Mantello_Spalla", V.striscia(punti, normali, 0.16), "Mantello", spessore=0.006)
    fibbia = u.sulla_pelle(Vector((-0.12, 0.0, 1.38)), Vector((-0.4, -0.5, 0.75)).normalized(), 0.06, 0.4)
    u.oggetto("Fibbia", V.sfera(fibbia, (0.03, 0.03, 0.012), 12, 6,
                                Matrix.Rotation(math.radians(-40), 4, "X")), "Oro")


def gladio(u):
    """Gladio Hispaniensis: lama dritta a punta lunga, guardia e pomo d'avorio, fodero dorato al fianco sinistro."""
    lato = LAMA.cross(Vector((1, 0, 0))).normalized()
    m = Matrix((LAMA.cross(lato).normalized(), lato, LAMA)).transposed().to_4x4()
    m.translation = PRESA
    lama = V.lama(0.55, 0.055, 0.0, spessore=0.008, foglia=0.01)
    V.trasforma(lama, m @ Matrix.Translation((0, 0, 0.07)))
    u.oggetto("Gladio_Lama", lama, "Ferro", liscio=False)
    elsa = [V.scatola((0, 0, 0.06), (0.08, 0.035, 0.025)), V.cilindro((0, 0, -0.06), (0, 0, 0.05), 0.016, n=10),
            V.sfera((0, 0, -0.075), (0.032, 0.03, 0.026), 10, 6)]
    for b in elsa:
        V.trasforma(b, m)
    u.oggetto("Gladio_Elsa", V.unisci(*elsa), "Avorio")
    base = Matrix.Translation((0.2, 0.0, 1.0)) @ Matrix.Rotation(math.radians(20), 4, "X")
    fodero = V.trasforma(V.scatola((0, 0, -0.27), (0.025, 0.07, 0.56)), base)
    u.oggetto("Gladio_Fodero", fodero, "Oro")


def costruisci():
    global U
    u = V.Unita(NOME, SIGLA)
    U = u
    materiali(u)
    u.costruisci_corpo(posa, barba=0.25)
    vestiti(u)
    paludamento(u)
    V.corona_alloro(u, "Alloro", "Alloro")
    gladio(u)
    triangoli = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in u.col.objects if o.type == "MESH")
    return {"oggetti": len(u.col.objects), "triangoli": triangoli}


def esporta(triangoli=5200, lato=512):
    import esporta as E
    r = E.prepara(NOME, U.giunti,
                  rigidi={"Gladio_Lama*": "mano.R", "Gladio_Elsa*": "mano.R", "Gladio_Fodero*": "bacino",
                          "Occhio*": "testa", "Alloro*": "testa"},
                  escludi=["Calcei", "Calcei.0*", "Calcei_Lacci*", "Corazza_Gorgone*"],
                  quote={"Calcei*": 220, "Occhio*": 60, "Tunica.*": 360, "Tunica": 360, "Corazza*": 520,
                         "Mantello": 420, "Mantello.*": 420, "Pteruges*": 360, "Alloro*": 300, "Gladio_*": 80},
                  togli_dal_corpo=[SIGLA + "_Nascosta"], triangoli=triangoli, corpo=U.corpo.name)
    E.cuoci(lato=lato)
    return r
