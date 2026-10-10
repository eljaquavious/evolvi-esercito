"""Poilu francese (1915-1918): la carta "Fante" del Novecento.

Riferimenti: uniforme blu orizzonte del 1915 (cappotto a doppio petto lungo al ginocchio con i bottoni di
ottone, pantaloni e fasce mollettiere blu, scarponcini di cuoio), elmo Adrian M15 con la cresta, cinturone con
tre giberne di cuoio, bretelle, tascapane e borraccia, fucile Lebel con la lunga baionetta "Rosalie", baffi.
Posa: fucile basso pronto (calcio al fianco destro, canna in avanti), la sinistra sotto l'astina.
"""

import math

import bmesh
from mathutils import Matrix, Vector

import umano
import vestiti as V

NOME = "Fante"
SIGLA = "PO"

CALCIO = Vector((-0.17, 0.16, 0.93))                       # punta del calcio, al fianco destro
CANNA = Vector((0.25, -1.0, 0.3)).normalized()             # verso della canna
LUNGHEZZA = 1.30                                            # fucile senza baionetta
BAIONETTA = 0.50

U = None


def punto_fucile(t):
    return CALCIO + CANNA * t


def materiali(u):
    u.materiale("Blu", (0.21, 0.28, 0.38), ruvidita=0.9)
    u.materiale("BluScuro", (0.14, 0.19, 0.27), ruvidita=0.9)
    u.materiale("Elmo", (0.20, 0.25, 0.30), metallo=0.25, ruvidita=0.6)
    u.materiale("Cuoio", (0.28, 0.15, 0.06), ruvidita=0.6)
    u.materiale("CuoioScuro", (0.16, 0.08, 0.03), ruvidita=0.6)
    u.materiale("Suola", (0.07, 0.04, 0.02), ruvidita=0.8)
    u.materiale("Ottone", (0.80, 0.60, 0.26), metallo=1.0, ruvidita=0.35)
    u.materiale("Noce", (0.36, 0.20, 0.09), ruvidita=0.5)
    u.materiale("Acciaio", (0.25, 0.25, 0.27), metallo=1.0, ruvidita=0.35)
    u.materiale("AcciaioChiaro", (0.62, 0.63, 0.65), metallo=1.0, ruvidita=0.25)
    u.materiale("Tela", (0.36, 0.32, 0.22), ruvidita=0.9)
    u.materiale("Peli", (0.14, 0.08, 0.04), ruvidita=0.8)


# Posa ----------------------------------------------------------------------------------------------

def posa(sch):
    for s in (1, -1):
        k = umano.sigla(s)
        umano.ruota_mondo(sch, "coscia" + k, (0, 1, 0), 3.0 * s)
        umano.ruota_mondo(sch, "piede" + k, (0, 1, 0), -3.0 * s)
    # Destra sul collo del calcio: la mano lo avvolge da sotto, il dorso verso fuori.
    presa = punto_fucile(0.26)
    y = Vector((0.35, -0.35, -1)).normalized()
    dorso = Vector((-1, 0, 0.2))
    dorso = (dorso - y * dorso.dot(y)).normalized()
    umano.posa_braccio(sch, -1, presa - y * 0.07 + dorso * 0.024, y, dorso, (-0.5, 0.6, -0.5))
    umano.chiudi_dita(sch, -1, {"indice": (55, 80, 40), "medio": (65, 90, 45), "anulare": (70, 90, 45),
                                "mignolo": (75, 85, 45), "pollice": (30, 40, 30)})
    # Sinistra sotto l'astina, palmo in su.
    presa = punto_fucile(0.52)
    y = Vector((-1, -0.25, 0.2)).normalized()
    dorso = Vector((0, 0, -1))
    dorso = (dorso - y * dorso.dot(y)).normalized()
    umano.posa_braccio(sch, 1, presa - y * 0.065 + dorso * 0.03, y, dorso, (0.5, 0.3, -0.8))
    umano.chiudi_dita(sch, 1, {"indice": (35, 55, 30), "medio": (40, 60, 30), "anulare": (45, 60, 30),
                               "mignolo": (50, 60, 30), "pollice": (15, 25, 15)})


# Uniforme ------------------------------------------------------------------------------------------

def uniforme(u):
    V.pantaloni(u, "Pantaloni", "Blu", t_inizio=0.0, t_fine=1.45, margine=0.008, spessore=0.004)
    V.pantaloni(u, "Mollettiere", "BluScuro", t_inizio=1.35, t_fine=1.93, margine=0.016, spessore=0.004)
    V.lacci_gamba(u, "Mollettiere_Giri", "BluScuro", [0.1, 0.22, 0.34, 0.46, 0.58], distacco=0.021, larghezza=0.012)
    V.calzature(u, "Scarponi", "Cuoio", "Suola", taglio=0.13, inclinazione=0.2)
    u.nascondi_pelle()
    V.veste(u, "Cappotto", 1.46, 0.55, "Blu", margine=0.03, svasatura=0.07, pieghe=0.006, n_pieghe=10,
            spessore=0.008)
    V.maniche(u, "Cappotto_Maniche", "Blu", t_inizio=-0.15, t_fine=1.9, margine=0.018, spessore=0.006)
    u.nascondi_pelle()
    # Colletto alto.
    collo = V.anello_sul_corpo(u, (0, -0.005, 1.475), (0, 0.12, 1), 0.012, 0.05, n=40, portata=0.2)
    u.oggetto("Cappotto_Colletto", collo, "Blu", spessore=0.006)
    # Bottoni di ottone a doppio petto.
    bottoni = []
    for z in (1.37, 1.28, 1.19, 1.10):
        for x in (-0.065, 0.065):
            p = u.sulla_pelle(Vector((0, 0, z)), Vector((x, -0.17, 0)).normalized(), 0.046, 0.35)
            bottoni.append(V.sfera(p, (0.009, 0.006, 0.009), 8, 5))
    u.oggetto("Bottoni", V.unisci(*bottoni), "Ottone")


def equipaggiamento(u):
    # Cinturone con tre giberne davanti.
    u.oggetto("Cinturone", V.anello_sul_corpo(u, (0, 0.01, 1.02), (0, 0, 1), 0.052, 0.045, n=64, portata=0.3),
              "Cuoio", spessore=0.005)
    giberne = []
    for x in (-0.11, 0.0, 0.11):
        if x == 0.0:
            continue
        d = Vector((x, -0.16, 0)).normalized()
        p = u.sulla_pelle(Vector((0, 0, 1.02)), d, 0.075, 0.35)
        giberne.append(V.scatola(p, (0.10, 0.045, 0.075), Matrix.Rotation(math.atan2(d.x, -d.y), 4, "Z")))
    p = u.sulla_pelle(Vector((0, 0, 1.02)), Vector((0, 1, 0)), 0.07, 0.35)
    giberne.append(V.scatola(p, (0.12, 0.05, 0.08)))
    u.oggetto("Giberne", V.unisci(*giberne), "Cuoio")
    # Bretelle: dalle spalle al cinturone, davanti e dietro.
    pezzi = []
    for s in (1, -1):
        for lato_y in (-1, 1):
            punti, normali = [], []
            for i in range(13):
                t = i / 12
                z = 1.44 - t * 0.42
                x = s * (0.10 + 0.02 * t)
                d = Vector((x, lato_y * 0.12, 0)).normalized()
                punti.append(u.sulla_pelle(Vector((0, 0, z)), d, 0.058, 0.35))
                normali.append(d)
            pezzi.append(V.striscia(punti, normali, 0.03))
    u.oggetto("Bretelle", V.unisci(*pezzi), "Cuoio", spessore=0.003)
    # Tascapane (musette) al fianco sinistro e borraccia al destro, appesi al cinturone, un po' indietro.
    p = u.sulla_pelle(Vector((0, 0, 0.88)), Vector((0.8, 0.45, 0)).normalized(), 0.14, 0.4)
    u.oggetto("Tascapane", V.scatola(p, (0.06, 0.24, 0.20), Matrix.Rotation(math.radians(-30), 4, "Z")), "Tela",
              suddividi=1)
    p = u.sulla_pelle(Vector((0, 0, 0.88)), Vector((-0.7, 0.6, 0)).normalized(), 0.15, 0.4)
    u.oggetto("Borraccia", V.sfera(p, (0.05, 0.08, 0.11), 14, 8, Matrix.Rotation(math.radians(40), 4, "Z")), "BluScuro")


def elmo(u):
    """Elmo Adrian M15: calotta tonda, visiera davanti, paranuca dietro, cresta in cima."""
    _, bordo, anelli = V.calotta(u, "Elmo_Calotta", "Elmo", 1.705, 1.675, (0, -0.02, 1.83),
                                 lambda t: 0.022 * math.sin(math.pi * min(1.0, t * 1.05)), distacco=0.015)
    centro = Vector((0, -0.02, 0))
    giri = []
    for f, giu in ((0.0, 0.0), (0.5, 0.35), (1.0, 1.0)):
        giro = []
        for p in bordo:
            radiale = Vector((p.x - centro.x, p.y - centro.y, 0)).normalized()
            davanti = max(0.0, -radiale.y)
            dietro = max(0.0, radiale.y)
            larga = 0.018 + 0.05 * davanti ** 2 + 0.055 * dietro ** 2
            giro.append(p + radiale * larga * f - Vector((0, 0, (0.012 + 0.02 * davanti + 0.03 * dietro) * giu)))
        giri.append(giro)
    tesa = V.griglia(giri, chiusa=True)
    V._verso_fuori(tesa)
    u.oggetto("Elmo_Tesa", tesa, "Elmo", spessore=0.003)
    # Cresta: una costola dalla fronte alla nuca sopra la calotta.
    n = len(bordo)
    davanti, dietro = 3 * n // 4, n // 4    # angoli -90 e +90 gradi: -Y e +Y
    punti = [anelli[k][davanti] for k in range(3, len(anelli) - 1)] + [anelli[k][dietro] for k in range(len(anelli) - 2, 2, -1)]
    punti = [p + Vector((0, 0, 0.012)) for p in punti]
    u.oggetto("Elmo_Cresta", V.tubo_lungo(punti, 0.012, n=6), "Elmo")
    # Fregio (granata) davanti.
    fronte = anelli[3][davanti] + Vector((0, -0.006, 0))
    u.oggetto("Elmo_Fregio", V.sfera(fronte, (0.014, 0.004, 0.016), 8, 5), "Ottone")


# Fucile Lebel con baionetta --------------------------------------------------------------------------

def fucile(u):
    lato = CANNA.cross(Vector((0, 0, 1))).normalized()
    su = lato.cross(CANNA).normalized()
    m = Matrix((lato, CANNA, su)).transposed().to_4x4()
    m.translation = CALCIO

    def sezione(t, alto, basso, largo):
        # Profilo del legno: da 'basso' a 'alto' sopra l'asse, larghezza 'largo'.
        return [(t, largo * math.cos(a), (alto + basso) / 2 + (alto - basso) / 2 * math.sin(a))
                for a in (math.radians(g) for g in range(0, 360, 30))]

    profilo = [(0.0, 0.03, -0.10, 0.022), (0.05, 0.03, -0.095, 0.022), (0.24, 0.02, -0.035, 0.016),
               (0.30, 0.018, -0.03, 0.016), (0.36, 0.02, -0.04, 0.018), (0.45, 0.018, -0.03, 0.017),
               (1.12, 0.012, -0.02, 0.014), (1.18, 0.008, -0.012, 0.011)]
    bm = bmesh.new()
    anelli = []
    for t, alto, basso, largo in profilo:
        anelli.append([bm.verts.new(m @ Vector((x, t, z))) for t, x, z in sezione(t, alto, basso, largo)])
    for a, b in zip(anelli, anelli[1:]):
        V.unisci_anelli(bm, a, b)
    bm.faces.new(list(reversed(anelli[0])))
    bm.faces.new(anelli[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    u.oggetto("Fucile_Legno", bm, "Noce")
    canna = V.cilindro(m @ Vector((0, 0.30, 0.03)), m @ Vector((0, LUNGHEZZA, 0.015)), 0.011, 0.009, n=10)
    otturatore = V.cilindro(m @ Vector((0, 0.30, 0.035)), m @ Vector((0, 0.42, 0.035)), 0.015, n=10)
    leva = V.cilindro(m @ Vector((0, 0.36, 0.035)), m @ Vector((-0.06, 0.37, 0.0)), 0.004, n=6)
    pomo = V.sfera(m @ Vector((-0.062, 0.37, -0.004)), (0.01, 0.01, 0.01), 8, 5)
    fascette = [V.cilindro(m @ Vector((0, t - 0.012, 0.0)), m @ Vector((0, t + 0.012, 0.0)), 0.026, n=10)
                for t in (0.80, 1.12)]
    u.oggetto("Fucile_Ferro", V.unisci(canna, otturatore, leva, pomo, *fascette), "Acciaio")
    # Baionetta Rosalie: lama a sezione cruciforme, lunga e sottile.
    lama = bmesh.new()
    giri = []
    for t, r in ((0.0, 0.009), (0.03, 0.008), (BAIONETTA * 0.6, 0.006), (BAIONETTA, 0.0005)):
        giri.append([lama.verts.new(m @ Vector((r * math.cos(a) * (1 if k % 2 == 0 else 0.35),
                                                 LUNGHEZZA + 0.02 + t,
                                                 0.015 + r * math.sin(a) * (1 if k % 2 == 0 else 0.35))))
                     for k, a in enumerate(math.radians(g) for g in range(0, 360, 45))])
    for a, b in zip(giri, giri[1:]):
        V.unisci_anelli(lama, a, b)
    lama.faces.new(list(reversed(giri[0])))
    u.oggetto("Fucile_Baionetta", V.unisci(lama, V.cilindro(m @ Vector((0, LUNGHEZZA - 0.03, 0.015)),
                                                             m @ Vector((0, LUNGHEZZA + 0.025, 0.015)), 0.014, n=10)),
              "AcciaioChiaro", liscio=False)
    # Cinghia del fucile sotto.
    u.oggetto("Fucile_Cinghia", V.tubo_lungo([m @ Vector((0, 0.10, -0.08)), m @ Vector((0, 0.45, -0.09)),
                                               m @ Vector((0, 0.80, -0.03))], 0.006, n=6), "CuoioScuro")


# Tutto ---------------------------------------------------------------------------------------------

def costruisci():
    global U
    u = V.Unita(NOME, SIGLA)
    U = u
    materiali(u)
    u.costruisci_corpo(posa, barba=0.75)
    uniforme(u)
    equipaggiamento(u)
    V.baffi(u, "Baffi", "Peli", folti=1.3)
    elmo(u)
    fucile(u)
    triangoli = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in u.col.objects if o.type == "MESH")
    return {"oggetti": len(u.col.objects), "triangoli": triangoli}


def esporta(triangoli=4600, lato=512):
    import esporta as E
    r = E.prepara(NOME, U.giunti,
                  rigidi={"Fucile_*": "mano.R", "Occhio*": "testa", "Elmo_*": "testa", "Baffi*": "testa"},
                  escludi=["Scarponi", "Scarponi.0*", "Mollettiere_Giri*", "Bottoni*", "Elmo_Fregio*"],
                  quote={"Scarponi*": 240, "Occhio*": 60, "Cappotto.*": 480, "Cappotto": 480,
                         "Cappotto_Maniche*": 300, "Pantaloni*": 160, "Mollettiere*": 200, "Fucile_*": 300,
                         "Elmo_Calotta*": 260, "Elmo_Tesa*": 200, "Elmo_Cresta*": 80, "Baffi*": 100},
                  togli_dal_corpo=[SIGLA + "_Nascosta"], triangoli=triangoli, corpo=U.corpo.name)
    E.cuoci(lato=lato)
    return r
