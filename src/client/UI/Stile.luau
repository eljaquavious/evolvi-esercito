-- Stile dell'interfaccia: colori vivaci con contorno scuro, pulsanti 3D, font Fredoka One + Nunito.
-- Tutto è disegnato in "pixel di progetto" su una tela 1920x1080 (vedi Stile.radice):
-- un UIScale adatta la tela allo schermo, così misure, contorni e testi restano proporzionati.

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Icone = require(script.Parent.Icone)

local Stile = {}

local function hex(h)
	return Color3.fromHex(h)
end

Stile.CONTORNO = hex("#1B1636")
Stile.BIANCO = Color3.new(1, 1, 1)

-- Tavolozza: t = alto della sfumatura, b = basso, d = base scura (lato 3D).
Stile.PAL = {
	rosso = { t = hex("#FF6B6B"), b = hex("#E5213B"), d = hex("#9B0F2A") },
	blu = { t = hex("#5CC8FF"), b = hex("#1E7BF0"), d = hex("#123F99") },
	viola = { t = hex("#C77DFF"), b = hex("#8A2BE2"), d = hex("#4E1596") },
	oro = { t = hex("#FFE45C"), b = hex("#FFA51F"), d = hex("#B35A00") },
	verde = { t = hex("#7CF56E"), b = hex("#21C04A"), d = hex("#0F7A30") },
	acqua = { t = hex("#5CF2E0"), b = hex("#13B8C9"), d = hex("#0B6C80") },
	rosa = { t = hex("#FF8AD8"), b = hex("#E8359E"), d = hex("#8E1563") },
	arancio = { t = hex("#FFB04D"), b = hex("#FF6A1A"), d = hex("#A33A00") },
	grigio = { t = hex("#B4BCD6"), b = hex("#717C9C"), d = hex("#3E4560") },
	notte = { t = hex("#4B4F86"), b = hex("#2B2D5C"), d = hex("#15163A") },
}

-- Colori semplici, per chi ha bisogno di un solo colore (notifiche, testi).
Stile.Colori = {
	Sfondo = hex("#2B2D5C"),
	Pannello = hex("#2B2D5C"),
	PannelloChiaro = hex("#F4F6FF"),
	Bordo = Stile.CONTORNO,
	Testo = Stile.BIANCO,
	TestoScuro = hex("#24183F"),
	TestoSecondario = hex("#6B6F9E"),
	Oro = hex("#FFD23F"),
	OroScuro = hex("#B35A00"),
	Blu = hex("#1E7BF0"),
	Azzurro = hex("#5CC8FF"),
	Rosso = hex("#E5213B"),
	Verde = hex("#21C04A"),
	Viola = hex("#8A2BE2"),
	Rosa = hex("#E8359E"),
	Acqua = hex("#13B8C9"),
	Secondario = hex("#717C9C"),
}

-- Fredoka One per titoli e numeri, Nunito per le etichette. Entrambi sono già dentro Roblox.
Stile.FontTitolo = Font.fromEnum(Enum.Font.FredokaOne)
Stile.FontEtichetta = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Heavy)
Stile.FontTesto = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Bold)

local LARGHEZZA, ALTEZZA = 1920, 1080

-- Crea un'istanza con proprietà e figli. Parent viene impostato per ultimo.
function Stile.crea(classe, proprieta, figli)
	local istanza = Instance.new(classe)
	local genitore
	for k, v in pairs(proprieta or {}) do
		if k == "Parent" then
			genitore = v
		else
			istanza[k] = v
		end
	end
	for _, figlio in ipairs(figli or {}) do
		figlio.Parent = istanza
	end
	istanza.Parent = genitore
	return istanza
end

-- Tela 1920x1080 adattata allo schermo: tutte le schermate si costruiscono qui dentro.
local radici = {}
local scalaAttuale = 1
local cambiScala = Instance.new("BindableEvent")
Stile.ScalaCambiata = cambiScala.Event

function Stile.scala()
	return scalaAttuale
end

function Stile.radice(gui)
	if radici[gui] then
		return radici[gui]
	end
	local tela = Stile.crea("Frame", {
		Name = "Tela",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(LARGHEZZA, ALTEZZA),
		Parent = gui,
	})
	local scala = Stile.crea("UIScale", { Parent = tela })
	local function adatta()
		local schermo = gui.AbsoluteSize
		if schermo.X < 1 or schermo.Y < 1 then
			return
		end
		local s = math.min(schermo.X / LARGHEZZA, schermo.Y / ALTEZZA)
		scalaAttuale = s
		scala.Scale = s
		-- La tela copre tutto lo schermo: i bordi seguono lo schermo, le misure restano in pixel di progetto.
		tela.Size = UDim2.fromOffset(schermo.X / s, schermo.Y / s)
		cambiScala:Fire(s)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(adatta)
	adatta()
	radici[gui] = tela
	return tela
end

function Stile.angoli(raggio)
	return Stile.crea("UICorner", { CornerRadius = UDim.new(0, raggio or 16) })
end

function Stile.tondo()
	return Stile.crea("UICorner", { CornerRadius = UDim.new(1, 0) })
end

function Stile.bordo(colore, spessore, trasparenza)
	return Stile.crea("UIStroke", {
		Color = colore or Stile.CONTORNO,
		Thickness = spessore or 4,
		Transparency = trasparenza or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

function Stile.sfumatura(alto, basso, rotazione)
	return Stile.crea("UIGradient", {
		Color = ColorSequence.new(alto, basso),
		Rotation = rotazione or 90,
	})
end

-- Testo semplice in Nunito, senza contorno.
function Stile.testo(proprieta)
	proprieta.BackgroundTransparency = 1
	proprieta.FontFace = proprieta.FontFace or Stile.FontEtichetta
	proprieta.TextColor3 = proprieta.TextColor3 or Stile.Colori.TestoScuro
	if proprieta.TextSize == nil and proprieta.TextScaled == nil then
		proprieta.TextScaled = true
	end
	return Stile.crea("TextLabel", proprieta)
end

-- Scritta bianca in Fredoka One con contorno scuro, come nei giochi simulator.
-- proprieta.Contorno: spessore del contorno (di solito un decimo della dimensione del testo).
function Stile.scritta(proprieta)
	local spessore = proprieta.Contorno
	proprieta.Contorno = nil
	proprieta.FontFace = proprieta.FontFace or Stile.FontTitolo
	proprieta.TextColor3 = proprieta.TextColor3 or Stile.BIANCO
	local etichetta = Stile.testo(proprieta)
	local dimensione = proprieta.TextSize or 32
	Stile.crea("UIStroke", {
		Name = "Contorno",
		Color = Stile.CONTORNO,
		Thickness = spessore or math.max(2, math.floor(dimensione / 9 + 0.5)),
		LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Parent = etichetta,
	})
	return etichetta
end

-- Compatibilità con il vecchio nome.
Stile.titolo = Stile.scritta

-- Icona dell'interfaccia (immagine caricata su Roblox; finché manca, un'emoji al suo posto).
function Stile.icona(nome, proprieta)
	return Icone.crea(nome, proprieta)
end

-- Riflesso bianco sulla metà alta di un pulsante.
local function riflesso(genitore, raggio, trasparenza)
	return Stile.crea("Frame", {
		Name = "Riflesso",
		Position = UDim2.new(0, 6, 0, 5),
		Size = UDim2.new(1, -12, 0.42, 0),
		BackgroundColor3 = Stile.BIANCO,
		BackgroundTransparency = trasparenza or 0.72,
		BorderSizePixel = 0,
		Parent = genitore,
	}, { Stile.angoli(math.max(4, raggio - 6)) })
end

local function animaPressione(bottone, faccia, profondita)
	local scala = Stile.crea("UIScale", { Parent = bottone })
	local info = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local premuto = false
	local function aggiorna()
		local sopra = bottone:GetAttribute("Sopra")
		TweenService:Create(scala, info, { Scale = premuto and 0.96 or (sopra and 1.04 or 1) }):Play()
		if faccia then
			faccia.Position = UDim2.fromOffset(0, premuto and math.floor(profondita / 2) or 0)
		end
	end
	bottone.MouseEnter:Connect(function()
		bottone:SetAttribute("Sopra", true)
		aggiorna()
	end)
	bottone.MouseLeave:Connect(function()
		bottone:SetAttribute("Sopra", false)
		premuto = false
		aggiorna()
	end)
	bottone.MouseButton1Down:Connect(function()
		premuto = true
		aggiorna()
	end)
	bottone.MouseButton1Up:Connect(function()
		premuto = false
		aggiorna()
	end)
	return scala
end

-- Colora (o ricolora) un pulsante creato con Stile.pulsante.
function Stile.coloraPulsante(bottone, pal)
	pal = type(pal) == "string" and Stile.PAL[pal] or pal
	local base = bottone:FindFirstChild("Base")
	local faccia = bottone:FindFirstChild("Faccia")
	if base then
		base.BackgroundColor3 = pal.d
	end
	if faccia then
		faccia:FindFirstChildOfClass("UIGradient").Color = ColorSequence.new(pal.t, pal.b)
	end
end

-- Pulsante 3D: base scura sotto, faccia con sfumatura, riflesso, contorno spesso.
-- opzioni: { Testo, TestoSize, Icona, IconaSize, Sotto (sottotitolo), SottoSize, Profondita, Raggio }
-- Restituisce il TextButton, l'etichetta principale, la faccia (per aggiungere altro) e l'eventuale sottotitolo.
function Stile.pulsante(proprieta, pal, opzioni)
	opzioni = opzioni or {}
	pal = type(pal) == "string" and Stile.PAL[pal] or pal or Stile.PAL.blu
	local profondita = opzioni.Profondita or 8
	local raggio = opzioni.Raggio or 18
	proprieta.Text = ""
	proprieta.AutoButtonColor = false
	proprieta.BackgroundTransparency = 1
	local bottone = Stile.crea("TextButton", proprieta)
	Stile.crea("Frame", {
		Name = "Base",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = pal.d,
		BorderSizePixel = 0,
		Parent = bottone,
	}, { Stile.angoli(raggio), Stile.bordo(Stile.CONTORNO, opzioni.Contorno or 5) })
	local faccia = Stile.crea("Frame", {
		Name = "Faccia",
		Size = UDim2.new(1, 0, 1, -profondita),
		BackgroundColor3 = Stile.BIANCO,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Parent = bottone,
	}, { Stile.angoli(raggio), Stile.sfumatura(pal.t, pal.b) })
	riflesso(faccia, raggio)

	local inizioTesto = 0
	if opzioni.Icona then
		local lato = opzioni.IconaSize or math.floor((proprieta.Size and proprieta.Size.Y.Offset or 80) * 0.78)
		Stile.icona(opzioni.Icona, {
			Name = "Icona",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, opzioni.IconaX or 14, 0.5, 0),
			Size = UDim2.fromOffset(lato, lato),
			Parent = faccia,
		})
		inizioTesto = (opzioni.IconaX or 14) + lato
	end
	local etichetta, sotto
	if opzioni.Testo then
		local dimensione = opzioni.TestoSize or 40
		local hasSotto = opzioni.Sotto ~= nil
		etichetta = Stile.scritta({
			Name = "Testo",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, inizioTesto, hasSotto and 0.4 or 0.5, 0),
			Size = UDim2.new(1, -inizioTesto - 10, 0, dimensione + 6),
			Text = opzioni.Testo,
			TextSize = dimensione,
			TextScaled = false,
			Parent = faccia,
		})
		Stile.crea("UITextSizeConstraint", { MaxTextSize = dimensione, MinTextSize = 10, Parent = etichetta })
		etichetta.TextScaled = true
		if hasSotto then
			local ds = opzioni.SottoSize or 22
			sotto = Stile.scritta({
				Name = "Sotto",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, inizioTesto, 0.78, 0),
				Size = UDim2.new(1, -inizioTesto - 10, 0, ds + 4),
				Text = opzioni.Sotto,
				TextSize = ds,
				Contorno = 3,
				Parent = faccia,
			})
			sotto.TextScaled = true
			Stile.crea("UITextSizeConstraint", { MaxTextSize = ds, MinTextSize = 8, Parent = sotto })
		end
	end
	animaPressione(bottone, faccia, profondita)
	return bottone, etichetta, faccia, sotto
end

-- Pulsante rotondo 3D con un'icona (chiudi, indietro...).
function Stile.pulsanteTondo(proprieta, pal, icona, lato)
	pal = type(pal) == "string" and Stile.PAL[pal] or pal
	lato = lato or 90
	proprieta.Size = proprieta.Size or UDim2.fromOffset(lato, lato)
	proprieta.Text = ""
	proprieta.AutoButtonColor = false
	proprieta.BackgroundTransparency = 1
	local bottone = Stile.crea("TextButton", proprieta)
	local profondita = math.floor(lato * 0.08)
	Stile.crea("Frame", {
		Name = "Base",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = pal.d,
		Parent = bottone,
	}, { Stile.tondo(), Stile.bordo(Stile.CONTORNO, 5) })
	local faccia = Stile.crea("Frame", {
		Name = "Faccia",
		Size = UDim2.new(1, 0, 1, -profondita),
		BackgroundColor3 = Stile.BIANCO,
		Parent = bottone,
	}, { Stile.tondo(), Stile.sfumatura(pal.t, pal.b) })
	Stile.crea("Frame", {
		Position = UDim2.fromScale(0.2, 0.06),
		Size = UDim2.fromScale(0.6, 0.36),
		BackgroundColor3 = Stile.BIANCO,
		BackgroundTransparency = 0.7,
		Parent = faccia,
	}, { Stile.tondo() })
	Stile.icona(icona, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.58, 0.58),
		Parent = faccia,
	})
	animaPressione(bottone, faccia, profondita)
	return bottone
end

-- Riquadro grande della lobby: icona 3D in alto, scritta sotto, eventuale distintivo.
function Stile.riquadro(proprieta, pal, icona, testo)
	local bottone, _, faccia = Stile.pulsante(proprieta, pal, { Raggio = 26, Profondita = 10, Contorno = 6 })
	Stile.icona(icona, {
		Name = "Icona",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromScale(0.68, 0.68),
		Parent = faccia,
	})
	local scritta = Stile.scritta({
		Name = "Testo",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(1, -12, 0, 50),
		Text = testo,
		TextSize = 46,
		Contorno = 5,
		Parent = faccia,
	})
	scritta.TextScaled = true
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 46, Parent = scritta })
	return bottone, faccia
end

-- Distintivo rosso con "!" (novità) nell'angolo di un riquadro.
function Stile.avviso(genitore)
	local punto = Stile.crea("Frame", {
		Name = "Avviso",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = Stile.Colori.Rosso,
		ZIndex = 5,
		Parent = genitore,
	}, { Stile.tondo(), Stile.bordo(Stile.BIANCO, 4), Stile.sfumatura(Stile.PAL.rosso.t, Stile.PAL.rosso.b) })
	Stile.scritta({
		Size = UDim2.fromScale(1, 1),
		Text = "!",
		TextSize = 30,
		Contorno = 2,
		ZIndex = 6,
		Parent = punto,
	})
	return punto
end

-- Nastro inclinato ("SOON", "NEW CARD!", "LEGEND").
function Stile.nastro(proprieta, pal, testo, dimensione)
	pal = type(pal) == "string" and Stile.PAL[pal] or pal
	proprieta.BackgroundColor3 = Stile.BIANCO
	proprieta.Rotation = proprieta.Rotation or 12
	proprieta.ZIndex = proprieta.ZIndex or 6
	local nastro = Stile.crea("Frame", proprieta, {
		Stile.tondo(),
		Stile.bordo(Stile.CONTORNO, 4),
		Stile.sfumatura(pal.t, pal.b),
	})
	Stile.scritta({
		Size = UDim2.fromScale(1, 1),
		Text = testo,
		TextSize = dimensione or 26,
		Contorno = 3,
		ZIndex = proprieta.ZIndex + 1,
		Parent = nastro,
	})
	return nastro
end

-- Etichetta colorata a pillola ("AVG OVR 71", "MEDIEVAL ERA").
function Stile.chip(proprieta, pal, testo, dimensione)
	pal = type(pal) == "string" and Stile.PAL[pal] or pal
	proprieta.BackgroundColor3 = Stile.BIANCO
	local chip = Stile.crea("Frame", proprieta, {
		Stile.tondo(),
		Stile.bordo(Stile.CONTORNO, 4),
		Stile.sfumatura(pal.t, pal.b),
	})
	local etichetta = Stile.scritta({
		Name = "Testo",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -16, 1, -6),
		Text = testo,
		TextSize = dimensione or 26,
		Contorno = 3,
		Parent = chip,
	})
	etichetta.TextScaled = true
	Stile.crea("UITextSizeConstraint", { MaxTextSize = dimensione or 26, Parent = etichetta })
	return chip, etichetta
end

-- Pillola blu notte con un'icona grande a sinistra (monete, stelle). Restituisce la pillola e il numero.
-- conPiu: aggiunge il pulsante verde "+" a destra (restituito come terzo valore).
function Stile.pillola(proprieta, icona, testo, conPiu)
	local altezza = proprieta.Size and proprieta.Size.Y.Offset or 70
	proprieta.BackgroundTransparency = 1
	local pillola = Stile.crea("Frame", proprieta)
	Stile.crea("Frame", {
		Name = "Fondo",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, altezza * 0.45, 0.5, 0),
		Size = UDim2.new(1, -altezza * 0.45, 0.82, 0),
		BackgroundColor3 = Stile.BIANCO,
		Parent = pillola,
	}, {
		Stile.tondo(),
		Stile.bordo(Stile.CONTORNO, 5),
		Stile.sfumatura(Stile.PAL.notte.t, Stile.PAL.notte.d),
	})
	Stile.icona(icona, {
		Name = "Icona",
		Size = UDim2.fromOffset(altezza * 1.08, altezza * 1.08),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -4, 0.5, 0),
		ZIndex = 3,
		Parent = pillola,
	})
	local destra = conPiu and altezza * 0.9 or 18
	local numero = Stile.scritta({
		Name = "Numero",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -destra, 0.5, 0),
		Size = UDim2.new(1, -altezza * 1.1 - destra, 0, altezza * 0.6),
		Text = testo or "0",
		TextSize = math.floor(altezza * 0.56),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
		Parent = pillola,
	})
	numero.TextScaled = true
	Stile.crea("UITextSizeConstraint", { MaxTextSize = math.floor(altezza * 0.56), Parent = numero })
	local piu
	if conPiu then
		piu = Stile.pulsante({
			Name = "Piu",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 2, 0.5, 0),
			Size = UDim2.fromOffset(altezza * 0.78, altezza * 0.78),
			ZIndex = 4,
			Parent = pillola,
		}, "verde", { Raggio = 14, Profondita = 5, Contorno = 4 })
		Stile.icona("plus", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.75, 0.75),
			Parent = piu:FindFirstChild("Faccia"),
		})
	end
	return pillola, numero, piu
end

-- Barra di avanzamento con binario scuro e riempimento colorato. Restituisce una tabella con :imposta(frazione, testo).
function Stile.barra(proprieta, pal, dimensioneTesto)
	pal = type(pal) == "string" and Stile.PAL[pal] or pal
	proprieta.BackgroundColor3 = hex("#15163A")
	local binario = Stile.crea("Frame", proprieta, { Stile.tondo(), Stile.bordo(Stile.CONTORNO, 4) })
	local riempimento = Stile.crea("Frame", {
		Name = "Riempimento",
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(0, 0, 1, -6),
		BackgroundColor3 = Stile.BIANCO,
		Parent = binario,
	}, { Stile.tondo(), Stile.sfumatura(pal.t, pal.b) })
	Stile.crea("Frame", {
		Position = UDim2.new(0, 6, 0, 2),
		Size = UDim2.new(1, -12, 0.38, 0),
		BackgroundColor3 = Stile.BIANCO,
		BackgroundTransparency = 0.6,
		Parent = riempimento,
	}, { Stile.tondo() })
	local testo
	if dimensioneTesto then
		testo = Stile.scritta({
			Name = "Testo",
			Size = UDim2.fromScale(1, 1),
			Text = "",
			TextSize = dimensioneTesto,
			Contorno = 3,
			ZIndex = (proprieta.ZIndex or 1) + 2,
			Parent = binario,
		})
	end
	local barra = { binario = binario, testo = testo }
	function barra:imposta(frazione, scritta)
		frazione = math.clamp(frazione or 0, 0, 1)
		riempimento.Visible = frazione > 0
		riempimento.Size = UDim2.new(frazione, frazione > 0 and -6 * frazione or 0, 1, -6)
		if testo and scritta then
			testo.Text = scritta
		end
	end
	return barra
end

-- Pannello blu notte semitrasparente (mazzo della lobby, esercito nemico...).
function Stile.pannello(proprieta, trasparenza)
	proprieta.BackgroundColor3 = proprieta.BackgroundColor3 or hex("#1E1F45")
	proprieta.BackgroundTransparency = proprieta.BackgroundTransparency or trasparenza or 0.15
	proprieta.BorderSizePixel = 0
	return Stile.crea("Frame", proprieta, { Stile.angoli(proprieta.Raggio or 28) })
end

-- Riquadro chiaro dentro le finestre.
function Stile.vassoio(proprieta)
	proprieta.BackgroundColor3 = proprieta.BackgroundColor3 or hex("#E4E9FA")
	proprieta.BorderSizePixel = 0
	return Stile.crea("Frame", proprieta, { Stile.angoli(24), Stile.bordo(Stile.CONTORNO, 4) })
end

-- Pulsante della chiusura: tondo rosso con la X.
function Stile.chiudi(proprieta)
	return Stile.pulsanteTondo(proprieta, "rosso", "close", 96)
end

-- Finestra centrale: fascia colorata con titolo e icona, corpo bianco, X rossa in alto a destra.
-- pal: nome del colore della fascia; icona: nome dell'icona accanto al titolo.
-- Restituisce finestra, area del contenuto e fascia (per aggiungere ad esempio le monete).
function Stile.finestra(gui, nome, titolo, pal, icona)
	pal = type(pal) == "string" and Stile.PAL[pal] or (typeof(pal) == "table" and pal) or Stile.PAL.blu
	local tela = Stile.radice(gui)
	local finestra = Stile.crea("Frame", {
		Name = nome,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 12),
		Size = UDim2.fromOffset(1796, 988),
		BackgroundColor3 = hex("#F4F6FF"),
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 10,
		Parent = tela,
	}, { Stile.angoli(40), Stile.bordo(Stile.CONTORNO, 7) })
	-- Ombra.
	Stile.crea("Frame", {
		Name = "Ombra",
		Position = UDim2.fromOffset(0, 14),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Stile.CONTORNO,
		BackgroundTransparency = 0.55,
		ZIndex = 9,
		Parent = finestra,
	}, { Stile.angoli(40) })
	local fascia = Stile.crea("Frame", {
		Name = "Fascia",
		Size = UDim2.new(1, 0, 0, 112),
		BackgroundColor3 = Stile.BIANCO,
		BorderSizePixel = 0,
		ZIndex = 11,
		Parent = finestra,
	}, { Stile.angoli(40), Stile.sfumatura(pal.t, pal.b) })
	-- Copre gli angoli arrotondati in basso della fascia e fa da linea di separazione.
	Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = pal.b,
		BorderSizePixel = 0,
		ZIndex = 11,
		Parent = fascia,
	})
	Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 3),
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = Stile.CONTORNO,
		BorderSizePixel = 0,
		ZIndex = 12,
		Parent = fascia,
	})
	Stile.crea("Frame", {
		Position = UDim2.fromOffset(20, 10),
		Size = UDim2.new(1, -40, 0, 34),
		BackgroundColor3 = Stile.BIANCO,
		BackgroundTransparency = 0.78,
		ZIndex = 12,
		Parent = fascia,
	}, { Stile.angoli(20) })
	if icona then
		Stile.icona(icona, {
			Name = "Icona",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 34, 0.5, -10),
			Size = UDim2.fromOffset(136, 136),
			ZIndex = 14,
			Parent = fascia,
		})
	end
	Stile.scritta({
		Name = "Titolo",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, icona and 176 or 40, 0.5, 0),
		Size = UDim2.fromOffset(900, 80),
		Text = titolo,
		TextSize = 72,
		Contorno = 7,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 14,
		Parent = fascia,
	})
	local chiudi = Stile.chiudi({
		Name = "Chiudi",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -18, 0, 26),
		ZIndex = 20,
		Parent = finestra,
	})
	chiudi.Activated:Connect(function()
		finestra.Visible = false
	end)
	local contenuto = Stile.crea("Frame", {
		Name = "Contenuto",
		Position = UDim2.fromOffset(44, 140),
		Size = UDim2.new(1, -88, 1, -168),
		BackgroundTransparency = 1,
		ZIndex = 11,
		Parent = finestra,
	})
	-- Piccola animazione di apertura.
	local scala = Stile.crea("UIScale", { Parent = finestra })
	finestra:GetPropertyChangedSignal("Visible"):Connect(function()
		if finestra.Visible then
			scala.Scale = 0.9
			TweenService:Create(scala, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
				:Play()
			-- Col controller la selezione parte dal primo pulsante della finestra (le schede in alto).
			if Stile.gamepad() then
				task.delay(0.1, function()
					Stile.seleziona(Stile.primoPulsante(contenuto))
				end)
			end
		elseif GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(finestra) then
			GuiService.SelectedObject = nil
		end
	end)
	return finestra, contenuto, fascia
end

-- ===================================================================== telefono, tablet e console

-- Telefono o tablet (schermo touch senza tastiera).
function Stile.touch()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- Su telefono e tablet Roblox mette il pulsante del salto in basso a destra: i pulsanti nostri ancorati in
-- basso a destra (PLAY, FIGHT!, ORDERS) si spostano a sinistra di tanto (pixel di progetto).
Stile.MARGINE_SALTO = 270

-- Distanza dal bordo destro per un elemento in basso a destra: quella data, più lo spazio del salto sul touch.
function Stile.destra(margine)
	return -(margine + (Stile.touch() and Stile.MARGINE_SALTO or 0))
end

-- Si sta usando un controller (console o gamepad sul PC)?
function Stile.gamepad()
	local ultimo = UserInputService:GetLastInputType()
	return ultimo.Name:sub(1, 7) == "Gamepad"
end

-- Con il controller il riquadro di selezione va su questo pulsante (con mouse e touch non fa nulla).
function Stile.seleziona(oggetto)
	if oggetto and Stile.gamepad() then
		task.defer(function()
			if oggetto.Parent and oggetto.Visible then
				GuiService.SelectedObject = oggetto
			end
		end)
	end
end

-- Primo pulsante visibile dentro un contenitore (per la selezione col controller).
function Stile.primoPulsante(contenitore)
	for _, d in ipairs(contenitore:GetDescendants()) do
		if d:IsA("GuiButton") and d.Visible and d.Selectable then
			local visibile, x = true, d.Parent
			while x and x ~= contenitore do
				if x:IsA("GuiObject") and not x.Visible then
					visibile = false
					break
				end
				x = x.Parent
			end
			if visibile then
				return d
			end
		end
	end
	return nil
end

-- Numero con separatore delle migliaia: 1625 -> "1,625".
function Stile.numero(n)
	local s = tostring(math.floor(n or 0))
	local segno = ""
	if string.sub(s, 1, 1) == "-" then
		segno, s = "-", string.sub(s, 2)
	end
	local fuori = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if string.sub(fuori, 1, 1) == "," then
		fuori = string.sub(fuori, 2)
	end
	return segno .. fuori
end

return Stile
