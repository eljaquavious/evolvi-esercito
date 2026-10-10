"""Giovanna d'Arco (1412-1431): il comandante "Giovanna" del Medioevo.

Riferimenti: le cronache dell'assedio di Orléans (1429), che parlano del suo "harnois blanc" (armatura completa
di acciaio lucido, senza sopravveste) e dello stendardo che portava lei stessa; le raffigurazioni dell'Ottocento
(Ingres, Lenepveu) e le ricostruzioni dell'armatura francese del primo Quattrocento. Capelli corti a caschetto
"a scodella", come gli uomini d'arme. Armatura: petto e schiena lisci, gonnellino a lame, spallacci tondi,
bracciali con le cubitiere, cosciali, ginocchiere e schinieri, scarpe a lame. Nella destra la spada alzata,
nella sinistra lo stendardo: bianco, seminato di gigli d'oro, con la coda biforcuta.
Il corpo è quello comune con la testa femminile (umano.carica(donna=True)).
"""

import math

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

import cavallo as C
import umano
import vestiti as V

NOME = "Giovanna"
SIGLA = "GI"

PRESA = Vector((-0.26, -0.24, 1.04))                    # pugno destro sull'elsa
LAMA = Vector((-0.05, -0.55, 0.83)).normalized()
ASTA = Vector((0.24, -0.14, 0.98))                       # pugno sinistro sull'asta
VERSO_ASTA = Vector((0.03, -0.08, 1.0)).normalized()

U = None


def materiali(u):
    u.materiale("Acciaio", (0.66, 0.67, 0.70), metallo=1.0, ruvidita=0.34)
    u.materiale("AcciaioScuro", (0.40, 0.41, 0.43), metallo=1.0, ruvidita=0.4)
    u.materiale("Ottone", (0.80, 0.60, 0.26), metallo=1.0, ruvidita=0.35)
    u.materiale("Cuoio", (0.22, 0.11, 0.05), ruvidita=0.6)
    u.materiale("Suola", (0.07, 0.04, 0.02), ruvidita=0.8)
    u.materiale("Capelli", (0.10, 0.055, 0.03), ruvidita=0.7)
    u.materiale("Legno", (0.40, 0.25, 0.12), ruvidita=0.6)
    u.materiale("Stendardo", (1.0, 1.0, 1.0), ruvidita=0.9, immagine=immagine_stendardo())


def posa(sch):
    for s in (1, -1):
        k = umano.sigla(s)
        umano.ruota_mondo(sch, "coscia" + k, (0, 1, 0), 4.0 * s)
        umano.ruota_mondo(sch, "piede" + k, (0, 1, 0), -4.0 * s)
    umano.ruota_mondo(sch, "coscia.L", (1, 0, 0), -10)
    umano.ruota_mondo(sch, "stinco.L", (1, 0, 0), 8)
    umano.ruota_mondo(sch, "testa", (0, 0, 1), -5)
    C.impugna(sch, -1, PRESA, LAMA, (0.3, -0.2, -0.4), (-0.7, 0.4, -0.5))
    C.impugna(sch, 1, ASTA, VERSO_ASTA, (-1, -0.3, 0), (0.7, 0.4, -0.5))


# Armatura ------------------------------------------------------------------------------------------

def armatura(u):
    # Imbottitura sotto (non si vede), poi le piastre.
    V.pantaloni(u, "Gambe", "Acciaio", t_inizio=0.05, t_fine=1.9, margine=0.012, spessore=0.005)
    V.calzature(u, "Scarpe", "Acciaio", "Suola", taglio=0.13, inclinazione=0.2)
    u.nascondi_pelle()
    V.veste(u, "Corazza", 1.45, 0.97, "Acciaio", margine=0.018, svasatura=0.0, pieghe=0.0, n_pieghe=4,
            spessore=0.006)
    V.maniche(u, "Bracciali", "Acciaio", t_inizio=-0.1, t_fine=1.86, margine=0.011, spessore=0.005)
    manopole(u)
    gorgiera(u)
    u.nascondi_pelle()
    # Gonnellino a lame sui fianchi: tre fasce che si allargano verso il basso.
    for i, (alto, basso) in enumerate(((1.0, 0.93), (0.95, 0.88), (0.90, 0.83))):
        V.veste(u, "Lame_%d" % i, alto, basso, "Acciaio", margine=0.03 + 0.009 * i, svasatura=0.04,
                pieghe=0.0, n_pieghe=4, spessore=0.006)
    # Resta (la costola) al centro del petto e il bordo del collo.
    punti = [u.sulla_pelle(Vector((0, 0, z)), Vector((0, -1, 0)), 0.026, 0.35) for z in np.linspace(1.40, 1.02, 9)]
    u.oggetto("Corazza_Costola", V.tubo_lungo(punti, 0.007, n=6), "Acciaio")
    u.oggetto("Corazza_Collo", V.anello_sul_corpo(u, (0, 0.0, 1.53), (0, 0.1, 1), 0.016, 0.012, n=48, portata=0.25),
              "AcciaioScuro", spessore=0.004)
    # Spallacci: gusci tondi dalla scapola al petto sopra la spalla, in tre lame.
    pezzi = []
    for s in (1, -1):
        for j, (largo, fuori) in enumerate(((0.14, 0.03), (0.11, 0.04), (0.08, 0.05))):
            punti, normali = [], []
            for i in range(17):
                t = i / 16
                a = math.pi * t
                d = Vector((s * (0.45 + 0.25 * j) * math.sin(a), -math.cos(a), math.sin(a) * (1.0 - 0.25 * j))).normalized()
                centro = Vector((s * (0.15 + 0.03 * j), 0.0, 1.30 - 0.05 * j))
                punti.append(u.sulla_pelle(centro, d, fuori, 0.4))
                normali.append(d)
            pezzi.append(V.striscia(punti, normali, largo))
    u.oggetto("Spallacci", V.unisci(*pezzi), "Acciaio", spessore=0.007)
    # Cubitiere e ginocchiere: coppe tonde sulle articolazioni.
    coppe = []
    for lato in ("d", "s"):
        g = u.P("gomito_" + lato)
        coppe.append(V.sfera(g + Vector((0, 0.03, 0)), (0.05, 0.05, 0.045), 12, 8))
        k = u.P("ginocchio_" + lato)
        coppe.append(V.sfera(k + Vector((0, -0.04, 0)), (0.055, 0.035, 0.06), 12, 8))
        # L'aletta a ventaglio sul lato esterno della ginocchiera.
        s = -1 if lato == "d" else 1
        coppe.append(V.sfera(k + Vector((s * 0.05, -0.012, 0.0)), (0.012, 0.045, 0.05), 10, 8))
    u.oggetto("Coppe", V.unisci(*coppe), "Acciaio")
    # Bordi delle piastre (i ribattini arrotolati): sulle gambe e sulle braccia, dove una piastra finisce.
    bordi = []
    for lato in ("d", "s"):
        for giunti, ts, distacco in ((("anca", "ginocchio", "caviglia"), (0.12, 0.8, 1.2, 1.86), 0.019),
                                     (("spalla", "gomito", "polso"), (0.15, 0.82, 1.18, 1.8), 0.017)):
            g0, g1, g2 = (u.P(g + "_" + lato) for g in giunti)
            for t in ts:
                a0, a1, f = (g0, g1, t) if t <= 1 else (g1, g2, t - 1)
                bordi.append(V.anello_sul_corpo(u, a0.lerp(a1, f), a1 - a0, distacco, 0.012, n=28, portata=0.15))
    u.oggetto("Bordi", V.unisci(*bordi), "AcciaioScuro", spessore=0.004)
    # Cintura di cuoio con la fibbia, e il fodero vuoto al fianco sinistro.
    u.oggetto("Cintura", V.anello_sul_corpo(u, (0, 0.0, 0.99), (0, 0, 1), 0.06, 0.035, n=64, portata=0.3), "Cuoio",
              spessore=0.004)
    base = Matrix.Translation((0.21, 0.04, 0.96)) @ Matrix.Rotation(math.radians(25), 4, "X")
    u.oggetto("Fodero", V.trasforma(V.scatola((0, 0, -0.4), (0.025, 0.06, 0.8)), base), "Cuoio")


def gorgiera(u):
    """Collo d'acciaio: stretto sul collo in alto, si allarga in basso fino a coprire l'orlo del petto
    (così dall'alto non si vede la pelle nascosta sotto la corazza)."""
    n, righe = 48, 7
    anelli = []
    for i, z in enumerate(np.linspace(1.535, 1.43, righe)):
        c, raggi = u.raggi_busto(float(z), n)
        m = min(r for r in raggi if r is not None)
        raggi = V.liscia_cerchio([min(m * 1.6, r) if r is not None else m for r in raggi], 3)
        margine = 0.009 + 0.026 * (i / (righe - 1)) ** 1.5
        anelli.append([Vector((c.x, c.y, float(z))) + Vector((math.cos(a), math.sin(a), 0)) * (raggi[j] + margine)
                       for j, a in enumerate(2 * math.pi * np.arange(n) / n)])
    bm = V.griglia(anelli, chiusa=True)
    V._verso_fuori(bm)
    u.oggetto("Gorgiera", bm, "Acciaio", spessore=0.005, copre=True)


def manopole(u):
    """Guanti d'arme a muffola: l'involucro della mano vera (dita chiuse sull'elsa e sull'asta) un po' gonfiato,
    con il polsino svasato."""
    pezzi = []
    for lato in ("d", "s"):
        polso, gomito = u.P("polso_" + lato), u.P("gomito_" + lato)
        asse = (polso - gomito).normalized()
        punti = [v.co.copy() for v in u.corpo.data.vertices
                 if (v.co - polso).length < 0.2 and (v.co - polso).dot(asse) > -0.01]
        bm = bmesh.new()
        for p in punti:
            bm.verts.new(p)
        bmesh.ops.convex_hull(bm, input=bm.verts)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        centro = sum((v.co for v in bm.verts), Vector()) / len(bm.verts)
        for v in bm.verts:
            v.co = v.co + (v.co - centro).normalized() * 0.008
        pezzi.append(bm)
        pezzi.append(V.cilindro(polso - asse * 0.06, polso + asse * 0.025, 0.042, 0.05, n=16, tappi=False))
    u.oggetto("Manopole", V.unisci(*pezzi), "Acciaio", spessore=0.003, copre=True)


def caschetto(u):
    """Capelli a scodella: frangia sulla fronte, ai lati scendono fino alla mascella, dietro fino alla nuca."""
    n, righe = 48, 12
    centro_y = -0.02
    apice = u.sulla_pelle(Vector((0, -0.01, 1.6)), Vector((0, 0.08, 1)).normalized(), 0.014, 0.3)
    bordo = []
    for j in range(n):
        a = 2 * math.pi * j / n
        d = Vector((math.cos(a), math.sin(a), 0))
        f = min(1.0, max(0.0, (d.y + 0.8) / 0.55))        # 0 davanti, 1 dai lati in giù
        z = 1.69 - 0.12 * f * f * (3 - 2 * f) - 0.015 * max(0.0, d.y) - 0.004 * (1 - f) * abs(math.sin(j * 1.7))
        bordo.append(u.sulla_pelle(Vector((0, centro_y, z)), d, 0.012, 0.2))
    anelli = []
    for t in np.linspace(0, 1, righe):
        anello = []
        for p in bordo:
            q = p.lerp(apice, min(float(t), 0.96) ** 1.3)
            radiale = Vector((q.x, q.y - centro_y, 0))
            if radiale.length > 1e-6:
                q = q + radiale.normalized() * (0.012 * math.sin(math.pi * min(1.0, float(t) * 1.1)))
            q = u.fuori_dalla_pelle(q, 0.012)
            anello.append(q)
        anelli.append(anello)
    bm = V.griglia(anelli, chiusa=True)
    bm.verts.ensure_lookup_table()
    bm.faces.new([bm.verts[len(bm.verts) - n + j] for j in range(n)])
    V._verso_fuori(bm)
    u.oggetto("Capelli", bm, "Capelli", spessore=0.006)
    # Ciocche: piccole punte sul bordo, perché non sembri un casco.
    ciocche = []
    for j in range(0, n, 2):
        p = bordo[j]
        if p.y < centro_y - 0.04:
            continue
        r = Vector((p.x, p.y - centro_y, 0)).normalized()
        ciocche.append(V.tubo_lungo([p + Vector((0, 0, 0.02)), p + r * 0.004 - Vector((0, 0, 0.012))],
                                    [0.009, 0.002], n=5))
    u.oggetto("Capelli_Ciocche", V.unisci(*ciocche), "Capelli")


# Spada e stendardo ---------------------------------------------------------------------------------

def spada(u):
    lato = LAMA.cross(Vector((1, 0, 0))).normalized()
    m = Matrix((LAMA.cross(lato).normalized(), lato, LAMA)).transposed().to_4x4()
    m.translation = PRESA
    lama = V.lama(0.74, 0.05, 0.02, spessore=0.007)
    V.trasforma(lama, m @ Matrix.Translation((0, 0, 0.07)))
    u.oggetto("Spada_Lama", lama, "Acciaio", liscio=False)
    elsa = [V.scatola((0, 0, 0.065), (0.2, 0.025, 0.018)), V.cilindro((0, 0, -0.08), (0, 0, 0.06), 0.014, n=10),
            V.sfera((0, 0, -0.1), (0.03, 0.03, 0.025), 10, 6)]
    for b in elsa:
        V.trasforma(b, m)
    u.oggetto("Spada_Elsa", V.unisci(*elsa), "Ottone")


def immagine_stendardo(lato=512):
    """Bianco, seminato di gigli d'oro stilizzati, con l'orlo dorato."""
    nome = SIGLA + "_Stendardo"
    vecchia = bpy.data.images.get(nome)
    if vecchia:
        bpy.data.images.remove(vecchia)
    yy, xx = np.mgrid[0:lato, 0:lato]
    u = (xx + 0.5) / lato
    v = (yy + 0.5) / lato
    rgb = np.ones((lato, lato, 3)) * np.array([0.90, 0.88, 0.82])
    rgb *= (0.95 + 0.05 * np.sin(u * 13 + v * 7))[..., None]
    oro = np.array([0.82, 0.60, 0.18])
    # Griglia di gigli sfalsati: petalo centrale, due laterali ricurvi e la fascia.
    passo = 0.16
    gu = (u / passo) % 1.0
    riga = np.floor(v / passo)
    gu = (gu + 0.5 * (riga % 2)) % 1.0
    gv = (v / passo) % 1.0
    x, y = (gu - 0.5) * 2, (gv - 0.5) * 2         # -1..1 nella cella, y in su
    centrale = (x / 0.16) ** 2 + ((y - 0.15) / 0.5) ** 2 < 1
    sinistro = ((x + 0.32) / 0.14) ** 2 + ((y + 0.02) / 0.32) ** 2 < 1
    destro = ((x - 0.32) / 0.14) ** 2 + ((y + 0.02) / 0.32) ** 2 < 1
    fascia = (np.abs(y + 0.18) < 0.07) & (np.abs(x) < 0.35)
    piede = (np.abs(x) < 0.1) & (y < -0.18) & (y > -0.55)
    giglio = centrale | sinistro | destro | fascia | piede
    rgb[giglio] = oro
    rgb[(u < 0.03) | (v < 0.04) | (v > 0.96)] = oro * 0.9
    rgba = np.concatenate([np.clip(rgb, 0, 1), np.ones((lato, lato, 1))], axis=2).astype(np.float32)
    img = bpy.data.images.new(nome, lato, lato, alpha=False)
    img.pixels.foreach_set(rgba.ravel())
    img.pack()
    return img


def stendardo(u):
    """Asta lunga tenuta in piedi con la sinistra; in cima il drappo bianco a coda di rondine che sventola
    all'indietro."""
    piede = ASTA - VERSO_ASTA * 0.75
    cima = ASTA + VERSO_ASTA * 1.85
    u.oggetto("Stendardo_Asta", V.cilindro(piede, cima, 0.017, 0.015, n=10), "Legno")
    u.oggetto("Stendardo_Puntale", V.unisci(V.sfera(cima + VERSO_ASTA * 0.04, (0.03, 0.03, 0.05), 10, 6),
                                             V.cilindro(piede, piede - VERSO_ASTA * 0.05, 0.02, 0.008, n=8)), "Ottone")
    alto, lungo = 0.62, 1.0
    ni, nk = 14, 8
    dietro = Vector((0.0, 1.0, 0.0))
    lato = VERSO_ASTA.cross(dietro).normalized()
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    # Coda di rondine: due metà (sopra e sotto) che nell'ultimo quarto si aprono a V, saldate dove si toccano.
    for meta in (0, 1):
        vv, coord = [], {}
        for i in range(ni + 1):
            fi = i / ni
            tacca = max(0.0, fi - 0.7) * 1.3
            riga = []
            for k in range(nk // 2 + 1):
                fk = k / (nk // 2) * (0.5 - tacca)
                if meta:
                    fk = 1 - fk
                onda = 0.07 * math.sin(math.pi * 2.2 * fi + 0.6) * fi
                cade = 0.10 * fi * fi
                p = cima - VERSO_ASTA * (0.06 + alto * fk + cade) + dietro * lungo * fi + lato * onda
                v = bm.verts.new(p)
                coord[v] = (fi, 1 - fk)
                riga.append(v)
            vv.append(riga)
        for i in range(ni):
            for k in range(nk // 2):
                giro = (vv[i][k], vv[i + 1][k], vv[i + 1][k + 1], vv[i][k + 1])
                f = bm.faces.new(giro if not meta else tuple(reversed(giro)))
                for loop in f.loops:
                    loop[uv].uv = coord[loop.vert]
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    u.oggetto("Stendardo_Drappo", bm, "Stendardo", spessore=0.004)


def costruisci():
    global U
    u = V.Unita(NOME, SIGLA)
    U = u
    materiali(u)
    u.costruisci_corpo(posa, pelle=(0.55, 0.33, 0.24), barba=0.0, capelli=False, donna=True)
    armatura(u)
    caschetto(u)
    spada(u)
    stendardo(u)
    triangoli = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in u.col.objects if o.type == "MESH")
    return {"oggetti": len(u.col.objects), "triangoli": triangoli}


def esporta(triangoli=5600, lato=512):
    import esporta as E
    r = E.prepara(NOME, U.giunti,
                  rigidi={"Spada_*": "mano.R", "Stendardo_*": "mano.L", "Occhio*": "testa", "Capelli*": "testa",
                          "Fodero*": "bacino"},
                  escludi=["Scarpe", "Scarpe.0*", "Corazza_Costola*", "Capelli_Ciocche*"],
                  quote={"Scarpe*": 220, "Occhio*": 60, "Gambe*": 380, "Corazza.*": 420, "Corazza": 420,
                         "Bracciali*": 300, "Lame_*": 120, "Corazza_Collo*": 60, "Gorgiera*": 140, "Spallacci*": 180, "Coppe*": 140, "Bordi*": 220, "Manopole*": 180,
                         "Cintura*": 60, "Fodero*": 12, "Capelli*": 320, "Spada_*": 80, "Stendardo_Asta*": 40,
                         "Stendardo_Puntale*": 40, "Stendardo_Drappo*": 200},
                  togli_dal_corpo=[SIGLA + "_Nascosta"], triangoli=triangoli, corpo=U.corpo.name)
    E.cuoci(lato=lato)
    return r
