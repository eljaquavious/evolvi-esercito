-- Titoli, cosmetici e codici: sblocchi giocando, acquisti (monete e Robux), oggetti indossati, codici.
-- Quello che esiste e come si sblocca è in Shared/Config/Ricompense.luau; i codici in ListaCodici.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Ricompense)
local Dati = require(script.Parent.Dati)
local Aspetto = require(script.Parent.Aspetto)
local ListaCodici = require(script.Parent.ListaCodici)
local Acquisti = require(script.Parent.Acquisti)

local Ricompense = {}

local remoti
local ultimoCodice = {} -- player -> os.clock() dell'ultimo tentativo, contro chi prova codici a raffica
local ATTESA_CODICI = 1.5

local function elenco(tipo)
	return tipo == "titolo" and Config.Titoli or Config.Cosmetici
end

local function posseduti(dati, tipo)
	return tipo == "titolo" and dati.titoli or dati.cosmetici
end

-- Sblocca quello che il giocatore si è guadagnato giocando. Modifica i dati sul posto
-- (li chiama init.server prima di mandare lo stato al client) e annuncia le novità.
function Ricompense.controlla(player, dati)
	local nuovi = {}
	for _, tipo in ipairs({ "titolo", "cosmetico" }) do
		local miei = posseduti(dati, tipo)
		for _, oggetto in ipairs(elenco(tipo)) do
			if not miei[oggetto.id] then
				if oggetto.iniziale then
					miei[oggetto.id] = true
				elseif Config.condizioneSoddisfatta(oggetto, dati) then
					miei[oggetto.id] = true
					table.insert(nuovi, { tipo = tipo, id = oggetto.id })
				end
			end
		end
	end
	if #nuovi > 0 and remoti then
		remoti.Sblocco:FireClient(player, nuovi)
	end
end

-- Indossa un titolo o un cosmetico (id = nil per toglierlo; per i cosmetici serve lo slot).
function Ricompense.equipaggia(player, tipo, id, slot)
	local dati = Dati.ottieni(player)
	if not dati or (tipo ~= "titolo" and tipo ~= "cosmetico") then
		return false
	end
	if id ~= nil then
		local oggetto = Config.trova(tipo, id)
		if not oggetto then
			return false, "Unknown item."
		end
		if not posseduti(dati, tipo)[id] then
			return false, "You haven't unlocked this yet."
		end
		slot = oggetto.slot
	end
	if tipo == "titolo" then
		Dati.modifica(player, function(d)
			d.titolo = id or Config.TITOLO_INIZIALE
		end)
	else
		local valido = false
		for _, s in ipairs(Config.Slot) do
			valido = valido or s.id == slot
		end
		if not valido then
			return false
		end
		Dati.modifica(player, function(d)
			d.indossati[slot] = id
		end)
	end
	Aspetto.aggiorna(player, Dati.ottieni(player))
	return true
end

local function dai(d, tipo, id)
	posseduti(d, tipo)[id] = true
end

-- Compra con le monete, oppure apre la finestra di Roblox per i Robux.
function Ricompense.acquista(player, tipo, id)
	local dati = Dati.ottieni(player)
	local oggetto = Config.trova(tipo, id)
	if not dati or not oggetto then
		return false, "Item not found."
	end
	if posseduti(dati, tipo)[id] then
		return false, "You already own " .. oggetto.nome .. "."
	end
	if oggetto.monete then
		if dati.monete < oggetto.monete then
			return false, "Not enough coins."
		end
		Dati.modifica(player, function(d)
			d.monete -= oggetto.monete
			dai(d, tipo, id)
		end)
		return true, "You got " .. oggetto.nome .. "!"
	elseif oggetto.robux then
		return Acquisti.chiedi(player, oggetto.robux.prodotto, function(p)
			return Ricompense.consegna(p, tipo, oggetto.id)
		end)
	end
	return false, "This can't be bought: " .. Config.comeSbloccare(oggetto)
end

-- Acquisto in Robux andato a buon fine (Server/Acquisti): dà l'oggetto e lo annuncia.
function Ricompense.consegna(player, tipo, id)
	if not Dati.ottieni(player) then
		return false
	end
	Dati.modifica(player, function(d)
		dai(d, tipo, id)
	end)
	remoti.Sblocco:FireClient(player, { { tipo = tipo, id = id } })
	return true
end

-- "2027-03-31" -> fine di quel giorno (UTC); nil se la data è scritta male.
local function scadenza(testo)
	local a, m, g = string.match(testo or "", "^(%d+)-(%d+)-(%d+)$")
	if not a then
		return nil
	end
	return os.time({ year = tonumber(a), month = tonumber(m), day = tonumber(g), hour = 23, min = 59, sec = 59 })
end

function Ricompense.riscatta(player, testo)
	local dati = Dati.ottieni(player)
	if not dati or typeof(testo) ~= "string" then
		return false, "Invalid code."
	end
	local adesso = os.clock()
	if ultimoCodice[player] and adesso - ultimoCodice[player] < ATTESA_CODICI then
		return false, "Slow down! Try again in a moment."
	end
	ultimoCodice[player] = adesso
	local codice = string.upper((string.gsub(string.sub(testo, 1, 40), "%s", "")))
	if codice == "" then
		return false, "Type a code first."
	end
	local voce
	for _, c in ipairs(ListaCodici) do
		if string.upper(c.codice) == codice then
			voce = c
		end
	end
	if not voce then
		return false, "That code doesn't exist."
	end
	if dati.codiciUsati[codice] then
		return false, "You already redeemed this code."
	end
	local fine = voce.scade and scadenza(voce.scade)
	if fine and os.time() > fine then
		return false, "This code has expired."
	end
	local premi, nuovi = {}, {}
	Dati.modifica(player, function(d)
		d.codiciUsati[codice] = true
		if voce.monete then
			d.monete += voce.monete
			d.statistiche.moneteGuadagnate += voce.monete
			table.insert(premi, "+" .. voce.monete .. " coins")
		end
		for _, tipo in ipairs({ "titolo", "cosmetico" }) do
			local id = voce[tipo]
			local oggetto = id and Config.trova(tipo, id)
			if oggetto and not posseduti(d, tipo)[id] then
				dai(d, tipo, id)
				table.insert(nuovi, { tipo = tipo, id = id })
				table.insert(premi, (tipo == "titolo" and "title " or "") .. oggetto.nome)
			end
		end
	end)
	if #nuovi > 0 then
		remoti.Sblocco:FireClient(player, nuovi)
	end
	if #premi == 0 then
		return true, "Code redeemed!"
	end
	return true, "Code redeemed! " .. table.concat(premi, ", ")
end

function Ricompense.giocatoreUscito(player)
	ultimoCodice[player] = nil
end

function Ricompense.inizializza(r)
	remoti = r
	remoti.Equipaggia.OnServerInvoke = Ricompense.equipaggia
	remoti.AcquistaOggetto.OnServerInvoke = Ricompense.acquista
	remoti.RiscattaCodice.OnServerInvoke = Ricompense.riscatta
	-- Il server non può controllare i Preferiti (lo sa solo il client): ci si fida, il premio è solo estetico.
	remoti.Preferito.OnServerInvoke = function(player)
		local dati = Dati.ottieni(player)
		if not dati or dati.preferito then
			return false
		end
		Dati.modifica(player, function(d)
			d.preferito = true
		end)
		return true
	end
	for _, tipo in ipairs({ "titolo", "cosmetico" }) do
		for _, oggetto in ipairs(elenco(tipo)) do
			if oggetto.robux then
				Acquisti.registra(oggetto.robux.prodotto, function(p)
					return Ricompense.consegna(p, tipo, oggetto.id)
				end)
			end
		end
	end
end

return Ricompense
