local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local versione = require(ReplicatedStorage.Shared.Versione)
local Stile = require(script.UI.Stile)
local Notifiche = require(script.UI.Notifiche)
local Hud = require(script.UI.Hud)
local Shop = require(script.UI.Shop)
local Partita = require(script.UI.Partita)

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
Shop.inizializza(gui, remoti)
Hud.inizializza(gui, {
	campagna = function()
		Shop.chiudi()
		Partita.avvia()
	end,
	ranked = function()
		remoti.Ranked:InvokeServer()
	end,
	shop = function()
		Shop.alterna()
	end,
})
Partita.inizializza(gui, remoti, function()
	Hud.mostraLobby(true)
end)

remoti.Fase.OnClientEvent:Connect(function(dati)
	if dati.fase ~= "lobby" then
		Hud.mostraLobby(false)
		Shop.chiudi()
	end
end)
remoti.Stato.OnClientEvent:Connect(Hud.aggiorna)
remoti.Notifica.OnClientEvent:Connect(function(messaggio)
	Notifiche.mostra(messaggio)
end)
remoti.ApriShop.OnClientEvent:Connect(function()
	if not Partita.inCorso() then
		Shop.apri()
	end
end)

task.spawn(function()
	-- I dati possono non essere ancora caricati: riprova finché arrivano.
	for _ = 1, 20 do
		local stato = remoti.ChiediStato:InvokeServer()
		if stato then
			Hud.aggiorna(stato)
			return
		end
		task.wait(0.5)
	end
end)

print("[Client] Evolvi Esercito avviato, versione " .. versione)
