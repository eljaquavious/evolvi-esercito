"""Legionario romano (I-II secolo d.C.) per Evolvi Esercito, costruito da zero in Blender.

Si esegue dentro Blender (anche via MCP): cancella la collezione "Legionario" e la ricostruisce.
Il personaggio guarda verso -Y, alto circa 1,75 m; la sua destra è verso -X.
Riferimenti: le due illustrazioni mandate da Mattia (lorica segmentata, elmo gallico imperiale,
tunica rossa, cingulum con grembiule borchiato, gladio a destra, lancia, scutum rosso con ali e fulmini).
La texture dello scudo si genera con tools/blender/scudo_texture.py e si carica a parte
(immagine "LG_Scudo" in Blender); senza, lo scudo resta rosso pieno.
"""

import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

if "umano" not in sys.modules and "__file__" in globals():
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import umano  # noqa: E402  (corpo realistico, tools/blender/umano.py)

COLLEZIONE = "Legionario"


# Materiali ---------------------------------------------------------------------------------------

def materiale(nome, colore, metallo=0.0, ruvidita=0.6, immagine=None):
    nome = "LG_" + nome
    m = bpy.data.materials.get(nome) or bpy.data.materials.new(nome)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*colore, 1.0)
    bsdf.inputs["Metallic"].default_value = metallo
    bsdf.inputs["Roughness"].default_value = ruvidita
    m.diffuse_color = (*colore, 1.0)
    if immagine is not None:
        nodo = m.node_tree.nodes.get("Texture") or m.node_tree.nodes.new("ShaderNodeTexImage")
        nodo.name = "Texture"
        nodo.image = immagine
        m.node_tree.links.new(nodo.outputs["Color"], bsdf.inputs["Base Color"])
    return m


def materiali():
    immagine = bpy.data.images.get("LG_Scudo")
    return {
        "pelle": materiale("Pelle", (0.60, 0.38, 0.26), ruvidita=0.55),
        "tunica": materiale("Tunica", (0.50, 0.05, 0.04), ruvidita=0.9),
        "acciaio": materiale("Acciaio", (0.66, 0.67, 0.69), metallo=1.0, ruvidita=0.4),
        "ottone": materiale("Ottone", (0.86, 0.62, 0.26), metallo=1.0, ruvidita=0.32),
        "cuoio": materiale("Cuoio", (0.22, 0.11, 0.05), ruvidita=0.65),
        "cuoio_chiaro": materiale("CuoioChiaro", (0.30, 0.17, 0.08), ruvidita=0.7),
        "legno": materiale("Legno", (0.42, 0.27, 0.14), ruvidita=0.7),
        "ferro": materiale("Ferro", (0.32, 0.32, 0.34), metallo=1.0, ruvidita=0.45),
        "occhi": materiale("Occhi", (0.04, 0.03, 0.02), ruvidita=0.3),
        "scudo": materiale("Scudo", (0.62, 0.10, 0.08), ruvidita=0.6, immagine=immagine),
        "scudo_retro": materiale("ScudoRetro", (0.30, 0.18, 0.09), ruvidita=0.8),
        "osso": materiale("Osso", (0.74, 0.64, 0.46), ruvidita=0.5),
    }


# Utilità di costruzione ----------------------------------------------------------------------------

def pulisci():
    col = bpy.data.collections.get(COLLEZIONE)
    if col:
        for o in list(col.all_objects):
            bpy.data.objects.remove(o, do_unlink=True)
        for figlia in list(col.children_recursive):
            bpy.data.collections.remove(figlia)
        bpy.data.collections.remove(col)
    cubo = bpy.data.objects.get("Cube")
    if cubo:
        bpy.data.objects.remove(cubo, do_unlink=True)
    for dati in (bpy.data.meshes, bpy.data.armatures, bpy.data.hair_curves):
        for d in list(dati):
            if d.users == 0:
                dati.remove(d)
    for m in list(bpy.data.materials):
        if m.users == 0 and (m.name.startswith("Leg_") or m.name.startswith("LG_")):
            bpy.data.materials.remove(m)
    vecchia = bpy.data.images.get("Scudo_Legionario")
    if vecchia and vecchia.users == 0:
        bpy.data.images.remove(vecchia)
    col = bpy.data.collections.new(COLLEZIONE)
    bpy.context.scene.collection.children.link(col)
    return col


class Costruttore:
    def __init__(self, collezione, mat):
        self.col = collezione
        self.mat = mat
        self.radice = bpy.data.objects.new(COLLEZIONE, None)
        self.col.objects.link(self.radice)

    def oggetto(self, nome, bm, mat, liscio=True, spessore=0.0, suddividi=0):
        me = bpy.data.meshes.new(nome)
        bm.normal_update()
        bm.to_mesh(me)
        bm.free()
        for poligono in me.polygons:
            poligono.use_smooth = liscio
        o = bpy.data.objects.new(nome, me)
        o.data.materials.append(self.mat[mat] if isinstance(mat, str) else mat)
        self.col.objects.link(o)
        o.parent = self.radice
        if spessore:
            mod = o.modifiers.new("Spessore", "SOLIDIFY")
            mod.thickness = spessore
            mod.offset = 1.0
        if suddividi:
            mod = o.modifiers.new("Liscio", "SUBSURF")
            mod.levels = suddividi
            mod.render_levels = suddividi
        if spessore or suddividi:
            applica(o)
        return o


def applica(o):
    """Applica i modificatori senza operatori (va bene anche da script esterno)."""
    deps = bpy.context.evaluated_depsgraph_get()
    valutato = o.evaluated_get(deps)
    nuova = bpy.data.meshes.new_from_object(valutato)
    vecchia = o.data
    o.modifiers.clear()
    o.data = nuova
    for m in vecchia.materials:
        if m.name not in [x.name for x in nuova.materials]:
            nuova.materials.append(m)
    bpy.data.meshes.remove(vecchia)


def anello_ellittico(bm, centro, rx, ry, n, inizio=0.0, fine=2 * math.pi, chiuso=True):
    """Vertici di un'ellisse orizzontale; angolo 0 = +X, pi/2 = +Y (dietro), 3pi/2 = davanti."""
    vs = []
    passi = n if chiuso else n + 1
    for i in range(passi):
        a = inizio + (fine - inizio) * i / n
        vs.append(bm.verts.new((centro[0] + rx * math.cos(a), centro[1] + ry * math.sin(a), centro[2])))
    return vs


def unisci_anelli(bm, a, b, chiuso=True):
    n = len(a)
    for i in range(n if chiuso else n - 1):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))


def tubo_ellittico(sezioni, n=32, inizio=0.0, fine=2 * math.pi, chiuso=True, tappi=False):
    """Superficie da una lista di sezioni (centro, rx, ry), dal basso in alto."""
    bm = bmesh.new()
    anelli = [anello_ellittico(bm, c, rx, ry, n, inizio, fine, chiuso) for c, rx, ry in sezioni]
    for a, b in zip(anelli, anelli[1:]):
        unisci_anelli(bm, a, b, chiuso)
    if tappi and chiuso:
        bm.faces.new(list(reversed(anelli[0])))
        bm.faces.new(anelli[-1])
    return bm


def cilindro(p0, p1, r0, r1=None, n=16, tappi=True):
    """Cilindro (o tronco di cono) tra due punti."""
    r1 = r0 if r1 is None else r1
    p0, p1 = Vector(p0), Vector(p1)
    asse = p1 - p0
    rot = asse.to_track_quat("Z", "Y").to_matrix().to_4x4()
    bm = bmesh.new()
    anelli = []
    for p, r in ((p0, r0), (p1, r1)):
        anello = []
        for i in range(n):
            a = 2 * math.pi * i / n
            locale = Vector((r * math.cos(a), r * math.sin(a), 0))
            anello.append(bm.verts.new(p + rot @ locale))
        anelli.append(anello)
    unisci_anelli(bm, anelli[0], anelli[1])
    if tappi:
        bm.faces.new(list(reversed(anelli[0])))
        bm.faces.new(anelli[1])
    return bm


def sfera(centro, scala, segmenti=16, anelli=10, matrice=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segmenti, v_segments=anelli, radius=1.0)
    m = Matrix.Translation(Vector(centro)) @ (matrice or Matrix.Identity(4)) @ Matrix.Diagonal((*scala, 1.0))
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    return bm


def scatola(centro, dimensioni, matrice=None):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    m = Matrix.Translation(Vector(centro)) @ (matrice or Matrix.Identity(4)) @ Matrix.Diagonal((*dimensioni, 1.0))
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    return bm


def unisci(*bms):
    """Unisce più bmesh in una sola (per avere meno oggetti)."""
    tot = bmesh.new()
    for b in bms:
        me = bpy.data.meshes.new("_tmp")
        b.to_mesh(me)
        b.free()
        tot.from_mesh(me)
        bpy.data.meshes.remove(me)
    return tot


def striscia(punti, normali, larghezza, spessore=0.0):
    """Nastro lungo una polilinea: 'normali' dà la direzione di uscita dalla superficie in ogni punto."""
    bm = bmesh.new()
    sinistra, destra = [], []
    for i, p in enumerate(punti):
        p = Vector(p)
        avanti = (Vector(punti[min(i + 1, len(punti) - 1)]) - Vector(punti[max(i - 1, 0)])).normalized()
        n = Vector(normali[i]).normalized()
        lato = avanti.cross(n).normalized() * larghezza / 2
        sinistra.append(bm.verts.new(p + lato))
        destra.append(bm.verts.new(p - lato))
    for i in range(len(punti) - 1):
        bm.faces.new((sinistra[i], sinistra[i + 1], destra[i + 1], destra[i]))
    return bm


# Corpo ------------------------------------------------------------------------------------------------
# Il corpo è quello realistico di umano.py: qui scegliamo la posa e adattiamo i vestiti alle sue misure.

GIUNTI_POSA = {}
ALBERO = None        # BVH del corpo in posa, per appoggiare schinieri, calzari e paraguance sulla pelle
NOMI_GIUNTI = {"spalla": ("braccio", 0), "gomito": ("braccio", 1), "polso": ("mano", 0),
               "ginocchio": ("stinco", 0), "caviglia": ("stinco", 1), "punta": ("piede", 1)}
IMPUGNATURA = 1.15   # altezza della mano destra sull'asta della lancia


def P(nome):
    """Articolazione del corpo in posa: 'gomito_d', 'caviglia_s'... (d = destra del soldato, verso -X)."""
    giunto, lato = nome.rsplit("_", 1)
    osso, estremo = NOMI_GIUNTI[giunto]
    return GIUNTI_POSA[osso + (".R" if lato == "d" else ".L")][estremo].copy()


def bordo_scudo(x_locale):
    """Punto sul bordo alto dello scudo e direzione 'fuori' (davanti) in quel punto."""
    phi = math.asin(x_locale / SCUDO_RAGGIO)
    m = scudo_matrice()
    p = m @ Vector((x_locale, SCUDO_RAGGIO - SCUDO_RAGGIO * math.cos(phi), SCUDO_ALTEZZA))
    return p, (m.to_3x3() @ Vector((math.sin(phi), -math.cos(phi), 0))).normalized()


def posa(sch):
    # Gambe un poco più chiuse, piedi piatti a terra.
    for s in (1, -1):
        k = umano.sigla(s)
        umano.ruota_mondo(sch, "coscia" + k, (0, 1, 0), 3.5 * s)
        umano.ruota_mondo(sch, "piede" + k, (0, 1, 0), -3.5 * s)
    # Destra: stringe l'asta verticale della lancia, col pollice che si chiude sulle dita.
    asse = Vector((LANCIA_ASSE.x, LANCIA_ASSE.y, IMPUGNATURA))
    avanti = Vector((0.15, -1, 0)).normalized()
    su = Vector((0, 0, 1))
    phi = math.radians(15)
    radiale = su * math.cos(phi) - avanti * math.sin(phi)
    y = avanti * math.cos(phi) + su * math.sin(phi)
    dorso = y.cross(radiale).normalized()
    umano.posa_braccio(sch, -1, asse - y * 0.09 + dorso * 0.028, y, dorso, (-0.5, 0.7, -0.3))
    umano.chiudi_dita(sch, -1, {"indice": (70, 95, 50), "medio": (75, 95, 50), "anulare": (80, 95, 50),
                                "mignolo": (85, 90, 50), "pollice": (35, 45, 35)})
    # Sinistra: appoggiata sul bordo alto dello scudo, dita oltre il bordo e pollice dietro.
    bordo, fuori = bordo_scudo(-0.13)
    y = (fuori - Vector((0, 0, 0.15))).normalized()
    dorso = (su - y * su.dot(y)).normalized()
    nocca = bordo + fuori * 0.012 + su * 0.016
    umano.posa_braccio(sch, 1, nocca - y * 0.0795, y, dorso, (0.6, 0.6, -0.4))
    umano.chiudi_dita(sch, 1, {"indice": (10, 60, 30), "medio": (10, 65, 30), "anulare": (10, 65, 30),
                               "mignolo": (10, 60, 30), "pollice": (30, 40, 20)})


def corpo(c):
    global ALBERO
    corpo, altri, giunti = umano.costruisci_corpo(c.col, posa)
    GIUNTI_POSA.clear()
    GIUNTI_POSA.update(giunti)
    for o in [corpo] + altri:
        o.parent = c.radice
    nascondi_sotto_vestiti(corpo)
    ALBERO = umano.albero(corpo.data)
    return corpo


def nascondi_sotto_vestiti(corpo):
    """Spinge dentro la lorica e la tunica la pelle del busto e dei fianchi che uscirebbe fuori."""
    me = corpo.data
    co = umano.coordinate(me)
    gruppi = {g.index: g.name for g in corpo.vertex_groups}
    busto = ("bacino", "spina", "torace", "collo", "clavicola.L", "clavicola.R")
    peso = np.zeros(len(co))
    gambe = np.zeros(len(co))
    for v in me.vertices:
        for g in v.groups:
            nome = gruppi[g.group]
            if nome in busto:
                peso[v.index] += g.weight
            elif nome.startswith("coscia"):
                gambe[v.index] += g.weight
    for i in np.nonzero((peso > 0.5) | (gambe > 0.5))[0]:
        x, y, z = co[i]
        if 0.975 <= z <= 1.445 and peso[i] > 0.5:
            rx, ry = esterno_armatura(z)
            rx, ry = rx - 0.022, ry - 0.022
        elif 0.60 <= z < 0.975:
            t = (1.02 - z) / 0.42
            rx, ry = 0.165 + t * 0.045 - 0.008, 0.125 + t * 0.04 - 0.008
        else:
            continue
        e = (x / rx) ** 2 + (y / ry) ** 2
        if e > 1:
            f = 0.99 / math.sqrt(e)
            co[i, 0], co[i, 1] = x * f, y * f
    umano.imposta_coordinate(me, co)


# Vestiti -----------------------------------------------------------------------------------------------

def tunica(c):
    sezioni = []
    pieghe = 18
    for i in range(9):
        t = i / 8
        z = 1.02 - t * 0.42
        rx = 0.165 + t * 0.045
        ry = 0.125 + t * 0.04
        sezioni.append(((0, 0.0, z), rx, ry))
    bm = tubo_ellittico(sezioni, n=72)
    # Pieghe verticali più marcate verso l'orlo.
    for v in bm.verts:
        t = (1.02 - v.co.z) / 0.42
        a = math.atan2(v.co.y / 0.14, v.co.x / 0.19)
        onda = math.sin(a * pieghe) * 0.009 * t
        d = Vector((v.co.x, v.co.y, 0)).normalized()
        v.co += d * onda
    c.oggetto("Tunica", bm, "tunica", spessore=0.006)
    # Maniche corte sopra il gomito.
    maniche = []
    for lato in ("d", "s"):
        spalla, gomito = P("spalla_" + lato), P("gomito_" + lato)
        fine = spalla + (gomito - spalla) * 0.45
        maniche.append(cilindro(spalla + (gomito - spalla) * -0.05, fine, 0.07, 0.064, n=20, tappi=False))
    c.oggetto("Maniche", unisci(*maniche), "tunica", spessore=0.005)
    # Focale: sciarpa avvolta al collo, con le pieghe, il nodo davanti e i due capi sul petto.
    sciarpa = tubo_ellittico([((0, -0.006, 1.43), 0.094, 0.084), ((0, -0.01, 1.455), 0.086, 0.078),
                              ((0, -0.006, 1.48), 0.074, 0.07), ((0, -0.004, 1.5), 0.066, 0.063)], n=48)
    for v in sciarpa.verts:
        a = math.atan2(v.co.y, v.co.x)
        d = Vector((v.co.x, v.co.y, 0)).normalized()
        v.co += d * 0.006 * math.sin(a * 7 + v.co.z * 90)
    nodo = sfera((0, -0.093, 1.44), (0.026, 0.02, 0.022), 12, 8)
    capi = []
    for s in (-1, 1):
        rot = Matrix.Rotation(math.radians(s * 12), 4, "Y")
        capi.append(sfera((s * 0.014, -0.118, 1.405), (0.016, 0.007, 0.034), 10, 6, rot))
    c.oggetto("Focale", sciarpa, "tunica", spessore=0.01)
    c.oggetto("Focale_Nodo", unisci(nodo, *capi), "tunica")


# Lorica segmentata -----------------------------------------------------------------------------------

def busto(z):
    """Raggi (x, y) dell'armatura alla quota z: segue il busto e ci sta sopra."""
    t = max(0.0, min(1.0, (z - 0.98) / (1.30 - 0.98)))
    return 0.178 + 0.012 * t, 0.137 + 0.008 * t


SEZIONI_PETTO = [(1.29, 0.19, 0.146), (1.36, 0.175, 0.138), (1.41, 0.14, 0.115), (1.445, 0.10, 0.09)]


def esterno_armatura(z):
    """Raggi (x, y) della superficie esterna di lorica e petto alla quota z (per appoggiarci sopra le cinghie)."""
    if z <= SEZIONI_PETTO[0][0]:
        rx, ry = busto(z)
        return rx + 0.012, ry + 0.012
    for (z0, x0, y0), (z1, x1, y1) in zip(SEZIONI_PETTO, SEZIONI_PETTO[1:]):
        if z <= z1:
            t = (z - z0) / (z1 - z0)
            return x0 + (x1 - x0) * t + 0.006, y0 + (y1 - y0) * t + 0.006
    return SEZIONI_PETTO[-1][1] + 0.006, SEZIONI_PETTO[-1][2] + 0.006


def lorica(c):
    lamine = []
    fibbie = []
    for i in range(7):
        basso = 0.975 + i * 0.045
        alto = basso + 0.054
        rx0, ry0 = busto(basso)
        rx1, ry1 = busto(alto)
        # A scandole: il bordo basso di ogni lamina esce un poco sopra quella sotto.
        sez = [((0, 0.0, basso), rx0 + 0.010, ry0 + 0.010), ((0, 0.0, basso + 0.008), rx0 + 0.009, ry0 + 0.009),
               ((0, 0.0, alto), rx1, ry1)]
        lamine.append(tubo_ellittico(sez, n=64))
        # Ganci d'ottone davanti, ai due lati dell'apertura.
        for s in (-1, 1):
            fibbie.append(scatola((s * 0.022, -(ry0 + 0.013), basso + 0.026), (0.016, 0.006, 0.02)))
    c.oggetto("Lorica_Fasce", unisci(*lamine), "acciaio", spessore=0.004)
    # Petto e schiena: lamine che salgono e si chiudono verso il collo.
    petto = tubo_ellittico([((0, 0.0, z), rx, ry) for z, rx, ry in SEZIONI_PETTO], n=64)
    c.oggetto("Lorica_Petto", petto, "acciaio", spessore=0.004)
    # Placche e cerniere d'ottone sul petto (come nelle illustrazioni).
    for s in (-1, 1):
        for k in range(2):
            z = 1.335 + k * 0.045
            rx, ry = 0.17 - k * 0.025, 0.136 - k * 0.012
            x = s * 0.07
            y = -ry * math.sqrt(max(0.0, 1 - (x / rx) ** 2)) - 0.006
            fibbie.append(sfera((x, y, z), (0.012, 0.006, 0.012), 10, 6))
            fibbie.append(scatola((x + s * 0.02, y + 0.002, z), (0.028, 0.004, 0.008)))
    # Striscia d'ottone sul bordo del collo.
    collo = tubo_ellittico([((0, 0.0, 1.44), 0.103, 0.092), ((0, 0.0, 1.452), 0.096, 0.088)], n=48)
    c.oggetto("Lorica_Collo", collo, "ottone", spessore=0.005)
    c.oggetto("Lorica_Fibbie", unisci(*fibbie), "ottone")
    spallacci(c)


def spallacci(c):
    lamine = []
    rivetti = []
    for s in (-1, 1):
        perno = Vector((s * 0.115, 0.0, 1.405))
        for k in range(5):
            theta = math.radians(14 + 9 * k)
            direzione = Vector((s * math.cos(theta), 0, -math.sin(theta)))
            su = Vector((s * math.sin(theta), 0, math.cos(theta)))
            centro = perno + direzione * (0.022 + k * 0.034)
            ry, rz = 0.112 + 0.004 * k, 0.07 + 0.006 * k
            punti_a, punti_b = [], []
            bm = bmesh.new()
            n = 20
            for i in range(n + 1):
                a = math.radians(-8 + 196 * i / n)
                base = centro + Vector((0, math.cos(a) * ry, 0)) + su * (math.sin(a) * rz)
                punti_a.append(bm.verts.new(base - direzione * 0.021))
                punti_b.append(bm.verts.new(base + direzione * 0.021 - su * 0.006))
            for i in range(n):
                bm.faces.new((punti_a[i], punti_a[i + 1], punti_b[i + 1], punti_b[i]))
            lamine.append(bm)
            if k in (0, 2, 4):
                cima = centro + su * (rz + 0.004)
                rivetti.append(sfera(cima, (0.006, 0.006, 0.006), 8, 4))
    c.oggetto("Lorica_Spallacci", unisci(*lamine), "acciaio", spessore=0.004)
    c.oggetto("Lorica_Rivetti", unisci(*rivetti), "ottone")


def cintura(c):
    rx, ry = 0.182, 0.142
    cint = tubo_ellittico([((0, 0.0, 0.94), rx, ry), ((0, 0.0, 0.975), rx - 0.002, ry - 0.002)], n=64)
    c.oggetto("Cintura", cint, "cuoio", spessore=0.006)
    placche = []
    for i in range(12):
        a = math.radians(200 + i * 12.7)
        x, y = (rx + 0.007) * math.cos(a), (ry + 0.007) * math.sin(a)
        rot = Matrix.Rotation(math.atan2(y / ry ** 2, x / rx ** 2) - math.pi / 2, 4, "Z")
        placche.append(scatola((x, y, 0.9575), (0.03, 0.004, 0.032), rot))
    c.oggetto("Cintura_Placche", unisci(*placche), "ottone")
    # Grembiule: strisce di cuoio borchiate davanti, con i pendagli in fondo.
    strisce, borchie = [], []
    for k in range(6):
        x = -0.06 + k * 0.024
        punti, normali = [], []
        for i in range(10):
            z = 0.945 - i * 0.025
            t = (1.02 - z) / 0.42
            ryz = 0.125 + t * 0.04 + 0.012
            rxz = 0.165 + t * 0.045
            y = -ryz * math.sqrt(max(0.0, 1 - (x / rxz) ** 2)) - 0.004
            punti.append((x, y, z))
            normali.append((0, -1, 0))
            if 0 < i < 9 and i % 2 == 0:
                borchie.append(sfera((x, y - 0.004, z), (0.007, 0.004, 0.007), 8, 4))
        strisce.append(striscia(punti, normali, 0.016))
        xf, yf, zf = punti[-1]
        borchie.append(sfera((xf, yf - 0.003, zf - 0.02), (0.009, 0.004, 0.018), 8, 6))
    c.oggetto("Grembiule", unisci(*strisce), "cuoio", spessore=0.003)
    c.oggetto("Grembiule_Borchie", unisci(*borchie), "ottone")


def balteo(c):
    """Tracolla dalla spalla sinistra al fianco destro, davanti e dietro, appoggiata sopra l'armatura."""
    def y_su(x, z, segno):
        rx, ry = esterno_armatura(z)
        xx = max(-rx * 0.98, min(rx * 0.98, x))
        return xx, segno * ry * math.sqrt(max(0.0, 1 - (xx / rx) ** 2)), rx, ry

    def lungo(segno):
        punti, normali = [], []
        for i in range(17):
            t = i / 16
            z = 1.435 - t * 0.445
            xx, y, rx, ry = y_su(0.105 - t * 0.30, z, segno)
            punti.append((xx, y, z))
            normali.append((xx / rx, y / ry, 0.25))
        return striscia(punti, normali, 0.03)
    # Sopra la spalla, dal capo davanti a quello dietro.
    _, y0, _, _ = y_su(0.105, 1.435, -1)
    sopra, norm_sopra = [], []
    for i in range(9):
        a = math.radians(i * 22.5)
        sopra.append((0.108, y0 * math.cos(a), 1.435 + 0.032 * math.sin(a)))
        norm_sopra.append((0.3, -math.cos(a), math.sin(a)))
    c.oggetto("Balteo", unisci(lungo(-1), lungo(1), striscia(sopra, norm_sopra, 0.03)), "cuoio", spessore=0.004)


# Gambe e piedi ---------------------------------------------------------------------------------------

def sulla_pelle(centro, direzione, distacco, portata=0.11):
    """Punto sulla pelle guardando da fuori verso 'centro' lungo -direzione, sollevato di 'distacco'."""
    hit = ALBERO.ray_cast(centro + direzione * portata, -direzione, portata)
    if hit[0] is None:
        return centro + direzione * (portata * 0.6)
    return hit[0] + direzione * distacco


def griglia(righe, chiusa=False):
    """Superficie da una griglia di punti (righe x colonne)."""
    bm = bmesh.new()
    vv = [[bm.verts.new(p) for p in riga] for riga in righe]
    n = len(vv[0])
    for a, b in zip(vv, vv[1:]):
        for k in range(n if chiusa else n - 1):
            bm.faces.new((a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]))
    return bm


def schinieri(c):
    """Schinieri modellati sulla gamba vera: davanti, dal ginocchio fin quasi alla caviglia."""
    gusci, lacci = [], []
    for lato in ("d", "s"):
        g, k = P("ginocchio_" + lato), P("caviglia_" + lato)
        asse = (k - g).normalized()
        righe = []
        for i in range(16):
            p = g.lerp(k, -0.07 + 0.87 * i / 15)
            riga = []
            for j in range(17):
                a = math.radians(205 + 130 * j / 16)        # solo il davanti (270 gradi = -Y)
                d = Vector((math.cos(a), math.sin(a), 0))
                d = (d - asse * d.dot(asse)).normalized()
                riga.append(sulla_pelle(p, d, 0.005))
            righe.append(riga)
        gusci.append(griglia(righe))
        # Due cinghie di cuoio che girano dietro il polpaccio.
        for t in (0.3, 0.68):
            p = g.lerp(k, t)
            punti, normali = [], []
            for j in range(19):
                a = math.radians(-25 + 230 * j / 18)
                d = Vector((math.cos(a), math.sin(a), 0))
                d = (d - asse * d.dot(asse)).normalized()
                punti.append(sulla_pelle(p, d, 0.003))
                normali.append(d)
            lacci.append(striscia(punti, normali, 0.014))
    o = c.oggetto("Schinieri", unisci(*gusci), "acciaio", spessore=0.0035)
    c.oggetto("Schinieri_Lacci", unisci(*lacci), "cuoio", spessore=0.002)
    return o


def calzari(c, corpo):
    """Calcei di cuoio: un guscio preso dal piede vero, tagliato sopra la caviglia, con la suola scura."""
    bm = bmesh.new()
    bm.from_mesh(corpo.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z > 0.2], context="VERTS")
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, 0.115),
                           plane_no=Vector((0, -0.25, 1)).normalized(), clear_outer=True)
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal * 0.0035
    for f in bm.faces:
        f.material_index = 1 if f.normal.z < -0.55 else 0
    me = bpy.data.meshes.new("Calzari")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("Calzari", me)
    me.materials.append(c.mat["cuoio_chiaro"])
    me.materials.append(c.mat["cuoio"])
    c.col.objects.link(o)
    o.parent = c.radice
    mod = o.modifiers.new("Spessore", "SOLIDIFY")
    mod.thickness = 0.003
    mod.offset = 1.0
    applica(o)
    for p in o.data.polygons:
        p.use_smooth = True
    # Cinghie alla caviglia.
    cinghie = []
    for lato in ("d", "s"):
        k = P("caviglia_" + lato)
        for dz in (0.02, 0.05):
            punti, normali = [], []
            for j in range(25):
                a = math.radians(360 * j / 24)
                d = Vector((math.cos(a), math.sin(a), 0))
                punti.append(sulla_pelle(Vector((k.x, k.y, k.z + dz)), d, 0.004))
                normali.append(d)
            cinghie.append(striscia(punti, normali, 0.012))
    c.oggetto("Calzari_Cinghie", unisci(*cinghie), "cuoio", spessore=0.002)
    return o


# Elmo (gallico imperiale) --------------------------------------------------------------------------

# L'elmo si disegna attorno a una testa "ideale" e poi si adatta al cranio del corpo vero
# (centro a y -0.0255, z 1.642; mezza larghezza 0.083, mezza profondità 0.104, cima a 1.75).
ADATTA_ELMO = (Matrix.Translation((0, -0.0255, 1.642)) @ Matrix.Diagonal((0.92, 0.95, 1.0, 1.0))
               @ Matrix.Translation((0, -0.004, -1.648)))


def appoggia_alla_guancia(v, distacco):
    """Porta un punto (già adattato) a 'distacco' dalla pelle lungo X, dal suo lato."""
    s = 1 if v.x > 0 else -1
    hit = ALBERO.ray_cast(Vector((s * 0.25, v.y, v.z)), Vector((-s, 0, 0)), 0.25)
    if hit[0] is not None:
        v.x = hit[0].x + s * distacco


def elmo(c):
    def metti(nome, bm, mat, **kw):
        bmesh.ops.transform(bm, matrix=ADATTA_ELMO, verts=bm.verts)
        if nome.startswith("Elmo_Paraguance"):
            for v in bm.verts:
                appoggia_alla_guancia(v.co, 0.005)
        return c.oggetto(nome, bm, mat, **kw)

    centro = Vector((0, 0.004, 1.648))
    bm = sfera(centro, (0.114, 0.128, 0.122), 32, 16)
    # Taglio inclinato: basso dietro (dove parte il paranuca), alto davanti sopra gli occhi.
    piano_co = Vector((0, 0, 1.628))
    piano_no = Vector((0, 0.42, 1)).normalized()
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=piano_co, plane_no=piano_no,
                           clear_inner=True)
    metti("Elmo_Calotta", bm, "acciaio", spessore=-0.005)
    ottone, borchie = [], []
    # Rinforzo sulla fronte: una visiera stretta che sporge.
    bmv = bmesh.new()
    interno, esterno = [], []
    for i in range(25):
        a = math.radians(200 + 140 * i / 24)
        x, y = 0.116 * math.cos(a), 0.13 * math.sin(a) + 0.004
        z = 1.628 - 0.42 * y
        interno.append(bmv.verts.new((x, y, z + 0.004)))
        esterno.append(bmv.verts.new((x * 1.2, y * 1.2 - 0.008, z - 0.004)))
    unisci_anelli(bmv, interno, esterno, chiuso=False)
    metti("Elmo_Visiera", bmv, "acciaio", spessore=0.004)
    # Croce di rinforzo sulla calotta (ottone) e bottone per il pennacchio.
    for asse in ("x", "y"):
        punti, normali = [], []
        for i in range(21):
            a = math.radians(-70 + 140 * i / 20)
            if asse == "x":
                d = Vector((math.sin(a) * 0.116, 0.004, math.cos(a) * 0.124))
            else:
                d = Vector((0, math.sin(a) * 0.130 + 0.004, math.cos(a) * 0.124))
            p = centro + d * 1.04
            punti.append(p)
            normali.append(d)
        ottone.append(striscia(punti, normali, 0.012))
    ottone.append(cilindro(centro + Vector((0, 0, 0.125)), centro + Vector((0, 0, 0.145)), 0.012, 0.009, n=12))
    ottone.append(sfera(centro + Vector((0, 0, 0.152)), (0.014, 0.014, 0.012), 12, 8))
    # Paranuca largo e spiovente.
    sez_basso, sez_alto = [], []
    paranuca = bmesh.new()
    n = 24
    for i in range(n + 1):
        a = math.radians(15 + 150 * i / n)
        x, y = math.cos(a), math.sin(a)
        alto = paranuca.verts.new((0.112 * x, 0.126 * y + 0.004, 1.628 - 0.42 * (0.126 * y + 0.004) + 0.006))
        # Ai lati, vicino alle orecchie, il paranuca scende meno e si allarga meno.
        basso = paranuca.verts.new((0.155 * x, 0.19 * y + 0.01, 1.52 + 0.045 * x * x))
        sez_alto.append(alto)
        sez_basso.append(basso)
    unisci_anelli(paranuca, sez_alto, sez_basso, chiuso=False)
    metti("Elmo_Paranuca", paranuca, "acciaio", spessore=0.004)
    bordo = []
    for i in range(n + 1):
        a = math.radians(15 + 150 * i / n)
        bordo.append(Vector((0.157 * math.cos(a), 0.192 * math.sin(a) + 0.01, 1.518 + 0.045 * math.cos(a) ** 2)))
    ottone.append(striscia(bordo, [(0, 0, 1)] * len(bordo), 0.012))
    # Paraguance: placche curve ai lati del viso, con il bordo d'ottone e due borchie.
    for s in (-1, 1):
        g = bmesh.new()
        righe = []
        for j in range(6):
            t = j / 5
            z = 1.655 - t * 0.12
            larghezza = 0.072 - 0.02 * t ** 2
            riga = []
            for i in range(6):
                u = i / 5
                # Segue la guancia: più stretta verso il mento e piegata indietro verso l'orecchio.
                x = s * (0.074 + 0.026 * u - 0.006 * t)
                y = -0.082 + u * (larghezza + 0.01) + 0.006 * t
                riga.append(g.verts.new((x, y, z)))
            righe.append(riga)
        for j in range(5):
            for i in range(5):
                f = (righe[j][i], righe[j][i + 1], righe[j + 1][i + 1], righe[j + 1][i])
                g.faces.new(f if s > 0 else tuple(reversed(f)))
        metti("Elmo_Paraguance_" + ("d" if s < 0 else "s"), g, "acciaio", spessore=0.004)
        # Borchie sui paraguance: adattate a parte (l'ottone si sposta solo con l'elmo).
        for p in ((s * 0.104, -0.045, 1.6), (s * 0.1, -0.03, 1.555)):
            q = ADATTA_ELMO @ Vector(p)
            appoggia_alla_guancia(q, 0.011)
            borchie.append(sfera(q, (0.005, 0.008, 0.008), 8, 4))
        # Paraorecchie: un bordino sopra l'orecchio.
        ottone.append(tubo_ellittico([((s * 0.112, 0.012, 1.62), 0.004, 0.03), ((s * 0.118, 0.012, 1.625), 0.004, 0.03)],
                                     n=12, inizio=math.radians(-180), fine=0, chiuso=False))
    metti("Elmo_Ottone", unisci(*ottone), "ottone")
    c.oggetto("Elmo_Borchie", unisci(*borchie), "ottone")


# Armi ---------------------------------------------------------------------------------------------------

LANCIA_ASSE = Vector((-0.25, -0.255, 0))


def lancia(c):
    x, y = LANCIA_ASSE.x, LANCIA_ASSE.y
    c.oggetto("Lancia_Asta", cilindro((x, y, 0.06), (x, y, 2.02), 0.0145, 0.0135, n=12), "legno")
    ferro = []
    ferro.append(cilindro((x, y, 2.0), (x, y, 2.08), 0.017, 0.011, n=12))
    # Punta a foglia: losanga schiacciata.
    punta = bmesh.new()
    sezioni = [(2.08, 0.006), (2.12, 0.032), (2.20, 0.024), (2.30, 0.0)]
    anelli = []
    for z, larghezza in sezioni:
        anello = [punta.verts.new((x + larghezza * math.cos(math.radians(a)), y + 0.006 * math.sin(math.radians(a)) *
                                   (1 if larghezza > 0 else 0), z)) for a in range(0, 360, 45)]
        anelli.append(anello)
    for a, b in zip(anelli, anelli[1:]):
        unisci_anelli(punta, a, b)
    ferro.append(punta)
    ferro.append(cilindro((x, y, 0.0), (x, y, 0.07), 0.003, 0.016, n=12))
    c.oggetto("Lancia_Ferro", unisci(*ferro), "ferro")


def gladio(c):
    # Fodero al fianco destro, un po' inclinato con l'elsa in avanti.
    # La punta va indietro, l'elsa in avanti e un poco in fuori.
    base = Matrix.Translation((-0.212, -0.025, 1.04)) @ Matrix.Rotation(math.radians(16), 4, "X") @ \
        Matrix.Rotation(math.radians(-5), 4, "Y")
    fodero = bmesh.new()
    sezioni = [(0.0, 0.03), (-0.36, 0.026), (-0.445, 0.014), (-0.47, 0.0)]
    anelli = []
    for z, mezza in sezioni:
        anello = [fodero.verts.new((mezza * math.cos(math.radians(a)) * (1 if mezza else 0) * 0.35,
                                    mezza * math.sin(math.radians(a)), z)) for a in range(0, 360, 30)]
        anelli.append(anello)
    for a, b in zip(anelli, anelli[1:]):
        unisci_anelli(fodero, a, b)
    bmesh.ops.transform(fodero, matrix=base, verts=fodero.verts)
    c.oggetto("Gladio_Fodero", fodero, "cuoio")
    ottone = []
    for z in (-0.02, -0.10):
        b = scatola((0, 0, z), (0.024, 0.066, 0.018))
        bmesh.ops.transform(b, matrix=base, verts=b.verts)
        ottone.append(b)
    puntale = cilindro((0, 0, -0.41), (0, 0, -0.475), 0.016, 0.004, n=10)
    bmesh.ops.transform(puntale, matrix=base, verts=puntale.verts)
    ottone.append(puntale)
    for s in (-1, 1):
        anello = sfera((0, s * 0.036, -0.06), (0.006, 0.006, 0.01), 8, 4)
        bmesh.ops.transform(anello, matrix=base, verts=anello.verts)
        ottone.append(anello)
    c.oggetto("Gladio_Ottone", unisci(*ottone), "ottone")
    elsa = []
    guardia = sfera((0, 0, 0.018), (0.024, 0.042, 0.016), 12, 8)
    impugnatura = cilindro((0, 0, 0.03), (0, 0, 0.115), 0.014, 0.014, n=12)
    pomo = sfera((0, 0, 0.13), (0.026, 0.03, 0.022), 12, 8)
    for b in (guardia, impugnatura, pomo):
        bmesh.ops.transform(b, matrix=base, verts=b.verts)
        elsa.append(b)
    c.oggetto("Gladio_Elsa", unisci(*elsa), "osso")


SCUDO_ALTEZZA = 1.05
SCUDO_LARGHEZZA = 0.66
SCUDO_RAGGIO = 0.42


def scudo_matrice():
    return Matrix.Translation((0.43, -0.24, 0.0)) @ Matrix.Rotation(math.radians(25), 4, "Z")


def scudo(c):
    m = scudo_matrice()
    meta = SCUDO_LARGHEZZA / SCUDO_RAGGIO / 2
    colonne = 32

    def punto(u, z, fuori=0.0):
        """Punto sul fronte curvo (u da 0 a 1 da sinistra a destra); fuori > 0 sporge davanti."""
        phi = -meta + 2 * meta * u
        r = SCUDO_RAGGIO + fuori
        return Vector((r * math.sin(phi), SCUDO_RAGGIO - r * math.cos(phi), z))

    def faccia(fuori, materiale_nome, uv, rovescia):
        bm = bmesh.new()
        livello = bm.loops.layers.uv.new("UVMap")
        righe = 4
        griglia = [[bm.verts.new(punto(i / colonne, SCUDO_ALTEZZA * j / righe, fuori)) for i in range(colonne + 1)]
                   for j in range(righe + 1)]
        for j in range(righe):
            for i in range(colonne):
                quad = [griglia[j][i], griglia[j][i + 1], griglia[j + 1][i + 1], griglia[j + 1][i]]
                coord = [(i / colonne, j / righe), ((i + 1) / colonne, j / righe), ((i + 1) / colonne, (j + 1) / righe),
                         (i / colonne, (j + 1) / righe)]
                if rovescia:
                    quad.reverse()
                    coord.reverse()
                f = bm.faces.new(quad)
                if uv:
                    for loop, (u, v) in zip(f.loops, coord):
                        loop[livello].uv = (u, v)
        bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
        return c.oggetto("Scudo_" + materiale_nome, bm, materiale_nome)

    faccia(0.0, "scudo", True, False)
    faccia(-0.014, "scudo_retro", False, True)
    # Bordatura d'ottone su tutti i lati.
    bordi = []
    for z in (0.004, SCUDO_ALTEZZA - 0.004):
        punti = [punto(i / colonne, z, -0.007) for i in range(colonne + 1)]
        bordi.append(cilindri_lungo(punti, 0.011))
    for u in (0.0, 1.0):
        punti = [punto(u, SCUDO_ALTEZZA * j / 8, -0.007) for j in range(9)]
        bordi.append(cilindri_lungo(punti, 0.011))
    b = unisci(*bordi)
    bmesh.ops.transform(b, matrix=m, verts=b.verts)
    c.oggetto("Scudo_Bordo", b, "ottone")
    # Umbone: placca curva quadrata e calotta al centro.
    placca = bmesh.new()
    u0, u1 = 0.5 - 0.085 / SCUDO_LARGHEZZA, 0.5 + 0.085 / SCUDO_LARGHEZZA
    z0, z1 = SCUDO_ALTEZZA / 2 - 0.105, SCUDO_ALTEZZA / 2 + 0.105
    griglia = [[placca.verts.new(punto(u0 + (u1 - u0) * i / 6, z0 + (z1 - z0) * j / 2, 0.003)) for i in range(7)]
               for j in range(3)]
    for j in range(2):
        for i in range(6):
            placca.faces.new((griglia[j][i + 1], griglia[j][i], griglia[j + 1][i], griglia[j + 1][i + 1]))
    bmesh.ops.transform(placca, matrix=m, verts=placca.verts)
    c.oggetto("Scudo_Umbone_Placca", placca, "acciaio", spessore=0.004)
    calotta = sfera(punto(0.5, SCUDO_ALTEZZA / 2, 0.006), (0.068, 0.05, 0.068), 20, 12)
    bmesh.ops.transform(calotta, matrix=m, verts=calotta.verts)
    c.oggetto("Scudo_Umbone", calotta, "acciaio")


def cilindri_lungo(punti, raggio):
    pezzi = [cilindro(a, b, raggio, n=8, tappi=False) for a, b in zip(punti, punti[1:])]
    return unisci(*pezzi)


# Tutto ---------------------------------------------------------------------------------------------

def costruisci():
    col = pulisci()
    c = Costruttore(col, materiali())
    corpo_vero = corpo(c)
    tunica(c)
    lorica(c)
    cintura(c)
    balteo(c)
    schinieri(c)
    calzari(c, corpo_vero)
    elmo(c)
    lancia(c)
    gladio(c)
    scudo(c)
    triangoli = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in col.objects if o.type == "MESH")
    return {"oggetti": len(col.objects), "triangoli": triangoli}


if __name__ == "__main__":
    print(costruisci())


# Studio per le foto (fuori dalla collezione del modello) ---------------------------------------------

def studio(larghezza=1080, altezza=1440):
    scena = bpy.context.scene
    col = bpy.data.collections.get("Studio")
    if col is None:
        col = bpy.data.collections.new("Studio")
        scena.collection.children.link(col)
    for o in list(col.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for nome in ("Camera", "Light"):
        o = bpy.data.objects.get(nome)
        if o and o.users_collection and o.users_collection[0].name == "Collection":
            o.hide_render = True
            o.hide_viewport = True

    def luce(nome, tipo, energia, posizione, colore=(1, 1, 1), dimensione=1.0):
        dati = bpy.data.lights.new(nome, tipo)
        dati.energy = energia
        dati.color = colore
        if tipo == "AREA":
            dati.size = dimensione
        o = bpy.data.objects.new(nome, dati)
        o.location = posizione
        col.objects.link(o)
        punta_a(o, Vector((0.05, 0, 1.0)))
        return o

    luce("Chiave", "AREA", 380, (2.6, -3.2, 3.6), (1.0, 0.96, 0.9), 2.0)
    luce("Riempimento", "AREA", 160, (-3.0, -2.4, 1.8), (0.85, 0.9, 1.0), 3.0)
    luce("Controluce", "AREA", 300, (0.5, 3.0, 3.0), (1.0, 0.95, 0.85), 2.0)
    pavimento = bpy.data.meshes.new("Pavimento")
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=True, segments=64, radius=3.0)
    bm.to_mesh(pavimento)
    bm.free()
    o = bpy.data.objects.new("Pavimento", pavimento)
    o.data.materials.append(materiale("Pavimento", (0.30, 0.26, 0.20), ruvidita=0.95))
    col.objects.link(o)
    mondo = scena.world or bpy.data.worlds.new("Mondo")
    scena.world = mondo
    mondo.use_nodes = True
    sfondo = mondo.node_tree.nodes.get("Background")
    sfondo.inputs["Color"].default_value = (0.36, 0.39, 0.44, 1)
    sfondo.inputs["Strength"].default_value = 0.5
    camera = bpy.data.objects.new("Fotocamera", bpy.data.cameras.new("Fotocamera"))
    camera.data.lens = 50
    col.objects.link(camera)
    scena.camera = camera
    scena.render.engine = "BLENDER_EEVEE"
    scena.render.resolution_x = larghezza
    scena.render.resolution_y = altezza
    scena.render.resolution_percentage = 100
    scena.render.image_settings.file_format = "JPEG"
    scena.render.image_settings.quality = 88
    scena.view_settings.view_transform = "Standard"
    return camera


def punta_a(o, bersaglio):
    direzione = bersaglio - o.location
    o.rotation_euler = direzione.to_track_quat("-Z", "Y").to_euler()


def foto(percorso, azimut=-25, elevazione=6, distanza=4.6, bersaglio=(0.08, 0, 1.12), lente=50):
    """azimut 0 = davanti al soldato."""
    camera = bpy.context.scene.camera or studio()
    camera.data.lens = lente
    a, e = math.radians(azimut), math.radians(elevazione)
    b = Vector(bersaglio)
    camera.location = b + Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * distanza
    punta_a(camera, b)
    bpy.context.scene.render.filepath = percorso
    bpy.ops.render.render(write_still=True)
    return percorso
