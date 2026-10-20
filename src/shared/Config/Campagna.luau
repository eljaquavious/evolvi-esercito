-- Livelli della campagna: battaglie storiche sulla mappa d'Europa, generate in modo fisso
-- (lo stesso livello ha sempre lo stesso terreno; ogni round ha la sua armata nemica).
-- Ogni epoca ha LIVELLI_PER_EPOCA livelli (o quelli che dice Epoche.Lista[].livelli); a metà e all'ultimo c'è un comandante da battere.
-- Un livello si vince al meglio di 5 round: quando ti manca una vittoria il nemico si chiude in una fortezza.

local Epoche = require(script.Parent.Epoche)

local Campagna = {}

-- Livelli di un'epoca normale; un'epoca può averne di meno (Epoche.Lista[].livelli: l'Era Moderna ne ha 2).
Campagna.LIVELLI_PER_EPOCA = 6

-- Quanti livelli ha l'epoca i, il numero del suo primo livello e l'epoca (con il posto dentro l'epoca) di un livello.
function Campagna.livelliEpoca(i)
	local epoca = Epoche.Lista[i]
	return epoca and (epoca.livelli or Campagna.LIVELLI_PER_EPOCA) or 0
end

function Campagna.primoDellEpoca(i)
	local primo = 1
	for k = 1, i - 1 do
		primo += Campagna.livelliEpoca(k)
	end
	return primo
end

function Campagna.ultimoDellEpoca(i)
	return Campagna.primoDellEpoca(i) + Campagna.livelliEpoca(i) - 1
end

Campagna.TOTALE = Campagna.ultimoDellEpoca(#Epoche.Lista)

function Campagna.epocaDi(numero)
	for i = 1, #Epoche.Lista do
		if numero <= Campagna.ultimoDellEpoca(i) then
			return i, numero - Campagna.primoDellEpoca(i) + 1
		end
	end
	return #Epoche.Lista, Campagna.livelliEpoca(#Epoche.Lista)
end
Campagna.COLONNE = 6
Campagna.RIGHE = 6
Campagna.RIGHE_GIOCATORE = 2
-- Terra di nessuno: righe in mezzo al campo dove nessuno si schiera, così le armate non si scontrano subito.
Campagna.TERRA_DI_NESSUNO = 2
Campagna.PRIMA_RIGA_NEMICA = Campagna.RIGHE_GIOCATORE + Campagna.TERRA_DI_NESSUNO + 1
Campagna.MAX_REGGIMENTI = 6
Campagna.ROUND_PER_VINCERE = 3
Campagna.STELLE_MASSIME = 3

-- Battaglie, in ordine cronologico (scelta di Mattia: l'esercito evolve con la storia). lat/lon servono a metterle
-- sulla mappa (spostate di poco nell'entroterra se cadono sul mare); fiume = un fiume attraversa il campo.
-- comandante = il boss del livello (deve stare nei comandanti dell'epoca). trincee = tratti di trincea sulle prime linee.
-- meteo = cielo e tempo del campo (Config/Luci.meteo). nemico = come chiamare l'esercito nemico nelle scritte (inglese).
-- armata = i reggimenti dell'esercito nemico, fedeli alla storia (Config/Epoche): si ottengono vincendo la battaglia.
-- citta = il campo è dentro una città (Server/Scenari).
Campagna.Battaglie = {
	-- Antichità
	{ nome = "Thermopylae", anno = "480 BC", lat = 38.8, lon = 22.53, bioma = "Montagnoso", meteo = "caldo", nemico = "the Persians", premio = "Oplita",
		armata = { "Immortale", "ArcierePersiano" } },
	{ nome = "Gaugamela", anno = "331 BC", lat = 36.36, lon = 43.25, bioma = "Desertico", meteo = "polvere", nemico = "the Persians",
		armata = { "Immortale", "ArcierePersiano", "CavalleriaPersiana" } },
	{ nome = "Cannae", anno = "216 BC", lat = 41.14, lon = 15.89, bioma = "Pianeggiante", fiume = true, comandante = "Annibale", meteo = "caldo", nemico = "the Carthaginians",
		armata = { "LanciereLibico", "FrombolieroBaleare", "CavalleriaNumidica" } },
	{ nome = "Zama", anno = "202 BC", lat = 36.3, lon = 9.4, bioma = "Desertico", meteo = "polvere", nemico = "the Carthaginians",
		armata = { "LanciereLibico", "FrombolieroBaleare", "CavalleriaNumidica", "Elefante" } },
	{ nome = "Gergovia", anno = "52 BC", lat = 45.71, lon = 3.13, bioma = "Collinoso", meteo = "nuvoloso", nemico = "the Gauls",
		armata = { "GuerrieroGallico", "ArciereGallico", "CavalleriaGallica" } },
	{ nome = "Alesia", anno = "52 BC", lat = 47.54, lon = 4.5, bioma = "Collinoso", comandante = "Cesare", meteo = "alba", nemico = "the Romans",
		armata = { "Legionario", "ArciereCretese", "CavalleriaGermanica" } },
	-- Medioevo
	{ nome = "Tours", anno = "732", lat = 47.0, lon = 0.6, bioma = "Pianeggiante", fiume = true, meteo = "tramonto", nemico = "the Umayyads",
		armata = { "FanteUmayyade", "ArciereArabo", "CavalleriaAraba" } },
	{ nome = "Hastings", anno = "1066", lat = 50.91, lon = 0.49, bioma = "Collinoso", comandante = "Guglielmo", meteo = "nuvoloso", nemico = "the Normans",
		armata = { "FanteNormanno", "ArciereNormanno", "CavaliereNormanno" } },
	{ nome = "Hattin", anno = "1187", lat = 32.8, lon = 35.45, bioma = "Desertico", comandante = "Saladino", meteo = "caldo", nemico = "Saladin's army",
		armata = { "FanteAyyubide", "ArciereAyyubide", "Mamelucco" } },
	{ nome = "Lake Peipus", anno = "1242", lat = 58.7, lon = 27.5, bioma = "Innevato", meteo = "neve", nemico = "the Teutonic Knights",
		armata = { "SergenteTeutonico", "BalestriereTeutonico", "CavaliereTeutonico" } },
	{ nome = "Crecy", anno = "1346", lat = 50.25, lon = 1.9, bioma = "Pianeggiante", meteo = "pioggia", nemico = "the French",
		armata = { "UomoDArme", "BalestriereGenovese", "Cavaliere" } },
	{ nome = "Orleans", anno = "1429", lat = 47.9, lon = 1.9, bioma = "Pianeggiante", fiume = true, comandante = "Giovanna", meteo = "sereno", nemico = "the French",
		armata = { "UomoDArme", "BalestriereGenovese", "Cavaliere" } },
	-- Età della polvere da sparo
	{ nome = "Constantinople", anno = "1453", lat = 41.05, lon = 28.85, bioma = "Pianeggiante", citta = true, meteo = "alba", nemico = "the Ottomans",
		armata = { "Giannizzero", "CannoneOttomano", "Sipahi" } },
	{ nome = "Lutzen", anno = "1632", lat = 51.25, lon = 12.14, bioma = "Pianeggiante", comandante = "GustavoAdolfo", meteo = "nebbia", nemico = "the Swedes",
		armata = { "PicchiereSvedese", "MoschettiereSvedese", "CorazziereSvedese" } },
	{ nome = "Vienna", anno = "1683", lat = 48.25, lon = 16.3, bioma = "Collinoso", fiume = true, meteo = "sereno", nemico = "the Ottomans",
		armata = { "Giannizzero", "CannoneOttomano", "Sipahi" } },
	{ nome = "Austerlitz", anno = "1805", lat = 49.13, lon = 16.76, bioma = "Collinoso", meteo = "alba", nemico = "the French",
		armata = { "FanteriaDiLinea", "Artiglieria", "Corazziere" } },
	{ nome = "Borodino", anno = "1812", lat = 55.52, lon = 35.82, bioma = "Pianeggiante", fiume = true, meteo = "nuvoloso", nemico = "the French",
		armata = { "FanteriaDiLinea", "Artiglieria", "Corazziere" } },
	{ nome = "Waterloo", anno = "1815", lat = 50.68, lon = 4.41, bioma = "Pianeggiante", comandante = "Napoleone", meteo = "nuvoloso", nemico = "the French",
		armata = { "FanteriaDiLinea", "Artiglieria", "Corazziere" } },
	-- Novecento: la Grande Guerra, poi la Seconda
	{ nome = "Gallipoli", trincee = true, anno = "1915", lat = 40.13, lon = 26.78, bioma = "Collinoso", meteo = "caldo", nemico = "the Ottomans",
		armata = { "FanteOttomano", "MitraglieriOttomani" } },
	{ nome = "Verdun", trincee = true, anno = "1916", lat = 49.16, lon = 5.38, bioma = "Collinoso", fiume = true, meteo = "pioggia", nemico = "the Germans",
		armata = { "Stosstruppen", "MitraglieriTedeschi" } },
	{ nome = "Amiens", trincee = true, anno = "1918", lat = 49.9, lon = 2.3, bioma = "Pianeggiante", comandante = "Foch", meteo = "nebbia", nemico = "the Allies",
		armata = { "FanteBritannico", "Fante", "CarroMarkV" } },
	{ nome = "Stalingrad", anno = "1942", lat = 48.7, lon = 44.5, bioma = "Innevato", fiume = true, meteo = "neve", nemico = "the Soviets",
		armata = { "FucilieriSovietici", "MitraglieriSovietici", "T34" } },
	{ nome = "Normandy", anno = "1944", lat = 49.34, lon = -0.6, bioma = "Pianeggiante", comandante = "Rommel", meteo = "nuvoloso", nemico = "the Germans",
		armata = { "Granatieri", "MG42", "Panzer" } },
	{ nome = "Paris", anno = "1944", lat = 48.86, lon = 2.35, bioma = "Pianeggiante", fiume = true, comandante = "DeGaulle", meteo = "tramonto", nemico = "the Free French",
		armata = { "FanteFranciaLibera", "Mitragliere", "CarroArmato" } },
	-- Era moderna. Vietnam e Afghanistan stanno fuori dalla mappa d'Europa: lat/lon qui sono il posto sulla mappa,
	-- sul bordo a est (verso l'Asia), non quello vero (Khe Sanh 16.6 N 106.7 E, Panjshir 35.3 N 69.5 E).
	{ nome = "Khe Sanh", trincee = true, anno = "1968", lat = 31.0, lon = 45.2, bioma = "Collinoso", comandante = "Giap", meteo = "nebbia", nemico = "the North Vietnamese",
		luogo = "Vietnam", armata = { "FanteNVA", "MitraglieriNVA", "PT76" } },
	{ nome = "Panjshir", anno = "1982", lat = 36.2, lon = 45.2, bioma = "Montagnoso", fiume = true, comandante = "Sokolov", meteo = "caldo", nemico = "the Soviets",
		luogo = "Afghanistan", armata = { "VDV", "PKM", "BMP2" } },
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
local function generaTerreno(numero, locale, battaglia, indiceEpoca)
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
	-- Il primo livello delle prime due epoche è un campo aperto: niente ostacoli (le trincee, se ci sono, restano).
	if locale == 1 and indiceEpoca <= 2 then
		return terreno
	end
	-- Più l'epoca è moderna, più il campo è ingombro (richiesta di Mattia): rottami, case, alberi abbattuti.
	local ingombro = indiceEpoca - 1
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
	-- Terra di nessuno: 2-3 ostacoli, uno in più per ogni epoca dopo la prima (col fiume ne restano meno:
	-- almeno metà delle caselle restano libere, così le armate passano).
	local numeroOstacoli = (rigaFiume and rng:NextInteger(1, 2) or rng:NextInteger(2, 3)) + math.floor(ingombro * 0.75 + 0.5)
	numeroOstacoli = math.min(numeroOstacoli, rigaFiume and 3 or 6)
	-- Nelle epoche moderne gli ostacoli sono soprattutto rottami (carri bruciati, barricate, crateri).
	local quotaNaturali = math.max(0.3, 0.6 - 0.08 * ingombro)
	for _ = 1, numeroOstacoli do
		local col, riga = casellaLibera(Campagna.RIGHE_GIOCATORE + 1, Campagna.PRIMA_RIGA_NEMICA - 1)
		if col then
			aggiungi(col, riga, rng:NextNumber() < quotaNaturali and "ostacolo" or "rottami")
		end
	end
	-- Su ogni metà del campo una o due casupole o rottami dove non ci si può schierare, una in più dalla terza epoca.
	for _, righe in ipairs({ { 1, Campagna.RIGHE_GIOCATORE }, { Campagna.PRIMA_RIGA_NEMICA, Campagna.RIGHE } }) do
		for _ = 1, math.min(3, (locale <= 2 and 1 or rng:NextInteger(1, 2)) + math.floor(ingombro / 2)) do
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
	local indiceEpoca, locale = Campagna.epocaDi(numero)
	local epoca = Epoche.Lista[indiceEpoca]
	local livelliEpoca = Campagna.livelliEpoca(indiceEpoca)
	local battaglia = Campagna.Battaglie[numero]
	-- Grado da 1 a 10: quanto si è avanti nell'epoca, qualunque sia il numero dei suoi livelli.
	local grado = 1 + (locale - 1) * 9 / math.max(1, livelliEpoca - 1)
	-- Più si va avanti nella campagna, più reggimenti ci sono in campo (richiesta di Mattia): il conto non
	-- riparte da capo a ogni epoca ma cresce dall'inizio alla fine, da 1 nemico contro 2 fino a 6 contro 6.
	local avanzamento = (numero - 1) / math.max(1, Campagna.TOTALE - 1)
	local numeroNemici = math.clamp(1 + math.floor(avanzamento * 5 + 0.5), 1, Campagna.MAX_REGGIMENTI)

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
		armata = battaglia.armata or epoca.truppe,
		citta = battaglia.citta,
		terreno = generaTerreno(numero, locale, battaglia, indiceEpoca),
		numeroNemici = numeroNemici,
		maxReggimenti = math.min(numeroNemici + 1, Campagna.MAX_REGGIMENTI),
		-- A parità di reggimenti (in fondo alla campagna) i nemici sono un po' più deboli.
		forzaNemici = (1 + 0.025 * (grado - 1)) * (numeroNemici >= Campagna.MAX_REGGIMENTI and 0.93 or 1),
		ricompensa = math.floor(40 + 15 * grado + 60 * (indiceEpoca - 1)),
		-- Prima vittoria: il comandante del livello, oppure una carta dell'epoca a rotazione.
		-- premio = la carta della prima vittoria quando non è né il boss né una dell'armata (gli Spartani alle Termopili).
		premio = battaglia.premio,
		cartaPremio = battaglia.comandante or battaglia.premio or (battaglia.armata or epoca.truppe)[1],
		ultimoDellEpoca = locale == livelliEpoca,
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
		piazza(livello.comandante or livello.armata[rng:NextInteger(1, #livello.armata)], Campagna.RIGHE - 1, Campagna.RIGHE - 1)
		return armata
	end

	local numero = livello.numeroNemici
	-- Nei livelli con un comandante, dal secondo round guida lui l'armata.
	if livello.comandante and round >= 2 then
		piazza(livello.comandante, Campagna.RIGHE - 1, Campagna.RIGHE)
		numero -= 1
	end
	for _ = 1, numero do
		piazzaReggimento(livello.armata[rng:NextInteger(1, #livello.armata)])
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
