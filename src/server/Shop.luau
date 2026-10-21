-- Shop: casse delle truppe, casse dei cosmetici (armeria) e pacchetti di monete.
-- Da ogni cassa esce una sola cosa. Le regole e le probabilità sono in Shared/Config/Casse.luau.
-- Il risultato arriva al client con l'evento CassaAperta (anche dopo un acquisto in Robux).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Casse = require(ReplicatedStorage.Shared.Config.Casse)
local Carte = require(ReplicatedStorage.Shared.Config.Carte)
local Epoche = require(ReplicatedStorage.Shared.Config.Epoche)
local ConfigRicompense = require(ReplicatedStorage.Shared.Config.Ricompense)
local Dati = require(script.Parent.Dati)
local Acquisti = require(script.Parent.Acquisti)

local Shop = {}

local remoti
local caso = Random.new()
local ultimo = {} -- player -> os.clock() dell'ultimo acquisto, contro i doppi clic

-- Sceglie una chiave con i pesi dati, solo tra quelle che hanno candidati. nil se nessuna.
local function scegliRarita(pesi, candidati)
	local totale = 0
	for chiave, peso in pairs(pesi) do
		if peso > 0 and candidati[chiave] and #candidati[chiave] > 0 then
			totale += peso
		end
	end
	if totale <= 0 then
		return nil
	end
	local x = caso:NextNumber() * totale
	for chiave, peso in pairs(pesi) do
		if peso > 0 and candidati[chiave] and #candidati[chiave] > 0 then
			x -= peso
			if x <= 0 then
				return chiave
			end
		end
	end
	return nil
end

local function aCaso(lista)
	return lista[caso:NextInteger(1, #lista)]
end

-- Carte divise per rarità che soddisfano il filtro.
local function cartePerRarita(filtro)
	local gruppi = {}
	for _, tipo in ipairs(Epoche.carte()) do
		local def = Epoche.Truppe[tipo]
		if def and filtro(tipo, def) then
			local r = Carte.rarita(def)
			gruppi[r] = gruppi[r] or {}
			table.insert(gruppi[r], tipo)
		end
	end
	return gruppi
end

-- Estrae la carta di una cassa delle truppe: nuova con probabilità cassa.nuova, altrimenti una copia.
local function estraiTruppa(dati, cassa)
	local function posseduta(tipo)
		return (dati.collezione[tipo] or 0) > 0
	end
	local nuove = cartePerRarita(function(tipo)
		return not posseduta(tipo)
	end)
	-- Le copie: mai i comandanti (sono unici).
	local copie = cartePerRarita(function(tipo, def)
		return posseduta(tipo) and not def.comandante
	end)
	local vuoleNuova = caso:NextNumber() < cassa.nuova
	local ordine = vuoleNuova and { { nuove, true }, { copie, false } } or { { copie, false }, { nuove, true } }
	for _, tentativo in ipairs(ordine) do
		local r = scegliRarita(cassa.pesi, tentativo[1])
		if r then
			return aCaso(tentativo[1][r]), tentativo[2], r
		end
	end
	-- Pesi a zero per tutto quello che resta (es. solo comandanti nuovi in una Small): qualsiasi copia.
	for _, gruppo in pairs(copie) do
		if #gruppo > 0 then
			local tipo = aCaso(gruppo)
			return tipo, false, Carte.rarita(Epoche.Truppe[tipo])
		end
	end
	return nil
end

-- Cosmetici dell'armeria che il giocatore non ha ancora, divisi per rarità.
local function cosmeticiMancanti(dati)
	local gruppi, quanti = {}, 0
	for _, c in ipairs(ConfigRicompense.Cosmetici) do
		if c.cassa and not dati.cosmetici[c.id] then
			gruppi[c.rarita] = gruppi[c.rarita] or {}
			table.insert(gruppi[c.rarita], c.id)
			quanti += 1
		end
	end
	return gruppi, quanti
end

local function estraiCosmetico(dati, cassa)
	local gruppi = cosmeticiMancanti(dati)
	local r = scegliRarita(cassa.pesi, gruppi)
	if not r then
		-- Restano solo rarità che questa cassa non dà (es. comuni nella Big): uno qualsiasi di quelli mancanti.
		for rarita, lista in pairs(gruppi) do
			if #lista > 0 then
				r = rarita
				break
			end
		end
	end
	return r and aCaso(gruppi[r]) or nil
end

-- Apre la cassa (già pagata) e manda il risultato al client. Restituisce true se ha dato qualcosa.
local function apri(player, cassa, tipo)
	local dati = Dati.ottieni(player)
	if not dati then
		return false
	end
	local risultato
	if tipo == "truppe" then
		local carta, nuova = estraiTruppa(dati, cassa)
		if not carta then
			return false
		end
		Dati.modifica(player, function(d)
			Dati.aggiungiCarta(d, carta)
			d.casseAperte += 1
		end)
		risultato = { tipo = "truppa", id = carta, nuova = nuova, copie = Dati.ottieni(player).collezione[carta] }
	elseif tipo == "cosmetici" then
		local id = estraiCosmetico(dati, cassa)
		if not id then
			-- Ha già tutto (può succedere solo se ha comprato con Robux mentre gli mancava l'ultimo): monete.
			Dati.modifica(player, function(d)
				d.monete += 1500
			end)
			risultato = { tipo = "monete", quante = 1500 }
		else
			Dati.modifica(player, function(d)
				d.cosmetici[id] = true
				d.casseAperte += 1
			end)
			risultato = { tipo = "cosmetico", id = id }
		end
	elseif tipo == "monete" then
		Dati.modifica(player, function(d)
			d.monete += cassa.monete
		end)
		risultato = { tipo = "monete", quante = cassa.monete }
	end
	risultato.cassa = cassa.id
	remoti.CassaAperta:FireClient(player, risultato)
	return true
end

function Shop.acquista(player, id)
	local cassa, tipo = Casse.trova(id)
	local dati = Dati.ottieni(player)
	if not cassa or not dati then
		return false, "Item not found."
	end
	local adesso = os.clock()
	if ultimo[player] and adesso - ultimo[player] < 1 then
		return false
	end
	ultimo[player] = adesso
	if tipo == "cosmetici" then
		local _, quanti = cosmeticiMancanti(dati)
		if quanti == 0 then
			return false, "You already own every Armory item!"
		end
	end
	if cassa.robux then
		return Acquisti.chiedi(player, cassa.robux.prodotto, function(p)
			return apri(p, cassa, tipo)
		end)
	end
	if dati.monete < cassa.monete then
		return false, "Not enough coins."
	end
	Dati.modifica(player, function(d)
		d.monete -= cassa.monete
	end)
	if not apri(player, cassa, tipo) then
		-- Non doveva succedere: rende le monete.
		Dati.modifica(player, function(d)
			d.monete += cassa.monete
		end)
		return false, "Something went wrong, your coins are back."
	end
	return true
end

function Shop.inizializza(r)
	remoti = r
	remoti.AcquistaCassa.OnServerInvoke = Shop.acquista
	for _, gruppo in ipairs({ { Casse.Truppe, "truppe" }, { Casse.Cosmetici, "cosmetici" }, { Casse.Monete, "monete" } }) do
		for _, cassa in ipairs(gruppo[1]) do
			if cassa.robux then
				Acquisti.registra(cassa.robux.prodotto, function(p)
					return apri(p, cassa, gruppo[2])
				end)
			end
		end
	end
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		ultimo[player] = nil
	end)
end

return Shop
