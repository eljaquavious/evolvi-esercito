-- Feedback dei giocatori (finestra Codes). Il primo feedback vale un premio in monete.
-- I feedback si salvano nel DataStore "Feedback_v1", una chiave per giorno ("2026-10-21") con la lista del giorno.
-- Si leggono:
--   1) nel gioco, dal pulsante INBOX della finestra Codes (lo vede solo il proprietario del gioco);
--   2) dal Creator Dashboard: il gioco > Data Stores Manager (Data Stores) > Feedback_v1.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Dati = require(script.Parent.Dati)

local Feedback = {}

Feedback.PREMIO = 150 -- monete per il primo feedback
local MINIMO, MASSIMO = 15, 500 -- caratteri
local ATTESA = 120 -- secondi tra un feedback e l'altro
local GIORNI_DA_LEGGERE = 14
local MAX_PER_GIORNO = 400

local archivio
pcall(function()
	archivio = DataStoreService:GetDataStore("Feedback_v1")
end)

local ultimo = {} -- player -> os.clock() dell'ultimo invio

-- Il proprietario del gioco (o del gruppo); in Studio chiunque, per collaudare.
function Feedback.amministratore(player)
	if RunService:IsStudio() then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, grado = pcall(function()
		return player:GetRankInGroup(game.CreatorId)
	end)
	return ok and grado == 255
end

local function giorno(t)
	return os.date("!%Y-%m-%d", t)
end

-- Il testo passa dal filtro di Roblox: chi lo legge è un altro utente.
local function filtra(player, testo)
	local ok, risultato = pcall(function()
		return TextService:FilterStringAsync(testo, player.UserId):GetNonChatStringForBroadcastAsync()
	end)
	return ok and risultato or nil
end

function Feedback.invia(player, testo)
	local dati = Dati.ottieni(player)
	if not dati or typeof(testo) ~= "string" then
		return false, "Something went wrong."
	end
	testo = string.gsub(string.sub(testo, 1, MASSIMO), "^%s+", "")
	testo = string.gsub(testo, "%s+$", "")
	if utf8.len(testo) == nil or #testo < MINIMO then
		return false, ("Write at least %d characters, tell us more!"):format(MINIMO)
	end
	local adesso = os.clock()
	if ultimo[player] and adesso - ultimo[player] < ATTESA then
		return false, "Thanks! You can send another one in a couple of minutes."
	end
	if not archivio then
		return false, "Feedback can't be saved right now. Try again later."
	end
	local pulito = filtra(player, testo)
	if not pulito then
		return false, "Feedback can't be sent right now. Try again later."
	end
	local voce = {
		t = os.time(),
		utente = player.UserId,
		nome = player.Name,
		livello = dati.livello,
		testo = pulito,
	}
	local ok, errore = pcall(function()
		archivio:UpdateAsync(giorno(voce.t), function(lista)
			lista = lista or {}
			if #lista >= MAX_PER_GIORNO then
				table.remove(lista, 1)
			end
			table.insert(lista, voce)
			return lista
		end)
	end)
	if not ok then
		warn("[Feedback] Salvataggio fallito: " .. tostring(errore))
		return false, "Feedback can't be saved right now. Try again later."
	end
	ultimo[player] = adesso
	if not dati.feedbackPremiato then
		Dati.modifica(player, function(d)
			d.feedbackPremiato = true
			d.monete += Feedback.PREMIO
			d.statistiche.moneteGuadagnate += Feedback.PREMIO
		end)
		return true, ("Thanks for your feedback! +%d coins"):format(Feedback.PREMIO)
	end
	return true, "Thanks for your feedback!"
end

-- Ultimi feedback, dal più recente. Solo per l'amministratore.
function Feedback.leggi(player)
	if not Feedback.amministratore(player) then
		return nil
	end
	if not archivio then
		return {}
	end
	local tutti = {}
	local oggi = os.time()
	for i = 0, GIORNI_DA_LEGGERE - 1 do
		local ok, lista = pcall(function()
			return archivio:GetAsync(giorno(oggi - i * 86400))
		end)
		if ok and type(lista) == "table" then
			for j = #lista, 1, -1 do
				table.insert(tutti, lista[j])
			end
		end
		if #tutti >= 300 then
			break
		end
	end
	return tutti
end

function Feedback.inizializza(remoti)
	remoti.InviaFeedback.OnServerInvoke = Feedback.invia
	remoti.LeggiFeedback.OnServerInvoke = Feedback.leggi
	remoti.SonoAdmin.OnServerInvoke = Feedback.amministratore
	Players.PlayerRemoving:Connect(function(player)
		ultimo[player] = nil
	end)
end

return Feedback
