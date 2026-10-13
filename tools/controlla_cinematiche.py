"""Controlla le cinematiche fuori da Studio, sui campi generati da test/campi.luau.

    lune run test/campi /tmp/campi          # i campi (JSON con rilievo, acqua e oggetti)
    lune run test/cinematiche /tmp/cin.json # le sceneggiature
    python3 tools/controlla_cinematiche.py /tmp/campi /tmp/cin.json [Nome]

Per ogni cinematica segnala: soldati in acqua o fuori dal campo, reparti che si compenetrano,
telecamera sotto terra o in acqua, terreno davanti all'obiettivo, oggetti (alberi, case) sulla strada
dei soldati o davanti alla telecamera che "sgombra" non toglie.
"""
import glob
import json
import math
import sys


def liscio(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def completa(tappe):
    ultima = {"t": 0, "x": 0, "z": 0, "a": 0}
    for tappa in tappe:
        for k in ("x", "z", "a"):
            tappa.setdefault(k, ultima[k])
        ultima = tappa


def stato_reparto(tappe, t):
    prima = tappe[0]
    if t <= prima["t"]:
        return prima["x"], prima["z"], prima["a"]
    for dopo in tappe[1:]:
        if t <= dopo["t"]:
            f = (t - prima["t"]) / max(0.01, dopo["t"] - prima["t"])
            if dopo.get("liscio"):
                f = liscio(f)
            da = (dopo["a"] - prima["a"] + 180) % 360 - 180
            return prima["x"] + (dopo["x"] - prima["x"]) * f, prima["z"] + (dopo["z"] - prima["z"]) * f, prima["a"] + da * f
        prima = dopo
    return prima["x"], prima["z"], prima["a"]


def offsets(r):
    passo = r.get("passo", 3.4)
    file, righe = r.get("file", 1), r.get("righe", 1)
    out = []
    for riga in range(1, righe + 1):
        for f in range(1, file + 1):
            out.append(((f - (file + 1) / 2) * passo, -(riga - 1) * passo))
    return out


def soldati(r, t):
    x, z, a = stato_reparto(r["tappe"], t)
    ra = math.radians(a)
    dx, dz = math.cos(ra), -math.sin(ra)
    fx, fz = math.sin(ra), math.cos(ra)
    return [(x + dx * ox + fx * oz, z + dz * ox + fz * oz) for ox, oz in offsets(r)]


class Campo:
    def __init__(self, dati):
        t = dati["terreno"]
        self.x0, self.z0, self.n, self.passo = t["x0"], t["z0"], t["n"], t["passo"]
        self.suolo, self.acqua = t["suolo"], t["acqua"]
        self.origine = dati["origine"]
        self.parti = []
        for p in dati["parti"]:
            c, s = p["c"], p["s"]
            self.parti.append((c[0], c[1], c[2], s[0], s[1], s[2]))

    def indice(self, x, z):
        i = int((x - self.x0) // self.passo)
        k = int((z - self.z0) // self.passo)
        if i < 0 or k < 0 or i >= self.n or k >= self.n:
            return None
        return i * self.n + k

    def quota(self, x, z):
        i = self.indice(x, z)
        if i is None:
            return None
        acqua = self.acqua[i]
        return max(self.suolo[i], acqua) if acqua is not False else self.suolo[i]

    def in_acqua(self, x, z):
        i = self.indice(x, z)
        if i is None:
            return True
        acqua = self.acqua[i]
        return acqua is not False and acqua > self.suolo[i] + 0.4


def controlla(nome, sc, campo, dettagli):
    problemi = []
    ox, oz = (sc.get("origine") or [0, 0])
    cx, cz = campo.origine[0] + ox, campo.origine[2] + oz
    for r in sc["reparti"]:
        completa(r["tappe"])
    reparti = {r["id"]: r for r in sc["reparti"]}
    durata = sc["durata"]
    tempi = [i * 0.5 for i in range(int(durata * 2) + 1)]

    # Oggetti che restano visibili (fuori dalle zone sgombre, o troppo grandi per essere tolti).
    zone = sc.get("sgombra") or []
    visibili = []
    for (px, py, pz, sx, sy, sz) in campo.parti:
        lx, lz = px - cx, pz - cz
        if max(sx, sz) < 40 and any(z[0] <= lx <= z[2] and z[1] <= lz <= z[3] for z in zone):
            continue
        if max(sx, sy, sz) < 1.2:
            continue  # sassi e ciuffi: non danno fastidio
        visibili.append((lx, py, lz, sx, sy, sz))
    griglia = {}
    for o in visibili:
        griglia.setdefault((int(o[0] // 10), int(o[2] // 10)), []).append(o)

    def oggetti_vicini(x, z, margine):
        trovati = []
        for gx in range(int(x // 10) - 3, int(x // 10) + 4):
            for gz in range(int(z // 10) - 3, int(z // 10) + 4):
                for o in griglia.get((gx, gz), ()):
                    raggio = max(o[3], o[5]) / 2
                    if math.hypot(o[0] - x, o[2] - z) < raggio + margine:
                        trovati.append(o)
        return trovati

    # Soldati: acqua, fuori campo, oggetti sulla strada.
    for r in sc["reparti"]:
        acqua, strada = [], set()
        for t in tempi:
            for (x, z) in soldati(r, t):
                if campo.in_acqua(cx + x, cz + z):
                    acqua.append(t)
                    break
            for (x, z) in soldati(r, t)[:: max(1, len(offsets(r)) // 6)]:
                for o in oggetti_vicini(x, z, 1.5):
                    if o[4] > 2.5:
                        strada.add((round(o[0]), round(o[2]), round(max(o[3], o[5]))))
        if acqua:
            problemi.append(f"  {r['id']}: in acqua da t={acqua[0]} a t={acqua[-1]} ({len(acqua)} istanti)")
        if strada:
            esempi = sorted(strada)[:4]
            problemi.append(f"  {r['id']}: {len(strada)} oggetti sulla strada, es. {esempi}")

    # Reparti che si compenetrano (soldati di reparti diversi a meno di 1.6 studs).
    for t in tempi[::2]:
        punti = []
        for r in sc["reparti"]:
            for p in soldati(r, t):
                punti.append((p, r["id"]))
        celle = {}
        for p, rid in punti:
            celle.setdefault((int(p[0] // 4), int(p[1] // 4)), []).append((p, rid))
        coppie = set()
        for (gx, gz), lista in celle.items():
            vicini = []
            for dx in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    vicini += celle.get((gx + dx, gz + dz), [])
            for p, rid in lista:
                for q, qid in vicini:
                    if qid > rid and math.hypot(p[0] - q[0], p[1] - q[1]) < 1.6:
                        coppie.add((rid, qid))
        for coppia in sorted(coppie):
            chiave = ("sovrapposti",) + coppia
            if chiave not in dettagli:
                dettagli.add(chiave)
                problemi.append(f"  t={t}: {coppia[0]} e {coppia[1]} si compenetrano")

    # Telecamera.
    def punto(v, segui, t):
        bx, bz = 0.0, 0.0
        if segui:
            bx, bz, _ = stato_reparto(reparti[segui]["tappe"], t)
        x, z = bx + v[0], bz + v[2]
        q = campo.quota(cx + x, cz + z)
        return x, (q if q is not None else 0) + v[1], z

    for n, inq in enumerate(sc["inquadrature"], 1):
        note = set()
        for i in range(11):
            f = i / 10
            t = inq["t"] + inq["durata"] * f
            g = f if inq.get("lineare") else liscio(f)
            da = punto(inq["da"][0], inq.get("segui"), t)
            a = punto(inq["a"][0], inq.get("segui"), t)
            gda = punto(inq["da"][1], inq.get("segui"), t)
            ga = punto(inq["a"][1], inq.get("segui"), t)
            pos = tuple(da[k] + (a[k] - da[k]) * g for k in range(3))
            guarda = tuple(gda[k] + (ga[k] - gda[k]) * g for k in range(3))
            # Pos ha la quota del terreno sotto i suoi estremi: ricalcolata qui sotto la posizione vera.
            q = campo.quota(cx + pos[0], cz + pos[2])
            if q is None:
                note.add("fuori dal campo")
                continue
            if pos[1] < q + 1.2:
                note.add(f"sotto terra a f={f:.1f} ({pos[1]-q:.1f})")
            # Terreno davanti all'obiettivo.
            coperto = 0
            for s in range(1, 20):
                k = s / 20
                x = pos[0] + (guarda[0] - pos[0]) * k
                y = pos[1] + (guarda[1] - pos[1]) * k
                z = pos[2] + (guarda[2] - pos[2]) * k
                qq = campo.quota(cx + x, cz + z)
                if qq is not None and qq > y + 0.3:
                    coperto += 1
            if coperto > 3:
                note.add(f"terreno davanti a f={f:.1f} ({coperto}/19)")
            # Oggetti molto vicini davanti all'obiettivo.
            d = math.dist(pos, guarda)
            for s in range(1, 8):
                k = min(1, s * 3 / max(d, 1))
                x = pos[0] + (guarda[0] - pos[0]) * k
                y = pos[1] + (guarda[1] - pos[1]) * k
                z = pos[2] + (guarda[2] - pos[2]) * k
                for o in oggetti_vicini(x, z, 0.5):
                    base = campo.quota(cx + o[0], cz + o[2]) or 0
                    if y < base + o[4] + 0.5:
                        note.add(f"oggetto {round(max(o[3], o[5]))} studs a ({round(o[0])},{round(o[2])}) davanti a f={f:.1f}")
        for nota in sorted(note)[:5]:
            problemi.append(f"  inquadratura {n} (t={inq['t']}): {nota}")
    return problemi


def main():
    cartella, file_cin = sys.argv[1], sys.argv[2]
    solo = sys.argv[3] if len(sys.argv) > 3 else None
    sceneggiature = json.load(open(file_cin))
    campi = {}
    for f in sorted(glob.glob(cartella + "/*.json")):
        d = json.load(open(f))
        campi[d["nome"]] = f
    for nome, sc in sceneggiature.items():
        if solo and nome != solo:
            continue
        if nome not in campi:
            print(f"{nome}: nessun campo generato")
            continue
        campo = Campo(json.load(open(campi[nome])))
        problemi = controlla(nome, sc, campo, set())
        print(f"{nome}: {'ok' if not problemi else str(len(problemi)) + ' problemi'}")
        for p in problemi:
            print(p)


if __name__ == "__main__":
    main()
