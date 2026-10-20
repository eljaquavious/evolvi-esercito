-- Animazioni dei soldati, calcolate a ogni fotogramma: passo di marcia, respiro da fermi, colpi
-- (spada, ascia, lancia, arco, pilum, fucile, mitragliatrice, cannone), colpi subiti e caduta.
-- Muove le articolazioni del modello (Bone o Motor6D, vedi Shared/Modelli) con .Transform:
-- a riposo sono allineate al soldato, quindi Angles(a, 0, 0) con a > 0 alza in avanti braccia e gambe,
-- Angles(0, b, 0) con b > 0 gira il busto portando avanti la spalla destra.

local Animatore = {}
Animatore.__index = Animatore

local PI = math.pi

-- Stile di combattimento per tipo.
Animatore.STILI = {
	Legionario = "legionario",
	ArciereCretese = "arco",
	Arciere = "arco",
	Compagno = "cavalleria",
	Cavaliere = "cavalleria",
	Annibale = "cavalleria",
	Guglielmo = "cavalleria",
	Spadaccino = "ascia",
	Cesare = "spada",
	Giovanna = "spada",
	Fante = "fucile",
	Foch = "pistola",
	DeGaulle = "pistola",
	Mitragliere = "mitragliatrice",
	CarroArmato = "carro",
	FortezzaAntica = "fortezza",
	FortezzaMedievale = "fortezza",
	FortezzaNovecento = "fortezza",
	FortezzaModerna = "fortezza",
	-- Armate nemiche e comandanti nuovi.
	Oplita = "spada",
	Immortale = "spada",
	ArcierePersiano = "arco",
	CavalleriaPersiana = "cavalleria",
	LanciereLibico = "spada",
	FrombolieroBaleare = "spada", -- il gesto di chi fa girare la fionda
	CavalleriaNumidica = "cavalleria",
	Elefante = "cavalleria",
	GuerrieroGallico = "spada",
	ArciereGallico = "arco",
	CavalleriaGallica = "cavalleria",
	CavalleriaGermanica = "cavalleria",
	FanteUmayyade = "spada",
	ArciereArabo = "arco",
	CavalleriaAraba = "cavalleria",
	FanteNormanno = "spada",
	ArciereNormanno = "arco",
	CavaliereNormanno = "cavalleria",
	FanteAyyubide = "spada",
	ArciereAyyubide = "arco",
	Mamelucco = "cavalleria",
	Saladino = "cavalleria",
	SergenteTeutonico = "spada",
	BalestriereTeutonico = "fucile",
	CavaliereTeutonico = "cavalleria",
	UomoDArme = "ascia",
	BalestriereGenovese = "fucile",
	PicchiereSvedese = "spada",
	MoschettiereSvedese = "fucile",
	CorazziereSvedese = "cavalleria",
	GustavoAdolfo = "cavalleria",
	Giannizzero = "fucile",
	CannoneOttomano = "carro",
	Sipahi = "cavalleria",
	FanteriaDiLinea = "fucile",
	Artiglieria = "carro",
	Corazziere = "cavalleria",
	Napoleone = "spada",
	FanteOttomano = "fucile",
	MitraglieriOttomani = "mitragliatrice",
	Stosstruppen = "fucile",
	MitraglieriTedeschi = "mitragliatrice",
	FanteBritannico = "fucile",
	CarroMarkV = "carro",
	FucilieriSovietici = "fucile",
	MitraglieriSovietici = "mitragliatrice",
	T34 = "carro",
	Granatieri = "fucile",
	MG42 = "mitragliatrice",
	Panzer = "carro",
	FanteFranciaLibera = "fucile",
	Rommel = "pistola",
	MarineUSA = "fucile",
	MitraglieriM60 = "mitragliatrice",
	M48Patton = "carro",
	FanteNVA = "fucile",
	MitraglieriNVA = "mitragliatrice",
	PT76 = "carro",
	FantePVA = "fucile",
	MitraglieriPVA = "mitragliatrice",
	Giap = "pistola",
	PengDehuai = "pistola",
}

-- Lunghezza di un passo completo (due appoggi) in studs.
local PASSI = { cavalleria = 7, carro = 6 }
local RIPRESA = 0.35 -- secondi per tornare in guardia dopo un colpo

local function liscio(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function ruota(x, y, z)
	return CFrame.Angles(x or 0, y or 0, z or 0)
end

function Animatore.nuovo(modello, info, tipo)
	local self = setmetatable({}, Animatore)
	self.modello = modello
	self.giunti = info.giunti
	self.mesh = info.mesh
	self.tipo = tipo
	self.stile = Animatore.STILI[tipo] or "spada"
	self.fase = math.random() * 2
	self.tempo = math.random() * 10
	self.marcia = 0 -- 0 = fermo, 1 = cammina a pieno ritmo
	self.attacco = nil -- { colpo, inizio, gesto }
	self.ferita = -10
	self.morte = nil
	self.lanciaVia = false
	self.gladioInMano = false
	self.riposo = Animatore._posizioniRiposo(self.giunti)
	-- Cavallo del modello Blender (zampe in tre pezzi), diverso da quello a blocchi (zampe intere).
	self.cavalloMesh = self.giunti["zampa.AR1"] ~= nil
	return self
end

-- Dove stanno le articolazioni a riposo (nello spazio del modello, studs): servono per mettere una mano
-- in un punto preciso (la corda dell'arco al mento, l'affondo della lancia). Solo per i modelli Blender.
function Animatore._posizioniRiposo(giunti)
	local posizioni = {}
	local function posizione(osso)
		if posizioni[osso] then
			return posizioni[osso]
		end
		local padre = osso.Parent
		local base = (padre and padre:IsA("Bone")) and posizione(padre) or Vector3.zero
		posizioni[osso] = base + osso.CFrame.Position
		return posizioni[osso]
	end
	local risultato = {}
	for nome, osso in pairs(giunti) do
		if osso:IsA("Bone") then
			risultato[nome] = posizione(osso)
		end
	end
	return next(risultato) and risultato or nil
end

-- Rotazione minima che porta la direzione "da" sulla direzione "a".
local function minima(da, a)
	local d1, d2 = da.Unit, a.Unit
	local asse = d1:Cross(d2)
	local s = asse.Magnitude
	if s < 1e-6 then
		return CFrame.identity
	end
	return CFrame.fromAxisAngle(asse / s, math.atan2(s, d1:Dot(d2)))
end

-- IK a due ossa: rotazioni di braccio e avambraccio del lato ("L" o "R") che portano il polso sul punto
-- "bersaglio" (spazio del busto a riposo), con il gomito verso "polo". Restituisce le due rotazioni.
function Animatore:_braccio(lato, bersaglio, polo)
	local R = self.riposo
	local spalla, gomito0, polso0 = R["braccio." .. lato], R["avambraccio." .. lato], R["mano." .. lato]
	local l1, l2 = (gomito0 - spalla).Magnitude, (polso0 - gomito0).Magnitude
	local d = bersaglio - spalla
	local distanza = math.clamp(d.Magnitude, math.abs(l1 - l2) + 1e-3, (l1 + l2) * 0.999)
	local u = d.Unit
	local a = (l1 * l1 - l2 * l2 + distanza * distanza) / (2 * distanza)
	local h = math.sqrt(math.max(0, l1 * l1 - a * a))
	local piano = polo - u * polo:Dot(u)
	piano = piano.Magnitude > 1e-4 and piano.Unit or Vector3.yAxis
	local gomito = spalla + u * a + piano * h
	local polso = spalla + u * distanza
	local r1 = minima(gomito0 - spalla, gomito - spalla)
	local r2 = minima(polso0 - gomito0, r1:VectorToObjectSpace(polso - gomito))
	return r1, r2
end

-- Porta la mano del lato sul bersaglio (spazio del modello), tenendo conto del busto già girato (p.torace),
-- dosata con peso (0-1). Con "tieni" la mano non cambia orientamento (l'arco resta dritto, la lancia in linea).
function Animatore:_mano(p, lato, bersaglio, polo, peso, tieni)
	local busto = p.torace or CFrame.identity
	local perno = self.riposo.torace
	local locale = perno + busto:VectorToObjectSpace(bersaglio - perno)
	local r1, r2 = self:_braccio(lato, locale, busto:VectorToObjectSpace(polo))
	r1 = CFrame.identity:Lerp(r1, peso)
	r2 = CFrame.identity:Lerp(r2, peso)
	p["braccio." .. lato] = r1
	p["avambraccio." .. lato] = r2
	if tieni then
		-- Rispetto alle rotazioni davvero applicate (già dosate): a metà gesto la mano non si inclina.
		p["mano." .. lato] = (busto.Rotation * r1 * r2):Inverse() * tieni
	end
end

-- Il colpo parte ora: "gesto" è il tempo (secondi reali) prima che la freccia o la lama partano.
function Animatore:attacca(colpo, gesto)
	self.attacco = { colpo = colpo, inizio = self.tempo, gesto = math.max(0.08, gesto) }
	if colpo == "mischia" and self.stile == "legionario" then
		self:_impugnaGladio()
	end
end

function Animatore:ferito()
	self.ferita = self.tempo
end

function Animatore:muori()
	self.morte = self.tempo
end

-- Il pilum è partito: sparisce dalla mano.
function Animatore:lasciaLancia()
	self.lanciaVia = true
end

-- Dopo il lancio il legionario sguaina il gladio che porta al fianco.
function Animatore:_impugnaGladio()
	if self.gladioInMano then
		return
	end
	self.gladioInMano = true
	local gladio, mano = self.giunti.gladio, self.giunti["mano.R"]
	if gladio and mano and gladio:IsA("Bone") then
		gladio.Parent = mano
		gladio.CFrame = CFrame.new(0, -0.2, -0.05) * ruota(PI / 2, 0, 0)
		self.lanciaVia = true
	end
end

-- Dove parte un proiettile (mano destra, o la sinistra per gli arcieri che tengono l'arco).
function Animatore:puntoTiro()
	-- Armi da fuoco del modello Blender: la bocca della canna ha un osso suo.
	local canna = self.giunti.canna
	if canna and canna:IsA("Bone") then
		return canna.WorldPosition
	end
	local nome = self.stile == "arco" and "mano.L" or "mano.R"
	local giunto = self.giunti[nome] or self.giunti["braccio.R"]
	if giunto and giunto:IsA("Bone") then
		return giunto.WorldPosition
	elseif giunto then
		return (giunto.Part1 and giunto.Part1.Position or self.modello:GetPivot().Position) + Vector3.new(0, -0.6, 0)
	end
	return self.modello:GetPivot().Position + Vector3.new(0, 3, 0)
end

-- Avanzamento del colpo: k = carica (0-1, fino al rilascio), r = rilascio (0-1 subito dopo), fine = colpo finito.
local function tempiColpo(attacco, tempo)
	local t = tempo - attacco.inizio
	local k = liscio(t / attacco.gesto)
	local dopo = t - attacco.gesto
	local r = dopo <= 0 and 0 or math.clamp(dopo / 0.12, 0, 1)
	local ritorno = dopo <= 0.12 and 1 or 1 - liscio((dopo - 0.12) / RIPRESA)
	return k, r, ritorno, dopo > 0.12 + RIPRESA
end

local POSE = {}

-- Legionario: pilum lanciato dall'alto, poi affondi col gladio dietro lo scudo.
function POSE.legionario(p, a, k, r, ritorno)
	if a.colpo == "lancio" then
		local alza = k * (1 - r) + r * 0.2
		local dietro = k * (1 - r)
		p["braccio.R"] = ruota(2.5 * alza - 0.9 * r * ritorno, 0, -0.2 * alza)
		p["avambraccio.R"] = ruota(0.4 * dietro, 0, 0)
		p.lancia = ruota(-(2.5 + 1.1) * dietro, 0, 0)
		p.torace = ruota(-0.15 * dietro, -0.55 * dietro + 0.35 * r * ritorno, 0)
		p["braccio.L"] = ruota(0.5 * dietro, 0, 0)
	else
		local indietro = k * (1 - r)
		local avanti = r * ritorno
		p["braccio.R"] = ruota(-0.35 * indietro + 1.25 * avanti, 0, 0)
		p["avambraccio.R"] = ruota(0.9 * indietro - 0.2 * avanti, 0, 0)
		p.torace = ruota(0.12 * avanti, -0.35 * indietro + 0.35 * avanti, 0)
		p["braccio.L"] = ruota(0.35 * (indietro + avanti), 0, 0)
		p.bacino = CFrame.new(0, 0, -0.25 * avanti)
	end
end

-- Fendente con la spada: alza il braccio, cala la lama.
function POSE.spada(p, a, k, r, ritorno, self)
	if self and self.riposo and self.riposo["mano.R"] then
		return POSE.spadaMesh(p, a, k, r, ritorno, self)
	end
	local su = k * (1 - r)
	local giu = r * ritorno
	p["braccio.R"] = ruota(2.6 * su + 0.8 * giu, 0, -0.3 * su)
	p["avambraccio.R"] = ruota(0.6 * su, 0, 0)
	p.torace = ruota(0.15 * giu, -0.4 * su + 0.4 * giu, 0)
	p["braccio.L"] = ruota(0.3 * su, 0, 0)
end

-- Modello Blender (la spada è già alzata in avanti a riposo): la mano sale sopra la spalla destra
-- e cala in avanti e in basso, il busto ruota col colpo e il passo avanza.
function POSE.spadaMesh(p, _a, k, r, ritorno, self)
	local su = k * (1 - r)
	local giu = r * ritorno
	p.torace = ruota(0.15 * giu, -0.35 * su + 0.4 * giu, 0)
	local presa = self.riposo["mano.R"] + Vector3.new(0.25 * su, 1.3 * su - 0.7 * giu, 0.9 * su - 0.8 * giu)
	self:_mano(p, "R", presa, Vector3.new(1, -0.3, 0.6), math.max(su, giu), CFrame.identity)
	p["braccio.L"] = ruota(0.3 * su, 0, 0)
	p.bacino = CFrame.new(0, 0, -0.2 * giu)
end

-- Ascia danese a due mani: carica sopra la spalla e colpo dall'alto.
function POSE.ascia(p, _a, k, r, ritorno)
	local su = k * (1 - r)
	local giu = r * ritorno
	p["braccio.R"] = ruota(2.8 * su + 0.9 * giu, 0, 0)
	p["braccio.L"] = ruota(2.2 * su + 0.9 * giu, 0, 0)
	p.torace = ruota(-0.2 * su + 0.3 * giu, -0.3 * su + 0.3 * giu, 0)
end

-- Arciere: si gira di fianco, alza l'arco dritto davanti a sé col braccio teso e porta la corda al mento;
-- scocca (la mano destra scatta indietro) e torna giù.
function POSE.arco(p, a, k, r, ritorno, self)
	if self.riposo and self.riposo["mano.L"] then
		return POSE.arcoMesh(p, a, k, r, ritorno, self)
	end
	local tende = k * (1 - r * 0.2) * ritorno + (1 - ritorno) * 0
	local scocca = r * ritorno
	p.torace = ruota(0, -0.55 * tende, 0)
	p["braccio.L"] = ruota(1.5 * tende, 0.55 * tende, 0)
	-- A riposo l'avambraccio sinistro è già in avanti (regge l'arco dritto): alzando il braccio si distende.
	p["avambraccio.L"] = ruota(-1.45 * tende, 0, 0)
	p["braccio.R"] = ruota(1.45 * tende - 0.25 * scocca, 0.55 * tende, 0.3 * scocca)
	p["avambraccio.R"] = ruota(0, 0, 1.9 * tende * (1 - scocca))
	p.testa = ruota(0, 0.5 * tende, 0)
end

function POSE.arcoMesh(p, _a, k, r, ritorno, self)
	local R = self.riposo
	local tende = k * ritorno
	local scocca = r * ritorno
	p.torace = ruota(0, -0.5 * tende, 0)
	p.testa = ruota(0.05 * tende, 0.45 * tende, 0)
	local spalla = R["braccio.L"]
	local braccio = (R["avambraccio.L"] - spalla).Magnitude + (R["mano.L"] - R["avambraccio.L"]).Magnitude
	local collo = R.testa
	-- Il braccio dell'arco tutto disteso verso il bersaglio, il pugno all'altezza della spalla (l'IK si ferma
	-- dove il braccio arriva); la corda tirata fino all'angolo della mascella, a destra del viso, con il gomito
	-- dietro in linea con la freccia.
	local arco = Vector3.new(collo.X - 0.05, spalla.Y + 0.1, collo.Z - braccio * 1.1)
	local mento = Vector3.new(collo.X + 0.13, collo.Y + 0.1, collo.Z + 0.05)
	self:_mano(p, "L", arco, Vector3.new(-1, -0.4, 0.2), tende, CFrame.identity)
	local tiro = mento + Vector3.new(0.15, 0.03, 0.3) * scocca
	self:_mano(p, "R", tiro, Vector3.new(0.35, 0.1, 1), tende)
	-- La freccia incoccata si vede finché la corda è tesa e non è ancora partita.
	self.incoccata = tende * (1 - math.min(1, scocca * 4))
end

-- Cavaliere: affondo con la lancia, il cavallo si impenna un poco.
function POSE.cavalleria(p, a, k, r, ritorno, self)
	if self.cavalloMesh then
		return POSE.cavalleriaMesh(p, a, k, r, ritorno, self)
	end
	local indietro = k * (1 - r)
	local avanti = r * ritorno
	p["braccio.R"] = ruota(0.4 * indietro + 1.1 * avanti, 0, 0)
	p.torace = ruota(-0.15 * indietro + 0.25 * avanti, -0.3 * indietro + 0.3 * avanti, 0)
	p.bacino = ruota(0.12 * indietro, 0, 0)
	p.collo = ruota(0.3 * indietro, 0, 0)
	p["zampa.AR"] = ruota(0.9 * indietro, 0, 0)
	p["zampa.AL"] = ruota(0.7 * indietro, 0, 0)
end

-- Modello Blender: la lancia arretra e poi affonda lungo il suo asse (la mano la tiene in linea),
-- il busto ruota col colpo, il cavallo si alza un poco sulle zampe dietro.
local LANCIA = Vector3.new(0, -0.2, -1).Unit
function POSE.cavalleriaMesh(p, _a, k, r, ritorno, self)
	local indietro = k * (1 - r)
	local avanti = r * ritorno
	p.torace = ruota(0.04 * avanti, -0.25 * indietro + 0.3 * avanti, 0)
	if self.riposo["mano.R"] then
		local presa = self.riposo["mano.R"] + LANCIA * (-0.9 * indietro + 0.85 * avanti) + Vector3.new(0, 0.3 * indietro, 0)
		self:_mano(p, "R", presa, Vector3.new(1, -0.3, 0.6), math.max(indietro, avanti), CFrame.identity)
	end
	local alza = indietro * 0.8 + avanti * 0.4
	p.cavallo = CFrame.new(0, 0.35 * alza, 0) * ruota(0.14 * alza, 0, 0)
	p["cavallo.collo"] = ruota(0.12 * alza, 0, 0)
	for _, lato in ipairs({ "R", "L" }) do
		p["zampa.A" .. lato .. "1"] = ruota(0.55 * alza, 0, 0)
		p["zampa.A" .. lato .. "2"] = ruota(0.25 * alza, 0, 0)
		p["zampa.A" .. lato .. "3"] = ruota(-1.3 * alza, 0, 0)
		p["zampa.P" .. lato .. "1"] = ruota(-0.12 * alza, 0, 0)
	end
end

-- Fucile: a riposo è basso e pronto (calcio al fianco); per mirare le braccia lo portano su all'altezza
-- della spalla tenendolo in piano (braccio su, avambraccio che compensa), poi il rinculo.
function POSE.fucile(p, _a, k, r, ritorno)
	local mira = k * ritorno
	local rinculo = r * ritorno * (1 - r)
	p["braccio.R"] = ruota(0.55 * mira - 0.12 * rinculo, 0.1 * mira, 0)
	p["avambraccio.R"] = ruota(-0.85 * mira, 0, 0)
	p["braccio.L"] = ruota(0.5 * mira, -0.1 * mira, 0)
	p["avambraccio.L"] = ruota(-0.8 * mira, 0, 0)
	p.torace = ruota(-0.2 * rinculo + 0.06 * mira, -0.15 * mira, 0)
	p.testa = ruota(0.12 * mira, 0.15 * mira, 0)
end

function POSE.pistola(p, _a, k, r, ritorno)
	local mira = k * ritorno
	p["braccio.R"] = ruota(1.5 * mira + 0.3 * r * ritorno * (1 - r), 0, 0)
	p.torace = ruota(0, 0.2 * mira, 0)
end

function POSE.mitragliatrice(p, _a, k, r, ritorno)
	local scossa = 0.08 * math.sin(r * 40) * ritorno * k
	p.bacino = CFrame.new(0, 0, scossa)
	p.mitragliatrice = CFrame.new(0, 0, scossa * 0.6)
end

function POSE.carro(p, _a, _k, r, ritorno, self)
	local rinculo = r * ritorno * (1 - r) * 4
	if self.giunti.cannone then
		-- Sherman di Blender: rincula solo il cannone, la torretta sobbalza appena.
		p.cannone = CFrame.new(0, 0, 0.45 * rinculo)
		p.torretta = ruota(-0.02 * rinculo, 0, 0)
	else
		p.torretta = CFrame.new(0, 0, 0.5 * rinculo)
	end
	p.bacino = ruota(-0.03 * rinculo, 0, 0)
end

function POSE.fortezza() end

-- Passo di marcia: gambe e braccia che oscillano, il corpo che sale e scende.
local function marcia(self, p, intensita)
	if intensita <= 0.01 then
		return
	end
	local s = math.sin(self.fase * 2 * PI)
	local c = math.cos(self.fase * 2 * PI)
	if self.cavalloMesh then
		-- Trotto: zampe a coppie diagonali; quella in avanti si alza piegando ginocchio o garretto.
		local fasi = { AR = 0, PL = 0, AL = PI, PR = PI }
		for zampa, f in pairs(fasi) do
			local angolo = self.fase * 2 * PI + f
			local spinta = math.sin(angolo)
			local alza = math.max(0, math.cos(angolo))
			local davanti = zampa:sub(1, 1) == "A"
			p["zampa." .. zampa .. "1"] = ruota((davanti and 0.4 or 0.35) * spinta * intensita, 0, 0)
			if davanti then
				p["zampa." .. zampa .. "2"] = ruota(0.35 * alza * intensita, 0, 0)
				p["zampa." .. zampa .. "3"] = ruota(-1.3 * alza * intensita, 0, 0)
			else
				p["zampa." .. zampa .. "2"] = ruota(-0.35 * alza * intensita, 0, 0)
				p["zampa." .. zampa .. "3"] = ruota(0.9 * alza * intensita, 0, 0)
			end
		end
		local battuta = math.abs(math.cos(self.fase * 2 * PI))
		p.cavallo = CFrame.new(0, 0.18 * battuta * intensita, 0) * ruota(0.03 * s * intensita, 0, 0)
		p["cavallo.collo"] = ruota(0.08 * c * intensita, 0, 0)
		p["cavallo.coda"] = ruota(0.25 * intensita, 0, 0.12 * s * intensita)
		-- Il cavaliere assorbe il trotto.
		p.bacino = CFrame.new(0, -0.08 * battuta * intensita, 0)
		p.torace = ruota(-0.05 * c * intensita, 0, 0)
		return
	elseif self.stile == "cavalleria" then
		p["zampa.AR"] = ruota(0.6 * s * intensita, 0, 0)
		p["zampa.PL"] = ruota(0.6 * s * intensita, 0, 0)
		p["zampa.AL"] = ruota(-0.6 * s * intensita, 0, 0)
		p["zampa.PR"] = ruota(-0.6 * s * intensita, 0, 0)
		p.bacino = CFrame.new(0, math.abs(c) * 0.25 * intensita, 0) * ruota(0.05 * s * intensita, 0, 0)
		p.collo = ruota(0.15 * c * intensita, 0, 0)
		p.torace = ruota(-0.08 * c * intensita, 0, 0)
		return
	elseif self.stile == "carro" or self.stile == "fortezza" or self.stile == "mitragliatrice" then
		p.bacino = CFrame.new(0, math.abs(s) * 0.05 * intensita, 0)
		return
	end
	p["coscia.R"] = ruota(0.55 * s * intensita, 0, 0)
	p["coscia.L"] = ruota(-0.55 * s * intensita, 0, 0)
	p["stinco.R"] = ruota(-0.8 * math.max(0, -c) * intensita, 0, 0)
	p["stinco.L"] = ruota(-0.8 * math.max(0, c) * intensita, 0, 0)
	p["piede.R"] = ruota(0.25 * math.max(0, -c) * intensita, 0, 0)
	p["piede.L"] = ruota(0.25 * math.max(0, c) * intensita, 0, 0)
	p.bacino = CFrame.new(0, (math.abs(c) - 0.6) * 0.12 * intensita, 0) * ruota(0, 0.08 * s * intensita, 0)
	p.torace = ruota(0.06 * intensita, -0.1 * s * intensita, 0)
	-- Le braccia libere oscillano poco: tengono armi e scudi.
	p["braccio.R"] = ruota(-0.18 * s * intensita, 0, 0)
	p["braccio.L"] = ruota(0.18 * s * intensita, 0, 0)
end

-- Chi viene colpito arretra il busto per un istante.
local function colpito(self, p)
	local t = self.tempo - self.ferita
	if t < 0 or t > 0.3 then
		return
	end
	local f = math.sin(t / 0.3 * PI)
	p.torace = (p.torace or CFrame.identity) * ruota(-0.25 * f, 0, 0)
	p.testa = (p.testa or CFrame.identity) * ruota(-0.2 * f, 0, 0)
end

-- Caduta all'indietro: il corpo ruota attorno ai piedi e si accascia.
local function caduta(self, p)
	local t = self.tempo - self.morte
	local f = liscio(t / 0.7)
	if self.stile == "mitragliatrice" and self.riposo then
		-- In ginocchio dietro l'arma: si accascia indietro e di lato; l'arma resta sul treppiede.
		p.bacino = CFrame.new(0.2 * f, -0.75 * f, 0.7 * f) * ruota(1.25 * f, 0, 0.35 * f)
		p["braccio.R"] = ruota(0.4 * f, 0, 0.7 * f)
		p["braccio.L"] = ruota(0.3 * f, 0, -0.7 * f)
		p.testa = ruota(0.3 * f, 0.4 * f, 0)
		return
	end
	if self.stile == "carro" or self.stile == "fortezza" or self.stile == "mitragliatrice" then
		p.bacino = CFrame.new(0, -1.2 * f, 0) * ruota(-0.12 * f, 0, 0.08 * f)
		return
	end
	if self.cavalloMesh then
		-- Il cavallo crolla sul fianco, con le zampe piegate; il cavaliere va giù con lui.
		-- Il corpo del cavallo finisce a terra: dal suo osso al suolo meno mezzo ventre.
		local metri = self.modello:GetAttribute("MeshMetri") or 2.34
		local basso = self.modello:GetAttribute("MeshBasso")
		local giu = basso and (self.riposo.cavallo.Y - basso - 0.32 * metri) or 2.9
		p.cavallo = CFrame.new(0.4 * f, -giu * f, 0) * ruota(0, 0, -1.4 * f)
		p["cavallo.collo"] = ruota(-0.3 * f, 0, 0)
		for _, zampa in ipairs({ "AR", "AL", "PR", "PL" }) do
			local davanti = zampa:sub(1, 1) == "A"
			p["zampa." .. zampa .. "3"] = ruota((davanti and -0.9 or 0.6) * f, 0, 0)
		end
		p.torace = ruota(-0.5 * f, 0, 0)
		p["braccio.R"] = ruota(1.0 * f, 0, 0.3 * f)
		return
	elseif self.stile == "cavalleria" then
		p.bacino = CFrame.new(0, -1.1 * f, 0) * ruota(0, 0, 1.2 * f)
		p.torace = ruota(-0.6 * f, 0, 0)
		return
	end
	-- Il bacino (alto circa 2,2 studs) scende a terra e tutto il corpo si rovescia indietro: la schiena a terra,
	-- le gambe distese in avanti, le braccia aperte.
	p.bacino = CFrame.new(0, -1.85 * f, 0.9 * f) * ruota(1.4 * f, 0, 0.12 * f)
	p["coscia.R"] = ruota(0.15 * f, 0, 0)
	p["coscia.L"] = ruota(0.45 * f, 0, 0)
	p["stinco.L"] = ruota(-0.8 * f, 0, 0)
	p["braccio.R"] = ruota(0.6 * f, 0, 0.9 * f)
	p["braccio.L"] = ruota(0.4 * f, 0, -0.8 * f)
	p.testa = ruota(0.25 * f, 0.4 * f, 0)
end

-- Respiro da fermi (e il cavallo che muove la testa e la coda).
local function respiro(self, p)
	if self.cavalloMesh then
		p["cavallo.collo"] = ruota(0.05 * math.sin(self.tempo * 0.6), 0.06 * math.sin(self.tempo * 0.23), 0)
		p["cavallo.muso"] = ruota(0.05 * math.sin(self.tempo * 1.1 + 1), 0, 0)
		p["cavallo.coda"] = ruota(0.05, 0, 0.18 * math.sin(self.tempo * 0.9) * math.max(0, math.sin(self.tempo * 0.31)))
	end
	local b = math.sin(self.tempo * 1.7) * 0.025
	p.torace = (p.torace or CFrame.identity) * ruota(b, 0, 0)
	p.testa = (p.testa or CFrame.identity) * ruota(-b * 0.6, math.sin(self.tempo * 0.37) * 0.12, 0)
end

-- Freccia incoccata dell'arciere di Blender: dalla mano della corda oltre il pugno dell'arco.
function Animatore:_freccia()
	if self.stile ~= "arco" or not self.riposo or not self.giunti["mano.L"] then
		return
	end
	local visibile = self.incoccata > 0.6 and not self.morte
	if not visibile then
		if self.freccia then
			self.freccia.Transparency = 1
		end
		return
	end
	if not self.freccia then
		local f = Instance.new("Part")
		f.Name = "FrecciaIncoccata"
		f.Anchored = true
		f.CanCollide = false
		f.CanQuery = false
		f.CanTouch = false
		f.CastShadow = false
		f.Material = Enum.Material.Wood
		f.Color = Color3.fromRGB(150, 110, 64)
		f.Parent = self.modello
		self.freccia = f
	end
	local a = self.giunti["mano.R"].TransformedWorldCFrame.Position
	local b = self.giunti["mano.L"].TransformedWorldCFrame.Position
	local d = b - a
	if d.Magnitude < 0.2 then
		self.freccia.Transparency = 1
		return
	end
	local lunghezza = d.Magnitude + 0.45
	self.freccia.Size = Vector3.new(0.05, 0.05, lunghezza)
	self.freccia.CFrame = CFrame.lookAt(a + d.Unit * (lunghezza / 2), b)
	self.freccia.Transparency = 0
end

-- dt in secondi, velocita in studs al secondo (quanto si sta spostando il soldato).
function Animatore:aggiorna(dt, velocita)
	self.tempo += dt
	local passo = PASSI[self.stile] or 3.4
	self.fase = (self.fase + velocita * dt / passo) % 1
	local obiettivo = math.clamp(velocita / 4, 0, 1)
	self.marcia += (obiettivo - self.marcia) * math.min(1, dt * 8)
	local p = {}
	self.incoccata = 0
	if self.morte then
		caduta(self, p)
	else
		respiro(self, p)
		marcia(self, p, self.marcia)
		local a = self.attacco
		if a then
			local k, r, ritorno, finito = tempiColpo(a, self.tempo)
			if finito then
				self.attacco = nil
			else
				local colpo = {}
				POSE[self.stile](colpo, a, k, r, ritorno, self)
				-- Il colpo comanda braccia e busto; le gambe restano quelle della marcia.
				for nome, cf in pairs(colpo) do
					p[nome] = cf
				end
			end
		end
		colpito(self, p)
	end
	self:_freccia()
	if self.lanciaVia and not self.gladioInMano then
		p.lancia = CFrame.new(0, -400, 0)
	elseif self.lanciaVia then
		p.lancia = CFrame.new(0, -400, 0)
	end
	for nome, giunto in pairs(self.giunti) do
		giunto.Transform = p[nome] or CFrame.identity
	end
end

return Animatore
