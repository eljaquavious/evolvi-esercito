# Icone dello shop nello stile delle altre icone (contorno scuro spesso, sfumature, riflessi):
# casse delle truppe, casse dell'armeria, pacchetti di monete, Robux, feedback, inbox.
# Scrive assets/gui/<nome>.png (512x512, sfondo trasparente). Poi: .\tools\carica-immagini.ps1 -UserId ...
#
# Uso: python tools/icone_shop.py   (Python di Blender con PYTHONPATH=%LOCALAPPDATA%\evolvi-pylib per Pillow)

import math
import os

from PIL import Image, ImageDraw, ImageFilter

S = 1024  # si disegna al doppio e si rimpicciolisce: bordi lisci
OUT = 512
CONTORNO = (27, 22, 54, 255)
SPESSO = 34
CARTELLA = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "gui")


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def nuova():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def sfumatura(img, forma_maschera, alto, basso, y0=None, y1=None):
    """Riempie la maschera con una sfumatura verticale da alto a basso."""
    bbox = forma_maschera.getbbox()
    if not bbox:
        return
    y0 = bbox[1] if y0 is None else y0
    y1 = bbox[3] if y1 is None else y1
    grad = Image.new("RGBA", (S, S))
    gd = ImageDraw.Draw(grad)
    for y in range(S):
        t = min(1, max(0, (y - y0) / max(1, (y1 - y0))))
        c = tuple(int(alto[i] + (basso[i] - alto[i]) * t) for i in range(4))
        gd.line([(0, y), (S, y)], fill=c)
    img.alpha_composite(Image.composite(grad, Image.new("RGBA", (S, S)), forma_maschera))


def maschera_poligono(punti):
    m = Image.new("L", (S, S), 0)
    ImageDraw.Draw(m).polygon(punti, fill=255)
    return m


def maschera_rett(x0, y0, x1, y1, r):
    m = Image.new("L", (S, S), 0)
    ImageDraw.Draw(m).rounded_rectangle([x0, y0, x1, y1], r, fill=255)
    return m


def maschera_ellisse(x0, y0, x1, y1):
    m = Image.new("L", (S, S), 0)
    ImageDraw.Draw(m).ellipse([x0, y0, x1, y1], fill=255)
    return m


def contorno(img, maschera, spessore=SPESSO):
    """Contorno scuro attorno alla maschera (dilatata) disegnato SOTTO quello che c'è."""
    dil = maschera.filter(ImageFilter.MaxFilter(spessore // 2 * 2 + 1))
    sotto = Image.new("RGBA", (S, S))
    sotto.paste(Image.new("RGBA", (S, S), CONTORNO), (0, 0), dil)
    sotto.alpha_composite(img)
    return sotto


def linea(d, punti, larghezza, colore=CONTORNO):
    d.line(punti, fill=colore, width=larghezza, joint="curve")
    for p in (punti[0], punti[-1]):
        r = larghezza / 2
        d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=colore)


def unisci_maschere(*ms):
    out = Image.new("L", (S, S), 0)
    for m in ms:
        out = Image.fromarray(__import__("numpy").maximum(__import__("numpy").array(out), __import__("numpy").array(m)))
    return out


def alone(img, colore, raggio=380, centro=(512, 540)):
    a = Image.new("RGBA", (S, S))
    d = ImageDraw.Draw(a)
    d.ellipse([centro[0] - raggio, centro[1] - raggio, centro[0] + raggio, centro[1] + raggio], fill=colore)
    a = a.filter(ImageFilter.GaussianBlur(70))
    a.alpha_composite(img)
    return a


def scintilla(d, x, y, r, colore=(255, 255, 255, 255)):
    punti = []
    for i in range(8):
        ang = i * math.pi / 4 - math.pi / 2
        rr = r if i % 2 == 0 else r * 0.28
        punti.append((x + math.cos(ang) * rr, y + math.sin(ang) * rr))
    d.polygon(punti, fill=colore)


def velo(img, disegna):
    """Disegna su un livello a parte e lo sovrappone: le parti semitrasparenti si mescolano invece di bucare."""
    livello = Image.new("RGBA", (S, S))
    disegna(ImageDraw.Draw(livello))
    img.alpha_composite(livello)


def salva(img, nome):
    img = img.resize((OUT, OUT), Image.LANCZOS)
    img.save(os.path.join(CARTELLA, nome + ".png"))
    print("scritta", nome)


# ------------------------------------------------------------------ casse di legno (truppe)

def cassa_legno(nome, legno_alto, legno_basso, legno_lato, fasce, fasce_scure, emblema=None, borchie=True, bagliore=None):
    img = nuova()
    # Cassa in prospettiva: davanti, coperchio sopra, fianco a destra.
    fx0, fy0, fx1, fy1 = 170, 400, 720, 900
    prof = 150
    davanti = [(fx0, fy0), (fx1, fy0), (fx1, fy1), (fx0, fy1)]
    sopra = [(fx0, fy0), (fx0 + prof, fy0 - 120), (fx1 + prof, fy0 - 120), (fx1, fy0)]
    lato = [(fx1, fy0), (fx1 + prof, fy0 - 120), (fx1 + prof, fy1 - 120), (fx1, fy1)]
    md, ms, ml = maschera_poligono(davanti), maschera_poligono(sopra), maschera_poligono(lato)
    sfumatura(img, md, legno_alto, legno_basso)
    sfumatura(img, ms, tuple(min(255, c + 30) if i < 3 else 255 for i, c in enumerate(legno_alto)), legno_alto)
    sfumatura(img, ml, legno_lato, tuple(int(c * 0.75) if i < 3 else 255 for i, c in enumerate(legno_lato)))
    d = ImageDraw.Draw(img)
    # Assi del davanti.
    for i in range(1, 4):
        y = fy0 + (fy1 - fy0) * i / 4
        d.line([(fx0, y), (fx1, y)], fill=tuple(int(c * 0.72) if j < 3 else 255 for j, c in enumerate(legno_basso)), width=10)
    for i in range(1, 3):
        y0 = fy0 + (fy1 - fy0) * i / 3 - 60
        d.line([(fx1 + 8, y0), (fx1 + prof - 8, y0 - 120)], fill=tuple(int(c * 0.7) if j < 3 else 255 for j, c in enumerate(legno_lato)), width=9)
    # Fasce di metallo verticali e bordo.
    for x in (fx0 + 70, fx1 - 70):
        m = maschera_rett(x - 34, fy0 - 4, x + 34, fy1 + 4, 8)
        sfumatura(img, m, fasce, fasce_scure)
        d.line([(x - 34, fy0), (x - 34, fy1)], fill=CONTORNO, width=10)
        d.line([(x + 34, fy0), (x + 34, fy1)], fill=CONTORNO, width=10)
        if borchie:
            for y in (fy0 + 60, (fy0 + fy1) / 2, fy1 - 60):
                d.ellipse([x - 13, y - 13, x + 13, y + 13], fill=fasce_scure, outline=CONTORNO, width=6)
    # Fascia orizzontale del coperchio.
    m = maschera_poligono([(fx0, fy0), (fx1, fy0), (fx1, fy0 + 64), (fx0, fy0 + 64)])
    sfumatura(img, m, fasce, fasce_scure)
    d.line([(fx0, fy0 + 64), (fx1, fy0 + 64)], fill=CONTORNO, width=12)
    # Spigoli.
    for p in ([davanti[0], davanti[1]], [sopra[1], sopra[2]], [sopra[0], sopra[1]], [sopra[2], lato[2]], [lato[0], lato[1]]):
        d.line(p, fill=CONTORNO, width=14)
    # Riflesso sul coperchio.
    velo(img, lambda v: v.polygon([(fx0 + 60, fy0 - 20), (fx0 + 100, fy0 - 50), (fx0 + 330, fy0 - 50), (fx0 + 290, fy0 - 20)], fill=(255, 255, 255, 110)))
    if emblema:
        emblema(img, (fx0 + fx1) / 2, (fy0 + 64 + fy1) / 2 + 10)
    tutto = Image.fromarray(__import__("numpy").maximum(__import__("numpy").maximum(__import__("numpy").array(md), __import__("numpy").array(ms)), __import__("numpy").array(ml)))
    img = contorno(img, tutto)
    if bagliore:
        img = alone(img, bagliore)
    d = ImageDraw.Draw(img)
    scintilla(d, 880, 300, 60)
    scintilla(d, 130, 330, 34)
    salva(img, nome)


def emblema_spade(colore_a, colore_b):
    def disegna(img, cx, cy):
        d = ImageDraw.Draw(img)
        r = 120
        m = maschera_ellisse(cx - r, cy - r, cx + r, cy + r)
        sfumatura(img, m, colore_a, colore_b)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=CONTORNO, width=14)
        for s in (-1, 1):
            linea(d, [(cx - s * 70, cy + 70), (cx + s * 70, cy - 70)], 30)
            linea(d, [(cx - s * 70, cy + 70), (cx + s * 70, cy - 70)], 14, (240, 244, 255, 255))
            linea(d, [(cx - s * 40 - 22, cy + 40 - s * 22 * -1), (cx - s * 40 + 22, cy + 40 + s * 22 * -1)], 16)
    return disegna


def emblema_stella(colore_a, colore_b):
    def disegna(img, cx, cy):
        d = ImageDraw.Draw(img)
        r = 130
        punti = []
        for i in range(10):
            ang = i * math.pi / 5 - math.pi / 2
            rr = r if i % 2 == 0 else r * 0.45
            punti.append((cx + math.cos(ang) * rr, cy + math.sin(ang) * rr))
        m = maschera_poligono(punti)
        sfumatura(img, m, colore_a, colore_b)
        d.polygon(punti, outline=CONTORNO, width=14)
    return disegna


# ------------------------------------------------------------------ scrigni (armeria)

def scrigno(nome, corpo_a, corpo_b, fasce_a, fasce_b, extra=None, bagliore=None):
    img = nuova()
    x0, x1 = 150, 874
    ybase, ycop = 470, 300
    mcop = Image.new("L", (S, S), 0)
    dm = ImageDraw.Draw(mcop)
    dm.rounded_rectangle([x0, ycop, x1, ybase + 40], 120, fill=255)
    dm.rectangle([x0, ybase - 40, x1, ybase + 40], fill=255)
    mcorpo = maschera_rett(x0 + 20, ybase, x1 - 20, 880, 40)
    sfumatura(img, mcorpo, corpo_a, corpo_b)
    sfumatura(img, mcop, tuple(min(255, c + 25) if i < 3 else 255 for i, c in enumerate(corpo_a)), corpo_b)
    d = ImageDraw.Draw(img)
    # Assi del corpo.
    for y in (600, 730):
        d.line([(x0 + 40, y), (x1 - 40, y)], fill=tuple(int(c * 0.7) if i < 3 else 160 for i, c in enumerate(corpo_b)), width=10)
    # Fasce verticali.
    for x in (x0 + 110, x1 - 110):
        m = maschera_rett(x - 40, ycop + 10, x + 40, 880, 10)
        sfumatura(img, m, fasce_a, fasce_b)
        d.rounded_rectangle([x - 40, ycop + 10, x + 40, 880], 10, outline=CONTORNO, width=12)
    # Fascia del bordo del coperchio.
    m = maschera_rett(x0 - 10, ybase - 20, x1 + 10, ybase + 50, 14)
    sfumatura(img, m, fasce_a, fasce_b)
    d.rounded_rectangle([x0 - 10, ybase - 20, x1 + 10, ybase + 50], 14, outline=CONTORNO, width=12)
    # Serratura.
    m = maschera_rett(442, ybase - 30, 582, ybase + 150, 28)
    sfumatura(img, m, fasce_a, fasce_b)
    d.rounded_rectangle([442, ybase - 30, 582, ybase + 150], 28, outline=CONTORNO, width=14)
    d.ellipse([490, ybase + 20, 534, ybase + 64], fill=CONTORNO)
    d.polygon([(500, ybase + 50), (524, ybase + 50), (532, ybase + 110), (492, ybase + 110)], fill=CONTORNO)
    # Riflesso sul coperchio.
    velo(img, lambda v: v.rounded_rectangle([x0 + 150, ycop + 30, x1 - 280, ycop + 80], 25, fill=(255, 255, 255, 120)))
    if extra:
        extra(img)
    tutto = Image.fromarray(__import__("numpy").maximum(__import__("numpy").array(mcop), __import__("numpy").array(mcorpo)))
    img = contorno(img, tutto)
    if bagliore:
        img = alone(img, bagliore)
    d = ImageDraw.Draw(img)
    scintilla(d, 890, 260, 60)
    scintilla(d, 120, 380, 36)
    salva(img, nome)


def linee_neon(img):
    """Linee luminose fantascientifiche sul corpo dello scrigno nero."""
    luce = Image.new("RGBA", (S, S))
    d = ImageDraw.Draw(luce)
    for pts, c in (
        ([(200, 640), (330, 640), (380, 700), (420, 700)], "#36E8FF"),
        ([(824, 640), (694, 640), (644, 700), (604, 700)], "#36E8FF"),
        ([(200, 800), (300, 800), (340, 760)], "#FF4FD8"),
        ([(824, 800), (724, 800), (684, 760)], "#FF4FD8"),
        ([(260, 380), (420, 380)], "#FF4FD8"),
        ([(604, 380), (764, 380)], "#36E8FF"),
    ):
        d.line(pts, fill=hexc(c), width=16, joint="curve")
    alone_l = luce.filter(ImageFilter.GaussianBlur(14))
    img.alpha_composite(alone_l)
    img.alpha_composite(alone_l)
    img.alpha_composite(luce)
    d = ImageDraw.Draw(img)
    for pts in (
        [(200, 640), (330, 640), (380, 700), (420, 700)],
        [(824, 640), (694, 640), (644, 700), (604, 700)],
    ):
        d.line(pts, fill=(255, 255, 255, 220), width=5, joint="curve")


# ------------------------------------------------------------------ monete

def moneta(img, cx, cy, r=110, spessore=34):
    d = ImageDraw.Draw(img)
    # Bordo (lato della moneta) e faccia.
    m = maschera_ellisse(cx - r, cy - r * 0.45 + spessore * 0.4, cx + r, cy + r * 0.45 + spessore)
    sfumatura(img, m, hexc("#E89A12"), hexc("#A85A00"))
    d.ellipse([cx - r, cy - r * 0.45 + spessore * 0.4, cx + r, cy + r * 0.45 + spessore], outline=CONTORNO, width=12)
    m = maschera_ellisse(cx - r, cy - r * 0.45, cx + r, cy + r * 0.45)
    sfumatura(img, m, hexc("#FFF06A"), hexc("#FFB31F"))
    d.ellipse([cx - r, cy - r * 0.45, cx + r, cy + r * 0.45], outline=CONTORNO, width=12)
    d.ellipse([cx - r * 0.62, cy - r * 0.28, cx + r * 0.62, cy + r * 0.28], outline=hexc("#E08A00"), width=9)
    velo(img, lambda v: v.ellipse([cx - r * 0.5, cy - r * 0.32, cx - r * 0.1, cy - r * 0.18], fill=(255, 255, 255, 170)))


def pila(img, cx, base, n, r=150):
    for i in range(n):
        moneta(img, cx, base - i * 50, r, 44)


def monete(nome, disegna, bagliore=hexc("#FFD23F", 110)):
    img = nuova()
    disegna(img)
    img = alone(img, bagliore, 300)
    d = ImageDraw.Draw(img)
    scintilla(d, 860, 250, 56)
    scintilla(d, 170, 300, 34)
    salva(img, nome)


def sacco(img):
    m = Image.new("L", (S, S), 0)
    dm = ImageDraw.Draw(m)
    dm.ellipse([250, 400, 774, 900], fill=255)
    dm.polygon([(400, 430), (624, 430), (580, 330), (444, 330)], fill=255)
    sfumatura(img, m, hexc("#C98A4E"), hexc("#7A4A22"))
    d = ImageDraw.Draw(img)
    d.polygon([(400, 430), (624, 430), (580, 330), (444, 330)], outline=CONTORNO, width=16)
    d.ellipse([250, 400, 774, 900], outline=CONTORNO, width=16)
    d.rounded_rectangle([390, 410, 634, 470], 24, fill=hexc("#5A3518"), outline=CONTORNO, width=12)
    velo(img, lambda v: v.ellipse([320, 470, 470, 620], fill=(255, 255, 255, 70)))
    # Moneta con la stella sul sacco.
    cx, cy, r = 512, 680, 96
    ImageDraw.Draw(img).ellipse([cx - r, cy - r, cx + r, cy + r], fill=hexc("#FFD23F"), outline=CONTORNO, width=14)
    punti = []
    for k in range(10):
        ang = k * math.pi / 5 - math.pi / 2
        rr = 58 if k % 2 == 0 else 26
        punti.append((cx + math.cos(ang) * rr, cy + math.sin(ang) * rr))
    ImageDraw.Draw(img).polygon(punti, fill=hexc("#FFA51F"), outline=CONTORNO, width=8)
    for (x, y) in ((420, 320), (520, 290), (610, 325)):
        moneta(img, x, y, 76, 24)
    return m


def forziere_aperto(img, quante, gemme=False):
    colori = (hexc("#FF6B6B"), hexc("#B01428"), hexc("#E5313E"), hexc("#7A0E20")) if gemme else (hexc("#4FA3FF"), hexc("#1D4FB8"), hexc("#3E8CF0"), hexc("#163E99"))
    # Coperchio aperto dietro.
    m = maschera_poligono([(190, 470), (834, 470), (800, 230), (224, 230)])
    sfumatura(img, m, colori[0], colori[1])
    d = ImageDraw.Draw(img)
    d.polygon([(190, 470), (834, 470), (800, 230), (224, 230)], outline=CONTORNO, width=16)
    for x in (320, 704):
        d.polygon([(x - 34, 470), (x + 34, 470), (x + 30, 230), (x - 30, 230)], fill=hexc("#FFC233"), outline=CONTORNO, width=10)
    # Monete che escono.
    for i in range(quante):
        ang = i / max(1, quante) * math.pi
        x = 512 + math.cos(ang) * 230 * (0.4 + (i % 3) * 0.3)
        y = 470 - math.sin(ang) * 60 - (i % 2) * 40
        moneta(img, x, y, 80, 24)
    if gemme:
        for (x, y, c) in ((380, 420, "#36E8FF"), (640, 400, "#FF4FD8"), (520, 360, "#7CF56E")):
            punti = [(x, y - 50), (x + 40, y), (x, y + 50), (x - 40, y)]
            d.polygon(punti, fill=hexc(c), outline=CONTORNO, width=10)
            velo(img, lambda v, x=x, y=y: v.polygon([(x, y - 50), (x + 14, y), (x, y + 10), (x - 14, y)], fill=(255, 255, 255, 140)))
    # Corpo davanti.
    m = maschera_rett(170, 470, 854, 880, 40)
    sfumatura(img, m, colori[2], colori[3])
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([170, 470, 854, 880], 40, outline=CONTORNO, width=16)
    for x in (320, 704):
        d.rounded_rectangle([x - 40, 470, x + 40, 880], 10, fill=hexc("#FFC233"), outline=CONTORNO, width=12)
    d.rounded_rectangle([160, 460, 864, 530], 16, fill=hexc("#FFC233"), outline=CONTORNO, width=12)
    d.rounded_rectangle([452, 520, 572, 660], 24, fill=hexc("#FFD860"), outline=CONTORNO, width=12)
    d.ellipse([496, 560, 528, 592], fill=CONTORNO)


# ------------------------------------------------------------------ altre

def robux():
    img = nuova()
    cx, cy, r = 512, 512, 400
    esagono = [(cx + math.cos(math.pi / 6 + i * math.pi / 3) * r, cy + math.sin(math.pi / 6 + i * math.pi / 3) * r) for i in range(6)]
    m = maschera_poligono(esagono)
    sfumatura(img, m, hexc("#FFFFFF"), hexc("#D8E2F2"))
    d = ImageDraw.Draw(img)
    interno = [(cx + math.cos(math.pi / 6 + i * math.pi / 3) * r * 0.62, cy + math.sin(math.pi / 6 + i * math.pi / 3) * r * 0.62) for i in range(6)]
    d.polygon(interno, fill=CONTORNO)
    d.rounded_rectangle([cx - 105, cy - 105, cx + 105, cy + 105], 22, fill=hexc("#FFFFFF"))
    img = contorno(img, m, 70)
    salva(img, "robux")


def feedback():
    img = nuova()
    m = Image.new("L", (S, S), 0)
    dm = ImageDraw.Draw(m)
    dm.rounded_rectangle([130, 170, 894, 700], 150, fill=255)
    dm.polygon([(280, 640), (460, 690), (230, 880)], fill=255)
    sfumatura(img, m, hexc("#5CF2E0"), hexc("#13A0C9"))
    d = ImageDraw.Draw(img)
    velo(img, lambda v: v.rounded_rectangle([210, 210, 700, 270], 30, fill=(255, 255, 255, 120)))
    # Tre stelle dentro il fumetto.
    for i, x in enumerate((330, 512, 694)):
        r = 95 if i == 1 else 80
        punti = []
        for k in range(10):
            ang = k * math.pi / 5 - math.pi / 2
            rr = r if k % 2 == 0 else r * 0.45
            punti.append((x + math.cos(ang) * rr, 440 + math.sin(ang) * rr))
        ms = maschera_poligono(punti)
        sfumatura(img, ms, hexc("#FFF06A"), hexc("#FFA51F"))
        d.polygon(punti, outline=CONTORNO, width=12)
    img = contorno(img, m)
    d = ImageDraw.Draw(img)
    scintilla(d, 880, 160, 56)
    salva(img, "feedback")


def inbox():
    img = nuova()
    # Busta.
    m = maschera_rett(220, 200, 804, 600, 30)
    sfumatura(img, m, hexc("#FFFFFF"), hexc("#D8E2F2"))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([220, 200, 804, 600], 30, outline=CONTORNO, width=16)
    d.line([(236, 220), (512, 430), (788, 220)], fill=CONTORNO, width=16, joint="curve")
    # Vassoio davanti.
    mv = maschera_poligono([(120, 520), (904, 520), (860, 880), (164, 880)])
    sfumatura(img, mv, hexc("#FFE45C"), hexc("#FF8A1F"))
    d = ImageDraw.Draw(img)
    d.polygon([(120, 520), (904, 520), (860, 880), (164, 880)], outline=CONTORNO, width=16)
    d.polygon([(330, 520), (694, 520), (640, 640), (384, 640)], fill=hexc("#E07A10"), outline=CONTORNO, width=12)
    img = contorno(img, Image.fromarray(__import__("numpy").maximum(__import__("numpy").array(m), __import__("numpy").array(mv))))
    salva(img, "inbox")


def main():
    legno = (hexc("#E8B070"), hexc("#B0703A"), hexc("#8A5428"))
    cassa_legno("crate_small", *legno, hexc("#C9CED8"), hexc("#7E8796"), borchie=True)
    cassa_legno("crate_medium", hexc("#C98A4E"), hexc("#86501F"), hexc("#6A3C16"), hexc("#8FD2FF"), hexc("#2C6FD0"),
                emblema=emblema_spade(hexc("#5CC8FF"), hexc("#1E5FC0")), bagliore=hexc("#5CC8FF", 90))
    cassa_legno("crate_big", hexc("#E5414E"), hexc("#9B1328"), hexc("#7A0E20"), hexc("#FFE45C"), hexc("#E58A00"),
                emblema=emblema_stella(hexc("#FFF06A"), hexc("#FFA51F")), bagliore=hexc("#FFD23F", 130))
    scrigno("chest_small", hexc("#5CF2E0"), hexc("#0F8FA8"), hexc("#E6ECF5"), hexc("#8E9AAE"))
    scrigno("chest_medium", hexc("#C77DFF"), hexc("#5A1BA8"), hexc("#FFE45C"), hexc("#E58A00"), bagliore=hexc("#C77DFF", 110))
    scrigno("chest_big", hexc("#3A2E66"), hexc("#120C2A"), hexc("#FF8AD8"), hexc("#B0127A"), extra=linee_neon, bagliore=hexc("#FF4FD8", 120))
    monete("coins_1", lambda img: pila(img, 512, 700, 4, 190))
    monete("coins_2", lambda img: (pila(img, 360, 760, 4), pila(img, 650, 740, 7)))
    monete("coins_3", lambda img: (pila(img, 280, 790, 4), pila(img, 744, 790, 5), pila(img, 512, 840, 8)))
    monete("coins_4", sacco)
    monete("coins_5", lambda img: forziere_aperto(img, 7))
    monete("coins_6", lambda img: forziere_aperto(img, 11, gemme=True), hexc("#FF8AD8", 120))
    robux()
    feedback()
    inbox()


# ------------------------------------------------------------------ stemmi dei gradi della ranked (Config/Gradi)

def scudo_punti(cx, cy, w, h):
    """Scudo a punta: lati dritti in alto, curva fino alla punta in basso."""
    pts = []
    for i in range(0, 21):
        t = i / 20
        x = cx - w / 2 + w * t
        pts.append((x, cy - h / 2 + 30 * math.sin(math.pi * t) * -1 + 30))
    for i in range(0, 31):
        t = i / 30
        a = math.pi * t
        x = cx + (w / 2) * math.cos(a)
        y = cy + h * 0.05 + (h * 0.45) * math.sin(a) ** 0.9 * (1 + 0.35 * math.sin(a))
        pts.append((x, min(y, cy + h / 2)))
    return pts


def gemma(img, cx, cy, r, alto, basso, facce=6):
    pts = [(cx + r * math.cos(math.pi / 2 + 2 * math.pi * k / facce), cy - r * math.sin(math.pi / 2 + 2 * math.pi * k / facce)) for k in range(facce)]
    m = maschera_poligono(pts)
    sfumatura(img, m, alto, basso)
    d = ImageDraw.Draw(img)
    d.polygon(pts, outline=CONTORNO, width=14)
    velo(img, lambda v: v.polygon([(cx, cy - r), (cx + r * 0.5, cy - r * 0.2), (cx, cy + r * 0.1), (cx - r * 0.5, cy - r * 0.2)], fill=(255, 255, 255, 120)))


def ali(img, cx, cy, colore_a, colore_b, apertura=1.0):
    """Due ali a ventaglio dietro lo scudo: cinque penne per lato, dalla più alta alla più bassa."""
    for s in (-1, 1):
        for k in range(5):
            ang = math.radians(62 - 22 * k)
            lung = (330 - 30 * k) * apertura
            base = (cx + s * 170, cy + 10 + 30 * k)
            dx, dy = s * math.cos(ang), -math.sin(ang)
            punta = (base[0] + dx * lung, base[1] + dy * lung)
            nx, ny = -dy, dx
            larg = 52
            pts = [(base[0] + nx * larg * 0.6, base[1] + ny * larg * 0.6),
                   (base[0] + dx * lung * 0.55 + nx * larg, base[1] + dy * lung * 0.55 + ny * larg),
                   punta,
                   (base[0] + dx * lung * 0.55 - nx * larg * 0.7, base[1] + dy * lung * 0.55 - ny * larg * 0.7),
                   (base[0] - nx * larg * 0.6, base[1] - ny * larg * 0.6)]
            m = maschera_poligono(pts)
            sfumatura(img, m, colore_a, colore_b)
            ImageDraw.Draw(img).polygon(pts, outline=CONTORNO, width=12)


def corona(img, cx, cy):
    pts = [(cx - 150, cy + 60), (cx - 170, cy - 70), (cx - 90, cy - 10), (cx, cy - 110), (cx + 90, cy - 10), (cx + 170, cy - 70), (cx + 150, cy + 60)]
    m = maschera_poligono(pts)
    sfumatura(img, m, hexc("#FFF06A"), hexc("#FFA51F"))
    d = ImageDraw.Draw(img)
    d.polygon(pts, outline=CONTORNO, width=14)
    for x, y in ((cx - 170, cy - 70), (cx, cy - 110), (cx + 170, cy - 70)):
        d.ellipse([x - 22, y - 22, x + 22, y + 22], fill=hexc("#FF4A6A"), outline=CONTORNO, width=8)


def stemma(nome, alto, basso, bordo_a, bordo_b, centro, extra_dietro=None, extra_sopra=None, bagliore=None):
    img = nuova()
    if extra_dietro:
        extra_dietro(img)
    pts = scudo_punti(512, 520, 560, 640)
    m = maschera_poligono(pts)
    sfumatura(img, m, bordo_a, bordo_b)
    interno = scudo_punti(512, 525, 450, 520)
    mi = maschera_poligono(interno)
    sfumatura(img, mi, alto, basso)
    d = ImageDraw.Draw(img)
    d.polygon(interno, outline=CONTORNO, width=10)
    velo(img, lambda v: v.polygon([(330, 300), (694, 300), (660, 380), (364, 380)], fill=(255, 255, 255, 70)))
    centro(img)
    img = contorno(img, m)
    if extra_sopra:
        extra_sopra(img)
    if bagliore:
        img = alone(img, bagliore, 400)
    d = ImageDraw.Draw(img)
    scintilla(d, 860, 220, 54)
    salva(img, "rank_" + nome)


def stella_centro(img, colore_a, colore_b, r=150):
    punti = []
    for k in range(10):
        ang = k * math.pi / 5 - math.pi / 2
        rr = r if k % 2 == 0 else r * 0.45
        punti.append((512 + math.cos(ang) * rr, 520 + math.sin(ang) * rr))
    ms = maschera_poligono(punti)
    sfumatura(img, ms, colore_a, colore_b)
    ImageDraw.Draw(img).polygon(punti, outline=CONTORNO, width=14)


def gradi():
    stemma("bronze", hexc("#F0A462"), hexc("#A95A24"), hexc("#FFD9A8"), hexc("#8A4A1A"),
           lambda img: stella_centro(img, hexc("#FFE0BC"), hexc("#C8752F")))
    stemma("silver", hexc("#E6EEFA"), hexc("#7D91BD"), hexc("#FFFFFF"), hexc("#5A6A90"),
           lambda img: stella_centro(img, hexc("#FFFFFF"), hexc("#9BB0D6")))
    stemma("gold", hexc("#FFE45C"), hexc("#E68700"), hexc("#FFF7B8"), hexc("#B35A00"),
           lambda img: stella_centro(img, hexc("#FFFBE0"), hexc("#FFC233")), bagliore=hexc("#FFD23F", 90))
    stemma("diamond", hexc("#5CE1FF"), hexc("#1E6FD0"), hexc("#D8F6FF"), hexc("#1A4FA0"),
           lambda img: gemma(img, 512, 520, 160, hexc("#E8FBFF"), hexc("#36A8FF")), bagliore=hexc("#5CE1FF", 100))
    stemma("ruby", hexc("#FF6A8A"), hexc("#A0122E"), hexc("#FFD0DA"), hexc("#7A0E20"),
           lambda img: gemma(img, 512, 520, 160, hexc("#FFB0C0"), hexc("#E5213B"), 8), bagliore=hexc("#FF4A6A", 110))
    stemma("master", hexc("#C77DFF"), hexc("#5A1BA8"), hexc("#F0D8FF"), hexc("#3A0E70"),
           lambda img: gemma(img, 512, 520, 150, hexc("#F0D8FF"), hexc("#9B5CFF"), 8),
           extra_dietro=lambda img: ali(img, 512, 470, hexc("#E8D0FF"), hexc("#8A4AE0")), bagliore=hexc("#C77DFF", 120))
    stemma("grandmaster", hexc("#FF8A1F"), hexc("#B01428"), hexc("#FFF06A"), hexc("#B35A00"),
           lambda img: gemma(img, 512, 540, 140, hexc("#FFF06A"), hexc("#FF3A3A"), 8),
           extra_dietro=lambda img: ali(img, 512, 470, hexc("#FFE45C"), hexc("#FF6A1A"), 1.15),
           extra_sopra=lambda img: corona(img, 512, 215), bagliore=hexc("#FF8A1F", 140))


if __name__ == "__main__":
    import sys as _sys
    if len(_sys.argv) > 1 and _sys.argv[1] == "gradi":
        gradi()
    else:
        main()
        gradi()
