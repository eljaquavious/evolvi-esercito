"""Icone delle carte delle truppe nuove: varianti ricolorate delle icone disegnate (assets/gui/card_*.png).

Per ogni truppa: l'icona di partenza e i colori nuovi. Si ruota la tinta dei colori vivi (il contorno scuro, i
bianchi e, se richiesto, gli ori restano come sono), poi si scalano saturazione e luminosità.
Il nome del file segue Icone.carta: "card_" + nome inglese in minuscolo, senza punteggiatura, spazi -> "_".

Uso: python tools/icone_varianti.py      (poi .\\tools\\carica-immagini.ps1 -UserId 2310327136)
"""
import os
import re

import numpy as np
from PIL import Image

RADICE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GUI = os.path.join(RADICE, "assets", "gui")

# nome della carta -> (icona di partenza, rotazione della tinta in gradi, saturazione x, luminosità x)
VARIANTI = {
    # Antichità
    "Spartan Hoplites": ("saxon_huscarls", 160, 1.1, 0.85),
    "Persian Immortals": ("roman_legionaries", -60, 1.0, 0.9),
    "Persian Archers": ("english_longbowmen", -70, 1.0, 1.0),
    "Persian Cavalry": ("companion_cavalry", 0, 0.9, 0.75),
    "Libyan Spearmen": ("saxon_huscarls", 150, 0.9, 1.0),
    "Balearic Slingers": ("cretan_archers", 0, 0.5, 0.9),
    "Numidian Cavalry": ("companion_cavalry", 0, 0.6, 0.5),
    "War Elephants": ("hannibal_barca", 0, 1.0, 0.95),
    "Gallic Warriors": ("saxon_huscarls", -95, 0.9, 0.85),
    "Gallic Archers": ("english_longbowmen", 100, 0.9, 0.9),
    "Gallic Horsemen": ("companion_cavalry", 0, 0.25, 0.85),
    "Germanic Cavalry": ("companion_cavalry", 0, 0.45, 0.42),
    # Medioevo
    "Umayyad Spearmen": ("saxon_huscarls", -70, 0.8, 0.9),
    "Arab Archers": ("cretan_archers", 120, 0.7, 1.0),
    "Arab Cavalry": ("companion_cavalry", 0, 0.3, 1.3),
    "Norman Spearmen": ("saxon_huscarls", 140, 1.0, 0.9),
    "Norman Archers": ("english_longbowmen", 0, 0.6, 0.85),
    "French Knights": ("companion_cavalry", 0, 0.8, 0.65),
    "Ayyubid Spearmen": ("saxon_huscarls", -170, 1.0, 1.0),
    "Ayyubid Archers": ("cretan_archers", 15, 1.0, 1.0),
    "Mamluk Lancers": ("companion_cavalry", 8, 1.1, 1.1),
    "Teutonic Sergeants": ("norman_knights", 0, 0.1, 0.8),
    "Teutonic Crossbowmen": ("cretan_archers", 0, 0.15, 0.85),
    "Teutonic Knights": ("companion_cavalry", 0, 0.1, 1.35),
    "French Men-at-Arms": ("norman_knights", 0, 0.6, 1.0),
    "Genoese Crossbowmen": ("cretan_archers", -30, 0.9, 1.0),
    "Saladin": ("william_the_conqueror", 100, 1.0, 0.9),
    # Età della polvere da sparo
    "Swedish Pikemen": ("norman_knights", 0, 0.9, 1.0),
    "Swedish Musketeers": ("french_poilus", 0, 1.3, 0.95),
    "Swedish Cuirassiers": ("companion_cavalry", 0, 0.4, 0.7),
    "Gustavus Adolphus": ("william_the_conqueror", 180, 1.0, 1.0),
    "Janissaries": ("french_poilus", 145, 1.2, 1.0),
    "Ottoman Bombard": ("machine_gun_crew", -55, 1.1, 1.1),
    "Sipahi Cavalry": ("companion_cavalry", -15, 1.0, 0.8),
    "French Line Infantry": ("french_poilus", 10, 1.3, 0.7),
    "French Artillery": ("machine_gun_crew", 0, 0.8, 0.9),
    "French Cuirassiers": ("companion_cavalry", 0, 0.2, 0.9),
    "Napoleon Bonaparte": ("william_the_conqueror", -120, 0.9, 0.85),
    # Novecento
    "Ottoman Infantry": ("french_poilus", -170, 0.5, 0.85),
    "Ottoman Machine Gunners": ("machine_gun_crew", -45, 0.5, 0.95),
    "German Stormtroopers": ("french_poilus", 0, 0.2, 0.7),
    "German Machine Gunners": ("machine_gun_crew", 0, 0.25, 0.8),
    "British Tommies": ("french_poilus", -145, 0.6, 0.75),
    "Mark V Tank": ("sherman_tank", -25, 0.6, 0.95),
    "Soviet Riflemen": ("french_poilus", -185, 0.55, 0.65),
    "Soviet Machine Gunners": ("machine_gun_crew", -60, 0.5, 0.75),
    "T-34 Tank": ("sherman_tank", 0, 1.0, 0.75),
    "German Grenadiers": ("french_poilus", 0, 0.25, 0.6),
    "MG 42 Team": ("machine_gun_crew", 0, 0.15, 0.7),
    "Panzer IV": ("sherman_tank", -35, 0.45, 1.05),
    "Free French Infantry": ("french_poilus", -140, 0.7, 0.8),
    "Erwin Rommel": ("ferdinand_foch", 0, 0.15, 0.7),
    # Era moderna
    "US Marines": ("french_poilus", -40, 0.55, 0.7),
    "M60 Gun Team": ("machine_gun_crew", -30, 0.45, 0.7),
    "M48 Patton": ("sherman_tank", 0, 0.6, 0.8),
    "NVA Regulars": ("french_poilus", -20, 0.8, 0.95),
    "NVA Machine Gunners": ("machine_gun_crew", -20, 0.8, 0.95),
    "PT-76 Tank": ("sherman_tank", 25, 1.0, 0.85),
    "Vo Nguyen Giap": ("ferdinand_foch", -25, 0.8, 0.9),
    "Chinese Volunteers": ("french_poilus", 15, 0.45, 1.0),
    "Chinese Machine Gunners": ("machine_gun_crew", 15, 0.45, 1.0),
    "Peng Dehuai": ("ferdinand_foch", 20, 0.6, 0.85),
}


def nome_file(nome):
    s = re.sub(r"[^a-z0-9\s]", "", nome.lower())
    return "card_" + re.sub(r"\s+", "_", s.strip())


def hsv(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx, mn = rgb.max(-1), rgb.min(-1)
    d = mx - mn
    h = np.zeros_like(mx)
    m = d > 1e-6
    rr = m & (mx == r)
    gg = m & (mx == g) & ~rr
    bb = m & ~rr & ~gg
    h[rr] = ((g - b)[rr] / d[rr]) % 6
    h[gg] = (b - r)[gg] / d[gg] + 2
    h[bb] = (r - g)[bb] / d[bb] + 4
    s = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0)
    return h * 60, s, mx


def rgb(h, s, v):
    c = v * s
    x = c * (1 - np.abs((h / 60) % 2 - 1))
    m = v - c
    z = np.zeros_like(h)
    k = (h // 60).astype(int) % 6
    r = np.choose(k, [c, x, z, z, x, c])
    g = np.choose(k, [x, c, c, x, z, z])
    b = np.choose(k, [z, z, x, c, c, x])
    return np.stack([r + m, g + m, b + m], -1)


def variante(base, tinta, sat, lum):
    im = np.asarray(Image.open(os.path.join(GUI, "card_%s.png" % base)).convert("RGBA")).astype(np.float64) / 255
    h, s, v = hsv(im[..., :3])
    vivo = (s > 0.18) & (v > 0.18)
    oro = vivo & (h > 38) & (h < 62) & (s > 0.55) & (v > 0.75)  # gli ori (bottoni, fibbie) restano
    cambia = vivo & ~oro
    if tinta:
        h = np.where(cambia, (h + tinta) % 360, h)
    s = np.where(cambia, np.clip(s * sat, 0, 1), s)
    v = np.where(cambia, np.clip(v * lum, 0, 1), v)
    out = im.copy()
    out[..., :3] = rgb(h, s, v)
    return Image.fromarray((out * 255).round().astype(np.uint8), "RGBA")


def main():
    for nome, (base, tinta, sat, lum) in VARIANTI.items():
        percorso = os.path.join(GUI, nome_file(nome) + ".png")
        variante(base, tinta, sat, lum).save(percorso)
        print(os.path.basename(percorso))


main()
