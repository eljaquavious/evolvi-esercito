"""Anteprime di una truppa R6 accanto a quella di prima (Cycles), per far scegliere a Mattia.

blender --background --factory-startup --python tools/blocchi/r6/anteprima.py -- <Nome> <cartella uscita>
Scrive in uscita: vecchio.png, <faccia>_fronte.png, _retro.png, _lato.png, _testa.png, _marcia.png e foglio.png.
"""
import math
import os
import sys

import bpy
from mathutils import Euler, Vector

QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, QUI)
import r6  # noqa: E402
import truppe  # noqa: E402

RADICE = os.path.dirname(os.path.dirname(os.path.dirname(QUI)))
FACCE = ["roblox", "fiero"]


def scena():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 64
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = 900, 1200
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "Standard"
    mondo = bpy.data.worlds.new("cielo")
    mondo.use_nodes = True
    sfondo = mondo.node_tree.nodes["Background"]
    sfondo.inputs["Color"].default_value = (*r6.lineare("#B8CCE0"), 1)
    sfondo.inputs["Strength"].default_value = 0.9
    sc.world = mondo
    sole = bpy.data.objects.new("sole", bpy.data.lights.new("sole", "SUN"))
    sole.data.energy = 3.2
    sole.data.angle = math.radians(8)
    sole.rotation_euler = Euler((math.radians(50), 0, math.radians(-35)))
    sc.collection.objects.link(sole)
    bpy.ops.mesh.primitive_plane_add(size=40)
    terra = bpy.context.object
    terra.data.materials.append(r6.mat("#8E9A7E", "pelle"))
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    return cam


def inquadra(cam, dove, guarda, focale=70):
    cam.location = Vector(dove)
    cam.data.lens = focale
    d = Vector(guarda) - cam.location
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def render(percorso):
    bpy.context.scene.render.filepath = percorso
    bpy.ops.render.render(write_still=True)


def vecchio(x):
    """Il modello di prima (FBX di assets-truppe) messo in x, con l'altezza vera in metri."""
    fbx = os.path.join(RADICE, "assets-truppe", NOME, NOME + ".fbx")
    prima = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=fbx)
    nuovi = [o for o in bpy.data.objects if o not in prima]
    radici = [o for o in nuovi if o.parent is None]
    bpy.context.view_layer.update()
    zs = [(o.matrix_world @ Vector(c)).z for o in nuovi if o.type == "MESH" for c in o.bound_box]
    alto = max(zs) - min(zs)
    k = (alto / 2.34) / alto if alto > 3 else 1.0
    for o in radici:
        o.scale *= k
        o.location = Vector((x, 0, -min(zs) * k))
    for o in nuovi:
        if o.type == "MESH":
            for m in o.data.materials:
                if m and m.use_nodes:
                    m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.8
    return nuovi


def nascondi(oggetti, si):
    for o in oggetti:
        o.hide_render = si


def posa_marcia(arm):
    pb = arm.pose.bones
    # Ossa verticali: rotazione X locale = avanti/indietro (in Blender il davanti è -Y).
    pb["coscia.L"].rotation_euler = Euler((math.radians(-28), 0, 0))
    pb["stinco.L"].rotation_euler = Euler((math.radians(20), 0, 0))
    pb["coscia.R"].rotation_euler = Euler((math.radians(24), 0, 0))
    pb["braccio.R"].rotation_euler = Euler((math.radians(-25), 0, 0))
    pb["braccio.L"].rotation_euler = Euler((math.radians(12), 0, 0))
    for b in pb:
        b.rotation_mode = "XYZ"


NOME = sys.argv[sys.argv.index("--") + 1]
USCITA = sys.argv[sys.argv.index("--") + 2]
os.makedirs(USCITA, exist_ok=True)

cam = scena()
modelli = {}
for f in FACCE:
    png = r6.faccia_png(f, os.path.join(USCITA, f"faccia_{f}.png"))
    m = truppe.TRUPPE[NOME](png, USCITA)
    m.armatura()
    modelli[f] = m
tutti = {f: list(m.coll.all_objects) for f, m in modelli.items()}
nascondi(tutti["fiero"], True)
centro = (0, 0, 0.95)
fronte = (1.9, -4.6, 1.75)

# Il vecchio, da solo, stessa inquadratura.
nascondi(tutti["roblox"], True)
vecchi = vecchio(0)
print("TRI_VECCHIO", sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in vecchi if o.type == "MESH"))
inquadra(cam, fronte, centro)
render(os.path.join(USCITA, "vecchio.png"))
nascondi(vecchi, True)

for f in FACCE:
    nascondi(tutti["roblox"], f != "roblox")
    nascondi(tutti["fiero"], f != "fiero")
    inquadra(cam, fronte, centro)
    render(os.path.join(USCITA, f"{f}_fronte.png"))
    inquadra(cam, (0.55, -1.9, 1.75), (0, 0, 1.6), focale=85)
    render(os.path.join(USCITA, f"{f}_testa.png"))
    if f == "roblox":
        # Da vicino: cintura, gonna, braccio e scudo, per vedere i materiali.
        inquadra(cam, (0.9, -1.55, 1.25), (0.0, 0, 0.95), focale=60)
        render(os.path.join(USCITA, "materiali.png"))
        inquadra(cam, (-2.6, 4.3, 1.8), centro)
        render(os.path.join(USCITA, "retro.png"))
        inquadra(cam, (-5.0, -0.4, 1.4), centro)
        render(os.path.join(USCITA, "lato.png"))
    else:
        for b in modelli[f].arm.pose.bones:
            b.rotation_mode = "XYZ"
        posa_marcia(modelli[f].arm)
        inquadra(cam, (3.4, -3.9, 1.6), centro)
        render(os.path.join(USCITA, "marcia.png"))
conta = sum(len(o.data.polygons) for o in tutti["roblox"] if o.type == "MESH")
tri = 0
for o in tutti["roblox"]:
    if o.type == "MESH":
        tri += sum(len(p.vertices) - 2 for p in o.data.polygons)
print("TRIANGOLI", tri, "PEZZI", len([o for o in tutti["roblox"] if o.type == "MESH"]))
