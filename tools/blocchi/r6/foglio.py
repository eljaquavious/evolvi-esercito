"""Foglio di controllo: ogni truppa R6 di tre quarti (Cycles, pochi campioni), tutte in una griglia.

blender --background --factory-startup --python tools/blocchi/r6/foglio.py -- <uscita.png> <Nome> [<Nome> ...]
"""
import math
import os
import sys
import tempfile

import bpy
from mathutils import Euler, Vector

QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, QUI)
import r6  # noqa: E402
import truppe  # noqa: E402

a = sys.argv[sys.argv.index("--") + 1:]
USCITA, NOMI = a[0], a[1:]
LAVORO = tempfile.mkdtemp(prefix="foglio_r6_")


def scena():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    r6.azzera()
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 24
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = 420, 520
    sc.view_settings.view_transform = "Standard"
    mondo = bpy.data.worlds.new("cielo")
    mondo.use_nodes = True
    mondo.node_tree.nodes["Background"].inputs["Color"].default_value = (*r6.lineare("#B8CCE0"), 1)
    sc.world = mondo
    sole = bpy.data.objects.new("sole", bpy.data.lights.new("sole", "SUN"))
    sole.data.energy = 3.2
    sole.rotation_euler = Euler((math.radians(50), 0, math.radians(-35)))
    sc.collection.objects.link(sole)
    bpy.ops.mesh.primitive_plane_add(size=40)
    bpy.context.object.data.materials.append(r6.mat("#8E9A7E", "pelle"))
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    return cam


immagini = []
for nome in NOMI:
    cam = scena()
    faccia = r6.faccia_png("fiero", os.path.join(LAVORO, "faccia.png"))
    m = truppe.TRUPPE[nome](faccia, LAVORO)
    m.armatura()
    a_cavallo = "cavallo" in m.ossa or "cannone" in m.ossa
    bpy.context.view_layer.update()
    fondo = min((o.matrix_world @ Vector(c)).z for o in m.pezzi for c in o.bound_box)
    bpy.data.objects["Plane"].location.z = fondo
    if a_cavallo:
        cam.location, guarda, cam.data.lens = Vector((4.2, -5.4, 2.0)), Vector((0, 0.1, 0.55)), 45
    else:
        cam.location, guarda, cam.data.lens = Vector((2.2, -4.8, 1.8)), Vector((0, 0, 0.95)), 62
    cima = max((o.matrix_world @ Vector(c)).z for o in m.pezzi for c in o.bound_box)
    if cima - fondo > 2.6:  # modelli alti (elefante): camera più lontana e più in alto
        k = (cima - fondo) / 2.6
        guarda = Vector((guarda.x, guarda.y, fondo + (cima - fondo) * 0.45))
        cam.location = guarda + (cam.location - guarda) * k
    cam.rotation_euler = (guarda - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.render.filepath = os.path.join(LAVORO, nome + ".png")
    bpy.ops.render.render(write_still=True)
    # Da dietro a sinistra (faretre, mantelli, scudi sulla schiena).
    cam.location = Vector((-cam.location.x, -cam.location.y, cam.location.z))
    cam.rotation_euler = (guarda - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.render.filepath = os.path.join(LAVORO, nome + "_retro.png")
    bpy.ops.render.render(write_still=True)
    tri = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in m.pezzi if o.type == "MESH")
    print("TRIANGOLI", nome, tri)
    immagini.append((nome, os.path.join(LAVORO, nome + ".png"), tri))

sys.path.append(os.path.join(os.environ.get("LOCALAPPDATA", ""), "evolvi-pylib"))
from PIL import Image, ImageDraw  # noqa: E402

col = min(5, len(immagini))
righe = (len(immagini) + col - 1) // col
foglio = Image.new("RGB", (420 * col, 1060 * righe), (40, 40, 40))
d = ImageDraw.Draw(foglio)
for i, (nome, f, tri) in enumerate(immagini):
    x, y = (i % col) * 420, (i // col) * 1060
    foglio.paste(Image.open(f).convert("RGB"), (x, y))
    foglio.paste(Image.open(f.replace(".png", "_retro.png")).convert("RGB"), (x, y + 520))
    d.text((x + 8, y + 1042), f"{nome}  {tri} tri", fill=(255, 255, 255))
foglio.save(USCITA)
print("FOGLIO", USCITA)
