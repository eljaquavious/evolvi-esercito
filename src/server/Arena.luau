-- Mappe di battaglia: un tabellone 8x8 circondato dalla decorazione del bioma.
-- Ogni giocatore in battaglia ha la sua arena, lontana dalla lobby.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Biomi = require(ReplicatedStorage.Shared.Config.Biomi)

local Arena = {}

Arena.CASELLA = 6
Arena.COLONNE = 8
Arena.RIGHE = 8

local DISTANZA_TRA_ARENE = 600
local INIZIO_ARENE = 3000

local cartella = Instance.new("Folder")
cartella.Name = "Arene"
cartella.Parent = workspace

local slotOccupati = {}

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

-- Ellissoide: un blocco con una mesh sferica che ne prende le dimensioni.
local function ellissoide(genitore, dimensione, posizione, colore, materiale)
	local p = blocco(genitore, {
		Size = dimensione,
		Position = posizione,
		Color = colore,
		Material = materiale,
		CanCollide = false,
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function cilindroVerticale(genitore, altezza, diametro, posizione, colore, materiale)
	return blocco(genitore, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(altezza, diametro, diametro),
		CFrame = CFrame.new(posizione) * CFrame.Angles(0, 0, math.rad(90)),
		Color = colore,
		Material = materiale or Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
end

local DECORAZIONI = {}

function DECORAZIONI.albero(g, pos, rng)
	local s = rng:NextNumber(0.8, 1.4)
	cilindroVerticale(g, 6 * s, 1.2 * s, pos + Vector3.new(0, 3 * s, 0), Color3.fromRGB(110, 76, 44), Enum.Material.Wood)
	local verde = Color3.fromRGB(60, 130 + rng:NextInteger(-20, 20), 56)
	ellissoide(g, Vector3.new(7, 6, 7) * s, pos + Vector3.new(0, 8 * s, 0), verde, Enum.Material.Grass)
end

function DECORAZIONI.pino(g, pos, rng, neve)
	local s = rng:NextNumber(0.9, 1.6)
	cilindroVerticale(g, 4 * s, 1 * s, pos + Vector3.new(0, 2 * s, 0), Color3.fromRGB(96, 66, 40), Enum.Material.Wood)
	for i = 0, 2 do
		local lato = (6 - i * 1.8) * s
		local livello = blocco(g, {
			Size = Vector3.new(lato, 2.4 * s, lato),
			CFrame = CFrame.new(pos + Vector3.new(0, (4 + i * 2.2) * s, 0)) * CFrame.Angles(0, math.rad(45 * i), 0),
			Color = Color3.fromRGB(40, 92, 58),
			Material = Enum.Material.Grass,
			CanCollide = false,
		})
		if neve then
			blocco(g, {
				Size = Vector3.new(lato * 0.8, 0.5, lato * 0.8),
				CFrame = livello.CFrame * CFrame.new(0, 1.3 * s, 0),
				Color = Color3.fromRGB(245, 248, 252),
				Material = Enum.Material.Snow,
				CanCollide = false,
			})
		end
	end
end

function DECORAZIONI.collina(g, pos, rng, colore)
	local larghezza = rng:NextNumber(30, 60)
	ellissoide(g, Vector3.new(larghezza, rng:NextNumber(14, 26), larghezza * rng:NextNumber(0.7, 1.2)), pos, colore, Enum.Material.Grass)
end

function DECORAZIONI.duna(g, pos, rng)
	local larghezza = rng:NextNumber(30, 70)
	ellissoide(g, Vector3.new(larghezza, rng:NextNumber(8, 16), larghezza * 0.5), pos, Color3.fromRGB(226, 196, 136), Enum.Material.Sand)
end

function DECORAZIONI.cactus(g, pos, rng)
	local s = rng:NextNumber(0.8, 1.3)
	local verde = Color3.fromRGB(70, 128, 70)
	cilindroVerticale(g, 7 * s, 1.4 * s, pos + Vector3.new(0, 3.5 * s, 0), verde, Enum.Material.Grass)
	cilindroVerticale(g, 2.5 * s, 0.9 * s, pos + Vector3.new(1.3 * s, 4.5 * s, 0), verde, Enum.Material.Grass)
	blocco(g, {
		Size = Vector3.new(1.3 * s, 0.8 * s, 0.8 * s),
		Position = pos + Vector3.new(0.7 * s, 3.4 * s, 0),
		Color = verde,
		Material = Enum.Material.Grass,
		CanCollide = false,
	})
end

function DECORAZIONI.roccia(g, pos, rng, colore)
	local s = rng:NextNumber(2, 6)
	blocco(g, {
		Size = Vector3.new(s * rng:NextNumber(0.8, 1.4), s, s * rng:NextNumber(0.8, 1.4)),
		CFrame = CFrame.new(pos + Vector3.new(0, s * 0.3, 0)) * CFrame.Angles(rng:NextNumber(0, 0.6), rng:NextNumber(0, math.pi), rng:NextNumber(0, 0.6)),
		Color = colore or Color3.fromRGB(128, 124, 118),
		Material = Enum.Material.Slate,
		CanCollide = false,
	})
end

function DECORAZIONI.montagna(g, pos, rng, neve)
	local altezza = rng:NextNumber(40, 70)
	local base = altezza * rng:NextNumber(0.9, 1.2)
	local grigio = Color3.fromRGB(116 + rng:NextInteger(-10, 10), 112, 106)
	for i = 0, 2 do
		local scala = 1 - i * 0.3
		local pezzo = blocco(g, {
			Size = Vector3.new(base * scala, altezza * scala, base * scala),
			CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-4, 4), altezza * 0.15 + i * altezza * 0.25, rng:NextNumber(-4, 4)))
				* CFrame.Angles(math.rad(45), rng:NextNumber(0, math.pi), math.rad(35)),
			Color = grigio,
			Material = Enum.Material.Slate,
			CanCollide = false,
		})
		if neve and i == 2 then
			pezzo.Color = Color3.fromRGB(240, 244, 250)
			pezzo.Material = Enum.Material.Snow
		end
	end
end

-- Cosa mettere intorno al tabellone, per bioma: { tipo, quantità, distanza minima, distanza massima }.
local PAESAGGI = {
	Pianeggiante = { { "albero", 26, 34, 120 }, { "roccia", 10, 30, 100 } },
	Collinoso = { { "collina", 14, 60, 140 }, { "albero", 18, 34, 110 } },
	Desertico = { { "duna", 14, 50, 140 }, { "cactus", 18, 32, 110 }, { "roccia", 6, 30, 90 } },
	Montagnoso = { { "montagna", 12, 110, 170 }, { "roccia", 22, 30, 90 }, { "pino", 8, 40, 100 } },
	Innevato = { { "montagna", 8, 110, 170 }, { "pino", 26, 32, 120 }, { "roccia", 8, 30, 90 } },
}

local function decora(g, biomaId, origine, rng, bioma)
	for _, voce in ipairs(PAESAGGI[biomaId] or {}) do
		local tipo, quantita, minimo, massimo = voce[1], voce[2], voce[3], voce[4]
		local piazzati, tentativi = 0, 0
		while piazzati < quantita and tentativi < quantita * 10 do
			tentativi += 1
			local angolo = rng:NextNumber(0, math.pi * 2)
			local raggio = rng:NextNumber(minimo, massimo)
			local x, z = math.cos(angolo) * raggio, math.sin(angolo) * raggio
			-- Lascia libera la visuale tra la telecamera e il tabellone.
			if not (z < -20 and math.abs(x) < 50 + (-z) * 0.3) then
				piazzati += 1
				local pos = origine + Vector3.new(x, 0, z)
				if tipo == "collina" then
					DECORAZIONI.collina(g, pos, rng, bioma.terreno:Lerp(Color3.new(0, 0, 0), 0.08))
				elseif tipo == "pino" or tipo == "montagna" then
					DECORAZIONI[tipo](g, pos, rng, biomaId == "Innevato")
				elseif tipo == "roccia" and biomaId == "Innevato" then
					DECORAZIONI.roccia(g, pos, rng, Color3.fromRGB(196, 204, 214))
				else
					DECORAZIONI[tipo](g, pos, rng)
				end
			end
		end
	end
end

-- Posizione a terra (sopra le caselle) per coordinate del tabellone, anche non intere.
function Arena.posizione(arena, x, y)
	local cx = (x - (Arena.COLONNE + 1) / 2) * Arena.CASELLA
	local cz = (y - (Arena.RIGHE + 1) / 2) * Arena.CASELLA
	return arena.origine + Vector3.new(cx, 1, cz)
end

function Arena.crea(player, biomaId)
	local slot = 1
	while slotOccupati[slot] do
		slot += 1
	end
	slotOccupati[slot] = true

	local bioma = Biomi.Dati[biomaId]
	local origine = Vector3.new(INIZIO_ARENE + slot * DISTANZA_TRA_ARENE, 0, 0)
	local modello = Instance.new("Model")
	modello.Name = "Arena_" .. player.UserId
	modello.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	blocco(modello, {
		Name = "Terreno",
		Size = Vector3.new(360, 2, 360),
		Position = origine - Vector3.new(0, 1, 0),
		Color = bioma.terreno,
		Material = bioma.materiale,
	})

	local tabellone = Instance.new("Folder")
	tabellone.Name = "Tabellone"
	tabellone.Parent = modello
	for col = 1, Arena.COLONNE do
		for riga = 1, Arena.RIGHE do
			local colore = (col + riga) % 2 == 0 and bioma.casellaA or bioma.casellaB
			if riga > Arena.RIGHE / 2 then
				colore = colore:Lerp(Color3.fromRGB(200, 70, 70), 0.12)
			end
			local casella = blocco(tabellone, {
				Name = "Casella_" .. col .. "_" .. riga,
				Size = Vector3.new(Arena.CASELLA - 0.25, 1, Arena.CASELLA - 0.25),
				Position = Arena.posizione({ origine = origine }, col, riga) - Vector3.new(0, 0.5, 0),
				Color = colore,
				Material = bioma.materiale,
			})
			casella:SetAttribute("Col", col)
			casella:SetAttribute("Riga", riga)
		end
	end
	blocco(modello, {
		Name = "Confine",
		Size = Vector3.new(Arena.COLONNE * Arena.CASELLA, 0.2, 0.4),
		Position = origine + Vector3.new(0, 1.05, 0),
		Color = Color3.fromRGB(255, 255, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})

	blocco(modello, {
		Name = "Belvedere",
		Size = Vector3.new(12, 1, 12),
		Position = origine + Vector3.new(0, 0.5, -75),
		Color = Color3.fromRGB(120, 110, 100),
		Material = Enum.Material.Cobblestone,
	})

	local decorazioni = Instance.new("Folder")
	decorazioni.Name = "Decorazioni"
	decorazioni.Parent = modello
	decora(decorazioni, biomaId, origine, Random.new(), bioma)

	local truppe = Instance.new("Folder")
	truppe.Name = "Truppe"
	truppe.Parent = modello

	modello.Parent = cartella

	return {
		slot = slot,
		origine = origine,
		modello = modello,
		truppe = truppe,
		bioma = bioma,
		belvedere = origine + Vector3.new(0, 4, -75),
	}
end

function Arena.distruggi(arena)
	if arena.modello then
		arena.modello:Destroy()
	end
	slotOccupati[arena.slot] = nil
end

return Arena
