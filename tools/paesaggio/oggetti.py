"""Gli oggetti dei campi (trincee, sacchetti, case, carri, palizzate...) come modelli 3D smussati.

Parte dalle stesse parti che il gioco costruisce (Server/Paesaggio), scritte da Lune:

    REGISTRA=/tmp/registro.json lune run test/campi /tmp/campi
    python3 tools/paesaggio/oggetti.py /tmp/registro.json [--glb cartella] [--solo nome ...]

Ogni parte diventa un solido con gli spigoli smussati (scatole, cunei, cilindri, palle; i sacchi di stoffa
diventano cuscini), con la texture del suo materiale (venature del legno, tavole, mattoni, pietre, trama
della stoffa, ruggine), lo sporco vicino a terra e le ombre di tutto l'oggetto cotte dentro. Scrive
Shared/MeshDati/Ogg_* (una cartella per oggetto, contesto e variante). Le parti di vetro, neon o trasparenti
restano parti vere nel gioco e qui si saltano.
"""
import json
import math
import os
import sys

import numpy as np
import trimesh
from scipy.spatial import ConvexHull

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from base import Modello, Rumore, mescola, ombreggia  # noqa: E402

R = Rumore(41)
R2 = Rumore(97)


# Solidi smussati (in coordinate della parte) ------------------------------------------------------

def _scafo(punti):
    punti = np.asarray(punti, float)
    h = ConvexHull(punti)
    m = trimesh.Trimesh(punti, h.simplices, process=True)
    trimesh.repair.fix_normals(m)
    return m


def blocco(sx, sy, sz):
    hx, hy, hz = sx / 2, sy / 2, sz / 2
    b = min(max(min(sx, sy, sz) * 0.12, 0.03), 0.22)
    if min(sx, sy, sz) < 0.12:
        return trimesh.creation.box((sx, sy, sz))
    P = []
    for i in (-1, 1):
        for j in (-1, 1):
            for k in (-1, 1):
                P += [(i * hx, j * (hy - b), k * (hz - b)), (i * (hx - b), j * hy, k * (hz - b)), (i * (hx - b), j * (hy - b), k * hz)]
    return _scafo(P)


def cuneo(sx, sy, sz):
    """WedgePart di Roblox: base piena, lato alto dietro (+Z), faccia inclinata verso -Z."""
    hx, hy, hz = sx / 2, sy / 2, sz / 2
    b = min(max(min(sx, sy, sz) * 0.1, 0.02), 0.16)
    V = np.array([(i * hx, -hy, -hz) for i in (-1, 1)] + [(i * hx, -hy, hz) for i in (-1, 1)] + [(i * hx, hy, hz) for i in (-1, 1)], float)
    if min(sx, sy, sz) < 0.12:
        return _scafo(V)
    c = V.mean(0)
    dentro = c + (V - c) * (1 - 2 * b / np.maximum(np.array([sx, sy, sz]), 1e-6))
    ico = trimesh.creation.icosphere(0, b).vertices
    return _scafo((dentro[:, None, :] + ico[None]).reshape(-1, 3))


def cilindro(sx, sy, sz):
    """Cilindro di Roblox: asse lungo X, diametro il minore tra Y e Z, bordi smussati."""
    h = sx / 2
    r = min(sy, sz) / 2
    lati = int(np.clip(round(r * 14), 8, 20))
    b = min(max(r * 0.15, 0.02), 0.2, h * 0.4)
    a = np.linspace(0, 2 * np.pi, lati, endpoint=False)
    cs, sn = np.cos(a), np.sin(a)
    P = []
    for x, rr in ((-h, r - b), (-h + b, r), (h - b, r), (h, r - b)):
        P += list(zip(np.full(lati, x), cs * rr, sn * rr))
    return _scafo(P)


def palla(sx, sy, sz):
    d = min(sx, sy, sz)
    m = trimesh.creation.icosphere(2 if d > 1.2 else 1, d / 2)
    return m


def _sfera_uv(lati, anelli):
    """Sfera di raggio 1 a meridiani e paralleli (pochi triangoli, si deforma bene in un cuscino)."""
    V = [(0, 1, 0)]
    for i in range(1, anelli):
        t = math.pi * i / anelli
        for k in range(lati):
            a = 2 * math.pi * k / lati
            V.append((math.sin(t) * math.cos(a), math.cos(t), math.sin(t) * math.sin(a)))
    V.append((0, -1, 0))
    F = []
    for k in range(lati):
        F.append([0, 1 + (k + 1) % lati, 1 + k])
    for i in range(anelli - 2):
        a0, a1 = 1 + i * lati, 1 + (i + 1) * lati
        for k in range(lati):
            k1 = (k + 1) % lati
            F += [[a0 + k, a0 + k1, a1 + k], [a0 + k1, a1 + k1, a1 + k]]
    ultimo = len(V) - 1
    a0 = 1 + (anelli - 2) * lati
    for k in range(lati):
        F.append([ultimo, a0 + k, a0 + (k + 1) % lati])
    m = trimesh.Trimesh(np.array(V, float), np.array(F), process=False)
    if m.volume < 0:
        m.invert()
    return m


def ellissoide(sx, sy, sz, cuscino=False):
    if cuscino:
        # Sacco pieno: quasi una scatola con i bordi tondi (superellissoide), pochi triangoli.
        m = _sfera_uv(10, 6)
        v = m.vertices.copy()
        v = np.sign(v) * np.abs(v) ** 0.55
        v /= np.abs(v).max(0)
        m.vertices = v * np.array([sx, sy, sz]) / 2
        return m
    grande = max(sx, sy, sz) > 1.0
    m = _sfera_uv(16 if grande else 10, 9 if grande else 6)
    m.vertices = m.vertices * np.array([sx, sy, sz]) / 2
    return m


def solido(forma, s, materiale):
    if forma == "Block":
        return blocco(*s)
    if forma == "Wedge":
        return cuneo(*s)
    if forma == "Cylinder":
        return cilindro(*s)
    if forma == "Ball":
        return palla(*s)
    return ellissoide(*s, cuscino=materiale == "Fabric" and s[1] < max(s[0], s[2]) * 0.8)


# Texture dei materiali (colore in coordinate della parte) -----------------------------------------

def _fr(x):
    return x - np.floor(x)


def _cella(ix, iy, seme=0):
    """Numero a caso 0-1 per cella intera (per tavole, mattoni e pietre di colore diverso)."""
    h = np.sin(ix * 12.9898 + iy * 78.233 + seme * 37.719) * 43758.5453
    return _fr(h)


def colore_materiale(materiale, base, q, nl, misura):
    """q: punti nella parte (N,3), nl: normali nella parte, misura: size della parte."""
    n = len(q)
    c = np.tile(base, (n, 1))
    lungo = int(np.argmax(misura))
    asse = np.zeros(3)
    asse[lungo] = 1
    if materiale == "Wood":
        # Venature lungo l'asse più lungo, anelli sulle teste.
        k = np.array([6.0, 6.0, 6.0])
        k[lungo] = 0.35
        vena = R.fbm(q * k, 3)
        c = mescola(c, c * 0.62, np.clip(np.abs(vena) * 2.6, 0, 1) * 0.7)
        c = c * (0.9 + 0.2 * (R2.fbm(q * 1.5, 2) * 0.5 + 0.5))[:, None]
        testa = np.abs(nl[:, lungo]) > 0.7
        if testa.any():
            altri = [i for i in range(3) if i != lungo]
            r = np.hypot(q[testa][:, altri[0]], q[testa][:, altri[1]])
            anelli = np.abs(np.sin(r * 22 + R.fbm(q[testa] * 3, 2) * 3))
            c[testa] = mescola(base * 1.25, base * 0.8, anelli * 0.6)
    elif materiale == "WoodPlanks":
        # Tavole lungo l'asse più lungo, larghe ~0.9 studs, con le fessure scure e tinte diverse.
        norm = int(np.argmax(np.abs(nl).mean(0))) if n else 1
        altri = [i for i in range(3) if i != lungo]
        traverso = altri[0] if altri[0] != norm else altri[1]
        w = q[:, traverso] / 0.9 + 0.5
        idx = np.floor(w)
        tinta = 0.82 + 0.3 * _cella(idx, lungo, 3)
        c = c * tinta[:, None]
        k = np.array([5.0, 5.0, 5.0])
        k[lungo] = 0.3
        c = mescola(c, c * 0.7, np.clip(np.abs(R.fbm(q * k + idx[:, None] * 3.1, 2)) * 2.4, 0, 1) * 0.55)
        fessura = np.clip((0.06 - np.abs(_fr(w) - 0.5) * 0 - np.minimum(_fr(w), 1 - _fr(w))) / 0.06, 0, 1)
        c = mescola(c, base * 0.35, fessura * 0.9)
        # Chiodi/teste delle tavole ogni tanto lungo l'asse.
    elif materiale == "Fabric":
        trama = R.fbm(q * 9, 2)
        c = c * (0.92 + 0.16 * trama)[:, None]
        macchie = np.clip(R2.fbm(q * 0.7 + 4, 3) * 2, 0, 1)
        c = mescola(c, c * 0.78, macchie * 0.5)
    elif materiale == "Brick":
        # Mattoni 1.2 x 0.55 con la malta chiara, file sfalsate; sui lati la stessa trama.
        orizz = q[:, 0] if abs(nl[:, 2].mean()) > abs(nl[:, 0].mean()) else q[:, 2]
        riga = np.floor(q[:, 1] / 0.55)
        u = orizz / 1.2 + 0.5 * (riga % 2)
        col = np.floor(u)
        tinta = 0.82 + 0.3 * _cella(col, riga, 5)
        c = c * tinta[:, None]
        mv = np.minimum(_fr(q[:, 1] / 0.55), 1 - _fr(q[:, 1] / 0.55)) * 0.55
        mu = np.minimum(_fr(u), 1 - _fr(u)) * 1.2
        malta = np.clip((0.07 - np.minimum(mv, mu)) / 0.05, 0, 1)
        c = mescola(c, np.array([186, 176, 160.0]), malta * 0.85)
        c = c * (0.92 + 0.12 * R.fbm(q * 4, 2))[:, None]
    elif materiale == "Cobblestone":
        cella = np.floor(q * 1.3 + R.fbm(q * 0.8, 2)[:, None] * 0.6)
        tinta = 0.75 + 0.4 * _cella(cella[:, 0] + cella[:, 2] * 7.1, cella[:, 1], 9)
        c = c * tinta[:, None]
        f = _fr(q * 1.3 + R.fbm(q * 0.8, 2)[:, None] * 0.6)
        bordo = np.min(np.minimum(f, 1 - f)[:, [0, 1, 2]], axis=1)
        c = mescola(c, base * 0.5, np.clip((0.08 - bordo) / 0.06, 0, 1) * 0.8)
    elif materiale in ("Slate", "Limestone", "Marble", "Granite", "Sandstone", "Rock", "Basalt"):
        strati = R.fbm(q * np.array([0.5, 2.2, 0.5]), 3)
        c = mescola(c, c * 0.72, np.clip(strati * 1.8 + 0.3, 0, 1) * 0.5)
        c = c * (0.88 + 0.24 * (R2.fbm(q * 3, 3) * 0.5 + 0.5))[:, None]
    elif materiale in ("Concrete", "Plaster"):
        c = c * (0.9 + 0.14 * R.fbm(q * 2.5, 3))[:, None]
        colature = np.clip(R2.fbm(q * np.array([3, 0.3, 3]), 2) * 2, 0, 1)
        c = mescola(c, c * 0.75, colature * 0.4)
    elif materiale in ("Metal", "CorrodedMetal", "DiamondPlate"):
        ruggine = np.clip(R.fbm(q * 1.6, 3) * 2.4 + (0.2 if materiale == "CorrodedMetal" else -0.4), 0, 1)
        c = mescola(c, np.array([118, 70, 40.0]), ruggine * 0.6)
        c = c * (0.9 + 0.12 * R2.fbm(q * 6, 2))[:, None]
    elif materiale in ("Grass", "LeafyGrass"):
        c = c * (0.78 + 0.4 * (R.fbm(q * 3.0, 3) * 0.5 + 0.5))[:, None]
    elif materiale in ("Snow", "Ice", "Glacier"):
        c = c * (0.94 + 0.08 * R.fbm(q * 2, 2))[:, None]
    elif materiale in ("Ground", "Mud", "Sand"):
        c = c * (0.85 + 0.25 * (R.fbm(q * 2.2, 3) * 0.5 + 0.5))[:, None]
    else:
        c = c * (0.93 + 0.1 * R.fbm(q * 3, 2))[:, None]
    return c


# Un oggetto ----------------------------------------------------------------------------------------

def oggetto(nome, parti):
    tutte = [p for p in parti if not p.get("r")]
    if not tutte:
        return None
    misure = []
    for p in tutte:
        pos = np.array(p["c"][:3])
        misure.append(pos)
    pos = np.array(misure)
    ingombro = np.ptp(pos, axis=0).max() + max(max(p["s"]) for p in tutte)
    # Texture piccole: i dettagli sono rumore e ombre, e i modelli pesano su chi entra nel gioco.
    lato = 128 if ingombro <= 7 else 256
    m = Modello(nome, lato)
    fondo = min(p["c"][1] - max(p["s"]) / 2 for p in tutte)
    for p in tutte:
        c = p["c"]
        T = np.eye(4)
        T[:3, :3] = np.array(c[3:]).reshape(3, 3)
        T[:3, 3] = c[:3]
        s = p["s"]
        mesh = solido(p["f"], s, p["m"])
        mesh.apply_transform(T)
        base = np.array(p["k"], float)
        materiale = p["m"]
        Rm, t0, misura = T[:3, :3], T[:3, 3], np.array(s, float)

        def colore(P, N, ao, Rm=Rm, t0=t0, base=base, materiale=materiale, misura=misura):
            q = (P - t0) @ Rm
            nl = N @ Rm
            col = colore_materiale(materiale, base, q, nl, misura)
            # Sporco e umido vicino a terra.
            terra = np.clip(1 - (P[:, 1] - max(fondo, -0.5)) / 0.9, 0, 1)
            col = mescola(col, col * 0.62 + np.array([30, 24, 16.0]), terra * 0.55)
            return ombreggia(col, N, ao, 1.15, 0.1)
        angolo = 35 if p["f"] in ("Block", "Wedge") else 70
        m.aggiungi(mesh, colore, angolo)
    return m


def main():
    registro = json.load(open(sys.argv[1]))
    glb = sys.argv[sys.argv.index("--glb") + 1] if "--glb" in sys.argv else None
    solo = sys.argv[sys.argv.index("--solo") + 1:] if "--solo" in sys.argv else None
    prova = "--prova" in sys.argv
    import meshdati
    for nome_mesh in sorted(registro):
        voce = registro[nome_mesh]
        if solo and voce["nome"] not in solo and nome_mesh not in solo:
            continue
        m = oggetto(nome_mesh, voce["parti"])
        if m is None:
            continue
        # Le cose grandi hanno una variante sola (il gioco ripiega sulla prima).
        if not nome_mesh.endswith("_1"):
            ingombro = np.ptp(np.array([p["c"][:3] for p in voce["parti"]]), axis=0).max()
            if ingombro > 6:
                continue
        try:
            m.cuoci(raggi_ao=32)
        except Exception as e:  # noqa: BLE001
            print("ERRORE", nome_mesh, e, flush=True)
            continue
        if prova:
            os.makedirs(glb, exist_ok=True)
            meshdati.glb(m.dati, os.path.join(glb, nome_mesh + ".glb"))
            print(nome_mesh, len(m.dati["pos"]), "vertici", len(m.dati["triangoli"]), "triangoli", flush=True)
        else:
            m.scrivi("oggetto %s, tools/paesaggio/oggetti.py" % voce["nome"], glb)


if __name__ == "__main__":
    main()
