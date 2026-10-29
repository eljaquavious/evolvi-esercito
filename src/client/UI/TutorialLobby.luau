-- Tutorial della lobby: appena si entra nel gioco per la prima volta, una guida passo passo come quella
-- della battaglia 1 (Thermopylae) spiega mazzo, Army, Shop, Daily, campagna e PLAY (Mattia, 29/10/2026).
-- Stesso aspetto di UI/Tutorial: riquadro con il consiglio, contorno dorato e freccia sull'elemento.
-- Si vede una volta sola: alla fine (o con SKIP) si salva "tutorialLobby" nelle impostazioni del giocatore.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Stile = require(script.Parent.Stile)

local TutorialLobby = {}

local tela, bersaglio, remoti
local riquadro, titolo, testo, numeroPasso, bottoneAvanti, testoAvanti, contorno, freccia
local indice, attivo, fatto = 0, false, false
local connessione
local finito = Instance.new("BindableEvent")
TutorialLobby.Finito = finito.Event

-- mostra = nome dell'elemento della lobby da indicare (Hud.bersaglio).
local PASSI = {
	{
		titolo = "WELCOME, COMMANDER!",
		testo = "This is your camp. From here you lead your army through 2,500 years of history, from Thermopylae to Khe Sanh.",
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
		titolo = "DAILY REWARD",
		testo = "Come back every day: a new reward each day, for 7 days in a row.",
		mostra = "Daily",
	},
	{
		titolo = "CAMPAIGN",
		testo = "Your progress through the 5 eras. Each battle gives up to 3 stars. Keep winning to reach the next era and its generals.",
		mostra = "Campagna",
	},
	{
		titolo = "TO BATTLE!",
		testo = "Press PLAY to open the campaign map and attack your first battle: Thermopylae. The battle will teach you the rest.",
		mostra = "Play",
		fine = "LET'S GO",
	},
}

local function chiudiRiquadro()
	riquadro.Visible = false
	contorno.Visible = false
end

-- Fine del tutorial (ultimo passo, SKIP o PLAY premuto): non si rivede più.
local function termina()
	if not attivo then
		return
	end
	attivo = false
	fatto = true
	chiudiRiquadro()
	task.spawn(function()
		pcall(function()
			remoti.Impostazioni:InvokeServer("tutorialLobby", true)
		end)
	end)
	finito:Fire()
end

-- Contorno dorato sull'elemento indicato, seguito a ogni frame (i riquadri crescono col mouse sopra).
local function seguiBersaglio()
	local passo = PASSI[indice]
	local elemento = passo and passo.mostra and bersaglio(passo.mostra)
	if not (riquadro.Visible and elemento and elemento.Visible and elemento.Parent) then
		contorno.Visible = false
		return
	end
	local scala = Stile.scala()
	local pos = (elemento.AbsolutePosition - tela.AbsolutePosition) / scala
	local dim = elemento.AbsoluteSize / scala
	contorno.Position = UDim2.fromOffset(pos.X - 10, pos.Y - 10)
	contorno.Size = UDim2.fromOffset(dim.X + 20, dim.Y + 20)
	contorno.Visible = true
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
		termina()
		return
	end
	titolo.Text = passo.titolo
	testo.Text = passo.testo
	numeroPasso.Text = ("%d / %d"):format(indice, #PASSI)
	testoAvanti.Text = passo.fine or "NEXT"
	riquadro.Visible = true
	local scala = riquadro:FindFirstChildOfClass("UIScale")
	scala.Scale = 0.85
	TweenService:Create(scala, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	Stile.seleziona(bottoneAvanti)
end

-- gui: la ScreenGui della lobby; funzioneBersaglio: Hud.bersaglio; r: i remoti.
function TutorialLobby.inizializza(gui, funzioneBersaglio, r)
	tela = Stile.radice(gui)
	bersaglio = funzioneBersaglio
	remoti = r
	riquadro = Stile.crea("Frame", {
		Name = "TutorialLobby",
		-- A destra del menu dei riquadri, non in mezzo: lascia libera la vista (Mattia, 29/10/2026).
		Position = UDim2.fromOffset(390, 300),
		Size = UDim2.fromOffset(560, 240),
		BackgroundColor3 = Stile.VETRO,
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 40,
		Parent = tela,
	}, {
		Stile.angoli(24),
		Stile.bordo(Stile.BIANCO, 2, 0.6),
		Stile.crea("UIScale", {}),
	})
	titolo = Stile.scritta({
		Position = UDim2.fromOffset(24, 14),
		Size = UDim2.new(1, -230, 0, 40),
		Text = "",
		TextSize = 32,
		TextColor3 = Stile.Colori.Oro,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 41,
		Parent = riquadro,
	})
	-- I titoli lunghi si rimpiccioliscono invece di finire sotto "1 / 7".
	titolo.TextScaled = true
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 32, Parent = titolo })
	numeroPasso = Stile.testo({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -130, 0, 20),
		Size = UDim2.fromOffset(90, 28),
		Text = "",
		TextColor3 = Stile.ACCENTI.grigio.t,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 41,
		Parent = riquadro,
	})
	local salta = Stile.crea("TextButton", {
		Name = "Salta",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 16),
		Size = UDim2.fromOffset(96, 36),
		BackgroundColor3 = Stile.BIANCO,
		BackgroundTransparency = 0.88,
		Text = "SKIP",
		TextSize = 20,
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
	salta.Activated:Connect(termina)
	testo = Stile.testo({
		Position = UDim2.fromOffset(24, 62),
		Size = UDim2.new(1, -48, 0, 104),
		Text = "",
		TextColor3 = Stile.BIANCO,
		FontFace = Stile.FontTesto,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 41,
		Parent = riquadro,
	})
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 26, MinTextSize = 12, Parent = testo })
	bottoneAvanti = Stile.pulsante({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -18, 1, -14),
		Size = UDim2.fromOffset(190, 52),
		ZIndex = 42,
		Parent = riquadro,
	}, "verde", { Testo = "NEXT", TestoSize = 28, Profondita = 5, Raggio = 12, Contorno = 3 })
	Stile.vetro(bottoneAvanti)
	testoAvanti = bottoneAvanti:FindFirstChild("Testo", true)
	bottoneAvanti.Activated:Connect(function()
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
