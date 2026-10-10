"""Cavallo per la cavalleria e i generali a cavallo.

Base: "Rigged Horse" di OpenGameArt (licenza CC0: modello di Lyndon Daniels, scheletro di ChadM,
https://opengameart.org/content/rigged-horse), con la sua texture del manto. Qui lo portiamo in scala,
lo mettiamo sotto il cavaliere (la sella sotto il suo bacino) e gli rifacciamo criniera e coda in
geometria piena (le ciocche trasparenti dell'originale non sopravvivono alla texture cotta del gioco).
In più: briglie, redini e gualdrappa misurate sul corpo vero del cavallo.

Convenzioni come il soldato: il cavallo guarda verso -Y, la sua destra è -X.
Ossa del gioco del cavallo: cavallo (radice), cavallo.collo, cavallo.muso, cavallo.coda e
zampa.{AR,AL,PR,PL}{1,2,3} (A = anteriore, P = posteriore, R/L = destra/sinistra; 1 spalla o anca,
2 gomito o grassella, 3 ginocchio o garretto). Il bacino del cavaliere è figlio di "cavallo".
"""

import math
import os
import urllib.request

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

import umano
import vestiti as V

URL = "https://opengameart.org/sites/default/files/riggedHorse.blend"
FILE = os.path.join(umano.CARTELLA, "riggedHorse.blend")

# Gruppi di vertici dell'originale -> ossa del gioco. Nell'originale "_L" davanti è la destra del cavallo.
MAPPA = {
    "Bone": "cavallo", "Bone.003": "cavallo", "Bone.004": "cavallo.coda", "Bone.005": "cavallo.coda",
    "Bone.001": "cavallo.collo", "Bone.002": "cavallo.muso", "Bone.001_L": "cavallo.muso", "Bone.001_R": "cavallo.muso",
    "Bone_L": "zampa.AR1", "Bone_L.001": "zampa.AR2", "Bone_L.002": "zampa.AR3",
    "Bone_R": "zampa.AL1", "Bone_R.001": "zampa.AL2", "Bone_R.002": "zampa.AL3",
    "Bone_L.003": "zampa.PL1", "Bone_L.004": "zampa.PL2", "Bone_L.005": "zampa.PL3",
    "Bone_R.003": "zampa.PR1", "Bone_R.004": "zampa.PR2", "Bone_R.005": "zampa.PR3",
}
# Ossa del gioco: (padre, osso dell'originale, estremo da cui ruota).
OSSA = {
    "cavallo": (None, "Bone", "mezzo"),
    "cavallo.collo": ("cavallo", "Bone.001", "testa"),
    "cavallo.muso": ("cavallo.collo", "Bone.002", "testa"),
    "cavallo.coda": ("cavallo", "Bone.004", "testa"),
    "zampa.AR1": ("cavallo", "Bone_L", "testa"), "zampa.AR2": ("zampa.AR1", "Bone_L.001", "testa"),
    "zampa.AR3": ("zampa.AR2", "Bone_L.002", "testa"),
    "zampa.AL1": ("cavallo", "Bone_R", "testa"), "zampa.AL2": ("zampa.AL1", "Bone_R.001", "testa"),
    "zampa.AL3": ("zampa.AL2", "Bone_R.002", "testa"),
    "zampa.PL1": ("cavallo", "Bone_L.003", "testa"), "zampa.PL2": ("zampa.PL1", "Bone_L.004", "testa"),
    "zampa.PL3": ("zampa.PL2", "Bone_L.005", "testa"),
    "zampa.PR1": ("cavallo", "Bone_R.003", "testa"), "zampa.PR2": ("zampa.PR1", "Bone_R.004", "testa"),
    "zampa.PR3": ("zampa.PR2", "Bone_R.005", "testa"),
}
ALTEZZA_ORIGINALE = 6.5       # garrese dell'originale, in sue unità (circa)


def assicura_file():
    if os.path.exists(FILE):
        return FILE
    os.makedirs(umano.CARTELLA, exist_ok=True)
    richiesta = urllib.request.Request(URL, headers={"User-Agent": "Mozilla/5.0 Blender"})
    with urllib.request.urlopen(richiesta, timeout=300) as r, open(FILE, "wb") as f:
        f.write(r.read())
    return FILE


# Posa del cavaliere --------------------------------------------------------------------------------

def punta(sch, nome, bersaglio):
    """Gira un osso attorno alla sua testa finché la coda guarda verso il bersaglio."""
    pb = sch.pose.bones[nome]
    a = (pb.tail - pb.head).normalized()
    b = (Vector(bersaglio) - pb.head).normalized()
    asse = a.cross(b)
    if asse.length < 1e-6:
        return
    umano.ruota_mondo(sch, nome, tuple(asse.normalized()), math.degrees(a.angle(b)))


def impugna(sch, s, punto, pollice, dita, polo, chiusura=1.0):
    """Pugno chiuso su un'asta (o sulle redini) che passa per 'punto': il pollice guarda lungo 'pollice',
    le dita girano attorno all'asta partendo verso 'dita'. È vestiti.impugna_verticale per un'asta qualsiasi."""
    su = Vector(pollice).normalized()
    avanti = Vector(dita)
    avanti = (avanti - su * avanti.dot(su)).normalized()
    phi = math.radians(15)
    radiale = su * math.cos(phi) - avanti * math.sin(phi)
    y = avanti * math.cos(phi) + su * math.sin(phi)
    dorso = (y.cross(radiale) if s < 0 else radiale.cross(y)).normalized()
    umano.posa_braccio(sch, s, Vector(punto) - y * 0.09 + dorso * 0.028, y, dorso, polo)
    umano.chiudi_dita(sch, s, {d: tuple(a * chiusura for a in g) for d, g in
                               {"indice": (70, 95, 50), "medio": (75, 95, 50), "anulare": (80, 95, 50),
                                "mignolo": (85, 90, 50), "pollice": (35, 45, 35)}.items()})


def seduto(sch, ginocchio, caviglia, piede):
    """Gambe a cavallo: coscia verso il ginocchio, stinco verso la caviglia, piede lungo 'piede' (lato sinistro,
    x > 0; il destro è lo specchio)."""
    for s in (1, -1):
        k = umano.sigla(s)
        punta(sch, "coscia" + k, (s * ginocchio[0], ginocchio[1], ginocchio[2]))
        punta(sch, "stinco" + k, (s * caviglia[0], caviglia[1], caviglia[2]))
        coda = sch.pose.bones["stinco" + k].tail.copy()
        punta(sch, "piede" + k, coda + Vector((s * piede[0], piede[1], piede[2])))


class Cavallo:
    """Il cavallo dentro un'unità: corpo, ossa (estremi nel mondo) e attrezzi per misurarlo."""

    def __init__(self, u, scala=0.24, snello=0.92, sella=(0.0, 0.0, 0.86), arretra=0.24, manto=None):
        """scala: 0.24 dà circa 1,55 m al garrese; snello stringe il corpo di lato (l'originale è un tiro pesante).
        sella: dove deve stare il punto più basso della sella (sotto il bacino del cavaliere).
        arretra: dove sta la sella tra garrese (0) e groppa (1)."""
        self.u = u
        assicura_file()
        with bpy.data.libraries.load(FILE, link=False) as (_, dst):
            dst.objects = ["Plane", "Armature"]
            dst.images = ["HorseMain4k00.png"]
        pelle, scheletro = dst.objects
        immagine = dst.images[0]
        for o in (pelle, scheletro):
            u.col.objects.link(o)
        bpy.context.view_layer.update()
        deps = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(pelle.evaluated_get(deps), preserve_all_data_layers=True, depsgraph=deps)
        me.transform(pelle.matrix_world)
        gruppi = [g.name for g in pelle.vertex_groups]
        ossa = {b.name: (scheletro.matrix_world @ b.head_local, scheletro.matrix_world @ b.tail_local)
                for b in scheletro.data.bones}
        for o in (pelle, scheletro):
            dati = o.data
            bpy.data.objects.remove(o, do_unlink=True)
            if dati.users == 0:
                (bpy.data.meshes if isinstance(dati, bpy.types.Mesh) else bpy.data.armatures).remove(dati)

        # Scala, poi zoccoli a terra e sella sotto il cavaliere.
        m = Matrix.Diagonal((scala * snello, scala, scala, 1.0))
        me.transform(m)
        ossa = {k: (m @ a, m @ b) for k, (a, b) in ossa.items()}
        garrese, groppa = ossa["Bone"][1], ossa["Bone"][0]
        punto = garrese.lerp(groppa, arretra)
        albero = BVHTree.FromPolygons([v.co.copy() for v in me.vertices], [tuple(p.vertices) for p in me.polygons])
        colpo = albero.ray_cast(Vector((0, punto.y, punto.z + 2)), Vector((0, 0, -1)), 4)
        dorso = colpo[0] if colpo[0] is not None else punto
        spostamento = Vector(sella) - Vector((0, dorso.y, dorso.z))
        me.transform(Matrix.Translation(spostamento))
        self.ossa = {k: (a + spostamento, b + spostamento) for k, (a, b) in ossa.items()}

        self.corpo = bpy.data.objects.new("CV_Corpo", me)
        u.col.objects.link(self.corpo)
        self.corpo.parent = u.radice
        if len(self.corpo.vertex_groups) == 0:
            for nome in gruppi:
                self.corpo.vertex_groups.new(name=nome)
        me.materials.clear()
        me.materials.append(u.materiale("Manto", manto or (1.0, 1.0, 1.0), ruvidita=0.7, immagine=immagine))
        if manto:
            # Il manto colora la texture (moltiplica), per avere bai scuri, morelli o grigi.
            nodi = u.mat["Manto"].node_tree
            bsdf = nodi.nodes["Principled BSDF"]
            mix = nodi.nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.blend_type = "MULTIPLY"
            mix.inputs["Factor"].default_value = 1.0
            nodi.links.new(nodi.nodes["Texture"].outputs["Color"], mix.inputs[6])
            mix.inputs[7].default_value = (*manto, 1.0)
            nodi.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
        for p in me.polygons:
            p.use_smooth = True
        self.albero = BVHTree.FromPolygons([v.co.copy() for v in me.vertices], [tuple(p.vertices) for p in me.polygons])
        self.dorso = dorso + spostamento

    # Misure ----------------------------------------------------------------------------------------

    def osso(self, nome, t=0.0):
        a, b = self.ossa[nome]
        return a.lerp(b, t)

    def perni(self):
        """Ossa del gioco del cavallo, per esporta.prepara(extra=...): nome -> (padre, punto)."""
        risultato = {}
        for nome, (padre, originale, estremo) in OSSA.items():
            t = {"testa": 0.0, "mezzo": 0.5, "coda": 1.0}[estremo]
            risultato[nome] = (padre, tuple(self.osso(originale, t)))
        return risultato

    def esporta_cavallo(self, pezzi=("CV_*",)):
        """Argomento cavallo= di esporta.prepara."""
        return {"corpo": self.corpo.name, "mappa": dict(MAPPA), "radice": "cavallo", "pezzi": list(pezzi)}

    def sulla_pelle(self, centro, direzione, distacco, portata=1.0):
        hit = self.albero.ray_cast(Vector(centro), Vector(direzione).normalized(), portata)
        if hit[0] is None:
            return None
        return hit[0] + Vector(direzione).normalized() * distacco

    def anello(self, centro, asse, distacco, n=32, portata=0.6):
        """Punti della pelle attorno a un asse (per briglie e fasce): (punti, direzioni)."""
        asse = Vector(asse).normalized()
        base = Vector((1, 0, 0)) - asse * asse.x
        base.normalize()
        punti, direzioni = [], []
        for j in range(n + 1):
            d = Matrix.Rotation(2 * math.pi * j / n, 3, asse) @ base
            p = self.sulla_pelle(centro, d, distacco, portata)
            if p is not None:
                punti.append(p)
                direzioni.append(d)
        return punti, direzioni

    # Pezzi -----------------------------------------------------------------------------------------

    def criniera_rasata(self, mat, altezza=0.075, spessore=0.035, n=26):
        """Criniera tagliata corta e dritta, come i cavalli del Partenone e del mosaico di Alessandro."""
        a, b = self.ossa["Bone.001"]
        asse = (b - a).normalized()
        su = Vector((0, 0, 1)) - asse * asse.z
        su = (su - asse * su.dot(asse)).normalized()
        # Il lato del collo verso l'alto e indietro (la cresta).
        cresta = (su - asse * 0.0).normalized()
        anelli = []
        for i in range(n):
            t = 0.04 + 0.9 * i / (n - 1)
            c = a.lerp(b, t)
            p = self.sulla_pelle(c, cresta, -0.01) or (c + cresta * 0.1)
            h = altezza * math.sin(math.pi * min(1.0, (t + 0.05) / 0.95)) ** 0.5 * (1 + 0.12 * math.sin(t * 60))
            w = spessore * (0.6 + 0.4 * math.sin(math.pi * t))
            x = Vector((1, 0, 0))
            alto = p + cresta * h
            anelli.append([p + x * w, alto + x * w * 0.35 + asse * 0.006, alto - x * w * 0.35 + asse * 0.006, p - x * w])
        bm = V.griglia(anelli, chiusa=True)
        bm.verts.ensure_lookup_table()
        bm.faces.new([bm.verts[k] for k in range(4)][::-1])
        bm.faces.new([bm.verts[len(bm.verts) - 4 + k] for k in range(4)])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        # Ciuffo sulla fronte, tra le orecchie.
        nuca = self.osso("Bone.002", 0.05)
        avanti = (self.osso("Bone.002", 1.0) - nuca).normalized()
        base = self.sulla_pelle(nuca, cresta, -0.01) or nuca
        ciuffo = [base, base + avanti * 0.05 + cresta * 0.03, base + avanti * 0.11 + cresta * 0.01]
        ciuffo = [self._fuori(p, 0.012) for p in ciuffo]
        bm2 = V.tubo_lungo(ciuffo, [0.022, 0.018, 0.006], n=8)
        return self.u.oggetto("CV_Criniera", V.unisci(bm, bm2), mat)

    def _fuori(self, p, distacco):
        loc, normale, _, _ = self.albero.find_nearest(p)
        if loc is not None and (p - loc).dot(normale) < distacco:
            return loc + normale * distacco
        return p

    def criniera_lunga(self, mat, lato=-1, lunghezza=0.22, n=24, spessore=0.012):
        """Criniera lunga che ricade su un lato del collo (lato -1 = destra), a ciocche, più il ciuffo."""
        a, b = self.ossa["Bone.001"]
        asse = (b - a).normalized()
        su = Vector((0, 0, 1))
        su = (su - asse * su.dot(asse)).normalized()
        fuori = Vector((lato, 0, 0))
        righe = []
        for k in range(6):
            f = k / 5
            riga = []
            for i in range(n):
                t = 0.03 + 0.92 * i / (n - 1)
                c = a.lerp(b, t)
                cresta = self.sulla_pelle(c, su, 0.0) or (c + su * 0.1)
                # Scende sul lato seguendo la pelle, le ciocche di lunghezza diversa.
                lungo = lunghezza * (0.6 + 0.4 * math.sin(math.pi * min(1.0, t * 1.1))) * (1 + 0.18 * math.sin(i * 2.3))
                d = (su * (1 - f) + fuori * f * 1.2 - su * f * 0.6).normalized()
                p = cresta + d * lungo * f + su * 0.03 * (1 - f)
                riga.append(self._fuori(p, 0.018 + 0.01 * f))
            righe.append(riga)
        bm = V.griglia(righe)
        V._verso_fuori(bm)
        nuca = self.osso("Bone.002", 0.05)
        avanti = (self.osso("Bone.002", 1.0) - nuca).normalized()
        base = self.sulla_pelle(nuca, su, -0.01) or nuca
        ciuffo = [base, base + avanti * 0.06 + su * 0.02, base + avanti * 0.13 - su * 0.01]
        ciuffo = [self._fuori(p, 0.014) for p in ciuffo]
        bm2 = V.tubo_lungo(ciuffo, [0.026, 0.02, 0.006], n=8)
        o = self.u.oggetto("CV_Criniera", bm, mat, spessore=spessore)
        self.u.oggetto("CV_Ciuffo", bm2, mat)
        return o

    def coda(self, mat, lunghezza=0.95, legata=False, n=14):
        """Coda piena: attaccatura alta, poi giù con un po' di arco; ciocche in rilievo sulla superficie."""
        attacco = self.osso("Bone.004", 0.0)
        giu = (self.osso("Bone.004", 1.0) - attacco).normalized()
        dietro = Vector((0, 1, 0))
        punti, raggi = [], []
        passi = 16
        for i in range(passi + 1):
            t = i / passi
            # Esce un poco all'indietro e in su, poi cade.
            p = attacco + dietro * (0.10 * math.sin(math.pi * min(1, t * 2.2)) + 0.05 * t) + giu * (lunghezza * t ** 1.15)
            punti.append(p)
            if legata:
                r = 0.05 if t < 0.35 else 0.035 + 0.04 * math.sin(math.pi * (t - 0.35) / 0.65)
            else:
                r = 0.045 + 0.06 * math.sin(math.pi * min(1.0, t * 1.15)) ** 0.8
            raggi.append(max(r * (1 - 0.8 * max(0.0, t - 0.85) / 0.15), 0.006))
        bm = bmesh.new()
        anelli = []
        su_prec = None
        for i, p in enumerate(punti):
            avanti = (punti[min(i + 1, passi)] - punti[max(i - 1, 0)]).normalized()
            su = su_prec if su_prec is not None else Vector((1, 0, 0))
            su = (su - avanti * su.dot(avanti)).normalized()
            su_prec = su
            lato = avanti.cross(su)
            anello = []
            for k in range(n * 2):
                a = 2 * math.pi * k / (n * 2)
                # Ciocche: scanalature che girano un poco lungo la coda.
                r = raggi[i] * (1 + 0.14 * math.sin(a * 7 + i * 0.35)) * (1.0 if lato.dot(dietro) >= 0 else 1.0)
                anello.append(bm.verts.new(p + (su * math.cos(a) + lato * math.sin(a)) * r))
            anelli.append(anello)
        for x, y in zip(anelli, anelli[1:]):
            V.unisci_anelli(bm, x, y)
        bm.faces.new(list(reversed(anelli[0])))
        bm.faces.new(anelli[-1])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        return self.u.oggetto("CV_Coda", bm, mat)

    def briglie(self, mat, mat_metallo, mano=None, larghezza=0.018):
        """Testiera (dietro le orecchie e sul naso), montanti, morso e redini fino alla mano del cavaliere."""
        a, b = self.ossa["Bone.002"]
        asse = (b - a).normalized()
        pezzi = []
        # Nucale dietro le orecchie e capezzina sul naso.
        anelli = {}
        for nome, t, d in (("nuca", 0.10, 0.006), ("naso", 0.70, 0.006)):
            punti, direzioni = self.anello(a.lerp(b, t), asse, d, n=36, portata=0.5)
            anelli[nome] = (punti, direzioni)
            if len(punti) > 3:
                pezzi.append(V.striscia(punti, direzioni, larghezza))
        # Montanti: dalla nucale alla capezzina, sui due lati.
        estremi = []
        for s in (1, -1):
            lato = Vector((s, 0, 0))
            alto = self.sulla_pelle(a.lerp(b, 0.12), lato, 0.006, 0.5)
            basso = self.sulla_pelle(a.lerp(b, 0.78), lato + Vector((0, 0, -0.3)), 0.006, 0.5)
            if alto is None or basso is None:
                continue
            punti = [self._fuori(alto.lerp(basso, k / 8), 0.006) for k in range(9)]
            pezzi.append(V.striscia(punti, [lato] * len(punti), larghezza * 0.9))
            estremi.append(basso)
        u = self.u
        u.oggetto("CV_Briglie", V.unisci(*pezzi), mat, spessore=0.004)
        # Anelli del morso agli angoli della bocca.
        morsi = []
        for p in estremi:
            morsi.append(V.trasforma(V.tubo_lungo([p + Vector((0, 0.022 * math.cos(2 * math.pi * k / 12), 0.022 * math.sin(2 * math.pi * k / 12)))
                                                   for k in range(13)], 0.004, n=6, tappi=False), Matrix.Identity(4)))
        if morsi:
            u.oggetto("CV_Morso", V.unisci(*morsi), mat_metallo)
        # Redini: dai due anelli del morso alla mano, con una curva morbida.
        if mano is not None and estremi:
            redini = []
            for p in estremi:
                q = Vector(mano)
                punti = []
                for k in range(13):
                    t = k / 12
                    r = p.lerp(q, t) + Vector((0, 0, -0.10 * math.sin(math.pi * t)))
                    if t < 0.5:
                        r = self._fuori(r, 0.02)
                    punti.append(r)
                redini.append(V.tubo_lungo(punti, 0.006, n=6))
            u.oggetto("CV_Redini", V.unisci(*redini), mat)
        return estremi

    def gualdrappa(self, nome, mat, davanti=-0.04, dietro=0.30, angolo=72, cade=0.16, distacco=0.012, frange=0.0,
                   righe=18, colonne=36, spessore=0.006):
        """Telo sul dorso (pelle di pantera, coperta): da 'davanti' a 'dietro' (frazioni tra garrese e groppa,
        negative davanti al garrese), fino a 'angolo' gradi per lato, poi scende dritto di 'cade' metri.
        UV: u attraverso il dorso (0 destra, 1 sinistra), v dal davanti al dietro."""
        garrese, groppa = self.ossa["Bone"][1], self.ossa["Bone"][0]
        asse = (groppa - garrese).normalized()
        anelli, uvs = [], []
        for i in range(righe + 1):
            f = davanti + (dietro - davanti) * i / righe
            c = garrese.lerp(groppa, f) + Vector((0, 0, -0.12))
            riga, ruv = [], []
            bordo_dx, bordo_sx = None, None
            punti = []
            for j in range(colonne + 1):
                a = math.radians(-angolo + 2 * angolo * j / colonne)
                d = Vector((math.sin(a), 0, math.cos(a)))
                d = (d - asse * d.dot(asse)).normalized()
                p = self.sulla_pelle(c, d, distacco, 1.2) or (c + d * 0.3)
                punti.append(p)
            # Ai due lati il telo scende dritto (non segue la pancia).
            k_cade = max(2, int(colonne * 0.12))
            dx = [punti[0] + Vector((0, 0, -cade * (k + 1) / k_cade)) for k in range(k_cade)][::-1]
            sx = [punti[-1] + Vector((0, 0, -cade * (k + 1) / k_cade)) for k in range(k_cade)]
            dx = [p + Vector((-0.012 * (k_cade - k) / k_cade, 0, 0)) for k, p in enumerate(dx)]
            sx = [p + Vector((0.012 * (k + 1) / k_cade, 0, 0)) for k, p in enumerate(sx)]
            riga = dx + punti + sx
            anelli.append(riga)
        bm = V.griglia(anelli)
        livello = bm.loops.layers.uv.new("UVMap")
        larghezza = len(anelli[0])
        bm.verts.ensure_lookup_table()
        indice = {v: k for k, v in enumerate(bm.verts)}
        for f in bm.faces:
            for loop in f.loops:
                k = indice[loop.vert]
                loop[livello].uv = ((k % larghezza) / (larghezza - 1), (k // larghezza) / righe)
        V._verso_fuori(bm)
        o = self.u.oggetto(nome, bm, mat, spessore=spessore)
        return o, anelli
