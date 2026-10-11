"""Costruttore di modelli a blocchi (stile personaggi di Roblox) con texture dipinta e ombre "cotte".

Un modello è fatto di scatole (e prismi) saldate alle ossa del gioco. Ogni faccia ha il suo riquadro nella
texture: lo si dipinge con un pittore (funzione che riceve un Pennello per quella faccia), poi si aggiungono
grana, bordi più scuri e un leggero sfumato dall'alto al basso, così i colori non sono piatti e lucidi.

Assi come in Roblox: +Y in alto, il fronte del soldato è -Z, la sua destra è +X. Misure in metri.
"""
import math
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

# Per ogni faccia: (normale, asse u, asse v) in coordinate locali della scatola. u va verso la destra di chi
# guarda la faccia da fuori, v verso il basso dell'immagine (per "sopra" l'alto dell'immagine è il fronte).
FACCE = {
    "fronte": ((0, 0, -1), (-1, 0, 0), (0, -1, 0)),
    "retro": ((0, 0, 1), (1, 0, 0), (0, -1, 0)),
    "destra": ((1, 0, 0), (0, 0, -1), (0, -1, 0)),
    "sinistra": ((-1, 0, 0), (0, 0, 1), (0, -1, 0)),
    "sopra": ((0, 1, 0), (1, 0, 0), (0, 0, 1)),
    "sotto": ((0, -1, 0), (1, 0, 0), (0, 0, -1)),
}


def colore(c):
    if isinstance(c, str):
        c = c.lstrip("#")
        return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4))
    return tuple(int(x) for x in c)


def mescola(a, b, t):
    a, b = colore(a), colore(b)
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def scuro(c, t=0.25):
    return mescola(c, (0, 0, 0), t)


def chiaro(c, t=0.25):
    return mescola(c, (255, 255, 255), t)


class Pennello:
    """Disegna dentro il riquadro di una faccia, in coordinate normalizzate (0-1, v verso il basso)."""

    def __init__(self, img, x0, y0, w, h, larghezza_m, altezza_m):
        self.img, self.x0, self.y0, self.w, self.h = img, x0, y0, w, h
        self.draw = ImageDraw.Draw(img)
        self.lm, self.hm = larghezza_m, altezza_m  # misure vere della faccia (per tratti in metri)
        self.materiale = "stoffa"

    def _xy(self, u, v):
        return self.x0 + u * self.w, self.y0 + v * self.h

    def riempi(self, c, materiale="stoffa"):
        self.materiale = materiale
        self.draw.rectangle([self.x0, self.y0, self.x0 + self.w - 1, self.y0 + self.h - 1], fill=colore(c))

    def rett(self, u0, v0, u1, v1, c):
        a, b = self._xy(u0, v0)
        d, e = self._xy(u1, v1)
        a, d = sorted((a, d))
        b, e = sorted((b, e))
        self.draw.rectangle([round(a), round(b), max(round(a), round(d) - 1), max(round(b), round(e) - 1)], fill=colore(c))

    def banda_v(self, v0, v1, c):
        self.rett(0, v0, 1, v1, c)

    def banda_u(self, u0, u1, c):
        self.rett(u0, 0, u1, 1, c)

    def ellisse(self, u0, v0, u1, v1, c):
        a, b = self._xy(u0, v0)
        d, e = self._xy(u1, v1)
        a, d = sorted((a, d))
        b, e = sorted((b, e))
        self.draw.ellipse([a, b, max(a, d - 1), max(b, e - 1)], fill=colore(c))

    def poligono(self, punti, c):
        self.draw.polygon([self._xy(u, v) for u, v in punti], fill=colore(c))

    def linea(self, punti, c, spessore_m=0.01):
        larghezza = max(1, round(spessore_m * self.w / max(self.lm, 1e-6)))
        self.draw.line([self._xy(u, v) for u, v in punti], fill=colore(c), width=larghezza)

    def righe_v(self, n, c, spessore=0.04, v0=0, v1=1):
        """n righe orizzontali (placche, cuciture) tra v0 e v1."""
        for i in range(1, n + 1):
            v = v0 + (v1 - v0) * i / (n + 1)
            self.rett(0, v - spessore / 2, 1, v + spessore / 2, c)

    def maglia(self, c_chiaro, c_scuro, passo_m=0.025):
        """Cotta di maglia: anellini sfalsati."""
        px = max(2, round(passo_m * self.w / max(self.lm, 1e-6)))
        for j, y in enumerate(range(self.y0, self.y0 + self.h, px)):
            for x in range(self.x0 + (j % 2) * px // 2, self.x0 + self.w, px):
                self.draw.ellipse([x, y, x + px - 1, y + px - 1], outline=colore(c_scuro))
                self.draw.point((x + px // 3, y + px // 3), fill=colore(c_chiaro))


class Modello:
    def __init__(self, nome, lato=512):
        self.nome = nome
        self.lato = lato
        self.ossa = []  # {nome, padre, posizione}
        self.indice_ossa = {}
        self.scatole = []  # da impacchettare e dipingere alla fine
        self.vertici_extra = None  # geometria già pronta (es. il cavallo), aggiunta così com'è
        self.altezza_utile = lato  # righe dell'atlante per le scatole (sotto può starci altro, es. il cavallo)

    def osso(self, nome, padre, posizione):
        self.indice_ossa[nome] = len(self.ossa)
        self.ossa.append({"nome": nome, "padre": padre, "posizione": [float(x) for x in posizione]})

    def posizione_osso(self, nome):
        return np.array(self.ossa[self.indice_ossa[nome]]["posizione"])

    def scatola(self, osso, centro, misure, pittori, assi=None, pesi=None, ombra=1.0, smussa=False):
        """Scatola di "misure" (larghezza x, altezza y, profondità z) centrata in "centro", ruotata con "assi"
        (matrice 3x3, colonne = assi locali x, y, z nel modello). pittori: dict faccia -> funzione(pennello),
        con la chiave "tutte" per le facce non indicate. pesi: [(osso, peso)] al posto del solo "osso"."""
        self.scatole.append({
            "osso": osso, "pesi": pesi, "centro": np.array(centro, dtype=float), "misure": np.array(misure, dtype=float),
            "assi": np.eye(3) if assi is None else np.array(assi, dtype=float), "pittori": pittori, "ombra": ombra,
        })

    def segmento(self, osso, da, a, larghezza, profondita, pittori, oltre=(0.0, 0.0), alto=None, **kw):
        """Scatola lungo il tratto da -> a (asse locale y da a verso da): per braccia, gambe, aste."""
        da, a = np.array(da, float), np.array(a, float)
        asse_y = da - a
        lunghezza = np.linalg.norm(asse_y)
        asse_y = asse_y / lunghezza
        riferimento = np.array(alto if alto is not None else (0, 0, -1), float)
        asse_x = np.cross(asse_y, riferimento)
        if np.linalg.norm(asse_x) < 1e-6:
            asse_x = np.cross(asse_y, np.array([1.0, 0, 0]))
        asse_x /= np.linalg.norm(asse_x)
        asse_z = np.cross(asse_x, asse_y)
        # Il fronte della scatola (-z) guarda verso "riferimento".
        if np.dot(-asse_z, riferimento) < 0:
            asse_x, asse_z = -asse_x, -asse_z
        totale = lunghezza + oltre[0] + oltre[1]
        centro = a - asse_y * oltre[1] + asse_y * totale / 2
        self.scatola(osso, centro, (larghezza, totale, profondita), pittori, assi=np.column_stack([asse_x, asse_y, asse_z]), **kw)

    # -- Costruzione finale -----------------------------------------------------------------------------

    def _impacchetta(self, px_m):
        """Riquadri delle facce in righe (scaffali), dal più alto al più basso. Restituisce la lista o None."""
        richieste = []
        for i, s in enumerate(self.scatole):
            w, h, d = s["misure"]
            dims = {"fronte": (w, h), "retro": (w, h), "destra": (d, h), "sinistra": (d, h), "sopra": (w, d), "sotto": (w, d)}
            for faccia, (fu, fv) in dims.items():
                pw, ph = max(4, math.ceil(fu * px_m)), max(4, math.ceil(fv * px_m))
                richieste.append((i, faccia, pw, ph, fu, fv))
        richieste.sort(key=lambda r: -r[3])
        x = y = riga = 0
        posti = []
        for r in richieste:
            pw, ph = r[2] + 2, r[3] + 2
            if x + pw > self.lato:
                x, y, riga = 0, y + riga, 0
            if y + ph > self.altezza_utile or pw > self.lato:
                return None
            posti.append((r, x + 1, y + 1))
            x += pw
            riga = max(riga, ph)
        return posti

    def costruisci(self, seme=1):
        rng = random.Random(seme)
        px_m = 260.0
        posti = self._impacchetta(px_m)
        while posti is None:
            px_m *= 0.94
            posti = self._impacchetta(px_m)
        img = Image.new("RGB", (self.lato, self.lato), (128, 128, 128))
        maschere = []  # (x, y, w, h, materiale, ombra, faccia)
        for (i, faccia, pw, ph, fu, fv), x, y in posti:
            s = self.scatole[i]
            pittore = s["pittori"].get(faccia) or s["pittori"].get("tutte")
            pennello = Pennello(img, x, y, pw, ph, fu, fv)
            pennello.faccia = faccia
            if callable(pittore):
                pittore(pennello)
            elif pittore is not None:
                pennello.riempi(pittore)
            maschere.append((x, y, pw, ph, pennello.materiale, s["ombra"], faccia))
        img = self._ombre(img, maschere, rng)

        pos, uv, nor, ossa_v, pesi, tri = [], [], [], [], [], []
        posto = {(r[0], r[1]): (x, y, r[2], r[3]) for r, x, y in posti}
        for i, s in enumerate(self.scatole):
            meta = s["misure"] / 2
            A = s["assi"]
            if s["pesi"]:
                indici = [self.indice_ossa[o] for o, _ in s["pesi"]][:4]
                valori = [p for _, p in s["pesi"]][:4]
            else:
                indici, valori = [self.indice_ossa[s["osso"]]], [1.0]
            indici += [0] * (4 - len(indici))
            valori += [0.0] * (4 - len(valori))
            for faccia, (n, au, av) in FACCE.items():
                x, y, pw, ph = posto[(i, faccia)]
                n, au, av = np.array(n, float), np.array(au, float), np.array(av, float)
                centro_f = n * meta
                eu = np.abs(au) @ meta
                ev = np.abs(av) @ meta
                base = len(pos)
                for (su, sv) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                    locale = centro_f + au * eu * su + av * ev * sv
                    pos.append(s["centro"] + A @ locale)
                    nor.append(A @ n)
                    # uv: u da sinistra a destra, v dall'alto in basso dell'immagine (come in Roblox).
                    uu = (x + (su + 1) / 2 * pw) / self.lato
                    vv = (y + (sv + 1) / 2 * ph) / self.lato
                    # mezzo pixel dentro, per non prendere il colore del vicino
                    uu = min(max(uu, (x + 0.5) / self.lato), (x + pw - 0.5) / self.lato)
                    vv = min(max(vv, (y + 0.5) / self.lato), (y + ph - 0.5) / self.lato)
                    uv.append((uu, vv))
                    ossa_v.append(indici)
                    pesi.append(valori)
                # Triangoli con la normale verso fuori (senso antiorario visto da fuori, come in Roblox).
                a, b, c, d = base, base + 1, base + 2, base + 3
                if np.dot(np.cross(pos[b] - pos[a], pos[c] - pos[a]), A @ n) > 0:
                    tri += [(a, b, c), (a, c, d)]
                else:
                    tri += [(a, c, b), (a, d, c)]
        m = {
            "pos": np.array(pos), "uv": np.array(uv), "normali": np.array(nor), "ossa_v": np.array(ossa_v),
            "pesi": np.array(pesi), "triangoli": np.array(tri), "texture": img, "ossa": self.ossa,
        }
        if self.vertici_extra is not None:
            m = unisci(m, self.vertici_extra)
        return m

    def _ombre(self, img, maschere, rng):
        """Grana del materiale, bordi più scuri (come l'occlusione negli spigoli) e sfumato verticale."""
        a = np.asarray(img).astype(np.float32)
        rumore = np.asarray(Image.effect_noise((self.lato, self.lato), 40).filter(ImageFilter.GaussianBlur(0.6))).astype(np.float32) / 255.0 - 0.5
        rumore_largo = np.asarray(Image.effect_noise((self.lato, self.lato), 60).filter(ImageFilter.GaussianBlur(3))).astype(np.float32) / 255.0 - 0.5
        for x, y, w, h, materiale, ombra, faccia in maschere:
            blocco = a[y:y + h, x:x + w]
            vv = np.linspace(0, 1, h)[:, None]
            uu = np.linspace(0, 1, w)[None, :]
            bordo = np.minimum(np.minimum(uu, 1 - uu) * w, np.minimum(vv, 1 - vv) * h)
            occlusione = 1 - 0.22 * ombra * np.exp(-bordo / 3.0)
            if faccia in ("sopra",):
                verticale = np.ones_like(vv) * 1.04
            elif faccia == "sotto":
                verticale = np.ones_like(vv) * 0.72
            else:
                verticale = 1.03 - 0.16 * ombra * vv
            grana = {"stoffa": 0.10, "pelle": 0.04, "metallo": 0.07, "legno": 0.14, "cuoio": 0.10, "liscio": 0.03}.get(materiale, 0.08)
            fattore = occlusione * verticale * (1 + grana * rumore[y:y + h, x:x + w] + grana * 0.8 * rumore_largo[y:y + h, x:x + w])
            if materiale == "metallo":
                # Riflesso morbido in alto, come una lama di luce sul ferro opaco.
                fattore = fattore * (1 + 0.12 * np.exp(-((vv - 0.22) ** 2) / 0.02))
            if materiale == "legno":
                venature = 0.06 * np.sin(uu * 40 + 3 * np.sin(vv * 7)) * np.ones_like(vv)
                fattore = fattore * (1 + venature)
            a[y:y + h, x:x + w] = blocco * fattore[..., None]
        return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def unisci(m1, m2):
    """Mette insieme due modelli già costruiti con le stesse ossa e uv nello stesso atlante (la texture è di m1)."""
    n = len(m1["pos"])
    out = dict(m1)
    for k in ("pos", "uv", "normali", "ossa_v", "pesi"):
        out[k] = np.concatenate([m1[k], m2[k]])
    out["triangoli"] = np.concatenate([m1["triangoli"], m2["triangoli"] + n])
    return out
