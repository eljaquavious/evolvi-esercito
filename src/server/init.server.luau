local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local NomiRemoti = require(Shared.Remoti)
local Campagna = require(Shared.Config.Campagna)
local versione = require(Shared.Versione)

local Dati = require(script.Dati)
local Ambiente = require(script.Ambiente)
local Lobby = require(script.Lobby)
local GestoreCampagna = require(script.GestoreCampagna)
local Collezione = require(script.Collezione)
local Shop = require(script.Shop)

-- Crea gli eventi tra server e client.
local cartellaRemoti = Instance.new("Folder")
cartellaRemoti.Name = "Remoti"
local remoti = {}
for _, nome in ipairs(NomiRemoti.Eventi) do
	local evento = Instance.new("RemoteEvent")
	evento.Name = nome
	evento.Parent = cartellaRemoti
	remoti[nome] = evento
end
for _, nome in ipairs(NomiRemoti.Funzioni) do
	local funzione = Instance.new("RemoteFunction")
	funzione.Name = nome
	funzione.Parent = cartellaRemoti
	remoti[nome] = funzione
end
cartellaRemoti.Parent = ReplicatedStorage

-- Quello che il client deve sapere del giocatore.
local function stato(dati)
	local livello = Campagna.livello(dati.livello)
	return {
		monete = dati.monete,
		livello = dati.livello,
		totale = Campagna.TOTALE,
		epoca = livello.epoca.nome,
		completata = dati.campagnaCompletata,
		collezione = dati.collezione,
		mazzo = dati.mazzo,
		statistiche = dati.statistiche,
	}
end

Dati.Cambiato:Connect(function(player, dati)
	remoti.Stato:FireClient(player, stato(dati))
end)

remoti.ChiediStato.OnServerInvoke = function(player)
	local dati = Dati.ottieni(player)
	return dati and stato(dati)
end

local function ranked(player)
	remoti.Notifica:FireClient(player, "Ranked is not available yet: coming soon!")
end
remoti.Ranked.OnServerInvoke = function(player)
	ranked(player)
	return false
end

Ambiente.imposta()
GestoreCampagna.inizializza(remoti)
Collezione.inizializza(remoti)
Shop.inizializza(remoti)

Lobby.costruisci({
	campagna = function(player)
		local ok, messaggio = GestoreCampagna.avvia(player)
		if not ok and messaggio then
			remoti.Notifica:FireClient(player, messaggio)
		end
	end,
	ranked = ranked,
	shop = function(player)
		remoti.ApriShop:FireClient(player)
	end,
})

local function giocatoreEntrato(player)
	Dati.carica(player)
end

Players.PlayerAdded:Connect(giocatoreEntrato)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(giocatoreEntrato, player)
end

Players.PlayerRemoving:Connect(function(player)
	GestoreCampagna.giocatoreUscito(player)
	Dati.rilascia(player)
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		Dati.salva(player)
	end
end)

print("[Server] Evolvi Esercito avviato, versione " .. versione)
