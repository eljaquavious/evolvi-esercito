-- Modelli delle truppe, costruiti con parti semplici.
-- Ogni modello ha una parte "Radice" ancorata a terra; le altre sono saldate alla radice,
-- quindi basta muovere la radice. Il fronte del modello è la direzione -Z.

local Modelli = {}

local COLORI_SQUADRA = {
	giocatore = Color3.fromRGB(58, 118, 222),
	nemico = Color3.fromRGB(206, 62, 62),
}
local PELLE = Color3.fromRGB(234, 190, 150)
local SCURO = Color3.fromRGB(46, 44, 42)
local METALLO = Color3.fromRGB(170, 174, 182)
local LEGNO = Color3.fromRGB(122, 82, 46)
local OLIVA = Color3.fromRGB(92, 104, 62)

local function parte(modello, radice, nome, dimensione, offset, colore, forma, materiale)
	local p = Instance.new("Part")
	p.Name = nome
	p.Size = dimensione
	p.Color = colore
	p.Shape = forma or Enum.PartType.Block
	p.Material = materiale or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.CFrame = radice.CFrame * offset
	local saldatura = Instance.new("WeldConstraint")
	saldatura.Part0 = radice
	saldatura.Part1 = p
	saldatura.Parent = p
	p.Parent = modello
	return p
end

local function soldato(m, r, colore, elmo, altezza)
	altezza = altezza or 0
	parte(m, r, "Gambe", Vector3.new(1.2, 1.4, 0.7), CFrame.new(0, 0.7 + altezza, 0), SCURO)
	parte(m, r, "Busto", Vector3.new(1.6, 1.6, 0.9), CFrame.new(0, 2.2 + altezza, 0), colore)
	parte(m, r, "Testa", Vector3.new(1.1, 1.1, 1.1), CFrame.new(0, 3.55 + altezza, 0), PELLE, Enum.PartType.Ball)
	if elmo then
		parte(m, r, "Elmo", Vector3.new(1.25, 0.45, 1.25), CFrame.new(0, 4.05 + altezza, 0), elmo, nil, Enum.Material.Metal)
	end
end

local COSTRUTTORI = {
	Spadaccino = function(m, r, c)
		soldato(m, r, c, METALLO)
		parte(m, r, "Spada", Vector3.new(0.2, 0.3, 2.4), CFrame.new(1.0, 2.2, -1.0), METALLO, nil, Enum.Material.Metal)
		parte(m, r, "Scudo", Vector3.new(0.3, 1.5, 1.2), CFrame.new(-1.0, 2.2, -0.2), c:Lerp(SCURO, 0.3))
	end,
	Arciere = function(m, r, c)
		soldato(m, r, c, nil)
		parte(m, r, "Cappuccio", Vector3.new(1.2, 0.5, 1.2), CFrame.new(0, 4.0, 0), c:Lerp(SCURO, 0.4))
		parte(m, r, "Arco", Vector3.new(0.2, 2.8, 0.25), CFrame.new(-1.0, 2.3, -0.5), LEGNO, nil, Enum.Material.Wood)
		parte(m, r, "Faretra", Vector3.new(0.5, 1.4, 0.5), CFrame.new(0.5, 2.5, 0.7), LEGNO)
	end,
	Cavaliere = function(m, r, c)
		local marrone = Color3.fromRGB(110, 72, 42)
		parte(m, r, "Cavallo", Vector3.new(1.4, 1.3, 3.0), CFrame.new(0, 1.9, 0), marrone)
		parte(m, r, "TestaCavallo", Vector3.new(0.8, 1.0, 1.3), CFrame.new(0, 2.8, -1.8), marrone)
		for _, posizione in ipairs({ Vector3.new(0.45, 0.6, 1.1), Vector3.new(-0.45, 0.6, 1.1), Vector3.new(0.45, 0.6, -1.1), Vector3.new(-0.45, 0.6, -1.1) }) do
			parte(m, r, "Zampa", Vector3.new(0.35, 1.2, 0.35), CFrame.new(posizione), marrone:Lerp(SCURO, 0.4))
		end
		parte(m, r, "Busto", Vector3.new(1.3, 1.4, 0.8), CFrame.new(0, 3.2, 0.2), c)
		parte(m, r, "Testa", Vector3.new(1.0, 1.0, 1.0), CFrame.new(0, 4.4, 0.2), PELLE, Enum.PartType.Ball)
		parte(m, r, "Elmo", Vector3.new(1.15, 0.45, 1.15), CFrame.new(0, 4.85, 0.2), METALLO, nil, Enum.Material.Metal)
		parte(m, r, "Lancia", Vector3.new(0.2, 0.2, 4.0), CFrame.new(0.8, 3.3, -1.4), LEGNO, nil, Enum.Material.Wood)
	end,
	Fante = function(m, r, c)
		soldato(m, r, c:Lerp(OLIVA, 0.35), OLIVA)
		parte(m, r, "Fucile", Vector3.new(0.25, 0.25, 2.6), CFrame.new(0.9, 2.4, -0.8), SCURO, nil, Enum.Material.Metal)
		parte(m, r, "Zaino", Vector3.new(1.2, 1.2, 0.5), CFrame.new(0, 2.3, 0.7), OLIVA)
	end,
	Mitragliere = function(m, r, c)
		soldato(m, r, c:Lerp(OLIVA, 0.35), OLIVA, -0.5)
		parte(m, r, "Mitragliatrice", Vector3.new(0.45, 0.45, 2.4), CFrame.new(0, 1.7, -1.5), SCURO, nil, Enum.Material.Metal)
		parte(m, r, "Treppiede", Vector3.new(0.2, 1.4, 0.2), CFrame.new(0, 0.8, -2.2), SCURO, nil, Enum.Material.Metal)
		parte(m, r, "Sacchi", Vector3.new(2.6, 0.8, 0.8), CFrame.new(0, 0.4, -2.6), Color3.fromRGB(176, 158, 110), nil, Enum.Material.Fabric)
	end,
	CarroArmato = function(m, r, c)
		local scafo = OLIVA:Lerp(c, 0.35)
		parte(m, r, "Scafo", Vector3.new(3.4, 1.2, 4.4), CFrame.new(0, 1.0, 0), scafo, nil, Enum.Material.Metal)
		parte(m, r, "CingoloDx", Vector3.new(0.8, 1.2, 4.6), CFrame.new(1.9, 0.6, 0), SCURO)
		parte(m, r, "CingoloSx", Vector3.new(0.8, 1.2, 4.6), CFrame.new(-1.9, 0.6, 0), SCURO)
		parte(m, r, "Torretta", Vector3.new(2.2, 0.9, 2.2), CFrame.new(0, 2.05, 0.3), scafo, nil, Enum.Material.Metal)
		parte(m, r, "Cannone", Vector3.new(0.35, 0.35, 2.8), CFrame.new(0, 2.1, -2.0), SCURO, nil, Enum.Material.Metal)
		parte(m, r, "Bandiera", Vector3.new(0.1, 0.6, 0.9), CFrame.new(0.8, 2.9, 0.9), c)
	end,
}

local function barraVita(radice, colore, altezza)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Vita"
	gui.Size = UDim2.fromOffset(56, 8)
	gui.StudsOffset = Vector3.new(0, altezza, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	local sfondo = Instance.new("Frame")
	sfondo.Size = UDim2.fromScale(1, 1)
	sfondo.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	sfondo.BorderSizePixel = 0
	sfondo.Parent = gui
	local riempimento = Instance.new("Frame")
	riempimento.Name = "Riempimento"
	riempimento.Size = UDim2.fromScale(1, 1)
	riempimento.BackgroundColor3 = colore
	riempimento.BorderSizePixel = 0
	riempimento.Parent = sfondo
	gui.Parent = radice
end

-- Crea il modello di una truppa. cframe è il punto a terra dove sta la truppa.
function Modelli.crea(tipo, squadra, cframe)
	local modello = Instance.new("Model")
	modello.Name = tipo
	local radice = Instance.new("Part")
	radice.Name = "Radice"
	radice.Size = Vector3.new(0.2, 0.2, 0.2)
	radice.Transparency = 1
	radice.Anchored = true
	radice.CanCollide = false
	radice.CanQuery = false
	radice.CanTouch = false
	radice.CFrame = cframe
	radice.Parent = modello
	modello.PrimaryPart = radice

	local colore = COLORI_SQUADRA[squadra]
	local costruttore = COSTRUTTORI[tipo]
	if costruttore then
		costruttore(modello, radice, colore)
	else
		soldato(modello, radice, colore, nil)
	end
	barraVita(radice, colore, tipo == "Cavaliere" and 6 or 5.2)
	modello:SetAttribute("Squadra", squadra)
	return modello
end

function Modelli.aggiornaVita(modello, frazione)
	local gui = modello.PrimaryPart and modello.PrimaryPart:FindFirstChild("Vita")
	if gui then
		gui.Frame.Riempimento.Size = UDim2.fromScale(math.clamp(frazione, 0, 1), 1)
	end
end

return Modelli
