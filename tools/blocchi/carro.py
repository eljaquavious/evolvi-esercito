"""Sherman M4 a blocchi (carro armato del Novecento), nello stile dei soldati di soldati.py.

Misure vere del carro (5,8 x 2,6 x 2,7 m). Ossa come il vecchio modello Blender: bacino (scafo),
torretta, cannone (perno del mantello) e canna (bocca), così l'Animatore lo muove come prima.

Uso: python3 tools/blocchi/carro.py [--glb cartella] [--prova]   (--prova: non scrive in MeshDati)
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import meshdati  # noqa: E402
from costruttore import Modello, chiaro, scuro  # noqa: E402
from soldati import tinta  # noqa: E402

OLIVA = "#5C6038"
OLIVA_CHIARO = "#6E7244"
CINGOLO = "#3A3632"
GOMMA = "#262422"
ACCIAIO = "#4A4C4E"


def stella(pen, u, v, r, c="#ECEAE0", cerchio=True, fondo=OLIVA):
    """Stella bianca americana (con il cerchio intorno). r in metri, centro in (u, v) della faccia."""
    ru, rv = r / pen.lm, r / pen.hm
    if cerchio:
        pen.ellisse(u - ru * 1.25, v - rv * 1.25, u + ru * 1.25, v + rv * 1.25, c)
        pen.ellisse(u - ru * 1.1, v - rv * 1.1, u + ru * 1.1, v + rv * 1.1, fondo)
    punti = []
    for k in range(10):
        a = -np.pi / 2 + k * np.pi / 5
        f = 1 if k % 2 == 0 else 0.4
        punti.append((u + ru * f * np.cos(a), v + rv * f * np.sin(a)))
    pen.poligono(punti, c)


def ruota(pen, u, v, r, c, centro=None):
    """Cerchio di raggio r metri nella faccia."""
    ru, rv = r / pen.lm, r / pen.hm
    pen.ellisse(u - ru, v - rv, u + ru, v + rv, c)


def lamiera(pen, c=OLIVA):
    pen.riempi(c, "metallo")
    pen.materiale = "metallo"


def Sherman():
    m = Modello("CarroArmato", 512)
    m.osso("bacino", None, (0, 1.0, 0))
    m.osso("torretta", "bacino", (0, 1.72, 0.25))
    m.osso("cannone", "torretta", (0, 2.18, -0.72))
    m.osso("canna", "cannone", (0, 2.18, -3.25))

    # Cingoli: fianco con le ruote dei carrelli, sopra e sotto il battistrada.
    def cingolo_fianco(pen):
        pen.riempi(CINGOLO, "metallo")
        pen.rett(0, 0, 1, 0.12, scuro(CINGOLO, 0.2))
        pen.rett(0, 0.88, 1, 1, scuro(CINGOLO, 0.2))
        for k in range(36):
            u = (k + 0.5) / 36
            pen.rett(u - 0.004, 0, u + 0.004, 0.12, GOMMA)
            pen.rett(u - 0.004, 0.88, u + 0.004, 1, GOMMA)
        for u in (0.13, 0.25, 0.44, 0.56, 0.75, 0.87):  # ruote portanti, a coppie nei carrelli
            ruota(pen, u, 0.64, 0.29, GOMMA)
            ruota(pen, u, 0.64, 0.24, "#4E5232")
            ruota(pen, u, 0.64, 0.07, scuro(OLIVA, 0.4))
        for u in (0.04, 0.96):  # ruota motrice e di rinvio
            ruota(pen, u, 0.45, 0.22, "#4E5232")

    def battistrada(pen):
        pen.riempi(CINGOLO, "metallo")
        for k in range(40):
            v = (k + 0.5) / 40
            pen.rett(0, v - 0.006, 1, v + 0.006, GOMMA)

    def battistrada_lati(pen):  # fronte/retro del cingolo (asse u lungo x)
        pen.riempi(CINGOLO, "metallo")
        for k in range(6):
            v = (k + 0.5) / 6
            pen.rett(0, v - 0.03, 1, v + 0.03, GOMMA)
    for x in (-1.08, 1.08):
        m.scatola("bacino", (x, 0.5, 0.1), (0.46, 0.92, 5.4), {
            "destra": cingolo_fianco, "sinistra": cingolo_fianco, "sopra": battistrada, "sotto": battistrada,
            "tutte": battistrada_lati})
        # Carrelli in rilievo (tre per lato) con le loro molle.
        for z in (-1.55, 0.1, 1.75):
            m.scatola("bacino", (x * 1.27, 0.62, z), (0.06, 0.14, 0.42), {"tutte": lambda pen: lamiera(pen, scuro(OLIVA, 0.15))})
        m.scatola("bacino", (x, 0.55, -2.75), (0.4, 0.5, 0.25), {"tutte": lambda pen: lamiera(pen, ACCIAIO)})  # motrice

    # Scafo basso tra i cingoli.
    m.scatola("bacino", (0, 0.72, 0.15), (1.72, 0.7, 5.0), {"tutte": lamiera})

    # Scafo alto sopra i cingoli, con la stella sui fianchi.
    def fianco_scafo(pen):
        lamiera(pen)
        pen.rett(0, 0.9, 1, 1, scuro(OLIVA, 0.25))
        stella(pen, 0.5, 0.48, 0.19)
        for u in np.linspace(0.05, 0.95, 10):  # rivetti
            pen.ellisse(u - 0.006, 0.06, u + 0.006, 0.12, scuro(OLIVA, 0.3))

    def ponte(pen):
        lamiera(pen)
        pen.rett(0.12, 0.6, 0.88, 0.62, scuro(OLIVA, 0.3))
        for u in (0.2, 0.35, 0.65, 0.8):  # griglie del motore
            pen.rett(u - 0.05, 0.68, u + 0.05, 0.95, scuro(OLIVA, 0.35))
            for v in np.linspace(0.7, 0.93, 6):
                pen.rett(u - 0.05, v, u + 0.05, v + 0.008, scuro(OLIVA, 0.55))
        stella(pen, 0.5, 0.14, 0.3)

    m.scatola("bacino", (0, 1.3, 0.5), (2.62, 0.5, 4.1), {
        "destra": fianco_scafo, "sinistra": fianco_scafo, "sopra": ponte, "tutte": lamiera})
    # Piastra frontale inclinata (glacis), con i portelli del pilota e la mitragliatrice di prua.
    def glacis(pen):
        lamiera(pen, OLIVA_CHIARO)
        for u in (0.28, 0.72):
            pen.rett(u - 0.12, 0.05, u + 0.12, 0.3, scuro(OLIVA, 0.15))
            pen.ellisse(u - 0.03, 0.12, u + 0.03, 0.2, scuro(OLIVA, 0.5))
        pen.ellisse(0.2, 0.42, 0.34, 0.58, scuro(OLIVA, 0.35))  # sfera della mitragliatrice
        for v in (0.68, 0.8):  # cingoli di ricambio
            pen.rett(0.4, v, 0.95, v + 0.09, CINGOLO)
            for u in np.linspace(0.42, 0.93, 8):
                pen.rett(u - 0.005, v, u + 0.005, v + 0.09, GOMMA)
    m.segmento("bacino", (0, 1.55, -1.55), (0, 0.85, -2.6), 2.4, 0.12, {"fronte": glacis, "tutte": lamiera}, alto=(0, 0.8, -1))
    # Fanali e mitragliatrice di prua.
    for x in (-0.95, 0.95):
        m.scatola("bacino", (x, 1.05, -2.55), (0.16, 0.14, 0.14), {"tutte": tinta(ACCIAIO, "metallo"), "fronte": tinta("#D8D4B8", "liscio")})
    m.segmento("bacino", (0.5, 1.25, -2.55), (0.5, 1.28, -2.15), 0.06, 0.06, {"tutte": tinta("#222326", "metallo")})
    # Retro: scarichi e cassette.
    m.scatola("bacino", (0, 0.95, 2.62), (2.2, 0.5, 0.2), {"tutte": lambda pen: lamiera(pen, scuro(OLIVA, 0.1))})
    for x in (-0.6, 0.6):
        m.scatola("bacino", (x, 0.82, 2.76), (0.3, 0.22, 0.14), {"tutte": tinta("#3A3430", "metallo")})
    # Attrezzi sul ponte: pala e piccone, cassa.
    m.scatola("bacino", (0.95, 1.58, 1.6), (0.3, 0.12, 1.1), {"tutte": tinta("#7A5A34", "legno")})
    m.scatola("bacino", (-0.95, 1.58, 1.4), (0.4, 0.18, 0.6), {"tutte": tinta(scuro(OLIVA, 0.1), "stoffa")})

    # Torretta fusa: blocchi sovrapposti che la arrotondano.
    def torretta_fianco(pen):
        lamiera(pen)
        stella(pen, 0.5, 0.5, 0.15, cerchio=False)

    def torretta_sopra(pen):
        lamiera(pen)
        pen.ellisse(0.55, 0.45, 0.85, 0.75, scuro(OLIVA, 0.3))  # portello del capocarro
        pen.ellisse(0.15, 0.5, 0.35, 0.7, scuro(OLIVA, 0.3))
    m.scatola("torretta", (0, 1.95, 0.25), (1.75, 0.55, 1.95), {"tutte": lamiera})
    m.scatola("torretta", (0, 1.94, 0.25), (1.95, 0.42, 1.6), {"destra": torretta_fianco, "sinistra": torretta_fianco,
                                                              "tutte": lamiera})  # arrotonda gli spigoli
    m.scatola("torretta", (0, 2.3, 0.35), (1.45, 0.2, 1.6), {"sopra": torretta_sopra, "tutte": lamiera})
    m.scatola("torretta", (0, 1.98, 1.3), (1.3, 0.45, 0.3), {"tutte": lamiera})  # contrappeso posteriore
    m.scatola("torretta", (0.35, 2.5, 0.55), (0.55, 0.12, 0.55), {"tutte": lambda pen: lamiera(pen, scuro(OLIVA, 0.08))})
    # Mitragliatrice .50 sul portello.
    m.segmento("torretta", (0.35, 2.78, -0.3), (0.35, 2.74, 0.45), 0.07, 0.07, {"tutte": tinta("#222326", "metallo")})
    m.scatola("torretta", (0.35, 2.68, 0.35), (0.12, 0.22, 0.14), {"tutte": tinta("#222326", "metallo")})
    m.scatola("torretta", (-0.55, 2.47, 0.8), (0.04, 0.6, 0.04), {"tutte": tinta("#222326", "metallo")})  # antenna
    # Mantello del cannone e canna da 75 mm.
    m.scatola("cannone", (0, 2.08, -0.8), (0.95, 0.55, 0.3), {"tutte": lambda pen: lamiera(pen, OLIVA_CHIARO)})
    m.segmento("cannone", (0, 2.1, -3.2), (0, 2.1, -0.9), 0.16, 0.16, {"tutte": lambda pen: lamiera(pen, scuro(OLIVA, 0.08))})
    m.segmento("cannone", (0, 2.1, -3.3), (0, 2.1, -3.05), 0.22, 0.22, {"tutte": lambda pen: lamiera(pen, scuro(OLIVA, 0.2))})
    return m


def main():
    dati = Sherman().costruisci(seme=7)
    if "--prova" not in sys.argv:
        meshdati.scrivi("CarroArmato", dati, "Sherman a blocchi")
    print("CarroArmato", len(dati["pos"]), "vertici", len(dati["triangoli"]), "triangoli")
    if "--glb" in sys.argv:
        cartella = sys.argv[sys.argv.index("--glb") + 1]
        meshdati.glb(dati, os.path.join(cartella, "CarroArmato.glb"))
        dati["texture"].save(os.path.join(cartella, "CarroArmato.png"))


if __name__ == "__main__":
    main()
