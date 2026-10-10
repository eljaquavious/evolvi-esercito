-- Plastico della campagna: l'Europa e il Mediterraneo in Terrain (quote e costa vere), su un grande tavolo
-- di legno, con il sentiero tra le battaglie tracciato sul terreno. Costruito una volta all'avvio;
-- i livelli e le tratte per mare li disegna ogni client per conto suo (stelle diverse).

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

-- Materiale della superficie per una cella di terra; h in studs (le montagne vere sono sopra i 15).
local function materialeCima(colonna, riga, h)
	local lat, lon = MappaEuropa.coordinate(colonna, riga)
	local variazione = math.noise(colonna * 0.11, riga * 0.11, 3.7)
	if h >= 22 or (lat > 59 and h >= 9) then
		return Enum.Material.Snow
	elseif h >= 16 then
		return Enum.Material.Rock
	elseif lat < 34.5 or (lat < 37.5 and lon > 30) or (lat < 38.5 and lon > 38) then
		return h >= 9 and Enum.Material.Sandstone or Enum.Material.Sand
	elseif costaVicina(colonna, riga) and lat < 44 then
		return Enum.Material.Sand
	elseif h >= 11 then
		return variazione > 0.1 and Enum.Material.Ground or Enum.Material.LeafyGrass
	elseif lat > 52 then
		return Enum.Material.LeafyGrass
	end
	return variazione > 0.3 and Enum.Material.LeafyGrass or Enum.Material.Grass
end

-- Celle di terra dove passa il sentiero tra due battaglie della stessa epoca. Largo 3 celle e senza
-- passi in diagonale: una riga di voxel sottile, nel Terrain, si vede a macchie e non come una strada.
local function celleSentiero()
	local celle = {}
	local function segna(colonna, riga)
		for dx = -1, 1 do
			for dy = -1, 1 do
				if math.abs(dx) + math.abs(dy) <= 1 and MappaEuropa.terra(colonna + dx, riga + dy) then
					celle[(colonna + dx) * 1000 + riga + dy] = true
				end
			end
		end
	end
	for _, sentiero in ipairs(MappaEuropa.Sentieri) do
		for i = 1, #sentiero, 2 do
			local colonna, riga = sentiero[i], sentiero[i + 1]
			segna(colonna, riga)
			local prossimaColonna = sentiero[i + 2]
			if prossimaColonna and prossimaColonna ~= colonna and sentiero[i + 3] ~= riga then
				segna(prossimaColonna, riga) -- passo diagonale: riempie l'angolo
			end
		end
	end
	return celle
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
	local sotto = MappaEuropa.VOXEL_SOTTO
	local ny = sotto + MappaEuropa.VOXEL_SOPRA
	local sentiero = celleSentiero()
	-- A blocchi di colonne: meno memoria e il server non si blocca.
	local lato = 40
	for bx = 0, math.ceil(nx / lato) - 1 do
		for bz = 0, math.ceil(nz / lato) - 1 do
			local lx, lz = math.min(lato, nx - bx * lato), math.min(lato, nz - bz * lato)
			local materiali, occupazione = {}, {}
			for i = 1, lx do
				materiali[i], occupazione[i] = {}, {}
				for j = 1, ny do
					materiali[i][j], occupazione[i][j] = {}, {}
				end
			end
			-- Indici dei voxel: x cresce con la X del mondo (verso ovest), z con la Z (verso nord).
			for i = 1, lx do
				local colonna = nx - (bx * lato + i)
				for k = 1, lz do
					local riga = nz - (bz * lato + k)
					local h = MappaEuropa.altezzaStuds(colonna, riga)
					local cima
					if h > 0 then
						cima = sentiero[colonna * 1000 + riga] and Enum.Material.Ground or materialeCima(colonna, riga, h)
					end
					local fondale = -MappaEuropa.profondita(colonna, riga)
					for j = 1, ny do
						local y0 = (j - 1 - sotto) * CELLA -- base del voxel
						local materiale, pieno = Enum.Material.Air, 0
						if h > 0 then
							if y0 + CELLA <= h then
								materiale, pieno = h - (y0 + CELLA) < CELLA and cima or Enum.Material.Ground, 1
							elseif y0 < h then
								materiale, pieno = cima, (h - y0) / CELLA
							end
						elseif y0 + CELLA <= fondale then
							materiale, pieno = Enum.Material.Sand, 1
						elseif y0 < fondale then
							materiale, pieno = Enum.Material.Sand, (fondale - y0) / CELLA
							if pieno < 0.5 then
								materiale, pieno = Enum.Material.Water, 1
							end
						elseif y0 < 0 then
							materiale, pieno = Enum.Material.Water, 1
						end
						materiali[i][j][k] = materiale
						occupazione[i][j][k] = pieno
					end
				end
			end
			-- Angolo del blocco: il voxel i = 1 è quello con la X minore (il più a est), k = 1 il più a sud.
			local minimo = MappaEuropa.CENTRO + Vector3.new(
				-nx * CELLA / 2 + bx * lato * CELLA,
				-sotto * CELLA,
				-nz * CELLA / 2 + bz * lato * CELLA
			)
			terrain:WriteVoxels(Region3.new(minimo, minimo + Vector3.new(lx * CELLA, ny * CELLA, lz * CELLA)), CELLA, materiali, occupazione)
			task.wait()
		end
	end
	tavolo()
	MappaCampagna.pronta = true
	task.spawn(misuraAltezze)
end

return MappaCampagna
