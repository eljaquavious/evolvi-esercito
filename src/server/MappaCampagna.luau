-- Plastico della campagna: l'Europa e il Mediterraneo in Terrain, su un grande tavolo di legno.
-- Costruito una volta all'avvio; i livelli e il sentiero li disegna ogni client per conto suo (stelle diverse).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MappaEuropa = require(ReplicatedStorage.Shared.Config.MappaEuropa)
local Campagna = require(ReplicatedStorage.Shared.Config.Campagna)

local MappaCampagna = {}

local terrain = workspace.Terrain
local CELLA = MappaEuropa.CELLA

-- Dove aspetta il giocatore mentre guarda la mappa: dietro e sotto la telecamera, a sud del plastico.
MappaCampagna.ATTESA = MappaEuropa.CENTRO + Vector3.new(0, 30, -(MappaEuropa.RIGHE / 2) * CELLA - 80)

local function costaVicina(colonna, riga)
	for dx = -1, 1 do
		for dy = -1, 1 do
			if not MappaEuropa.terra(colonna + dx, riga + dy) then
				return true
			end
		end
	end
	return false
end

-- Materiale della superficie per una cella di terra.
local function materialeCima(colonna, riga, altezza)
	local lat, lon = MappaEuropa.coordinate(colonna, riga)
	if altezza >= 4.2 or lat > 59.5 and altezza >= 1.5 then
		return Enum.Material.Snow
	elseif altezza >= 3 then
		return Enum.Material.Rock
	elseif lat < 34.5 or (lat < 37.5 and lon > 30) then
		return Enum.Material.Sand
	elseif costaVicina(colonna, riga) and lat < 44 then
		return Enum.Material.Sand
	elseif lat > 50 then
		return Enum.Material.LeafyGrass
	end
	return Enum.Material.Grass
end

local function tavolo()
	local larghezza = MappaEuropa.COLONNE * CELLA
	local profondita = MappaEuropa.RIGHE * CELLA
	local modello = Instance.new("Model")
	modello.Name = "TavoloMappa"
	local function asse(dimensione, posizione)
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = dimensione
		p.Position = MappaEuropa.CENTRO + posizione
		p.Color = Color3.fromRGB(92, 58, 34)
		p.Material = Enum.Material.Wood
		p.TopSurface = Enum.SurfaceType.Smooth
		p.Parent = modello
		return p
	end
	local bordo, alto = 10, 4
	local fondo = -MappaEuropa.VOXEL_SOTTO * CELLA
	asse(Vector3.new(larghezza + bordo * 2, 4, profondita + bordo * 2), Vector3.new(0, fondo - 2, 0))
	asse(Vector3.new(larghezza + bordo * 2, alto - fondo, bordo), Vector3.new(0, (alto + fondo) / 2, profondita / 2 + bordo / 2))
	asse(Vector3.new(larghezza + bordo * 2, alto - fondo, bordo), Vector3.new(0, (alto + fondo) / 2, -profondita / 2 - bordo / 2))
	asse(Vector3.new(bordo, alto - fondo, profondita), Vector3.new(larghezza / 2 + bordo / 2, (alto + fondo) / 2, 0))
	asse(Vector3.new(bordo, alto - fondo, profondita), Vector3.new(-larghezza / 2 - bordo / 2, (alto + fondo) / 2, 0))
	-- Piattaforma d'attesa del giocatore.
	local attesa = asse(Vector3.new(12, 1, 12), MappaCampagna.ATTESA - MappaEuropa.CENTRO - Vector3.new(0, 3.5, 0))
	attesa.Name = "Attesa"
	attesa.Material = Enum.Material.WoodPlanks
	modello.Parent = workspace
end

-- Il Terrain rende i voxel parziali più alti di quanto dica l'occupazione: la quota vera dei livelli
-- si misura con un raycast e si pubblica in ReplicatedStorage.AltezzeMappa (attributi L1, L2...).
-- Subito dopo WriteVoxels il raycast non colpisce ancora il terreno nuovo, quindi si riprova.
local function misuraAltezze()
	local altezze = Instance.new("Folder")
	altezze.Name = "AltezzeMappa"
	altezze.Parent = ReplicatedStorage
	local parametri = RaycastParams.new()
	parametri.FilterType = Enum.RaycastFilterType.Include
	parametri.FilterDescendantsInstances = { terrain }
	parametri.IgnoreWater = true
	for _ = 1, 30 do
		task.wait(0.5)
		local mancanti = 0
		for numero, battaglia in ipairs(Campagna.Battaglie) do
			local chiave = "L" .. numero
			if not altezze:GetAttribute(chiave) then
				local punto = MappaEuropa.posizione(battaglia.lat, battaglia.lon)
				local colpo = workspace:Raycast(Vector3.new(punto.X, 100, punto.Z), Vector3.new(0, -200, 0), parametri)
				if colpo then
					altezze:SetAttribute(chiave, colpo.Position.Y)
				else
					mancanti += 1
				end
			end
		end
		if mancanti == 0 then
			return
		end
	end
	warn("[MappaCampagna] quota di alcuni livelli non misurata: uso la stima")
end

function MappaCampagna.costruisci()
	local nx, nz = MappaEuropa.COLONNE, MappaEuropa.RIGHE
	local ny = MappaEuropa.VOXEL_SOTTO + MappaEuropa.VOXEL_SOPRA
	local materiali, occupazione = {}, {}
	for x = 1, nx do
		materiali[x], occupazione[x] = {}, {}
		for y = 1, ny do
			materiali[x][y], occupazione[x][y] = {}, {}
		end
	end
	-- Indici dei voxel: x cresce con la X del mondo (verso ovest), z con la Z (verso nord).
	for colonna = 0, nx - 1 do
		local x = nx - colonna
		for riga = 0, nz - 1 do
			local z = nz - riga
			local altezza = MappaEuropa.altezza(colonna, riga)
			local cima = altezza > 0 and materialeCima(colonna, riga, altezza) or nil
			for y = 1, ny do
				local livello = y - MappaEuropa.VOXEL_SOTTO -- 1 = primo voxel sopra il mare
				local materiale, pieno = Enum.Material.Air, 0
				if altezza <= 0 then
					if livello <= 0 then
						materiale, pieno = Enum.Material.Water, 1
					end
				elseif livello <= math.floor(altezza) then
					materiale, pieno = livello == math.floor(altezza) and cima or Enum.Material.Ground, 1
				elseif livello == math.floor(altezza) + 1 then
					-- Ultimo voxel parzialmente pieno: pendii morbidi invece di gradini.
					materiale, pieno = cima, altezza % 1
				end
				if livello <= 0 and altezza > 0 then
					materiale, pieno = Enum.Material.Ground, 1
				end
				materiali[x][y][z] = materiale
				occupazione[x][y][z] = pieno
			end
		end
	end
	local minimo = MappaEuropa.CENTRO - Vector3.new(nx * CELLA / 2, MappaEuropa.VOXEL_SOTTO * CELLA, nz * CELLA / 2)
	local massimo = minimo + Vector3.new(nx * CELLA, ny * CELLA, nz * CELLA)
	local regione = Region3.new(minimo, massimo):ExpandToGrid(CELLA)
	terrain:WriteVoxels(regione, CELLA, materiali, occupazione)
	tavolo()
	task.spawn(misuraAltezze)
end

return MappaCampagna
