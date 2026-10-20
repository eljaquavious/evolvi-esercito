-- Tutorial della prima battaglia (Mattia, 20/10/2026: "la prima battaglia è un tutorial passo passo").
-- Un riquadro con il consiglio del momento e, se serve, un contorno dorato che lampeggia sull'elemento da usare.
-- Alcuni passi vanno avanti con NEXT, altri quando il giocatore fa la cosa richiesta (Tutorial.evento).
-- Lo comanda Partita: Tutorial.avvia() all'inizio del livello di tutorial, poi gli eventi della partita.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Stile = require(script.Parent.Stile)

local Tutorial = {}

local tela -- la tela 1920x1080 della partita
local bersagli = {} -- nome -> funzione che restituisce l'elemento GUI da evidenziare
local riquadro, testo, titolo, numeroPasso, bottoneAvanti, testoAvanti, contorno, freccia
local passi, indice, attivo = nil, 0, false
local connessione

-- Passi: chiave dell'elemento da evidenziare, testo, e "aspetta" = l'evento che fa andare avanti (nil = NEXT).
-- "fase" = in quale momento della partita si mostra (il passo aspetta che la partita ci arrivi).
local PASSI = {
	{
		fase = "piazzamento",
		titolo = "WELCOME, COMMANDER!",
		testo = "This is your first battle. Follow these steps and you will win it. Your army fights by itself, but YOU command it.",
	},
	{
		fase = "piazzamento",
		titolo = "1 · DEPLOY YOUR REGIMENTS",
		testo = "These are your regiment cards. Click a card to send that regiment onto the field. Click it again to call it back.",
		mostra = "mazzo",
		aspetta = "carta",
	},
	{
		fase = "piazzamento",
		titolo = "2 · KNOW YOUR TROOPS",
		testo = "OVR is the strength of the card. Infantry beats Cavalry, Cavalry beats Ranged, Ranged beats Infantry. Deploy as many regiments as the battle allows.",
		mostra = "mazzo",
	},
	{
		fase = "piazzamento",
		titolo = "3 · READ THE SCOUTS REPORT",
		testo = "Your scouts tell you which troops the enemy will bring. Choose the regiments that beat them.",
		mostra = "esploratori",
	},
	{
		fase = "piazzamento",
		titolo = "4 · PICK A FORMATION",
		testo = "Your regiments take their places at once. New historical formations unlock as you advance in the campaign.",
		mostra = "formazioni",
	},
	{
		fase = "piazzamento",
		titolo = "5 · TO BATTLE!",
		testo = "When your army is ready, press FIGHT!",
		mostra = "combatti",
		aspetta = "battaglia",
	},
	{
		fase = "battaglia",
		titolo = "6 · GIVE ORDERS",
		testo = "Orders go to your whole army. Try HOLD THE LINE (key 2): your regiments stand firm and wait for the enemy. ADVANCE (key 1) sends them forward again.",
		mostra = "ordini",
		aspetta = "ordine",
	},
	{
		fase = "battaglia",
		titolo = "7 · CHOOSE THE TARGET",
		testo = "Pick a TARGET (keys 6-0) or click an enemy regiment on the field: your troops attack it. Click one of your cards first to command only that regiment.",
		mostra = "ordini",
		aspetta = "bersaglio",
	},
	{
		fase = "battaglia",
		titolo = "8 · SOUND THE CHARGE",
		testo = "GENERAL CHARGE (key 5) can be sounded once per round: use it when the armies clash!",
		mostra = "ordini",
		fine = "GOT IT",
	},
	{
		fase = "round",
		titolo = "ROUND OVER",
		testo = "The first army to win 3 rounds wins the battle. Before every round you can change your cards and formation.",
		fine = "GOT IT",
	},
}

local function chiudiRiquadro()
	if riquadro then
		riquadro.Visible = false
	end
	if contorno then
		contorno.Visible = false
	end
end

-- Contorno dorato sopra l'elemento da usare (seguito a ogni frame: i pannelli si muovono e si ridimensionano).
local function seguiBersaglio()
	local passo = passi and passi[indice]
	local elemento = passo and passo.mostra and bersagli[passo.mostra] and bersagli[passo.mostra]()
	if not (attivo and riquadro.Visible and elemento and elemento.Visible and elemento.Parent) then
		contorno.Visible = false
		return
	end
	local scala = Stile.scala()
	local origine = tela.AbsolutePosition
	local pos = (elemento.AbsolutePosition - origine) / scala
	local dim = elemento.AbsoluteSize / scala
	contorno.Position = UDim2.fromOffset(pos.X - 10, pos.Y - 10)
	contorno.Size = UDim2.fromOffset(dim.X + 20, dim.Y + 20)
	contorno.Visible = true
	local lampo = (math.sin(os.clock() * 6) + 1) / 2
	contorno.UIStroke.Transparency = 0.1 + 0.5 * lampo
	-- La freccia sta sopra l'elemento; per i pannelli alti sui lati, di fianco (verso il centro dello schermo).
	local larghezza = tela.AbsoluteSize.X / scala
	if pos.Y > 200 or dim.Y < 300 then
		freccia.Text = "▼"
		freccia.AnchorPoint = Vector2.new(0.5, 1)
		freccia.Position = UDim2.new(0.5, 0, 0, -12 - 8 * lampo)
	elseif pos.X + dim.X / 2 > larghezza / 2 then
		freccia.Text = "▶"
		freccia.AnchorPoint = Vector2.new(1, 0.5)
		freccia.Position = UDim2.new(0, -12 - 8 * lampo, 0.5, 0)
	else
		freccia.Text = "◀"
		freccia.AnchorPoint = Vector2.new(0, 0.5)
		freccia.Position = UDim2.new(1, 12 + 8 * lampo, 0.5, 0)
	end
end

local faseAttuale
local diLato = false -- dopo la prima carta schierata il riquadro va in basso a sinistra (Mattia: "occupa lo schermo")

-- Due misure del riquadro: grande al centro (benvenuto e prima carta), piccolo in basso a sinistra (il resto).
local function impostaLayout()
	if diLato then
		riquadro.AnchorPoint = Vector2.new(0, 1)
		riquadro.Position = UDim2.new(0, 28, 1, -28)
		riquadro.Size = UDim2.fromOffset(290, 330)
		titolo.Size = UDim2.new(1, -40, 0, 60)
		titolo.TextWrapped = true
		titolo.TextSize = 24
		numeroPasso.Visible = false
		testo.Position = UDim2.fromOffset(18, 78)
		testo.Size = UDim2.new(1, -36, 0, 170)
		bottoneAvanti.AnchorPoint = Vector2.new(0.5, 1)
		bottoneAvanti.Position = UDim2.new(0.5, 0, 1, -14)
		bottoneAvanti.Size = UDim2.fromOffset(170, 48)
	else
		riquadro.AnchorPoint = Vector2.new(0.5, 0)
		riquadro.Position = UDim2.new(0.5, 0, 0, 230)
		riquadro.Size = UDim2.fromOffset(760, 210)
		titolo.Size = UDim2.new(1, -150, 0, 44)
		titolo.TextWrapped = false
		titolo.TextSize = 36
		numeroPasso.Visible = true
		testo.Position = UDim2.fromOffset(24, 62)
		testo.Size = UDim2.new(1, -48, 0, 82)
		bottoneAvanti.AnchorPoint = Vector2.new(1, 1)
		bottoneAvanti.Position = UDim2.new(1, -18, 1, -14)
		bottoneAvanti.Size = UDim2.fromOffset(190, 52)
	end
end

local function mostraPasso()
	local passo = passi and passi[indice]
	if not passo then
		attivo = false
		chiudiRiquadro()
		return
	end
	if passo.fase ~= faseAttuale then
		chiudiRiquadro() -- il passo aspetta che la partita arrivi alla sua fase
		return
	end
	-- Dopo la prima carta schierata (passo 2 fatto) il riquadro sta di lato.
	diLato = indice > 2
	impostaLayout()
	titolo.Text = passo.titolo
	testo.Text = passo.testo
	numeroPasso.Text = ("%d / %d"):format(indice, #passi)
	bottoneAvanti.Visible = passo.aspetta == nil
	testoAvanti.Text = passo.fine or "NEXT"
	riquadro.Visible = true
	local scala = riquadro:FindFirstChildOfClass("UIScale")
	scala.Scale = 0.85
	TweenService:Create(scala, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

local function avanti()
	indice += 1
	mostraPasso()
end

function Tutorial.inizializza(t, elementi)
	tela = t
	bersagli = elementi
	riquadro = Stile.crea("Frame", {
		Name = "Tutorial",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 230),
		Size = UDim2.fromOffset(760, 210),
		BackgroundColor3 = Stile.BIANCO,
		Visible = false,
		ZIndex = 40,
		Parent = tela,
	}, {
		Stile.angoli(24),
		Stile.bordo(Stile.CONTORNO, 5),
		Stile.sfumatura(Stile.PAL.notte.b, Stile.PAL.notte.d),
		Stile.crea("UIScale", {}),
	})
	titolo = Stile.scritta({
		Position = UDim2.fromOffset(24, 14),
		Size = UDim2.new(1, -150, 0, 44),
		Text = "",
		TextSize = 36,
		TextColor3 = Stile.Colori.Oro,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 41,
		Parent = riquadro,
	})
	numeroPasso = Stile.testo({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -22, 0, 18),
		Size = UDim2.fromOffset(110, 30),
		Text = "",
		TextColor3 = Stile.PAL.grigio.t,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 41,
		Parent = riquadro,
	})
	testo = Stile.testo({
		Position = UDim2.fromOffset(24, 62),
		Size = UDim2.new(1, -48, 0, 82),
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
	testoAvanti = bottoneAvanti:FindFirstChild("Testo", true)
	bottoneAvanti.Activated:Connect(avanti)
	contorno = Stile.crea("Frame", {
		Name = "TutorialContorno",
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

-- Inizia il tutorial dal primo passo (il livello di tutorial è appena partito).
function Tutorial.avvia()
	passi, indice, attivo = PASSI, 1, true
	faseAttuale = nil
	diLato = false
	if not connessione then
		connessione = RunService.RenderStepped:Connect(function()
			if attivo then
				seguiBersaglio()
			end
		end)
	end
end

function Tutorial.ferma()
	attivo = false
	passi = nil
	chiudiRiquadro()
end

function Tutorial.attivo()
	return attivo
end

-- Eventi della partita: "piazzamento", "battaglia", "round", "risultato" (cambi di fase) e le azioni del
-- giocatore "carta", "ordine", "bersaglio".
function Tutorial.evento(nome)
	if not attivo then
		return
	end
	if nome == "piazzamento" or nome == "battaglia" or nome == "round" or nome == "risultato" then
		faseAttuale = nome
		if nome == "risultato" then
			Tutorial.ferma()
			return
		end
		-- Passi dello schieramento rimasti indietro (FIGHT premuto prima): si saltano. Quelli della battaglia
		-- invece aspettano la battaglia del round dopo, se il round è finito prima di arrivarci.
		while passi[indice] and passi[indice].fase == "piazzamento" and nome ~= "piazzamento" do
			indice += 1
		end
		-- FIGHT premuto: il passo che lo aspettava è fatto.
		if passi[indice] and passi[indice].aspetta == nome then
			indice += 1
		end
		mostraPasso()
		return
	end
	local passo = passi[indice]
	if passo and passo.aspetta == nome and passo.fase == faseAttuale then
		avanti()
	end
end

return Tutorial
