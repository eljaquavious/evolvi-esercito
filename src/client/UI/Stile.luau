-- Colori e funzioni comuni dell'interfaccia.

local Stile = {}

Stile.Colori = {
	Sfondo = Color3.fromRGB(22, 24, 32),
	Pannello = Color3.fromRGB(34, 37, 48),
	PannelloChiaro = Color3.fromRGB(48, 52, 66),
	Bordo = Color3.fromRGB(78, 84, 104),
	Testo = Color3.fromRGB(240, 240, 245),
	TestoSecondario = Color3.fromRGB(170, 176, 192),
	Oro = Color3.fromRGB(255, 204, 72),
	Blu = Color3.fromRGB(70, 140, 255),
	Rosso = Color3.fromRGB(232, 76, 76),
	Verde = Color3.fromRGB(76, 196, 110),
}

Stile.Font = Enum.Font.GothamMedium
Stile.FontTitolo = Enum.Font.GothamBlack

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

function Stile.bordo(colore, spessore)
	return Stile.crea("UIStroke", {
		Color = colore or Stile.Colori.Bordo,
		Thickness = spessore or 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Stile.pannello(proprieta)
	proprieta.BackgroundColor3 = proprieta.BackgroundColor3 or Stile.Colori.Pannello
	proprieta.BorderSizePixel = 0
	return Stile.crea("Frame", proprieta, { Stile.angoli(12), Stile.bordo() })
end

function Stile.testo(proprieta)
	proprieta.BackgroundTransparency = 1
	proprieta.Font = proprieta.Font or Stile.Font
	proprieta.TextColor3 = proprieta.TextColor3 or Stile.Colori.Testo
	proprieta.TextScaled = proprieta.TextScaled ~= false
	return Stile.crea("TextLabel", proprieta)
end

function Stile.bottone(proprieta, colore)
	proprieta.BackgroundColor3 = colore or Stile.Colori.Blu
	proprieta.BorderSizePixel = 0
	proprieta.Font = proprieta.Font or Stile.FontTitolo
	proprieta.TextColor3 = proprieta.TextColor3 or Stile.Colori.Testo
	proprieta.TextScaled = true
	proprieta.AutoButtonColor = true
	local bottone = Stile.crea("TextButton", proprieta, {
		Stile.angoli(10),
		Stile.crea("UIPadding", {
			PaddingTop = UDim.new(0.18, 0),
			PaddingBottom = UDim.new(0.18, 0),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
	})
	return bottone
end

return Stile
