-- Tutorial della lobby: appena si entra nel gioco per la prima volta, una guida passo passo come quella
-- della battaglia 1 (Thermopylae) spiega mazzo, Army, Shop, Ranked, campagna e PLAY (Mattia, 29/10/2026).
-- Stesso aspetto di UI/Tutorial: riquadro con il consiglio, contorno dorato e freccia sull'elemento.
--
-- Rifatto il 10/11/2026 (Mattia: "dev'essere necessario"): riquadro grande, il resto dello schermo oscurato
-- tranne il riquadro e l'elemento indicato (che non si può cliccare: si va avanti con NEXT), un passo sulle
-- RANKED, sempre 7 passi. SKIP salta le spiegazioni ma porta all'ultimo passo: alla fine si deve per forza
-- avviare la prima battaglia (PLAY NOW, o il PLAY vero, l'unico cliccabile).
-- Si vede una volta sola: quando parte la battaglia si salva "tutorialLobby" nelle impostazioni del giocatore.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Stile = require(script.Parent.Stile)

local TutorialLobby = {}

local tela, bersaglio, remoti, avvia
local riquadro, titolo, testo, numeroPasso, bottoneAvanti, testoAvanti, salta, contorno, freccia
local velo = {} -- quattro fasce scure attorno al buco sull'elemento indicato
local tappo -- blocca i clic sull'elemento indicato (tranne PLAY all'ultimo passo)
local indice, attivo, fatto = 0, false, false
local connessione
local finito = Instance.new("BindableEvent")
TutorialLobby.Finito = finito.Event

local BUIO = 0.28 -- trasparenza del velo scuro
local LONTANO = 4000 -- le fasce escono di molto dalla tela, così coprono anche le bande ai lati dello schermo

-- mostra = nome dell'elemento della lobby da indicare (Hud.bersaglio).
local PASSI = {
	{
		titolo = "WELCOME, COMMANDER!",
		testo = "This is your camp. From here you lead your army through 2,500 years of history, from Thermopylae to Khe Sanh. Come back every day for a free Daily reward!",
	},
	{
		titolo = "YOUR DECK",
		testo = "These are the regiment cards you take into battle. Every card is a whole regiment, OVR is its strength.",
		mostra = "Mazzo",
	},
	{
		titolo = "ARMY",
		testo = "Open ARMY to see your collection and change your deck. Win battles to unlock new troops.",
		mostra = "Army",
	},
	{
		titolo = "SHOP",
		testo = "Spend your coins on crates: new troops for your army and cosmetics for your commander.",
		mostra = "Shop",
	},
	{
		titolo = "RANKED 1v1",
		testo = "Ready to test your army? RANKED is open: fight other commanders in a best of 3, climb from Bronze to Champion and win crates.",
		mostra = "Ranked",
	},
	{
		titolo = "CAMPAIGN",
		testo = "Your progress through the 5 eras. Each battle gives up to 3 stars. Keep winning to reach the next era and its generals.",
		mostra = "Campagna",
	},
	{
		titolo = "TO BATTLE!",
		testo = "Your first battle awaits: Thermopylae. Press PLAY to march, the battle will teach you the rest.",
		mostra = "Play",
		fine = "PLAY NOW",
	},
}

local function chiudi()
	riquadro.Visible = false
	contorno.Visible = false
	tappo.Visible = false
	for _, fascia in ipairs(velo) do
		fascia.Visible = false
	end
end

-- Fine del tutorial (la battaglia parte): non si rivede più.
local function termina()
	if not attivo then
		return
	end
	attivo = false
	fatto = true
	chiudi()
	task.spawn(function()
		pcall(function()
			remoti.Impostazioni:InvokeServer("tutorialLobby", true)
		end)
	end)
	finito:Fire()
end

-- L'ultimo passo: si parte per la prima battaglia.
local function parti()
	if not attivo then
		return
	end
	termina()
	if avvia then
		task.spawn(avvia)
	end
end

-- Velo scuro con un buco sul rettangolo (x, y, larghezza, altezza) nelle coordinate della tela; nil = tutto scuro.
local function veloAttorno(x, y, l, a)
	if not x then
		x, y, l, a = 0, 0, 0, 0
	end
	local alto, basso, sinistra, destra = velo[1], velo[2], velo[3], velo[4]
	alto.Position = UDim2.fromOffset(-LONTANO, -LONTANO)
	alto.Size = UDim2.fromOffset(LONTANO * 3, LONTANO + y)
	basso.Position = UDim2.fromOffset(-LONTANO, y + a)
	basso.Size = UDim2.fromOffset(LONTANO * 3, LONTANO * 2)
	sinistra.Position = UDim2.fromOffset(-LONTANO, y)
	sinistra.Size = UDim2.fromOffset(LONTANO + x, a)
	destra.Position = UDim2.fromOffset(x + l, y)
	destra.Size = UDim2.fromOffset(LONTANO * 2, a)
	for _, fascia in ipairs(velo) do
		fascia.Visible = true
	end
	tappo.Position = UDim2.fromOffset(x, y)
	tappo.Size = UDim2.fromOffset(l, a)
	tappo.Visible = l > 0
end

-- Contorno dorato e buco nel velo sull'elemento indicato, seguiti a ogni frame (i riquadri crescono col mouse sopra).
local function seguiBersaglio()
	local passo = PASSI[indice]
	local elemento = passo and passo.mostra and bersaglio(passo.mostra)
	if not riquadro.Visible then
		return
	end
	if not (elemento and elemento.Visible and elemento.Parent) then
		contorno.Visible = false
		veloAttorno(nil)
		return
	end
	local scala = Stile.scala()
	local pos = (elemento.AbsolutePosition - tela.AbsolutePosition) / scala
	local dim = elemento.AbsoluteSize / scala
	contorno.Position = UDim2.fromOffset(pos.X - 10, pos.Y - 10)
	contorno.Size = UDim2.fromOffset(dim.X + 20, dim.Y + 20)
	contorno.Visible = true
	veloAttorno(pos.X - 14, pos.Y - 14, dim.X + 28, dim.Y + 28)
	-- All'ultimo passo il PLAY vero si può premere: il tappo non c'è.
	tappo.Visible = not passo.fine
	local lampo = (math.sin(os.clock() * 6) + 1) / 2
	contorno.UIStroke.Transparency = 0.35 * lampo
	-- Freccia verso il centro dello schermo: di lato per gli elementi ai bordi, sopra per quelli in basso al centro.
	local larghezza = tela.AbsoluteSize.X / scala
	local centroX = pos.X + dim.X / 2
	if centroX < larghezza * 0.3 then
		freccia.Text = "◀"
		freccia.AnchorPoint = Vector2.new(0, 0.5)
		freccia.Position = UDim2.new(1, 12 + 8 * lampo, 0.5, 0)
	elseif centroX > larghezza * 0.7 then
		freccia.Text = "▶"
		freccia.AnchorPoint = Vector2.new(1, 0.5)
		freccia.Position = UDim2.new(0, -12 - 8 * lampo, 0.5, 0)
	else
		freccia.Text = "▼"
		freccia.AnchorPoint = Vector2.new(0.5, 1)
		freccia.Position = UDim2.new(0.5, 0, 0, -12 - 8 * lampo)
	end
end

local function mostraPasso()
	local passo = PASSI[indice]
	if not passo then
		parti()
		return
	end
	titolo.Text = passo.titolo
	testo.Text = passo.testo
	numeroPasso.Text = ("%d / %d"):format(indice, #PASSI)
	testoAvanti.Text = passo.fine or "NEXT"
	-- All'ultimo passo non si salta più: si parte.
	salta.Visible = not passo.fine
	-- Senza elemento da indicare il riquadro sta al centro; con un elemento, in alto al centro (gli elementi sono
	-- ai lati e in basso).
	riquadro.AnchorPoint = Vector2.new(0.5, passo.mostra and 0 or 0.5)
	riquadro.Position = passo.mostra and UDim2.new(0.5, 0, 0, 190) or UDim2.fromScale(0.5, 0.45)
	riquadro.Visible = true
	seguiBersaglio()
	local scala = riquadro:FindFirstChildOfClass("UIScale")
	scala.Scale = 0.85
	TweenService:Create(scala, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	Stile.seleziona(bottoneAvanti)
end

-- gui: la ScreenGui della lobby; funzioneBersaglio: Hud.bersaglio; r: i remoti;
-- funzioneAvvia: fa partire la prima battaglia (alla fine del tutorial).
function TutorialLobby.inizializza(gui, funzioneBersaglio, r, funzioneAvvia)
	tela = Stile.radice(gui)
	bersaglio = funzioneBersaglio
	remoti = r
	avvia = funzioneAvvia
	-- Il velo: quattro fasce scure che fermano i clic (Active), più il tappo trasparente sul buco.
	for i = 1, 4 do
		velo[i] = Stile.crea("TextButton", {
			Name = "TutorialVelo",
			Text = "",
			AutoButtonColor = false,
			Active = true,
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = BUIO,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 38,
			Parent = tela,
		})
	end
	tappo = Stile.crea("TextButton", {
		Name = "TutorialTappo",
		Text = "",
		AutoButtonColor = false,
		Active = true,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 38,
		Parent = tela,
	})
	riquadro = Stile.crea("Frame", {
		Name = "TutorialLobby",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(1040, 400),
		BackgroundColor3 = Stile.VETRO,
		BackgroundTransparency = 0.02,
		Visible = false,
		ZIndex = 40,
		Parent = tela,
	}, {
		Stile.angoli(28),
		Stile.bordo(Stile.Colori.Oro, 4, 0.1),
		Stile.crea("UIScale", {}),
	})
	titolo = Stile.scritta({
		Position = UDim2.fromOffset(32, 20),
		Size = UDim2.new(1, -330, 0, 68),
		Text = "",
		TextSize = 58,
		TextColor3 = Stile.Colori.Oro,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 41,
		Parent = riquadro,
	})
	-- I titoli lunghi si rimpiccioliscono invece di finire sotto "1 / 7".
	titolo.TextScaled = true
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 58, Parent = titolo })
	numeroPasso = Stile.testo({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -184, 0, 34),
		Size = UDim2.fromOffset(110, 44),
		Text = "",
		TextColor3 = Stile.ACCENTI.grigio.t,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 41,
		Parent = riquadro,
	})
	salta = Stile.crea("TextButton", {
		Name = "Salta",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 24),
		Size = UDim2.fromOffset(140, 54),
		BackgroundColor3 = Stile.BIANCO,
		BackgroundTransparency = 0.88,
		Text = "SKIP",
		TextSize = 30,
		FontFace = Stile.FontEtichetta,
		TextColor3 = Stile.BIANCO,
		AutoButtonColor = false,
		ZIndex = 42,
		Parent = riquadro,
	}, { Stile.tondo(), Stile.bordo(Stile.BIANCO, 2, 0.7) })
	salta.MouseEnter:Connect(function()
		salta.BackgroundTransparency = 0.7
	end)
	salta.MouseLeave:Connect(function()
		salta.BackgroundTransparency = 0.88
	end)
	-- SKIP: via le spiegazioni, ma la prima battaglia si gioca comunque.
	salta.Activated:Connect(function()
		indice = #PASSI
		mostraPasso()
	end)
	testo = Stile.testo({
		Position = UDim2.fromOffset(36, 104),
		Size = UDim2.new(1, -72, 0, 180),
		Text = "",
		TextColor3 = Stile.BIANCO,
		FontFace = Stile.FontTesto,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 41,
		Parent = riquadro,
	})
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 42, MinTextSize = 16, Parent = testo })
	bottoneAvanti = Stile.pulsante({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -20),
		Size = UDim2.fromOffset(320, 84),
		ZIndex = 42,
		Parent = riquadro,
	}, Stile.ACCENTI.verde, { Testo = "NEXT", TestoSize = 44, Profondita = 6, Raggio = 14, Contorno = 3 })
	testoAvanti = bottoneAvanti:FindFirstChild("Testo", true)
	bottoneAvanti.Activated:Connect(function()
		if PASSI[indice] and PASSI[indice].fine then
			parti()
			return
		end
		indice += 1
		mostraPasso()
	end)
	contorno = Stile.crea("Frame", {
		Name = "TutorialLobbyContorno",
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 39,
		Parent = tela,
	}, {
		Stile.angoli(18),
		Stile.crea("UIStroke", { Color = Stile.Colori.Oro, Thickness = 6 }),
	})
	freccia = Stile.scritta({
		Size = UDim2.fromOffset(80, 70),
		Text = "▼",
		TextSize = 64,
		TextColor3 = Stile.Colori.Oro,
		ZIndex = 39,
		Parent = contorno,
	})
end

function TutorialLobby.attivo()
	return attivo
end

-- Con lo stato del giocatore: parte se è la prima volta (tutorial mai visto e campagna al livello 1).
-- Restituisce true se il tutorial è partito o è in corso.
function TutorialLobby.forse(stato)
	if attivo then
		return true
	end
	if fatto or not stato then
		return false
	end
	local visto = stato.impostazioni and stato.impostazioni.tutorialLobby
	if visto or (stato.livello or 1) > 1 or stato.completata then
		fatto = true
		return false
	end
	attivo = true
	indice = 1
	if not connessione then
		connessione = RunService.RenderStepped:Connect(function()
			if attivo then
				seguiBersaglio()
			end
		end)
	end
	task.delay(1.5, function()
		if attivo then
			mostraPasso()
		end
	end)
	return true
end

-- PLAY premuto o lobby lasciata: il tutorial si chiude e conta come visto.
function TutorialLobby.ferma()
	termina()
end

return TutorialLobby
