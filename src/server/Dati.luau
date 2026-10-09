-- Progressi dei giocatori, salvati in un DataStore.
-- In Studio il DataStore funziona solo con "Enable Studio Access to API Services" attivo;
-- senza, il gioco va lo stesso ma non salva.

local DataStoreService = game:GetService("DataStoreService")

local Dati = {}

local PREDEFINITI = {
	monete = 100,
	livello = 1, -- prossimo livello della campagna da giocare
	campagnaCompletata = false,
}

local negozio
do
	local ok, errore = pcall(function()
		negozio = DataStoreService:GetDataStore("Giocatori_v1")
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

function Dati.carica(player)
	local dati = table.clone(PREDEFINITI)
	local ok = false
	if negozio then
		local salvati
		ok, salvati = pcall(function()
			return negozio:GetAsync(chiave(player))
		end)
		if ok and type(salvati) == "table" then
			for k, v in pairs(salvati) do
				dati[k] = v
			end
		elseif not ok then
			warn("[Dati] Caricamento fallito per " .. player.Name .. ": " .. tostring(salvati))
		end
	end
	cache[player] = dati
	-- Se il caricamento è fallito non salviamo, per non sovrascrivere i dati veri con quelli predefiniti.
	caricatoBene[player] = ok
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

return Dati
