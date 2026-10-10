-- Gestione del mazzo: il giocatore sceglie quali carte della collezione portare in battaglia.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Epoche = require(ReplicatedStorage.Shared.Config.Epoche)
local Carte = require(ReplicatedStorage.Shared.Config.Carte)
local Dati = require(script.Parent.Dati)

local Collezione = {}

-- Valida e salva il nuovo mazzo: una lista di tipi, al massimo DIMENSIONE_MAZZO,
-- senza usare più copie di quante il giocatore ne possieda.
function Collezione.salvaMazzo(player, mazzo)
	local dati = Dati.ottieni(player)
	if not dati or typeof(mazzo) ~= "table" then
		return false, "Invalid deck."
	end
	if #mazzo > Carte.DIMENSIONE_MAZZO then
		return false, "A deck can hold at most " .. Carte.DIMENSIONE_MAZZO .. " cards."
	end
	local usate = {}
	local pulito = {}
	for _, tipo in ipairs(mazzo) do
		if typeof(tipo) ~= "string" or not Epoche.Truppe[tipo] then
			return false, "Unknown card."
		end
		usate[tipo] = (usate[tipo] or 0) + 1
		if usate[tipo] > (dati.collezione[tipo] or 0) then
			return false, "You don't own enough copies of that card."
		end
		table.insert(pulito, tipo)
	end
	Dati.modifica(player, function(d)
		d.mazzo = pulito
	end)
	return true
end

function Collezione.inizializza(remoti)
	remoti.SalvaMazzo.OnServerInvoke = Collezione.salvaMazzo
end

return Collezione
