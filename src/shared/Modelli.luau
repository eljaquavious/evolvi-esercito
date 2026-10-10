-- Modelli dei soldati e dei reggimenti, costruiti con parti semplici.
-- Condiviso: il server li usa sul campo, il client per i ritratti delle carte.
-- Ogni modello ha una parte "Radice" ancorata a terra; le altre sono saldate alla radice,
-- quindi basta muovere la radice. Il fronte del modello è la direzione -Z.

local TweenService = game:GetService("TweenService")

local Modelli = {}

Modelli.COLORI_SQUADRA = {
	giocatore = Color3.fromRGB(52, 112, 220),
	nemico = Color3.fromRGB(204, 56, 56),
}

local PELLE = Color3.fromRGB(232, 186, 146)
local SCURO = Color3.fromRGB(44, 42, 40)
local CUOIO = Color3.fromRGB(104, 70, 40)
local METALLO = Color3.fromRGB(172, 176, 186)
local LEGNO = Color3.fromRGB(120, 80, 44)
local OLIVA = Color3.fromRGB(88, 100, 58)
local KAKI = Color3.fromRGB(150, 136, 96)

local function nuovaRadice(modello, cframe)
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
	return radice
end

-- Aggiunge una parte saldata a "base", posizionata con offset (in studs già scalati).
local function parte(genitore, base, dimensione, offset, colore, forma, materiale)
	local p = Instance.new("Part")
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
	p.CastShadow = true
	p.CFrame = base.CFrame * offset
	local saldatura = Instance.new("WeldConstraint")
	saldatura.Part0 = base
	saldatura.Part1 = p
	saldatura.Parent = p
	p.Parent = genitore
	return p
end

-- Costruttore di figure in scala: f(dimensione, x, y, z, colore, forma, materiale, rotazione)
local function scalatore(genitore, base, origine, s)
	return function(dimensione, x, y, z, colore, forma, materiale, rotazione)
		local offset = origine * CFrame.new(x * s, y * s, z * s)
		if rotazione then
			offset = offset * rotazione
		end
		return parte(genitore, base, dimensione * s, offset, colore, forma, materiale)
	end
end

-- Corpo umano base: gambe, busto, braccia, testa. altezza sposta tutto in su (per i cavalieri).
local function corpo(p, divisa, pantaloni, altezza)
	local h = altezza or 0
	p(Vector3.new(0.5, 1.4, 0.55), -0.32, 0.7 + h, 0, pantaloni)
	p(Vector3.new(0.5, 1.4, 0.55), 0.32, 0.7 + h, 0, pantaloni)
	p(Vector3.new(1.4, 1.5, 0.75), 0, 2.15 + h, 0, divisa)
	p(Vector3.new(1.45, 0.22, 0.8), 0, 1.5 + h, 0, CUOIO)
	p(Vector3.new(0.42, 1.35, 0.5), -0.93, 2.2 + h, -0.1, divisa)
	p(Vector3.new(0.42, 1.35, 0.5), 0.93, 2.2 + h, -0.1, divisa)
	p(Vector3.new(1, 1, 1), 0, 3.45 + h, 0, PELLE, Enum.PartType.Ball)
end

local FIGURE = {}

function FIGURE.Spadaccino(p, colore)
	corpo(p, colore, SCURO)
	p(Vector3.new(1.5, 0.3, 0.8), 0, 2.95, 0, METALLO, nil, Enum.Material.Metal) -- spalline
	p(Vector3.new(1.1, 0.55, 1.1), 0, 3.85, 0, METALLO, nil, Enum.Material.Metal) -- elmo
	p(Vector3.new(0.18, 0.18, 2.2), 0.95, 1.9, -1.0, METALLO, nil, Enum.Material.Metal) -- spada
	p(Vector3.new(0.6, 0.15, 0.15), 0.95, 1.9, -0.1, CUOIO) -- elsa
	p(Vector3.new(0.25, 1.6, 1.3), -1.2, 2.1, -0.3, colore:Lerp(SCURO, 0.25)) -- scudo
	p(Vector3.new(0.27, 0.5, 0.5), -1.2, 2.1, -0.3, METALLO, nil, Enum.Material.Metal) -- umbone
end

function FIGURE.Arciere(p, colore)
	corpo(p, colore:Lerp(Color3.fromRGB(70, 110, 60), 0.4), CUOIO)
	p(Vector3.new(1.15, 0.6, 1.15), 0, 3.8, 0.05, colore:Lerp(SCURO, 0.35), nil, Enum.Material.Fabric) -- cappuccio
	p(Vector3.new(0.15, 2.8, 0.2), -1.15, 2.4, -0.5, LEGNO, nil, Enum.Material.Wood) -- arco
	p(Vector3.new(0.05, 2.6, 0.05), -1.0, 2.4, -0.5, Color3.fromRGB(230, 230, 220)) -- corda
	p(Vector3.new(0.45, 1.3, 0.45), 0.45, 2.5, 0.6, CUOIO, nil, nil, CFrame.Angles(0, 0, math.rad(-20))) -- faretra
end

function FIGURE.Cavaliere(p, colore)
	local manto = Color3.fromRGB(96, 62, 36)
	p(Vector3.new(1.3, 1.25, 3.0), 0, 2.0, 0, manto) -- cavallo
	p(Vector3.new(0.7, 1.3, 0.8), 0, 2.9, -1.5, manto, nil, nil, CFrame.Angles(math.rad(-30), 0, 0)) -- collo
	p(Vector3.new(0.65, 0.7, 1.2), 0, 3.4, -2.05, manto) -- testa
	p(Vector3.new(1.4, 0.9, 1.6), 0, 2.4, 0.2, colore, nil, Enum.Material.Fabric) -- gualdrappa
	for _, x in ipairs({ -0.45, 0.45 }) do
		for _, z in ipairs({ -1.1, 1.1 }) do
			p(Vector3.new(0.3, 1.4, 0.3), x, 0.7, z, manto:Lerp(SCURO, 0.4))
		end
	end
	p(Vector3.new(0.2, 0.9, 0.2), 0, 2.2, 1.6, SCURO, nil, nil, CFrame.Angles(math.rad(25), 0, 0)) -- coda
	-- cavaliere seduto
	p(Vector3.new(1.3, 1.3, 0.75), 0, 3.4, 0.2, colore)
	p(Vector3.new(0.4, 1.2, 0.45), -0.85, 3.4, 0.1, colore)
	p(Vector3.new(0.4, 1.2, 0.45), 0.85, 3.4, 0.1, colore)
	p(Vector3.new(0.95, 0.95, 0.95), 0, 4.55, 0.2, PELLE, Enum.PartType.Ball)
	p(Vector3.new(1.05, 0.8, 1.05), 0, 4.75, 0.2, METALLO, nil, Enum.Material.Metal) -- elmo
	p(Vector3.new(0.18, 0.18, 4.2), 0.85, 3.6, -1.3, LEGNO, nil, Enum.Material.Wood) -- lancia
	p(Vector3.new(0.3, 0.3, 0.5), 0.85, 3.6, -3.5, METALLO, nil, Enum.Material.Metal) -- punta
end

function FIGURE.Fante(p, colore)
	local divisa = OLIVA:Lerp(colore, 0.3)
	corpo(p, divisa, OLIVA:Lerp(SCURO, 0.3))
	p(Vector3.new(1.25, 0.45, 1.25), 0, 3.9, 0, OLIVA:Lerp(SCURO, 0.2), nil, Enum.Material.Metal) -- elmetto
	p(Vector3.new(0.16, 0.2, 2.5), 0.85, 2.3, -0.9, SCURO, nil, Enum.Material.Metal) -- fucile
	p(Vector3.new(0.2, 0.35, 0.9), 0.85, 2.2, 0.15, LEGNO, nil, Enum.Material.Wood) -- calcio
	p(Vector3.new(1.0, 1.1, 0.45), 0, 2.3, 0.6, KAKI, nil, Enum.Material.Fabric) -- zaino
	p(Vector3.new(1.5, 0.25, 0.25), 0, 1.6, -0.45, colore) -- fascia squadra
end

function FIGURE.Mitragliere(p, colore)
	local divisa = OLIVA:Lerp(colore, 0.3)
	-- soldato in ginocchio dietro la mitragliatrice
	p(Vector3.new(1.2, 0.7, 1.4), 0, 0.35, 0.3, OLIVA:Lerp(SCURO, 0.3))
	p(Vector3.new(1.4, 1.5, 0.75), 0, 1.45, 0.3, divisa)
	p(Vector3.new(1.45, 0.25, 0.25), 0, 1.0, -0.1, colore)
	p(Vector3.new(0.42, 1.2, 0.5), -0.9, 1.4, -0.2, divisa, nil, nil, CFrame.Angles(math.rad(50), 0, 0))
	p(Vector3.new(0.42, 1.2, 0.5), 0.9, 1.4, -0.2, divisa, nil, nil, CFrame.Angles(math.rad(50), 0, 0))
	p(Vector3.new(1, 1, 1), 0, 2.7, 0.3, PELLE, Enum.PartType.Ball)
	p(Vector3.new(1.25, 0.45, 1.25), 0, 3.15, 0.3, OLIVA:Lerp(SCURO, 0.2), nil, Enum.Material.Metal)
	p(Vector3.new(0.5, 0.5, 1.6), 0, 1.2, -1.4, SCURO, nil, Enum.Material.Metal) -- corpo arma
	p(Vector3.new(0.22, 0.22, 1.4), 0, 1.25, -2.8, SCURO, nil, Enum.Material.Metal) -- canna
	p(Vector3.new(0.15, 1.1, 0.15), 0.4, 0.55, -1.6, SCURO, nil, nil, CFrame.Angles(0, 0, math.rad(20)))
	p(Vector3.new(0.15, 1.1, 0.15), -0.4, 0.55, -1.6, SCURO, nil, nil, CFrame.Angles(0, 0, math.rad(-20)))
	p(Vector3.new(2.8, 0.7, 0.8), 0, 0.35, -2.4, Color3.fromRGB(176, 158, 110), nil, Enum.Material.Fabric) -- sacchi
end

function FIGURE.CarroArmato(p, colore)
	local scafo = OLIVA:Lerp(colore, 0.25)
	p(Vector3.new(3.6, 1.3, 5.2), 0, 1.15, 0, scafo, nil, Enum.Material.Metal)
	p(Vector3.new(3.2, 0.8, 1.2), 0, 1.4, -2.7, scafo, nil, Enum.Material.Metal, CFrame.Angles(math.rad(-30), 0, 0))
	for _, x in ipairs({ -2.05, 2.05 }) do
		p(Vector3.new(0.9, 1.3, 5.6), x, 0.65, 0, SCURO, nil, Enum.Material.Metal)
		for i = -2, 2 do
			p(Vector3.new(0.95, 0.9, 0.9), x, 0.5, i * 1.1, Color3.fromRGB(70, 70, 70), Enum.PartType.Cylinder, Enum.Material.Metal)
		end
	end
	p(Vector3.new(2.4, 1.0, 2.6), 0, 2.3, 0.4, scafo, nil, Enum.Material.Metal) -- torretta
	p(Vector3.new(0.9, 0.35, 0.9), 0.5, 2.95, 0.8, scafo:Lerp(SCURO, 0.2), Enum.PartType.Cylinder, Enum.Material.Metal, CFrame.Angles(0, 0, math.rad(90)))
	p(Vector3.new(0.38, 0.38, 3.4), 0, 2.3, -2.4, SCURO, nil, Enum.Material.Metal) -- cannone
	p(Vector3.new(0.55, 0.55, 0.6), 0, 2.3, -4.1, SCURO, nil, Enum.Material.Metal)
	p(Vector3.new(1.6, 0.6, 0.1), 0, 1.4, 2.65, colore) -- insegna squadra
	p(Vector3.new(0.08, 0.7, 1.0), 1.0, 3.3, 1.2, colore) -- bandierina
end

-- Formazioni: posizioni dei soldati nel reggimento (in studs, la casella è larga 10).
local FORMAZIONI = {
	[1] = { Vector3.new(0, 0, 0) },
	[3] = { Vector3.new(-3, 0, 0), Vector3.new(0, 0, 0.4), Vector3.new(3, 0, 0) },
	[5] = { Vector3.new(-3, 0, -1.6), Vector3.new(0, 0, -1.6), Vector3.new(3, 0, -1.6), Vector3.new(-1.5, 0, 1.8), Vector3.new(1.5, 0, 1.8) },
}
local function formazione(numero)
	if FORMAZIONI[numero] then
		return FORMAZIONI[numero]
	end
	local lista = {}
	local perRiga = math.ceil(numero / 2)
	for i = 0, numero - 1 do
		local colonna, riga = i % perRiga, math.floor(i / perRiga)
		table.insert(lista, Vector3.new((colonna - (perRiga - 1) / 2) * 2.1, 0, (riga - 0.5) * 2.6 + (colonna % 2) * 0.3))
	end
	return lista
end

-- Scala dei soldati nel reggimento, per farli stare nella casella.
local SCALE = {
	Spadaccino = 0.82,
	Arciere = 0.82,
	Cavaliere = 0.8,
	Fante = 0.82,
	Mitragliere = 0.85,
	CarroArmato = 1.4,
}
-- Le formazioni sono pensate per la scala 0.62: con soldati più grandi si allargano in proporzione.
local ALLARGAMENTO = 1.25

local function figura(genitore, base, tipo, colore, origine, s)
	local p = scalatore(genitore, base, origine, s)
	local costruttore = FIGURE[tipo] or FIGURE.Spadaccino
	costruttore(p, colore)
end

-- Un solo soldato in un modello, per i ritratti delle carte.
function Modelli.soldato(tipo, squadra)
	local modello = Instance.new("Model")
	modello.Name = tipo
	local radice = nuovaRadice(modello, CFrame.new())
	figura(modello, radice, tipo, Modelli.COLORI_SQUADRA[squadra or "giocatore"], CFrame.new(), 1)
	return modello
end

local function barraVita(radice, colore, numero)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Vita"
	gui.Size = UDim2.fromOffset(70, 16)
	gui.StudsOffset = Vector3.new(0, 7, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 250

	local sfondo = Instance.new("Frame")
	sfondo.Name = "Sfondo"
	sfondo.AnchorPoint = Vector2.new(0, 0.5)
	sfondo.Position = UDim2.new(0, 18, 0.5, 0)
	sfondo.Size = UDim2.new(1, -18, 0, 7)
	sfondo.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
	sfondo.BorderSizePixel = 0
	sfondo.Parent = gui
	Instance.new("UICorner", sfondo).CornerRadius = UDim.new(1, 0)

	local riempimento = Instance.new("Frame")
	riempimento.Name = "Riempimento"
	riempimento.Size = UDim2.fromScale(1, 1)
	riempimento.BackgroundColor3 = colore
	riempimento.BorderSizePixel = 0
	riempimento.Parent = sfondo
	Instance.new("UICorner", riempimento).CornerRadius = UDim.new(1, 0)

	local conteggio = Instance.new("TextLabel")
	conteggio.Name = "Conteggio"
	conteggio.Size = UDim2.new(0, 16, 1, 0)
	conteggio.BackgroundColor3 = colore
	conteggio.BorderSizePixel = 0
	conteggio.Text = tostring(numero)
	conteggio.TextColor3 = Color3.new(1, 1, 1)
	conteggio.TextScaled = true
	conteggio.Font = Enum.Font.GothamBlack
	conteggio.Parent = gui
	Instance.new("UICorner", conteggio).CornerRadius = UDim.new(0, 4)

	gui.Parent = radice
end

-- Un reggimento intero: i soldati in formazione attorno al punto a terra "cframe".
function Modelli.reggimento(def, squadra, cframe)
	local modello = Instance.new("Model")
	modello.Name = def.id
	local radice = nuovaRadice(modello, cframe)
	local colore = Modelli.COLORI_SQUADRA[squadra]
	local scala = SCALE[def.id] or 0.82
	for i, posizione in ipairs(formazione(def.soldati)) do
		local soldato = Instance.new("Model")
		soldato.Name = "Soldato" .. i
		local origine = CFrame.new(posizione * ALLARGAMENTO) * CFrame.Angles(0, math.rad((i * 37) % 11 - 5), 0)
		figura(soldato, radice, def.id, colore, origine, scala)
		soldato.Parent = modello
	end
	barraVita(radice, colore, def.soldati)
	modello:SetAttribute("Squadra", squadra)
	modello:SetAttribute("Soldati", def.soldati)
	return modello
end

local function abbatti(soldato)
	for _, p in ipairs(soldato:GetDescendants()) do
		if p:IsA("BasePart") then
			local saldatura = p:FindFirstChildWhichIsA("WeldConstraint")
			if saldatura then
				saldatura:Destroy()
			end
			p.Anchored = true
			TweenService:Create(p, TweenInfo.new(0.5), {
				CFrame = p.CFrame * CFrame.new(0, -0.6, 0) * CFrame.Angles(math.rad(70), 0, 0),
				Transparency = 1,
			}):Play()
		end
	end
	task.delay(0.6, function()
		soldato:Destroy()
	end)
end

-- Aggiorna barra e soldati visibili in base alla vita rimasta (0-1).
function Modelli.aggiornaVita(modello, frazione)
	frazione = math.clamp(frazione, 0, 1)
	local radice = modello.PrimaryPart
	local gui = radice and radice:FindFirstChild("Vita")
	local totale = modello:GetAttribute("Soldati") or 1
	local vivi = frazione <= 0 and 0 or math.max(1, math.ceil(totale * frazione))
	if gui then
		gui.Sfondo.Riempimento.Size = UDim2.fromScale(frazione, 1)
		gui.Conteggio.Text = tostring(vivi)
	end
	-- Rimuove i soldati in eccesso partendo dal fondo della formazione.
	for i = totale, vivi + 1, -1 do
		local soldato = modello:FindFirstChild("Soldato" .. i)
		if soldato and not soldato:GetAttribute("Caduto") then
			soldato:SetAttribute("Caduto", true)
			abbatti(soldato)
		end
	end
end

return Modelli
