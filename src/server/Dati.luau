-- Progressi dei giocatori, salvati in un DataStore.
-- In Studio il DataStore funziona solo se il place è pubblicato e
-- "Enable Studio Access to API Services" è attivo; senza, il gioco va lo stesso ma non salva.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Epoche = require(ReplicatedStorage.Shared.Config.Epoche)
local Campagna = require(ReplicatedStorage.Shared.Config.Campagna)
local Prova = require(ReplicatedStorage.Shared.Prova)

local Dati = {}

local COPIE_IN_PROVA = 3 -- copie di ogni reggimento in modalità prova (i comandanti sono unici)

local function predefiniti()
	local iniziale = Epoche.Lista[1].mazzoIniziale
	local collezione = {}
	for _, tipo in ipairs(iniziale) do
		collezione[tipo] = (collezione[tipo] or 0) + 1
	end
	return {
		monete = 100,
		livello = 1, -- prossimo livello della campagna da giocare
		campagnaCompletata = false,
		collezione = collezione, -- tipo -> copie possedute
		mazzo = table.clone(iniziale), -- lista di tipi, una voce per carta
		stelle = {}, -- tostring(numero livello) -> stelle migliori (1-3)
		esperienza = 0,
		statistiche = {
			battaglie = 0,
			vittorie = 0,
			sconfitte = 0,
			reggimentiSconfitti = 0,
			reggimentiPersi = 0,
			moneteGuadagnate = 0,
			livelloMassimo = 1,
		},
	}
end

local negozio
do
	local ok, errore = pcall(function()
		negozio = DataStoreService:GetDataStore("Giocatori_v3")
	end)
	if not ok then
		warn("[Dati] DataStore non disponibile, i progressi non verranno salvati: " .. tostring(errore))
	end
end

local cache = {}
local caricatoBene = {}
local cambiato = Instance.new("BindableEvent")
Dati.Cambiato = cambiato.Event

local function chiave(player)
	return "giocatore_" .. player.UserId
end

-- Copia i valori salvati sopra i predefiniti, così i campi aggiunti in versioni nuove esistono sempre.
local function unisci(base, salvati)
	for k, v in pairs(salvati) do
		if type(v) == "table" and type(base[k]) == "table" and #base[k] == 0 then
			unisci(base[k], v)
		else
			base[k] = v
		end
	end
	return base
end

function Dati.carica(player)
	local dati = predefiniti()
	local ok = false
	if negozio then
		local salvati
		ok, salvati = pcall(function()
			return negozio:GetAsync(chiave(player))
		end)
		if ok and type(salvati) == "table" then
			unisci(dati, salvati)
		elseif not ok then
			warn("[Dati] Caricamento fallito per " .. player.Name .. ": " .. tostring(salvati))
		end
	end
	if Prova then
		-- Modalità prova (solo in Studio): tutti i livelli aperti e tutte le carte, per collaudare qualsiasi cosa.
		dati.livello = Campagna.TOTALE
		for _, tipo in ipairs(Epoche.carte()) do
			local copie = Epoche.Truppe[tipo].comandante and 1 or COPIE_IN_PROVA
			dati.collezione[tipo] = math.max(dati.collezione[tipo] or 0, copie)
		end
	end
	cache[player] = dati
	-- Se il caricamento è fallito non salviamo, per non sovrascrivere i dati veri con quelli predefiniti.
	-- Nemmeno in modalità prova: livelli e carte regalati non devono finire nei progressi veri.
	caricatoBene[player] = ok and not Prova
	cambiato:Fire(player, dati)
	return dati
end

function Dati.ottieni(player)
	return cache[player]
end

function Dati.modifica(player, funzione)
	local dati = cache[player]
	if not dati then
		return
	end
	funzione(dati)
	cambiato:Fire(player, dati)
end

function Dati.salva(player)
	local dati = cache[player]
	if not (negozio and dati and caricatoBene[player]) then
		return
	end
	local ok, errore = pcall(function()
		negozio:SetAsync(chiave(player), dati)
	end)
	if not ok then
		warn("[Dati] Salvataggio fallito per " .. player.Name .. ": " .. tostring(errore))
	end
end

function Dati.rilascia(player)
	Dati.salva(player)
	cache[player] = nil
	caricatoBene[player] = nil
end

-- Aggiunge una carta alla collezione; se il mazzo ha posto, la mette anche nel mazzo.
-- I comandanti sono unici: se ne ha già uno, non se ne aggiunge un altro.
function Dati.aggiungiCarta(dati, tipo)
	if Epoche.Truppe[tipo].comandante and (dati.collezione[tipo] or 0) > 0 then
		return
	end
	dati.collezione[tipo] = (dati.collezione[tipo] or 0) + 1
	if #dati.mazzo < 6 then
		table.insert(dati.mazzo, tipo)
	end
end

function Dati.stelle(dati, numero)
	return dati.stelle[tostring(numero)] or 0
end

return Dati
