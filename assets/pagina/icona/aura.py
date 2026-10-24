"""Icona da render Blender: sfondo del gioco sfocato + aura attorno alla sagoma di Cesare + render nitido.
Uso: aura.py render.png maschera.png sfondo.jpg uscita.png"""
import sys
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage
rnd, msk, sfo, out_path = sys.argv[1:5]
ren = Image.open(rnd).convert("RGBA"); N = ren.width
def f32(im): return np.asarray(im).astype(np.float32) / 255
def img(a): return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
R = f32(ren); A = R[..., 3:4]; C = R[..., :3]
M = f32(Image.open(msk).convert("RGBA"))[..., 3]  # solo Cesare

# sfondo: tramonto del campo di Austerlitz (cattura di Studio), sfocato e un po' scuro
s = Image.open(sfo).convert("RGB")
h = s.height; s = s.crop(((s.width - h) // 2 + 120, 0, (s.width - h) // 2 + 120 + h, h)).resize((N, N), Image.BICUBIC)
bg = f32(s.filter(ImageFilter.GaussianBlur(N * 0.012))) * 0.62
yy, xx = np.mgrid[0:N, 0:N] / N

# aura: distanza dal bordo della sagoma, con lingue che salgono (rumore stirato in verticale)
dist = ndimage.distance_transform_edt(M < 0.5) / N
rng = np.random.default_rng(7)
def rumore(scala_x, scala_y):
    r = rng.random((int(N / scala_y) + 2, int(N / scala_x) + 2)).astype(np.float32)
    r = np.asarray(Image.fromarray((r * 255).astype(np.uint8)).resize((N, N), Image.BICUBIC)).astype(np.float32) / 255
    return r
lingue = 0.6 * rumore(10, 28) + 0.4 * rumore(22, 60)
lingue = np.clip((lingue - 0.35) / 0.4, 0, 1) ** 1.5
# la distanza "si allunga" verso l'alto: l'aura sale come una fiamma
spinta = ndimage.distance_transform_edt(M < 0.5)
d_lingue = dist / (0.45 + 1.1 * lingue)
nucleo = np.exp(-dist / 0.005)
corona = np.exp(-d_lingue / 0.016)
alone = np.exp(-dist / 0.05) * 0.3
oro_chiaro = np.array([1.0, 0.95, 0.72]); oro = np.array([1.0, 0.72, 0.25]); arancio = np.array([1.0, 0.45, 0.12])
aura = nucleo[..., None] * oro_chiaro * 1.0 + corona[..., None] * oro * 1.0 + alone[..., None] * arancio
fuori = (M < 0.5)[..., None]
aura = aura * fuori
bg = 1 - (1 - bg) * (1 - np.clip(aura, 0, 1))  # screen

# luce di contorno dorata sul bordo interno di Cesare
dentro = ndimage.distance_transform_edt(M > 0.5) / N
bordo = np.exp(-dentro / 0.004)[..., None] * (M > 0.5)[..., None]
C2 = C + bordo * oro_chiaro * 0.35

out = C2 * A + bg * (1 - A)
# bloom leggero e vignettatura
luce = np.clip(out - 0.75, 0, 1)
bloom = f32(img(luce).filter(ImageFilter.GaussianBlur(N * 0.01)))
out = 1 - (1 - out) * (1 - bloom * 0.5)
v = np.sqrt((xx - 0.55) ** 2 + (yy - 0.45) ** 2)
out = out * np.clip(1.1 - 0.7 * v ** 1.5, 0.5, 1)[..., None]
res = img(out)
crop = [int(v) for v in sys.argv[5:9]] if len(sys.argv) > 8 else [0, 0, N, N]
res = res.crop(crop).resize((512, 512), Image.LANCZOS).filter(ImageFilter.UnsharpMask(0.8, 50, 1))
res.save(out_path)
res.resize((150, 150), Image.LANCZOS).save(out_path.replace(".png", "_150.png"))
print("ok")
