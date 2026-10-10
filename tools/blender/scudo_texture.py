"""Disegna la texture del fronte dello scutum (rosso con ali, fulmini e spina) come nella foto di riferimento.
Uso: python3 tools/blender/scudo_texture.py <uscita.png>
Coordinate: u da 0 (sinistra) a 1 (destra), v da 0 (alto) a 1 (basso) sul fronte dello scudo."""
import math
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

L, A = 1024, 1632  # proporzioni dello scudo: 0.66 x 1.05 m
S = 2  # sovracampionamento
W, H = L * S, A * S

ROSSO = (186, 36, 30)
ROSSO_BORDO = (140, 26, 22)
BIANCO = (246, 242, 230)
GIALLO = (250, 196, 40)
ARANCIO = (214, 120, 24)

img = Image.new("RGB", (W, H), ROSSO)
d = ImageDraw.Draw(img)


def p(u, v):
    return (u * W, v * H)


def linea(punti, spessore, colore):
    pts = [p(u, v) for u, v in punti]
    d.line(pts, fill=colore, width=int(spessore * W), joint="curve")
    r = spessore * W / 2
    for x, y in pts:
        d.ellipse((x - r, y - r, x + r, y + r), fill=colore)


def specchia(punti):
    return [(1 - u, v) for u, v in punti]


def capovolgi(punti):
    return [(u, 1 - v) for u, v in punti]


# Spina gialla: un fuso verticale dall'umbone ai bordi, sottile verso le punte.
for verso in (-1, 1):
    pts = []
    for i in range(41):
        t = i / 40
        v = 0.5 + verso * (0.09 + t * 0.405)
        larghezza = 0.018 * (1 - t) ** 0.8 + 0.002
        pts.append((0.5 - larghezza, v))
    for i in range(40, -1, -1):
        t = i / 40
        v = 0.5 + verso * (0.09 + t * 0.405)
        larghezza = 0.018 * (1 - t) ** 0.8 + 0.002
        pts.append((0.5 + larghezza, v))
    d.polygon([p(u, v) for u, v in pts], fill=GIALLO)


def piuma(base, punta, curvatura, larghezza):
    """Piuma a banana dalla base alla punta, piegata di 'curvatura' (in unità u)."""
    (u0, v0), (u1, v1) = base, punta
    du, dv = u1 - u0, v1 - v0
    lun = math.hypot(du * W, dv * H)
    nx, ny = -dv * H / lun, du * W / lun  # normale in pixel
    sinistra, destra = [], []
    for i in range(31):
        t = i / 30
        cx = u0 * W + du * W * t + nx * curvatura * W * math.sin(math.pi * t)
        cy = v0 * H + dv * H * t + ny * curvatura * W * math.sin(math.pi * t)
        mezza = larghezza * W * (0.55 + 0.45 * math.sin(math.pi * min(1, t * 1.15))) * (1 - t ** 3)
        sinistra.append((cx + nx * mezza, cy + ny * mezza))
        destra.append((cx - nx * mezza, cy - ny * mezza))
    contorno = sinistra + destra[::-1]
    d.polygon(contorno, fill=GIALLO, outline=ARANCIO)
    d.line(contorno + [contorno[0]], fill=ARANCIO, width=int(0.006 * W))


def ala(alto):
    """Ala sinistra: alto=True sopra la freccia orizzontale, altrimenti sotto (specchiata in verticale)."""
    tras = (lambda q: q) if alto else capovolgi
    # Remiganti lunghe: partono vicino all'umbone e si piegano verso l'alto a sinistra, a ventaglio.
    remiganti = [
        ((0.33, 0.395), (0.115, 0.175), 0.034, 0.030),
        ((0.33, 0.41), (0.085, 0.225), 0.034, 0.033),
        ((0.33, 0.425), (0.07, 0.285), 0.030, 0.034),
        ((0.33, 0.44), (0.07, 0.35), 0.022, 0.033),
        ((0.34, 0.455), (0.09, 0.41), 0.012, 0.028),
    ]
    for base, punta, curva, larg in remiganti:
        b, t = tras([base, punta])
        piuma(b, t, curva if alto else -curva, larg)
    # Copritrici: due file di squame, il bordo arancio verso l'esterno.
    file = (
        ((0.415, 0.465), (0.255, 0.385), 6, 0.034),
        ((0.43, 0.47), (0.315, 0.415), 4, 0.03),
    )
    for (ua, va), (ub, vb), n, raggio in file:
        for k in range(n - 1, -1, -1):
            f = k / (n - 1)
            (u, v), = tras([(ua + (ub - ua) * f, va + (vb - va) * f)])
            x, y = p(u, v)
            r = raggio * W
            d.ellipse((x - r, y - r, x + r, y + r), fill=GIALLO)
            inizio = 100 if alto else 170
            d.arc((x - r, y - r, x + r, y + r), inizio, inizio + 150, fill=ARANCIO, width=int(0.006 * W))


for alto in (True, False):
    ala(alto)
# Ali della metà destra: stesso disegno specchiato.
meta = img.crop((0, 0, W // 2, H)).transpose(Image.FLIP_LEFT_RIGHT)
img.paste(meta, (W // 2, 0))
d = ImageDraw.Draw(img)

# Fulmini a gradini bianchi verso i quattro angoli, con la punta a freccia.
def fulmine_gradini(da, a, gradini, spessore):
    (u0, v0), (u1, v1) = da, a
    pts = [(u0, v0)]
    for i in range(gradini):
        f0 = i / gradini
        f1 = (i + 1) / gradini
        u_a = u0 + (u1 - u0) * f1
        v_m = v0 + (v1 - v0) * f0
        v_b = v0 + (v1 - v0) * f1
        pts.append((u_a, v_m))
        pts.append((u_a, v_b))
    linea(pts, spessore, BIANCO)
    # Punta: un tratto in diagonale verso l'angolo.
    su = -1 if u1 < u0 else 1
    sv = -1 if v1 < v0 else 1
    linea([(u1, v1), (u1 + su * 0.035, v1 + sv * 0.025)], spessore, BIANCO)


for su in (-1, 1):
    for sv in (-1, 1):
        da = (0.5 + su * 0.06, 0.5 + sv * 0.10)
        a = (0.5 + su * 0.40, 0.5 + sv * 0.41)
        fulmine_gradini(da, a, 5, 0.018)

# Frecce orizzontali bianche a sinistra e a destra dell'umbone.
for su in (-1, 1):
    punta = 0.5 + su * 0.43
    linea([(0.5 + su * 0.14, 0.5), (punta, 0.5)], 0.022, BIANCO)
    linea([(punta, 0.5), (punta - su * 0.06, 0.5 - 0.022)], 0.016, BIANCO)
    linea([(punta, 0.5), (punta - su * 0.06, 0.5 + 0.022)], 0.016, BIANCO)

# Bordo più scuro e leggera variazione del colore, come cuoio dipinto.
img = img.resize((L, A), Image.LANCZOS)
pix = img.load()
random.seed(3)
rumore = Image.effect_noise((L, A), 18).convert("L")
rp = rumore.load()
for y in range(A):
    for x in range(L):
        r, g, b = pix[x, y]
        bordo = min(x, L - 1 - x, y, A - 1 - y) / L
        scuro = 1 - 0.35 * max(0.0, 1 - bordo / 0.025)
        n = (rp[x, y] - 128) / 128 * 0.06
        f = scuro * (1 + n)
        pix[x, y] = (min(255, int(r * f)), min(255, int(g * f)), min(255, int(b * f)))
uscita = sys.argv[1] if len(sys.argv) > 1 else "modelli/legionario/scudo.jpg"
img.save(uscita, quality=90, optimize=True)
