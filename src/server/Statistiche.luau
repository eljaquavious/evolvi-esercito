-- Statistiche per il Creator Dashboard di Roblox (Analytics > Funnels e Analytics > Custom events).
-- Servono a capire dove i giocatori smettono di giocare e se usano i comandi della battaglia.
-- Funzionano solo dal server e solo nel gioco pubblicato: in Studio le chiamate si saltano.
--
-- 1) Funnel "primi passi" (onboarding): una volta sola per giocatore, solo per chi è nuovo.
--    Il passo raggiunto si salva nei dati (passoOnboarding), così vale anche tra una visita e l'altra.
--    Chi giocava già prima di questa versione non entra nel funnel (passoOnboarding = FUORI).
-- 2) Funnel "Battaglia" (ripetuto): ogni battaglia della campagna è una sessione del funnel, divisa per livello.
-- 3) Eventi personalizzati: Ordine, Bersaglio, Abilita (quali comandi usano in battaglia),
--    ComandiPerBattaglia (quanti in una battaglia), UscitoInBattaglia (chi chiude il gioco a metà).
-- I nomi si vedono solo nel dashboard (li legge Mattia): in italiano, senza virgole né virgolette.

local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Dati = require(script.Parent.Dati)

local Statistiche = {}

local ATTIVE = not RunService:IsStudio()
local FUORI = 999 -- passoOnboarding di chi non è nel funnel dei primi passi

-- Passi del funnel dei primi passi, in ordine (il numero è la posizione).
Statistiche.PRIMI_PASSI = {
	"Entrato nel gioco", -- 1
	"Tutorial lobby finito", -- 2
	"Mappa aperta", -- 3
	"Battaglia 1 avviata", -- 4
	"Primo FIGHT", -- 5
	"Primo round finito", -- 6
	"Primo round vinto", -- 7
	"Battaglia 1 vinta", -- 8
	"Battaglia 2 avviata", -- 9
	"Battaglia 2 vinta", -- 10
	"Battaglia 3 vinta", -- 11
	"Battaglia 5 vinta", -- 12
	"Prima epoca finita", -- 13
}
local PASSO = {}
for i, nome in ipairs(Statistiche.PRIMI_PASSI) do
	PASSO[nome] = i
end

-- Passi del funnel "Battaglia".
local BATTAGLIA = { "Avviata", "FIGHT", "Round 1 finito", "Round 2 finito", "Finita", "Vinta" }

local escluso = {} -- player -> true: godmode (Mattia), i suoi giri di prova non devono sporcare i dati

local function campi(a, b, c)
	local t = {}
	if a then t[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = a end
	if b then t[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = b end
	if c then t[Enum.AnalyticsCustomFieldKeys.CustomField03.Name] = c end
	return t
end

local function attive(player)
	return ATTIVE and player and player.Parent and not escluso[player]
end

-- In Studio non si manda niente a Roblox: si scrive nell'Output, per collaudare.
local function prova(...)
	if not ATTIVE then
		print("[Statistiche]", ...)
	end
end

-- Nome del livello per dividere i grafici: "L04 Zama".
function Statistiche.nomeLivello(livello)
	return string.format("L%02d %s", livello.numero, livello.nome)
end

-- Da chiamare quando i dati del giocatore sono caricati.
function Statistiche.entrato(player, dati)
	if not dati then
		return
	end
	if Dati.godmode(player) then
		escluso[player] = true
		return
	end
	if dati.passoOnboarding == nil then
		-- Campo nuovo: chi ha già giocato battaglie o è avanti nella campagna non è un giocatore nuovo.
		local vecchio = (dati.statistiche and dati.statistiche.battaglie or 0) > 0 or (dati.livello or 1) > 1
		Dati.modifica(player, function(d)
			d.passoOnboarding = vecchio and FUORI or 0
		end)
	end
	Statistiche.passo(player, "Entrato nel gioco")
end

function Statistiche.uscito(player)
	escluso[player] = nil
end

-- Passo del funnel dei primi passi (nome da PRIMI_PASSI). Conta solo se è più avanti dell'ultimo raggiunto.
function Statistiche.passo(player, nome)
	local n = PASSO[nome]
	local dati = Dati.ottieni(player)
	if not n or not dati or not dati.passoOnboarding or dati.passoOnboarding >= FUORI then
		return
	end
	if n <= dati.passoOnboarding and n ~= 1 then
		return
	end
	if n > dati.passoOnboarding then
		Dati.modifica(player, function(d)
			d.passoOnboarding = n
		end)
	end
	prova("primi passi", n, nome)
	if attive(player) then
		pcall(AnalyticsService.LogOnboardingFunnelStepEvent, AnalyticsService, player, n, nome)
	end
end

-- Funnel "Battaglia": sessione = la sessione della campagna (le si aggiunge un id), passo = indice in BATTAGLIA.
function Statistiche.battaglia(player, sessione, passo)
	if not sessione.idStatistiche then
		sessione.idStatistiche = HttpService:GenerateGUID(false)
		sessione.passoStatistiche = 0
		sessione.comandi = 0
	end
	if passo <= sessione.passoStatistiche then
		return
	end
	sessione.passoStatistiche = passo
	prova("battaglia", Statistiche.nomeLivello(sessione.livello), passo, BATTAGLIA[passo])
	if attive(player) then
		pcall(AnalyticsService.LogFunnelStepEvent, AnalyticsService, player, "Battaglia", sessione.idStatistiche, passo,
			BATTAGLIA[passo], campi(Statistiche.nomeLivello(sessione.livello)))
	end
end

-- Evento personalizzato (nome, valore numerico, fino a 3 campi di testo).
function Statistiche.evento(player, nome, valore, a, b, c)
	prova("evento", nome, valore, a, b, c)
	if attive(player) then
		pcall(AnalyticsService.LogCustomEvent, AnalyticsService, player, nome, valore or 1, campi(a, b, c))
	end
end

-- Un comando dato in battaglia (Ordine, Bersaglio, Abilita, Riserva): quale, in che livello e (extra) a che ala.
function Statistiche.comando(player, sessione, tipo, dettaglio, extra)
	sessione.comandi = (sessione.comandi or 0) + 1
	Statistiche.evento(player, tipo, 1, tostring(dettaglio), Statistiche.nomeLivello(sessione.livello), extra)
end

-- Fine della battaglia: quanti comandi ha dato il giocatore in tutta la battaglia.
function Statistiche.fineBattaglia(player, sessione, vittoria)
	Statistiche.evento(player, "ComandiPerBattaglia", sessione.comandi or 0, Statistiche.nomeLivello(sessione.livello),
		vittoria and "Vinta" or "Persa")
end

-- Il giocatore esce dal gioco con una battaglia aperta: in che livello, a che round, in che fase.
function Statistiche.uscitoInBattaglia(player, sessione)
	if not sessione or sessione.fase == "risultato" then
		return
	end
	Statistiche.evento(player, "UscitoInBattaglia", 1, Statistiche.nomeLivello(sessione.livello),
		"Round " .. tostring(sessione.round), tostring(sessione.fase))
end

return Statistiche
