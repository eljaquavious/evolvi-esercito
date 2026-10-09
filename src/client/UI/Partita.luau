-- Interfaccia della campagna: piazzamento delle truppe, battaglia e risultato.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local Stile = require(script.Parent.Stile)
local Notifiche = require(script.Parent.Notifiche)

local Partita = {}

local player = Players.LocalPlayer
local remoti
local suFineLobby -- callback per tornare all'interfaccia della lobby

local info -- dati del livello in corso
local fase = "lobby"
local selezionata
local arena
local evidenzia

local barraTruppe, schedeTruppe = nil, {}
local intestazione, titoloLivello, contatore, bottoneCombatti, avviso
local risultato, titoloRisultato, dettaglioRisultato, bottoneContinua

local nebbiaOriginale

local function impostaCamera()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(info.centro + Vector3.new(0, 52, -50), info.centro + Vector3.new(0, 0, 3))
end

local function ripristinaCamera()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	local character = player.Character
	local umanoide = character and character:FindFirstChildOfClass("Humanoid")
	if umanoide then
		camera.CameraSubject = umanoide
	end
end

local function impostaNebbia(colore)
	if not nebbiaOriginale then
		nebbiaOriginale = { Lighting.FogColor, Lighting.FogStart, Lighting.FogEnd }
	end
	Lighting.FogColor = colore
	Lighting.FogStart = 150
	Lighting.FogEnd = 420
end

local function ripristinaNebbia()
	if nebbiaOriginale then
		Lighting.FogColor, Lighting.FogStart, Lighting.FogEnd = table.unpack(nebbiaOriginale)
		nebbiaOriginale = nil
	end
end

local function aggiornaContatore(numero)
	contatore.Text = ("Truppe %d/%d"):format(numero, info.maxTruppe)
end

local function seleziona(id)
	selezionata = id
	for idScheda, scheda in pairs(schedeTruppe) do
		scheda:FindFirstChildWhichIsA("UIStroke").Color = idScheda == id and Stile.Colori.Oro or Stile.Colori.Bordo
		scheda:FindFirstChildWhichIsA("UIStroke").Thickness = idScheda == id and 3 or 1.5
	end
end

local function costruisciSchede()
	for _, scheda in pairs(schedeTruppe) do
		scheda:Destroy()
	end
	schedeTruppe = {}
	for i, truppa in ipairs(info.truppe) do
		local scheda = Stile.crea("TextButton", {
			Size = UDim2.new(1 / #info.truppe, -10, 1, 0),
			LayoutOrder = i,
			BackgroundColor3 = Stile.Colori.PannelloChiaro,
			AutoButtonColor = true,
			Text = "",
			Parent = barraTruppe,
		}, { Stile.angoli(10), Stile.bordo() })
		Stile.testo({
			Position = UDim2.new(0, 10, 0, 6),
			Size = UDim2.new(1, -20, 0.3, 0),
			Text = truppa.nome,
			Font = Stile.FontTitolo,
			Parent = scheda,
		})
		Stile.testo({
			Position = UDim2.new(0, 10, 0.34, 0),
			Size = UDim2.new(1, -20, 0.2, 0),
			Text = truppa.classe,
			TextColor3 = Stile.Colori.Oro,
			Parent = scheda,
		})
		Stile.testo({
			Position = UDim2.new(0, 10, 0.56, 0),
			Size = UDim2.new(1, -20, 0.18, 0),
			Text = ("❤ %d  ⚔ %d  🎯 %s"):format(truppa.hp, truppa.danno, truppa.gittata > 2 and "Lunga" or "Corta"),
			TextColor3 = Stile.Colori.TestoSecondario,
			Parent = scheda,
		})
		Stile.testo({
			Position = UDim2.new(0, 10, 0.77, 0),
			Size = UDim2.new(1, -20, 0.17, 0),
			Text = truppa.descrizione,
			TextColor3 = Stile.Colori.TestoSecondario,
			Parent = scheda,
		})
		scheda.Activated:Connect(function()
			seleziona(truppa.id)
		end)
		schedeTruppe[truppa.id] = scheda
	end
	seleziona(info.truppe[1].id)
end

local function casellaSotto(posizioneSchermo)
	if not arena then
		return nil
	end
	local tabellone = arena:FindFirstChild("Tabellone")
	if not tabellone then
		return nil
	end
	local camera = workspace.CurrentCamera
	local raggio = camera:ViewportPointToRay(posizioneSchermo.X, posizioneSchermo.Y)
	local parametri = RaycastParams.new()
	parametri.FilterType = Enum.RaycastFilterType.Include
	parametri.FilterDescendantsInstances = { tabellone }
	local colpo = workspace:Raycast(raggio.Origin, raggio.Direction * 500, parametri)
	return colpo and colpo.Instance
end

local function clic(posizioneSchermo)
	local casella = casellaSotto(posizioneSchermo)
	if not casella then
		return
	end
	local col, riga = casella:GetAttribute("Col"), casella:GetAttribute("Riga")
	if riga > 4 then
		Notifiche.mostra("Puoi piazzare le truppe solo nella tua metà del campo.")
		return
	end
	local ok, messaggio, numero = remoti.Casella:InvokeServer(selezionata, col, riga)
	if ok then
		aggiornaContatore(numero)
	elseif messaggio then
		Notifiche.mostra(messaggio, Stile.Colori.Rosso)
	end
end

local function mostraPiazzamento(visibile)
	intestazione.Visible = visibile
	barraTruppe.Visible = visibile
	bottoneCombatti.Visible = visibile
	avviso.Visible = visibile
end

local function entraPiazzamento(dati)
	info = dati
	fase = "piazzamento"
	risultato.Visible = false
	arena = workspace:WaitForChild("Arene"):WaitForChild(dati.arena, 10)
	impostaCamera()
	impostaNebbia(dati.nebbia)
	titoloLivello.Text = ("Livello %d/%d · Epoca %s · %s"):format(dati.livello, dati.totale, dati.epoca, dati.bioma)
	aggiornaContatore(0)
	costruisciSchede()
	avviso.Text = "Scegli una truppa e clicca una casella della tua metà. Clicca una truppa piazzata per toglierla. Il nemico si vedrà all'inizio della battaglia."
	mostraPiazzamento(true)
end

local function entraBattaglia()
	fase = "battaglia"
	barraTruppe.Visible = false
	bottoneCombatti.Visible = false
	avviso.Text = "Battaglia in corso…"
	if evidenzia then
		evidenzia.Adornee = nil
	end
end

local function mostraRisultato(dati)
	fase = "risultato"
	mostraPiazzamento(false)
	risultato.Visible = true
	titoloRisultato.Text = dati.vittoria and "VITTORIA!" or "SCONFITTA"
	titoloRisultato.TextColor3 = dati.vittoria and Stile.Colori.Oro or Stile.Colori.Rosso
	local righe = { "+" .. dati.monete .. " monete" }
	if dati.nuovaEpoca then
		table.insert(righe, "Il tuo esercito evolve: epoca " .. dati.nuovaEpoca .. " sbloccata!")
	elseif dati.completata and dati.vittoria then
		table.insert(righe, "Hai completato la campagna! Nuove epoche in arrivo.")
	end
	dettaglioRisultato.Text = table.concat(righe, "\n")
	bottoneContinua.Text = dati.vittoria and "Prossimo livello" or "Riprova"
end

local function tornaLobby()
	fase = "lobby"
	info = nil
	arena = nil
	mostraPiazzamento(false)
	risultato.Visible = false
	ripristinaCamera()
	ripristinaNebbia()
	if suFineLobby then
		suFineLobby()
	end
end

function Partita.avvia()
	local ok, messaggio = remoti.AvviaCampagna:InvokeServer()
	if not ok and messaggio then
		Notifiche.mostra(messaggio, Stile.Colori.Rosso)
	end
	return ok
end

function Partita.inCorso()
	return fase ~= "lobby"
end

function Partita.inizializza(gui, r, callbackLobby)
	remoti = r
	suFineLobby = callbackLobby

	intestazione = Stile.pannello({
		Name = "Intestazione",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.new(0, 560, 0, 40),
		BackgroundColor3 = Stile.Colori.Sfondo,
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = gui,
	})
	titoloLivello = Stile.testo({
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(0.72, -14, 1, -16),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Stile.FontTitolo,
		Parent = intestazione,
	})
	contatore = Stile.testo({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 8),
		Size = UDim2.new(0.28, -14, 1, -16),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Stile.Colori.Oro,
		Parent = intestazione,
	})

	avviso = Stile.testo({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 110),
		Size = UDim2.new(0, 560, 0, 34),
		TextColor3 = Stile.Colori.Testo,
		TextStrokeTransparency = 0.4,
		TextWrapped = true,
		Visible = false,
		Parent = gui,
	})

	barraTruppe = Stile.crea("Frame", {
		Name = "Truppe",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, -90, 1, -16),
		Size = UDim2.new(0.6, 0, 0, 120),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	}, {
		Stile.crea("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Stile.crea("UISizeConstraint", { MaxSize = Vector2.new(640, 120) }),
	})

	bottoneCombatti = Stile.bottone({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(170, 60),
		Text = "⚔ COMBATTI!",
		Visible = false,
		Parent = gui,
	}, Stile.Colori.Rosso)
	bottoneCombatti.Activated:Connect(function()
		local ok, messaggio = remoti.Combatti:InvokeServer()
		if not ok and messaggio then
			Notifiche.mostra(messaggio, Stile.Colori.Rosso)
		end
	end)

	local esci = Stile.bottone({
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 16, 0, 64),
		Size = UDim2.fromOffset(110, 40),
		Text = "← Lobby",
		Parent = intestazione.Parent,
	}, Stile.Colori.PannelloChiaro)
	esci.Visible = false
	intestazione:GetPropertyChangedSignal("Visible"):Connect(function()
		esci.Visible = intestazione.Visible and fase == "piazzamento"
	end)
	esci.Activated:Connect(function()
		remoti.TornaLobby:InvokeServer()
	end)

	risultato = Stile.pannello({
		Name = "Risultato",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(380, 240),
		BackgroundColor3 = Stile.Colori.Sfondo,
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	})
	titoloRisultato = Stile.testo({
		Position = UDim2.fromOffset(20, 16),
		Size = UDim2.new(1, -40, 0, 54),
		Font = Stile.FontTitolo,
		ZIndex = 21,
		Parent = risultato,
	})
	dettaglioRisultato = Stile.testo({
		Position = UDim2.fromOffset(20, 78),
		Size = UDim2.new(1, -40, 0, 70),
		TextWrapped = true,
		ZIndex = 21,
		Parent = risultato,
	})
	bottoneContinua = Stile.bottone({
		Position = UDim2.new(0, 20, 1, -70),
		Size = UDim2.new(0.5, -26, 0, 50),
		ZIndex = 21,
		Parent = risultato,
	}, Stile.Colori.Blu)
	bottoneContinua.Activated:Connect(Partita.avvia)
	local bottoneLobby = Stile.bottone({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 1, -70),
		Size = UDim2.new(0.5, -26, 0, 50),
		Text = "Lobby",
		ZIndex = 21,
		Parent = risultato,
	}, Stile.Colori.PannelloChiaro)
	bottoneLobby.Activated:Connect(function()
		remoti.TornaLobby:InvokeServer()
	end)

	evidenzia = Stile.crea("SelectionBox", {
		Color3 = Stile.Colori.Oro,
		LineThickness = 0.15,
		SurfaceTransparency = 0.8,
		SurfaceColor3 = Stile.Colori.Oro,
		Parent = gui,
	})

	UserInputService.InputBegan:Connect(function(input, usatoDaGui)
		if usatoDaGui or fase ~= "piazzamento" then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			clic(Vector2.new(input.Position.X, input.Position.Y))
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if fase ~= "piazzamento" or input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		local casella = casellaSotto(Vector2.new(input.Position.X, input.Position.Y))
		if casella and casella:GetAttribute("Riga") <= 4 then
			evidenzia.Adornee = casella
		else
			evidenzia.Adornee = nil
		end
	end)

	remoti.Fase.OnClientEvent:Connect(function(dati)
		if dati.fase == "piazzamento" then
			entraPiazzamento(dati)
		elseif dati.fase == "battaglia" then
			entraBattaglia()
		elseif dati.fase == "risultato" then
			mostraRisultato(dati)
		elseif dati.fase == "lobby" then
			tornaLobby()
		end
	end)
end

return Partita
