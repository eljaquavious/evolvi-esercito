"""Huscarl sassone (Hastings, 1066): la carta "Spadaccino" del Medioevo, sullo stesso corpo del legionario.

Riferimenti: arazzo di Bayeux e ricostruzioni (elmo conico con nasale, cotta di maglia fino al ginocchio
con maniche corte, tunica di lana colorata sotto, brache con fasce (winingas) sugli stinchi, scarpe di
cuoio, grande scudo tondo di tiglio dipinto portato sulla schiena quando si usa l'ascia danese a due mani,
baffi). Posa: la destra regge l'ascia in verticale col manico a terra, come il legionario con la lancia.
"""

import math

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

import umano
import vestiti as V

NOME = "Spadaccino"
SIGLA = "HU"

IMPUGNATURA = 1.12
ASSE_ASCIA = Vector((-0.25, -0.255, 0))
TESTA_ASCIA = 1.47   # quota del centro dell'occhio dell'ascia

U = None


def materiali(u):
    u.materiale("Tunica", (0.08, 0.17, 0.30), ruvidita=0.9)
    u.materiale("Brache", (0.30, 0.25, 0.18), ruvidita=0.9)
    u.materiale("Fasce", (0.42, 0.36, 0.26), ruvidita=0.9)
    u.materiale("Maglia", (0.42, 0.43, 0.45), metallo=1.0, ruvidita=0.55)
    _grana_maglia(u.mat["Maglia"])
    u.materiale("Ferro", (0.50, 0.50, 0.52), metallo=1.0, ruvidita=0.35)
    u.materiale("FerroScuro", (0.28, 0.28, 0.30), metallo=1.0, ruvidita=0.45)
    u.materiale("Cuoio", (0.20, 0.10, 0.045), ruvidita=0.65)
    u.materiale("Suola", (0.07, 0.04, 0.02), ruvidita=0.8)
    u.materiale("Legno", (0.45, 0.30, 0.16), ruvidita=0.6)
    u.materiale("Ottone", (0.80, 0.58, 0.24), metallo=1.0, ruvidita=0.35)
    u.materiale("Peli", (0.16, 0.09, 0.04), ruvidita=0.8)
    u.materiale("Scudo", (0.6, 0.1, 0.08), ruvidita=0.6, immagine=immagine_scudo())
    u.materiale("ScudoRetro", (0.36, 0.24, 0.12), ruvidita=0.8)


def _grana_maglia(m):
    """Maglia: anellini scuri e chiari (rumore fine): nella texture del gioco resta una grana grigia."""
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    coord = nt.nodes.new("ShaderNodeTexCoord")
    onde = nt.nodes.new("ShaderNodeTexVoronoi")
    onde.inputs["Scale"].default_value = 260.0
    rampa = nt.nodes.new("ShaderNodeValToRGB")
    rampa.color_ramp.elements[0].color = (0.16, 0.16, 0.18, 1)
    rampa.color_ramp.elements[1].color = (0.42, 0.43, 0.45, 1)
    nt.links.new(coord.outputs["Object"], onde.inputs["Vector"])
    nt.links.new(onde.outputs["Distance"], rampa.inputs["Fac"])
    nt.links.new(rampa.outputs["Color"], bsdf.inputs["Base Color"])


# Posa ----------------------------------------------------------------------------------------------

def posa(sch):
    for s in (1, -1):
        k = umano.sigla(s)
        umano.ruota_mondo(sch, "coscia" + k, (0, 1, 0), 3.0 * s)
        umano.ruota_mondo(sch, "piede" + k, (0, 1, 0), -3.0 * s)
    # Destra sul manico dell'ascia (come la lancia del legionario).
    asse = Vector((ASSE_ASCIA.x, ASSE_ASCIA.y, IMPUGNATURA))
    avanti = Vector((0.15, -1, 0)).normalized()
    su = Vector((0, 0, 1))
    phi = math.radians(15)
    radiale = su * math.cos(phi) - avanti * math.sin(phi)
    y = avanti * math.cos(phi) + su * math.sin(phi)
    dorso = y.cross(radiale).normalized()
    umano.posa_braccio(sch, -1, asse - y * 0.09 + dorso * 0.028, y, dorso, (-0.5, 0.7, -0.3))
    umano.chiudi_dita(sch, -1, {"indice": (70, 95, 50), "medio": (75, 95, 50), "anulare": (80, 95, 50),
                                "mignolo": (85, 90, 50), "pollice": (35, 45, 35)})
    # Sinistra: pugno chiuso lungo il fianco, un poco staccato.
    umano.ruota_mondo(sch, "braccio.L", (0, 1, 0), -5)
    umano.piega(sch, "avambraccio.L", -10)
    umano.chiudi_dita(sch, 1, {"indice": (60, 80, 40), "medio": (65, 85, 40), "anulare": (70, 85, 40),
                               "mignolo": (75, 80, 40), "pollice": (20, 30, 20)})


# Vestiti -------------------------------------------------------------------------------------------

def vestiti(u):
    V.veste(u, "Tunica", 1.44, 0.50, "Tunica", margine=0.010, svasatura=0.05, pieghe=0.005)
    V.maniche(u, "Tunica_Maniche", "Tunica", t_inizio=-0.15, t_fine=1.9, margine=0.008)
    V.pantaloni(u, "Brache", "Brache", t_inizio=0.55, t_fine=1.2, margine=0.008)
    V.pantaloni(u, "Fasce", "Fasce", t_inizio=1.12, t_fine=1.9, margine=0.013, spessore=0.003)
    V.lacci_gamba(u, "Fasce_Giri", "Cuoio", [0.12, 0.4, 0.68], distacco=0.016, larghezza=0.01)
    V.calzature(u, "Scarpe", "Cuoio", "Suola", taglio=0.105, inclinazione=0.25)
    u.nascondi_pelle()
    # La cotta di maglia sopra la tunica (misurata sul corpo, con più margine).
    V.veste(u, "Cotta", 1.45, 0.56, "Maglia", margine=0.026, svasatura=0.055, pieghe=0.004, n_pieghe=10,
            spessore=0.006)
    V.maniche(u, "Cotta_Maniche", "Maglia", t_inizio=-0.15, t_fine=0.85, margine=0.019, spessore=0.005)
    u.oggetto("Cintura", V.anello_sul_corpo(u, (0, 0.01, 1.0), (0, 0, 1), 0.044, 0.045, n=64, portata=0.3), "Cuoio",
              spessore=0.004)
    fibbia = V.scatola(u.sulla_pelle(Vector((0, 0, 1.0)), Vector((0, -1, 0)), 0.05, 0.3), (0.045, 0.012, 0.05))
    u.oggetto("Cintura_Fibbia", fibbia, "Ottone")


def baffi(u):
    pezzi = []
    for s in (1, -1):
        punti = [Vector((s * 0.004, -0.123, 1.579)), Vector((s * 0.02, -0.119, 1.574)),
                 Vector((s * 0.034, -0.110, 1.563)), Vector((s * 0.042, -0.100, 1.548))]
        punti = [u.fuori_dalla_pelle(p, 0.004) for p in punti]
        pezzi.append(V.tubo_lungo(punti, [0.0045, 0.0055, 0.004, 0.0015], n=8))
    u.oggetto("Baffi", V.unisci(*pezzi), "Peli")


def elmo(u):
    """Elmo conico (a spicchi) con nasale: bordo appoggiato sulla testa vera, punta in alto."""
    n = 40
    centro = Vector((0, -0.02, 0))
    apice = Vector((0, -0.005, 1.845))
    # (l'ultimo anello resta un cerchietto: la punta è un tappo, non un ventaglio di triangoli schiacciati)
    bordo = []
    for j in range(n):
        a = 2 * math.pi * j / n
        d = Vector((math.cos(a), math.sin(a), 0))
        z = 1.668 - 0.022 * max(0.0, d.y)   # dietro un poco più basso
        bordo.append(u.sulla_pelle(Vector((centro.x, centro.y, z)), d, 0.013, 0.2))
    anelli = []
    for t in np.linspace(0, 1, 12):
        anello = []
        for j, p in enumerate(bordo):
            q = p.lerp(apice, min(t, 0.96) ** 1.1)
            radiale = Vector((q.x, q.y - centro.y, 0))
            if radiale.length > 1e-6:
                q = q + radiale.normalized() * 0.022 * math.sin(math.pi * t) * (1 - t * 0.3)
            if t < 0.999:
                q = u.fuori_dalla_pelle(q, 0.012)
            anello.append(q)
        anelli.append(anello)
    bm = V.griglia(anelli, chiusa=True)
    bm.verts.ensure_lookup_table()
    bm.faces.new([bm.verts[len(bm.verts) - n + j] for j in range(n)])
    V._verso_fuori(bm)
    u.oggetto("Elmo_Calotta", bm, "Ferro", spessore=0.003)
    # Fascia del bordo, nervature e nasale.
    u.oggetto("Elmo_Fascia", V.tubo_lungo(bordo + [bordo[0]], 0.006, n=8, tappi=False), "FerroScuro")
    nervature = []
    for j in range(0, n, n // 4):
        pts = [anelli[k][j] + (anelli[k][j] - Vector((0, centro.y, anelli[k][j].z))).normalized() * 0.002
               for k in range(0, 11)]
        nervature.append(V.tubo_lungo(pts, 0.0045, n=6))
    u.oggetto("Elmo_Nervature", V.unisci(*nervature), "FerroScuro")
    punti, normali = [], []
    for z in np.linspace(1.672, 1.596, 8):
        punti.append(u.sulla_pelle(Vector((0, -0.03, float(z))), Vector((0, -1, 0)), 0.009, 0.2))
        normali.append(Vector((0, -1, 0.15)))
    u.oggetto("Elmo_Nasale", V.striscia(punti, normali, 0.024), "Ferro", spessore=0.004)


# Ascia danese -----------------------------------------------------------------------------------------

def ascia(u):
    x, y = ASSE_ASCIA.x, ASSE_ASCIA.y
    u.oggetto("Ascia_Manico", V.cilindro((x, y, 0.04), (x, y, TESTA_ASCIA + 0.08), 0.016, 0.014, n=12), "Legno")
    # Occhio (anello attorno al manico) e lama a barba, sottile verso il filo.
    occhio = V.cilindro((x, y, TESTA_ASCIA - 0.045), (x, y, TESTA_ASCIA + 0.05), 0.024, n=12)
    contorno = [(0.0, 0.035), (0.05, 0.03), (0.12, 0.07), (0.205, 0.135)]
    for k in range(1, 12):
        a = math.radians(70 - 140 * k / 12)
        contorno.append((0.12 + 0.105 * math.cos(a) * 0.95, 0.0 + 0.145 * math.sin(a)))
    contorno += [(0.19, -0.155), (0.11, -0.08), (0.05, -0.035), (0.0, -0.04)]
    bm = bmesh.new()
    sopra, sotto = [], []
    for uu, vv in contorno:
        th = 0.013 * max(0.0, 1 - uu / 0.21) + 0.0015
        sopra.append(bm.verts.new((x + th, y - uu, TESTA_ASCIA + vv)))
        sotto.append(bm.verts.new((x - th, y - uu, TESTA_ASCIA + vv)))
    bm.faces.new(sopra)
    bm.faces.new(list(reversed(sotto)))
    for i in range(len(contorno)):
        j = (i + 1) % len(contorno)
        bm.faces.new((sopra[i], sotto[i], sotto[j], sopra[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    u.oggetto("Ascia_Lama", V.unisci(bm, occhio), "Ferro", liscio=False)
    # Fascia di cuoio sotto la testa e puntale.
    u.oggetto("Ascia_Fascia", V.cilindro((x, y, TESTA_ASCIA - 0.16), (x, y, TESTA_ASCIA - 0.07), 0.019, n=12), "Cuoio")


# Scudo sulla schiena ----------------------------------------------------------------------------------

def immagine_scudo(lato=512):
    """Tiglio dipinto a spicchi rossi e crema con bordo scuro, come molti scudi sassoni ricostruiti."""
    nome = SIGLA + "_Scudo"
    vecchia = bpy.data.images.get(nome)
    if vecchia:
        bpy.data.images.remove(vecchia)
    img = bpy.data.images.new(nome, lato, lato, alpha=False)
    yy, xx = np.mgrid[0:lato, 0:lato]
    u = (xx + 0.5) / lato * 2 - 1
    v = (yy + 0.5) / lato * 2 - 1
    r = np.hypot(u, v)
    a = np.arctan2(v, u)
    rosso = np.array([0.55, 0.07, 0.05])
    crema = np.array([0.80, 0.70, 0.50])
    spicchio = (np.floor((a + math.pi) / (2 * math.pi) * 8).astype(int) % 2) == 0
    rgb = np.where(spicchio[..., None], rosso, crema)
    # Venature del legno e un po' di usura.
    rng = np.random.default_rng(4)
    venature = 0.92 + 0.08 * np.sin(v * 90 + np.sin(u * 7) * 2)
    rgb = rgb * venature[..., None] * (0.95 + 0.05 * rng.random((lato, lato)))[..., None]
    # Linee scure tra gli spicchi.
    bordo_spicchi = np.abs(np.sin((a + math.pi) * 4)) < 0.035
    rgb[bordo_spicchi & (r > 0.2)] = [0.08, 0.05, 0.03]
    rgb[r > 0.94] = [0.18, 0.10, 0.05]
    rgba = np.concatenate([np.clip(rgb, 0, 1), np.ones((lato, lato, 1))], axis=2).astype(np.float32)
    img.pixels.foreach_set(rgba.ravel())
    img.pack()
    return img


def scudo(u):
    raggio = 0.42
    # Quanto sporge la schiena (con la cotta) dove poggia lo scudo.
    dietro = 0.0
    for x in np.linspace(-0.2, 0.2, 5):
        for z in np.linspace(1.0, 1.45, 6):
            hit = u.albero.ray_cast(Vector((float(x), 0.0, float(z))), Vector((0, 1, 0)), 0.4)
            if hit[0] is not None:
                dietro = max(dietro, hit[0].y)
    centro = Vector((0.02, dietro + 0.075, 1.2))
    m = Matrix.Translation(centro) @ Matrix.Rotation(math.radians(-4), 4, "X") @ \
        Matrix.Rotation(math.radians(180), 4, "Z") @ Matrix.Rotation(math.radians(12), 4, "Y")
    fronte, retro, bordo = V.scudo_tondo(raggio, 0.05, spessore=0.014)
    for b in (fronte, retro, bordo):
        V.trasforma(b, m)
    u.oggetto("Scudo_Fronte", fronte, "Scudo")
    u.oggetto("Scudo_Retro", retro, "ScudoRetro")
    u.oggetto("Scudo_Bordo", bordo, "Cuoio")
    umbone = V.sfera((0, -0.05, 0), (0.075, 0.06, 0.075), 16, 8)
    V.trasforma(umbone, m)
    u.oggetto("Scudo_Umbone", umbone, "Ferro")
    # Cinghia a tracolla: spalla sinistra -> fianco destro, davanti sopra la cotta.
    punti, normali = [], []
    da, a = Vector((0.13, -0.07, 1.44)), Vector((-0.17, -0.07, 0.98))
    for i in range(25):
        p = da.lerp(a, i / 24)
        d = Vector((p.x, p.y, 0)).normalized()
        punti.append(u.sulla_pelle(Vector((0, 0, p.z)), d, 0.04, 0.35))
        normali.append(d)
    u.oggetto("Scudo_Cinghia", V.striscia(punti, normali, 0.04), "Cuoio", spessore=0.004)


# Tutto ---------------------------------------------------------------------------------------------

def costruisci():
    global U
    u = V.Unita(NOME, SIGLA)
    U = u
    materiali(u)
    u.costruisci_corpo(posa, barba=0.7)
    vestiti(u)
    baffi(u)
    elmo(u)
    ascia(u)
    scudo(u)
    triangoli = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in u.col.objects if o.type == "MESH")
    return {"oggetti": len(u.col.objects), "triangoli": triangoli}


def esporta(triangoli=4600, lato=512):
    import esporta as E
    r = E.prepara(NOME, U.giunti,
                  rigidi={"Ascia_*": "mano.R", "Scudo_Fronte*": "torace", "Scudo_Retro*": "torace",
                          "Scudo_Bordo*": "torace", "Scudo_Umbone*": "torace", "Occhio*": "testa", "Elmo_*": "testa",
                          "Baffi*": "testa"},
                  escludi=["Scarpe", "Scarpe.0*", "Fasce_Giri*", "Cintura_Fibbia*", "Elmo_Nervature*"],
                  quote={"Scarpe*": 260, "Occhio*": 60, "Cotta.*": 460, "Cotta": 460, "Cotta_Maniche*": 260,
                         "Tunica*": 160, "Brache*": 120, "Ascia_*": 400, "Elmo_Calotta*": 280, "Elmo_Fascia*": 120, "Elmo_Nasale*": 60,
                         "Baffi*": 100},
                  togli_dal_corpo=[SIGLA + "_Nascosta"], triangoli=triangoli, corpo=U.corpo.name)
    E.cuoci(lato=lato)
    return r
