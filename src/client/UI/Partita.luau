-- Interfaccia della campagna: piazzamento dei reggimenti, conto alla rovescia, battaglia e risultato.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Stile = require(script.Parent.Stile)
local Carta = require(script.Parent.Carta)
local Notifiche = require(script.Parent.Notifiche)

local Partita = {}

local player = Players.LocalPlayer
local remoti
local suFineLobby -- callback per tornare all'interfaccia della lobby

local info -- dati del livello in corso
local fase = "lobby"
local selezionata -- indice nel mazzo
local usate = {} -- [indice] = true
local carte = {} -- [indice] = carta nella barra
local arena
local evidenzia

local intestazione, titoloLivello, contatore, avviso, bottoneLobby
local barraMazzo, bottoneCombatti, scrittaConto
local risultato, titoloRisultato, dettaglioRisultato, spazioPremio, bottoneContinua

local atmosferaOriginale

local function impostaCamera()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	-- Più dall'alto e puntata verso il lato del giocatore: la fila più vicina resta sopra la barra delle carte.
	camera.CFrame = CFrame.lookAt(info.centro + Vector3.new(0, 64, -50), info.centro + Vector3.new(0, 0, -9))
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

local function impostaAtmosfera(colore)
	local atmosfera = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosfera or not colore then
		return
	end
	if not atmosferaOriginale then
		atmosferaOriginale = { atmosfera.Color, atmosfera.Decay }
	end
	atmosfera.Color = colore
	atmosfera.Decay = colore:Lerp(Color3.new(0, 0, 0), 0.3)
end

local function ripristinaAtmosfera()
	local atmosfera = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosfera and atmosferaOriginale then
		atmosfera.Color, atmosfera.Decay = atmosferaOriginale[1], atmosferaOriginale[2]
	end
	atmosferaOriginale = nil
end

local function numeroUsate()
	local n = 0
	for _ in pairs(usate) do
		n += 1
	end
	return n
end

local function aggiornaCarte()
	for indice, carta in pairs(carte) do
		Carta.spegni(carta, usate[indice] == true, "DEPLOYED")
		Carta.seleziona(carta, indice == selezionata)
	end
	contatore.Text = ("REGIMENTS %d/%d"):format(numeroUsate(), info.maxReggimenti)
end

local function seleziona(indice)
	selezionata = indice
	aggiornaCarte()
end

-- Dopo un piazzamento passa alla prima carta ancora libera.
local function selezionaLibera()
	if selezionata and not usate[selezionata] then
		return
	end
	selezionata = nil
	for indice = 1, #info.mazzo do
		if not usate[indice] then
			selezionata = indice
			break
		end
	end
end

local function costruisciMazzo()
	for _, carta in pairs(carte) do
		carta:Destroy()
	end
	carte = {}
	for indice, tipo in ipairs(info.mazzo) do
		local carta = Carta.crea(tipo)
		carta.Size = UDim2.new(1 / 6, -10, 1, 0)
		carta.LayoutOrder = indice
		carta.Parent = barraMazzo
		carta.Activated:Connect(function()
			if usate[indice] then
				Notifiche.mostra("Already on the field: click its tile to take it back.")
				return
			end
			seleziona(indice)
		end)
		carte[indice] = carta
	end
end

local function casellaSotto(posizioneSchermo)
	local tabellone = arena and arena:FindFirstChild("Tabellone")
	if not tabellone then
		return nil
	end
	local raggio = workspace.CurrentCamera:ViewportPointToRay(posizioneSchermo.X, posizioneSchermo.Y)
	local parametri = RaycastParams.new()
	parametri.FilterType = Enum.RaycastFilterType.Include
	parametri.FilterDescendantsInstances = { tabellone }
	local colpo = workspace:Raycast(raggio.Origin, raggio.Direction * 500, parametri)
	local casella = colpo and colpo.Instance
	if casella and casella:GetAttribute("Col") then
		return casella
	end
	return nil
end

local function casellaValida(casella)
	return casella and casella:GetAttribute("Riga") <= info.righeGiocatore and not casella:GetAttribute("Ostacolo")
end

local function clic(posizioneSchermo)
	local casella = casellaSotto(posizioneSchermo)
	if not casella then
		return
	end
	if casella:GetAttribute("Riga") > info.righeGiocatore then
		Notifiche.mostra("You can only deploy on the blue tiles.")
		return
	end
	if casella:GetAttribute("Ostacolo") then
		Notifiche.mostra("That tile is blocked.")
		return
	end
	local ok, messaggio, lista = remoti.Casella:InvokeServer(selezionata, casella:GetAttribute("Col"), casella:GetAttribute("Riga"))
	if ok then
		usate = {}
		for _, indice in ipairs(lista or {}) do
			usate[indice] = true
		end
		selezionaLibera()
		aggiornaCarte()
	elseif messaggio then
		Notifiche.mostra(messaggio, Stile.Colori.Rosso)
	end
end

local function mostraPiazzamento(visibile)
	intestazione.Visible = visibile
	barraMazzo.Visible = visibile
	bottoneCombatti.Visible = visibile
	bottoneLobby.Visible = visibile
	avviso.Visible = visibile
end

local function entraPiazzamento(dati)
	info = dati
	fase = "piazzamento"
	risultato.Visible = false
	scrittaConto.Visible = false
	arena = workspace:WaitForChild("Arene"):WaitForChild(dati.arena, 10)
	impostaCamera()
	impostaAtmosfera(dati.atmosfera)
	titoloLivello.Text = ("LEVEL %d/%d  ·  %s  ·  %s"):format(dati.livello, dati.totale, string.upper(dati.epoca), string.upper(dati.bioma))
	usate = {}
	costruisciMazzo()
	selezionata = nil
	selezionaLibera()
	aggiornaCarte()
	avviso.Text = "Pick a card, then click a blue tile. Click a placed regiment to take it back. The enemy is revealed when the battle starts."
	mostraPiazzamento(true)
end

local function contoAllaRovescia(conto)
	scrittaConto.Visible = true
	local scala = scrittaConto:FindFirstChildOfClass("UIScale")
	for numero = conto, 0, -1 do
		if fase ~= "battaglia" then
			break
		end
		scrittaConto.Text = numero > 0 and tostring(numero) or "FIGHT!"
		scrittaConto.TextColor3 = numero > 0 and Stile.Colori.Testo or Stile.Colori.Oro
		scala.Scale = 1.8
		TweenService:Create(scala, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		task.wait(numero > 0 and 1 or 0.8)
	end
	scrittaConto.Visible = false
end

local function entraBattaglia(dati)
	fase = "battaglia"
	barraMazzo.Visible = false
	bottoneCombatti.Visible = false
	bottoneLobby.Visible = false
	avviso.Text = "The enemy army is revealed!"
	evidenzia.Adornee = nil
	task.spawn(contoAllaRovescia, dati.conto or 3)
	task.delay((dati.conto or 3) + 0.2, function()
		if fase == "battaglia" then
			avviso.Text = "Battle in progress..."
		end
	end)
end

local function mostraRisultato(dati)
	fase = "risultato"
	mostraPiazzamento(false)
	scrittaConto.Visible = false
	risultato.Visible = true
	titoloRisultato.Text = dati.vittoria and "VICTORY!" or "DEFEAT"
	titoloRisultato.TextColor3 = dati.vittoria and Stile.Colori.Oro or Stile.Colori.Rosso
	local righe = {
		("+%d coins"):format(dati.monete),
		("Enemy regiments defeated: %d"):format(dati.sconfitti or 0),
		("Regiments lost: %d"):format(dati.persi or 0),
	}
	if dati.nuovaEpoca then
		table.insert(righe, "")
		table.insert(righe, "Your army evolves: " .. dati.nuovaEpoca .. " era unlocked! Check your new cards in ARMY.")
	elseif dati.completata and dati.vittoria then
		table.insert(righe, "")
		table.insert(righe, "Campaign complete! New eras are coming soon.")
	elseif not dati.vittoria then
		table.insert(righe, "")
		table.insert(righe, "Tip: Infantry beats Cavalry, Cavalry beats Ranged, Ranged beats Infantry.")
	end
	dettaglioRisultato.Text = table.concat(righe, "\n")

	for _, figlio in ipairs(spazioPremio:GetChildren()) do
		if figlio:IsA("GuiObject") then
			figlio:Destroy()
		end
	end
	spazioPremio.Visible = dati.premio ~= nil
	if dati.premio then
		Stile.titolo({
			Size = UDim2.new(1, 0, 0, 24),
			Text = "NEW CARD!",
			TextColor3 = Stile.Colori.Oro,
			ZIndex = 22,
			Parent = spazioPremio,
		})
		local carta = Carta.crea(dati.premio)
		carta.AnchorPoint = Vector2.new(0.5, 0)
		carta.Position = UDim2.new(0.5, 0, 0, 30)
		carta.Size = UDim2.new(1, 0, 1, -30)
		carta.ZIndex = 22
		carta.Parent = spazioPremio
	end
	dettaglioRisultato.Size = dati.premio and UDim2.new(0.62, -20, 1, -170) or UDim2.new(1, -40, 1, -170)

	if dati.vittoria then
		bottoneContinua.Text = dati.completata and "PLAY AGAIN" or "NEXT LEVEL"
	else
		bottoneContinua.Text = "RETRY"
	end
end

local function tornaLobby()
	fase = "lobby"
	info = nil
	arena = nil
	mostraPiazzamento(false)
	risultato.Visible = false
	scrittaConto.Visible = false
	evidenzia.Adornee = nil
	ripristinaCamera()
	ripristinaAtmosfera()
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
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(640, 46),
		BackgroundColor3 = Stile.Colori.Sfondo,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = gui,
	})
	titoloLivello = Stile.titolo({
		Position = UDim2.fromOffset(16, 9),
		Size = UDim2.new(0.7, -16, 1, -18),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = intestazione,
	})
	contatore = Stile.titolo({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 11),
		Size = UDim2.new(0.3, -16, 1, -22),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Stile.Colori.Oro,
		Parent = intestazione,
	})

	avviso = Stile.testo({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 62),
		Size = UDim2.fromOffset(640, 22),
		Font = Stile.FontTesto,
		TextStrokeTransparency = 0.3,
		Visible = false,
		Parent = gui,
	})

	bottoneLobby = Stile.bottone({
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.fromOffset(110, 46),
		Text = "LOBBY",
		Visible = false,
		Parent = gui,
	}, Stile.Colori.Secondario)
	bottoneLobby.Activated:Connect(function()
		remoti.TornaLobby:InvokeServer()
	end)

	barraMazzo = Stile.crea("Frame", {
		Name = "Mazzo",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, -100, 1, -14),
		Size = UDim2.fromScale(0.62, 0.23),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	}, {
		Stile.crea("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Stile.crea("UISizeConstraint", { MaxSize = Vector2.new(820, 190) }),
	})

	bottoneCombatti = Stile.bottone({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -18, 1, -18),
		Size = UDim2.fromOffset(190, 70),
		Text = "FIGHT!",
		Visible = false,
		Parent = gui,
	}, Stile.Colori.Rosso)
	bottoneCombatti.Activated:Connect(function()
		local ok, messaggio = remoti.Combatti:InvokeServer()
		if not ok and messaggio then
			Notifiche.mostra(messaggio, Stile.Colori.Rosso)
		end
	end)

	scrittaConto = Stile.titolo({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(500, 140),
		Text = "",
		Visible = false,
		ZIndex = 30,
		Parent = gui,
	})
	Stile.crea("UIScale", { Parent = scrittaConto })
	scrittaConto:FindFirstChildOfClass("UIStroke").Thickness = 4

	risultato = Stile.pannello({
		Name = "Risultato",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(540, 400),
		BackgroundColor3 = Stile.Colori.Sfondo,
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	})
	titoloRisultato = Stile.titolo({
		Position = UDim2.fromOffset(20, 16),
		Size = UDim2.new(1, -40, 0, 64),
		ZIndex = 21,
		Parent = risultato,
	})
	dettaglioRisultato = Stile.testo({
		Position = UDim2.fromOffset(28, 92),
		Size = UDim2.new(1, -40, 1, -170),
		Font = Stile.FontTesto,
		TextScaled = false,
		TextSize = 20,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 21,
		Parent = risultato,
	})
	spazioPremio = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 84),
		Size = UDim2.new(0.34, 0, 1, -160),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 21,
		Parent = risultato,
	})
	bottoneContinua = Stile.bottone({
		Position = UDim2.new(0, 20, 1, -70),
		Size = UDim2.new(0.5, -26, 0, 52),
		ZIndex = 21,
		Parent = risultato,
	}, Stile.Colori.Blu)
	bottoneContinua.Activated:Connect(Partita.avvia)
	local esci = Stile.bottone({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 1, -70),
		Size = UDim2.new(0.5, -26, 0, 52),
		Text = "LOBBY",
		ZIndex = 21,
		Parent = risultato,
	}, Stile.Colori.Secondario)
	esci.Activated:Connect(function()
		remoti.TornaLobby:InvokeServer()
	end)

	evidenzia = Stile.crea("SelectionBox", {
		Color3 = Stile.Colori.Oro,
		LineThickness = 0.15,
		SurfaceTransparency = 0.75,
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
		evidenzia.Adornee = casellaValida(casella) and casella or nil
	end)

	remoti.Fase.OnClientEvent:Connect(function(dati)
		if dati.fase == "piazzamento" then
			entraPiazzamento(dati)
		elseif dati.fase == "battaglia" then
			entraBattaglia(dati)
		elseif dati.fase == "risultato" then
			mostraRisultato(dati)
		elseif dati.fase == "lobby" then
			tornaLobby()
		end
	end)
end

return Partita
