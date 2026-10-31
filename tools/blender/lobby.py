"""Oggetti della lobby (la Cittadella, src/server/Lobby.luau) fatti in Blender: torce, bracieri, colonne,
piedistalli, il banco ARMY, i banchi dello shop (uno per cassa), stendardi, botti, casse, rastrelliere,
lampadario, tavolo di guerra, portale, plinti delle statue, cartelli. Tutto smussato, una texture sola.

Mattia, 31/10/2026: "rifai la lobby con Blender, non tralasciare i dettagli inutili: anche le torce perfette;
cilindri e sfere smussati".

Misure "a misura 1" della lobby (Lobby.luau poi ingrandisce tutto di SCALA). Assi di Blender: Z in alto, il
davanti verso -Y; ogni oggetto ha l'origine nel suo punto d'appoggio (a terra al centro, o sul muro per le
torce). Tutti gli oggetti stanno nello stesso FBX, ognuno col suo nome: nel gioco diventano le MeshPart di
un Model.

Uso:
  blender --background --factory-startup --python tools/blender/lobby.py [-- --anteprime]
Scrive assets-lobby/OggettiLobby.fbx (texture dentro), assets-lobby/atlante.png e assets-lobby/oggetti.json
(per ogni oggetto: centro dell'ingombro rispetto all'origine, misure, punti per fuochi e scritte; assi di
Roblox). Da lì si aggiorna src/shared/Config/AssetLobby.luau con tools/lobby_luau.py.
"""
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import attrezzi as A  # noqa: E402
from attrezzi import DAVANTI, FIANCO, R, S, T  # noqa: E402

RADICE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
USCITA = os.path.join(RADICE, "assets-lobby")

CELLE = [
    ("legno", lambda: A.cella_legno(A.hexc("#7A5232"), 1)),
    ("legno_scuro", lambda: A.cella_legno(A.hexc("#432B19"), 2)),
    ("ferro", lambda: A.cella_metallo(A.hexc("#3C3E44"), 3, 0.1)),
    ("oro", lambda: A.cella_metallo(A.hexc("#D9A94A"), 4)),
    ("pietra", lambda: A.cella_pietra(A.hexc("#A39886"), 5)),
    ("pietra_scura", lambda: A.cella_pietra(A.hexc("#5E5850"), 6)),
    ("marmo", lambda: A.cella_marmo(A.hexc("#E6E0D4"), 7)),
    ("feltro", lambda: A.cella_tessuto(A.hexc("#2E5A36"), 8)),
    ("cera", lambda: A.cella_liscia(A.hexc("#F0E6CC"), 9)),
    ("brace", lambda: A.cella_brace(10)),
    ("carta", lambda: A.cella_carta(A.hexc("#DCC79C"), 11)),
    ("velluto", lambda: A.cella_tessuto(A.hexc("#7E1F26"), 12)),
    ("bronzo", lambda: A.cella_metallo(A.hexc("#A87036"), 13)),
    ("lama", lambda: A.cella_metallo(A.hexc("#C9CED6"), 14, 0.04)),
    ("cuoio", lambda: A.cella_tessuto(A.hexc("#6E4326"), 15)),
    ("pietra_chiara", lambda: A.cella_pietra(A.hexc("#CDC2AC"), 16)),
]

OGGETTI = {}   # nome -> funzione che costruisce e restituisce (Pezzo, ampio, centro_v)
INDICI = {}


def oggetto(nome, ampio=8.0, centro_v=None):
    def registra(f):
        OGGETTI[nome] = (f, ampio, centro_v)
        return f
    return registra


def P(nome):
    return A.Pezzo(nome, INDICI)


# Torcia e braciere ---------------------------------------------------------------------------------

@oggetto("Torcia", ampio=4, centro_v=0.6)
def torcia():
    """Torcia a muro. Origine: sul muro, all'altezza del supporto; sporge verso -Y."""
    p = P("Torcia")
    # Piastra sul muro con quattro chiodi e il bordo ribattuto.
    p.aggiungi(A.scatola((0.8, 0.12, 1.5), 0.04), "ferro", T(0, -0.06, 0))
    p.aggiungi(A.scatola((0.62, 0.06, 1.3), 0.025), "ferro", T(0, -0.14, 0))
    for x in (-0.26, 0.26):
        for z in (-0.58, 0.58):
            p.aggiungi(A.sfera(0.065, 0.6), "bronzo", T(x, -0.15, z) @ DAVANTI)
    # Braccio piegato e anello che tiene il manico.
    p.aggiungi(A.tubo([Vector((0, -0.12, -0.25)), Vector((0, -0.55, -0.25)), Vector((0, -0.9, -0.05)),
                       Vector((0, -1.05, 0.2))], 0.07), "ferro")
    p.aggiungi(A.tubo([Vector((0, -0.12, 0.35)), Vector((0, -0.6, 0.3)), Vector((0, -1.0, 0.25))], 0.05), "ferro")
    m = T(0, -1.12, 0.6) @ R("X", 14)
    p.aggiungi(A.toro(0.25, 0.055, 20, 8), "ferro", T(0, -1.05, 0.25))
    # Manico di legno, più largo in alto, con tre fasce di cuoio.
    p.aggiungi(A.cilindro(0.13, 2.1, 12, 0.04, r2=0.17), "legno", m)
    for k, z in enumerate((-0.75, -0.45, 0.62)):
        p.aggiungi(A.toro(0.15 + z * 0.015, 0.035, 14, 6), "cuoio", m @ T(0, 0, z))
    # Coppa di ferro con la brace dentro.
    coppa = A.tornio([(0.0, 0.0), (0.14, 0.0), (0.3, 0.12), (0.4, 0.42), (0.44, 0.52), (0.4, 0.56),
                      (0.33, 0.33), (0.0, 0.3)], 18)
    p.aggiungi(coppa, "ferro", m @ T(0, 0, 1.02))
    p.aggiungi(A.toro(0.43, 0.035, 18, 6), "bronzo", m @ T(0, 0, 1.36))
    p.aggiungi(A.sfera(0.34, 0.42, 14, 6), "brace", m @ T(0, 0, 1.38))
    rng = np.random.default_rng(3)
    for i in range(6):
        a = i / 6 * 2 * math.pi
        p.aggiungi(A.sasso(0.09, i), "brace", m @ T(math.cos(a) * 0.2, math.sin(a) * 0.2, 1.46 + rng.random() * 0.05))
    p.punto("fuoco", (m @ Vector((0, 0, 1.75))))
    return p


@oggetto("Braciere", ampio=5, centro_v=2.2)
def braciere():
    """Braciere su tre zampe a S. Origine a terra al centro."""
    p = P("Braciere")
    ciotola = A.tornio([(0.0, 2.85), (0.6, 2.88), (1.3, 3.02), (1.78, 3.38), (2.04, 3.84), (2.12, 3.95),
                        (2.02, 4.0), (1.93, 3.88), (1.68, 3.52), (0.0, 3.52)], 32)
    p.aggiungi(ciotola, "ferro")
    p.aggiungi(A.toro(2.09, 0.09, 40, 8), "bronzo", T(0, 0, 3.97))
    p.aggiungi(A.toro(1.62, 0.055, 36, 6), "bronzo", T(0, 0, 3.3))
    for i in range(12):
        a = i / 12 * 2 * math.pi
        p.aggiungi(A.sfera(0.075, 0.6), "bronzo", T(math.cos(a) * 1.86, math.sin(a) * 1.86, 3.62) @ R("Z", math.degrees(a)) @ FIANCO)
    for i in range(3):
        a = i / 3 * 2 * math.pi + math.pi / 2
        c, s = math.cos(a), math.sin(a)
        punti = []
        for k in range(9):
            t = k / 8
            r = 1.42 + 0.26 * math.cos(2 * math.pi * t)
            punti.append(Vector((c * r, s * r, 0.12 + t * 3.0)))
        p.aggiungi(A.tubo(punti, 0.1, 10), "ferro")
        p.aggiungi(A.sfera(0.2, 0.7), "ferro", T(c * 1.68, s * 1.68, 0.12))
        p.aggiungi(A.sfera(0.15), "bronzo", T(c * 1.16, s * 1.16, 1.5))
        p.aggiungi(A.toro(0.16, 0.05, 12, 6), "bronzo", T(c * 1.68, s * 1.68, 3.05))
    p.aggiungi(A.toro(1.16, 0.06, 36, 6), "ferro", T(0, 0, 1.5))
    # Brace a cupola e pezzi di carbone.
    p.aggiungi(A.sfera(1.78, 0.2, 24, 8), "brace", T(0, 0, 3.52))
    rng = np.random.default_rng(5)
    for i in range(14):
        a = rng.random() * 2 * math.pi
        r = rng.random() * 1.4
        p.aggiungi(A.sasso(0.18 + rng.random() * 0.1, i), "brace", T(math.cos(a) * r, math.sin(a) * r, 3.7 + (1.4 - r) * 0.12))
    p.punto("fuoco", (0, 0, 4.2))
    return p


# Colonne e plinti ----------------------------------------------------------------------------------

def colonna_generica(nome, alto, diametro, cella_fusto, cella_basi, cella_anello):
    p = P(nome)
    r = diametro / 2
    lato = r * 2 + 1.4
    # Plinto quadrato, base modanata, fusto con l'entasi, capitello modanato, abaco.
    p.aggiungi(A.scatola((lato, lato, 0.8), 0.1), cella_basi, T(0, 0, 0.4))
    p.aggiungi(A.tornio([(0.0, 0.8), (r + 0.45, 0.8), (r + 0.5, 0.95), (r + 0.42, 1.12), (r + 0.25, 1.2),
                         (r + 0.3, 1.36), (r + 0.18, 1.5), (r + 0.06, 1.58), (0.0, 1.58)], 32), cella_basi)
    fusto = [(0.0, 1.58)] + [(r * (1 - 0.06 * ((z - 1.58) / (alto - 4.2)) ** 2), z)
                              for z in np.linspace(1.58, alto - 2.6, 8)] + [(0.0, alto - 2.6)]
    p.aggiungi(A.tornio(fusto, 32), cella_fusto)
    p.aggiungi(A.toro(r * 0.96, 0.13, 32, 8), cella_anello, T(0, 0, alto - 2.75))
    rc = r * 0.94
    p.aggiungi(A.tornio([(0.0, alto - 2.6), (rc, alto - 2.6), (rc + 0.12, alto - 2.3), (rc + 0.35, alto - 1.7),
                         (rc + 0.6, alto - 1.15), (rc + 0.7, alto - 0.95), (0.0, alto - 0.95)], 32), cella_basi)
    p.aggiungi(A.scatola((lato, lato, 0.95), 0.1), cella_basi, T(0, 0, alto - 0.475))
    p.aggiungi(A.scatola((lato + 0.12, lato + 0.12, 0.18), 0.05), cella_anello, T(0, 0, alto - 0.95))
    return p


@oggetto("ColonnaRotonda", ampio=42, centro_v=20)
def colonna_rotonda():
    return colonna_generica("ColonnaRotonda", 40, 3.6, "pietra_chiara", "pietra_chiara", "oro")


@oggetto("ColonnaPorta", ampio=28, centro_v=13)
def colonna_porta():
    return colonna_generica("ColonnaPorta", 26, 3.4, "pietra_chiara", "pietra_chiara", "oro")


@oggetto("ColonnaMarmo", ampio=30, centro_v=14)
def colonna_marmo():
    return colonna_generica("ColonnaMarmo", 28, 2.6, "marmo", "marmo", "oro")


@oggetto("PlintoStatua", ampio=11, centro_v=2.3)
def plinto_statua():
    """Plinto tondo delle statue dei comandanti: zoccolo scuro, tamburo di marmo, anello d'oro. Piano a 4.6."""
    p = P("PlintoStatua")
    p.aggiungi(A.tornio([(0.0, 0.0), (5.0, 0.0), (5.06, 0.12), (5.0, 1.05), (4.7, 1.16), (4.35, 1.24),
                         (4.1, 1.32), (0.0, 1.32)], 40), "pietra_scura")
    p.aggiungi(A.tornio([(0.0, 1.32), (4.0, 1.32), (4.0, 3.98), (0.0, 3.98)], 40), "marmo")
    p.aggiungi(A.toro(4.02, 0.1, 48, 8), "oro", T(0, 0, 1.45))
    p.aggiungi(A.tornio([(0.0, 3.98), (4.18, 3.98), (4.32, 4.1), (4.36, 4.36), (4.22, 4.5), (4.0, 4.56),
                         (0.0, 4.56)], 40), "pietra_scura")
    p.aggiungi(A.toro(4.3, 0.09, 48, 8), "oro", T(0, 0, 4.3))
    p.punto("piano", (0, 0, 4.56))
    return p


# Piedistallo della Galleria ------------------------------------------------------------------------

@oggetto("Piedistallo", ampio=10, centro_v=1)
def piedistallo():
    """Piedistallo dei reggimenti (9 x 9.5). Sopra c'è il panno colorato dell'epoca (una Part del gioco)."""
    p = P("Piedistallo")
    L, D = 9.0, 9.5
    p.aggiungi(A.scatola((L + 0.3, D + 0.3, 0.3), 0.08), "pietra_scura", T(0, 0, 0.15))
    p.aggiungi(A.scatola((L - 0.5, D - 0.5, 1.2), 0.1), "pietra_scura", T(0, 0, 0.9))
    p.aggiungi(A.scatola((L, D, 0.32), 0.1), "pietra", T(0, 0, 1.6))
    # Listelli d'oro sul bordo del piano e cornice dello scasso dove sta il panno.
    for s in (-1, 1):
        p.aggiungi(A.scatola((L + 0.04, 0.09, 0.09), 0.03), "oro", T(0, s * (D / 2 - 0.02), 1.48))
        p.aggiungi(A.scatola((0.09, D + 0.04, 0.09), 0.03), "oro", T(s * (L / 2 - 0.02), 0, 1.48))
        p.aggiungi(A.scatola((L - 1.0, 0.12, 0.12), 0.04), "oro", T(0, s * (D / 2 - 0.55), 1.8))
        p.aggiungi(A.scatola((0.12, D - 1.0, 0.12), 0.04), "oro", T(s * (L / 2 - 0.55), 0, 1.8))
    # Borchie agli angoli dello zoccolo.
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.aggiungi(A.sfera(0.16, 0.7), "bronzo", T(sx * (L / 2 - 0.45), sy * (D / 2 - 0.45), 1.85))
    # Leggio della targa davanti, inclinato.
    m = T(0, -D / 2 - 0.5, 1.05) @ R("X", -20)
    p.aggiungi(A.scatola((6.2, 0.3, 1.5), 0.06), "legno_scuro", m)
    for z in (-0.78, 0.78):
        p.aggiungi(A.scatola((6.4, 0.36, 0.12), 0.04), "oro", m @ T(0, 0, z))
    for x in (-3.15, 3.15):
        p.aggiungi(A.scatola((0.12, 0.36, 1.66), 0.04), "oro", m @ T(x, 0, 0))
    for x in (-2.2, 2.2):
        p.aggiungi(A.scatola((0.25, 0.4, 0.9), 0.05), "pietra_scura", T(x, -D / 2 - 0.25, 0.45))
    p.punto("targa", m @ Vector((0, -0.16, 0)))
    p.punto("piano", (0, 0, 1.76))
    return p


# Banco ARMY ----------------------------------------------------------------------------------------

@oggetto("BancoArmy", ampio=22, centro_v=2.5)
def banco_army():
    """Tavolo dell'esercito: piano di legno con il feltro verde, tre cassetti, gambe tornite; sopra le
    mappe, le carte del mazzo, i candelieri, il calamaio e la penna, il compasso."""
    p = P("BancoArmy")
    L, D, H = 20.0, 8.0, 4.0
    p.aggiungi(A.scatola((L, D, 0.5), 0.14, 3), "legno", T(0, 0, H - 0.25))
    p.aggiungi(A.scatola((L - 1.6, D - 1.6, 0.06), 0.02), "feltro", T(0, 0, H + 0.01))
    for s in (-1, 1):
        p.aggiungi(A.scatola((L - 1.3, 0.12, 0.1), 0.04), "oro", T(0, s * (D / 2 - 0.65), H + 0.03))
        p.aggiungi(A.scatola((0.12, D - 1.3, 0.1), 0.04), "oro", T(s * (L / 2 - 0.65), 0, H + 0.03))
    # Fascia sotto il piano con i cassetti davanti e le borchie.
    p.aggiungi(A.scatola((L - 1.0, D - 1.0, 1.0), 0.06), "legno_scuro", T(0, 0, H - 1.0))
    for x in (-6.2, 0, 6.2):
        p.aggiungi(A.scatola((5.0, 0.16, 0.74), 0.05), "legno", T(x, -D / 2 + 0.44, H - 1.0))
        p.aggiungi(A.toro(0.16, 0.04, 14, 6), "bronzo", T(x, -D / 2 + 0.28, H - 1.02) @ DAVANTI)
        p.aggiungi(A.sfera(0.09), "bronzo", T(x, -D / 2 + 0.3, H - 0.86))
    # Gambe tornite e traverse.
    gamba = [(0.0, 0.0), (0.46, 0.0), (0.5, 0.14), (0.36, 0.34), (0.44, 0.62), (0.3, 1.0), (0.27, 1.7),
             (0.38, 2.0), (0.3, 2.3), (0.36, 2.52), (0.36, H - 1.5), (0.0, H - 1.5)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.aggiungi(A.tornio(gamba, 18), "legno_scuro", T(sx * (L / 2 - 1.0), sy * (D / 2 - 0.9), 0))
            p.aggiungi(A.sfera(0.22, 0.6), "bronzo", T(sx * (L / 2 - 1.0), sy * (D / 2 - 0.9), H - 1.52))
    for s in (-1, 1):
        p.aggiungi(A.scatola((L - 2.2, 0.32, 0.32), 0.08), "legno_scuro", T(0, s * (D / 2 - 0.9), 0.62))
        p.aggiungi(A.scatola((0.32, D - 2.0, 0.32), 0.08), "legno_scuro", T(s * (L / 2 - 1.0), 0, 0.62))
    top = H + 0.04
    # Mappa aperta con i bordi arrotolati, mappa arrotolata con i pomoli.
    m = T(-2.0, 0.6, top) @ R("Z", 7)
    p.aggiungi(A.scatola((5.4, 3.6, 0.03), 0.01), "carta", m @ T(0, 0, 0.015))
    for x in (-2.75, 2.75):
        p.aggiungi(A.cilindro(0.13, 3.6, 12, 0.03), "carta", m @ T(x, 0, 0.13) @ R("X", 90))
    p.aggiungi(A.cilindro(0.32, 3.4, 14, 0.06), "carta", T(-6.8, 1.6, top + 0.32) @ FIANCO)
    for x in (-8.55, -5.05):
        p.aggiungi(A.cilindro(0.2, 0.36, 12, 0.04), "legno_scuro", T(x, 1.6, top + 0.32) @ FIANCO)
        p.aggiungi(A.sfera(0.14), "bronzo", T(x + (0.26 if x > -7 else -0.26), 1.6, top + 0.32))
    # Compasso sulla mappa.
    for ang in (-12, 12):
        p.aggiungi(A.scatola((0.08, 2.0, 0.06), 0.02), "ferro", T(-1.4, 0.2, top + 0.09) @ R("Z", ang + 7) @ T(0, -0.9, 0))
    p.aggiungi(A.sfera(0.1), "bronzo", T(-1.4, 0.2, top + 0.12))
    # Carte del mazzo a ventaglio e il mazzo coperto.
    colori = ["oro", "oro", "lama", "lama", "bronzo", "bronzo"]
    for i, c in enumerate(colori):
        a = -25 + i * 10
        p.aggiungi(A.scatola((1.1, 1.6, 0.03), 0.02), c, T(4.6, -1.2, top + 0.02 + i * 0.012) @ R("Z", a) @ T(0, 0.7, 0))
    p.aggiungi(A.scatola((1.1, 1.6, 0.45), 0.04), "legno_scuro", T(7.6, -1.6, top + 0.23) @ R("Z", -8))
    p.aggiungi(A.scatola((0.9, 1.4, 0.04), 0.02), "oro", T(7.6, -1.6, top + 0.46) @ R("Z", -8))
    # Candelieri con le candele.
    candeliere = [(0.0, 0.0), (0.5, 0.0), (0.5, 0.08), (0.22, 0.2), (0.12, 0.5), (0.2, 0.86), (0.1, 1.15),
                  (0.28, 1.26), (0.28, 1.34), (0.0, 1.34)]
    for x in (-L / 2 + 1.4, L / 2 - 1.4):
        p.aggiungi(A.tornio(candeliere, 16), "bronzo", T(x, 2.6, top))
        p.aggiungi(A.cilindro(0.15, 1.1, 12, 0.03), "cera", T(x, 2.6, top + 1.34 + 0.55))
        p.aggiungi(A.sfera(0.07, 1.4), "cera", T(x + 0.12, 2.6, top + 1.9))
        p.punto("fuoco", (x, 2.6, top + 2.6))
    # Calamaio e penna.
    p.aggiungi(A.tornio([(0.0, 0.0), (0.32, 0.0), (0.38, 0.28), (0.16, 0.44), (0.16, 0.56), (0.0, 0.56)], 16),
               "ferro", T(2.0, 2.4, top))
    penna = A.prisma([(-0.02, 0.0), (0.1, 0.4), (0.14, 1.6), (0.0, 2.1), (-0.08, 1.4)], -0.015, 0.015, 0.0)
    p.aggiungi(penna, "carta", T(2.05, 2.4, top + 0.4) @ R("Y", -25) @ R("Z", 90))
    p.aggiungi(A.cilindro(0.025, 0.6, 6, 0.0), "legno_scuro", T(2.0, 2.4, top + 0.5) @ R("Y", -25))
    return p


# Banco dello shop (uno per cassa) ------------------------------------------------------------------

@oggetto("BancoCassa", ampio=8, centro_v=1.8)
def banco_cassa():
    """Mobile da esposizione per un forziere: zoccolo, anta a cornice, colonnine d'angolo, piano con il
    cuscino di velluto. Sul cuscino il gioco mette il forziere; sulla targhetta il prezzo."""
    p = P("BancoCassa")
    L, D, H = 6.6, 5.0, 3.4
    p.aggiungi(A.scatola((L + 0.3, D + 0.3, 0.3), 0.08), "legno_scuro", T(0, 0, 0.15))
    p.aggiungi(A.scatola((L - 0.4, D - 0.4, H - 0.6), 0.06), "legno", T(0, 0, 0.3 + (H - 0.6) / 2))
    # Ante a cornice davanti e ai lati.
    zc = 0.3 + (H - 0.6) / 2
    for verso in ("davanti", "sinistra", "destra"):
        if verso == "davanti":
            base, largo = T(0, -(D / 2 - 0.2), zc), L - 1.6
            ruota = R("Z", 0)
        else:
            s = -1 if verso == "sinistra" else 1
            base, largo = T(s * (L / 2 - 0.2), 0, zc), D - 1.6
            ruota = R("Z", -90 * s)
        m = base @ ruota
        alto = H - 1.3
        p.aggiungi(A.scatola((largo, 0.12, 0.2), 0.04), "legno_scuro", m @ T(0, -0.04, alto / 2))
        p.aggiungi(A.scatola((largo, 0.12, 0.2), 0.04), "legno_scuro", m @ T(0, -0.04, -alto / 2))
        p.aggiungi(A.scatola((0.2, 0.12, alto + 0.2), 0.04), "legno_scuro", m @ T(largo / 2, -0.04, 0))
        p.aggiungi(A.scatola((0.2, 0.12, alto + 0.2), 0.04), "legno_scuro", m @ T(-largo / 2, -0.04, 0))
        p.aggiungi(A.scatola((largo - 0.6, 0.06, alto - 0.5), 0.05), "legno", m @ T(0, -0.04, 0))
    # Colonnine tornite agli angoli.
    colonnina = [(0.0, 0.0), (0.28, 0.0), (0.3, 0.12), (0.2, 0.25), (0.22, 0.4), (0.16, 0.6), (0.16, H - 1.25),
                 (0.24, H - 1.1), (0.24, H - 0.9), (0.0, H - 0.9)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.aggiungi(A.tornio(colonnina, 16), "bronzo", T(sx * (L / 2 - 0.1), sy * (D / 2 - 0.1), 0.3))
    # Piano con bordo d'oro e cuscino di velluto con le nappe.
    p.aggiungi(A.scatola((L + 0.3, D + 0.3, 0.32), 0.1), "legno_scuro", T(0, 0, H - 0.44))
    for s in (-1, 1):
        p.aggiungi(A.scatola((L + 0.32, 0.1, 0.08), 0.03), "oro", T(0, s * (D / 2 + 0.11), H - 0.44))
        p.aggiungi(A.scatola((0.1, D + 0.32, 0.08), 0.03), "oro", T(s * (L / 2 + 0.11), 0, H - 0.44))
    p.aggiungi(A.scatola((5.0, 3.6, 0.34), 0.15, 3), "velluto", T(0, 0, H - 0.11))
    for sx in (-1, 1):
        for sy in (-1, 1):
            q = T(sx * 2.45, sy * 1.75, H - 0.15)
            p.aggiungi(A.sfera(0.1), "oro", q)
            p.aggiungi(A.cilindro(0.06, 0.3, 8, 0.02, r2=0.11), "oro", q @ T(0, 0, -0.22))
    # Targhetta del prezzo, d'ottone, con quattro chiodini.
    p.aggiungi(A.scatola((3.0, 0.08, 0.8), 0.03), "bronzo", T(0, -(D / 2 + 0.05), 1.75))
    for x in (-1.36, 1.36):
        for z in (-0.28, 0.28):
            p.aggiungi(A.sfera(0.045, 0.6), "oro", T(x, -(D / 2 + 0.1), 1.75 + z) @ DAVANTI)
    p.punto("piano", (0, 0, H + 0.06))
    p.punto("targa", (0, -(D / 2 + 0.1), 1.75))
    return p


# Stendardo -----------------------------------------------------------------------------------------

def telo_stendardo(nome, larghezza=6.5, altezza=16.0):
    """Telo con le onde e la coda a due punte. Origine in alto al centro (sotto l'asta)."""
    p = P(nome)
    import bmesh
    bm = bmesh.new()
    nx, nz = 12, 28
    coda = larghezza * 0.42
    spessore = 0.12

    def punto(i, k, lato):
        x = -larghezza / 2 + larghezza * i / nx
        t = k / nz
        z = -t * altezza
        # Coda: al centro il telo risale (taglio a V).
        if t > 1 - coda / altezza:
            taglio = coda * (1 - abs(x) / (larghezza / 2))
            z = max(z, -altezza + taglio * ((t - (1 - coda / altezza)) / (coda / altezza)))
        y = 0.18 * math.sin(x / larghezza * math.pi * 2 + t * 2.2) * (0.3 + t) + lato * spessore / 2
        return Vector((x, y, z))

    davanti = [[bm.verts.new(punto(i, k, -1)) for i in range(nx + 1)] for k in range(nz + 1)]
    dietro = [[bm.verts.new(punto(i, k, 1)) for i in range(nx + 1)] for k in range(nz + 1)]
    for k in range(nz):
        for i in range(nx):
            bm.faces.new((davanti[k][i], davanti[k + 1][i], davanti[k + 1][i + 1], davanti[k][i + 1]))
            bm.faces.new((dietro[k][i + 1], dietro[k + 1][i + 1], dietro[k + 1][i], dietro[k][i]))
    for k in range(nz):
        for g in (0, nx):
            bm.faces.new((davanti[k][g], dietro[k][g], dietro[k + 1][g], davanti[k + 1][g]))
    for i in range(nx):
        for k in (0, nz):
            bm.faces.new((davanti[k][i], davanti[k][i + 1], dietro[k][i + 1], dietro[k][i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    p.aggiungi(bm, "legno")
    return p


@oggetto("StendardoTelo", ampio=18, centro_v=-8)
def stendardo_telo():
    return telo_stendardo("StendardoTelo")


@oggetto("StendardoAsta", ampio=9, centro_v=0)
def stendardo_asta():
    """Asta orizzontale con i puntali, il cordone e l'emblema d'oro a rombo sul telo."""
    p = P("StendardoAsta")
    larghezza = 6.5
    p.aggiungi(A.cilindro(0.2, larghezza + 1.2, 16, 0.05), "legno_scuro", T(0, 0, 0.3) @ FIANCO)
    for s in (-1, 1):
        x = s * (larghezza / 2 + 0.75)
        p.aggiungi(A.sfera(0.3), "oro", T(x, 0, 0.3))
        punta = A.cilindro(0.16, 0.5, 12, 0.0, r2=0.0)
        p.aggiungi(punta, "oro", T(x + s * 0.5, 0, 0.3) @ R("Y", 90 * s))
        p.aggiungi(A.toro(0.24, 0.05, 14, 6), "oro", T(s * (larghezza / 2 + 0.35), 0, 0.3) @ FIANCO)
    # Cordone e nappe che pendono ai lati.
    for s in (-1, 1):
        x = s * (larghezza / 2 + 0.2)
        p.aggiungi(A.tubo([Vector((x, -0.05, 0.2)), Vector((x + s * 0.2, -0.12, -1.6)), Vector((x + s * 0.15, -0.15, -3.0))], 0.05, 6), "oro")
        p.aggiungi(A.cilindro(0.08, 0.7, 10, 0.02, r2=0.18), "oro", T(x + s * 0.15, -0.15, -3.35))
    # Emblema: rombo con il cerchio, sul davanti del telo.
    m = T(0, -0.32, -5.2)
    p.aggiungi(A.scatola((2.6, 0.08, 2.6), 0.04), "oro", m @ R("Y", 45))
    p.aggiungi(A.toro(0.75, 0.1, 24, 6), "legno_scuro", m @ T(0, -0.06, 0) @ DAVANTI)
    p.aggiungi(A.cilindro(0.5, 0.1, 20, 0.03), "oro", m @ T(0, -0.08, 0) @ DAVANTI)
    # Frangia d'oro in fondo al telo, sulle due punte.
    for s in (-1, 1):
        p.aggiungi(A.scatola((larghezza * 0.38, 0.16, 0.22), 0.05), "oro", T(s * larghezza * 0.3, -0.06, -15.6 + 0.45) @ R("Y", s * 25))
    return p


# Botte, cassa di legno, rastrelliere ---------------------------------------------------------------

@oggetto("Botte", ampio=4, centro_v=1.5)
def botte():
    p = P("Botte")
    H = 3.0

    def r(z):
        return 1.0 + 0.2 * math.sin(math.pi * z / H)

    p.aggiungi(A.tornio([(0.0, 0.0)] + [(r(z), z) for z in np.linspace(0, H, 12)] + [(0.0, H)], 24), "legno")
    for z in (0.3, 0.85, H - 0.85, H - 0.3):
        p.aggiungi(A.toro(r(z) + 0.02, 0.05, 28, 6), "ferro", T(0, 0, z))
    p.aggiungi(A.cilindro(0.86, 0.06, 24, 0.02), "legno_scuro", T(0, 0, H - 0.02))
    p.aggiungi(A.cilindro(0.1, 0.12, 10, 0.03), "legno_scuro", T(0.4, 0.2, H + 0.04))
    # Le doghe: righe scure sul fianco, che seguono la pancia della botte.
    for i in range(12):
        a = i / 12 * 2 * math.pi
        c, s = math.cos(a), math.sin(a)
        p.aggiungi(A.tubo([Vector((c * r(z), s * r(z), z)) for z in np.linspace(0.08, H - 0.08, 9)], 0.022, 4),
                   "legno_scuro")
    return p


@oggetto("CassaLegno", ampio=4, centro_v=1.8)
def cassa_legno():
    p = P("CassaLegno")
    L = 3.6
    p.aggiungi(A.scatola((L - 0.2, L - 0.2, L - 0.2), 0.03), "legno", T(0, 0, L / 2))
    trave = 0.34
    for a in (-1, 1):
        for b in (-1, 1):
            p.aggiungi(A.scatola((trave, trave, L), 0.06), "legno_scuro", T(a * (L - trave) / 2, b * (L - trave) / 2, L / 2))
            p.aggiungi(A.scatola((L, trave, trave), 0.06), "legno_scuro", T(0, a * (L - trave) / 2, L / 2 + b * (L - trave) / 2))
            p.aggiungi(A.scatola((trave, L, trave), 0.06), "legno_scuro", T(a * (L - trave) / 2, 0, L / 2 + b * (L - trave) / 2))
    diagonale = math.hypot(L - trave * 2, L - trave * 2)
    for s in (-1, 1):
        p.aggiungi(A.scatola((diagonale, 0.14, 0.32), 0.05), "legno_scuro", T(0, s * (L / 2 - 0.02), L / 2) @ R("Y", 45))
        p.aggiungi(A.scatola((0.14, diagonale, 0.32), 0.05), "legno_scuro", T(s * (L / 2 - 0.02), 0, L / 2) @ R("X", 45))
    return p


def rastrelliera(nome, arma):
    p = P(nome)
    for s in (-1, 1):
        p.aggiungi(A.scatola((0.6, 0.6, 8.4), 0.08), "legno", T(s * 4.2, 0, 4.2))
        p.aggiungi(A.sfera(0.36), "legno_scuro", T(s * 4.2, 0, 8.55))
        p.aggiungi(A.scatola((0.9, 1.6, 0.3), 0.06), "legno_scuro", T(s * 4.2, 0, 0.15))
    p.aggiungi(A.scatola((9.0, 1.3, 0.4), 0.08), "legno", T(0, -0.35, 1.2))
    p.aggiungi(A.scatola((9.0, 0.6, 0.5), 0.08), "legno", T(0, 0, 6.6))
    for i in range(-3, 4):
        p.aggiungi(A.cilindro(0.12, 0.4, 10, 0.03), "legno_scuro", T(i * 1.15, -0.4, 6.6) @ DAVANTI)
        x = i * 1.15
        if arma == "lance":
            p.aggiungi(A.cilindro(0.11, 8.4, 10, 0.03), "legno", T(x, -0.4, 5.4))
            p.aggiungi(A.cilindro(0.22, 1.1, 4, 0.0, r2=0.0), "lama", T(x, -0.4, 10.15) @ S(1, 0.35, 1))
            p.aggiungi(A.toro(0.13, 0.04, 10, 6), "ferro", T(x, -0.4, 9.55))
        elif arma == "spade":
            lama = A.prisma([(-0.17, 0.0), (0.17, 0.0), (0.14, 4.0), (0.0, 4.5), (-0.14, 4.0)], -0.04, 0.04, 0.0)
            p.aggiungi(lama, "lama", T(x, -0.4, 1.6) @ R("Z", 90))
            p.aggiungi(A.scatola((1.3, 0.22, 0.22), 0.06), "oro", T(x, -0.4, 6.15))
            p.aggiungi(A.cilindro(0.12, 1.0, 10, 0.03), "cuoio", T(x, -0.4, 6.75))
            p.aggiungi(A.sfera(0.2), "oro", T(x, -0.4, 7.35))
        else:
            calcio = A.prisma([(-0.25, 0.0), (0.2, 0.0), (0.15, 1.2), (0.06, 2.8), (-0.12, 2.8), (-0.25, 1.0)],
                              -0.14, 0.14, 0.04)
            p.aggiungi(calcio, "legno", T(x, -0.4, 1.4))
            p.aggiungi(A.cilindro(0.08, 3.4, 10, 0.02), "ferro", T(x, -0.42, 5.8))
            p.aggiungi(A.scatola((0.12, 0.3, 0.5), 0.03), "ferro", T(x, -0.3, 4.3))
    return p


@oggetto("RastrellieraLance", ampio=12, centro_v=5)
def rastrelliera_lance():
    return rastrelliera("RastrellieraLance", "lance")


@oggetto("RastrellieraSpade", ampio=12, centro_v=5)
def rastrelliera_spade():
    return rastrelliera("RastrellieraSpade", "spade")


@oggetto("RastrellieraFucili", ampio=12, centro_v=5)
def rastrelliera_fucili():
    return rastrelliera("RastrellieraFucili", "fucili")


# Lampadario ----------------------------------------------------------------------------------------

@oggetto("Lampadario", ampio=30, centro_v=0)
def lampadario():
    """Lampadario ad anello (raggio 13) con 8 candele; il gioco aggiunge le catene fino al soffitto."""
    p = P("Lampadario")
    p.aggiungi(A.toro(13.0, 0.36, 72, 10), "ferro")
    p.aggiungi(A.toro(12.3, 0.16, 72, 8), "ferro", T(0, 0, -0.55))
    for i in range(16):
        a = i / 16 * 2 * math.pi
        c, s = math.cos(a), math.sin(a)
        p.aggiungi(A.tubo([Vector((c * 12.3, s * 12.3, -0.55)), Vector((c * 12.7, s * 12.7, -0.3)), Vector((c * 13, s * 13, 0))], 0.07, 6), "ferro")
    for i in range(8):
        a = i / 8 * 2 * math.pi
        q = Vector((math.cos(a) * 13, math.sin(a) * 13, 0.3))
        p.aggiungi(A.tornio([(0.0, 0.0), (0.2, 0.0), (0.5, 0.2), (0.55, 0.3), (0.2, 0.32), (0.2, 0.5), (0.0, 0.5)], 14), "bronzo", T(*q))
        p.aggiungi(A.cilindro(0.2, 1.2, 12, 0.04), "cera", T(q.x, q.y, q.z + 1.1))
        p.aggiungi(A.sfera(0.08, 1.5), "cera", T(q.x + 0.16, q.y, q.z + 1.5))
        p.punto("fuoco", (q.x, q.y, q.z + 2.0))
    # Raggi verso il mozzo e i quattro attacchi delle catene.
    for i in range(4):
        a = i / 4 * 2 * math.pi + math.pi / 4
        c, s = math.cos(a), math.sin(a)
        p.aggiungi(A.tubo([Vector((c * 12.6, s * 12.6, 0)), Vector((c * 6, s * 6, 0.6)), Vector((c * 1, s * 1, 0.4))], 0.12, 8), "ferro")
        p.aggiungi(A.toro(0.3, 0.07, 12, 6), "ferro", T(c * 13, s * 13, 0.45) @ R("Z", math.degrees(a)) @ R("X", 90))
        p.punto("catena", (c * 13, s * 13, 0.75))
    p.aggiungi(A.sfera(1.0, 0.8), "bronzo", T(0, 0, 0.4))
    p.aggiungi(A.cilindro(0.3, 1.2, 12, 0.06, r2=0.0), "bronzo", T(0, 0, -0.8) @ R("X", 180))
    return p


# Tavolo di guerra della Rotonda ---------------------------------------------------------------------

@oggetto("TavoloGuerra", ampio=60, centro_v=3)
def tavolo_guerra():
    """Tavolo grande al centro della Rotonda (piano 44 x 34): sul piano il gioco mette il mare e il plastico
    d'Europa. Due gradini tondi di pietra sotto."""
    p = P("TavoloGuerra")
    L, D = 44.0, 34.0
    p.aggiungi(A.tornio([(0.0, 0.0), (31.0, 0.0), (31.0, 0.45), (30.6, 0.6), (0.0, 0.6)], 72), "pietra_scura")
    p.aggiungi(A.tornio([(0.0, 0.6), (28.0, 0.6), (28.0, 1.05), (27.6, 1.2), (0.0, 1.2)], 72), "pietra")
    p.aggiungi(A.toro(28.0, 0.12, 96, 6), "oro", T(0, 0, 1.12))
    H = 5.6  # piano del mare
    # Cornice del piano, alta, con il bordo d'oro, e la fascia sotto con le formelle.
    for s in (-1, 1):
        p.aggiungi(A.scatola((L + 1.6, 1.0, 1.0), 0.18, 3), "legno", T(0, s * (D / 2 + 0.3), H))
        p.aggiungi(A.scatola((1.0, D + 1.6, 1.0), 0.18, 3), "legno", T(s * (L / 2 + 0.3), 0, H))
        p.aggiungi(A.scatola((L + 1.7, 0.14, 0.14), 0.05), "oro", T(0, s * (D / 2 + 0.82), H + 0.25))
        p.aggiungi(A.scatola((0.14, D + 1.7, 0.14), 0.05), "oro", T(s * (L / 2 + 0.82), 0, H + 0.25))
    p.aggiungi(A.scatola((L, D, 0.5), 0.05), "legno_scuro", T(0, 0, H - 0.45))
    p.aggiungi(A.scatola((L - 1.0, D - 1.0, 1.6), 0.08), "legno_scuro", T(0, 0, H - 1.5))
    for s in (-1, 1):
        for x in np.linspace(-L / 2 + 4, L / 2 - 4, 7):
            p.aggiungi(A.scatola((4.4, 0.12, 0.9), 0.05), "legno", T(x, s * (D / 2 - 0.5), H - 1.5))
            p.aggiungi(A.sfera(0.14), "oro", T(x, s * (D / 2 - 0.58), H - 1.5))
        for y in np.linspace(-D / 2 + 4, D / 2 - 4, 5):
            p.aggiungi(A.scatola((0.12, 4.4, 0.9), 0.05), "legno", T(s * (L / 2 - 0.5), y, H - 1.5))
            p.aggiungi(A.sfera(0.14), "oro", T(s * (L / 2 - 0.58), y, H - 1.5))
    # Sei gambe tornite, grosse, con i piedi a cipolla.
    gamba = [(0.0, 1.2), (1.0, 1.2), (1.05, 1.4), (0.75, 1.65), (0.9, 2.0), (0.6, 2.5), (0.55, 3.0),
             (0.75, 3.3), (0.62, 3.55), (0.7, H - 2.3), (0.0, H - 2.3)]
    for x in (-L / 2 + 2.5, 0.0, L / 2 - 2.5):
        for s in (-1, 1):
            p.aggiungi(A.tornio(gamba, 20), "legno_scuro", T(x, s * (D / 2 - 2.0), 0))
    p.punto("piano", (0, 0, H))
    p.punto("misure_piano", (L, D, 0))
    return p


# Portale --------------------------------------------------------------------------------------------

@oggetto("Portale", ampio=34, centro_v=11)
def portale():
    """Portale delle ali: gradini, anello di conci (oro ogni cinque), pilastri con i bracieri in cima.
    Origine a terra al centro dell'anello; chi arriva sta verso -Y."""
    p = P("Portale")
    raggio = 9.0
    zc = 2 + raggio + 1.2
    p.aggiungi(A.scatola((32, 12, 1), 0.2), "pietra_scura", T(0, 1, 0.5))
    p.aggiungi(A.scatola((28, 9, 1), 0.2), "pietra", T(0, 1.5, 1.5))
    for s in (-1, 1):
        p.aggiungi(A.scatola((31.4, 0.12, 0.12), 0.04), "oro", T(0, s * 6 + 1, 1.0))
    n = 30
    for i in range(n):
        a0 = i / n * 2 * math.pi
        a1 = (i + 1) / n * 2 * math.pi
        oro = i % 5 == 0
        r0, r1 = raggio - (0.2 if oro else 0.0), raggio + 2.8 + (0.5 if oro else 0.0)
        spessore = 3.6 + (0.6 if oro else 0.0)
        gap = 0.04
        prof = [(math.cos(a0 + gap) * r0, math.sin(a0 + gap) * r0), (math.cos(a1 - gap) * r0, math.sin(a1 - gap) * r0),
                (math.cos(a1 - gap) * r1, math.sin(a1 - gap) * r1), (math.cos(a0 + gap) * r1, math.sin(a0 + gap) * r1)]
        # Profilo nel piano XZ (x, z) estruso lungo Y: con prisma (profilo in YZ, estruso in X) e una rotazione.
        concio = A.prisma([(x, z) for x, z in prof], -spessore / 2, spessore / 2, 0.14)
        p.aggiungi(concio, "oro" if oro else "pietra_scura", T(0, 0, zc) @ R("Z", 90) @ R("X", 0))
    p.aggiungi(A.toro(raggio - 0.05, 0.22, 64, 8), "bronzo", T(0, -1.0, zc) @ DAVANTI)
    p.aggiungi(A.toro(raggio - 0.05, 0.22, 64, 8), "bronzo", T(0, 1.0, zc) @ DAVANTI)
    for s in (-1, 1):
        x = s * 14
        p.aggiungi(A.scatola((4.8, 5.8, 0.8), 0.12), "pietra_scura", T(x, 1, 2.4))
        p.aggiungi(A.scatola((4, 5, 17.2), 0.2), "pietra", T(x, 1, 2.8 + 8.6))
        for z in (6, 11, 16):
            p.aggiungi(A.scatola((4.12, 5.12, 0.18), 0.05), "pietra_scura", T(x, 1, z))
        p.aggiungi(A.scatola((5, 6, 1.4), 0.2), "oro", T(x, 1, 20.6))
        p.aggiungi(A.tornio([(0.0, 0.0), (0.6, 0.0), (1.2, 0.3), (1.5, 0.9), (1.55, 1.0), (1.4, 1.02), (1.1, 0.6),
                             (0.0, 0.55)], 20), "ferro", T(x, 1, 21.3))
        p.aggiungi(A.sfera(1.2, 0.25, 16, 6), "brace", T(x, 1, 21.85))
        p.punto("fuoco", (x, 1, 22.6))
    p.punto("centro", (0, 0, zc))
    return p


# Cartello -------------------------------------------------------------------------------------------

@oggetto("Cartello", ampio=30, centro_v=0)
def cartello():
    """Insegna 26 x 7: tavola scura, cornice d'oro con le rosette agli angoli, cresta in cima.
    Origine al centro della tavola; la faccia scritta guarda -Y (la scritta la mette il gioco)."""
    p = P("Cartello")
    L, H = 26.0, 7.0
    p.aggiungi(A.scatola((L, 0.6, H), 0.12), "legno_scuro")
    for s in (-1, 1):
        p.aggiungi(A.scatola((L + 0.8, 0.8, 0.45), 0.14), "oro", T(0, 0, s * (H / 2 + 0.05)))
        p.aggiungi(A.scatola((0.45, 0.8, H + 0.5), 0.14), "oro", T(s * (L / 2 + 0.05), 0, 0))
        for z in (-1, 1):
            p.aggiungi(A.sfera(0.5, 0.5), "oro", T(s * (L / 2 + 0.05), -0.35, z * (H / 2 + 0.05)) @ DAVANTI)
    cresta = A.prisma([(-1.6, 0.0), (1.6, 0.0), (1.4, 1.2), (0.0, 2.1), (-1.4, 1.2)], -0.2, 0.2, 0.06)
    p.aggiungi(cresta, "oro", T(0, 0, H / 2 + 0.2) @ R("Z", 90))
    for s in (-1, 1):
        p.aggiungi(A.toro(0.7, 0.14, 16, 6, arco=200), "oro", T(s * 2.6, -0.05, H / 2 + 0.7) @ DAVANTI @ R("Z", 90 - s * 70))
    p.punto("scritta", (0, -0.32, 0))
    return p


# Arena: podio e stemmi dei gradi ---------------------------------------------------------------------

@oggetto("Podio", ampio=22, centro_v=2)
def podio():
    """Podio a tre gradini (1 al centro, 2 a sinistra, 3 a destra guardando il davanti -Y). Le cifre le mette
    il gioco sulle facce davanti ("cifra" = centro della faccia di ogni gradino)."""
    p = P("Podio")
    gradini = [(0.0, 4.5, "oro"), (-6.4, 3.0, "lama"), (6.4, 2.0, "bronzo")]
    p.aggiungi(A.scatola((20.4, 7.4, 0.4), 0.1), "pietra_scura", T(0, 0, 0.2))
    for x, h, c in gradini:
        p.aggiungi(A.scatola((6.0, 6.0, h - 0.4), 0.12), "marmo", T(x, 0, 0.4 + (h - 0.4) / 2))
        p.aggiungi(A.scatola((6.3, 6.3, 0.34), 0.1), c, T(x, 0, h - 0.17))
        p.aggiungi(A.scatola((6.1, 6.1, 0.2), 0.06), c, T(x, 0, 0.5))
        p.punto("cifra", (x, -3.02, 0.4 + (h - 0.4) / 2))
    return p


@oggetto("StemmaCornice", ampio=9, centro_v=0)
def stemma_cornice():
    """Cornice di ferro degli stemmi dei gradi, appesa al muro: anello con le borchie e le alette.
    Origine al centro; il davanti guarda -Y. Il disco colorato è StemmaDisco (da tingere)."""
    p = P("StemmaCornice")
    p.aggiungi(A.toro(3.55, 0.32, 48, 10), "ferro", DAVANTI)
    p.aggiungi(A.cilindro(3.6, 0.3, 48, 0.05), "ferro", T(0, 0.3, 0) @ DAVANTI)
    for i in range(12):
        a = i / 12 * 2 * math.pi
        p.aggiungi(A.sfera(0.17, 0.6), "bronzo", T(math.cos(a) * 3.55, -0.3, math.sin(a) * 3.55) @ DAVANTI)
    for s in (-1, 1):
        aletta = A.prisma([(-0.9, 0.0), (0.9, 0.0), (0.5, 1.6), (-0.5, 1.6)], -0.12, 0.12, 0.05)
        p.aggiungi(aletta, "ferro", T(s * 3.7, 0, 0) @ R("Z", 90) @ R("X", -90 * s))
    p.aggiungi(A.scatola((1.6, 0.3, 1.2), 0.08), "ferro", T(0, 0, 4.1))
    p.aggiungi(A.sfera(0.32), "bronzo", T(0, -0.15, 4.75))
    return p


@oggetto("StemmaDisco", ampio=8, centro_v=0)
def stemma_disco():
    p = P("StemmaDisco")
    p.aggiungi(A.cilindro(3.3, 0.5, 48, 0.18), "legno", T(0, -0.15, 0) @ DAVANTI)
    p.aggiungi(A.cilindro(2.2, 0.2, 40, 0.08), "legno", T(0, -0.45, 0) @ DAVANTI)
    return p


# Lampada del Novecento -------------------------------------------------------------------------------

@oggetto("LampadaIndustriale", ampio=4, centro_v=-1.5)
def lampada_industriale():
    """Lampada da officina: stelo, paralume di ferro smaltato, lampadina. Origine in alto (al soffitto)."""
    p = P("LampadaIndustriale")
    p.aggiungi(A.cilindro(0.5, 0.3, 16, 0.06), "ferro", T(0, 0, -0.15))
    p.aggiungi(A.cilindro(0.07, 2.4, 8, 0.0), "ferro", T(0, 0, -1.4))
    p.aggiungi(A.tornio([(0.0, 0.0), (0.3, 0.0), (0.4, -0.3), (1.4, -1.0), (1.55, -1.12), (1.5, -1.18),
                         (1.3, -1.06), (0.32, -0.4), (0.0, -0.36)], 24), "feltro", T(0, 0, -2.6))
    p.aggiungi(A.toro(1.5, 0.05, 24, 6), "ferro", T(0, 0, -3.75))
    p.aggiungi(A.sfera(0.36, 1.2, 12, 8), "cera", T(0, 0, -3.35))
    p.punto("luce", (0, 0, -3.5))
    return p


# Esportazione ---------------------------------------------------------------------------------------

def main():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(USCITA, exist_ok=True)
    img, indici = A.atlante([(n, f()) for n, f in CELLE], os.path.join(USCITA, "atlante.png"))
    INDICI.update(indici)
    mat = A.materiale_atlante(img)
    info = {}
    for nome, (costruisci, ampio, centro_v) in OGGETTI.items():
        pezzo = costruisci()
        tinta = nome in ("StendardoTelo", "StemmaDisco")  # il gioco li colora
        ob = A.finisci(pezzo, None if tinta else mat, ampio=ampio, centro_v=centro_v or 0.0)
        mn, mx = A.ingombro(ob)
        centro = (mn + mx) / 2
        info[nome] = {
            "centro": A.roblox(centro),
            "misure": [abs(x) for x in A.roblox(mx - mn)],
            "triangoli": len(ob.data.polygons),
            "punti": {k: [A.roblox(v) for v in vs] for k, vs in pezzo.punti.items()},
        }
        print(f"{nome}: {len(ob.data.polygons)} triangoli")
    fbx = os.path.join(USCITA, "OggettiLobby.fbx")
    bpy.ops.export_scene.fbx(filepath=fbx, use_selection=False, object_types={"MESH"}, mesh_smooth_type="OFF",
                             path_mode="COPY", embed_textures=True, axis_forward="-Z", axis_up="Y",
                             apply_scale_options="FBX_SCALE_ALL")
    with open(os.path.join(USCITA, "oggetti.json"), "w", encoding="utf-8") as f:
        json.dump(info, f, indent=1)
    if "--anteprime" in a:
        anteprime()


def anteprime():
    """Una foto per oggetto, in fila, per controllare."""
    scena = bpy.context.scene
    scena.render.engine = "BLENDER_EEVEE"
    scena.view_settings.view_transform = "Standard"
    scena.render.resolution_x = 600
    scena.render.resolution_y = 600
    mondo = bpy.data.worlds.new("Mondo")
    scena.world = mondo
    mondo.use_nodes = True
    mondo.node_tree.nodes["Background"].inputs["Color"].default_value = (0.45, 0.48, 0.52, 1)
    sole = bpy.data.objects.new("Sole", bpy.data.lights.new("Sole", "SUN"))
    sole.data.energy = 3.0
    sole.rotation_euler = (math.radians(50), 0, math.radians(-30))
    scena.collection.objects.link(sole)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = 50
    scena.collection.objects.link(cam)
    scena.camera = cam
    oggetti = [o for o in scena.objects if o.type == "MESH"]
    for o in oggetti:
        o.hide_render = True
    cartella = os.path.join(USCITA, "anteprime")
    os.makedirs(cartella, exist_ok=True)
    for o in oggetti:
        o.hide_render = False
        if o.name == "StendardoTelo":
            o.hide_render = True
            continue
        mn, mx = A.ingombro(o)
        c = Vector(((mn + mx) / 2).tolist())
        d = max(mx - mn)
        cam.location = c + Vector((-0.55, -1.0, 0.45)).normalized() * d * 2.4
        cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
        if o.name == "StendardoAsta":
            telo = scena.objects["StendardoTelo"]
            telo.hide_render = False
        scena.render.filepath = os.path.join(cartella, o.name + ".png")
        bpy.ops.render.render(write_still=True)
        o.hide_render = True
        if o.name == "StendardoAsta":
            scena.objects["StendardoTelo"].hide_render = True


main()
