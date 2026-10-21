local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local versione = require(ReplicatedStorage.Shared.Versione)
local Stile = require(script.UI.Stile)
local Notifiche = require(script.UI.Notifiche)
local Hud = require(script.UI.Hud)
local Shop = require(script.UI.Shop)
local AperturaCassa = require(script.UI.AperturaCassa)
local Inventario = require(script.UI.Inventario)
local Profilo = require(script.UI.Profilo)
local Partita = require(script.UI.Partita)
local Mappa = require(script.UI.Mappa)
local Armadio = require(script.UI.Armadio)
local Impostazioni = require(script.UI.Impostazioni)
local Truppe = require(script.Truppe)
local Paesaggio = require(script.Paesaggio)
local LobbyVita = require(script.LobbyVita)
local Mantelli = require(script.Mantelli)
local Cinematica = require(script.Cinematica)

local player = Players.LocalPlayer
local cartellaRemoti = ReplicatedStorage:WaitForChild("Remoti")
local remoti = {}
for _, remoto in ipairs(cartellaRemoti:GetChildren()) do
	remoti[remoto.Name] = remoto
end

local gui = Stile.crea("ScreenGui", {
	Name = "EvolviEsercito",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	IgnoreGuiInset = false,
	Parent = player:WaitForChild("PlayerGui"),
})

Notifiche.inizializza(gui)
require(script.UI.Preferiti).inizializza(remoti)
require(script.Chat).inizializza()
require(script.Suoni).musica("lobby")
Truppe.inizializza(remoti)
LobbyVita.inizializza(remoti)
Mantelli.inizializza()
task.spawn(Paesaggio.inizializza)
Shop.inizializza(gui, remoti)
AperturaCassa.inizializza(gui, remoti)
Inventario.inizializza(gui, remoti)
Profilo.inizializza(gui)
Impostazioni.inizializza(gui, remoti)
Mappa.inizializza(gui, remoti)
Armadio.inizializza(gui, remoti, {
	-- Gli sblocchi si festeggiano in lobby, non in mezzo a una battaglia o sulla mappa.
	puoMostrare = function()
		return not Partita.inCorso() and not Mappa.aperta()
	end,
})

-- Una sola finestra aperta alla volta.
local finestre = { Shop, Inventario, Profilo, Armadio, Impostazioni }
local function chiudiFinestre(tranne)
	for _, finestra in ipairs(finestre) do
		if finestra ~= tranne then
			finestra.chiudi()
		end
	end
end
local function alterna(finestra)
	return function()
		chiudiFinestre(finestra)
		finestra.alterna()
	end
end

local function notificaSeFallisce(ok, messaggio)
	if not ok and messaggio then
		Notifiche.mostra(messaggio, Stile.Colori.Rosso)
	end
end

Hud.inizializza(gui, {
	play = function()
		chiudiFinestre()
		notificaSeFallisce(remoti.ApriMappa:InvokeServer())
	end,
	esercito = alterna(Inventario),
	shop = alterna(Shop),
	profilo = alterna(Profilo),
	impostazioni = alterna(Impostazioni),
	ranked = function()
		remoti.Ranked:InvokeServer()
	end,
	armadio = function()
		chiudiFinestre(Armadio)
		Armadio.alterna("COSMETICS")
	end,
	codici = function()
		chiudiFinestre(Armadio)
		Armadio.alterna("CODES")
	end,
})
Armadio.collegaNovita(Hud.mostraNovita)
-- Un cosmetico delle casse nel Locker porta allo shop.
Armadio.apriShop = function()
	chiudiFinestre(Shop)
	Shop.apri()
end
Partita.inizializza(gui, remoti, function()
	Hud.mostraLobby(true)
end)

local function aggiornaStato(stato)
	Impostazioni.aggiorna(stato)
	Hud.aggiorna(stato)
	Shop.aggiorna(stato)
	Inventario.aggiorna(stato)
	Profilo.aggiorna(stato)
	Armadio.aggiorna(stato)
	Mappa.aggiorna(stato)
	Cinematica.aggiorna(stato)
end

remoti.Fase.OnClientEvent:Connect(function(dati)
	if dati.fase ~= "lobby" then
		Hud.mostraLobby(false)
		chiudiFinestre()
	end
end)
remoti.Stato.OnClientEvent:Connect(aggiornaStato)
remoti.Notifica.OnClientEvent:Connect(function(messaggio)
	Notifiche.mostra(messaggio)
end)
-- Le finestre aperte dalla lobby (bancone dello shop, tavolo ARMY): si aprono, non si alternano,
-- così passarci davanti due volte non le richiude.
local function apriDallaLobby(finestra)
	return function()
		if not Partita.inCorso() and not Mappa.aperta() then
			chiudiFinestre(finestra)
			finestra.apri()
		end
	end
end
remoti.ApriShop.OnClientEvent:Connect(apriDallaLobby(Shop))
remoti.ApriEsercito.OnClientEvent:Connect(apriDallaLobby(Inventario))

task.spawn(function()
	-- I dati possono non essere ancora caricati: riprova finché arrivano.
	for _ = 1, 20 do
		local stato = remoti.ChiediStato:InvokeServer()
		if stato then
			aggiornaStato(stato)
			return
		end
		task.wait(0.5)
	end
end)

print("[Client] Evolvi Esercito avviato, versione " .. versione)
