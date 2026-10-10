-- Livelli della campagna: battaglie storiche sulla mappa d'Europa, generate in modo fisso
-- (lo stesso livello ha sempre lo stesso terreno; ogni round ha la sua armata nemica).
-- Ogni epoca ha LIVELLI_PER_EPOCA livelli; al 5° e al 10° c'è un comandante da battere.
-- Un livello si vince al meglio di 5 round: quando ti manca una vittoria il nemico si chiude in una fortezza.

local Epoche = require(script.Parent.Epoche)

local Campagna = {}

Campagna.LIVELLI_PER_EPOCA = 10
Campagna.TOTALE = Campagna.LIVELLI_PER_EPOCA * #Epoche.Lista
Campagna.COLONNE = 6
Campagna.RIGHE = 6
Campagna.RIGHE_GIOCATORE = 3
Campagna.MAX_REGGIMENTI = 6
Campagna.ROUND_PER_VINCERE = 3
Campagna.STELLE_MASSIME = 3

-- Battaglie, in ordine. lat/lon servono a metterle sulla mappa (spostate di poco nell'entroterra se cadono sul mare); fiume = un fiume attraversa il campo.
-- comandante = il boss del livello (deve stare nei comandanti dell'epoca).
Campagna.Battaglie = {
	-- Antichità
	{ nome = "Marathon", anno = "490 BC", lat = 38.15, lon = 23.96, bioma = "Pianeggiante" },
	{ nome = "Thermopylae", anno = "480 BC", lat = 38.8, lon = 22.53, bioma = "Montagnoso" },
	{ nome = "Gaugamela", anno = "331 BC", lat = 36.36, lon = 43.25, bioma = "Desertico" },
	{ nome = "Heraclea", anno = "280 BC", lat = 40.39, lon = 16.44, bioma = "Collinoso", fiume = true },
	{ nome = "Cannae", anno = "216 BC", lat = 41.14, lon = 15.89, bioma = "Pianeggiante", fiume = true, comandante = "Annibale" },
	{ nome = "Zama", anno = "202 BC", lat = 36.3, lon = 9.4, bioma = "Desertico" },
	{ nome = "Cynoscephalae", anno = "197 BC", lat = 39.4, lon = 22.6, bioma = "Collinoso" },
	{ nome = "Carthage", anno = "146 BC", lat = 36.68, lon = 10.09, bioma = "Desertico" },
	{ nome = "Aquae Sextiae", anno = "102 BC", lat = 43.53, lon = 5.45, bioma = "Collinoso", fiume = true },
	{ nome = "Alesia", anno = "52 BC", lat = 47.54, lon = 4.5, bioma = "Collinoso", comandante = "Cesare" },
	-- Medioevo
	{ nome = "Tours", anno = "732", lat = 47.0, lon = 0.6, bioma = "Pianeggiante", fiume = true },
	{ nome = "Roncevaux Pass", anno = "778", lat = 43.0, lon = -1.32, bioma = "Montagnoso" },
	{ nome = "Lechfeld", anno = "955", lat = 48.3, lon = 10.9, bioma = "Pianeggiante", fiume = true },
	{ nome = "Stamford Bridge", anno = "1066", lat = 53.99, lon = -0.91, bioma = "Collinoso", fiume = true },
	{ nome = "Hastings", anno = "1066", lat = 50.91, lon = 0.49, bioma = "Collinoso", comandante = "Guglielmo" },
	{ nome = "Manzikert", anno = "1071", lat = 39.14, lon = 42.54, bioma = "Montagnoso" },
	{ nome = "Legnano", anno = "1176", lat = 45.6, lon = 8.9, bioma = "Pianeggiante" },
	{ nome = "Hattin", anno = "1187", lat = 32.8, lon = 35.45, bioma = "Desertico" },
	{ nome = "Lake Peipus", anno = "1242", lat = 58.7, lon = 27.5, bioma = "Innevato" },
	{ nome = "Orleans", anno = "1429", lat = 47.9, lon = 1.9, bioma = "Pianeggiante", fiume = true, comandante = "Giovanna" },
	-- Novecento
	{ nome = "The Marne", anno = "1914", lat = 49.0, lon = 3.4, bioma = "Pianeggiante", fiume = true },
	{ nome = "Tannenberg", anno = "1914", lat = 53.5, lon = 20.1, bioma = "Collinoso" },
	{ nome = "Gallipoli", anno = "1915", lat = 40.13, lon = 26.78, bioma = "Collinoso" },
	{ nome = "Verdun", anno = "1916", lat = 49.16, lon = 5.38, bioma = "Collinoso", fiume = true },
	{ nome = "Amiens", anno = "1918", lat = 49.9, lon = 2.3, bioma = "Pianeggiante", comandante = "Foch" },
	{ nome = "El Alamein", anno = "1942", lat = 30.83, lon = 28.95, bioma = "Desertico" },
	{ nome = "Stalingrad", anno = "1942", lat = 48.7, lon = 44.5, bioma = "Innevato", fiume = true },
	{ nome = "Monte Cassino", anno = "1944", lat = 41.49, lon = 13.81, bioma = "Montagnoso" },
	{ nome = "Normandy", anno = "1944", lat = 49.34, lon = -0.6, bioma = "Pianeggiante" },
	{ nome = "Paris", anno = "1944", lat = 48.86, lon = 2.35, bioma = "Pianeggiante", fiume = true, comandante = "DeGaulle" },
}

local function chiave(col, riga)
	return col .. "," .. riga
end

-- Prima casella libera a caso tra le righe indicate; se non ce n'è, una qualsiasi della metà nemica.
local function cercaCasella(rng, occupate, rigaMin, rigaMax)
	for _ = 1, 60 do
		local col, riga = rng:NextInteger(1, Campagna.COLONNE), rng:NextInteger(rigaMin, rigaMax)
		if not occupate[chiave(col, riga)] then
			return col, riga
		end
	end
	for riga = Campagna.RIGHE, Campagna.RIGHE_GIOCATORE + 1, -1 do
		for col = 1, Campagna.COLONNE do
			if not occupate[chiave(col, riga)] then
				return col, riga
			end
		end
	end
	return nil
end

-- Terreno del campo: { { col, riga, tipo } } con tipo "ostacolo" (non si attraversa), "fiume" (rallenta
-- ed espone), "guado" (punto basso del fiume, normale) o "collina" (protegge e allunga il tiro).
local function generaTerreno(numero, locale, battaglia)
	local rng = Random.new(numero * 7919)
	local terreno, occupate = {}, {}
	local function aggiungi(col, riga, tipo)
		occupate[chiave(col, riga)] = true
		table.insert(terreno, { col = col, riga = riga, tipo = tipo })
	end
	if locale == 1 then
		return terreno
	end
	local rigaFiume
	if battaglia.fiume then
		rigaFiume = rng:NextInteger(Campagna.RIGHE_GIOCATORE, Campagna.RIGHE_GIOCATORE + 1)
		local guadi = {}
		for _ = 1, rng:NextInteger(1, 2) do
			guadi[rng:NextInteger(1, Campagna.COLONNE)] = true
		end
		for col = 1, Campagna.COLONNE do
			aggiungi(col, rigaFiume, guadi[col] and "guado" or "fiume")
		end
	end
	local numeroOstacoli = rigaFiume and rng:NextInteger(0, 1) or rng:NextInteger(1, 3)
	for _ = 1, numeroOstacoli do
		local col = rng:NextInteger(1, Campagna.COLONNE)
		local riga = rng:NextInteger(Campagna.RIGHE_GIOCATORE, Campagna.RIGHE_GIOCATORE + 1)
		if not occupate[chiave(col, riga)] then
			aggiungi(col, riga, "ostacolo")
		end
	end
	for _ = 1, rng:NextInteger(0, 2) do
		local col, riga = rng:NextInteger(1, Campagna.COLONNE), rng:NextInteger(1, Campagna.RIGHE)
		if not occupate[chiave(col, riga)] then
			aggiungi(col, riga, "collina")
		end
	end
	return terreno
end

-- Le caselle dove non si può schierare un reggimento.
function Campagna.bloccata(livello, col, riga)
	for _, t in ipairs(livello.terreno) do
		if t.col == col and t.riga == riga then
			return t.tipo == "ostacolo" or t.tipo == "fiume"
		end
	end
	return false
end

function Campagna.livello(numero)
	numero = math.clamp(numero, 1, Campagna.TOTALE)
	local indiceEpoca = math.floor((numero - 1) / Campagna.LIVELLI_PER_EPOCA) + 1
	local epoca = Epoche.Lista[indiceEpoca]
	local locale = (numero - 1) % Campagna.LIVELLI_PER_EPOCA + 1
	local battaglia = Campagna.Battaglie[numero]
	local numeroNemici = math.min(1 + math.floor(locale * 0.35), Campagna.MAX_REGGIMENTI - 1)

	return {
		numero = numero,
		locale = locale,
		indiceEpoca = indiceEpoca,
		epoca = epoca,
		nome = battaglia.nome,
		anno = battaglia.anno,
		bioma = battaglia.bioma,
		comandante = battaglia.comandante,
		terreno = generaTerreno(numero, locale, battaglia),
		numeroNemici = numeroNemici,
		maxReggimenti = math.min(numeroNemici + 1, Campagna.MAX_REGGIMENTI),
		forzaNemici = 1 + 0.025 * (locale - 1),
		ricompensa = 40 + 10 * locale + 60 * (indiceEpoca - 1),
		-- Prima vittoria: il comandante del livello, oppure una carta dell'epoca a rotazione.
		cartaPremio = battaglia.comandante or epoca.truppe[(locale - 1) % #epoca.truppe + 1],
		ultimoDellEpoca = locale == Campagna.LIVELLI_PER_EPOCA,
	}
end

-- Armata nemica di un round: { { tipo, col, riga } }. assedio = al giocatore manca una vittoria:
-- il nemico difende la fortezza dell'epoca con un solo reggimento (o il suo comandante).
function Campagna.armata(livello, round, assedio)
	local rng = Random.new(livello.numero * 7919 + round * 104729)
	local epoca = livello.epoca
	local occupate = {}
	for riga = 1, Campagna.RIGHE_GIOCATORE do
		for col = 1, Campagna.COLONNE do
			occupate[chiave(col, riga)] = true
		end
	end
	for _, t in ipairs(livello.terreno) do
		if t.tipo == "ostacolo" or t.tipo == "fiume" then
			occupate[chiave(t.col, t.riga)] = true
		end
	end
	local armata = {}
	local function piazza(tipo, rigaMin, rigaMax)
		local col, riga = cercaCasella(rng, occupate, rigaMin, rigaMax)
		if col then
			occupate[chiave(col, riga)] = true
			table.insert(armata, { tipo = tipo, col = col, riga = riga })
		end
	end
	local function piazzaReggimento(tipo)
		-- I reggimenti a distanza stanno in fondo, gli altri davanti.
		if Epoche.Truppe[tipo].gittata > 2 then
			piazza(tipo, Campagna.RIGHE, Campagna.RIGHE)
		else
			piazza(tipo, Campagna.RIGHE_GIOCATORE + 1, Campagna.RIGHE - 1)
		end
	end

	if assedio then
		local col = rng:NextInteger(3, 4)
		if occupate[chiave(col, Campagna.RIGHE)] then
			col = 7 - col
		end
		occupate[chiave(col, Campagna.RIGHE)] = true
		table.insert(armata, { tipo = epoca.fortezza, col = col, riga = Campagna.RIGHE })
		piazza(livello.comandante or epoca.truppe[rng:NextInteger(1, #epoca.truppe)], Campagna.RIGHE - 1, Campagna.RIGHE - 1)
		return armata
	end

	local numero = livello.numeroNemici
	-- Nei livelli con un comandante, dal secondo round guida lui l'armata.
	if livello.comandante and round >= 2 then
		piazza(livello.comandante, Campagna.RIGHE - 1, Campagna.RIGHE)
		numero -= 1
	end
	for _ = 1, numero do
		piazzaReggimento(epoca.truppe[rng:NextInteger(1, #epoca.truppe)])
	end
	return armata
end

-- Forza di un reggimento nemico in un round: cresce un po' a ogni round. La fortezza è proporzionata
-- a quanti reggimenti può schierare il giocatore, così l'assedio non è né impossibile né scontato.
-- Nei livelli con un comandante il resto dell'armata è un po' più debole: il boss vale già molto.
function Campagna.forza(livello, round, tipo)
	local forza = livello.forzaNemici + 0.03 * (round - 1)
	local def = Epoche.Truppe[tipo]
	if def and def.fortezza then
		return forza * livello.maxReggimenti / 4
	end
	if def and def.comandante then
		return 1
	end
	if livello.comandante then
		forza -= 0.12
	end
	return forza
end

-- Stelle di un livello vinto: 3 senza perdere round, 2 perdendone uno, 1 altrimenti.
function Campagna.stelle(persi)
	return math.max(1, Campagna.STELLE_MASSIME - persi)
end

return Campagna
