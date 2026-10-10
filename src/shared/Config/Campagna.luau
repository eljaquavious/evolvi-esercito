-- Livelli della campagna, generati in modo fisso: lo stesso livello ha sempre gli stessi nemici e ostacoli.
-- Ogni epoca ha LIVELLI_PER_EPOCA livelli; finita un'epoca si passa alla successiva.

local Epoche = require(script.Parent.Epoche)
local Biomi = require(script.Parent.Biomi)

local Campagna = {}

Campagna.LIVELLI_PER_EPOCA = 10
Campagna.TOTALE = Campagna.LIVELLI_PER_EPOCA * #Epoche.Lista
Campagna.COLONNE = 6
Campagna.RIGHE = 6
Campagna.RIGHE_GIOCATORE = 3
Campagna.MAX_REGGIMENTI = 6

local function chiave(col, riga)
	return col .. "," .. riga
end

local function cercaCasella(rng, occupate, rigaMin, rigaMax)
	for _ = 1, 50 do
		local col, riga = rng:NextInteger(1, Campagna.COLONNE), rng:NextInteger(rigaMin, rigaMax)
		if not occupate[chiave(col, riga)] then
			return col, riga
		end
	end
	for riga = Campagna.RIGHE_GIOCATORE + 1, Campagna.RIGHE do
		for col = 1, Campagna.COLONNE do
			if not occupate[chiave(col, riga)] then
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
	local occupate = {}

	-- Ostacoli nelle due righe centrali: non si possono occupare né attraversare.
	local ostacoli = {}
	local numeroOstacoli = locale == 1 and 0 or rng:NextInteger(1, 3)
	for _ = 1, numeroOstacoli do
		local col = rng:NextInteger(1, Campagna.COLONNE)
		local riga = rng:NextInteger(Campagna.RIGHE_GIOCATORE, Campagna.RIGHE_GIOCATORE + 1)
		if not occupate[chiave(col, riga)] then
			occupate[chiave(col, riga)] = true
			table.insert(ostacoli, { col = col, riga = riga })
		end
	end

	local numeroNemici = math.min(1 + math.floor(locale * 0.45), Campagna.MAX_REGGIMENTI - 1)
	local nemici = {}
	for _ = 1, numeroNemici do
		local tipo = epoca.truppe[rng:NextInteger(1, #epoca.truppe)]
		local def = Epoche.Truppe[tipo]
		-- I reggimenti a distanza stanno in fondo, gli altri davanti.
		local rigaMin, rigaMax = Campagna.RIGHE_GIOCATORE + 1, Campagna.RIGHE_GIOCATORE + 2
		if def.gittata > 2 then
			rigaMin, rigaMax = Campagna.RIGHE, Campagna.RIGHE
		end
		local col, riga = cercaCasella(rng, occupate, rigaMin, rigaMax)
		if col then
			occupate[chiave(col, riga)] = true
			table.insert(nemici, { tipo = tipo, col = col, riga = riga })
		end
	end

	-- Prima vittoria del livello: una carta dell'epoca, a rotazione.
	local premio = epoca.truppe[(locale - 1) % #epoca.truppe + 1]

	return {
		numero = numero,
		locale = locale,
		indiceEpoca = indiceEpoca,
		epoca = epoca,
		bioma = bioma,
		nemici = nemici,
		ostacoli = ostacoli,
		maxReggimenti = math.min(#nemici + 1, Campagna.MAX_REGGIMENTI),
		forzaNemici = 1 + 0.02 * (locale - 1),
		ricompensa = 40 + 10 * locale + 60 * (indiceEpoca - 1),
		cartaPremio = premio,
		ultimoDellEpoca = locale == Campagna.LIVELLI_PER_EPOCA,
	}
end

return Campagna
