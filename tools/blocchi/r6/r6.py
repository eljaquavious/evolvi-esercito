"""Truppe col corpo base di Roblox (R6), costruite in Blender.

Corpo: busto 2x2x1, braccia e gambe 1x2x1, testa a cilindro smussato come quella classica di Roblox.
Un "stud" del corpo vale S metri; con S = 0.34 il soldato è alto circa 1,77 m, come le truppe di prima.
Vestiti, armature e armi sono pezzi veri con spessore (non dipinti sul corpo).

Le ossa hanno gli stessi nomi e la stessa posa a riposo delle truppe di prima (avambracci in avanti a reggere
le armi), così le animazioni del gioco restano quelle.

Coordinate come in Roblox: X destra del soldato, Y su, il davanti è -Z. Ogni pezzo si converte in Blender
con blender(p) = (-x, z, y), la stessa rotazione di esporta_fbx.py.
Si usa solo dentro Blender (bpy).
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

sys.path.append(os.path.join(os.environ.get("LOCALAPPDATA", ""), "evolvi-pylib"))

S = 0.34
GAMBE = 2 * S
BUSTO_A = 2 * S
BUSTO_L = 2 * S
BUSTO_P = S
ARTO = S
COLLO = GAMBE + BUSTO_A  # cima del busto
TESTA_D = 1.25 * S  # diametro della testa
TESTA_H = 1.2 * S
TESTA_Y = COLLO + TESTA_H / 2 - 0.02 * S  # centro della testa (appoggiata sul busto)
X_BRACCIO = 1.5 * S
X_GAMBA = 0.5 * S
SPALLA = COLLO - 0.5 * S
OMERO = 0.8 * S
AVAMBRACCIO = 0.6 * S
MANO = 0.45 * S

PELLI = ["#E8B48C", "#D9A27A", "#C98E64", "#F0C49E", "#B97F58"]


def blender(p):
    return Vector((-p[0], p[2], p[1]))


def rgb(c):
    c = c.lstrip("#")
    return tuple(int(c[i:i + 2], 16) / 255 for i in (0, 2, 4))


def lineare(c):
    """Da sRGB (colori scritti in esadecimale) a lineare, come vuole Blender."""
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in rgb(c))


def norm(v):
    v = np.asarray(v, float)
    return v / np.linalg.norm(v)


# -- Materiali -------------------------------------------------------------------------------------------

_MATERIALI = {}


def azzera():
    """Dimentica i materiali e i disegni fatti (dopo read_factory_settings non esistono più)."""
    _MATERIALI.clear()
    _DISEGNI.clear()


# Ogni materiale è opaco e ha la grana del suo materiale vero (criterio fisso di Mattia: niente plastica lucida).
# ruvido, metallo, forza del riflesso (Specular IOR Level), velluto (Sheen, per le stoffe).
TIPI = {
    "stoffa": dict(ruvido=0.92, metallo=0.0, riflesso=0.25, velluto=0.5),
    "lana": dict(ruvido=0.96, metallo=0.0, riflesso=0.2, velluto=0.7),
    "crine": dict(ruvido=0.85, metallo=0.0, riflesso=0.3, velluto=0.6),
    "cuoio": dict(ruvido=0.68, metallo=0.0, riflesso=0.4, velluto=0.0),
    "cuoio_dipinto": dict(ruvido=0.74, metallo=0.0, riflesso=0.35, velluto=0.0),
    "legno": dict(ruvido=0.78, metallo=0.0, riflesso=0.3, velluto=0.0),
    "pelle": dict(ruvido=0.62, metallo=0.0, riflesso=0.35, velluto=0.15),
    "ferro": dict(ruvido=0.52, metallo=0.85, riflesso=0.5, velluto=0.0),
    "ottone": dict(ruvido=0.55, metallo=0.9, riflesso=0.5, velluto=0.0),
    "bronzo": dict(ruvido=0.7, metallo=0.7, riflesso=0.4, velluto=0.0),  # bronzo vecchio dei cannoni, con la patina
    "piombo": dict(ruvido=0.62, metallo=0.6, riflesso=0.4, velluto=0.0),
    "maglia": dict(ruvido=0.6, metallo=0.8, riflesso=0.45, velluto=0.0),  # cotta di maglia: anellini
    "squame": dict(ruvido=0.55, metallo=0.85, riflesso=0.5, velluto=0.0),  # squame e lamelle
    "pelliccia": dict(ruvido=0.97, metallo=0.0, riflesso=0.15, velluto=0.9),
    "feltro": dict(ruvido=0.95, metallo=0.0, riflesso=0.18, velluto=0.6),  # cappelli
    "legno_dipinto": dict(ruvido=0.8, metallo=0.0, riflesso=0.3, velluto=0.0),  # scudi dipinti
    "pietra": dict(ruvido=0.93, metallo=0.0, riflesso=0.2, velluto=0.0),
    "vimini": dict(ruvido=0.88, metallo=0.0, riflesso=0.25, velluto=0.0),
}


class _Nodi:
    """Piccoli aiuti per costruire i nodi della grana in coordinate dell'oggetto (metri)."""

    def __init__(self, m):
        self.n, self.l = m.node_tree.nodes, m.node_tree.links
        self.bsdf = self.n["Principled BSDF"]
        self.coord = self.n.new("ShaderNodeTexCoord").outputs["Object"]

    def mappa(self, scala):
        mp = self.n.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = scala
        self.l.new(self.coord, mp.inputs["Vector"])
        return mp.outputs["Vector"]

    def rumore(self, scala, dettaglio=4.0, distorsione=0.0):
        t = self.n.new("ShaderNodeTexNoise")
        t.inputs["Detail"].default_value = dettaglio
        t.inputs["Distortion"].default_value = distorsione
        self.l.new(self.mappa(scala), t.inputs["Vector"])
        return t.outputs["Fac"]

    def onde(self, scala, direzione, distorsione=0.0):
        t = self.n.new("ShaderNodeTexWave")
        t.wave_type = "BANDS"
        t.bands_direction = direzione
        t.inputs["Scale"].default_value = 1.0
        t.inputs["Distortion"].default_value = distorsione
        self.l.new(self.mappa(scala), t.inputs["Vector"])
        return t.outputs["Fac"]

    def celle(self, scala):
        t = self.n.new("ShaderNodeTexVoronoi")
        t.feature = "SMOOTH_F1"
        self.l.new(self.mappa(scala), t.inputs["Vector"])
        return t.outputs["Distance"]

    def intervallo(self, fac, lo, hi, da=0.3, a=0.7):
        r = self.n.new("ShaderNodeMapRange")
        r.inputs["From Min"].default_value, r.inputs["From Max"].default_value = da, a
        r.inputs["To Min"].default_value, r.inputs["To Max"].default_value = lo, hi
        self.l.new(fac, r.inputs["Value"])
        return r.outputs["Result"]

    def moltiplica(self, a, b):
        x = self.n.new("ShaderNodeMix")
        x.data_type = "RGBA"
        x.blend_type = "MULTIPLY"
        x.inputs["Factor"].default_value = 1.0
        self.l.new(a, x.inputs["A"])
        self.l.new(b, x.inputs["B"])
        return x.outputs["Result"]

    def somma(self, a, b, kb=1.0):
        x = self.n.new("ShaderNodeMath")
        x.operation = "MULTIPLY_ADD"
        self.l.new(b, x.inputs[0])
        x.inputs[1].default_value = kb
        self.l.new(a, x.inputs[2])
        return x.outputs["Value"]

    def rilievo(self, altezza, forza, distanza=0.002):
        b = self.n.new("ShaderNodeBump")
        b.inputs["Strength"].default_value = forza
        b.inputs["Distance"].default_value = distanza
        self.l.new(altezza, b.inputs["Height"])
        self.l.new(b.outputs["Normal"], self.bsdf.inputs["Normal"])

    def ruvidezza(self, fac, lo, hi):
        self.l.new(self.intervallo(fac, lo, hi), self.bsdf.inputs["Roughness"])


def _grana(m, tipo, colore):
    """Grana del tipo sul materiale: variazioni di colore e di ruvidezza e rilievo. colore: uscita del colore base."""
    g = _Nodi(m)
    p = TIPI[tipo]
    g.bsdf.inputs["Roughness"].default_value = p["ruvido"]
    g.bsdf.inputs["Metallic"].default_value = p["metallo"]
    g.bsdf.inputs["Specular IOR Level"].default_value = p["riflesso"]
    g.bsdf.inputs["Sheen Weight"].default_value = p["velluto"]
    g.bsdf.inputs["Sheen Roughness"].default_value = 0.5
    macchie = g.rumore((14,) * 3, 3)
    if tipo in ("stoffa", "lana"):
        # Trama: fili in due direzioni (onde incrociate) e fibre fini.
        passo = 55 if tipo == "stoffa" else 32
        trama = g.moltiplica(g.onde((passo,) * 3, "X"), g.onde((passo,) * 3, "Z"))
        fibre = g.rumore((420,) * 3, 2)
        colore = g.moltiplica(colore, g.intervallo(macchie, 0.86, 1.06))
        colore = g.moltiplica(colore, g.intervallo(trama, 0.88, 1.04, 0.0, 1.0))
        g.rilievo(g.somma(trama, fibre, 0.5), 0.35, 0.0015)
    elif tipo == "crine":
        # Ciocche: striature lunghe lungo l'altezza delle piume.
        ciocche = g.rumore((260, 260, 18), 3, 1.0)
        colore = g.moltiplica(colore, g.intervallo(ciocche, 0.72, 1.12, 0.25, 0.75))
        g.rilievo(ciocche, 0.45, 0.003)
        g.ruvidezza(ciocche, 0.75, 0.9)
    elif tipo in ("cuoio", "cuoio_dipinto"):
        # Grana del cuoio: celle minute, macchie e consumo.
        celle = g.celle((240,) * 3)
        colore = g.moltiplica(colore, g.intervallo(macchie, 0.8 if tipo == "cuoio" else 0.88, 1.08))
        colore = g.moltiplica(colore, g.intervallo(celle, 0.92, 1.03, 0.0, 0.6))
        g.rilievo(celle, 0.3 if tipo == "cuoio" else 0.15, 0.0015)
        g.ruvidezza(macchie, p["ruvido"] - 0.12, p["ruvido"] + 0.1)
    elif tipo == "legno":
        # Venature lungo la lunghezza (Z di Blender, verticale): onde stirate e mosse.
        vena = g.onde((90, 90, 6), "X", distorsione=6.0)
        colore = g.moltiplica(colore, g.intervallo(vena, 0.74, 1.1, 0.0, 1.0))
        colore = g.moltiplica(colore, g.intervallo(macchie, 0.9, 1.05))
        g.rilievo(vena, 0.12, 0.002)
    elif tipo == "maglia":
        # Anellini di ferro: righe fitte incrociate, scure nelle fessure.
        anelli = g.moltiplica(g.onde((150,) * 3, "X"), g.onde((150,) * 3, "Z"))
        colore = g.moltiplica(colore, g.intervallo(anelli, 0.55, 1.12, 0.0, 1.0))
        colore = g.moltiplica(colore, g.intervallo(macchie, 0.9, 1.04))
        g.rilievo(anelli, 0.6, 0.002)
        g.ruvidezza(anelli, 0.75, 0.48)
    elif tipo == "squame":
        # Squame sovrapposte: celle di Voronoi, i bordi scuri e in rilievo.
        celle = g.celle((70, 70, 110))
        colore = g.moltiplica(colore, g.intervallo(celle, 1.08, 0.62, 0.0, 0.5))
        colore = g.moltiplica(colore, g.intervallo(macchie, 0.92, 1.03))
        g.rilievo(celle, 0.5, 0.004)
        g.ruvidezza(celle, 0.45, 0.7)
    elif tipo == "pelliccia":
        # Pelo: ciuffi mossi in tutte le direzioni, molto opaco.
        ciuffi = g.rumore((160,) * 3, 6, 3.0)
        colore = g.moltiplica(colore, g.intervallo(ciuffi, 0.7, 1.15, 0.2, 0.8))
        g.rilievo(ciuffi, 0.7, 0.004)
    elif tipo in ("legno_dipinto", "pietra", "vimini", "feltro"):
        if tipo == "vimini":
            grana = g.moltiplica(g.onde((70,) * 3, "X", 1.0), g.onde((70,) * 3, "Z", 1.0))
            forza = 0.5
        elif tipo == "pietra":
            grana = g.rumore((40,) * 3, 8, 0.5)
            forza = 0.4
        elif tipo == "feltro":
            grana = g.rumore((500,) * 3, 3)
            forza = 0.12
        else:
            grana = g.onde((90, 90, 6), "X", distorsione=6.0)
            forza = 0.08
        colore = g.moltiplica(colore, g.intervallo(macchie, 0.86, 1.05))
        colore = g.moltiplica(colore, g.intervallo(grana, 0.9, 1.04, 0.0, 1.0))
        g.rilievo(grana, forza, 0.002)
    elif tipo in ("ferro", "ottone", "piombo"):
        # Metallo satinato: graffi fini (rumore stirato), macchie di ossido e piccole ammaccature.
        graffi = g.rumore((520, 520, 40), 2)
        colore = g.moltiplica(colore, g.intervallo(macchie, 0.93, 1.02))
        colore = g.moltiplica(colore, g.intervallo(graffi, 0.94, 1.03))
        g.ruvidezza(graffi, p["ruvido"] - 0.1, p["ruvido"] + 0.12)
        g.rilievo(g.rumore((60,) * 3, 2), 0.08, 0.003)
    elif tipo == "bronzo":
        # Bronzo esposto: patina scura a chiazze larghe, graffi più chiari, superficie fusa un po' ruvida.
        patina = g.rumore((1.6,) * 3, 3, 0.3)
        graffi = g.rumore((520, 520, 40), 2)
        colore = g.moltiplica(colore, g.intervallo(patina, 0.8, 1.03, 0.35, 0.65))
        colore = g.moltiplica(colore, g.intervallo(macchie, 0.9, 1.03))
        colore = g.moltiplica(colore, g.intervallo(graffi, 0.95, 1.04))
        g.ruvidezza(patina, p["ruvido"] + 0.12, p["ruvido"] - 0.08)
        g.rilievo(g.rumore((80,) * 3, 3), 0.05, 0.003)
    else:  # pelle
        colore = g.moltiplica(colore, g.intervallo(macchie, 0.95, 1.03))
        g.rilievo(g.rumore((300,) * 3, 2), 0.04, 0.001)
    g.l.new(colore, g.bsdf.inputs["Base Color"])


def mat(colore, tipo="stoffa", nome=None):
    """Materiale di un colore e di un tipo (vedi TIPI): opaco, con la grana del materiale vero."""
    chiave = (colore, tipo)
    if chiave in _MATERIALI:
        return _MATERIALI[chiave]
    m = bpy.data.materials.new(nome or (tipo + "_" + colore.lstrip("#")))
    m.use_nodes = True
    base = m.node_tree.nodes.new("ShaderNodeRGB")
    base.outputs[0].default_value = (*lineare(colore), 1)
    _grana(m, tipo, base.outputs[0])
    m["colore"], m["tipo"] = colore, tipo
    _MATERIALI[chiave] = m
    return m


def mat_immagine(nome, percorso, sotto, tipo="stoffa"):
    """Materiale con un'immagine (PNG con trasparenza) sopra il colore "sotto": facce, disegni degli scudi."""
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    n, l = m.node_tree.nodes, m.node_tree.links
    img = n.new("ShaderNodeTexImage")
    img.image = bpy.data.images.load(percorso, check_existing=False)
    img.extension = "CLIP"
    img.interpolation = "Cubic"
    proiezione = n.new("ShaderNodeUVMap")  # la proiezione dal davanti, non l'atlante della cottura
    proiezione.uv_map = "UV"
    l.new(proiezione.outputs["UV"], img.inputs["Vector"])
    mix = n.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs["A"].default_value = (*lineare(sotto), 1)
    l.new(img.outputs["Alpha"], mix.inputs["Factor"])
    l.new(img.outputs["Color"], mix.inputs["B"])
    _grana(m, tipo, mix.outputs["Result"])
    m["colore"], m["tipo"], m["immagine"] = sotto, tipo, percorso
    return m


def tornio(profilo, lati):
    """Solido di rotazione attorno a Y: profilo = [(raggio, y)] dal basso in alto; raggio 0 = polo."""
    bm = bmesh.new()
    anelli = []
    for r, y in profilo:
        if r < 1e-9:
            anelli.append([bm.verts.new((0, y, 0))])
        else:
            anelli.append([bm.verts.new((r * math.cos(2 * math.pi * k / lati), y, r * math.sin(2 * math.pi * k / lati)))
                           for k in range(lati)])
    for a, b in zip(anelli, anelli[1:]):
        for k in range(lati):
            if len(a) == 1:
                bm.faces.new((a[0], b[(k + 1) % lati], b[k]))
            elif len(b) == 1:
                bm.faces.new((a[k], a[(k + 1) % lati], b[0]))
            else:
                bm.faces.new((a[k], a[(k + 1) % lati], b[(k + 1) % lati], b[k]))
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    return bm


# -- Modello ---------------------------------------------------------------------------------------------

class Modello:
    """Raccoglie ossa e pezzi. Ogni pezzo è un oggetto Blender con i gruppi di vertici delle sue ossa."""

    def __init__(self, nome):
        self.nome = nome
        self.ossa = {}  # nome -> (padre, posizione roblox)
        self.ordine = []
        self.pezzi = []
        self.trasforma = None  # funzione(p roblox) -> p: per i cavalieri, rimpiccioliti attorno alla sella
        self.trasformate = {}
        self.coll = bpy.data.collections.new(nome)
        bpy.context.scene.collection.children.link(self.coll)

    def osso(self, nome, padre, posizione):
        self.ossa[nome] = (padre, np.asarray(posizione, float))
        self.trasformate[nome] = self.trasforma
        if nome not in self.ordine:
            self.ordine.append(nome)

    def P(self, nome):
        return self.ossa[nome][1]

    # Geometria: ogni funzione crea i vertici in coordinate locali, poi li porta al loro posto.
    def _oggetto(self, nome, bm, materiali, pesi, assi, centro, uv_piano=None):
        assi = np.eye(3) if assi is None else np.asarray(assi, float)
        centro = np.asarray(centro, float)
        if uv_piano:
            # Proiezione dal davanti (coordinate locali x, y) per facce e disegni.
            lw, lh = uv_piano
            uv = bm.loops.layers.uv.new("UV")
            for f in bm.faces:
                for lp in f.loops:
                    x, y = lp.vert.co.x, lp.vert.co.y
                    lp[uv].uv = (0.5 - x / lw, y / lh + 0.5)
        locali = [np.array(v.co) for v in bm.verts]
        t = self.trasforma or (lambda q: q)
        for v, p in zip(bm.verts, locali):
            v.co = blender(t(assi @ p + centro))
        me = bpy.data.meshes.new(nome)
        bm.to_mesh(me)
        bm.free()
        for m_ in materiali:
            me.materials.append(m_)
        ob = bpy.data.objects.new(nome, me)
        self.coll.objects.link(ob)
        # Pesi: lista [(osso, peso)] uguale per tutti, oppure funzione(posizione locale) -> lista.
        gruppi = {}
        for i, p in enumerate(locali):
            lista = pesi(p, assi @ p + centro) if callable(pesi) else pesi
            for osso, w in lista:
                if osso not in gruppi:
                    gruppi[osso] = ob.vertex_groups.new(name=osso)
                gruppi[osso].add([i], w, "REPLACE")
        self.pezzi.append(ob)
        return ob

    def scatola(self, nome, centro, misure, materiale, pesi, assi=None, smusso=0.0, rastrema=None,
                fronte=None, uv=False, segmenti=1):
        """Scatola. rastrema=(sx, sz): scala della faccia di sotto (gonne svasate).
        fronte: materiale della faccia davanti (-Z locale), per disegni proiettati (uv=True)."""
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co = Vector((v.co.x * misure[0], v.co.y * misure[1], v.co.z * misure[2]))
            if rastrema and v.co.y < 0:
                v.co.x *= rastrema[0]
                v.co.z *= rastrema[1]
        materiali = [materiale]
        if fronte is not None:
            materiali.append(fronte)
            for f in bm.faces:
                if f.normal.z < -0.5:
                    f.material_index = 1
        if smusso >= 0.005:  # gli smussi piu piccoli non si vedono nel gioco: niente triangoli in piu
            bmesh.ops.bevel(bm, geom=list(bm.edges), offset=smusso, segments=segmenti, affect="EDGES",
                            profile=0.5, clamp_overlap=True)
        return self._oggetto(nome, bm, materiali, pesi, assi, centro, uv_piano=(misure[0], misure[1]) if uv else None)

    def segmento(self, nome, da, a, larghezza, profondita, materiale, pesi, oltre=(0.0, 0.0), alto=None, smusso=0.0):
        """Scatola lungo da -> a (prolungata di oltre[0] prima e oltre[1] dopo)."""
        da, a = np.asarray(da, float), np.asarray(a, float)
        y = norm(a - da)
        riferimento = np.asarray(alto if alto is not None else (1, 0, 0), float)
        x = riferimento - y * riferimento.dot(y)
        if np.linalg.norm(x) < 1e-5:
            x = np.array([0, 0, 1.0]) - y * y[2]
        x = norm(x)
        z = np.cross(x, y)
        inizio, fine = da - y * oltre[0], a + y * oltre[1]
        lunghezza = np.linalg.norm(fine - inizio)
        return self.scatola(nome, (inizio + fine) / 2, (larghezza, lunghezza, profondita), materiale, pesi,
                            assi=np.column_stack([x, y, z]), smusso=smusso)

    def cilindro(self, nome, centro, raggio, altezza, materiale, pesi, lati=16, smusso=0.0, segmenti=3,
                 assi=None, raggio_sotto=None, fronte=None, uv=None, parte=None, smussa_sotto=True):
        """Cilindro verticale (asse Y locale). smusso: raggio dell'arrotondamento dei bordi delle basi."""
        if smusso > 0 and parte is None:
            # Al tornio: fianco dritto e basi arrotondate con un quarto di cerchio (il bevel di Blender sulle
            # basi di un cilindro viene ridotto quasi a niente dai lati corti).
            rb, h = min(smusso, raggio * 0.95, altezza / 2 * 0.95), altezza / 2
            profilo = [(0.0, -h)]
            if smussa_sotto:
                profilo += [(raggio - rb + rb * math.sin(a), -h + rb - rb * math.cos(a))
                            for a in np.linspace(0, math.pi / 2, segmenti + 1)]
            else:
                profilo += [(raggio, -h)]
            profilo += [(raggio - rb + rb * math.cos(a), h - rb + rb * math.sin(a))
                        for a in np.linspace(0, math.pi / 2, segmenti + 1)]
            profilo += [(0.0, h)]
            bm = tornio(profilo, lati)
        else:
            bm = bmesh.new()
            bmesh.ops.create_cone(bm, cap_ends=parte is None, cap_tris=False, segments=lati,
                                  radius1=raggio if raggio_sotto is None else raggio_sotto, radius2=raggio,
                                  depth=altezza)
            for v in bm.verts:  # asse Z del cono -> Y
                v.co = Vector((v.co.x, v.co.z, -v.co.y))
            if parte:  # mezzo tubo aperto, dietro (nuca dell'elmo) o davanti (rinforzo sulla fronte)
                segno = 1 if parte == "retro" else -1
                bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z * segno < -1e-4], context="VERTS")
        materiali = [materiale]
        if fronte is not None:
            materiali.append(fronte)
            bm.normal_update()
            for f in bm.faces:
                if f.calc_center_median().z < 0 and f.normal.z < -0.2:
                    f.material_index = 1
        for f in bm.faces:
            f.smooth = True
        return self._oggetto(nome, bm, materiali, pesi, assi, centro, uv_piano=uv)

    def disco(self, nome, centro, raggio, spessore, materiale, pesi, fronte=None, lati=24, assi=None,
              scala=(1.0, 1.0), bombato=0.0):
        """Disco con l'asse lungo Z locale: la base davanti (-Z) riceve "fronte" con la proiezione del disegno.
        scala: (x, y) per gli ovali. bombato: quanto sporge il centro davanti (scudi convessi)."""
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=lati, radius1=raggio, radius2=raggio,
                              depth=spessore)
        if bombato > 0:
            davanti = [f for f in bm.faces if f.normal.z < -0.5]
            bmesh.ops.inset_region(bm, faces=davanti, thickness=raggio * 0.3, depth=bombato * 0.6)
            bmesh.ops.inset_region(bm, faces=davanti, thickness=raggio * 0.35, depth=bombato * 0.4)
        for v in bm.verts:
            v.co.x *= scala[0]
            v.co.y *= scala[1]
        materiali = [materiale]
        bm.normal_update()
        if fronte is not None:
            materiali.append(fronte)
            for f in bm.faces:
                if f.normal.z < -0.3:
                    f.material_index = 1
        for f in bm.faces:
            f.smooth = abs(f.normal.z) < 0.3
        d = 2 * raggio
        return self._oggetto(nome, bm, materiali, pesi, assi, centro, uv_piano=(d * scala[0], d * scala[1]))

    def sfera(self, nome, centro, raggio, materiale, pesi, anelli=6, lati=10, schiaccia=(1, 1, 1), meta=False):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=lati, v_segments=anelli, radius=raggio)
        for v in bm.verts:
            v.co = Vector((v.co.x * schiaccia[0], v.co.z * schiaccia[1], -v.co.y * schiaccia[2]))
        if meta:  # mezza sfera verso -Z (umboni degli scudi)
            via = [v for v in bm.verts if v.co.z > 1e-5]
            for v in via:
                v.co.z = 0
        for f in bm.faces:
            f.smooth = True
        return self._oggetto(nome, bm, [materiale], pesi, None, centro)

    def cupola(self, nome, centro, raggio, altezza, materiale, pesi, anelli=4, lati=18):
        """Mezzo ellissoide con la base piatta in "centro" (calotte degli elmi)."""
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=lati, v_segments=anelli * 2, radius=1.0)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -1e-4], context="VERTS")
        bmesh.ops.holes_fill(bm, edges=list(bm.edges), sides=0)
        for v in bm.verts:
            v.co = Vector((v.co.x * raggio, v.co.z * altezza, -v.co.y * raggio))
        for f in bm.faces:
            f.smooth = len(f.verts) < 5
        return self._oggetto(nome, bm, [materiale], pesi, None, centro)

    def maglia(self, nome, vertici, facce, materiale, pesi):
        """Mesh libera: vertici già al loro posto (coordinate Roblox), facce come liste di indici."""
        bm = bmesh.new()
        vv = [bm.verts.new(tuple(map(float, v))) for v in vertici]
        for f in facce:
            bm.faces.new([vv[i] for i in f])
        bm.normal_update()
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        return self._oggetto(nome, bm, [materiale], pesi, None, (0, 0, 0))

    def lastra_curva(self, nome, centro, larghezza, altezza, spessore, raggio, materiale, pesi, fronte=None,
                     fette=10, assi=None):
        """Lastra piegata attorno all'asse verticale, con la pancia verso -Z (scudi curvi).
        La faccia davanti riceve "fronte" con la proiezione uv del disegno."""
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.subdivide_edges(bm, edges=[e for e in bm.edges if abs(e.verts[0].co.x - e.verts[1].co.x) > 0.5],
                                  cuts=fette - 1, use_grid_fill=True)
        for v in bm.verts:
            x = v.co.x * larghezza
            v.co = Vector((x, v.co.y * altezza, v.co.z * spessore + (raggio - math.sqrt(raggio ** 2 - x ** 2))))
        bm.normal_update()
        materiali = [materiale]
        if fronte is not None:
            materiali.append(fronte)
            for f in bm.faces:
                if f.normal.z < -0.5:
                    f.material_index = 1
        return self._oggetto(nome, bm, materiali, pesi, assi, centro, uv_piano=(larghezza, altezza))

    # -- Fine ---------------------------------------------------------------------------------------------

    def armatura(self):
        dati = bpy.data.armatures.new(self.nome + "_Ossa")
        arm = bpy.data.objects.new(self.nome + "_Ossa", dati)
        self.coll.objects.link(arm)
        bpy.context.view_layer.objects.active = arm
        bpy.ops.object.mode_set(mode="EDIT")
        for nome in self.ordine:
            b = dati.edit_bones.new(nome)
            tr = self.trasformate.get(nome) or (lambda q: q)
            t = blender(tr(self.P(nome)))
            b.head = t
            b.tail = t + Vector((0, 0, 0.1))
        for nome in self.ordine:
            padre = self.ossa[nome][0]
            if padre:
                dati.edit_bones[nome].parent = dati.edit_bones[padre]
        bpy.ops.object.mode_set(mode="OBJECT")
        for ob in self.pezzi:
            mod = ob.modifiers.new("Ossa", "ARMATURE")
            mod.object = arm
            ob.parent = arm
        self.arm = arm
        return arm


# -- Corpo -----------------------------------------------------------------------------------------------

def scheletro(m, mano_r, mano_l):
    """Ossa del soldato in piedi, come soldati.py. mano_r/mano_l: direzione dell'avambraccio."""
    m.osso("bacino", None, (0, GAMBE, 0))
    m.osso("spina", "bacino", (0, GAMBE + 0.12, 0))
    m.osso("torace", "spina", (0, GAMBE + 0.34, 0))
    m.osso("testa", "torace", (0, COLLO, 0))
    for lato, segno, direzione in (("L", -1, mano_l), ("R", 1, mano_r)):
        spalla = np.array([segno * X_BRACCIO, SPALLA, 0])
        gomito = spalla + np.array([0, -OMERO, 0])
        polso = gomito + norm(direzione) * AVAMBRACCIO
        m.osso("braccio." + lato, "torace", spalla)
        m.osso("avambraccio." + lato, "braccio." + lato, gomito)
        m.osso("mano." + lato, "avambraccio." + lato, polso)
    for lato, segno in (("L", -1), ("R", 1)):
        m.osso("coscia." + lato, "bacino", (segno * X_GAMBA, GAMBE, 0))
        m.osso("stinco." + lato, "coscia." + lato, (segno * X_GAMBA, GAMBE * 0.5, 0))
        m.osso("piede." + lato, "stinco." + lato, (segno * X_GAMBA, 0.07, 0))


BUSTO_PESI = [("torace", 0.75), ("spina", 0.25)]


def busto(m, materiale):
    return m.scatola("busto", (0, GAMBE + BUSTO_A / 2, 0), (BUSTO_L, BUSTO_A, BUSTO_P), materiale, BUSTO_PESI,
                     smusso=0.0)


def testa(m, pelle, faccia):
    """Testa classica di Roblox: cilindro con le basi arrotondate, faccia proiettata dal davanti."""
    pelle_m = mat(pelle, "pelle")
    faccia_m = mat_immagine("faccia_" + m.nome, faccia, pelle, "pelle")
    return m.cilindro("testa", (0, TESTA_Y, 0), TESTA_D / 2, TESTA_H, pelle_m, [("testa", 1.0)], lati=20,
                      smusso=0.3 * S, segmenti=3, fronte=faccia_m, uv=(TESTA_D, TESTA_H))


def braccio(m, lato, manica, pelle, manica_fino=None, avambraccio=None, mano=None):
    """Braccio a blocco piegato al gomito: omero (manica fino a "manica_fino" sotto la spalla, poi pelle),
    avambraccio e pugno lungo la direzione della mano."""
    spalla, gomito, polso = m.P("braccio." + lato), m.P("avambraccio." + lato), m.P("mano." + lato)
    x = spalla[0]
    fondo = gomito[1] - ARTO / 2
    taglio = COLLO - (manica_fino if manica_fino is not None else 1.1 * S)
    taglio = max(taglio, fondo)
    m.scatola("omero." + lato, (x, (COLLO + taglio) / 2, 0), (ARTO, COLLO - taglio, ARTO), manica,
              [("braccio." + lato, 1.0)], smusso=0.0)
    if taglio > fondo + 1e-4:
        m.scatola("gomito." + lato, (x, (taglio + fondo) / 2, 0), (ARTO * 0.995, taglio - fondo, ARTO * 0.995),
                  pelle, [("braccio." + lato, 1.0)], smusso=0.0)
    d = norm(polso - gomito)
    # Avambraccio: dal dietro del gomito al polso, un filo più sottile per non sfarfallare con l'omero.
    m.segmento("avambraccio." + lato, gomito, polso, ARTO * 0.985, ARTO * 0.985, avambraccio or pelle,
               [("avambraccio." + lato, 1.0)], oltre=(ARTO / 2 - 0.004, 0.0), smusso=0.0)
    m.segmento("pugno." + lato, polso, polso + d * MANO, ARTO * 0.975, ARTO * 0.975, mano or pelle,
               [("mano." + lato, 1.0)],
               oltre=(0.004, 0.0), smusso=0.0)


def gamba(m, lato, sopra, sotto, taglio=None):
    """Gamba a blocco: coscia (colore "sopra") e stinco (colore "sotto"), il taglio al ginocchio."""
    anca, ginocchio = m.P("coscia." + lato), m.P("stinco." + lato)
    x = anca[0]
    taglio = ginocchio[1] if taglio is None else taglio
    m.scatola("coscia." + lato, (x, (GAMBE + taglio - 0.02) / 2, 0), (ARTO, GAMBE - taglio + 0.02, ARTO), sopra,
              [("coscia." + lato, 1.0)], smusso=0.0)
    m.scatola("stinco." + lato, (x, taglio / 2, 0), (ARTO * 0.99, taglio, ARTO * 0.99), sotto,
              [("stinco." + lato, 1.0)], smusso=0.0)


def anello(m, nome, centro, misure, spessore, materiale, pesi, smusso=0.004, rastrema=None):
    """Fascia attorno a un blocco (cinture, bordi delle maniche, lacci): scatola un po' più grande.
    Se arriva in cima al busto o alle braccia copre anche la cima (alzata di mezzo spessore): una faccia sullo
    stesso piano di quella del corpo si fa ombra da sola e nel bake dell'occlusione viene nera."""
    if abs(centro[1] + misure[1] / 2 - COLLO) < 1e-4:
        d = spessore / 2
        centro = (centro[0], centro[1] + d / 2, centro[2])
        misure = (misure[0], misure[1] + d, misure[2])
    return m.scatola(nome, centro, (misure[0] + 2 * spessore, misure[1], misure[2] + 2 * spessore), materiale, pesi,
                     smusso=smusso, rastrema=rastrema)


# -- Disegni dipinti ---------------------------------------------------------------------------------------

class Penna:
    """Disegna su un'immagine con le coordinate 0-1 (v verso il basso), come i pittori dei modelli a blocchi.
    "riempi" copre tutto (il disegno diventa opaco); senza "riempi" il fondo resta trasparente."""

    def __init__(self, lato=512):
        from PIL import Image, ImageDraw
        self.L = lato * 3
        self.lato = lato
        self.img = Image.new("RGBA", (self.L, self.L), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)
        self.materiale = "stoffa"

    def _c(self, c):
        return tuple(int(c.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)) + (255,)

    def _p(self, u, v):
        return (u * self.L, v * self.L)

    def riempi(self, c, materiale="stoffa"):
        self.d.rectangle([0, 0, self.L, self.L], fill=self._c(c))

    def rett(self, u0, v0, u1, v1, c):
        self.d.rectangle([*self._p(min(u0, u1), min(v0, v1)), *self._p(max(u0, u1), max(v0, v1))], fill=self._c(c))

    def ellisse(self, u0, v0, u1, v1, c):
        self.d.ellipse([*self._p(min(u0, u1), min(v0, v1)), *self._p(max(u0, u1), max(v0, v1))], fill=self._c(c))

    def poligono(self, punti, c):
        self.d.polygon([self._p(u, v) for u, v in punti], fill=self._c(c))

    def linea(self, punti, c, spessore=0.01):
        self.d.line([self._p(u, v) for u, v in punti], fill=self._c(c), width=max(1, int(spessore * self.L * 1.5)),
                    joint="curve")

    def righe_v(self, n, c, spessore=0.04, v0=0, v1=1):
        for i in range(1, n + 1):
            v = v0 + (v1 - v0) * i / (n + 1)
            self.rett(0, v - spessore / 2, 1, v + spessore / 2, c)

    def salva(self, percorso):
        from PIL import Image
        self.img.resize((self.lato, self.lato), Image.LANCZOS).save(percorso)
        return percorso


_DISEGNI = {}


def disegno(cartella, nome, pittore, sotto, tipo="stoffa", lato=512):
    """Materiale con il disegno di "pittore(penna)" sopra il colore "sotto" (va su un pezzo con uv=True)."""
    chiave = (cartella, nome, sotto, tipo)
    if chiave not in _DISEGNI:
        p = Penna(lato)
        pittore(p)
        percorso = p.salva(os.path.join(cartella, f"disegno_{nome}.png"))
        _DISEGNI[chiave] = mat_immagine(f"disegno_{nome}", percorso, sotto, tipo)
    return _DISEGNI[chiave]


# -- Facce -----------------------------------------------------------------------------------------------

def faccia_png(tipo, percorso, lato=512):
    """Disegna una faccia (sfondo trasparente). Coordinate 0-1 sul davanti della testa, y verso il basso.
    "roblox": la faccia base di Roblox (due occhi ovali, sorriso). "fiero": occhi con la luce, sopracciglia
    decise e un mezzo sorriso sicuro."""
    from PIL import Image, ImageDraw
    k = 4  # disegno grande e poi rimpicciolito: bordi lisci
    L = lato * k
    img = Image.new("RGBA", (L, L), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    P = lambda u, v: (u * L, v * L)
    nero = (20, 20, 20, 255)

    def ellisse(u0, v0, u1, v1, c):
        d.ellipse([*P(u0, v0), *P(u1, v1)], fill=c)

    def arco(punti, spessore, c):
        pts = [P(u, v) for u, v in punti]
        d.line(pts, fill=c, width=int(spessore * L), joint="curve")
        r = spessore * L / 2
        for x, y in (pts[0], pts[-1]):
            d.ellipse([x - r, y - r, x + r, y + r], fill=c)

    if tipo == "roblox":
        for u in (0.37, 0.63):
            ellisse(u - 0.042, 0.33, u + 0.042, 0.50, nero)
        curva = [(0.30 + 0.4 * t, 0.62 + 0.11 * math.sin(math.pi * t)) for t in np.linspace(0, 1, 24)]
        arco(curva, 0.032, nero)
    elif tipo == "fiero":
        marrone = (48, 28, 18, 255)
        for u, s in ((0.36, -1), (0.64, 1)):
            ellisse(u - 0.05, 0.37, u + 0.05, 0.53, nero)
            ellisse(u - 0.028, 0.39, u + 0.006, 0.44, (255, 255, 255, 255))
            # Sopracciglia spesse, più basse verso il naso: sguardo deciso.
            interno, esterno = u - s * 0.07, u + s * 0.08
            d.polygon([P(esterno, 0.305), P(interno, 0.335), P(interno, 0.375), P(esterno, 0.345)], fill=marrone)
        # Mezzo sorriso sicuro: dritto a sinistra, sale a destra (di chi guarda), con la fossetta.
        curva = [(0.40 + 0.24 * t, 0.675 + 0.012 * math.sin(math.pi * t) - 0.05 * t ** 2.2) for t in np.linspace(0, 1, 24)]
        arco(curva, 0.03, nero)
        arco([(0.655, 0.60), (0.668, 0.635)], 0.018, nero)
    img = img.resize((lato, lato), Image.LANCZOS)
    img.save(percorso)
    return percorso
