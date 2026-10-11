-- Interfaccia della campagna: piazzamento dei reggimenti con il resoconto degli esploratori,
-- conto alla rovescia, battaglia, punteggio dei round (al meglio di 5) e risultato con le stelle.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Stile = require(script.Parent.Stile)
local Carta = require(script.Parent.Carta)
local Notifiche = require(script.Parent.Notifiche)
local Prova = require(ReplicatedStorage.Shared.Prova)

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
local evidenziata -- casella sotto il mouse, colorata d'oro solo su questo client
local coloriEvidenziata = {}

local intestazione, titoloLivello, contatore, avviso, bottoneLobby, punteggio
local barraMazzo, bottoneCombatti, scrittaConto, esploratori, carteEsploratori, bannerRound
local risultato, titoloRisultato, stelleRisultato, dettaglioRisultato, spazioPremio, bottoneContinua
local prossimoLivello
local bottoneVinci -- modalità prova (solo in Studio): vince subito il round

local atmosferaOriginale

local ZOOM_INIZIALE = 30
local ZOOM_LOBBY = 14
local zoomOriginale

local function seguiPersonaggio()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	local character = player.Character
	local umanoide = character and character:FindFirstChildOfClass("Humanoid")
	if umanoide then
		camera.CameraSubject = umanoide
	end
end

-- Nel campo il giocatore cammina: telecamera normale che lo segue, ma si può allontanare molto
-- per vedere tutta la battaglia. All'arrivo parte da dietro le file blu, guardando il nemico.
local function impostaCamera()
	seguiPersonaggio()
	if not zoomOriginale then
		zoomOriginale = { player.CameraMinZoomDistance, player.CameraMaxZoomDistance }
	end
	-- Minimo e massimo uguali per un attimo: la telecamera riparte da vicino anche se nella
	-- battaglia prima si era allontanata del tutto.
	player.CameraMaxZoomDistance = ZOOM_INIZIALE
	player.CameraMinZoomDistance = ZOOM_INIZIALE
	task.delay(0.2, function()
		player.CameraMaxZoomDistance = 160
		player.CameraMinZoomDistance = zoomOriginale and zoomOriginale[1] or 0.5
	end)
	workspace.CurrentCamera.CFrame = CFrame.lookAt(info.centro + Vector3.new(0, 34, -112), info.centro + Vector3.new(0, 0, -16))
end

-- Torna alla telecamera normale, riavvicinata: dal campo si poteva essere molto lontani.
local function ripristinaCamera()
	seguiPersonaggio()
	if zoomOriginale then
		local minimo, massimo = zoomOriginale[1], zoomOriginale[2]
		zoomOriginale = nil
		player.CameraMinZoomDistance = math.min(minimo, ZOOM_LOBBY)
		player.CameraMaxZoomDistance = ZOOM_LOBBY
		task.delay(0.2, function()
			player.CameraMaxZoomDistance = massimo
		end)
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
	local raggio = workspace.CurrentCamera:ScreenPointToRay(posizioneSchermo.X, posizioneSchermo.Y)
	local parametri = RaycastParams.new()
	parametri.FilterType = Enum.RaycastFilterType.Include
	parametri.FilterDescendantsInstances = { tabellone }
	local colpo = workspace:Raycast(raggio.Origin, raggio.Direction * 500, parametri)
	-- Ogni casella è un modello fatto di piastrelle: si risale al modello.
	local casella = colpo and colpo.Instance.Parent
	if casella and casella:GetAttribute("Col") then
		return casella
	end
	return nil
end

-- Colora d'oro le piastrelle della casella sotto il mouse (gli Highlight non si vedono con grafica bassa).
local function evidenzia(casella)
	if casella == evidenziata then
		return
	end
	for parte, colore in pairs(coloriEvidenziata) do
		parte.Color = colore
	end
	coloriEvidenziata = {}
	evidenziata = casella
	if casella then
		for _, parte in ipairs(casella:GetChildren()) do
			if parte:IsA("BasePart") then
				coloriEvidenziata[parte] = parte.Color
				parte.Color = parte.Name == "Bordo" and Stile.Colori.Oro or parte.Color:Lerp(Stile.Colori.Oro, 0.75)
			end
		end
	end
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
		Notifiche.mostra(casella:GetAttribute("Terreno") == "fiume" and "You can't deploy in the river." or "That tile is blocked.")
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
	punteggio.Visible = visibile
	esploratori.Visible = visibile
end

-- Il pulsante WIN ROUND c'è solo in modalità prova, mentre si schiera o si combatte.
local function mostraVinci(visibile)
	if bottoneVinci then
		bottoneVinci.Visible = visibile
	end
end

local function testoPunteggio(dati)
	return ("ROUND %d   ·   YOU %d - %d ENEMY   ·   FIRST TO %d"):format(dati.round, dati.vinti, dati.persi, dati.perVincere)
end

-- Resoconto degli esploratori: le carte dell'armata nemica, senza dire dove si schiererà.
local function mostraEsploratori(tipi)
	for _, figlio in ipairs(carteEsploratori:GetChildren()) do
		if figlio:IsA("GuiObject") then
			figlio:Destroy()
		end
	end
	for i, tipo in ipairs(tipi or {}) do
		local carta = Carta.mini(tipo)
		carta.Size = UDim2.new(0, 58, 0, 70)
		carta.AutoButtonColor = false
		carta.LayoutOrder = i
		carta.Parent = carteEsploratori
	end
	-- Alto quanto le carte (due per riga), invece di un riquadro fisso mezzo vuoto.
	local righe = math.max(1, math.ceil(#(tipi or {}) / 2))
	esploratori.Size = UDim2.fromOffset(150, 52 + righe * 78 + 4)
end

local function entraPiazzamento(dati)
	local nuovoCampo = not info or info.arena ~= dati.arena or info.livello ~= dati.livello or dati.round == 1
	info = dati
	fase = "piazzamento"
	risultato.Visible = false
	scrittaConto.Visible = false
	arena = workspace:WaitForChild("Arene"):WaitForChild(dati.arena, 10)
	-- Tra un round e l'altro la telecamera resta dove l'ha messa il giocatore.
	if nuovoCampo then
		impostaCamera()
	end
	impostaAtmosfera(dati.atmosfera)
	titoloLivello.Text = ("%d. %s  ·  %s"):format(dati.livello, string.upper(dati.nome), dati.anno)
	punteggio.Text = testoPunteggio(dati)
	usate = {}
	for _, indice in ipairs(dati.usate or {}) do
		usate[indice] = true
	end
	costruisciMazzo()
	selezionata = nil
	selezionaLibera()
	aggiornaCarte()
	mostraEsploratori(dati.esploratori)
	bannerRound.Visible = false
	if dati.assedio then
		avviso.Text = "SIEGE! The enemy hides in a fortress: destroy it and win the battle."
		avviso.TextColor3 = Stile.Colori.Oro
	elseif dati.round == 1 and dati.fiume then
		avviso.Text = "Pick a card, then click a blue tile. No troops in the river: they cross it at the sandy fords."
		avviso.TextColor3 = Stile.Colori.Testo
	elseif dati.round == 1 then
		avviso.Text = "Walk around the field. Pick a card, then click a blue tile. Hills protect troops and help archers."
		avviso.TextColor3 = Stile.Colori.Testo
	else
		avviso.Text = "Your regiments are back in position: change them or press FIGHT!"
		avviso.TextColor3 = Stile.Colori.Testo
	end
	mostraPiazzamento(true)
	mostraVinci(true)
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
	esploratori.Visible = false
	avviso.Text = dati.assedio and "Storm the fortress!" or "The enemy army is revealed!"
	evidenzia(nil)
	task.spawn(contoAllaRovescia, dati.conto or 3)
	task.delay((dati.conto or 3) + 0.2, function()
		if fase == "battaglia" then
			avviso.Text = "Battle in progress..."
		end
	end)
end

-- Fine di un round: grande scritta con il punteggio, poi il server manda il prossimo piazzamento o il risultato.
local function mostraRound(dati)
	fase = "round"
	mostraVinci(false)
	scrittaConto.Visible = false
	bannerRound.Visible = true
	local titolo = bannerRound:FindFirstChild("Titolo")
	titolo.Text = dati.vittoria and "ROUND WON!" or "ROUND LOST"
	titolo.TextColor3 = dati.vittoria and Stile.Colori.Oro or Stile.Colori.Rosso
	bannerRound:FindFirstChild("Punteggio").Text = ("YOU %d - %d ENEMY"):format(dati.vinti, dati.persi)
	punteggio.Text = ("YOU %d - %d ENEMY"):format(dati.vinti, dati.persi)
	local scala = bannerRound:FindFirstChildOfClass("UIScale")
	scala.Scale = 0.6
	TweenService:Create(scala, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	if dati.vittoria and dati.vinti == dati.perVincere - 1 and dati.persi < dati.perVincere - 1 then
		avviso.Text = "Match point! The enemy retreats into its fortress."
	else
		avviso.Text = ""
	end
end

local function mostraRisultato(dati)
	fase = "risultato"
	mostraPiazzamento(false)
	mostraVinci(false)
	scrittaConto.Visible = false
	bannerRound.Visible = false
	risultato.Visible = true
	prossimoLivello = dati.prossimo
	titoloRisultato.Text = dati.vittoria and "VICTORY!" or "DEFEAT"
	titoloRisultato.TextColor3 = dati.vittoria and Stile.Colori.Oro or Stile.Colori.Rosso
	stelleRisultato.Text = string.rep("★", dati.stelle) .. string.rep("☆", 3 - dati.stelle)
	stelleRisultato.Visible = dati.vittoria
	local righe = {
		("%s  ·  rounds %d - %d"):format(dati.nome, dati.vinti, dati.persi),
		("+%d coins    +%d XP"):format(dati.monete, dati.esperienza),
		("Enemy regiments defeated: %d"):format(dati.sconfitti or 0),
		("Regiments lost: %d"):format(dati.persiReggimenti or 0),
	}
	if dati.nuovoLivelloGiocatore then
		table.insert(righe, ("LEVEL UP! You are now level %d."):format(dati.nuovoLivelloGiocatore))
	end
	if dati.nuovaEpoca then
		table.insert(righe, "Your army evolves: " .. dati.nuovaEpoca .. " era unlocked! Check your new cards in ARMY.")
	elseif dati.completata and dati.vittoria then
		table.insert(righe, "Campaign complete! New eras are coming soon.")
	elseif not dati.vittoria then
		table.insert(righe, "Tip: read the scouts report and counter it. Infantry beats Cavalry, Cavalry beats Ranged, Ranged beats Infantry.")
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
	dettaglioRisultato.Size = dati.premio and UDim2.new(0.62, -20, 1, -210) or UDim2.new(1, -40, 1, -210)

	if dati.vittoria then
		bottoneContinua.Text = dati.prossimo == dati.numero and "PLAY AGAIN" or "NEXT BATTLE"
	else
		bottoneContinua.Text = "RETRY"
	end
end

-- Esce dalla partita; ripristinaVista = false quando si passa alla mappa, che ha la sua telecamera.
local function esci(ripristinaVista)
	fase = "lobby"
	info = nil
	arena = nil
	mostraPiazzamento(false)
	mostraVinci(false)
	risultato.Visible = false
	scrittaConto.Visible = false
	bannerRound.Visible = false
	evidenzia(nil)
	ripristinaAtmosfera()
	if ripristinaVista then
		ripristinaCamera()
	end
end

local function tornaLobby()
	esci(true)
	if suFineLobby then
		suFineLobby()
	end
end

-- numero: livello da giocare (senza, il prossimo non ancora vinto).
function Partita.avvia(numero)
	local ok, messaggio = remoti.AvviaCampagna:InvokeServer(numero)
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

	punteggio = Stile.titolo({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.fromOffset(520, 24),
		Text = "",
		Visible = false,
		Parent = gui,
	})

	avviso = Stile.testo({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 88),
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

	if Prova then
		bottoneVinci = Stile.bottone({
			Name = "VinciRound",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -18, 0, 10),
			Size = UDim2.fromOffset(190, 46),
			Text = "WIN ROUND",
			Visible = false,
			Parent = gui,
		}, Color3.fromRGB(60, 190, 80))
		bottoneVinci.Activated:Connect(function()
			local ok, messaggio = remoti.VinciRound:InvokeServer()
			if not ok and messaggio then
				Notifiche.mostra(messaggio, Stile.Colori.Rosso)
			end
		end)
	end

	esploratori = Stile.pannello({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.45, 0),
		Size = UDim2.fromOffset(150, 300),
		BackgroundColor3 = Stile.Colori.Sfondo,
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = gui,
	})
	Stile.titolo({
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 0, 22),
		Text = "SCOUTS REPORT",
		TextColor3 = Stile.Colori.Oro,
		Parent = esploratori,
	})
	Stile.testo({
		Position = UDim2.fromOffset(8, 30),
		Size = UDim2.new(1, -16, 0, 14),
		Text = "Enemy regiments this round",
		Font = Stile.FontTesto,
		TextColor3 = Stile.Colori.TestoSecondario,
		Parent = esploratori,
	})
	carteEsploratori = Stile.crea("Frame", {
		Position = UDim2.fromOffset(10, 52),
		Size = UDim2.new(1, -20, 1, -60),
		BackgroundTransparency = 1,
		Parent = esploratori,
	}, {
		Stile.crea("UIGridLayout", {
			CellSize = UDim2.fromOffset(58, 70),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	bannerRound = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(560, 150),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 30,
		Parent = gui,
	}, { Stile.crea("UIScale", {}) })
	local titoloBanner = Stile.titolo({
		Name = "Titolo",
		Size = UDim2.new(1, 0, 0, 96),
		Text = "",
		ZIndex = 31,
		Parent = bannerRound,
	})
	titoloBanner:FindFirstChildOfClass("UIStroke").Thickness = 4
	Stile.titolo({
		Name = "Punteggio",
		Position = UDim2.fromOffset(0, 100),
		Size = UDim2.new(1, 0, 0, 44),
		Text = "",
		ZIndex = 31,
		Parent = bannerRound,
	})

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
		Size = UDim2.fromOffset(600, 450),
		BackgroundColor3 = Stile.Colori.Sfondo,
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	})
	titoloRisultato = Stile.titolo({
		Position = UDim2.fromOffset(20, 14),
		Size = UDim2.new(1, -40, 0, 60),
		ZIndex = 21,
		Parent = risultato,
	})
	stelleRisultato = Stile.titolo({
		Position = UDim2.fromOffset(20, 76),
		Size = UDim2.new(1, -40, 0, 48),
		Text = "",
		Font = Stile.Font,
		TextColor3 = Stile.Colori.Oro,
		ZIndex = 21,
		Parent = risultato,
	})
	dettaglioRisultato = Stile.testo({
		Position = UDim2.fromOffset(28, 132),
		Size = UDim2.new(1, -40, 1, -210),
		Font = Stile.FontTesto,
		TextScaled = false,
		TextSize = 19,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 21,
		Parent = risultato,
	})
	spazioPremio = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 124),
		Size = UDim2.new(0.32, 0, 1, -200),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 21,
		Parent = risultato,
	})
	bottoneContinua = Stile.bottone({
		Position = UDim2.new(0, 20, 1, -70),
		Size = UDim2.fromOffset(240, 52),
		ZIndex = 21,
		Parent = risultato,
	}, Color3.fromRGB(60, 190, 80))
	bottoneContinua.Activated:Connect(function()
		Partita.avvia(prossimoLivello)
	end)
	local mappa = Stile.bottone({
		Position = UDim2.new(0, 272, 1, -70),
		Size = UDim2.fromOffset(148, 52),
		Text = "MAP",
		ZIndex = 21,
		Parent = risultato,
	}, Stile.Colori.Blu)
	mappa.Activated:Connect(function()
		remoti.ApriMappa:InvokeServer()
	end)
	local lobby = Stile.bottone({
		Position = UDim2.new(0, 432, 1, -70),
		Size = UDim2.fromOffset(148, 52),
		Text = "LOBBY",
		ZIndex = 21,
		Parent = risultato,
	}, Stile.Colori.Secondario)
	lobby.Activated:Connect(function()
		remoti.TornaLobby:InvokeServer()
	end)

	UserInputService.InputBegan:Connect(function(input, usatoDaGui)
		if usatoDaGui or fase ~= "piazzamento" then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			clic(Vector2.new(input.Position.X, input.Position.Y))
		end
	end)
	-- Sul telefono si trascina per girare la telecamera: si piazza solo con un tocco secco.
	UserInputService.TouchTap:Connect(function(posizioni, usatoDaGui)
		if not usatoDaGui and fase == "piazzamento" and posizioni[1] then
			clic(posizioni[1])
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if fase ~= "piazzamento" or input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		local casella = casellaSotto(Vector2.new(input.Position.X, input.Position.Y))
		evidenzia(casellaValida(casella) and casella or nil)
	end)

	remoti.Fase.OnClientEvent:Connect(function(dati)
		if dati.fase == "piazzamento" then
			entraPiazzamento(dati)
		elseif dati.fase == "battaglia" then
			entraBattaglia(dati)
		elseif dati.fase == "round" then
			mostraRound(dati)
		elseif dati.fase == "risultato" then
			mostraRisultato(dati)
		elseif dati.fase == "lobby" then
			tornaLobby()
		elseif dati.fase == "mappa" and fase ~= "lobby" then
			esci(false)
		end
	end)
end

return Partita
