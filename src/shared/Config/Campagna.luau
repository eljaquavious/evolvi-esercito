-- Livelli della campagna: battaglie storiche sulla mappa d'Europa, generate in modo fisso
-- (lo stesso livello ha sempre lo stesso terreno; ogni round ha la sua armata nemica).
-- Ogni epoca ha LIVELLI_PER_EPOCA livelli; a metà e all'ultimo c'è un comandante da battere.
-- Un livello si vince al meglio di 5 round: quando ti manca una vittoria il nemico si chiude in una fortezza.

local Epoche = require(script.Parent.Epoche)

local Campagna = {}

Campagna.LIVELLI_PER_EPOCA = 6
Campagna.TOTALE = Campagna.LIVELLI_PER_EPOCA * #Epoche.Lista
Campagna.COLONNE = 6
Campagna.RIGHE = 6
Campagna.RIGHE_GIOCATORE = 2
-- Terra di nessuno: righe in mezzo al campo dove nessuno si schiera, così le armate non si scontrano subito.
Campagna.TERRA_DI_NESSUNO = 2
Campagna.PRIMA_RIGA_NEMICA = Campagna.RIGHE_GIOCATORE + Campagna.TERRA_DI_NESSUNO + 1
Campagna.MAX_REGGIMENTI = 6
Campagna.ROUND_PER_VINCERE = 3
Campagna.STELLE_MASSIME = 3

-- Battaglie, in ordine. lat/lon servono a metterle sulla mappa (spostate di poco nell'entroterra se cadono sul mare); fiume = un fiume attraversa il campo.
-- comandante = il boss del livello (deve stare nei comandanti dell'epoca). trincee = tratti di trincea sulle prime linee.
-- meteo = cielo e tempo del campo (Config/Luci.meteo). nemico = come chiamare l'esercito nemico nelle scritte (inglese).
-- L'ordine segue un sentiero sulla mappa, senza salti avanti e indietro: per questo non è sempre cronologico.
Campagna.Battaglie = {
	-- Antichità: dalla Mesopotamia alla Grecia, poi Italia, Africa e Gallia.
	{ nome = "Gaugamela", anno = "331 BC", lat = 36.36, lon = 43.25, bioma = "Desertico", meteo = "polvere", nemico = "the Persians" },
	{ nome = "Thermopylae", anno = "480 BC", lat = 38.8, lon = 22.53, bioma = "Montagnoso", meteo = "caldo", nemico = "the Persians" },
	{ nome = "Cannae", anno = "216 BC", lat = 41.14, lon = 15.89, bioma = "Pianeggiante", fiume = true, comandante = "Annibale", meteo = "caldo", nemico = "the Carthaginians" },
	{ nome = "Zama", anno = "202 BC", lat = 36.3, lon = 9.4, bioma = "Desertico", meteo = "polvere", nemico = "the Carthaginians" },
	{ nome = "Gergovia", anno = "52 BC", lat = 45.71, lon = 3.13, bioma = "Collinoso", meteo = "nuvoloso", nemico = "the Gauls" },
	{ nome = "Alesia", anno = "52 BC", lat = 47.54, lon = 4.5, bioma = "Collinoso", comandante = "Cesare", meteo = "alba", nemico = "the Romans" },
	-- Medioevo: dalla Terrasanta al Baltico, poi Inghilterra e Francia.
	{ nome = "Hattin", anno = "1187", lat = 32.8, lon = 35.45, bioma = "Desertico", meteo = "caldo", nemico = "Saladin's army" },
	{ nome = "Lake Peipus", anno = "1242", lat = 58.7, lon = 27.5, bioma = "Innevato", meteo = "neve", nemico = "the Teutonic Knights" },
	{ nome = "Hastings", anno = "1066", lat = 50.91, lon = 0.49, bioma = "Collinoso", comandante = "Guglielmo", meteo = "nuvoloso", nemico = "the Normans" },
	{ nome = "Crecy", anno = "1346", lat = 50.25, lon = 1.9, bioma = "Pianeggiante", meteo = "pioggia", nemico = "the French" },
	{ nome = "Tours", anno = "732", lat = 47.0, lon = 0.6, bioma = "Pianeggiante", fiume = true, meteo = "tramonto", nemico = "the Umayyads" },
	{ nome = "Orleans", anno = "1429", lat = 47.9, lon = 1.9, bioma = "Pianeggiante", fiume = true, comandante = "Giovanna", meteo = "sereno", nemico = "the French" },
	-- Novecento: la Grande Guerra da Gallipoli ad Amiens, poi la Seconda da Stalingrado a Parigi.
	{ nome = "Gallipoli", trincee = true, anno = "1915", lat = 40.13, lon = 26.78, bioma = "Collinoso", meteo = "caldo", nemico = "the Ottomans" },
	{ nome = "Verdun", trincee = true, anno = "1916", lat = 49.16, lon = 5.38, bioma = "Collinoso", fiume = true, meteo = "pioggia", nemico = "the Germans" },
	{ nome = "Amiens", trincee = true, anno = "1918", lat = 49.9, lon = 2.3, bioma = "Pianeggiante", comandante = "Foch", meteo = "nebbia", nemico = "the Allies" },
	{ nome = "Stalingrad", anno = "1942", lat = 48.7, lon = 44.5, bioma = "Innevato", fiume = true, meteo = "neve", nemico = "the Soviets" },
	{ nome = "Normandy", anno = "1944", lat = 49.34, lon = -0.6, bioma = "Pianeggiante", meteo = "nuvoloso", nemico = "the Germans" },
	{ nome = "Paris", anno = "1944", lat = 48.86, lon = 2.35, bioma = "Pianeggiante", fiume = true, comandante = "DeGaulle", meteo = "tramonto", nemico = "the Free French" },
}
-- Battaglie tolte quando i livelli sono scesi da 10 a 6 per epoca (i loro scenari restano in Scenari.luau,
-- pronti per tornare): Marathon, Heraclea, Carthage, Aquae Sextiae, Manzikert, Lechfeld, Stamford Bridge,
-- Roncevaux Pass, Tannenberg, The Marne, El Alamein, Monte Cassino.

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
	for riga = Campagna.RIGHE, Campagna.PRIMA_RIGA_NEMICA, -1 do
		for col = 1, Campagna.COLONNE do
			if not occupate[chiave(col, riga)] then
				return col, riga
			end
		end
	end
	return nil
end

-- Tipi di casella che non si attraversano (ostacoli naturali, case, rottami della guerra) e quelli dove non
-- ci si schiera (gli stessi più il fiume). La trincea invece si occupa: chi ci sta dentro è più riparato.
Campagna.SOLIDI = { ostacolo = true, casa = true, rottami = true }
Campagna.BLOCCATI = { ostacolo = true, casa = true, rottami = true, fiume = true }

-- Terreno del campo: { { col, riga, tipo } } con tipo "ostacolo" (naturale: alberi, rocce), "casa" (casupola,
-- tenda, casa diroccata), "rottami" (carri rotti, relitti, barricate), "fiume" (rallenta ed espone), "guado"
-- (punto basso del fiume, normale), "collina" (protegge e allunga il tiro) o "trincea" (ripara chi c'è dentro).
local function generaTerreno(numero, locale, battaglia)
	local rng = Random.new(numero * 7919)
	local terreno, occupate = {}, {}
	local function aggiungi(col, riga, tipo)
		occupate[chiave(col, riga)] = true
		table.insert(terreno, { col = col, riga = riga, tipo = tipo })
	end
	local function casellaLibera(rigaMin, rigaMax)
		for _ = 1, 30 do
			local col, riga = rng:NextInteger(1, Campagna.COLONNE), rng:NextInteger(rigaMin, rigaMax)
			if not occupate[chiave(col, riga)] then
				return col, riga
			end
		end
		return nil
	end
	-- Trincee (Grande Guerra): un tratto di 3-4 caselle sulla prima linea di ognuno.
	if battaglia.trincee then
		for _, riga in ipairs({ Campagna.RIGHE_GIOCATORE, Campagna.PRIMA_RIGA_NEMICA }) do
			local lunghezza = rng:NextInteger(3, 4)
			local inizio = rng:NextInteger(1, Campagna.COLONNE - lunghezza + 1)
			for col = inizio, inizio + lunghezza - 1 do
				aggiungi(col, riga, "trincea")
			end
		end
	end
	-- Il primo livello di ogni epoca è un campo aperto: niente ostacoli (le trincee, se ci sono, restano).
	if locale == 1 then
		return terreno
	end
	-- Terra di nessuno: il fiume, se c'è, e qualche ostacolo naturale o rottame.
	local rigaFiume
	if battaglia.fiume then
		rigaFiume = rng:NextInteger(Campagna.RIGHE_GIOCATORE + 1, Campagna.PRIMA_RIGA_NEMICA - 1)
		local guadi = {}
		for _ = 1, rng:NextInteger(1, 2) do
			guadi[rng:NextInteger(1, Campagna.COLONNE)] = true
		end
		for col = 1, Campagna.COLONNE do
			aggiungi(col, rigaFiume, guadi[col] and "guado" or "fiume")
		end
	end
	local numeroOstacoli = rigaFiume and rng:NextInteger(1, 2) or rng:NextInteger(2, 3)
	for _ = 1, numeroOstacoli do
		local col, riga = casellaLibera(Campagna.RIGHE_GIOCATORE + 1, Campagna.PRIMA_RIGA_NEMICA - 1)
		if col then
			aggiungi(col, riga, rng:NextNumber() < 0.6 and "ostacolo" or "rottami")
		end
	end
	-- Su ogni metà del campo una o due casupole o rottami dove non ci si può schierare.
	for _, righe in ipairs({ { 1, Campagna.RIGHE_GIOCATORE }, { Campagna.PRIMA_RIGA_NEMICA, Campagna.RIGHE } }) do
		for _ = 1, locale <= 2 and 1 or rng:NextInteger(1, 2) do
			local col, riga = casellaLibera(righe[1], righe[2])
			if col then
				aggiungi(col, riga, rng:NextNumber() < 0.5 and "casa" or "rottami")
			end
		end
	end
	for _ = 1, rng:NextInteger(0, 2) do
		local col, riga = casellaLibera(1, Campagna.RIGHE)
		if col then
			aggiungi(col, riga, "collina")
		end
	end
	return terreno
end

-- Le caselle dove non si può schierare un reggimento.
function Campagna.bloccata(livello, col, riga)
	for _, t in ipairs(livello.terreno) do
		if t.col == col and t.riga == riga then
			return Campagna.BLOCCATI[t.tipo] == true
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
	-- Grado da 1 a 10: quanto si è avanti nell'epoca, qualunque sia il numero dei suoi livelli.
	local grado = 1 + (locale - 1) * 9 / math.max(1, Campagna.LIVELLI_PER_EPOCA - 1)
	local numeroNemici = math.min(1 + math.floor(grado * 0.35), Campagna.MAX_REGGIMENTI - 1)

	return {
		numero = numero,
		locale = locale,
		grado = grado,
		indiceEpoca = indiceEpoca,
		epoca = epoca,
		nome = battaglia.nome,
		anno = battaglia.anno,
		bioma = battaglia.bioma,
		comandante = battaglia.comandante,
		meteo = battaglia.meteo or "sereno",
		nemico = battaglia.nemico or "the enemy",
		terreno = generaTerreno(numero, locale, battaglia),
		numeroNemici = numeroNemici,
		maxReggimenti = math.min(numeroNemici + 1, Campagna.MAX_REGGIMENTI),
		forzaNemici = 1 + 0.025 * (grado - 1),
		ricompensa = math.floor(40 + 15 * grado + 60 * (indiceEpoca - 1)),
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
	for riga = 1, Campagna.PRIMA_RIGA_NEMICA - 1 do
		for col = 1, Campagna.COLONNE do
			occupate[chiave(col, riga)] = true
		end
	end
	for _, t in ipairs(livello.terreno) do
		if Campagna.BLOCCATI[t.tipo] then
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
			piazza(tipo, Campagna.PRIMA_RIGA_NEMICA, Campagna.RIGHE - 1)
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
