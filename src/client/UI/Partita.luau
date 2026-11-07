-- Interfaccia della campagna: schieramento (carte scelte + formazione storica) con il resoconto degli
-- esploratori, conto alla rovescia, battaglia con gli ordini generali all'armata, cinematica breve tra i
-- round (al meglio di 5) e risultato con le stelle.
-- Aspetto come nei mockup 6-battle (piazzamento e battaglia) e 7-victory (risultato).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")

local Cielo = require(script.Parent.Parent.Cielo)
local Meteo = require(script.Parent.Parent.Meteo)
local Intermezzo = require(script.Parent.Parent.Intermezzo)
local Truppe = require(script.Parent.Parent.Truppe)
local Effetti = require(script.Parent.Parent.Effetti)
local Stile = require(script.Parent.Stile)
local Carta = require(script.Parent.Carta)
local Icone = require(script.Parent.Icone)
local Notifiche = require(script.Parent.Notifiche)
local Prova = require(ReplicatedStorage.Shared.Prova)
local Epoche = require(ReplicatedStorage.Shared.Config.Epoche)
local Carte = require(ReplicatedStorage.Shared.Config.Carte)
local Battaglia = require(ReplicatedStorage.Shared.Battaglia)
local Cinematica = require(script.Parent.Parent.Cinematica)
local Suoni = require(script.Parent.Parent.Suoni)
local Preferiti = require(script.Parent.Preferiti)
local Tutorial = require(script.Parent.Tutorial)
local FineRanked = require(script.Parent.FineRanked)

local Partita = {}

local player = Players.LocalPlayer
local remoti
local suFineLobby -- callback per tornare all'interfaccia della lobby

local info -- dati del livello in corso
local fase = "lobby"
local scelte = {} -- indici del mazzo schierati, in ordine
local usate = {} -- [indice] = true (le stesse scelte, per cercarle in fretta)
local carte = {} -- [indice] = carta nella barra
local arena
-- In battaglia le carte in basso sono i reggimenti sul campo (con l'abilità dei comandanti); gli ordini
-- valgono per tutta l'armata e si danno dal pannello ORDERS (o con i tasti da 1 a 5).
local idPerIndice = {} -- indice del mazzo -> id del reggimento in battaglia
local bottoniAbilita = {} -- id del comandante -> pulsante ABILITY
local suggerimento
local pannelloFormazioni, listaFormazioni, descrizioneFormazione
local bottoniFormazione = {} -- id della formazione -> pulsante
local pannelloOrdini
local bottoniOrdine = {} -- nome dell'ordine -> pulsante
-- Bersagli: dal pannello ORDERS (classe o generale, tasti 6-0) o cliccando un reggimento nemico sul campo.
-- Cliccando una propria carta (o un proprio soldato) il bersaglio vale solo per quel reggimento.
local BERSAGLI = {
	{ filtro = "Fanteria", nome = "Infantry" },
	{ filtro = "Cavalleria", nome = "Cavalry" },
	{ filtro = "Tiratore", nome = "Ranged" },
	{ filtro = "Comandante", nome = "General" },
	{ filtro = nil, nome = "Any" },
}
local bottoniMira = {} -- [i di BERSAGLI] -> pulsante
local miraArmata = nil -- bersaglio di tutta l'armata
local mireReparti = {} -- id del proprio reggimento -> bersaglio suo (false = libero)
local repartoScelto = nil -- id del proprio reggimento selezionato (nil = tutta l'armata)
local titoloMira
local scegliReparto -- definita più sotto (la usano le carte della barra)
local inviando = false -- una richiesta di schieramento alla volta
local inAttesa = nil -- { nuove, formazione }: scelte fatte mentre il server rispondeva, partono subito dopo
local confermate = {} -- le ultime carte schierate confermate dal server (per tornare indietro se rifiuta)
-- Ali (Mattia, 3/11/2026: "ordini per ala, non per tutta l'armata"): gli ordini vanno all'ala scelta
-- (nil = tutta l'armata). Ogni reggimento ha la sua ala, scritta sulla sua carta.
local NOMI_ALA = { sinistra = "LEFT", centro = "CENTER", destra = "RIGHT" }
local alaScelta = nil
local ordiniAli = {} -- ala -> ordine in corso
local caricheAli = {} -- ala -> true se ha già caricato in questo round
local alaDi = {} -- id del proprio reggimento -> ala
local bottoniAla = {} -- ala (o "tutte") -> pulsante
-- Riserva: carte rimaste in mano che si schierano a battaglia iniziata, cliccando la carta e poi il campo.
local riserva = nil -- { mano = { indici }, quante, pronta = os.clock() da cui si può, messe }
local carteRiserva = {} -- indice del mazzo -> carta in mano
-- Comando che aspetta un clic sul campo: { tipo = "riserva", indice } o { tipo = "abilita", id }.
local puntamento = nil
local aggiornaPuntamento, mettiRiserva, convertiRiserva, aggiornaRiserva, cartaInCampo -- definite più sotto

-- Tabellone in alto: targhe YOU / Round / ENEMY con i pallini dei round vinti.
local intestazione, titoloLivello, titoloRound, sottotitolo, puntiTu, puntiNemico, timer
local contatore, avviso, bottoneLobby, nomeNemico
local versioneTimer = 0 -- il conto alla rovescia dello schieramento in ranked si ferma se cambia
local barraMazzo, carteMazzo, bottoneCombatti, scrittaConto, esploratori, righeEsploratori, bannerRound
local risultato, scheda, raggi, rotazioneRaggi, stelleRisultato, targaRisultato, titoloRisultato, codeTarga
local battagliaRisultato, pannelloPremi, testoMonete, testoEsperienza, dettaglioRisultato, spazioPremio
local bottoneContinua, testoContinua, bottoneLobbyRisultato
local prossimoLivello
local bottoneVinci -- modalità prova (solo in Studio): vince subito il round
-- Il pulsante WIN ROUND si vede solo se è true (Mattia, 21/10/2026: in Studio si gioca come un giocatore vero).
-- Il remoto VinciRound resta per i collaudi automatici.
local MOSTRA_WIN_ROUND = false

local ZOOM_INIZIALE = 30
local ZOOM_LOBBY = 14
local zoomOriginale

local AZZURRO = Stile.ACCENTI.blu.t
local NOTTE_SCURA = Color3.fromHex("#15161C")

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
	-- In ranked il secondo giocatore sta dall'altra parte del campo (info.girato): la telecamera si gira.
	local verso = info.girato and -1 or 1
	workspace.CurrentCamera.CFrame = CFrame.lookAt(info.centro + Vector3.new(0, 34, -112 * verso), info.centro + Vector3.new(0, 0, -16 * verso))
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

-- Cielo e tempo della battaglia (Config/Luci.meteo), con il colore dell'aria del bioma; pioggia e neve
-- le fa cadere Meteo.
local function impostaCielo(dati)
	Meteo.imposta(Cielo.battaglia(dati.meteo, dati.atmosfera))
end

local function ripristinaCielo()
	Meteo.imposta(nil)
	Cielo.campo()
end

-- Piccola animazione "pop": la UIScale dell'oggetto parte da "da" e rimbalza a 1.
local function pop(oggetto, da, durata)
	local scala = oggetto:FindFirstChildOfClass("UIScale") or Stile.crea("UIScale", { Parent = oggetto })
	scala.Scale = da or 0
	TweenService:Create(scala, TweenInfo.new(durata or 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- ===================================================================== sensazione delle azioni
-- (6/11/2026) Le tre azioni più frequenti (pulsanti, carte, ordini) rispondono come nei giochi Nintendo:
-- subito, con un suono e un movimento brevi, e con un effetto che si vede sul campo dove l'azione arriva.

-- Toni della scala maggiore (do re mi fa sol la si do): ogni carta schierata suona una nota più alta della
-- precedente, come le monete prese in fila. Ritirarla scende.
local TONI = { 1, 1.122, 1.26, 1.335, 1.498, 1.682, 1.888, 2 }
local AZZURRO = Color3.fromRGB(120, 200, 255)
local ORO = Color3.fromRGB(255, 205, 70)
local ROSSO = Color3.fromRGB(255, 90, 80)

-- Nome di un tasto del controller per i suggerimenti: SQUARE / CIRCLE / CROSS / TRIANGLE su PlayStation,
-- X / B / A / Y su Xbox (Roblox restituisce "ButtonSquare" o "ButtonX" secondo il controller collegato).
local function nomeTasto(tasto)
	local ok, nome = pcall(UserInputService.GetStringForKeyCode, UserInputService, tasto)
	if not ok or type(nome) ~= "string" or nome == "" then
		nome = tasto.Name
	end
	return string.upper((nome:gsub("^Button", "")))
end

-- Suggerimento sopra le carte: cosa si preme, secondo il momento ("piazzamento" o "battaglia") e il comando
-- in uso (mouse, tocco, controller). Si rifà quando il giocatore passa da uno all'altro.
local momentoSuggerimento = nil
local function aggiornaSuggerimento(momento)
	momentoSuggerimento = momento or momentoSuggerimento
	if not suggerimento or not momentoSuggerimento then
		return
	end
	if momentoSuggerimento == "piazzamento" then
		suggerimento.Text = Stile.gamepad() and ("%s DEPLOY  ·  %s RECALL  ·  L1/R1 FORMATION  ·  %s FIGHT!"):format(
			nomeTasto(Enum.KeyCode.ButtonX), nomeTasto(Enum.KeyCode.ButtonB), nomeTasto(Enum.KeyCode.ButtonY))
			or Stile.touch() and "TAP A CARD TO DEPLOY OR RECALL IT"
			or "CLICK A CARD TO DEPLOY OR RECALL IT"
	elseif Stile.gamepad() then
		suggerimento.Text = ("%s REGIMENT  ·  %s ABILITY  ·  %s RESERVE  ·  D-PAD/%s ORDERS  ·  L2/R2 WING  ·  L1/R1 TARGET"):format(
			nomeTasto(Enum.KeyCode.ButtonX), nomeTasto(Enum.KeyCode.ButtonB), nomeTasto(Enum.KeyCode.ButtonA), nomeTasto(Enum.KeyCode.ButtonY))
	elseif Stile.touch() then
		suggerimento.Text = "PICK A WING, THEN AN ORDER  ·  TAP AN ENEMY TO ATTACK IT"
	else
		suggerimento.Text = "WING: Z X C V  ·  ORDERS: 1-5  ·  CLICK AN ENEMY TO ATTACK IT"
	end
end
UserInputService.LastInputTypeChanged:Connect(function()
	aggiornaSuggerimento()
end)

-- Carta schierata (o reggimento selezionato): si alza di 18 px sopra le altre, come una carta presa in mano.
local function alzaCarta(carta, su)
	local corpo = carta and carta:FindFirstChild("Corpo")
	if not corpo then
		return
	end
	local y = su and -18 or 0
	if corpo.Position.Y.Offset == y then
		return
	end
	TweenService:Create(corpo, TweenInfo.new(su and 0.22 or 0.14, su and Enum.EasingStyle.Back or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(0, y),
	}):Play()
end

-- Piccola rotazione che si assesta (la carta "schiocca" quando la giochi).
local function dondola(carta, gradi)
	carta.Rotation = gradi
	TweenService:Create(carta, TweenInfo.new(0.35, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
end

-- "No" con la testa: la carta trema di lato tre volte (azione rifiutata).
local function scuoti(carta)
	local corpo = carta and carta:FindFirstChild("Corpo")
	if not corpo then
		return
	end
	local y = corpo.Position.Y.Offset
	task.spawn(function()
		for _, x in ipairs({ -10, 9, -7, 5, -3, 0 }) do
			corpo.Position = UDim2.fromOffset(x, y)
			task.wait(0.035)
		end
	end)
end

-- Colpo di telecamera (la carica): il campo visivo si stringe di 5 gradi e torna in 0,4 s.
local fovBase = nil
local function colpoCamera()
	local camera = workspace.CurrentCamera
	if not camera or fovBase then
		return
	end
	fovBase = camera.FieldOfView
	local stringi = TweenService:Create(camera, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = fovBase - 5 })
	stringi.Completed:Connect(function()
		local torna = TweenService:Create(camera, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { FieldOfView = fovBase })
		torna.Completed:Connect(function()
			fovBase = nil
		end)
		torna:Play()
	end)
	stringi:Play()
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

local function aggiornaCarte()
	for indice, carta in pairs(carte) do
		-- Le carte schierate brillano, quelle rimaste fuori sono scure.
		Carta.spegni(carta, not usate[indice], "RESERVE")
		Carta.seleziona(carta, usate[indice] == true)
		alzaCarta(carta, usate[indice] == true)
	end
	if (info.riserva or 0) > 0 then
		contatore.Text = ("FIRST LINE %d/%d · RESERVE +%d"):format(#scelte, info.maxReggimenti, info.riserva)
	else
		contatore.Text = ("REGIMENTS %d/%d"):format(#scelte, info.maxReggimenti)
	end
end

local function impostaScelte(lista)
	scelte, usate = {}, {}
	for _, indice in ipairs(lista or {}) do
		table.insert(scelte, indice)
		usate[indice] = true
	end
end

local function datiFormazione(id)
	for _, f in ipairs(info and info.formazioni or {}) do
		if f.id == id then
			return f
		end
	end
	return nil
end

-- Pannello FORMATION: oro quella scelta, blu le altre sbloccate, grigie quelle ancora chiuse.
local function aggiornaFormazioni()
	for id, bottone in pairs(bottoniFormazione) do
		local f = datiFormazione(id)
		Stile.coloraPulsante(bottone, id == info.formazione and "oro" or (f and f.sbloccata and "blu" or "grigio"))
	end
	local f = datiFormazione(info.formazione)
	descrizioneFormazione.Text = f and f.descrizione or ""
end

-- Manda al server le carte scelte e (se cambia) la formazione: i reggimenti prendono subito posto sul campo.
local function inviaScelte(nuove, formazione)
	if inviando then
		inAttesa = { nuove = nuove, formazione = formazione or (inAttesa and inAttesa.formazione) }
		return
	end
	inviando = true
	local ok, messaggio, lista = remoti.Schiera:InvokeServer(nuove, formazione)
	inviando = false
	if fase ~= "piazzamento" then
		inAttesa = nil
		return
	end
	if ok then
		confermate = table.clone(lista or {})
		if formazione then
			info.formazione = formazione
		end
	end
	-- Il giocatore ha già scelto altro mentre si aspettava (carte giocate di fila col controller o col mouse):
	-- si manda subito l'ultima scelta, senza tornare indietro a quella vecchia.
	if inAttesa then
		local prossima = inAttesa
		inAttesa = nil
		inviaScelte(prossima.nuove, prossima.formazione)
		return
	end
	if ok then
		impostaScelte(lista)
		if formazione then
			info.formazione = formazione
		end
		aggiornaCarte()
		aggiornaFormazioni()
		if #scelte > 0 then
			Tutorial.evento("carta")
		end
	else
		-- Rifiutata dal server: suono di errore e le carte tornano come erano.
		Suoni.ui("errore")
		impostaScelte(confermate)
		aggiornaCarte()
		if messaggio then
			Notifiche.mostra(messaggio, Stile.Colori.Rosso)
		end
	end
end

-- Schiera o ritira la carta "indice" del mazzo (clic, tocco, o i tasti del controller). Le scelte cambiano
-- subito anche sul client, così una seconda carta giocata prima della risposta del server parte dalla prima.
local function giocaCarta(indice)
	local carta = carte[indice]
	if not carta then
		return
	end
	if fase ~= "piazzamento" then
		return
	end
	local nuove = table.clone(scelte)
	local posto = table.find(nuove, indice)
	if posto then
		table.remove(nuove, posto)
		-- Ritirata: subito giù, suono che scende.
		Suoni.ui("carta", 0.8 * TONI[math.min(#nuove + 1, #TONI)])
		alzaCarta(carta, false)
	elseif #nuove >= info.maxReggimenti then
		Suoni.ui("errore")
		scuoti(carta)
		if (info.riserva or 0) > 0 then
			Notifiche.mostra(("Your first line is full (%d). The other cards wait in reserve: you can send %d of them in during the battle."):format(info.maxReggimenti, info.riserva), Stile.Colori.Rosso)
		else
			Notifiche.mostra(("Maximum %d regiments in this battle: recall one first."):format(info.maxReggimenti), Stile.Colori.Rosso)
		end
		return
	else
		table.insert(nuove, indice)
		-- Schierata: subito su, con lo schiocco e la nota successiva della scala; le truppe atterrano
		-- sul campo appena il server risponde (Truppe.schieramento).
		Suoni.ui("carta", TONI[math.min(#nuove, #TONI)])
		alzaCarta(carta, true)
		dondola(carta, -6)
	end
	impostaScelte(nuove)
	inviaScelte(nuove, nil)
end

local function costruisciMazzo()
	for _, carta in pairs(carte) do
		carta:Destroy()
	end
	-- Anche le carte della riserva rimaste dalla battaglia di prima.
	for _, carta in pairs(carteRiserva) do
		carta:Destroy()
	end
	carte, idPerIndice, bottoniAbilita, carteRiserva = {}, {}, {}, {}
	riserva, puntamento = nil, nil
	aggiornaSuggerimento("piazzamento")
	local layout = carteMazzo:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.Padding = UDim.new(0, #info.mazzo > 7 and 12 or 56)
	end
	for indice, tipo in ipairs(info.mazzo) do
		local carta = Carta.crea(tipo)
		carta.Size = UDim2.fromOffset(112, 162)
		carta.LayoutOrder = indice
		carta.Parent = carteMazzo
		carta.Activated:Connect(function()
			giocaCarta(indice)
		end)
		carte[indice] = carta
	end
end

local function costruisciFormazioni()
	for _, bottone in pairs(bottoniFormazione) do
		bottone:Destroy()
	end
	bottoniFormazione = {}
	for i, f in ipairs(info.formazioni or {}) do
		-- Solo il nome; se è bloccata, il lucchetto (Mattia, 29/10/2026: la battaglia di sblocco non serve).
		local testo = string.upper(f.nome)
		local bottone = Stile.pulsante({
			Name = f.id,
			Size = UDim2.new(1, 0, 0, 46),
			LayoutOrder = i,
			Parent = listaFormazioni,
		}, f.sbloccata and "blu" or "grigio", {
			Testo = testo,
			TestoSize = 22,
			Icona = not f.sbloccata and "lock" or nil,
			IconaSize = 28,
			IconaX = 10,
			Profondita = 5,
			Raggio = 12,
			Contorno = 3,
		})
		bottone.Activated:Connect(function()
			if fase ~= "piazzamento" then
				return
			end
			if not f.sbloccata then
				Notifiche.mostra(("%s unlocks at battle %d."):format(f.nome, f.sblocco))
				return
			end
			if f.id ~= info.formazione then
				inviaScelte(scelte, f.id)
			end
		end)
		bottoniFormazione[f.id] = bottone
	end
	aggiornaFormazioni()
end

local function mostraPiazzamento(visibile)
	intestazione.Visible = visibile
	barraMazzo.Visible = visibile
	bottoneCombatti.Visible = visibile
	bottoneLobby.Visible = visibile
	avviso.Visible = visibile
	esploratori.Visible = visibile
	pannelloFormazioni.Visible = visibile
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
local function mostraEsploratori(tipi, inRiserva, entrata)
	inRiserva = inRiserva or {}
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
			-- Reggimento della riserva nemica: entra a battaglia iniziata (dalle retrovie o da un fianco).
			if inRiserva[i] then
				Stile.chip({
					Name = "Riserva",
					Position = UDim2.fromOffset(124, 46),
					Size = UDim2.fromOffset(120, 32),
					Parent = riga,
				}, entrata == "FLANK" and "rosso" or "oro", "RESERVE" .. (entrata and (" · " .. entrata) or ""), 15)
			end
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
	Suoni.musica("schieramento")
	risultato.Visible = false
	scrittaConto.Visible = false
	arena = workspace:WaitForChild("Arene"):WaitForChild(dati.arena, 10)
	-- Tra un round e l'altro la telecamera resta dove l'ha messa il giocatore.
	if nuovoCampo then
		impostaCamera()
	end
	impostaCielo(dati)
	if dati.ranked then
		titoloLivello.Text = ("RANKED  ·  %s"):format(string.upper(dati.nome))
	else
		titoloLivello.Text = ("%d. %s  ·  %s"):format(dati.livello, string.upper(dati.nome), dati.anno)
	end
	nomeNemico.Text = dati.ranked and string.upper(dati.avversario or "ENEMY") or "ENEMY"
	aggiornaPunteggio(dati)
	sottotitolo.Text = dati.assedio and "SIEGE! STORM THE FORTRESS" or "DEPLOY YOUR ARMY"
	sottotitolo.TextColor3 = dati.assedio and Stile.Colori.Oro or AZZURRO
	impostaScelte(dati.usate)
	confermate = table.clone(dati.usate or {})
	costruisciMazzo()
	aggiornaCarte()
	costruisciFormazioni()
	Stile.seleziona(carte[1] or bottoneCombatti)
	mostraEsploratori(dati.esploratori, dati.riservaNemica, dati.entrata)
	bannerRound.Visible = false
	if dati.ranked then
		avviso.Text = dati.round == 1 and ("RANKED vs %s: deploy your ARMY deck, pick a formation, then press FIGHT!"):format(dati.avversario or "your opponent")
			or "Next round! Change your army or press FIGHT!"
		avviso.TextColor3 = Stile.Colori.Testo
	elseif dati.assedio then
		avviso.Text = "SIEGE! The enemy hides in a fortress: destroy it and win the battle."
		avviso.TextColor3 = Stile.Colori.Oro
	elseif dati.round == 1 and dati.fiume then
		avviso.Text = "Click cards to deploy them and pick a formation. Your regiments cross the river at the sandy fords."
		avviso.TextColor3 = Stile.Colori.Testo
	elseif dati.round == 1 then
		avviso.Text = "Click cards to deploy them and pick a formation: your army takes position at once. Hills protect troops."
		avviso.TextColor3 = Stile.Colori.Testo
	else
		avviso.Text = "Your army is back in formation: change it or press FIGHT!"
		avviso.TextColor3 = Stile.Colori.Testo
	end
	if not dati.ranked and not dati.assedio and (dati.riserva or 0) > 0 then
		if dati.avvisoEntrata then
			avviso.Text = dati.avvisoEntrata .. " Keep your best counter in reserve!"
			avviso.TextColor3 = dati.entrata == "FLANK" and Stile.ACCENTI.rosso.t or Stile.Colori.Oro
		elseif dati.round == 1 then
			avviso.Text = ("Deploy your FIRST LINE. The other cards wait in RESERVE: %d of them can join the battle after %d seconds."):format(dati.riserva, dati.riservaDopo or 30)
		end
	end
	mostraPiazzamento(true)
	if dati.ranked then
		-- Gli esploratori non vedono l'armata dell'avversario.
		esploratori.Visible = false
	end
	mostraTimer(nil)
	versioneTimer += 1
	if dati.limite then
		-- Ranked: tempo per schierarsi, poi si combatte comunque.
		local versione = versioneTimer
		local fineTempo = os.clock() + dati.limite
		task.spawn(function()
			while fase == "piazzamento" and versione == versioneTimer do
				local resto = math.max(0, math.ceil(fineTempo - os.clock()))
				mostraTimer(("0:%02d"):format(resto))
				task.wait(0.25)
			end
		end)
	end
	mostraVinci(true)
	-- Prima battaglia: tutorial passo passo.
	if dati.tutorial and dati.round == 1 and not Tutorial.attivo() then
		Tutorial.avvia()
	end
	Tutorial.evento("piazzamento")
end

-- Colori dei numeri del conto alla rovescia: 3 blu, 2 verde, 1 oro, FIGHT! arancio.
local COLORI_CONTO = { Stile.ACCENTI.oro.t, Stile.ACCENTI.verde.t, Stile.ACCENTI.blu.t }

local function contoAllaRovescia(conto)
	scrittaConto.Visible = true
	local scala = scrittaConto:FindFirstChildOfClass("UIScale")
	for numero = conto, 0, -1 do
		if fase ~= "battaglia" then
			break
		end
		scrittaConto.Text = numero > 0 and tostring(numero) or "FIGHT!"
		scrittaConto.TextColor3 = numero > 0 and (COLORI_CONTO[numero] or Stile.BIANCO) or Stile.ACCENTI.arancio.t
		mostraTimer(numero > 0 and ("0:%02d"):format(numero) or "GO!")
		scala.Scale = 1.8
		TweenService:Create(scala, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		task.wait(numero > 0 and 1 or 0.8)
	end
	scrittaConto.Visible = false
	if fase == "battaglia" then
		-- Grido di guerra di tutta l'armata al via.
		Suoni.effetto("grido")
		mostraTimer(nil)
		sottotitolo.Text = "FIGHT!"
		sottotitolo.TextColor3 = Stile.ACCENTI.arancio.t
	end
end

local function spegniAbilita(id, testo)
	local bottone = bottoniAbilita[id]
	if bottone then
		bottone.Active = false
		bottone.AutoButtonColor = false
		local etichetta = bottone:FindFirstChild("Testo", true)
		if etichetta then
			etichetta.Text = testo
		end
		local faccia = bottone:FindFirstChild("Faccia")
		local sfumatura = faccia and faccia:FindFirstChildOfClass("UIGradient")
		if sfumatura then
			sfumatura.Color = ColorSequence.new(Stile.PAL.grigio.t, Stile.PAL.grigio.b)
		end
		bottoniAbilita[id] = nil
	end
end

-- Sigla dell'ala (L, C, R) sopra la carta di un reggimento in campo; oro se l'ala è quella scelta.
local function siglaAla(carta, ala)
	local vecchia = carta:FindFirstChild("Ala")
	if vecchia then
		vecchia:Destroy()
	end
	if not ala then
		return
	end
	local chip = Stile.chip({
		Name = "Ala",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 18),
		Size = UDim2.fromOffset(84, 28),
		ZIndex = 21,
		Parent = carta,
	}, alaScelta == ala and "oro" or "blu", NOMI_ALA[ala], 16)
	chip:SetAttribute("Ala", ala)
end

local function aggiornaSigle()
	for _, carta in pairs(carte) do
		local chip = carta:FindFirstChild("Ala")
		if chip then
			siglaAla(carta, chip:GetAttribute("Ala"))
		end
	end
end

-- Il giocatore preme ABILITY: l'abilità parte dove clicca sul campo (Mattia, 3/11/2026). Con il controller,
-- dove sta il suo avatar.
local function lanciaAbilita(id, x, y)
	local ok, messaggio = remoti.Abilita:InvokeServer(id, x, y)
	if ok then
		spegniAbilita(id, "USED")
	elseif messaggio then
		Notifiche.mostra(messaggio, Stile.Colori.Rosso)
	end
	return ok
end

-- Manda in campo la carta "indice" della riserva nel punto x, y (caselle): la sua carta passa tra quelle in campo.
function mettiRiserva(indice, x, y)
	local ok, messaggio, id, ala = remoti.Riserva:InvokeServer(indice, x, y)
	if not ok then
		if messaggio then
			Notifiche.mostra(messaggio, Stile.Colori.Rosso)
		end
		return false
	end
	convertiRiserva(indice, id, ala)
	return true
end

-- La carta "indice" della riserva è entrata in campo come reggimento "id": passa tra le carte in campo.
-- La chiama sia la risposta del server sia l'evento "rinforzi" (arriva per primo chi arriva).
function convertiRiserva(indice, id, ala)
	if fase ~= "battaglia" or not riserva or not id then
		return
	end
	for _, altro in pairs(idPerIndice) do
		if altro == id then
			return -- già fatto
		end
	end
	riserva.messe += 1
	local vecchia = carteRiserva[indice]
	carteRiserva[indice] = nil
	if vecchia then
		vecchia:Destroy()
	end
	local tipo = info and info.mazzo and info.mazzo[indice]
	if tipo then
		cartaInCampo({ id = id, indice = indice, tipo = tipo, ala = ala })
		Tutorial.evento("riserva")
	end
	aggiornaRiserva()
end

-- Posizione dell'avatar in caselle, o nil.
local function posizioneAvatar()
	local character = player.Character
	local radice = character and character:FindFirstChild("HumanoidRootPart")
	if not radice then
		return nil
	end
	return Truppe.casella(radice.Position)
end

-- daController = il comando arriva da un tasto del controller: si usa sempre il punto dell'avatar.
local function avviaPuntamento(nuovo, daController)
	if puntamento and puntamento.tipo == nuovo.tipo and (puntamento.id == nuovo.id and puntamento.indice == nuovo.indice) then
		puntamento = nil -- di nuovo lo stesso pulsante: annulla
	else
		puntamento = nuovo
	end
	if puntamento and (daController or Stile.gamepad()) then
		-- Col controller niente puntatore: si usa il punto dove sta l'avatar.
		local x, y = posizioneAvatar()
		local scelto = puntamento
		puntamento = nil
		if x then
			if scelto.tipo == "abilita" then
				lanciaAbilita(scelto.id, x, y)
			else
				task.spawn(mettiRiserva, scelto.indice, x, y)
			end
		end
	end
	if puntamento then
		avviso.Text = puntamento.tipo == "abilita" and "Click the field where to use the ability (right click to cancel)."
			or "Click on your half of the field where the reserve should enter (right click to cancel)."
		avviso.TextColor3 = Stile.Colori.Oro
	end
	aggiornaPuntamento()
end

-- Carte della riserva: in fondo alla barra, spente finché la riserva non è pronta.
function aggiornaRiserva()
	if not riserva then
		return
	end
	local pronta = os.clock() >= riserva.pronta
	local finita = riserva.messe >= riserva.quante
	for indice, carta in pairs(carteRiserva) do
		local testo
		if finita then
			testo = "FULL"
		elseif pronta then
			testo = nil
		else
			testo = ("IN %ds"):format(math.max(1, math.ceil(riserva.pronta - os.clock())))
		end
		local scelta = puntamento ~= nil and puntamento.tipo == "riserva" and puntamento.indice == indice
		local stato = (testo or "") .. (scelta and "*" or "")
		-- Si rifà la carta solo quando cambia (lo si chiama più volte al secondo per il conto alla rovescia).
		if carta:GetAttribute("StatoRiserva") ~= stato then
			carta:SetAttribute("StatoRiserva", stato)
			Carta.spegni(carta, testo ~= nil, testo or "")
			Carta.seleziona(carta, scelta)
		end
	end
	if riserva.etichetta then
		riserva.etichetta.Text = finita and "RESERVE SENT" or (pronta and ("RESERVE READY! %d LEFT"):format(riserva.quante - riserva.messe) or "RESERVE")
	end
end

-- Barra in basso durante la battaglia: le carte schierate (con l'ala e, per i comandanti, il pulsante ABILITY)
-- e le carte della riserva.
function cartaInCampo(r)
	local def = Epoche.Truppe[r.tipo]
	idPerIndice[r.indice] = r.id
	alaDi[r.id] = r.ala
	local carta = Carta.crea(r.tipo)
	carta.Size = UDim2.fromOffset(112, 162)
	carta.LayoutOrder = r.indice
	carta.Parent = carteMazzo
	carta.AutoButtonColor = false
	-- Clic sulla carta: i bersagli scelti dopo valgono solo per questo reggimento (di nuovo: tutta l'armata).
	if carta:IsA("GuiButton") then
		carta.Activated:Connect(function()
			if fase == "battaglia" and not carta:GetAttribute("Caduto") then
				scegliReparto(r.id)
			end
		end)
	end
	siglaAla(carta, r.ala)
	if def.abilita then
		local bottone = Stile.pulsante({
			Name = "Abilita",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 14),
			Size = UDim2.fromOffset(132, 48),
			ZIndex = 20,
			Parent = carta,
		}, "arancio", { Testo = "ABILITY", TestoSize = 24, Profondita = 5, Raggio = 12, Contorno = 3 })
		bottone.Activated:Connect(function()
			if bottoniAbilita[r.id] and fase == "battaglia" then
				avviaPuntamento({ tipo = "abilita", id = r.id })
			end
		end)
		bottoniAbilita[r.id] = bottone
	end
	carte[r.indice] = carta
	return carta
end

local function costruisciBarraBattaglia(reggimenti, dati)
	for _, carta in pairs(carte) do
		carta:Destroy()
	end
	for _, carta in pairs(carteRiserva) do
		carta:Destroy()
	end
	carte, idPerIndice, bottoniAbilita, alaDi, carteRiserva = {}, {}, {}, {}, {}
	table.sort(reggimenti, function(a, b)
		return a.indice < b.indice
	end)
	for _, r in ipairs(reggimenti) do
		cartaInCampo(r)
	end
	riserva = nil
	if dati and (dati.riserva or 0) > 0 and dati.mano and #dati.mano > 0 then
		riserva = { mano = dati.mano, quante = dati.riserva, pronta = os.clock() + (dati.conto or 3) + 0.2 + (dati.riservaDopo or 30), messe = 0 }
		for _, indice in ipairs(dati.mano) do
			local tipo = info and info.mazzo and info.mazzo[indice]
			if tipo then
				local carta = Carta.crea(tipo)
				carta.Size = UDim2.fromOffset(112, 162)
				carta.LayoutOrder = 100 + indice
				carta.Parent = carteMazzo
				carta.AutoButtonColor = false
				Stile.chip({
					Name = "EtichettaRiserva",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0.5, 0, 0, 18),
					Size = UDim2.fromOffset(96, 30),
					ZIndex = 21,
					Parent = carta,
				}, "verde", "RESERVE", 16)
				if carta:IsA("GuiButton") then
					carta.Activated:Connect(function()
						if fase ~= "battaglia" or not riserva or riserva.messe >= riserva.quante then
							return
						end
						if os.clock() < riserva.pronta then
							Notifiche.mostra(("Your reserve joins the battle in %d seconds."):format(math.ceil(riserva.pronta - os.clock())))
							return
						end
						avviaPuntamento({ tipo = "riserva", indice = indice })
					end)
				end
				carteRiserva[indice] = carta
			end
		end
	end
	contatore.Text = riserva and "REGIMENTS · RESERVE" or "REGIMENTS"
	if riserva then
		riserva.etichetta = contatore
	end
	aggiornaRiserva()
	aggiornaSuggerimento("battaglia")
end

-- Cosa fa ogni ordine, per l'avviso sotto il tabellone.
local SPIEGAZIONE_ORDINI = {
	avanza = "Every regiment marches on the nearest enemy.",
	tieni = "Your line stands firm and fights only who comes close.",
	ripiega = "Your army falls back in good order, then holds the new line.",
	fianchi = "The cavalry rides around the wings to hit the enemy archers, the rest holds.",
	carica = "They charge faster and the cavalry charges again. Once per round for each wing!",
}

-- Ordine in corso dell'ala scelta (con tutta l'armata: quello comune alle ali, o nil se sono diversi).
local function ordineScelto()
	if alaScelta then
		return ordiniAli[alaScelta] or "avanza"
	end
	local comune = ordiniAli.sinistra or "avanza"
	for _, ala in ipairs(Battaglia.ALI) do
		if (ordiniAli[ala] or "avanza") ~= comune then
			return nil
		end
	end
	return comune
end

-- Pannello ORDERS: in alto l'ala scelta (oro) con l'ordine di ogni ala; sotto, oro l'ordine in corso
-- dell'ala scelta e grigia la carica se quell'ala (o, con tutta l'armata, ogni ala) l'ha già suonata.
local function aggiornaOrdini()
	local attuale = ordineScelto()
	local caricato
	if alaScelta then
		caricato = caricheAli[alaScelta] == true
	else
		caricato = true
		for _, ala in ipairs(Battaglia.ALI) do
			if not caricheAli[ala] then
				caricato = false
			end
		end
	end
	for nome, bottone in pairs(bottoniOrdine) do
		local finita = nome == "carica" and caricato and attuale ~= "carica"
		Stile.coloraPulsante(bottone, nome == attuale and "oro" or (finita and "grigio" or "blu"))
	end
	for chiave, bottone in pairs(bottoniAla) do
		local ala = chiave ~= "tutte" and chiave or nil
		Stile.coloraPulsante(bottone, ala == alaScelta and "oro" or "blu")
		local sotto = bottone:FindFirstChild("Sotto", true)
		if sotto then
			local ordine = ala and (ordiniAli[ala] or "avanza") or ordineScelto()
			local nome = ordine and Battaglia.NOMI_ORDINI[ordine]
			sotto.Text = nome and string.upper(nome.nome) or "MIXED"
		end
	end
	aggiornaSigle()
end

-- Sceglie l'ala a cui vanno gli ordini (nil = tutta l'armata).
local function scegliAla(ala)
	if fase ~= "battaglia" then
		return
	end
	alaScelta = ala
	aggiornaOrdini()
	-- Sinistra più grave, destra più acuta: si "sente" dove va l'ordine.
	Suoni.ui("ala", ala == "sinistra" and 0.89 or ala == "destra" and 1.12 or 1)
	local quante = 0
	for id, a in pairs(alaDi) do
		if ala == nil or a == ala then
			quante += 1
			Truppe.impulso(id, ORO)
		end
	end
	avviso.Text = ala and ("ORDERS TO YOUR %s WING (%d %s)"):format(NOMI_ALA[ala], quante, quante == 1 and "regiment" or "regiments")
		or "ORDERS TO YOUR WHOLE ARMY"
	avviso.TextColor3 = Stile.Colori.Oro
end

-- Nome visibile di un bersaglio: classe, generale o reggimento nemico (numero).
local function nomeMira(filtro)
	if type(filtro) == "number" then
		return "THAT REGIMENT"
	end
	for _, b in ipairs(BERSAGLI) do
		if b.filtro == filtro then
			return filtro and ("ENEMY " .. string.upper(b.nome)) or "ANY ENEMY"
		end
	end
	return "ANY ENEMY"
end

-- Pannello TARGET: oro il bersaglio in corso (del reggimento selezionato, o di tutta l'armata).
local function aggiornaMire()
	local filtro = miraArmata
	if repartoScelto and mireReparti[repartoScelto] ~= nil then
		filtro = mireReparti[repartoScelto] or nil
	end
	for i, bottone in pairs(bottoniMira) do
		Stile.coloraPulsante(bottone, BERSAGLI[i].filtro == filtro and "oro" or "blu")
	end
	if titoloMira then
		local nome
		for indice, id in pairs(idPerIndice) do
			if id == repartoScelto then
				local def = Epoche.Truppe[info and info.mazzo and info.mazzo[indice] or ""]
				nome = def and def.nome
			end
		end
		titoloMira.Text = repartoScelto and ("TARGET · %s"):format(string.upper(nome or "REGIMENT")) or "TARGET · WHOLE ARMY"
	end
	-- Segnale sopra il reggimento nemico scelto (dell'armata o del reggimento selezionato).
	Truppe.segnaBersaglio(type(filtro) == "number" and filtro or (type(miraArmata) == "number" and miraArmata or nil))
end

local function daiBersaglio(filtro)
	if fase ~= "battaglia" then
		return
	end
	local ok, messaggio = remoti.Bersaglio:InvokeServer(filtro, repartoScelto)
	if ok then
		Suoni.ui("mira")
		if type(filtro) == "number" then
			Truppe.impulso(filtro, ROSSO)
		end
	else
		Suoni.ui("errore")
		if messaggio then
			Notifiche.mostra(messaggio, Stile.Colori.Rosso)
		end
	end
end

-- Seleziona (o deseleziona) un proprio reggimento: i bersagli valgono solo per lui.
scegliReparto = function(id, silenzioso)
	if repartoScelto == id then
		id = nil
	end
	repartoScelto = id
	for indice, carta in pairs(carte) do
		Carta.seleziona(carta, id ~= nil and idPerIndice[indice] == id)
		alzaCarta(carta, id ~= nil and idPerIndice[indice] == id)
	end
	if not silenzioso then
		Suoni.ui("ala", id and 1.26 or 0.84)
	end
	if id then
		Truppe.impulso(id, AZZURRO)
	end
	aggiornaMire()
end

-- ===================================================================== controller: un tasto per azione
-- (6/11/2026, feedback di un giocatore PlayStation: "è lento muovere le truppe, aggiungete tasti tipo quadrato").
-- Prima, per schierare una carta, scegliere un reggimento, l'abilità o la riserva bisognava spostare il cursore
-- dell'interfaccia fino al pulsante. Ora ognuna è un solo tasto.

-- Schieramento, QUADRATO / X: schiera la prima carta non ancora schierata.
local function padSchiera()
	if fase ~= "piazzamento" or not info then
		return
	end
	for indice = 1, #info.mazzo do
		if not usate[indice] then
			giocaCarta(indice)
			Stile.seleziona(carte[indice])
			return
		end
	end
	Suoni.ui("errore")
end

-- Schieramento, CERCHIO / B: ritira l'ultima carta schierata.
local function padRitira()
	if fase ~= "piazzamento" then
		return
	end
	local ultima = scelte[#scelte]
	if ultima then
		giocaCarta(ultima)
		Stile.seleziona(carte[ultima])
	else
		Suoni.ui("errore")
	end
end

-- Schieramento, L1 / R1: formazione sbloccata precedente o successiva.
local function padFormazione(passo)
	if fase ~= "piazzamento" or not info then
		return
	end
	local sbloccate = {}
	for _, f in ipairs(info.formazioni or {}) do
		if f.sbloccata then
			table.insert(sbloccate, f)
		end
	end
	if #sbloccate < 2 then
		Suoni.ui("errore")
		return
	end
	local attuale = 1
	for i, f in ipairs(sbloccate) do
		if f.id == info.formazione then
			attuale = i
		end
	end
	local f = sbloccate[(attuale - 1 + passo) % #sbloccate + 1]
	Stile.premi(bottoniFormazione[f.id])
	inviaScelte(scelte, f.id)
end

-- Battaglia, QUADRATO / X: seleziona il reggimento successivo (dopo l'ultimo, di nuovo tutta l'armata).
local function padReparto()
	if fase ~= "battaglia" then
		return
	end
	local ordine = {}
	for indice, carta in pairs(carte) do
		if idPerIndice[indice] and not carta:GetAttribute("Caduto") then
			table.insert(ordine, indice)
		end
	end
	table.sort(ordine)
	if #ordine == 0 then
		Suoni.ui("errore")
		return
	end
	local attuale = 0
	for i, indice in ipairs(ordine) do
		if idPerIndice[indice] == repartoScelto then
			attuale = i
		end
	end
	local prossimo = ordine[attuale + 1]
	scegliReparto(prossimo and idPerIndice[prossimo] or nil)
	if prossimo then
		dondola(carte[prossimo], -6)
		local def = Epoche.Truppe[info and info.mazzo and info.mazzo[prossimo] or ""]
		avviso.Text = ("%s SELECTED: targets (L1/R1) and ability (%s) go to them."):format(
			string.upper(def and def.nome or "REGIMENT"), nomeTasto(Enum.KeyCode.ButtonB))
	else
		avviso.Text = "WHOLE ARMY SELECTED"
	end
	avviso.TextColor3 = Stile.Colori.Oro
end

-- Battaglia, CERCHIO / B: abilità del reggimento selezionato (o della prima carta che ne ha una pronta),
-- lanciata dove sta l'avatar.
local function padAbilita()
	if fase ~= "battaglia" then
		return
	end
	local id = repartoScelto and bottoniAbilita[repartoScelto] and repartoScelto
	if not id then
		local indici = {}
		for indice, idReparto in pairs(idPerIndice) do
			if bottoniAbilita[idReparto] then
				table.insert(indici, indice)
			end
		end
		table.sort(indici)
		id = indici[1] and idPerIndice[indici[1]]
	end
	if not id then
		Suoni.ui("errore")
		avviso.Text = "No ability ready."
		avviso.TextColor3 = Stile.ACCENTI.rosso.t
		return
	end
	Stile.premi(bottoniAbilita[id])
	avviaPuntamento({ tipo = "abilita", id = id }, true)
end

-- Battaglia, CROCE / A: manda in campo la prossima carta della riserva, dove sta l'avatar.
local function padRiserva()
	if not riserva or riserva.messe >= riserva.quante then
		Suoni.ui("errore")
		avviso.Text = "No reserve left."
		avviso.TextColor3 = Stile.ACCENTI.rosso.t
		return
	end
	if os.clock() < riserva.pronta then
		Suoni.ui("errore")
		Notifiche.mostra(("Your reserve joins the battle in %d seconds."):format(math.ceil(riserva.pronta - os.clock())))
		return
	end
	for _, indice in ipairs(riserva.mano) do
		if carteRiserva[indice] then
			Suoni.ui("premi")
			dondola(carteRiserva[indice], -6)
			avviaPuntamento({ tipo = "riserva", indice = indice }, true)
			return
		end
	end
	Suoni.ui("errore")
end

-- ===================================================================== momenti da mostrare
-- (7/11/2026) Collaudo "un bambino fa vedere il gioco all'amico": a metà battaglia diceva "ora si menano e
-- basta, aspetta". Due momenti nuovi da far vedere: la carica perfetta (toccarla quando le linee stanno per
-- toccarsi, con "NOW!" acceso sul pulsante) e la rotta di ogni reggimento nemico distrutto ("ROUTED!").

-- La carica si può ancora suonare (dall'ala scelta, o da almeno un'ala con reggimenti)?
local function caricaDisponibile()
	local conTruppe = {}
	for _, ala in pairs(alaDi) do
		conTruppe[ala] = true
	end
	for _, ala in ipairs(Battaglia.ALI) do
		if (alaScelta == nil or ala == alaScelta) and conTruppe[ala] and not caricheAli[ala] then
			return true
		end
	end
	return false
end

-- Le linee stanno per toccarsi e la carica c'è: è il momento della carica perfetta.
local function finestraCarica()
	if fase ~= "battaglia" or not caricaDisponibile() then
		return false
	end
	local distanza = Truppe.distanzaFronte()
	return distanza ~= nil and distanza <= Battaglia.FINESTRA_CARICA
end

local scrittaGrande -- la scritta al centro dello schermo per i momenti forti (creata in inizializza)
local function momento(testo, colore)
	if not scrittaGrande then
		return
	end
	scrittaGrande.Text = testo
	scrittaGrande.TextColor3 = colore
	-- Il contorno (UIStroke "Contorno" di Stile.scritta) sparisce insieme al testo: da solo resterebbe una
	-- sagoma nera.
	local contorno = scrittaGrande:FindFirstChild("Contorno")
	scrittaGrande.TextTransparency = 0
	if contorno then
		contorno.Transparency = 0
	end
	scrittaGrande.Visible = true
	pop(scrittaGrande, 0.3, 0.22)
	local versione = (scrittaGrande:GetAttribute("Versione") or 0) + 1
	scrittaGrande:SetAttribute("Versione", versione)
	task.delay(1.1, function()
		if scrittaGrande:GetAttribute("Versione") == versione then
			TweenService:Create(scrittaGrande, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			if contorno then
				TweenService:Create(contorno, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			end
		end
	end)
end

local function caricaPerfetta()
	momento("PERFECT CHARGE!", ORO)
	Suoni.ui("tamburo")
	local centro = Truppe.centro("giocatore")
	if centro then
		Effetti.onda(centro, 22, ORO, 0.8)
		Effetti.scritta(centro + Vector3.new(0, 8, 0), "PERFECT!", ORO, 2)
	end
end

-- Un reggimento nemico è stato distrutto: id = l'ultimo soldato caduto.
local function rotta(id)
	local squadra, posizione = Truppe.soldatoInfo(id)
	if squadra ~= "nemico" or not posizione then
		return
	end
	momento("ROUTED!", ROSSO)
	Suoni.ui("tamburo", 0.8)
	colpoCamera()
	Effetti.onda(posizione, 14, ROSSO, 0.7)
	Effetti.scritta(posizione + Vector3.new(0, 7, 0), "ROUTED!", ROSSO, 2)
end

local function daiOrdine(nome)
	if fase ~= "battaglia" then
		return
	end
	local ok, messaggio, perfetta = remoti.Ordine:InvokeServer(nome, alaScelta)
	if ok then
		-- Tromba per avanzare e caricare, colpo di tamburo per gli altri ordini; onda sotto chi lo riceve.
		Suoni.ui(nome == "carica" and "carica" or nome == "avanza" and "tromba" or "tamburo")
		local colore = nome == "carica" and ORO or AZZURRO
		for id, a in pairs(alaDi) do
			if alaScelta == nil or a == alaScelta then
				Truppe.impulso(id, colore)
			end
		end
		if nome == "carica" then
			colpoCamera()
		end
		if perfetta then
			caricaPerfetta()
		end
		pop(avviso, 0.75, 0.25)
	else
		Suoni.ui("errore")
		if messaggio then
			Notifiche.mostra(messaggio, Stile.Colori.Rosso)
		end
	end
end

-- Eventi della battaglia che cambiano la barra: reggimenti caduti, ordini e abilità usate (anche dal nemico).
local function eventoBattaglia(e)
	if e.tipo == "morte" and e.reggimento then
		rotta(e.id)
		for indice, id in pairs(idPerIndice) do
			if id == e.reggimento and carte[indice] then
				carte[indice]:SetAttribute("Caduto", true)
				Carta.spegni(carte[indice], true, "FALLEN")
				spegniAbilita(id, "FALLEN")
				alaDi[id] = nil
				if puntamento and puntamento.tipo == "abilita" and puntamento.id == id then
					puntamento = nil
					aggiornaPuntamento()
				end
				if repartoScelto == id then
					scegliReparto(id, true) -- deseleziona, senza suono
				end
			end
		end
		if type(miraArmata) == "number" and miraArmata == e.reggimento then
			miraArmata = nil -- il reggimento nemico scelto è caduto
			aggiornaMire()
		end
	elseif e.tipo == "bersaglio" and e.squadra == "giocatore" then
		Tutorial.evento("bersaglio")
		if e.reggimento then
			mireReparti[e.reggimento] = e.filtro or false
		else
			miraArmata = e.filtro
			mireReparti = {}
		end
		aggiornaMire()
		avviso.Text = ("%s: %s!"):format(e.reggimento and "YOUR REGIMENT ATTACKS" or "ALL REGIMENTS ATTACK", nomeMira(e.filtro))
		avviso.TextColor3 = Stile.Colori.Oro
	elseif e.tipo == "ordine" and e.squadra == "giocatore" then
		for _, ala in ipairs(e.ali or Battaglia.ALI) do
			ordiniAli[ala] = e.ordine
			if e.ordine == "carica" then
				caricheAli[ala] = true
			end
		end
		if not e.automatico then
			Tutorial.evento("ordine")
		end
		aggiornaOrdini()
		local nome = Battaglia.NOMI_ORDINI[e.ordine]
		-- Chi riceve l'ordine: un'ala sola o tutta l'armata.
		local chi = e.ali and #e.ali == 1 and ("YOUR %s WING"):format(NOMI_ALA[e.ali[1]]) or "YOUR ARMY"
		if e.automatico then
			avviso.Text = e.ordine == "tieni" and ("The retreat is over: %s holds the new line."):format(string.lower(chi))
				or ("The charge is spent: %s keeps advancing."):format(string.lower(chi))
		elseif e.perfetta then
			avviso.Text = ("%s PERFECT CHARGE! Perfect timing: they hit much harder."):format(chi)
		elseif nome then
			avviso.Text = ("%s %s: %s"):format(chi, nome.grido, SPIEGAZIONE_ORDINI[e.ordine] or "")
		end
		avviso.TextColor3 = Stile.Colori.Oro
	elseif e.tipo == "rinforzi" and e.squadra == "giocatore" then
		for indice in pairs(carteRiserva) do
			if info and info.mazzo and info.mazzo[indice] == e.tipoCarta then
				convertiRiserva(indice, e.reggimento, e.ala)
				break
			end
		end
	elseif e.tipo == "riservaPronta" and e.squadra == "giocatore" then
		-- Nessuno dei tuoi è più in campo: la riserva si può schierare subito, e va fatto in fretta.
		if riserva and riserva.messe < riserva.quante then
			riserva.pronta = math.min(riserva.pronta, os.clock())
			avviso.Text = "Your front line has fallen! Send your RESERVE now or the round is lost."
			avviso.TextColor3 = Stile.ACCENTI.rosso.t
			aggiornaRiserva()
		end
	elseif e.tipo == "rinforzi" and e.squadra == "nemico" then
		avviso.Text = ("ENEMY RESERVES! %s joins the battle%s"):format(
			string.upper((Epoche.Truppe[e.tipoCarta] or {}).nome or "A regiment"),
			info and info.entrataBattaglia == "FLANK" and " on your flank!" or "!"
		)
		avviso.TextColor3 = Stile.ACCENTI.rosso.t
	elseif e.tipo == "abilita" then
		local def = Epoche.Truppe[e.tipoCarta]
		if def and def.abilita then
			if e.squadra == "giocatore" then
				spegniAbilita(e.reggimento, "USED")
				avviso.Text = ("%s! %s"):format(string.upper(def.abilita.nome), Epoche.testoAbilita(def))
				avviso.TextColor3 = Stile.Colori.Oro
			else
				avviso.Text = ("ENEMY %s uses %s!"):format(string.upper(def.nome), string.upper(def.abilita.nome))
				avviso.TextColor3 = Stile.ACCENTI.rosso.t
			end
		end
	end
end

-- Punto del campo (in caselle) sotto un punto del viewport, o nil.
local parametriCampo = RaycastParams.new()
parametriCampo.FilterType = Enum.RaycastFilterType.Include
local function casellaSotto(vx, vy)
	local campo = Truppe.campo()
	if not campo then
		return nil
	end
	local raggio = workspace.CurrentCamera:ViewportPointToRay(vx, vy)
	parametriCampo.FilterDescendantsInstances = arena and { arena, workspace.Terrain } or { workspace.Terrain }
	local colpo = workspace:Raycast(raggio.Origin, raggio.Direction * 1500, parametriCampo)
	local posizione = colpo and colpo.Position
	if not posizione and raggio.Direction.Y < -1e-3 then
		-- Niente sotto (terreno non ancora arrivato): il piano del campo.
		local t = (campo.origine.Y - raggio.Origin.Y) / raggio.Direction.Y
		posizione = raggio.Origin + raggio.Direction * t
	end
	if not posizione then
		return nil
	end
	return Truppe.casella(posizione)
end

local COLORE_ABILITA = Color3.fromRGB(255, 200, 60)
local COLORE_RISERVA = Color3.fromRGB(90, 230, 140)
local COLORE_NO = Color3.fromRGB(255, 80, 70)

-- Carte evidenziate e avviso del comando che aspetta un clic sul campo (il cerchio lo muove ogni frame).
function aggiornaPuntamento()
	for id, bottone in pairs(bottoniAbilita) do
		local etichetta = bottone:FindFirstChild("Testo", true)
		if etichetta then
			etichetta.Text = puntamento and puntamento.tipo == "abilita" and puntamento.id == id and "AIM..." or "ABILITY"
		end
	end
	aggiornaRiserva()
	if not puntamento then
		Truppe.togliAnello("Puntamento")
	end
end

-- Come Battaglia:postoRiserva: il punto dove la riserva entra davvero (dentro la tua metà campo).
-- lontano = il punto scelto è troppo fuori dalla tua metà: il clic non vale.
local function postoRiserva(x, y)
	local campo = Truppe.campo()
	local colonne = campo and campo.colonne or 6
	local meta = campo and (campo.righe + 1) / 2 or 3.5
	local cx, cy = math.clamp(x, 0.75, colonne + 0.25), math.clamp(y, 0.75, meta - 0.4)
	local lontano = math.abs(cx - x) > 2 or (y - cy) > 1.5 or (cy - y) > 3
	return cx, cy, lontano
end

-- Clic sul campo mentre un comando aspetta il punto: abilità o riserva. Restituisce true se l'ha usato.
local function cliccaCampo(vx, vy)
	if not puntamento then
		return false
	end
	local x, y = casellaSotto(vx, vy)
	if not x then
		return true
	end
	if puntamento.tipo == "riserva" then
		local lontano
		x, y, lontano = postoRiserva(x, y)
		if lontano then
			Notifiche.mostra("The reserve can only enter on your half of the field.", Stile.Colori.Rosso)
			return true
		end
	end
	local scelto = puntamento
	puntamento = nil
	aggiornaPuntamento()
	if scelto.tipo == "abilita" then
		task.spawn(lanciaAbilita, scelto.id, x, y)
	else
		task.spawn(mettiRiserva, scelto.indice, x, y)
	end
	return true
end

-- Ogni frame in battaglia: il cerchio del comando da puntare.
RunService.RenderStepped:Connect(function()
	if fase ~= "battaglia" then
		return
	end
	if puntamento and not Stile.touch() then
		local mouse = UserInputService:GetMouseLocation()
		local x, y = casellaSotto(mouse.X, mouse.Y)
		if x then
			if puntamento.tipo == "abilita" then
				Truppe.anello("Puntamento", x, y, Battaglia.RAGGIO_ABILITA, COLORE_ABILITA, 0.1)
			else
				local cx, cy, lontano = postoRiserva(x, y)
				Truppe.anello("Puntamento", cx, cy, 0.45, lontano and COLORE_NO or COLORE_RISERVA, 0.1)
			end
		end
	end
	if riserva and riserva.messe < riserva.quante then
		aggiornaRiserva()
	end
end)

-- Collaudo "bambino di 9 anni sul telefono" (6/11/2026): l'avatar arriva a più di 100 studs dallo scontro e
-- sul telefono la battaglia era una macchiolina lontana. Quando parte la battaglia, se l'avatar è lontano
-- dai suoi reggimenti, si mette 20 studs dietro di loro guardando il nemico, con la telecamera alle spalle.
-- Poi cammina da solo dietro il suo esercito che avanza, come un comandante, così lo scontro resta vicino.
-- Appena il giocatore muove l'avatar a mano (tasti, levetta, levetta del telefono) smette di seguirlo.
-- In ranked no: i due giocatori stanno su lati opposti del campo.
local LONTANO_DALLA_BATTAGLIA = 40
local DIETRO_LE_FILE = 20
local PIATTO = Vector3.new(1, 0, 1)
local TASTI_CAMMINA = {
	[Enum.KeyCode.W] = true, [Enum.KeyCode.A] = true, [Enum.KeyCode.S] = true, [Enum.KeyCode.D] = true,
	[Enum.KeyCode.Up] = true, [Enum.KeyCode.Down] = true, [Enum.KeyCode.Left] = true, [Enum.KeyCode.Right] = true,
	[Enum.KeyCode.Thumbstick1] = true, [Enum.KeyCode.Space] = true,
}
local battagliaSeguita = 0 -- cresce a ogni battaglia: un ciclo di camminata vecchio si ferma da solo
local seguendo = false -- l'avatar sta camminando da solo dietro l'esercito

-- Punto 20 studs dietro il centro dei nostri, sulla linea verso il nemico (nil se una squadra non c'è più).
local function puntoDietroLeFile()
	local nostri, nemici = Truppe.centro("giocatore"), Truppe.centro("nemico")
	if not (nostri and nemici) then
		return nil
	end
	local verso = ((nemici - nostri) * PIATTO)
	if verso.Magnitude < 1 then
		return nil
	end
	verso = verso.Unit
	return nostri - verso * DIETRO_LE_FILE, verso, nostri, nemici
end

local function avvicinaAllaBattaglia(dati)
	if dati.ranked or (info and info.girato) then
		return
	end
	battagliaSeguita += 1
	local questa = battagliaSeguita
	task.delay(0.3, function()
		if fase ~= "battaglia" or battagliaSeguita ~= questa then
			return
		end
		local character = player.Character
		local radice = character and character:FindFirstChild("HumanoidRootPart")
		local umanoide = character and character:FindFirstChildOfClass("Humanoid")
		local punto, verso, nostri, nemici = puntoDietroLeFile()
		if not (radice and umanoide and punto) then
			return
		end
		if ((radice.Position - nostri) * PIATTO).Magnitude >= LONTANO_DALLA_BATTAGLIA then
			local arrivo = punto + Vector3.new(0, 4, 0)
			character:PivotTo(CFrame.lookAt(arrivo, arrivo + verso))
			radice.AssemblyLinearVelocity = Vector3.zero
			workspace.CurrentCamera.CFrame = CFrame.lookAt(arrivo - verso * 24 + Vector3.new(0, 12, 0), (nostri + nemici) / 2)
		end
		-- Segue l'esercito finché dura la battaglia e il giocatore non prende i comandi.
		seguendo = true
		while fase == "battaglia" and battagliaSeguita == questa and umanoide.Parent and umanoide.Health > 0 do
			punto = puntoDietroLeFile()
			if punto and ((radice.Position - punto) * PIATTO).Magnitude > 6 then
				umanoide:MoveTo(Vector3.new(punto.X, radice.Position.Y, punto.Z))
			end
			task.wait(0.4)
		end
		if battagliaSeguita == questa then
			seguendo = false
		end
	end)
end

-- Il giocatore muove l'avatar da sé: l'avatar non segue più l'esercito in questa battaglia.
UserInputService.InputBegan:Connect(function(input, usatoDaGui)
	if not seguendo or usatoDaGui then
		return
	end
	local mano = TASTI_CAMMINA[input.KeyCode]
	-- Sul telefono la levetta è nella metà sinistra dello schermo (i tocchi sulle carte li prende la GUI).
	local levetta = input.UserInputType == Enum.UserInputType.Touch and input.Position.X < workspace.CurrentCamera.ViewportSize.X / 2
	if mano or levetta then
		battagliaSeguita += 1
		seguendo = false
		local umanoide = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local radice = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if umanoide and radice then
			umanoide:MoveTo(radice.Position) -- ferma la camminata automatica
		end
	end
end)

local function entraBattaglia(dati)
	fase = "battaglia"
	Suoni.musica("battaglia")
	alaScelta, ordiniAli, caricheAli, puntamento = nil, {}, {}, nil
	if info then
		info.entrataBattaglia = dati.entrata
	end
	costruisciBarraBattaglia(dati.reggimenti or {}, dati)
	-- Col controller in battaglia il cursore dell'interfaccia non serve: la croce direzionale dà gli ordini e
	-- CROCE / A manda la riserva (prima la croce spostava anche il cursore tra le carte).
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(barraMazzo.Parent) then
		GuiService.SelectedObject = nil
	end
	barraMazzo.Visible = true
	bottoneCombatti.Visible = false
	bottoneLobby.Visible = false
	esploratori.Visible = false
	pannelloFormazioni.Visible = false
	pannelloOrdini.Visible = true
	aggiornaOrdini()
	aggiornaPuntamento()
	miraArmata, mireReparti, repartoScelto = nil, {}, nil
	aggiornaMire()
	Tutorial.evento("battaglia")
	avvicinaAllaBattaglia(dati)
	sottotitolo.Text = "GET READY!"
	sottotitolo.TextColor3 = Stile.Colori.Oro
	avviso.Text = dati.assedio and "Storm the fortress!" or "The enemy army is revealed!"
	task.spawn(contoAllaRovescia, dati.conto or 3)
	task.delay((dati.conto or 3) + 0.2, function()
		if fase == "battaglia" then
			avviso.Text = "Battle in progress..."
		end
	end)
end

-- Fine di un round: cinematica breve sul campo (Intermezzo) con l'esito e il punteggio, poi il server manda
-- il prossimo schieramento o il risultato. Senza campo, la vecchia grande scritta.
local function mostraRound(dati)
	fase = "round"
	puntamento = nil
	Truppe.togliAnello("Puntamento")
	Tutorial.evento("round")
	mostraPiazzamento(false)
	pannelloOrdini.Visible = false
	mostraVinci(false)
	scrittaConto.Visible = false
	mostraTimer(nil)
	aggiornaPunteggio(dati)
	-- Round vinto: musica vittoriosa a metà; se era l'ultimo, già quella della vittoria.
	if dati.vittoria then
		Suoni.musica(dati.finita and "vittoria" or "roundVinto")
	end
	-- In ranked niente cinematica tra i round (Mattia): solo la scritta col punteggio.
	if info and info.centro and not dati.ranked then
		bannerRound.Visible = false
		Intermezzo.riproduci(dati, info.centro)
		return
	end
	bannerRound.Visible = true
	local titolo = bannerRound:FindFirstChild("Titolo")
	titolo.Text = dati.vittoria and "ROUND WON!" or "ROUND LOST"
	titolo.TextColor3 = dati.vittoria and Stile.ACCENTI.oro.t or Stile.ACCENTI.rosso.t
	bannerRound:FindFirstChild("Punteggio").Text = ("YOU  %d - %d  %s"):format(dati.vinti, dati.persi, dati.ranked and string.upper(dati.avversario or "ENEMY") or "ENEMY")
	pop(bannerRound, 0.6)
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
	if dati.ranked then
		fase = "risultato"
		mostraPiazzamento(false)
		mostraVinci(false)
		pannelloOrdini.Visible = false
		scrittaConto.Visible = false
		bannerRound.Visible = false
		mostraTimer(nil)
		Suoni.musica("vittoria")
		FineRanked.mostra(dati)
		return
	end
	fase = "risultato"
	Tutorial.evento("risultato")
	if dati.vittoria then
		Suoni.musica("vittoria") -- se suona già dalla cinematica dell'ultimo round, continua
	else
		Suoni.fermaMusica()
	end
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
		raggi.ImageColor3 = dati.vittoria and Stile.ACCENTI.oro.t or Stile.ACCENTI.grigio.t
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
	if dati.cassa then
		table.insert(righe, "BONUS: a Small Crate is waiting for you in the SHOP!")
	end
	if dati.nuovoLivelloGiocatore then
		table.insert(righe, ("LEVEL UP! You are now level %d."):format(dati.nuovoLivelloGiocatore))
	end
	if dati.nuoveFormazioni and #dati.nuoveFormazioni > 0 then
		table.insert(righe, "NEW FORMATION: " .. table.concat(dati.nuoveFormazioni, ", ") .. "!")
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

	-- La cassa vinta non si apre qui: aspetta nello SHOP della lobby (Mattia, 31/10/2026).
	bottoneContinua.Visible = true
	bottoneLobbyRisultato.Visible = true
	Stile.seleziona(bottoneContinua)
	if dati.vittoria then
		Preferiti.dopoVittoria()
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
	puntamento = nil
	Truppe.togliAnello("Puntamento")
	Tutorial.ferma()
	Suoni.fermaMusica()
	Suoni.musica("lobby")
	info = nil
	arena = nil
	mostraPiazzamento(false)
	mostraVinci(false)
	risultato.Visible = false
	scrittaConto.Visible = false
	bannerRound.Visible = false
	pannelloOrdini.Visible = false
	Intermezzo.ferma()
	FineRanked.chiudi()
	ripristinaCielo()
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
	nomeNemico = Stile.scritta({
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.new(1, -16, 0, 44),
		Text = "ENEMY",
		TextSize = 40,
		Parent = nemico,
	})
	nomeNemico.TextScaled = true
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 40, Parent = nomeNemico })
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
		BackgroundColor3 = Color3.fromHex("#16171D"),
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
	suggerimento = Stile.testo({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -28, 0, 20),
		Size = UDim2.fromOffset(480, 30),
		Text = "CLICK A CARD TO DEPLOY OR RECALL IT",
		TextColor3 = Stile.Colori.Oro,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = barraMazzo,
	})
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 24, Parent = suggerimento })
	-- Scorre di lato quando le carte sono tante (in ranked si sceglie da tutta la collezione).
	carteMazzo = Stile.crea("ScrollingFrame", {
		Name = "Carte",
		Position = UDim2.fromOffset(20, 66),
		Size = UDim2.new(1, -40, 0, 176),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollingDirection = Enum.ScrollingDirection.X,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
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

	-- FIGHT! e ORDERS al bordo destro sotto Formation su tutte le piattaforme: in partita il tasto del salto
	-- su touch è spento (LobbyVita), quindi non c'è niente da evitare (Mattia, 29/10/2026).
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
	-- Su schermi stretti (tablet 4:3) FIGHT! e ORDERS coprivano l'ultima carta del vassoio: il vassoio si
	-- sposta a sinistra quanto basta per lasciare 20 pixel tra i due (Mattia, 29/10/2026).
	local function sistemaVassoio()
		local scala = Stile.scala()
		if scala <= 0 then
			return
		end
		local larghezza = tela.AbsoluteSize.X / scala
		local meta = barraMazzo.Size.X.Offset / 2
		local centro = larghezza / 2 - 80
		local sinistraFight = larghezza - 28 - bottoneCombatti.Size.X.Offset
		if centro + meta > sinistraFight - 20 then
			centro = math.max(sinistraFight - 20 - meta, 20 + meta)
		end
		barraMazzo.Position = UDim2.new(0, centro, 1, -16)
		-- La barra degli ordini sta sopra il vassoio, allineata con lui.
		if pannelloOrdini then
			pannelloOrdini.Position = UDim2.new(0, centro, 1, pannelloOrdini.Position.Y.Offset)
		end
	end
	Stile.ScalaCambiata:Connect(function()
		task.defer(sistemaVassoio)
	end)
	task.defer(sistemaVassoio)

	bottoneCombatti.Activated:Connect(function()
		local ok, messaggio = remoti.Combatti:InvokeServer()
		if messaggio then
			-- In ranked: "Ready! Waiting for your opponent..."
			Notifiche.mostra(messaggio, not ok and Stile.Colori.Rosso or nil)
		end
	end)

	if Prova and MOSTRA_WIN_ROUND then
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

	-- Pannello "Formation" a destra durante lo schieramento.
	pannelloFormazioni = Stile.crea("Frame", {
		Name = "Formazioni",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -28, 0, 190),
		Size = UDim2.fromOffset(330, 640),
		BackgroundColor3 = Stile.BIANCO,
		Visible = false,
		ZIndex = 5,
		Parent = tela,
	}, { Stile.angoli(26), Stile.bordo(Stile.CONTORNO, 5), Stile.sfumatura(Stile.PAL.notte.b, Stile.PAL.notte.d) })
	local testataFormazioni = targa({
		Name = "Testata",
		Size = UDim2.new(1, 0, 0, 72),
		Parent = pannelloFormazioni,
	}, Stile.PAL.blu, 24)
	Stile.scritta({
		Position = UDim2.fromOffset(22, 0),
		Size = UDim2.new(1, -30, 1, 0),
		Text = "Formation",
		TextSize = 42,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = testataFormazioni,
	})
	-- Le formazioni sono più di quante ne stanno: la lista scorre (rotella o trascinando).
	listaFormazioni = Stile.crea("ScrollingFrame", {
		Name = "Lista",
		Position = UDim2.fromOffset(14, 86),
		Size = UDim2.new(1, -20, 0, 460),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Stile.BIANCO,
		Parent = pannelloFormazioni,
	}, {
		Stile.crea("UIPadding", { PaddingRight = UDim.new(0, 12) }),
		Stile.crea("UIListLayout", {
			Padding = UDim.new(0, 5),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	descrizioneFormazione = Stile.testo({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -28, 0, 80),
		Text = "",
		TextColor3 = Stile.BIANCO,
		FontFace = Stile.FontTesto,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = pannelloFormazioni,
	})
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 10, Parent = descrizioneFormazione })

	-- Barra "Orders" durante la battaglia, sopra le carte e larga come loro (Mattia, 4/11/2026: il pannello di
	-- lato aveva troppe cose). Sopra le ali (tasti Z X C V, sotto il nome l'ordine che sta eseguendo), sotto i
	-- 5 ordini (tasti 1-5). I bersagli si scelgono cliccando un nemico sul campo (o coi tasti 6-0).
	local LARGHEZZA_ORDINI, ALTEZZA_ORDINI = 1100, 154
	local SPAZIO = 18 -- tra un pulsante e l'altro (Mattia, 4/11: "troppo vicini")
	pannelloOrdini = Stile.crea("Frame", {
		Name = "Ordini",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, -80, 1, -16 - 246 - 28),
		Size = UDim2.fromOffset(LARGHEZZA_ORDINI, ALTEZZA_ORDINI),
		BackgroundColor3 = Color3.fromHex("#16171D"),
		BackgroundTransparency = 0.12,
		Visible = false,
		ZIndex = 5,
		Parent = tela,
	}, { Stile.angoli(22), Stile.bordo(Stile.CONTORNO, 4) })
	local voci = { { chiave = "tutte", nome = "ALL", tasto = "Z" } }
	for i, ala in ipairs(Battaglia.ALI) do
		table.insert(voci, { chiave = ala, nome = NOMI_ALA[ala], tasto = ({ "X", "C", "V" })[i] })
	end
	local etichettaAli = Stile.scritta({
		Position = UDim2.fromOffset(20, 14),
		Size = UDim2.fromOffset(110, 52),
		Text = "WING",
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = pannelloOrdini,
	})
	etichettaAli.ZIndex = 6
	local largoAla = (LARGHEZZA_ORDINI - 20 - 110 - 20 - 3 * SPAZIO) / #voci
	for i, voce in ipairs(voci) do
		local bottone = Stile.pulsante({
			Name = "Ala" .. voce.chiave,
			Position = UDim2.fromOffset(20 + 110 + (i - 1) * (largoAla + SPAZIO), 14),
			Size = UDim2.fromOffset(largoAla, 52),
			Parent = pannelloOrdini,
		}, voce.chiave == "tutte" and "oro" or "blu", { Testo = ("%s  %s"):format(voce.tasto, voce.nome), TestoSize = 22, Sotto = "ADVANCE", SottoSize = 14, Profondita = 4, Raggio = 10, Contorno = 3 })
		bottone.Activated:Connect(function()
			scegliAla(voce.chiave ~= "tutte" and voce.chiave or nil)
		end)
		bottoniAla[voce.chiave] = bottone
	end
	local largoOrdine = (LARGHEZZA_ORDINI - 40 - (#Battaglia.ORDINI - 1) * SPAZIO) / #Battaglia.ORDINI
	for i, nome in ipairs(Battaglia.ORDINI) do
		local bottone = Stile.pulsante({
			Name = nome,
			Position = UDim2.fromOffset(20 + (i - 1) * (largoOrdine + SPAZIO), 80),
			Size = UDim2.fromOffset(largoOrdine, 60),
			Parent = pannelloOrdini,
		}, "blu", { Testo = ("%d  %s"):format(i, string.upper(Battaglia.NOMI_ORDINI[nome].nome)), TestoSize = 24, Profondita = 5, Raggio = 12, Contorno = 3 })
		bottone.Activated:Connect(function()
			daiOrdine(nome)
		end)
		bottoniOrdine[nome] = bottone
		if nome == "carica" then
			-- "NOW!" a destra del pulsante quando è il momento della carica perfetta (finestraCarica).
			local adesso = Stile.scritta({
				Name = "Adesso",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(1, 14, 0.5, 0),
				Size = UDim2.fromOffset(170, 70),
				Text = "NOW!",
				TextSize = 64,
				TextColor3 = ORO,
				Visible = false,
				ZIndex = 8,
				Parent = bottone,
			})
			local battitoAdesso = Stile.crea("UIScale", { Parent = adesso })
			RunService.RenderStepped:Connect(function()
				local acceso = fase == "battaglia" and pannelloOrdini.Visible and finestraCarica()
				adesso.Visible = acceso
				if acceso then
					local battito = (math.sin(os.clock() * 12) + 1) / 2
					adesso.Rotation = -6 + 4 * battito
					battitoAdesso.Scale = 0.9 + 0.2 * battito
				end
			end)
		end
	end

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
		TextColor3 = Stile.ACCENTI.oro.t,
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
		TextColor3 = Stile.ACCENTI.acqua.t,
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

	FineRanked.inizializza(gui, remoti)
	Tutorial.inizializza(tela, {
		mazzo = function()
			return barraMazzo
		end,
		primaCarta = function()
			return carte[1]
		end,
		esploratori = function()
			return esploratori
		end,
		formazioni = function()
			return pannelloFormazioni
		end,
		combatti = function()
			return bottoneCombatti
		end,
		ordini = function()
			return pannelloOrdini
		end,
		carica = function()
			return bottoniOrdine.carica
		end,
		finestraCarica = finestraCarica,
	})
	scrittaGrande = Stile.scritta({
		Name = "Momento",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.36, 0),
		Size = UDim2.fromOffset(1100, 140),
		Text = "",
		TextSize = 120,
		Visible = false,
		ZIndex = 30,
		Parent = tela,
	})

	local TASTI = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five }
	local TASTI_MIRA = { Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine, Enum.KeyCode.Zero }
	-- Tasti delle ali: Z tutta l'armata, X sinistra, C centro, V destra (false = tutta l'armata).
	local TASTI_ALA = { [Enum.KeyCode.Z] = false, [Enum.KeyCode.X] = "sinistra", [Enum.KeyCode.C] = "centro", [Enum.KeyCode.V] = "destra" }
	-- Controller (console): croce direzionale e Y per i cinque ordini, Y anche per FIGHT! nello schieramento,
	-- dorsali L1/R1 per cambiare il bersaglio di tutta l'armata.
	local TASTI_PAD = { Enum.KeyCode.DPadUp, Enum.KeyCode.DPadDown, Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadRight, Enum.KeyCode.ButtonY }
	local miraPad = #BERSAGLI
	-- CROCE / A in battaglia: la riserva al posto del salto. Se un pulsante è selezionato (tutorial), resta suo.
	ContextActionService:BindActionAtPriority("RiservaController", function(_, stato)
		if fase ~= "battaglia" or GuiService.SelectedObject then
			return Enum.ContextActionResult.Pass
		end
		if stato == Enum.UserInputState.Begin then
			padRiserva()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonA)
	UserInputService.InputBegan:Connect(function(input, usatoDaGui)
		if fase == "piazzamento" and input.KeyCode == Enum.KeyCode.ButtonY and bottoneCombatti.Visible then
			local ok, messaggio = remoti.Combatti:InvokeServer()
			if messaggio then
				Notifiche.mostra(messaggio, not ok and Stile.Colori.Rosso or nil)
			end
			return
		end
		if fase == "piazzamento" then
			if input.KeyCode == Enum.KeyCode.ButtonX then
				padSchiera()
				return
			elseif input.KeyCode == Enum.KeyCode.ButtonB then
				padRitira()
				return
			elseif input.KeyCode == Enum.KeyCode.ButtonR1 or input.KeyCode == Enum.KeyCode.ButtonL1 then
				padFormazione(input.KeyCode == Enum.KeyCode.ButtonR1 and 1 or -1)
				return
			end
		end
		if fase == "battaglia" then
			if input.KeyCode == Enum.KeyCode.ButtonX then
				padReparto()
				return
			elseif input.KeyCode == Enum.KeyCode.ButtonB then
				padAbilita()
				return
			end
			local pad = table.find(TASTI_PAD, input.KeyCode)
			if pad and Battaglia.ORDINI[pad] then
				Stile.premi(bottoniOrdine[Battaglia.ORDINI[pad]])
				daiOrdine(Battaglia.ORDINI[pad])
				return
			end
			if input.KeyCode == Enum.KeyCode.ButtonR1 or input.KeyCode == Enum.KeyCode.ButtonL1 then
				local passo = input.KeyCode == Enum.KeyCode.ButtonR1 and 1 or -1
				miraPad = (miraPad - 1 + passo) % #BERSAGLI + 1
				daiBersaglio(BERSAGLI[miraPad].filtro)
				return
			end
			-- L2 / R2: l'ala a cui vanno gli ordini (tutta l'armata, sinistra, centro, destra).
			if input.KeyCode == Enum.KeyCode.ButtonR2 or input.KeyCode == Enum.KeyCode.ButtonL2 then
				local giro = { false, "sinistra", "centro", "destra" }
				local attuale = table.find(giro, alaScelta or false) or 1
				local passo = input.KeyCode == Enum.KeyCode.ButtonR2 and 1 or -1
				local nuova = giro[(attuale - 1 + passo) % #giro + 1]
				Stile.premi(bottoniAla[nuova or "tutte"])
				scegliAla(nuova or nil)
				return
			end
		end
		if usatoDaGui or fase ~= "battaglia" then
			return
		end
		local ala = TASTI_ALA[input.KeyCode]
		if ala ~= nil then
			Stile.premi(bottoniAla[ala or "tutte"])
			scegliAla(ala or nil)
			return
		end
		-- Comando che aspetta un punto del campo (abilità o riserva): clic sinistro lo usa, destro lo annulla.
		if puntamento then
			if input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.Escape then
				puntamento = nil
				aggiornaPuntamento()
				avviso.Text = "Cancelled."
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				local inset = game:GetService("GuiService"):GetGuiInset()
				cliccaCampo(input.Position.X, input.Position.Y + inset.Y)
				return
			end
		end
		local numero = table.find(TASTI, input.KeyCode)
		if numero and Battaglia.ORDINI[numero] then
			Stile.premi(bottoniOrdine[Battaglia.ORDINI[numero]])
			daiOrdine(Battaglia.ORDINI[numero])
		end
		local mira = table.find(TASTI_MIRA, input.KeyCode)
		if mira then
			Stile.premi(bottoniMira[mira])
			daiBersaglio(BERSAGLI[mira].filtro)
		end
		-- Clic (o tocco) sul campo: un nemico diventa il bersaglio, un proprio soldato seleziona il suo reggimento.
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			-- input.Position non conta la barra in alto di Roblox, WorldToViewportPoint sì.
			local inset = game:GetService("GuiService"):GetGuiInset()
			local squadra, id = Truppe.reggimentoSulloSchermo(input.Position.X, input.Position.Y + inset.Y, 60)
			if squadra == "nemico" then
				daiBersaglio(id)
			elseif squadra == "giocatore" then
				scegliReparto(id)
			end
		end
	end)
	remoti.Truppe.OnClientEvent:Connect(function(dati)
		if dati.tipo == "passo" and fase == "battaglia" then
			for _, e in ipairs(dati.eventi) do
				eventoBattaglia(e)
			end
		end
	end)
	remoti.Fase.OnClientEvent:Connect(function(dati)
		if dati.fase ~= "piazzamento" and fase == "cinematica" then
			Cinematica.ferma()
		end
		if dati.fase ~= "round" and Intermezzo.inCorso() then
			Intermezzo.ferma()
		end
		if dati.fase == "piazzamento" then
			-- All'inizio di un livello, prima del piazzamento, la cinematica della battaglia.
			local inizioLivello = dati.round == 1 and dati.vinti == 0 and dati.persi == 0
			if inizioLivello and not dati.ranked and fase ~= "cinematica" and Cinematica.daMostrare(dati.nome, dati.livello) then
				fase = "cinematica"
				info = nil
				-- Da NEXT BATTLE: la schermata del risultato non deve restare sopra la cinematica (bug, Mattia 21/10/2026).
				risultato.Visible = false
				bannerRound.Visible = false
				mostraPiazzamento(false)
				mostraVinci(false)
				pannelloOrdini.Visible = false
				scrittaConto.Visible = false
				mostraTimer(nil)
				FineRanked.chiudi()
				Suoni.musica(nil) -- la cinematica ha la sua musica
				impostaCielo(dati)
				local campo = workspace:WaitForChild("Arene"):WaitForChild(dati.arena, 10)
				Cinematica.riproduci(dati.nome, dati.centro, campo, function()
					if fase == "cinematica" then
						entraPiazzamento(dati)
					end
				end)
			else
				entraPiazzamento(dati)
			end
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
