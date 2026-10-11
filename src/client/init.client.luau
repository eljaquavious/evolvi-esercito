local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local versione = require(ReplicatedStorage.Shared.Versione)
local Stile = require(script.UI.Stile)
local Notifiche = require(script.UI.Notifiche)
local Hud = require(script.UI.Hud)
local Shop = require(script.UI.Shop)
local Inventario = require(script.UI.Inventario)
local Profilo = require(script.UI.Profilo)
local Partita = require(script.UI.Partita)
local Mappa = require(script.UI.Mappa)
local Truppe = require(script.Truppe)

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
Truppe.inizializza(remoti)
Shop.inizializza(gui, remoti)
Inventario.inizializza(gui, remoti)
Profilo.inizializza(gui)
Mappa.inizializza(gui, remoti)

-- Una sola finestra aperta alla volta.
local finestre = { Shop, Inventario, Profilo }
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
	ranked = function()
		remoti.Ranked:InvokeServer()
	end,
})
Partita.inizializza(gui, remoti, function()
	Hud.mostraLobby(true)
end)

local function aggiornaStato(stato)
	Hud.aggiorna(stato)
	Shop.aggiorna(stato)
	Inventario.aggiorna(stato)
	Profilo.aggiorna(stato)
	Mappa.aggiorna(stato)
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
remoti.ApriShop.OnClientEvent:Connect(function()
	if not Partita.inCorso() and not Mappa.aperta() then
		chiudiFinestre(Shop)
		Shop.apri()
	end
end)

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
