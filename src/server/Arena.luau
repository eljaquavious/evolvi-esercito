-- Campi di battaglia: un grande terreno naturale del bioma (rilievi, fiume, vegetazione) con dentro la
-- griglia 6x6 dove si schierano i reggimenti (2 righe a testa, in mezzo 2 righe di terra di nessuno). Le caselle si vedono solo durante lo schieramento.
-- Ogni giocatore in battaglia ha il suo campo, lontano dalla lobby, e ci cammina dentro.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Biomi = require(ReplicatedStorage.Shared.Config.Biomi)
local Campagna = require(ReplicatedStorage.Shared.Config.Campagna)
local Scenari = require(script.Parent.Scenari)

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
local FONDO_MARE = -7
local FONDO_LAGO = -3.5
local GHIACCIO = ALTEZZA_BASE - 0.2 -- quota del lago gelato

-- Forma del terreno e materiali per bioma. Solo materiali del Terrain: uno da parti (per esempio Pebble)
-- in WriteVoxels diventa Grass, con la sua erba alta.
local RILIEVI = {
	Pianeggiante = { ondulazione = 3, bordo = 28, base = Enum.Material.Grass, campo = Enum.Material.LeafyGrass, chiazze = Enum.Material.Ground, alto = Enum.Material.Grass, roccia = Enum.Material.Rock, sponda = Enum.Material.Mud },
	Collinoso = { ondulazione = 9, bordo = 42, base = Enum.Material.Grass, campo = Enum.Material.LeafyGrass, chiazze = Enum.Material.Ground, alto = Enum.Material.LeafyGrass, roccia = Enum.Material.Rock, sponda = Enum.Material.Mud },
	Desertico = { ondulazione = 5, bordo = 30, dune = true, base = Enum.Material.Sand, campo = Enum.Material.Sand, chiazze = Enum.Material.Sandstone, alto = Enum.Material.Sandstone, roccia = Enum.Material.Sandstone, sponda = Enum.Material.Mud },
	Montagnoso = { ondulazione = 12, bordo = 64, neve = 52, base = Enum.Material.Ground, campo = Enum.Material.Ground, chiazze = Enum.Material.Rock, alto = Enum.Material.Rock, roccia = Enum.Material.Rock, sponda = Enum.Material.Ground },
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

-- Mare dello scenario: la coordinata verso il largo e la linea di costa (mossa) in quel punto.
local function versoMare(arena, x, z)
	local m = arena.scenario.mare
	local c = (m.asse == "x" and x or z) * m.segno
	local lungo = m.asse == "x" and z or x
	return c, m.inizio + math.noise(lungo / 90, arena.seme, 6.1) * 18
end

-- Distanza "ellittica" dal centro di un lago (1 = riva), con la riva frastagliata.
local function distanzaLago(arena, lago, x, z)
	local dx, dz = (x - lago[1]) / lago[3], (z - lago[2]) / lago[4]
	local d = math.sqrt(dx * dx + dz * dz)
	return d + math.noise(x / 40, z / 40, arena.seme + lago[1] / 100) * 0.12
end

-- La colonna (x, z) è dove lo scenario mette acqua vera: mare o lago non gelato.
local function regioneAcqua(arena, x, z)
	local sc = arena.scenario
	if sc.mare then
		local c, costa = versoMare(arena, x, z)
		if c > costa then
			return true
		end
	end
	for _, lago in ipairs(sc.laghi or {}) do
		if not lago.ghiaccio and distanzaLago(arena, lago, x, z) < 1.1 then
			return true
		end
	end
	return false
end

local function sulGhiaccio(arena, x, z, margine)
	for _, lago in ipairs(arena.scenario.laghi or {}) do
		if lago.ghiaccio and distanzaLago(arena, lago, x, z) < 1.02 + margine / math.min(lago[3], lago[4]) then
			return true
		end
	end
	return false
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
	h += r.bordo * liscio(150, LATO / 2 - 20, distanza) * (0.7 + 0.5 * math.noise(x / 60 + s, z / 60, 2.1))
	for _, c in ipairs(arena.colline) do
		local d = math.sqrt((x - c.X) ^ 2 + (z - c.Y) ^ 2)
		if d < RAGGIO_COLLINA then
			h += ALTEZZA_COLLINA * (0.5 + 0.5 * math.cos(math.pi * d / RAGGIO_COLLINA))
		end
	end
	-- Rilievi della battaglia storica: colli { x, z, raggio, altezza } e versanti lungo un lato.
	local sc = arena.scenario
	for _, c in ipairs(sc.colli or {}) do
		local d = math.sqrt((x - c[1]) ^ 2 + (z - c[2]) ^ 2)
		if d < c[3] then
			h += c[4] * (0.5 + 0.5 * math.cos(math.pi * d / c[3]))
		end
	end
	for _, v in ipairs(sc.versanti or {}) do
		local c = (v.asse == "x" and x or z) * v.segno
		local lungo = v.asse == "x" and z or x
		local mosso = c + math.noise(lungo / 50, s, 4.2) * (v.mosso or 16)
		h += v.altezza * liscio(v.inizio, v.inizio + (v.largo or 70), mosso) * (0.85 + 0.3 * math.noise(x / 45, z / 45, s + 9))
	end
	for _, sp in ipairs(arena.spianate) do
		local d = math.sqrt((x - sp.x) ^ 2 + (z - sp.z) ^ 2)
		if d < sp.r * 1.6 then
			h += (sp.h - h) * (1 - liscio(sp.r, sp.r * 1.6, d))
		end
	end
	if sc.mare then
		local c, costa = versoMare(arena, x, z)
		local largo = liscio(costa - 6, costa + 40, c)
		h += (FONDO_MARE + math.noise(x / 30, z / 30, s + 2) - h) * largo
	end
	for _, lago in ipairs(sc.laghi or {}) do
		local d = distanzaLago(arena, lago, x, z)
		if lago.ghiaccio then
			h = GHIACCIO + (h - GHIACCIO) * liscio(1.0, 1.25, d)
		else
			-- Prima si spiana la conca attorno al lago, poi si scava: niente rive a strapiombo sui pendii.
			h = h + (ALTEZZA_BASE + 0.5 - h) * (1 - liscio(1.1, 1.9, d))
			h = FONDO_LAGO + (h - FONDO_LAGO) * liscio(0.7, 1.05, d)
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
	local sc = arena.scenario
	for _, lago in ipairs(sc.laghi or {}) do
		local d = distanzaLago(arena, lago, x, z)
		if lago.ghiaccio and d < 1.0 then
			return math.noise(x / 22, z / 22, arena.seme + 7) > 0.3 and Enum.Material.Snow or Enum.Material.Ice
		elseif not lago.ghiaccio and d < 1.08 then
			return Enum.Material.Mud
		end
	end
	if sc.mare and h < ACQUA + 4 then
		local c, costa = versoMare(arena, x, z)
		if c > costa - 30 then
			return Enum.Material.Sand
		end
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
					local acqua = nelFiume(arena, x, z, 6) or (h < ACQUA + 0.5 and regioneAcqua(arena, x, z))
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

-- Quello che serve agli scenari per mettere gli oggetti sul terreno di questo campo.
local function ambiente(arena, livello)
	-- L'acqua del fiume arriva fin dove la sponda scende sotto il pelo dell'acqua, ben oltre il letto.
	local function acqua(x, z)
		if nelFiume(arena, x, z, 6) then
			-- Il Terrain liscia i voxel e l'acqua sale un po' sulla sponda: si tiene un margine in altezza.
			return altezza(arena, x, z) < ACQUA + 1
		end
		return altezza(arena, x, z) < ACQUA + 0.3 and regioneAcqua(arena, x, z)
	end
	-- Fuori dal quadrato delle quote misurate il terreno vero si discosta da quello calcolato (di più sui
	-- pendii ripidi): lì la quota si misura al momento, così gli oggetti non restano sospesi o interrati.
	local parametri = RaycastParams.new()
	parametri.FilterType = Enum.RaycastFilterType.Include
	parametri.FilterDescendantsInstances = { terrain }
	parametri.IgnoreWater = true
	local function quotaVera(x, z)
		if arena.quote and math.max(math.abs(x), math.abs(z)) >= MEZZO_QUOTE then
			local colpo = workspace:Raycast(arena.origine + Vector3.new(x, Y_MAX + 10, z), Vector3.new(0, Y_MIN - Y_MAX - 20, 0), parametri)
			if colpo then
				return colpo.Position.Y - arena.origine.Y
			end
		end
		return quota(arena, x, z)
	end
	-- Acqua vera entro "margine" dal punto (con margine negativo: tutto il cerchio è acqua).
	local function liquida(x, z, margine)
		if nelFiume(arena, x, z, margine) then
			return true
		end
		local sc = arena.scenario
		if not sc.mare and not sc.laghi and not arena.rigaFiume then
			return false
		end
		local r = math.abs(margine)
		local tutti = margine < 0
		local centro = acqua(x, z)
		if tutti and not centro then
			return false
		elseif not tutti and centro then
			return true
		end
		for i = 0, 7 do
			local a = i * math.pi / 4
			local w = acqua(x + math.cos(a) * r, z + math.sin(a) * r)
			if tutti and not w then
				return false
			elseif not tutti and w then
				return true
			end
		end
		return tutti
	end
	return {
		terra = function(x, z)
			return arena.origine + Vector3.new(x, quotaVera(x, z) - 0.3, z)
		end,
		acquaY = arena.origine.Y + ACQUA,
		fiumeZ = arena.rigaFiume and function(x)
			return zFiume(arena, x)
		end or nil,
		-- Per non metterci sopra oggetti, anche il lago gelato conta come acqua.
		inAcqua = function(x, z, margine)
			return liquida(x, z, margine) or sulGhiaccio(arena, x, z, margine)
		end,
		liquida = liquida,
		bioma = arena.biomaId,
		epoca = livello.epoca and livello.epoca.id or "Antica",
		seme = livello.numero * 31 + 7,
	}
end

-- Materiali solidi: il giocatore gira attorno a tronchi, rocce, muri e carri (non a foglie, erba e teli).
local SOLIDI = {
	[Enum.Material.Wood] = true, [Enum.Material.WoodPlanks] = true, [Enum.Material.Slate] = true,
	[Enum.Material.Cobblestone] = true, [Enum.Material.Brick] = true, [Enum.Material.Concrete] = true,
	[Enum.Material.Limestone] = true, [Enum.Material.Sandstone] = true, [Enum.Material.Rock] = true,
	[Enum.Material.Metal] = true, [Enum.Material.CorrodedMetal] = true, [Enum.Material.Plaster] = true,
	[Enum.Material.Marble] = true, [Enum.Material.Granite] = true, [Enum.Material.Basalt] = true,
}

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
		rilievo = table.clone(RILIEVI[biomaId] or RILIEVI.Pianeggiante),
		scenario = Scenari.dati(livello.nome),
		seme = (livello.numero * 0.618) % 1 * 100,
		terreno = {}, -- "col,riga" -> tipo (ostacolo, fiume, guado, collina)
		colline = {},
		guadi = {},
		spianate = {}, -- { x, z, r, h }: terreno piatto sotto gli edifici grandi dello scenario
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

	-- Lo scenario della battaglia può cambiare la forma e i materiali del terreno del bioma.
	for k, v in pairs(arena.scenario.terreno or {}) do
		arena.rilievo[k] = v
	end
	-- Le quote delle spianate si prendono tutte dal terreno ancora intatto, poi valgono insieme.
	local spianate = {}
	for _, v in ipairs(Scenari.spianate(livello.nome)) do
		table.insert(spianate, { x = v[1], z = v[2], r = v[3], h = altezza(arena, v[1], v[2]) })
	end
	arena.spianate = spianate

	scriviTerreno(arena)
	local piano = Scenari.prepara(livello.nome, ambiente(arena, livello))
	piano:scava() -- crateri e trincee fanno parte del terreno: prima di misurare le quote
	-- Trincee sulle caselle: un tratto per ogni fila di caselle "trincea" una accanto all'altra.
	for riga = 1, Arena.RIGHE do
		local col = 1
		while col <= Arena.COLONNE do
			if arena.terreno[col .. "," .. riga] == "trincea" then
				local fine = col
				while arena.terreno[(fine + 1) .. "," .. riga] == "trincea" do
					fine += 1
				end
				local x, z = centroCasella((col + fine) / 2, riga)
				piano:trinceaCampo(x, z, (fine - col + 1) * Arena.CASELLA, riga <= Campagna.RIGHE_GIOCATORE and 1 or -1)
				col = fine + 1
			else
				col += 1
			end
		end
	end
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
			local terraDiNessuno = not delGiocatore and riga < Campagna.PRIMA_RIGA_NEMICA
			local colore = delGiocatore and Color3.fromRGB(40, 110, 255)
				or terraDiNessuno and Color3.fromRGB(150, 140, 120)
				or Color3.fromRGB(220, 30, 30)
			if (col + riga) % 2 == 0 then
				colore = colore:Lerp(Color3.new(1, 1, 1), 0.08)
			end
			local coloreBordo = colore:Lerp(Color3.new(1, 1, 1), 0.5)
			local tipo = arena.terreno[col .. "," .. riga]
			if Campagna.SOLIDI[tipo] then
				colore = colore:Lerp(Color3.new(0, 0, 0), 0.45)
			elseif tipo == "trincea" then
				colore = colore:Lerp(Color3.fromRGB(150, 110, 60), 0.45)
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
			if terraDiNessuno then
				casella:SetAttribute("TerraDiNessuno", true)
			end
			-- Il fiume si attraversa ma non ci si schiera dentro.
			if Campagna.BLOCCATI[tipo] then
				casella:SetAttribute("Ostacolo", true)
			end
		end
	end

	local decorazioni = Instance.new("Folder")
	decorazioni.Name = "Decorazioni"
	decorazioni.Parent = modello
	-- Ostacoli sulle caselle bloccate, dettagli tra le caselle, poi tutto lo scenario attorno al campo.
	for _, t in ipairs(livello.terreno) do
		if Campagna.SOLIDI[t.tipo] then
			local x, z = centroCasella(t.col, t.riga)
			piano:ostacolo(decorazioni, x, z, t.tipo)
		end
	end
	piano:decoraTrincee(decorazioni)
	piano:dettagliCampo(decorazioni, function(x, z)
		local col = math.floor((x + META_CAMPO) / Arena.CASELLA) + 1
		local riga = math.floor((z + META_CAMPO) / Arena.CASELLA) + 1
		local tipo = arena.terreno[col .. "," .. riga]
		return Campagna.SOLIDI[tipo] or tipo == "trincea"
	end)
	piano:decora(decorazioni)
	for _, parte in ipairs(decorazioni:GetDescendants()) do
		if parte:IsA("BasePart") then
			local lato = math.max(parte.Size.X, parte.Size.Y, parte.Size.Z)
			if SOLIDI[parte.Material] and lato > 1.5 then
				parte.CanCollide = true
			end
			-- Le parti piccole (erba, sassi, frecce) non fanno ombra: migliaia di ombre minuscole costano
			-- e non si vedono.
			if lato < 2 then
				parte.CastShadow = false
			end
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
