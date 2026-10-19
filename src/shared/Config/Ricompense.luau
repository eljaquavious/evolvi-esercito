-- Titoli e cosmetici: cosa esiste, come si sblocca, quanto costa.
-- Ogni oggetto ha UNO tra: condizione (si sblocca giocando), monete (si compra con le monete),
-- robux (si compra con Robux: prodotto = id del Developer Product, 0 finché non è creato),
-- soloCodice (arriva solo da un codice), iniziale (lo hanno tutti da subito).
--
-- Condizioni: { tipo, n }
--   battaglia  = vinci la battaglia n della campagna
--   vittorie   = vinci n battaglie della campagna
--   stelleEpoca = tutte le stelle dell'epoca n
--   stelle     = n stelle in totale
--   sconfitti  = sconfiggi n reggimenti nemici
--   comandanti = possiedi tutti i comandanti
--   ranked     = vinci n partite ranked (le ranked non ci sono ancora: restano bloccati, "coming soon")
--   preferito  = metti il gioco nei Preferiti di Roblox

local Epoche = require(script.Parent.Epoche)
local Campagna = require(script.Parent.Campagna)

local Ricompense = {}

-- Rarità: colore della tavolozza (Stile.PAL), colore del titolo sopra la testa e nome mostrato.
Ricompense.Rarita = {
	comune = { nome = "COMMON", pal = "grigio", colore = "#D2D8EA", ordine = 1 },
	raro = { nome = "RARE", pal = "blu", colore = "#5CC8FF", ordine = 2 },
	epico = { nome = "EPIC", pal = "viola", colore = "#D49BFF", ordine = 3 },
	leggendario = { nome = "LEGENDARY", pal = "oro", colore = "#FFD23F", ordine = 4 },
	esclusivo = { nome = "EXCLUSIVE", pal = "rosa", colore = "#FF8AD8", ordine = 5 },
}

-- Parti del corpo dove si indossano i cosmetici (uno per parte).
Ricompense.Slot = {
	{ id = "Testa", nome = "HEAD" },
	{ id = "Corpo", nome = "BODY" },
	{ id = "Schiena", nome = "BACK" },
	{ id = "Aura", nome = "AURA" }, -- particelle attorno al corpo (Shared.Cosmetici3D)
}

Ricompense.Titoli = {
	{ id = "Recluta", nome = "Recruit", rarita = "comune", iniziale = true },
	{ id = "Soldato", nome = "Soldier", rarita = "comune", condizione = { "vittorie", 1 } },
	{ id = "Veterano", nome = "Veteran", rarita = "raro", condizione = { "vittorie", 25 } },
	{ id = "Signore", nome = "Warlord", rarita = "epico", condizione = { "vittorie", 100 } },
	{ id = "Imperatore", nome = "Emperor", rarita = "epico", condizione = { "battaglia", 6 }, epoca = 1 },
	{ id = "GranRe", nome = "High King", rarita = "epico", condizione = { "battaglia", 12 }, epoca = 2 },
	{ id = "GranMaresciallo", nome = "Marshal of the Empire", rarita = "epico", condizione = { "battaglia", 18 }, epoca = 3 },
	{ id = "Maresciallo", nome = "Field Marshal", rarita = "leggendario", condizione = { "battaglia", 24 }, epoca = 4 },
	{ id = "Flagello", nome = "Scourge of Armies", rarita = "epico", condizione = { "sconfitti", 500 } },
	{ id = "Leggende", nome = "Keeper of Legends", rarita = "epico", condizione = { "comandanti" } },
	{ id = "Stratega", nome = "Master Tactician", rarita = "leggendario", condizione = { "stelle", 72 } },
	{ id = "Comandante", nome = "Commander", rarita = "raro", condizione = { "ranked", 10 } },
	{ id = "Generalissimo", nome = "Generalissimo", rarita = "leggendario", condizione = { "ranked", 100 } },
	{ id = "Mercenario", nome = "Mercenary", rarita = "raro", monete = 4000 },
	{ id = "Fedele", nome = "Loyal Ally", rarita = "raro", condizione = { "preferito" } },
	{ id = "Magnifico", nome = "The Magnificent", rarita = "leggendario", robux = { prezzo = 99, prodotto = 0 } },
	{ id = "Fondatore", nome = "Founder", rarita = "esclusivo", soloCodice = true },
}

-- I modelli 3D sono in Shared.Cosmetici3D (stesso id).
Ricompense.Cosmetici = {
	-- Testa
	{ id = "Galea", nome = "Legionary Galea", slot = "Testa", rarita = "raro", condizione = { "battaglia", 1 }, epoca = 1 },
	{ id = "Alloro", nome = "Laurel Wreath", slot = "Testa", rarita = "epico", condizione = { "stelleEpoca", 1 }, epoca = 1 },
	{ id = "ElmoGrande", nome = "Great Helm", slot = "Testa", rarita = "raro", condizione = { "battaglia", 9 }, epoca = 2 },
	{ id = "Adrian", nome = "Adrian Helmet", slot = "Testa", rarita = "raro", condizione = { "battaglia", 20 }, epoca = 4 },
	{ id = "Kepi", nome = "Marshal's Kepi", slot = "Testa", rarita = "epico", condizione = { "stelleEpoca", 4 }, epoca = 4 },
	{ id = "Vichingo", nome = "Viking Helmet", slot = "Testa", rarita = "comune", monete = 1000 },
	{ id = "Corona", nome = "Iron Crown", slot = "Testa", rarita = "leggendario", condizione = { "ranked", 25 } },
	-- Corpo
	{ id = "Lorica", nome = "Lorica Segmentata", slot = "Corpo", rarita = "epico", condizione = { "battaglia", 6 }, epoca = 1 },
	{ id = "Piastre", nome = "Knight's Plate", slot = "Corpo", rarita = "epico", condizione = { "battaglia", 12 }, epoca = 2 },
	{ id = "Cartucciera", nome = "Bandolier", slot = "Corpo", rarita = "epico", condizione = { "battaglia", 24 }, epoca = 4 },
	{ id = "CorazzaOro", nome = "Golden Cuirass", slot = "Corpo", rarita = "leggendario", robux = { prezzo = 149, prodotto = 0 } },
	-- Schiena
	{ id = "Scudo", nome = "Roman Scutum", slot = "Schiena", rarita = "raro", condizione = { "battaglia", 3 }, epoca = 1 },
	{ id = "Arco", nome = "English Longbow", slot = "Schiena", rarita = "raro", condizione = { "battaglia", 11 }, epoca = 2 },
	{ id = "Mantello", nome = "Royal Cape", slot = "Schiena", rarita = "epico", condizione = { "stelleEpoca", 2 }, epoca = 2 },
	{ id = "Fucile", nome = "Lebel Rifle", slot = "Schiena", rarita = "raro", condizione = { "battaglia", 21 }, epoca = 4 },
	{ id = "Stendardo", nome = "War Banner", slot = "Schiena", rarita = "raro", monete = 2500 },
	{ id = "Aquila", nome = "Imperial Eagle", slot = "Schiena", rarita = "leggendario", robux = { prezzo = 99, prodotto = 0 } },
	-- Aure
	{ id = "AuraFedele", nome = "Loyal Aura", slot = "Aura", rarita = "epico", condizione = { "preferito" } },
	{ id = "AuraBrace", nome = "Ember Aura", slot = "Aura", rarita = "raro", monete = 3000 },
	{ id = "AuraGelo", nome = "Frost Aura", slot = "Aura", rarita = "raro", condizione = { "battaglia", 10 }, epoca = 2 },
	{ id = "AuraFumo", nome = "Smoke of War", slot = "Aura", rarita = "raro", condizione = { "battaglia", 23 }, epoca = 4 },
	{ id = "AuraSangue", nome = "Crimson Aura", slot = "Aura", rarita = "epico", condizione = { "sconfitti", 250 } },
	{ id = "AuraTempesta", nome = "Storm Aura", slot = "Aura", rarita = "epico", condizione = { "vittorie", 50 } },
	{ id = "AuraReale", nome = "Royal Aura", slot = "Aura", rarita = "leggendario", robux = { prezzo = 149, prodotto = 0 } },
}

local indiceTitoli, indiceCosmetici = {}, {}
for _, t in ipairs(Ricompense.Titoli) do
	indiceTitoli[t.id] = t
end
for _, c in ipairs(Ricompense.Cosmetici) do
	indiceCosmetici[c.id] = c
end

function Ricompense.titolo(id)
	return indiceTitoli[id]
end

function Ricompense.cosmetico(id)
	return indiceCosmetici[id]
end

-- "titolo" o "cosmetico" -> definizione.
function Ricompense.trova(tipo, id)
	if tipo == "titolo" then
		return indiceTitoli[id]
	elseif tipo == "cosmetico" then
		return indiceCosmetici[id]
	end
	return nil
end

-- Il titolo che porta chi non ne ha scelto uno.
Ricompense.TITOLO_INIZIALE = "Recluta"

-- I dati arrivano dal server (Dati) o dallo stato del client: i nomi dei campi coincidono,
-- tranne la campagna finita (campagnaCompletata sul server, completata sul client).
local function finita(d)
	return d.campagnaCompletata or d.completata
end

local function battagliaVinta(d, n)
	return finita(d) or (d.livello or 1) > n
end

local function stelleDi(d, primo, ultimo)
	local stelle = d.stelle or {}
	local somma = 0
	for n = primo, ultimo do
		somma += stelle[tostring(n)] or stelle[n] or 0
	end
	return somma
end

-- Avanzamento verso la condizione: valore attuale, obiettivo (sbloccato quando attuale >= obiettivo).
function Ricompense.avanzamento(oggetto, d)
	local c = oggetto.condizione
	if not c then
		return 0, 1
	end
	local tipo, n = c[1], c[2]
	local s = d.statistiche or {}
	if tipo == "battaglia" then
		return battagliaVinta(d, n) and 1 or 0, 1
	elseif tipo == "vittorie" then
		return s.vittorie or 0, n
	elseif tipo == "stelleEpoca" then
		local per = Campagna.LIVELLI_PER_EPOCA
		local massimo = per * Campagna.STELLE_MASSIME
		return stelleDi(d, (n - 1) * per + 1, n * per), massimo
	elseif tipo == "stelle" then
		return stelleDi(d, 1, Campagna.TOTALE), n
	elseif tipo == "sconfitti" then
		return s.reggimentiSconfitti or 0, n
	elseif tipo == "comandanti" then
		local posseduti, totale = 0, 0
		for _, epoca in ipairs(Epoche.Lista) do
			for _, id in ipairs(epoca.comandanti) do
				totale += 1
				if ((d.collezione or {})[id] or 0) > 0 then
					posseduti += 1
				end
			end
		end
		return posseduti, totale
	elseif tipo == "ranked" then
		return s.vittorieRanked or 0, n
	elseif tipo == "preferito" then
		return d.preferito and 1 or 0, 1
	end
	return 0, 1
end

function Ricompense.condizioneSoddisfatta(oggetto, d)
	if not oggetto.condizione then
		return false
	end
	local attuale, obiettivo = Ricompense.avanzamento(oggetto, d)
	return attuale >= obiettivo
end

-- Frase in inglese che spiega come si ottiene l'oggetto.
function Ricompense.comeSbloccare(oggetto)
	if oggetto.iniziale then
		return "Every commander starts here."
	elseif oggetto.soloCodice then
		return "Only from a special code."
	elseif oggetto.monete then
		return "Buy it with coins."
	elseif oggetto.robux then
		return "Buy it with Robux."
	end
	local tipo, n = oggetto.condizione[1], oggetto.condizione[2]
	if tipo == "battaglia" then
		local battaglia = Campagna.Battaglie[n]
		local epoca = Epoche.Lista[math.ceil(n / Campagna.LIVELLI_PER_EPOCA)]
		if n % Campagna.LIVELLI_PER_EPOCA == 0 and epoca then
			return ("Conquer the %s era (win %s)."):format(epoca.nome, battaglia.nome)
		end
		return ("Win the Battle of %s."):format(battaglia.nome)
	elseif tipo == "vittorie" then
		return n == 1 and "Win your first battle." or ("Win %d battles."):format(n)
	elseif tipo == "stelleEpoca" then
		return ("Earn every star in the %s era."):format(Epoche.Lista[n].nome)
	elseif tipo == "stelle" then
		return ("Earn all %d campaign stars."):format(n)
	elseif tipo == "sconfitti" then
		return ("Defeat %d enemy regiments."):format(n)
	elseif tipo == "comandanti" then
		return "Collect every commander card."
	elseif tipo == "ranked" then
		return ("Win %d ranked matches (coming soon)."):format(n)
	elseif tipo == "preferito" then
		return "Add the game to your Favorites."
	end
	return ""
end

return Ricompense
