"""Arciere lungo inglese (Agincourt, 1415): la carta "Arciere" del Medioevo.

Riferimenti: ricostruzioni e miniature della Guerra dei Cent'anni (giubba imbottita trapuntata con la croce
rossa di San Giorgio, calze aderenti, scarpe basse, cappello di ferro a tesa larga (kettle hat), arco lungo
di tasso alto quasi quanto l'arciere, frecce infilate nella cintura, spada corta al fianco).
Posa: la sinistra regge l'arco dritto davanti al fianco, la destra pende accanto alle frecce.
"""

import math

import bmesh
import bpy
from mathutils import Matrix, Vector

import umano
import vestiti as V

NOME = "Arciere"
SIGLA = "LB"

IMPUGNATURA = Vector((0.255, -0.235, 1.02))
META_ARCO = 0.9          # arco lungo: 1,8 m

U = None


def materiali(u):
    giubba = u.materiale("Giubba", (0.70, 0.64, 0.50), ruvidita=0.9)
    _croce_e_trapunta(giubba)
    u.materiale("Calze", (0.32, 0.07, 0.05), ruvidita=0.85)
    u.materiale("Cuoio", (0.20, 0.10, 0.045), ruvidita=0.65)
    u.materiale("Suola", (0.07, 0.04, 0.02), ruvidita=0.8)
    u.materiale("Ferro", (0.50, 0.50, 0.52), metallo=1.0, ruvidita=0.4)
    u.materiale("FerroScuro", (0.28, 0.28, 0.30), metallo=1.0, ruvidita=0.45)
    u.materiale("Ottone", (0.80, 0.58, 0.24), metallo=1.0, ruvidita=0.35)
    u.materiale("Tasso", (0.55, 0.32, 0.14), ruvidita=0.5)
    u.materiale("Corno", (0.80, 0.74, 0.62), ruvidita=0.5)
    u.materiale("Corda", (0.80, 0.74, 0.60), ruvidita=0.8)
    u.materiale("Legno", (0.50, 0.36, 0.20), ruvidita=0.6)
    u.materiale("Piume", (0.86, 0.84, 0.78), ruvidita=0.9)
    u.materiale("PiumeGrigie", (0.40, 0.40, 0.42), ruvidita=0.9)


def _croce_e_trapunta(m):
    """Giubba color lino con trapuntature verticali e la croce rossa di San Giorgio davanti e dietro."""
    nt = m.node_tree
    N, L = nt.nodes, nt.links
    bsdf = N["Principled BSDF"]
    coord = N.new("ShaderNodeTexCoord")
    xyz = N.new("ShaderNodeSeparateXYZ")
    L.new(coord.outputs["Object"], xyz.inputs[0])

    def op(tipo, a, b=None):
        n = N.new("ShaderNodeMath")
        n.operation = tipo
        for i, v in enumerate((a, b)):
            if v is None:
                continue
            if isinstance(v, (int, float)):
                n.inputs[i].default_value = v
            else:
                L.new(v, n.inputs[i])
        return n.outputs[0]

    x, z = xyz.outputs["X"], xyz.outputs["Z"]
    asta = op("MULTIPLY", op("LESS_THAN", op("ABSOLUTE", x), 0.042),
              op("MULTIPLY", op("GREATER_THAN", z, 0.92), op("LESS_THAN", z, 1.43)))
    braccio = op("MULTIPLY", op("LESS_THAN", op("ABSOLUTE", op("SUBTRACT", z, 1.27)), 0.042),
                 op("LESS_THAN", op("ABSOLUTE", x), 0.2))
    croce = op("MAXIMUM", asta, braccio)
    # Trapuntatura: righe verticali ogni 3,5 cm (più scure).
    righe = op("ABSOLUTE", op("SINE", op("MULTIPLY", x, 2 * math.pi / 0.035 / 2)))
    trapunta = op("ADD", 0.82, op("MULTIPLY", 0.18, op("POWER", righe, 0.25)))
    base = N.new("ShaderNodeMix")
    base.data_type = "RGBA"
    base.blend_type = "MULTIPLY"
    base.inputs["Factor"].default_value = 1.0
    base.inputs[6].default_value = (0.70, 0.64, 0.50, 1)
    grigio = N.new("ShaderNodeCombineColor")
    for i in range(3):
        L.new(trapunta, grigio.inputs[i])
    L.new(grigio.outputs[0], base.inputs[7])
    finale = N.new("ShaderNodeMix")
    finale.data_type = "RGBA"
    L.new(croce, finale.inputs["Factor"])
    L.new(base.outputs[2], finale.inputs[6])
    finale.inputs[7].default_value = (0.60, 0.05, 0.04, 1)
    L.new(finale.outputs[2], bsdf.inputs["Base Color"])


# Posa ----------------------------------------------------------------------------------------------

def posa(sch):
    for s in (1, -1):
        k = umano.sigla(s)
        umano.ruota_mondo(sch, "coscia" + k, (0, 1, 0), 2.5 * s)
        umano.ruota_mondo(sch, "piede" + k, (0, 1, 0), -2.5 * s)
    V.impugna_verticale(sch, 1, IMPUGNATURA, (0.5, 0.7, -0.3))
    umano.ruota_mondo(sch, "braccio.R", (0, 1, 0), 5)
    umano.piega(sch, "avambraccio.R", -14)
    umano.chiudi_dita(sch, -1, {"indice": (20, 35, 20), "medio": (25, 40, 20), "anulare": (30, 40, 20),
                                "mignolo": (35, 40, 20), "pollice": (10, 15, 10)})


# Vestiti -------------------------------------------------------------------------------------------

def vestiti(u):
    V.pantaloni(u, "Calze", "Calze", t_inizio=0.0, t_fine=1.94, margine=0.004, spessore=0.003)
    V.calzature(u, "Scarpe", "Cuoio", "Suola", taglio=0.10, inclinazione=0.25)
    V.veste(u, "Giubba", 1.45, 0.70, "Giubba", margine=0.022, svasatura=0.045, pieghe=0.004, n_pieghe=12,
            spessore=0.008)
    V.maniche(u, "Giubba_Maniche", "Giubba", t_inizio=-0.15, t_fine=1.92, margine=0.016, spessore=0.006)
    u.nascondi_pelle()
    u.oggetto("Cintura", V.anello_sul_corpo(u, (0, 0.01, 0.98), (0, 0, 1), 0.04, 0.035, n=64, portata=0.3), "Cuoio",
              spessore=0.004)
    fibbia = V.scatola(u.sulla_pelle(Vector((0, 0, 0.98)), Vector((0, -1, 0)), 0.046, 0.3), (0.04, 0.012, 0.045))
    u.oggetto("Cintura_Fibbia", fibbia, "Ottone")


def cappello(u):
    """Kettle hat: cupola di ferro e tesa larga un poco spiovente."""
    _, bordo, _ = V.calotta(u, "Cappello_Cupola", "Ferro", 1.70, 1.675, (0, -0.02, 1.835),
                            lambda t: 0.03 * math.sin(math.pi * min(1.0, t * 1.15)), distacco=0.016)
    centro = Vector((0, -0.02, 0))
    giri = []
    for f, giu in ((0.0, 0.0), (0.035, 0.012), (0.075, 0.035)):
        giro = []
        for p in bordo:
            radiale = Vector((p.x - centro.x, p.y - centro.y, 0)).normalized()
            giro.append(p + radiale * f - Vector((0, 0, giu)))
        giri.append(giro)
    tesa = V.griglia(giri, chiusa=True)
    V._verso_fuori(tesa)
    u.oggetto("Cappello_Tesa", tesa, "Ferro", spessore=0.003)
    u.oggetto("Cappello_Bordo", V.tubo_lungo(giri[-1] + [giri[-1][0]], 0.004, n=6, tappi=False), "FerroScuro")
    u.oggetto("Cappello_Fascia", V.tubo_lungo(bordo + [bordo[0]], 0.005, n=6, tappi=False), "FerroScuro")


# Arco e frecce -----------------------------------------------------------------------------------------

def arco(u):
    # Arco lungo di tasso: flettenti quasi dritti che si curvano piano verso la corda, punte di corno.
    V.arco_teso(u, "Arco", IMPUGNATURA, META_ARCO, lambda s: 0.13 * s ** 2, raggi=(0.016, 0.0075), inclinazione=3,
                corna=False, mat_legno="Tasso")


def frecce(u):
    """Una dozzina di frecce infilate nella cintura al fianco destro, punte in giù."""
    aste, piume, punte = [], [], []
    base = Vector((-0.19, 0.07, 0.98))
    base = u.sulla_pelle(Vector((0, 0.0, 0.98)), Vector((base.x, base.y, 0)).normalized(), 0.052, 0.35)
    for k in range(11):
        a = 2 * math.pi * k / 11
        off = Vector((math.cos(a) * 0.022, math.sin(a) * 0.018, 0)) * (0.4 if k % 3 == 0 else 1.0)
        verso = Vector((-0.08 + 0.05 * math.cos(a), 0.12 + 0.04 * math.sin(a), 1)).normalized()
        p0 = base + off - verso * 0.38
        p1 = base + off + verso * 0.40
        aste.append(V.cilindro(p0, p1, 0.0045, n=6))
        punte.append(V.cilindro(p0 - verso * 0.04, p0, 0.0005, 0.006, n=6))
        for j in range(3):
            lato = Matrix.Rotation(2 * math.pi * j / 3 + k, 3, verso) @ verso.orthogonal().normalized()
            q0 = p1 - verso * 0.14
            pts = [q0 + lato * 0.004, p1 - verso * 0.02 + lato * 0.004, p1 - verso * 0.03 + lato * 0.02,
                   q0 + verso * 0.015 + lato * 0.016]
            bm = bmesh.new()
            bm.faces.new([bm.verts.new(p) for p in pts])
            piume.append(bm)
    u.oggetto("Frecce_Aste", V.unisci(*aste), "Legno")
    u.oggetto("Frecce_Punte", V.unisci(*punte), "FerroScuro")
    u.oggetto("Frecce_Piume", V.unisci(*piume), "Piume", spessore=0.0015)


def spada(u):
    """Spada corta nel fodero al fianco sinistro, punta indietro."""
    attacco = u.sulla_pelle(Vector((0, 0, 0.98)), Vector((0.85, -0.25, 0)).normalized(), 0.05, 0.35)
    punta = attacco + Vector((0.035, 0.33, -0.55))
    d = (punta - attacco).normalized()
    lato = d.cross(Vector((1, 0, 0))).normalized()
    fodero = V.tubo_lungo([attacco + d * 0.02, attacco + d * 0.4, punta - d * 0.06, punta],
                          [0.022, 0.02, 0.016, 0.004], n=10)
    u.oggetto("Spada_Fodero", fodero, "Cuoio")
    elsa = attacco - d * 0.03
    pezzi = [V.cilindro(elsa - lato * 0.085, elsa + lato * 0.085, 0.007, n=8),
             V.cilindro(elsa, elsa - d * 0.11, 0.012, 0.013, n=10),
             V.sfera(elsa - d * 0.125, (0.02, 0.02, 0.02), 10, 6)]
    u.oggetto("Spada_Elsa", V.unisci(*pezzi), "FerroScuro")
    u.oggetto("Spada_Puntale", V.cilindro(punta - d * 0.05, punta + d * 0.005, 0.015, 0.004, n=8), "Ottone")


# Tutto ---------------------------------------------------------------------------------------------

def costruisci():
    global U
    u = V.Unita(NOME, SIGLA)
    U = u
    materiali(u)
    u.costruisci_corpo(posa, barba=0.6)
    vestiti(u)
    cappello(u)
    arco(u)
    frecce(u)
    spada(u)
    triangoli = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in u.col.objects if o.type == "MESH")
    return {"oggetti": len(u.col.objects), "triangoli": triangoli}


def esporta(triangoli=4600, lato=512):
    import esporta as E
    r = E.prepara(NOME, U.giunti,
                  rigidi={"Arco_*": "arco", "Spada_*": "bacino", "Frecce_*": "bacino", "Occhio*": "testa",
                          "Cappello_*": "testa"},
                  escludi=["Scarpe", "Scarpe.0*", "Cintura_Fibbia*", "Cappello_Fascia*", "Frecce_Punte*"],
                  quote={"Scarpe*": 240, "Occhio*": 60, "Giubba.*": 460, "Giubba": 460, "Giubba_Maniche*": 300,
                         "Calze*": 200, "Arco_Legno*": 792, "Arco_Corno*": 100, "Cappello_Cupola*": 260,
                         "Cappello_Tesa*": 200, "Frecce_Aste*": 140},
                  togli_dal_corpo=[SIGLA + "_Nascosta"], triangoli=triangoli, corpo=U.corpo.name,
                  extra={"arco": ("mano.L", IMPUGNATURA)})
    E.cuoci(lato=lato)
    return r
