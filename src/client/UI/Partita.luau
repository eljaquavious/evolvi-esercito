-- Interfaccia della campagna: piazzamento dei reggimenti con il resoconto degli esploratori,
-- conto alla rovescia, battaglia, punteggio dei round (al meglio di 5) e risultato con le stelle.
-- Aspetto come nei mockup 6-battle (piazzamento e battaglia) e 7-victory (risultato).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Stile = require(script.Parent.Stile)
local Carta = require(script.Parent.Carta)
local Icone = require(script.Parent.Icone)
local Notifiche = require(script.Parent.Notifiche)
local Prova = require(ReplicatedStorage.Shared.Prova)
local Epoche = require(ReplicatedStorage.Shared.Config.Epoche)
local Carte = require(ReplicatedStorage.Shared.Config.Carte)

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

-- Tabellone in alto: targhe YOU / Round / ENEMY con i pallini dei round vinti.
local intestazione, titoloLivello, titoloRound, sottotitolo, puntiTu, puntiNemico, timer
local contatore, avviso, bottoneLobby
local barraMazzo, carteMazzo, bottoneCombatti, scrittaConto, esploratori, righeEsploratori, bannerRound
local risultato, scheda, raggi, rotazioneRaggi, stelleRisultato, targaRisultato, titoloRisultato, codeTarga
local battagliaRisultato, pannelloPremi, testoMonete, testoEsperienza, dettaglioRisultato, spazioPremio
local bottoneContinua, testoContinua, bottoneLobbyRisultato
local prossimoLivello
local bottoneVinci -- modalità prova (solo in Studio): vince subito il round

local atmosferaOriginale

local ZOOM_INIZIALE = 30
local ZOOM_LOBBY = 14
local zoomOriginale

local AZZURRO = Stile.PAL.blu.t
local NOTTE_SCURA = Color3.fromHex("#15163A")

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

-- Piccola animazione "pop": la UIScale dell'oggetto parte da "da" e rimbalza a 1.
local function pop(oggetto, da, durata)
	local scala = oggetto:FindFirstChildOfClass("UIScale") or Stile.crea("UIScale", { Parent = oggetto })
	scala.Scale = da or 0
	TweenService:Create(scala, TweenInfo.new(durata or 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- Il messaggio sotto il tabellone scende quando si vede la pillola rossa del conto alla rovescia.
local function posizionaAvviso()
	avviso.Position = UDim2.new(0.5, 0, 0, timer.Visible and 214 or 146)
end

local function mostraTimer(testo)
	timer.Visible = testo ~= nil
	if testo then
		timer:FindFirstChild("Testo").Text = testo
	end
	posizionaAvviso()
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
		carta.Size = UDim2.fromOffset(112, 162)
		carta.LayoutOrder = indice
		carta.Parent = carteMazzo
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
	if casella:GetAttribute("TerraDiNessuno") then
		Notifiche.mostra("That's no man's land: deploy on the blue tiles.")
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
	esploratori.Visible = visibile
	if not visibile then
		mostraTimer(nil)
	end
end

-- Il pulsante WIN ROUND c'è solo in modalità prova, mentre si schiera o si combatte.
local function mostraVinci(visibile)
	if bottoneVinci then
		bottoneVinci.Visible = visibile
	end
end

-- Pallini dei round vinti sotto YOU / ENEMY: oro quelli vinti, scuri gli altri.
local function puntini(contenitore, totale, accesi)
	for _, figlio in ipairs(contenitore:GetChildren()) do
		if figlio.Name == "Punto" then
			figlio:Destroy()
		end
	end
	for i = 1, totale do
		Stile.crea("Frame", {
			Name = "Punto",
			Size = UDim2.fromOffset(28, 28),
			BackgroundColor3 = i <= accesi and Stile.Colori.Oro or NOTTE_SCURA,
			LayoutOrder = i,
			Parent = contenitore,
		}, { Stile.tondo(), Stile.bordo(Stile.CONTORNO, 3) })
	end
end

local function aggiornaPunteggio(dati)
	titoloRound.Text = ("Round %d"):format(dati.round or 1)
	puntini(puntiTu, dati.perVincere or 3, dati.vinti or 0)
	puntini(puntiNemico, dati.perVincere or 3, dati.persi or 0)
end

-- Resoconto degli esploratori: le carte dell'armata nemica, senza dire dove si schiererà.
local function mostraEsploratori(tipi)
	for _, figlio in ipairs(righeEsploratori:GetChildren()) do
		if figlio:IsA("GuiObject") then
			figlio:Destroy()
		end
	end
	tipi = tipi or {}
	for i, tipo in ipairs(tipi) do
		local def = Epoche.Truppe[tipo]
		local riga = Stile.crea("Frame", {
			Name = "Nemico",
			Size = UDim2.new(1, 0, 0, 92),
			BackgroundColor3 = Stile.BIANCO,
			LayoutOrder = i,
			Parent = righeEsploratori,
		}, { Stile.angoli(16), Stile.bordo(Stile.CONTORNO, 4), Stile.sfumatura(Stile.PAL.notte.t, Stile.PAL.notte.b) })
		local carta = Carta.mini(tipo)
		carta.AnchorPoint = Vector2.new(0, 0.5)
		carta.Position = UDim2.new(0, 10, 0.5, 0)
		carta.Size = UDim2.fromOffset(54, 78)
		carta.AutoButtonColor = false
		carta.Parent = riga
		if def then
			local nome = Stile.testo({
				Position = UDim2.fromOffset(76, 10),
				Size = UDim2.new(1, -86, 0, 26),
				Text = string.upper(def.nome),
				TextColor3 = Stile.BIANCO,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = riga,
			})
			Stile.crea("UITextSizeConstraint", { MaxTextSize = 20, Parent = nome })
			Stile.icona(Carta.iconaClasse(def), {
				Position = UDim2.fromOffset(76, 42),
				Size = UDim2.fromOffset(40, 40),
				Parent = riga,
			})
			Stile.scritta({
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -12, 1, -4),
				Size = UDim2.fromOffset(90, 50),
				Text = tostring(Carte.valutazioni(def).OVR),
				TextSize = 44,
				Contorno = 4,
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = riga,
			})
		end
	end
	-- Alto quanto le righe, invece di un riquadro fisso mezzo vuoto.
	local n = math.max(1, #tipi)
	esploratori.Size = UDim2.fromOffset(330, 84 + n * 100 + 40)
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
	aggiornaPunteggio(dati)
	sottotitolo.Text = dati.assedio and "SIEGE! STORM THE FORTRESS" or "PLACE YOUR REGIMENTS"
	sottotitolo.TextColor3 = dati.assedio and Stile.Colori.Oro or AZZURRO
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
	mostraTimer(nil)
	mostraVinci(true)
end

-- Colori dei numeri del conto alla rovescia: 3 blu, 2 verde, 1 oro, FIGHT! arancio.
local COLORI_CONTO = { Stile.PAL.oro.t, Stile.PAL.verde.t, Stile.PAL.blu.t }

local function contoAllaRovescia(conto)
	scrittaConto.Visible = true
	local scala = scrittaConto:FindFirstChildOfClass("UIScale")
	for numero = conto, 0, -1 do
		if fase ~= "battaglia" then
			break
		end
		scrittaConto.Text = numero > 0 and tostring(numero) or "FIGHT!"
		scrittaConto.TextColor3 = numero > 0 and (COLORI_CONTO[numero] or Stile.BIANCO) or Stile.PAL.arancio.t
		mostraTimer(numero > 0 and ("0:%02d"):format(numero) or "GO!")
		scala.Scale = 1.8
		TweenService:Create(scala, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		task.wait(numero > 0 and 1 or 0.8)
	end
	scrittaConto.Visible = false
	if fase == "battaglia" then
		mostraTimer(nil)
		sottotitolo.Text = "FIGHT!"
		sottotitolo.TextColor3 = Stile.PAL.arancio.t
	end
end

local function entraBattaglia(dati)
	fase = "battaglia"
	barraMazzo.Visible = false
	bottoneCombatti.Visible = false
	bottoneLobby.Visible = false
	esploratori.Visible = false
	sottotitolo.Text = "GET READY!"
	sottotitolo.TextColor3 = Stile.Colori.Oro
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
	mostraTimer(nil)
	bannerRound.Visible = true
	local titolo = bannerRound:FindFirstChild("Titolo")
	titolo.Text = dati.vittoria and "ROUND WON!" or "ROUND LOST"
	titolo.TextColor3 = dati.vittoria and Stile.PAL.oro.t or Stile.PAL.rosso.t
	bannerRound:FindFirstChild("Punteggio").Text = ("YOU  %d - %d  ENEMY"):format(dati.vinti, dati.persi)
	aggiornaPunteggio(dati)
	sottotitolo.Text = dati.vittoria and "ROUND WON!" or "ROUND LOST"
	sottotitolo.TextColor3 = dati.vittoria and Stile.Colori.Oro or Stile.PAL.rosso.t
	pop(bannerRound, 0.6)
	if dati.vittoria and dati.vinti == dati.perVincere - 1 and dati.persi < dati.perVincere - 1 then
		avviso.Text = "Match point! The enemy retreats into its fortress."
	else
		avviso.Text = ""
	end
end

-- Stella del risultato: piena se guadagnata, spenta altrimenti (immagine o emoji).
local function coloraStella(stella, accesa)
	if stella:IsA("ImageLabel") then
		stella.ImageTransparency = accesa and 0 or 0.45
		stella.ImageColor3 = accesa and Stile.BIANCO or Color3.fromRGB(120, 110, 90)
	elseif stella:IsA("TextLabel") then
		stella.TextTransparency = accesa and 0 or 0.65
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

	-- Targa: oro per la vittoria, grigia con le code rosse per la sconfitta.
	local pal = dati.vittoria and Stile.PAL.oro or Stile.PAL.grigio
	titoloRisultato.Text = dati.vittoria and "VICTORY!" or "DEFEAT"
	targaRisultato:FindFirstChildOfClass("UIGradient").Color = ColorSequence.new(pal.t, pal.b)
	for _, coda in ipairs(codeTarga) do
		coda.BackgroundColor3 = dati.vittoria and Stile.PAL.oro.d or Stile.PAL.rosso.d
	end
	if raggi then
		raggi.ImageColor3 = dati.vittoria and Stile.PAL.oro.t or Stile.PAL.grigio.t
		raggi.ImageTransparency = dati.vittoria and 0.55 or 0.8
		if rotazioneRaggi then
			rotazioneRaggi:Cancel()
		end
		raggi.Rotation = 0
		rotazioneRaggi = TweenService:Create(raggi, TweenInfo.new(40, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 })
		rotazioneRaggi:Play()
	end

	-- Stelle che compaiono una alla volta.
	local stelle = dati.vittoria and (dati.stelle or 0) or 0
	for i, stella in ipairs(stelleRisultato) do
		coloraStella(stella, i <= stelle)
		local scala = stella:FindFirstChildOfClass("UIScale")
		scala.Scale = 0
		task.delay(0.25 + i * 0.22, function()
			if fase == "risultato" then
				pop(stella, 0, 0.4)
			end
		end)
	end

	battagliaRisultato.Text = ("BATTLE %d  ·  %s"):format(dati.numero or 0, string.upper(dati.nome or ""))
	testoMonete.Text = "+" .. Stile.numero(dati.monete or 0)
	testoEsperienza.Text = ("+%s XP"):format(Stile.numero(dati.esperienza or 0))

	local righe = {
		("Rounds %d - %d\nEnemy regiments defeated: %d  ·  Lost: %d"):format(
			dati.vinti,
			dati.persi,
			dati.sconfitti or 0,
			dati.persiReggimenti or 0
		),
	}
	if dati.nuovoLivelloGiocatore then
		table.insert(righe, ("LEVEL UP! You are now level %d."):format(dati.nuovoLivelloGiocatore))
	end
	if dati.nuovaEpoca then
		table.insert(righe, "NEW ERA! Your army evolves: " .. dati.nuovaEpoca .. " era unlocked! Check your new cards in ARMY.")
	elseif dati.completata and dati.vittoria then
		table.insert(righe, "CAMPAIGN COMPLETE! New eras are coming soon.")
	elseif not dati.vittoria then
		table.insert(righe, "Tip: read the scouts report and counter it. Infantry beats Cavalry, Cavalry beats Ranged, Ranged beats Infantry.")
	end
	dettaglioRisultato.Text = table.concat(righe, "\n")

	-- Carta nuova a destra del pannello dei premi.
	for _, figlio in ipairs(spazioPremio:GetChildren()) do
		if figlio:IsA("GuiObject") then
			figlio:Destroy()
		end
	end
	spazioPremio.Visible = dati.premio ~= nil
	pannelloPremi.Position = UDim2.new(0.5, dati.premio and -140 or 0, 0, 430)
	if dati.premio then
		local carta = Carta.crea(dati.premio)
		carta.AnchorPoint = Vector2.new(0.5, 0)
		carta.Position = UDim2.new(0.5, 0, 0, 30)
		carta.Size = UDim2.fromOffset(240, 348)
		carta.AutoButtonColor = false
		carta.Parent = spazioPremio
		Carta.seleziona(carta, true)
		Stile.nastro({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 14, 0, 30),
			Size = UDim2.fromOffset(230, 56),
			Rotation = 12,
			ZIndex = 6,
			Parent = spazioPremio,
		}, "rosa", "NEW CARD!", 32)
		task.delay(1, function()
			if fase == "risultato" then
				pop(spazioPremio, 0.2, 0.45)
			end
		end)
	end

	if dati.vittoria then
		testoContinua.Text = dati.prossimo == dati.numero and "PLAY AGAIN" or "NEXT BATTLE"
		Stile.coloraPulsante(bottoneContinua, "verde")
		Stile.coloraPulsante(bottoneLobbyRisultato, "verde")
	else
		testoContinua.Text = "RETRY"
		Stile.coloraPulsante(bottoneContinua, "arancio")
		Stile.coloraPulsante(bottoneLobbyRisultato, "grigio")
	end
	pop(scheda, 0.85, 0.3)
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

-- Targa colorata non cliccabile (YOU, ENEMY, intestazione del pannello nemico).
local function targa(proprieta, pal, raggio)
	proprieta.BackgroundColor3 = Stile.BIANCO
	proprieta.BorderSizePixel = 0
	local frame = Stile.crea("Frame", proprieta, {
		Stile.angoli(raggio or 22),
		Stile.bordo(Stile.CONTORNO, 5),
		Stile.sfumatura(pal.t, pal.b),
	})
	Stile.crea("Frame", {
		Name = "Riflesso",
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.new(1, -16, 0.4, 0),
		BackgroundColor3 = Stile.BIANCO,
		BackgroundTransparency = 0.75,
		BorderSizePixel = 0,
		Parent = frame,
	}, { Stile.angoli(math.max(6, (raggio or 22) - 8)) })
	return frame
end

local function filaPuntini(genitore)
	return Stile.crea("Frame", {
		Name = "Puntini",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 52),
		Size = UDim2.fromOffset(160, 28),
		BackgroundTransparency = 1,
		Parent = genitore,
	}, {
		Stile.crea("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

function Partita.inizializza(gui, r, callbackLobby)
	remoti = r
	suFineLobby = callbackLobby
	local tela = Stile.radice(gui)

	-- Tabellone in alto al centro.
	intestazione = Stile.crea("Frame", {
		Name = "Intestazione",
		Size = UDim2.new(1, 0, 0, 140),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 5,
		Parent = tela,
	})
	local tabellone = Stile.crea("Frame", {
		Name = "Tabellone",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(1064, 120),
		BackgroundTransparency = 1,
		Parent = intestazione,
	})
	local tu = targa({
		Name = "Tu",
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.fromOffset(270, 92),
		ZIndex = 1,
		Parent = tabellone,
	}, Stile.PAL.blu)
	Stile.scritta({
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 44),
		Text = "YOU",
		TextSize = 40,
		Parent = tu,
	})
	puntiTu = filaPuntini(tu)
	local nemico = targa({
		Name = "Nemico",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 16),
		Size = UDim2.fromOffset(270, 92),
		ZIndex = 1,
		Parent = tabellone,
	}, Stile.PAL.rosso)
	Stile.scritta({
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 44),
		Text = "ENEMY",
		TextSize = 40,
		Parent = nemico,
	})
	puntiNemico = filaPuntini(nemico)
	local centro = Stile.crea("Frame", {
		Name = "Centro",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(590, 118),
		BackgroundColor3 = Stile.BIANCO,
		ZIndex = 2,
		Parent = tabellone,
	}, { Stile.angoli(30), Stile.bordo(Stile.CONTORNO, 6), Stile.sfumatura(Stile.PAL.notte.t, Stile.PAL.notte.b) })
	titoloRound = Stile.scritta({
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.new(1, 0, 0, 62),
		Text = "Round 1",
		TextSize = 58,
		Contorno = 6,
		Parent = centro,
	})
	sottotitolo = Stile.testo({
		Position = UDim2.fromOffset(20, 76),
		Size = UDim2.new(1, -40, 0, 30),
		Text = "PLACE YOUR REGIMENTS",
		TextColor3 = AZZURRO,
		Parent = centro,
	})
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 26, Parent = sottotitolo })

	-- Pillola rossa sotto il tabellone (conto alla rovescia).
	timer = Stile.crea("Frame", {
		Name = "Timer",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 146),
		Size = UDim2.fromOffset(170, 64),
		BackgroundColor3 = Stile.BIANCO,
		Visible = false,
		ZIndex = 5,
		Parent = tela,
	}, { Stile.tondo(), Stile.bordo(Stile.CONTORNO, 5), Stile.sfumatura(Stile.PAL.rosso.t, Stile.PAL.rosso.b) })
	Stile.scritta({
		Name = "Testo",
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextSize = 44,
		Contorno = 4,
		Parent = timer,
	})

	-- Nome del livello sotto il pulsante LOBBY, in alto a sinistra.
	titoloLivello = Stile.scritta({
		Position = UDim2.fromOffset(28, 104),
		Size = UDim2.fromOffset(380, 34),
		Text = "",
		TextSize = 28,
		Contorno = 3,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = intestazione,
	})
	titoloLivello.TextScaled = true
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 28, Parent = titoloLivello })

	avviso = Stile.scritta({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 146),
		Size = UDim2.fromOffset(1000, 30),
		Text = "",
		TextSize = 24,
		Contorno = 3,
		FontFace = Stile.FontEtichetta,
		Visible = false,
		ZIndex = 5,
		Parent = tela,
	})
	avviso.TextScaled = true
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 24, Parent = avviso })

	bottoneLobby = Stile.pulsante({
		Name = "Lobby",
		Position = UDim2.fromOffset(28, 24),
		Size = UDim2.fromOffset(170, 70),
		Visible = false,
		ZIndex = 6,
		Parent = tela,
	}, "grigio", { Testo = "LOBBY", TestoSize = 32, Icona = "back", IconaSize = 40, Profondita = 7, Raggio = 18 })
	bottoneLobby.Activated:Connect(function()
		remoti.TornaLobby:InvokeServer()
	end)

	-- Vassoio "Your Regiments" in basso con le carte del mazzo.
	barraMazzo = Stile.crea("Frame", {
		Name = "Mazzo",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, -80, 1, -16),
		Size = UDim2.fromOffset(1100, 246),
		BackgroundColor3 = Color3.fromHex("#1E1F45"),
		BackgroundTransparency = 0.12,
		Visible = false,
		ZIndex = 5,
		Parent = tela,
	}, { Stile.angoli(30), Stile.bordo(Stile.CONTORNO, 5) })
	Stile.scritta({
		Position = UDim2.fromOffset(28, 10),
		Size = UDim2.fromOffset(280, 50),
		Text = "Your Regiments",
		TextSize = 40,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = barraMazzo,
	})
	contatore = select(
		2,
		Stile.chip({
			Name = "Contatore",
			Position = UDim2.fromOffset(318, 14),
			Size = UDim2.fromOffset(220, 42),
			Parent = barraMazzo,
		}, "oro", "REGIMENTS 0/0", 24)
	)
	local suggerimento = Stile.testo({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -28, 0, 20),
		Size = UDim2.fromOffset(480, 30),
		Text = "CLICK A CARD, THEN A BLUE TILE",
		TextColor3 = Stile.Colori.Oro,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = barraMazzo,
	})
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 24, Parent = suggerimento })
	carteMazzo = Stile.crea("Frame", {
		Name = "Carte",
		Position = UDim2.fromOffset(20, 70),
		Size = UDim2.new(1, -40, 0, 164),
		BackgroundTransparency = 1,
		Parent = barraMazzo,
	}, {
		Stile.crea("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 56),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	bottoneCombatti = Stile.pulsante({
		Name = "Combatti",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -28, 1, -28),
		Size = UDim2.fromOffset(410, 186),
		Visible = false,
		ZIndex = 6,
		Parent = tela,
	}, "arancio", {
		Testo = "FIGHT!",
		TestoSize = 92,
		Icona = "fight",
		IconaSize = 124,
		IconaX = 28,
		Profondita = 14,
		Raggio = 32,
		Contorno = 6,
	})
	bottoneCombatti.Activated:Connect(function()
		local ok, messaggio = remoti.Combatti:InvokeServer()
		if not ok and messaggio then
			Notifiche.mostra(messaggio, Stile.Colori.Rosso)
		end
	end)

	if Prova then
		bottoneVinci = Stile.pulsante({
			Name = "VinciRound",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -28, 0, 24),
			Size = UDim2.fromOffset(240, 72),
			Visible = false,
			ZIndex = 6,
			Parent = tela,
		}, "verde", { Testo = "WIN ROUND", TestoSize = 34, Profondita = 7 })
		bottoneVinci.Activated:Connect(function()
			local ok, messaggio = remoti.VinciRound:InvokeServer()
			if not ok and messaggio then
				Notifiche.mostra(messaggio, Stile.Colori.Rosso)
			end
		end)
	end

	-- Pannello "Enemy Army" a sinistra: resoconto degli esploratori.
	esploratori = Stile.crea("Frame", {
		Name = "Esploratori",
		Position = UDim2.fromOffset(28, 190),
		Size = UDim2.fromOffset(330, 300),
		BackgroundColor3 = Stile.BIANCO,
		Visible = false,
		ZIndex = 5,
		Parent = tela,
	}, { Stile.angoli(26), Stile.bordo(Stile.CONTORNO, 5), Stile.sfumatura(Stile.PAL.notte.b, Stile.PAL.notte.d) })
	local testata = targa({
		Name = "Testata",
		Size = UDim2.new(1, 0, 0, 72),
		Parent = esploratori,
	}, Stile.PAL.rosso, 24)
	Stile.scritta({
		Position = UDim2.fromOffset(22, 0),
		Size = UDim2.new(1, -30, 1, 0),
		Text = "Enemy Army",
		TextSize = 42,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = testata,
	})
	righeEsploratori = Stile.crea("Frame", {
		Name = "Righe",
		Position = UDim2.fromOffset(14, 86),
		Size = UDim2.new(1, -28, 1, -126),
		BackgroundTransparency = 1,
		Parent = esploratori,
	}, {
		Stile.crea("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local regola = Stile.testo({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -24, 0, 24),
		Text = "CAV BEATS RNG · RNG BEATS INF · INF BEATS CAV",
		TextColor3 = AZZURRO,
		Parent = esploratori,
	})
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 16, Parent = regola })

	-- Grande scritta di fine round.
	bannerRound = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(1000, 220),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 30,
		Parent = tela,
	}, { Stile.crea("UIScale", {}) })
	Stile.scritta({
		Name = "Titolo",
		Size = UDim2.new(1, 0, 0, 140),
		Text = "",
		TextSize = 130,
		Contorno = 12,
		Parent = bannerRound,
	})
	Stile.scritta({
		Name = "Punteggio",
		Position = UDim2.fromOffset(0, 150),
		Size = UDim2.new(1, 0, 0, 64),
		Text = "",
		TextSize = 56,
		Contorno = 6,
		Parent = bannerRound,
	})

	-- Conto alla rovescia al centro dello schermo.
	scrittaConto = Stile.scritta({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(900, 240),
		Text = "",
		TextSize = 200,
		Contorno = 16,
		Visible = false,
		ZIndex = 30,
		Parent = tela,
	})
	Stile.crea("UIScale", { Parent = scrittaConto })

	-- Schermata del risultato: velo scuro, raggi che girano, stelle, targa, premi e pulsanti.
	risultato = Stile.crea("Frame", {
		Name = "Risultato",
		-- Il velo sale oltre il bordo alto, per coprire anche la fascia della barra di Roblox.
		Position = UDim2.fromOffset(0, -200),
		Size = UDim2.new(1, 0, 1, 200),
		BackgroundColor3 = Stile.CONTORNO,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Active = true,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 20,
		Parent = tela,
	})
	risultato:GetPropertyChangedSignal("Visible"):Connect(function()
		if not risultato.Visible and rotazioneRaggi then
			rotazioneRaggi:Cancel()
			rotazioneRaggi = nil
		end
	end)
	local immagineRaggi = Icone.immagine("rays")
	if immagineRaggi then
		raggi = Stile.crea("ImageLabel", {
			Name = "Raggi",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.45, 100),
			Size = UDim2.fromOffset(2200, 2200),
			Image = immagineRaggi,
			ImageTransparency = 0.55,
			BackgroundTransparency = 1,
			Parent = risultato,
		})
	end
	scheda = Stile.crea("Frame", {
		Name = "Scheda",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 100),
		Size = UDim2.fromOffset(1100, 1040),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = risultato,
	}, { Stile.crea("UIScale", {}) })

	stelleRisultato = {}
	local posizioniStelle = { { -180, 70, 150 }, { 0, 30, 180 }, { 180, 70, 150 } }
	for i, p in ipairs(posizioniStelle) do
		local stella = Stile.icona("star", {
			Name = "Stella" .. i,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, p[1], 0, p[2]),
			Size = UDim2.fromOffset(p[3], p[3]),
			Rotation = (i - 2) * 12,
			ZIndex = 3,
			Parent = scheda,
		})
		Stile.crea("UIScale", { Parent = stella })
		stelleRisultato[i] = stella
	end

	-- Targa "VICTORY!" con le code del nastro dietro.
	codeTarga = {}
	for _, lato in ipairs({ -1, 1 }) do
		codeTarga[#codeTarga + 1] = Stile.crea("Frame", {
			Name = "Coda",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, lato * 400, 0, 310),
			Size = UDim2.fromOffset(140, 104),
			Rotation = lato * 22,
			BackgroundColor3 = Stile.PAL.oro.d,
			ZIndex = 3,
			Parent = scheda,
		}, { Stile.angoli(14), Stile.bordo(Stile.CONTORNO, 5) })
	end
	targaRisultato = targa({
		Name = "Targa",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 290),
		Size = UDim2.fromOffset(760, 146),
		ZIndex = 4,
		Parent = scheda,
	}, Stile.PAL.oro, 40)
	targaRisultato:FindFirstChildOfClass("UIStroke").Thickness = 7
	titoloRisultato = Stile.scritta({
		Size = UDim2.fromScale(1, 1),
		Text = "VICTORY!",
		TextSize = 116,
		Contorno = 10,
		Parent = targaRisultato,
	})
	battagliaRisultato = Stile.scritta({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 378),
		Size = UDim2.fromOffset(800, 40),
		Text = "",
		TextSize = 32,
		Contorno = 3,
		FontFace = Stile.FontEtichetta,
		ZIndex = 4,
		Parent = scheda,
	})

	-- Pannello dei premi.
	pannelloPremi = Stile.crea("Frame", {
		Name = "Premi",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 430),
		Size = UDim2.fromOffset(520, 400),
		BackgroundColor3 = Stile.BIANCO,
		ZIndex = 4,
		Parent = scheda,
	}, { Stile.angoli(30), Stile.bordo(Stile.CONTORNO, 6), Stile.sfumatura(Stile.PAL.notte.t, Stile.PAL.notte.d) })
	Stile.scritta({
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.new(1, 0, 0, 50),
		Text = "Rewards",
		TextSize = 44,
		Parent = pannelloPremi,
	})
	Stile.icona("coin", {
		Position = UDim2.fromOffset(70, 74),
		Size = UDim2.fromOffset(88, 88),
		Parent = pannelloPremi,
	})
	testoMonete = Stile.scritta({
		Position = UDim2.fromOffset(180, 78),
		Size = UDim2.fromOffset(300, 80),
		Text = "+0",
		TextSize = 70,
		Contorno = 6,
		TextColor3 = Stile.PAL.oro.t,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = pannelloPremi,
	})
	Stile.icona("level", {
		Position = UDim2.fromOffset(76, 172),
		Size = UDim2.fromOffset(76, 76),
		Parent = pannelloPremi,
	})
	testoEsperienza = Stile.scritta({
		Position = UDim2.fromOffset(180, 172),
		Size = UDim2.fromOffset(300, 76),
		Text = "+0 XP",
		TextSize = 60,
		Contorno = 6,
		TextColor3 = Stile.PAL.acqua.t,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = pannelloPremi,
	})
	dettaglioRisultato = Stile.testo({
		Position = UDim2.fromOffset(26, 262),
		Size = UDim2.new(1, -52, 0, 120),
		Text = "",
		TextColor3 = Stile.BIANCO,
		FontFace = Stile.FontTesto,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = pannelloPremi,
	})
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 21, MinTextSize = 12, Parent = dettaglioRisultato })

	spazioPremio = Stile.crea("Frame", {
		Name = "Premio",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 300, 0, 420),
		Size = UDim2.fromOffset(260, 400),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 5,
		Parent = scheda,
	}, { Stile.crea("UIScale", {}) })

	-- Pulsanti in basso: continua (NEXT BATTLE / RETRY), MAP, LOBBY.
	bottoneContinua, testoContinua = Stile.pulsante({
		Name = "Continua",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, -330, 0, 880),
		Size = UDim2.fromOffset(410, 116),
		ZIndex = 5,
		Parent = scheda,
	}, "verde", { Testo = "NEXT BATTLE", TestoSize = 44, Icona = "fight", IconaSize = 62, Profondita = 10, Raggio = 26 })
	bottoneContinua.Activated:Connect(function()
		Partita.avvia(prossimoLivello)
	end)
	local mappa = Stile.pulsante({
		Name = "Mappa",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 55, 0, 880),
		Size = UDim2.fromOffset(300, 116),
		ZIndex = 5,
		Parent = scheda,
	}, "blu", { Testo = "MAP", TestoSize = 56, Icona = "campaign", IconaSize = 84, Profondita = 10, Raggio = 26 })
	mappa.Activated:Connect(function()
		remoti.ApriMappa:InvokeServer()
	end)
	bottoneLobbyRisultato = Stile.pulsante({
		Name = "Lobby",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 385, 0, 880),
		Size = UDim2.fromOffset(300, 116),
		ZIndex = 5,
		Parent = scheda,
	}, "verde", { Testo = "LOBBY", TestoSize = 56, Icona = "army", IconaSize = 84, Profondita = 10, Raggio = 26 })
	bottoneLobbyRisultato.Activated:Connect(function()
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
