-- Carta di un reggimento, in stile carte dei giochi di calcio: OVR, ruolo, ritratto 3D e statistiche.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Epoche = require(ReplicatedStorage.Shared.Config.Epoche)
local Carte = require(ReplicatedStorage.Shared.Config.Carte)
local Modelli = require(ReplicatedStorage.Shared.Modelli)
local Stile = require(script.Parent.Stile)

local Carta = {}

Carta.PROPORZIONE = 0.7 -- larghezza / altezza

-- Colori della carta per epoca: { alto, basso, bordo, testo }.
local TEMI = {
	Medievale = { Color3.fromRGB(236, 196, 112), Color3.fromRGB(150, 98, 38), Color3.fromRGB(255, 226, 150), Color3.fromRGB(46, 30, 10) },
	Novecento = { Color3.fromRGB(178, 190, 160), Color3.fromRGB(62, 74, 50), Color3.fromRGB(214, 226, 190), Color3.fromRGB(20, 26, 14) },
}

local function ritratto(genitore, tipo)
	local vista = Stile.crea("ViewportFrame", {
		Name = "Ritratto",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0.04, 0),
		Size = UDim2.fromScale(0.68, 0.5),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 170, 170),
		LightColor = Color3.fromRGB(255, 244, 230),
		LightDirection = Vector3.new(-1, -1.4, 1),
		Parent = genitore,
	})
	local modello = Modelli.soldato(tipo, "giocatore")
	modello.Parent = vista
	local cframe, dimensione = modello:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	local distanza = dimensione.Magnitude * 1.65
	local centro = cframe.Position + Vector3.new(0, dimensione.Y * 0.05, 0)
	camera.CFrame = CFrame.lookAt(centro + Vector3.new(-0.55, 0.3, -1).Unit * distanza, centro)
	camera.Parent = vista
	vista.CurrentCamera = camera
	return vista
end

-- Crea la carta di "tipo". opzioni: { quantita = numero, nota = testo in basso, spenta = bool }
-- Restituisce un TextButton: dimensione e posizione le decide chi la usa.
function Carta.crea(tipo, opzioni)
	opzioni = opzioni or {}
	local def = Epoche.Truppe[tipo]
	local v = Carte.valutazioni(def)
	local tema = TEMI[def.epoca] or TEMI.Medievale
	local scuro = tema[4]

	local carta = Stile.crea("TextButton", {
		Name = "Carta_" .. tipo,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	}, {
		Stile.angoli(12),
		-- Border: su un TextButton il bordo "Contextual" andrebbe sul testo (vuoto) e non si vedrebbe.
		Stile.crea("UIStroke", { Color = tema[3], Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		Stile.sfumatura(tema[1], tema[2], 110),
		Stile.crea("UIAspectRatioConstraint", { AspectRatio = Carta.PROPORZIONE }),
	})

	carta:FindFirstChildWhichIsA("UIStroke"):SetAttribute("Originale", tema[3])

	-- OVR, ruolo ed epoca in alto a sinistra.
	Stile.testo({
		Position = UDim2.fromScale(0.07, 0.04),
		Size = UDim2.fromScale(0.3, 0.16),
		Text = tostring(v.OVR),
		Font = Stile.FontTitolo,
		TextColor3 = scuro,
		Parent = carta,
	})
	Stile.testo({
		Position = UDim2.fromScale(0.07, 0.2),
		Size = UDim2.fromScale(0.3, 0.07),
		Text = Epoche.Classi[def.classe].sigla,
		Font = Stile.Font,
		TextColor3 = scuro,
		Parent = carta,
	})
	Stile.crea("Frame", {
		Position = UDim2.fromScale(0.1, 0.29),
		Size = UDim2.fromScale(0.24, 0.006),
		BackgroundColor3 = scuro,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		Parent = carta,
	})
	Stile.testo({
		Position = UDim2.fromScale(0.07, 0.31),
		Size = UDim2.fromScale(0.3, 0.055),
		Text = "x" .. def.soldati,
		Font = Stile.Font,
		TextColor3 = scuro,
		Parent = carta,
	})

	ritratto(carta, tipo)

	-- Nome su una fascia.
	local fascia = Stile.crea("Frame", {
		Position = UDim2.fromScale(0.06, 0.55),
		Size = UDim2.fromScale(0.88, 0.1),
		BackgroundColor3 = scuro,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Parent = carta,
	}, { Stile.angoli(6) })
	Stile.testo({
		Position = UDim2.fromScale(0.04, 0.1),
		Size = UDim2.fromScale(0.92, 0.8),
		Text = string.upper(def.nome),
		Font = Stile.FontTitolo,
		TextColor3 = tema[3],
		Parent = fascia,
	})

	-- Statistiche su due colonne.
	local statistiche = Stile.crea("Frame", {
		Position = UDim2.fromScale(0.08, 0.68),
		Size = UDim2.fromScale(0.84, 0.28),
		BackgroundTransparency = 1,
		Parent = carta,
	}, {
		Stile.crea("UIGridLayout", {
			CellSize = UDim2.fromScale(0.5, 0.33),
			CellPadding = UDim2.fromScale(0, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local voci = {}
	for _, nome in ipairs(Carte.ORDINE_STATISTICHE) do
		table.insert(voci, { v[nome], nome })
	end
	table.insert(voci, { def.soldati, "MEN" })
	for i, voce in ipairs(voci) do
		local cella = Stile.crea("Frame", { BackgroundTransparency = 1, LayoutOrder = i, Parent = statistiche })
		Stile.testo({
			Size = UDim2.fromScale(0.42, 0.9),
			Text = tostring(voce[1]),
			Font = Stile.FontTitolo,
			TextColor3 = scuro,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = cella,
		})
		Stile.testo({
			Position = UDim2.fromScale(0.48, 0.12),
			Size = UDim2.fromScale(0.5, 0.7),
			Text = voce[2],
			Font = Stile.Font,
			TextColor3 = scuro,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = cella,
		})
	end

	if opzioni.quantita then
		Stile.crea("TextLabel", {
			Name = "Quantita",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 4, 0, -6),
			Size = UDim2.fromScale(0.3, 0.12),
			BackgroundColor3 = Stile.Colori.Rosso,
			Text = "x" .. opzioni.quantita,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			Font = Stile.Font,
			ZIndex = 5,
			Parent = carta,
		}, { Stile.angoli(8), Stile.bordo(Color3.new(1, 1, 1), 1.5) })
	end

	if opzioni.nota then
		Stile.crea("TextLabel", {
			Name = "Nota",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.9, 0.14),
			BackgroundColor3 = Stile.Colori.Sfondo,
			BackgroundTransparency = 0.15,
			Text = opzioni.nota,
			TextColor3 = Stile.Colori.Oro,
			TextScaled = true,
			Font = Stile.FontTitolo,
			ZIndex = 6,
			Parent = carta,
		}, { Stile.angoli(6) })
	end

	Carta.spegni(carta, opzioni.spenta)
	return carta
end

-- Scurisce la carta (già usata, non posseduta...).
function Carta.spegni(carta, spenta)
	local velo = carta:FindFirstChild("Velo")
	if spenta and not velo then
		Stile.crea("Frame", {
			Name = "Velo",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.45,
			ZIndex = 4,
			Parent = carta,
		}, { Stile.angoli(12) })
	elseif not spenta and velo then
		velo:Destroy()
	end
end

-- Evidenzia la carta selezionata con un bordo azzurro spesso.
function Carta.seleziona(carta, selezionata)
	local bordo = carta:FindFirstChildWhichIsA("UIStroke")
	if bordo then
		bordo.Thickness = selezionata and 5 or 2.5
		bordo.Color = selezionata and Color3.fromRGB(90, 220, 255) or bordo:GetAttribute("Originale")
	end
end

return Carta
