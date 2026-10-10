-- Lobby: piazza del castello con il portale della campagna, quello delle ranked e lo shop.
-- Viene costruita all'avvio del server.

local Lobby = {}

Lobby.SPAWN = Vector3.new(0, 4, 26)

local terrain = workspace.Terrain

local PIETRA = Color3.fromRGB(150, 142, 132)
local PIETRA_SCURA = Color3.fromRGB(104, 98, 92)
local LEGNO = Color3.fromRGB(110, 74, 42)
local ORO = Color3.fromRGB(255, 204, 72)

local function blocco(genitore, proprieta)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(proprieta) do
		p[k] = v
	end
	p.Parent = genitore
	return p
end

local function cilindro(genitore, altezza, diametro, posizione, colore, materiale)
	return blocco(genitore, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(altezza, diametro, diametro),
		CFrame = CFrame.new(posizione) * CFrame.Angles(0, 0, math.rad(90)),
		Color = colore,
		Material = materiale,
	})
end

local function insegna(parte, testo, colore, faccia, font)
	local gui = Instance.new("SurfaceGui")
	gui.Face = faccia or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	local etichetta = Instance.new("TextLabel")
	etichetta.Size = UDim2.fromScale(1, 1)
	etichetta.BackgroundTransparency = 1
	etichetta.Text = testo
	etichetta.TextColor3 = colore
	etichetta.TextScaled = true
	etichetta.Font = font or Enum.Font.LuckiestGuy
	etichetta.Parent = gui
	local bordo = Instance.new("UIStroke")
	bordo.Thickness = 3
	bordo.Color = Color3.fromRGB(30, 20, 10)
	bordo.Parent = etichetta
	gui.Parent = parte
end

local function prompt(parte, azione, oggetto, callback)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = azione
	p.ObjectText = oggetto
	p.HoldDuration = 0
	p.MaxActivationDistance = 16
	p.RequiresLineOfSight = false
	p.Triggered:Connect(callback)
	p.Parent = parte
	return p
end

local function torcia(genitore, posizione)
	blocco(genitore, { Size = Vector3.new(0.8, 2.4, 0.8), Position = posizione, Color = LEGNO, Material = Enum.Material.Wood })
	local fiamma = blocco(genitore, {
		Size = Vector3.new(0.6, 0.6, 0.6),
		Position = posizione + Vector3.new(0, 1.5, 0),
		Transparency = 1,
		CanCollide = false,
	})
	local fuoco = Instance.new("Fire")
	fuoco.Size = 3
	fuoco.Heat = 6
	fuoco.Parent = fiamma
	local luce = Instance.new("PointLight")
	luce.Color = Color3.fromRGB(255, 170, 90)
	luce.Range = 18
	luce.Brightness = 1.6
	luce.Shadows = true
	luce.Parent = fiamma
end

local function stendardo(genitore, posizione, colore)
	blocco(genitore, { Size = Vector3.new(5, 9, 0.2), Position = posizione, Color = colore, Material = Enum.Material.Fabric })
	blocco(genitore, { Size = Vector3.new(5.6, 0.4, 0.4), Position = posizione + Vector3.new(0, 4.7, 0), Color = LEGNO, Material = Enum.Material.Wood })
	blocco(genitore, { Size = Vector3.new(2, 2, 0.25), Position = posizione + Vector3.new(0, 1, 0), Color = ORO, Material = Enum.Material.Fabric })
end

-- Tratto di mura con merli, centrato in "posizione" e lungo "lunghezza" sull'asse X.
local function mura(genitore, posizione, lunghezza)
	blocco(genitore, {
		Size = Vector3.new(lunghezza, 22, 6),
		Position = posizione + Vector3.new(0, 11, 0),
		Color = PIETRA,
		Material = Enum.Material.Cobblestone,
	})
	local numero = math.floor(lunghezza / 4)
	for i = 0, numero - 1, 2 do
		blocco(genitore, {
			Size = Vector3.new(2.4, 3, 6.4),
			Position = posizione + Vector3.new(-lunghezza / 2 + 1.2 + i * 4, 23.5, 0),
			Color = PIETRA,
			Material = Enum.Material.Cobblestone,
		})
	end
end

local function torre(genitore, posizione)
	cilindro(genitore, 32, 14, posizione + Vector3.new(0, 16, 0), PIETRA_SCURA, Enum.Material.Cobblestone)
	cilindro(genitore, 2, 16, posizione + Vector3.new(0, 33, 0), PIETRA, Enum.Material.Cobblestone)
	blocco(genitore, {
		Size = Vector3.new(11, 9, 11),
		CFrame = CFrame.new(posizione + Vector3.new(0, 38, 0)) * CFrame.Angles(0, math.rad(45), 0),
		Color = Color3.fromRGB(150, 52, 44),
		Material = Enum.Material.Slate,
	})
end

local function albero(genitore, posizione, scala)
	cilindro(genitore, 7 * scala, 1.3 * scala, posizione + Vector3.new(0, 3.5 * scala, 0), LEGNO, Enum.Material.Wood)
	for _, offset in ipairs({ Vector3.new(0, 8, 0), Vector3.new(2, 6.8, 1), Vector3.new(-1.8, 7, -1.2) }) do
		blocco(genitore, {
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 5.5 * scala,
			Position = posizione + offset * scala,
			Color = Color3.fromRGB(62, 128, 56),
			Material = Enum.Material.Grass,
		})
	end
end

-- Portale: arco in pietra con velo luminoso e insegna. Il fronte guarda verso +Z.
local function portale(genitore, nome, posizione, colore, titolo, azione, callback)
	local modello = Instance.new("Model")
	modello.Name = nome
	for _, lato in ipairs({ -1, 1 }) do
		blocco(modello, { Size = Vector3.new(3.5, 18, 3.5), Position = posizione + Vector3.new(lato * 7.5, 9, 0), Color = PIETRA_SCURA, Material = Enum.Material.Slate })
		blocco(modello, { Size = Vector3.new(4.5, 1.5, 4.5), Position = posizione + Vector3.new(lato * 7.5, 0.75, 0), Color = PIETRA, Material = Enum.Material.Slate })
		torcia(modello, posizione + Vector3.new(lato * 10.5, 9, 1.5))
	end
	blocco(modello, { Size = Vector3.new(19, 3, 4), Position = posizione + Vector3.new(0, 19.5, 0), Color = PIETRA_SCURA, Material = Enum.Material.Slate })
	local velo = blocco(modello, {
		Name = "Velo",
		Size = Vector3.new(11.5, 17, 0.6),
		Position = posizione + Vector3.new(0, 9.5, 0),
		Color = colore,
		Material = Enum.Material.ForceField,
		CanCollide = false,
	})
	local luce = Instance.new("PointLight")
	luce.Color = colore
	luce.Range = 20
	luce.Brightness = 2
	luce.Parent = velo
	local cartello = blocco(modello, {
		Size = Vector3.new(17, 3.6, 0.5),
		Position = posizione + Vector3.new(0, 23.4, 0.4),
		Color = Color3.fromRGB(40, 30, 24),
		Material = Enum.Material.Wood,
	})
	insegna(cartello, titolo, colore, Enum.NormalId.Back)
	prompt(velo, azione, titolo, callback)
	modello.Parent = genitore
	return modello
end

local function fontana(genitore, centro)
	cilindro(genitore, 1.6, 22, centro + Vector3.new(0, 0.8, 0), PIETRA, Enum.Material.Slate)
	cilindro(genitore, 1.2, 19, centro + Vector3.new(0, 1.1, 0), Color3.fromRGB(70, 140, 200), Enum.Material.Glass).Transparency = 0.3
	cilindro(genitore, 6, 3, centro + Vector3.new(0, 4, 0), PIETRA_SCURA, Enum.Material.Slate)
	cilindro(genitore, 1, 8, centro + Vector3.new(0, 7.5, 0), PIETRA, Enum.Material.Slate)
	local acqua = blocco(genitore, { Size = Vector3.new(1, 1, 1), Position = centro + Vector3.new(0, 8.2, 0), Transparency = 1, CanCollide = false })
	local getto = Instance.new("ParticleEmitter")
	getto.Color = ColorSequence.new(Color3.fromRGB(180, 220, 255))
	getto.Size = NumberSequence.new(0.5, 0.1)
	getto.Transparency = NumberSequence.new(0.3, 1)
	getto.Lifetime = NumberRange.new(0.8, 1.2)
	getto.Rate = 60
	getto.Speed = NumberRange.new(8, 10)
	getto.SpreadAngle = Vector2.new(15, 15)
	getto.Acceleration = Vector3.new(0, -25, 0)
	getto.Parent = acqua
end

-- callback: { campagna = function(player), ranked = function(player), shop = function(player) }
function Lobby.costruisci(callback)
	-- Prato intorno al castello, al posto della Baseplate.
	terrain:FillBlock(CFrame.new(0, -8, 0), Vector3.new(700, 16, 700), Enum.Material.Grass)
	-- Sotto la piazza terra battuta: l'erba alta spunterebbe dal pavimento.
	terrain:FillCylinder(CFrame.new(0, -8, -6), 16, 68, Enum.Material.Ground)
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Transparency = 1
		baseplate.CanCollide = false
		for _, figlio in ipairs(baseplate:GetChildren()) do
			if figlio:IsA("Texture") or figlio:IsA("Decal") then
				figlio:Destroy()
			end
		end
	end

	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"

	cilindro(lobby, 1, 130, Vector3.new(0, 0.3, -6), PIETRA, Enum.Material.Cobblestone)
	cilindro(lobby, 1.1, 30, Vector3.new(0, 0.35, 0), Color3.fromRGB(176, 128, 74), Enum.Material.Sandstone)
	fontana(lobby, Vector3.new(0, 0.6, 0))

	-- Mura e torri dietro i portali.
	mura(lobby, Vector3.new(0, 0, -70), 120)
	torre(lobby, Vector3.new(-62, 0, -70))
	torre(lobby, Vector3.new(62, 0, -70))
	for _, x in ipairs({ -40, -14, 14, 40 }) do
		stendardo(lobby, Vector3.new(x, 13, -66.8), x < 0 and Color3.fromRGB(52, 100, 200) or Color3.fromRGB(180, 44, 44))
	end
	local titolo = blocco(lobby, {
		Name = "Titolo",
		Size = Vector3.new(50, 8, 1),
		Position = Vector3.new(0, 31, -68),
		Transparency = 1,
		CanCollide = false,
	})
	insegna(titolo, "EVOLVE YOUR ARMY", ORO, Enum.NormalId.Back)

	portale(lobby, "PortaleCampagna", Vector3.new(-24, 0.8, -42), Color3.fromRGB(90, 170, 255), "CAMPAIGN", "Play", callback.campagna)
	portale(lobby, "PortaleRanked", Vector3.new(24, 0.8, -42), Color3.fromRGB(255, 96, 96), "RANKED", "Join queue", callback.ranked)

	-- Bancarella dello shop sul lato destro, rivolta verso il centro.
	local shop = Instance.new("Model")
	shop.Name = "Shop"
	local base = Vector3.new(50, 0.8, 8)
	local banco = blocco(shop, { Size = Vector3.new(4, 4, 18), Position = base + Vector3.new(0, 2, 0), Color = LEGNO, Material = Enum.Material.WoodPlanks })
	for _, z in ipairs({ -8.5, 8.5 }) do
		blocco(shop, { Size = Vector3.new(1, 13, 1), Position = base + Vector3.new(-1.5, 6.5, z), Color = LEGNO, Material = Enum.Material.Wood })
		blocco(shop, { Size = Vector3.new(1, 13, 1), Position = base + Vector3.new(4, 6.5, z), Color = LEGNO, Material = Enum.Material.Wood })
	end
	for i = 0, 5 do
		blocco(shop, {
			Size = Vector3.new(8, 0.5, 3.2),
			CFrame = CFrame.new(base + Vector3.new(1.3, 13.2, -8 + i * 3.2)) * CFrame.Angles(0, 0, math.rad(-14)),
			Color = i % 2 == 0 and Color3.fromRGB(200, 50, 50) or Color3.fromRGB(240, 230, 210),
			Material = Enum.Material.Fabric,
		})
	end
	local cartelloShop = blocco(shop, { Size = Vector3.new(0.5, 3.4, 11), Position = base + Vector3.new(-2.4, 10, 0), Color = Color3.fromRGB(40, 30, 24), Material = Enum.Material.Wood })
	insegna(cartelloShop, "SHOP", ORO, Enum.NormalId.Left)
	for i, colore in ipairs({ Color3.fromRGB(176, 128, 74), Color3.fromRGB(110, 124, 76), Color3.fromRGB(214, 170, 52) }) do
		local cassa = blocco(shop, { Size = Vector3.new(2.6, 2.2, 2.6), Position = base + Vector3.new(0, 5.1, (i - 2) * 5), Color = colore, Material = Enum.Material.WoodPlanks })
		blocco(shop, { Size = Vector3.new(2.7, 0.4, 2.7), Position = cassa.Position + Vector3.new(0, 0.3, 0), Color = Color3.fromRGB(60, 50, 40), Material = Enum.Material.Metal })
	end
	prompt(banco, "Open shop", "SHOP", callback.shop)
	shop.Parent = lobby

	-- Alberi e torce intorno alla piazza.
	local rng = Random.new(42)
	for i = 1, 26 do
		local angolo = (i / 26) * math.pi * 2
		local raggio = rng:NextNumber(78, 110)
		local pos = Vector3.new(math.cos(angolo) * raggio, 0, math.sin(angolo) * raggio - 6)
		if pos.Z > -60 then
			albero(lobby, pos, rng:NextNumber(1, 1.6))
		end
	end
	for _, posizione in ipairs({ Vector3.new(-44, 1.6, 30), Vector3.new(44, 1.6, 30), Vector3.new(-56, 1.6, -10), Vector3.new(56, 1.6, -26) }) do
		torcia(lobby, posizione)
	end

	-- Le parti sono costruite a partire da y = 0: si alza tutto fino alla superficie vera dell'erba.
	local parametri = RaycastParams.new()
	parametri.FilterType = Enum.RaycastFilterType.Include
	parametri.FilterDescendantsInstances = { terrain }
	local colpo = workspace:Raycast(Vector3.new(0, 200, -6), Vector3.new(0, -400, 0), parametri)
	local alzo = colpo and colpo.Position.Y or 2 -- 2: dove finisce la superficie se il terreno non è ancora colpibile
	lobby:PivotTo(lobby:GetPivot() + Vector3.new(0, alzo, 0))
	Lobby.SPAWN += Vector3.new(0, alzo, 0)
	lobby.Parent = workspace

	-- Sposta lo spawn della Baseplate dentro la piazza e lo rende invisibile.
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation")
	if spawn then
		spawn.Position = Lobby.SPAWN - Vector3.new(0, 3, 0)
		spawn.Transparency = 1
		spawn.CanCollide = false
		for _, figlio in ipairs(spawn:GetChildren()) do
			if figlio:IsA("Decal") then
				figlio:Destroy()
			end
		end
	end
	return lobby
end

return Lobby
