"""Esporta una truppa R6 (truppe.py) in FBX per Roblox: un'unica mesh con le ossa e le mappe PBR cotte in Blender
(colore, metallo, ruvidezza, normali), così nel gioco ogni parte sembra il suo materiale vero.

blender --background --factory-startup --python tools/blocchi/r6/esporta.py -- <Nome> [<Nome> ...] [--lato 1024]
Scrive assets-truppe/<Nome>/: <Nome>.fbx, <Nome>.json (misure per Config/AssetTruppe) e le mappe
<Nome>_colore.png, _metallo.png, _ruvido.png, _normale.png.
"""
import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, QUI)
import r6  # noqa: E402
import truppe  # noqa: E402

RADICE = os.path.dirname(os.path.dirname(os.path.dirname(QUI)))
USCITA = os.path.join(RADICE, "assets-truppe")

# Studs per metro, come esporta_fbx.py: i comandanti sono più grandi.
METRI = {n: 2.8 for n in ("Annibale", "Cesare", "Guglielmo", "Giovanna", "Foch", "DeGaulle", "Saladino",
                          "GustavoAdolfo", "Napoleone", "Rommel")}
METRI["Elefante"] = 2.6  # come l'elefante di prima


def argomenti():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    lato, nomi, i = 1024, [], 0
    while i < len(a):
        if a[i] == "--lato":
            lato = int(a[i + 1])
            i += 2
        else:
            nomi.append(a[i])
            i += 1
    return nomi, lato


def _firma(v, nomi):
    """I pesi del vertice come chiave: due pezzi con la stessa firma si muovono insieme in ogni posa."""
    return tuple(sorted((nomi[g.group], round(g.weight, 3)) for g in v.groups if g.weight > 1e-4))


def togli_nascoste(m):
    """Leggerezza senza cambiare l'aspetto: via le facce sepolte dentro un altro pezzo chiuso che si muove con le
    stesse ossa (il busto sotto la giubba, le braccia sotto le maniche, la testa dentro l'elmo chiuso).
    Una faccia va via solo se ogni suo punto di prova, guardando in fuori lungo la sua normale, è dentro un solido
    chiuso (il primo colpo trova il rovescio di una faccia), quindi non si vede da nessun lato e in nessuna posa."""
    from mathutils.bvhtree import BVHTree
    pezzi = [o for o in m.pezzi if o.type == "MESH" and o.name != "cavallo" and len(o.data.polygons)]
    dati = []
    for o in pezzi:
        me = o.data
        nomi = {g.index: g.name for g in o.vertex_groups}
        firme = [_firma(v, nomi) for v in me.vertices]
        bm = bmesh.new()
        bm.from_mesh(me)
        chiuso = len(bm.edges) > 0 and all(e.is_manifold for e in bm.edges)
        bm.free()
        facce = []
        for p in me.polygons:
            f = {firme[i] for i in p.vertices}
            facce.append(f.pop() if len(f) == 1 else None)
        co = [v.co.copy() for v in me.vertices]
        minimo = Vector(np.min(np.array([c[:] for c in co]), 0))
        massimo = Vector(np.max(np.array([c[:] for c in co]), 0))
        dati.append(dict(o=o, chiuso=chiuso, facce=facce, co=co, min=minimo, max=massimo))
    # Un albero per pezzo chiuso e per firma (solo le sue facce con quella firma).
    alberi = []
    for k, d in enumerate(dati):
        if not d["chiuso"]:
            continue
        per_firma = {}
        for p, f in zip(d["o"].data.polygons, d["facce"]):
            if f is not None:
                per_firma.setdefault(f, []).append(list(p.vertices))
        for f, polys in per_firma.items():
            alberi.append((k, f, BVHTree.FromPolygons(d["co"], polys), d["min"], d["max"]))
    via_totale = 0
    for k, d in enumerate(dati):
        me = d["o"].data
        via = []
        for p, f in zip(me.polygons, d["facce"]):
            if f is None:
                continue
            candidati = [a for a in alberi if a[0] != k and a[1] == f]
            if not candidati:
                continue
            vs = [d["co"][i] for i in p.vertices]
            lo = Vector(np.min(np.array([v[:] for v in vs]), 0)) - Vector((0.1,) * 3)
            hi = Vector(np.max(np.array([v[:] for v in vs]), 0)) + Vector((0.1,) * 3)
            candidati = [a for a in candidati if all(a[3][i] <= hi[i] and a[4][i] >= lo[i] for i in range(3))]
            if not candidati:
                continue
            n = p.normal.copy()
            sepolta = True
            for i in range(1, len(vs) - 1):
                a, b, c = vs[0], vs[i], vs[i + 1]
                lato = max((b - a).length, (c - b).length, (a - c).length)
                passi = int(min(10, max(2, math.ceil(lato / 0.03))))
                for u in range(passi + 1):
                    for w in range(passi + 1 - u):
                        bu, bw = (u + 0.15) / (passi + 0.45), (w + 0.15) / (passi + 0.45)
                        q = a + (b - a) * bu + (c - a) * bw + n * 1e-4
                        dentro = False
                        vicino = 1e9
                        for _, _, albero, _, _ in candidati:
                            colpo = albero.ray_cast(q, n, 0.12)
                            if colpo[0] is not None and colpo[3] < vicino:
                                vicino = colpo[3]
                                dentro = colpo[1].dot(n) > 0
                        if not dentro:
                            sepolta = False
                            break
                    if not sepolta:
                        break
                if not sepolta:
                    break
            if sepolta:
                via.append(p.index)
        if via:
            bm = bmesh.new()
            bm.from_mesh(me)
            bm.faces.ensure_lookup_table()
            bmesh.ops.delete(bm, geom=[bm.faces[i] for i in via], context="FACES_ONLY")
            bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
            bm.to_mesh(me)
            bm.free()
            via_totale += len(via)
    print("NASCOSTE", m.nome, via_totale, "facce tolte")


def pesa_canna(ogg, arm, raggio=0.09):
    """Roblox butta via le ossa che non muovono nessun vertice: l'osso "canna" (bocca di fucili, pistole,
    mitragliatrici e cannoni, da cui il gioco fa partire il colpo) prende i vertici dell'arma vicini alla bocca,
    tolti al padre. È figlio del padre e il gioco non lo ruota: il movimento resta identico."""
    b = arm.data.bones.get("canna")
    if b is None or b.parent is None:
        return
    testa = arm.matrix_world @ b.head_local
    gruppi = {g.name: g for g in ogg.vertex_groups}
    padre = gruppi.get(b.parent.name)
    if padre is None:
        return
    canna = gruppi.get("canna") or ogg.vertex_groups.new(name="canna")
    pieni = []
    for v in ogg.data.vertices:
        pesi = {ogg.vertex_groups[g.group].name: g.weight for g in v.groups if g.weight > 1e-4}
        if pesi.get(b.parent.name, 0) > 0.999 and len(pesi) == 1:
            pieni.append(((ogg.matrix_world @ v.co - testa).length, v.index))
    pieni.sort()
    scelti = [i for d, i in pieni if d < raggio] or [i for _, i in pieni[:4]]
    padre.remove(scelti)
    canna.add(scelti, 1.0, "REPLACE")
    print("CANNA", ogg.name, len(scelti), "vertici")


def unisci(m):
    """Tutti i pezzi in una mesh sola (gruppi delle ossa e materiali restano)."""
    pezzi = [o for o in m.pezzi if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in pezzi:
        o.select_set(True)
    bpy.context.view_layer.objects.active = pezzi[0]
    bpy.ops.object.join()
    ogg = bpy.context.view_layer.objects.active
    ogg.name = m.nome
    return ogg


def atlante(ogg):
    """Nuova uv "Atlas" per la cottura: isole automatiche, la faccia (dettagli fini) più grande."""
    me = ogg.data
    uv = me.uv_layers.new(name="Atlas")
    me.uv_layers.active = uv
    bpy.ops.object.select_all(action="DESELECT")
    ogg.select_set(True)
    bpy.context.view_layer.objects.active = ogg
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.003, scale_to_bounds=False)
    # Facce e disegni (materiali con immagine): isole ingrandite prima dell'impacchettamento.
    bm = bmesh.from_edit_mesh(me)
    strato = bm.loops.layers.uv["Atlas"]
    grandi = {i for i, s in enumerate(me.materials) if s and "immagine" in s}
    for f in bm.faces:
        if f.material_index in grandi:
            for lp in f.loops:
                lp[strato].uv *= 4.0 if s_faccia(me.materials[f.material_index]) else 2.0
    bmesh.update_edit_mesh(me)
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(margin=0.004, rotate=True)
    bpy.ops.object.mode_set(mode="OBJECT")


def s_faccia(materiale):
    return materiale.name.startswith("faccia_")


def immagine(nome, lato, colore=True):
    img = bpy.data.images.new(nome, lato, lato, alpha=False, float_buffer=False)
    if not colore:
        img.colorspace_settings.name = "Non-Color"
    return img


def bersaglio(ogg, img):
    """Mette l'immagine come nodo attivo in ogni materiale (la cottura scrive lì)."""
    for m in ogg.data.materials:
        n = m.node_tree.nodes
        nodo = n.get("_bersaglio") or n.new("ShaderNodeTexImage")
        nodo.name = "_bersaglio"
        nodo.image = img
        n.active = nodo


def cuoci(ogg, tipo, img, filtro=None, campioni=1):
    sc = bpy.context.scene
    sc.cycles.samples = campioni
    bersaglio(ogg, img)
    b = sc.render.bake
    b.margin = 6
    b.use_selected_to_active = False
    if filtro is not None:
        b.use_pass_direct = False
        b.use_pass_indirect = False
        b.use_pass_color = True
    bpy.ops.object.bake(type=tipo, pass_filter=filtro or set(), normal_space="TANGENT", uv_layer="Atlas",
                        margin=6)


def con_colore_finto(ogg, valore_di):
    """Mette temporaneamente in Base Color un valore per materiale (per cuocere il metallo come colore)."""
    salvati = []
    for m in ogg.data.materials:
        n, l = m.node_tree.nodes, m.node_tree.links
        bsdf = n["Principled BSDF"]
        presa = bsdf.inputs["Base Color"]
        vecchio = presa.links[0].from_socket if presa.links else None
        v = valore_di(m, bsdf)
        rgb = n.new("ShaderNodeRGB")
        rgb.outputs[0].default_value = (v, v, v, 1)
        l.new(rgb.outputs[0], presa)
        salvati.append((m, rgb, vecchio))
    return salvati


def ripristina(salvati):
    for m, rgb, vecchio in salvati:
        n, l = m.node_tree.nodes, m.node_tree.links
        presa = n["Principled BSDF"].inputs["Base Color"]
        n.remove(rgb)
        if vecchio is not None:
            l.new(vecchio, presa)


def salva(img, percorso):
    img.filepath_raw = percorso
    img.file_format = "PNG"
    img.save()


def pixel(img):
    return np.array(img.pixels[:], dtype=np.float32).reshape(img.size[1], img.size[0], 4)


def esporta(nome, lato):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    r6.azzera()
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    cartella = os.path.join(USCITA, nome)
    os.makedirs(cartella, exist_ok=True)
    sorgenti = os.path.join(cartella, "_sorgenti")
    os.makedirs(sorgenti, exist_ok=True)
    faccia = r6.faccia_png("fiero", os.path.join(sorgenti, "faccia.png"))
    m = truppe.TRUPPE[nome](faccia, sorgenti)
    togli_nascoste(m)
    arm = m.armatura()
    ogg = unisci(m)
    pesa_canna(ogg, arm)
    atlante(ogg)

    # Cottura: colore (con un'ombra morbida nelle fessure), metallo, ruvidezza, normali.
    colore = immagine(nome + "_colore", lato)
    # Il colore "diffuso" di un metallo per Blender è nero: per cuocere il colore il metallo va a zero.
    metalli = [(m_, m_.node_tree.nodes["Principled BSDF"].inputs["Metallic"].default_value) for m_ in ogg.data.materials]
    for m_, _ in metalli:
        m_.node_tree.nodes["Principled BSDF"].inputs["Metallic"].default_value = 0.0
    cuoci(ogg, "DIFFUSE", colore, {"COLOR"})
    ao = immagine(nome + "_ao", lato, colore=False)
    cuoci(ogg, "AO", ao, campioni=48)
    c, o = pixel(colore), pixel(ao)
    c[..., :3] *= (0.62 + 0.38 * o[..., :1])
    colore.pixels[:] = c.ravel()
    salva(colore, os.path.join(cartella, nome + "_colore.png"))
    metallo = immagine(nome + "_metallo", lato // 2, colore=False)
    salvati = con_colore_finto(ogg, lambda m_, bsdf: dict(metalli)[m_])
    cuoci(ogg, "DIFFUSE", metallo, {"COLOR"})
    ripristina(salvati)
    for m_, v_ in metalli:
        m_.node_tree.nodes["Principled BSDF"].inputs["Metallic"].default_value = v_
    salva(metallo, os.path.join(cartella, nome + "_metallo.png"))
    ruvido = immagine(nome + "_ruvido", lato // 2, colore=False)
    cuoci(ogg, "ROUGHNESS", ruvido)
    salva(ruvido, os.path.join(cartella, nome + "_ruvido.png"))
    normale = immagine(nome + "_normale", lato if nome in METRI else lato // 2, colore=False)
    cuoci(ogg, "NORMAL", normale, campioni=4)
    salva(normale, os.path.join(cartella, nome + "_normale.png"))

    # Un solo materiale con le mappe cotte; via la uv della proiezione.
    finale = bpy.data.materials.new(nome)
    finale.use_nodes = True
    n, l = finale.node_tree.nodes, finale.node_tree.links
    bsdf = n["Principled BSDF"]
    for img, presa in ((colore, "Base Color"), (metallo, "Metallic"), (ruvido, "Roughness")):
        t = n.new("ShaderNodeTexImage")
        t.image = img
        l.new(t.outputs["Color"], bsdf.inputs[presa])
    t = n.new("ShaderNodeTexImage")
    t.image = normale
    nm = n.new("ShaderNodeNormalMap")
    l.new(t.outputs["Color"], nm.inputs["Color"])
    l.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    ogg.data.materials.clear()
    ogg.data.materials.append(finale)
    for f in ogg.data.polygons:
        f.material_index = 0
    for strato in [s for s in ogg.data.uv_layers if s.name != "Atlas"]:
        ogg.data.uv_layers.remove(strato)

    # Scala in studs (come le truppe di prima) e misure per il gioco.
    metri = METRI.get(nome, 2.34)
    ogg.data.transform(__import__("mathutils").Matrix.Scale(metri, 4))
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for b in arm.data.edit_bones:
        testa = b.head * metri
        b.head = testa
        b.tail = testa + Vector((0, 0, 0.1))
    bpy.ops.object.mode_set(mode="OBJECT")
    v = np.array([p.co[:] for p in ogg.data.vertices])
    roblox = np.stack([-v[:, 0], v[:, 2], v[:, 1]], axis=1)
    minimo, massimo = roblox.min(0), roblox.max(0)
    centro = (minimo + massimo) / 2
    json.dump({"metri": metri, "centro": centro.tolist(), "basso": float(minimo[1] - centro[1]),
               "triangoli": int(sum(len(p.vertices) - 2 for p in ogg.data.polygons))},
              open(os.path.join(cartella, nome + ".json"), "w"))

    fbx = os.path.join(cartella, nome + ".fbx")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(
        filepath=fbx, use_selection=False, object_types={"ARMATURE", "MESH"}, add_leaf_bones=False,
        bake_anim=False, use_armature_deform_only=False, primary_bone_axis="Y", secondary_bone_axis="X",
        mesh_smooth_type="FACE", path_mode="COPY", embed_textures=True, axis_forward="-Z", axis_up="Y",
        apply_scale_options="FBX_SCALE_ALL", use_tspace=True,
    )
    print("ESPORTATO", nome, len(v), "vertici", fbx)


def main():
    nomi, lato = argomenti()
    for nome in nomi:
        esporta(nome, lato)


main()
