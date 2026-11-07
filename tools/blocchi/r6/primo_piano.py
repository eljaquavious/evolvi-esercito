"""Primi piani di controllo delle truppe R6 (Cycles): scudo, testa, petto, mano destra, figura intera.

blender --background --factory-startup --python tools/blocchi/r6/primo_piano.py -- <uscita.png> <Nome>:<vista> [...]
viste: scudo, testa, petto, mano, intero, retro. Mette i primi piani in una griglia (4 per riga).
"""
import math
import os
import sys
import tempfile

import bpy
import numpy as np
from mathutils import Euler, Vector

QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, QUI)
import kit  # noqa: E402
import r6  # noqa: E402
import truppe  # noqa: E402

a = sys.argv[sys.argv.index("--") + 1:]
USCITA, RICHIESTE = a[0], a[1:]
LAVORO = tempfile.mkdtemp(prefix="primo_piano_r6_")
LATO = 520


def scena():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    r6.azzera()
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 32
    sc.cycles.use_denoising = True
    sc.render.resolution_x = sc.render.resolution_y = LATO
    sc.view_settings.view_transform = "Standard"
    mondo = bpy.data.worlds.new("cielo")
    mondo.use_nodes = True
    mondo.node_tree.nodes["Background"].inputs["Color"].default_value = (*r6.lineare("#B8CCE0"), 1)
    sc.world = mondo
    sole = bpy.data.objects.new("sole", bpy.data.lights.new("sole", "SUN"))
    sole.data.energy = 3.2
    sole.rotation_euler = Euler((math.radians(50), 0, math.radians(-35)))
    sc.collection.objects.link(sole)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    return cam


def in_blender(m, p):
    return Vector(r6.blender(kit.finale(m, p)))


# vista -> (punto da guardare in coordinate Roblox, direzione della camera in Roblox, distanza, focale)
def vista(m, nome):
    davanti_sx = np.array([-0.55, 0.25, -1.0])
    davanti_dx = np.array([0.55, 0.25, -1.0])
    if nome == "scudo":
        return kit.pugno(m, "L")[0], np.array([-0.7, 0.2, -1.0]), 1.5, 60
    if nome == "testa":
        return m.P("testa") + np.array([0, 0.2, 0]), np.array([0.35, 0.15, -1.0]), 1.3, 70
    if nome == "petto":
        return m.P("torace") + np.array([0, 0.05, 0]), np.array([0.25, 0.1, -1.0]), 1.5, 60
    if nome == "mano":
        return kit.pugno(m, "R")[0] + np.array([0, 0.25, 0]), davanti_dx, 2.2, 55
    if nome == "retro":
        return m.P("torace"), np.array([-0.5, 0.25, 1.0]), 3.2, 55
    return m.P("torace") - np.array([0, 0.3, 0]), davanti_sx * np.array([-1, 1, 1]), 4.2, 55


immagini = []
for i, richiesta in enumerate(RICHIESTE):
    nome, v = richiesta.split(":")
    cam = scena()
    faccia = r6.faccia_png("fiero", os.path.join(LAVORO, "faccia.png"))
    m = truppe.TRUPPE[nome](faccia, LAVORO)
    m.armatura()
    guarda, direzione, distanza, focale = vista(m, v)
    g = in_blender(m, guarda)
    d = Vector(r6.blender(direzione / np.linalg.norm(direzione)))
    cam.location = g + d * distanza
    cam.data.lens = focale
    cam.rotation_euler = (g - cam.location).to_track_quat("-Z", "Y").to_euler()
    f = os.path.join(LAVORO, f"{i}.png")
    bpy.context.scene.render.filepath = f
    bpy.ops.render.render(write_still=True)
    immagini.append((richiesta, f))

sys.path.append(os.path.join(os.environ.get("LOCALAPPDATA", ""), "evolvi-pylib"))
from PIL import Image, ImageDraw  # noqa: E402

col = min(4, len(immagini))
righe = (len(immagini) + col - 1) // col
foglio = Image.new("RGB", (LATO * col, (LATO + 20) * righe), (40, 40, 40))
dr = ImageDraw.Draw(foglio)
for i, (testo, f) in enumerate(immagini):
    x, y = (i % col) * LATO, (i // col) * (LATO + 20)
    foglio.paste(Image.open(f).convert("RGB"), (x, y))
    dr.text((x + 8, y + LATO + 4), testo, fill=(255, 255, 255))
foglio.save(USCITA)
print("FOGLIO", USCITA)
