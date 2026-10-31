# Icone dello shop delle casse dai render dei forzieri 3D (tools/blender/forzieri.py --anteprime scrive
# assets-forzieri/<Nome>/icona_grezza.png). Aggiunge il contorno scuro spesso, l'alone e le scintille come le
# altre icone (tools/icone_shop.py) e scrive assets/gui/<icona>.png. Poi: .\tools\carica-immagini.ps1
# (togliere prima le vecchie righe crate_* e chest_* da src/client/UI/ImmaginiId.luau).
#
# Uso: python tools/icone_forzieri.py   (Python di Blender con PYTHONPATH=%LOCALAPPDATA%\evolvi-pylib per Pillow)

import os

from PIL import Image, ImageDraw

import icone_shop as I

RADICE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Nome del forziere -> (icona, alone o None), gli stessi colori delle icone di prima.
FORZIERI = {
    "CassaPiccola": ("crate_small", None),
    "CassaMedia": ("crate_medium", I.hexc("#5CC8FF", 90)),
    "CassaGrande": ("crate_big", I.hexc("#FFD23F", 130)),
    "ArmeriaPiccola": ("chest_small", None),
    "ArmeriaMedia": ("chest_medium", I.hexc("#C77DFF", 110)),
    "ArmeriaGrande": ("chest_big", I.hexc("#FF4FD8", 120)),
}

LARGO = 840      # larghezza massima del forziere sulla tela da 1024
FONDO = 905      # dove poggia


def icona(nome, file, alone):
    grezza = Image.open(os.path.join(RADICE, "assets-forzieri", nome, "icona_grezza.png")).convert("RGBA")
    grezza = grezza.crop(grezza.getchannel("A").getbbox())
    k = min(LARGO / grezza.width, 760 / grezza.height)
    grezza = grezza.resize((round(grezza.width * k), round(grezza.height * k)), Image.LANCZOS)
    img = I.nuova()
    img.alpha_composite(grezza, ((I.S - grezza.width) // 2, FONDO - grezza.height))
    maschera = img.getchannel("A").point(lambda a: 255 if a > 40 else 0)
    img = I.contorno(img, maschera, 26)
    if alone:
        img = I.alone(img, alone)
    d = ImageDraw.Draw(img)
    I.scintilla(d, 880, 250, 60)
    I.scintilla(d, 130, 300, 34)
    I.salva(img, file)


def main():
    for nome, (file, alone) in FORZIERI.items():
        icona(nome, file, alone)


if __name__ == "__main__":
    main()
