"""Corpo umano realistico per le truppe di Evolvi Esercito.

Base: il corpo maschile realistico del pacchetto "Human Base Meshes" di Blender Studio (licenza CC0,
https://www.blender.org/download/demo-files/). Qui lo portiamo a 1,75 m, gli diamo uno scheletro,
lo mettiamo in posa (braccia, mani, dita, gambe), lo "cuociamo" in una mesh ferma e lo coloriamo:
pelle, labbra, barba rasata, occhi con l'iride e sopracciglia fatte di peli veri.

Convenzioni come legionario.py: il soldato guarda verso -Y, la sua destra è verso -X, piedi a z = 0.
Le misure delle articolazioni sono state prese una volta sola sulla base mesh (lato sinistro, x > 0)
e valgono già scalate e spostate; il lato destro è lo specchio.
"""

import math
import os
import random
import urllib.request
import zipfile

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree

CARTELLA = os.path.join(os.path.expanduser("~"), "Documents", "EvolviEsercito", "base")
VERSIONE = "human-base-meshes-bundle-v1.4.1"
URL = "https://download.blender.org/demo/asset-bundles/human-base-meshes/%s.zip" % VERSIONE
PACCHETTO = os.path.join(CARTELLA, VERSIONE, "human_base_meshes_bundle.blend")
COLLEZIONE_BASE = "Body Male - Realistic"
CORPO_BASE = "GEO-body_male_realistic"

ALTEZZA = 1.75
SCALA = ALTEZZA / 1.684                  # la base mesh è alta 1,684 m
SPOSTAMENTO = Vector((0, 0.02, 0))       # il suo busto sta 2 cm avanti: lo centriamo su y = 0

# Articolazioni del lato sinistro (x >= 0), in metri, già alla scala finale.
GIUNTI = {
    "bacino": (0, 0.02, 0.93), "spina": (0, 0.02, 1.06), "torace": (0, 0.015, 1.22),
    "collo": (0, -0.005, 1.45), "testa": (0, -0.02, 1.565), "cima": (0, -0.03, 1.75),
    "clavicola": (0.025, -0.01, 1.43), "spalla": (0.185, 0.02, 1.385), "gomito": (0.298, 0.025, 1.14),
    "polso": (0.3894, -0.0504, 0.9125),
    "anca": (0.09, 0.02, 0.90), "ginocchio": (0.13, 0.02, 0.50), "caviglia": (0.18, 0.065, 0.085),
    "punta": (0.205, -0.07, 0.03),
}
# Dita della mano sinistra: nocca, due falangi, punta (il pollice parte dal carpo).
DITA = {
    "pollice": [(0.3803, -0.0754, 0.8959), (0.3799, -0.1124, 0.8761), (0.3832, -0.1413, 0.8580), (0.3836, -0.1624, 0.8414)],
    "indice": [(0.4155, -0.1084, 0.8532), (0.4340, -0.1301, 0.8187), (0.4356, -0.1443, 0.7941), (0.4380, -0.1560, 0.7710)],
    "medio": [(0.4211, -0.0845, 0.8481), (0.4419, -0.1057, 0.8063), (0.4482, -0.1182, 0.7770), (0.4517, -0.1307, 0.7489)],
    "anulare": [(0.4265, -0.0678, 0.8366), (0.4426, -0.0827, 0.7973), (0.4448, -0.0896, 0.7687), (0.4447, -0.0984, 0.7423)],
    "mignolo": [(0.4263, -0.0506, 0.8180), (0.4368, -0.0480, 0.7889), (0.4407, -0.0460, 0.7666), (0.4431, -0.0463, 0.7493)],
}
DORSO_SINISTRO = (0.9011, -0.1233, 0.4157)   # normale del dorso della mano sinistra a riposo
OCCHIO = (0.0342, -0.1066, 1.6355)            # centro dell'occhio sinistro
RAGGIO_OCCHIO = 0.0125


def lato(p, s):
    """Punto del lato sinistro portato sul lato s (+1 sinistra, -1 destra)."""
    return Vector((p[0] * s, p[1], p[2]))


def sigla(s):
    return ".L" if s > 0 else ".R"


# Pacchetto e caricamento -------------------------------------------------------------------------

def assicura_pacchetto():
    if os.path.exists(PACCHETTO):
        return PACCHETTO
    os.makedirs(CARTELLA, exist_ok=True)
    archivio = os.path.join(CARTELLA, VERSIONE + ".zip")
    richiesta = urllib.request.Request(URL, headers={"User-Agent": "Mozilla/5.0 Blender"})
    with urllib.request.urlopen(richiesta, timeout=300) as r, open(archivio, "wb") as f:
        f.write(r.read())
    with zipfile.ZipFile(archivio) as z:
        z.extractall(CARTELLA)
    return PACCHETTO


def contesto():
    """Finestra e vista 3D per gli operatori che ne hanno bisogno."""
    finestra = bpy.context.window_manager.windows[0]
    for area in finestra.screen.areas:
        if area.type == "VIEW_3D":
            regione = next(r for r in area.regions if r.type == "WINDOW")
            return {"window": finestra, "area": area, "region": regione}
    return {"window": finestra}


def carica(col):
    """Aggiunge alla collezione il corpo base (con il Multires) e i due occhi, già a 1,75 m."""
    assicura_pacchetto()
    nomi = [CORPO_BASE, CORPO_BASE + ".eye.L", CORPO_BASE + ".eye.R"]
    with bpy.data.libraries.load(PACCHETTO, link=False) as (sorgente, destinazione):
        destinazione.objects = nomi
    corpo, occhi = None, []
    for o in destinazione.objects:
        col.objects.link(o)
        if o.name.startswith(CORPO_BASE + ".eye"):
            occhi.append(o)
        else:
            corpo = o
    for o in occhi:
        s = 1 if o.name.split(".eye.")[1].startswith("L") else -1
        o.parent = None
        o.matrix_world = (Matrix.Translation(lato(OCCHIO, s)) @ Matrix.Rotation(math.pi / 2, 4, "X")
                          @ Matrix.Diagonal((0.862 * SCALA,) * 3 + (1,)))
    corpo.matrix_world = Matrix.Identity(4)
    corpo.data.transform(Matrix.Translation(SPOSTAMENTO) @ Matrix.Scale(SCALA, 4))
    corpo.name, corpo.data.name = "Corpo", "Corpo"
    for o in occhi:
        o.name = "Occhio" + (".L" if ".eye.L" in o.name else ".R")
    return corpo, occhi


# Scheletro ---------------------------------------------------------------------------------------

def crea_scheletro(col):
    arm = bpy.data.armatures.new("Scheletro")
    ob = bpy.data.objects.new("Scheletro", arm)
    col.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    with bpy.context.temp_override(**contesto()):
        bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.edit_bones
    G = {k: Vector(v) for k, v in GIUNTI.items()}
    avanti = Vector((0, -1, 0))

    def osso(nome, testa, coda, padre=None, su=avanti, connesso=False):
        b = eb.new(nome)
        b.head, b.tail = testa, coda
        b.align_roll(su)
        if padre:
            b.parent = eb[padre]
            b.use_connect = connesso
        return b

    osso("bacino", G["bacino"], G["spina"])
    osso("spina", G["spina"], G["torace"], "bacino", connesso=True)
    osso("torace", G["torace"], G["collo"], "spina", connesso=True)
    osso("collo", G["collo"], G["testa"], "torace", connesso=True)
    osso("testa", G["testa"], G["cima"], "collo", connesso=True)
    for s in (1, -1):
        k = sigla(s)
        dorso = lato(DORSO_SINISTRO, s)
        spalla, gomito, polso = lato(G["spalla"], s), lato(G["gomito"], s), lato(G["polso"], s)
        meta = (gomito + polso) / 2
        osso("clavicola" + k, lato(G["clavicola"], s), spalla, "torace")
        osso("braccio" + k, spalla, gomito, "clavicola" + k, dorso, True)
        osso("avambraccio" + k, gomito, meta, "braccio" + k, dorso, True)
        osso("torsione" + k, meta, polso, "avambraccio" + k, dorso, True)
        osso("mano" + k, polso, lato(DITA["medio"][0], s), "torsione" + k, dorso, True)
        for dito, punti in DITA.items():
            p = [lato(q, s) for q in punti]
            osso(dito + "1" + k, p[0], p[1], "mano" + k, dorso)
            osso(dito + "2" + k, p[1], p[2], dito + "1" + k, dorso, True)
            osso(dito + "3" + k, p[2], p[3], dito + "2" + k, dorso, True)
        osso("coscia" + k, lato(G["anca"], s), lato(G["ginocchio"], s), "bacino")
        osso("stinco" + k, lato(G["ginocchio"], s), lato(G["caviglia"], s), "coscia" + k, avanti, True)
        osso("piede" + k, lato(G["caviglia"], s), lato(G["punta"], s), "stinco" + k, Vector((0, 0, 1)), True)
    with bpy.context.temp_override(**contesto()):
        bpy.ops.object.mode_set(mode="OBJECT")
    return ob


def pesa(corpo, scheletro):
    """Pesi automatici (bone heat) del corpo sullo scheletro."""
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    corpo.select_set(True)
    scheletro.select_set(True)
    bpy.context.view_layer.objects.active = scheletro
    with bpy.context.temp_override(**contesto(), selected_objects=[corpo, scheletro],
                                   selected_editable_objects=[corpo, scheletro], active_object=scheletro):
        bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    scheletro.select_set(False)
    corpo.select_set(False)


# Posa ---------------------------------------------------------------------------------------------

def matrice(testa, y, z):
    """Matrice di un osso con l'asse Y lungo y e l'asse Z il più possibile verso z."""
    y = Vector(y).normalized()
    x = y.cross(Vector(z)).normalized()
    z = x.cross(y)
    m = Matrix((x, y, z)).transposed().to_4x4()
    m.translation = testa
    return m


def ruota_attorno(v, asse, angolo):
    return Matrix.Rotation(angolo, 3, asse) @ v


def angolo_firmato(a, b, asse):
    a = (a - asse * a.dot(asse)).normalized()
    b = (b - asse * b.dot(asse)).normalized()
    return math.atan2(asse.dot(a.cross(b)), a.dot(b))


def due_ossa(spalla, bersaglio, l1, l2, polo):
    """IK a due ossa: dove va il gomito per portare il polso sul bersaglio."""
    d = min((bersaglio - spalla).length, (l1 + l2) * 0.999)
    u = (bersaglio - spalla).normalized()
    a = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
    h = math.sqrt(max(0.0, l1 * l1 - a * a))
    p = (polo - u * polo.dot(u)).normalized()
    return spalla + u * a + p * h, spalla + u * d


def aggiorna():
    bpy.context.view_layer.update()


def posa_braccio(sch, s, polso, mano_y, mano_dorso, polo):
    """Mette il braccio del lato s con il polso in 'polso' e la mano orientata (dita verso mano_y, dorso verso mano_dorso)."""
    k = sigla(s)
    pb = sch.pose.bones
    ossa = sch.data.bones
    spalla = pb["braccio" + k].head.copy()
    l1 = ossa["braccio" + k].length
    l2 = ossa["avambraccio" + k].length + ossa["torsione" + k].length
    gomito, polso = due_ossa(spalla, Vector(polso), l1, l2, Vector(polo))
    yb = (gomito - spalla).normalized()
    ya = (polso - gomito).normalized()
    # Il gomito è una cerniera: la piega sta nel piano di braccio e avambraccio.
    piega = ya - yb * ya.dot(yb)
    if piega.length < 1e-4:
        piega = Vector(polo) - yb * Vector(polo).dot(yb)
    piega.normalize()
    cerniera = piega.cross(yb)          # asse Z del braccio
    zb = cerniera
    pb["braccio" + k].matrix = matrice(spalla, yb, zb)
    aggiorna()
    # Avambraccio: parte dalla cerniera e ruota verso il dorso della mano (pronazione) in due tratti.
    mano_y, mano_dorso = Vector(mano_y).normalized(), Vector(mano_dorso)
    z0 = (zb - ya * zb.dot(ya)).normalized()
    torsione = angolo_firmato(z0, mano_dorso, ya)
    pb["avambraccio" + k].matrix = matrice(gomito, ya, ruota_attorno(z0, ya, torsione / 3))
    aggiorna()
    pb["torsione" + k].matrix = matrice(pb["torsione" + k].head, ya, ruota_attorno(z0, ya, torsione * 2 / 3))
    aggiorna()
    pb["mano" + k].matrix = matrice(pb["mano" + k].head, mano_y, mano_dorso)
    aggiorna()
    return gomito, polso


def piega(sch, nome, angolo, asse="X"):
    """Ruota un osso attorno a un suo asse locale (per le dita: X negativo = chiudere verso il palmo)."""
    pb = sch.pose.bones[nome]
    pb.rotation_mode = "QUATERNION"
    pb.rotation_quaternion = Quaternion(Vector({"X": (1, 0, 0), "Y": (0, 1, 0), "Z": (0, 0, 1)}[asse]),
                                        math.radians(angolo)) @ pb.rotation_quaternion
    aggiorna()


def ruota_mondo(sch, nome, asse, angolo):
    """Ruota un osso attorno a un asse del mondo che passa per la sua testa."""
    pb = sch.pose.bones[nome]
    t = pb.head.copy()
    pb.matrix = Matrix.Translation(t) @ Matrix.Rotation(math.radians(angolo), 4, Vector(asse)) @ Matrix.Translation(-t) @ pb.matrix
    aggiorna()


def chiudi_dita(sch, s, angoli):
    """angoli: per ogni dito (nocca, falange media, punta) in gradi di chiusura verso il palmo."""
    for dito, a in angoli.items():
        for i, g in enumerate(a):
            if g:
                piega(sch, "%s%d%s" % (dito, i + 1, sigla(s)), -g)


def mano_rest(s):
    """Assi della mano a riposo: dita (y), verso il pollice, dorso."""
    polso = lato(GIUNTI["polso"], s)
    y = (lato(DITA["medio"][0], s) - polso).normalized()
    dorso = lato(DORSO_SINISTRO, s)
    dorso = (dorso - y * dorso.dot(y)).normalized()
    return y, dorso


def giunti_in_posa(sch):
    """Posizioni nel mondo di teste e code delle ossa in posa."""
    m = sch.matrix_world
    return {b.name: (m @ b.head, m @ b.tail) for b in sch.pose.bones}


# Cottura ------------------------------------------------------------------------------------------

def cuoci(corpo, sch, livello=2):
    """Applica Multires (al livello scelto) e scheletro: resta una mesh ferma nella posa."""
    mr = corpo.modifiers.get("Multires")
    if mr:
        mr.levels = livello
        mr.render_levels = livello
    deps = bpy.context.evaluated_depsgraph_get()
    nuova = bpy.data.meshes.new_from_object(corpo.evaluated_get(deps), preserve_all_data_layers=True, depsgraph=deps)
    vecchia = corpo.data
    corpo.modifiers.clear()
    corpo.parent = None
    corpo.matrix_world = Matrix.Identity(4)
    corpo.data = nuova
    nuova.name = "Corpo"
    bpy.data.meshes.remove(vecchia)
    for p in corpo.data.polygons:
        p.use_smooth = True
    return corpo


def coordinate(me):
    co = np.zeros(len(me.vertices) * 3, dtype=np.float64)
    me.vertices.foreach_get("co", co)
    return co.reshape(-1, 3)


def imposta_coordinate(me, co):
    me.vertices.foreach_set("co", co.astype(np.float32).ravel())
    me.update()


def albero(me):
    return BVHTree.FromPolygons([v.co.copy() for v in me.vertices], [tuple(p.vertices) for p in me.polygons])


# Materiali ----------------------------------------------------------------------------------------

def _nodi(m):
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    return nt, nt.nodes, nt.links


def materiale_pelle(nome="UM_Pelle", colore=(0.46, 0.25, 0.155)):
    m = bpy.data.materials.get(nome) or bpy.data.materials.new(nome)
    nt, N, L = _nodi(m)
    uscita = N.new("ShaderNodeOutputMaterial")
    bsdf = N.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 0.5
    bsdf.inputs["Subsurface Weight"].default_value = 0.25
    bsdf.inputs["Subsurface Radius"].default_value = (1.0, 0.35, 0.2)
    bsdf.inputs["Subsurface Scale"].default_value = 0.006
    attributo = N.new("ShaderNodeAttribute")
    attributo.attribute_name = "Colore"
    base = N.new("ShaderNodeRGB")
    base.outputs[0].default_value = (*colore, 1.0)
    per = N.new("ShaderNodeMix")
    per.data_type = "RGBA"
    per.blend_type = "MULTIPLY"
    per.inputs["Factor"].default_value = 1.0
    L.new(base.outputs[0], per.inputs[6])
    L.new(attributo.outputs["Color"], per.inputs[7])
    # Pori e piccole irregolarità.
    rumore = N.new("ShaderNodeTexNoise")
    rumore.inputs["Scale"].default_value = 900.0
    rumore.inputs["Detail"].default_value = 4.0
    rilievo = N.new("ShaderNodeBump")
    rilievo.inputs["Strength"].default_value = 0.08
    rilievo.inputs["Distance"].default_value = 0.0004
    L.new(rumore.outputs["Fac"], rilievo.inputs["Height"])
    L.new(rilievo.outputs["Normal"], bsdf.inputs["Normal"])
    L.new(per.outputs[2], bsdf.inputs["Base Color"])
    L.new(bsdf.outputs[0], uscita.inputs[0])
    m.diffuse_color = (*colore, 1.0)
    return m


def materiale_occhio(nome="UM_Occhio", iride=(0.10, 0.05, 0.022)):
    """Bulbo: sclera, iride con raggi, anello scuro e pupilla, in coordinate dell'oggetto (+Z = avanti)."""
    m = bpy.data.materials.get(nome) or bpy.data.materials.new(nome)
    nt, N, L = _nodi(m)
    uscita = N.new("ShaderNodeOutputMaterial")
    bsdf = N.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 0.25
    bsdf.inputs["Coat Weight"].default_value = 1.0
    bsdf.inputs["Coat Roughness"].default_value = 0.03
    coord = N.new("ShaderNodeTexCoord")
    sep = N.new("ShaderNodeSeparateXYZ")
    L.new(coord.outputs["Object"], sep.inputs[0])
    # r = distanza dall'asse avanti, normalizzata sul raggio del bulbo (0.014 nelle coordinate dell'oggetto).
    xy = N.new("ShaderNodeCombineXYZ")
    L.new(sep.outputs["X"], xy.inputs["X"])
    L.new(sep.outputs["Y"], xy.inputs["Y"])
    lung = N.new("ShaderNodeVectorMath")
    lung.operation = "LENGTH"
    L.new(xy.outputs[0], lung.inputs[0])
    norm = N.new("ShaderNodeMath")
    norm.operation = "DIVIDE"
    norm.inputs[1].default_value = 0.014
    L.new(lung.outputs["Value"], norm.inputs[0])
    # Dietro (Z < 0) è tutto sclera: spingiamo r a 1.
    dietro = N.new("ShaderNodeMath")
    dietro.operation = "LESS_THAN"
    dietro.inputs[1].default_value = 0.0
    L.new(sep.outputs["Z"], dietro.inputs[0])
    somma = N.new("ShaderNodeMath")
    somma.operation = "ADD"
    somma.use_clamp = True
    L.new(norm.outputs[0], somma.inputs[0])
    L.new(dietro.outputs[0], somma.inputs[1])
    rampa = N.new("ShaderNodeValToRGB")
    el = rampa.color_ramp.elements
    el[0].position, el[0].color = 0.0, (0.005, 0.004, 0.004, 1)
    el[1].position, el[1].color = 1.0, (0.62, 0.55, 0.50, 1)
    for pos, col in ((0.15, (0.006, 0.005, 0.004, 1)), (0.18, (iride[0] * 0.6, iride[1] * 0.6, iride[2] * 0.6, 1)),
                     (0.30, (*iride, 1)), (0.37, (iride[0] * 0.5, iride[1] * 0.5, iride[2] * 0.5, 1)),
                     (0.41, (0.05, 0.035, 0.03, 1)), (0.45, (0.78, 0.74, 0.70, 1)), (0.80, (0.74, 0.66, 0.62, 1))):
        e = el.new(pos)
        e.color = col
    L.new(somma.outputs[0], rampa.inputs["Fac"])
    # Raggi dell'iride: rumore stirato lungo il raggio.
    raggi = N.new("ShaderNodeTexWave")
    raggi.wave_type = "RINGS"
    raggi.inputs["Scale"].default_value = 3.0
    mescola = N.new("ShaderNodeMix")
    mescola.data_type = "RGBA"
    mescola.blend_type = "OVERLAY"
    mescola.inputs["Factor"].default_value = 0.15
    L.new(rampa.outputs["Color"], mescola.inputs[6])
    L.new(raggi.outputs["Color"], mescola.inputs[7])
    L.new(mescola.outputs[2], bsdf.inputs["Base Color"])
    L.new(bsdf.outputs[0], uscita.inputs[0])
    m.diffuse_color = (0.7, 0.66, 0.62, 1)
    return m


def materiale_peli(nome="UM_Peli", colore=(0.03, 0.018, 0.011)):
    m = bpy.data.materials.get(nome) or bpy.data.materials.new(nome)
    nt, N, L = _nodi(m)
    uscita = N.new("ShaderNodeOutputMaterial")
    bsdf = N.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (*colore, 1)
    bsdf.inputs["Roughness"].default_value = 0.45
    L.new(bsdf.outputs[0], uscita.inputs[0])
    m.diffuse_color = (*colore, 1)
    return m


# Colori della pelle -------------------------------------------------------------------------------

def liscio(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def colora(corpo, barba=0.55, capelli=True, seme=3):
    """Attributo 'Colore' per vertice: labbra, guance, barba rasata e capelli corti (moltiplica il colore pelle)."""
    me = corpo.data
    co = coordinate(me)
    x, y, z = co[:, 0], co[:, 1], co[:, 2]
    ax = np.abs(x)
    rng = np.random.default_rng(seme)
    col = np.ones((len(co), 3))
    davanti = liscio(-0.02, -0.07, y)                # solo la parte anteriore della testa
    # Labbra: più rosate.
    labbra = liscio(0.03, 0.018, ax) * liscio(0.016, 0.004, np.abs(z - 1.561)) * liscio(-0.115, -0.13, y)
    col *= 1 - labbra[:, None] * np.array([0.0, 0.22, 0.2])
    # Guance e orecchie appena più rosse.
    guance = liscio(0.03, 0.0, np.hypot(ax - 0.045, z - 1.60)) * davanti
    col *= 1 - 0.25 * guance[:, None] * np.array([0.0, 0.25, 0.25])
    orecchie = liscio(0.075, 0.09, ax) * liscio(1.66, 1.64, z) * liscio(1.57, 1.59, z)
    col *= 1 - 0.3 * orecchie[:, None] * np.array([0.0, 0.25, 0.25])
    # Barba rasata: mento, mascella, labbro superiore e sotto il mento, non sulle labbra né sugli zigomi.
    sotto_naso = liscio(1.598, 1.585, z) * liscio(1.49, 1.52, z)
    zigomi = liscio(1.585 - 0.35 * np.maximum(ax - 0.03, 0), 1.57 - 0.35 * np.maximum(ax - 0.03, 0), z)
    zona = sotto_naso * np.maximum(zigomi, liscio(0.02, 0.0, ax)) * liscio(0.095, 0.07, ax) * liscio(0.03, -0.01, y)
    zona = np.clip(zona * (1 - labbra * 1.2), 0, 1)
    grana = 0.75 + 0.5 * rng.random(len(co))
    col *= 1 - (barba * zona * grana)[:, None] * np.array([0.42, 0.46, 0.45])
    if capelli:
        # Capelli rasati sopra l'attaccatura: fronte alta, tempie, sopra le orecchie, nuca.
        linea = np.interp(y, [-0.15, -0.08, -0.03, 0.02, 0.08], [1.705, 1.70, 1.655, 1.60, 1.565])
        linea -= np.where(y < -0.06, 0.5 * np.maximum(ax - 0.035, 0), 0.0)
        cuoio = liscio(linea - 0.004, linea + 0.006, z) * liscio(0.12, 0.1, ax)
        grana = 0.8 + 0.4 * rng.random(len(co))
        col *= 1 - (0.78 * cuoio * grana)[:, None] * np.array([1.0, 1.02, 1.05])
    col = np.clip(col, 0.02, 1.0)
    attr = me.color_attributes.get("Colore") or me.color_attributes.new("Colore", "FLOAT_COLOR", "POINT")
    rgba = np.concatenate([col, np.ones((len(co), 1))], axis=1).astype(np.float32)
    attr.data.foreach_set("color", rgba.ravel())
    me.update()


# Sopracciglia (peli veri, come curve) -------------------------------------------------------------

def sopracciglia(col, corpo, materiale, peli=320, seme=7):
    me = corpo.data
    t = albero(me)
    rng = random.Random(seme)
    ex, ey, ez = OCCHIO
    radici, direzioni, normali = [], [], []
    for s in (1, -1):
        for _ in range(peli):
            u = rng.random()                        # 0 = vicino al naso, 1 = verso la tempia
            spessore = 0.0095 * (1 - u) + 0.0042 * u
            x = s * (ex - 0.017 + u * 0.044)
            zc = ez + 0.0165 + 0.007 * math.sin(math.pi * min(1.0, u * 1.25)) - 0.004 * max(0.0, u - 0.8) / 0.2
            v = (rng.random() - 0.5) * spessore * (0.8 + 0.4 * rng.random())
            pz = zc + v
            hit = t.ray_cast(Vector((x, -0.4, pz)), Vector((0, 1, 0)), 1.0)
            if hit[0] is None:
                continue
            p, n = hit[0], hit[1].normalized()
            # I peli vicino al naso salgono, gli altri vanno verso la tempia; tutti stesi sulla pelle.
            verso = Vector((s * (0.55 + 0.6 * u), 0.0, 0.85 - 0.75 * u + (rng.random() - 0.5) * 0.4))
            verso = (verso - n * verso.dot(n)).normalized()
            radici.append(p + n * 0.0002)
            direzioni.append(verso)
            normali.append(n)
    hc = bpy.data.hair_curves.new("Sopracciglia")
    hc.add_curves([4] * len(radici))
    pos = []
    for p, d, n in zip(radici, direzioni, normali):
        lunghezza = 0.006 + rng.random() * 0.004
        alza = 0.25 + rng.random() * 0.2
        for i in range(4):
            f = i / 3
            pos.extend(p + d * lunghezza * f + n * lunghezza * (alza * f - 0.35 * f * f))
    hc.position_data.foreach_set("vector", pos)
    raggio = hc.attributes.get("radius") or hc.attributes.new("radius", "FLOAT", "POINT")
    raggio.data.foreach_set("value", [0.00007, 0.00006, 0.00005, 0.00002] * len(radici))
    hc.materials.append(materiale)
    o = bpy.data.objects.new("Sopracciglia", hc)
    col.objects.link(o)
    return o


# Tutto insieme ------------------------------------------------------------------------------------

def costruisci_corpo(col, posa, livello=2, pelle=(0.46, 0.25, 0.155)):
    """Carica, mette in posa con la funzione posa(scheletro), cuoce e colora.

    Restituisce il corpo, gli altri oggetti (occhi e sopracciglia) e le articolazioni in posa."""
    corpo, occhi = carica(col)
    sch = crea_scheletro(col)
    pesa(corpo, sch)
    posa(sch)
    giunti = giunti_in_posa(sch)
    cuoci(corpo, sch, livello)
    bpy.data.objects.remove(sch, do_unlink=True)
    corpo.data.materials.clear()
    corpo.data.materials.append(materiale_pelle(colore=pelle))
    for o in occhi:
        o.data.materials.clear()
        o.data.materials.append(materiale_occhio())
    colora(corpo)
    peli = sopracciglia(col, corpo, materiale_peli())
    return corpo, occhi + [peli], giunti
