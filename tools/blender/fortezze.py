"""Fortezze del match point: aiuti comuni a fortezza_antica.py, fortezza_medievale.py e fortezza_novecento.py.

Le superfici grandi (pietra, tronchi, assi, cemento, ardesia, terra, sacchetti) hanno texture dipinte qui con
numpy, ripetibili, proiettate "a scatola" in coordinate dell'oggetto: un metro di muro è un metro di texture
qualunque sia il pezzo, e nella cottura per il gioco i blocchi e le assi finiscono nell'immagine.
Il davanti della fortezza è verso -Y (come i soldati); l'origine è a terra al centro.
"""

import math

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

import vestiti as V


# Rumore e immagini ---------------------------------------------------------------------------------

def rumore(lato, cx, cy=None, seme=0):
    """Rumore di valore liscio che si ripete (i bordi si raccordano), 0..1; cx, cy = celle in x e in y."""
    cy = cy or cx
    rng = np.random.default_rng(seme)
    g = rng.random((cy, cx))
    t = (np.arange(lato) + 0.5) / lato
    tx, ty = t * cx, t * cy
    x0 = np.floor(tx).astype(int) % cx
    y0 = np.floor(ty).astype(int) % cy
    x1, y1 = (x0 + 1) % cx, (y0 + 1) % cy
    fx, fy = tx - np.floor(tx), ty - np.floor(ty)
    fx, fy = (fx * fx * (3 - 2 * fx))[None, :], (fy * fy * (3 - 2 * fy))[:, None]
    a, b = g[y0][:, x0], g[y0][:, x1]
    c, d = g[y1][:, x0], g[y1][:, x1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def frattale(lato, seme=0, ottave=((4, 0.45), (8, 0.25), (16, 0.17), (32, 0.08), (64, 0.05))):
    tot = sum(p for _, p in ottave)
    return sum(rumore(lato, c, c, seme + 13 * i) * p for i, (c, p) in enumerate(ottave)) / tot


def immagine(nome, rgb):
    vecchia = bpy.data.images.get(nome)
    if vecchia:
        bpy.data.images.remove(vecchia)
    h, w = rgb.shape[:2]
    img = bpy.data.images.new(nome, w, h, alpha=False)
    rgba = np.concatenate([np.clip(rgb, 0, 1), np.ones((h, w, 1))], axis=2).astype(np.float32)
    img.pixels.foreach_set(rgba.ravel())
    img.pack()
    return img


def _tagli(rng, lungo_min, lungo_max):
    """Tagli tra 0 e 1 (ripetibili) di una fila di blocchi."""
    inizio = rng.random() * lungo_max
    tagli, p = [], inizio
    while p < inizio + 1 - lungo_min * 0.6:
        tagli.append(p % 1.0)
        p += rng.uniform(lungo_min, lungo_max)
    return np.sort(np.array(tagli))


def _blocchi_fila(u, tagli):
    """Per ogni u (0..1): indice del blocco e distanza (in frazione) dal taglio più vicino."""
    k = np.searchsorted(tagli, u, side="right")
    prima = tagli[(k - 1) % len(tagli)]
    dopo = tagli[k % len(tagli)]
    d1 = (u - prima) % 1.0
    d2 = (dopo - u) % 1.0
    return k % len(tagli), np.minimum(d1, d2)


def tex_pietra(nome, base=(0.58, 0.54, 0.47), malta=(0.40, 0.38, 0.34), righe=8, lato=512, seme=1,
               lungo=(0.14, 0.32), varia=0.09):
    """Muratura a blocchi squadrati in file sfalsate, con i giunti di malta e gli spigoli un po' scuri."""
    rng = np.random.default_rng(seme)
    x = (np.arange(lato) + 0.5) / lato
    rgb = np.zeros((lato, lato, 3))
    h = lato // righe
    base, malta = np.array(base), np.array(malta)
    grana = frattale(lato, seme)
    for r in range(righe):
        tagli = _tagli(rng, *lungo)
        k, d = _blocchi_fila(x, tagli)
        tinte = base * (1 + varia * rng.normal(size=(len(tagli), 1))) * (1 + 0.04 * rng.normal(size=(len(tagli), 3)))
        fila = tinte[k]                                     # (lato, 3)
        dy = np.minimum(np.arange(h) + 0.5, h - np.arange(h) - 0.5)[:, None]   # px dal giunto orizzontale
        dx = (d * lato)[None, :]
        dist = np.minimum(dx, dy)
        blocco = fila[None, :, :] * (0.82 + 0.18 * np.clip(dist / 4.0, 0, 1))[..., None]
        giunto = (dist < 1.6)[..., None]
        rgb[r * h:(r + 1) * h] = np.where(giunto, malta, blocco)
    rgb *= (0.8 + 0.4 * grana)[..., None]
    return immagine(nome, rgb)


def tex_tronchi(nome, n=8, base=(0.36, 0.25, 0.15), lato=512, seme=2):
    """Tronchi verticali affiancati (palizzata): tondi in ombra ai bordi, corteccia a strisce."""
    rng = np.random.default_rng(seme)
    u = (np.arange(lato) + 0.5) / lato * n
    k = np.floor(u).astype(int) % n
    f = u - np.floor(u)
    tinte = np.array(base) * (1 + 0.12 * rng.normal(size=(n, 1)))
    tondo = 0.45 + 0.55 * np.sin(np.pi * np.clip(f, 0, 1)) ** 0.6
    corteccia = rumore(lato, n * 6, 6, seme) * 0.6 + rumore(lato, n * 14, 3, seme + 1) * 0.4
    rgb = tinte[k][None, :, :] * (tondo[None, :] * (0.7 + 0.5 * corteccia))[..., None]
    fessura = (f < 0.035) | (f > 0.965)
    rgb[:, fessura] *= 0.25
    return immagine(nome, rgb)


def tex_assi(nome, n=10, base=(0.42, 0.30, 0.18), lato=512, seme=3, giunti=3):
    """Assi verticali con le venature, le fughe scure, qualche giunta di testa e i chiodi."""
    rng = np.random.default_rng(seme)
    u = (np.arange(lato) + 0.5) / lato * n
    k = np.floor(u).astype(int) % n
    f = u - np.floor(u)
    tinte = np.array(base) * (1 + 0.13 * rng.normal(size=(n, 1)))
    vena = rumore(lato, n * 3, 40, seme) * 0.5 + rumore(lato, n * 8, 90, seme + 2) * 0.5
    rgb = tinte[k][None, :, :] * (0.75 + 0.45 * vena)[..., None]
    rgb[:, (f < 0.04) | (f > 0.97)] *= 0.3
    y = np.arange(lato)
    for j in range(n):
        for _ in range(giunti):
            yy = rng.integers(0, lato)
            cols = k == j
            rgb[max(0, yy - 1):yy + 1][:, cols] *= 0.35
            for dx in (0.25, 0.75):
                cx = int((j + dx) / n * lato)
                rgb[max(0, yy - 6):yy - 3, max(0, cx - 1):cx + 2] = np.array([0.12, 0.11, 0.10])
    return immagine(nome, rgb)


def tex_cemento(nome, base=(0.50, 0.49, 0.45), lato=512, seme=4, file=8, mimetica=None):
    """Calcestruzzo gettato: le file delle tavole della cassaforma, macchie, colature; mimetica = due colori
    a chiazze grandi (opzionale)."""
    rng = np.random.default_rng(seme)
    rgb = np.ones((lato, lato, 3)) * np.array(base)
    h = lato // file
    for r in range(file):
        rgb[r * h:(r + 1) * h] *= 1 + 0.05 * rng.normal()
        rgb[r * h:r * h + 2] *= 0.8
    macchie = frattale(lato, seme)
    colature = rumore(lato, 48, 3, seme + 5)
    rgb *= (0.78 + 0.35 * macchie)[..., None]
    rgb *= (0.92 + 0.12 * colature)[..., None]
    if mimetica:
        a = rumore(lato, 3, 3, seme + 7) + 0.3 * rumore(lato, 9, 9, seme + 8)
        b = rumore(lato, 4, 4, seme + 9) + 0.3 * rumore(lato, 11, 11, seme + 10)
        for maschera, colore in ((a > 0.8, mimetica[0]), (b > 0.85, mimetica[1])):
            rgb[maschera] = rgb[maschera] * 0.35 + np.array(colore) * (0.65 * (0.8 + 0.4 * macchie[maschera]))[:, None]
    return immagine(nome, rgb)


def tex_ardesia(nome, base=(0.20, 0.22, 0.26), lato=512, seme=5, righe=16, colonne=12):
    """Lastre d'ardesia in file sfalsate, col bordo di sotto in ombra."""
    rng = np.random.default_rng(seme)
    rgb = np.zeros((lato, lato, 3))
    h = lato // righe
    x = (np.arange(lato) + 0.5) / lato
    for r in range(righe):
        u = (x * colonne + 0.5 * (r % 2)) % colonne
        k = np.floor(u).astype(int)
        f = u - k
        tinte = np.array(base) * (1 + 0.15 * rng.normal(size=(colonne, 1)))
        fila = tinte[k % colonne][None, :, :].repeat(h, axis=0)
        ombra = np.linspace(1.0, 0.55, h)[::-1][:, None]       # in basso (riga 0 = basso dell'immagine)
        fila = fila * ombra[..., None]
        fila[:, (f < 0.03) | (f > 0.97)] *= 0.4
        rgb[r * h:(r + 1) * h] = fila
    rgb *= (0.85 + 0.3 * frattale(lato, seme))[..., None]
    return immagine(nome, rgb)


def tex_terra(nome, erba=(0.22, 0.30, 0.11), terra=(0.34, 0.26, 0.16), lato=512, seme=6, quanta=0.55):
    """Terra battuta con ciuffi d'erba: chiazze grandi e grana fine."""
    m = frattale(lato, seme)
    fine = rumore(lato, 128, 128, seme + 3)
    w = np.clip((m - (1 - quanta) + 0.08) / 0.16, 0, 1)[..., None]
    rgb = np.array(terra) * (1 - w) + np.array(erba) * w
    return immagine(nome, rgb * (0.75 + 0.45 * fine)[..., None])


def tex_sacchetti(nome, base=(0.55, 0.48, 0.33), lato=512, seme=7, righe=8, colonne=4):
    """Muro di sacchetti di sabbia: file sfalsate di cuscini tondeggianti, con le cuciture."""
    rng = np.random.default_rng(seme)
    rgb = np.zeros((lato, lato, 3))
    h = lato // righe
    x = (np.arange(lato) + 0.5) / lato
    yy = (np.arange(h) + 0.5) / h
    for r in range(righe):
        u = (x * colonne + 0.5 * (r % 2)) % colonne
        k = np.floor(u).astype(int)
        f = u - k
        tinte = np.array(base) * (1 + 0.1 * rng.normal(size=(colonne, 1)))
        gonfio = (np.sin(np.pi * yy)[:, None] ** 0.5) * (np.sin(np.pi * f)[None, :] ** 0.35)
        fila = tinte[k % colonne][None, :, :] * (0.35 + 0.75 * gonfio)[..., None]
        rgb[r * h:(r + 1) * h] = fila
    rgb *= (0.85 + 0.3 * rumore(lato, 64, 64, seme))[..., None]
    return immagine(nome, rgb)


def tex_drappo(nome, fondo=(0.55, 0.06, 0.05), bordo=(0.85, 0.62, 0.2), lato=256, emblema="croce"):
    """Stendardo nemico: rosso con l'orlo d'oro e un emblema semplice."""
    yy, xx = np.mgrid[0:lato, 0:lato]
    u = (xx + 0.5) / lato
    v = (yy + 0.5) / lato
    rgb = np.ones((lato, lato, 3)) * np.array(fondo)
    rgb *= (0.92 + 0.1 * np.sin(u * 9 + v * 4))[..., None]
    if emblema == "croce":
        m = (np.abs(u - 0.5) < 0.07) | (np.abs(v - 0.55) < 0.07)
        rgb[m & (v > 0.15) & (v < 0.9) & (u > 0.15) & (u < 0.85)] = np.array(bordo)
    elif emblema == "aquila":
        corpo = ((u - 0.5) / 0.08) ** 2 + ((v - 0.5) / 0.22) ** 2 < 1
        ali = (np.abs(v - 0.62 + 0.25 * np.abs(u - 0.5)) < 0.05) & (np.abs(u - 0.5) < 0.32)
        testa = ((u - 0.5) / 0.06) ** 2 + ((v - 0.76) / 0.06) ** 2 < 1
        rgb[corpo | ali | testa] = np.array(bordo)
    rgb[(u < 0.05) | (u > 0.95) | (v < 0.05) | (v > 0.95)] = np.array(bordo)
    return immagine(nome, rgb)


def materiale_tex(u, chiave, img, metri, ruvidita=0.8, metallo=0.0):
    """Materiale con la texture ripetuta ogni "metri" metri, proiettata a scatola dalle coordinate dell'oggetto."""
    m = u.materiale(chiave, (1.0, 1.0, 1.0), metallo=metallo, ruvidita=ruvidita, immagine=img)
    nt = m.node_tree
    tex = nt.nodes["Texture"]
    tex.projection = "BOX"
    tex.projection_blend = 0.2
    coord = nt.nodes.get("Coord") or nt.nodes.new("ShaderNodeTexCoord")
    coord.name = "Coord"
    mappa = nt.nodes.get("Mappa") or nt.nodes.new("ShaderNodeMapping")
    mappa.name = "Mappa"
    mappa.inputs["Scale"].default_value = (1.0 / metri,) * 3
    nt.links.new(coord.outputs["Object"], mappa.inputs["Vector"])
    nt.links.new(mappa.outputs["Vector"], tex.inputs["Vector"])
    return m


# Pezzi d'architettura ------------------------------------------------------------------------------

def scatola(c, dim, rot=0.0, inclina=None):
    m = Matrix.Rotation(math.radians(rot), 4, "Z")
    if inclina:
        m = m @ Matrix.Rotation(math.radians(inclina[1]), 4, inclina[0])
    return V.scatola(c, dim, m)


def prisma_lungo(a, b, profilo):
    """Profilo (laterale, z) chiuso, estruso sul suolo dal punto a al punto b (laterale = a sinistra
    andando da a verso b)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    d.z = 0
    d.normalize()
    lato = Vector((-d.y, d.x, 0))
    bm = bmesh.new()
    A = [bm.verts.new(a + lato * s + Vector((0, 0, z))) for s, z in profilo]
    B = [bm.verts.new(b + lato * s + Vector((0, 0, z))) for s, z in profilo]
    bm.faces.new(A[::-1])
    bm.faces.new(B)
    n = len(profilo)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((A[i], A[j], B[j], B[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def cono(c, r, h, n=16, r_cima=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=n, radius1=r, radius2=r_cima, depth=h)
    bmesh.ops.translate(bm, vec=Vector(c) + Vector((0, 0, h / 2)), verts=bm.verts)
    return bm


def cilindro_z(c, r, h, n=16, r_cima=None):
    c = Vector(c)
    return V.cilindro(c, c + Vector((0, 0, h)), r, r if r_cima is None else r_cima, n=n)


def piramide(c, lx, ly, h, rot=0.0):
    """Tetto a quattro falde (piramide a base rettangolare lx × ly)."""
    bm = cono((0, 0, 0), math.sqrt(0.5), h, n=4)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(45), 3, "Z"))
    bmesh.ops.scale(bm, vec=(lx, ly, 1.0), verts=bm.verts)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(rot), 3, "Z"))
    bmesh.ops.translate(bm, vec=Vector(c), verts=bm.verts)
    return bm


def lungo(a, b, passo, fn):
    """Chiama fn(punto, direzione) a intervalli regolari lungo il segmento a-b (centrati)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    n = max(1, int(d.length / passo))
    return [fn(a + d * ((i + 0.5) / n), d.normalized()) for i in range(n)]


def merli(a, b, z, alto, spessore, largo=0.5, passo=0.9, fuori=0.0):
    """Merli lungo il segmento a-b (la faccia esterna a sinistra andando da a a b, spostata di "fuori")."""
    def merlo(p, d):
        lato = Vector((-d.y, d.x, 0))
        return scatola(p + lato * fuori + Vector((0, 0, z + alto / 2)), (largo, spessore, alto),
                       rot=math.degrees(math.atan2(d.y, d.x)))
    return lungo(a, b, passo, merlo)


def anello_merli(c, r, z, alto, n, spessore=0.3, largo=0.5):
    pezzi = []
    for i in range(n):
        a = 2 * math.pi * (i + 0.5) / n
        d = Vector((math.cos(a), math.sin(a), 0))
        pezzi.append(scatola(Vector(c) + d * (r - spessore / 2) + Vector((0, 0, z + alto / 2)),
                             (spessore, largo, alto), rot=math.degrees(a)))
    return pezzi


def mensole_anello(c, r, z, n, alto=0.35, fuori=0.25, largo=0.18):
    """Beccatelli (mensole dei piombatoi) tutto attorno a una torre tonda."""
    pezzi = []
    for i in range(n):
        a = 2 * math.pi * i / n
        d = Vector((math.cos(a), math.sin(a), 0))
        pezzi.append(scatola(Vector(c) + d * (r + fuori / 2 - 0.02) + Vector((0, 0, z + alto / 2)),
                             (fuori, largo, alto), rot=math.degrees(a)))
    return pezzi


def palizzata(a, b, z0, z1, tronco=0.3, punta=0.28):
    """Fila di pali appuntiti tra a e b: una lastra con il bordo in alto a denti (lo spessore lo dà
    l'oggetto); i tronchi veri li disegna la texture, con lo stesso passo."""
    a, b = Vector(a), Vector(b)
    d = b - a
    n = max(1, round(d.length / tronco))
    bm = bmesh.new()
    giu = [bm.verts.new(a + d * (i / n) + Vector((0, 0, z0))) for i in range(n + 1)]
    su = [bm.verts.new(a + d * (i / n) + Vector((0, 0, z1 - punta))) for i in range(n + 1)]
    for i in range(n):
        cima = bm.verts.new(a + d * ((i + 0.5) / n) + Vector((0, 0, z1 + 0.04 * ((i * 7) % 3 - 1))))
        bm.faces.new((giu[i], giu[i + 1], su[i + 1], cima, su[i]))
    return bm


def drappo(c, larghezza, altezza, verso, onde=0.06, n=8):
    """Bandiera rettangolare appesa per il lato sinistro (UV su tutta l'immagine)."""
    c = Vector(c)
    verso = Vector(verso).normalized()
    normale = verso.cross(Vector((0, 0, 1))).normalized()
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    righe = []
    for i in range(n + 1):
        f = i / n
        riga = []
        for k in range(3):
            g = k / 2
            p = c + verso * larghezza * f - Vector((0, 0, altezza * g)) + normale * onde * math.sin(f * 2 * math.pi) * f
            riga.append(bm.verts.new(p))
        righe.append(riga)
    for i in range(n):
        for k in range(2):
            fa = bm.faces.new((righe[i][k], righe[i + 1][k], righe[i + 1][k + 1], righe[i][k + 1]))
            for loop, (a, b) in zip(fa.loops, ((i, k), (i + 1, k), (i + 1, k + 1), (i, k + 1))):
                loop[uv].uv = (a / n, 1 - b / 2)
    return bm


# Esportazione ------------------------------------------------------------------------------------

def esporta(nome, tiri, triangoli=7000, quote=None, lato=1024):
    """Tutto rigido sull'osso "bacino"; "tiro1".."tiroN" sono i punti da cui partono frecce e colpi."""
    import esporta as E
    extra = {"tiro%d" % (i + 1): ("bacino", Vector(p)) for i, p in enumerate(tiri)}
    r = E.prepara(nome, {"bacino": ((0, 0, 1.0), (0, 0, 1.2))}, rigidi={"*": "bacino"}, quote=quote or {},
                  triangoli=triangoli, corpo="(nessuno)", umano=False, extra=extra)
    E.cuoci(lato=lato)
    return r


def conta(u):
    triangoli = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in u.col.objects if o.type == "MESH")
    return {"oggetti": len(u.col.objects), "triangoli": triangoli}
