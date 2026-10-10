"""Fortezza dell'Antichità ("Hill Fort"): il forte di legno e terra che il nemico difende sul match point.

Riferimenti: le ricostruzioni delle fortificazioni di Alesia (MuséoParc Alésia: aggere di terra con la
palizzata di pali appuntiti, torri di legno a due piani con la piattaforma e il tetto di tavole, porta tra due
torri con il camminamento sopra), i castra di legno della Colonna Traiana (porte a torri, tende di cuoio dentro
il recinto, il vessillo), i "cervi" (rami appuntiti) davanti al vallo descritti da Cesare.
Pianta 8 × 8 m: aggere e palizzata tutto attorno, porta con due torri davanti (verso -Y), due torri di guardia
agli angoli dietro, tende e vessillo dentro.
"""

import math

import bmesh
from mathutils import Vector

import fortezze as F
import vestiti as V

NOME = "FortezzaAntica"
SIGLA = "FA"

L = 3.9                 # mezzo lato del recinto (multiplo del passo dei pali, 0.3)
PORTA = 1.2             # mezza larghezza del varco della porta
TORRE_PORTA = 2.1       # x del centro delle torri della porta
TIRI = [(-TORRE_PORTA, -L, 5.3), (TORRE_PORTA, -L, 5.3), (0.0, -L - 0.2, 4.6), (-3.5, 3.5, 4.9), (3.5, 3.5, 4.9)]

U = None


def materiali(u):
    F.materiale_tex(u, "Terra", F.tex_terra(SIGLA + "_Terra", quanta=0.45), 2.5)
    F.materiale_tex(u, "Tronchi", F.tex_tronchi(SIGLA + "_Tronchi", n=8), 2.4)
    F.materiale_tex(u, "Assi", F.tex_assi(SIGLA + "_Assi", n=10), 2.0)
    F.materiale_tex(u, "AssiScure", F.tex_assi(SIGLA + "_AssiScure", n=8, base=(0.27, 0.19, 0.12), seme=9), 2.0)
    u.materiale("Legno", (0.33, 0.22, 0.13), ruvidita=0.7)
    u.materiale("Pali", (0.29, 0.20, 0.115), ruvidita=0.7)
    u.materiale("Buio", (0.03, 0.025, 0.02), ruvidita=0.9)
    u.materiale("Scudo", (0.50, 0.07, 0.05), ruvidita=0.7)
    u.materiale("Ferro", (0.16, 0.15, 0.15), metallo=1.0, ruvidita=0.5)
    u.materiale("Cuoio", (0.42, 0.30, 0.18), ruvidita=0.8)
    u.materiale("CuoioScuro", (0.30, 0.20, 0.12), ruvidita=0.8)
    u.materiale("Corda", (0.55, 0.47, 0.33), ruvidita=0.9)
    u.materiale("Vessillo", (1.0, 1.0, 1.0), ruvidita=0.9, immagine=F.tex_drappo(SIGLA + "_Vessillo", emblema="aquila"))
    u.materiale("Oro", (0.80, 0.60, 0.22), metallo=1.0, ruvidita=0.35)


def aggere(u):
    """Il terrapieno: sezione a trapezio (esce sotto terra per i terreni in pendenza), interrotto alla porta."""
    profilo = [(-1.0, -0.5), (-0.3, 1.05), (0.45, 1.05), (1.2, -0.5)]
    pezzi = []
    # Il "laterale" del profilo guarda a sinistra andando da a a b: i lati girano in senso antiorario, così
    # il negativo (il fuori) è all'esterno del recinto.
    lati = [((PORTA, -L), (L + 0.3, -L)), ((L, -L - 0.3), (L, L + 0.3)), ((L + 0.3, L), (-L - 0.3, L)),
            ((-L, L + 0.3), (-L, -L - 0.3)), ((-L - 0.3, -L), (-PORTA, -L))]
    for a, b in lati:
        pezzi.append(F.prisma_lungo((*a, 0), (*b, 0), profilo))
    u.oggetto("Aggere", V.unisci(*pezzi), "Terra", liscio=False)


def vallo(u):
    """Palizzata sul ciglio esterno dell'aggere: pali appuntiti alti 2 m sopra il terrapieno."""
    pezzi = []
    lati = [((PORTA, -L), (L, -L)), ((L, -L), (L, L)), ((L, L), (-L, L)), ((-L, L), (-L, -L)), ((-L, -L), (-PORTA, -L))]
    for a, b in lati:
        pezzi.append(F.palizzata((*a, 0), (*b, 0), 0.9, 3.0))
    u.oggetto("Vallo", V.unisci(*pezzi), "Tronchi", liscio=False, spessore=0.22)
    # Traversa interna che tiene i pali, e il camminamento di ronda dietro.
    travi = []
    for a, b in lati:
        a, b = Vector((*a, 0)), Vector((*b, 0))
        d = (b - a).normalized()
        dentro = Vector((-d.y, d.x, 0))
        for z in (1.55, 2.35):
            travi.append(V.cilindro(a + dentro * 0.32 + Vector((0, 0, z)), b + dentro * 0.32 + Vector((0, 0, z)), 0.07,
                                    n=6))
    u.oggetto("Vallo_Traverse", V.unisci(*travi), "Pali")


def torre(u, nome, x, y, lato, alto, porta=False):
    """Torre di legno: fusto chiuso di assi su quattro pali d'angolo, ballatoio sporgente con il parapetto,
    pali che reggono il tetto a quattro falde."""
    pezzi_assi, pezzi_pali, pezzi_scuri = [], [], []
    m = lato / 2
    pezzi_assi.append(F.scatola((x, y, (alto - 2.1) / 2), (lato - 0.1, lato - 0.1, alto - 1.1)))
    piano = alto - 1.6
    for sx in (-1, 1):
        for sy in (-1, 1):
            pezzi_pali.append(V.cilindro((x + sx * m, y + sy * m, -0.4), (x + sx * m, y + sy * m, alto + 0.25), 0.12,
                                         n=8))
            # Saettoni sotto il ballatoio.
            pezzi_pali.append(V.cilindro((x + sx * m, y + sy * m, piano - 0.9),
                                         (x + sx * (m + 0.35), y + sy * (m + 0.35), piano - 0.05), 0.06, n=6))
    # Ballatoio, parapetto (assi) e tetto.
    pezzi_scuri.append(F.scatola((x, y, piano), (lato + 0.7, lato + 0.7, 0.16)))
    b = m + 0.35
    for (ax, ay), (bx, by) in (((-b, -b), (b, -b)), ((b, -b), (b, b)), ((b, b), (-b, b)), ((-b, b), (-b, -b))):
        pezzi_assi.append(F.prisma_lungo((x + ax, y + ay, 0), (x + bx, y + by, 0),
                                         [(-0.05, piano), (0.05, piano), (0.05, piano + 1.0), (-0.05, piano + 1.0)]))
        pezzi_pali.append(V.cilindro((x + ax, y + ay, piano), (x + ax, y + ay, alto + 0.3), 0.07, n=6))
    tetto = F.piramide((x, y, alto + 0.25), lato + 1.1, lato + 1.1, 1.15)
    u.oggetto(nome + "_Assi", V.unisci(*pezzi_assi), "Assi", liscio=False)
    u.oggetto(nome + "_Pali", V.unisci(*pezzi_pali), "Pali")
    u.oggetto(nome + "_Ballatoio", V.unisci(*pezzi_scuri), "AssiScure", liscio=False)
    u.oggetto(nome + "_Tetto", tetto, "AssiScure", liscio=False, spessore=0.08)
    # Feritoie: fessure scure sul fusto, verso fuori.
    fori = []
    for sx, sy in ((0, -1), (1, 0), (-1, 0)) if porta else ((0, -1), (1, 0), (-1, 0), (0, 1)):
        c = Vector((x + sx * (m - 0.04), y + sy * (m - 0.04), piano - 1.4))
        fori.append(F.scatola(c, (0.14 if sx == 0 else 0.1, 0.1 if sx == 0 else 0.14, 0.5)))
    u.oggetto(nome + "_Feritoie", V.unisci(*fori), "Buio", liscio=False)


def porta(u):
    torre(u, "TorreS", -TORRE_PORTA, -L + 0.2, 1.8, 6.0, porta=True)
    torre(u, "TorreD", TORRE_PORTA, -L + 0.2, 1.8, 6.0, porta=True)
    # Battenti a due ante, con le traverse e le bandelle di ferro.
    battenti = [F.scatola((-PORTA / 2, -L + 0.15, 1.45), (PORTA - 0.04, 0.14, 2.9)),
                F.scatola((PORTA / 2, -L + 0.15, 1.45), (PORTA - 0.04, 0.14, 2.9))]
    u.oggetto("Porta_Battenti", V.unisci(*battenti), "AssiScure", liscio=False)
    ferri = []
    for z in (0.5, 1.45, 2.4):
        ferri.append(F.scatola((0, -L + 0.07, z), (2 * PORTA - 0.1, 0.03, 0.08)))
    ferri.append(F.scatola((0, -L + 0.04, 1.3), (2 * PORTA + 0.4, 0.12, 0.14)))      # sbarra
    u.oggetto("Porta_Ferri", V.unisci(*ferri), "Ferro", liscio=False)
    # Camminamento sopra la porta, da torre a torre, con il parapetto di pali.
    ponte = [F.scatola((0, -L + 0.2, 3.35), (2 * TORRE_PORTA, 1.6, 0.2))]
    for x in (-PORTA - 0.05, PORTA + 0.05):
        ponte.append(F.scatola((x, -L + 0.2, 1.6), (0.25, 0.25, 3.3)))       # stipiti
    u.oggetto("Porta_Ponte", V.unisci(*ponte), "AssiScure", liscio=False)
    u.oggetto("Porta_Parapetto", F.palizzata((-TORRE_PORTA + 0.9, -L - 0.55, 0), (TORRE_PORTA - 0.9, -L - 0.55, 0), 3.2,
                                             4.4, tronco=0.25, punta=0.2), "Tronchi", liscio=False, spessore=0.15)
    # Scudi ovali appesi al parapetto, con l'umbone di ferro.
    scudi, umboni = [], []
    for x in (-0.9, -0.3, 0.3, 0.9):
        c = Vector((x, -L - 0.66, 3.75))
        scudi.append(V.sfera(c, (0.26, 0.05, 0.4), 12, 6))
        umboni.append(V.sfera(c - Vector((0, 0.05, 0)), (0.07, 0.04, 0.07), 8, 4))
    u.oggetto("Porta_Scudi", V.unisci(*scudi), "Scudo")
    u.oggetto("Porta_Umboni", V.unisci(*umboni), "Ferro")


def tende(u):
    """Due tende di cuoio (papilio) col colmo e i pioli, e il vessillo davanti alla tenda del comandante."""
    pezzi, scuri, corde = [], [], []
    for (x, y, lungo, largo, alto) in ((-1.6, 1.2, 2.2, 1.7, 1.5), (1.4, 1.6, 2.6, 2.0, 1.75)):
        profilo = [(-largo / 2, 0.0), (largo / 2, 0.0), (largo * 0.42, 0.45), (0.0, alto), (-largo * 0.42, 0.45)]
        pezzi.append(F.prisma_lungo((x, y - lungo / 2, 0), (x, y + lungo / 2, 0), profilo))
        scuri.append(F.scatola((x, y - lungo / 2 - 0.01, 0.55), (0.5, 0.03, 1.0)))       # ingresso
        for sy in (-1, 1):
            corde.append(V.cilindro((x, y + sy * lungo / 2, alto), (x, y + sy * (lungo / 2 + 0.7), 0.0), 0.012, n=4))
    u.oggetto("Tende", V.unisci(*pezzi), "Cuoio", liscio=False)
    u.oggetto("Tende_Ingressi", V.unisci(*scuri), "CuoioScuro", liscio=False)
    u.oggetto("Tende_Corde", V.unisci(*corde), "Corda")
    # Vessillo: asta, traversa, drappo quadrato con la frangia e l'aquila d'oro in cima.
    x, y = 0.2, 0.0
    asta = [V.cilindro((x, y, 0), (x, y, 4.2), 0.035, n=8), V.cilindro((x - 0.55, y, 3.6), (x + 0.55, y, 3.6), 0.025, n=6)]
    u.oggetto("Vessillo_Asta", V.unisci(*asta), "Legno")
    u.oggetto("Vessillo_Drappo", F.drappo((x - 0.5, y - 0.02, 3.58), 1.0, 1.0, (1, 0, 0), onde=0.04), "Vessillo",
              spessore=0.01)
    aquila = [V.sfera((x, y, 4.33), (0.07, 0.06, 0.1), 8, 6), V.sfera((x, y, 4.3), (0.26, 0.03, 0.08), 8, 4)]
    u.oggetto("Vessillo_Aquila", V.unisci(*aquila), "Oro")


def difese(u):
    """Cervi: rami appuntiti incrociati davanti al terrapieno, ai lati della porta."""
    pezzi = []
    for x in (-3.4, -2.6, 2.6, 3.4):
        y = -L - 1.6
        for k, a in enumerate((-35, 0, 35)):
            d = Vector((math.sin(math.radians(a)), -0.55, 0.8)).normalized()
            base = Vector((x + 0.15 * (k - 1), y, -0.2))
            pezzi.append(V.cilindro(base - d * 0.3, base + d * 1.2, 0.05, 0.012, n=5))
    u.oggetto("Cervi", V.unisci(*pezzi), "Pali")


def costruisci():
    global U
    u = V.Unita(NOME, SIGLA)
    U = u
    materiali(u)
    aggere(u)
    vallo(u)
    porta(u)
    torre(u, "TorreDS", -3.45, 3.45, 1.5, 5.4)
    torre(u, "TorreDD", 3.45, 3.45, 1.5, 5.4)
    tende(u)
    difese(u)
    return F.conta(u)


def esporta(triangoli=6500, lato=1024):
    return F.esporta(NOME, TIRI, triangoli, quote={"Tende_Corde*": 60, "Vallo_Traverse*": 300, "Cervi*": 200,
                                                     "Vessillo_Drappo*": 40, "Vessillo_Aquila*": 60}, lato=lato)
