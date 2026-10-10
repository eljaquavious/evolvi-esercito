-- Carta di un reggimento, in stile carte dei giochi di calcio: OVR, ruolo, ritratto 3D e statistiche.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Epoche = require(ReplicatedStorage.Shared.Config.Epoche)
local Carte = require(ReplicatedStorage.Shared.Config.Carte)
local Modelli = require(ReplicatedStorage.Shared.Modelli)
local Stile = require(script.Parent.Stile)

local Carta = {}

Carta.PROPORZIONE = 0.7 -- larghezza / altezza

-- Colori della carta per epoca: { alto, basso, bordo, testo, nome sulla fascia }.
local TEMI = {
	Antica = { Color3.fromRGB(240, 186, 150), Color3.fromRGB(150, 62, 44), Color3.fromRGB(255, 214, 180), Color3.fromRGB(56, 18, 10) },
	Medievale = { Color3.fromRGB(236, 196, 112), Color3.fromRGB(150, 98, 38), Color3.fromRGB(255, 226, 150), Color3.fromRGB(46, 30, 10) },
	Novecento = { Color3.fromRGB(178, 190, 160), Color3.fromRGB(62, 74, 50), Color3.fromRGB(214, 226, 190), Color3.fromRGB(20, 26, 14) },
	-- Comandanti: carta leggendaria nera e oro.
	Leggenda = { Color3.fromRGB(78, 64, 44), Color3.fromRGB(18, 14, 10), Color3.fromRGB(255, 210, 90), Color3.fromRGB(246, 206, 112), Color3.fromRGB(30, 22, 8) },
}

function Carta.tema(def)
	return def.comandante and TEMI.Leggenda or TEMI[def.epoca] or TEMI.Medievale
end

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
	local tema = Carta.tema(def)
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
		TextColor3 = tema[5] or tema[3],
		Parent = fascia,
	})
	if def.comandante then
		Stile.testo({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 0.55),
			Size = UDim2.fromScale(0.6, 0.06),
			Text = "LEGEND",
			Font = Stile.FontTitolo,
			TextColor3 = tema[3],
			Parent = carta,
		})
	end

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
-- testo: scritta opzionale sul velo (es. "DEPLOYED").
function Carta.spegni(carta, spenta, testo)
	local velo = carta:FindFirstChild("Velo")
	if spenta and not velo then
		velo = Stile.crea("Frame", {
			Name = "Velo",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = testo and 0.3 or 0.45,
			ZIndex = 4,
			Parent = carta,
		}, { Stile.angoli(12) })
		if testo then
			Stile.titolo({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.42),
				Size = UDim2.fromScale(0.9, 0.12),
				Text = testo,
				TextColor3 = Stile.Colori.Verde,
				ZIndex = 5,
				Parent = velo,
			})
		end
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

-- Carta piccola per la barra del mazzo: ritratto, OVR e numero dello slot.
function Carta.mini(tipo, numero)
	local def = Epoche.Truppe[tipo]
	local tema = Carta.tema(def)
	local carta = Stile.crea("TextButton", {
		Name = "Mini_" .. tipo,
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	}, {
		Stile.angoli(8),
		Stile.crea("UIStroke", { Color = tema[3], Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		Stile.sfumatura(tema[1], tema[2], 110),
		Stile.crea("UIAspectRatioConstraint", { AspectRatio = 0.82 }),
	})
	local vista = ritratto(carta, tipo)
	vista.AnchorPoint = Vector2.new(0.5, 0)
	vista.Position = UDim2.fromScale(0.5, 0.02)
	vista.Size = UDim2.fromScale(0.95, 0.78)
	Stile.titolo({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -4, 1, -2),
		Size = UDim2.fromScale(0.5, 0.26),
		Text = tostring(Carte.valutazioni(def).OVR),
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = carta,
	})
	if numero then
		Stile.crea("TextLabel", {
			Position = UDim2.fromOffset(-4, -4),
			Size = UDim2.fromScale(0.3, 0.24),
			BackgroundColor3 = Stile.Colori.Sfondo,
			Text = tostring(numero),
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			Font = Stile.Font,
			ZIndex = 3,
			Parent = carta,
		}, { Stile.angoli(4), Stile.bordo(Color3.new(1, 1, 1), 1) })
	end
	return carta
end

return Carta
