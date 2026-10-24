"""Render di Cesare in posa da Blender, sfondo trasparente. Uso: blender -b -P posa.py -- params.json uscita.png"""
import bpy, sys, json, math
from mathutils import Matrix, Vector, Euler
args = sys.argv[sys.argv.index("--") + 1:]
P = json.load(open(args[0])); OUT = args[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=r"D:\evolvi-esercito\assets-truppe\Cesare\Cesare.fbx")
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
mesh = next(o for o in bpy.data.objects if o.type == "MESH")
# texture a pixel netti (come i blocchi del gioco), materiale opaco
for m in mesh.data.materials:
    for n in m.node_tree.nodes:
        if n.type == "TEX_IMAGE": n.interpolation = "Closest"
        if n.type == "BSDF_PRINCIPLED":
            n.inputs["Roughness"].default_value = P.get("ruvido", 0.6)
            if "Specular IOR Level" in n.inputs: n.inputs["Specular IOR Level"].default_value = 0.35

def R(x=0, y=0, z=0):
    # rotazione Roblox CFrame.Angles(x,y,z) = Rx*Ry*Rz, assi Roblox -> assi locali dell'osso Blender
    return (Matrix.Rotation(-x, 4, "X") @ Matrix.Rotation(y, 4, "Y") @ Matrix.Rotation(-z, 4, "Z"))
def T(x=0, y=0, z=0):
    return Matrix.Translation(Vector((-x, y, -z)))
pose = {}
alza = P.get("alza", 1.25)
pose["cavallo"] = T(0, 0.5 * alza, 0.3) @ R(0.22 * alza)
pose["cavallo.collo"] = R(0.15 * alza)
for l in "RL":
    pose["zampa.A%s1" % l] = R(0.6 * alza); pose["zampa.A%s2" % l] = R(0.3 * alza); pose["zampa.A%s3" % l] = R(-1.4 * alza)
    pose["zampa.P%s1" % l] = R(-0.25 * alza); pose["zampa.P%s2" % l] = R(0.2 * alza)
for nome, v in P.get("ossa", {}).items():
    pose[nome] = R(*v)
for nome, mat in pose.items():
    pb = arm.pose.bones.get(nome)
    if pb:
        pb.rotation_mode = "QUATERNION"
        pb.matrix_basis = mat
bpy.context.view_layer.update()
if P.get("maschera"):
    # solo il cavaliere: le facce del cavallo diventano "holdout" (trasparenti ma coprono quello che sta dietro)
    hold = bpy.data.materials.new("holdout"); hold.use_nodes = True
    nt = hold.node_tree; nt.nodes.clear()
    o_ = nt.nodes.new("ShaderNodeOutputMaterial"); h_ = nt.nodes.new("ShaderNodeHoldout")
    nt.links.new(h_.outputs[0], o_.inputs[0])
    bianco = bpy.data.materials.new("bianco"); bianco.use_nodes = True
    nt = bianco.node_tree; nt.nodes.clear()
    o_ = nt.nodes.new("ShaderNodeOutputMaterial"); e_ = nt.nodes.new("ShaderNodeEmission")
    e_.inputs[0].default_value = (1, 1, 1, 1); nt.links.new(e_.outputs[0], o_.inputs[0])
    mesh.data.materials.clear(); mesh.data.materials.append(bianco); mesh.data.materials.append(hold)
    nomi = {g.index: g.name for g in mesh.vertex_groups}
    def cavallo(v):
        best = max(v.groups, key=lambda g: g.weight, default=None)
        return best is not None and (nomi[best.group].startswith("cavallo") or nomi[best.group].startswith("zampa"))
    vc = [cavallo(v) for v in mesh.data.vertices]
    for poly in mesh.data.polygons:
        n = sum(vc[i] for i in poly.vertices)
        poly.material_index = 1 if n * 2 > len(poly.vertices) else 0

sc = bpy.context.scene
sc.render.engine = "CYCLES" if P.get("cycles") else "BLENDER_EEVEE"
if P.get("cycles"):
    sc.cycles.samples = P.get("campioni", 96); sc.cycles.use_denoising = True
sc.render.resolution_x = sc.render.resolution_y = P.get("ris", 2048)
sc.render.film_transparent = True
sc.render.filter_size = 1.2
try: sc.view_settings.view_transform = "AgX"; sc.view_settings.look = "AgX - Medium High Contrast"
except Exception: pass
sc.view_settings.exposure = P.get("esposizione", 0)
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (1.0, 0.62, 0.42, 1); w.node_tree.nodes["Background"].inputs[1].default_value = P.get("ambiente", 0.6)

def luce(nome, tipo, energia, colore, pos, mira, size=1):
    d = bpy.data.lights.new(nome, tipo); d.energy = energia; d.color = colore
    if tipo == "AREA": d.size = size
    o = bpy.data.objects.new(nome, d); sc.collection.objects.link(o)
    o.location = pos
    dirv = Vector(mira) - Vector(pos); o.rotation_euler = dirv.to_track_quat("-Z", "Y").to_euler()
testa = arm.matrix_world @ arm.pose.bones["testa"].head
for L in P["luci"]:
    luce(L["nome"], L["tipo"], L["energia"], L["colore"], [testa[i] + L["pos"][i] for i in range(3)], testa, L.get("size", 2))
cam_d = bpy.data.cameras.new("cam"); cam_d.lens = P["lente"]
cam = bpy.data.objects.new("cam", cam_d); sc.collection.objects.link(cam); sc.camera = cam
mira = testa + Vector(P["mira"])
cam.location = testa + Vector(P["cam"])
cam.rotation_euler = (mira - cam.location).to_track_quat("-Z", "Y").to_euler()
sc.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("TESTA", tuple(testa))
