-- Mappa d'Europa e del Mediterraneo per la campagna: altezze e costa vere (dati in MappaEuropaDati),
-- con le funzioni per passare da latitudine/longitudine a posizioni nel mondo. Condivisa: il server mette
-- la mappa a pixel (Config/AssetMappa, piastrelle tutte alla stessa altezza), il client ci mette sopra i
-- livelli e il sentiero. Le altezze vere (altezzaStuds) servono ancora alla mappa in rilievo della lobby.

local Dati = require(script.Parent.MappaEuropaDati)

local MappaEuropa = {}

MappaEuropa.LON_OVEST = -12
MappaEuropa.LON_EST = 46
MappaEuropa.LAT_NORD = 62
MappaEuropa.LAT_SUD = 28
MappaEuropa.COLONNE = #Dati.Griglia[1]
MappaEuropa.RIGHE = #Dati.Griglia
MappaEuropa.CELLA = 4 -- studs, il lato di un pixel della mappa
MappaEuropa.PIASTRELLA = 0.8 -- altezza delle piastrelle di terra sul mare (tools/blender/mappa_pixel.py ALTO)
-- Centro della mappa: lontano da lobby (0, 0) e arene (x >= 4200).
MappaEuropa.CENTRO = Vector3.new(-2800, 0, 0)
MappaEuropa.Sentieri = Dati.Sentieri

-- Valore di ogni carattere della griglia: 0-9 mare (profondità), 10-89 terra (altezza).
local valori = {}
for i = 1, #Dati.ALFABETO do
	valori[string.byte(Dati.ALFABETO, i)] = i - 1
end

local function valore(colonna, riga)
	local stringa = Dati.Griglia[riga + 1]
	if not stringa or colonna < 0 or colonna >= MappaEuropa.COLONNE then
		return 0
	end
	return valori[string.byte(stringa, colonna + 1)] or 0
end

local function gradi()
	local dlon = (MappaEuropa.LON_EST - MappaEuropa.LON_OVEST) / MappaEuropa.COLONNE
	local dlat = (MappaEuropa.LAT_NORD - MappaEuropa.LAT_SUD) / MappaEuropa.RIGHE
	return dlon, dlat
end

-- Colonna e riga (da 0, anche non intere) di un punto.
function MappaEuropa.cella(lat, lon)
	local dlon, dlat = gradi()
	return (lon - MappaEuropa.LON_OVEST) / dlon, (MappaEuropa.LAT_NORD - lat) / dlat
end

-- Latitudine e longitudine al centro della cella (colonna, riga) contate da 0.
function MappaEuropa.coordinate(colonna, riga)
	local dlon, dlat = gradi()
	return MappaEuropa.LAT_NORD - (riga + 0.5) * dlat, MappaEuropa.LON_OVEST + (colonna + 0.5) * dlon
end

function MappaEuropa.terra(colonna, riga)
	return valore(colonna, riga) >= 10
end

-- Altezza del terreno in studs sopra il mare (0 = mare). Le montagne sono esagerate (radice della quota vera).
function MappaEuropa.altezzaStuds(colonna, riga)
	local v = valore(colonna, riga)
	if v < 10 then
		return 0
	end
	return 1 + (v - 10) * 0.4
end

-- Quota della mappa a pixel in una cella: le piastrelle sulla terra, 0 sul mare.
function MappaEuropa.quota(colonna, riga)
	return MappaEuropa.terra(colonna, riga) and MappaEuropa.PIASTRELLA or 0
end

-- Altezza in voxel sopra il mare (0 = mare).
function MappaEuropa.altezza(colonna, riga)
	return MappaEuropa.altezzaStuds(colonna, riga) / MappaEuropa.CELLA
end

-- Profondità del fondale in studs (0 sulla terra).
function MappaEuropa.profondita(colonna, riga)
	local v = valore(colonna, riga)
	if v >= 10 then
		return 0
	end
	return 2 + v * 1.4
end

-- Posizione nel mondo del centro della cella; il nord è verso +Z, l'est verso -X
-- (così una telecamera a sud che guarda verso +Z vede la mappa diritta).
function MappaEuropa.posizioneCella(colonna, riga)
	local x = MappaEuropa.CENTRO.X - (colonna + 0.5 - MappaEuropa.COLONNE / 2) * MappaEuropa.CELLA
	local z = MappaEuropa.CENTRO.Z + (MappaEuropa.RIGHE / 2 - riga - 0.5) * MappaEuropa.CELLA
	return Vector3.new(x, MappaEuropa.CENTRO.Y, z)
end

-- Punto sulla superficie del plastico per una latitudine e longitudine.
function MappaEuropa.posizione(lat, lon)
	local colonna, riga = MappaEuropa.cella(lat, lon)
	local base = MappaEuropa.posizioneCella(colonna - 0.5, riga - 0.5)
	return base + Vector3.new(0, MappaEuropa.quota(math.floor(colonna), math.floor(riga)), 0)
end

-- Cella che contiene un punto del mondo.
function MappaEuropa.cellaDi(posizione)
	local colonna = math.floor((MappaEuropa.CENTRO.X - posizione.X) / MappaEuropa.CELLA + MappaEuropa.COLONNE / 2)
	local riga = math.floor(MappaEuropa.RIGHE / 2 - (posizione.Z - MappaEuropa.CENTRO.Z) / MappaEuropa.CELLA)
	return colonna, riga
end

-- Superficie (Y) in un punto del mondo: la più alta tra la cella e le vicine (un punto sulla fessura tra
-- terra e mare sta sulla piastrella).
function MappaEuropa.superficie(posizione)
	local colonna, riga = MappaEuropa.cellaDi(posizione)
	local massima = 0
	for dx = -1, 1 do
		for dy = -1, 1 do
			massima = math.max(massima, MappaEuropa.quota(colonna + dx, riga + dy))
		end
	end
	return MappaEuropa.CENTRO.Y + massima
end

return MappaEuropa
