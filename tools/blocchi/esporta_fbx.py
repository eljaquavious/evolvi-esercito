"""Esporta un modello di src/shared/MeshDati in FBX con ossa e pesi, per caricarlo su Roblox come asset vero.

Le truppe costruite a runtime (EditableMesh) consumano il tetto di memoria del client: oltre una ventina di tipi
non ci stanno più. Caricate come asset (MeshPart con Bone) non hanno tetto.

Si lancia con Blender (serve bpy):
  blender --background --python tools/blocchi/esporta_fbx.py -- <Nome> [<Nome> ...] [--metri 2.34] [--uscita cartella]
Scrive <uscita>/<Nome>/<Nome>.fbx e <Nome>.png (la texture, da caricare a parte).
"""
import os
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
# Pillow non c'è nel Python di Blender: la si prende dalla cartella dei pacchetti del PC (in fondo, così il
# numpy di Blender resta quello che usa bpy).
sys.path.append(os.path.join(os.environ.get("LOCALAPPDATA", ""), "evolvi-pylib"))
import meshdati  # noqa: E402

RADICE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


# Studs per metro di ogni tipo, come Modelli.TIPI (metri): i comandanti sono più grandi, il carro compresso.
METRI = {
    "Annibale": 2.8, "Cesare": 2.8, "Guglielmo": 2.8, "Giovanna": 2.8, "Foch": 2.8, "DeGaulle": 2.8,
    "CarroArmato": 1.6,
}


def argomenti():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opzioni = {"metri": None, "uscita": os.path.join(RADICE, "assets-truppe")}
    nomi = []
    i = 0
    while i < len(a):
        if a[i] == "--metri":
            opzioni["metri"] = float(a[i + 1])
            i += 2
        elif a[i] == "--uscita":
            opzioni["uscita"] = a[i + 1]
            i += 2
        else:
            nomi.append(a[i])
            i += 1
    return nomi, opzioni


def blender(p):
    """Da Roblox (X destra, Y su, -Z avanti) a Blender (Z su). Roblox legge le coordinate grezze dell'FBX e ignora
    gli assi dichiarati: con questa rotazione il modello arriva dritto (provato in Studio il 18/10/2026)."""
    p = np.asarray(p, float)
    return np.stack([-p[..., 0], p[..., 2], p[..., 1]], axis=-1)


def pulisci():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def esporta(nome, metri, uscita):
    pulisci()
    m = meshdati.leggi(nome)
    cartella = os.path.join(uscita, nome)
    os.makedirs(cartella, exist_ok=True)
    png = os.path.join(cartella, nome + ".png")
    m["texture"].save(png)
    # Misure per il gioco (Config/AssetTruppe): centro del riquadro rispetto ai piedi e fondo, in studs.
    import json
    centro = (np.asarray(m["minimo"]) + np.asarray(m["massimo"])) / 2 * metri
    json.dump({"metri": metri, "centro": centro.tolist(), "basso": float(m["minimo"][1] * metri - centro[1])},
              open(os.path.join(cartella, nome + ".json"), "w"))

    # Armatura: un osso per articolazione, corto e verticale, con la testa nel punto dell'articolazione.
    arm_dati = bpy.data.armatures.new(nome + "_Ossa")
    arm = bpy.data.objects.new(nome + "_Ossa", arm_dati)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for o in m["ossa"]:
        b = arm_dati.edit_bones.new(o["nome"])
        testa = blender(o["posizione"]) * metri
        b.head = testa
        b.tail = testa + np.array([0, 0, 0.1])
        b.roll = 0
    for o in m["ossa"]:
        if o["padre"]:
            arm_dati.edit_bones[o["nome"]].parent = arm_dati.edit_bones[o["padre"]]
    bpy.ops.object.mode_set(mode="OBJECT")

    # Mesh con uv, normali e pesi.
    pos = blender(m["pos"]) * metri
    tri = m["triangoli"]
    mesh = bpy.data.meshes.new(nome)
    mesh.from_pydata(pos.tolist(), [], tri.tolist())
    mesh.update()
    uv = mesh.uv_layers.new(name="UV")
    uv_v = np.asarray(m["uv"]).copy()
    uv_v[:, 1] = 1 - uv_v[:, 1]
    for poligono in mesh.polygons:
        for indice in poligono.loop_indices:
            v = mesh.loops[indice].vertex_index
            uv.data[indice].uv = uv_v[v]
    for poligono in mesh.polygons:
        poligono.use_smooth = False
    ogg = bpy.data.objects.new(nome, mesh)
    bpy.context.scene.collection.objects.link(ogg)
    gruppi = [ogg.vertex_groups.new(name=o["nome"]) for o in m["ossa"]]
    for v in range(len(pos)):
        for k in range(4):
            peso = float(m["pesi"][v][k])
            if peso > 0:
                gruppi[int(m["ossa_v"][v][k])].add([v], peso, "ADD")
    mod = ogg.modifiers.new("Ossa", "ARMATURE")
    mod.object = arm
    ogg.parent = arm

    # Materiale con la texture.
    mat = bpy.data.materials.new(nome)
    mat.use_nodes = True
    nodi = mat.node_tree.nodes
    bsdf = nodi.get("Principled BSDF")
    img = nodi.new("ShaderNodeTexImage")
    img.image = bpy.data.images.load(png)
    mat.node_tree.links.new(img.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 1.0
    mesh.materials.append(mat)

    fbx = os.path.join(cartella, nome + ".fbx")
    bpy.ops.export_scene.fbx(
        filepath=fbx,
        use_selection=False,
        object_types={"ARMATURE", "MESH"},
        add_leaf_bones=False,
        bake_anim=False,
        use_armature_deform_only=False,
        primary_bone_axis="Y",
        secondary_bone_axis="X",
        mesh_smooth_type="FACE",
        path_mode="COPY",
        embed_textures=True,
        axis_forward="-Z",
        axis_up="Y",
        apply_scale_options="FBX_SCALE_ALL",
    )
    print("esportato", fbx, len(pos), "vertici")


def main():
    nomi, opzioni = argomenti()
    for nome in nomi:
        esporta(nome, opzioni["metri"] or METRI.get(nome, 2.34), opzioni["uscita"])


main()
