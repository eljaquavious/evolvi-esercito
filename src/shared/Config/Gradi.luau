-- Gradi della ranked (Mattia, 22/10/2026): Bronze I-III, Silver I-III, Gold I-III, Diamond I-III, Ruby I-III,
-- Master, Grandmaster. Si sale con i punti ranked (RP): +30 a vittoria, -20 a sconfitta (mai sotto 0).
-- Ogni divisione vale 100 RP; Master da 1500, Grandmaster da 2000.

local Gradi = {}

Gradi.PUNTI_VITTORIA = 30
Gradi.PUNTI_SCONFITTA = 20

-- Le fasce: nome, colore (per testi e barre), icona (assets/gui/rank_<...>.png), divisioni.
Gradi.Fasce = {
	{ id = "bronze", nome = "Bronze", colore = Color3.fromHex("#E08A4A"), divisioni = 3 },
	{ id = "silver", nome = "Silver", colore = Color3.fromHex("#C9D4E8"), divisioni = 3 },
	{ id = "gold", nome = "Gold", colore = Color3.fromHex("#FFD23F"), divisioni = 3 },
	{ id = "diamond", nome = "Diamond", colore = Color3.fromHex("#5CE1FF"), divisioni = 3 },
	{ id = "ruby", nome = "Ruby", colore = Color3.fromHex("#FF4A6A"), divisioni = 3 },
	{ id = "master", nome = "Master", colore = Color3.fromHex("#C77DFF"), divisioni = 1, punti = 500 },
	{ id = "grandmaster", nome = "Grandmaster", colore = Color3.fromHex("#FF8A1F"), divisioni = 1 },
}

local ROMANI = { "I", "II", "III" }
local PUNTI_DIVISIONE = 100

-- Elenco piatto dei gradi dal più basso: { nome, fascia, minimo }.
Gradi.Lista = {}
do
	local minimo = 0
	for _, fascia in ipairs(Gradi.Fasce) do
		for d = 1, fascia.divisioni do
			table.insert(Gradi.Lista, {
				nome = fascia.divisioni > 1 and (fascia.nome .. " " .. ROMANI[d]) or fascia.nome,
				fascia = fascia,
				minimo = minimo,
			})
			minimo += fascia.punti or PUNTI_DIVISIONE
		end
	end
end

-- Grado per i punti dati: grado, indice, prossimo grado (nil al massimo).
function Gradi.di(punti)
	punti = math.max(0, punti or 0)
	local indice = 1
	for i, g in ipairs(Gradi.Lista) do
		if punti >= g.minimo then
			indice = i
		end
	end
	return Gradi.Lista[indice], indice, Gradi.Lista[indice + 1]
end

-- Settimana delle classifiche settimanali: numero che cambia ogni lunedì alle 00:00 UTC.
local LUNEDI_ZERO = 345600 -- lunedì 5 gennaio 1970, 00:00 UTC
local SETTIMANA = 604800

function Gradi.settimana(tempo)
	return math.floor(((tempo or os.time()) - LUNEDI_ZERO) / SETTIMANA)
end

-- Secondi alla fine della settimana in corso.
function Gradi.fineSettimana(tempo)
	tempo = tempo or os.time()
	return LUNEDI_ZERO + (Gradi.settimana(tempo) + 1) * SETTIMANA - tempo
end

return Gradi
