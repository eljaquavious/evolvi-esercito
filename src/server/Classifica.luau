-- Classifiche della ranked: di sempre (punti RP attuali) e settimanale (RP guadagnati da lunedì).
-- Stanno in due OrderedDataStore: "RankedSempre" e "RankedSettimana_<numero della settimana>" (Config/Gradi).
-- In Studio (place non pubblicato) i DataStore non ci sono: si usa una classifica in memoria con i giocatori
-- di questo server, così la finestra si può collaudare.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gradi = require(ReplicatedStorage.Shared.Config.Gradi)
local Dati = require(script.Parent.Dati)

local Classifica = {}

local QUANTI = 50
local VALIDITA = 60 -- secondi in cui una classifica letta resta buona

local memoria = { sempre = {}, settimana = {} } -- userId -> punti (quando i DataStore mancano)
local cache = {} -- chiave -> { tempo, lista }
local nomi = {} -- userId -> nome

local function archivio(tipo)
	local nome = tipo == "settimana" and ("RankedSettimana_" .. Gradi.settimana()) or "RankedSempre"
	local ok, ds = pcall(function()
		return DataStoreService:GetOrderedDataStore(nome)
	end)
	return ok and ds or nil, nome
end

local function nomeDi(userId)
	if nomi[userId] then
		return nomi[userId]
	end
	local p = Players:GetPlayerByUserId(userId)
	if p then
		nomi[userId] = p.DisplayName
		return nomi[userId]
	end
	local ok, nome = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nomi[userId] = ok and nome or ("Player " .. userId)
	return nomi[userId]
end

-- Salva i punti del giocatore nelle due classifiche (dopo ogni ranked).
function Classifica.registra(player, punti, puntiSettimana)
	memoria.sempre[player.UserId] = punti
	memoria.settimana[player.UserId] = puntiSettimana
	nomi[player.UserId] = player.DisplayName
	for tipo, valore in pairs({ sempre = punti, settimana = puntiSettimana }) do
		local ds = archivio(tipo)
		if ds then
			task.spawn(function()
				local ok, errore = pcall(function()
					ds:SetAsync(tostring(player.UserId), math.floor(valore))
				end)
				if not ok then
					warn("[Classifica] " .. tostring(errore))
				end
			end)
		end
		cache[tipo] = nil
	end
end

local function daMemoria(tipo)
	local lista = {}
	for userId, punti in pairs(memoria[tipo]) do
		table.insert(lista, { userId = userId, punti = punti })
	end
	-- In memoria ci sono anche i giocatori connessi che non hanno ancora giocato una ranked.
	for _, p in ipairs(Players:GetPlayers()) do
		if memoria[tipo][p.UserId] == nil then
			local d = Dati.ottieni(p)
			if d and d.ranked then
				local valore = tipo == "settimana" and (d.ranked.settimana == Gradi.settimana() and d.ranked.puntiSettimana or 0) or d.ranked.punti
				table.insert(lista, { userId = p.UserId, punti = valore })
			end
		end
	end
	table.sort(lista, function(a, b)
		return a.punti > b.punti
	end)
	return lista
end

-- Prime QUANTI posizioni: { { posizione, userId, nome, punti, grado } }. tipo = "sempre" o "settimana".
function Classifica.leggi(_player, tipo)
	if tipo ~= "sempre" and tipo ~= "settimana" then
		return {}
	end
	local c = cache[tipo]
	if c and os.clock() - c.tempo < VALIDITA then
		return c.lista
	end
	local righe
	local ds = archivio(tipo)
	if ds then
		local ok, pagine = pcall(function()
			return ds:GetSortedAsync(false, QUANTI)
		end)
		if ok and pagine then
			righe = {}
			for _, voce in ipairs(pagine:GetCurrentPage()) do
				table.insert(righe, { userId = tonumber(voce.key), punti = voce.value })
			end
		end
	end
	righe = righe or daMemoria(tipo)
	local lista = {}
	for i, r in ipairs(righe) do
		if i > QUANTI then
			break
		end
		local g = Gradi.di(tipo == "sempre" and r.punti or 0)
		table.insert(lista, { posizione = i, userId = r.userId, nome = nomeDi(r.userId), punti = r.punti, grado = tipo == "sempre" and g.nome or nil })
	end
	cache[tipo] = { tempo = os.clock(), lista = lista }
	return lista
end

function Classifica.inizializza(remoti)
	remoti.LeggiClassifica.OnServerInvoke = Classifica.leggi
end

return Classifica
