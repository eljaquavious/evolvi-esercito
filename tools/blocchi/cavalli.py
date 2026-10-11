"""Cavalli dei vecchi modelli Blender, ripresi per i cavalieri a blocchi.

Dal modello vecchio si tengono solo i triangoli del cavallo (ossa cavallo* e zampa*), si dà loro un
nuovo atlante uv compatto (xatlas) e si ricuoce la texture: il colore viene da quella vecchia, a cui si
aggiungono occlusione ambientale (raggi sulla mesh) e un poco di luce dall'alto, così il pelo non è
più piatto e lucido.
"""
import numpy as np
import trimesh
import xatlas
from PIL import Image

import meshdati


def _cavallo(nome_ossa):
    return nome_ossa.startswith(("cavallo", "zampa"))


def ossa_cavallo(vecchio):
    """Le ossa del cavallo (nell'ordine del file, i padri prima dei figli)."""
    return [o for o in vecchio["ossa"] if _cavallo(o["nome"])]


def _occlusione(pos, normali, tri, raggi=48, seme=3):
    """Quanta luce del cielo arriva a ogni vertice (1 = tutta), con raggi a caso nell'emisfero."""
    mesh = trimesh.Trimesh(vertices=pos, faces=tri, process=False)
    rng = np.random.default_rng(seme)
    d = rng.normal(size=(raggi, 3))
    d /= np.linalg.norm(d, axis=1, keepdims=True)
    luce = np.zeros(len(pos))
    for k in range(raggi):
        dk = np.tile(d[k], (len(pos), 1))
        verso = np.sign((dk * normali).sum(1))
        dk = dk * np.where(verso == 0, 1, verso)[:, None]
        origini = pos + normali * 0.01 + dk * 0.005
        colpiti = mesh.ray.intersects_any(origini, dk)
        # Il cielo pesa di più dall'alto (come la luce ambiente di Roblox).
        peso = 0.6 + 0.4 * np.clip(dk[:, 1], 0, 1)
        luce += np.where(colpiti, 0, 1) * peso
    return luce / (raggi * 0.8)


def cuoci(vecchio, larghezza, altezza):
    """Cavallo del modello "vecchio" con texture nuova larghezza x altezza pixel.
    Restituisce (dati, immagine): dati con pos, normali, triangoli, ossa (nomi), pesi e uv in pixel."""
    nomi = [o["nome"] for o in vecchio["ossa"]]
    n = len(vecchio["pos"])
    dominante = vecchio["ossa_v"][np.arange(n), vecchio["pesi"].argmax(1)]
    cav = np.array([_cavallo(nomi[i]) for i in dominante])
    tri_v = vecchio["triangoli"]
    tri_v = tri_v[cav[tri_v].all(1)]
    usati = np.unique(tri_v)
    nuovo_indice = -np.ones(n, dtype=np.int64)
    nuovo_indice[usati] = np.arange(len(usati))
    tri = nuovo_indice[tri_v]
    pos = vecchio["pos"][usati]
    normali = vecchio["normali"][usati]
    uv_vecchie = vecchio["uv"][usati]
    ossa_v = vecchio["ossa_v"][usati]
    pesi = vecchio["pesi"][usati].copy()
    # Solo le ossa del cavallo: il cavaliere nuovo ha un altro scheletro.
    for k in range(4):
        pesi[:, k] *= np.array([_cavallo(nomi[i]) for i in ossa_v[:, k]])
    pesi /= np.maximum(pesi.sum(1, keepdims=True), 1e-9)

    # Si saldano i vertici con la stessa posizione (le cuciture uv vecchie spezzavano la mesh in
    # mille pezzi): così xatlas fa isole grandi. Ogni triangolo si porta dietro le sue uv vecchie.
    chiave = np.round(pos / 1e-4).astype(np.int64)
    _, saldato, inverso = np.unique(chiave, axis=0, return_index=True, return_inverse=True)
    inverso = inverso.reshape(-1)
    tri_s = inverso[tri]
    buoni = (tri_s[:, 0] != tri_s[:, 1]) & (tri_s[:, 1] != tri_s[:, 2]) & (tri_s[:, 0] != tri_s[:, 2])
    tri, tri_s = tri[buoni], tri_s[buoni]
    uv_angoli = uv_vecchie[tri]  # F x 3 x 2
    pos_s = pos[saldato]
    normali_s = np.zeros_like(pos_s)
    np.add.at(normali_s, inverso, normali)
    normali_s /= np.maximum(np.linalg.norm(normali_s, axis=1, keepdims=True), 1e-9)
    ossa_s, pesi_s = ossa_v[saldato], pesi[saldato]

    # Due atlanti quadrati affiancati (davanti e dietro del cavallo): xatlas impacchetta in quadrati.
    meta = np.median(pos_s[tri_s].mean(1)[:, 2])
    gruppi = [np.where(pos_s[tri_s].mean(1)[:, 2] < meta)[0], np.where(pos_s[tri_s].mean(1)[:, 2] >= meta)[0]]
    quadro = min(larghezza // 2, altezza)
    P, N, OV, PV, UVP, T, UVA = [], [], [], [], [], [], []
    base = 0
    for g, facce in enumerate(gruppi):
        usati_g = np.unique(tri_s[facce])
        indice_g = -np.ones(len(pos_s), dtype=np.int64)
        indice_g[usati_g] = np.arange(len(usati_g))
        atlante = xatlas.Atlas()
        atlante.add_mesh(pos_s[usati_g].astype(np.float32), indice_g[tri_s[facce]].astype(np.uint32),
                         normali_s[usati_g].astype(np.float32))
        opzioni_carte = xatlas.ChartOptions()
        tpu = 200.0
        while True:
            opzioni = xatlas.PackOptions()
            opzioni.padding = 3
            opzioni.bilinear = True
            opzioni.texels_per_unit = tpu
            opzioni.resolution = 0
            atlante.generate(opzioni_carte, opzioni)
            if atlante.width <= quadro and atlante.height <= quadro:
                break
            tpu *= 0.95
        vmap, tri_n, uv_n = atlante[0]
        sorgente_v = usati_g[vmap]
        P.append(pos_s[sorgente_v])
        N.append(normali_s[sorgente_v])
        OV.append(ossa_s[sorgente_v])
        PV.append(pesi_s[sorgente_v])
        UVP.append(uv_n * np.array([atlante.width, atlante.height]) + np.array([g * quadro, 0]))
        T.append(tri_n.astype(np.int64) + base)
        UVA.append(uv_angoli[facce])
        base += len(vmap)
    pos, normali = np.concatenate(P), np.concatenate(N)
    ossa_v, pesi = np.concatenate(OV), np.concatenate(PV)
    uv_px, tri, uv_angoli = np.concatenate(UVP), np.concatenate(T), np.concatenate(UVA)

    luce = _occlusione(pos, normali, tri)
    # Sfumato in altezza: pancia e zampe più scure, dorso pieno.
    y = pos[:, 1]
    alto = np.clip((y - y.min()) / (y.max() - y.min()), 0, 1)
    ombra = np.clip(luce, 0, 1) ** 0.8 * (0.78 + 0.22 * alto) * (0.9 + 0.12 * np.clip(normali[:, 1], -1, 1))
    ombra = np.clip(ombra, 0.38, 1.08)

    sorgente = np.asarray(vecchio["texture"]).astype(np.float32)
    lato_v = sorgente.shape[0]
    img = np.zeros((altezza, larghezza, 3), np.float32)
    pieno = np.zeros((altezza, larghezza), bool)
    for f, (a, b, c) in enumerate(tri):
        P = uv_px[[a, b, c]]
        x0, y0 = np.floor(P.min(0)).astype(int)
        x1, y1 = np.ceil(P.max(0)).astype(int)
        x0, y0 = max(x0, 0), max(y0, 0)
        x1, y1 = min(x1, larghezza - 1), min(y1, altezza - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        v0, v1 = P[1] - P[0], P[2] - P[0]
        den = v0[0] * v1[1] - v1[0] * v0[1]
        if abs(den) < 1e-12:
            continue
        dx, dy = xs - P[0][0], ys - P[0][1]
        l1 = (dx * v1[1] - v1[0] * dy) / den
        l2 = (v0[0] * dy - dx * v0[1]) / den
        l0 = 1 - l1 - l2
        dentro = (l0 >= -0.02) & (l1 >= -0.02) & (l2 >= -0.02)
        if not dentro.any():
            continue
        L = np.stack([l0, l1, l2], -1)[dentro]
        uvv = L @ uv_angoli[f]
        sx = np.clip(uvv[:, 0] * lato_v - 0.5, 0, lato_v - 1)
        sy = np.clip(uvv[:, 1] * lato_v - 0.5, 0, lato_v - 1)
        colore = sorgente[sy.round().astype(int), sx.round().astype(int)]
        o = L @ ombra[[a, b, c]]
        yy = ys[dentro].astype(int)
        xx = xs[dentro].astype(int)
        img[yy, xx] = colore * o[:, None]
        pieno[yy, xx] = True
    # Si allargano i bordi delle isole, per non vedere il nero tra una e l'altra.
    for _ in range(6):
        vuoti = ~pieno
        somma = np.zeros_like(img)
        conta = np.zeros(pieno.shape, np.float32)
        for sx, sy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sp = np.roll(np.roll(pieno, sy, 0), sx, 1)
            si = np.roll(np.roll(img, sy, 0), sx, 1)
            somma += si * sp[..., None]
            conta += sp
        nuovi = vuoti & (conta > 0)
        img[nuovi] = somma[nuovi] / conta[nuovi][:, None]
        pieno |= nuovi
    immagine = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
    dati = {
        "pos": pos, "normali": normali, "triangoli": tri, "uv_px": uv_px,
        "ossa": [nomi[i] for i in range(len(nomi))], "ossa_v": ossa_v, "pesi": pesi,
    }
    return dati, immagine


if __name__ == "__main__":
    import sys
    v = meshdati.leggi(sys.argv[1])
    d, img = cuoci(v, 512, 232)
    img.save("/tmp/claude-0/cavallo_%s.png" % sys.argv[1])
    print(len(d["pos"]), len(d["triangoli"]))
