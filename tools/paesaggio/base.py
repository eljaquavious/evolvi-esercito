"""Attrezzi per i modelli del paesaggio (alberi, cespugli, rocce, oggetti dell'uomo).

Le forme organiche (chiome, rocce) sono campi di distanza con rumore, trasformati in mesh con i marching
cubes e poi alleggerite; rami e tronchi sono tubi lungo curve. Poi un atlante uv (xatlas) e una texture
"cotta": colore procedurale in 3D (corteccia, foglie, pietra), occlusione ambientale e un po' di luce
dall'alto, così le superfici sono opache e ombreggiate anche senza luci particolari.

Misure in studs (come gli oggetti di Server/Paesaggio), +Y in alto, l'origine a terra al piede del modello.
"""
import math
import os
import sys

import fast_simplification
import numpy as np
import trimesh
import xatlas
from PIL import Image
from skimage.measure import marching_cubes

QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(QUI, "..", "blocchi"))
import meshdati  # noqa: E402


# Rumore di Perlin 3D -------------------------------------------------------------------------------

_GRAD = np.array([[1, 1, 0], [-1, 1, 0], [1, -1, 0], [-1, -1, 0], [1, 0, 1], [-1, 0, 1], [1, 0, -1], [-1, 0, -1],
                  [0, 1, 1], [0, -1, 1], [0, 1, -1], [0, -1, -1]], float)


class Rumore:
    def __init__(self, seme=0):
        rng = np.random.default_rng(seme)
        p = rng.permutation(256)
        self.perm = np.concatenate([p, p])

    def __call__(self, p):
        p = np.asarray(p, float)
        fl = np.floor(p)
        i = fl.astype(np.int64) & 255
        f = p - fl
        u = f * f * f * (f * (f * 6 - 15) + 10)
        perm = self.perm
        out = 0.0

        def g(ix, iy, iz, fx, fy, fz):
            h = perm[perm[perm[ix] + iy] + iz] % 12
            gr = _GRAD[h]
            return gr[:, 0] * fx + gr[:, 1] * fy + gr[:, 2] * fz

        x, y, z = i[:, 0], i[:, 1], i[:, 2]
        fx, fy, fz = f[:, 0], f[:, 1], f[:, 2]
        n000 = g(x, y, z, fx, fy, fz)
        n100 = g(x + 1, y, z, fx - 1, fy, fz)
        n010 = g(x, y + 1, z, fx, fy - 1, fz)
        n110 = g(x + 1, y + 1, z, fx - 1, fy - 1, fz)
        n001 = g(x, y, z + 1, fx, fy, fz - 1)
        n101 = g(x + 1, y, z + 1, fx - 1, fy, fz - 1)
        n011 = g(x, y + 1, z + 1, fx, fy - 1, fz - 1)
        n111 = g(x + 1, y + 1, z + 1, fx - 1, fy - 1, fz - 1)
        ux, uy, uz = u[:, 0], u[:, 1], u[:, 2]
        a = n000 + ux * (n100 - n000)
        b = n010 + ux * (n110 - n010)
        c = n001 + ux * (n101 - n001)
        d = n011 + ux * (n111 - n011)
        e = a + uy * (b - a)
        f2 = c + uy * (d - c)
        out = e + uz * (f2 - e)
        return out

    def fbm(self, p, ottave=4, scala=1.0, guadagno=0.5):
        p = np.asarray(p, float) * scala
        somma, ampiezza, norma = 0.0, 1.0, 0.0
        for k in range(ottave):
            somma = somma + ampiezza * self(p * (2.0 ** k) + k * 17.31)
            norma += ampiezza
            ampiezza *= guadagno
        return somma / norma


# Forme -------------------------------------------------------------------------------------------

def da_campo(funzione, minimo, massimo, passo, bersaglio=None):
    """Mesh della superficie funzione(p) = 0 (negativa dentro) nel box, con i marching cubes."""
    minimo = np.asarray(minimo, float) - passo * 2
    massimo = np.asarray(massimo, float) + passo * 2
    n = np.ceil((massimo - minimo) / passo).astype(int) + 1
    xs = [minimo[k] + np.arange(n[k]) * passo for k in range(3)]
    X, Y, Z = np.meshgrid(*xs, indexing="ij")
    punti = np.stack([X.ravel(), Y.ravel(), Z.ravel()], 1)
    valori = funzione(punti).reshape(n)
    # Bordo del box sempre "fuori": la superficie si chiude.
    valori[[0, -1], :, :] = 1
    valori[:, [0, -1], :] = 1
    valori[:, :, [0, -1]] = 1
    v, f, _, _ = marching_cubes(valori, 0.0, spacing=(passo, passo, passo))
    v = v + minimo
    mesh = trimesh.Trimesh(v, f, process=True)
    if mesh.volume < 0:
        mesh.invert()  # normali in fuori
    if bersaglio and len(mesh.faces) > bersaglio:
        mesh = semplifica(mesh, bersaglio)
    return mesh


def semplifica(mesh, bersaglio):
    riduzione = 1 - bersaglio / len(mesh.faces)
    v, f = fast_simplification.simplify(mesh.vertices.astype(np.float32), mesh.faces.astype(np.int32), riduzione)
    m = trimesh.Trimesh(v, f, process=True)
    return m


def unione_morbida(distanze, k):
    """Unione morbida (smooth min polinomiale) di più distanze, lungo l'asse 0."""
    d = distanze[0]
    for altra in distanze[1:]:
        h = np.clip(0.5 + 0.5 * (altra - d) / k, 0, 1)
        d = altra + (d - altra) * h - k * h * (1 - h)
    return d


def tubo(punti, raggi, lati=8, chiudi_fine=True, chiudi_inizio=False):
    """Tubo lungo una polilinea, con raggio variabile (anelli con riferimento trasportato)."""
    P = np.asarray(punti, float)
    R = np.asarray(raggi, float)
    n = len(P)
    T = np.gradient(P, axis=0)
    T /= np.maximum(np.linalg.norm(T, axis=1, keepdims=True), 1e-9)
    ref = np.array([1.0, 0, 0]) if abs(T[0, 0]) < 0.9 else np.array([0, 0, 1.0])
    N = np.cross(T[0], ref)
    N /= np.linalg.norm(N)
    vert = []
    for i in range(n):
        if i > 0:
            N = N - T[i] * np.dot(N, T[i])
            N /= max(np.linalg.norm(N), 1e-9)
        B = np.cross(T[i], N)
        for k in range(lati):
            a = 2 * np.pi * k / lati
            vert.append(P[i] + R[i] * (np.cos(a) * N + np.sin(a) * B))
    facce = []
    for i in range(n - 1):
        for k in range(lati):
            a, b = i * lati + k, i * lati + (k + 1) % lati
            c, d = a + lati, b + lati
            facce += [[a, c, b], [b, c, d]]
    vert = list(vert)
    if chiudi_fine:
        punta = len(vert)
        vert.append(P[-1] + T[-1] * R[-1] * 0.6)
        base = (n - 1) * lati
        for k in range(lati):
            facce.append([base + k, punta, base + (k + 1) % lati])
    if chiudi_inizio:
        fondo = len(vert)
        vert.append(P[0] - T[0] * R[0] * 0.3)
        for k in range(lati):
            facce.append([k, (k + 1) % lati, fondo])
    # Gli anelli girano in modo che le facce guardino dentro: si rovescia, normali in fuori.
    return trimesh.Trimesh(np.array(vert), np.array(facce)[:, ::-1], process=False)


def capsule(p, a, b, ra, rb, piatto=1.0):
    """Distanza da un cono arrotondato da a (raggio ra) a b (raggio rb); piatto > 1 lo schiaccia in verticale."""
    k = np.array([1.0, piatto, 1.0])
    q, a, b = p * k, np.asarray(a, float) * k, np.asarray(b, float) * k
    ab = b - a
    t = np.clip(((q - a) @ ab) / max(ab @ ab, 1e-9), 0, 1)
    d = np.linalg.norm(q - (a + t[:, None] * ab), axis=1)
    return d - (ra + (rb - ra) * t)


def ruota(v, asse, angolo):
    asse = np.asarray(asse, float) / np.linalg.norm(asse)
    v = np.asarray(v, float)
    return v * math.cos(angolo) + np.cross(asse, v) * math.sin(angolo) + asse * (asse @ v) * (1 - math.cos(angolo))


def curva(da, a, piega=(0, 0, 0), passi=6):
    """Punti di una curva quadratica da "da" ad "a", spinta di "piega" a metà."""
    da, a, piega = np.asarray(da, float), np.asarray(a, float), np.asarray(piega, float)
    meta = (da + a) / 2 + piega
    t = np.linspace(0, 1, passi)[:, None]
    return (1 - t) ** 2 * da + 2 * (1 - t) * t * meta + t * t * a


# Colori ------------------------------------------------------------------------------------------

def rgb(c):
    c = c.lstrip("#")
    return np.array([int(c[i:i + 2], 16) for i in (0, 2, 4)], float)


def mescola(a, b, t):
    t = np.asarray(t, float)
    if t.ndim == 1:
        t = t[:, None]
    return a + (b - a) * t


# Cottura -----------------------------------------------------------------------------------------

def _occlusione(pos, normali, tri, raggi=40, seme=3, distanza=None):
    mesh = trimesh.Trimesh(vertices=pos, faces=tri, process=False)
    rng = np.random.default_rng(seme)
    d = rng.normal(size=(raggi, 3))
    d /= np.linalg.norm(d, axis=1, keepdims=True)
    luce = np.zeros(len(pos))
    pesi = 0.0
    for k in range(raggi):
        dk = np.tile(d[k], (len(pos), 1))
        verso = np.sign((dk * normali).sum(1))
        dk = dk * np.where(verso == 0, 1, verso)[:, None]
        origini = pos + normali * 0.03 + dk * 0.02
        peso = 0.55 + 0.45 * np.clip(dk[:, 1], 0, 1)
        if distanza is None:
            colpiti = mesh.ray.intersects_any(origini, dk)
        else:
            loc, idx, _ = mesh.ray.intersects_location(origini, dk, multiple_hits=False)
            colpiti = np.zeros(len(pos), bool)
            if len(idx):
                vicini = np.linalg.norm(loc - origini[idx], axis=1) < distanza
                colpiti[idx[vicini]] = True
        luce += np.where(colpiti, 0, 1) * peso
        pesi += 0.8
    return np.clip(luce / pesi, 0, 1)


def _rasterizza(uv_px, tri, colore_punti, lato):
    img = np.zeros((lato, lato, 3), np.float32)
    pieno = np.zeros((lato, lato), bool)
    for f, (a, b, c) in enumerate(tri):
        T = uv_px[[a, b, c]]
        x0, y0 = np.maximum(np.floor(T.min(0)).astype(int), 0)
        x1, y1 = np.minimum(np.ceil(T.max(0)).astype(int), lato - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        v0, v1 = T[1] - T[0], T[2] - T[0]
        den = v0[0] * v1[1] - v1[0] * v0[1]
        if abs(den) < 1e-12:
            continue
        dx, dy = xs - T[0][0], ys - T[0][1]
        l1 = (dx * v1[1] - v1[0] * dy) / den
        l2 = (v0[0] * dy - dx * v0[1]) / den
        l0 = 1 - l1 - l2
        dentro = (l0 >= -0.04) & (l1 >= -0.04) & (l2 >= -0.04)
        if not dentro.any():
            continue
        L = np.stack([l0, l1, l2], -1)[dentro]
        yy, xx = ys[dentro].astype(int), xs[dentro].astype(int)
        img[yy, xx] = colore_punti(f, (a, b, c), L)
        pieno[yy, xx] = True
    for _ in range(6):
        somma = np.zeros_like(img)
        conta = np.zeros(pieno.shape, np.float32)
        for sx, sy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sp = np.roll(np.roll(pieno, sy, 0), sx, 1)
            somma += np.roll(np.roll(img, sy, 0), sx, 1) * sp[..., None]
            conta += sp
        nuovi = ~pieno & (conta > 0)
        img[nuovi] = somma[nuovi] / conta[nuovi][:, None]
        pieno |= nuovi
    return img


class Modello:
    """Un modello del paesaggio: parti con la loro funzione di colore, poi cotte in una mesh con texture."""

    def __init__(self, nome, lato=512):
        self.nome, self.lato = nome, lato
        self.parti = []  # (mesh, colore(p, n, ao) -> rgb, angolo di spigolo vivo in gradi)

    def aggiungi(self, mesh, colore, angolo=60):
        self.parti.append((mesh, colore, angolo))

    def cuoci(self, raggi_ao=40, distanza_ao=None):
        P, N, F, idx = [], [], [], []
        base = 0
        for k, (mesh, colore, angolo) in enumerate(self.parti):
            m = mesh.copy()
            m.merge_vertices()
            m = trimesh.graph.smooth_shade(m, angle=np.radians(angolo), facet_minarea=1e9) if angolo < 180 else m
            P.append(np.asarray(m.vertices))
            N.append(np.asarray(m.vertex_normals))
            F.append(np.asarray(m.faces) + base)
            idx += [k] * len(m.faces)
            base += len(m.vertices)
        pos, nor, tri = np.vstack(P), np.vstack(N), np.vstack(F)
        parte_faccia = np.array(idx)
        lato = self.lato
        atlante = xatlas.Atlas()
        atlante.add_mesh(pos.astype(np.float32), tri.astype(np.uint32), nor.astype(np.float32))
        area = trimesh.Trimesh(pos, tri, process=False).area
        tpu = np.sqrt(0.6 * lato * lato / area)
        for _ in range(30):
            opz = xatlas.PackOptions()
            opz.padding = 2
            opz.bilinear = True
            opz.texels_per_unit = float(tpu)
            opz.resolution = 0
            atlante.generate(xatlas.ChartOptions(), opz)
            if atlante.width <= lato and atlante.height <= lato:
                break
            tpu *= 0.92 * min(lato / atlante.width, lato / atlante.height) ** 0.5
        vmap, tri_n, uv_n = atlante[0]
        pos, nor = pos[vmap], nor[vmap]
        tri = tri_n.astype(np.int64)
        uv_px = uv_n * np.array([atlante.width, atlante.height])
        ao = _occlusione(pos, nor, tri, raggi=raggi_ao, distanza=distanza_ao)
        colori = [p[1] for p in self.parti]

        def colore_punti(f, abc, L):
            abc = list(abc)
            p3, n3, a3 = L @ pos[abc], L @ nor[abc], np.clip(L @ ao[abc], 0, 1)
            n3 = n3 / np.maximum(np.linalg.norm(n3, axis=1, keepdims=True), 1e-9)
            return colori[parte_faccia[f]](p3, n3, a3)

        img = _rasterizza(uv_px, tri, colore_punti, lato)
        n = len(pos)
        self.dati = {"pos": pos, "uv": uv_px / lato, "normali": nor, "ossa_v": np.zeros((n, 4), np.int64),
                     "pesi": np.tile([1.0, 0, 0, 0], (n, 1)), "triangoli": tri,
                     # 6 bit per canale: non si vede e la texture si comprime molto meglio.
                     "texture": Image.fromarray((np.clip(img, 0, 255).astype(np.uint8) >> 2) << 2 | 2), "ossa": []}
        return self.dati

    def scrivi(self, nota, glb=None):
        d = self.dati
        meshdati.scrivi(self.nome, d, nota)
        if glb:
            os.makedirs(glb, exist_ok=True)
            meshdati.glb(d, os.path.join(glb, self.nome + ".glb"))
        print(self.nome, len(d["pos"]), "vertici", len(d["triangoli"]), "triangoli", flush=True)


def ombreggia(colore, n, ao, forza_ao=1.0, alto=0.12):
    """Colore base (N,3) con occlusione ambientale e un po' di luce del cielo dall'alto."""
    luce = (np.clip(ao, 0, 1) ** (0.9 * forza_ao)) * 0.62 + 0.38
    luce = luce * (1 - alto + alto * (0.5 + 0.5 * n[:, 1]))
    return colore * luce[:, None]
