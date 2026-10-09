-- Lobby: piazza con il portale della campagna, quello delle ranked e lo shop.
-- Viene costruita all'avvio del server, sopra la Baseplate.

local Lobby = {}

Lobby.SPAWN = Vector3.new(0, 4, 20)

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

local function insegna(parte, testo, colore, faccia)
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
	etichetta.Font = Enum.Font.GothamBlack
	etichetta.Parent = gui
	gui.Parent = parte
end

local function prompt(parte, azione, oggetto, callback)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = azione
	p.ObjectText = oggetto
	p.HoldDuration = 0
	p.MaxActivationDistance = 14
	p.RequiresLineOfSight = false
	p.Triggered:Connect(callback)
	p.Parent = parte
	return p
end

-- Portale: due colonne, un architrave, un velo luminoso e un'insegna. Il fronte guarda verso +Z.
local function portale(genitore, nome, posizione, colore, titolo, azione, callback)
	local modello = Instance.new("Model")
	modello.Name = nome
	local pietra = Color3.fromRGB(92, 88, 96)
	for _, lato in ipairs({ -1, 1 }) do
		blocco(modello, {
			Size = Vector3.new(3, 16, 3),
			Position = posizione + Vector3.new(lato * 7.5, 8, 0),
			Color = pietra,
			Material = Enum.Material.Slate,
		})
	end
	blocco(modello, {
		Size = Vector3.new(18, 3, 3.4),
		Position = posizione + Vector3.new(0, 17.5, 0),
		Color = pietra,
		Material = Enum.Material.Slate,
	})
	local velo = blocco(modello, {
		Name = "Velo",
		Size = Vector3.new(12, 16, 0.6),
		Position = posizione + Vector3.new(0, 8, 0),
		Color = colore,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
	})
	local cartello = blocco(modello, {
		Size = Vector3.new(16, 3.4, 0.4),
		Position = posizione + Vector3.new(0, 21.4, 0),
		Color = Color3.fromRGB(30, 30, 36),
	})
	insegna(cartello, titolo, colore, Enum.NormalId.Back)
	prompt(velo, azione, titolo, callback)
	modello.Parent = genitore
	return modello
end

-- callback: { campagna = function(player), ranked = function(player), shop = function(player) }
function Lobby.costruisci(callback)
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"

	blocco(lobby, {
		Name = "Piazza",
		Size = Vector3.new(130, 1, 110),
		Position = Vector3.new(0, 0.5, -10),
		Color = Color3.fromRGB(150, 142, 132),
		Material = Enum.Material.Cobblestone,
	})
	blocco(lobby, {
		Name = "Centro",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 26, 26),
		CFrame = CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(176, 128, 74),
		Material = Enum.Material.Sandstone,
	})

	-- Titolo del gioco sopra la piazza.
	local titolo = blocco(lobby, {
		Name = "Titolo",
		Size = Vector3.new(44, 9, 1),
		Position = Vector3.new(0, 30, -58),
		Color = Color3.fromRGB(24, 24, 30),
	})
	insegna(titolo, "EVOLVI ESERCITO", Color3.fromRGB(255, 214, 92), Enum.NormalId.Back)

	portale(lobby, "PortaleCampagna", Vector3.new(-24, 1, -40), Color3.fromRGB(80, 170, 255), "CAMPAGNA", "Gioca", callback.campagna)
	portale(lobby, "PortaleRanked", Vector3.new(24, 1, -40), Color3.fromRGB(255, 96, 96), "RANKED", "Entra in coda", callback.ranked)

	-- Bancone dello shop sul lato destro.
	local shop = Instance.new("Model")
	shop.Name = "Shop"
	local base = Vector3.new(50, 1, 6)
	blocco(shop, {
		Size = Vector3.new(4, 4, 16),
		Position = base + Vector3.new(0, 2, 0),
		Color = Color3.fromRGB(122, 82, 46),
		Material = Enum.Material.Wood,
	})
	for _, z in ipairs({ -7, 7 }) do
		blocco(shop, {
			Size = Vector3.new(1, 12, 1),
			Position = base + Vector3.new(2, 6, z),
			Color = Color3.fromRGB(96, 64, 36),
			Material = Enum.Material.Wood,
		})
	end
	blocco(shop, {
		Size = Vector3.new(8, 1, 18),
		CFrame = CFrame.new(base + Vector3.new(1, 12.5, 0)) * CFrame.Angles(0, 0, math.rad(-12)),
		Color = Color3.fromRGB(214, 170, 52),
		Material = Enum.Material.Fabric,
	})
	local cartelloShop = blocco(shop, {
		Size = Vector3.new(0.4, 3, 10),
		Position = base + Vector3.new(-2.2, 9, 0),
		Color = Color3.fromRGB(30, 30, 36),
	})
	insegna(cartelloShop, "SHOP", Color3.fromRGB(255, 214, 92), Enum.NormalId.Left)
	-- Casse in mostra sul bancone.
	for i, colore in ipairs({ Color3.fromRGB(176, 128, 74), Color3.fromRGB(110, 124, 76), Color3.fromRGB(214, 170, 52) }) do
		blocco(shop, {
			Size = Vector3.new(2.4, 2.4, 2.4),
			Position = base + Vector3.new(0, 5.2, (i - 2) * 4.5),
			Color = colore,
			Material = Enum.Material.WoodPlanks,
		})
	end
	local banco = shop:FindFirstChildWhichIsA("BasePart")
	prompt(banco, "Apri lo shop", "SHOP", callback.shop)
	shop.Parent = lobby

	-- Torce agli angoli della piazza.
	for _, posizione in ipairs({ Vector3.new(-60, 1, -60), Vector3.new(60, 1, -60), Vector3.new(-60, 1, 40), Vector3.new(60, 1, 40) }) do
		blocco(lobby, {
			Size = Vector3.new(1.2, 8, 1.2),
			Position = posizione + Vector3.new(0, 4, 0),
			Color = Color3.fromRGB(80, 60, 40),
			Material = Enum.Material.Wood,
		})
		local fiamma = blocco(lobby, {
			Size = Vector3.new(1.6, 1.6, 1.6),
			Position = posizione + Vector3.new(0, 8.6, 0),
			Color = Color3.fromRGB(255, 160, 60),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		local luce = Instance.new("PointLight")
		luce.Color = Color3.fromRGB(255, 170, 90)
		luce.Range = 24
		luce.Brightness = 2
		luce.Parent = fiamma
	end

	lobby.Parent = workspace

	-- Sposta lo spawn della Baseplate dentro la piazza, se esiste.
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation")
	if spawn then
		spawn.Position = Lobby.SPAWN - Vector3.new(0, 3, 0)
	end
	return lobby
end

return Lobby
