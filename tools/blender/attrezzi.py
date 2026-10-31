"""Attrezzi comuni per i modelli fatti con bmesh (oggetti della lobby): forme smussate, tornio, atlante.

Assi di Blender: Z in alto, il davanti verso -Y. Misure in studs. Ogni forma si aggiunge a un Pezzo con il
nome di una cella dell'atlante (il colore/materiale); i pezzi "da tingere" non hanno texture e il gioco li
colora con MeshPart.Color.
"""
import math

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

LATO_ATLANTE = 1024
CELLA = 256
MARGINE = 10
PER_RIGA = LATO_ATLANTE // CELLA


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])


# Trasformazioni ------------------------------------------------------------------------------------

def T(x=0, y=0, z=0):
    return Matrix.Translation((x, y, z))


def R(asse, gradi):
    return Matrix.Rotation(math.radians(gradi), 4, asse)


def S(x, y=None, z=None):
    return Matrix.Diagonal((x, x if y is None else y, x if z is None else z, 1))


DAVANTI = R("X", 90)   # l'asse Z di una forma verso -Y
FIANCO = R("Y", 90)    # l'asse Z di una forma lungo X


# Rumore e celle ------------------------------------------------------------------------------------

def rumore(lato, celle, seme):
    rng = np.random.default_rng(seme)
    g = rng.random((celle + 1, celle + 1))
    g[-1, :] = g[0, :]
    g[:, -1] = g[:, 0]
    t = np.linspace(0, celle, lato, endpoint=False)
    i = t.astype(int)
    f = t - i
    f = f * f * (3 - 2 * f)
    a = g[np.ix_(i, i)]
    b = g[np.ix_(i, i + 1)]
    c = g[np.ix_(i + 1, i)]
    d = g[np.ix_(i + 1, i + 1)]
    fx = f[None, :]
    fy = f[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def cella_legno(colore, seme):
    n = CELLA
    y = np.mgrid[0:n, 0:n][0] / n
    onda = rumore(n, 4, seme) * 0.08 + rumore(n, 9, seme + 1) * 0.02
    righe = (np.sin((y + onda) * math.pi * 26) * 0.5 + 0.5) ** 3
    fibre = rumore(n, 32, seme + 2)
    fibre = np.repeat(fibre[:, :1], n, axis=1) * 0.6 + fibre * 0.4
    chiaro = 1.0 - righe * 0.22 - (fibre - 0.5) * 0.12 + (rumore(n, 3, seme + 3) - 0.5) * 0.1
    return colore[None, None, :] * chiaro[..., None]


def cella_metallo(colore, seme, ruvido=0.06):
    n = CELLA
    y = np.mgrid[0:n, 0:n][0] / n
    chiaro = 1.04 - y * 0.1 + (rumore(n, 24, seme) - 0.5) * ruvido + (rumore(n, 6, seme + 1) - 0.5) * ruvido
    return colore[None, None, :] * chiaro[..., None]


def cella_pietra(colore, seme):
    n = CELLA
    chiaro = 0.92 + (rumore(n, 6, seme) - 0.5) * 0.16 + (rumore(n, 40, seme + 1) - 0.5) * 0.14
    macchie = (rumore(n, 64, seme + 2) > 0.82) * -0.08
    return colore[None, None, :] * (chiaro + macchie)[..., None]


def cella_marmo(colore, seme):
    n = CELLA
    y, x = np.mgrid[0:n, 0:n] / n
    v = np.sin((x * 3 + y * 5 + rumore(n, 5, seme) * 2.5) * math.pi * 2)
    vene = np.exp(-(v ** 2) * 40) * 0.18
    chiaro = 0.98 - vene + (rumore(n, 30, seme + 1) - 0.5) * 0.05
    return colore[None, None, :] * chiaro[..., None]


def cella_tessuto(colore, seme):
    n = CELLA
    y, x = np.mgrid[0:n, 0:n]
    trama = ((x % 4 < 2) ^ (y % 4 < 2)) * 0.05
    chiaro = 0.92 + trama + (rumore(n, 20, seme) - 0.5) * 0.12
    return colore[None, None, :] * chiaro[..., None]


def cella_brace(seme):
    n = CELLA
    r = rumore(n, 16, seme)
    caldo = np.clip((r - 0.35) * 2.2, 0, 1)
    nero = hexc("#2A1A12")
    rosso = hexc("#FF5A1A")
    giallo = hexc("#FFD24A")
    c = nero[None, None, :] * (1 - caldo[..., None]) + rosso[None, None, :] * caldo[..., None]
    picchi = np.clip((r - 0.7) * 4, 0, 1)[..., None]
    return c * (1 - picchi) + giallo[None, None, :] * picchi


def cella_carta(colore, seme):
    n = CELLA
    chiaro = 0.95 + (rumore(n, 8, seme) - 0.5) * 0.14 + (rumore(n, 50, seme + 1) - 0.5) * 0.05
    return colore[None, None, :] * chiaro[..., None]


def cella_liscia(colore, seme=0, var=0.04):
    n = CELLA
    y = np.mgrid[0:n, 0:n][0] / n
    chiaro = 1.02 - y * 0.06 + (rumore(n, 12, seme) - 0.5) * var
    return colore[None, None, :] * chiaro[..., None]


def atlante(celle, file):
    """celle: elenco di (nome, immagine CELLAxCELLAx3) nell'ordine; restituisce l'immagine di Blender e
    il dizionario nome -> indice."""
    img = np.zeros((LATO_ATLANTE, LATO_ATLANTE, 3))
    indici = {}
    for i, (nome, c) in enumerate(celle):
        r, k = divmod(i, PER_RIGA)
        img[r * CELLA:(r + 1) * CELLA, k * CELLA:(k + 1) * CELLA] = np.clip(c, 0, 1)
        indici[nome] = i
    im = bpy.data.images.new("atlante", LATO_ATLANTE, LATO_ATLANTE, alpha=False)
    pixel = np.ones((LATO_ATLANTE, LATO_ATLANTE, 4), dtype=np.float32)
    pixel[..., :3] = img[::-1]
    im.pixels.foreach_set(pixel.ravel())
    im.filepath_raw = file
    im.file_format = "PNG"
    im.save()
    return im, indici


# Forme ---------------------------------------------------------------------------------------------

def smussa(bm, larghezza, segmenti=2, angolo=30):
    spigoli = [e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0) > math.radians(angolo)]
    if spigoli and larghezza > 0.001:
        bmesh.ops.bevel(bm, geom=spigoli, offset=larghezza, offset_type="OFFSET", segments=segmenti,
                        profile=0.5, affect="EDGES", clamp_overlap=True)
    return bm


def scatola(misure, smusso=0.04, segmenti=2):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(misure), verts=bm.verts)
    return smussa(bm, min(smusso, min(misure) * 0.45), segmenti)


def cilindro(r, alto, lati=20, smusso=0.03, r2=None):
    """Cilindro (o tronco di cono) sull'asse Z, centrato; spigoli dei tappi smussati."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=lati, radius1=r,
                          radius2=r if r2 is None else r2, depth=alto)
    return smussa(bm, min(smusso, r * 0.4, alto * 0.4), 2, 40) if smusso else bm


def sfera(r, schiaccia=1.0, u=12, v=8):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=r)
    if schiaccia != 1.0:
        bmesh.ops.scale(bm, vec=Vector((1, 1, schiaccia)), verts=bm.verts)
    return bm


def sasso(r, seme, suddivisioni=1):
    """Pezzo di carbone o pietra: icosfera deformata."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=suddivisioni, radius=r)
    rng = np.random.default_rng(seme)
    for v in bm.verts:
        v.co *= 0.8 + rng.random() * 0.35
    return bm


def toro(r, spessore, lati=24, sezione=8, arco=360.0):
    bm = bmesh.new()
    chiuso = arco >= 359.9
    n = lati if chiuso else lati + 1
    anelli = []
    for i in range(n):
        a = math.radians(arco) * i / lati
        c = Vector((math.cos(a) * r, math.sin(a) * r, 0))
        d = Vector((math.cos(a), math.sin(a), 0))
        anelli.append([bm.verts.new(c + d * math.cos(b) * spessore + Vector((0, 0, math.sin(b) * spessore)))
                       for b in (2 * math.pi * k / sezione for k in range(sezione))])
    for i in range(lati if chiuso else lati):
        a, b = anelli[i], anelli[(i + 1) % n]
        for k in range(sezione):
            k2 = (k + 1) % sezione
            bm.faces.new((a[k], b[k], b[k2], a[k2]))
    if not chiuso:
        bm.faces.new(anelli[0][::-1])
        bm.faces.new(anelli[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def tornio(profilo, lati=24, chiudi_sotto=True, chiudi_sopra=True):
    """Solido di rotazione attorno a Z: profilo = [(raggio, z), ...] dal basso in alto."""
    bm = bmesh.new()
    anelli = []
    for r, z in profilo:
        if r < 1e-4:
            anelli.append([bm.verts.new((0, 0, z))])
        else:
            anelli.append([bm.verts.new((math.cos(2 * math.pi * i / lati) * r, math.sin(2 * math.pi * i / lati) * r, z))
                           for i in range(lati)])
    for a, b in zip(anelli, anelli[1:]):
        if len(a) == 1 and len(b) == 1:
            continue
        if len(a) == 1:
            for i in range(lati):
                bm.faces.new((a[0], b[i], b[(i + 1) % lati]))
        elif len(b) == 1:
            for i in range(lati):
                bm.faces.new((a[i], b[0], a[(i + 1) % lati]))
        else:
            for i in range(lati):
                j = (i + 1) % lati
                bm.faces.new((a[i], a[j], b[j], b[i]))
    if chiudi_sotto and len(anelli[0]) > 1:
        bm.faces.new(anelli[0][::-1])
    if chiudi_sopra and len(anelli[-1]) > 1:
        bm.faces.new(anelli[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def prisma(profilo, x0, x1, smusso=0.03):
    """Profilo convesso [(y, z), ...] estruso lungo X da x0 a x1."""
    bm = bmesh.new()
    a = [bm.verts.new((x0, y, z)) for y, z in profilo]
    b = [bm.verts.new((x1, y, z)) for y, z in profilo]
    n = len(profilo)
    bm.faces.new(a[::-1])
    bm.faces.new(b)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return smussa(bm, smusso, 2) if smusso else bm


def tubo(punti, r, lati=10):
    """Tubo lungo una polilinea (punti Vector), con i tappi: catene, sbarre piegate."""
    bm = bmesh.new()
    anelli = []
    for i, p in enumerate(punti):
        if i == 0:
            d = punti[1] - p
        elif i == len(punti) - 1:
            d = p - punti[i - 1]
        else:
            d = (punti[i + 1] - punti[i - 1])
        d.normalize()
        su = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
        a = d.cross(su).normalized()
        b = d.cross(a).normalized()
        anelli.append([bm.verts.new(p + (a * math.cos(t) + b * math.sin(t)) * r)
                       for t in (2 * math.pi * k / lati for k in range(lati))])
    for x, y in zip(anelli, anelli[1:]):
        for k in range(lati):
            k2 = (k + 1) % lati
            bm.faces.new((x[k], x[k2], y[k2], y[k]))
    bm.faces.new(anelli[0][::-1])
    bm.faces.new(anelli[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


# Pezzi e mesh --------------------------------------------------------------------------------------

class Pezzo:
    """Raccoglie le forme di un oggetto in un solo bmesh; ogni faccia ricorda la cella dell'atlante."""

    def __init__(self, nome, indici=None):
        self.nome = nome
        self.indici = indici or {}
        self.bm = bmesh.new()
        self.punti = {}  # nome -> [Vector]: dove il gioco mette fuochi, luci, scritte

    def aggiungi(self, bm, cella, matrice=None):
        if matrice is not None:
            bm.transform(matrice)
        indice = self.indici.get(cella, 0)
        for f in bm.faces:
            f.material_index = indice
        me = bpy.data.meshes.new("tmp")
        bm.to_mesh(me)
        bm.free()
        self.bm.from_mesh(me)
        bpy.data.meshes.remove(me)

    def punto(self, nome, posizione):
        self.punti.setdefault(nome, []).append(Vector(posizione))


def finisci(pezzo, materiale=None, ampio=8.0, centro_v=0.0, angolo_liscio=50, sfaccettate=()):
    """Mesh finale: triangoli, normali lisce sotto "angolo_liscio", UV proiettate nella cella di ogni faccia
    ("ampio" = studs coperti da una cella, centrati sull'origine e su "centro_v" in altezza). Senza materiale:
    niente UV né texture (pezzo da tingere)."""
    bm = pezzo.bm
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        if len(e.link_faces) != 2:
            e.smooth = False
            continue
        a, b = e.link_faces
        e.smooth = not (a.material_index != b.material_index or a.material_index in sfaccettate
                        or e.calc_face_angle(0) > math.radians(angolo_liscio))
    if materiale is not None:
        uv = bm.loops.layers.uv.new("UVMap")
        for f in bm.faces:
            r, k = divmod(f.material_index, PER_RIGA)
            n = f.normal
            ax = max(range(3), key=lambda i: abs(n[i]))
            for l in f.loops:
                p = l.vert.co
                u, v = ((p.y, p.z), (p.x, p.z), (p.x, p.y))[ax]
                # Senza ripetizione (una faccia a cavallo del bordo si stirerebbe su tutta la cella):
                # "ampio" deve coprire tutto l'oggetto.
                u = min(max(0.5 + u / ampio, 0), 1)
                v = min(max(0.5 + (v - centro_v) / ampio, 0), 1)
                px = k * CELLA + MARGINE + u * (CELLA - 2 * MARGINE)
                py = r * CELLA + MARGINE + v * (CELLA - 2 * MARGINE)
                l[uv].uv = (px / LATO_ATLANTE, 1 - py / LATO_ATLANTE)
    me = bpy.data.meshes.new(pezzo.nome)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.material_index = 0
    if materiale is not None:
        me.materials.append(materiale)
    ob = bpy.data.objects.new(pezzo.nome, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def materiale_atlante(img, nome="Atlante"):
    mat = bpy.data.materials.new(nome)
    mat.use_nodes = True
    nodi = mat.node_tree.nodes
    bsdf = nodi.get("Principled BSDF")
    tex = nodi.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Linear"
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.7
    return mat


def ingombro(ob):
    vs = np.array([v.co[:] for v in ob.data.vertices])
    return vs.min(0), vs.max(0)


def roblox(v):
    """Da Blender a Roblox: x = -x, y = z, z = y (come tools/blocchi/esporta_fbx.py)."""
    return [-float(v[0]), float(v[2]), float(v[1])]
