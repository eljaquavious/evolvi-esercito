-- Colori, caratteri e funzioni comuni dell'interfaccia.

local Stile = {}

Stile.Colori = {
	Sfondo = Color3.fromRGB(16, 20, 32),
	Pannello = Color3.fromRGB(28, 34, 52),
	PannelloChiaro = Color3.fromRGB(44, 52, 76),
	Bordo = Color3.fromRGB(90, 102, 140),
	Testo = Color3.fromRGB(244, 244, 250),
	TestoSecondario = Color3.fromRGB(170, 180, 204),
	Oro = Color3.fromRGB(255, 206, 84),
	OroScuro = Color3.fromRGB(176, 128, 40),
	Blu = Color3.fromRGB(64, 132, 255),
	Rosso = Color3.fromRGB(232, 72, 72),
	Verde = Color3.fromRGB(70, 196, 110),
	Viola = Color3.fromRGB(150, 96, 230),
	Secondario = Color3.fromRGB(104, 116, 152),
}

Stile.Font = Enum.Font.GothamBold
Stile.FontTesto = Enum.Font.GothamMedium
Stile.FontTitolo = Enum.Font.LuckiestGuy

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

function Stile.angoli(raggio)
	return Stile.crea("UICorner", { CornerRadius = UDim.new(0, raggio or 10) })
end

function Stile.bordo(colore, spessore, trasparenza)
	return Stile.crea("UIStroke", {
		Color = colore or Stile.Colori.Bordo,
		Thickness = spessore or 1.5,
		Transparency = trasparenza or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Stile.sfumatura(alto, basso, rotazione)
	return Stile.crea("UIGradient", {
		Color = ColorSequence.new(alto, basso),
		Rotation = rotazione or 90,
	})
end

function Stile.pannello(proprieta)
	proprieta.BackgroundColor3 = proprieta.BackgroundColor3 or Stile.Colori.Pannello
	proprieta.BorderSizePixel = 0
	local colore = proprieta.BackgroundColor3
	return Stile.crea("Frame", proprieta, {
		Stile.angoli(14),
		Stile.bordo(Stile.Colori.Bordo, 1.5, 0.3),
		Stile.sfumatura(colore:Lerp(Color3.new(1, 1, 1), 0.06), colore:Lerp(Color3.new(0, 0, 0), 0.2)),
	})
end

function Stile.testo(proprieta)
	proprieta.BackgroundTransparency = 1
	proprieta.Font = proprieta.Font or Stile.Font
	proprieta.TextColor3 = proprieta.TextColor3 or Stile.Colori.Testo
	proprieta.TextScaled = proprieta.TextScaled ~= false
	return Stile.crea("TextLabel", proprieta)
end

-- Titolo con contorno, per scritte grandi.
function Stile.titolo(proprieta)
	proprieta.Font = Stile.FontTitolo
	local etichetta = Stile.testo(proprieta)
	Stile.crea("UIStroke", { Thickness = 2, Color = Color3.fromRGB(20, 14, 6), Parent = etichetta })
	return etichetta
end

function Stile.bottone(proprieta, colore)
	colore = colore or Stile.Colori.Blu
	proprieta.BackgroundColor3 = colore
	proprieta.BorderSizePixel = 0
	proprieta.Font = proprieta.Font or Stile.FontTitolo
	proprieta.TextColor3 = proprieta.TextColor3 or Stile.Colori.Testo
	proprieta.TextScaled = true
	proprieta.AutoButtonColor = true
	local bottone = Stile.crea("TextButton", proprieta, {
		Stile.angoli(12),
		Stile.bordo(colore:Lerp(Color3.new(0, 0, 0), 0.45), 2),
		Stile.sfumatura(colore:Lerp(Color3.new(1, 1, 1), 0.18), colore:Lerp(Color3.new(0, 0, 0), 0.18)),
		Stile.crea("UIPadding", {
			PaddingTop = UDim.new(0.2, 0),
			PaddingBottom = UDim.new(0.2, 0),
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
		}),
	})
	Stile.crea("UIStroke", {
		Thickness = 1.5,
		Color = Color3.fromRGB(20, 14, 6),
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Parent = bottone,
	})
	return bottone
end

-- Finestra centrale con titolo e pulsante di chiusura. Restituisce finestra e area del contenuto.
function Stile.finestra(gui, nome, titolo, colore)
	local finestra = Stile.pannello({
		Name = nome,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, -116, 0.53, 0),
		Size = UDim2.new(0.94, -232, 0.84, 0),
		BackgroundColor3 = Stile.Colori.Sfondo,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	})
	Stile.crea("UISizeConstraint", { MinSize = Vector2.new(360, 320), MaxSize = Vector2.new(1100, 760), Parent = finestra })
	Stile.titolo({
		Position = UDim2.fromOffset(22, 14),
		Size = UDim2.new(1, -100, 0, 40),
		Text = titolo,
		TextColor3 = colore or Stile.Colori.Oro,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 11,
		Parent = finestra,
	})
	local chiudi = Stile.bottone({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(44, 40),
		Text = "X",
		ZIndex = 11,
		Parent = finestra,
	}, Stile.Colori.Rosso)
	chiudi.Activated:Connect(function()
		finestra.Visible = false
	end)
	local contenuto = Stile.crea("Frame", {
		Name = "Contenuto",
		Position = UDim2.fromOffset(22, 66),
		Size = UDim2.new(1, -44, 1, -86),
		BackgroundTransparency = 1,
		ZIndex = 11,
		Parent = finestra,
	})
	return finestra, contenuto
end

return Stile
