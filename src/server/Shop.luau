-- Shop delle casse. Per ora le casse non hanno contenuti: l'acquisto risponde "in arrivo".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Casse = require(ReplicatedStorage.Shared.Config.Casse)
local Campagna = require(ReplicatedStorage.Shared.Config.Campagna)
local Epoche = require(ReplicatedStorage.Shared.Config.Epoche)
local Dati = require(script.Parent.Dati)

local Shop = {}

local function epocaSbloccata(dati, idEpoca)
	local raggiunta = Campagna.livello(dati.livello).indiceEpoca
	return (Epoche.indice(idEpoca) or math.huge) <= raggiunta
end

function Shop.acquista(player, idCassa)
	local cassa = Casse.trova(idCassa)
	local dati = Dati.ottieni(player)
	if not cassa or not dati then
		return false, "Cassa non trovata."
	end
	if cassa.richiedeEpoca and not epocaSbloccata(dati, cassa.richiedeEpoca) then
		return false, "Sblocca l'epoca " .. cassa.richiedeEpoca .. " nella campagna per aprire questa cassa."
	end
	if not cassa.disponibile then
		return false, "I contenuti della " .. cassa.nome .. " arriveranno presto!"
	end
	if cassa.valuta == "Robux" then
		-- Qui andrà MarketplaceService:PromptProductPurchase con il prodotto sviluppatore della cassa.
		return false, "Acquisti in Robux non ancora attivi."
	end
	if dati.monete < cassa.prezzo then
		return false, "Monete insufficienti."
	end
	Dati.modifica(player, function(d)
		d.monete -= cassa.prezzo
	end)
	-- Qui andrà l'estrazione del contenuto.
	return true, "Hai aperto la " .. cassa.nome .. "!"
end

function Shop.inizializza(remoti)
	remoti.AcquistaCassa.OnServerInvoke = Shop.acquista
end

return Shop
