local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local NomiRemoti = require(Shared.Remoti)
local Campagna = require(Shared.Config.Campagna)
local Progressi = require(Shared.Config.Progressi)
local versione = require(Shared.Versione)

local Dati = require(script.Dati)
local Ambiente = require(script.Ambiente)
local ModelliAsset = require(script.ModelliAsset)
local Lobby = require(script.Lobby)
local GestoreCampagna = require(script.GestoreCampagna)
local Collezione = require(script.Collezione)
local Shop = require(script.Shop)
local MappaCampagna = require(script.MappaCampagna)
local Ricompense = require(script.Ricompense)
local Aspetto = require(script.Aspetto)
local Acquisti = require(script.Acquisti)
local Feedback = require(script.Feedback)

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
		stelle = dati.stelle,
		esperienza = dati.esperienza,
		livelloGiocatore = Progressi.livello(dati.esperienza),
		titoli = dati.titoli,
		titolo = dati.titolo,
		cosmetici = dati.cosmetici,
		indossati = dati.indossati,
		preferito = dati.preferito,
		feedbackPremiato = dati.feedbackPremiato,
		impostazioni = dati.impostazioni,
	}
end

Dati.Cambiato:Connect(function(player)
	-- Il BindableEvent passa una copia della tabella: si lavora sui dati veri.
	local dati = Dati.ottieni(player)
	if not dati then
		return
	end
	-- Prima i titoli e i cosmetici guadagnati con questo cambiamento, così lo stato mandato li comprende.
	Ricompense.controlla(player, dati)
	Aspetto.aggiorna(player, dati)
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

-- Menu Settings: si salvano con i progressi, così valgono anche la volta dopo.
local IMPOSTAZIONI = { musica = true, effetti = true, prestazioni = true }
remoti.Impostazioni.OnServerInvoke = function(player, chiave, valore)
	if typeof(chiave) ~= "string" or not IMPOSTAZIONI[chiave] or typeof(valore) ~= "boolean" or not Dati.ottieni(player) then
		return false
	end
	Dati.modifica(player, function(d)
		d.impostazioni[chiave] = valore
	end)
	return true
end

ModelliAsset.carica()
Ambiente.imposta()
GestoreCampagna.inizializza(remoti)
Collezione.inizializza(remoti)
Acquisti.inizializza()
Ricompense.inizializza(remoti)
Shop.inizializza(remoti)
Feedback.inizializza(remoti)
Aspetto.inizializza(Dati.ottieni)

Lobby.costruisci({
	campagna = function(player)
		local ok, messaggio = GestoreCampagna.apriMappa(player)
		if not ok and messaggio then
			remoti.Notifica:FireClient(player, messaggio)
		end
	end,
	ranked = ranked,
	shop = function(player)
		remoti.ApriShop:FireClient(player)
	end,
	esercito = function(player)
		remoti.ApriEsercito:FireClient(player)
	end,
})

local function giocatoreEntrato(player)
	Dati.carica(player)
end

Players.PlayerAdded:Connect(giocatoreEntrato)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(giocatoreEntrato, player)
	-- In Studio il personaggio può essere nato prima che lo spawn fosse spostato nella Rotonda.
	if player.Character then
		player.Character:PivotTo(Lobby.SPAWN)
	end
end

-- Il plastico della mappa si costruisce a blocchi in qualche secondo: dopo la lobby, per non far aspettare nessuno.
task.spawn(MappaCampagna.costruisci)

Players.PlayerRemoving:Connect(function(player)
	GestoreCampagna.giocatoreUscito(player)
	Ricompense.giocatoreUscito(player)
	Dati.rilascia(player)
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		Dati.salva(player)
	end
end)

print("[Server] Evolvi Esercito avviato, versione " .. versione)
