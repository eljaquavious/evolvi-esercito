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
	return self
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
function POSE.spada(p, _a, k, r, ritorno)
	local su = k * (1 - r)
	local giu = r * ritorno
	p["braccio.R"] = ruota(2.6 * su + 0.8 * giu, 0, -0.3 * su)
	p["avambraccio.R"] = ruota(0.6 * su, 0, 0)
	p.torace = ruota(0.15 * giu, -0.4 * su + 0.4 * giu, 0)
	p["braccio.L"] = ruota(0.3 * su, 0, 0)
end

-- Ascia danese a due mani: carica sopra la spalla e colpo dall'alto.
function POSE.ascia(p, _a, k, r, ritorno)
	local su = k * (1 - r)
	local giu = r * ritorno
	p["braccio.R"] = ruota(2.8 * su + 0.9 * giu, 0, 0)
	p["braccio.L"] = ruota(2.2 * su + 0.9 * giu, 0, 0)
	p.torace = ruota(-0.2 * su + 0.3 * giu, -0.3 * su + 0.3 * giu, 0)
end

-- Arciere: tende l'arco verso il nemico, scocca, torna giù.
function POSE.arco(p, _a, k, r, ritorno)
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

-- Cavaliere: affondo con la lancia, il cavallo si impenna un poco.
function POSE.cavalleria(p, _a, k, r, ritorno)
	local indietro = k * (1 - r)
	local avanti = r * ritorno
	p["braccio.R"] = ruota(0.4 * indietro + 1.1 * avanti, 0, 0)
	p.torace = ruota(-0.15 * indietro + 0.25 * avanti, -0.3 * indietro + 0.3 * avanti, 0)
	p.bacino = ruota(0.12 * indietro, 0, 0)
	p.collo = ruota(0.3 * indietro, 0, 0)
	p["zampa.AR"] = ruota(0.9 * indietro, 0, 0)
	p["zampa.AL"] = ruota(0.7 * indietro, 0, 0)
end

-- Fucile: lo porta alla spalla, mira, rinculo.
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
	p.bacino = CFrame.new(0, 0, 0.08 * math.sin(r * 40) * ritorno * k)
end

function POSE.carro(p, _a, _k, r, ritorno)
	local rinculo = r * ritorno * (1 - r) * 4
	p.torretta = CFrame.new(0, 0, 0.5 * rinculo)
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
	if self.stile == "cavalleria" then
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
	if self.stile == "carro" or self.stile == "fortezza" or self.stile == "mitragliatrice" then
		p.bacino = CFrame.new(0, -1.2 * f, 0) * ruota(-0.12 * f, 0, 0.08 * f)
		return
	end
	if self.stile == "cavalleria" then
		p.bacino = CFrame.new(0, -1.1 * f, 0) * ruota(0, 0, 1.2 * f)
		p.torace = ruota(-0.6 * f, 0, 0)
		return
	end
	p.bacino = CFrame.new(0, -0.9 * f, 0.6 * f) * ruota(-1.35 * f, 0, 0.15 * f)
	p["coscia.R"] = ruota(0.5 * f, 0, 0)
	p["coscia.L"] = ruota(0.9 * f, 0, 0)
	p["stinco.L"] = ruota(-1.0 * f, 0, 0)
	p["braccio.R"] = ruota(1.2 * f, 0, 0.4 * f)
	p["braccio.L"] = ruota(0.9 * f, 0, -0.5 * f)
	p.testa = ruota(-0.3 * f, 0.3 * f, 0)
end

-- Respiro da fermi.
local function respiro(self, p)
	local b = math.sin(self.tempo * 1.7) * 0.025
	p.torace = (p.torace or CFrame.identity) * ruota(b, 0, 0)
	p.testa = (p.testa or CFrame.identity) * ruota(-b * 0.6, math.sin(self.tempo * 0.37) * 0.12, 0)
end

-- dt in secondi, velocita in studs al secondo (quanto si sta spostando il soldato).
function Animatore:aggiorna(dt, velocita)
	self.tempo += dt
	local passo = PASSI[self.stile] or 3.4
	self.fase = (self.fase + velocita * dt / passo) % 1
	local obiettivo = math.clamp(velocita / 4, 0, 1)
	self.marcia += (obiettivo - self.marcia) * math.min(1, dt * 8)
	local p = {}
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
				POSE[self.stile](colpo, a, k, r, ritorno)
				-- Il colpo comanda braccia e busto; le gambe restano quelle della marcia.
				for nome, cf in pairs(colpo) do
					p[nome] = cf
				end
			end
		end
		colpito(self, p)
	end
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
