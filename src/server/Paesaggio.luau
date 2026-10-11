-- Oggetti dei campi di battaglia, costruiti con parti: vegetazione, rocce e le cose dell'uomo di ogni epoca
-- (accampamenti, villaggi, rovine, trincee). Ogni costruttore riceve:
--   g = cartella dove mettere le parti, cf = CFrame a terra (posizione e direzione), rng = Random,
--   s = scala, ctx = { neve = bool }.
-- Misure in studs: un uomo è alto circa 4 studs (1 m = 2,34 studs).

local Paesaggio = {}

local C = Color3.fromRGB
local M = Enum.Material

-- Parti di base ----------------------------------------------------------------------------------

local function parte(g, size, cf, colore, materiale, classe)
	local p = Instance.new(classe or "Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = colore
	p.Material = materiale or M.SmoothPlastic
	p.Parent = g
	return p
end

local function palla(g, d, pos, colore, materiale)
	local p = parte(g, Vector3.one * d, CFrame.new(pos), colore, materiale)
	p.Shape = Enum.PartType.Ball
	return p
end

-- Ellissoide: una palla schiacciata (Ball non si deforma, quindi un cilindro corto con le punte tonde
-- non serve: si usa una sfera di mesh).
local function ovale(g, size, cf, colore, materiale)
	local p = parte(g, size, cf, colore, materiale)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- CFrame in centro che guarda verso dir, anche quando dir è verticale (lì lookAt con l'alto di default
-- non sa dove girarsi).
local function guarda(centro, dir)
	local alto = math.abs(dir.Unit.Y) > 0.99 and Vector3.xAxis or Vector3.yAxis
	return CFrame.lookAt(centro, centro + dir, alto)
end

-- Cilindro da a a b, diametro d (il cilindro di Roblox ha l'asse lungo X).
local function cilindro(g, a, b, d, colore, materiale)
	local lunghezza = (b - a).Magnitude
	local cf = guarda((a + b) / 2, b - a) * CFrame.Angles(0, math.pi / 2, 0)
	local p = parte(g, Vector3.new(lunghezza, d, d), cf, colore, materiale)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Trave da a a b (sezione l x h).
local function trave(g, a, b, l, h, colore, materiale)
	local lunghezza = (b - a).Magnitude
	return parte(g, Vector3.new(l, h, lunghezza), guarda((a + b) / 2, b - a), colore, materiale)
end

-- Cuneo con il lato alto verso cf.LookVector (la falda scende all'indietro). Il WedgePart di Roblox ha la
-- faccia inclinata verso -Z e il lato alto dietro (+Z): lo si gira. Se in Studio i tetti vengono a V,
-- è questo verso da invertire (ALTO_DIETRO = false), e tutti i tetti tornano giusti insieme.
local ALTO_DIETRO = true
local GIRA = CFrame.Angles(0, math.pi, 0)
local function cuneo(g, size, cf, colore, materiale)
	return parte(g, size, ALTO_DIETRO and cf * GIRA or cf, colore, materiale, "WedgePart")
end

-- Tetto a due falde sopra il rettangolo l x p (l lungo X), colmo alto h sopra cf.
local function tetto(g, cf, l, p, h, colore, materiale, sporge)
	sporge = sporge or 0.8
	local meta = p / 2 + sporge
	cuneo(g, Vector3.new(l + sporge * 2, h, meta), cf * CFrame.new(0, h / 2, -meta / 2) * CFrame.Angles(0, math.pi, 0), colore, materiale)
	cuneo(g, Vector3.new(l + sporge * 2, h, meta), cf * CFrame.new(0, h / 2, meta / 2), colore, materiale)
end

-- Cono fatto di cunei attorno a un asse (tetti di capanne e padiglioni).
local function cono(g, centro, raggio, altezza, colore, materiale, spicchi)
	spicchi = spicchi or 8
	local lato = 2 * raggio * math.tan(math.pi / spicchi) + 0.1
	for i = 0, spicchi - 1 do
		local a = i * 2 * math.pi / spicchi
		local cf = CFrame.new(centro) * CFrame.Angles(0, a, 0) * CFrame.new(0, altezza / 2, -raggio / 2)
		cuneo(g, Vector3.new(lato, altezza, raggio), cf * CFrame.Angles(0, math.pi, 0), colore, materiale)
	end
end

local function varia(colore, rng, quanto)
	local d = (rng:NextNumber() - 0.5) * 2 * (quanto or 0.08)
	return Color3.new(math.clamp(colore.R + d, 0, 1), math.clamp(colore.G + d, 0, 1), math.clamp(colore.B + d, 0, 1))
end

local function su(cf, y)
	return cf * CFrame.new(0, y, 0)
end

local P = {}
Paesaggio.oggetti = P

-- Raggio d'ingombro di ogni oggetto alla scala 1 (per non sovrapporli).
Paesaggio.ingombro = {}
local function ingombro(nome, r)
	Paesaggio.ingombro[nome] = r
end

-- Vegetazione ------------------------------------------------------------------------------------

local CORTECCIA = C(96, 70, 46)
local FOGLIE = C(66, 112, 48)

function P.quercia(g, cf, rng, s, ctx)
	local base = cf.Position
	local alto = 7 * s
	cilindro(g, base - Vector3.new(0, 1, 0), base + Vector3.new(0, alto, 0), 1.6 * s, varia(CORTECCIA, rng, 0.04), M.Wood)
	-- Rami principali e chioma a nuvole.
	local verde = varia(FOGLIE, rng, 0.06)
	for i = 1, 3 do
		local a = rng:NextNumber(0, 2 * math.pi)
		local fine = base + Vector3.new(math.cos(a) * 3.5 * s, alto + rng:NextNumber(1, 3) * s, math.sin(a) * 3.5 * s)
		cilindro(g, base + Vector3.new(0, alto * 0.75, 0), fine, 0.7 * s, CORTECCIA, M.Wood)
		palla(g, rng:NextNumber(5, 7) * s, fine + Vector3.new(0, 1.2 * s, 0), varia(verde, rng, 0.05), ctx.neve and M.Snow or M.Grass)
	end
	palla(g, 8 * s, base + Vector3.new(0, alto + 3 * s, 0), verde, ctx.neve and M.Snow or M.Grass)
	palla(g, 5.5 * s, base + Vector3.new(rng:NextNumber(-2, 2) * s, alto + 6 * s, rng:NextNumber(-2, 2) * s), varia(verde, rng, 0.05), M.Grass)
end
ingombro("quercia", 6)

function P.betulla(g, cf, rng, s, ctx)
	local base = cf.Position
	local alto = 10 * s
	cilindro(g, base - Vector3.new(0, 1, 0), base + Vector3.new(0, alto, 0), 0.8 * s, C(226, 222, 212), M.SmoothPlastic)
	for k = 1, 4 do
		local y = rng:NextNumber(1, alto * 0.8)
		parte(g, Vector3.new(0.86 * s, 0.25 * s, 0.86 * s), CFrame.new(base + Vector3.new(0, y, 0)), C(40, 38, 36))
	end
	local verde = ctx.neve and C(150, 140, 110) or varia(C(110, 150, 60), rng, 0.05)
	for k = 1, 4 do
		ovale(g, Vector3.new(4, 5.5, 4) * s, CFrame.new(base + Vector3.new(rng:NextNumber(-1.2, 1.2) * s, alto - 2 * s + k * 1.2 * s, rng:NextNumber(-1.2, 1.2) * s)), varia(verde, rng, 0.04), M.Grass)
	end
end
ingombro("betulla", 3)

function P.cipresso(g, cf, rng, s)
	local base = cf.Position
	cilindro(g, base - Vector3.new(0, 1, 0), base + Vector3.new(0, 3 * s, 0), 0.8 * s, CORTECCIA, M.Wood)
	local verde = varia(C(40, 74, 40), rng, 0.04)
	ovale(g, Vector3.new(3.2, 16, 3.2) * s, CFrame.new(base + Vector3.new(0, 10 * s, 0)), verde, M.Grass)
	ovale(g, Vector3.new(2.2, 6, 2.2) * s, CFrame.new(base + Vector3.new(0, 17 * s, 0)), verde, M.Grass)
end
ingombro("cipresso", 2.5)

function P.ulivo(g, cf, rng, s)
	local base = cf.Position
	-- Tronco nodoso e storto, due rami aperti, chioma bassa grigio-verde.
	local storto = base + Vector3.new(rng:NextNumber(-1, 1) * s, 3 * s, rng:NextNumber(-1, 1) * s)
	cilindro(g, base - Vector3.new(0, 0.5, 0), storto, 1.5 * s, C(110, 96, 78), M.Wood)
	local verde = varia(C(120, 132, 90), rng, 0.04)
	for i = 1, 3 do
		local a = i * 2.1 + rng:NextNumber(0, 1)
		local fine = storto + Vector3.new(math.cos(a) * 2.6 * s, 1.8 * s, math.sin(a) * 2.6 * s)
		cilindro(g, storto, fine, 0.6 * s, C(110, 96, 78), M.Wood)
		ovale(g, Vector3.new(5, 3, 5) * s, CFrame.new(fine + Vector3.new(0, 0.8 * s, 0)), varia(verde, rng, 0.04), M.Grass)
	end
	ovale(g, Vector3.new(6, 3.2, 6) * s, CFrame.new(storto + Vector3.new(0, 2.6 * s, 0)), verde, M.Grass)
end
ingombro("ulivo", 4)

function P.palma(g, cf, rng, s)
	-- Palma da dattero: tronco a segmenti un po' curvo, ciuffo di fronde che ricadono, grappoli.
	local base = cf.Position
	local piega = cf.LookVector * rng:NextNumber(0.5, 1.6) * s
	local punti = {}
	local n = 6
	for i = 0, n do
		local t = i / n
		punti[i] = base + Vector3.new(0, 13 * s * t, 0) + piega * t * t * 2
	end
	for i = 0, n - 1 do
		cilindro(g, punti[i], punti[i + 1] + (punti[i + 1] - punti[i]).Unit * 0.3, (1.3 - 0.06 * i) * s, C(128, 104, 74), M.Wood)
	end
	local cima = punti[n]
	local verde = C(82, 120, 52)
	for i = 0, 8 do
		local a = i * 2 * math.pi / 9 + rng:NextNumber(-0.2, 0.2)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local meta = cima + dir * 3.2 * s + Vector3.new(0, 1.0 * s, 0)
		local fine = cima + dir * 6.4 * s + Vector3.new(0, -1.6 * s, 0)
		trave(g, cima, meta, 1.5 * s, 0.2 * s, varia(verde, rng, 0.05), M.Grass)
		trave(g, meta, fine, 1.2 * s, 0.2 * s, varia(verde, rng, 0.05), M.Grass)
	end
	for i = 1, 3 do
		local a = i * 2.1
		palla(g, 1.0 * s, cima + Vector3.new(math.cos(a) * 0.9 * s, -0.9 * s, math.sin(a) * 0.9 * s), C(176, 108, 40))
	end
end
ingombro("palma", 3)

function P.tamerice(g, cf, rng, s)
	local base = cf.Position
	for i = 1, 3 do
		local a = rng:NextNumber(0, 2 * math.pi)
		local fine = base + Vector3.new(math.cos(a) * 1.5 * s, 4 * s, math.sin(a) * 1.5 * s)
		cilindro(g, base, fine, 0.45 * s, C(110, 86, 70), M.Wood)
		ovale(g, Vector3.new(3.4, 4, 3.4) * s, CFrame.new(fine + Vector3.new(0, 1 * s, 0)), varia(C(136, 140, 110), rng, 0.05), M.Grass)
	end
end
ingombro("tamerice", 3)

function P.cespuglio(g, cf, rng, s, ctx)
	local base = cf.Position
	local verde = ctx.neve and C(214, 222, 230) or varia(C(70, 108, 50), rng, 0.06)
	for i = 1, rng:NextInteger(3, 5) do
		ovale(g, Vector3.new(rng:NextNumber(2.2, 3.4), rng:NextNumber(1.6, 2.4), rng:NextNumber(2.2, 3.4)) * s,
			CFrame.new(base + Vector3.new(rng:NextNumber(-1.4, 1.4) * s, 0.7 * s, rng:NextNumber(-1.4, 1.4) * s)),
			varia(verde, rng, 0.04), ctx.neve and M.Snow or M.Grass)
	end
end
ingombro("cespuglio", 2)

function P.arbusto(g, cf, rng, s)
	-- Arbusto secco del deserto: rametti chiari a raggiera.
	local base = cf.Position
	for i = 1, 7 do
		local a = rng:NextNumber(0, 2 * math.pi)
		local fine = base + Vector3.new(math.cos(a) * 1.4 * s, rng:NextNumber(1, 2) * s, math.sin(a) * 1.4 * s)
		cilindro(g, base, fine, 0.16 * s, C(150, 128, 92), M.Wood)
	end
	ovale(g, Vector3.new(2.2, 1.1, 2.2) * s, CFrame.new(base + Vector3.new(0, 0.9 * s, 0)), varia(C(150, 146, 100), rng, 0.05), M.Grass)
end
ingombro("arbusto", 1.5)

-- Ciuffo d'erba: lame sottili inclinate (verde, o paglia secca).
function P.ciuffo(g, cf, rng, s, ctx)
	local base = cf.Position
	local colore = ctx.secco and C(190, 170, 110) or (ctx.neve and C(150, 150, 120) or C(96, 140, 60))
	for i = 1, 5 do
		local a = rng:NextNumber(0, 2 * math.pi)
		local alto = rng:NextNumber(1.2, 2.2) * s
		parte(g, Vector3.new(0.12, alto, 0.35) * Vector3.new(s, 1, s),
			CFrame.new(base + Vector3.new(0, alto / 2 - 0.2, 0)) * CFrame.Angles(0, a, rng:NextNumber(-0.35, 0.35)),
			varia(colore, rng, 0.06), M.Grass)
	end
end
ingombro("ciuffo", 0.8)

function P.fiori(g, cf, rng, s)
	local base = cf.Position
	local colori = { C(230, 210, 60), C(200, 40, 50), C(240, 240, 240), C(150, 90, 200) }
	local colore = colori[rng:NextInteger(1, #colori)]
	for i = 1, 6 do
		local p = base + Vector3.new(rng:NextNumber(-1.5, 1.5) * s, 0, rng:NextNumber(-1.5, 1.5) * s)
		cilindro(g, p, p + Vector3.new(0, 1.1 * s, 0), 0.1, C(80, 130, 60), M.Grass)
		palla(g, 0.45 * s, p + Vector3.new(0, 1.15 * s, 0), colore, M.SmoothPlastic)
	end
end
ingombro("fiori", 1.5)

function P.canne(g, cf, rng, s)
	local base = cf.Position
	for i = 1, 9 do
		local p = base + Vector3.new(rng:NextNumber(-2, 2) * s, -0.5, rng:NextNumber(-2, 2) * s)
		local alto = rng:NextNumber(4, 6) * s
		local cima = p + Vector3.new(rng:NextNumber(-0.4, 0.4), alto, rng:NextNumber(-0.4, 0.4))
		cilindro(g, p, cima, 0.18 * s, C(120, 140, 70), M.Grass)
		ovale(g, Vector3.new(0.35, 1.0, 0.35) * s, CFrame.new(cima), C(110, 80, 50), M.Fabric)
	end
end
ingombro("canne", 2.5)

function P.tronco(g, cf, rng, s)
	-- Tronco caduto con due monconi di rami.
	local a = cf.Position + cf.RightVector * 5 * s + Vector3.new(0, 0.6 * s, 0)
	local b = cf.Position - cf.RightVector * 5 * s + Vector3.new(0, 0.6 * s, 0)
	cilindro(g, a, b, 1.6 * s, CORTECCIA, M.Wood)
	cilindro(g, a - cf.RightVector * 2 * s, a - cf.RightVector * 3 * s + Vector3.new(0, 2 * s, 1 * s), 0.5 * s, CORTECCIA, M.Wood)
	parte(g, Vector3.new(0.2, 1.5, 1.5) * s, CFrame.lookAt(a, b) * CFrame.Angles(0, math.pi / 2, 0), C(170, 140, 100), M.Wood)
end
ingombro("tronco", 5)

function P.ceppo(g, cf, rng, s)
	cilindro(g, cf.Position - Vector3.new(0, 0.5, 0), cf.Position + Vector3.new(0, 1.2 * s, 0), 1.6 * s, CORTECCIA, M.Wood)
	parte(g, Vector3.new(1.4, 0.1, 1.4) * s, su(cf, 1.25 * s), C(176, 146, 104), M.Wood)
end
ingombro("ceppo", 1.2)

-- Albero spezzato dalle cannonate: tronco nudo e bruciato, monconi di rami.
function P.alberoSpezzato(g, cf, rng, s)
	local base = cf.Position
	local alto = rng:NextNumber(5, 9) * s
	local cima = base + Vector3.new(rng:NextNumber(-0.6, 0.6) * s, alto, rng:NextNumber(-0.6, 0.6) * s)
	cilindro(g, base - Vector3.new(0, 0.5, 0), cima, 1.2 * s, C(60, 50, 42), M.Wood)
	for i = 1, rng:NextInteger(1, 3) do
		local da = base:Lerp(cima, rng:NextNumber(0.5, 0.9))
		local a = rng:NextNumber(0, 2 * math.pi)
		cilindro(g, da, da + Vector3.new(math.cos(a) * 2 * s, rng:NextNumber(0.5, 1.5) * s, math.sin(a) * 2 * s), 0.4 * s, C(54, 46, 40), M.Wood)
	end
	cuneo(g, Vector3.new(1.2, 1.4, 1.2) * s, CFrame.new(cima + Vector3.new(0, 0.6 * s, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), C(70, 58, 46), M.Wood)
end
ingombro("alberoSpezzato", 1.5)

-- Abete: tronco e quattro palchi di rami sfalsati (con la neve sopra, d'inverno).
function P.pino(g, cf, rng, s, ctx)
	local base = cf.Position
	cilindro(g, base - Vector3.new(0, 1, 0), base + Vector3.new(0, 4 * s, 0), 1.0 * s, C(92, 62, 38), M.Wood)
	local verde = varia(C(38, 84, 54), rng, 0.04)
	for i = 0, 3 do
		local lato = (7 - i * 1.6) * s
		local livello = parte(g, Vector3.new(lato, 2.2 * s, lato), CFrame.new(base + Vector3.new(0, (3.4 + i * 2.0) * s, 0))
			* CFrame.Angles(0, math.rad(45 * i + rng:NextNumber(0, 20)), 0), verde, M.Grass)
		if ctx.neve then
			parte(g, Vector3.new(lato * 0.82, 0.5 * s, lato * 0.82), livello.CFrame * CFrame.new(0, 1.2 * s, 0), C(244, 247, 251), M.Snow)
		end
	end
	parte(g, Vector3.new(1.4, 2.2, 1.4) * s, CFrame.new(base + Vector3.new(0, 11.6 * s, 0)) * CFrame.Angles(0, 0.4, 0), verde, M.Grass)
end
ingombro("pino", 4)

-- Sassi sparsi.
function P.sassi(g, cf, rng, s, ctx)
	local colore = ctx.neve and C(170, 176, 186) or (ctx.sabbia and C(186, 154, 110) or C(130, 126, 118))
	for i = 1, rng:NextInteger(3, 6) do
		local d = rng:NextNumber(0.6, 1.6) * s
		parte(g, Vector3.new(d * rng:NextNumber(1, 1.6), d * 0.7, d), CFrame.new(cf.Position + Vector3.new(rng:NextNumber(-2, 2) * s, d * 0.15, rng:NextNumber(-2, 2) * s))
			* CFrame.Angles(rng:NextNumber(0, 0.6), rng:NextNumber(0, 3), rng:NextNumber(0, 0.6)), varia(colore, rng, 0.05), ctx.sabbia and M.Sandstone or M.Slate)
	end
end
ingombro("sassi", 1.5)

-- Resti di una battaglia sul terreno, dell'epoca (ctx.epoca): scudi, lance e frecce piantate, elmi, bossoli.
function P.resti(g, cf, rng, s, ctx)
	local base = cf.Position
	local epoca = ctx.epoca or "Antica"
	local function freccia(p, lunga)
		local dir = Vector3.new(rng:NextNumber(-0.4, 0.4), 1, rng:NextNumber(-0.6, 0.2)).Unit
		cilindro(g, p - dir * 0.3, p + dir * lunga, 0.1, C(150, 120, 80), M.Wood)
		parte(g, Vector3.new(0.05, 0.5, 0.3), CFrame.lookAt(p + dir * (lunga - 0.2), p + dir * lunga + Vector3.new(0, 0, 0.01)) * CFrame.Angles(math.pi / 2, 0, 0), C(230, 226, 214), M.Fabric)
	end
	if epoca == "Antica" then
		-- Scudo tondo rovesciato a terra, una lancia piantata storta, un elmo.
		local scudo = parte(g, Vector3.new(0.25, 3.6, 3.6) * s, cf * CFrame.new(rng:NextNumber(-1, 1) * s, 0.25, 0) * CFrame.Angles(0, rng:NextNumber(0, 3), math.pi / 2 + rng:NextNumber(-0.3, 0.3)), varia(C(150, 50, 36), rng, 0.08), M.Wood)
		scudo.Shape = Enum.PartType.Cylinder
		local p = base + Vector3.new(rng:NextNumber(-2, 2) * s, 0, rng:NextNumber(-2, 2) * s)
		local cima = p + Vector3.new(rng:NextNumber(-2, 2), 6 * s, rng:NextNumber(-2, 2))
		cilindro(g, p - Vector3.new(0, 0.6, 0), cima, 0.2 * s, C(130, 100, 64), M.Wood)
		parte(g, Vector3.new(0.25, 1.0, 0.25) * s, CFrame.lookAt(cima, cima + (cima - p).Unit) * CFrame.Angles(math.pi / 2, 0, 0), C(150, 150, 150), M.Metal)
		ovale(g, Vector3.new(1.2, 1.0, 1.4) * s, CFrame.new(base + Vector3.new(2 * s, 0.3, -1 * s)) * CFrame.Angles(0.3, 0, 0.4), C(170, 120, 60), M.Metal)
	elseif epoca == "Medievale" then
		-- Scudo a mandorla a terra e un ciuffo di frecce piantate.
		parte(g, Vector3.new(2.4, 0.2, 3.4) * s, cf * CFrame.new(rng:NextNumber(-1, 1) * s, 0.15, 0) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 3), 0), varia(C(40, 60, 130), rng, 0.08), M.WoodPlanks)
		for i = 1, rng:NextInteger(3, 6) do
			freccia(base + Vector3.new(rng:NextNumber(-2.5, 2.5) * s, 0, rng:NextNumber(-2.5, 2.5) * s), rng:NextNumber(1.6, 2.4))
		end
		local p = base + Vector3.new(-2 * s, 0.3, 1.5 * s)
		cilindro(g, p, p + Vector3.new(5 * s, 0.2, 1 * s), 0.25 * s, C(130, 100, 64), M.Wood)
	else
		-- Elmetto, fucile a terra, bossoli e una cassetta di munizioni sfondata.
		ovale(g, Vector3.new(1.5, 0.7, 1.7) * s, CFrame.new(base + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0.2, rng:NextNumber(0, 3), 0.3), C(84, 90, 70), M.Metal)
		parte(g, Vector3.new(0.25, 0.35, 4.2) * s, cf * CFrame.new(1.5 * s, 0.2, 0) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), C(70, 50, 34), M.Wood)
		for i = 1, 5 do
			cilindro(g, base + Vector3.new(rng:NextNumber(-2, 2) * s, 0.15, rng:NextNumber(-2, 2) * s), base + Vector3.new(rng:NextNumber(-2, 2) * s, 0.15, rng:NextNumber(-2, 2) * s) + Vector3.new(0.3, 0, 0), 0.15, C(200, 160, 70), M.Metal)
		end
		parte(g, Vector3.new(1.6, 0.8, 1.0) * s, cf * CFrame.new(-1.8 * s, 0.35, 1 * s) * CFrame.Angles(0, rng:NextNumber(0, 3), 0.2), C(96, 90, 60), M.WoodPlanks)
	end
end
ingombro("resti", 2.5)

-- Campo coltivato: una lastra bassa a strisce (grano maturo, o verde), con i solchi.
function P.campo(g, cf, rng, s, ctx)
	local l, p = 40 * s, 26 * s
	local colori = ctx.colori or { C(210, 180, 96), C(196, 164, 84) }
	local strisce = 6
	for i = 0, strisce - 1 do
		parte(g, Vector3.new(l, 1.3, p / strisce - 0.3), cf * CFrame.new(0, 0.2, -p / 2 + (i + 0.5) * p / strisce) * CFrame.Angles(rng:NextNumber(-0.02, 0.02), 0, 0), varia(colori[i % 2 + 1], rng, 0.03), M.Grass)
	end
end
ingombro("campo", 22)

function P.roccia(g, cf, rng, s, ctx)
	local colore = ctx.neve and C(196, 204, 214) or (ctx.sabbia and C(196, 160, 112) or C(122 + rng:NextInteger(-12, 12), 118, 110))
	for i = 1, 4 do
		local d = rng:NextNumber(2, 4) * s / i ^ 0.4
		parte(g, Vector3.new(d * rng:NextNumber(1, 1.5), d, d * rng:NextNumber(1, 1.4)),
			CFrame.new(cf.Position + Vector3.new(rng:NextNumber(-1.2, 1.2) * s, d * 0.3, rng:NextNumber(-1.2, 1.2) * s))
				* CFrame.Angles(rng:NextNumber(0, 0.5), rng:NextNumber(0, math.pi), rng:NextNumber(0, 0.5)),
			varia(colore, rng, 0.04), ctx.sabbia and M.Sandstone or M.Slate)
	end
end
ingombro("roccia", 3)

function P.masso(g, cf, rng, s, ctx)
	local colore = ctx.sabbia and C(186, 150, 104) or C(128, 124, 116)
	local d = rng:NextNumber(6, 9) * s
	parte(g, Vector3.new(d * 1.3, d * 0.8, d), CFrame.new(cf.Position + Vector3.new(0, d * 0.25, 0))
		* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 3), rng:NextNumber(-0.3, 0.3)), colore, ctx.sabbia and M.Sandstone or M.Slate)
	parte(g, Vector3.new(d * 0.6, d * 0.5, d * 0.7), CFrame.new(cf.Position + Vector3.new(d * 0.6, d * 0.1, d * 0.3))
		* CFrame.Angles(0.4, rng:NextNumber(0, 3), 0.2), varia(colore, rng, 0.04), ctx.sabbia and M.Sandstone or M.Slate)
	if ctx.neve then
		parte(g, Vector3.new(d * 1.1, 0.6, d * 0.8), CFrame.new(cf.Position + Vector3.new(0, d * 0.66, 0)), C(240, 244, 250), M.Snow)
	end
end
ingombro("masso", 7)

-- Antichità --------------------------------------------------------------------------------------

local TELA = C(214, 200, 168)
local CUOIO = C(120, 82, 48)
local LEGNO = C(120, 86, 52)
local PIETRA = C(198, 190, 172)

-- Tenda romana (papilio) di cuoio: due falde, i paletti, le corde.
function P.tendaRomana(g, cf, rng, s)
	local l, p, h = 8 * s, 7 * s, 5 * s
	tetto(g, cf * CFrame.new(0, 0.6, 0), l, p, h, varia(CUOIO, rng, 0.04), M.Fabric, 0.1)
	-- Pareti basse sui lati corti (triangoli).
	for _, segno in ipairs({ -1, 1 }) do
		local x = segno * l / 2
		for _, lato in ipairs({ -1, 1 }) do
			cuneo(g, Vector3.new(0.2, h, p / 2), cf * CFrame.new(x, 0.6 + h / 2, lato * p / 4) * CFrame.Angles(0, lato > 0 and 0 or math.pi, 0), varia(CUOIO, rng, 0.03), M.Fabric)
		end
		cilindro(g, (cf * CFrame.new(x, 0, 0)).Position, (cf * CFrame.new(x, h + 1.2, 0)).Position, 0.3, LEGNO, M.Wood)
	end
end
ingombro("tendaRomana", 6)

-- Padiglione tondo a strisce con la banderuola (persiani e medievali).
function P.padiglione(g, cf, rng, s, ctx)
	local colori = ctx.colori or { C(220, 210, 180), C(160, 40, 40) }
	local r, h = 5 * s, 5 * s
	local centro = cf.Position
	local spicchi = 12
	local lato = 2 * r * math.tan(math.pi / spicchi) + 0.05
	for i = 0, spicchi - 1 do
		local a = i * 2 * math.pi / spicchi
		parte(g, Vector3.new(lato, h, 0.25), CFrame.new(centro) * CFrame.Angles(0, a, 0) * CFrame.new(0, h / 2, -r), colori[i % 2 + 1], M.Fabric)
	end
	cono(g, centro + Vector3.new(0, h, 0), r + 0.6, 4 * s, colori[2], M.Fabric, spicchi)
	local cima = centro + Vector3.new(0, h + 4 * s, 0)
	cilindro(g, cima, cima + Vector3.new(0, 3 * s, 0), 0.25, LEGNO, M.Wood)
	cuneo(g, Vector3.new(0.1, 1.2 * s, 2.4 * s), CFrame.new(cima + Vector3.new(0, 2.4 * s, 1.2 * s)) * CFrame.Angles(0, 0, 0), colori[2], M.Fabric)
	-- Ingresso: un telo scuro davanti.
	parte(g, Vector3.new(2.6 * s, h * 0.8, 0.3), cf * CFrame.new(0, h * 0.4, -r - 0.1), C(60, 40, 30), M.Fabric)
end
ingombro("padiglione", 7)

-- Insegna: asta con traversa e drappo rosso (vexillum), o l'aquila.
function P.insegna(g, cf, rng, s, ctx)
	local base = cf.Position
	local cima = base + Vector3.new(0, 10 * s, 0)
	cilindro(g, base - Vector3.new(0, 0.5, 0), cima, 0.3 * s, LEGNO, M.Wood)
	cilindro(g, cima - cf.RightVector * 1.4 * s - Vector3.new(0, 0.6, 0), cima + cf.RightVector * 1.4 * s - Vector3.new(0, 0.6, 0), 0.2 * s, LEGNO, M.Wood)
	parte(g, Vector3.new(2.6 * s, 2.8 * s, 0.1), cf * CFrame.new(0, 10 * s - 2.2 * s, 0.1), ctx.drappo or C(170, 30, 30), M.Fabric)
	palla(g, 0.8 * s, cima + Vector3.new(0, 0.4 * s, 0), C(210, 170, 60), M.Metal)
end
ingombro("insegna", 1.5)

-- Fuoco da campo: cerchio di sassi, legna incrociata e la fiamma.
function P.fuoco(g, cf, rng, s)
	local base = cf.Position
	for i = 0, 7 do
		local a = i * math.pi / 4
		palla(g, 0.9 * s, base + Vector3.new(math.cos(a) * 1.6 * s, 0.2, math.sin(a) * 1.6 * s), C(110, 106, 100), M.Slate)
	end
	for i = 0, 2 do
		local a = i * math.pi / 3
		local d = Vector3.new(math.cos(a), 0, math.sin(a)) * 1.2 * s
		cilindro(g, base - d + Vector3.new(0, 0.2, 0), base + d + Vector3.new(0, 0.5, 0), 0.4 * s, C(70, 50, 34), M.Wood)
	end
	local brace = palla(g, 1.0 * s, base + Vector3.new(0, 0.3, 0), C(255, 120, 40), M.Neon)
	local fuoco = Instance.new("Fire")
	fuoco.Size = 4 * s
	fuoco.Heat = 6
	fuoco.Parent = brace
	local luce = Instance.new("PointLight")
	luce.Color = C(255, 160, 80)
	luce.Range = 16
	luce.Brightness = 1.5
	luce.Parent = brace
end
ingombro("fuoco", 2)

function P.anfore(g, cf, rng, s)
	for i = 1, rng:NextInteger(3, 6) do
		local p = cf.Position + Vector3.new(rng:NextNumber(-1.6, 1.6) * s, 0, rng:NextNumber(-1.6, 1.6) * s)
		ovale(g, Vector3.new(1.2, 2.2, 1.2) * s, CFrame.new(p + Vector3.new(0, 1.0 * s, 0)), varia(C(176, 100, 60), rng, 0.05), M.Slate)
		cilindro(g, p + Vector3.new(0, 1.9 * s, 0), p + Vector3.new(0, 2.6 * s, 0), 0.45 * s, C(170, 96, 58), M.Slate)
	end
end
ingombro("anfore", 2.5)

-- Carro a due ruote con il carico coperto.
function P.carro(g, cf, rng, s)
	local cassa = cf * CFrame.new(0, 2.4 * s, 0)
	parte(g, Vector3.new(4.5, 0.4, 7) * s, cassa, LEGNO, M.WoodPlanks)
	for _, x in ipairs({ -2.2, 2.2 }) do
		parte(g, Vector3.new(0.3, 1.4, 7) * s, cassa * CFrame.new(x * s, 0.7 * s, 0), LEGNO, M.WoodPlanks)
		local ruota = parte(g, Vector3.new(0.4 * s, 4 * s, 4 * s), cf * CFrame.new(x * s * 1.15, 2 * s, 0.5 * s), C(90, 64, 40), M.Wood)
		ruota.Shape = Enum.PartType.Cylinder
	end
	ovale(g, Vector3.new(4.2, 2.6, 6) * s, cassa * CFrame.new(0, 1.2 * s, 0), TELA, M.Fabric)
	trave(g, (cassa * CFrame.new(0, -0.3 * s, -3.5 * s)).Position, (cf * CFrame.new(0, 0.6, -8 * s)).Position, 0.4 * s, 0.4 * s, LEGNO, M.Wood)
end
ingombro("carro", 5)

-- Carro falcato persiano rovesciato, con una ruota staccata.
function P.carroFalcato(g, cf, rng, s)
	local cassa = cf * CFrame.new(0, 1.2 * s, 0) * CFrame.Angles(0, 0, 1.2)
	parte(g, Vector3.new(3.5, 2.4, 3) * s, cassa, C(150, 110, 60), M.WoodPlanks)
	local ruota = parte(g, Vector3.new(0.4 * s, 4.4 * s, 4.4 * s), cf * CFrame.new(-2.6 * s, 2.2 * s, 0), C(96, 70, 44), M.Wood)
	ruota.Shape = Enum.PartType.Cylinder
	local staccata = parte(g, Vector3.new(0.4 * s, 4.4 * s, 4.4 * s), cf * CFrame.new(3.5 * s, 0.3, 2.5 * s) * CFrame.Angles(0, 0, math.pi / 2), C(96, 70, 44), M.Wood)
	staccata.Shape = Enum.PartType.Cylinder
	-- La falce di ferro sul mozzo e il timone spezzato.
	parte(g, Vector3.new(0.15, 0.4, 3.4) * s, cf * CFrame.new(-3 * s, 2.2 * s, 1.6 * s) * CFrame.Angles(0.4, 0, 0), C(150, 150, 154), M.Metal)
	trave(g, (cf * CFrame.new(0, 0.5, -1.5 * s)).Position, (cf * CFrame.new(0.5 * s, 0.3, -6 * s)).Position, 0.4 * s, 0.4 * s, C(110, 80, 50), M.Wood)
end
ingombro("carroFalcato", 5)

-- Palizzata: pali appuntiti uno accanto all'altro, lungo cf.RightVector, lunga l.
function P.palizzata(g, cf, rng, s, ctx)
	local l = ctx.lunghezza or 24
	local n = math.max(2, math.floor(l / (1.1 * s)))
	for i = 0, n - 1 do
		local x = -l / 2 + (i + 0.5) * l / n
		local alto = rng:NextNumber(6.5, 7.5) * s
		local p = cf * CFrame.new(x, 0, 0)
		cilindro(g, p.Position - Vector3.new(0, 1, 0), p.Position + Vector3.new(0, alto, 0), 1.0 * s, varia(LEGNO, rng, 0.05), M.Wood)
		cuneo(g, Vector3.new(0.9, 1.0, 0.9) * s, p * CFrame.new(0, alto + 0.5 * s, 0), varia(LEGNO, rng, 0.05), M.Wood)
	end
	trave(g, (cf * CFrame.new(-l / 2, 4 * s, -0.6 * s)).Position, (cf * CFrame.new(l / 2, 4 * s, -0.6 * s)).Position, 0.5 * s, 0.6 * s, C(100, 72, 44), M.Wood)
end
ingombro("palizzata", 3)

-- Torre di guardia di legno: quattro pali, piattaforma con il parapetto, tettuccio.
function P.torre(g, cf, rng, s)
	local h, l = 16 * s, 5 * s
	for _, x in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -1, 1 }) do
			local p = cf * CFrame.new(x * l / 2, 0, z * l / 2)
			cilindro(g, p.Position - Vector3.new(0, 1, 0), p.Position + Vector3.new(0, h + 4 * s, 0), 0.8 * s, LEGNO, M.Wood)
		end
	end
	parte(g, Vector3.new(l + 1, 0.6, l + 1), cf * CFrame.new(0, h, 0), C(110, 80, 50), M.WoodPlanks)
	for k = 0, 3 do
		parte(g, Vector3.new(l + 1, 2 * s, 0.4), cf * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, h + 1.3 * s, (l + 1) / 2), C(126, 92, 58), M.WoodPlanks)
	end
	tetto(g, cf * CFrame.new(0, h + 4 * s, 0), l + 1, l + 1, 2.5 * s, C(90, 70, 50), M.WoodPlanks, 0.6)
	-- Croci di rinforzo.
	trave(g, (cf * CFrame.new(-l / 2, 1, -l / 2)).Position, (cf * CFrame.new(l / 2, h, -l / 2)).Position, 0.4, 0.4, LEGNO, M.Wood)
	trave(g, (cf * CFrame.new(l / 2, 1, l / 2)).Position, (cf * CFrame.new(-l / 2, h, l / 2)).Position, 0.4, 0.4, LEGNO, M.Wood)
end
ingombro("torre", 5)

-- Rovina classica: colonne spezzate, un architrave caduto, blocchi.
function P.rovina(g, cf, rng, s)
	for i = 0, 3 do
		local p = cf * CFrame.new((i - 1.5) * 5 * s, 0, 0)
		local alto = rng:NextNumber(3, 12) * s
		cilindro(g, p.Position - Vector3.new(0, 0.5, 0), p.Position + Vector3.new(0, alto, 0), 2 * s, varia(PIETRA, rng, 0.03), M.Marble)
		parte(g, Vector3.new(2.8, 0.8, 2.8) * s, p * CFrame.new(0, 0.2, 0), PIETRA, M.Marble)
	end
	parte(g, Vector3.new(9, 1.6, 2.2) * s, cf * CFrame.new(3 * s, 0.6 * s, 4 * s) * CFrame.Angles(0, 0.4, 0.12), varia(PIETRA, rng, 0.03), M.Marble)
	for i = 1, 4 do
		parte(g, Vector3.new(2, 1.4, 1.6) * s, cf * CFrame.new(rng:NextNumber(-8, 8) * s, 0.5 * s, rng:NextNumber(-4, 6) * s) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), varia(PIETRA, rng, 0.05), M.Marble)
	end
end
ingombro("rovina", 11)

-- Capanna gallica tonda: muro di graticcio e tetto conico di paglia.
function P.capanna(g, cf, rng, s, ctx)
	local r, h = 5 * s, 4 * s
	local centro = cf.Position
	local spicchi = 10
	local lato = 2 * r * math.tan(math.pi / spicchi) + 0.1
	for i = 0, spicchi - 1 do
		local a = i * 2 * math.pi / spicchi
		parte(g, Vector3.new(lato, h, 0.6), CFrame.new(centro) * CFrame.Angles(0, a, 0) * CFrame.new(0, h / 2 - 0.5, -r), varia(C(176, 150, 112), rng, 0.03), M.Cobblestone)
	end
	cono(g, centro + Vector3.new(0, h - 0.5, 0), r + 1.2, 6 * s, ctx.neve and C(236, 240, 246) or C(176, 150, 86), ctx.neve and M.Snow or M.Grass, spicchi)
	parte(g, Vector3.new(2.4 * s, 3.2 * s, 0.4), cf * CFrame.new(0, 1.3 * s, -r - 0.3), C(70, 50, 34), M.WoodPlanks)
end
ingombro("capanna", 6.5)

-- Muretto a secco.
function P.muretto(g, cf, rng, s, ctx)
	local l = ctx.lunghezza or 20
	local n = math.max(2, math.floor(l / (2.4 * s)))
	for i = 0, n - 1 do
		local x = -l / 2 + (i + 0.5) * l / n
		parte(g, Vector3.new(2.6, rng:NextNumber(2.2, 3), 1.8) * s, cf * CFrame.new(x, 0.9 * s, 0) * CFrame.Angles(rng:NextNumber(-0.1, 0.1), rng:NextNumber(-0.15, 0.15), 0), varia(C(150, 144, 130), rng, 0.05), M.Slate)
	end
end
ingombro("muretto", 2)

-- Tumulo funerario coperto d'erba (il Soros di Maratona).
function P.tumulo(g, cf, rng, s, ctx)
	ovale(g, Vector3.new(30, 12, 30) * s, CFrame.new(cf.Position + Vector3.new(0, 0, 0)), ctx.secco and C(170, 160, 110) or C(96, 130, 64), M.Grass)
end
ingombro("tumulo", 15)

-- Medioevo ---------------------------------------------------------------------------------------

local INTONACO = C(214, 200, 170)
local PAGLIA = C(186, 156, 92)

-- Casa di campagna: muri di graticcio, travi scure, tetto di paglia, porta e finestra.
function P.casa(g, cf, rng, s, ctx)
	local l, p, h = 14 * s, 9 * s, 6 * s
	parte(g, Vector3.new(l, h, p), cf * CFrame.new(0, h / 2 - 0.5, 0), varia(INTONACO, rng, 0.03), M.Plaster)
	for _, x in ipairs({ -l / 2, -l / 6, l / 6, l / 2 }) do
		parte(g, Vector3.new(0.6, h, 0.3), cf * CFrame.new(x, h / 2 - 0.5, -p / 2 - 0.1), C(70, 50, 34), M.Wood)
	end
	parte(g, Vector3.new(l + 0.4, 0.6, 0.3), cf * CFrame.new(0, h - 0.6, -p / 2 - 0.1), C(70, 50, 34), M.Wood)
	parte(g, Vector3.new(2.4 * s, 4 * s, 0.3), cf * CFrame.new(-l / 3, 2 * s - 0.5, -p / 2 - 0.15), C(80, 56, 36), M.WoodPlanks)
	parte(g, Vector3.new(2 * s, 1.6 * s, 0.3), cf * CFrame.new(l / 3, 3.6 * s, -p / 2 - 0.15), C(40, 34, 30), M.SmoothPlastic)
	tetto(g, cf * CFrame.new(0, h - 0.5, 0), l, p, 6 * s, ctx.neve and C(236, 240, 246) or varia(PAGLIA, rng, 0.04), ctx.neve and M.Snow or M.Grass, 1.2)
	-- Camino di pietra.
	parte(g, Vector3.new(1.6, 4, 1.6) * s, cf * CFrame.new(l / 2 - 2 * s, h + 3.5 * s, 1.5 * s), C(130, 124, 116), M.Cobblestone)
end
ingombro("casa", 9)

-- Mulino a vento su un pilastro (da qui Edoardo III guardò Crécy).
function P.mulino(g, cf, rng, s)
	local h = 14 * s
	cilindro(g, cf.Position - Vector3.new(0, 1, 0), cf.Position + Vector3.new(0, h * 0.5, 0), 3 * s, C(110, 80, 50), M.Wood)
	local corpo = cf * CFrame.new(0, h * 0.5 + 4 * s, 0)
	parte(g, Vector3.new(7, 8, 7) * s, corpo, C(150, 112, 70), M.WoodPlanks)
	tetto(g, corpo * CFrame.new(0, 4 * s, 0), 7 * s, 7 * s, 3.5 * s, C(110, 76, 46), M.WoodPlanks, 0.4)
	local mozzo = (corpo * CFrame.new(0, 1.5 * s, -4 * s)).Position
	palla(g, 1.2 * s, mozzo, C(80, 60, 40), M.Wood)
	for k = 0, 3 do
		local a = k * math.pi / 2 + 0.4
		local dir = corpo.RightVector * math.cos(a) + corpo.UpVector * math.sin(a)
		local pala = parte(g, Vector3.new(2.6 * s, 0.2, 9 * s), CFrame.lookAt(mozzo + dir * 5.5 * s, mozzo + dir * 10 * s, cf.LookVector), C(222, 210, 180), M.Fabric)
		pala.CFrame = pala.CFrame * CFrame.new(0, 0, 0)
		trave(g, mozzo, mozzo + dir * 10 * s, 0.4 * s, 0.4 * s, C(90, 66, 40), M.Wood)
	end
	-- Scala d'accesso.
	trave(g, (corpo * CFrame.new(0, -4 * s, 3.5 * s)).Position, (cf * CFrame.new(0, 0, 10 * s)).Position, 1.6 * s, 0.3, C(100, 74, 46), M.WoodPlanks)
end
ingombro("mulino", 8)

function P.pagliaio(g, cf, rng, s, ctx)
	local colore = ctx.neve and C(230, 234, 240) or varia(C(206, 176, 100), rng, 0.04)
	ovale(g, Vector3.new(6, 7, 6) * s, CFrame.new(cf.Position + Vector3.new(0, 2.6 * s, 0)), colore, ctx.neve and M.Snow or M.Grass)
	cilindro(g, cf.Position, cf.Position + Vector3.new(0, 7 * s, 0), 0.3, C(100, 74, 46), M.Wood)
end
ingombro("pagliaio", 3.5)

-- Staccionata di pali e traverse, lunga l.
function P.staccionata(g, cf, rng, s, ctx)
	local l = ctx.lunghezza or 24
	local n = math.max(2, math.floor(l / (4 * s)))
	for i = 0, n do
		local p = cf * CFrame.new(-l / 2 + i * l / n, 0, 0)
		cilindro(g, p.Position - Vector3.new(0, 0.5, 0), p.Position + Vector3.new(0, 3 * s, 0), 0.45 * s, C(120, 92, 60), M.Wood)
	end
	for _, y in ipairs({ 1.4, 2.5 }) do
		trave(g, (cf * CFrame.new(-l / 2, y * s, 0)).Position, (cf * CFrame.new(l / 2, y * s, 0)).Position, 0.3 * s, 0.35 * s, C(132, 100, 66), M.Wood)
	end
end
ingombro("staccionata", 2)

-- Chiesetta di pietra con il campanile.
function P.chiesa(g, cf, rng, s, ctx)
	local l, p, h = 12 * s, 22 * s, 9 * s
	parte(g, Vector3.new(l, h, p), cf * CFrame.new(0, h / 2 - 0.5, 0), C(186, 176, 156), M.Cobblestone)
	tetto(g, cf * CFrame.new(0, h - 0.5, 0) * CFrame.Angles(0, math.pi / 2, 0), p, l, 6 * s, ctx.neve and C(236, 240, 246) or C(110, 70, 56), ctx.neve and M.Snow or M.Slate, 0.8)
	local torre = cf * CFrame.new(0, 0, -p / 2 - 3 * s)
	parte(g, Vector3.new(6, 20, 6) * s, torre * CFrame.new(0, 10 * s - 0.5, 0), C(176, 166, 146), M.Cobblestone)
	cono(g, (torre * CFrame.new(0, 20 * s - 0.5, 0)).Position, 4.6 * s, 9 * s, C(80, 80, 90), M.Slate, 4)
	parte(g, Vector3.new(3 * s, 5 * s, 0.4), cf * CFrame.new(0, 2.5 * s - 0.5, -p / 2 - 6.1 * s), C(80, 56, 36), M.WoodPlanks)
	for _, z in ipairs({ -p / 4, 0, p / 4 }) do
		parte(g, Vector3.new(0.4, 3 * s, 1.4 * s), cf * CFrame.new(l / 2 + 0.1, h * 0.6, z), C(40, 40, 50), M.SmoothPlastic)
	end
end
ingombro("chiesa", 14)

function P.pozzo(g, cf, rng, s)
	local base = cf.Position
	for i = 0, 9 do
		local a = i * math.pi / 5
		parte(g, Vector3.new(1.5, 2.6, 0.8) * s, CFrame.new(base) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.9 * s, -2 * s), C(150, 144, 130), M.Cobblestone)
	end
	for _, x in ipairs({ -2.2, 2.2 }) do
		cilindro(g, base + cf.RightVector * x * s, base + cf.RightVector * x * s + Vector3.new(0, 5.5 * s, 0), 0.4 * s, LEGNO, M.Wood)
	end
	tetto(g, cf * CFrame.new(0, 5.5 * s, 0), 5 * s, 4 * s, 1.6 * s, C(110, 76, 46), M.WoodPlanks, 0.3)
end
ingombro("pozzo", 3)

function P.botti(g, cf, rng, s)
	for i = 1, rng:NextInteger(2, 5) do
		local p = cf.Position + Vector3.new(rng:NextNumber(-2, 2) * s, 0, rng:NextNumber(-2, 2) * s)
		cilindro(g, p, p + Vector3.new(0, 2.6 * s, 0), 2 * s, C(130, 90, 54), M.WoodPlanks)
		for _, y in ipairs({ 0.4, 2.2 }) do
			cilindro(g, p + Vector3.new(0, y * s, 0), p + Vector3.new(0, y * s + 0.2, 0), 2.08 * s, C(70, 70, 74), M.Metal)
		end
	end
end
ingombro("botti", 2.5)

-- Fila di pavesi (grandi scudi da balestriere) piantati a terra.
function P.pavesi(g, cf, rng, s, ctx)
	local colori = ctx.colori or { C(30, 60, 140), C(200, 170, 40) }
	for i = -2, 2 do
		local p = cf * CFrame.new(i * 2.6 * s, 2.4 * s, 0) * CFrame.Angles(-0.2, 0, 0)
		parte(g, Vector3.new(2.4, 4.6, 0.3) * s, p, colori[(i + 3) % 2 + 1], M.WoodPlanks)
		parte(g, Vector3.new(0.5, 4.6, 0.35) * s, p * CFrame.new(0, 0, -0.05), colori[(i + 4) % 2 + 1], M.WoodPlanks)
	end
end
ingombro("pavesi", 7)

-- Pali appuntiti degli arcieri inglesi, piantati inclinati verso il nemico.
function P.paliArcieri(g, cf, rng, s, ctx)
	local l = ctx.lunghezza or 20
	for i = 0, math.floor(l / (1.6 * s)) do
		local p = cf * CFrame.new(-l / 2 + i * 1.6 * s + rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-1, 1) * s)
		local cima = (p * CFrame.new(0, 3.6 * s, -2.4 * s)).Position
		cilindro(g, p.Position - Vector3.new(0, 0.4, 0), cima, 0.45 * s, varia(C(140, 108, 70), rng, 0.04), M.Wood)
	end
end
ingombro("paliArcieri", 3)

-- Ponte di legno su cavalletti (Stamford Bridge): lungo cf.LookVector, l studs.
function P.ponte(g, cf, rng, s, ctx)
	local l = ctx.lunghezza or 30
	local larghezza = 7 * s
	parte(g, Vector3.new(larghezza, 0.8, l), cf * CFrame.new(0, 2.6, 0), C(120, 90, 58), M.WoodPlanks)
	for z = -l / 2, l / 2, 6 do
		for _, x in ipairs({ -larghezza / 2 + 0.4, larghezza / 2 - 0.4 }) do
			local p = cf * CFrame.new(x, 0, z)
			cilindro(g, p.Position - Vector3.new(0, 4, 0), p.Position + Vector3.new(0, 5.6, 0), 0.8, C(90, 66, 42), M.Wood)
		end
	end
	for _, x in ipairs({ -larghezza / 2 + 0.4, larghezza / 2 - 0.4 }) do
		trave(g, (cf * CFrame.new(x, 5, -l / 2)).Position, (cf * CFrame.new(x, 5, l / 2)).Position, 0.4, 0.4, C(130, 100, 66), M.Wood)
	end
end
ingombro("ponte", 6)

-- Tratto di mura merlate con una torre tonda (Orléans, Cartagine).
function P.mura(g, cf, rng, s, ctx)
	local l = ctx.lunghezza or 60
	local h = 16 * s
	local colore = ctx.pietra or C(176, 166, 146)
	parte(g, Vector3.new(l, h, 5 * s), cf * CFrame.new(0, h / 2 - 1, 0), colore, M.Cobblestone)
	for x = -l / 2 + 1.5, l / 2 - 1.5, 3.2 * s do
		parte(g, Vector3.new(1.8 * s, 2.2 * s, 5 * s), cf * CFrame.new(x, h + 1.1 * s - 1, 0), colore, M.Cobblestone)
	end
	for _, x in ipairs({ -l / 2, l / 2 }) do
		local p = cf * CFrame.new(x, 0, 0)
		local t = parte(g, Vector3.new(h * 1.5, 11 * s, 11 * s), CFrame.new(p.Position + Vector3.new(0, h * 0.75 - 1, 0)) * CFrame.Angles(0, 0, math.pi / 2), colore, M.Cobblestone)
		t.Shape = Enum.PartType.Cylinder
		cono(g, p.Position + Vector3.new(0, h * 1.5 - 1, 0), 6.5 * s, 9 * s, ctx.neve and C(236, 240, 246) or C(70, 74, 92), M.Slate, 8)
	end
	-- Porta ad arco (scura).
	parte(g, Vector3.new(6 * s, 9 * s, 5.4 * s), cf * CFrame.new(0, 4.5 * s - 1, 0), C(40, 32, 26), M.WoodPlanks)
end
ingombro("mura", 30)

-- Novecento ---------------------------------------------------------------------------------------

local SACCO = C(168, 150, 110)
local KAKI = C(92, 96, 64)

-- Muretto di sacchetti di sabbia a file sfalsate, lungo l.
function P.sacchetti(g, cf, rng, s, ctx)
	local l = ctx.lunghezza or 14
	for fila = 0, 2 do
		local scarto = (fila % 2) * 0.9 * s
		local n = math.floor(l / (1.8 * s))
		for i = 0, n - 1 do
			local x = -l / 2 + scarto + i * 1.8 * s
			if x < l / 2 - 0.9 * s then
				ovale(g, Vector3.new(1.9, 0.9, 1.2) * s, cf * CFrame.new(x + 0.9 * s, (0.4 + fila * 0.8) * s, 0) * CFrame.Angles(0, rng:NextNumber(-0.08, 0.08), 0), varia(SACCO, rng, 0.05), M.Fabric)
			end
		end
	end
end
ingombro("sacchetti", 2)

-- Reticolato di filo spinato su cavalletti a X, lungo l.
function P.filoSpinato(g, cf, rng, s, ctx)
	local l = ctx.lunghezza or 24
	local n = math.max(2, math.floor(l / (5 * s)))
	for i = 0, n do
		local p = cf * CFrame.new(-l / 2 + i * l / n, 0, 0)
		for _, segno in ipairs({ -1, 1 }) do
			trave(g, (p * CFrame.new(0, 0, -1.4 * s * segno)).Position, (p * CFrame.new(0, 3.2 * s, 1.4 * s * segno)).Position, 0.3, 0.3, C(90, 74, 56), M.Wood)
		end
	end
	for _, y in ipairs({ 0.8, 1.8, 2.8 }) do
		for _, z in ipairs({ -0.8, 0.8 }) do
			trave(g, (cf * CFrame.new(-l / 2, y * s, z * s)).Position, (cf * CFrame.new(l / 2, y * s, z * s)).Position, 0.08, 0.08, C(70, 66, 62), M.Metal)
		end
	end
	-- Spirali (anelli) sopra.
	for x = -l / 2 + 1, l / 2 - 1, 2 do
		local anello = parte(g, Vector3.new(0.08, 2 * s, 2 * s), cf * CFrame.new(x, 2 * s, 0), C(80, 76, 72), M.Metal)
		anello.Shape = Enum.PartType.Cylinder
		anello.Transparency = 0.2
	end
end
ingombro("filoSpinato", 2.5)

-- Riccio cèco: tre travi d'acciaio incrociate.
function P.riccio(g, cf, rng, s)
	local centro = cf.Position + Vector3.new(0, 1.6 * s, 0)
	local assi = { Vector3.new(1, 1, 0), Vector3.new(0, 1, 1), Vector3.new(-1, 1, -1) }
	for _, a in ipairs(assi) do
		local d = (cf:VectorToWorldSpace(a)).Unit * 2.6 * s
		trave(g, centro - d, centro + d, 0.5 * s, 0.5 * s, C(70, 66, 62), M.CorrodedMetal)
	end
end
ingombro("riccio", 2.5)

-- Casa di mattoni sventrata: muri con buchi, un tetto crollato, macerie.
function P.casaDiroccata(g, cf, rng, s, ctx)
	local l, p, h = 16 * s, 12 * s, 10 * s
	local colore = ctx.pietra or C(160, 120, 96)
	local muro = function(cfMuro, lunghezza, alto)
		-- Un muro a pezzi: colonne di altezza diversa (il profilo spezzato) con una finestra vuota.
		local pezzi = 6
		for i = 0, pezzi - 1 do
			local x = -lunghezza / 2 + (i + 0.5) * lunghezza / pezzi
			local a = alto * rng:NextNumber(0.35, 1)
			if i ~= 2 or rng:NextNumber() < 0.4 then
				parte(g, Vector3.new(lunghezza / pezzi + 0.05, a, 1 * s), cfMuro * CFrame.new(x, a / 2 - 0.5, 0), varia(colore, rng, 0.03), M.Brick)
			end
		end
	end
	muro(cf * CFrame.new(0, 0, -p / 2), l, h)
	muro(cf * CFrame.new(0, 0, p / 2), l, h * 0.7)
	muro(cf * CFrame.new(-l / 2, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), p, h)
	-- Travi del tetto cadute e macerie.
	for i = 1, 3 do
		trave(g, (cf * CFrame.new(rng:NextNumber(-l / 2, l / 2), h * 0.8, -p / 2)).Position, (cf * CFrame.new(rng:NextNumber(-l / 2, l / 2), 0.5, rng:NextNumber(0, p / 2))).Position, 0.7 * s, 0.7 * s, C(70, 54, 40), M.Wood)
	end
	for i = 1, 8 do
		parte(g, Vector3.new(rng:NextNumber(1, 3), rng:NextNumber(0.6, 1.6), rng:NextNumber(1, 3)) * s, cf * CFrame.new(rng:NextNumber(-l / 2, l / 2 + 4), 0.3 * s, rng:NextNumber(-p / 2, p / 2 + 4)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 3), rng:NextNumber(-0.4, 0.4)), varia(colore, rng, 0.06), M.Brick)
	end
	if ctx.neve then
		parte(g, Vector3.new(l, 0.6, p), cf * CFrame.new(0, 0.1, 0), C(236, 240, 246), M.Snow)
	end
end
ingombro("casaDiroccata", 11)

-- Palo del telegrafo con i fili (si ripete lungo una strada).
function P.palo(g, cf, rng, s)
	local cima = cf.Position + Vector3.new(0, 14 * s, 0)
	cilindro(g, cf.Position - Vector3.new(0, 1, 0), cima, 0.7 * s, C(92, 70, 50), M.Wood)
	trave(g, cima - cf.RightVector * 2.2 * s - Vector3.new(0, 1, 0), cima + cf.RightVector * 2.2 * s - Vector3.new(0, 1, 0), 0.3, 0.4, C(92, 70, 50), M.Wood)
end
ingombro("palo", 1)

-- Cannone da campagna da 75 con lo scudo, le ruote e la coda a terra.
function P.cannone(g, cf, rng, s, ctx)
	local colore = ctx.colore or C(108, 112, 92)
	local asse = cf * CFrame.new(0, 2.4 * s, 0)
	for _, x in ipairs({ -2.4, 2.4 }) do
		local ruota = parte(g, Vector3.new(0.5 * s, 4.6 * s, 4.6 * s), asse * CFrame.new(x * s, 0, 0), C(80, 64, 46), M.Wood)
		ruota.Shape = Enum.PartType.Cylinder
	end
	parte(g, Vector3.new(4.4, 3.4, 0.25) * s, asse * CFrame.new(0, 1.4 * s, -0.8 * s), colore, M.Metal)
	cilindro(g, (asse * CFrame.new(0, 0.6 * s, 1.5 * s)).Position, (asse * CFrame.new(0, 0.9 * s, -6.5 * s)).Position, 0.7 * s, C(70, 72, 66), M.Metal)
	trave(g, (asse * CFrame.new(0, -0.4 * s, 0.5 * s)).Position, (cf * CFrame.new(0, 0.4, 7 * s)).Position, 0.8 * s, 0.6 * s, colore, M.Metal)
	-- Casse di munizioni accanto.
	for i = 1, 3 do
		parte(g, Vector3.new(1.6, 1, 2.4) * s, cf * CFrame.new(4 * s + i * 0.3, (i - 0.5) * 1.0 * s, 3 * s) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), C(110, 96, 64), M.WoodPlanks)
	end
end
ingombro("cannone", 6)

function P.casse(g, cf, rng, s)
	for i = 1, rng:NextInteger(3, 6) do
		parte(g, Vector3.new(2.2, 1.4, 1.6) * s, cf * CFrame.new(rng:NextNumber(-2, 2) * s, 0.7 * s + (i > 3 and 1.4 * s or 0), rng:NextNumber(-1.5, 1.5) * s) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), varia(C(120, 104, 70), rng, 0.04), M.WoodPlanks)
	end
end
ingombro("casse", 2.5)

-- Carro armato distrutto: scafo inclinato, torretta girata, cingolo srotolato, annerito.
function P.relitto(g, cf, rng, s, ctx)
	local colore = ctx.colore or C(84, 80, 62)
	local scafo = cf * CFrame.new(0, 2.2 * s, 0) * CFrame.Angles(0.06, 0, 0.1)
	parte(g, Vector3.new(7, 3, 13) * s, scafo, colore, M.CorrodedMetal)
	for _, x in ipairs({ -4, 4 }) do
		parte(g, Vector3.new(1.6, 3.2, 14) * s, scafo * CFrame.new(x * s, -0.6 * s, 0), C(46, 44, 40), M.CorrodedMetal)
	end
	local torretta = scafo * CFrame.new(0, 2.6 * s, 0.5 * s) * CFrame.Angles(0, rng:NextNumber(-1.5, 1.5), 0)
	ovale(g, Vector3.new(5.6, 2.6, 6) * s, torretta, colore, M.CorrodedMetal)
	cilindro(g, (torretta * CFrame.new(0, 0.2 * s, -2.5 * s)).Position, (torretta * CFrame.new(0, -0.3 * s, -9 * s)).Position, 0.7 * s, C(56, 54, 48), M.CorrodedMetal)
	trave(g, (cf * CFrame.new(4 * s, 0.3, 7 * s)).Position, (cf * CFrame.new(5 * s, 0.3, 14 * s)).Position, 1.6 * s, 0.3, C(46, 44, 40), M.CorrodedMetal)
	local fumo = Instance.new("Smoke")
	fumo.Color = C(60, 60, 60)
	fumo.Opacity = 0.18
	fumo.RiseVelocity = 3
	fumo.Size = 6
	fumo.Parent = parte(g, Vector3.one, torretta, colore, M.CorrodedMetal)
end
ingombro("relitto", 8)

-- Taxi Renault AG1 (i taxi della Marna): carrozzeria rossa e nera, cappotte, ruote a raggi.
function P.taxi(g, cf, rng, s)
	local base = cf * CFrame.new(0, 2 * s, 0)
	parte(g, Vector3.new(4, 1.8, 9) * s, base, C(120, 24, 24), M.SmoothPlastic)
	parte(g, Vector3.new(3.6, 1.6, 3) * s, base * CFrame.new(0, 0.1 * s, -4.8 * s), C(30, 30, 30), M.Metal)
	parte(g, Vector3.new(4, 2.6, 4.2) * s, base * CFrame.new(0, 2.2 * s, 1.6 * s), C(24, 24, 24), M.Fabric)
	for _, x in ipairs({ -2.1, 2.1 }) do
		for _, z in ipairs({ -3.2, 3.2 }) do
			local ruota = parte(g, Vector3.new(0.4 * s, 2.6 * s, 2.6 * s), cf * CFrame.new(x * s, 1.3 * s, z * s), C(40, 36, 32), M.Rubber)
			ruota.Shape = Enum.PartType.Cylinder
		end
	end
	palla(g, 0.8 * s, (base * CFrame.new(1.4 * s, 0.4 * s, -6.3 * s)).Position, C(220, 210, 160), M.Neon)
	palla(g, 0.8 * s, (base * CFrame.new(-1.4 * s, 0.4 * s, -6.3 * s)).Position, C(220, 210, 160), M.Neon)
end
ingombro("taxi", 5)

-- Siepe del bocage normanno: lunga e alta, su un argine di terra.
function P.siepe(g, cf, rng, s, ctx)
	local l = ctx.lunghezza or 40
	parte(g, Vector3.new(l, 3 * s, 5 * s), cf * CFrame.new(0, 0.6 * s, 0), C(96, 78, 52), M.Ground)
	for x = -l / 2 + 2, l / 2 - 2, 3.5 * s do
		ovale(g, Vector3.new(5, rng:NextNumber(5, 8), 5) * s, cf * CFrame.new(x + rng:NextNumber(-0.6, 0.6), 4.5 * s, rng:NextNumber(-0.5, 0.5)), varia(C(60, 100, 44), rng, 0.05), M.Grass)
	end
end
ingombro("siepe", 4)

function P.meloSidro(g, cf, rng, s, ctx)
	local base = cf.Position
	cilindro(g, base - Vector3.new(0, 0.5, 0), base + Vector3.new(0, 4 * s, 0), 0.9 * s, CORTECCIA, M.Wood)
	local verde = varia(C(80, 120, 50), rng, 0.05)
	ovale(g, Vector3.new(8, 5, 8) * s, CFrame.new(base + Vector3.new(0, 6 * s, 0)), verde, M.Grass)
	for i = 1, 6 do
		palla(g, 0.5 * s, base + Vector3.new(rng:NextNumber(-3, 3) * s, rng:NextNumber(4.5, 7) * s, rng:NextNumber(-3, 3) * s), C(190, 50, 40), M.SmoothPlastic)
	end
end
ingombro("meloSidro", 4.5)

-- Cratere di granata: buca nel terreno con il bordo di terra smossa e qualche detrito.
-- (la buca la scava Paesaggio.scava, prima di decorare).
function P.bordoCratere(g, cf, rng, s, ctx)
	local r = 5 * s
	for i = 0, 11 do
		local a = i * math.pi / 6 + rng:NextNumber(-0.2, 0.2)
		ovale(g, Vector3.new(3.6, 1.6, 2.4) * s, CFrame.new(cf.Position + Vector3.new(math.cos(a) * r, 0.2, math.sin(a) * r)) * CFrame.Angles(0, -a, 0), varia(ctx.neve and C(214, 218, 224) or C(96, 80, 62), rng, 0.05), ctx.neve and M.Snow or M.Ground)
	end
end
ingombro("bordoCratere", 6)

-- Rovina dell'abbazia sul monte (Cassino): grande blocco di muri e archi spezzati.
function P.abbazia(g, cf, rng, s)
	local l, p, h = 70 * s, 50 * s, 18 * s
	local colore = C(206, 196, 176)
	for _, lato in ipairs({ { 0, -p / 2, l, 0 }, { 0, p / 2, l, 0 }, { -l / 2, 0, p, math.pi / 2 }, { l / 2, 0, p, math.pi / 2 } }) do
		local cfMuro = cf * CFrame.new(lato[1], 0, lato[2]) * CFrame.Angles(0, lato[4], 0)
		local pezzi = 10
		for i = 0, pezzi - 1 do
			local a = h * rng:NextNumber(0.4, 1)
			parte(g, Vector3.new(lato[3] / pezzi + 0.1, a, 3 * s), cfMuro * CFrame.new(-lato[3] / 2 + (i + 0.5) * lato[3] / pezzi, a / 2 - 1, 0), varia(colore, rng, 0.03), M.Cobblestone)
			if rng:NextNumber() < 0.6 then
				parte(g, Vector3.new(lato[3] / pezzi * 0.5, a * 0.4, 3.2 * s), cfMuro * CFrame.new(-lato[3] / 2 + (i + 0.5) * lato[3] / pezzi, a * 0.3, 0), C(50, 46, 42), M.SmoothPlastic)
			end
		end
	end
	parte(g, Vector3.new(12, 30, 12) * s, cf * CFrame.new(-l / 4, 15 * s - 1, 0), varia(colore, rng, 0.03), M.Cobblestone)
end
ingombro("abbazia", 45)

-- Fabbricato industriale in rovina (Stalingrado): scheletro di cemento e ferri.
function P.fabbrica(g, cf, rng, s, ctx)
	local l, p, h = 40 * s, 24 * s, 16 * s
	local cemento = C(150, 146, 140)
	for x = -l / 2, l / 2, 8 * s do
		for _, z in ipairs({ -p / 2, p / 2 }) do
			local a = h * rng:NextNumber(0.5, 1)
			parte(g, Vector3.new(2, a, 2) * s, cf * CFrame.new(x, a / 2 - 1, z), cemento, M.Concrete)
		end
	end
	for i = 1, 3 do
		local x = rng:NextNumber(-l / 2, l / 2)
		parte(g, Vector3.new(8 * s, 1.2 * s, p), cf * CFrame.new(x, h * rng:NextNumber(0.3, 0.9), 0) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3)), cemento, M.Concrete)
	end
	parte(g, Vector3.new(l * 0.6, h * 0.6, 1.2 * s), cf * CFrame.new(-l * 0.2, h * 0.3 - 1, -p / 2), C(140, 100, 80), M.Brick)
	cilindro(g, (cf * CFrame.new(l / 2 + 6 * s, 0, 0)).Position, (cf * CFrame.new(l / 2 + 6 * s, 36 * s, 0)).Position, 4 * s, C(130, 90, 70), M.Brick)
	for i = 1, 10 do
		parte(g, Vector3.new(rng:NextNumber(1, 4), rng:NextNumber(0.6, 2), rng:NextNumber(1, 4)) * s, cf * CFrame.new(rng:NextNumber(-l / 2, l / 2), 0.4 * s, rng:NextNumber(-p / 2, p / 2)) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 3), 0), cemento, M.Concrete)
	end
	if ctx.neve then
		parte(g, Vector3.new(l, 0.5, p), cf * CFrame.new(0, 0.1, 0), C(236, 240, 246), M.Snow)
	end
end
ingombro("fabbrica", 24)

-- Palazzo sventrato di Stalingrado: quattro piani di mattoni con le finestre vuote, il tetto crollato,
-- un angolo squarciato dalle granate e il cumulo di macerie davanti.
function P.palazzoDiroccato(g, cf, rng, s, ctx)
	local l, p = 26 * s, 12 * s
	local piano, piani = 4.6 * s, 4
	local h = piano * piani
	local colore = varia(ctx.pietra or C(150, 112, 92), rng, 0.04)
	local squarcio = rng:NextNumber(-l / 2 + 4 * s, l / 2 - 4 * s) -- dove le granate hanno aperto il muro
	-- Facciate: pilastri tra le finestre (altezze spezzate) e le fasce dei solai.
	for _, z in ipairs({ -p / 2, p / 2 }) do
		local colonne = 7
		local alti = {}
		for c = 0, colonne do
			local x = -l / 2 + c * l / colonne
			local alto = h * (math.abs(x - squarcio) < 5 * s and rng:NextNumber(0.15, 0.45) or rng:NextNumber(0.7, 1))
			alti[c] = alto
			parte(g, Vector3.new(1.6 * s, alto, 0.9 * s), cf * CFrame.new(x, alto / 2 - 1, z), varia(colore, rng, 0.03), M.Brick)
		end
		for k = 1, piani do
			local y = k * piano - 1
			if k < piani or rng:NextNumber() < 0.5 then
				-- La fascia del solaio corre solo tra pilastri che arrivano fin lì: dove il muro è caduto si
				-- interrompe, invece di restare sospesa per aria.
				local inizio = nil
				for c = 0, colonne + 1 do
					local regge = c <= colonne and alti[c] - 1 >= y - s
					if regge and not inizio then
						inizio = c
					elseif not regge and inizio then
						if c - 1 > inizio then
							local x0, x1 = -l / 2 + inizio * l / colonne, -l / 2 + (c - 1) * l / colonne
							parte(g, Vector3.new(x1 - x0, 1.1 * s, 1 * s), cf * CFrame.new((x0 + x1) / 2, y - 0.5 * s, z), varia(colore, rng, 0.03), M.Brick)
						end
						inizio = nil
					end
				end
			end
		end
	end
	-- Fianchi pieni con qualche finestra annerita.
	for _, x in ipairs({ -l / 2, l / 2 }) do
		local alto = h * rng:NextNumber(0.6, 1)
		parte(g, Vector3.new(0.9 * s, alto, p), cf * CFrame.new(x, alto / 2 - 1, 0), varia(colore, rng, 0.03), M.Brick)
	end
	-- Solai crollati, inclinati dentro il guscio.
	for k = 1, 2 do
		parte(g, Vector3.new(l * 0.45, 0.8 * s, p - 1), cf * CFrame.new(rng:NextNumber(-l / 4, l / 4), k * piano * 0.8, 0) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), 0, rng:NextNumber(-0.45, 0.45)), C(120, 116, 110), M.Concrete)
	end
	-- Cumulo di macerie davanti allo squarcio.
	for i = 1, 9 do
		parte(g, Vector3.new(rng:NextNumber(1.5, 4), rng:NextNumber(0.8, 2.2), rng:NextNumber(1.5, 4)) * s,
			cf * CFrame.new(squarcio + rng:NextNumber(-6, 6) * s, rng:NextNumber(0, 1.6) * s, -p / 2 - rng:NextNumber(0, 6) * s)
				* CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 3), rng:NextNumber(-0.5, 0.5)),
			varia(colore, rng, 0.06), M.Brick)
	end
	trave(g, (cf * CFrame.new(squarcio, piano * 2, -p / 2)).Position, (cf * CFrame.new(squarcio + 5 * s, 0.4, -p / 2 - 5 * s)).Position, 0.6 * s, 0.6 * s, C(60, 50, 44), M.Metal)
	if ctx.neve then
		parte(g, Vector3.new(10, 0.6, 7) * s, cf * CFrame.new(squarcio, 1.6 * s, -p / 2 - 3 * s) * CFrame.Angles(0.15, 0, 0), C(236, 240, 246), M.Snow)
		parte(g, Vector3.new(l - 2, 0.5, p - 2), cf * CFrame.new(0, 0.1, 0), C(236, 240, 246), M.Snow)
	end
end
ingombro("palazzoDiroccato", 15)

-- Forte di cemento (Douaumont): la casamatta bassa coperta di terra, le torrette d'acciaio a cupola,
-- le campane d'osservazione e il fossato, tutto butterato dalle granate.
function P.forte(g, cf, rng, s, ctx)
	local l, p = 64 * s, 34 * s
	local cemento = C(132, 128, 118)
	local terra = C(92, 76, 58)
	-- Il tumulo di terra che copre il forte e la casamatta che ne esce davanti.
	ovale(g, Vector3.new(l * 1.1, 14 * s, p * 1.2), cf * CFrame.new(0, 1 * s, 4 * s), terra, M.Mud)
	parte(g, Vector3.new(l * 0.8, 7 * s, 9 * s), cf * CFrame.new(0, 3.5 * s - 1, -p / 2 + 3 * s), cemento, M.Concrete)
	parte(g, Vector3.new(l * 0.8 + 1, 1.2 * s, 10 * s), cf * CFrame.new(0, 7.2 * s - 1, -p / 2 + 3 * s), cemento:Lerp(C(0, 0, 0), 0.08), M.Concrete)
	for i = -3, 3 do
		parte(g, Vector3.new(2.6 * s, 1.6 * s, 0.4), cf * CFrame.new(i * 6.5 * s, 4 * s, -p / 2 - 1.55 * s), C(26, 26, 26), M.Concrete)
	end
	-- Torrette a cupola (cannoni da 155 e da 75) e campane d'osservazione.
	for _, t in ipairs({ { -14, 6, 7 }, { 12, 2, 5.5 }, { 26, 10, 4.5 } }) do
		local pos = cf * CFrame.new(t[1] * s, 7.6 * s, t[2] * s)
		parte(g, Vector3.new(1.2, t[3] * 2.4, t[3] * 2.4) * s, pos * CFrame.Angles(0, 0, math.pi / 2), cemento, M.Concrete).Shape = Enum.PartType.Cylinder
		ovale(g, Vector3.new(t[3] * 2, t[3] * 1.1, t[3] * 2) * s, pos * CFrame.new(0, 0.4 * s, 0), C(70, 74, 72), M.Metal)
		if t[3] > 5 then
			cilindro(g, (pos * CFrame.new(0, 2 * s, -t[3] * 0.6 * s)).Position, (pos * CFrame.new(0, 2.4 * s, -t[3] * 1.6 * s)).Position, 0.9 * s, C(46, 48, 46), M.Metal)
		end
	end
	for _, x in ipairs({ -26, 0 }) do
		local pos = cf * CFrame.new(x * s, 8 * s, -4 * s)
		ovale(g, Vector3.new(3.2, 3.4, 3.2) * s, pos, C(80, 84, 80), M.Metal)
	end
	-- Il fossato davanti con il muro di controscarpa e i reticolati.
	parte(g, Vector3.new(l, 3 * s, 1.2 * s), cf * CFrame.new(0, 0.5 * s, -p / 2 - 9 * s), cemento, M.Concrete)
	for i = 1, 3 do
		P.filoSpinato(g, cf * CFrame.new((i - 2) * 22 * s, 0, -p / 2 - 14 * s), rng, 1, { lunghezza = 20 * s })
	end
	-- Blocchi di cemento sbriciolati dalle granate.
	for i = 1, 8 do
		parte(g, Vector3.new(rng:NextNumber(1.5, 4), rng:NextNumber(1, 2.4), rng:NextNumber(1.5, 4)) * s,
			cf * CFrame.new(rng:NextNumber(-l / 2, l / 2), rng:NextNumber(1, 7) * s, rng:NextNumber(-p / 2, p / 2))
				* CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, 3), rng:NextNumber(-0.6, 0.6)),
			cemento:Lerp(C(0, 0, 0), rng:NextNumber(0, 0.15)), M.Concrete)
	end
	if ctx.neve then
		ovale(g, Vector3.new(l, 2, p) * s, cf * CFrame.new(0, 7.4 * s, 4 * s), C(236, 240, 246), M.Snow)
	end
end
ingombro("forte", 34)

-- Lampione di Parigi e una barricata di mobili, sacchi e pavé.
function P.barricata(g, cf, rng, s)
	for i = 1, 10 do
		parte(g, Vector3.new(rng:NextNumber(1.5, 3.5), rng:NextNumber(1, 2.5), rng:NextNumber(1.2, 2.5)) * s, cf * CFrame.new(rng:NextNumber(-7, 7) * s, rng:NextNumber(0.4, 2.4) * s, rng:NextNumber(-1, 1) * s) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 3), rng:NextNumber(-0.5, 0.5)), varia(C(110, 90, 70), rng, 0.08), i % 3 == 0 and M.Cobblestone or M.WoodPlanks)
	end
	local ruota = parte(g, Vector3.new(0.4 * s, 3 * s, 3 * s), cf * CFrame.new(6 * s, 2.5 * s, 0.8 * s) * CFrame.Angles(0, 0, 0.6), C(60, 50, 40), M.Wood)
	ruota.Shape = Enum.PartType.Cylinder
	local lampione = cf * CFrame.new(-9 * s, 0, 2 * s)
	cilindro(g, lampione.Position, lampione.Position + Vector3.new(0, 12 * s, 0), 0.5 * s, C(40, 46, 44), M.Metal)
	parte(g, Vector3.new(1.4, 1.8, 1.4) * s, lampione * CFrame.new(0, 12.8 * s, 0), C(230, 220, 170), M.Glass)
end
ingombro("barricata", 9)

-- Palazzo parigino (Haussmann): pietra chiara, cinque piani di finestre, balconi di ferro al secondo e al
-- quinto, tetto a mansarda d'ardesia con i camini, bottega con la tenda al pianterreno.
function P.palazzo(g, cf, rng, s, ctx)
	local l, p, h = 26 * s, 14 * s, 24 * s
	local pietra = varia(C(222, 210, 184), rng, 0.03)
	parte(g, Vector3.new(l, h, p), cf * CFrame.new(0, h / 2 - 1, 0), pietra, M.Limestone)
	local fronte = -p / 2 - 0.15
	local colonne = 6
	for piano = 1, 5 do
		local y = 4.5 * s + piano * 3.6 * s
		for c = 0, colonne - 1 do
			local x = -l / 2 + (c + 0.5) * l / colonne
			parte(g, Vector3.new(1.8 * s, 2.6 * s, 0.3), cf * CFrame.new(x, y - 1, fronte), C(46, 52, 62), M.Glass)
			parte(g, Vector3.new(2.3 * s, 0.35 * s, 0.4), cf * CFrame.new(x, y - 1 + 1.5 * s, fronte - 0.05), pietra:Lerp(C(255, 255, 255), 0.2), M.Limestone)
		end
		if piano == 2 or piano == 5 then
			parte(g, Vector3.new(l - 1, 0.3, 1.4 * s), cf * CFrame.new(0, y - 1 - 1.4 * s, fronte - 0.7 * s), pietra, M.Limestone)
			parte(g, Vector3.new(l - 1, 1.1 * s, 0.15), cf * CFrame.new(0, y - 1 - 0.8 * s, fronte - 1.35 * s), C(30, 32, 34), M.Metal)
		end
	end
	-- Pianterreno: bottega con la vetrina e la tenda a righe.
	parte(g, Vector3.new(l * 0.6, 4 * s, 0.3), cf * CFrame.new(-l * 0.15, 2 * s - 1, fronte), C(60, 40, 30), M.Glass)
	local tenda = ctx.tenda or C(150, 30, 30)
	cuneo(g, Vector3.new(l * 0.62, 1.2 * s, 2.4 * s), cf * CFrame.new(-l * 0.15, 4.6 * s - 1, fronte - 1.2 * s) * CFrame.Angles(0, math.pi, 0), tenda, M.Fabric)
	-- Mansarda: due falde ripide e il colmo, camini.
	local cima = cf * CFrame.new(0, h - 1, 0)
	cuneo(g, Vector3.new(l, 5 * s, 3 * s), cima * CFrame.new(0, 2.5 * s, -p / 2 + 1.5 * s) * CFrame.Angles(0, math.pi, 0), C(84, 92, 106), M.Slate)
	cuneo(g, Vector3.new(l, 5 * s, 3 * s), cima * CFrame.new(0, 2.5 * s, p / 2 - 1.5 * s), C(84, 92, 106), M.Slate)
	parte(g, Vector3.new(l, 5 * s, p - 6 * s), cima * CFrame.new(0, 2.5 * s, 0), C(84, 92, 106), M.Slate)
	for c = 0, colonne - 1, 2 do
		parte(g, Vector3.new(1.6 * s, 2 * s, 1.0), cima * CFrame.new(-l / 2 + (c + 0.5) * l / colonne, 2.6 * s, -p / 2 + 1.6 * s), C(70, 76, 86), M.Slate)
	end
	for _, x in ipairs({ -l / 3, l / 3 }) do
		parte(g, Vector3.new(2 * s, 3.4 * s, 1.4 * s), cima * CFrame.new(x, 6 * s, 0), C(176, 110, 84), M.Brick)
	end
	if ctx.neve then
		parte(g, Vector3.new(l, 0.4, p - 6 * s), cima * CFrame.new(0, 5.1 * s, 0), C(240, 244, 250), M.Snow)
	end
end
ingombro("palazzo", 15)

-- La Tour Eiffel, da lontano: quattro piedi a traliccio che si piegano verso l'alto, due piattaforme, la guglia.
function P.torreEiffel(g, cf, rng, s)
	local colore = C(120, 92, 66)
	local base = 34 * s
	local function punto(f, angolo)
		-- Larghezza del traliccio all'altezza f (0 = piedi, 1 = cima): curva esponenziale.
		local mezza = base * math.exp(-3.2 * f) * 0.5 + 0.6 * s
		return cf * CFrame.new(angolo.X * mezza, f * 150 * s, angolo.Y * mezza)
	end
	local angoli = { Vector2.new(1, 1), Vector2.new(-1, 1), Vector2.new(-1, -1), Vector2.new(1, -1) }
	local quote = { 0, 0.08, 0.16, 0.24, 0.34, 0.46, 0.6, 0.75, 0.9, 1.0 }
	for _, a in ipairs(angoli) do
		for i = 1, #quote - 1 do
			local p0, p1 = punto(quote[i], a).Position, punto(quote[i + 1], a).Position
			local spesso = (2.6 - 2.0 * quote[i]) * s
			trave(g, p0, p1, spesso, spesso, colore, M.Metal)
		end
	end
	-- Archi tra i piedi alla base e le due piattaforme.
	for k, a in ipairs(angoli) do
		local b = angoli[k % 4 + 1]
		trave(g, punto(0.08, a).Position, punto(0.08, b).Position, 1.2 * s, 1.8 * s, colore, M.Metal)
	end
	for _, f in ipairs({ 0.16, 0.38 }) do
		local mezza = base * math.exp(-3.2 * f) * 0.5 + 2 * s
		parte(g, Vector3.new(mezza * 2.2, 2.4 * s, mezza * 2.2), cf * CFrame.new(0, f * 150 * s, 0), colore, M.Metal)
	end
	parte(g, Vector3.new(4 * s, 3 * s, 4 * s), cf * CFrame.new(0, 0.9 * 150 * s, 0), colore, M.Metal)
	cilindro(g, (cf * CFrame.new(0, 150 * s, 0)).Position, (cf * CFrame.new(0, 162 * s, 0)).Position, 0.8 * s, colore, M.Metal)
end
ingombro("torreEiffel", 22)

-- Ponte di pietra ad archi su un fiume (lungo cf.LookVector, l studs), con i parapetti.
function P.pontePietra(g, cf, rng, s, ctx)
	local l = ctx.lunghezza or 40
	local larghezza = 10 * s
	local pietra = ctx.pietra or C(196, 186, 164)
	parte(g, Vector3.new(larghezza, 1.6, l), cf * CFrame.new(0, 3.4, 0), pietra, M.Limestone)
	for _, x in ipairs({ -larghezza / 2, larghezza / 2 }) do
		parte(g, Vector3.new(0.8, 1.6, l), cf * CFrame.new(x, 4.9, 0), pietra, M.Limestone)
	end
	for _, z in ipairs({ -l / 6, l / 6 }) do
		parte(g, Vector3.new(larghezza + 1.4, 8, 3), cf * CFrame.new(0, -1.2, z), pietra:Lerp(C(0, 0, 0), 0.08), M.Limestone)
		cuneo(g, Vector3.new(larghezza + 1.4, 3, 2.4), cf * CFrame.new(0, -1.2, z - 2.6) * CFrame.Angles(0, math.pi, 0), pietra:Lerp(C(0, 0, 0), 0.08), M.Limestone)
	end
end
ingombro("pontePietra", 8)

-- Lampione di ghisa a una lanterna.
function P.lampione(g, cf, rng, s)
	local base = cf.Position
	cilindro(g, base - Vector3.new(0, 0.5, 0), base + Vector3.new(0, 1.6 * s, 0), 1.0 * s, C(36, 42, 40), M.Metal)
	cilindro(g, base, base + Vector3.new(0, 11 * s, 0), 0.45 * s, C(36, 42, 40), M.Metal)
	parte(g, Vector3.new(1.3, 1.7, 1.3) * s, CFrame.new(base + Vector3.new(0, 11.9 * s, 0)), C(236, 226, 170), M.Glass)
	cuneo(g, Vector3.new(1.7, 0.7, 1.7) * s, CFrame.new(base + Vector3.new(0, 13.1 * s, 0)), C(36, 42, 40), M.Metal)
end
ingombro("lampione", 1)

-- Cartello di campo minato (Achtung Minen): paletto con la tavoletta triangolare.
function P.cartello(g, cf, rng, s)
	local base = cf.Position
	cilindro(g, base - Vector3.new(0, 0.5, 0), base + Vector3.new(0, 3 * s, 0), 0.25 * s, C(110, 90, 66), M.Wood)
	local tavola = cf * CFrame.new(0, 3.1 * s, -0.15) * CFrame.Angles(0, 0, math.pi / 4)
	parte(g, Vector3.new(1.4, 1.4, 0.1) * s, tavola, C(214, 196, 140), M.WoodPlanks)
	parte(g, Vector3.new(0.6, 0.6, 0.12) * s, tavola, C(150, 30, 26), M.SmoothPlastic)
end
ingombro("cartello", 0.8)

-- Casa mediterranea: cubo imbiancato col tetto piatto, porta e finestrelle, a volte una scala esterna.
function P.casaBianca(g, cf, rng, s, ctx)
	local l, p, h = rng:NextNumber(10, 15) * s, rng:NextNumber(8, 11) * s, rng:NextNumber(6, 9) * s
	local muro = varia(ctx.colore or C(232, 224, 204), rng, 0.04)
	parte(g, Vector3.new(l, h, p), cf * CFrame.new(0, h / 2 - 1, 0), muro, M.Plaster)
	parte(g, Vector3.new(l + 0.6, 0.6, p + 0.6), cf * CFrame.new(0, h - 0.9, 0), muro:Lerp(C(0, 0, 0), 0.08), M.Plaster)
	parte(g, Vector3.new(2.2 * s, 3.6 * s, 0.3), cf * CFrame.new(-l / 4, 1.8 * s - 1, -p / 2 - 0.1), C(96, 64, 40), M.WoodPlanks)
	for _, x in ipairs({ l / 6, l / 3 }) do
		parte(g, Vector3.new(1.2 * s, 1.2 * s, 0.3), cf * CFrame.new(x, h * 0.6, -p / 2 - 0.1), C(40, 50, 60), M.SmoothPlastic)
	end
	if rng:NextNumber() < 0.5 then
		trave(g, (cf * CFrame.new(l / 2 + 1.2 * s, -0.5, p / 4)).Position, (cf * CFrame.new(l / 2 + 1.2 * s, h - 1, -p / 4)).Position, 2 * s, 0.6, muro, M.Plaster)
	end
end
ingombro("casaBianca", 8)

-- Trireme (o pentere) tirata in secca o all'ancora: scafo nero con lo sperone, i remi, l'albero con la vela.
function P.nave(g, cf, rng, s, ctx)
	local l, larga = 44 * s, 6 * s
	local scafo = ctx.colore or C(52, 40, 32)
	local corpo = cf * CFrame.new(0, 1.2 * s, 0)
	parte(g, Vector3.new(larga, 3 * s, l * 0.7), corpo, scafo, M.WoodPlanks)
	-- Prua (verso -Z, con lo sperone di bronzo) e poppa che si alza ricurva.
	cuneo(g, Vector3.new(larga, 3 * s, l * 0.16), corpo * CFrame.new(0, 0, -l * 0.43) * CFrame.Angles(0, math.pi, 0), scafo, M.WoodPlanks)
	parte(g, Vector3.new(1.2 * s, 1.0 * s, 4 * s), corpo * CFrame.new(0, -1.0 * s, -l * 0.52), C(170, 120, 60), M.Metal)
	cuneo(g, Vector3.new(larga, 4.5 * s, l * 0.14), corpo * CFrame.new(0, 0.8 * s, l * 0.42), scafo, M.WoodPlanks)
	parte(g, Vector3.new(larga + 0.4, 0.4, l * 0.7), corpo * CFrame.new(0, 1.6 * s, 0), C(150, 40, 30), M.WoodPlanks)
	-- Occhio dipinto a prua.
	for _, x in ipairs({ -1, 1 }) do
		palla(g, 1.0 * s, (corpo * CFrame.new(x * (larga / 2 + 0.05), 0.4 * s, -l * 0.36)).Position, C(230, 226, 210), M.SmoothPlastic)
	end
	-- Remi in fila sui due fianchi.
	for _, x in ipairs({ -1, 1 }) do
		for i = 0, 9 do
			local z = -l * 0.3 + i * l * 0.062
			local a = (corpo * CFrame.new(x * larga / 2, 0.6 * s, z)).Position
			local b = (corpo * CFrame.new(x * (larga / 2 + 7 * s), -2.4 * s, z + 1.5 * s)).Position
			trave(g, a, b, 0.25 * s, 0.25 * s, C(140, 110, 70), M.Wood)
		end
	end
	local albero = corpo * CFrame.new(0, 1.6 * s, -l * 0.05)
	cilindro(g, albero.Position, albero.Position + Vector3.new(0, 18 * s, 0), 0.7 * s, C(110, 82, 52), M.Wood)
	trave(g, (albero * CFrame.new(-7 * s, 16 * s, 0)).Position, (albero * CFrame.new(7 * s, 16 * s, 0)).Position, 0.4 * s, 0.4 * s, C(110, 82, 52), M.Wood)
	parte(g, Vector3.new(13 * s, 9 * s, 0.2), albero * CFrame.new(0, 11.4 * s, 0.4 * s), ctx.vela or C(214, 196, 160), M.Fabric)
end
ingombro("nave", 22)

-- Mezzo da sbarco (o lancia a remi) arenato sulla spiaggia.
function P.barca(g, cf, rng, s, ctx)
	local corpo = cf * CFrame.new(0, 0.9 * s, 0) * CFrame.Angles(0, 0, rng:NextNumber(-0.15, 0.15))
	local colore = ctx.colore or C(84, 88, 80)
	parte(g, Vector3.new(4.4, 2.2, 9) * s, corpo, colore, M.WoodPlanks)
	cuneo(g, Vector3.new(4.4, 2.2, 3) * s, corpo * CFrame.new(0, 0, -6 * s) * CFrame.Angles(0, math.pi, 0), colore, M.WoodPlanks)
	parte(g, Vector3.new(3.6, 0.4, 8) * s, corpo * CFrame.new(0, 0.6 * s, 0), C(60, 50, 40), M.WoodPlanks)
	for _, z in ipairs({ -2, 0.5, 3 }) do
		parte(g, Vector3.new(3.8, 0.3, 0.8) * s, corpo * CFrame.new(0, 0.9 * s, z * s), C(120, 96, 66), M.WoodPlanks)
	end
end
ingombro("barca", 5)

-- Muro di scudi (i Sassoni a Hastings): scudi tondi sovrapposti in fila, con le lance alzate dietro.
function P.muroScudi(g, cf, rng, s, ctx)
	local l = ctx.lunghezza or 24
	local colori = ctx.colori or { C(170, 40, 34), C(220, 196, 120), C(40, 70, 130), C(70, 110, 60) }
	local n = math.max(2, math.floor(l / (2.4 * s)))
	for i = 0, n - 1 do
		local x = -l / 2 + (i + 0.5) * l / n
		local scudo = parte(g, Vector3.new(0.3 * s, 3.6 * s, 3.6 * s), cf * CFrame.new(x, 2.2 * s, -rng:NextNumber(0, 0.3)) * CFrame.Angles(0, math.pi / 2, rng:NextNumber(-0.1, 0.1)), varia(colori[rng:NextInteger(1, #colori)], rng, 0.05), M.Wood)
		scudo.Shape = Enum.PartType.Cylinder
		palla(g, 0.8 * s, (cf * CFrame.new(x, 2.2 * s, -0.4 * s)).Position, C(150, 150, 150), M.Metal)
		if i % 2 == 0 then
			local p = (cf * CFrame.new(x + 0.6 * s, 0, 1.2 * s)).Position
			cilindro(g, p, p + Vector3.new(0, 9 * s, -1.4 * s), 0.25 * s, C(130, 100, 64), M.Wood)
		end
	end
end
ingombro("muroScudi", 3)

-- Ghiaccio rotto (lago Peipus): buca d'acqua nera con le lastre spezzate e inclinate attorno.
function P.ghiaccioRotto(g, cf, rng, s)
	local base = cf.Position
	local buco = parte(g, Vector3.new(0.3, 9 * s, 7 * s), CFrame.new(base + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), math.pi / 2), C(20, 40, 56), M.Glass)
	buco.Shape = Enum.PartType.Cylinder
	for i = 1, 7 do
		local a = i * 2 * math.pi / 7 + rng:NextNumber(-0.3, 0.3)
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		parte(g, Vector3.new(rng:NextNumber(2.2, 3.6), 0.5, rng:NextNumber(1.6, 2.6)) * s,
			CFrame.lookAt(base + d * 4.2 * s + Vector3.new(0, 0.4, 0), base + d * 8 * s) * CFrame.Angles(rng:NextNumber(0.15, 0.5), 0, rng:NextNumber(-0.2, 0.2)),
			C(200, 224, 236), M.Ice)
	end
end
ingombro("ghiaccioRotto", 6)

-- Trincea: scavata con Paesaggio.scava; qui le pareti di tavole, i sacchetti sul ciglio e le passerelle.
function P.trincea(g, cf, rng, s, ctx)
	local l = ctx.lunghezza or 30
	for _, lato in ipairs({ -1, 1 }) do
		parte(g, Vector3.new(l, 5, 0.4), cf * CFrame.new(0, -2.3, lato * 3.2), C(110, 86, 58), M.WoodPlanks)
		local cfSacchi = cf * CFrame.new(0, 0, lato * 4.2)
		P.sacchetti(g, cfSacchi, rng, 1, { lunghezza = l })
	end
	for z = -l / 2 + 2, l / 2 - 2, 4 do
		parte(g, Vector3.new(4, 0.3, 1.2), cf * CFrame.new(z, -4.6, 0) * CFrame.Angles(0, math.pi / 2, 0), C(126, 98, 66), M.WoodPlanks)
	end
end
ingombro("trincea", 6)

-- Trincea sulle caselle del campo: bassa (i soldati dentro si vedono ancora), larga quasi una casella,
-- con il parapetto di sacchetti verso il nemico (+Z locale) e le pareti di tavole.
function P.trinceaCampo(g, cf, rng, s, ctx)
	local l = ctx.lunghezza or 16
	local p = ctx.profondita or 2
	local mezzo = (ctx.larghezza or 10) / 2
	for _, lato in ipairs({ -1, 1 }) do
		parte(g, Vector3.new(l, p + 0.6, 0.4), cf * CFrame.new(0, -p / 2 + 0.2, lato * (mezzo - 0.2)), varia(C(110, 86, 58), rng, 0.04), M.WoodPlanks)
	end
	P.sacchetti(g, cf * CFrame.new(0, 0, mezzo + 0.9), rng, 1, { lunghezza = l })
	for x = -l / 2 + 2, l / 2 - 2, 3 do
		parte(g, Vector3.new(0.5, p + 1.2, 0.5), cf * CFrame.new(x, -p / 2 + 0.5, mezzo - 0.5), C(92, 70, 46), M.Wood)
	end
	-- Passerelle di tavole sul fondo.
	for x = -l / 2 + 1.5, l / 2 - 1.5, 3 do
		parte(g, Vector3.new(2.6, 0.3, mezzo * 1.2), cf * CFrame.new(x, -p + 0.15, 0) * CFrame.Angles(0, rng:NextNumber(-0.05, 0.05), 0), varia(C(126, 98, 66), rng, 0.05), M.WoodPlanks)
	end
end
ingombro("trinceaCampo", 8)

-- Scavi nel terreno (crateri e trincee): fanno parte del terreno, quindi si fanno prima degli oggetti.
function Paesaggio.scavaCratere(posizione, raggio)
	workspace.Terrain:FillBall(posizione + Vector3.new(0, raggio * 0.45, 0), raggio, Enum.Material.Air)
	workspace.Terrain:FillBall(posizione - Vector3.new(0, raggio * 0.6, 0), raggio * 0.5, Enum.Material.Mud)
end

function Paesaggio.scavaTrincea(cf, lunghezza, profondita, larghezza)
	profondita, larghezza = profondita or 5, larghezza or 6
	workspace.Terrain:FillBlock(cf * CFrame.new(0, 1 - (profondita + 1) / 2, 0), Vector3.new(lunghezza, profondita + 1, larghezza), Enum.Material.Air)
	workspace.Terrain:FillBlock(cf * CFrame.new(0, -profondita - 0.5, 0), Vector3.new(lunghezza, 1, larghezza), Enum.Material.Mud)
end

return Paesaggio
