# Genera la mappa d'Europa dai dati di elevazione reali (AWS Terrain Tiles, formato terrarium, zoom 5)
# e la maschera terra/mare GLOBE (global-land-mask), più i sentieri tra le battaglie.
# Uso: python3 tools/genera_mappa.py src/shared/Config/Campagna.luau src/shared/Config/MappaEuropaDati.luau
# Serve: pip install numpy pillow global-land-mask
import math, os, sys, heapq, urllib.request
import numpy as np
from PIL import Image
from global_land_mask import globe

DEM = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'cache_quote')
Z = 5
X0, X1, Y0, Y1 = 14, 20, 8, 13
os.makedirs(DEM, exist_ok=True)
for x in range(X0, X1 + 1):
    for y in range(Y0, Y1 + 1):
        file = f'{DEM}/t_{x}_{y}.png'
        if not os.path.exists(file):
            urllib.request.urlretrieve(f'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{Z}/{x}/{y}.png', file)
img = np.zeros(((Y1 - Y0 + 1) * 256, (X1 - X0 + 1) * 256))
for x in range(X0, X1 + 1):
    for y in range(Y0, Y1 + 1):
        a = np.asarray(Image.open(f'{DEM}/t_{x}_{y}.png').convert('RGB')).astype(np.float64)
        e = a[:, :, 0] * 256 + a[:, :, 1] + a[:, :, 2] / 256 - 32768
        img[(y - Y0) * 256:(y - Y0 + 1) * 256, (x - X0) * 256:(x - X0 + 1) * 256] = e

N = 2 ** Z * 256
def elev(lat, lon):
    px = (lon + 180) / 360 * N - X0 * 256
    s = math.sin(math.radians(lat))
    py = (0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * N - Y0 * 256
    i, j = int(py), int(px)
    ty, tx = py - i, px - j
    a = img[i, j] * (1 - tx) + img[i, j + 1] * tx
    b = img[i + 1, j] * (1 - tx) + img[i + 1, j + 1] * tx
    return a * (1 - ty) + b * ty

LON0, LON1, LAT0, LAT1 = -12.0, 46.0, 28.0, 62.0
COL, RIG = 240, 200
dlon = (LON1 - LON0) / COL
dlat = (LAT1 - LAT0) / RIG

terra = np.zeros((RIG, COL), bool)
quota = np.zeros((RIG, COL))
for r in range(RIG):
    for c in range(COL):
        punti = [(LAT1 - (r + (i + 0.5) / 3) * dlat, LON0 + (c + (j + 0.5) / 3) * dlon) for i in range(3) for j in range(3)]
        t = sum(globe.is_land(la, lo) for la, lo in punti)
        terra[r, c] = t >= 5
        quota[r, c] = sum(elev(la, lo) for la, lo in punti) / 9

# Codifica: un carattere per cella. 0-9 = mare (profondità), 10-89 = terra (altezza).
ALFABETO = [chr(i) for i in range(35, 127) if chr(i) not in '\\"']
def codice(r, c):
    if terra[r, c]:
        e = max(0.0, quota[r, c])
        studs = 1.0 + 0.42 * math.sqrt(e)
        return min(89, 10 + round((studs - 1.0) / 0.4))
    d = max(0.0, -quota[r, c])
    return min(9, int(math.sqrt(d) / 6))

righe = [''.join(ALFABETO[codice(r, c)] for c in range(COL)) for r in range(RIG)]

# Battaglie (stesso ordine di Campagna.luau), per i sentieri.
sorgente = open(sys.argv[1]).read()
import re
battaglie = [(m.group(1), float(m.group(2)), float(m.group(3))) for m in re.finditer(r'nome = "([^"]+)".*?lat = ([-0-9.]+), lon = ([-0-9.]+)', sorgente)]
assert len(battaglie) == 30, len(battaglie)

def cella(lat, lon):
    return int((LAT1 - lat) / dlat), int((lon - LON0) / dlon)

celle = []
for nome, lat, lon in battaglie:
    r, c = cella(lat, lon)
    if not terra[r, c]:
        print('MARE:', nome, file=sys.stderr)
    celle.append((r, c))

def costo(r, c):
    if not terra[r, c]:
        return 1.6
    return 1.0 + max(0, quota[r, c]) / 500

def astar(a, b):
    aperti = [(0, a)]
    da = {a: None}
    g = {a: 0}
    while aperti:
        _, n = heapq.heappop(aperti)
        if n == b:
            break
        r, c = n
        for dr in (-1, 0, 1):
            for dc in (-1, 0, 1):
                if dr == 0 and dc == 0:
                    continue
                m = (r + dr, c + dc)
                if not (0 <= m[0] < RIG and 0 <= m[1] < COL):
                    continue
                passo = (1.414 if dr and dc else 1.0) * (costo(*n) + costo(*m)) / 2
                if terra[n] != terra[m]:
                    passo += 6  # imbarcarsi o sbarcare costa: niente zig-zag lungo la costa
                ng = g[n] + passo
                if ng < g.get(m, 1e18):
                    g[m] = ng
                    da[m] = n
                    h = math.hypot(m[0] - b[0], m[1] - b[1])
                    heapq.heappush(aperti, (ng + h, m))
    percorso = []
    n = b
    while n is not None:
        percorso.append(n)
        n = da[n]
    return percorso[::-1]

sentieri = []
for i in range(1, 30):
    if i % 10 == 0:
        sentieri.append([])  # nuova epoca: nessun sentiero dalla battaglia prima
        continue
    sentieri.append(astar(celle[i - 1], celle[i]))

out = []
out.append('-- Dati della mappa d\'Europa, generati da uno script a partire da dati geografici reali:')
out.append('-- elevazione e fondali da AWS Terrain Tiles (https://registry.opendata.aws/terrain-tiles/), costa dalla')
out.append('-- maschera terra/mare GLOBE della NOAA (pacchetto Python global-land-mask). Non modificare a mano.')
out.append('-- Griglia: %d colonne da %g°E a %g°E, %d righe da %g°N a %g°N. Un carattere per cella:' % (COL, LON0, LON1, RIG, LAT1, LAT0))
out.append('-- posizione nell\'ALFABETO 0-9 = mare (profondità), 10-89 = terra (altezza).')
out.append('local Dati = {}')
out.append('Dati.ALFABETO = "%s"' % ''.join(ALFABETO))
out.append('Dati.Griglia = {')
for riga in righe:
    out.append('\t"%s",' % riga)
out.append('}')
out.append('-- Sentieri: per ogni livello dal 2°, le celle (colonna, riga, contate da 0) del percorso dal livello prima.')
out.append('-- Vuoto al primo livello di ogni epoca.')
out.append('Dati.Sentieri = {')
out.append('\t{},')
for s in sentieri:
    out.append('\t{ ' + ', '.join('%d, %d' % (c, r) for r, c in s) + ' },')
out.append('}')
out.append('return Dati')
open(sys.argv[2], 'w').write('\n'.join(out) + '\n')

print('celle sentieri:', sum(len(s) for s in sentieri), file=sys.stderr)
