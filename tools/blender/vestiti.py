"""Attrezzi comuni per vestire il corpo realistico di umano.py: costruttore, forme di base, misure sul
corpo in posa (tuniche, maniche e calzature prese dalla pelle vera), armi e scudi ricorrenti.

Ogni truppa (arciere_cretese.py, ...) crea una Unita, sceglie la posa, chiama corpo() e poi i pezzi.
Convenzioni come il legionario: il soldato guarda verso -Y, la sua destra è -X, alto circa 1,75 m.
"""

import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

if "umano" not in sys.modules and "__file__" in globals():
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import umano  # noqa: E402

NOMI_GIUNTI = {"spalla": ("braccio", 0), "gomito": ("braccio", 1), "polso": ("mano", 0),
               "ginocchio": ("stinco", 0), "caviglia": ("stinco", 1), "punta": ("piede", 1),
               "anca": ("coscia", 0)}


# Unità: collezione, materiali, oggetti --------------------------------------------------------------

class Unita:
    def __init__(self, nome, sigla):
        self.nome = nome
        self.sigla = sigla
        self.col = pulisci(nome, sigla)
        self.radice = bpy.data.objects.new(nome, None)
        self.col.objects.link(self.radice)
        self.mat = {}
        self.giunti = {}
        self.albero = None
        self.corpo = None
        self.coperti = []   # pezzi che coprono la pelle (per nascondere quella sotto)

    def materiale(self, chiave, colore, metallo=0.0, ruvidita=0.6, immagine=None):
        nome = self.sigla + "_" + chiave
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
        self.mat[chiave] = m
        return m

    def oggetto(self, nome, bm, mat, liscio=True, spessore=0.0, suddividi=0, copre=False):
        me = bpy.data.meshes.new(nome)
        bm.normal_update()
        if copre:
            # La superficie prima dello spessore, con le normali verso fuori: è il lato interno della stoffa.
            self.coperti.append(BVHTree.FromBMesh(bm))
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

    # Corpo e misure ------------------------------------------------------------------------------

    def costruisci_corpo(self, posa, pelle=(0.46, 0.25, 0.155), barba=0.55, capelli=True):
        corpo, altri, giunti = umano.costruisci_corpo(self.col, posa, pelle=pelle)
        if barba != 0.55 or not capelli:
            umano.colora(corpo, barba=barba, capelli=capelli)
        self.giunti = giunti
        for o in [corpo] + altri:
            o.parent = self.radice
        self.corpo = corpo
        self.albero = umano.albero(corpo.data)
        return corpo

    def P(self, nome):
        """Articolazione in posa: 'gomito_d', 'caviglia_s'... (d = destra del soldato, verso -X)."""
        giunto, lato = nome.rsplit("_", 1)
        osso, estremo = NOMI_GIUNTI[giunto]
        return Vector(self.giunti[osso + (".R" if lato == "d" else ".L")][estremo])

    def sulla_pelle(self, centro, direzione, distacco, portata=0.2):
        hit = self.albero.ray_cast(centro, direzione, portata)
        if hit[0] is None:
            return centro + direzione * 0.06
        return hit[0] + direzione * distacco

    def fuori_dalla_pelle(self, v, distacco):
        loc, normale, _, _ = self.albero.find_nearest(v)
        if loc is not None and (v - loc).dot(normale) < distacco:
            return loc + normale * distacco
        return v

    def centro_sezione(self, p, asse, raggi=24, portata=0.2):
        punti = []
        for j in range(raggi):
            a = 2 * math.pi * j / raggi
            d = Vector((math.cos(a), math.sin(a), 0))
            d = (d - asse * d.dot(asse)).normalized()
            hit = self.albero.ray_cast(p, d, portata)
            if hit[0] is not None:
                punti.append(hit[0])
        return sum(punti, Vector()) / len(punti) if punti else p

    def raggi_busto(self, z, n, centro=None):
        """Distanze della pelle del busto dal centro della sezione alla quota z (None = nessun colpo)."""
        c = centro or self.centro_sezione(Vector((0, 0, z)), Vector((0, 0, 1)), portata=0.3)
        c = Vector((c.x * 0, c.y, z))
        raggi = []
        for j in range(n):
            a = 2 * math.pi * j / n
            d = Vector((math.cos(a), math.sin(a), 0))
            hit = self.albero.ray_cast(c, d, 0.35)
            raggi.append((hit[0] - c).length if hit[0] is not None else None)
        return c, raggi

    # Pelle sotto i vestiti -------------------------------------------------------------------------

    def nascondi_pelle(self, margine=0.004):
        """La pelle che esce dai vestiti (in "coperti") viene spinta dentro, e quella coperta prende il
        materiale "<sigla>_Nascosta": l'esportazione per il gioco la butta via."""
        me = self.corpo.data
        co = umano.coordinate(me)
        normali = [v.normal.copy() for v in me.vertices]
        alberi = self.coperti
        coperto = np.zeros(len(co), dtype=bool)
        for i in range(len(co)):
            p = Vector(co[i])
            for albero in alberi:
                loc, normale, _, d = albero.find_nearest(p, 0.06)
                if loc is None:
                    continue
                # Il vestito ha le normali verso l'esterno: un punto davanti alla superficie va spinto dentro.
                if (p - loc).dot(normale) > -margine:
                    if d < 0.04:
                        co[i] = loc - normale * margine
                        coperto[i] = True
                # Dietro la superficie: è coperto solo se il vestito sta davvero sopra la pelle (oltre l'orlo
                # di una corazza staccata dal corpo la pelle resta scoperta, e nel gioco non deve sparire).
                elif albero.ray_cast(p, normali[i], 0.15)[0] is not None:
                    coperto[i] = True
        umano.imposta_coordinate(me, co)
        nascosta = self.materiale("Nascosta", (0.5, 0.1, 0.1))
        me.materials.append(nascosta)
        indice = len(me.materials) - 1
        for poligono in me.polygons:
            if all(coperto[k] for k in poligono.vertices):
                poligono.material_index = indice
        self.albero = umano.albero(me)
        return int(coperto.sum())


def pulisci(nome, sigla):
    col = bpy.data.collections.get(nome)
    if col:
        for o in list(col.all_objects):
            bpy.data.objects.remove(o, do_unlink=True)
        for figlia in list(col.children_recursive):
            bpy.data.collections.remove(figlia)
        bpy.data.collections.remove(col)
    for dati in (bpy.data.meshes, bpy.data.armatures, bpy.data.hair_curves):
        for d in list(dati):
            if d.users == 0:
                dati.remove(d)
    for m in list(bpy.data.materials):
        if m.users == 0 and m.name.startswith(sigla + "_"):
            bpy.data.materials.remove(m)
    col = bpy.data.collections.new(nome)
    bpy.context.scene.collection.children.link(col)
    # Le altre unità restano nel file ma non si vedono (e non entrano nelle foto).
    for altra in bpy.context.scene.collection.children:
        if altra != col and altra.name not in ("Studio", "Collection"):
            altra.hide_render = True
            altra.hide_viewport = True
    return col


def applica(o):
    deps = bpy.context.evaluated_depsgraph_get()
    nuova = bpy.data.meshes.new_from_object(o.evaluated_get(deps))
    vecchia = o.data
    o.modifiers.clear()
    o.data = nuova
    for m in vecchia.materials:
        if m.name not in [x.name for x in nuova.materials]:
            nuova.materials.append(m)
    bpy.data.meshes.remove(vecchia)


# Forme di base -------------------------------------------------------------------------------------

def anello_ellittico(bm, centro, rx, ry, n, inizio=0.0, fine=2 * math.pi, chiuso=True):
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


def tubo_ellittico(sezioni, n=32, tappi=False):
    bm = bmesh.new()
    anelli = [anello_ellittico(bm, c, rx, ry, n) for c, rx, ry in sezioni]
    for a, b in zip(anelli, anelli[1:]):
        unisci_anelli(bm, a, b)
    if tappi:
        bm.faces.new(list(reversed(anelli[0])))
        bm.faces.new(anelli[-1])
    return bm


def cilindro(p0, p1, r0, r1=None, n=16, tappi=True):
    r1 = r0 if r1 is None else r1
    p0, p1 = Vector(p0), Vector(p1)
    asse = p1 - p0
    rot = asse.to_track_quat("Z", "Y").to_matrix().to_4x4()
    bm = bmesh.new()
    anelli = []
    for p, r in ((p0, r0), (p1, r1)):
        anelli.append([bm.verts.new(p + rot @ Vector((r * math.cos(2 * math.pi * i / n), r * math.sin(2 * math.pi * i / n), 0)))
                       for i in range(n)])
    unisci_anelli(bm, anelli[0], anelli[1])
    if tappi:
        bm.faces.new(list(reversed(anelli[0])))
        bm.faces.new(anelli[1])
    return bm


def tubo_lungo(punti, raggi, n=10, tappi=True):
    """Tubo che segue una polilinea, con raggio variabile (un numero o una lista)."""
    if not isinstance(raggi, (list, tuple)):
        raggi = [raggi] * len(punti)
    punti = [Vector(p) for p in punti]
    bm = bmesh.new()
    anelli = []
    su_prec = None
    for i, p in enumerate(punti):
        avanti = (punti[min(i + 1, len(punti) - 1)] - punti[max(i - 1, 0)]).normalized()
        su = su_prec if su_prec is not None else avanti.orthogonal().normalized()
        su = (su - avanti * su.dot(avanti)).normalized()
        su_prec = su
        lato = avanti.cross(su)
        anelli.append([bm.verts.new(p + (su * math.cos(2 * math.pi * k / n) + lato * math.sin(2 * math.pi * k / n)) * raggi[i])
                       for k in range(n)])
    for a, b in zip(anelli, anelli[1:]):
        unisci_anelli(bm, a, b)
    if tappi:
        bm.faces.new(list(reversed(anelli[0])))
        bm.faces.new(anelli[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
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
    tot = bmesh.new()
    for b in bms:
        me = bpy.data.meshes.new("_tmp")
        b.to_mesh(me)
        b.free()
        tot.from_mesh(me)
        bpy.data.meshes.remove(me)
    return tot


def trasforma(bm, matrice):
    bmesh.ops.transform(bm, matrix=matrice, verts=bm.verts)
    return bm


def striscia(punti, normali, larghezza):
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


def griglia(righe, chiusa=False):
    bm = bmesh.new()
    vv = [[bm.verts.new(p) for p in riga] for riga in righe]
    n = len(vv[0])
    for a, b in zip(vv, vv[1:]):
        for k in range(n if chiusa else n - 1):
            bm.faces.new((a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]))
    return bm


def liscia_cerchio(r, volte=2):
    r = np.array(r, dtype=float)
    for _ in range(volte):
        r = (np.roll(r, 1) + r + np.roll(r, -1)) / 3
    return r


# Vestiti misurati sul corpo ----------------------------------------------------------------------------

def veste(u, nome, z_alto, z_basso, mat, margine=0.012, svasatura=0.05, pieghe=0.006, n_pieghe=16, n=64,
          righe=14, z_anca=0.93, spessore=0.005):
    """Tunica (o gonna, o giubba) dal busto in giù: ogni anello segue la pelle vera più un margine;
    sotto le anche non entra tra le gambe e si allarga verso l'orlo, con pieghe verticali."""
    anelli = []
    precedenti = None
    zs = np.linspace(z_alto, z_basso, righe)
    for i, z in enumerate(zs):
        c, raggi = u.raggi_busto(float(z), n)
        if precedenti is not None:
            raggi = [r if r is not None else precedenti[j] for j, r in enumerate(raggi)]
        else:
            m = max(r for r in raggi if r is not None)
            raggi = [r if r is not None else m for r in raggi]
        raggi = np.array(raggi, dtype=float)
        if z < z_anca and precedenti is not None:
            # Tra le gambe la stoffa non entra: resta l'involucro dell'anello sopra.
            raggi = np.maximum(raggi, np.array(precedenti) * 0.985)
        raggi = liscia_cerchio(np.maximum.reduce([raggi, np.roll(raggi, 1), np.roll(raggi, -1)]), 2)
        precedenti = list(raggi)
        t = (z_alto - z) / max(1e-6, z_alto - z_basso)
        giu = max(0.0, (z_anca - z) / max(1e-6, z_anca - z_basso)) if z < z_anca else 0.0
        anello = []
        for j in range(n):
            a = 2 * math.pi * j / n
            d = Vector((math.cos(a), math.sin(a), 0))
            r = raggi[j] + margine + svasatura * giu ** 1.4 + pieghe * (0.3 + t) * math.sin(a * n_pieghe)
            anello.append(Vector((c.x, c.y, z)) + d * r)
        anelli.append(anello)
    bm = griglia(anelli, chiusa=True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # Normali verso fuori: il primo anello è in alto, la griglia gira in senso antiorario visto dall'alto.
    _verso_fuori(bm)
    return u.oggetto(nome, bm, mat, spessore=spessore, copre=True)


def _verso_fuori(bm):
    bm.normal_update()
    centro = sum((v.co for v in bm.verts), Vector()) / len(bm.verts)
    fuori = sum(((f.calc_center_median() - centro).dot(f.normal) for f in bm.faces))
    if fuori < 0:
        for f in bm.faces:
            f.normal_flip()
    bm.normal_update()


def maniche(u, nome, mat, t_inizio=-0.12, t_fine=0.48, margine=0.009, spessore=0.004, n=32):
    """Maniche: un tubo misurato sul braccio vero dalla spalla fino a t_fine dell'omero (1 = gomito);
    con t_fine > 1 prosegue sull'avambraccio fino a t_fine - 1 del polso."""
    return tubo_arto(u, nome, mat, ("spalla", "gomito", "polso"), t_inizio, t_fine, margine, spessore, n, 0.14)


def pantaloni(u, nome, mat, t_inizio=0.0, t_fine=1.9, margine=0.008, spessore=0.004, n=32):
    """Gambe di brache o calzoni: dall'anca (0) al ginocchio (1) e giù fino alla caviglia (2)."""
    return tubo_arto(u, nome, mat, ("anca", "ginocchio", "caviglia"), t_inizio, t_fine, margine, spessore, n, 0.2)


def tubo_arto(u, nome, mat, giunti, t_inizio, t_fine, margine, spessore, n, portata, righe=18):
    """Tubo di stoffa (o maglia) misurato sull'arto vero: t da 0 a 1 sul primo osso, da 1 a 2 sul secondo."""
    tubi = []
    for lato in ("d", "s"):
        g0, g1, g2 = (u.P(g + "_" + lato) for g in giunti)
        anelli = []
        for riga, t in enumerate(np.linspace(t_inizio, t_fine, righe)):
            # Il polsino in fondo stringe sulla pelle: dentro non si vede la pelle nascosta.
            stretto = margine * (0.25 if riga == righe - 1 else 0.6 if riga == righe - 2 else 1.0)
            if t <= 1:
                a0, a1, f = g0, g1, t
            else:
                a0, a1, f = g1, g2, t - 1
            asse = (a1 - a0).normalized()
            base = asse.orthogonal().normalized()
            p = a0.lerp(a1, max(f, 0.05)) if t >= 0 else g0 + (g0 - g1).normalized() * (-t) * (g1 - g0).length * 0.5
            raggi = []
            for j in range(n):
                d = Matrix.Rotation(2 * math.pi * j / n, 3, asse) @ base
                hit = u.albero.ray_cast(p, d, portata)
                raggi.append((hit[0] - p).length if hit[0] is not None else None)
            m = max([r for r in raggi if r is not None] or [0.05])
            raggi = liscia_cerchio([m if r is None else r for r in raggi], 3)
            pieghe = 0.001 + 0.003 * max(0.0, t) / max(t_fine, 0.1)
            anelli.append([p + (Matrix.Rotation(2 * math.pi * j / n, 3, asse) @ base) *
                           (raggi[j] + stretto + pieghe * math.sin(j * 5 * 2 * math.pi / n + t * 4)) for j in range(n)])
        bm = griglia(anelli, chiusa=True)
        _verso_fuori_locale(bm, g0, g1)
        tubi.append(bm)
    return u.oggetto(nome, unisci(*tubi), mat, spessore=spessore, copre=True)


def _verso_fuori_locale(bm, a, b):
    bm.normal_update()
    asse = (b - a).normalized()
    voti = 0.0
    for f in bm.faces:
        c = f.calc_center_median()
        radiale = (c - a) - asse * (c - a).dot(asse)
        voti += radiale.dot(f.normal)
    if voti < 0:
        for f in bm.faces:
            f.normal_flip()


def anello_sul_corpo(u, centro, asse, distacco, larghezza, n=40, portata=0.25):
    """Fascia attorno a un arto o alla testa, appoggiata sulla pelle (punti, normali)."""
    asse = Vector(asse).normalized()
    base = asse.orthogonal().normalized()
    punti, normali = [], []
    for j in range(n + 1):
        d = Matrix.Rotation(2 * math.pi * j / n, 3, asse) @ base
        punti.append(u.sulla_pelle(Vector(centro), d, distacco, portata))
        normali.append(d)
    return striscia(punti, normali, larghezza)


def calzature(u, nome, mat, mat_suola, taglio=0.115, inclinazione=0.25, distacco=0.004):
    """Scarpe chiuse prese dal piede vero (involucro convesso, niente dita), tagliate alla quota 'taglio'."""
    bm = bmesh.new()
    bm.from_mesh(u.corpo.data)
    # Piedi non a terra (a cavallo): ogni piede si riporta nella posa in piedi, si calza e si rimette a posto.
    porta = _piedi_a_terra(u)
    if porta:
        bmesh.ops.delete(bm, geom=[v for v in bm.verts
                                   if (v.co - u.P("caviglia_" + ("s" if v.co.x > 0 else "d"))).length > 0.3],
                         context="VERTS")
        for v in bm.verts:
            v.co = porta[1 if v.co.x > 0 else -1] @ v.co
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z > taglio + 0.12], context="VERTS")
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, taglio),
                           plane_no=Vector((0, -inclinazione, 1)).normalized(), clear_outer=True)
    piede = {1: [], -1: []}
    for v in bm.verts:
        piede[1 if v.co.x > 0 else -1].append(v.co.copy())
    involucri = {}
    for s, punti in piede.items():
        hb = bmesh.new()
        for q in punti:
            hb.verts.new(q)
        bmesh.ops.convex_hull(hb, input=hb.verts[:], use_existing_faces=False)
        bmesh.ops.delete(hb, geom=[v for v in hb.verts if not v.link_faces], context="VERTS")
        involucri[s] = (BVHTree.FromBMesh(hb), sum(punti, Vector()) / len(punti))
        hb.free()
    bm.normal_update()
    for v in bm.verts:
        albero, centro = involucri[1 if v.co.x > 0 else -1]
        loc, normale, _, _ = albero.find_nearest(v.co)
        if normale.dot(loc - centro) < 0:
            normale = -normale
        aderente = v.co + v.normal * distacco
        sulla_forma = loc + normale * distacco
        bordo = taglio + inclinazione * v.co.y
        t = min(1.0, max(0.0, (bordo - v.co.z) / 0.03))
        v.co = aderente.lerp(sulla_forma, t)
    for _ in range(4):
        bmesh.ops.smooth_vert(bm, verts=[v for v in bm.verts if not v.is_boundary], factor=0.5,
                              use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bm.normal_update()
    for f in bm.faces:
        f.material_index = 1 if f.normal.z < -0.55 or f.calc_center_median().z < 0.012 else 0
    if porta:
        for v in bm.verts:
            v.co = porta[1 if v.co.x > 0 else -1].inverted() @ v.co
    for v in bm.verts:
        v.co = u.fuori_dalla_pelle(v.co, distacco)
    bm.normal_update()
    # Copre il piede: la pelle sotto la scarpa si nasconde (le normali di bm guardano fuori dal piede).
    u.coperti.append(BVHTree.FromBMesh(bm))
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(nome, me)
    me.materials.append(u.mat[mat])
    me.materials.append(u.mat[mat_suola])
    u.col.objects.link(o)
    o.parent = u.radice
    # La pelle ad alta definizione è troppo fitta per una scarpa: si alleggerisce prima dello spessore
    # (così anche la versione da gioco resta intera).
    facce = len(me.polygons)
    if facce > 3000:
        dec = o.modifiers.new("Leggera", "DECIMATE")
        dec.ratio = 3000 / facce
    mod = o.modifiers.new("Spessore", "SOLIDIFY")
    mod.thickness = 0.003
    mod.offset = 1.0
    applica(o)
    for p in o.data.polygons:
        p.use_smooth = True
    scarpe_da_gioco(u, o, nome + "_Gioco")
    return o


def _piedi_a_terra(u):
    """Se i piedi non poggiano a terra (cavaliere): per lato, la matrice che porta il piede in posa nella posizione
    in piedi del corpo a riposo (caviglia, punta e ginocchio di umano.GIUNTI). Altrimenti None."""
    if u.P("caviglia_s").z < 0.13:
        return None
    porta = {}
    for s, lato in ((1, "s"), (-1, "d")):
        def asse(ginocchio, caviglia, punta):
            e1 = (punta - caviglia).normalized()
            e2 = ginocchio - caviglia
            e2 = (e2 - e1 * e2.dot(e1)).normalized()
            m = Matrix((e1, e2, e1.cross(e2))).transposed().to_4x4()
            m.translation = caviglia
            return m
        riposo = asse(*(umano.lato(umano.GIUNTI[g], s) for g in ("ginocchio", "caviglia", "punta")))
        posa = asse(u.P("ginocchio_" + lato), u.P("caviglia_" + lato), u.P("punta_" + lato))
        porta[s] = riposo @ posa.inverted()
    return porta


def scarpe_da_gioco(u, scarpe, nome):
    """Per il gioco: una scarpa chiusa e convessa per piede (la stoffa sottile della scarpa vera, decimata,
    si sbriciola). Non entra nelle foto; l'esportazione usa questa al posto dell'altra."""
    me = scarpe.data
    pezzi = []
    for s in (1, -1):
        hb = bmesh.new()
        for v in me.vertices:
            if v.co.x * s > 0:
                hb.verts.new(v.co)
        bmesh.ops.convex_hull(hb, input=hb.verts[:], use_existing_faces=False)
        bmesh.ops.delete(hb, geom=[v for v in hb.verts if not v.link_faces], context="VERTS")
        pezzi.append(hb)
    bm = unisci(*pezzi)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    for f in bm.faces:
        f.material_index = 1 if f.normal.z < -0.55 or f.calc_center_median().z < 0.012 else 0
    o = bpy.data.objects.new(nome, bpy.data.meshes.new(nome))
    bm.to_mesh(o.data)
    bm.free()
    for m in me.materials:
        o.data.materials.append(m)
    for p in o.data.polygons:
        p.use_smooth = True
    u.col.objects.link(o)
    o.parent = u.radice
    o.hide_render = True
    return o


def lacci_gamba(u, nome, mat, quote, distacco=0.003, larghezza=0.011):
    """Lacci incrociati attorno alla gamba (sandali alti, fasce): un anello per quota (frazione caviglia->ginocchio)."""
    pezzi = []
    for lato in ("d", "s"):
        g, k = u.P("ginocchio_" + lato), u.P("caviglia_" + lato)
        asse = (g - k).normalized()
        for t in quote:
            p = u.centro_sezione(k.lerp(g, t), asse)
            pezzi.append(anello_sul_corpo(u, p, asse, distacco, larghezza, 32, 0.12))
    return u.oggetto(nome, unisci(*pezzi), mat, spessore=0.002)


def cinghia_busto(u, nome, mat, da, a, larghezza=0.04, distacco=0.012, passi=24):
    """Cinghia a tracolla sul busto da un punto all'altro passando sulla pelle (davanti)."""
    da, a = Vector(da), Vector(a)
    punti, normali = [], []
    for i in range(passi + 1):
        p = da.lerp(a, i / passi)
        c = Vector((0, 0.0, p.z))
        d = Vector((p.x, p.y, 0))
        d = d.normalized() if d.length > 1e-6 else Vector((0, -1, 0))
        punti.append(u.sulla_pelle(c, d, distacco, 0.35))
        normali.append(d)
    return u.oggetto(nome, striscia(punti, normali, larghezza), mat, spessore=0.003)


# Armi ----------------------------------------------------------------------------------------------

def lama(lunghezza, larghezza_base, larghezza_punta=0.0, spessore=0.006, foglia=0.0, sezioni=10):
    """Lama piatta lungo +Z dalla base (z=0) alla punta; foglia > 0 la allarga a metà (xiphos, foglia)."""
    bm = bmesh.new()
    anelli = []
    for i in range(sezioni + 1):
        t = i / sezioni
        larghezza = larghezza_base + (larghezza_punta - larghezza_base) * t + foglia * math.sin(math.pi * t) * (1 - t)
        if i == sezioni:
            larghezza = 0.0005
        anelli.append([bm.verts.new((larghezza / 2 * math.cos(a), spessore / 2 * math.sin(a), lunghezza * t))
                       for a in (0, math.pi / 2, math.pi, 3 * math.pi / 2)])
    for a, b in zip(anelli, anelli[1:]):
        unisci_anelli(bm, a, b)
    bm.faces.new(list(reversed(anelli[0])))
    return bm


def scudo_tondo(raggio, bombatura, spessore=0.015, n=48, anelli_n=8, uv=True):
    """Scudo rotondo bombato verso -Y (il fronte), centro nell'origine; restituisce fronte, retro e bordo."""
    def punto(r, a, dietro=0.0):
        z = bombatura * (1 - (r / raggio) ** 2)
        return Vector((r * math.cos(a), -z + dietro, r * math.sin(a)))
    fronte = bmesh.new()
    livello = fronte.loops.layers.uv.new("UVMap")
    centro = fronte.verts.new(punto(0, 0))
    giri = [[fronte.verts.new(punto(raggio * (k + 1) / anelli_n, 2 * math.pi * j / n)) for j in range(n)] for k in range(anelli_n)]
    for j in range(n):
        f = fronte.faces.new((centro, giri[0][(j + 1) % n], giri[0][j]))
    for a, b in zip(giri, giri[1:]):
        for j in range(n):
            fronte.faces.new((a[j], a[(j + 1) % n], b[(j + 1) % n], b[j]))
    for f in fronte.faces:
        for loop in f.loops:
            co = loop.vert.co
            loop[livello].uv = (0.5 + co.x / (2 * raggio), 0.5 + co.z / (2 * raggio))
    bmesh.ops.recalc_face_normals(fronte, faces=fronte.faces)
    for f in fronte.faces:
        if f.normal.y > 0:
            f.normal_flip()
    retro = bmesh.new()
    rc = retro.verts.new(punto(0, 0, spessore))
    rgiri = [[retro.verts.new(punto(raggio * (k + 1) / anelli_n, 2 * math.pi * j / n, spessore)) for j in range(n)] for k in range(anelli_n)]
    for j in range(n):
        retro.faces.new((rc, rgiri[0][j], rgiri[0][(j + 1) % n]))
    for a, b in zip(rgiri, rgiri[1:]):
        for j in range(n):
            retro.faces.new((a[(j + 1) % n], a[j], b[j], b[(j + 1) % n]))
    # Il retro guarda indietro (+Y): la cottura della texture parte dal lato giusto.
    retro.normal_update()
    for f in retro.faces:
        if f.normal.y < 0:
            f.normal_flip()
    bordo = tubo_lungo([punto(raggio, 2 * math.pi * j / n, spessore / 2) for j in range(n + 1)], spessore * 0.7, n=8, tappi=False)
    return fronte, retro, bordo


# Foto ----------------------------------------------------------------------------------------------

def foto(percorso, azimut=-25, elevazione=6, distanza=4.6, bersaglio=(0.0, 0, 1.0), lente=50):
    import legionario
    if bpy.context.scene.camera is None or bpy.context.scene.camera.name != "Fotocamera":
        legionario.studio(900, 1200)
    return legionario.foto(percorso, azimut, elevazione, distanza, bersaglio, lente)


# Pose, archi ed elmi ricorrenti ----------------------------------------------------------------------

def impugna_verticale(sch, s, punto, polo, inclinazione=15, avanti_x=0.15):
    """Pugno chiuso su un'asta verticale (lancia, manico, arco) che passa per 'punto': s = -1 destra, +1 sinistra.
    È la presa della lancia del legionario, specchiata per la sinistra."""
    punto = Vector(punto)
    avanti = Vector((avanti_x * -s, -1, 0)).normalized()
    su = Vector((0, 0, 1))
    phi = math.radians(inclinazione)
    radiale = su * math.cos(phi) - avanti * math.sin(phi)
    y = avanti * math.cos(phi) + su * math.sin(phi)
    dorso = (y.cross(radiale) if s < 0 else radiale.cross(y)).normalized()
    umano.posa_braccio(sch, s, punto - y * 0.09 + dorso * 0.028, y, dorso, polo)
    umano.chiudi_dita(sch, s, {"indice": (70, 95, 50), "medio": (75, 95, 50), "anulare": (80, 95, 50),
                               "mignolo": (85, 90, 50), "pollice": (35, 45, 35)})


def arco_teso(u, prefisso, impugnatura, meta, profilo, raggi=(0.0135, 0.0065), inclinazione=4, corna=True,
              mat_legno="Legno", mat_corno="Corno", mat_impugnatura="Cuoio", mat_corda="Corda"):
    """Arco teso in verticale nel piano YZ, impugnatura in 'impugnatura', corda verso l'arciere (+Y).
    profilo(s) = scostamento verso la corda del flettente a s (0 impugnatura, 1 punta)."""
    m = Matrix.Translation(Vector(impugnatura)) @ Matrix.Rotation(math.radians(inclinazione), 4, "X")
    flettenti, punte = [], []
    for segno in (1, -1):
        punti, rr = [], []
        for i in range(25):
            s = i / 24
            punti.append(m @ Vector((0, profilo(s), segno * s * meta)))
            rr.append(raggi[0] * (1 - s) + raggi[1] * s + (0.004 if s < 0.12 else 0.0))
        flettenti.append(tubo_lungo(punti, rr, n=8))
        if corna:
            pp = [m @ Vector((0, profilo(s), segno * s * meta)) for s in (0.9, 0.95, 1.0)]
            pp.append(m @ Vector((0, profilo(1.0) - 0.02, segno * (meta + 0.03))))
            punte.append(tubo_lungo(pp, [raggi[1] + 0.001, raggi[1] + 0.0005, raggi[1], 0.004], n=8))
        else:
            pp = [m @ Vector((0, profilo(s), segno * s * meta)) for s in (0.96, 1.0)]
            pp.append(m @ Vector((0, profilo(1.0), segno * (meta + 0.025))))
            punte.append(tubo_lungo(pp, [raggi[1] + 0.0015, raggi[1] + 0.001, 0.003], n=8))
    u.oggetto(prefisso + "_Legno", unisci(*flettenti), mat_legno)
    u.oggetto(prefisso + "_Corno", unisci(*punte), mat_corno)
    u.oggetto(prefisso + "_Impugnatura", cilindro(m @ Vector((0, 0.002, -0.06)), m @ Vector((0, 0.002, 0.06)),
                                                  raggi[0] + 0.005, n=12), mat_impugnatura)
    alto = m @ Vector((0, profilo(1.0) - 0.005, meta - 0.005))
    basso = m @ Vector((0, profilo(1.0) - 0.005, -meta + 0.005))
    u.oggetto(prefisso + "_Corda", cilindro(basso, alto, 0.0022, n=6), mat_corda)


def calotta(u, nome, mat, z_davanti, z_dietro, apice, forma, distacco=0.013, n=40, righe=12, spessore=0.003):
    """Calotta di elmo appoggiata sulla testa vera: il bordo segue la testa alla quota z (più bassa dietro),
    poi sale verso l'apice. forma(t) = rigonfiamento in fuori a t (0 bordo, 1 apice).
    Restituisce l'oggetto e i punti del bordo (per tese, fasce, nasali)."""
    centro_y = -0.02
    apice = Vector(apice)
    bordo = []
    for j in range(n):
        a = 2 * math.pi * j / n
        d = Vector((math.cos(a), math.sin(a), 0))
        z = z_davanti + (z_dietro - z_davanti) * max(0.0, d.y)
        bordo.append(u.sulla_pelle(Vector((0, centro_y, z)), d, distacco, 0.2))
    anelli = []
    for t in np.linspace(0, 1, righe):
        anello = []
        for p in bordo:
            q = p.lerp(apice, min(float(t), 0.96))
            radiale = Vector((q.x, q.y - centro_y, 0))
            if radiale.length > 1e-6:
                q = q + radiale.normalized() * forma(float(t))
            if t < 0.95:
                q = u.fuori_dalla_pelle(q, distacco)
            anello.append(q)
        anelli.append(anello)
    bm = griglia(anelli, chiusa=True)
    bm.verts.ensure_lookup_table()
    bm.faces.new([bm.verts[len(bm.verts) - n + j] for j in range(n)])
    _verso_fuori(bm)
    return u.oggetto(nome, bm, mat, spessore=spessore), bordo, anelli


def baffi(u, nome, mat, folti=1.0):
    """Baffi sopra il labbro, appoggiati sulla pelle (folti > 1 più grossi e lunghi)."""
    pezzi = []
    for s in (1, -1):
        punti = [Vector((s * 0.004, -0.123, 1.579)), Vector((s * 0.02, -0.119, 1.574)),
                 Vector((s * 0.034, -0.110, 1.563)), Vector((s * (0.042 + 0.006 * (folti - 1)), -0.100, 1.548))]
        punti = [u.fuori_dalla_pelle(p, 0.004 * folti) for p in punti]
        pezzi.append(tubo_lungo(punti, [0.0045 * folti, 0.0055 * folti, 0.004 * folti, 0.0015], n=8))
    return u.oggetto(nome, unisci(*pezzi), mat)


def pteruges(u, nome, mat, z_alto=1.0, lunghezza=0.20, n=18, distacco=0.04, larghezza=None, spalle=True,
             lunghezza_spalle=0.17, n_spalle=9, spessore=0.006):
    """Strisce di cuoio (o lino) che pendono dalla corazza: un giro attorno ai fianchi e, se spalle, un giro
    attorno all'omero. Ogni striscia è una lista appena svasata in fuori verso il fondo, con un poco di spazio
    tra l'una e l'altra."""
    pezzi = []
    c, raggi = u.raggi_busto(z_alto, n * 4)
    m = max(r for r in raggi if r is not None)
    raggi = [m if r is None else r for r in raggi]
    giro = 2 * math.pi
    for k in range(n):
        a = giro * (k + 0.5) / n
        r = raggi[int(round((k + 0.5) * 4)) % (n * 4)] + distacco
        largo = larghezza or (giro * r / n * 0.86)
        d = Vector((math.cos(a), math.sin(a), 0))
        t = Vector((-math.sin(a), math.cos(a), 0))
        alto = Vector((c.x, c.y, z_alto)) + d * r
        basso = alto + d * 0.035 - Vector((0, 0, lunghezza))
        bm = bmesh.new()
        vs = [bm.verts.new(p) for p in (alto - t * largo / 2, alto + t * largo / 2, basso + t * largo / 2,
                                         basso - t * largo / 2)]
        bm.faces.new(vs)
        pezzi.append(bm)
    if spalle:
        for lato in ("d", "s"):
            spalla, gomito = u.P("spalla_" + lato), u.P("gomito_" + lato)
            asse = (gomito - spalla).normalized()
            base = asse.orthogonal().normalized()
            for k in range(n_spalle):
                ang = 2 * math.pi * k / n_spalle
                d = Matrix.Rotation(ang, 3, asse) @ base
                p0 = spalla + asse * 0.02
                hit = u.albero.ray_cast(p0, d, 0.2)
                r = ((hit[0] - p0).length if hit[0] is not None else 0.06) + distacco * 0.8
                t = asse.cross(d).normalized()
                largo = 2 * math.pi * r / n_spalle * 0.85
                alto = p0 + d * r
                basso = alto + asse * lunghezza_spalle + d * 0.02
                bm = bmesh.new()
                vs = [bm.verts.new(p) for p in (alto - t * largo / 2, alto + t * largo / 2, basso + t * largo / 2,
                                                 basso - t * largo / 2)]
                bm.faces.new(vs)
                pezzi.append(bm)
    bm = unisci(*pezzi)
    _verso_fuori(bm)
    return u.oggetto(nome, bm, mat, spessore=spessore)


def mantello_dietro(u, nome, mat, z_alto=1.43, z_basso=0.45, da=0.25, a=math.pi - 0.25, svasatura=0.18,
                    distacco=0.035, colonne=24, righe=16, spessore=0.006, pieghe=0.012):
    """Mantello che pende dalle spalle dietro la schiena fino a z_basso, allargandosi verso l'orlo, con pieghe.
    Angoli da 'da' ad 'a' attorno al busto (0 = sinistra +X, pi/2 = dietro +Y, pi = destra)."""
    angoli = np.linspace(da, a, colonne)
    righe_p = []
    ultimo = None
    for i, z in enumerate(np.linspace(z_alto, z_basso, righe)):
        t = i / (righe - 1)
        riga = []
        for j, ang in enumerate(angoli):
            d = Vector((math.cos(ang), math.sin(ang), 0))
            if z > 0.95:
                p = u.sulla_pelle(Vector((0, 0.0, float(z))), d, distacco + 0.02 * t, 0.45)
            else:
                # Sotto la vita il mantello scende dritto dal punto sopra, allargandosi e senza entrare nelle gambe.
                p = ultimo[j] + Vector((0, 0, float(z) - ultimo[j].z))
                p = p + d * svasatura * (0.95 - float(z)) / 0.5 * 0.5
            p = p + d * pieghe * math.sin(j * 1.7) * t
            riga.append(p)
        if z > 0.95:
            ultimo = riga
        righe_p.append(riga)
    bm = griglia(righe_p)
    _verso_fuori(bm)
    return u.oggetto(nome, bm, mat, spessore=spessore)


def corona_alloro(u, nome, mat, z=1.705, foglie=26):
    """Corona d'alloro: due rami di foglie a mandorla attorno alla testa che si incontrano sulla fronte."""
    pezzi = []
    for s in (1, -1):
        for k in range(foglie // 2):
            t = k / (foglie // 2 - 1)
            a = math.pi / 2 + s * (math.pi * 0.95) * t        # dalla nuca (+Y) alla fronte, di qua e di là
            d = Vector((math.cos(a), math.sin(a), 0))
            zz = z - 0.025 * (1 - t) + 0.01 * t
            p = u.sulla_pelle(Vector((0, -0.02, zz)), d, 0.012, 0.2)
            tangente = Vector((-math.sin(a), math.cos(a), 0)) * -s
            m = Matrix((tangente.cross(d), tangente, d)).transposed().to_4x4()
            for su in (1, -1):
                foglia = sfera((0, 0, 0), (0.007, 0.024, 0.003), 8, 4)
                trasforma(foglia, Matrix.Translation(p + Vector((0, 0, 0.012 * su))) @ m @
                          Matrix.Rotation(math.radians(30 * su), 4, "Z"))
                pezzi.append(foglia)
    return u.oggetto(nome, unisci(*pezzi), mat)
