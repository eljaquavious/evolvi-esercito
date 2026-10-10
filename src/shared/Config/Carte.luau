-- Valutazioni da carta (1-99) e OVR, calcolate dalle statistiche dei reggimenti.

local Epoche = require(script.Parent.Epoche)

local Carte = {}

Carte.DIMENSIONE_MAZZO = 6

-- Valore che corrisponde a 99 per ogni statistica.
local MASSIMI = {
	attacco = 140, -- danno al secondo
	vita = 1200,
	velocita = 2.2,
	gittata = 4.2,
	difesa = 0.5,
}

local function valuta(valore, massimo)
	return math.clamp(math.floor(valore / massimo * 99 + 0.5), 1, 99)
end

-- Restituisce { ATK, HP, SPD, RNG, DEF, OVR }.
function Carte.valutazioni(def)
	local v = {
		ATK = valuta(def.danno * def.cadenza * (def.carica and 1.25 or 1) * (def.area and 1.3 or 1), MASSIMI.attacco),
		HP = valuta(def.hp, MASSIMI.vita),
		SPD = valuta(def.velocita, MASSIMI.velocita),
		RNG = valuta(def.gittata, MASSIMI.gittata),
		DEF = valuta(def.armatura, MASSIMI.difesa),
	}
	-- L'OVR pesa di più attacco e vita; parte da una base per l'epoca, così le epoche più avanzate valgono di più.
	local media = v.ATK * 0.3 + v.HP * 0.3 + v.SPD * 0.15 + v.RNG * 0.1 + v.DEF * 0.15
	local base = 30 + 12 * ((Epoche.indice(def.epoca) or 1) - 1)
	v.OVR = math.clamp(math.floor(base + media * 0.55 + 0.5), 1, 99)
	return v
end

Carte.ORDINE_STATISTICHE = { "ATK", "HP", "SPD", "RNG", "DEF" }

return Carte
