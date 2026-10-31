"""Texture della lobby per pavimenti e muri, al posto dei materiali di Roblox (Mattia, 1/11/2026: "non mi piacciono
i materiali dei pavimenti né le mura a mattonelle").

Immagini in scala di grigi quasi bianche, ripetibili: il gioco le tinge col colore della parte (Texture.Color3).
  tex_lastre   pavimento a grandi lastre di pietra (2 x 2 per ripetizione), fughe sottili;
  tex_assi     pavimento di assi di legno, giunti sfalsati;
  tex_intonaco muro intonacato liscio, macchie appena accennate.
Scrive in assets/gui (poi tools/carica-immagini.ps1 le carica e mette gli id in ImmaginiId.luau).

Uso: python tools/texture_lobby.py   (con numpy e Pillow)
"""
import os

import numpy as np
from PIL import Image

RADICE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
USCITA = os.path.join(RADICE, "assets", "gui")
N = 512


def rumore(celle, seme):
    """Rumore morbido ripetibile N x N."""
    rng = np.random.default_rng(seme)
    g = rng.random((celle + 1, celle + 1))
    g[-1, :] = g[0, :]
    g[:, -1] = g[:, 0]
    t = np.linspace(0, celle, N, endpoint=False)
    i = t.astype(int)
    f = t - i
    f = f * f * (3 - 2 * f)
    a, b = g[np.ix_(i, i)], g[np.ix_(i, i + 1)]
    c, d = g[np.ix_(i + 1, i)], g[np.ix_(i + 1, i + 1)]
    fx, fy = f[None, :], f[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def salva(nome, valori):
    v = np.clip(valori, 0, 1)
    img = (np.stack([v, v, v], -1) * 255).astype(np.uint8)
    Image.fromarray(img).save(os.path.join(USCITA, nome + ".png"))


def lastre():
    y, x = np.mgrid[0:N, 0:N]
    lato = N // 2
    rng = np.random.default_rng(3)
    tono = rng.uniform(0.86, 0.98, (2, 2))
    v = tono[(y // lato) % 2, (x // lato) % 2]
    v = v + (rumore(6, 1) - 0.5) * 0.08 + (rumore(40, 2) - 0.5) * 0.04
    # Fuga sottile e un filo di luce sul bordo alto/sinistro di ogni lastra.
    dx, dy = x % lato, y % lato
    fuga = (dx < 3) | (dy < 3)
    luce = ((dx >= 3) & (dx < 7)) | ((dy >= 3) & (dy < 7))
    v = np.where(luce, v + 0.04, v)
    v = np.where(fuga, 0.62, v)
    salva("tex_lastre", v)


def assi():
    y, x = np.mgrid[0:N, 0:N]
    alto = N // 6 + 1  # 6 assi per ripetizione (l'ultima un poco più stretta)
    fila = y // alto
    rng = np.random.default_rng(5)
    sfasa = rng.integers(0, N, 8)
    tono = rng.uniform(0.84, 0.98, (8, 3))
    pezzo = ((x + sfasa[fila % 8]) % N) // (N // 2)
    v = tono[fila % 8, pezzo % 3]
    venatura = np.sin((x / N * 2 * np.pi * 3) + rumore(5, 7) * 6 + fila) * 0.025
    v = v + venatura + (rumore(48, 8) - 0.5) * 0.04
    giunto = ((x + sfasa[fila % 8]) % (N // 2)) < 3
    v = np.where((y % alto) < 3, 0.58, v)
    v = np.where(giunto, 0.64, v)
    salva("tex_assi", v)


def intonaco():
    v = 0.93 + (rumore(4, 11) - 0.5) * 0.07 + (rumore(16, 12) - 0.5) * 0.04 + (rumore(64, 13) - 0.5) * 0.025
    salva("tex_intonaco", v)


if __name__ == "__main__":
    lastre()
    assi()
    intonaco()
    print("ok")
