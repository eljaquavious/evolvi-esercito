"""Legionario romano (I-II secolo d.C.) per Evolvi Esercito, costruito da zero in Blender.

Si esegue dentro Blender (anche via MCP): cancella la collezione "Legionario" e la ricostruisce.
Il personaggio guarda verso -Y, alto circa 1,75 m; la sua destra è verso -X.
Riferimenti: le due illustrazioni mandate da Mattia (lorica segmentata, elmo gallico imperiale,
tunica rossa, cingulum con grembiule borchiato, gladio a destra, lancia, scutum rosso con ali e fulmini).
La texture dello scudo si genera con tools/blender/scudo_texture.py e si carica a parte
(immagine "LG_Scudo" in Blender); senza, lo scudo resta rosso pieno.
"""

import math

import bmesh
import bpy
from mathutils import Matrix, Vector

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
        "acciaio": materiale("Acciaio", (0.78, 0.79, 0.80), metallo=1.0, ruvidita=0.28),
        "ottone": materiale("Ottone", (0.86, 0.62, 0.26), metallo=1.0, ruvidita=0.32),
        "cuoio": materiale("Cuoio", (0.22, 0.11, 0.05), ruvidita=0.65),
        "cuoio_chiaro": materiale("CuoioChiaro", (0.42, 0.24, 0.12), ruvidita=0.7),
        "legno": materiale("Legno", (0.42, 0.27, 0.14), ruvidita=0.7),
        "ferro": materiale("Ferro", (0.32, 0.32, 0.34), metallo=1.0, ruvidita=0.45),
        "occhi": materiale("Occhi", (0.04, 0.03, 0.02), ruvidita=0.3),
        "scudo": materiale("Scudo", (0.62, 0.10, 0.08), ruvidita=0.6, immagine=immagine),
        "scudo_retro": materiale("ScudoRetro", (0.30, 0.18, 0.09), ruvidita=0.8),
        "osso": materiale("Osso", (0.86, 0.80, 0.66), ruvidita=0.5),
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
    for me in list(bpy.data.meshes):
        if me.users == 0:
            bpy.data.meshes.remove(me)
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

# Scheletro per il modificatore Skin: punto -> (posizione, raggio x, raggio y).
SCHELETRO = {
    "bacino": ((0, 0.0, 0.95), 0.15, 0.11),
    "vita": ((0, 0.0, 1.10), 0.135, 0.10),
    "petto": ((0, 0.0, 1.27), 0.16, 0.11),
    "spalle": ((0, 0.0, 1.38), 0.15, 0.10),
    "collo": ((0, 0.0, 1.47), 0.062, 0.062),
    "nuca": ((0, 0.0, 1.54), 0.058, 0.058),
    "spalla_d": ((-0.18, 0.0, 1.40), 0.058, 0.058),
    "gomito_d": ((-0.25, 0.03, 1.13), 0.043, 0.043),
    "avambraccio_d": ((-0.25, -0.08, 1.15), 0.045, 0.045),
    "polso_d": ((-0.25, -0.20, 1.17), 0.032, 0.032),
    "spalla_s": ((0.18, 0.0, 1.40), 0.058, 0.058),
    "gomito_s": ((0.30, -0.02, 1.16), 0.043, 0.043),
    "avambraccio_s": ((0.31, -0.13, 1.12), 0.045, 0.045),
    "polso_s": ((0.32, -0.24, 1.08), 0.032, 0.032),
    "anca_d": ((-0.09, 0.0, 0.92), 0.085, 0.085),
    "coscia_d": ((-0.10, -0.005, 0.72), 0.078, 0.078),
    "ginocchio_d": ((-0.11, -0.01, 0.52), 0.055, 0.055),
    "polpaccio_d": ((-0.115, 0.01, 0.34), 0.06, 0.06),
    "caviglia_d": ((-0.12, 0.02, 0.10), 0.04, 0.04),
    "anca_s": ((0.09, 0.0, 0.92), 0.085, 0.085),
    "coscia_s": ((0.10, -0.005, 0.72), 0.078, 0.078),
    "ginocchio_s": ((0.11, -0.01, 0.52), 0.055, 0.055),
    "polpaccio_s": ((0.115, 0.01, 0.34), 0.06, 0.06),
    "caviglia_s": ((0.12, 0.02, 0.10), 0.04, 0.04),
}
OSSA = [
    ("bacino", "vita"), ("vita", "petto"), ("petto", "spalle"), ("spalle", "collo"), ("collo", "nuca"),
    ("spalle", "spalla_d"), ("spalla_d", "gomito_d"), ("gomito_d", "avambraccio_d"), ("avambraccio_d", "polso_d"),
    ("spalle", "spalla_s"), ("spalla_s", "gomito_s"), ("gomito_s", "avambraccio_s"), ("avambraccio_s", "polso_s"),
    ("bacino", "anca_d"), ("anca_d", "coscia_d"), ("coscia_d", "ginocchio_d"), ("ginocchio_d", "polpaccio_d"),
    ("polpaccio_d", "caviglia_d"),
    ("bacino", "anca_s"), ("anca_s", "coscia_s"), ("coscia_s", "ginocchio_s"), ("ginocchio_s", "polpaccio_s"),
    ("polpaccio_s", "caviglia_s"),
]


def P(nome):
    return Vector(SCHELETRO[nome][0])


def corpo(c):
    bm = bmesh.new()
    pelle = bm.verts.layers.skin.verify()
    indici = {}
    for nome, (pos, rx, ry) in SCHELETRO.items():
        v = bm.verts.new(pos)
        v[pelle].radius = (rx, ry)
        indici[nome] = v
    indici["bacino"][pelle].use_root = True
    for a, b in OSSA:
        bm.edges.new((indici[a], indici[b]))
    me = bpy.data.meshes.new("Corpo")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("Corpo", me)
    c.col.objects.link(o)
    o.parent = c.radice
    skin = o.modifiers.new("Skin", "SKIN")
    skin.branch_smoothing = 0.6
    skin.use_smooth_shade = True
    sub = o.modifiers.new("Liscio", "SUBSURF")
    sub.levels = 1
    sub.render_levels = 1
    o.data.materials.append(c.mat["pelle"])
    applica(o)
    for poligono in o.data.polygons:
        poligono.use_smooth = True
    return o


def testa(c):
    centro = Vector((0, -0.012, 1.635))
    bm = sfera(centro, (0.078, 0.098, 0.112), 24, 16)
    for v in bm.verts:
        d = v.co - centro
        # Mascella più stretta in basso e mento in avanti; nuca piena.
        if d.z < 0:
            f = 1 - 0.28 * (-d.z / 0.112)
            v.co.x = centro.x + d.x * f
            if d.y < 0:
                v.co.y = centro.y + d.y * (1 + 0.08 * (-d.z / 0.112))
        if d.y > 0:
            v.co.y = centro.y + d.y * 1.05
    c.oggetto("Testa", bm, "pelle")
    # Naso: un piccolo cuneo sul viso.
    naso = bmesh.new()
    punta = naso.verts.new((0, -0.128, 1.615))
    base = [naso.verts.new(p) for p in ((-0.016, -0.104, 1.6), (0.016, -0.104, 1.6), (0, -0.106, 1.655))]
    naso.faces.new((base[0], base[1], punta))
    naso.faces.new((base[1], base[2], punta))
    naso.faces.new((base[2], base[0], punta))
    naso.faces.new((base[2], base[1], base[0]))
    c.oggetto("Naso", naso, "pelle", liscio=False)
    occhi = unisci(*(sfera((s * 0.031, -0.0985, 1.648), (0.010, 0.005, 0.0065), 10, 6) for s in (-1, 1)))
    c.oggetto("Occhi", occhi, "occhi")
    sopracciglia = unisci(*(scatola((s * 0.032, -0.1, 1.663), (0.03, 0.008, 0.006)) for s in (-1, 1)))
    bocca = scatola((0, -0.0985, 1.579), (0.03, 0.006, 0.004))
    c.oggetto("Sopracciglia", unisci(sopracciglia, bocca), "cuoio")
    # Orecchie (si vedono appena sotto i paraguance).
    orecchie = unisci(*(sfera((s * 0.08, 0.0, 1.635), (0.012, 0.022, 0.03), 10, 6) for s in (-1, 1)))
    c.oggetto("Orecchie", orecchie, "pelle")


def mani(c):
    # Destra: pugno chiuso attorno all'asta della lancia.
    asta = LANCIA_ASSE
    pugno = sfera((asta.x + 0.004, asta.y + 0.006, 1.165), (0.034, 0.042, 0.05), 14, 10)
    pollice = sfera((asta.x + 0.02, asta.y - 0.03, 1.19), (0.012, 0.012, 0.024), 8, 6)
    c.oggetto("ManoDestra", unisci(pugno, pollice), "pelle")
    # Sinistra: appoggiata sul bordo dello scudo, dita oltre il bordo.
    m = scudo_matrice()
    palmo = sfera((0, 0, 0), (0.045, 0.03, 0.018), 12, 8)
    bmesh.ops.transform(palmo, matrix=m @ Matrix.Translation((-0.13, 0.005, SCUDO_ALTEZZA + 0.018)), verts=palmo.verts)
    dita = sfera((0, 0, 0), (0.04, 0.012, 0.035), 10, 6)
    bmesh.ops.transform(dita, matrix=m @ Matrix.Translation((-0.13, -0.022, SCUDO_ALTEZZA - 0.012)), verts=dita.verts)
    c.oggetto("ManoSinistra", unisci(palmo, dita), "pelle")


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
    # Focale: sciarpa annodata al collo.
    sciarpa = tubo_ellittico([((0, -0.005, 1.425), 0.088, 0.078), ((0, -0.01, 1.46), 0.082, 0.074),
                              ((0, -0.006, 1.495), 0.07, 0.066), ((0, -0.004, 1.51), 0.064, 0.06)], n=32)
    c.oggetto("Focale", sciarpa, "tunica", spessore=0.012)


# Lorica segmentata -----------------------------------------------------------------------------------

def busto(z):
    """Raggi (x, y) dell'armatura alla quota z: segue il busto e ci sta sopra."""
    t = max(0.0, min(1.0, (z - 0.98) / (1.30 - 0.98)))
    return 0.178 + 0.012 * t, 0.137 + 0.008 * t


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
    sez = [((0, 0.0, 1.29), 0.19, 0.146), ((0, 0.0, 1.36), 0.175, 0.138), ((0, 0.0, 1.41), 0.14, 0.115),
           ((0, 0.0, 1.445), 0.10, 0.09)]
    petto = tubo_ellittico(sez, n=64)
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
    """Tracolla dalla spalla sinistra al fianco destro, davanti e dietro."""
    def lungo(davanti):
        segno = -1 if davanti else 1
        punti, normali = [], []
        for i in range(13):
            t = i / 12
            x = 0.12 - t * 0.31
            z = 1.425 - t * 0.43
            rx, ry = busto(z)
            rx += 0.012
            ry += 0.013
            if z > 1.29:
                rx, ry = 0.19 - (z - 1.29) * 0.9, 0.146 - (z - 1.29) * 0.5
            xx = max(-rx * 0.98, min(rx * 0.98, x))
            y = segno * ry * math.sqrt(max(0.0, 1 - (xx / rx) ** 2))
            punti.append((xx, y, z))
            normali.append((xx / rx, y / ry, 0.2))
        return striscia(punti, normali, 0.03)
    sopra = []
    for i in range(7):
        a = math.radians(i * 30)
        sopra.append((0.125, -0.10 * math.cos(a), 1.425 + 0.045 * math.sin(a)))
    norm_sopra = [(0.3, -math.cos(math.radians(i * 30)), math.sin(math.radians(i * 30))) for i in range(7)]
    c.oggetto("Balteo", unisci(lungo(True), lungo(False), striscia(sopra, norm_sopra, 0.03)), "cuoio",
              spessore=0.004)


# Gambe e piedi ---------------------------------------------------------------------------------------

def schinieri(c):
    gusci, lacci = [], []
    for lato in ("d", "s"):
        ginocchio, caviglia = P("ginocchio_" + lato), P("caviglia_" + lato)
        sezioni = []
        for i in range(8):
            t = i / 7
            p = ginocchio.lerp(caviglia, 0.04 + t * 0.8)
            r = 0.072 - t * 0.016
            sezioni.append(((p.x, p.y - 0.004, p.z), r, r * 0.95))
        # Solo la parte davanti della gamba (da -160 a -20 gradi), come un guscio.
        gusci.append(tubo_ellittico(list(reversed(sezioni)), n=16, inizio=math.radians(200),
                                    fine=math.radians(340), chiuso=False))
        # Ginocchiera: la parte alta dello schiniere si gonfia sulla rotula.
        rotula = ginocchio + Vector((0, -0.056, -0.006))
        gusci.append(sfera(rotula, (0.04, 0.016, 0.042), 12, 8))
        for t in (0.3, 0.7):
            p = ginocchio.lerp(caviglia, 0.12 + t * 0.72)
            r = 0.07 - t * 0.016
            lacci.append(tubo_ellittico([((p.x, p.y, p.z - 0.008), r, r), ((p.x, p.y, p.z + 0.008), r, r)], n=16,
                                        inizio=math.radians(-20), fine=math.radians(200), chiuso=False))
    c.oggetto("Schinieri", unisci(*gusci), "acciaio", spessore=0.004)
    c.oggetto("Schinieri_Lacci", unisci(*lacci), "cuoio", spessore=0.003)


def calzari(c):
    pezzi, suole = [], []
    for lato in ("d", "s"):
        cav = P("caviglia_" + lato)
        x = cav.x
        piede = sfera((x, -0.05, 0.045), (0.052, 0.13, 0.05), 16, 10)
        for v in piede.verts:
            if v.co.z < 0.012:
                v.co.z = 0.012
        collo = cilindro((x, 0.015, 0.03), (x, 0.02, 0.15), 0.048, 0.044, n=16)
        pezzi += [piede, collo]
        suole.append(scatola((x, -0.05, 0.007), (0.1, 0.26, 0.014)))
        for z in (0.06, 0.10, 0.14):
            suole.append(tubo_ellittico([((x, 0.02, z - 0.006), 0.051, 0.051), ((x, 0.02, z + 0.006), 0.05, 0.05)],
                                        n=16))
    c.oggetto("Calzari", unisci(*pezzi), "cuoio_chiaro")
    c.oggetto("Calzari_Suole", unisci(*suole), "cuoio")


# Elmo (gallico imperiale) --------------------------------------------------------------------------

def elmo(c):
    centro = Vector((0, 0.004, 1.648))
    bm = sfera(centro, (0.114, 0.128, 0.122), 32, 16)
    # Taglio inclinato: basso dietro (dove parte il paranuca), alto davanti sopra gli occhi.
    piano_co = Vector((0, 0, 1.628))
    piano_no = Vector((0, 0.42, 1)).normalized()
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=piano_co, plane_no=piano_no,
                           clear_inner=True)
    c.oggetto("Elmo_Calotta", bm, "acciaio", spessore=-0.005)
    ottone = []
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
    c.oggetto("Elmo_Visiera", bmv, "acciaio", spessore=0.004)
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
        basso = paranuca.verts.new((0.165 * x, 0.19 * y + 0.01, 1.52))
        sez_alto.append(alto)
        sez_basso.append(basso)
    unisci_anelli(paranuca, sez_alto, sez_basso, chiuso=False)
    c.oggetto("Elmo_Paranuca", paranuca, "acciaio", spessore=0.004)
    bordo = []
    for i in range(n + 1):
        a = math.radians(15 + 150 * i / n)
        bordo.append(Vector((0.167 * math.cos(a), 0.192 * math.sin(a) + 0.01, 1.518)))
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
        c.oggetto("Elmo_Paraguance_" + ("d" if s < 0 else "s"), g, "acciaio", spessore=0.004)
        ottone.append(sfera((s * 0.104, -0.045, 1.6), (0.005, 0.008, 0.008), 8, 4))
        ottone.append(sfera((s * 0.1, -0.03, 1.555), (0.005, 0.008, 0.008), 8, 4))
        # Paraorecchie: un bordino sopra l'orecchio.
        ottone.append(tubo_ellittico([((s * 0.112, 0.012, 1.62), 0.004, 0.03), ((s * 0.118, 0.012, 1.625), 0.004, 0.03)],
                                     n=12, inizio=math.radians(-180), fine=0, chiuso=False))
    c.oggetto("Elmo_Ottone", unisci(*ottone), "ottone")


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
    base = Matrix.Translation((-0.212, -0.02, 1.0)) @ Matrix.Rotation(math.radians(16), 4, "X") @ \
        Matrix.Rotation(math.radians(-5), 4, "Y")
    fodero = bmesh.new()
    sezioni = [(0.0, 0.03), (-0.40, 0.026), (-0.50, 0.014), (-0.53, 0.0)]
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
    puntale = cilindro((0, 0, -0.46), (0, 0, -0.535), 0.016, 0.004, n=10)
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
    corpo(c)
    testa(c)
    mani(c)
    tunica(c)
    lorica(c)
    cintura(c)
    balteo(c)
    schinieri(c)
    calzari(c)
    elmo(c)
    # Testa ed elmo un poco più giù: il collo restava troppo lungo.
    for o in list(c.col.objects):
        if o.type == "MESH" and o.name.split("_")[0] in ("Testa", "Naso", "Occhi", "Sopracciglia", "Orecchie", "Elmo"):
            o.data.transform(Matrix.Translation((0, 0, -0.022)))
    lancia(c)
    gladio(c)
    scudo(c)
    triangoli = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in col.objects if o.type == "MESH")
    return {"oggetti": len(col.objects), "triangoli": triangoli}


if __name__ == "__main__":
    print(costruisci())
