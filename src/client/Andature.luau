-- Andature condivise da truppe e avatar dei giocatori (8/11/2026, reference di Mattia: camminata a manichino
-- saltellante e corsa piegata in avanti). Una sola camminata per tutti; due corse: quella del giocatore,
-- esagerata, e quella della truppa, una marcia forzata più composta.
--
-- Ogni funzione restituisce una posa: { nome articolazione -> CFrame } con i nomi delle ossa dei soldati
-- (bacino, torace, testa, braccio.R, avambraccio.R, coscia.R, stinco.R, piede.R e i .L).
-- Convenzioni (come in Animatore): Angles(a, 0, 0) con a > 0 porta in avanti braccia e gambe; lo stinco
-- si piega indietro con a < 0, l'avambraccio in avanti con a > 0; Angles(0, 0, z) con z > 0 apre verso
-- destra (braccio destro in fuori), con z < 0 verso sinistra. "fase" va da 0 a 1 in un passo completo
-- (due appoggi): con fase 0,25 la gamba destra è tutta avanti.

local Andature = {}

local PI = math.pi
local ruota = CFrame.Angles

-- "avanti" (opz.avanti) è il segno della rotazione in X che piega in avanti bacino, busto e testa: -1 sia sugli
-- avatar Roblox sia sulle ossa dei soldati (provato in Studio: con +0,4 sul torace la testa va indietro).
-- opz = { braccia = 0-1 (oscillazione delle braccia: i soldati tengono armi e scudi), scala = rimbalzo, avanti }
local function opzioni(opz)
	opz = opz or {}
	return opz.braccia or 1, opz.scala or 1, opz.avanti or -1
end

local function onde(fase)
	local a = fase * 2 * PI
	return math.sin(a), math.cos(a)
end

-- Camminata unica (truppe e giocatori): ginocchia alte, braccia aperte che oscillano larghe, il corpo che
-- rimbalza a ogni appoggio e dondola un poco. braccia (0-1) dosa l'oscillazione delle braccia: i soldati
-- tengono armi e scudi.
function Andature.cammina(fase, opz)
	local braccia, scala, avanti = opzioni(opz)
	local s, c = onde(fase)
	local p = {}
	for _, lato in ipairs({ "R", "L" }) do
		local v = lato == "R" and 1 or -1
		local sl, cl = s * v, c * v
		-- La gamba che va avanti si alza di più di quanto quella dietro si allunghi.
		p["coscia." .. lato] = ruota(0.5 * sl + 0.22 * math.max(0, sl), 0, 0.04 * v)
		-- Ginocchio piegato mentre la gamba torna avanti in aria.
		p["stinco." .. lato] = ruota(-0.95 * math.max(0, cl), 0, 0)
		p["piede." .. lato] = ruota(0.3 * math.max(0, cl) - 0.12 * math.max(0, -sl), 0, 0)
		-- Braccia opposte alle gambe, aperte in fuori, il gomito un po' piegato.
		p["braccio." .. lato] = ruota(-0.6 * sl * braccia, 0, (0.3 + 0.08 * math.abs(s)) * v * braccia)
		p["avambraccio." .. lato] = ruota((0.1 + 0.3 * math.max(0, -sl)) * braccia, 0, 0)
	end
	-- Il corpo è più in alto quando le gambe si incrociano (|c| = 1), più in basso all'appoggio.
	local su = (math.abs(c) - 0.55) * 0.32 * scala
	p.bacino = CFrame.new(0, su, 0) * ruota(0, 0.1 * s, 0.05 * s)
	p.torace = ruota(0.03 * avanti, -0.16 * s, -0.04 * s)
	p.testa = ruota(0, 0.08 * s, 0.03 * s)
	return p
end

-- Corsa del giocatore: piegato in avanti, braccia a pistone con il gomito ad angolo retto, il tallone che
-- calcia dietro e il ginocchio che sale davanti.
function Andature.corsaGiocatore(fase, opz)
	local _, scala, avanti = opzioni(opz)
	local s, c = onde(fase)
	local p = {}
	for _, lato in ipairs({ "R", "L" }) do
		local v = lato == "R" and 1 or -1
		local sl, cl = s * v, c * v
		p["coscia." .. lato] = ruota(0.85 * sl + 0.35 + 0.25 * math.max(0, sl), 0, 0.03 * v)
		-- Il calcio indietro: ginocchio chiusissimo appena la gamba si stacca da dietro.
		p["stinco." .. lato] = ruota(-0.35 - 1.35 * math.max(0, cl) ^ 0.7, 0, 0)
		p["piede." .. lato] = ruota(0.35 * math.max(0, cl), 0, 0)
		p["braccio." .. lato] = ruota(-1.0 * sl + 0.15, 0, 0.14 * v)
		p["avambraccio." .. lato] = ruota(1.35 + 0.3 * math.max(0, sl), 0, 0)
	end
	local su = (math.abs(c) - 0.5) * 0.42 * scala
	p.bacino = CFrame.new(0, su - 0.18 * scala, 0) * ruota(0.3 * avanti, 0.14 * s, 0.03 * s)
	p.torace = ruota(0.24 * avanti, -0.22 * s, 0)
	-- La testa compensa e guarda avanti.
	p.testa = ruota(-0.38 * avanti, 0.1 * s, 0)
	return p
end

-- Corsa della truppa: una marcia forzata. Passi più corti e rapidi, busto poco inclinato e fermo, braccia
-- vicine al corpo (tengono le armi), un rimbalzo regolare.
function Andature.corsaTruppa(fase, opz)
	local braccia, scala, avanti = opzioni(opz)
	local s, c = onde(fase)
	local p = {}
	for _, lato in ipairs({ "R", "L" }) do
		local v = lato == "R" and 1 or -1
		local sl, cl = s * v, c * v
		p["coscia." .. lato] = ruota(0.6 * sl + 0.12 + 0.12 * math.max(0, sl), 0, 0.03 * v)
		p["stinco." .. lato] = ruota(-0.2 - 0.85 * math.max(0, cl), 0, 0)
		p["piede." .. lato] = ruota(0.25 * math.max(0, cl), 0, 0)
		p["braccio." .. lato] = ruota((-0.35 * sl + 0.1) * braccia, 0, 0.1 * v * braccia)
		p["avambraccio." .. lato] = ruota((0.6 + 0.15 * math.max(0, sl)) * braccia, 0, 0)
	end
	local su = (math.abs(c) - 0.5) * 0.24 * scala
	p.bacino = CFrame.new(0, su - 0.08 * scala, 0) * ruota(0.1 * avanti, 0.06 * s, 0.02 * s)
	p.torace = ruota(0.08 * avanti, -0.08 * s, 0)
	p.testa = ruota(-0.1 * avanti, 0, 0)
	return p
end

-- Posa da fermo del giocatore (immagine di Mattia): braccia staccate dal corpo, gambe un po' aperte,
-- il respiro che muove appena busto e braccia.
function Andature.fermo(tempo, opz)
	local _, _, avanti = opzioni(opz)
	local r = math.sin(tempo * 1.6)
	local p = {}
	for _, lato in ipairs({ "R", "L" }) do
		local v = lato == "R" and 1 or -1
		p["braccio." .. lato] = ruota(0.02 * r, 0, (0.24 + 0.02 * r) * v)
		p["avambraccio." .. lato] = ruota(0.12, 0, 0)
		p["coscia." .. lato] = ruota(0, 0, 0.1 * v)
		p["piede." .. lato] = ruota(0, 0, -0.1 * v)
	end
	p.bacino = CFrame.new(0, 0.015 * r, 0)
	p.torace = ruota(-0.015 * r * avanti, 0, 0)
	p.testa = ruota(0, 0.1 * math.sin(tempo * 0.37), 0)
	return p
end

-- Posa in aria (salto e caduta del giocatore).
function Andature.aria(sale)
	local p = {}
	for _, lato in ipairs({ "R", "L" }) do
		local v = lato == "R" and 1 or -1
		p["braccio." .. lato] = ruota(sale and 0.5 or 0.2, 0, (sale and 0.5 or 0.9) * v)
		p["avambraccio." .. lato] = ruota(0.4, 0, 0)
	end
	p["coscia.R"] = ruota(0.7, 0, 0.05)
	p["stinco.R"] = ruota(-1.0, 0, 0)
	p["coscia.L"] = ruota(-0.1, 0, -0.05)
	p["stinco.L"] = ruota(-0.4, 0, 0)
	return p
end

-- Seduto.
function Andature.seduto()
	local p = {}
	for _, lato in ipairs({ "R", "L" }) do
		local v = lato == "R" and 1 or -1
		p["coscia." .. lato] = ruota(PI / 2, 0, 0.05 * v)
		p["stinco." .. lato] = ruota(-PI / 2, 0, 0)
		p["braccio." .. lato] = ruota(0.25, 0, 0.12 * v)
		p["avambraccio." .. lato] = ruota(0.4, 0, 0)
	end
	return p
end

-- Somma pesata di due pose (peso 0 = tutta a, 1 = tutta b); le articolazioni assenti valgono l'identità.
function Andature.miscela(a, b, peso)
	if peso <= 0 then
		return a
	elseif peso >= 1 then
		return b
	end
	local p = {}
	for nome, cf in pairs(a) do
		p[nome] = cf:Lerp(b[nome] or CFrame.identity, peso)
	end
	for nome, cf in pairs(b) do
		if not a[nome] then
			p[nome] = CFrame.identity:Lerp(cf, peso)
		end
	end
	return p
end

-- Posa dosata (intensità 0-1 rispetto alla posa a riposo).
function Andature.dosa(a, peso)
	return Andature.miscela({}, a, peso)
end

return Andature
