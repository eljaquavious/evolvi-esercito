-- Campi di battaglia: un grande terreno naturale del bioma (rilievi, fiume, vegetazione) con dentro la
-- griglia 6x6 dove si schierano i reggimenti. Le caselle si vedono solo durante lo schieramento.
-- Ogni giocatore in battaglia ha il suo campo, lontano dalla lobby, e ci cammina dentro.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Biomi = require(ReplicatedStorage.Shared.Config.Biomi)
local Campagna = require(ReplicatedStorage.Shared.Config.Campagna)

local Arena = {}

Arena.CASELLA = 16
Arena.COLONNE = Campagna.COLONNE
Arena.RIGHE = Campagna.RIGHE

local DISTANZA_TRA_ARENE = 1200
local INIZIO_ARENE = 3000
local LATO = 640 -- lato del terreno naturale
local VOXEL = 4
local Y_MIN, Y_MAX = -24, 80 -- quote del terreno scritto (relative all'arena)
local META_CAMPO = Arena.CASELLA * Arena.COLONNE / 2
local ALTEZZA_BASE = 3 -- quota del campo
local ALTEZZA_COLLINA = 5
local RAGGIO_COLLINA = Arena.CASELLA * 1.7 -- colline basse e larghe: le caselle sopra restano leggibili
local ACQUA = 1.2 -- pelo dell'acqua del fiume
local FONDO_FIUME = -1.5
local LARGHEZZA_FIUME = 13
local SPONDA = 10 -- larghezza della sponda in pendio
local MEZZO_QUOTE = 80 -- le quote si misurano su questo quadrato attorno al centro
local PASSO_QUOTE = 2
local SENZA_ERBA_ALTA = 150 -- vicino al campo niente Grass: la sua erba alta nasconde soldati e caselle
local PEZZI_CASELLA = 4 -- ogni casella è fatta di 4x4 piastrelle che seguono il terreno
local SOPRA_TERRENO = 0.35

-- Forma del terreno e materiali per bioma.
local RILIEVI = {
	Pianeggiante = { ondulazione = 3, bordo = 28, base = Enum.Material.Grass, campo = Enum.Material.LeafyGrass, chiazze = Enum.Material.Ground, alto = Enum.Material.Grass, roccia = Enum.Material.Rock, sponda = Enum.Material.Mud },
	Collinoso = { ondulazione = 9, bordo = 42, base = Enum.Material.Grass, campo = Enum.Material.LeafyGrass, chiazze = Enum.Material.Ground, alto = Enum.Material.LeafyGrass, roccia = Enum.Material.Rock, sponda = Enum.Material.Mud },
	Desertico = { ondulazione = 5, bordo = 30, dune = true, base = Enum.Material.Sand, campo = Enum.Material.Sand, chiazze = Enum.Material.Sandstone, alto = Enum.Material.Sandstone, roccia = Enum.Material.Sandstone, sponda = Enum.Material.Mud },
	Montagnoso = { ondulazione = 12, bordo = 64, neve = 52, base = Enum.Material.Ground, campo = Enum.Material.Ground, chiazze = Enum.Material.Pebble, alto = Enum.Material.Rock, roccia = Enum.Material.Rock, sponda = Enum.Material.Ground },
	Innevato = { ondulazione = 8, bordo = 48, neve = -100, base = Enum.Material.Snow, campo = Enum.Material.Snow, chiazze = Enum.Material.Ground, alto = Enum.Material.Snow, roccia = Enum.Material.Rock, sponda = Enum.Material.Ground },
}

local terrain = workspace.Terrain

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


-- Cosa mettere attorno al campo, per bioma: { tipo, quantità, scala minima, scala massima }.
local PAESAGGI = {
	Pianeggiante = { { "albero", 90, 1.1, 1.9 }, { "roccia", 22, 1, 1.8 } },
	Collinoso = { { "albero", 80, 1.1, 1.8 }, { "roccia", 30, 1, 2 } },
	Desertico = { { "cactus", 50, 1, 1.6 }, { "roccia", 26, 1, 2.2 } },
	Montagnoso = { { "pino", 70, 1.2, 2 }, { "roccia", 45, 1.2, 2.6 } },
	Innevato = { { "pino", 90, 1.2, 2 }, { "roccia", 14, 1, 1.8 } },
}

local function liscio(a, b, x)
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

-- Centro di una casella (anche con coordinate non intere) rispetto al centro del campo.
local function centroCasella(col, riga)
	return (col - (Arena.COLONNE + 1) / 2) * Arena.CASELLA, (riga - (Arena.RIGHE + 1) / 2) * Arena.CASELLA
end

-- Linea del fiume: dritta sulla sua riga dentro il campo, poi fa anse.
local function zFiume(arena, x)
	local _, z0 = centroCasella(1, arena.rigaFiume)
	local fuori = liscio(META_CAMPO, META_CAMPO + 80, math.abs(x))
	return z0 + math.sin(x / 70 + arena.seme) * 34 * fuori
end

local function nelFiume(arena, x, z, margine)
	return arena.rigaFiume ~= nil and math.abs(z - zFiume(arena, x)) < LARGHEZZA_FIUME / 2 + margine
end

-- Altezza calcolata del terreno in un punto (x, z relativi al centro del campo).
local function altezza(arena, x, z)
	local r = arena.rilievo
	local s = arena.seme
	local n = math.noise(x / 110 + s, z / 110 - s, 0.31) + 0.4 * math.noise(x / 40 - s, z / 40 + s, 0.77)
	local distanza = math.max(math.abs(x), math.abs(z))
	local fuoriCampo = liscio(META_CAMPO + 8, META_CAMPO + 90, distanza)
	local h = ALTEZZA_BASE + n * r.ondulazione * (0.15 + 0.85 * fuoriCampo)
	if r.dune then
		h += math.abs(math.noise(x / 30, z / 55, s)) * 7 * fuoriCampo
	end
	-- Rilievi verso il bordo: il campo sta in una valle.
	h += r.bordo * liscio(190, LATO / 2 - 20, distanza) * (0.7 + 0.5 * math.noise(x / 60 + s, z / 60, 2.1))
	for _, c in ipairs(arena.colline) do
		local d = math.sqrt((x - c.X) ^ 2 + (z - c.Y) ^ 2)
		if d < RAGGIO_COLLINA then
			h += ALTEZZA_COLLINA * (0.5 + 0.5 * math.cos(math.pi * d / RAGGIO_COLLINA))
		end
	end
	if arena.rigaFiume then
		local dz = math.abs(z - zFiume(arena, x))
		local fondo = FONDO_FIUME
		local colonna = math.floor((x + META_CAMPO) / Arena.CASELLA) + 1
		if math.abs(x) < META_CAMPO and arena.guadi[colonna] then
			fondo = ACQUA + 0.4 -- guado: banco di ghiaia appena fuori dall'acqua
		end
		h = fondo + (h - fondo) * liscio(LARGHEZZA_FIUME / 2, LARGHEZZA_FIUME / 2 + SPONDA, dz)
	end
	return math.min(h, Y_MAX - 2)
end

local function materiale(arena, x, z, h, pendenza)
	local r = arena.rilievo
	if nelFiume(arena, x, z, 4) then
		return r.sponda
	end
	if r.neve and h > r.neve then
		return Enum.Material.Snow
	end
	if pendenza > 0.9 then
		return r.roccia
	end
	if math.max(math.abs(x), math.abs(z)) < META_CAMPO + 10 then
		return math.noise(x / 18, z / 18, arena.seme) > 0.25 and r.chiazze or r.campo
	end
	if h > ALTEZZA_BASE + 26 then
		return r.alto
	end
	if math.noise(x / 26, z / 26, arena.seme + 3) > 0.35 then
		return r.chiazze
	end
	local vicino = math.max(math.abs(x), math.abs(z)) + math.noise(x / 40, z / 40, arena.seme + 5) * 30 < SENZA_ERBA_ALTA
	if vicino and r.base == Enum.Material.Grass then
		return r.campo
	end
	return r.base
end

-- Scrive il terreno a blocchi (meno memoria e niente blocchi lunghi del server).
local function scriviTerreno(arena)
	local perLato = LATO / VOXEL
	local strati = (Y_MAX - Y_MIN) / VOXEL
	local lato = 40
	for bx = 0, perLato / lato - 1 do
		for bz = 0, perLato / lato - 1 do
			local materiali, occupazione = {}, {}
			for i = 1, lato do
				materiali[i], occupazione[i] = {}, {}
				local x = -LATO / 2 + (bx * lato + i - 0.5) * VOXEL
				for j = 1, strati do
					materiali[i][j], occupazione[i][j] = {}, {}
				end
				for k = 1, lato do
					local z = -LATO / 2 + (bz * lato + k - 0.5) * VOXEL
					local h = altezza(arena, x, z)
					local pendenza = (math.abs(altezza(arena, x + VOXEL, z) - altezza(arena, x - VOXEL, z))
						+ math.abs(altezza(arena, x, z + VOXEL) - altezza(arena, x, z - VOXEL))) / (2 * VOXEL)
					local cima = materiale(arena, x, z, h, pendenza)
					local sotto = arena.rilievo.roccia == Enum.Material.Sandstone and Enum.Material.Sandstone or Enum.Material.Ground
					local acqua = nelFiume(arena, x, z, 6)
					for j = 1, strati do
						local y0 = Y_MIN + (j - 1) * VOXEL
						local m, o = Enum.Material.Air, 0
						if y0 + VOXEL <= h then
							m, o = h - (y0 + VOXEL) < VOXEL and cima or sotto, 1
						elseif y0 < h then
							m, o = cima, (h - y0) / VOXEL
						end
						if acqua and o < 0.5 and y0 < ACQUA then
							m, o = Enum.Material.Water, math.min(1, (ACQUA - y0) / VOXEL)
						end
						materiali[i][j][k] = m
						occupazione[i][j][k] = o
					end
				end
			end
			local minimo = arena.origine + Vector3.new(-LATO / 2 + bx * lato * VOXEL, Y_MIN, -LATO / 2 + bz * lato * VOXEL)
			terrain:WriteVoxels(Region3.new(minimo, minimo + Vector3.new(lato * VOXEL, strati * VOXEL, lato * VOXEL)), VOXEL, materiali, occupazione)
			task.wait()
		end
	end
end

-- Quota del terreno sul campo: misurata se possibile (il Terrain liscia i voxel e non segue
-- esattamente l'altezza calcolata), altrimenti calcolata.
local function quota(arena, x, z)
	local q = arena.quote
	if q then
		local fi, fk = (x + MEZZO_QUOTE) / PASSO_QUOTE, (z + MEZZO_QUOTE) / PASSO_QUOTE
		local i, k = math.floor(fi), math.floor(fk)
		if q[i] and q[i + 1] and q[i][k] and q[i][k + 1] then
			local tx, tz = fi - i, fk - k
			local a = q[i][k] + (q[i + 1][k] - q[i][k]) * tx
			local b = q[i][k + 1] + (q[i + 1][k + 1] - q[i][k + 1]) * tx
			return a + (b - a) * tz
		end
	end
	return altezza(arena, x, z)
end

-- Misura le quote con raycast. Subito dopo WriteVoxels il raycast non vede ancora il terreno nuovo: si aspetta.
local function misuraQuote(arena)
	local parametri = RaycastParams.new()
	parametri.FilterType = Enum.RaycastFilterType.Include
	parametri.FilterDescendantsInstances = { terrain }
	parametri.IgnoreWater = true
	local function colpo(x, z)
		local risultato = workspace:Raycast(arena.origine + Vector3.new(x, Y_MAX + 10, z), Vector3.new(0, Y_MIN - Y_MAX - 20, 0), parametri)
		return risultato and risultato.Position.Y - arena.origine.Y
	end
	for _ = 1, 50 do
		if colpo(0, 0) then
			break
		end
		task.wait(0.1)
	end
	local quote = {}
	local n = MEZZO_QUOTE * 2 / PASSO_QUOTE
	for i = 0, n do
		quote[i] = {}
		for k = 0, n do
			local x, z = -MEZZO_QUOTE + i * PASSO_QUOTE, -MEZZO_QUOTE + k * PASSO_QUOTE
			quote[i][k] = colpo(x, z) or altezza(arena, x, z)
		end
	end
	arena.quote = quote
end

-- Punto a terra per coordinate del campo (colonna, riga), anche non intere.
function Arena.posizione(arena, x, y)
	local cx, cz = centroCasella(x, y)
	return arena.origine + Vector3.new(cx, quota(arena, cx, cz), cz)
end

-- Quota su cui appoggiare i segni delle caselle: sopra il terreno e, nel fiume, sul pelo dell'acqua.
local function quotaSegno(arena, x, z)
	local q = quota(arena, x, z)
	if nelFiume(arena, x, z, 6) then
		q = math.max(q, ACQUA)
	end
	return q + SOPRA_TERRENO
end

-- Piastrella piatta tra (x0, z0) e (x1, z1), inclinata come il terreno sotto di lei.
local function cframePiastrella(arena, x0, z0, x1, z1)
	local a, b = quotaSegno(arena, x0, z0), quotaSegno(arena, x1, z0)
	local c, d = quotaSegno(arena, x0, z1), quotaSegno(arena, x1, z1)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local pendenzaX = (b - a + d - c) / 2 / (x1 - x0)
	local pendenzaZ = (c - a + d - b) / 2 / (z1 - z0)
	local su = Vector3.new(-pendenzaX, 1, -pendenzaZ).Unit
	local destra = (Vector3.xAxis - su * su.X).Unit
	-- Al centro il terreno può gonfiarsi più degli angoli: si tiene il più alto.
	local y = math.max((a + b + c + d) / 4, quotaSegno(arena, cx, cz))
	return CFrame.fromMatrix(arena.origine + Vector3.new(cx, y, cz), destra, su)
end

-- Una casella: 4x4 piastrelle colorate più il bordo a segmenti, tutto adagiato sul terreno
-- (una lastra unica e piatta veniva tagliata da colline e sponde).
local function creaCasella(arena, genitore, col, riga, colore, coloreBordo)
	local casella = Instance.new("Model")
	casella.Name = "Casella_" .. col .. "_" .. riga
	local cx, cz = centroCasella(col, riga)
	local mezzo = (Arena.CASELLA - 1.2) / 2
	local lato = mezzo * 2 / PEZZI_CASELLA
	local pezzi = {}
	for i = 0, PEZZI_CASELLA - 1 do
		for k = 0, PEZZI_CASELLA - 1 do
			local x0, z0 = cx - mezzo + i * lato, cz - mezzo + k * lato
			table.insert(pezzi, blocco(casella, {
				Name = "Piastrella",
				Size = Vector3.new(lato + 0.05, 0.2, lato + 0.05),
				CFrame = cframePiastrella(arena, x0, z0, x0 + lato, z0 + lato),
				Color = colore,
				Transparency = 0.35,
			}))
		end
	end
	-- Bordo: segmenti sottili da un punto del terreno al successivo.
	local angoli = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }
	for a = 1, 4 do
		local da, verso = angoli[a], angoli[a % 4 + 1]
		local function punto(f)
			local x = cx + mezzo * (da[1] + (verso[1] - da[1]) * f)
			local z = cz + mezzo * (da[2] + (verso[2] - da[2]) * f)
			return arena.origine + Vector3.new(x, quotaSegno(arena, x, z) + 0.06, z)
		end
		for t = 0, PEZZI_CASELLA - 1 do
			local p0, p1 = punto(t / PEZZI_CASELLA), punto((t + 1) / PEZZI_CASELLA)
			table.insert(pezzi, blocco(casella, {
				Name = "Bordo",
				Size = Vector3.new(0.35, 0.16, (p1 - p0).Magnitude + 0.35),
				CFrame = CFrame.lookAt((p0 + p1) / 2, p1),
				Color = coloreBordo,
				Transparency = 0.1,
			}))
		end
	end
	for _, pezzo in ipairs(pezzi) do
		pezzo.CanTouch = false
		pezzo.CastShadow = false
		arena.caselle[pezzo] = pezzo.Transparency
	end
	casella.Parent = genitore
	return casella
end

local function decora(arena, g, rng)
	local paesaggio = PAESAGGI[arena.biomaId] or {}
	local neve = arena.biomaId == "Innevato"
	for _, voce in ipairs(paesaggio) do
		local tipo, quantita, scalaMin, scalaMax = voce[1], voce[2], voce[3], voce[4]
		local piazzati, tentativi = 0, 0
		while piazzati < quantita and tentativi < quantita * 10 do
			tentativi += 1
			local x = rng:NextNumber(-LATO / 2 + 30, LATO / 2 - 30)
			local z = rng:NextNumber(-LATO / 2 + 30, LATO / 2 - 30)
			local lontano = math.max(math.abs(x), math.abs(z)) > META_CAMPO + 22
			if lontano and not nelFiume(arena, x, z, 6) then
				piazzati += 1
				local pos = arena.origine + Vector3.new(x, altezza(arena, x, z) - 0.6, z)
				OGGETTI[tipo](g, pos, rng, rng:NextNumber(scalaMin, scalaMax), neve)
			end
		end
	end
end

function Arena.crea(player, livello)
	local slot = 1
	while slotOccupati[slot] do
		slot += 1
	end
	slotOccupati[slot] = true

	local biomaId = livello.bioma
	local arena = {
		slot = slot,
		origine = Vector3.new(INIZIO_ARENE + slot * DISTANZA_TRA_ARENE, 0, 0),
		bioma = Biomi.Dati[biomaId],
		biomaId = biomaId,
		rilievo = RILIEVI[biomaId] or RILIEVI.Pianeggiante,
		seme = (livello.numero * 0.618) % 1 * 100,
		terreno = {}, -- "col,riga" -> tipo (ostacolo, fiume, guado, collina)
		colline = {},
		guadi = {},
	}
	for _, t in ipairs(livello.terreno) do
		arena.terreno[t.col .. "," .. t.riga] = t.tipo
		if t.tipo == "fiume" or t.tipo == "guado" then
			arena.rigaFiume = t.riga
		end
		if t.tipo == "guado" then
			arena.guadi[t.col] = true
		elseif t.tipo == "collina" then
			table.insert(arena.colline, Vector2.new(centroCasella(t.col, t.riga)))
		end
	end

	scriviTerreno(arena)
	misuraQuote(arena)

	local modello = Instance.new("Model")
	modello.Name = "Arena_" .. player.UserId
	modello.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	arena.modello = modello

	-- Caselle: solo un segno sul terreno, che sparisce quando si combatte.
	local tabellone = Instance.new("Folder")
	tabellone.Name = "Tabellone"
	tabellone.Parent = modello
	arena.caselle = {}
	for col = 1, Arena.COLONNE do
		for riga = 1, Arena.RIGHE do
			local delGiocatore = riga <= Campagna.RIGHE_GIOCATORE
			local colore = delGiocatore and Color3.fromRGB(40, 110, 255) or Color3.fromRGB(220, 30, 30)
			if (col + riga) % 2 == 0 then
				colore = colore:Lerp(Color3.new(1, 1, 1), 0.08)
			end
			local coloreBordo = colore:Lerp(Color3.new(1, 1, 1), 0.5)
			local tipo = arena.terreno[col .. "," .. riga]
			if tipo == "ostacolo" then
				colore = colore:Lerp(Color3.new(0, 0, 0), 0.45)
			elseif tipo == "fiume" then
				colore = Color3.fromRGB(90, 200, 255)
			elseif tipo == "guado" then
				colore = Color3.fromRGB(226, 204, 150):Lerp(colore, 0.3)
			elseif tipo == "collina" then
				colore = colore:Lerp(Color3.fromRGB(120, 200, 80), 0.4)
			end
			local casella = creaCasella(arena, tabellone, col, riga, colore, coloreBordo)
			casella:SetAttribute("Col", col)
			casella:SetAttribute("Riga", riga)
			if tipo then
				casella:SetAttribute("Terreno", tipo)
			end
			-- Il fiume si attraversa ma non ci si schiera dentro.
			if tipo == "ostacolo" or tipo == "fiume" then
				casella:SetAttribute("Ostacolo", true)
			end
		end
	end

	local decorazioni = Instance.new("Folder")
	decorazioni.Name = "Decorazioni"
	decorazioni.Parent = modello
	local rng = Random.new(livello.numero * 31 + 7)
	-- Ostacoli naturali sulle caselle bloccate: un gruppo di alberi, rocce o cactus.
	for _, t in ipairs(livello.terreno) do
		if t.tipo == "ostacolo" then
			local centro = Arena.posizione(arena, t.col, t.riga) - Vector3.new(0, 0.4, 0)
			local oggetto = OGGETTI[arena.bioma.ostacolo]
			oggetto(decorazioni, centro, rng, 1.7, biomaId == "Innevato")
			for _ = 1, 2 do
				local scarto = Vector3.new(rng:NextNumber(-4.5, 4.5), 0, rng:NextNumber(-4.5, 4.5))
				oggetto(decorazioni, centro + scarto, rng, rng:NextNumber(0.9, 1.2), biomaId == "Innevato")
			end
		end
	end
	decora(arena, decorazioni, rng)
	-- Tronchi e rocce sono solidi: il giocatore ci gira attorno.
	for _, parte in ipairs(decorazioni:GetDescendants()) do
		if parte:IsA("BasePart") and (parte.Material == Enum.Material.Wood or parte.Material == Enum.Material.Slate) then
			parte.CanCollide = true
		end
	end

	-- Muri invisibili sul bordo: si cammina solo nella valle.
	local limite = LATO / 2 - 24
	for _, lato in ipairs({ { limite, 0, 4, LATO }, { -limite, 0, 4, LATO }, { 0, limite, LATO, 4 }, { 0, -limite, LATO, 4 } }) do
		blocco(modello, {
			Name = "Limite",
			Size = Vector3.new(lato[3], 400, lato[4]),
			Position = arena.origine + Vector3.new(lato[1], 150, lato[2]),
			Transparency = 1,
			CanCollide = true,
			CanQuery = false,
		})
	end

	local truppe = Instance.new("Folder")
	truppe.Name = "Truppe"
	truppe.Parent = modello

	modello.Parent = cartella
	arena.truppe = truppe
	-- Il giocatore arriva dietro le sue file, rivolto verso il nemico.
	local zArrivo = -META_CAMPO - 22
	local arrivo = arena.origine + Vector3.new(0, quota(arena, 0, zArrivo) + 4, zArrivo)
	arena.arrivo = CFrame.lookAt(arrivo, arrivo + Vector3.zAxis)
	return arena
end

-- Mostra o nasconde le caselle: si vedono solo mentre si schiera.
function Arena.mostraCaselle(arena, visibile)
	for pezzo, trasparenza in pairs(arena.caselle or {}) do
		if pezzo.Parent then
			pezzo.Transparency = visibile and trasparenza or 1
			pezzo.CanQuery = visibile
		end
	end
end

function Arena.distruggi(arena)
	if arena.modello then
		arena.modello:Destroy()
	end
	local centro = arena.origine + Vector3.new(0, (Y_MIN + Y_MAX) / 2, 0)
	terrain:FillBlock(CFrame.new(centro), Vector3.new(LATO + 8, Y_MAX - Y_MIN + 8, LATO + 8), Enum.Material.Air)
	slotOccupati[arena.slot] = nil
end

return Arena
