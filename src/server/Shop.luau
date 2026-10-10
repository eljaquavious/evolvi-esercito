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
		return false, "Crate not found."
	end
	if cassa.richiedeEpoca and not epocaSbloccata(dati, cassa.richiedeEpoca) then
		return false, "Unlock the " .. Epoche.epoca(cassa.richiedeEpoca).nome .. " era in the campaign to open this crate."
	end
	if not cassa.disponibile then
		return false, cassa.nome .. ": contents coming soon!"
	end
	if cassa.valuta == "Robux" then
		-- Qui andrà MarketplaceService:PromptProductPurchase con il prodotto sviluppatore della cassa.
		return false, "Robux purchases are not active yet."
	end
	if dati.monete < cassa.prezzo then
		return false, "Not enough coins."
	end
	Dati.modifica(player, function(d)
		d.monete -= cassa.prezzo
	end)
	-- Qui andrà l'estrazione del contenuto.
	return true, "You opened the " .. cassa.nome .. "!"
end

function Shop.inizializza(remoti)
	remoti.AcquistaCassa.OnServerInvoke = Shop.acquista
end

return Shop
