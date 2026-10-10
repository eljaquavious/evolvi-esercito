"""Versione da gioco di un modello: pochi triangoli, scheletro semplice, texture cotta.

Dal modello ad alta definizione (costruito da uno script di truppa, per esempio legionario.py) fa:
1. una copia unita e decimata di tutti i pezzi (tranne i dettagli minuti, che finiscono nella texture);
2. i pesi sulle ossa del gioco (16 ossa: bacino, spina, torace, testa, braccia, avambracci, mani,
   cosce, stinchi, piedi), presi dal corpo per vestiti e armature, rigidi per armi e scudi;
3. una texture: il colore dei pezzi originali cotto sulle coordinate UV della copia;
4. i dati binari che legge src/shared/Mesh.luau (assi di Roblox: x = -x di Blender, y = z, z = y;
   misure in metri, il gioco le scala).

Uso (dentro Blender, dopo aver costruito il modello):
    E = carica_moduli(sha, "esporta")["esporta"]
    E.prepara(collezione, giunti, rigidi={...}, escludi=[...], triangoli=4000)   # ~20 s
    E.cuoci(lato=512)                                                            # ~30 s
    dati = E.dati()                                                              # dict JSON
"""

import base64
import fnmatch
import math
import struct

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

NOME = "Gioco"

# Ossa del gioco, con il padre. Le ossa del corpo realistico che mancano qui si fondono in quelle sotto.
OSSA = [
    ("bacino", None),
    ("spina", "bacino"),
    ("torace", "spina"),
    ("testa", "torace"),
    ("braccio.L", "torace"),
    ("avambraccio.L", "braccio.L"),
    ("mano.L", "avambraccio.L"),
    ("braccio.R", "torace"),
    ("avambraccio.R", "braccio.R"),
    ("mano.R", "avambraccio.R"),
    ("coscia.L", "bacino"),
    ("stinco.L", "coscia.L"),
    ("piede.L", "stinco.L"),
    ("coscia.R", "bacino"),
    ("stinco.R", "coscia.R"),
    ("piede.R", "stinco.R"),
]
INDICE = {nome: i for i, (nome, _) in enumerate(OSSA)}
DITA = ("pollice", "indice", "medio", "anulare", "mignolo")

STATO = {}


def osso_gioco(nome):
    """Osso del gioco in cui finisce un osso del corpo realistico."""
    if nome in INDICE:
        return nome
    base, _, lato = nome.partition(".")
    if base == "collo":
        return "testa"
    if base == "clavicola":
        return "torace"
    if base == "torsione":
        return "avambraccio." + lato
    if base.rstrip("123") in DITA:
        return "mano." + lato
    return None


def perno(nome, giunti):
    """Punto attorno a cui ruota l'osso del gioco (nella posa del modello)."""
    if nome == "testa":
        return Vector(giunti["collo"][0])
    return Vector(giunti[nome][0])


def roblox(v):
    return (-v[0], v[2], v[1])


def _mesh_valutata(o):
    deps = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(o.evaluated_get(deps), preserve_all_data_layers=True, depsgraph=deps)
    me.transform(o.matrix_world)
    return me


def _pesi_corpo(corpo):
    """Matrice (vertici del corpo x ossa del gioco) con i pesi del corpo realistico."""
    me = corpo.data
    pesi = np.zeros((len(me.vertices), len(OSSA)), dtype=np.float32)
    gruppi = {g.index: osso_gioco(g.name) for g in corpo.vertex_groups}
    for v in me.vertices:
        for g in v.groups:
            osso = gruppi.get(g.group)
            if osso:
                pesi[v.index, INDICE[osso]] += g.weight
    somma = pesi.sum(axis=1, keepdims=True)
    somma[somma == 0] = 1
    return pesi / somma


def _decima(me, obiettivo):
    """Riduce la mesh a circa "obiettivo" triangoli (collasso), tenendo gruppi e attributi."""
    attuali = sum(len(p.vertices) - 2 for p in me.polygons)
    if attuali <= obiettivo:
        return me
    temp = bpy.data.objects.new("_decima", me)
    bpy.context.scene.collection.objects.link(temp)
    mod = temp.modifiers.new("Decima", "DECIMATE")
    mod.ratio = obiettivo / attuali
    mod.use_collapse_triangulate = True
    deps = bpy.context.evaluated_depsgraph_get()
    nuova = bpy.data.meshes.new_from_object(temp.evaluated_get(deps), preserve_all_data_layers=True, depsgraph=deps)
    bpy.data.objects.remove(temp, do_unlink=True)
    bpy.data.meshes.remove(me)
    return nuova


def _budget(triangoli, totale, minimo=40):
    """Triangoli per pezzo: i pezzi grandi si riducono di più (in proporzione alla radice), i piccoli restano."""
    basso, alto = 0.0, 1000.0
    for _ in range(60):
        k = (basso + alto) / 2
        somma = sum(min(t, max(min(t, minimo), k * math.sqrt(t))) for t in triangoli)
        if somma > totale:
            alto = k
        else:
            basso = k
    return [int(min(t, max(min(t, minimo), basso * math.sqrt(t)))) for t in triangoli]


def prepara(collezione, giunti, rigidi=None, escludi=None, triangoli=4000, togli_dal_corpo=None, corpo="Corpo"):
    """Crea l'oggetto "Gioco": copia unita, pesata e decimata dei pezzi della collezione.

    rigidi: {"Lancia_*": "mano.R", ...} pezzi che seguono un osso solo.
    escludi: nomi (anche con *) dei dettagli minuti da non copiare (restano nella texture).
    togli_dal_corpo: materiali del corpo da buttare (pelle nascosta sotto i vestiti).
    Ogni pezzo si decima per conto suo, così quelli sottili (l'asta della lancia) non spariscono.
    """
    rigidi = rigidi or {}
    escludi = escludi or []
    vecchio = bpy.data.objects.get(NOME)
    if vecchio:
        bpy.data.objects.remove(vecchio, do_unlink=True)
    col = bpy.data.collections[collezione] if isinstance(collezione, str) else collezione
    sorgenti = [o for o in col.all_objects if o.type == "MESH" and o.visible_get()]
    oggetto_corpo = bpy.data.objects.get(corpo)
    pesi_corpo = _pesi_corpo(oggetto_corpo) if oggetto_corpo else None
    albero_corpo = None
    if oggetto_corpo:
        me_corpo = _mesh_valutata(oggetto_corpo)
        albero_corpo = (BVHTree.FromPolygons([v.co.copy() for v in me_corpo.vertices], [tuple(p.vertices) for p in me_corpo.polygons]),
                        [tuple(p.vertices) for p in me_corpo.polygons], [v.co.copy() for v in me_corpo.vertices])
        bpy.data.meshes.remove(me_corpo)
    ossa_corpo = {g.index: osso_gioco(g.name) for g in oggetto_corpo.vertex_groups} if oggetto_corpo else {}

    # Prima passata: le copie dei pezzi (il corpo senza la pelle nascosta).
    copie = []
    for o in sorgenti:
        if any(fnmatch.fnmatch(o.name, e) for e in escludi):
            continue
        me = _mesh_valutata(o)
        if o == oggetto_corpo and togli_dal_corpo:
            bm = bmesh.new()
            bm.from_mesh(me)
            via = [f for f in bm.faces if f.material_index < len(me.materials) and me.materials[f.material_index]
                   and me.materials[f.material_index].name in togli_dal_corpo]
            bmesh.ops.delete(bm, geom=via, context="FACES")
            bm.to_mesh(me)
            bm.free()
        copie.append((o, me))
    budget = _budget([sum(len(p.vertices) - 2 for p in me.polygons) for _, me in copie], triangoli)

    bm = bmesh.new()
    deform = bm.verts.layers.deform.verify()
    materiali = []
    for (o, me), obiettivo in zip(copie, budget):
        me = _decima(me, obiettivo)
        osso_rigido = next((osso for schema, osso in rigidi.items() if fnmatch.fnmatch(o.name, schema)), None)
        mappa = []
        for m in me.materials:
            if m not in materiali:
                materiali.append(m)
            mappa.append(materiali.index(m))
        pesi = []
        for v in me.vertices:
            w = np.zeros(len(OSSA), dtype=np.float32)
            if osso_rigido:
                w[INDICE[osso_rigido]] = 1
            elif o == oggetto_corpo:
                for g in v.groups:
                    osso = ossa_corpo.get(g.group)
                    if osso:
                        w[INDICE[osso]] += g.weight
            elif albero_corpo:
                albero, facce, punti = albero_corpo
                _, _, faccia, _ = albero.find_nearest(v.co)
                if faccia is not None:
                    somma = 0.0
                    for i in facce[faccia]:
                        d = 1.0 / max(1e-4, (punti[i] - v.co).length)
                        w = w + pesi_corpo[i] * d
                        somma += d
                    w = w / somma
            if w.sum() <= 0:
                w[INDICE["torace"]] = 1
            pesi.append(w / w.sum())
        for p in me.polygons:
            p.material_index = mappa[p.material_index] if p.material_index < len(mappa) else 0
        # I gruppi della copia non servono più: i pesi del gioco si scrivono a parte.
        inizio = len(bm.verts)
        bm.from_mesh(me)
        bm.verts.ensure_lookup_table()
        for k, w in enumerate(pesi):
            dv = bm.verts[inizio + k][deform]
            dv.clear()
            for i in np.nonzero(w > 0.01)[0]:
                dv[int(i)] = float(w[i])
        bpy.data.meshes.remove(me)

    me = bpy.data.meshes.new(NOME)
    bm.to_mesh(me)
    bm.free()
    for m in materiali:
        me.materials.append(m)
    for p in me.polygons:
        p.use_smooth = True
    gioco = bpy.data.objects.new(NOME, me)
    bpy.context.scene.collection.objects.link(gioco)
    for nome, _ in OSSA:
        gioco.vertex_groups.new(name=nome)
    gioco.hide_render = True

    STATO.clear()
    STATO.update({"giunti": {k: (tuple(v[0]), tuple(v[1])) for k, v in giunti.items()}, "sorgenti": [o.name for o in sorgenti]})
    return {"triangoli": sum(len(p.vertices) - 2 for p in me.polygons), "vertici": len(me.vertices),
            "pezzi": {o.name: b for (o, _), b in zip(copie, budget)}}


def cuoci(lato=512, margine=0.03):
    """Coordinate UV sulla copia e colore dei pezzi originali cotto in un'immagine."""
    gioco = bpy.data.objects[NOME]
    me = gioco.data
    # UV: proiezione automatica a isole.
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.to_mesh(me)
    bm.free()
    while me.uv_layers:
        me.uv_layers.remove(me.uv_layers[0])
    me.uv_layers.new(name="UV")
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    gioco.hide_set(False)
    gioco.select_set(True)
    bpy.context.view_layer.objects.active = gioco
    contesto = _contesto_3d()
    with bpy.context.temp_override(**contesto, active_object=gioco, selected_objects=[gioco], selected_editable_objects=[gioco], object=gioco):
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004, area_weight=0.6, scale_to_bounds=True)
        bpy.ops.object.mode_set(mode="OBJECT")

    immagine = bpy.data.images.get("Gioco_Colore")
    if immagine:
        bpy.data.images.remove(immagine)
    immagine = bpy.data.images.new("Gioco_Colore", lato, lato, alpha=False)
    mat = bpy.data.materials.get("Gioco_Cottura") or bpy.data.materials.new("Gioco_Cottura")
    mat.use_nodes = True
    nodi = mat.node_tree.nodes
    nodo = nodi.get("Cottura") or nodi.new("ShaderNodeTexImage")
    nodo.name = "Cottura"
    nodo.image = immagine
    nodi.active = nodo
    me.materials.clear()
    me.materials.append(mat)

    scena = bpy.context.scene
    scena.render.engine = "CYCLES"
    scena.cycles.samples = 4
    scena.cycles.device = "CPU"
    cottura = scena.render.bake
    cottura.use_selected_to_active = True
    cottura.cage_extrusion = margine
    cottura.max_ray_distance = margine * 3
    cottura.margin = 6
    cottura.use_pass_direct = False
    cottura.use_pass_indirect = False
    cottura.use_pass_color = True
    sorgenti = [bpy.data.objects[n] for n in STATO["sorgenti"] if n in bpy.data.objects]
    # Il colore "diffuso" dei metalli è nero: per la cottura i metalli diventano opachi del loro colore.
    metalli = {}
    for o in sorgenti:
        for m in o.data.materials:
            bsdf = m and m.use_nodes and m.node_tree.nodes.get("Principled BSDF")
            if bsdf and m.name not in metalli:
                metalli[m.name] = (bsdf, bsdf.inputs["Metallic"].default_value)
                bsdf.inputs["Metallic"].default_value = 0.0
    for o in sorgenti:
        o.hide_render = False
        o.select_set(True)
    gioco.hide_render = False
    gioco.select_set(True)
    bpy.context.view_layer.objects.active = gioco
    with bpy.context.temp_override(**contesto, active_object=gioco, selected_objects=sorgenti + [gioco], selected_editable_objects=sorgenti + [gioco]):
        bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, use_selected_to_active=True, cage_extrusion=margine,
                            max_ray_distance=margine * 3, margin=6)
    gioco.hide_render = True
    for bsdf, valore in metalli.values():
        bsdf.inputs["Metallic"].default_value = valore
    return {"lato": lato}


def _contesto_3d():
    for finestra in bpy.context.window_manager.windows:
        for area in finestra.screen.areas:
            if area.type == "VIEW_3D":
                return {"window": finestra, "area": area, "region": next(r for r in area.regions if r.type == "WINDOW")}
    return {}


def dati(lato_texture=256):
    """Dati per il gioco: ossa, geometria binaria e texture RGB, in base64 (non compressi)."""
    gioco = bpy.data.objects[NOME]
    me = gioco.data
    me.calc_loop_triangles()
    uv = me.uv_layers.active.data
    gruppi = {g.index: INDICE.get(g.name) for g in gioco.vertex_groups}
    # Pesi per vertice: le 4 ossa più forti.
    pesi_vertice = []
    for v in me.vertices:
        coppie = sorted(((g.weight, gruppi[g.group]) for g in v.groups if gruppi.get(g.group) is not None), reverse=True)[:4]
        if not coppie:
            coppie = [(1.0, INDICE["torace"])]
        somma = sum(w for w, _ in coppie)
        coppie = [(w / somma, i) for w, i in coppie]
        pesi_vertice.append(coppie)
    # Vertici del gioco: uno per ogni coppia (vertice, uv, normale) diversa.
    chiavi, vertici, triangoli = {}, [], []
    for tri in me.loop_triangles:
        indici = []
        for k in range(3):
            l = tri.loops[k]
            vi = tri.vertices[k]
            u, w = uv[l].uv
            n = tri.split_normals[k]
            chiave = (vi, round(u, 5), round(w, 5), round(n[0], 2), round(n[1], 2), round(n[2], 2))
            if chiave not in chiavi:
                chiavi[chiave] = len(vertici)
                vertici.append((vi, u, w, n))
            indici.append(chiavi[chiave])
        triangoli.append(indici)
    posizioni = np.array([roblox(me.vertices[v[0]].co) for v in vertici], dtype=np.float64)
    minimo, massimo = posizioni.min(axis=0), posizioni.max(axis=0)
    estensione = np.maximum(massimo - minimo, 1e-6)
    buf = bytearray(struct.pack("<II", len(vertici), len(triangoli)))
    for k, (vi, u, w, n) in enumerate(vertici):
        q = np.clip(np.round((posizioni[k] - minimo) / estensione * 65535), 0, 65535).astype(int)
        nr = roblox(n)
        coppie = pesi_vertice[vi]
        ossa = [i for _, i in coppie] + [0] * (4 - len(coppie))
        pesi = [int(round(p * 255)) for p, _ in coppie]
        pesi[0] += 255 - sum(pesi)
        pesi += [0] * (4 - len(pesi))
        buf += struct.pack("<HHHHHbbb4B4B", q[0], q[1], q[2],
                           int(round(min(max(u, 0), 1) * 65535)), int(round(min(max(1 - w, 0), 1) * 65535)),
                           int(round(nr[0] * 127)), int(round(nr[1] * 127)), int(round(nr[2] * 127)), *ossa, *pesi)
    for t in triangoli:
        buf += struct.pack("<HHH", *t)
    # Texture: media a blocchi fino al lato richiesto, righe dall'alto (come le immagini di Roblox).
    immagine = bpy.data.images["Gioco_Colore"]
    lato = immagine.size[0]
    pixel = np.array(immagine.pixels[:], dtype=np.float32).reshape(lato, lato, 4)[::-1, :, :3]
    passo = lato // lato_texture
    pixel = pixel.reshape(lato_texture, passo, lato_texture, passo, 3).mean(axis=(1, 3))
    # Un'immagine a 8 bit di Blender dà già i valori sRGB, come li vuole Roblox.
    rgb = np.clip(np.round(pixel * 255), 0, 255).astype(np.uint8).tobytes()
    giunti = STATO["giunti"]
    ossa = []
    for nome, padre in OSSA:
        ossa.append({"nome": nome, "padre": padre, "posizione": roblox(perno(nome, giunti))})
    return {
        "minimo": list(minimo),
        "massimo": list(massimo),
        "ossa": ossa,
        "vertici": len(vertici),
        "triangoli": len(triangoli),
        "geometria": base64.b64encode(bytes(buf)).decode(),
        "texture": {"lato": lato_texture, "rgb": base64.b64encode(rgb).decode()},
    }
