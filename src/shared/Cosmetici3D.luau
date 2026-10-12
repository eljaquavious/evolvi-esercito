-- Modelli 3D dei cosmetici, fatti di parti opache (niente lucido), nello stile a blocchi delle truppe.
-- Ogni modello è costruito attorno al centro della parte del corpo che lo porta (Testa o Busto),
-- con le misure di un avatar standard (testa 1.2, busto R15 2 x 1.6 x 1): davanti è -Z, sopra è +Y.
-- Cosmetici3D.indossa lo ridimensiona sulla testa o sul busto vero del personaggio e lo salda lì.
-- Lo usano il server (cosmetici addosso ai giocatori) e il client (anteprime nelle finestre).

local Cosmetici3D = {}

local RIFERIMENTO = { Testa = "Testa", Corpo = "Busto", Schiena = "Busto" }
local MISURA = { Testa = 1.2, Busto = 2 } -- larghezza della parte standard

local function hex(h)
	return Color3.fromHex(h)
end

local FERRO = hex("#8C9198")
local FERRO_SCURO = hex("#4E535B")
local ACCIAIO = hex("#A4AAB2")
local OTTONE = hex("#B08A3E")
local ORO = hex("#E2B13C")
local ORO_SCURO = hex("#A87A1E")
local CUOIO = hex("#6B4A2E")
local CUOIO_SCURO = hex("#4A3320")
local LEGNO = hex("#7A5432")
local ROSSO = hex("#9B2C2C")
local CREMISI = hex("#8E1B2A")
local BIANCO = hex("#EDE8DA")
local NERO = hex("#24222A")
local VERDE_ALLORO = hex("#557D38")
local VIOLA = hex("#5B2A7A")

local PLASTICA = Enum.Material.Plastic
local STOFFA = Enum.Material.Fabric
local LEGNAME = Enum.Material.Wood

local rad = math.rad

-- Una parte del modello. forma: "blocco", "palla", "cilindro" (asse X), "cuneo".
local function parte(modello, forma, misura, cf, colore, materiale)
	local p
	if forma == "cuneo" then
		p = Instance.new("WedgePart")
	else
		p = Instance.new("Part")
		if forma == "palla" then
			p.Shape = Enum.PartType.Ball
		elseif forma == "cilindro" then
			p.Shape = Enum.PartType.Cylinder
		end
	end
	p.Size = misura
	p.CFrame = cf
	p.Color = colore
	p.Material = materiale or PLASTICA
	p.Reflectance = 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = true
	p.Parent = modello
	return p
end

local function C(x, y, z)
	return CFrame.new(x, y, z)
end

-- Cilindro in piedi (asse Y) centrato in posizione.
local function verticale(x, y, z)
	return C(x, y, z) * CFrame.Angles(0, 0, rad(90))
end

-- Anello di blocchi attorno all'asse Y (fasce, corone, ghirlande).
local function anello(modello, n, raggio, y, misura, colore, materiale, inclina, salta)
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		if not (salta and salta(a)) then
			local cf = CFrame.Angles(0, a, 0) * C(0, y, -raggio) * CFrame.Angles(rad(inclina or 0), 0, 0)
			parte(modello, "blocco", misura, cf, colore, materiale)
		end
	end
end

local Costruttori = {}

-- ===================================================================== TESTA
-- La testa standard va da -0.6 a 0.6 su ogni asse; la faccia è sul lato -Z.

-- Galea del legionario: calotta di ferro, paranuca, paraguance, cresta rossa.
function Costruttori.Galea(m)
	parte(m, "palla", Vector3.new(1.42, 0.86, 1.48), C(0, 0.4, 0.02), FERRO)
	parte(m, "cilindro", Vector3.new(0.3, 1.44, 1.5), verticale(0, 0.2, 0.03), FERRO)
	parte(m, "blocco", Vector3.new(1.3, 0.1, 0.16), C(0, 0.3, -0.72), OTTONE) -- rinforzo sulla fronte
	parte(m, "blocco", Vector3.new(1.36, 0.08, 0.62), C(0, -0.06, 0.62) * CFrame.Angles(rad(-18), 0, 0), FERRO_SCURO) -- paranuca
	for _, s in ipairs({ -1, 1 }) do
		parte(m, "blocco", Vector3.new(0.08, 0.6, 0.42), C(s * 0.7, -0.15, -0.22) * CFrame.Angles(0, 0, rad(s * 4)), FERRO_SCURO)
		parte(m, "palla", Vector3.new(0.12, 0.12, 0.12), C(s * 0.74, -0.05, -0.22), OTTONE)
	end
	parte(m, "blocco", Vector3.new(0.12, 0.12, 0.3), C(0, 0.88, 0), OTTONE) -- supporto
	parte(m, "blocco", Vector3.new(0.18, 0.34, 1.3), C(0, 1.07, 0.05), ROSSO, STOFFA) -- cresta
	parte(m, "palla", Vector3.new(0.18, 0.34, 0.34), C(0, 1.07, -0.6), ROSSO, STOFFA)
	parte(m, "palla", Vector3.new(0.18, 0.34, 0.34), C(0, 1.07, 0.7), ROSSO, STOFFA)
end

-- Elmo a secchio del cavaliere: cilindro d'acciaio con la fessura per gli occhi e la croce d'ottone.
function Costruttori.ElmoGrande(m)
	parte(m, "cilindro", Vector3.new(1.42, 1.5, 1.5), verticale(0, 0.06, 0), ACCIAIO)
	parte(m, "palla", Vector3.new(1.5, 0.42, 1.5), C(0, 0.77, 0), ACCIAIO)
	parte(m, "blocco", Vector3.new(1.02, 0.09, 0.1), C(0, 0.12, -0.73), NERO) -- fessura
	parte(m, "blocco", Vector3.new(0.12, 0.84, 0.08), C(0, -0.12, -0.75), OTTONE)
	parte(m, "blocco", Vector3.new(1.0, 0.1, 0.08), C(0, 0.27, -0.75), OTTONE)
	for i = 0, 3 do -- fori per respirare
		parte(m, "blocco", Vector3.new(0.06, 0.06, 0.06), C(0.3, -0.12 - i * 0.12, -0.75), NERO)
	end
	parte(m, "cilindro", Vector3.new(0.1, 1.53, 1.53), verticale(0, -0.6, 0), FERRO_SCURO)
end

-- Elmo Adrian francese della Grande Guerra: calotta blu orizzonte, tesa, cresta e granata d'ottone.
function Costruttori.Adrian(m)
	local blu = hex("#6F8296")
	parte(m, "palla", Vector3.new(1.4, 0.92, 1.46), C(0, 0.42, 0.02), blu)
	parte(m, "palla", Vector3.new(1.62, 0.07, 1.86), C(0, 0.18, 0), blu) -- tesa
	parte(m, "blocco", Vector3.new(0.12, 0.16, 1.12), C(0, 0.88, 0.02), blu) -- cresta
	parte(m, "blocco", Vector3.new(0.2, 0.22, 0.05), C(0, 0.48, -0.72) * CFrame.Angles(rad(-12), 0, 0), OTTONE)
	parte(m, "palla", Vector3.new(0.14, 0.14, 0.06), C(0, 0.55, -0.74), OTTONE)
	parte(m, "blocco", Vector3.new(0.05, 0.62, 0.05), C(0.62, -0.12, -0.08), CUOIO) -- sottogola
	parte(m, "blocco", Vector3.new(0.05, 0.62, 0.05), C(-0.62, -0.12, -0.08), CUOIO)
end

-- Corona d'alloro: foglie verdi attorno alla testa, aperta davanti.
function Costruttori.Alloro(m)
	anello(m, 22, 0.66, 0.34, Vector3.new(0.2, 0.07, 0.3), VERDE_ALLORO, STOFFA, 0, function(a)
		return a < 0.35 or a > math.pi * 2 - 0.35
	end)
	anello(m, 22, 0.7, 0.42, Vector3.new(0.18, 0.06, 0.26), hex("#6E9A48"), STOFFA, -25, function(a)
		return a < 0.45 or a > math.pi * 2 - 0.45
	end)
	parte(m, "palla", Vector3.new(0.12, 0.12, 0.12), C(0, 0.36, 0.66), ORO) -- nodo dietro
end

-- Kepì da maresciallo: fascia blu, cupola rossa, gallone d'oro, visiera nera.
function Costruttori.Kepi(m)
	local cf = C(0, 0.62, 0.02) * CFrame.Angles(rad(-8), 0, 0)
	parte(m, "cilindro", Vector3.new(0.26, 1.34, 1.34), cf * C(0, -0.12, 0) * CFrame.Angles(0, 0, rad(90)), hex("#1E2A55"), STOFFA)
	parte(m, "cilindro", Vector3.new(0.32, 1.26, 1.26), cf * C(0, 0.16, 0) * CFrame.Angles(0, 0, rad(90)), hex("#A3202C"), STOFFA)
	parte(m, "cilindro", Vector3.new(0.05, 1.36, 1.36), cf * C(0, 0.0, 0) * CFrame.Angles(0, 0, rad(90)), ORO)
	parte(m, "cilindro", Vector3.new(0.04, 1.28, 1.28), cf * C(0, 0.3, 0) * CFrame.Angles(0, 0, rad(90)), ORO)
	parte(m, "blocco", Vector3.new(0.92, 0.05, 0.4), cf * C(0, -0.24, -0.74) * CFrame.Angles(rad(14), 0, 0), NERO)
	for i = -1, 1 do -- stelle da generale
		parte(m, "palla", Vector3.new(0.09, 0.09, 0.06), cf * C(i * 0.16, -0.12, -0.68), ORO)
	end
end

-- Elmo vichingo: calotta, fascia e nasale d'ottone, corna d'avorio.
function Costruttori.Vichingo(m)
	parte(m, "palla", Vector3.new(1.42, 1.02, 1.46), C(0, 0.36, 0.02), FERRO)
	parte(m, "cilindro", Vector3.new(0.16, 1.47, 1.5), verticale(0, 0.2, 0.02), OTTONE)
	parte(m, "blocco", Vector3.new(0.14, 0.86, 0.08), C(0, 0.4, -0.72), OTTONE)
	parte(m, "blocco", Vector3.new(0.12, 0.42, 0.1), C(0, -0.0, -0.74), FERRO_SCURO) -- nasale
	local avorio = hex("#E6DCC2")
	for _, s in ipairs({ -1, 1 }) do
		local base = C(s * 0.72, 0.42, 0)
		parte(m, "cilindro", Vector3.new(0.4, 0.26, 0.26), base * CFrame.Angles(0, 0, rad(s * -20)), avorio)
		parte(m, "cilindro", Vector3.new(0.34, 0.19, 0.19), C(s * 1.0, 0.6, 0) * CFrame.Angles(0, 0, rad(s * -55)), avorio)
		parte(m, "cilindro", Vector3.new(0.26, 0.13, 0.13), C(s * 1.12, 0.86, 0) * CFrame.Angles(0, 0, rad(s * -80)), avorio)
		parte(m, "palla", Vector3.new(0.12, 0.12, 0.12), C(s * 1.13, 1.0, 0), avorio)
	end
end

-- Corona di ferro dei campioni ranked: anello d'oro, punte, gemme rosse.
function Costruttori.Corona(m)
	anello(m, 16, 0.64, 0.48, Vector3.new(0.27, 0.3, 0.08), ORO)
	anello(m, 8, 0.64, 0.74, Vector3.new(0.14, 0.24, 0.08), ORO)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		parte(m, "palla", Vector3.new(0.13, 0.13, 0.13), CFrame.Angles(0, a, 0) * C(0, 0.88, -0.64), ORO)
		local gemma = (i % 2 == 0) and hex("#B3182E") or hex("#1F5FB8")
		parte(m, "palla", Vector3.new(0.12, 0.12, 0.08), CFrame.Angles(0, a + math.pi / 8, 0) * C(0, 0.48, -0.68), gemma)
	end
end

-- ===================================================================== CORPO
-- Il busto standard (R15) va da -1 a 1 in X, da -0.8 a 0.8 in Y, da -0.5 a 0.5 in Z.
-- Sotto c'è il bacino, fino a -1.2: cinture e gonnellini lo coprono.

-- Gonnellino di strisce di cuoio (pteruges), davanti e dietro.
local function strisce(m, colore, y, lunghezza, bordo)
	for _, z in ipairs({ -0.6, 0.6 }) do
		for i = -3, 3 do
			parte(m, "blocco", Vector3.new(0.24, lunghezza, 0.05), C(i * 0.29, y - lunghezza / 2, z), colore, STOFFA)
			if bordo then
				parte(m, "blocco", Vector3.new(0.25, 0.06, 0.06), C(i * 0.29, y - lunghezza + 0.03, z), bordo)
			end
		end
	end
end

local function cintura(m, colore, y, fibbia)
	parte(m, "blocco", Vector3.new(2.16, 0.2, 1.16), C(0, y, 0), colore, STOFFA)
	if fibbia then
		parte(m, "blocco", Vector3.new(0.26, 0.2, 0.06), C(0, y, -0.6), fibbia)
	end
end

function Costruttori.Lorica(m)
	parte(m, "blocco", Vector3.new(2.06, 1.6, 1.08), C(0, 0, 0), FERRO_SCURO)
	for i = 0, 4 do -- fasce sovrapposte
		parte(m, "blocco", Vector3.new(2.12, 0.17, 1.14), C(0, -0.68 + i * 0.2, 0), FERRO)
	end
	parte(m, "blocco", Vector3.new(0.9, 0.5, 0.06), C(-0.48, 0.42, -0.57), FERRO) -- piastre del petto
	parte(m, "blocco", Vector3.new(0.9, 0.5, 0.06), C(0.48, 0.42, -0.57), FERRO)
	for _, x in ipairs({ -0.48, 0.48 }) do
		parte(m, "palla", Vector3.new(0.1, 0.1, 0.06), C(x, 0.42, -0.61), OTTONE)
	end
	for _, s in ipairs({ -1, 1 }) do -- spallacci a lamine
		for j = 0, 2 do
			parte(m, "blocco", Vector3.new(0.62, 0.11, 1.16), C(s * (0.86 + j * 0.14), 0.84 - j * 0.16, 0) * CFrame.Angles(0, 0, rad(s * -28)), j % 2 == 0 and FERRO or FERRO_SCURO)
		end
	end
	cintura(m, CUOIO, -0.86, OTTONE)
	strisce(m, CUOIO, -0.96, 0.46, OTTONE)
end

function Costruttori.Piastre(m)
	parte(m, "blocco", Vector3.new(2.1, 1.62, 1.12), C(0, 0, 0), ACCIAIO)
	parte(m, "palla", Vector3.new(1.86, 1.5, 0.46), C(0, 0.06, -0.42), ACCIAIO) -- petto bombato
	parte(m, "blocco", Vector3.new(0.08, 1.2, 0.08), C(0, 0.06, -0.66), FERRO) -- costola centrale
	for _, s in ipairs({ -1, 1 }) do -- spallacci rotondi
		parte(m, "palla", Vector3.new(1.0, 0.8, 1.24), C(s * 1.02, 0.66, 0), ACCIAIO)
		parte(m, "blocco", Vector3.new(0.9, 0.08, 1.2), C(s * 1.06, 0.42, 0) * CFrame.Angles(0, 0, rad(s * -18)), FERRO)
	end
	parte(m, "blocco", Vector3.new(0.6, 0.12, 0.08), C(0, 0.72, -0.6), FERRO) -- gorgiera
	for i = 0, 2 do -- falda a lamine
		parte(m, "blocco", Vector3.new(2.18 + i * 0.04, 0.17, 1.18 + i * 0.04), C(0, -0.86 - i * 0.15, 0), i % 2 == 0 and ACCIAIO or FERRO)
	end
	parte(m, "blocco", Vector3.new(2.2, 0.08, 1.2), C(0, -0.74, 0), hex("#8E1B2A"), STOFFA) -- cinta rossa
end

function Costruttori.Cartucciera(m)
	-- Giubba della Grande Guerra sotto, cinghia a tracolla e cinturone con le giberne.
	local giubba = hex("#5F6F84")
	parte(m, "blocco", Vector3.new(2.06, 1.6, 1.08), C(0, 0, 0), giubba, STOFFA)
	parte(m, "blocco", Vector3.new(0.08, 1.5, 0.04), C(0, 0, -0.55), hex("#4B5868"), STOFFA)
	for i = 0, 3 do
		parte(m, "palla", Vector3.new(0.08, 0.08, 0.05), C(0.12, 0.5 - i * 0.32, -0.56), OTTONE)
	end
	for _, z in ipairs({ -0.58, 0.58 }) do
		parte(m, "blocco", Vector3.new(0.26, 2.2, 0.06), C(0, 0, z) * CFrame.Angles(0, 0, rad(-38)), CUOIO)
	end
	for i = -2, 2 do -- cartucce sulla tracolla
		local cf = CFrame.Angles(0, 0, rad(-38)) * C(0, i * 0.3, -0.62)
		parte(m, "blocco", Vector3.new(0.2, 0.2, 0.08), cf, CUOIO_SCURO)
		parte(m, "blocco", Vector3.new(0.14, 0.06, 0.02), cf * C(0, 0.04, -0.05), OTTONE)
	end
	cintura(m, CUOIO, -0.86, OTTONE)
	for _, x in ipairs({ -0.62, -0.32, 0.32, 0.62 }) do
		parte(m, "blocco", Vector3.new(0.26, 0.3, 0.16), C(x, -0.9, -0.64), CUOIO_SCURO)
	end
end

function Costruttori.Maglia(m)
	local maglia = hex("#7D838B")
	parte(m, "blocco", Vector3.new(2.08, 1.62, 1.1), C(0, 0, 0), maglia, STOFFA)
	parte(m, "blocco", Vector3.new(2.12, 0.5, 1.14), C(0, -1.06, 0), maglia, STOFFA) -- orlo lungo sui fianchi
	parte(m, "blocco", Vector3.new(1.2, 0.2, 1.14), C(0, 0.76, 0), hex("#6A7078"), STOFFA) -- collo
	cintura(m, CUOIO, -0.78, OTTONE)
end

function Costruttori.CorazzaOro(m)
	-- Corazza muscolare da generale romano, d'oro opaco, con gonnellino viola.
	parte(m, "blocco", Vector3.new(2.08, 1.6, 1.1), C(0, 0, 0), ORO_SCURO)
	parte(m, "palla", Vector3.new(0.98, 0.7, 0.4), C(-0.46, 0.36, -0.44), ORO) -- pettorali
	parte(m, "palla", Vector3.new(0.98, 0.7, 0.4), C(0.46, 0.36, -0.44), ORO)
	for r = 0, 2 do -- addominali
		for _, x in ipairs({ -0.24, 0.24 }) do
			parte(m, "palla", Vector3.new(0.42, 0.28, 0.24), C(x, -0.12 - r * 0.26, -0.5), ORO)
		end
	end
	parte(m, "blocco", Vector3.new(1.9, 1.5, 0.12), C(0, 0, 0.52), ORO) -- schiena
	for _, s in ipairs({ -1, 1 }) do
		parte(m, "palla", Vector3.new(0.96, 0.62, 1.18), C(s * 0.98, 0.7, 0), ORO)
		parte(m, "palla", Vector3.new(0.18, 0.18, 0.18), C(s * 0.56, 0.62, -0.56), hex("#B3182E")) -- borchie
	end
	cintura(m, VIOLA, -0.86, ORO)
	strisce(m, VIOLA, -0.96, 0.5, ORO)
end

-- ===================================================================== SCHIENA
-- La schiena del busto è a Z = +0.5.

function Costruttori.Scudo(m)
	-- Scudo curvo: tre pannelli rossi, bordo e umbone d'oro.
	local centro = C(0, -0.1, 0.78) * CFrame.Angles(0, 0, rad(-6))
	parte(m, "blocco", Vector3.new(0.56, 2.1, 0.1), centro, ROSSO)
	for _, s in ipairs({ -1, 1 }) do
		local lato = centro * C(s * 0.5, 0, -0.08) * CFrame.Angles(0, rad(s * 22), 0)
		parte(m, "blocco", Vector3.new(0.48, 2.1, 0.1), lato, ROSSO)
		parte(m, "blocco", Vector3.new(0.06, 2.14, 0.12), lato * C(s * 0.25, 0, 0), ORO_SCURO)
	end
	parte(m, "blocco", Vector3.new(1.42, 0.07, 0.14), centro * C(0, 1.06, -0.04), ORO_SCURO)
	parte(m, "blocco", Vector3.new(1.42, 0.07, 0.14), centro * C(0, -1.06, -0.04), ORO_SCURO)
	parte(m, "palla", Vector3.new(0.42, 0.42, 0.3), centro * C(0, 0, 0.08), ORO)
	for _, s in ipairs({ -1, 1 }) do -- ali stilizzate
		parte(m, "blocco", Vector3.new(0.34, 0.08, 0.04), centro * C(s * 0.34, 0.32, 0.06) * CFrame.Angles(0, 0, rad(s * 25)), ORO)
		parte(m, "blocco", Vector3.new(0.34, 0.08, 0.04), centro * C(s * 0.34, -0.32, 0.06) * CFrame.Angles(0, 0, rad(s * -25)), ORO)
	end
	parte(m, "blocco", Vector3.new(0.12, 2.0, 0.06), C(0, 0.1, 0.58) * CFrame.Angles(0, 0, rad(40)), CUOIO) -- cinghia
end

function Costruttori.Arco(m)
	-- Arco lungo in diagonale e faretra con le frecce.
	local diag = C(0, 0, 0.66) * CFrame.Angles(0, 0, rad(-28))
	for i = -2, 2 do
		local y = i * 0.62
		local x = 0.18 - (i * i) * 0.04
		parte(m, "cilindro", Vector3.new(0.66, 0.11, 0.11), diag * C(x, y, 0) * CFrame.Angles(0, 0, rad(90 + i * 7)), LEGNO, LEGNAME)
	end
	parte(m, "blocco", Vector3.new(0.02, 3.0, 0.02), diag * C(-0.06, 0, 0), BIANCO) -- corda
	parte(m, "blocco", Vector3.new(0.16, 0.3, 0.14), diag * C(0.22, 0, 0), CUOIO) -- impugnatura
	local faretra = C(0.42, 0.15, 0.82) * CFrame.Angles(0, 0, rad(22))
	parte(m, "cilindro", Vector3.new(1.3, 0.38, 0.38), faretra * CFrame.Angles(0, 0, rad(90)), CUOIO, STOFFA)
	parte(m, "cilindro", Vector3.new(0.1, 0.42, 0.42), faretra * C(0, 0.62, 0) * CFrame.Angles(0, 0, rad(90)), CUOIO_SCURO)
	for i = -1, 1 do
		local freccia = faretra * C(i * 0.09, 0.82, (i % 2) * 0.06 - 0.03)
		parte(m, "blocco", Vector3.new(0.04, 0.4, 0.04), freccia, LEGNO, LEGNAME)
		parte(m, "blocco", Vector3.new(0.12, 0.16, 0.02), freccia * C(0, 0.14, 0), BIANCO, STOFFA)
	end
end

function Costruttori.Mantello(m)
	-- Mantello reale cremisi con bordo d'oro e collo d'ermellino.
	local cf = C(0, -1.0, 0.64) * CFrame.Angles(rad(8), 0, 0)
	parte(m, "blocco", Vector3.new(2.1, 3.0, 0.1), cf, CREMISI, STOFFA)
	parte(m, "blocco", Vector3.new(2.12, 0.12, 0.12), cf * C(0, -1.46, 0), ORO, STOFFA)
	for _, s in ipairs({ -1, 1 }) do
		parte(m, "blocco", Vector3.new(0.1, 3.0, 0.12), cf * C(s * 1.03, 0, 0), ORO, STOFFA)
	end
	parte(m, "blocco", Vector3.new(2.3, 0.3, 1.24), C(0, 0.84, 0.02), BIANCO, STOFFA) -- ermellino
	for i = -3, 3 do
		parte(m, "blocco", Vector3.new(0.06, 0.12, 0.02), C(i * 0.3, 0.84, -0.63), NERO, STOFFA)
		parte(m, "blocco", Vector3.new(0.06, 0.12, 0.02), C(i * 0.3 + 0.15, 0.84, 0.65), NERO, STOFFA)
	end
	parte(m, "palla", Vector3.new(0.22, 0.22, 0.12), C(0, 0.74, -0.66), ORO) -- fermaglio
end

function Costruttori.Fucile(m)
	-- Fucile Lebel con baionetta, a tracolla sulla schiena.
	local cf = C(0.05, 0.1, 0.66) * CFrame.Angles(0, 0, rad(38))
	parte(m, "blocco", Vector3.new(0.18, 1.1, 0.14), cf * C(0, -0.7, 0), LEGNO, LEGNAME) -- calcio
	parte(m, "cuneo", Vector3.new(0.14, 0.4, 0.3), cf * C(0, -1.1, 0.06) * CFrame.Angles(0, rad(90), 0), LEGNO, LEGNAME)
	parte(m, "blocco", Vector3.new(0.12, 0.9, 0.12), cf * C(0, 0.3, 0), LEGNO, LEGNAME) -- cassa
	parte(m, "cilindro", Vector3.new(1.4, 0.07, 0.07), cf * C(0, 0.6, -0.02) * CFrame.Angles(0, 0, rad(90)), FERRO_SCURO)
	parte(m, "blocco", Vector3.new(0.05, 0.16, 0.12), cf * C(0, -0.05, 0.1), FERRO_SCURO) -- otturatore
	parte(m, "blocco", Vector3.new(0.03, 0.8, 0.07), cf * C(0, 1.62, -0.02), hex("#C4C8CE")) -- baionetta
	parte(m, "blocco", Vector3.new(0.05, 2.0, 0.03), cf * C(0.1, 0, 0.09), CUOIO) -- cinghia
end

function Costruttori.Stendardo(m)
	-- Asta con bandiera cremisi e stemma d'oro, come i portabandiera.
	parte(m, "cilindro", Vector3.new(4.2, 0.12, 0.12), verticale(0.5, 1.0, 0.72), LEGNO, LEGNAME)
	parte(m, "cilindro", Vector3.new(1.4, 0.08, 0.08), C(0.0, 2.85, 0.72), LEGNO, LEGNAME)
	local bandiera = C(-0.05, 2.25, 0.72)
	parte(m, "blocco", Vector3.new(1.3, 1.1, 0.04), bandiera, CREMISI, STOFFA)
	parte(m, "cuneo", Vector3.new(0.04, 0.4, 0.65), bandiera * C(0.325, -0.75, 0) * CFrame.Angles(0, rad(90), rad(180)), CREMISI, STOFFA)
	parte(m, "cuneo", Vector3.new(0.04, 0.4, 0.65), bandiera * C(-0.325, -0.75, 0) * CFrame.Angles(0, rad(-90), rad(180)), CREMISI, STOFFA)
	parte(m, "blocco", Vector3.new(0.42, 0.42, 0.06), bandiera * CFrame.Angles(0, 0, rad(45)), ORO, STOFFA)
	parte(m, "blocco", Vector3.new(0.22, 0.22, 0.08), bandiera * CFrame.Angles(0, 0, rad(45)), CREMISI, STOFFA)
	parte(m, "palla", Vector3.new(0.26, 0.26, 0.26), C(0.5, 3.15, 0.72), ORO)
	parte(m, "blocco", Vector3.new(0.12, 2.0, 0.06), C(0, 0.1, 0.58) * CFrame.Angles(0, 0, rad(-40)), CUOIO) -- cinghia
end

function Costruttori.Aquila(m)
	-- Aquila imperiale d'oro su asta, con la corona d'alloro e la targa SPQR.
	parte(m, "cilindro", Vector3.new(4.0, 0.12, 0.12), verticale(0.45, 0.9, 0.72), ORO_SCURO)
	local base = C(0.45, 3.0, 0.72)
	parte(m, "blocco", Vector3.new(0.6, 0.08, 0.12), base, ORO_SCURO)
	parte(m, "palla", Vector3.new(0.32, 0.46, 0.3), base * C(0, 0.3, 0), ORO) -- corpo
	parte(m, "palla", Vector3.new(0.2, 0.2, 0.2), base * C(0, 0.6, -0.06), ORO) -- testa
	parte(m, "cuneo", Vector3.new(0.06, 0.1, 0.12), base * C(0, 0.58, -0.2) * CFrame.Angles(rad(180), 0, 0), ORO_SCURO) -- becco
	for _, s in ipairs({ -1, 1 }) do
		parte(m, "blocco", Vector3.new(0.6, 0.26, 0.05), base * C(s * 0.36, 0.5, 0) * CFrame.Angles(0, 0, rad(s * 40)), ORO)
		parte(m, "blocco", Vector3.new(0.44, 0.16, 0.05), base * C(s * 0.56, 0.78, 0) * CFrame.Angles(0, 0, rad(s * 70)), ORO_SCURO)
	end
	for i = 0, 13 do -- ghirlanda sotto l'aquila, rivolta all'indietro
		local a = i / 14 * math.pi * 2
		parte(m, "blocco", Vector3.new(0.12, 0.06, 0.06), base * C(0, -0.42, 0) * CFrame.Angles(0, 0, a) * C(0, 0.24, 0), VERDE_ALLORO, STOFFA)
	end
	local targa = parte(m, "blocco", Vector3.new(0.7, 0.42, 0.06), base * C(0, -0.95, 0), ROSSO, STOFFA)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 100
	gui.LightInfluence = 1
	local scritta = Instance.new("TextLabel")
	scritta.Size = UDim2.fromScale(1, 1)
	scritta.BackgroundTransparency = 1
	scritta.Text = "SPQR"
	scritta.TextScaled = true
	scritta.Font = Enum.Font.Garamond
	scritta.TextColor3 = ORO
	scritta.Parent = gui
	gui.Parent = targa
	parte(m, "blocco", Vector3.new(0.12, 2.0, 0.06), C(0, 0.1, 0.58) * CFrame.Angles(0, 0, rad(-40)), CUOIO) -- cinghia
end

-- Modello del cosmetico alle misure standard, attorno all'origine. Restituisce il Model
-- e la parte del corpo che lo porta ("Testa" o "Busto").
function Cosmetici3D.costruisci(id, slot)
	local costruttore = Costruttori[id]
	if not costruttore then
		return nil
	end
	local modello = Instance.new("Model")
	modello.Name = id
	costruttore(modello)
	modello.WorldPivot = CFrame.new()
	for _, p in ipairs(modello:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = true
		end
	end
	return modello, RIFERIMENTO[slot] or "Busto"
end

-- Testa e busto del personaggio (R15 o R6) e la loro larghezza visibile.
local function parteDelCorpo(personaggio, riferimento)
	if riferimento == "Testa" then
		local testa = personaggio:FindFirstChild("Head")
		if not testa then
			return nil
		end
		-- La testa R6 è un blocco 2x1x1 con una mesh: si vede larga circa 1.2.
		local larghezza = testa.Size.X
		local mesh = testa:FindFirstChildOfClass("SpecialMesh")
		if mesh and mesh.MeshType == Enum.MeshType.Head then
			larghezza = 1.2 * mesh.Scale.X / 1.25
		end
		return testa, math.clamp(larghezza, 0.6, 2.4)
	end
	local busto = personaggio:FindFirstChild("UpperTorso") or personaggio:FindFirstChild("Torso")
	if not busto then
		return nil
	end
	return busto, math.clamp(busto.Size.X, 1, 4)
end

-- Mette il cosmetico addosso al personaggio, saldato alla testa o al busto. Restituisce il Model.
function Cosmetici3D.indossa(personaggio, id, slot)
	local modello, riferimento = Cosmetici3D.costruisci(id, slot)
	if not modello then
		return nil
	end
	local corpo, larghezza = parteDelCorpo(personaggio, riferimento)
	if not corpo then
		modello:Destroy()
		return nil
	end
	local scala = larghezza / MISURA[riferimento]
	if math.abs(scala - 1) > 0.01 then
		modello:ScaleTo(scala)
	end
	modello:PivotTo(corpo.CFrame)
	for _, p in ipairs(modello:GetDescendants()) do
		if p:IsA("BasePart") then
			local saldatura = Instance.new("WeldConstraint")
			saldatura.Part0 = corpo
			saldatura.Part1 = p
			saldatura.Parent = p
			p.Anchored = false
		end
	end
	modello.Parent = personaggio
	return modello
end

return Cosmetici3D
