"""Cannoni R6: il 12 libbre di Gribeauval e la grande bombarda ottomana, con i serventi R6 (fermi, sull'osso
"bacino"). Stesse ossa dei vecchi pezzi: bacino, torretta, cannone (rinculo), canna (bocca)."""
import math

import bpy
import numpy as np

from kit import (ASSE_Z, LATI, NERO, OTTONE, T1, M, anello_tondo, barba, capelli, cintura, colletto, fante,
                 fascia_vita, gonna, pugno, rot_z, shako, spalline, stivale, strato, tubo, turbante, vesti, bottoni)
from r6 import BUSTO_P, COLLO, GAMBE, PELLI, S, Modello, blender
from mathutils import Vector

C = [("cannone", 1.0)]
BC = [("bacino", 1.0)]
ASSE_RUOTA = rot_z(-math.pi / 2)  # asse Y locale verso +X


def scuro(c, f):
    r, g, b = (int(c.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4))
    return "#%02X%02X%02X" % tuple(int(v * (1 - f)) for v in (r, g, b))


def pezzo(nome, faccia, cartella, y, cannone_z, canna_z):
    m = Modello(nome)
    m.cartella, m.faccia, m.pelle, m.posa = cartella, faccia, PELLI[1], "piedi"
    m.osso("bacino", None, (0, 0.6, 0))
    m.osso("torretta", "bacino", (0, 0.9, 0))
    m.osso("cannone", "torretta", (0, y, cannone_z))
    m.osso("canna", "cannone", (0, y, canna_z))
    return m


def canna(m, nome, y, z0, z1, r0, r1, materiale, lati=20):
    """Tratto di canna lungo Z, da z0 (raggio r0) a z1 (raggio r1)."""
    return tubo(m, nome, (0, y, z0), (0, y, z1), r0, materiale, C, lati=lati, raggio_fine=r1)


def foro(m, y, z, r):
    m.cilindro("foro", (0, y, z - 0.002), r, 0.006, M("#0E0C0A", "ferro"), C, lati=16, assi=ASSE_Z)


def ruota(m, nome, centro, r, larga, legno, ferro, raggi=12):
    """Ruota a raggi con l'asse lungo X: cerchione di legno, cerchio di ferro, raggi, mozzo."""
    c = np.asarray(centro, float)
    lg, fe = M(legno, "legno_dipinto"), M(ferro, "ferro")
    anello_tondo(m, nome + "_cerchione", c, r - 0.05, larga, 0.09, lg, BC, assi=ASSE_RUOTA, lati=28)
    anello_tondo(m, nome + "_cerchio", c, r - 0.006, larga + 0.012, 0.022, fe, BC, assi=ASSE_RUOTA, lati=28)
    for k in range(raggi):
        a = 2 * math.pi * k / raggi
        d = np.array([0, math.cos(a), math.sin(a)])
        tubo(m, f"{nome}_raggio{k}", c + d * 0.09, c + d * (r - 0.07), 0.024, lg, BC, lati=6, raggio_fine=0.018)
    tubo(m, nome + "_mozzo", c - np.array([0.13, 0, 0]), c + np.array([0.13, 0, 0]), 0.1, lg, BC, lati=12,
         raggio_fine=0.08)
    for s in (-1, 1):
        tubo(m, f"{nome}_ghiera{s}", c + np.array([s * 0.12, 0, 0]), c + np.array([s * 0.17, 0, 0]), 0.065, fe, BC,
             lati=12)


def scovolo(m, testa="#2A2420", lungo=2.0):
    """Asta di traverso tenuta con le due mani, con la testa di setole (o il calcatoio) in cima."""
    pr, _ = pugno(m, "R")
    pl, _ = pugno(m, "L")
    d = (pl - pr) / np.linalg.norm(pl - pr)
    cima, fondo = pr + d * lungo * 0.62, pr - d * lungo * 0.38
    W = [("mano.R", 1.0)]
    tubo(m, "scovolo_asta", fondo, cima, 0.022, M("#80562F", "legno"), W, lati=8)
    tubo(m, "scovolo_testa", cima - d * 0.02, cima + d * 0.24, 0.07, M(testa, "pelliccia"), W, lati=10)


def aggiungi_servente(m, figura, posti):
    """Copia i pezzi del servente nel cannone ai posti (x, z, gradi), tutti sull'osso "bacino"."""
    for k, (x, z, gradi) in enumerate(posti):
        t = math.radians(gradi)
        R = np.array([[math.cos(t), 0, math.sin(t)], [0, 1, 0], [-math.sin(t), 0, math.cos(t)]])
        for ob in figura.pezzi:
            nuovo = ob.copy()
            nuovo.data = ob.data.copy()
            nuovo.name = f"servente{k}_{ob.name}"
            for v in nuovo.data.vertices:
                b = v.co
                p = np.array([-b.x, b.z, b.y])  # coordinate Roblox
                q = R @ p + np.array([x, 0, z])
                v.co = Vector(blender(q))
            nuovo.vertex_groups.clear()
            g = nuovo.vertex_groups.new(name="bacino")
            g.add(list(range(len(nuovo.data.vertices))), 1.0, "REPLACE")
            m.coll.objects.link(nuovo)
            m.pezzi.append(nuovo)
    for ob in figura.pezzi:  # l'originale non serve più
        dati = ob.data
        bpy.data.objects.remove(ob)
        bpy.data.meshes.remove(dati)
    figura.pezzi = []


SERVENTE = dict(mano_r=(-0.5, -0.2, -1), mano_l=(0.5, 0.1, -1))


def Artiglieria(faccia, cartella):
    """Cannone da 12 libbre di Gribeauval: canna di bronzo, affusto verde, ruote a raggi, palle e secchio;
    due cannonieri della Guardia con lo shako e lo scovolo."""
    Y = 1.02
    m = pezzo("Artiglieria", faccia, cartella, Y, -0.25, -2.0)
    br = "#B88A44"
    bronzo, bronzo_s = M(br, "bronzo"), M(scuro(br, 0.2), "bronzo")
    canna(m, "culatta", Y, 0.45, -0.35, 0.14, 0.13, bronzo)
    canna(m, "rinforzo", Y, -0.35, -0.95, 0.118, 0.11, bronzo)
    canna(m, "volata", Y, -0.95, -1.8, 0.1, 0.094, bronzo)
    canna(m, "gioia", Y, -1.8, -2.0, 0.11, 0.13, bronzo_s)
    foro(m, Y, -2.0, 0.065)
    for i, (z, r) in enumerate(((0.45, 0.15), (-0.35, 0.135), (-0.95, 0.12))):
        canna(m, f"anello{i}", Y, z + 0.03, z - 0.03, r, r, bronzo_s)
    canna(m, "bottone", Y, 0.6, 0.45, 0.05, 0.08, bronzo_s, lati=12)
    m.sfera("pomo", (0, Y, 0.66), 0.065, bronzo_s, C, anelli=6, lati=12)
    tubo(m, "orecchioni", (-0.24, Y, -0.25), (0.24, Y, -0.25), 0.045, bronzo_s, C, lati=12)
    for x in (-0.07, 0.07):  # i "delfini", le maniglie sopra la canna
        tubo(m, f"delfino{x}", (x, Y + 0.1, -0.56), (x, Y + 0.17, -0.48), 0.018, bronzo_s, C, lati=6)
        tubo(m, f"delfino_b{x}", (x, Y + 0.17, -0.48), (x, Y + 0.17, -0.36), 0.018, bronzo_s, C, lati=6)
        tubo(m, f"delfino_c{x}", (x, Y + 0.17, -0.36), (x, Y + 0.1, -0.3), 0.018, bronzo_s, C, lati=6)

    verde, ferro = "#4E6A3A", "#26282A"
    vd, fe = M(verde, "legno_dipinto"), M(ferro, "ferro")
    for x in (-0.2, 0.2):  # le cosce dell'affusto, dalla sala alla coda a terra
        da, a = np.array([x, 0.98, -0.32]), np.array([x * 0.7, 0.16, 2.15])
        m.segmento(f"coscia{x}", da, a, 0.32, 0.1, vd, BC, alto=(0, 1, 0), smusso=0.012)
        for t in (0.15, 0.45, 0.75):
            p = da + t * (a - da)
            m.scatola(f"staffa{x}{t}", p, (0.116, 0.34, 0.05), fe, BC, smusso=0.004)
    m.scatola("sala", (0, 0.72, 0), (1.26, 0.12, 0.12), fe, BC, smusso=0.01)
    for z, y in ((0.35, 0.82), (1.2, 0.5)):
        m.scatola(f"traversa{z}", (0, y, z), (0.34, 0.12, 0.16), vd, BC, smusso=0.01)
    m.scatola("coda", (0, 0.13, 2.18), (0.32, 0.18, 0.2), vd, BC, smusso=0.012)
    m.cilindro("occhione", (0, 0.2, 2.29), 0.06, 0.04, fe, BC, lati=12, assi=ASSE_Z)
    m.scatola("cuneo", (0, 0.86, 0.32), (0.22, 0.1, 0.34), M("#5A3A22", "legno"), BC, smusso=0.01)
    for x in (-0.68, 0.68):
        ruota(m, f"ruota{x}", (x, 0.72, 0.0), 0.72, 0.09, verde, ferro)
    palla = M("#2A2A2C", "ferro")
    for i, (x, y, z) in enumerate(((0.75, 0.07, 1.3), (0.9, 0.07, 1.3), (0.825, 0.07, 1.43), (0.825, 0.19, 1.34))):
        m.sfera(f"palla{i}", (x, y, z), 0.07, palla, BC, anelli=6, lati=10)
    m.cilindro("secchio", (-0.8, 0.15, 1.4), 0.12, 0.3, M("#6A4428", "legno"), BC, lati=12, raggio_sotto=0.1)
    anello_tondo(m, "secchio_cerchio", (-0.8, 0.26, 1.4), 0.125, 0.04, 0.012, fe, BC, lati=12)

    blu, rosso = "#22305E", "#B82820"
    f = fante("Cannoniere", faccia, cartella, PELLI[1], **SERVENTE)
    vesti(f, blu, manica=blu, manica_fino=2 * S, avambraccio=blu, coscia=blu, stinco=blu)
    strato(f, "giubba", COLLO, GAMBE - 0.02, blu, T1)
    f.scatola("risvolti", (0, COLLO - 0.55 * S, -(BUSTO_P / 2 + T1 + 0.004)), (0.8 * S, 1.1 * S, 0.008), M(rosso), [("torace", 1.0)],
              rastrema=(0.6, 1.0))
    colletto(f, rosso, alto=0.14 * S)
    spalline(f, rosso, frange=rosso)
    cintura(f, "#ECEAE2", fibbia=OTTONE)
    for lato, _ in LATI:
        stivale(f, lato, "#1A1A1E", alto=0.55 * S)
    capelli(f, "#3A2A1E", sopra=False)
    barba(f, "#3A2A1E", piena=False)
    shako(f, pennacchio=rosso)
    scovolo(f)
    aggiungi_servente(m, f, [(0.85, -1.35, 40), (-0.85, 1.0, -15)])
    return m


def CannoneOttomano(faccia, cartella):
    """La grande bombarda di Costantinopoli: canna di bronzo in due pezzi avvitati, fascia con l'iscrizione,
    letto di travi, palizzata, palle di pietra; due topçu col turbante e lo scovolo."""
    Y = 0.8
    m = pezzo("CannoneOttomano", faccia, cartella, Y, 0.2, -2.2)
    br = "#B4843E"
    bronzo, bronzo_s = M(br, "bronzo"), M(scuro(br, 0.22), "bronzo")
    canna(m, "camera", Y, 1.45, 0.3, 0.3, 0.31, bronzo)
    canna(m, "fondo", Y, 1.6, 1.45, 0.22, 0.25, bronzo_s)
    canna(m, "tromba", Y, 0.3, -2.0, 0.43, 0.43, bronzo, lati=24)
    canna(m, "bocca", Y, -1.95, -2.2, 0.49, 0.49, bronzo_s, lati=24)
    foro(m, Y, -2.2, 0.36)
    m.sfera("palla_in_canna", (0, Y, -2.12), 0.3, M("#9C968A", "pietra"), C, anelli=6, lati=12)
    canna(m, "manicotto", Y, 0.48, 0.18, 0.42, 0.42, bronzo_s, lati=24)
    for k in range(8):  # le prese per avvitare le due metà
        a = k * math.pi / 4
        m.scatola(f"presa{k}", (0.43 * math.cos(a), Y + 0.43 * math.sin(a), 0.33), (0.12, 0.12, 0.26), bronzo_s, C,
                  smusso=0.012, assi=rot_z(a))
    for i, z in enumerate((-1.55, -0.65, -0.15)):
        canna(m, f"anello{i}", Y, z + 0.05, z - 0.05, 0.455, 0.455, bronzo_s, lati=24)
    canna(m, "fascia_scritta", Y, -0.8, -1.4, 0.438, 0.438, bronzo_s, lati=24)
    for k in range(22):  # i segni dell'iscrizione sulla fascia, sopra e ai lati
        a = math.radians(-80 + 160 * k / 21)
        p = np.array([0.44 * math.sin(a), Y + 0.44 * math.cos(a), -1.1])
        m.scatola(f"segno{k}", p, (0.03, 0.012, 0.16 if k % 3 else 0.08), M(scuro(br, 0.45), "bronzo"), C,
                  assi=rot_z(-a))

    legno = "#6A4A2A"
    lg, lg_s = M(legno, "legno"), M(scuro(legno, 0.25), "legno")
    for x in (-0.42, 0.42):
        m.scatola(f"longherone{x}", (x, 0.17, -0.2), (0.3, 0.32, 3.9), lg, BC, smusso=0.02)
        m.scatola(f"sponda{x}", (x * 1.15, 0.52, -0.2), (0.12, 0.4, 3.2), lg, BC, smusso=0.015)
    for z in (-1.9, -0.8, 0.4, 1.5):
        m.scatola(f"traversa{z}", (0, 0.06, z), (1.5, 0.12, 0.26), lg_s, BC, smusso=0.015)
    for z in (-1.6, 0.9):
        m.scatola(f"sella{z}", (0, 0.36, z), (0.75, 0.16, 0.5), lg_s, BC, smusso=0.015)
    m.scatola("cuneo", (0, 0.42, -1.6), (0.45, 0.1, 0.42), lg, BC, smusso=0.01, assi=rot_x_(0.24))
    for x in (-0.55, -0.18, 0.18, 0.55):  # la palizzata dietro, contro il rinculo
        m.cilindro(f"palo{x}", (x, 0.65, 1.95), 0.12, 1.3, lg, BC, lati=8, smusso=0.04, segmenti=1)
    m.scatola("palizzata_trave", (0, 1.15, 1.85), (1.5, 0.22, 0.2), lg_s, BC, smusso=0.02)
    m.scatola("terrapieno", (0, 0.28, 2.25), (1.8, 0.56, 0.55), M("#7A6448", "pietra"), BC, smusso=0.18, segmenti=2,
              rastrema=(1.15, 1.3))
    pietra = M("#9C968A", "pietra")
    for i, (x, y, z) in enumerate(((1.05, 0.28, -0.4), (1.05, 0.28, 0.25), (1.05, 0.76, -0.08), (-1.05, 0.28, 0.6))):
        m.sfera(f"palla{i}", (x, y, z), 0.28, pietra, BC, anelli=8, lati=12)

    rosso, blu = "#A02828", "#2A4E8A"
    f = fante("Topci", faccia, cartella, PELLI[2], **SERVENTE)
    vesti(f, rosso, manica=rosso, manica_fino=2 * S, avambraccio=rosso, coscia=blu, stinco=blu)
    strato(f, "giubba", COLLO, GAMBE - 0.02, rosso, T1)
    gonna(f, rosso, basso=GAMBE - 0.5 * S, t=0.02, nome="falde")
    fascia_vita(f, "#D8A830")
    for lato, _ in LATI:
        stivale(f, lato, "#C8A030", alto=0.6 * S)
    capelli(f, "#1A1410", sopra=False)
    barba(f, "#1A1410", piena=False)
    turbante(f, "#ECE6D6", punta=False)
    f.cupola("turbante_rosso", (0, COLLO + 1.2 * S, 0.0), 0.56 * S, 0.27 * S, M(rosso, "feltro"), [("testa", 1.0)])
    scovolo(f, "#3A2E24", lungo=2.2)
    aggiungi_servente(m, f, [(1.4, -1.6, 35), (-1.25, -0.6, -20)])
    return m


def rot_x_(a):
    return np.array([[1, 0, 0], [0, math.cos(a), -math.sin(a)], [0, math.sin(a), math.cos(a)]])


TRUPPE = {"Artiglieria": Artiglieria, "CannoneOttomano": CannoneOttomano}
