-- Modelli 3D dei cosmetici, fatti di parti opache (niente lucido), nello stile a blocchi delle truppe.
-- Ogni modello è costruito attorno al centro della parte del corpo che lo porta (Testa o Busto),
-- con le misure di un avatar standard (testa 1.2, busto R15 2 x 1.6 x 1): davanti è -Z, sopra è +Y.
-- Cosmetici3D.indossa lo ridimensiona sulla testa o sul busto vero del personaggio e lo salda lì.
-- Lo usano il server (cosmetici addosso ai giocatori) e il client (anteprime nelle finestre).

local Cosmetici3D = {}

local RIFERIMENTO = { Testa = "Testa", Corpo = "Busto", Schiena = "Busto" }
local MISURA = { Testa = 1.2 } -- larghezza della testa standard (il busto standard è 2 x 1.6 x 1)

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
			-- Una Part a sfera resta una sfera perfetta: per gli ellissoidi serve una mesh a sfera,
			-- che riempie la scatola della parte qualunque siano le tre misure.
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
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

-- Cilindro da un punto a un altro (un po' più lungo, così i tratti si toccano).
local function tubo(modello, a, b, diametro, colore, materiale)
	local centro = (a + b) / 2
	local lunghezza = (b - a).Magnitude + diametro * 0.5
	local cf = CFrame.lookAt(centro, b) * CFrame.Angles(0, rad(90), 0)
	return parte(modello, "cilindro", Vector3.new(lunghezza, diametro, diametro), cf, colore, materiale)
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

-- La scritta d'oro SPQR sul retro (+Z) della targa dell'aquila.
local function scrittaSPQR(targa)
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
		parte(m, "blocco", Vector3.new(0.08, 0.6, 0.42), C(s * 0.7, -0.15, -0.22) * CFrame.Angles(0, 0, rad(s * 4)), FERRO)
		parte(m, "palla", Vector3.new(0.12, 0.12, 0.12), C(s * 0.74, -0.05, -0.22), OTTONE)
	end
	parte(m, "blocco", Vector3.new(0.12, 0.08, 1.0), C(0, 0.84, 0.02), OTTONE) -- supporto
	for i = -3, 3 do -- cresta di crine che segue la curva dell'elmo, da davanti a dietro
		local a = i * 0.34
		local pos = Vector3.new(0, 0.4 + 0.5 * math.cos(a), 0.02 + 0.78 * math.sin(a))
		parte(m, "palla", Vector3.new(0.2, 0.46, 0.36), CFrame.new(pos) * CFrame.Angles(a, 0, 0), ROSSO, STOFFA)
	end
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
	parte(m, "palla", Vector3.new(1.4, 0.92, 1.46), C(0, 0.56, 0.02), blu)
	parte(m, "palla", Vector3.new(1.62, 0.07, 1.86), C(0, 0.32, 0), blu) -- tesa
	parte(m, "blocco", Vector3.new(0.12, 0.16, 1.12), C(0, 1.02, 0.02), blu) -- cresta
	parte(m, "blocco", Vector3.new(0.2, 0.22, 0.05), C(0, 0.62, -0.7) * CFrame.Angles(rad(-14), 0, 0), OTTONE)
	parte(m, "palla", Vector3.new(0.14, 0.14, 0.06), C(0, 0.69, -0.72), OTTONE)
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
	local cf = C(0, 0.5, 0.02) * CFrame.Angles(rad(-8), 0, 0)
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
	parte(m, "blocco", Vector3.new(0.12, 0.26, 0.1), C(0, 0.08, -0.74), FERRO_SCURO) -- nasale
	local avorio = hex("#E6DCC2")
	for _, s in ipairs({ -1, 1 }) do
		-- Corno curvo: tratti che si sovrappongono, sempre più sottili, fino alla punta.
		local punti = {
			Vector3.new(s * 0.6, 0.4, 0),
			Vector3.new(s * 0.86, 0.48, -0.04),
			Vector3.new(s * 1.04, 0.66, -0.08),
			Vector3.new(s * 1.12, 0.88, -0.1),
			Vector3.new(s * 1.1, 1.06, -0.1),
		}
		local diametri = { 0.3, 0.24, 0.18, 0.12 }
		for i = 1, #punti - 1 do
			tubo(m, punti[i], punti[i + 1], diametri[i], avorio)
			parte(m, "palla", Vector3.one * diametri[i], CFrame.new(punti[i + 1]), avorio)
		end
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
	parte(m, "palla", Vector3.new(1.2, 0.36, 1.12), C(0, 0.8, 0), giubba, STOFFA) -- colletto
	for _, s in ipairs({ -1, 1 }) do -- spalle arrotondate con le spalline
		parte(m, "palla", Vector3.new(0.9, 0.62, 1.16), C(s * 0.94, 0.62, 0), giubba, STOFFA)
		parte(m, "blocco", Vector3.new(0.5, 0.06, 0.22), C(s * 0.82, 0.92, 0) * CFrame.Angles(0, 0, rad(s * -12)), hex("#4B5868"), STOFFA)
		parte(m, "palla", Vector3.new(0.09, 0.09, 0.06), C(s * 0.62, 0.95, -0.02), OTTONE)
	end
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
	-- Mantello reale cremisi che scende dalle spalle e si allarga, bordo d'oro, rotolo d'ermellino sul collo.
	local fasce = { -- { y del centro, altezza, larghezza, inclinazione }
		{ 0.35, 0.9, 2.0, 4 },
		{ -0.5, 0.9, 2.2, 9 },
		{ -1.35, 0.9, 2.4, 14 },
	}
	-- Ogni fascia ha la sua cerniera in cima (attributo "Cerniera<i>" del modello, "Fascia" sulle parti):
	-- indossa la salda con un Weld e il client la fa ondeggiare (Mantelli.luau).
	local z = 0.6
	local yPrima = 0.8
	for i, f in ipairs(fasce) do
		local alto = f[2]
		m:SetAttribute("Cerniera" .. i, Vector3.new(0, yPrima, z))
		local function telo(...)
			parte(m, ...):SetAttribute("Fascia", i)
		end
		local cf = C(0, yPrima - alto / 2, z) * CFrame.Angles(rad(f[4]), 0, 0)
		telo("blocco", Vector3.new(f[3], alto + 0.24, 0.1), cf, CREMISI, STOFFA)
		for _, s in ipairs({ -1, 1 }) do -- i lati piegati in avanti danno la curva
			telo("blocco", Vector3.new(0.3, alto + 0.24, 0.1), cf * C(s * (f[3] / 2 + 0.1), 0, -0.1) * CFrame.Angles(0, rad(s * -40), 0), CREMISI, STOFFA)
			telo("blocco", Vector3.new(0.06, alto + 0.24, 0.12), cf * C(s * (f[3] / 2 + 0.2), 0, -0.2) * CFrame.Angles(0, rad(s * -40), 0), ORO, STOFFA)
		end
		if i == #fasce then
			telo("blocco", Vector3.new(f[3] + 0.4, 0.1, 0.12), cf * C(0, -alto / 2, 0), ORO, STOFFA)
		end
		yPrima -= alto * math.cos(rad(f[4]))
		z += alto * math.sin(rad(f[4]))
	end
	-- Ermellino: un rotolo morbido attorno al collo, con le codine nere.
	for i = -2, 2 do
		local a = rad(i * 22)
		local pos = Vector3.new(math.sin(a) * 0.75, 0.86, math.cos(a) * 0.45 + 0.05)
		parte(m, "palla", Vector3.new(0.55, 0.32, 0.4), CFrame.new(pos) * CFrame.Angles(0, a, 0), BIANCO, STOFFA)
		parte(m, "blocco", Vector3.new(0.05, 0.12, 0.03), CFrame.new(pos) * CFrame.Angles(0, a, 0) * C(0.1, 0, 0.2), NERO, STOFFA)
	end
	parte(m, "palla", Vector3.new(0.22, 0.22, 0.12), C(0, 0.74, -0.62), ORO) -- fermaglio
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
	-- Asta di fianco alla testa, bandiera cremisi in alto sopra la testa, stemma d'oro.
	local x, z = 0.95, 0.78
	parte(m, "cilindro", Vector3.new(4.7, 0.12, 0.12), verticale(x, 1.55, z), LEGNO, LEGNAME)
	parte(m, "cilindro", Vector3.new(1.5, 0.08, 0.08), C(x - 0.6, 3.62, z), LEGNO, LEGNAME)
	local bandiera = C(x - 0.62, 3.05, z)
	parte(m, "blocco", Vector3.new(1.3, 1.1, 0.04), bandiera, CREMISI, STOFFA)
	parte(m, "cuneo", Vector3.new(0.04, 0.35, 0.65), bandiera * C(0.325, -0.72, 0) * CFrame.Angles(0, rad(90), rad(180)), CREMISI, STOFFA)
	parte(m, "cuneo", Vector3.new(0.04, 0.35, 0.65), bandiera * C(-0.325, -0.72, 0) * CFrame.Angles(0, rad(-90), rad(180)), CREMISI, STOFFA)
	parte(m, "blocco", Vector3.new(0.42, 0.42, 0.06), bandiera * CFrame.Angles(0, 0, rad(45)), ORO, STOFFA)
	parte(m, "blocco", Vector3.new(0.22, 0.22, 0.08), bandiera * CFrame.Angles(0, 0, rad(45)), CREMISI, STOFFA)
	parte(m, "palla", Vector3.new(0.26, 0.26, 0.26), C(x, 3.95, z), ORO)
	parte(m, "blocco", Vector3.new(0.12, 2.0, 0.06), C(0, 0.1, 0.58) * CFrame.Angles(0, 0, rad(-40)), CUOIO) -- cinghia
end

function Costruttori.Aquila(m)
	-- Aquila imperiale d'oro su asta, con la corona d'alloro e la targa SPQR.
	parte(m, "cilindro", Vector3.new(4.9, 0.12, 0.12), verticale(1.0, 1.45, 0.78), ORO_SCURO)
	local base = C(1.0, 3.1, 0.78)
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
		parte(m, "blocco", Vector3.new(0.12, 0.06, 0.06), base * C(0, -0.22, 0) * CFrame.Angles(0, 0, a) * C(0, 0.2, 0), VERDE_ALLORO, STOFFA)
	end
	scrittaSPQR(parte(m, "blocco", Vector3.new(0.7, 0.42, 0.06), base * C(0, -0.62, 0), ROSSO, STOFFA))
	parte(m, "blocco", Vector3.new(0.12, 2.0, 0.06), C(0, 0.1, 0.58) * CFrame.Angles(0, 0, rad(-40)), CUOIO) -- cinghia
end

-- ===================================================================== AURE
-- Un'aura è fatta di particelle attorno al corpo (non hanno forma). Nelle finestre, dove le particelle non si
-- vedono, si mostra un globo luminoso con i suoi colori; addosso, un blocco invisibile saldato alla radice del
-- personaggio fa uscire le particelle (Cosmetici3D.indossa).

local SCINTILLE = "rbxasset://textures/particles/sparkles_main.dds"
local FUMO = "rbxasset://textures/particles/smoke_main.dds"
local FUOCO = "rbxasset://textures/particles/fire_main.dds"

-- Ogni emettitore: texture, colori (inizio, fine), quanti al secondo, misura, durata, velocità verso l'alto,
-- piedi = escono da terra attorno ai piedi invece che da tutto il corpo.
local AURE = {
	AuraFedele = {
		globo = { hex("#FFE07A"), hex("#FFF6D0") },
		luce = hex("#FFD86A"),
		emettitori = {
			{ texture = SCINTILLE, colori = { hex("#FFE58A"), hex("#FFB830") }, rate = 18, misura = 0.45, durata = 1.6, su = 2.5 },
			{ texture = SCINTILLE, colori = { hex("#FFFFFF"), hex("#FFE9A8") }, rate = 8, misura = 0.25, durata = 2.2, su = 1.2, piedi = true },
		},
	},
	AuraBrace = {
		globo = { hex("#FF7A1A"), hex("#FFC14D") },
		luce = hex("#FF7A2A"),
		emettitori = {
			{ texture = FUOCO, colori = { hex("#FFB040"), hex("#B21E0A") }, rate = 34, misura = 1.7, durata = 0.8, su = 5, piedi = true, luminosa = 1, velocita = { 2, 4 }, apertura = 12, trasparenza = 0.25 },
			{ texture = SCINTILLE, colori = { hex("#FFD27A"), hex("#FF5A10") }, rate = 10, misura = 0.25, durata = 1.4, su = 4 },
		},
	},
	AuraGelo = {
		globo = { hex("#9FE3FF"), hex("#FFFFFF") },
		luce = hex("#9FDcff"),
		emettitori = {
			{ texture = SCINTILLE, colori = { hex("#FFFFFF"), hex("#8FD8FF") }, rate = 16, misura = 0.35, durata = 2.2, su = -0.8 },
			{ texture = FUMO, colori = { hex("#E8F7FF"), hex("#A8D8F0") }, rate = 12, misura = 2, durata = 1.8, su = 0.4, piedi = true, trasparenza = 0.45, luce = 0, luminosa = 0.3 },
		},
	},
	AuraFumo = {
		globo = { hex("#6E6A64"), hex("#A8A29A") },
		emettitori = {
			{ texture = FUMO, colori = { hex("#B8B0A4"), hex("#6A645C") }, rate = 16, misura = 2.6, durata = 2.4, su = 1.4, piedi = true, trasparenza = 0.3, luce = 0.3 },
			{ texture = SCINTILLE, colori = { hex("#FFB060"), hex("#7A2A10") }, rate = 4, misura = 0.2, durata = 1.2, su = 3, piedi = true },
		},
	},
	AuraSangue = {
		globo = { hex("#B0141E"), hex("#FF4A4A") },
		luce = hex("#D0202A"),
		emettitori = {
			{ texture = FUMO, colori = { hex("#E0202C"), hex("#600810") }, rate = 16, misura = 2.2, durata = 1.8, su = 1.8, piedi = true, trasparenza = 0.3, luce = 0, luminosa = 0.5 },
			{ texture = SCINTILLE, colori = { hex("#FF5A5A"), hex("#8A0A10") }, rate = 10, misura = 0.3, durata = 1.4, su = 2.2 },
		},
	},
	AuraTempesta = {
		globo = { hex("#4A8CFF"), hex("#E0F0FF") },
		luce = hex("#6AA8FF"),
		emettitori = {
			{ texture = SCINTILLE, colori = { hex("#E6F4FF"), hex("#3A7CFF") }, rate = 26, misura = 0.4, durata = 0.6, su = 0, veloce = true },
			{ texture = FUMO, colori = { hex("#7A90B0"), hex("#3A4660") }, rate = 12, misura = 2.2, durata = 2, su = 0.6, piedi = true, trasparenza = 0.4, luce = 0.3 },
		},
	},
	AuraReale = {
		globo = { hex("#8A3CE0"), hex("#FFD23F") },
		luce = hex("#B070FF"),
		emettitori = {
			{ texture = SCINTILLE, colori = { hex("#C890FF"), hex("#6A20C0") }, rate = 16, misura = 0.45, durata = 1.8, su = 2 },
			{ texture = SCINTILLE, colori = { hex("#FFE27A"), hex("#FFB020") }, rate = 10, misura = 0.3, durata = 2, su = 1.4, piedi = true },
		},
	},
}

-- Globo per le finestre: nucleo luminoso, guscio velato e scintille attorno, nei colori dell'aura.
for id, aura in pairs(AURE) do
	Costruttori[id] = function(m)
		local a, b = aura.globo[1], aura.globo[2]
		parte(m, "palla", Vector3.new(1.1, 1.1, 1.1), C(0, 0, 0), a, Enum.Material.Neon)
		local guscio = parte(m, "palla", Vector3.new(1.9, 1.9, 1.9), C(0, 0, 0), b, Enum.Material.Glass)
		guscio.Transparency = 0.6
		for i = 0, 7 do
			local ang = i / 8 * math.pi * 2
			local alto = math.sin(i * 1.7) * 0.7
			parte(m, "palla", Vector3.new(0.22, 0.22, 0.22), C(math.cos(ang) * 1.45, alto, math.sin(ang) * 1.45), i % 2 == 0 and a or b, Enum.Material.Neon)
		end
		anello(m, 20, 1.25, -0.95, Vector3.new(0.34, 0.06, 0.1), b, Enum.Material.Neon)
	end
end

local function invisibile(nome, misura)
	local p = Instance.new("Part")
	p.Name = nome
	p.Transparency = 1
	p.Size = misura
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	return p
end

-- I blocchi invisibili che fanno uscire le particelle: uno grande quanto il corpo (alto "altezza") e uno
-- piatto ai piedi. Restituisce il blocco del corpo, con quello dei piedi dentro (da saldare).
local function emettitoriAura(aura, altezza)
	local blocco = invisibile("Aura", Vector3.new(2.6, altezza, 2.2))
	local piedi = invisibile("AuraPiedi", Vector3.new(3, 0.2, 3))
	piedi.Parent = blocco
	for _, e in ipairs(aura.emettitori) do
		local emettitore = Instance.new("ParticleEmitter")
		emettitore.Texture = e.texture
		emettitore.Color = ColorSequence.new(e.colori[1], e.colori[2])
		-- Le scintille sono minuscole: ne servono tante e grandi perché l'aura si veda anche da lontano.
		local scintille = e.texture == SCINTILLE
		local misura = scintille and e.misura * 1.6 or e.misura
		emettitore.Rate = scintille and e.rate * 2.2 or e.rate
		emettitore.Lifetime = NumberRange.new(e.durata * 0.7, e.durata)
		emettitore.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, misura * 0.6),
			NumberSequenceKeypoint.new(0.3, misura),
			NumberSequenceKeypoint.new(1, 0),
		})
		local t = e.trasparenza or 0.1
		emettitore.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.15, t),
			NumberSequenceKeypoint.new(0.75, t),
			NumberSequenceKeypoint.new(1, 1),
		})
		emettitore.LightEmission = e.luminosa or (e.texture == FUMO and 0 or 1)
		emettitore.LightInfluence = e.luce or (e.texture == FUMO and 1 or 0)
		emettitore.Rotation = NumberRange.new(0, 360)
		emettitore.RotSpeed = NumberRange.new(-60, 60)
		emettitore.Acceleration = Vector3.new(0, e.su, 0)
		local v = e.velocita or (e.veloce and { 2, 4 }) or { 0.2, 0.8 }
		emettitore.Speed = NumberRange.new(v[1], v[2])
		emettitore.SpreadAngle = Vector2.new(e.apertura or 180, e.apertura or 180)
		emettitore.Drag = e.veloce and 3 or 0.5
		-- Dai piedi escono dal blocco piatto a terra; le altre da tutto il corpo.
		emettitore.Shape = Enum.ParticleEmitterShape.Box
		emettitore.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		emettitore.Parent = e.piedi and piedi or blocco
	end
	if aura.luce then
		local luce = Instance.new("PointLight")
		luce.Color = aura.luce
		luce.Brightness = 0.6
		luce.Range = 7
		luce.Shadows = false
		luce.Parent = blocco
	end
	return blocco
end

-- Modello del cosmetico alle misure standard, attorno all'origine. Restituisce il Model
-- e la parte del corpo che lo porta ("Testa" o "Busto").
-- ===================================================================== MODELLI DI BLENDER
-- I cosmetici rifatti in Blender (assets-foto/cosmetici.py) sono in ReplicatedStorage.CosmeticiMesh: un Model per
-- cosmetico, con le MeshPart alle misure standard attorno all'origine. Ogni MeshPart si chiama
-- "<Cosmetico>_<Colore>" (le fasce del mantello "<Cosmetico>_<Colore>_F<n>"): il colore e il materiale li dà
-- questa tabella. Se il modello di Blender manca, si usa il costruttore a blocchi qui sopra.
local COLORI_MESH = {
	Ferro = { FERRO }, FerroScuro = { FERRO_SCURO }, Acciaio = { ACCIAIO }, Ottone = { OTTONE },
	Oro = { ORO }, OroScuro = { ORO_SCURO }, Cuoio = { CUOIO, Enum.Material.Leather },
	CuoioScuro = { CUOIO_SCURO, Enum.Material.Leather }, Legno = { LEGNO, LEGNAME }, Rosso = { ROSSO, STOFFA },
	Cremisi = { CREMISI, STOFFA }, Bianco = { BIANCO, STOFFA }, Nero = { NERO }, Alloro = { VERDE_ALLORO },
	AlloroChiaro = { hex("#6E9A48") }, Ramo = { hex("#5A4A2A"), LEGNAME }, Viola = { VIOLA, STOFFA },
	BluOrizzonte = { hex("#6F8296") }, BluOrizzonteScuro = { hex("#5A6B7E") }, BluKepi = { hex("#1E2A55"), STOFFA },
	RossoKepi = { hex("#A3202C"), STOFFA }, Avorio = { hex("#E6DCC2") }, CornoPunta = { hex("#4A3A2A") },
	Rubino = { hex("#B3182E") }, Zaffiro = { hex("#1F5FB8") }, Perla = { hex("#F2EEE4") },
	Velluto = { hex("#7A1426"), STOFFA }, Ermellino = { hex("#F1EEE6"), STOFFA }, Giubba = { hex("#6C7F99"), STOFFA },
	GiubbaScura = { hex("#4B5868"), STOFFA }, Crine = { hex("#A3242A"), STOFFA },
	Piuma = { hex("#E9E4D6"), STOFFA }, PiumaRossa = { ROSSO, STOFFA }, Corda = { hex("#D9D2BE"), STOFFA },
	Targa = { ROSSO, STOFFA },
	-- Capelli corti da soldato sotto kepì e Adrian: coprono la nuca, così la testa non sembra calva.
	CapelliCorti = { hex("#3A2A20"), Enum.Material.SmoothPlastic },
	-- Era moderna: elmetto M1, giubbotto antiproiettile, radio da campo (tela e vernice verde oliva).
	OlivaM1 = { hex("#56603F"), STOFFA }, OlivaScuro = { hex("#3F4630"), STOFFA }, Mimetica = { hex("#6E5E3A"), STOFFA },
	Radio = { hex("#4E5638") }, Kaki = { hex("#8A7E58"), STOFFA },
}
-- Texture che hanno già il loro colore (la parte resta SmoothPlastic sotto): ciocche del crine e pelo d'ermellino.
local TEXTURE_MESH = {
	Crine = "rbxassetid://76896273696498",
	Ermellino = "rbxassetid://135148699216148",
}
-- Superfici PBR (SurfaceAppearance): le mappe da script non si possono scrivere, quindi gli stampi sono in
-- CosmeticiMesh._Superfici e qui si copiano e si tingono. Metallo = metallo splendente (richiesta di Mattia),
-- Lucido = vetro e vernice, Satinato = avorio e smalto.
-- Per riflettere serve Lighting.EnvironmentSpecularScale alto (Config/Luci).
local SUPERFICI = {
	Ferro = { "Metallo", hex("#7C838E") }, FerroScuro = { "Metallo", hex("#4A5059") },
	Acciaio = { "Metallo", hex("#9AA1AB") }, Ottone = { "Metallo", hex("#B8862A") },
	Oro = { "Metallo", hex("#D9A93A") }, OroScuro = { "Metallo", hex("#A07A26") },
	Rubino = { "Lucido", hex("#B3182E") }, Zaffiro = { "Lucido", hex("#1F5FB8") }, Perla = { "Lucido", hex("#F2EEE4") },
	Avorio = { "Satinato", hex("#E6DCC2") }, CornoPunta = { "Satinato", hex("#4A3A2A") },
	BluOrizzonte = { "Satinato", hex("#6F8296") }, BluOrizzonteScuro = { "Satinato", hex("#5A6B7E") },
	Alloro = { "Satinato", VERDE_ALLORO }, AlloroChiaro = { "Satinato", hex("#6E9A48") },
}
-- Eccezioni per un solo cosmetico: la visiera del kepì è di cuoio verniciato.
local SUPERFICI_DI = { Kepi = { Nero = { "Lucido", hex("#15141A") } } }

-- Cerniere del mantello: il punto in cima al centro di ogni fascia (mantello_punto in cosmetici.py).
local CERNIERE_MESH = {
	Mantello = { Vector3.new(0, 0.85, 0.56), Vector3.new(0, -0.1, 0.7), Vector3.new(0, -1.05, 0.84) },
}

local function daBlender(id)
	local cartella = game:GetService("ReplicatedStorage"):FindFirstChild("CosmeticiMesh")
	local stampo = cartella and cartella:FindFirstChild(id)
	if not stampo then
		return nil
	end
	local superfici = cartella:FindFirstChild("_Superfici")
	local modello = stampo:Clone()
	for _, p in ipairs(modello:GetDescendants()) do
		if p:IsA("MeshPart") then
			local colore, fascia = string.match(p.Name, "^[^_]+_([^_]+)_?F?(%d*)$")
			local aspetto = COLORI_MESH[colore or ""]
			if aspetto then
				p.Color = aspetto[1]
				p.Material = aspetto[2] or PLASTICA
			end
			if TEXTURE_MESH[colore] then
				p.TextureID = TEXTURE_MESH[colore]
				p.Material = Enum.Material.SmoothPlastic
			end
			local sup = (SUPERFICI_DI[id] or {})[colore] or SUPERFICI[colore]
			local stampoSup = sup and superfici and superfici:FindFirstChild(sup[1])
			if stampoSup then
				local s = stampoSup:Clone()
				s.Color = sup[2]
				s.Parent = p
				p.Color = sup[2]
				if sup[1] == "Metallo" then
					p.Material = Enum.Material.Metal
				end
			end
			if fascia and fascia ~= "" then
				p:SetAttribute("Fascia", tonumber(fascia))
			end
			if colore == "Targa" then
				scrittaSPQR(p)
			end
			p.CastShadow = true
		end
	end
	for i, punto in ipairs(CERNIERE_MESH[id] or {}) do
		modello:SetAttribute("Cerniera" .. i, punto)
	end
	modello:SetAttribute("Blender", true)
	return modello
end

function Cosmetici3D.costruisci(id, slot)
	local modello = daBlender(id)
	if not modello then
		local costruttore = Costruttori[id]
		if not costruttore then
			return nil
		end
		modello = Instance.new("Model")
		modello.Name = id
		costruttore(modello)
	end
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

-- Testa e busto del personaggio (R15 o R6) e quanto sono grandi rispetto alla parte standard,
-- asse per asse: la testa cresce uguale in tutte le direzioni, il busto segue larghezza, altezza e spessore veri.
local function parteDelCorpo(personaggio, riferimento)
	if riferimento == "Testa" then
		local testa = personaggio:FindFirstChild("Head")
		if not testa then
			return nil
		end
		-- La testa R6 è un blocco 2x1x1 con una mesh: si vede larga circa 1.2.
		local larghezza = math.max(testa.Size.X, testa.Size.Z)
		local altezza = testa.Size.Y
		local mesh = testa:FindFirstChildOfClass("SpecialMesh")
		local r6 = mesh and mesh.MeshType == Enum.MeshType.Head
		if r6 then
			larghezza = 1.2 * mesh.Scale.X / 1.25
			altezza = larghezza
		end
		local k = math.clamp(larghezza / MISURA.Testa, 0.5, 2)
		-- Teste più alte che larghe (molte teste dinamiche): il copricapo si appoggia in cima, non a metà.
		local su = math.max(0, altezza / 2 - MISURA.Testa / 2 * k)
		if r6 then
			su = 0.15 * k -- la faccia R6 ha gli occhi più in alto: il bordo degli elmi li copriva (provato in Studio)
		end
		return testa, Vector3.new(k, k, k), su
	end
	local busto = personaggio:FindFirstChild("UpperTorso") or personaggio:FindFirstChild("Torso")
	if not busto then
		return nil
	end
	local misura = busto.Size
	return busto,
		Vector3.new(
			math.clamp(misura.X / 2, 0.5, 2),
			math.clamp(misura.Y / 1.6, 0.5, 2),
			math.clamp(misura.Z / 1, 0.5, 2)
		)
end

-- Ridimensiona il modello (costruito attorno all'origine) di k asse per asse.
local function scala(modello, k)
	for _, p in ipairs(modello:GetDescendants()) do
		if p:IsA("BasePart") then
			local cf = p.CFrame
			local function fattore(asse)
				return (asse * k).Magnitude
			end
			p.Size = p.Size * Vector3.new(fattore(cf.XVector), fattore(cf.YVector), fattore(cf.ZVector))
			p.CFrame = cf.Rotation + cf.Position * k
		end
	end
end

-- Mette il cosmetico addosso al personaggio, saldato alla testa o al busto. Restituisce il Model.
function Cosmetici3D.indossa(personaggio, id, slot)
	if slot == "Aura" then
		local aura = AURE[id]
		local radice = personaggio:FindFirstChild("HumanoidRootPart")
		local umanoide = personaggio:FindFirstChildOfClass("Humanoid")
		if not (aura and radice) then
			return nil
		end
		-- Altezza del corpo: dalle anche (HipHeight) fino in cima alla testa, circa.
		local anca = umanoide and umanoide.HipHeight or 2
		local altezza = math.clamp(anca + radice.Size.Y / 2 + 2.2, 4, 9)
		local modello = Instance.new("Model")
		modello.Name = id
		local blocco = emettitoriAura(aura, altezza)
		-- Il centro del blocco sta a metà tra i piedi e la cima della testa.
		local piediY = -(radice.Size.Y / 2 + anca)
		blocco.CFrame = radice.CFrame * CFrame.new(0, piediY + altezza / 2, 0)
		local piedi = blocco.AuraPiedi
		piedi.CFrame = radice.CFrame * CFrame.new(0, piediY + 0.15, 0)
		for _, p in ipairs({ blocco, piedi }) do
			local saldatura = Instance.new("WeldConstraint")
			saldatura.Part0 = radice
			saldatura.Part1 = p
			saldatura.Parent = p
		end
		blocco.Parent = modello
		modello.Parent = personaggio
		return modello
	end
	local modello, riferimento = Cosmetici3D.costruisci(id, slot)
	if not modello then
		return nil
	end
	local corpo, k, su = parteDelCorpo(personaggio, riferimento)
	if not corpo then
		modello:Destroy()
		return nil
	end
	if slot == "Corpo" and not modello:GetAttribute("Blender") then
		-- Il busto vero non è una scatola: il petto sporge. L'armatura a blocchi sta un po' più larga e profonda
		-- (quelle di Blender sono già fatte più larghe del busto).
		k *= Vector3.new(1.04, 1.02, 1.2)
	end
	scala(modello, k)
	for nome, valore in pairs(modello:GetAttributes()) do
		if string.sub(nome, 1, 8) == "Cerniera" then
			modello:SetAttribute(nome, valore * k) -- nello spazio della parte del corpo, come il modello
		end
	end
	modello:PivotTo(corpo.CFrame * CFrame.new(0, su or 0, 0))
	for _, p in ipairs(modello:GetDescendants()) do
		if p:IsA("BasePart") then
			if p:GetAttribute("Fascia") then
				-- Le parti che si muovono (il telo del mantello) usano un Weld: il client ne cambia C0.
				local saldatura = Instance.new("Weld")
				saldatura.Name = "Telo"
				saldatura.Part0 = corpo
				saldatura.Part1 = p
				saldatura.C0 = corpo.CFrame:ToObjectSpace(p.CFrame)
				saldatura:SetAttribute("Base", saldatura.C0)
				saldatura.Parent = p
			else
				local saldatura = Instance.new("WeldConstraint")
				saldatura.Part0 = corpo
				saldatura.Part1 = p
				saldatura.Parent = p
			end
			p.Anchored = false
		end
	end
	modello.Parent = personaggio
	return modello
end

return Cosmetici3D
