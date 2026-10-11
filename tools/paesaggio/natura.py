"""Alberi, cespugli, erba e rocce dei campi di battaglia come modelli 3D veri (Shared/MeshDati/Natura*).

Ogni modello è in studs alla scala 1 degli oggetti di Server/Paesaggio (stesso ingombro), con l'origine a
terra: il gioco lo copia e lo ridimensiona. Più varianti per tipo, così i boschi non sembrano fotocopie.

Uso: python3 tools/paesaggio/natura.py [nomi ...] [--glb cartella] [--prova]
"""
import math
import os
import sys

import numpy as np
import trimesh

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from base import Modello, Rumore, capsule, curva, da_campo, mescola, ombreggia, rgb, ruota, tubo, unione_morbida  # noqa: E402

R = Rumore(7)
R2 = Rumore(23)


# Colori procedurali ------------------------------------------------------------------------------

def corteccia(base="#5A4936", scuro="#33281F", chiaro=None, solchi=3.0):
    b, s = rgb(base), rgb(scuro)
    c = rgb(chiaro) if chiaro else b * 1.18

    def f(p, n, ao):
        q = p * np.array([solchi, 0.35, solchi])
        solco = np.abs(R.fbm(q, 3))  # solchi verticali
        macchie = R2.fbm(p * 0.8, 2)
        col = mescola(b, s, np.clip(1 - solco * 3.2, 0, 1) * 0.75)
        col = mescola(col, c, np.clip(macchie * 1.5, 0, 1) * 0.5)
        return ombreggia(col, n, ao, 1.1, 0.1)
    return f


def foglie(scuro, medio, chiaro, secco=None, grana=2.2, neve=None):
    s, m, c = rgb(scuro), rgb(medio), rgb(chiaro)
    sec = rgb(secco) if secco else None
    bianco = rgb("#EEF2F6")

    def f(p, n, ao):
        grande = R.fbm(p * 0.09, 3) * 0.5 + 0.5
        col = mescola(s, m, np.clip(grande * 1.4 - 0.1, 0, 1))
        # Ciuffi di foglie: grana fine, più chiara sulle punte esposte.
        fine = R2.fbm(p * grana, 3)
        punte = np.clip(fine * 1.8 + 0.2 * n[:, 1], 0, 1)
        col = mescola(col, c, punte * 0.55)
        col = col * (0.78 + 0.42 * (R.fbm(p * grana * 2.7 + 5, 2) * 0.5 + 0.5))[:, None]
        if sec is not None:
            col = mescola(col, sec, np.clip(R2.fbm(p * 0.25 + 9, 2) * 2 - 0.4, 0, 1) * 0.45)
        col = ombreggia(col, n, ao ** 1.25, 1.3, 0.22)
        if neve is not None:
            copre = np.clip((n[:, 1] - neve) * 4 + R.fbm(p * 1.3, 2) * 1.2, 0, 1)
            col = mescola(col, bianco * (0.75 + 0.25 * ao)[:, None], copre)
        return col
    return f


def pietra(base="#85817A", scuro="#55524D", chiaro="#A9A59C", muschio="#6E7845", vene=1.0, neve=None, sabbia=False):
    b, s, c, mu = rgb(base), rgb(scuro), rgb(chiaro), rgb(muschio)
    bianco = rgb("#EEF2F6")

    def f(p, n, ao):
        strati = R.fbm(p * np.array([0.25, 1.4, 0.25]) * vene, 3)
        col = mescola(b, s, np.clip(strati * 2.0 + 0.3, 0, 1) * 0.6)
        col = mescola(col, c, np.clip(R2.fbm(p * 0.6, 3) * 2, 0, 1) * 0.5)
        col = col * (0.88 + 0.24 * (R.fbm(p * 4.0, 2) * 0.5 + 0.5))[:, None]
        if not sabbia:
            # Muschio e licheni sopra e nelle parti in ombra.
            m = np.clip((n[:, 1] - 0.35) * 2.2, 0, 1) * np.clip(R2.fbm(p * 0.7 + 3, 3) * 2.5 + 0.2, 0, 1)
            col = mescola(col, mu, m * 0.7)
        else:
            polvere = np.clip((n[:, 1] - 0.4) * 2, 0, 1)
            col = mescola(col, rgb("#D2B888"), polvere * 0.45)
        col = ombreggia(col, n, ao, 1.2, 0.08)
        if neve is not None:
            copre = np.clip((n[:, 1] - neve) * 5 + R.fbm(p * 0.9, 2) * 1.5, 0, 1)
            col = mescola(col, bianco * (0.8 + 0.2 * ao)[:, None], copre)
        return col
    return f


def tinta(c):
    col = rgb(c)

    def f(p, n, ao):
        return ombreggia(np.tile(col, (len(p), 1)), n, ao)
    return f


# Pezzi -------------------------------------------------------------------------------------------

def chioma(centri, raggi, k=1.4, rumore=0.75, bozzi=0.35, passo=0.32, bersaglio=2600, schiaccia=1.0, seme=0):
    """Chioma a nuvole: palle fuse insieme, con rumore grande (forma) e piccolo (ciuffi di foglie)."""
    C = np.asarray(centri, float)
    Rr = np.asarray(raggi, float)
    off = np.array([seme * 13.1, seme * 7.7, seme * 3.3])

    def campo(p):
        q = p.copy()
        q[:, 1] = q[:, 1] / schiaccia
        d = [np.linalg.norm(q - c * np.array([1, 1 / schiaccia, 1]), axis=1) - r for c, r in zip(C, Rr)]
        d = unione_morbida(d, k)
        d = d + R.fbm(p * 0.28 + off, 3) * rumore + np.abs(R2.fbm(p * 1.1 + off, 2)) * bozzi * 2 - bozzi * 0.5
        return d
    lo = (C - Rr[:, None]).min(0) - 1.5
    hi = (C + Rr[:, None]).max(0) + 1.5
    return da_campo(campo, lo, hi, passo, bersaglio)


def ramo(rng, da, a, r0, r1, piega=0.6, lati=7, passi=6):
    d = np.asarray(a, float) - np.asarray(da, float)
    lato = np.cross(d, [0, 1, 0])
    if np.linalg.norm(lato) < 1e-6:
        lato = np.array([1.0, 0, 0])
    lato /= np.linalg.norm(lato)
    spinta = lato * rng.normal() * piega + np.array([0, 1, 0]) * abs(rng.normal()) * piega * 0.6
    P = curva(da, a, spinta, passi)
    return tubo(P, np.linspace(r0, r1, passi), lati)


def unisci(meshes):
    return trimesh.util.concatenate(meshes)


# Latifoglie --------------------------------------------------------------------------------------

def chioma_ciuffi(centri, raggi, k=0.6, rumore=0.45, bozzi=0.3, passo=0.28, bersaglio=3200, seme=0):
    """Chioma fatta di tanti ciuffi di foglie (uno per punta di ramo), fusi appena: si vedono i singoli
    ciuffi e qualche buco, come nelle chiome vere."""
    C = np.asarray(centri, float)
    Rr = np.asarray(raggi, float)
    off = np.array([seme * 13.1, seme * 7.7, seme * 3.3])

    def campo(p):
        d = np.full(len(p), 1e3)
        # Unione morbida a coppie, ma solo dove serve (vicino): veloce anche con tanti ciuffi.
        for c, r in zip(C, Rr):
            dc = np.linalg.norm((p - c) * np.array([1, 1.15, 1]), axis=1) - r
            h = np.clip(0.5 + 0.5 * (dc - d) / k, 0, 1)
            d = dc + (d - dc) * h - k * h * (1 - h)
        return d + R.fbm(p * 0.45 + off, 3) * rumore + np.abs(R2.fbm(p * 1.25 + off, 2)) * bozzi * 2 - bozzi * 0.6
    lo = (C - Rr[:, None]).min(0) - 1.2
    hi = (C + Rr[:, None]).max(0) + 1.2
    return da_campo(campo, lo, hi, passo, bersaglio)


def rami(rng, da, verso, lungo, raggio, livelli, legno, punte, apertura=(0.45, 0.85), su=0.35, figli=(2, 3), accorcia=0.68,
         lati=7):
    """Ramo da "da" lungo "verso"; poi figli più corti e sottili, fino alle punte (dove andranno le foglie)."""
    verso = np.asarray(verso, float)
    verso = verso / np.linalg.norm(verso)
    fine = np.asarray(da, float) + verso * lungo
    lato = np.cross(verso, [0, 1, 0])
    if np.linalg.norm(lato) < 1e-6:
        lato = np.array([1.0, 0, 0])
    lato /= np.linalg.norm(lato)
    piega = lato * rng.normal() * lungo * 0.12 + np.array([0, 1, 0]) * lungo * 0.06
    legno.append(tubo(curva(da, fine, piega, 5), np.linspace(raggio, raggio * 0.62, 5), lati))
    if livelli == 0:
        punte.append((fine, lungo))
        return
    n = rng.integers(figli[0], figli[1] + 1)
    giro = rng.uniform(0, 2 * math.pi)
    for i in range(n):
        asse = ruota(lato, verso, giro + i * 2 * math.pi / n)
        d = ruota(verso, asse, rng.uniform(*apertura))
        d = d + np.array([0, su, 0])
        partenza = fine if i > 0 else np.asarray(da, float) + verso * lungo * rng.uniform(0.55, 0.8)
        rami(rng, partenza, d, lungo * accorcia * rng.uniform(0.85, 1.15), raggio * 0.6, livelli - 1, legno, punte,
             apertura, su, figli, accorcia, max(4, lati - 1))


def radici(rng, legno, n=5, raggio=0.55, largo=2.2):
    for k in range(n):
        a = k * 2 * math.pi / n + rng.uniform(-0.3, 0.3)
        d = np.array([math.cos(a), 0, math.sin(a)])
        legno.append(tubo(curva([0, 1.3, 0], d * largo * rng.uniform(0.8, 1.1) + [0, -0.5, 0], [0, -0.2, 0], 5),
                          np.linspace(raggio, 0.1, 5), 6))


def quercia(nome, seme):
    """Quercia: tronco robusto con le radici, grossi rami aperti, chioma larga fatta di ciuffi."""
    rng = np.random.default_rng(seme)
    m = Modello(nome, 256)
    alto = rng.uniform(5.0, 6.0)
    cima = np.array([rng.uniform(-0.5, 0.5), alto, rng.uniform(-0.5, 0.5)])
    legno, punte = [tubo(curva([0, -1, 0], cima, [rng.uniform(-0.4, 0.4), 0, rng.uniform(-0.4, 0.4)], 7), np.linspace(1.0, 0.75, 7), 10)], []
    radici(rng, legno)
    n = rng.integers(4, 6)
    for k in range(n):
        a = k * 2 * math.pi / n + rng.uniform(-0.35, 0.35)
        d = np.array([math.cos(a), rng.uniform(0.7, 1.1), math.sin(a)])
        rami(rng, cima * rng.uniform(0.8, 1.0), d, rng.uniform(4.0, 5.2), 0.55, 2, legno, punte, (0.4, 0.8), 0.25)
    rami(rng, cima, [0, 1, 0], 4.0, 0.5, 2, legno, punte, (0.5, 0.9), 0.2)
    centri = [p + np.array([0, 0.9, 0]) for p, _ in punte]
    raggi = [rng.uniform(1.6, 2.2) for _ in punte]
    m.aggiungi(unisci(legno), corteccia("#5C4A38", "#2F261E"), 75)
    m.aggiungi(chioma_ciuffi(centri, raggi, k=0.9, bozzi=0.4, bersaglio=3000, seme=seme), foglie("#34491F", "#516E2C", "#86A04A", "#8C8A3C"), 180)
    return m


def betulla(nome, seme):
    """Betulla: tronco sottile bianco con le macchie nere, rami all'insù, chioma alta e leggera."""
    rng = np.random.default_rng(seme)
    m = Modello(nome, 256)
    alto = rng.uniform(11, 13)
    cima = np.array([rng.uniform(-0.7, 0.7), alto, rng.uniform(-0.7, 0.7)])
    legno, punte = [tubo(curva([0, -1, 0], cima, [rng.uniform(-0.5, 0.5), 0, rng.uniform(-0.5, 0.5)], 9), np.linspace(0.5, 0.14, 9), 8)], []
    for k in range(7):
        t = rng.uniform(0.35, 0.85)
        da = np.array([0, -1, 0]) + (cima - [0, -1, 0]) * t
        a = rng.uniform(0, 2 * math.pi)
        rami(rng, da, [math.cos(a), 1.3, math.sin(a)], rng.uniform(2.2, 3.0), 0.16, 1, legno, punte, (0.3, 0.6), 0.5, (2, 2))
    punte.append((cima, 1))
    centri = [p + np.array([0, 0.5, 0]) for p, _ in punte]
    raggi = [rng.uniform(1.15, 1.55) for _ in punte]
    bianco, nero = rgb("#E4E1D8"), rgb("#2A2826")

    def corteccia_betulla(p, n, ao):
        macchie = R.fbm(p * np.array([1.8, 5.0, 1.8]), 2)
        col = mescola(np.tile(bianco, (len(p), 1)), nero, np.clip((macchie - 0.25) * 6, 0, 1))
        col = col * (0.9 + 0.1 * R2.fbm(p * 6, 2))[:, None]
        piede_scuro = np.clip(1 - (p[:, 1] + 1) / 2.5, 0, 1)
        col = mescola(col, rgb("#3E3A34"), piede_scuro * 0.7)
        return ombreggia(col, n, ao, 1.0, 0.1)
    m.aggiungi(unisci(legno), corteccia_betulla, 75)
    m.aggiungi(chioma_ciuffi(centri, raggi, k=0.7, rumore=0.35, passo=0.24, bersaglio=2400, seme=seme),
               foglie("#4B6A26", "#6E8F33", "#A3B955"), 180)
    return m


def cipresso(nome, seme):
    """Cipresso mediterraneo: colonna stretta e alta, a punta, fitta."""
    rng = np.random.default_rng(seme)
    m = Modello(nome, 256)
    alto = rng.uniform(17, 20)
    m.aggiungi(tubo(curva([0, -1, 0], [0, 3, 0], [0, 0, 0], 3), [0.45, 0.4, 0.35], 7), corteccia("#5A4532", "#2E2219"), 75)

    def campo(p):
        y = p[:, 1]
        t = np.clip((y - 1.0) / (alto - 1.0), 0, 1)
        r = 2.2 * np.sin(np.clip(t, 0, 1) ** 0.55 * math.pi) ** 0.9 * (1 - 0.35 * t) + 0.05
        d = np.hypot(p[:, 0], p[:, 2]) - r
        d = np.maximum(d, np.maximum(1.2 - y, y - alto))
        return d + R.fbm(p * np.array([0.6, 0.25, 0.6]) + seme, 3) * 0.45 + np.abs(R2.fbm(p * 1.4 + seme, 2)) * 0.5 - 0.1
    m.aggiungi(da_campo(campo, [-3, 0, -3], [3, alto + 1, 3], 0.3, 2200), foglie("#1F3A22", "#2E5230", "#4D7342", grana=2.6), 180)
    return m


def ulivo(nome, seme):
    """Ulivo: tronco basso, nodoso e contorto, rami aperti, chioma grigio-verde a ciuffi radi."""
    rng = np.random.default_rng(seme)
    m = Modello(nome, 256)
    legno, punte = [], []
    biforca = np.array([rng.uniform(-0.8, 0.8), 2.6, rng.uniform(-0.8, 0.8)])
    # Tronco fatto di due-tre fusti attorcigliati.
    for k in range(3):
        a = k * 2.1 + rng.uniform(0, 1)
        off = np.array([math.cos(a), 0, math.sin(a)]) * 0.35
        P = curva(np.array([0, -0.8, 0]) + off * 1.6, biforca + off, [rng.normal() * 0.6, 0, rng.normal() * 0.6], 7)
        legno.append(tubo(P, np.linspace(0.7, 0.42, 7), 8))
    for k in range(4):
        a = k * 1.57 + rng.uniform(-0.3, 0.3)
        rami(rng, biforca, [math.cos(a), 0.9, math.sin(a)], rng.uniform(1.7, 2.2), 0.32, 2, legno, punte, (0.4, 0.9), 0.15, (2, 2))
    centri = [p + np.array([0, 0.4, 0]) for p, _ in punte]
    raggi = [rng.uniform(0.85, 1.15) for _ in punte]
    m.aggiungi(unisci(legno), corteccia("#6E6152", "#3C342C", "#8E8270", solchi=1.6), 75)
    m.aggiungi(chioma_ciuffi(centri, raggi, k=0.5, rumore=0.25, bozzi=0.3, passo=0.17, bersaglio=2200, seme=seme),
               foglie("#4E5A3E", "#6F7C58", "#A4AC8A", grana=3.2), 180)
    return m


def tamerice(nome, seme):
    """Tamerice: arbusto alto a più fusti, chioma piumosa grigio-verde."""
    rng = np.random.default_rng(seme)
    m = Modello(nome, 256)
    legno, centri, raggi = [], [], []
    for k in range(4):
        a = k * 1.6 + rng.uniform(0, 0.8)
        d = np.array([math.cos(a), 0, math.sin(a)])
        fine = d * rng.uniform(1.2, 2.0) + [0, rng.uniform(3.8, 5.0), 0]
        legno.append(ramo(rng, [0, -0.5, 0], fine, 0.3, 0.1, 0.5, 6, 5))
        centri.append(fine + [0, 0.6, 0])
        raggi.append(rng.uniform(1.4, 1.9))
    m.aggiungi(unisci(legno), corteccia("#6B5546", "#3A2C24", solchi=2), 75)
    m.aggiungi(chioma(centri, raggi, k=1.0, rumore=0.5, bozzi=0.5, schiaccia=1.2, bersaglio=1400, passo=0.25, seme=seme),
               foglie("#5B6248", "#848A68", "#B4B48C", grana=3.2), 180)
    return m


def palma(nome, seme):
    """Palma da dattero: tronco ad anelli un po' curvo, ciuffo di fronde arcuate e i grappoli."""
    rng = np.random.default_rng(seme)
    m = Modello(nome, 256)
    alto = rng.uniform(12.5, 14)
    piega = np.array([rng.uniform(1.0, 2.2), 0, rng.uniform(-0.6, 0.6)])
    t = np.linspace(0, 1, 14)[:, None]
    P = np.array([0, -1, 0]) + np.array([0, alto + 1, 0]) * t + piega * t * t
    raggi = 0.62 - 0.14 * t[:, 0] + 0.12 * np.exp(-t[:, 0] * 12)
    tronco = tubo(P, raggi, 10)
    anello, sc = rgb("#7E6648"), rgb("#4E3E2C")

    def corteccia_palma(p, n, ao):
        anelli = np.abs(np.sin(p[:, 1] * 3.4 + R.fbm(p * 0.8, 2) * 2))
        col = mescola(np.tile(anello, (len(p), 1)), sc, (anelli ** 4) * 0.8)
        col = col * (0.9 + 0.2 * R2.fbm(p * np.array([4, 1, 4]), 2))[:, None]
        return ombreggia(col, n, ao, 1.0, 0.1)
    m.aggiungi(tronco, corteccia_palma, 60)
    cima = P[-1]
    fronde = []
    n = 13
    for k in range(n):
        a = k * 2 * math.pi / n + rng.uniform(-0.15, 0.15)
        d = np.array([math.cos(a), 0, math.sin(a)])
        su = rng.uniform(0.3, 1.0)
        lungo = rng.uniform(6.0, 7.5)
        punti = 9
        s = np.linspace(0, 1, punti)
        asse = cima + d[None] * (s[:, None] * lungo) + np.array([0, 1, 0]) * (su * 3 * s - 4.2 * s * s)[:, None]
        larghezza = 1.15 * np.sin(np.clip(s, 0.05, 1) * math.pi) ** 0.6 + 0.05
        lato = np.cross(d, [0, 1, 0])
        # Fronda: striscia piegata a V (le foglioline scendono ai lati), doppia faccia.
        vert, facce = [], []
        for i in range(punti):
            centro = asse[i]
            vert.append(centro + np.array([0, 0.08, 0]))
            vert.append(centro + lato * larghezza[i] + np.array([0, -0.45 * larghezza[i], 0]))
            vert.append(centro - lato * larghezza[i] + np.array([0, -0.45 * larghezza[i], 0]))
        for i in range(punti - 1):
            a0, a1 = i * 3, (i + 1) * 3
            for (x, y) in ((0, 1), (2, 0)):
                facce += [[a0 + x, a1 + x, a0 + y], [a0 + y, a1 + x, a1 + y]]
        V, Fc = np.array(vert), np.array(facce)
        fronde.append(trimesh.Trimesh(V, Fc, process=False))
        fronde.append(trimesh.Trimesh(V, Fc[:, ::-1], process=False))
    m.aggiungi(unisci(fronde), foglie("#3D5524", "#5F7A30", "#94A84E", "#A28E4C", grana=3.0), 50)
    datteri = []
    for k in range(4):
        a = k * 1.57 + 0.4
        c = cima + np.array([math.cos(a) * 0.7, -0.9, math.sin(a) * 0.7])
        datteri.append(trimesh.creation.icosphere(2, 0.55).apply_translation(c))
    m.aggiungi(unisci(datteri), lambda p, n, ao: ombreggia(mescola(np.tile(rgb("#B06A28"), (len(p), 1)), rgb("#7A3E18"), np.clip(R.fbm(p * 5, 2) + 0.5, 0, 1)), n, ao), 180)
    return m


# Conifere ----------------------------------------------------------------------------------------

def pino(nome, seme, neve=False):
    """Abete: tronco dritto e palchi di rami a raggiera che scendono, sempre più corti verso la punta."""
    rng = np.random.default_rng(seme)
    m = Modello(nome, 256)
    alto = rng.uniform(13, 15.5)
    m.aggiungi(tubo(curva([0, -1, 0], [0, alto * 0.8, 0], [0, 0, 0], 4), np.linspace(0.6, 0.18, 4), 8), corteccia("#5A3E2A", "#2C1F17"), 75)
    fronde = []
    palchi = 9
    for i in range(palchi):
        t = i / (palchi - 1)
        h = 2.4 + (alto - 3.6) * t
        lungo = (4.4 - 3.4 * t) * rng.uniform(0.9, 1.1)
        n = 12 if t < 0.6 else 9
        giro = rng.uniform(0, 2 * math.pi)
        for k in range(n):
            a = giro + k * 2 * math.pi / n + rng.uniform(-0.15, 0.15)
            d = np.array([math.cos(a), 0, math.sin(a)])
            l = lungo * rng.uniform(0.85, 1.1)
            fine = np.array([0, h, 0]) + d * l + np.array([0, -l * rng.uniform(0.35, 0.5), 0])
            fronde.append((np.array([0, h + 0.3, 0]), fine, 1.0 - 0.35 * t, 0.2))
    cima = (np.array([0, alto - 1.6, 0]), np.array([0, alto + 0.8, 0]), 0.75, 0.05)
    fronde.append(cima)

    def campo(p):
        d = np.full(len(p), 1e3)
        k = 0.35
        for a, b, ra, rb in fronde:
            dc = capsule(p, a, b, ra, rb, 1.6)
            h = np.clip(0.5 + 0.5 * (dc - d) / k, 0, 1)
            d = dc + (d - dc) * h - k * h * (1 - h)
        return d + R.fbm(p * 0.8 + seme, 2) * 0.18 + np.abs(R2.fbm(p * 2.2 + seme, 2)) * 0.22 - 0.02
    m.aggiungi(da_campo(campo, [-5.5, 0.0, -5.5], [5.5, alto + 1.5, 5.5], 0.2, 3400),
               foglie("#1A3324", "#294A33", "#4A6B48", grana=2.8, neve=0.25 if neve else None), 180)
    return m


# Bassi -------------------------------------------------------------------------------------------

def cespuglio(nome, seme, colori=("#2F4A1F", "#4A6A2B", "#7A9744"), neve=False, secco=None):
    """Cespuglio: tanti ciuffi bassi fusi insieme, più alto in mezzo."""
    rng = np.random.default_rng(seme)
    m = Modello(nome, 128)
    centri, raggi = [], []
    for k in range(rng.integers(7, 10)):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0.2, 1.6)
        r = rng.uniform(0.65, 1.05) * (1.15 - d * 0.2)
        centri.append([math.cos(a) * d, r * 0.6 + (1.6 - d) * 0.35, math.sin(a) * d])
        raggi.append(r)
    mesh = chioma_ciuffi(centri, raggi, k=0.35, rumore=0.25, bozzi=0.2, passo=0.15, bersaglio=1300, seme=seme)
    m.aggiungi(mesh, foglie(*colori, secco=secco, grana=3.4, neve=0.3 if neve else None), 180)
    return m


def arbusto(nome, seme):
    """Arbusto secco del deserto: rametti chiari a raggiera e un cuscino di foglie grigie."""
    rng = np.random.default_rng(seme)
    m = Modello(nome, 128)
    rami = []
    for k in range(10):
        a = rng.uniform(0, 2 * math.pi)
        fine = np.array([math.cos(a) * 1.5, rng.uniform(0.9, 2.0), math.sin(a) * 1.5])
        rami.append(ramo(rng, [0, -0.2, 0], fine, 0.09, 0.03, 0.3, 4, 4))
    m.aggiungi(unisci(rami), corteccia("#9A8264", "#5E4C38", solchi=4), 75)
    m.aggiungi(chioma([[0, 0.8, 0], [0.6, 0.7, 0.3], [-0.5, 0.75, -0.3]], [0.9, 0.7, 0.75], k=0.6, rumore=0.25, bozzi=0.35,
                      passo=0.14, bersaglio=700, schiaccia=0.7, seme=seme), foglie("#6E6A48", "#948C62", "#C2B88A", grana=4), 180)
    return m


def ciuffo(nome, seme, colori=("#4C6A2C", "#6E8E3A", "#A2B65A")):
    """Ciuffo d'erba: lame strette e curve che si aprono a ventaglio (doppia faccia)."""
    rng = np.random.default_rng(seme)
    m = Modello(nome, 128)
    lame = []
    for k in range(18):
        a = rng.uniform(0, 2 * math.pi)
        d = np.array([math.cos(a), 0, math.sin(a)])
        alto = rng.uniform(1.0, 2.2)
        apre = rng.uniform(0.3, 1.0)
        base = d * rng.uniform(0, 0.35)
        s = np.linspace(0, 1, 4)
        asse = base[None] + d[None] * (apre * s * s)[:, None] + np.array([0, 1, 0]) * (alto * s - 0.15)[:, None]
        largo = 0.09 * (1 - s) + 0.01
        lato = np.cross(d, [0, 1, 0])
        V = np.concatenate([asse + lato * largo[:, None], asse - lato * largo[:, None]])
        F = []
        for i in range(3):
            F += [[i, i + 4, i + 1], [i + 1, i + 4, i + 5]]
        F = np.array(F)
        lame.append(trimesh.Trimesh(V, F, process=False))
        lame.append(trimesh.Trimesh(V, F[:, ::-1], process=False))
    s, md, c = (rgb(x) for x in colori)

    def colore(p, n, ao):
        t = np.clip(p[:, 1] / 2.0, 0, 1)
        col = mescola(mescola(np.tile(s, (len(p), 1)), md, np.clip(t * 2, 0, 1)), c, np.clip(t * 2 - 1, 0, 1))
        return col * (0.85 + 0.3 * (R.fbm(p * 3, 2) * 0.5 + 0.5))[:, None]
    m.aggiungi(unisci(lame), colore, 50)
    return m


# Legno a terra -----------------------------------------------------------------------------------

def tronco(nome, seme):
    """Tronco caduto, con i monconi dei rami e il taglio chiaro."""
    rng = np.random.default_rng(seme)
    m = Modello(nome, 128)
    P = curva([-5, 0.6, 0], [5, 0.7, 0], [0, 0.2, rng.uniform(-0.6, 0.6)], 8)
    legno = [tubo(P, np.linspace(0.85, 0.7, 8), 10, chiudi_fine=False)]
    legno.append(ramo(rng, [-2.5, 0.9, 0], [-3.5, 2.6, 1.0], 0.28, 0.1, 0.2, 6, 4))
    legno.append(ramo(rng, [1.5, 1.0, 0], [2.3, 1.6, -1.6], 0.22, 0.08, 0.2, 6, 4))
    m.aggiungi(unisci(legno), corteccia("#55432F", "#2D241A"), 75)
    taglio = trimesh.creation.cylinder(0.72, 0.05, 16)
    taglio.apply_transform(trimesh.transformations.rotation_matrix(math.pi / 2, [0, 0, 1]))
    taglio.apply_translation(P[-1])
    m.aggiungi(taglio, lambda p, n, ao: ombreggia(mescola(np.tile(rgb("#C2A274"), (len(p), 1)), rgb("#8A6A44"),
               np.abs(np.sin(np.hypot(p[:, 1] - P[-1][1], p[:, 2] - P[-1][2]) * 18)) * 0.5), n, ao), 30)
    return m


def ceppo(nome, seme):
    rng = np.random.default_rng(seme)
    m = Modello(nome, 128)
    m.aggiungi(tubo(curva([0, -0.6, 0], [0, 1.2, 0], [0, 0, 0], 4), [0.95, 0.85, 0.8, 0.78], 12, chiudi_fine=False), corteccia("#55432F", "#2D241A"), 75)
    for k in range(4):
        a = k * 1.57 + rng.uniform(-0.3, 0.3)
        d = np.array([math.cos(a), 0, math.sin(a)])
        m.aggiungi(tubo(curva([0, 0.4, 0], d * 1.7 + [0, -0.4, 0], [0, -0.1, 0], 4), np.linspace(0.4, 0.1, 4), 6), corteccia("#55432F", "#2D241A"), 75)
    taglio = trimesh.creation.cylinder(0.78, 0.06, 16)
    taglio.apply_translation([0, 1.2, 0])
    m.aggiungi(taglio, lambda p, n, ao: ombreggia(mescola(np.tile(rgb("#B8966A"), (len(p), 1)), rgb("#7E5E3C"),
               np.abs(np.sin(np.hypot(p[:, 0], p[:, 2]) * 16)) * 0.45), n, ao), 30)
    return m


def albero_spezzato(nome, seme):
    """Albero spezzato e bruciato dalle cannonate: tronco nudo, punta scheggiata, monconi."""
    rng = np.random.default_rng(seme)
    m = Modello(nome, 128)
    alto = rng.uniform(6, 9)
    cima = np.array([rng.uniform(-0.5, 0.5), alto, rng.uniform(-0.5, 0.5)])
    legno = [tubo(curva([0, -0.8, 0], cima, [rng.uniform(-0.4, 0.4), 0, rng.uniform(-0.4, 0.4)], 7), np.linspace(0.7, 0.45, 7), 9, chiudi_fine=False)]
    # Schegge sulla rottura.
    for k in range(5):
        a = k * 1.25 + rng.uniform(0, 0.5)
        d = np.array([math.cos(a), 0, math.sin(a)]) * 0.3
        legno.append(tubo(curva(cima - [0, 0.4, 0] + d, cima + d * 1.2 + [0, rng.uniform(0.6, 1.6), 0], [0, 0, 0], 3), [0.16, 0.1, 0.02], 4))
    for k in range(rng.integers(2, 4)):
        da = cima * rng.uniform(0.45, 0.85)
        a = rng.uniform(0, 2 * math.pi)
        legno.append(ramo(rng, da, da + np.array([math.cos(a) * 1.8, rng.uniform(0.6, 1.4), math.sin(a) * 1.8]), 0.2, 0.06, 0.3, 5, 4))
    m.aggiungi(unisci(legno), corteccia("#3E3530", "#1C1816", "#5C5048"), 75)
    return m


# Rocce -------------------------------------------------------------------------------------------

def roccia(nome, seme, misura=(3.0, 2.0, 2.6), tagli=7, passo=0.2, bersaglio=1600, colore=None, lato=256, affonda=0.3):
    """Roccia: ellissoide tagliato da piani (le facce) e scavato dal rumore (crepe e spigoli consumati)."""
    rng = np.random.default_rng(seme)
    m = Modello(nome, lato)
    a = np.array(misura, float)
    piani = []
    for k in range(tagli):
        n = rng.normal(size=3)
        n[1] = abs(n[1]) * 0.8 if k % 2 == 0 else n[1]
        n /= np.linalg.norm(n)
        piani.append((n, rng.uniform(0.62, 0.85) * np.abs(n * a).sum() / np.linalg.norm(n) / 1.6))
    off = np.array([seme * 3.1, 0, seme * 1.7])

    def campo(p):
        q = p / a
        d = (np.linalg.norm(q, axis=1) - 1) * a.min()
        for n, dist in piani:
            d = np.maximum(d, p @ n - dist)
        d = d + R.fbm(p * 0.45 + off, 4) * a.min() * 0.18 + np.abs(R2.fbm(p * 1.3 + off, 3)) * a.min() * 0.06
        return d
    mesh = da_campo(campo, -a * 1.2, a * 1.2, passo * a.min() / 2.0, bersaglio)
    mesh.apply_translation([0, a[1] * (1 - affonda) - 0.1, 0])
    m.aggiungi(mesh, colore or pietra(), 50)
    return m


def gruppo_rocce(nome, seme, colore=None):
    """Tre-quattro rocce vicine, come in P.roccia (una grande e qualche pezzo staccato)."""
    rng = np.random.default_rng(seme)
    m = Modello(nome, 256)
    for k in range(4):
        d = rng.uniform(2.2, 3.6) / (k + 1) ** 0.45
        r = roccia("_", seme * 10 + k, (d * rng.uniform(1.0, 1.4), d * 0.75, d * rng.uniform(0.9, 1.2)), passo=0.22,
                   bersaglio=1400 // (k + 1) + 300)
        mesh = r.parti[0][0]
        a = rng.uniform(0, 2 * math.pi)
        dist = 0 if k == 0 else rng.uniform(1.6, 3.0)
        mesh.apply_transform(trimesh.transformations.rotation_matrix(rng.uniform(0, 2 * math.pi), [0, 1, 0]))
        mesh.apply_translation([math.cos(a) * dist, 0, math.sin(a) * dist])
        m.aggiungi(mesh, colore or pietra(), 50)
    return m


def sassi(nome, seme, colore=None):
    rng = np.random.default_rng(seme)
    m = Modello(nome, 128)
    for k in range(6):
        d = rng.uniform(0.5, 1.2)
        r = roccia("_", seme * 10 + k, (d * rng.uniform(1.0, 1.5), d * 0.6, d), tagli=5, passo=0.25, bersaglio=160, affonda=0.4)
        mesh = r.parti[0][0]
        a = rng.uniform(0, 2 * math.pi)
        dist = rng.uniform(0, 2.0)
        mesh.apply_translation([math.cos(a) * dist, 0, math.sin(a) * dist])
        m.aggiungi(mesh, colore or pietra(), 50)
    return m


# Elenco ------------------------------------------------------------------------------------------

SABBIA = dict(base="#B79A72", scuro="#8C7052", chiaro="#D2BA90", sabbia=True)

MODELLI = {
    "NaturaQuercia1": lambda n: quercia(n, 1),
    "NaturaQuercia2": lambda n: quercia(n, 2),
    "NaturaQuercia3": lambda n: quercia(n, 3),
    "NaturaBetulla1": lambda n: betulla(n, 4),
    "NaturaBetulla2": lambda n: betulla(n, 5),
    "NaturaCipresso1": lambda n: cipresso(n, 6),
    "NaturaUlivo1": lambda n: ulivo(n, 7),
    "NaturaUlivo2": lambda n: ulivo(n, 8),
    "NaturaTamerice1": lambda n: tamerice(n, 9),
    "NaturaPalma1": lambda n: palma(n, 10),
    "NaturaPalma2": lambda n: palma(n, 11),
    "NaturaPino1": lambda n: pino(n, 12),
    "NaturaPino2": lambda n: pino(n, 13),
    "NaturaPinoNeve1": lambda n: pino(n, 14, neve=True),
    "NaturaPinoNeve2": lambda n: pino(n, 15, neve=True),
    "NaturaCespuglio1": lambda n: cespuglio(n, 16),
    "NaturaCespuglio2": lambda n: cespuglio(n, 17, ("#37502A", "#56743A", "#8AA354")),
    "NaturaCespuglioNeve1": lambda n: cespuglio(n, 18, ("#3A4A30", "#5A6A44", "#80906A"), neve=True),
    "NaturaArbusto1": lambda n: arbusto(n, 19),
    "NaturaCiuffo1": lambda n: ciuffo(n, 20),
    "NaturaCiuffoSecco1": lambda n: ciuffo(n, 21, ("#8A7A4A", "#B49E64", "#D8C690")),
    "NaturaCiuffoNeve1": lambda n: ciuffo(n, 22, ("#6E7258", "#90927A", "#B8BAA8")),
    "NaturaTronco1": lambda n: tronco(n, 23),
    "NaturaCeppo1": lambda n: ceppo(n, 24),
    "NaturaSpezzato1": lambda n: albero_spezzato(n, 25),
    "NaturaSpezzato2": lambda n: albero_spezzato(n, 26),
    "NaturaRoccia1": lambda n: gruppo_rocce(n, 27),
    "NaturaRoccia2": lambda n: gruppo_rocce(n, 28),
    "NaturaRocciaSabbia1": lambda n: gruppo_rocce(n, 29, pietra(**SABBIA)),
    "NaturaRocciaNeve1": lambda n: gruppo_rocce(n, 30, pietra(neve=0.35)),
    "NaturaMasso1": lambda n: roccia(n, 31, (8.5, 5.5, 7.0), tagli=9, bersaglio=2400, lato=256, affonda=0.35),
    "NaturaMassoSabbia1": lambda n: roccia(n, 32, (8.5, 5.0, 7.0), tagli=9, bersaglio=2400, lato=512, colore=pietra(**SABBIA), affonda=0.35),
    "NaturaMassoNeve1": lambda n: roccia(n, 33, (8.5, 5.5, 7.0), tagli=9, bersaglio=2400, lato=512, colore=pietra(neve=0.3), affonda=0.35),
    "NaturaSassi1": lambda n: sassi(n, 34),
    "NaturaSassiSabbia1": lambda n: sassi(n, 35, pietra(**SABBIA)),
}


def main():
    nomi = [a for a in sys.argv[1:] if not a.startswith("--") and (sys.argv.index(a) == 0 or sys.argv[sys.argv.index(a) - 1] != "--glb")]
    glb = sys.argv[sys.argv.index("--glb") + 1] if "--glb" in sys.argv else None
    prova = "--prova" in sys.argv
    for nome in nomi or MODELLI:
        m = MODELLI[nome](nome)
        m.cuoci()
        if prova:
            import meshdati
            os.makedirs(glb, exist_ok=True)
            meshdati.glb(m.dati, os.path.join(glb, nome + ".glb"))
            print(nome, len(m.dati["pos"]), "vertici", len(m.dati["triangoli"]), "triangoli", flush=True)
        else:
            m.scrivi("paesaggio, tools/paesaggio/natura.py", glb)


if __name__ == "__main__":
    main()
