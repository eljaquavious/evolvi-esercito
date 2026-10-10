-- Mappe di battaglia: un tabellone 6x6 su terreno del bioma, con rilievi e vegetazione intorno.
-- Ogni giocatore in battaglia ha la sua arena, lontana dalla lobby.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Biomi = require(ReplicatedStorage.Shared.Config.Biomi)
local Campagna = require(ReplicatedStorage.Shared.Config.Campagna)

local Arena = {}

Arena.CASELLA = 10
Arena.COLONNE = Campagna.COLONNE
Arena.RIGHE = Campagna.RIGHE
Arena.ALTEZZA_CASELLE = 0.4

local DISTANZA_TRA_ARENE = 600
local INIZIO_ARENE = 3000
local LATO_TERRENO = 400

local terrain = workspace.Terrain

local cartella = Instance.new("Folder")
cartella.Name = "Arene"
cartella.Parent = workspace

local slotOccupati = {}

-- Altezza reale del terreno in (x, z): i voxel di Terrain sono da 4 studs, la superficie non cade esattamente dove si riempie.
local function superficie(x, z)
	local parametri = RaycastParams.new()
	parametri.FilterType = Enum.RaycastFilterType.Include
	parametri.FilterDescendantsInstances = { terrain }
	local colpo = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), parametri)
	return colpo and colpo.Position.Y or 0
end

local function blocco(genitore, proprieta)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide = false
	for k, v in pairs(proprieta) do
		p[k] = v
	end
	p.Parent = genitore
	return p
end

local function sfera(genitore, diametro, posizione, colore, materiale)
	return blocco(genitore, {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * diametro,
		Position = posizione,
		Color = colore,
		Material = materiale or Enum.Material.Grass,
	})
end

local function tronco(genitore, altezza, diametro, posizione, colore)
	return blocco(genitore, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(altezza, diametro, diametro),
		CFrame = CFrame.new(posizione + Vector3.new(0, altezza / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = colore or Color3.fromRGB(104, 72, 42),
		Material = Enum.Material.Wood,
	})
end

-- Vegetazione e rocce, costruite con parti. s = scala.
local OGGETTI = {}

function OGGETTI.albero(g, pos, rng, s)
	tronco(g, 6 * s, 1.1 * s, pos)
	local verde = Color3.fromRGB(58 + rng:NextInteger(-8, 8), 128 + rng:NextInteger(-16, 16), 52)
	sfera(g, 6.5 * s, pos + Vector3.new(0, 7.5 * s, 0), verde)
	sfera(g, 4.5 * s, pos + Vector3.new(1.8 * s, 6.3 * s, 0.8 * s), verde:Lerp(Color3.new(0, 0, 0), 0.08))
	sfera(g, 4.2 * s, pos + Vector3.new(-1.6 * s, 6.6 * s, -1 * s), verde:Lerp(Color3.new(1, 1, 0.6), 0.06))
end

function OGGETTI.pino(g, pos, rng, s, neve)
	tronco(g, 3 * s, 0.9 * s, pos, Color3.fromRGB(92, 62, 38))
	for i = 0, 3 do
		local lato = (6 - i * 1.4) * s
		local livello = blocco(g, {
			Size = Vector3.new(lato, 1.8 * s, lato),
			CFrame = CFrame.new(pos + Vector3.new(0, (3 + i * 1.7) * s, 0)) * CFrame.Angles(0, math.rad(45 * i + rng:NextNumber(0, 20)), 0),
			Color = Color3.fromRGB(38, 88, 56),
			Material = Enum.Material.Grass,
		})
		if neve then
			blocco(g, {
				Size = Vector3.new(lato * 0.85, 0.4 * s, lato * 0.85),
				CFrame = livello.CFrame * CFrame.new(0, 1.0 * s, 0),
				Color = Color3.fromRGB(246, 249, 252),
				Material = Enum.Material.Snow,
			})
		end
	end
end

function OGGETTI.cactus(g, pos, rng, s)
	local verde = Color3.fromRGB(72, 132, 72)
	local function pezzo(altezza, offset)
		blocco(g, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(altezza, 1.3 * s, 1.3 * s),
			CFrame = CFrame.new(pos + offset + Vector3.new(0, altezza / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = verde,
			Material = Enum.Material.Grass,
		})
		sfera(g, 1.3 * s, pos + offset + Vector3.new(0, altezza, 0), verde)
	end
	pezzo(7 * s, Vector3.zero)
	pezzo(2.6 * s, Vector3.new(1.4 * s, 3.4 * s, 0))
	pezzo(2 * s, Vector3.new(-1.4 * s, 2.4 * s, 0))
	blocco(g, { Size = Vector3.new(1.6 * s, 0.9 * s, 0.9 * s), Position = pos + Vector3.new(0.7 * s, 3.6 * s, 0), Color = verde, Material = Enum.Material.Grass })
	blocco(g, { Size = Vector3.new(1.6 * s, 0.9 * s, 0.9 * s), Position = pos + Vector3.new(-0.7 * s, 2.6 * s, 0), Color = verde, Material = Enum.Material.Grass })
end

function OGGETTI.roccia(g, pos, rng, s, neve)
	local colore = neve and Color3.fromRGB(196, 204, 214) or Color3.fromRGB(122 + rng:NextInteger(-12, 12), 118, 110)
	for i = 1, 3 do
		local d = rng:NextNumber(2, 4) * s / i ^ 0.4
		blocco(g, {
			Size = Vector3.new(d * rng:NextNumber(1, 1.5), d, d * rng:NextNumber(1, 1.4)),
			CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-1, 1) * s, d * 0.35, rng:NextNumber(-1, 1) * s))
				* CFrame.Angles(rng:NextNumber(0, 0.5), rng:NextNumber(0, math.pi), rng:NextNumber(0, 0.5)),
			Color = colore,
			Material = Enum.Material.Slate,
		})
	end
end

-- Cosa mettere intorno al tabellone, per bioma: { tipo, quantità, distanza minima, distanza massima }.
-- "collina", "duna" e "montagna" sono rilievi di Terrain; gli altri sono parti.
local PAESAGGI = {
	Pianeggiante = { { "albero", 34, 46, 170 }, { "roccia", 12, 44, 150 }, { "collina", 4, 150, 190 } },
	Collinoso = { { "collina", 16, 80, 190 }, { "albero", 22, 46, 150 }, { "roccia", 8, 44, 140 } },
	Desertico = { { "duna", 16, 70, 190 }, { "cactus", 22, 44, 150 }, { "roccia", 8, 44, 140 } },
	Montagnoso = { { "montagna", 12, 120, 200 }, { "roccia", 24, 44, 130 }, { "pino", 12, 50, 140 } },
	Innevato = { { "montagna", 9, 120, 200 }, { "pino", 34, 44, 160 }, { "roccia", 8, 44, 130 } },
}

local function rilievo(tipo, pos, rng, bioma, neve)
	if tipo == "collina" then
		local raggio = rng:NextNumber(18, 32)
		terrain:FillBall(pos - Vector3.new(0, raggio * 0.55, 0), raggio, bioma.materialeRilievi)
	elseif tipo == "duna" then
		local raggio = rng:NextNumber(16, 28)
		terrain:FillBall(pos - Vector3.new(0, raggio * 0.7, 0), raggio, Enum.Material.Sand)
	elseif tipo == "montagna" then
		local raggio = rng:NextNumber(30, 46)
		local centro = pos - Vector3.new(0, raggio * 0.35, 0)
		terrain:FillBall(centro, raggio, Enum.Material.Rock)
		terrain:FillBall(centro + Vector3.new(rng:NextNumber(-8, 8), raggio * 0.55, rng:NextNumber(-8, 8)), raggio * 0.55, neve and Enum.Material.Snow or Enum.Material.Rock)
		if neve then
			terrain:FillBall(centro + Vector3.new(0, raggio * 0.9, 0), raggio * 0.25, Enum.Material.Snow)
		end
	end
end

local function decora(g, biomaId, bioma, origine, rng)
	local neve = biomaId == "Innevato"
	for _, voce in ipairs(PAESAGGI[biomaId] or {}) do
		local tipo, quantita, minimo, massimo = voce[1], voce[2], voce[3], voce[4]
		local piazzati, tentativi = 0, 0
		while piazzati < quantita and tentativi < quantita * 10 do
			tentativi += 1
			local angolo = rng:NextNumber(0, math.pi * 2)
			local raggio = rng:NextNumber(minimo, massimo)
			local x, z = math.cos(angolo) * raggio, math.sin(angolo) * raggio
			-- Lascia libera la visuale tra la telecamera (dietro al lato del giocatore) e il tabellone.
			if not (z < -30 and math.abs(x) < 60 + (-z) * 0.4) then
				piazzati += 1
				local pos = origine + Vector3.new(x, 0, z)
				if tipo == "collina" or tipo == "duna" or tipo == "montagna" then
					rilievo(tipo, pos, rng, bioma, neve)
				else
					OGGETTI[tipo](g, pos, rng, rng:NextNumber(0.9, 1.5), neve)
				end
			end
		end
	end
end

-- Posizione a terra (sopra le caselle) per coordinate del tabellone, anche non intere.
function Arena.posizione(arena, x, y)
	local cx = (x - (Arena.COLONNE + 1) / 2) * Arena.CASELLA
	local cz = (y - (Arena.RIGHE + 1) / 2) * Arena.CASELLA
	return arena.origine + Vector3.new(cx, Arena.ALTEZZA_CASELLE, cz)
end

function Arena.crea(player, livello)
	local slot = 1
	while slotOccupati[slot] do
		slot += 1
	end
	slotOccupati[slot] = true

	local biomaId = livello.bioma
	local bioma = Biomi.Dati[biomaId]
	local origine = Vector3.new(INIZIO_ARENE + slot * DISTANZA_TRA_ARENE, 0, 0)
	local arena = { slot = slot, origine = origine, bioma = bioma, biomaId = biomaId }

	-- Terreno: un blocco piatto intorno a y = 0. Sotto il tabellone niente erba, che coprirebbe caselle e soldati.
	terrain:FillBlock(CFrame.new(origine - Vector3.new(0, 8, 0)), Vector3.new(LATO_TERRENO, 16, LATO_TERRENO), bioma.materiale)
	if bioma.materiale == Enum.Material.Grass then
		terrain:FillBlock(CFrame.new(origine - Vector3.new(0, 8, 0)), Vector3.new(Arena.COLONNE * Arena.CASELLA + 16, 16, Arena.RIGHE * Arena.CASELLA + 16), Enum.Material.Ground)
	end
	-- Il tabellone poggia sulla superficie vera del terreno.
	origine = Vector3.new(origine.X, superficie(origine.X, origine.Z) + 0.15, origine.Z)
	arena.origine = origine

	local modello = Instance.new("Model")
	modello.Name = "Arena_" .. player.UserId
	modello.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	arena.modello = modello

	local ostacoli = {}
	for _, o in ipairs(livello.ostacoli) do
		ostacoli[o.col .. "," .. o.riga] = true
	end

	local tabellone = Instance.new("Folder")
	tabellone.Name = "Tabellone"
	tabellone.Parent = modello
	local lato = Arena.CASELLA
	-- Cornice del tabellone.
	blocco(modello, {
		Name = "Cornice",
		Size = Vector3.new(Arena.COLONNE * lato + 2, 0.3, Arena.RIGHE * lato + 2),
		Position = origine + Vector3.new(0, 0.1, 0),
		Color = Color3.fromRGB(60, 52, 44),
		Material = Enum.Material.WoodPlanks,
		Transparency = 0.2,
	})
	for col = 1, Arena.COLONNE do
		for riga = 1, Arena.RIGHE do
			local delGiocatore = riga <= Campagna.RIGHE_GIOCATORE
			local colore = bioma.casella:Lerp(delGiocatore and Color3.fromRGB(60, 120, 255) or Color3.fromRGB(230, 70, 70), delGiocatore and 0.6 or 0.45)
			if (col + riga) % 2 == 0 then
				colore = colore:Lerp(Color3.new(1, 1, 1), 0.12)
			end
			local casella = blocco(tabellone, {
				Name = "Casella_" .. col .. "_" .. riga,
				Size = Vector3.new(lato - 0.5, Arena.ALTEZZA_CASELLE, lato - 0.5),
				Position = Arena.posizione(arena, col, riga) - Vector3.new(0, Arena.ALTEZZA_CASELLE / 2, 0),
				Color = colore,
				Material = Enum.Material.SmoothPlastic,
				Transparency = 0.25,
				CanQuery = true,
			})
			casella:SetAttribute("Col", col)
			casella:SetAttribute("Riga", riga)
			if ostacoli[col .. "," .. riga] then
				casella:SetAttribute("Ostacolo", true)
				casella.Color = colore:Lerp(Color3.new(0, 0, 0), 0.35)
			end
		end
	end
	blocco(modello, {
		Name = "Confine",
		Size = Vector3.new(Arena.COLONNE * lato, 0.15, 0.5),
		Position = origine + Vector3.new(0, Arena.ALTEZZA_CASELLE + 0.08, 0),
		Color = Color3.fromRGB(255, 240, 200),
		Material = Enum.Material.Neon,
	})

	local decorazioni = Instance.new("Folder")
	decorazioni.Name = "Decorazioni"
	decorazioni.Parent = modello
	local rng = Random.new(livello.numero * 31 + 7)
	for _, o in ipairs(livello.ostacoli) do
		local pos = Arena.posizione(arena, o.col, o.riga)
		OGGETTI[bioma.ostacolo](decorazioni, pos, rng, 1.2, biomaId == "Innevato")
	end
	decora(decorazioni, biomaId, bioma, origine, rng)

	blocco(modello, {
		Name = "Belvedere",
		Size = Vector3.new(10, 1, 10),
		Position = origine + Vector3.new(0, 0.5, -95),
		Color = Color3.fromRGB(120, 110, 100),
		Material = Enum.Material.Cobblestone,
		CanCollide = true,
	})

	local truppe = Instance.new("Folder")
	truppe.Name = "Truppe"
	truppe.Parent = modello

	modello.Parent = cartella
	arena.truppe = truppe
	arena.belvedere = origine + Vector3.new(0, 4, -95)
	return arena
end

function Arena.distruggi(arena)
	if arena.modello then
		arena.modello:Destroy()
	end
	terrain:FillBlock(CFrame.new(arena.origine + Vector3.new(0, 30, 0)), Vector3.new(LATO_TERRENO + 120, 140, LATO_TERRENO + 120), Enum.Material.Air)
	slotOccupati[arena.slot] = nil
end

return Arena
