"""Anteprima dei campi di battaglia generati da test/campi.luau, senza Studio.

Disegna il rilievo (con i colori dei materiali del Terrain di Roblox) e tutte le parti (blocchi, cunei,
cilindri, palle) con uno z-buffer, dal punto dove arriva il giocatore e dall'alto.

    lune run test/campi /tmp/campi
    python3 tools/anteprima_campi.py /tmp/campi [livello ...]

Scrive <cartella>/NN_giocatore.jpg e <cartella>/NN_alto.jpg.
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image

# Colori predefiniti dei materiali del Terrain di Roblox.
TERRENO = {
    "Grass": (106, 127, 63), "LeafyGrass": (115, 132, 74), "Ground": (102, 92, 59), "Mud": (58, 46, 36),
    "Sand": (143, 126, 95), "Sandstone": (137, 90, 71), "Rock": (102, 108, 111), "Slate": (63, 127, 107),
    "Snow": (195, 199, 218), "Ice": (129, 194, 224), "Glacier": (101, 176, 234), "Pavement": (148, 148, 140),
    "Cobblestone": (132, 123, 90), "Limestone": (206, 173, 148), "Basalt": (30, 30, 37), "Asphalt": (115, 123, 107),
    "Concrete": (127, 102, 63), "Brick": (138, 86, 62), "Salt": (198, 189, 181), "Air": (0, 0, 0),
}
ACQUA = (52, 104, 120)
CIELO = np.array([200, 214, 230], dtype=np.float32) / 255
SOLE = np.array([-0.45, 0.78, 0.43])
SOLE /= np.linalg.norm(SOLE)


def terreno_triangoli(d, fattore=2):
    t = d["terreno"]
    n, x0, z0, passo = t["n"], t["x0"], t["z0"], t["passo"]
    suolo = np.array(t["suolo"], dtype=np.float32).reshape(n, n)[::fattore, ::fattore]
    mat = np.array(t["mat"]).reshape(n, n)[::fattore, ::fattore]
    acqua = np.array([np.nan if a is False else a for a in t["acqua"]], dtype=np.float32).reshape(n, n)[::fattore, ::fattore]
    nomi = t["nomi"]
    m = suolo.shape[0]
    p = passo * fattore
    xs = x0 + (np.arange(m) + 0.5) * p
    zs = z0 + (np.arange(m) + 0.5) * p
    tris, cols = [], []
    for i in range(m - 1):
        for k in range(m - 1):
            a = (xs[i], suolo[i, k], zs[k])
            b = (xs[i + 1], suolo[i + 1, k], zs[k])
            c = (xs[i], suolo[i, k + 1], zs[k + 1])
            e = (xs[i + 1], suolo[i + 1, k + 1], zs[k + 1])
            col = TERRENO.get(nomi[mat[i, k] - 1], (255, 0, 255))
            tris += [(a, b, e), (a, e, c)]
            cols += [col, col]
            w = acqua[i, k]
            if not np.isnan(w):
                a, b, c, e = (xs[i], w, zs[k]), (xs[i + 1], w, zs[k]), (xs[i], w, zs[k + 1]), (xs[i + 1], w, zs[k + 1])
                tris += [(a, b, e), (a, e, c)]
                cols += [ACQUA, ACQUA]
    return tris, cols


def anello(n):
    return [(math.cos(2 * math.pi * j / n), math.sin(2 * math.pi * j / n)) for j in range(n)]


def parte_triangoli(p):
    sx, sy, sz = p["s"]
    c = p["c"]
    pos = np.array(c[:3])
    R = np.array(c[3:]).reshape(3, 3)  # colonne: assi locali X, Y, Z
    f = p["f"]
    facce = []
    if f in ("Block", "Wedge"):
        hx, hy, hz = sx / 2, sy / 2, sz / 2
        v = {}
        for ix in (-1, 1):
            for iy in (-1, 1):
                for iz in (-1, 1):
                    v[(ix, iy, iz)] = (ix * hx, iy * hy, iz * hz)
        if f == "Block":
            quads = [
                [(-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1)], [(-1, 1, -1), (1, 1, -1), (1, 1, 1), (-1, 1, 1)],
                [(-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1)], [(-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)],
                [(-1, -1, -1), (-1, 1, -1), (-1, 1, 1), (-1, -1, 1)], [(1, -1, -1), (1, 1, -1), (1, 1, 1), (1, -1, 1)],
            ]
            for q in quads:
                facce.append([v[q[0]], v[q[1]], v[q[2]]])
                facce.append([v[q[0]], v[q[2]], v[q[3]]])
        else:
            # Cuneo di Roblox: base intera, faccia verticale dietro (+Z), pendenza verso davanti (-Z).
            b0, b1, b2, b3 = v[(-1, -1, -1)], v[(1, -1, -1)], v[(1, -1, 1)], v[(-1, -1, 1)]
            t0, t1 = v[(-1, 1, 1)], v[(1, 1, 1)]
            facce += [[b0, b1, b2], [b0, b2, b3], [b3, b2, t1], [b3, t1, t0], [b0, b1, t1], [b0, t1, t0], [b0, b3, t0], [b1, b2, t1]]
    elif f == "Cylinder":
        r = min(sy, sz) / 2
        hx = sx / 2
        ring = anello(10)
        for j in range(10):
            a, b = ring[j], ring[(j + 1) % 10]
            p0, p1 = (-hx, a[0] * r, a[1] * r), (-hx, b[0] * r, b[1] * r)
            q0, q1 = (hx, a[0] * r, a[1] * r), (hx, b[0] * r, b[1] * r)
            facce += [[p0, p1, q1], [p0, q1, q0], [(-hx, 0, 0), p0, p1], [(hx, 0, 0), q0, q1]]
    else:  # Ball (diametro = lato minore) o Sphere (ellissoide della SpecialMesh)
        if f == "Ball":
            rx = ry = rz = min(sx, sy, sz) / 2
        else:
            rx, ry, rz = sx / 2, sy / 2, sz / 2
        nl, nm = 5, 8
        punti = {}
        for i in range(nl + 1):
            th = math.pi * i / nl
            for j in range(nm):
                ph = 2 * math.pi * j / nm
                punti[(i, j)] = (rx * math.sin(th) * math.cos(ph), ry * math.cos(th), rz * math.sin(th) * math.sin(ph))
        for i in range(nl):
            for j in range(nm):
                a, b, c, e = punti[(i, j)], punti[(i, (j + 1) % nm)], punti[(i + 1, j)], punti[(i + 1, (j + 1) % nm)]
                facce += [[a, b, e], [a, e, c]]
    loc = np.array(facce, dtype=np.float64)
    return loc @ R.T + pos


def ombreggia(tris, cols, cam):
    tris = np.asarray(tris, dtype=np.float64)
    cols = np.asarray(cols, dtype=np.float32) / 255
    n = np.cross(tris[:, 1] - tris[:, 0], tris[:, 2] - tris[:, 0])
    lung = np.linalg.norm(n, axis=1, keepdims=True)
    n = n / np.maximum(lung, 1e-9)
    centro = tris.mean(axis=1)
    verso = cam - centro
    n *= np.sign(np.sum(n * verso, axis=1, keepdims=True) + 1e-9)
    luce = 0.5 + 0.62 * np.clip(n @ SOLE, 0, 1)
    c = cols * luce[:, None]
    dist = np.linalg.norm(verso, axis=1)
    nebbia = 1 - np.exp(-dist / 1100)
    c = c * (1 - nebbia[:, None]) + CIELO * nebbia[:, None]
    return tris, np.clip(c, 0, 1)


def disegna(tris, cols, cam, bersaglio, fov, W, H, percorso):
    cam = np.asarray(cam, dtype=np.float64)
    avanti = np.asarray(bersaglio, dtype=np.float64) - cam
    avanti /= np.linalg.norm(avanti)
    destra = np.cross(avanti, [0, 1, 0])
    destra /= np.linalg.norm(destra)
    su = np.cross(destra, avanti)
    rel = tris - cam
    x = rel @ destra
    y = rel @ su
    z = rel @ avanti
    vicino = 0.5
    tieni = np.all(z > vicino, axis=1)
    x, y, z, cols = x[tieni], y[tieni], z[tieni], cols[tieni]
    f = (H / 2) / math.tan(math.radians(fov) / 2)
    px = W / 2 + f * x / z
    py = H / 2 - f * y / z
    img = np.ones((H, W, 3), dtype=np.float32) * CIELO
    zb = np.full((H, W), np.inf, dtype=np.float32)
    x0 = np.clip(np.floor(px.min(axis=1)), 0, W).astype(int)
    x1 = np.clip(np.ceil(px.max(axis=1)), 0, W).astype(int)
    y0 = np.clip(np.floor(py.min(axis=1)), 0, H).astype(int)
    y1 = np.clip(np.ceil(py.max(axis=1)), 0, H).astype(int)
    for t in np.nonzero((x1 > x0) & (y1 > y0))[0]:
        if (x1[t] - x0[t]) * (y1[t] - y0[t]) > W * H * 4:
            continue
        gx, gy = np.meshgrid(np.arange(x0[t], x1[t]) + 0.5, np.arange(y0[t], y1[t]) + 0.5)
        X0, X1, X2 = px[t]
        Y0, Y1, Y2 = py[t]
        den = (Y1 - Y2) * (X0 - X2) + (X2 - X1) * (Y0 - Y2)
        if abs(den) < 1e-9:
            continue
        l0 = ((Y1 - Y2) * (gx - X2) + (X2 - X1) * (gy - Y2)) / den
        l1 = ((Y2 - Y0) * (gx - X2) + (X0 - X2) * (gy - Y2)) / den
        l2 = 1 - l0 - l1
        dentro = (l0 >= -1e-4) & (l1 >= -1e-4) & (l2 >= -1e-4)
        if not dentro.any():
            continue
        zt = z[t]
        prof = 1 / (l0 / zt[0] + l1 / zt[1] + l2 / zt[2])
        blocco = zb[y0[t]:y1[t], x0[t]:x1[t]]
        meglio = dentro & (prof < blocco)
        blocco[meglio] = prof[meglio]
        img[y0[t]:y1[t], x0[t]:x1[t]][meglio] = cols[t]
    Image.fromarray((img * 255).astype(np.uint8)).save(percorso, quality=88)


def anteprima(cartella, numero):
    percorso = os.path.join(cartella, "%02d.json" % numero)
    with open(percorso) as fp:
        d = json.load(fp)
    o = np.array(d["origine"], dtype=np.float64)
    tris, cols = terreno_triangoli(d)
    for p in d["parti"]:
        if p["t"] >= 0.9:
            continue
        pt = parte_triangoli(p)
        tris.extend(pt.tolist())
        cols.extend([p["k"]] * len(pt))
    t = d["terreno"]
    n = t["n"]
    suolo = np.array(t["suolo"]).reshape(n, n)

    def quota(x, z):
        i = int((o[0] + x - t["x0"]) / t["passo"])
        k = int((o[2] + z - t["z0"]) / t["passo"])
        return suolo[min(max(i, 0), n - 1), min(max(k, 0), n - 1)]

    viste = [
        ("giocatore", o + [0, quota(0, -88) + 13, -88], o + [0, quota(0, 30) + 2, 30], 70, 1280, 720),
        ("alto", o + [0, 260, -340], o + [0, 0, 40], 62, 1280, 720),
        ("lato", o + [300, 110, -40], o + [0, 10, 60], 66, 1280, 720),
    ]
    for nome, cam, bersaglio, fov, W, H in viste:
        tt, cc = ombreggia(tris, cols, cam)
        uscita = os.path.join(cartella, "%02d_%s.jpg" % (numero, nome))
        disegna(tt, cc, cam, bersaglio, fov, W, H, uscita)
    return d["nome"], len(d["parti"])


if __name__ == "__main__":
    cartella = sys.argv[1]
    numeri = [int(a) for a in sys.argv[2:]] or range(1, 31)
    for numero in numeri:
        if os.path.exists(os.path.join(cartella, "%02d.json" % numero)):
            print(numero, *anteprima(cartella, numero), flush=True)
