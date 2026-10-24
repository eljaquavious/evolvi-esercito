-- Premio giornaliero (richiesta di Mattia, 24/10/2026): 7 premi, uno al giorno; dopo il settimo si riparte dal primo.
-- Il giorno cambia a mezzanotte UTC. Saltare un giorno non fa ripartire da capo: si prende il premio successivo.
-- dati.giornaliero = { giorno = premi già ritirati nel giro in corso (0-6), ultimo = giorno UTC dell'ultimo ritiro }

local Dati = require(script.Parent.Dati)
local Shop = require(script.Parent.Shop)

local Giornaliero = {}

-- monete e, il settimo giorno, anche una Small Crate di truppe (Config/Casse, si apre con l'animazione delle casse).
Giornaliero.PREMI = {
	{ monete = 100 },
	{ monete = 150 },
	{ monete = 200 },
	{ monete = 250 },
	{ monete = 300 },
	{ monete = 400 },
	{ monete = 500, cassa = "CassaPiccola" },
}

local GIORNO = 86400

local function oggi()
	return math.floor(os.time() / GIORNO)
end

-- Quello che il client deve sapere: il premio di oggi (1-7), se si può ritirare, i secondi al giorno dopo.
function Giornaliero.stato(dati)
	local g = dati.giornaliero
	return {
		prossimo = g.giorno + 1,
		disponibile = g.ultimo ~= oggi(),
		mancano = (oggi() + 1) * GIORNO - os.time(),
		premi = Giornaliero.PREMI,
	}
end

function Giornaliero.ritira(player)
	local dati = Dati.ottieni(player)
	if not dati then
		return false, "Loading your data, try again in a moment."
	end
	if dati.giornaliero.ultimo == oggi() then
		return false, "Come back tomorrow for your next reward!"
	end
	local numero = dati.giornaliero.giorno + 1
	local premio = Giornaliero.PREMI[numero]
	Dati.modifica(player, function(d)
		d.monete += premio.monete
		d.statistiche.moneteGuadagnate += premio.monete
		d.giornaliero.ultimo = oggi()
		d.giornaliero.giorno = numero % #Giornaliero.PREMI
	end)
	if premio.cassa then
		task.spawn(Shop.regala, player, premio.cassa)
	end
	return true, ("Day %d reward: +%d coins%s"):format(numero, premio.monete, premio.cassa and " and a Small Crate!" or "!")
end

function Giornaliero.inizializza(remoti)
	remoti.RitiraGiornaliero.OnServerInvoke = Giornaliero.ritira
end

return Giornaliero
