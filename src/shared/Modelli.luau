-- Modelli dei soldati: quelli fatti in Blender (Shared/Mesh, con ossa) e, per le truppe che non li hanno
-- ancora, figure costruite con parti semplici. Entrambi hanno le stesse "articolazioni" con i nomi delle
-- ossa del gioco (bacino, torace, testa, braccio.R...), che il client anima con .Transform
-- (Bone o Motor6D): a riposo sono orientate come il modello, quindi si ruota attorno agli assi del soldato.
-- Il fronte del modello è la direzione -Z, la sua destra è +X. La parte "Radice" è ancorata a terra.

local Mesh = require(script.Parent.Mesh)

local Modelli = {}

Modelli.COLORI_SQUADRA = {
	giocatore = Color3.fromRGB(52, 112, 220),
	nemico = Color3.fromRGB(204, 56, 56),
}

local PELLE = Color3.fromRGB(232, 186, 146)
local SCURO = Color3.fromRGB(44, 42, 40)
local CUOIO = Color3.fromRGB(104, 70, 40)
local METALLO = Color3.fromRGB(172, 176, 186)
local LEGNO = Color3.fromRGB(120, 80, 44)
local OLIVA = Color3.fromRGB(88, 100, 58)
local KAKI = Color3.fromRGB(150, 136, 96)
local ORO = Color3.fromRGB(230, 184, 70)
local BRONZO = Color3.fromRGB(184, 128, 64)
local ROSSO_ROMANO = Color3.fromRGB(168, 32, 32)
local BLU_ORIZZONTE = Color3.fromRGB(122, 146, 176)
local PIETRA = Color3.fromRGB(150, 146, 136)
local CEMENTO = Color3.fromRGB(128, 128, 120)

local function nuovaRadice(modello, cframe)
	local radice = Instance.new("Part")
	radice.Name = "Radice"
	radice.Size = Vector3.new(0.2, 0.2, 0.2)
	radice.Transparency = 1
	radice.Anchored = true
	radice.CanCollide = false
	radice.CanQuery = false
	radice.CanTouch = false
	radice.CFrame = cframe
	radice.Parent = modello
	modello.PrimaryPart = radice
	return radice
end

-- Figure a parti: ogni pezzo è saldato al segmento del corpo a cui appartiene; i segmenti sono uniti
-- da Motor6D nei punti delle articolazioni (coordinate della figura prima della scala).
local SCHELETRI = {
	fante = {
		{ "bacino", nil, Vector3.new(0, 1.45, 0) },
		{ "torace", "bacino", Vector3.new(0, 1.5, 0) },
		{ "testa", "torace", Vector3.new(0, 2.95, 0) },
		{ "braccio.R", "torace", Vector3.new(0.93, 2.8, -0.1) },
		{ "braccio.L", "torace", Vector3.new(-0.93, 2.8, -0.1) },
		{ "coscia.R", "bacino", Vector3.new(0.32, 1.4, 0) },
		{ "coscia.L", "bacino", Vector3.new(-0.32, 1.4, 0) },
	},
	cavallo = {
		{ "bacino", nil, Vector3.new(0, 2.0, 0) },
		{ "torace", "bacino", Vector3.new(0, 2.9, 0.2) },
		{ "testa", "torace", Vector3.new(0, 4.1, 0.2) },
		{ "braccio.R", "torace", Vector3.new(0.85, 3.9, 0.1) },
		{ "braccio.L", "torace", Vector3.new(-0.85, 3.9, 0.1) },
		{ "collo", "bacino", Vector3.new(0, 2.6, -1.3) },
		{ "zampa.AR", "bacino", Vector3.new(0.45, 1.4, -1.1) },
		{ "zampa.AL", "bacino", Vector3.new(-0.45, 1.4, -1.1) },
		{ "zampa.PR", "bacino", Vector3.new(0.45, 1.4, 1.1) },
		{ "zampa.PL", "bacino", Vector3.new(-0.45, 1.4, 1.1) },
		{ "coda", "bacino", Vector3.new(0, 2.5, 1.5) },
	},
	carro = {
		{ "bacino", nil, Vector3.new(0, 1.2, 0) },
		{ "torretta", "bacino", Vector3.new(0, 1.9, 0.4) },
	},
	rigido = {
		{ "bacino", nil, Vector3.new(0, 1, 0) },
	},
}

-- Segmento di un pezzo, dalla posizione del suo centro.
local CLASSIFICA = {
	fante = function(x, y, _z)
		if y < 1.45 and math.abs(x) < 0.75 then
			return x > 0 and "coscia.R" or "coscia.L"
		elseif math.abs(x) >= 0.75 and y >= 1.2 then
			return x > 0 and "braccio.R" or "braccio.L"
		elseif y >= 3.0 then
			return "testa"
		end
		return "torace"
	end,
	cavallo = function(x, y, z)
		if y < 1.45 and math.abs(x) < 0.8 then
			return (z < 0 and "zampa.A" or "zampa.P") .. (x > 0 and "R" or "L")
		elseif math.abs(x) >= 0.75 and y >= 2.9 then
			return x > 0 and "braccio.R" or "braccio.L"
		elseif y >= 4.2 then
			return "testa"
		elseif z < -1.2 and y > 2.5 then
			return "collo"
		elseif z > 1.5 then
			return "coda"
		elseif y >= 2.9 and z > -0.6 then
			return "torace"
		end
		return "bacino"
	end,
	carro = function(_x, y, _z)
		return y >= 1.9 and "torretta" or "bacino"
	end,
	rigido = function()
		return "bacino"
	end,
}

local function parteSemplice(genitore, dimensione, cframe, colore, forma, materiale)
	local p = Instance.new("Part")
	p.Size = dimensione
	p.Color = colore
	p.Shape = forma or Enum.PartType.Block
	p.Material = materiale or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.CastShadow = true
	p.CFrame = cframe
	p.Parent = genitore
	return p
end

-- Costruisce i segmenti e restituisce la funzione p(dimensione, x, y, z, colore, forma, materiale, rotazione)
-- con cui le FIGURE aggiungono i pezzi, già saldati al segmento giusto.
local function rig(modello, radice, tipoScheletro, s)
	local segmenti, giunti = {}, {}
	for _, voce in ipairs(SCHELETRI[tipoScheletro]) do
		local nome, padre, perno = voce[1], voce[2], voce[3]
		local seg = Instance.new("Part")
		seg.Name = nome
		seg.Size = Vector3.one * 0.1
		seg.Transparency = 1
		seg.CanCollide = false
		seg.CanQuery = false
		seg.CanTouch = false
		seg.Massless = true
		seg.CFrame = radice.CFrame * CFrame.new(perno * s)
		seg.Parent = modello
		local base = padre and segmenti[padre] or radice
		local motore = Instance.new("Motor6D")
		motore.Name = nome
		motore.Part0 = base
		motore.Part1 = seg
		motore.C0 = base.CFrame:ToObjectSpace(seg.CFrame)
		motore.Parent = seg
		segmenti[nome] = seg
		giunti[nome] = motore
	end
	local classifica = CLASSIFICA[tipoScheletro]
	local function p(dimensione, x, y, z, colore, forma, materiale, rotazione)
		local offset = CFrame.new(x * s, y * s, z * s)
		if rotazione then
			offset = offset * rotazione
		end
		local seg = segmenti[classifica(x, y, z)]
		local pezzo = parteSemplice(modello, dimensione * s, radice.CFrame * offset, colore, forma, materiale)
		local saldatura = Instance.new("WeldConstraint")
		saldatura.Part0 = seg
		saldatura.Part1 = pezzo
		saldatura.Parent = pezzo
		return pezzo
	end
	return p, giunti, segmenti
end

-- Corpo umano base: gambe, busto, braccia, testa. altezza sposta tutto in su (per i cavalieri).
local function corpo(p, divisa, pantaloni, altezza)
	local h = altezza or 0
	p(Vector3.new(0.5, 1.4, 0.55), -0.32, 0.7 + h, 0, pantaloni)
	p(Vector3.new(0.5, 1.4, 0.55), 0.32, 0.7 + h, 0, pantaloni)
	p(Vector3.new(1.4, 1.5, 0.75), 0, 2.15 + h, 0, divisa)
	p(Vector3.new(1.45, 0.22, 0.8), 0, 1.5 + h, 0, CUOIO)
	p(Vector3.new(0.42, 1.35, 0.5), -0.93, 2.2 + h, -0.1, divisa)
	p(Vector3.new(0.42, 1.35, 0.5), 0.93, 2.2 + h, -0.1, divisa)
	p(Vector3.new(1, 1, 1), 0, 3.45 + h, 0, PELLE, Enum.PartType.Ball)
end

local FIGURE = {}

-- Cavallo con gualdrappa del colore della squadra, e cavaliere seduto (busto e braccia) del colore "divisa".
local function cavallo(p, colore, divisa, manto)
	manto = manto or Color3.fromRGB(96, 62, 36)
	p(Vector3.new(1.3, 1.25, 3.0), 0, 2.0, 0, manto) -- cavallo
	p(Vector3.new(0.7, 1.3, 0.8), 0, 2.9, -1.5, manto, nil, nil, CFrame.Angles(math.rad(-30), 0, 0)) -- collo
	p(Vector3.new(0.65, 0.7, 1.2), 0, 3.4, -2.05, manto) -- testa
	p(Vector3.new(0.2, 0.5, 1.0), 0, 3.45, -1.3, SCURO) -- criniera
	p(Vector3.new(1.4, 0.9, 1.6), 0, 2.4, 0.2, colore, nil, Enum.Material.Fabric) -- gualdrappa
	for _, x in ipairs({ -0.45, 0.45 }) do
		for _, z in ipairs({ -1.1, 1.1 }) do
			p(Vector3.new(0.3, 1.4, 0.3), x, 0.7, z, manto:Lerp(SCURO, 0.4))
		end
	end
	p(Vector3.new(0.2, 0.9, 0.2), 0, 2.2, 1.6, SCURO, nil, nil, CFrame.Angles(math.rad(25), 0, 0)) -- coda
	-- cavaliere seduto
	p(Vector3.new(1.3, 1.3, 0.75), 0, 3.4, 0.2, divisa)
	p(Vector3.new(0.4, 1.2, 0.45), -0.85, 3.4, 0.1, divisa)
	p(Vector3.new(0.4, 1.2, 0.45), 0.85, 3.4, 0.1, divisa)
	p(Vector3.new(0.5, 0.9, 0.5), -0.45, 2.75, -0.1, divisa:Lerp(SCURO, 0.3), nil, nil, CFrame.Angles(math.rad(-60), 0, 0)) -- gambe
	p(Vector3.new(0.5, 0.9, 0.5), 0.45, 2.75, -0.1, divisa:Lerp(SCURO, 0.3), nil, nil, CFrame.Angles(math.rad(-60), 0, 0))
	p(Vector3.new(0.95, 0.95, 0.95), 0, 4.55, 0.2, PELLE, Enum.PartType.Ball)
end

-- Huscarl sassone: cotta di maglia, scudo tondo, ascia danese.
function FIGURE.Spadaccino(p, colore)
	corpo(p, colore, SCURO)
	p(Vector3.new(1.5, 0.9, 0.85), 0, 1.55, 0, METALLO:Lerp(SCURO, 0.3), nil, Enum.Material.DiamondPlate) -- cotta
	p(Vector3.new(1.1, 0.55, 1.1), 0, 3.85, 0, METALLO, nil, Enum.Material.Metal) -- elmo
	p(Vector3.new(0.18, 0.5, 0.12), 0, 3.55, -0.5, METALLO, nil, Enum.Material.Metal) -- nasale
	p(Vector3.new(0.16, 3.2, 0.16), 0.95, 2.4, -0.5, LEGNO, nil, Enum.Material.Wood) -- manico ascia
	p(Vector3.new(0.12, 0.8, 0.6), 0.95, 3.9, -0.75, METALLO, nil, Enum.Material.Metal) -- lama
	p(Vector3.new(0.25, 1.7, 1.7), -1.2, 2.1, -0.3, colore:Lerp(SCURO, 0.2), Enum.PartType.Cylinder, nil) -- scudo tondo
	p(Vector3.new(0.3, 0.5, 0.5), -1.25, 2.1, -0.3, METALLO, Enum.PartType.Ball, Enum.Material.Metal) -- umbone
end

-- Legionario romano: lorica, elmo con cresta, scutum rettangolare e gladio.
function FIGURE.Legionario(p, colore)
	corpo(p, ROSSO_ROMANO:Lerp(colore, 0.35), CUOIO)
	p(Vector3.new(1.5, 1.2, 0.85), 0, 2.3, 0, METALLO, nil, Enum.Material.Metal) -- lorica
	p(Vector3.new(1.1, 0.6, 1.15), 0, 3.85, 0, METALLO, nil, Enum.Material.Metal) -- elmo
	p(Vector3.new(0.2, 0.45, 1.1), 0, 4.3, 0, colore, nil, Enum.Material.Fabric) -- cresta
	p(Vector3.new(0.3, 2.4, 1.6), -1.15, 2.0, -0.35, colore:Lerp(ROSSO_ROMANO, 0.3)) -- scutum
	p(Vector3.new(0.32, 0.5, 0.5), -1.2, 2.0, -0.35, ORO, Enum.PartType.Ball, Enum.Material.Metal) -- umbone
	p(Vector3.new(0.16, 0.16, 1.4), 0.95, 1.9, -0.8, METALLO, nil, Enum.Material.Metal) -- gladio
end

-- Arciere cretese: tunica leggera, arco corto, faretra.
function FIGURE.ArciereCretese(p, colore)
	corpo(p, Color3.fromRGB(226, 214, 186):Lerp(colore, 0.4), CUOIO)
	p(Vector3.new(1.12, 0.35, 1.12), 0, 3.95, 0, colore:Lerp(SCURO, 0.3), nil, Enum.Material.Fabric) -- fascia
	p(Vector3.new(0.15, 2.3, 0.2), -1.15, 2.4, -0.5, LEGNO, nil, Enum.Material.Wood) -- arco
	p(Vector3.new(0.05, 2.1, 0.05), -1.0, 2.4, -0.5, Color3.fromRGB(230, 230, 220))
	p(Vector3.new(0.45, 1.3, 0.45), 0.45, 2.5, 0.6, CUOIO, nil, nil, CFrame.Angles(0, 0, math.rad(-20))) -- faretra
end

-- Cavaliere dei Compagni: elmo beotico, mantello, lancia.
function FIGURE.Compagno(p, colore)
	cavallo(p, colore, Color3.fromRGB(236, 226, 200):Lerp(colore, 0.3), Color3.fromRGB(60, 44, 34))
	p(Vector3.new(1.05, 0.75, 1.05), 0, 4.8, 0.2, BRONZO, nil, Enum.Material.Metal) -- elmo
	p(Vector3.new(1.4, 1.6, 0.2), 0, 3.3, 0.7, colore, nil, Enum.Material.Fabric) -- mantello
	p(Vector3.new(0.16, 0.16, 4.4), 0.85, 3.6, -1.3, LEGNO, nil, Enum.Material.Wood) -- lancia
	p(Vector3.new(0.28, 0.28, 0.5), 0.85, 3.6, -3.6, METALLO, nil, Enum.Material.Metal)
end

-- Arciere lungo inglese: cappuccio verde, arco alto quanto lui.
function FIGURE.Arciere(p, colore)
	corpo(p, colore:Lerp(Color3.fromRGB(70, 110, 60), 0.4), CUOIO)
	p(Vector3.new(1.15, 0.6, 1.15), 0, 3.8, 0.05, colore:Lerp(SCURO, 0.35), nil, Enum.Material.Fabric) -- cappuccio
	p(Vector3.new(0.15, 3.8, 0.2), -1.15, 2.2, -0.5, LEGNO, nil, Enum.Material.Wood) -- arco lungo
	p(Vector3.new(0.05, 2.6, 0.05), -1.0, 2.4, -0.5, Color3.fromRGB(230, 230, 220)) -- corda
	p(Vector3.new(0.45, 1.3, 0.45), 0.45, 2.5, 0.6, CUOIO, nil, nil, CFrame.Angles(0, 0, math.rad(-20))) -- faretra
end

function FIGURE.Cavaliere(p, colore)
	cavallo(p, colore, colore)
	p(Vector3.new(1.05, 0.8, 1.05), 0, 4.75, 0.2, METALLO, nil, Enum.Material.Metal) -- elmo
	p(Vector3.new(0.18, 0.5, 0.12), 0, 4.55, -0.38, METALLO, nil, Enum.Material.Metal) -- nasale normanno
	p(Vector3.new(0.25, 1.5, 1.1), -0.95, 3.3, 0.1, colore:Lerp(Color3.new(1, 1, 1), 0.3)) -- scudo a mandorla
	p(Vector3.new(0.18, 0.18, 4.2), 0.85, 3.6, -1.3, LEGNO, nil, Enum.Material.Wood) -- lancia
	p(Vector3.new(0.3, 0.3, 0.5), 0.85, 3.6, -3.5, METALLO, nil, Enum.Material.Metal) -- punta
end

-- Poilu francese: divisa blu orizzonte ed elmetto Adrian con la cresta.
function FIGURE.Fante(p, colore)
	local divisa = BLU_ORIZZONTE:Lerp(colore, 0.3)
	corpo(p, divisa, BLU_ORIZZONTE:Lerp(SCURO, 0.3))
	p(Vector3.new(1.25, 0.45, 1.25), 0, 3.9, 0, BLU_ORIZZONTE:Lerp(SCURO, 0.25), nil, Enum.Material.Metal) -- elmetto Adrian
	p(Vector3.new(0.16, 0.25, 1.0), 0, 4.2, 0, BLU_ORIZZONTE:Lerp(SCURO, 0.25), nil, Enum.Material.Metal) -- cresta
	p(Vector3.new(0.16, 0.2, 2.5), 0.85, 2.3, -0.9, SCURO, nil, Enum.Material.Metal) -- fucile
	p(Vector3.new(0.2, 0.35, 0.9), 0.85, 2.2, 0.15, LEGNO, nil, Enum.Material.Wood) -- calcio
	p(Vector3.new(1.0, 1.1, 0.45), 0, 2.3, 0.6, KAKI, nil, Enum.Material.Fabric) -- zaino
	p(Vector3.new(1.5, 0.25, 0.25), 0, 1.6, -0.45, colore) -- fascia squadra
end

function FIGURE.Mitragliere(p, colore)
	local divisa = OLIVA:Lerp(colore, 0.3)
	-- soldato in ginocchio dietro la mitragliatrice
	p(Vector3.new(1.2, 0.7, 1.4), 0, 0.35, 0.3, OLIVA:Lerp(SCURO, 0.3))
	p(Vector3.new(1.4, 1.5, 0.75), 0, 1.45, 0.3, divisa)
	p(Vector3.new(1.45, 0.25, 0.25), 0, 1.0, -0.1, colore)
	p(Vector3.new(0.42, 1.2, 0.5), -0.9, 1.4, -0.2, divisa, nil, nil, CFrame.Angles(math.rad(50), 0, 0))
	p(Vector3.new(0.42, 1.2, 0.5), 0.9, 1.4, -0.2, divisa, nil, nil, CFrame.Angles(math.rad(50), 0, 0))
	p(Vector3.new(1, 1, 1), 0, 2.7, 0.3, PELLE, Enum.PartType.Ball)
	p(Vector3.new(1.25, 0.45, 1.25), 0, 3.15, 0.3, OLIVA:Lerp(SCURO, 0.2), nil, Enum.Material.Metal)
	p(Vector3.new(0.5, 0.5, 1.6), 0, 1.2, -1.4, SCURO, nil, Enum.Material.Metal) -- corpo arma
	p(Vector3.new(0.22, 0.22, 1.4), 0, 1.25, -2.8, SCURO, nil, Enum.Material.Metal) -- canna
	p(Vector3.new(0.15, 1.1, 0.15), 0.4, 0.55, -1.6, SCURO, nil, nil, CFrame.Angles(0, 0, math.rad(20)))
	p(Vector3.new(0.15, 1.1, 0.15), -0.4, 0.55, -1.6, SCURO, nil, nil, CFrame.Angles(0, 0, math.rad(-20)))
	p(Vector3.new(2.8, 0.7, 0.8), 0, 0.35, -2.4, Color3.fromRGB(176, 158, 110), nil, Enum.Material.Fabric) -- sacchi
end

function FIGURE.CarroArmato(p, colore)
	local scafo = OLIVA:Lerp(colore, 0.25)
	p(Vector3.new(3.6, 1.3, 5.2), 0, 1.15, 0, scafo, nil, Enum.Material.Metal)
	p(Vector3.new(3.2, 0.8, 1.2), 0, 1.4, -2.7, scafo, nil, Enum.Material.Metal, CFrame.Angles(math.rad(-30), 0, 0))
	for _, x in ipairs({ -2.05, 2.05 }) do
		p(Vector3.new(0.9, 1.3, 5.6), x, 0.65, 0, SCURO, nil, Enum.Material.Metal)
		for i = -2, 2 do
			p(Vector3.new(0.95, 0.9, 0.9), x, 0.5, i * 1.1, Color3.fromRGB(70, 70, 70), Enum.PartType.Cylinder, Enum.Material.Metal)
		end
	end
	p(Vector3.new(2.4, 1.0, 2.6), 0, 2.3, 0.4, scafo, nil, Enum.Material.Metal) -- torretta
	p(Vector3.new(0.9, 0.35, 0.9), 0.5, 2.95, 0.8, scafo:Lerp(SCURO, 0.2), Enum.PartType.Cylinder, Enum.Material.Metal, CFrame.Angles(0, 0, math.rad(90)))
	p(Vector3.new(0.38, 0.38, 3.4), 0, 2.3, -2.4, SCURO, nil, Enum.Material.Metal) -- cannone
	p(Vector3.new(0.55, 0.55, 0.6), 0, 2.3, -4.1, SCURO, nil, Enum.Material.Metal)
	p(Vector3.new(1.6, 0.6, 0.1), 0, 1.4, 2.65, colore) -- insegna squadra
	p(Vector3.new(0.08, 0.7, 1.0), 1.0, 3.3, 1.2, colore) -- bandierina
end

-- Comandanti: figura più grande, mantello, copricapo dell'epoca e anello d'oro a terra.
local function anello(p)
	local parte = p(Vector3.new(0.12, 5.2, 5.2), 0, 0.06, 0, ORO, Enum.PartType.Cylinder, Enum.Material.Neon, CFrame.Angles(0, 0, math.rad(90)))
	parte.Name = "Anello" -- tolto nei ritratti delle carte
end

local function stendardo(p, colore, x)
	p(Vector3.new(0.14, 6, 0.14), x, 3, 0.9, LEGNO, nil, Enum.Material.Wood)
	p(Vector3.new(0.08, 1.6, 1.4), x, 5.2, 1.6, colore, nil, Enum.Material.Fabric)
	p(Vector3.new(0.3, 0.3, 0.3), x, 6.1, 0.9, ORO, Enum.PartType.Ball, Enum.Material.Metal)
end

function FIGURE.Annibale(p, colore)
	anello(p)
	cavallo(p, colore, Color3.fromRGB(110, 40, 90), Color3.fromRGB(40, 34, 30))
	p(Vector3.new(1.05, 0.75, 1.05), 0, 4.8, 0.2, BRONZO, nil, Enum.Material.Metal) -- elmo
	p(Vector3.new(0.2, 0.6, 1.2), 0, 5.3, 0.2, Color3.fromRGB(240, 240, 230), nil, Enum.Material.Fabric) -- pennacchio
	p(Vector3.new(1.5, 1.8, 0.2), 0, 3.4, 0.7, Color3.fromRGB(110, 40, 90), nil, Enum.Material.Fabric) -- mantello porpora
	stendardo(p, colore, -1.3)
end

function FIGURE.Cesare(p, colore)
	anello(p)
	corpo(p, ROSSO_ROMANO, CUOIO)
	p(Vector3.new(1.55, 1.25, 0.9), 0, 2.3, 0, ORO, nil, Enum.Material.Metal) -- lorica d'oro
	p(Vector3.new(1.6, 2.6, 0.2), 0, 2.1, 0.55, ROSSO_ROMANO, nil, Enum.Material.Fabric) -- mantello
	p(Vector3.new(1.15, 0.2, 1.15), 0, 3.95, 0, Color3.fromRGB(90, 150, 60), Enum.PartType.Cylinder, nil, CFrame.Angles(0, 0, math.rad(90))) -- alloro
	p(Vector3.new(0.16, 0.16, 1.4), 0.95, 1.9, -0.8, METALLO, nil, Enum.Material.Metal) -- gladio
	stendardo(p, colore, -1.3)
end

function FIGURE.Guglielmo(p, colore)
	anello(p)
	cavallo(p, colore, Color3.fromRGB(150, 30, 30), Color3.fromRGB(230, 226, 214))
	p(Vector3.new(1.05, 0.8, 1.05), 0, 4.75, 0.2, METALLO, nil, Enum.Material.Metal) -- elmo
	p(Vector3.new(0.18, 0.5, 0.12), 0, 4.55, -0.38, METALLO, nil, Enum.Material.Metal)
	p(Vector3.new(1.0, 0.25, 1.0), 0, 5.25, 0.2, ORO, nil, Enum.Material.Metal) -- corona
	p(Vector3.new(1.5, 1.8, 0.2), 0, 3.4, 0.7, Color3.fromRGB(150, 30, 30), nil, Enum.Material.Fabric)
	stendardo(p, colore, -1.3)
end

function FIGURE.Giovanna(p, colore)
	anello(p)
	corpo(p, METALLO, METALLO)
	p(Vector3.new(1.5, 1.6, 0.85), 0, 2.2, 0, METALLO:Lerp(Color3.new(1, 1, 1), 0.3), nil, Enum.Material.Metal) -- armatura
	p(Vector3.new(1.4, 1.2, 0.2), 0, 1.6, -0.45, Color3.fromRGB(40, 60, 150), nil, Enum.Material.Fabric) -- sopravveste
	p(Vector3.new(1.05, 0.45, 1.05), 0, 3.95, 0.1, Color3.fromRGB(120, 72, 36)) -- capelli
	p(Vector3.new(0.16, 0.16, 2.0), 0.95, 1.9, -0.9, METALLO, nil, Enum.Material.Metal) -- spada
	stendardo(p, Color3.fromRGB(240, 236, 220), -1.3)
end

function FIGURE.Foch(p, colore)
	anello(p)
	local divisa = Color3.fromRGB(70, 74, 92)
	corpo(p, divisa, Color3.fromRGB(150, 40, 40))
	p(Vector3.new(0.95, 0.65, 0.95), 0, 4.15, 0, Color3.fromRGB(150, 40, 40), Enum.PartType.Cylinder, nil, CFrame.Angles(0, 0, math.rad(90))) -- képi
	p(Vector3.new(0.9, 0.12, 0.5), 0, 3.85, -0.45, SCURO) -- visiera
	p(Vector3.new(0.9, 0.1, 0.1), 0, 2.6, -0.4, ORO, nil, Enum.Material.Metal) -- decorazioni
	p(Vector3.new(1.0, 1.0, 0.12), 0.85, 2.1, -0.2, Color3.fromRGB(230, 230, 210)) -- mappa
	stendardo(p, colore, -1.3)
end

function FIGURE.DeGaulle(p, colore)
	anello(p)
	local divisa = Color3.fromRGB(120, 112, 80)
	corpo(p, divisa, divisa:Lerp(SCURO, 0.3))
	p(Vector3.new(0.9, 0.9, 0.9), 0, 4.25, 0, Color3.fromRGB(40, 50, 80), Enum.PartType.Cylinder, nil, CFrame.Angles(0, 0, math.rad(90))) -- képi alto
	p(Vector3.new(0.92, 0.15, 0.92), 0, 4.45, 0, ORO, Enum.PartType.Cylinder, Enum.Material.Metal, CFrame.Angles(0, 0, math.rad(90)))
	p(Vector3.new(0.9, 0.12, 0.5), 0, 3.85, -0.45, SCURO)
	p(Vector3.new(0.4, 0.4, 0.1), -0.35, 2.6, -0.4, Color3.fromRGB(200, 40, 40)) -- croce di Lorena
	stendardo(p, colore, -1.3)
end

-- Fortezze: occupano una casella intera (10 studs); il fronte è verso -Z.
local function muro(p, x, z, lx, lz, altezza, colore, materiale)
	p(Vector3.new(lx, altezza, lz), x, altezza / 2, z, colore, nil, materiale)
end

local function torre(p, x, z, altezza, colore, materiale, tetto)
	p(Vector3.new(2.2, altezza, 2.2), x, altezza / 2, z, colore, nil, materiale)
	for _, dx in ipairs({ -0.8, 0.8 }) do
		for _, dz in ipairs({ -0.8, 0.8 }) do
			p(Vector3.new(0.6, 0.6, 0.6), x + dx, altezza + 0.3, z + dz, colore, nil, materiale)
		end
	end
	if tetto then
		p(Vector3.new(2.4, 0.4, 2.4), x, altezza + 0.9, z, tetto, nil, Enum.Material.WoodPlanks)
	end
end

function FIGURE.FortezzaAntica(p, colore)
	local legno = Color3.fromRGB(122, 86, 52)
	for i = -4, 4 do
		p(Vector3.new(0.9, 3.4, 0.9), i * 0.95, 1.7, -3.6, legno, Enum.PartType.Block, Enum.Material.Wood) -- palizzata
		p(Vector3.new(0.9, 3.4, 0.9), i * 0.95, 1.7, 3.6, legno, Enum.PartType.Block, Enum.Material.Wood)
	end
	for i = -3, 3 do
		p(Vector3.new(0.9, 3.4, 0.9), -3.8, 1.7, i * 0.95, legno, nil, Enum.Material.Wood)
		p(Vector3.new(0.9, 3.4, 0.9), 3.8, 1.7, i * 0.95, legno, nil, Enum.Material.Wood)
	end
	torre(p, -3.6, -3.6, 5, legno, Enum.Material.WoodPlanks, legno:Lerp(SCURO, 0.3))
	torre(p, 3.6, -3.6, 5, legno, Enum.Material.WoodPlanks, legno:Lerp(SCURO, 0.3))
	p(Vector3.new(4, 2.5, 3), 0, 1.25, 0.5, Color3.fromRGB(200, 180, 140), nil, Enum.Material.Fabric) -- tenda
	p(Vector3.new(0.14, 7, 0.14), 0, 3.5, 0.5, LEGNO)
	p(Vector3.new(0.08, 1.4, 2), 0, 6.2, 1.5, colore, nil, Enum.Material.Fabric)
end

function FIGURE.FortezzaMedievale(p, colore)
	muro(p, 0, -3.6, 7.2, 1.2, 4, PIETRA, Enum.Material.Cobblestone)
	muro(p, 0, 3.6, 7.2, 1.2, 4, PIETRA, Enum.Material.Cobblestone)
	muro(p, -3.6, 0, 1.2, 7.2, 4, PIETRA, Enum.Material.Cobblestone)
	muro(p, 3.6, 0, 1.2, 7.2, 4, PIETRA, Enum.Material.Cobblestone)
	for i = -3, 3, 2 do
		p(Vector3.new(0.8, 0.7, 1.2), i, 4.35, -3.6, PIETRA, nil, Enum.Material.Cobblestone) -- merli
	end
	p(Vector3.new(1.8, 2.6, 0.3), 0, 1.3, -4.25, LEGNO:Lerp(SCURO, 0.3), nil, Enum.Material.Wood) -- portone
	for _, x in ipairs({ -3.6, 3.6 }) do
		for _, z in ipairs({ -3.6, 3.6 }) do
			torre(p, x, z, 6, PIETRA:Lerp(SCURO, 0.1), Enum.Material.Cobblestone)
		end
	end
	torre(p, 0, 0.8, 8, PIETRA:Lerp(SCURO, 0.15), Enum.Material.Cobblestone) -- mastio
	p(Vector3.new(0.14, 3, 0.14), 0, 9.6, 0.8, LEGNO)
	p(Vector3.new(0.08, 1.2, 1.8), 0, 10.4, 1.7, colore, nil, Enum.Material.Fabric)
end

function FIGURE.FortezzaNovecento(p, colore)
	p(Vector3.new(7, 2.6, 6), 0, 1.3, 0.4, CEMENTO, nil, Enum.Material.Concrete) -- bunker
	p(Vector3.new(7.6, 0.6, 6.6), 0, 2.9, 0.4, CEMENTO:Lerp(SCURO, 0.15), nil, Enum.Material.Concrete)
	p(Vector3.new(4.5, 0.5, 0.3), 0, 1.7, -2.65, SCURO) -- feritoia
	p(Vector3.new(0.22, 0.22, 1.6), 1.2, 1.7, -3.3, SCURO, nil, Enum.Material.Metal) -- mitragliatrice
	p(Vector3.new(0.22, 0.22, 1.6), -1.2, 1.7, -3.3, SCURO, nil, Enum.Material.Metal)
	for i = -4, 4 do
		p(Vector3.new(0.9, 0.8, 1.1), i * 0.9, 0.4, -4.2, Color3.fromRGB(176, 158, 110), nil, Enum.Material.Fabric) -- sacchetti
	end
	for _, x in ipairs({ -3.4, 3.4 }) do
		p(Vector3.new(0.15, 1.2, 1.2), x, 0.6, -3.9, SCURO, nil, Enum.Material.Metal, CFrame.Angles(math.rad(45), 0, 0)) -- cavalli di frisia
	end
	p(Vector3.new(0.14, 4, 0.14), 2.8, 5, 2.4, SCURO)
	p(Vector3.new(0.08, 1.2, 1.8), 2.8, 6.4, 3.3, colore, nil, Enum.Material.Fabric)
end

-- Come è fatto ogni tipo. scheletro = articolazioni delle figure a parti; scala = studs per unità della
-- figura a parti; metri = studs per metro dei modelli Blender. Le truppe sono un po' più basse del
-- giocatore (circa 4 studs contro 5), i comandanti più grandi delle truppe.
local TIPI = {
	Legionario = { scheletro = "fante", scala = 1.0, metri = 2.34 },
	ArciereCretese = { scheletro = "fante", scala = 1.0, metri = 2.34 },
	Compagno = { scheletro = "cavallo", scala = 1.0, metri = 2.34 },
	Spadaccino = { scheletro = "fante", scala = 1.0, metri = 2.34 },
	Arciere = { scheletro = "fante", scala = 1.0, metri = 2.34 },
	Cavaliere = { scheletro = "cavallo", scala = 1.0, metri = 2.34 },
	Fante = { scheletro = "fante", scala = 1.0, metri = 2.34 },
	Mitragliere = { scheletro = "rigido", scala = 1.0, metri = 2.34 },
	-- Lo Sherman vero è lungo 5,9 m: in scala piena sarebbe 14 studs; un po' compresso resta leggibile sul campo.
	CarroArmato = { scheletro = "carro", scala = 1.7, metri = 1.6 },
	Annibale = { scheletro = "cavallo", scala = 1.2, metri = 2.8 },
	Cesare = { scheletro = "fante", scala = 1.2, metri = 2.8 },
	Guglielmo = { scheletro = "cavallo", scala = 1.2, metri = 2.8 },
	Giovanna = { scheletro = "fante", scala = 1.2, metri = 2.8 },
	Foch = { scheletro = "fante", scala = 1.2, metri = 2.8 },
	DeGaulle = { scheletro = "fante", scala = 1.2, metri = 2.8 },
	FortezzaAntica = { scheletro = "rigido", scala = 2.3, metri = 2.34 },
	FortezzaMedievale = { scheletro = "rigido", scala = 2.3, metri = 2.34 },
	FortezzaNovecento = { scheletro = "rigido", scala = 2.3, metri = 2.34 },
}

-- Cerchio a terra del colore della squadra (oro per i comandanti), per riconoscere i soldati da lontano.
local function cerchio(modello, radice, diametro, colore, comandante)
	local disco = Instance.new("Part")
	disco.Name = "Cerchio"
	disco.Shape = Enum.PartType.Cylinder
	-- Sottile e appena sopra il terreno: non deve coprire i piedi.
	disco.Size = Vector3.new(0.04, diametro, diametro)
	disco.CFrame = radice.CFrame * CFrame.new(0, 0.025, 0) * CFrame.Angles(0, 0, math.rad(90))
	disco.Color = comandante and Color3.fromRGB(255, 200, 70) or colore
	disco.Material = Enum.Material.Neon
	disco.Transparency = 0.55
	disco.CanCollide = false
	disco.CanQuery = false
	disco.CanTouch = false
	disco.CastShadow = false
	disco.Massless = true
	disco.Anchored = false
	local saldatura = Instance.new("WeldConstraint")
	saldatura.Part0 = radice
	saldatura.Part1 = disco
	saldatura.Parent = disco
	disco.Parent = modello
	return disco
end

-- Un soldato pronto da animare, con i piedi in "cframe" (default: origine).
-- opzioni: { cerchio = diametro in studs (nil = niente cerchio), comandante = bool }
-- Restituisce il modello e una tabella { giunti = { nome -> Bone | Motor6D }, mesh = bool, radice }.
function Modelli.crea(tipo, squadra, cframe, opzioni)
	opzioni = opzioni or {}
	cframe = cframe or CFrame.new()
	local info = TIPI[tipo] or TIPI.Spadaccino
	local modello = Instance.new("Model")
	modello.Name = tipo
	local radice = nuovaRadice(modello, cframe)
	local colore = Modelli.COLORI_SQUADRA[squadra or "giocatore"]
	local giunti, conMesh = {}, false
	if Mesh.disponibile(tipo) then
		local parte, centro, basso = Mesh.copia(tipo, info.metri)
		if parte then
			-- L'origine dei modelli Blender è sotto i piedi del soldato; nei cavalieri il cavaliere è stato
			-- costruito in piedi e poi messo in sella, così gli zoccoli scendono sotto l'origine: si alza tutto
			-- finché gli zoccoli toccano terra.
			local fondo = centro.Y + basso
			local alza = fondo < -0.5 and -fondo or 0
			parte.CFrame = cframe * CFrame.new(centro + Vector3.new(0, alza, 0))
			modello:SetAttribute("MeshBasso", basso)
			modello:SetAttribute("MeshMetri", info.metri)
			local saldatura = Instance.new("WeldConstraint")
			saldatura.Part0 = radice
			saldatura.Part1 = parte
			saldatura.Parent = parte
			parte.Parent = modello
			for _, osso in ipairs(parte:GetDescendants()) do
				if osso:IsA("Bone") then
					giunti[osso.Name] = osso
				end
			end
			conMesh = true
		end
	end
	if not conMesh then
		local p, g = rig(modello, radice, info.scheletro, info.scala)
		giunti = g
		local costruttore = FIGURE[tipo] or FIGURE.Spadaccino
		costruttore(p, colore)
		local anello = modello:FindFirstChild("Anello")
		if anello then
			anello:Destroy()
		end
	end
	if opzioni.cerchio then
		cerchio(modello, radice, opzioni.cerchio, colore, opzioni.comandante)
	end
	modello:SetAttribute("Squadra", squadra)
	return modello, { giunti = giunti, mesh = conMesh, radice = radice }
end

-- Un solo soldato fermo, per i ritratti delle carte e le icone.
function Modelli.soldato(tipo, squadra)
	return (Modelli.crea(tipo, squadra))
end

return Modelli
