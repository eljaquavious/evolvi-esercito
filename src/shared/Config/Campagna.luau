-- Livelli della campagna, generati in modo fisso: lo stesso livello ha sempre gli stessi nemici.
-- Ogni epoca ha LIVELLI_PER_EPOCA livelli; finita un'epoca si passa alla successiva.

local Epoche = require(script.Parent.Epoche)
local Biomi = require(script.Parent.Biomi)

local Campagna = {}

Campagna.LIVELLI_PER_EPOCA = 10
Campagna.TOTALE = Campagna.LIVELLI_PER_EPOCA * #Epoche.Lista
Campagna.RIGHE_GIOCATORE = 4

local function cercaCasella(rng, occupate, rigaMin, rigaMax)
	for _ = 1, 50 do
		local col, riga = rng:NextInteger(1, 8), rng:NextInteger(rigaMin, rigaMax)
		if not occupate[col .. "," .. riga] then
			return col, riga
		end
	end
	for riga = 5, 8 do
		for col = 1, 8 do
			if not occupate[col .. "," .. riga] then
				return col, riga
			end
		end
	end
	return nil
end

function Campagna.livello(numero)
	numero = math.clamp(numero, 1, Campagna.TOTALE)
	local indiceEpoca = math.floor((numero - 1) / Campagna.LIVELLI_PER_EPOCA) + 1
	local epoca = Epoche.Lista[indiceEpoca]
	local locale = (numero - 1) % Campagna.LIVELLI_PER_EPOCA + 1
	local bioma = Biomi.Ordine[(numero - 1) % #Biomi.Ordine + 1]

	local rng = Random.new(numero * 7919)
	local numeroNemici = math.min(2 + math.floor(locale * 0.7), 9)
	local nemici = {}
	local occupate = {}
	for _ = 1, numeroNemici do
		local tipo = epoca.truppe[rng:NextInteger(1, #epoca.truppe)]
		local def = Epoche.Truppe[tipo]
		-- Le truppe a distanza stanno dietro, le altre davanti.
		local rigaMin, rigaMax = 5, 6
		if def.gittata > 2 then
			rigaMin, rigaMax = 7, 8
		end
		local col, riga = cercaCasella(rng, occupate, rigaMin, rigaMax)
		if col then
			occupate[col .. "," .. riga] = true
			table.insert(nemici, { tipo = tipo, col = col, riga = riga })
		end
	end

	return {
		numero = numero,
		locale = locale,
		indiceEpoca = indiceEpoca,
		epoca = epoca,
		bioma = bioma,
		nemici = nemici,
		maxTruppe = #nemici + 1,
		forzaNemici = 1 + 0.015 * (locale - 1),
		ricompensa = 40 + 10 * locale + 60 * (indiceEpoca - 1),
		ultimoDellEpoca = locale == Campagna.LIVELLI_PER_EPOCA,
	}
end

return Campagna
