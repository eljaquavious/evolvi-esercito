-- Scenari dei campi di battaglia: per ogni battaglia storica la vegetazione del posto, i luoghi e le cose
-- dell'uomo attorno al campo (accampamenti, mura, villaggi, trincee, relitti), gli ostacoli sulle caselle,
-- i dettagli sparsi sul campo, gli scavi (crateri, trincee) e le modifiche al terreno (mare, laghi, fango).
--
-- Coordinate in studs rispetto al centro del campo: x di traverso, z lungo la battaglia (z > 0 = nemico).
-- Il campo è ±48; attorno resta libera una cornice (PROTETTO) e il corridoio da cui arriva il giocatore.
-- Zone: { x0, x1, z0, z1 }. verso: "campo" = guarda il campo, un numero = gradi, nil = a caso.

local Paesaggio = require(script.Parent.Paesaggio)

local P = Paesaggio.oggetti
local C = Color3.fromRGB
local M = Enum.Material

local Scenari = {}

local META_CAMPO = 48
local PROTETTO = META_CAMPO + 20
local BORDO = 290 -- oltre, il terreno sale ripido verso i muri invisibili
local CELLA = 16 -- lato delle celle della griglia degli ingombri
local DENSITA = 2.2 -- moltiplica la vegetazione delle tabelle (alberi, rocce)
local DENSITA_PICCOLI = 3.5 -- e quella bassa (erba, sassi, fiori, arbusti)
-- Tende e padiglioni stanno in file (gli accampamenti erano ordinati), il resto è sparso.
local TENDE = { padiglione = true, tendaRomana = true }

-- Vegetazione di base per bioma: { oggetto, quanti, scala minima, scala massima }.
local FLORA = {
	Pianeggiante = { { "quercia", 34, 0.9, 1.4 }, { "betulla", 14, 0.9, 1.3 }, { "cespuglio", 60, 0.8, 1.4 }, { "ciuffo", 130, 0.8, 1.3 }, { "fiori", 40, 0.8, 1.2 }, { "roccia", 12, 0.8, 1.5 }, { "sassi", 30, 0.8, 1.2 } },
	Collinoso = { { "quercia", 32, 0.9, 1.5 }, { "pino", 16, 0.9, 1.4 }, { "cespuglio", 60, 0.8, 1.4 }, { "ciuffo", 120, 0.8, 1.3 }, { "roccia", 24, 0.9, 1.8 }, { "masso", 5, 0.7, 1.1 }, { "sassi", 40, 0.8, 1.3 }, { "fiori", 24, 0.8, 1.2 } },
	Desertico = { { "arbusto", 70, 0.8, 1.4 }, { "ciuffo", 120, 0.8, 1.3 }, { "tamerice", 18, 0.9, 1.4 }, { "palma", 8, 0.9, 1.3 }, { "roccia", 26, 0.8, 1.8 }, { "masso", 5, 0.6, 1.0 }, { "sassi", 50, 0.8, 1.3 } },
	Montagnoso = { { "pino", 56, 1.0, 1.7 }, { "roccia", 40, 1.0, 2.2 }, { "masso", 12, 0.8, 1.3 }, { "cespuglio", 40, 0.8, 1.3 }, { "ciuffo", 90, 0.8, 1.2 }, { "sassi", 60, 0.8, 1.4 } },
	Innevato = { { "pino", 80, 1.0, 1.8 }, { "betulla", 20, 0.9, 1.3 }, { "roccia", 16, 0.9, 1.6 }, { "cespuglio", 30, 0.8, 1.2 }, { "sassi", 30, 0.8, 1.3 } },
}

-- Ostacoli sulle caselle bloccate e piccoli dettagli sparsi tra le caselle, per bioma.
local OSTACOLI = {
	Pianeggiante = { "quercia", "cespuglio" },
	Collinoso = { "roccia", "quercia" },
	Desertico = { "roccia", "tamerice", "arbusto" },
	Montagnoso = { "masso", "pino" },
	Innevato = { "pino", "roccia" },
}
local DETTAGLI = {
	Pianeggiante = { "ciuffo", "ciuffo", "fiori", "sassi" },
	Collinoso = { "ciuffo", "ciuffo", "sassi", "fiori" },
	Desertico = { "ciuffo", "sassi", "sassi", "arbusto" },
	Montagnoso = { "sassi", "sassi", "ciuffo" },
	Innevato = { "sassi", "ciuffo" },
}
-- Cornice: boschi (o rocce) fitti sui fianchi della valle, che la chiudono. { oggetto, quanti, smin, smax }.
local CORNICE = {
	Pianeggiante = { { "quercia", 50, 1.0, 1.6 }, { "betulla", 24, 1.0, 1.4 }, { "cespuglio", 50, 1.0, 1.5 } },
	Collinoso = { { "quercia", 46, 1.0, 1.6 }, { "pino", 30, 1.0, 1.6 }, { "cespuglio", 50, 1.0, 1.5 } },
	Desertico = { { "masso", 30, 0.8, 1.6 }, { "roccia", 50, 1.2, 2.4 }, { "arbusto", 50, 1.0, 1.5 } },
	Montagnoso = { { "pino", 80, 1.1, 1.9 }, { "masso", 20, 0.9, 1.5 }, { "roccia", 30, 1.2, 2.2 } },
	Innevato = { { "pino", 90, 1.1, 1.9 }, { "betulla", 20, 1.0, 1.4 }, { "roccia", 16, 1.0, 1.8 } },
}

local CONTESTO_BIOMA = {
	Desertico = { secco = true, sabbia = true },
	Innevato = { neve = true },
}

-- Colori dei padiglioni e dei drappi.
local PERSIANI = { C(226, 210, 164), C(110, 40, 120) }
local PUNICI = { C(232, 222, 196), C(120, 36, 100) }
local GRECI = { C(222, 214, 190), C(60, 80, 140) }
local CROCIATI = { C(240, 236, 224), C(170, 30, 30) }
local SARACENI = { C(240, 230, 200), C(40, 120, 60) }
local BIZANTINI = { C(150, 30, 40), C(220, 180, 70) }
local SELGIUCHIDI = { C(230, 220, 190), C(30, 90, 140) }
local TEUTONICI = { C(240, 240, 238), C(30, 30, 30) }
local MAGIARI = { C(200, 190, 170), C(140, 110, 80) }
local NORMANNI = { C(230, 220, 190), C(30, 60, 140) }
local OMAYYADI = { C(240, 236, 220), C(30, 110, 70) }
local INGLESI = { C(220, 40, 40), C(230, 200, 60) }
local GENOVESI = { C(200, 40, 40), C(240, 240, 240) }

-- Composizioni ricorrenti -------------------------------------------------------------------------

-- Accampamento romano (castra): recinto di pali con le torri agli angoli, tende in file, insegna e fuochi.
local function castra(x, z, lato)
	local m = lato / 2
	local linee = {
		{ "palizzata", { x - m, z - m }, { x + m, z - m }, 22 },
		{ "palizzata", { x + m, z - m }, { x + m, z + m }, 22 },
		{ "palizzata", { x + m, z + m }, { x - m, z + m }, 22 },
		{ "palizzata", { x - m, z + m }, { x - m, z - m }, 22 },
	}
	local pezzi = {
		{ "torre", x - m, z - m, 0, 0.8 }, { "torre", x + m, z - m, 0, 0.8 },
		{ "torre", x - m, z + m, 0, 0.8 }, { "torre", x + m, z + m, 0, 0.8 },
		{ "insegna", x, z, "campo", 1.1 }, { "fuoco", x + 10, z + 6, nil, 1 },
	}
	for i = -1, 1 do
		for k = -1, 1, 2 do
			table.insert(pezzi, { "tendaRomana", x + i * m * 0.55, z + k * m * 0.4, 0, 0.9 })
		end
	end
	return linee, pezzi
end

-- Bastia: fortino quadrato di pali con una torre (gli Inglesi attorno a Orléans).
local function bastia(x, z, lato)
	local m = lato / 2
	return {
		{ "palizzata", { x - m, z - m }, { x + m, z - m }, 18 },
		{ "palizzata", { x + m, z - m }, { x + m, z + m }, 18 },
		{ "palizzata", { x + m, z + m }, { x - m, z + m }, 18 },
		{ "palizzata", { x - m, z + m }, { x - m, z - m }, 18 },
	}, { { "torre", x, z, 0, 0.9 }, { "fuoco", x + 6, z - 5, nil, 0.9 } }
end

-- Cerchio di carri (il campo trincerato dei Teutoni, il convoglio inglese a Crécy).
local function cerchioCarri(x, z, r, n, arco)
	local pezzi = {}
	arco = arco or 2 * math.pi
	for i = 0, n - 1 do
		local a = -arco / 2 + arco * i / math.max(1, n - (arco < 6 and 1 or 0)) + math.pi / 2
		local px, pz = x + math.cos(a) * r, z + math.sin(a) * r
		-- Il carro gira di lato rispetto al centro (il timone verso il vicino).
		table.insert(pezzi, { "carro", px, pz, math.deg(-a), 0.9 })
	end
	return pezzi
end

local function unisci(dest, sorgente)
	for _, v in ipairs(sorgente) do
		table.insert(dest, v)
	end
	return dest
end

-- Le battaglie ------------------------------------------------------------------------------------

local S = {}
Scenari.Battaglie = S

-- Antichità

S["Gaugamela"] = {
	-- Pianura spianata da Dario per i carri falcati; il campo persiano coi padiglioni; i Macedoni dietro.
	terreno = { ondulazione = 2 },
	flora = { { "arbusto", 60, 0.8, 1.3 }, { "ciuffo", 140, 0.8, 1.3 }, { "tamerice", 16, 0.9, 1.3 }, { "palma", 5, 0.9, 1.2 }, { "roccia", 18, 0.8, 1.6 }, { "sassi", 60, 0.8, 1.3 } },
	gruppi = {
		{ "padiglione", 9, { -150, 150, 140, 230 }, 0.9, 1.3, ctx = { colori = PERSIANI }, verso = "campo" },
		{ "insegna", 3, { -100, 100, 120, 160 }, 1.0, 1.2, ctx = { drappo = C(110, 40, 120) }, verso = "campo" },
		{ "fuoco", 5, { -150, 150, 140, 230 }, 0.9, 1.1 },
		{ "carroFalcato", 7, { -200, 200, 75, 150 }, 0.9, 1.1 },
		{ "carroFalcato", 3, { -200, 200, -100, 60 }, 0.9, 1.1 },
		{ "tendaRomana", 6, { -130, 130, -230, -140 }, 0.9, 1.1, verso = 0 },
		{ "insegna", 2, { -80, 80, -150, -120 }, 1.0, 1.2, ctx = { drappo = C(180, 40, 30) }, verso = 0 },
		{ "anfore", 4, { -130, 130, -230, -140 }, 0.9, 1.1 },
		{ "carro", 3, { -150, 150, -250, -150 }, 0.9, 1.1 },
	},
	resti = 16,
	ostacolo = { "carroFalcato", "roccia" },
}

S["Thermopylae"] = {
	-- Il passo stretto tra la montagna e il mare; il muro dei Focesi rialzato dagli Spartani.
	versanti = { { asse = "x", segno = -1, inizio = 85, altezza = 55, largo = 90 } },
	terreno = { ondulazione = 7 },
	mare = { asse = "x", segno = 1, inizio = 120 },
	flora = { { "pino", 26, 1.0, 1.6 }, { "cipresso", 10, 0.9, 1.3 }, { "ulivo", 8, 0.9, 1.2 }, { "cespuglio", 40, 0.8, 1.3 }, { "ciuffo", 90, 0.8, 1.2 }, { "roccia", 30, 1.0, 2.0 }, { "sassi", 60, 0.8, 1.3 } },
	gruppi = {
		{ "masso", 18, { -280, -80, -260, 260 }, 0.9, 1.6 },
		{ "roccia", 20, { -280, -90, -260, 260 }, 1.2, 2.2 },
		{ "tendaRomana", 5, { -110, 60, -230, -140 }, 0.9, 1.1, verso = 0 },
		{ "fuoco", 3, { -110, 60, -230, -140 }, 1, 1 },
		{ "insegna", 2, { -60, 40, -150, -120 }, 1, 1.2, ctx = { drappo = C(170, 30, 30) }, verso = 0 },
		{ "padiglione", 6, { -150, 90, 170, 250 }, 0.9, 1.2, ctx = { colori = PERSIANI }, verso = "campo" },
		{ "nave", 3, { 170, 260, -200, 200 }, 0.8, 1.0, verso = 90, galleggia = true },
	},
	linee = {
		{ "muretto", { -110, 80 }, { 110, 80 }, 22, ctx = { lunghezza = 22 } },
	},
	resti = 18,
	ostacolo = { "masso", "roccia" },
}

S["Marathon"] = {
	-- La piana tra le colline e il mare: la grande palude, il tumulo (Soros), le navi persiane in secca.
	versanti = { { asse = "z", segno = 1, inizio = 215, altezza = 30, largo = 80 } },
	mare = { asse = "z", segno = -1, inizio = 175 },
	flora = { { "ulivo", 28, 0.9, 1.3 }, { "cipresso", 12, 0.9, 1.3 }, { "cespuglio", 40, 0.8, 1.3 }, { "ciuffo", 120, 0.8, 1.2 }, { "fiori", 30, 0.8, 1.1 }, { "sassi", 30, 0.8, 1.2 } },
	gruppi = {
		{ "canne", 40, { 90, 270, -150, 120 }, 0.9, 1.4 },
		{ "nave", 5, { -200, 200, -260, -205 }, 0.8, 1.0, verso = 0, galleggia = true },
		{ "tendaRomana", 6, { -130, 130, 150, 240 }, 0.9, 1.1, verso = "campo" },
		{ "fuoco", 3, { -130, 130, 150, 240 }, 1, 1 },
		{ "insegna", 2, { -70, 70, 120, 150 }, 1, 1.2, ctx = { drappo = C(60, 80, 140) }, verso = "campo" },
		{ "padiglione", 4, { -150, 60, -190, -130 }, 0.8, 1.0, ctx = { colori = PERSIANI }, verso = 0 },
	},
	pezzi = { { "tumulo", -160, 40, 0, 1.0 } },
	resti = 14,
	ostacolo = { "ulivo", "cespuglio" },
}

S["Heraclea"] = {
	-- Le colline sul fiume Siris: l'accampamento romano da una parte, quello di Pirro dall'altra.
	flora = { { "quercia", 26, 0.9, 1.4 }, { "ulivo", 16, 0.9, 1.3 }, { "cipresso", 10, 0.9, 1.3 }, { "cespuglio", 50, 0.8, 1.3 }, { "ciuffo", 110, 0.8, 1.2 }, { "roccia", 16, 0.9, 1.6 }, { "sassi", 30, 0.8, 1.2 }, { "fiori", 20, 0.8, 1.1 } },
	riva = { { "canne", 30, 0.9, 1.3 } },
	gruppi = {
		{ "padiglione", 6, { -140, 140, 160, 240 }, 0.9, 1.2, ctx = { colori = GRECI }, verso = "campo" },
		{ "insegna", 2, { -80, 80, 130, 160 }, 1, 1.2, ctx = { drappo = C(60, 80, 140) }, verso = "campo" },
		{ "fuoco", 3, { -140, 140, 160, 240 }, 1, 1 },
	},
	castra = { { -150, -170, 80 } },
	resti = 14,
	ostacolo = { "roccia", "ulivo" },
}

S["Cannae"] = {
	-- La pianura dell'Ofanto in estate: grano, ulivi, la collina con le rovine di Canne, i due campi romani.
	colli = { { 190, 165, 70, 14 } },
	flora = { { "ulivo", 22, 0.9, 1.3 }, { "quercia", 8, 0.9, 1.3 }, { "cipresso", 8, 0.9, 1.3 }, { "cespuglio", 40, 0.8, 1.3 }, { "ciuffo", 120, 0.8, 1.2 }, { "fiori", 20, 0.8, 1.1 }, { "sassi", 30, 0.8, 1.2 } },
	contesto = { secco = true },
	riva = { { "canne", 24, 0.9, 1.3 } },
	gruppi = {
		{ "campo", 6, { -270, 270, -270, 270 }, 0.9, 1.2, verso = 0 },
		{ "padiglione", 7, { -160, 160, 160, 240 }, 0.9, 1.2, ctx = { colori = PUNICI }, verso = "campo" },
		{ "insegna", 3, { -90, 90, 130, 160 }, 1, 1.2, ctx = { drappo = C(120, 36, 100) }, verso = "campo" },
		{ "fuoco", 4, { -160, 160, 160, 240 }, 1, 1 },
	},
	pezzi = { { "rovina", 180, 150, "campo", 1.0 }, { "rovina", 205, 175, 30, 0.8 } },
	castra = { { -170, -170, 80 }, { 170, -190, 64 } },
	resti = 18,
	ostacolo = { "ulivo", "roccia" },
}

S["Zama"] = {
	-- La piana africana: palme e ulivi, il campo di Annibale, quello di Scipione dietro.
	flora = { { "palma", 16, 0.9, 1.3 }, { "ulivo", 10, 0.9, 1.2 }, { "tamerice", 16, 0.9, 1.3 }, { "arbusto", 60, 0.8, 1.3 }, { "ciuffo", 120, 0.8, 1.2 }, { "roccia", 18, 0.8, 1.6 }, { "sassi", 50, 0.8, 1.2 } },
	gruppi = {
		{ "padiglione", 8, { -150, 150, 150, 240 }, 0.9, 1.2, ctx = { colori = PUNICI }, verso = "campo" },
		{ "insegna", 3, { -90, 90, 120, 155 }, 1, 1.2, ctx = { drappo = C(120, 36, 100) }, verso = "campo" },
		{ "fuoco", 4, { -150, 150, 150, 240 }, 1, 1 },
		{ "anfore", 5, { -150, 150, 150, 240 }, 0.9, 1.1 },
		{ "carro", 4, { -200, 200, 150, 250 }, 0.9, 1.1 },
	},
	castra = { { 0, -190, 90 } },
	resti = 16,
	ostacolo = { "palma", "roccia", "tamerice" },
}

S["Carthage"] = {
	-- L'assedio della città: le mura di Cartagine sul mare, le case bianche dentro, le torri d'assedio
	-- e il vallo romano davanti, gli incendi.
	colli = { { 0, 225, 90, 12 } },
	mare = { asse = "z", segno = 1, inizio = 245 },
	flora = { { "palma", 18, 0.9, 1.3 }, { "ulivo", 10, 0.9, 1.2 }, { "arbusto", 40, 0.8, 1.3 }, { "ciuffo", 100, 0.8, 1.2 }, { "roccia", 12, 0.8, 1.4 }, { "sassi", 40, 0.8, 1.2 } },
	linee = {
		{ "mura", { -230, 160 }, { 230, 160 }, 64, ctx = { lunghezza = 64, pietra = C(214, 196, 160) } },
		{ "palizzata", { -220, 105 }, { -75, 105 }, 22, ctx = { lunghezza = 22 } },
		{ "palizzata", { 75, 105 }, { 220, 105 }, 22, ctx = { lunghezza = 22 } },
	},
	gruppi = {
		{ "casaBianca", 18, { -230, 230, 180, 240 }, 0.9, 1.3, verso = "campo" },
		{ "fuoco", 8, { -230, 230, 175, 240 }, 1.2, 1.6 },
		{ "torre", 3, { -180, 180, 118, 135 }, 1.0, 1.1, verso = 0 },
		{ "rovina", 2, { -220, 220, 75, 100 }, 0.6, 0.8 },
		{ "anfore", 5, { -220, 220, 70, 140 }, 0.9, 1.1 },
		{ "nave", 3, { -200, 200, 262, 285 }, 0.8, 1.0, verso = 90, galleggia = true },
	},
	castra = { { -160, -170, 80 } },
	resti = 16,
	ostacolo = { "anfore", "roccia", "palma" },
}

S["Aquae Sextiae"] = {
	-- La Provenza sul fiume Arc: pini d'Aleppo, ulivi, lavanda; il cerchio di carri dei Teutoni.
	colli = { { 40, 330, 190, 60 } }, -- la Montagne Sainte-Victoire dietro il nemico
	flora = { { "pino", 22, 0.9, 1.4 }, { "ulivo", 16, 0.9, 1.3 }, { "cipresso", 10, 0.9, 1.3 }, { "quercia", 8, 0.9, 1.3 }, { "cespuglio", 40, 0.8, 1.3 }, { "ciuffo", 100, 0.8, 1.2 }, { "roccia", 20, 0.9, 1.8 }, { "sassi", 40, 0.8, 1.2 } },
	riva = { { "canne", 24, 0.9, 1.3 } },
	gruppi = {
		{ "fiori", 50, { -270, 270, -270, 270 }, 0.9, 1.3, ctx = { colore = C(150, 110, 200) } },
		{ "fuoco", 4, { 90, 170, 150, 230 }, 1, 1 },
	},
	pezzi = cerchioCarri(130, 190, 38, 12),
	castra = { { -160, -170, 80 } },
	resti = 14,
	ostacolo = { "roccia", "ulivo" },
}

S["Gergovia"] = {
	-- L'oppidum degli Arverni sull'altopiano (capanne dietro il murus gallicus), i due campi di Cesare.
	versanti = { { asse = "z", segno = 1, inizio = 110, altezza = 26, largo = 50, mosso = 8 } }, -- l'altopiano
	flora = { { "quercia", 38, 0.9, 1.5 }, { "betulla", 10, 0.9, 1.3 }, { "cespuglio", 50, 0.8, 1.3 }, { "ciuffo", 110, 0.8, 1.2 }, { "roccia", 16, 0.9, 1.6 }, { "sassi", 30, 0.8, 1.2 }, { "fiori", 20, 0.8, 1.1 } },
	linee = {
		{ "muretto", { -170, 165 }, { 170, 165 }, 20, ctx = { lunghezza = 20 } },
		{ "palizzata", { -170, 172 }, { 170, 172 }, 22, ctx = { lunghezza = 22 } },
	},
	gruppi = {
		{ "capanna", 11, { -160, 160, 190, 260 }, 0.9, 1.2, verso = "campo" },
		{ "fuoco", 4, { -160, 160, 190, 260 }, 1, 1 },
		{ "campo", 3, { -260, 260, -260, 0 }, 0.9, 1.1, verso = 0, ctx = { colori = { C(150, 170, 80), C(130, 150, 70) } } },
	},
	castra = { { -160, -170, 80 }, { 175, -60, 56 } },
	resti = 14,
	ostacolo = { "quercia", "roccia" },
}

S["Alesia"] = {
	-- L'oppidum sul Mont Auxois e le due linee di Cesare: circonvallazione con le torri, i campi romani.
	colli = { { 0, 250, 120, 30 } }, -- il Mont Auxois
	flora = { { "quercia", 34, 0.9, 1.5 }, { "betulla", 10, 0.9, 1.3 }, { "cespuglio", 40, 0.8, 1.3 }, { "ciuffo", 110, 0.8, 1.2 }, { "roccia", 14, 0.9, 1.6 }, { "sassi", 30, 0.8, 1.2 } },
	linee = {
		{ "palizzata", { -240, 100 }, { -76, 100 }, 22, ctx = { lunghezza = 22 }, ogni = { "torre", 3 } },
		{ "palizzata", { 76, 100 }, { 240, 100 }, 22, ctx = { lunghezza = 22 }, ogni = { "torre", 3 } },
		{ "palizzata", { -240, -140 }, { -40, -140 }, 22, ctx = { lunghezza = 22 }, ogni = { "torre", 3 } },
		{ "palizzata", { 40, -140 }, { 240, -140 }, 22, ctx = { lunghezza = 22 }, ogni = { "torre", 3 } },
		{ "paliArcieri", { -200, 88 }, { -80, 88 }, 20, ctx = { lunghezza = 20 } },
		{ "paliArcieri", { 80, 88 }, { 200, 88 }, 20, ctx = { lunghezza = 20 } },
		{ "palizzata", { -150, 175 }, { 150, 175 }, 22, ctx = { lunghezza = 22 } },
	},
	gruppi = {
		{ "capanna", 12, { -150, 150, 195, 265 }, 0.9, 1.2, verso = "campo" },
		{ "fuoco", 4, { -150, 150, 195, 265 }, 1, 1 },
	},
	castra = { { -185, -210, 70 }, { 185, -210, 70 } },
	resti = 18,
	ostacolo = { "paliArcieri", "roccia" },
	contestoOstacolo = { lunghezza = 12 },
}

-- Medioevo

S["Hattin"] = {
	-- I Corni di Hattin, la sterpaglia incendiata da Saladino, il villaggio, le due armate accampate.
	colli = { { -170, 215, 45, 26 }, { -95, 240, 45, 22 } }, -- i due Corni
	flora = { { "ulivo", 10, 0.9, 1.2 }, { "arbusto", 70, 0.8, 1.3 }, { "ciuffo", 140, 0.8, 1.2 }, { "roccia", 26, 0.9, 1.8 }, { "sassi", 60, 0.8, 1.3 } },
	pezzi = { { "masso", -170, 215, 0, 1.3 }, { "masso", -95, 240, 40, 1.2 }, { "masso", -150, 228, 70, 0.9 }, { "masso", -110, 228, 20, 0.8 } },
	gruppi = {
		{ "fuoco", 10, { -250, 250, 60, 150 }, 1.0, 1.6 },
		{ "padiglione", 6, { -150, 150, -240, -140 }, 0.9, 1.1, ctx = { colori = CROCIATI }, verso = 0 },
		{ "padiglione", 7, { -40, 200, 160, 240 }, 0.9, 1.2, ctx = { colori = SARACENI }, verso = "campo" },
		{ "insegna", 3, { -60, 120, 130, 160 }, 1, 1.2, ctx = { drappo = C(40, 120, 60) }, verso = "campo" },
		{ "casaBianca", 7, { 140, 240, -60, 60 }, 0.9, 1.2, verso = "campo" },
	},
	resti = 18,
	ostacolo = { "roccia", "arbusto" },
}

S["Manzikert"] = {
	-- L'altopiano armeno: steppa sassosa; il campo bizantino col labaro, quello selgiuchide davanti.
	cornice = { { "roccia", 50, 1.2, 2.2 }, { "masso", 18, 0.9, 1.4 }, { "cespuglio", 40, 1.0, 1.4 } },
	flora = { { "pino", 10, 0.9, 1.3 }, { "cespuglio", 30, 0.8, 1.2 }, { "ciuffo", 160, 0.8, 1.3 }, { "roccia", 36, 1.0, 2.0 }, { "masso", 10, 0.8, 1.3 }, { "sassi", 70, 0.8, 1.4 } },
	contesto = { secco = true },
	gruppi = {
		{ "padiglione", 8, { -150, 150, -250, -150 }, 0.9, 1.2, ctx = { colori = BIZANTINI }, verso = 0 },
		{ "insegna", 3, { -80, 80, -150, -125 }, 1, 1.2, ctx = { drappo = C(150, 30, 40) }, verso = 0 },
		{ "padiglione", 6, { -150, 150, 170, 250 }, 0.9, 1.2, ctx = { colori = SELGIUCHIDI }, verso = "campo" },
		{ "fuoco", 5, { -150, 150, 170, 250 }, 1, 1 },
		{ "carro", 4, { -200, 200, -260, -170 }, 0.9, 1.1 },
	},
	resti = 18,
	ostacolo = { "masso", "roccia" },
}

S["Lake Peipus"] = {
	-- La battaglia sul ghiaccio: il lago gelato, i canneti sulle rive, la chiesa di Novgorod, i Cavalieri
	-- Teutonici accampati sulla riva opposta. Sulle caselle bloccate il ghiaccio è rotto.
	terreno = { ondulazione = 1.5 },
	laghi = { { 0, 0, 170, 185, ghiaccio = true } },
	flora = { { "pino", 70, 1.0, 1.8 }, { "betulla", 26, 0.9, 1.3 }, { "cespuglio", 20, 0.8, 1.2 }, { "sassi", 20, 0.8, 1.2 } },
	gruppi = {
		{ "canne", 30, { -230, 230, -240, 240 }, 0.9, 1.3, riva = true },
		{ "padiglione", 6, { -150, 150, 215, 270 }, 0.9, 1.2, ctx = { colori = TEUTONICI }, verso = "campo" },
		{ "fuoco", 4, { -150, 150, 215, 270 }, 1, 1 },
		{ "casa", 4, { -240, -120, -270, -205 }, 0.8, 1.0, verso = "campo" },
		{ "pagliaio", 4, { -250, -100, -270, -200 }, 0.9, 1.1 },
	},
	pezzi = { { "chiesa", -60, -240, "campo", 0.8 } },
	resti = 16,
	ostacolo = { "ghiaccioRotto" },
	dettagli = { "sassi" },
}

S["Lechfeld"] = {
	-- La piana del Lech presso Augusta: villaggio con i campi, le mura della città dietro, le yurte magiare.
	flora = { { "betulla", 20, 0.9, 1.3 }, { "quercia", 24, 0.9, 1.4 }, { "pino", 10, 0.9, 1.3 }, { "cespuglio", 40, 0.8, 1.3 }, { "ciuffo", 110, 0.8, 1.2 }, { "fiori", 30, 0.8, 1.1 }, { "sassi", 20, 0.8, 1.2 } },
	riva = { { "canne", 24, 0.9, 1.3 } },
	gruppi = {
		{ "campo", 6, { -270, 270, -270, 270 }, 0.9, 1.2, verso = 0 },
		{ "casa", 5, { 120, 250, -200, -90 }, 0.8, 1.0, verso = "campo" },
		{ "pagliaio", 6, { 110, 260, -220, -80 }, 0.9, 1.1 },
		{ "padiglione", 7, { -150, 150, 160, 250 }, 0.9, 1.1, ctx = { colori = MAGIARI }, verso = "campo" },
		{ "fuoco", 4, { -150, 150, 160, 250 }, 1, 1 },
	},
	pezzi = { { "mura", -40, -255, 0, 1.0, ctx = { lunghezza = 120 } } },
	linee = { { "staccionata", { 110, -70 }, { 260, -70 }, 24, ctx = { lunghezza = 24 } } },
	resti = 14,
	ostacolo = { "quercia", "cespuglio" },
}

S["Hastings"] = {
	-- Senlac Hill: il muro di scudi sassone sul crinale, i draghi del Wessex, il vecchio melo;
	-- il campo normanno dietro di te.
	versanti = { { asse = "z", segno = 1, inizio = 70, altezza = 10, largo = 50, mosso = 6 } }, -- Senlac Hill
	flora = { { "quercia", 32, 0.9, 1.5 }, { "cespuglio", 50, 0.8, 1.3 }, { "ciuffo", 110, 0.8, 1.2 }, { "fiori", 24, 0.8, 1.1 }, { "roccia", 10, 0.8, 1.4 }, { "sassi", 24, 0.8, 1.2 } },
	linee = {
		{ "muroScudi", { -150, 84 }, { -60, 84 }, 18, ctx = { lunghezza = 18 } },
		{ "muroScudi", { -60, 90 }, { 60, 90 }, 18, ctx = { lunghezza = 18 } },
		{ "muroScudi", { 60, 84 }, { 150, 84 }, 18, ctx = { lunghezza = 18 } },
		{ "siepe", { -260, -110 }, { -90, -110 }, 34, ctx = { lunghezza = 34 } },
		{ "siepe", { 90, 150 }, { 260, 150 }, 34, ctx = { lunghezza = 34 } },
	},
	gruppi = {
		{ "insegna", 2, { -40, 40, 112, 130 }, 1.1, 1.3, ctx = { drappo = C(200, 160, 40) }, verso = "campo" },
		{ "padiglione", 6, { -150, 150, -250, -150 }, 0.9, 1.1, ctx = { colori = NORMANNI }, verso = 0 },
		{ "fuoco", 3, { -150, 150, -250, -150 }, 1, 1 },
		{ "campo", 3, { -260, 260, 160, 270 }, 0.9, 1.1, verso = 0, ctx = { colori = { C(150, 170, 80), C(130, 150, 70) } } },
	},
	pezzi = { { "meloSidro", -120, 140, nil, 1.3 } },
	resti = 18,
	ostacolo = { "quercia", "roccia" },
}

S["Stamford Bridge"] = {
	-- Il ponte di legno sul Derwent, il campo vichingo sull'altra riva, il villaggio.
	flora = { { "quercia", 30, 0.9, 1.4 }, { "betulla", 12, 0.9, 1.3 }, { "cespuglio", 50, 0.8, 1.3 }, { "ciuffo", 110, 0.8, 1.2 }, { "fiori", 30, 0.8, 1.1 }, { "sassi", 20, 0.8, 1.2 } },
	riva = { { "canne", 30, 0.9, 1.3 } },
	ponti = { { "ponte", -100 }, { "ponte", 150 } },
	gruppi = {
		{ "tendaRomana", 7, { -150, 150, 160, 250 }, 0.9, 1.1, verso = "campo" },
		{ "fuoco", 4, { -150, 150, 160, 250 }, 1, 1 },
		{ "casa", 4, { 120, 250, -230, -120 }, 0.8, 1.0, verso = "campo" },
		{ "pagliaio", 3, { 110, 250, -240, -110 }, 0.9, 1.1 },
	},
	linee = { { "staccionata", { 110, -100 }, { 250, -100 }, 24, ctx = { lunghezza = 24 } } },
	resti = 14,
	ostacolo = { "quercia", "cespuglio" },
}

S["Crecy"] = {
	-- Il mulino sul crinale da cui guardava Edoardo III, i pali degli arcieri inglesi, il cerchio di carri;
	-- i pavesi dei balestrieri genovesi dalla tua parte, il villaggio e la foresta di Crécy.
	colli = { { 70, 165, 75, 12 } }, -- il crinale del mulino
	flora = { { "quercia", 26, 0.9, 1.4 }, { "betulla", 8, 0.9, 1.3 }, { "cespuglio", 40, 0.8, 1.3 }, { "ciuffo", 110, 0.8, 1.2 }, { "fiori", 30, 0.8, 1.1 }, { "sassi", 20, 0.8, 1.2 } },
	linee = {
		{ "paliArcieri", { -160, 80 }, { -70, 80 }, 18, ctx = { lunghezza = 18 } },
		{ "paliArcieri", { 70, 80 }, { 160, 80 }, 18, ctx = { lunghezza = 18 } },
		{ "pavesi", { -170, -84 }, { -80, -84 }, 18, ctx = { colori = GENOVESI } },
		{ "pavesi", { 80, -84 }, { 170, -84 }, 18, ctx = { colori = GENOVESI } },
	},
	gruppi = {
		{ "insegna", 3, { -60, 60, 120, 140 }, 1, 1.2, ctx = { drappo = C(200, 40, 40) }, verso = "campo" },
		{ "casa", 5, { -250, -140, 150, 260 }, 0.8, 1.0, verso = "campo" },
		{ "pagliaio", 6, { -260, 260, -260, 260 }, 0.9, 1.1 },
		{ "campo", 5, { -270, 270, -270, 270 }, 0.9, 1.2, verso = 0 },
		{ "quercia", 24, { 170, 280, -280, 280 }, 1.0, 1.5 },
	},
	pezzi = unisci({ { "mulino", 70, 160, "campo", 1.0 }, { "chiesa", -200, 230, "campo", 0.8 } }, cerchioCarri(0, 215, 34, 9, math.pi * 1.2)),
	resti = 18,
	ostacolo = { "pagliaio", "quercia" },
}

S["Roncevaux Pass"] = {
	-- La gola dei Pirenei: pareti di roccia, faggi e abeti, la cappella sul colle, la retroguardia coi carri.
	versanti = { { asse = "x", segno = 1, inizio = 95, altezza = 50, largo = 80 }, { asse = "x", segno = -1, inizio = 95, altezza = 50, largo = 80 } },
	terreno = { ondulazione = 12, bordo = 90 },
	flora = { { "pino", 50, 1.0, 1.7 }, { "quercia", 14, 0.9, 1.4 }, { "cespuglio", 30, 0.8, 1.2 }, { "ciuffo", 80, 0.8, 1.2 }, { "roccia", 30, 1.0, 2.2 }, { "sassi", 60, 0.8, 1.4 } },
	gruppi = {
		{ "masso", 24, { -280, 280, -280, 280 }, 0.9, 1.6 },
		{ "carro", 6, { -60, 60, -260, -150 }, 0.9, 1.1, verso = 0 },
		{ "fuoco", 2, { -60, 60, -260, -150 }, 1, 1 },
	},
	pezzi = { { "chiesa", -120, 215, "campo", 0.6 } },
	resti = 18,
	ostacolo = { "masso", "roccia" },
}

S["Tours"] = {
	-- Il campo omayyade col bottino sui carri; dalla tua parte i boschi dei Franchi.
	flora = { { "quercia", 26, 0.9, 1.5 }, { "betulla", 10, 0.9, 1.3 }, { "cespuglio", 40, 0.8, 1.3 }, { "ciuffo", 110, 0.8, 1.2 }, { "fiori", 24, 0.8, 1.1 }, { "sassi", 20, 0.8, 1.2 } },
	riva = { { "canne", 24, 0.9, 1.3 } },
	gruppi = {
		{ "quercia", 40, { -280, 280, -280, -110 }, 1.0, 1.6 },
		{ "padiglione", 8, { -160, 160, 160, 250 }, 0.9, 1.2, ctx = { colori = OMAYYADI }, verso = "campo" },
		{ "carro", 6, { -160, 160, 150, 260 }, 0.9, 1.1 },
		{ "insegna", 2, { -60, 60, 125, 150 }, 1, 1.2, ctx = { drappo = C(30, 110, 70) }, verso = "campo" },
		{ "fuoco", 4, { -160, 160, 160, 250 }, 1, 1 },
		{ "campo", 3, { -260, 260, 0, 270 }, 0.9, 1.1, verso = 0 },
	},
	resti = 16,
	ostacolo = { "quercia", "cespuglio" },
}

S["Orleans"] = {
	-- Le mura di Orléans oltre la Loira, la cattedrale, il ponte con le Tourelles; le bastie inglesi.
	flora = { { "quercia", 16, 0.9, 1.4 }, { "betulla", 10, 0.9, 1.3 }, { "cespuglio", 40, 0.8, 1.3 }, { "ciuffo", 110, 0.8, 1.2 }, { "fiori", 24, 0.8, 1.1 }, { "sassi", 20, 0.8, 1.2 } },
	riva = { { "canne", 24, 0.9, 1.3 } },
	ponti = { { "pontePietra", 110 } },
	linee = {
		{ "mura", { -240, 205 }, { 240, 205 }, 80, ctx = { lunghezza = 80 } },
	},
	gruppi = {
		{ "casa", 8, { -230, 230, 225, 275 }, 0.8, 1.0, verso = "campo" },
		{ "pagliaio", 4, { -260, 260, -260, 0 }, 0.9, 1.1 },
		{ "fuoco", 3, { -200, 200, -200, -120 }, 1, 1 },
	},
	pezzi = { { "chiesa", 30, 255, "campo", 1.2 }, { "torre", 110, -45, 0, 1.0 } },
	bastie = { { -160, -150, 40 }, { 170, -170, 40 }, { -200, 60, 36 } },
	resti = 16,
	ostacolo = { "botti", "cespuglio" },
}

-- Novecento

S["Gallipoli"] = {
	-- La baia di Anzac dietro di te, le colline di macchia con le trincee turche, i crateri.
	cornice = { { "pino", 36, 1.0, 1.5 }, { "arbusto", 60, 1.0, 1.5 }, { "cespuglio", 50, 1.0, 1.5 } },
	versanti = { { asse = "z", segno = 1, inizio = 100, altezza = 34, largo = 110, mosso = 10 } }, -- le creste sopra la baia
	terreno = { ondulazione = 10 },
	mare = { asse = "z", segno = -1, inizio = 185 },
	flora = { { "arbusto", 50, 0.8, 1.3 }, { "cespuglio", 40, 0.8, 1.3 }, { "pino", 14, 0.9, 1.3 }, { "ciuffo", 100, 0.8, 1.2 }, { "roccia", 24, 0.9, 1.8 }, { "sassi", 40, 0.8, 1.2 } },
	contesto = { secco = true },
	trincee = { { { -200, 92 }, { -60, 92 } }, { { 60, 92 }, { 200, 92 } }, { { -150, 160 }, { 150, 160 } } },
	crateri = { 20, { -250, 250, -150, 250 }, 6, 10 },
	linee = {
		{ "filoSpinato", { -190, 76 }, { -60, 76 }, 22, ctx = { lunghezza = 22 } },
		{ "filoSpinato", { 60, 76 }, { 190, 76 }, 22, ctx = { lunghezza = 22 } },
	},
	gruppi = {
		{ "barca", 6, { -200, 200, -215, -190 }, 0.9, 1.1, verso = 180 },
		{ "casse", 6, { -200, 200, -190, -100 }, 0.9, 1.1 },
		{ "cannone", 2, { -150, 150, 180, 230 }, 1, 1, verso = "campo" },
		{ "sacchetti", 6, { -200, 200, 110, 140 }, 1, 1, verso = 0, ctx = { lunghezza = 14 } },
	},
	resti = 20,
	ostacolo = { "sacchetti", "filoSpinato" },
	contestoOstacolo = { lunghezza = 12 },
}

S["Tannenberg"] = {
	-- La Prussia orientale: boschi di betulle e abeti, i laghi masuri, le fattorie; carri russi abbandonati.
	laghi = { { -195, 140, 70, 52 }, { 210, -170, 60, 46 } },
	flora = { { "pino", 40, 1.0, 1.6 }, { "betulla", 30, 0.9, 1.3 }, { "cespuglio", 40, 0.8, 1.3 }, { "ciuffo", 100, 0.8, 1.2 }, { "fiori", 20, 0.8, 1.1 }, { "sassi", 24, 0.8, 1.2 } },
	gruppi = {
		{ "canne", 30, { -280, 280, -280, 280 }, 0.9, 1.3, riva = true },
		{ "casa", 4, { 120, 250, 60, 180 }, 0.8, 1.0, verso = "campo" },
		{ "pagliaio", 4, { 110, 260, 50, 190 }, 0.9, 1.1 },
		{ "carro", 5, { -200, 200, 100, 250 }, 0.9, 1.1 },
		{ "cannone", 3, { -150, 150, -200, -120 }, 1, 1, verso = 0 },
		{ "campo", 3, { -260, 260, -260, 260 }, 0.9, 1.1, verso = 0, ctx = { colori = { C(150, 170, 80), C(130, 150, 70) } } },
	},
	linee = { { "palo", { -260, -105 }, { 260, -105 }, 40 } },
	trincee = { { { -160, 110 }, { 160, 110 } } },
	crateri = { 8, { -250, 250, -100, 250 }, 6, 9 },
	resti = 16,
	ostacolo = { "pino", "cespuglio" },
}

S["Verdun"] = {
	-- Il paesaggio lunare: crateri ovunque, fango, alberi spezzati, le trincee e i reticolati, le rovine di
	-- Fleury, il forte di Douaumont in alto.
	cornice = { { "alberoSpezzato", 80, 1.0, 1.8 }, { "ceppo", 40, 1.0, 1.6 } },
	colli = { { 0, 270, 110, 20 } }, -- Douaumont
	terreno = { campo = M.Mud, chiazze = M.Ground, base = M.Mud, alto = M.Ground, sponda = M.Mud },
	flora = { { "alberoSpezzato", 50, 0.8, 1.4 }, { "ciuffo", 30, 0.8, 1.1 }, { "sassi", 40, 0.8, 1.3 } },
	contesto = { secco = true },
	crateri = { 46, { -280, 280, -280, 280 }, 6, 12 },
	trincee = { { { -220, 95 }, { -70, 95 } }, { { 70, 95 }, { 220, 95 } }, { { -220, -100 }, { -40, -100 } }, { { 40, -100 }, { 220, -100 } } },
	linee = {
		{ "filoSpinato", { -220, 80 }, { -70, 80 }, 22, ctx = { lunghezza = 22 } },
		{ "filoSpinato", { 70, 80 }, { 220, 80 }, 22, ctx = { lunghezza = 22 } },
		{ "filoSpinato", { -220, -84 }, { -40, -84 }, 22, ctx = { lunghezza = 22 } },
		{ "filoSpinato", { 40, -84 }, { 220, -84 }, 22, ctx = { lunghezza = 22 } },
	},
	gruppi = {
		{ "casaDiroccata", 5, { -260, 260, -60, 60 }, 0.8, 1.0, verso = "campo" },
		{ "cannone", 3, { -200, 200, 140, 230 }, 1, 1, verso = "campo" },
		{ "casse", 4, { -200, 200, -200, -120 }, 0.9, 1.1 },
	},
	pezzi = { { "forte", 0, 262, "campo", 1.0 } },
	resti = 24,
	ostacolo = { "filoSpinato", "alberoSpezzato" },
	contestoOstacolo = { lunghezza = 12 },
}

S["The Marne"] = {
	-- La campagna della Marna a settembre: grano mietuto, pagliai, pioppi sul fiume, la batteria da 75 e i
	-- taxi di Parigi in colonna sulla strada.
	flora = { { "quercia", 16, 0.9, 1.4 }, { "betulla", 10, 0.9, 1.3 }, { "cespuglio", 40, 0.8, 1.3 }, { "ciuffo", 110, 0.8, 1.2 }, { "fiori", 40, 0.8, 1.1, ctx = { colore = C(200, 40, 40) } }, { "sassi", 20, 0.8, 1.2 } },
	riva = { { "cipresso", 16, 0.8, 1.1 }, { "canne", 16, 0.9, 1.3 } },
	linee = {
		{ "taxi", { -230, -165 }, { 230, -165 }, 26 },
		{ "palo", { -260, -180 }, { 260, -180 }, 40 },
	},
	gruppi = {
		{ "campo", 8, { -270, 270, -270, 270 }, 0.9, 1.2, verso = 0 },
		{ "pagliaio", 10, { -270, 270, -270, 270 }, 0.9, 1.1 },
		{ "casa", 5, { 140, 260, 60, 220 }, 0.8, 1.0, verso = "campo" },
		{ "cannone", 4, { -150, 150, -135, -100 }, 1, 1, verso = 0 },
		{ "casse", 3, { -150, 150, -140, -100 }, 0.9, 1.1 },
	},
	pezzi = { { "chiesa", 200, 240, "campo", 0.8 } },
	trincee = { { { -180, 120 }, { 180, 120 } } },
	resti = 16,
	ostacolo = { "pagliaio", "cespuglio" },
}

S["Amiens"] = {
	-- Agosto 1918: i carri armati, le trincee e i reticolati tra i campi di grano, le fattorie in rovina.
	flora = { { "quercia", 14, 0.9, 1.3 }, { "alberoSpezzato", 16, 0.8, 1.3 }, { "cespuglio", 30, 0.8, 1.2 }, { "ciuffo", 110, 0.8, 1.2 }, { "fiori", 30, 0.8, 1.1, ctx = { colore = C(200, 40, 40) } }, { "sassi", 20, 0.8, 1.2 } },
	trincee = { { { -220, 105 }, { -60, 105 } }, { { 60, 105 }, { 220, 105 } }, { { -200, -115 }, { 200, -115 } } },
	crateri = { 20, { -260, 260, -200, 260 }, 6, 10 },
	linee = {
		{ "filoSpinato", { -200, 86 }, { -60, 86 }, 22, ctx = { lunghezza = 22 } },
		{ "filoSpinato", { 60, 86 }, { 200, 86 }, 22, ctx = { lunghezza = 22 } },
		{ "palo", { -260, 200 }, { 260, 200 }, 40 },
	},
	gruppi = {
		{ "campo", 6, { -270, 270, -270, 270 }, 0.9, 1.2, verso = 0 },
		{ "relitto", 4, { -230, 230, -60, 180 }, 0.9, 1.0, ctx = { colore = C(96, 90, 64) } },
		{ "casaDiroccata", 3, { -250, 250, 130, 250 }, 0.8, 1.0, verso = "campo" },
		{ "cannone", 3, { -150, 150, -200, -140 }, 1, 1, verso = 0 },
	},
	resti = 20,
	ostacolo = { "filoSpinato", "sacchetti" },
	contestoOstacolo = { lunghezza = 12 },
}

S["El Alamein"] = {
	-- Il deserto roccioso sulla costa: campi minati coi cartelli, relitti di carri, le postazioni di sacchetti,
	-- la strada costiera coi pali del telegrafo.
	colli = { { 120, 230, 90, 8 } }, -- la cresta di Ruweisat
	mare = { asse = "x", segno = -1, inizio = 205 },
	flora = { { "arbusto", 50, 0.8, 1.3 }, { "ciuffo", 70, 0.8, 1.2 }, { "roccia", 30, 0.8, 1.8 }, { "masso", 4, 0.6, 1.0 }, { "sassi", 70, 0.8, 1.3 } },
	linee = {
		{ "palo", { -175, -260 }, { -175, 260 }, 40 },
		{ "cartello", { -160, 110 }, { 160, 110 }, 14 },
		{ "filoSpinato", { -170, 120 }, { -60, 120 }, 22, ctx = { lunghezza = 22 } },
		{ "filoSpinato", { 60, 120 }, { 170, 120 }, 22, ctx = { lunghezza = 22 } },
	},
	gruppi = {
		{ "relitto", 6, { -160, 250, -200, 250 }, 0.9, 1.0, ctx = { colore = C(176, 150, 104) } },
		{ "cannone", 3, { -120, 200, 150, 230 }, 1, 1, verso = "campo", ctx = { colore = C(176, 156, 112) } },
		{ "sacchetti", 6, { -150, 200, 130, 170 }, 1, 1, verso = 0, ctx = { lunghezza = 14 } },
		{ "casse", 6, { -150, 200, -220, -120 }, 0.9, 1.1 },
		{ "tendaRomana", 4, { -120, 120, -250, -170 }, 0.9, 1.0, verso = 0 },
	},
	crateri = { 10, { -150, 250, -200, 250 }, 5, 8 },
	resti = 18,
	ostacolo = { "sacchetti", "roccia" },
	contestoOstacolo = { lunghezza = 12 },
}

S["Stalingrad"] = {
	-- Le rovine sotto la neve: la fabbrica Ottobre Rosso, i palazzi sventrati, le barricate, i crateri.
	cornice = { { "palazzoDiroccato", 26, 0.9, 1.2 }, { "casaDiroccata", 16, 0.9, 1.2 } },
	colli = { { -210, 230, 70, 18 } }, -- il Mamayev Kurgan
	terreno = { chiazze = M.Ground },
	flora = { { "alberoSpezzato", 14, 0.8, 1.2 }, { "sassi", 30, 0.8, 1.3 } },
	crateri = { 26, { -270, 270, -270, 270 }, 6, 10 },
	gruppi = {
		{ "fabbrica", 3, { -240, 240, 150, 250 }, 0.9, 1.1, verso = "campo" },
		{ "palazzoDiroccato", 10, { -230, 230, 90, 200 }, 0.9, 1.1, verso = "campo" },
		{ "palazzoDiroccato", 6, { -230, 230, -200, -95 }, 0.9, 1.1, verso = "campo" },
		{ "casaDiroccata", 12, { -270, 270, -270, 270 }, 0.8, 1.1, verso = "campo" },
		{ "barricata", 5, { -200, 200, -150, 150 }, 0.9, 1.0, verso = "campo" },
		{ "relitto", 4, { -230, 230, -200, 230 }, 0.9, 1.0, ctx = { colore = C(92, 96, 98) } },
		{ "palo", 6, { -260, 260, -260, 260 }, 1, 1 },
		{ "casse", 4, { -200, 200, -220, -120 }, 0.9, 1.1 },
	},
	resti = 22,
	ostacolo = { "barricata", "casse" },
	contestoOstacolo = {},
}

S["Monte Cassino"] = {
	-- L'abbazia distrutta in cima al monte, la città di Cassino in rovina ai piedi, gli uliveti bombardati.
	versanti = { { asse = "z", segno = 1, inizio = 120, altezza = 40, largo = 140, mosso = 12 } },
	terreno = { ondulazione = 12, bordo = 30 },
	flora = { { "ulivo", 26, 0.9, 1.3 }, { "cipresso", 10, 0.9, 1.3 }, { "alberoSpezzato", 18, 0.8, 1.3 }, { "cespuglio", 30, 0.8, 1.2 }, { "ciuffo", 80, 0.8, 1.2 }, { "roccia", 30, 1.0, 2.0 }, { "masso", 8, 0.8, 1.3 }, { "sassi", 50, 0.8, 1.3 } },
	crateri = { 30, { -270, 270, -230, 230 }, 6, 10 },
	gruppi = {
		{ "casaDiroccata", 8, { -240, -70, 110, 210 }, 0.8, 1.0, verso = "campo" },
		{ "sacchetti", 6, { -200, 200, 95, 140 }, 1, 1, verso = 0, ctx = { lunghezza = 14 } },
		{ "cannone", 2, { -150, 150, -200, -140 }, 1, 1, verso = 0 },
	},
	pezzi = { { "abbazia", 40, 262, "campo", 0.8 } },
	resti = 20,
	ostacolo = { "masso", "sacchetti" },
	contestoOstacolo = { lunghezza = 12 },
}

S["Normandy"] = {
	-- Il bocage: siepi su argini che chiudono i campi, meleti, fattorie di pietra, carri armati colpiti.
	flora = { { "quercia", 20, 0.9, 1.4 }, { "cespuglio", 40, 0.8, 1.3 }, { "ciuffo", 110, 0.8, 1.2 }, { "fiori", 30, 0.8, 1.1 }, { "sassi", 16, 0.8, 1.2 } },
	linee = {
		{ "siepe", { -270, 105 }, { -75, 105 }, 38, ctx = { lunghezza = 38 } },
		{ "siepe", { 75, 105 }, { 270, 105 }, 38, ctx = { lunghezza = 38 } },
		{ "siepe", { -270, -110 }, { -75, -110 }, 38, ctx = { lunghezza = 38 } },
		{ "siepe", { 75, -110 }, { 270, -110 }, 38, ctx = { lunghezza = 38 } },
		{ "siepe", { -100, -270 }, { -100, -125 }, 38, ctx = { lunghezza = 38 } },
		{ "siepe", { 100, 125 }, { 100, 270 }, 38, ctx = { lunghezza = 38 } },
		{ "siepe", { -100, 125 }, { -100, 270 }, 38, ctx = { lunghezza = 38 } },
	},
	gruppi = {
		{ "meloSidro", 28, { -270, 270, -270, 270 }, 0.9, 1.2 },
		{ "casa", 4, { 130, 260, -250, -130 }, 0.8, 1.0, verso = "campo", ctx = {} },
		{ "relitto", 3, { -230, 230, -100, 220 }, 0.9, 1.0, ctx = { colore = C(84, 90, 64) } },
		{ "campo", 3, { -270, 270, -270, 270 }, 0.9, 1.1, verso = 0, ctx = { colori = { C(150, 170, 80), C(130, 150, 70) } } },
		{ "palo", 10, { 110, 270, 120, 270 }, 0.5, 0.6 },
	},
	pezzi = { { "chiesa", -190, 230, "campo", 0.8 } },
	crateri = { 10, { -260, 260, -250, 250 }, 5, 8 },
	resti = 18,
	ostacolo = { "siepe", "meloSidro" },
	contestoOstacolo = { lunghezza = 13 },
}

S["Paris"] = {
	-- Agosto 1944 sul Campo di Marte: la Tour Eiffel in fondo, i palazzi di Haussmann attorno, i ponti
	-- sulla Senna, le barricate, i platani, i lampioni.
	cornice = { { "palazzo", 26, 0.9, 1.1 }, { "quercia", 30, 1.0, 1.4 } },
	terreno = { chiazze = M.Pavement, alto = M.Pavement },
	flora = { { "quercia", 20, 0.9, 1.3 }, { "cespuglio", 30, 0.8, 1.2 }, { "ciuffo", 60, 0.8, 1.1 }, { "fiori", 30, 0.8, 1.1 } },
	ponti = { { "pontePietra", -110 }, { "pontePietra", 120 } },
	linee = {
		{ "palazzo", { -250, 150 }, { -110, 150 }, 34 },
		{ "palazzo", { 110, 150 }, { 250, 150 }, 34 },
		{ "palazzo", { -250, -200 }, { -60, -200 }, 34 },
		{ "palazzo", { 60, -200 }, { 250, -200 }, 34 },
		{ "lampione", { -230, -170 }, { 230, -170 }, 26 },
		{ "lampione", { -230, 120 }, { 230, 120 }, 26 },
	},
	gruppi = {
		{ "palazzo", 6, { -270, -140, -150, 110 }, 0.9, 1.1, verso = 90 },
		{ "palazzo", 6, { 140, 270, -150, 110 }, 0.9, 1.1, verso = -90 },
		{ "barricata", 6, { -220, 220, -150, 120 }, 0.9, 1.0, verso = "campo" },
		{ "relitto", 3, { -200, 200, -140, 110 }, 0.9, 1.0, ctx = { colore = C(84, 88, 76) } },
		{ "sacchetti", 4, { -200, 200, 80, 120 }, 1, 1, verso = 0, ctx = { lunghezza = 14 } },
	},
	pezzi = { { "torreEiffel", 0, 255, 0, 1.3 } },
	resti = 14,
	ostacolo = { "barricata", "sacchetti" },
	contestoOstacolo = { lunghezza = 12 },
}

-- Dati per il terreno (Arena) --------------------------------------------------------------------------

function Scenari.dati(nome)
	return S[nome] or {}
end

-- Piano di un campo -----------------------------------------------------------------------------------

-- ambiente = {
--   terra(x, z) -> Vector3 a terra (assoluto), acquaY -> quota assoluta del pelo dell'acqua,
--   fiumeZ(x) -> z della mezzeria del fiume o nil, inAcqua(x, z, margine) -> bool (acqua o ghiaccio),
--   liquida(x, z, margine) -> bool (solo acqua vera),
--   bioma, epoca (id dell'epoca: "Antica", "Medievale", "Novecento"), seme }
function Scenari.prepara(nome, ambiente)
	local scenario = S[nome] or {}
	local piano = {
		scenario = scenario,
		ambiente = ambiente,
		rng = Random.new(ambiente.seme),
		occupati = {},
		crateri = {},
		trincee = {},
	}
	local ctx = {}
	for k, v in pairs(CONTESTO_BIOMA[ambiente.bioma] or {}) do
		ctx[k] = v
	end
	for k, v in pairs(scenario.contesto or {}) do
		ctx[k] = v
	end
	ctx.epoca = ambiente.epoca
	piano.ctx = ctx
	return setmetatable(piano, { __index = Scenari })
end

local function contesto(piano, extra)
	local c = {}
	for k, v in pairs(piano.ctx) do
		c[k] = v
	end
	for k, v in pairs(extra or {}) do
		c[k] = v
	end
	return c
end

-- La cornice del campo e il corridoio dietro al giocatore (da dove arriva e guarda).
local function protetto(x, z, r)
	if math.max(math.abs(x), math.abs(z)) < PROTETTO + r then
		return true
	end
	return math.abs(x) < 24 + r and z < -40 and z > -125 - r
end

local function fuoriValle(x, z, r)
	return math.max(math.abs(x), math.abs(z)) > BORDO - r
end

function Scenari:libero(x, z, r, opzioni)
	opzioni = opzioni or {}
	if fuoriValle(x, z, r) or (not opzioni.nelCampo and protetto(x, z, r)) then
		return false
	end
	if opzioni.fascia and math.max(math.abs(x), math.abs(z)) < opzioni.fascia then
		return false
	end
	-- Prima gli ingombri (veloce, a celle), poi l'acqua (che misura il terreno).
	if not opzioni.sovrapponi then
		local visti = {}
		for i = math.floor((x - r) / CELLA), math.floor((x + r) / CELLA) do
			for k = math.floor((z - r) / CELLA), math.floor((z + r) / CELLA) do
				for _, o in ipairs(self.occupati[i * 4096 + k] or {}) do
					if not visti[o] then
						visti[o] = true
						if (o.x - x) ^ 2 + (o.z - z) ^ 2 < (o.r + r) ^ 2 then
							return false
						end
					end
				end
			end
		end
	end
	local acqua = opzioni.suGhiaccio and self.ambiente.liquida or self.ambiente.inAcqua
	if not opzioni.galleggia and acqua(x, z, r) then
		return false
	end
	if opzioni.galleggia and not self.ambiente.inAcqua(x, z, -r * 0.5) then
		return false
	end
	return true
end

-- Gli ingombri stanno in una griglia a celle: ognuno in tutte le celle che il suo cerchio tocca.
function Scenari:occupa(x, z, r)
	local o = { x = x, z = z, r = r }
	for i = math.floor((x - r) / CELLA), math.floor((x + r) / CELLA) do
		for k = math.floor((z - r) / CELLA), math.floor((z + r) / CELLA) do
			local chiave = i * 4096 + k
			local cella = self.occupati[chiave]
			if not cella then
				cella = {}
				self.occupati[chiave] = cella
			end
			table.insert(cella, o)
		end
	end
end

-- Mette un oggetto: verso "campo" (guarda il centro), un numero (gradi) o nil (a caso).
function Scenari:metti(g, nome, x, z, s, verso, extra, opzioni)
	local fn = P[nome]
	if not fn then
		warn("Scenari: oggetto sconosciuto " .. tostring(nome))
		return
	end
	local base = self.ambiente.terra(x, z)
	if opzioni and opzioni.galleggia then
		base = Vector3.new(base.X, self.ambiente.acquaY - 0.4, base.Z)
	end
	local cf
	if verso == "campo" then
		local verso2 = Vector3.new(-x, 0, -z)
		cf = verso2.Magnitude > 1 and CFrame.lookAt(base, base + verso2) or CFrame.new(base)
		cf = cf * CFrame.Angles(0, self.rng:NextNumber(-0.25, 0.25), 0)
	elseif type(verso) == "number" then
		cf = CFrame.new(base) * CFrame.Angles(0, math.rad(verso), 0)
	else
		cf = CFrame.new(base) * CFrame.Angles(0, self.rng:NextNumber(0, 2 * math.pi), 0)
	end
	local ok, errore = pcall(fn, g, cf, self.rng, s, contesto(self, extra))
	if not ok then
		warn("Scenari: " .. nome .. " - " .. tostring(errore))
	end
end

-- Cerca un posto libero nella zona e ci mette l'oggetto.
function Scenari:spargi(g, nome, n, zona, smin, smax, extra, verso, opzioni)
	local raggio = Paesaggio.ingombro[nome] or 3
	local messi = 0
	for _ = 1, n * 12 do
		if messi >= n then
			break
		end
		local x = self.rng:NextNumber(zona[1], zona[2])
		local z = self.rng:NextNumber(zona[3], zona[4])
		local s = self.rng:NextNumber(smin, smax)
		local ok = self:libero(x, z, raggio * s, opzioni)
		if ok and opzioni and opzioni.riva then
			ok = self.ambiente.inAcqua(x, z, raggio * s + 12) and not self.ambiente.inAcqua(x, z, 0)
		end
		if ok then
			self:occupa(x, z, raggio * s * (opzioni and opzioni.sovrapponi and 0.3 or 1))
			self:metti(g, nome, x, z, s, verso, extra, opzioni)
			messi += 1
		end
	end
end

-- Macchie: n oggetti a gruppetti attorno a centri a caso nella zona (boschetti, cespugli, sassaie),
-- che in natura stanno insieme e non sparsi uno per uno.
function Scenari:macchie(g, nome, n, zona, smin, smax, extra, opzioni)
	local raggio = Paesaggio.ingombro[nome] or 3
	local piccolo = raggio < 2
	local largo = piccolo and 9 or raggio * 4.5
	local messi = 0
	for _ = 1, n * 4 do
		if messi >= n then
			break
		end
		local cx = self.rng:NextNumber(zona[1], zona[2])
		local cz = self.rng:NextNumber(zona[3], zona[4])
		local quanti = self.rng:NextInteger(piccolo and 4 or 2, piccolo and 9 or 7)
		for _ = 1, quanti * 2 do
			if quanti <= 0 or messi >= n then
				break
			end
			-- Più fitti al centro della macchia.
			local d = largo * math.sqrt(self.rng:NextNumber()) * self.rng:NextNumber(0.4, 1)
			local a = self.rng:NextNumber(0, 2 * math.pi)
			local x, z = cx + math.cos(a) * d, cz + math.sin(a) * d
			local s = self.rng:NextNumber(smin, smax)
			if self:libero(x, z, raggio * s * (piccolo and 0.5 or 0.8), opzioni) then
				self:occupa(x, z, raggio * s * (piccolo and 0.3 or 0.8))
				self:metti(g, nome, x, z, s, nil, extra, opzioni)
				messi += 1
				quanti -= 1
			end
		end
	end
end

-- Tende in file ordinate dentro la zona, rivolte al campo, con un corridoio in mezzo.
function Scenari:fila(g, nome, n, zona, smin, smax, extra, verso)
	local raggio = (Paesaggio.ingombro[nome] or 3) * (smin + smax) / 2
	local passo = raggio * 2.3
	-- Un blocco quasi quadrato (due file in profondità per ogni tre di fronte), al centro della zona.
	local colonne = math.clamp(math.ceil(math.sqrt(n * 1.6)), 1, math.max(1, math.floor((zona[2] - zona[1]) / passo)))
	local righe = math.max(1, math.ceil(n / colonne))
	local dz = math.min(passo * 1.15, (zona[4] - zona[3]) / righe)
	local cx = (zona[1] + zona[2]) / 2
	local messi = 0
	for r = 0, righe - 1 do
		for c = 0, colonne - 1 do
			if messi >= n then
				return
			end
			-- La via principale in mezzo al blocco resta libera.
			local x = cx + (c - (colonne - 1) / 2) * passo + (c >= colonne / 2 and passo * 0.4 or -passo * 0.4) + self.rng:NextNumber(-1.2, 1.2)
			local z = zona[3] + (r + 0.5) * dz + self.rng:NextNumber(-1.2, 1.2)
			if self:libero(x, z, raggio * 0.9) then
				self:occupa(x, z, raggio)
				self:metti(g, nome, x, z, self.rng:NextNumber(smin, smax), verso or "campo", extra)
				messi += 1
			end
		end
	end
end

-- Oggetti lunghi (palizzate, siepi, mura) uno dopo l'altro lungo un segmento, orientati lungo di esso.
function Scenari:linea(g, voce)
	local nome, da, a, passo = voce[1], voce[2], voce[3], voce[4]
	local fn = P[nome]
	if not fn then
		warn("Scenari: oggetto sconosciuto " .. tostring(nome))
		return
	end
	local d = Vector3.new(a[1] - da[1], 0, a[2] - da[2])
	local n = math.max(1, math.floor(d.Magnitude / passo + 0.5))
	local dir = d.Unit
	for k = 0, n - 1 do
		local f = (k + 0.5) / n
		local x, z = da[1] + d.X * f, da[2] + d.Z * f
		if not protetto(x, z, 2) and not fuoriValle(x, z, 0) and not self.ambiente.inAcqua(x, z, 3) then
			local base = self.ambiente.terra(x, z)
			local cf = CFrame.fromMatrix(base, dir, Vector3.yAxis)
			local ok, errore = pcall(fn, g, cf, self.rng, 1, contesto(self, voce.ctx))
			if not ok then
				warn("Scenari: " .. nome .. " - " .. tostring(errore))
			end
			self:occupa(x, z, passo / 2)
			if voce.ogni and k % voce.ogni[2] == 0 then
				self:metti(g, voce.ogni[1], x - dir.Z * 4, z + dir.X * 4, voce.ogni[3] or 0.8, 0)
			end
		end
	end
end

-- Scavi nel terreno (prima di misurare le quote): crateri e trincee.
function Scenari:scava()
	local sc = self.scenario
	if sc.crateri then
		local n, zona, rmin, rmax = sc.crateri[1], sc.crateri[2], sc.crateri[3], sc.crateri[4]
		local fatti = 0
		for _ = 1, n * 10 do
			if fatti >= n then
				break
			end
			local x = self.rng:NextNumber(zona[1], zona[2])
			local z = self.rng:NextNumber(zona[3], zona[4])
			local r = self.rng:NextNumber(rmin, rmax)
			if self:libero(x, z, r + 2) then
				local base = self.ambiente.terra(x, z)
				Paesaggio.scavaCratere(base, r)
				self:occupa(x, z, r + 2)
				table.insert(self.crateri, { x = x, z = z, r = r, base = base })
				fatti += 1
			end
		end
	end
	for _, t in ipairs(sc.trincee or {}) do
		local da, a = t[1], t[2]
		local d = Vector3.new(a[1] - da[1], 0, a[2] - da[2])
		local n = math.max(1, math.floor(d.Magnitude / 30 + 0.5))
		for k = 0, n - 1 do
			local f = (k + 0.5) / n
			local x, z = da[1] + d.X * f, da[2] + d.Z * f
			if not protetto(x, z, 4) and not self.ambiente.inAcqua(x, z, 6) then
				local base = self.ambiente.terra(x, z)
				local cf = CFrame.fromMatrix(base, d.Unit, Vector3.yAxis)
				local lunghezza = d.Magnitude / n + 0.5
				Paesaggio.scavaTrincea(cf, lunghezza)
				self:occupa(x, z, lunghezza / 2)
				table.insert(self.trincee, { cf = cf, lunghezza = lunghezza })
			end
		end
	end
end

-- Tutto il resto, dopo gli scavi.
function Scenari:decora(g)
	local sc = self.scenario
	local amb = self.ambiente
	-- Prima i pezzi fissi e le composizioni (castra, bastie), poi le linee, i gruppi e la flora.
	local pezzi = table.clone(sc.pezzi or {})
	local linee = table.clone(sc.linee or {})
	for _, c in ipairs(sc.castra or {}) do
		local l, p = castra(c[1], c[2], c[3])
		unisci(linee, l)
		unisci(pezzi, p)
	end
	for _, b in ipairs(sc.bastie or {}) do
		local l, p = bastia(b[1], b[2], b[3])
		unisci(linee, l)
		unisci(pezzi, p)
	end
	for _, v in ipairs(pezzi) do
		local nome, x, z, verso, s = v[1], v[2], v[3], v[4], v[5] or 1
		if not fuoriValle(x, z, 0) then
			self:metti(g, nome, x, z, s, verso, v.ctx)
			self:occupa(x, z, (Paesaggio.ingombro[nome] or 3) * s)
		end
	end
	-- Ponti sul fiume: a cavallo della sua mezzeria, lungo z.
	if amb.fiumeZ then
		for _, v in ipairs(sc.ponti or {}) do
			local x = v[2]
			local z = amb.fiumeZ(x)
			local terra = amb.terra(x, z)
			-- Di traverso al fiume, che lì può correre storto (anse).
			local lungo = Vector3.new(2, 0, amb.fiumeZ(x + 1) - amb.fiumeZ(x - 1)).Unit
			local cf = CFrame.fromMatrix(Vector3.new(terra.X, amb.acquaY, terra.Z), lungo, Vector3.yAxis)
			local ok, errore = pcall(P[v[1]], g, cf, self.rng, 1, contesto(self, { lunghezza = 40 / lungo.X }))
			if not ok then
				warn("Scenari: ponte - " .. tostring(errore))
			end
			self:occupa(x, z, 22)
		end
	end
	for _, voce in ipairs(linee) do
		self:linea(g, voce)
	end
	for _, c in ipairs(self.crateri) do
		local ok, errore = pcall(P.bordoCratere, g, CFrame.new(c.base), self.rng, c.r / 5, contesto(self))
		if not ok then
			warn("Scenari: cratere - " .. tostring(errore))
		end
	end
	for _, t in ipairs(self.trincee) do
		local ok, errore = pcall(P.trincea, g, t.cf, self.rng, 1, contesto(self, { lunghezza = t.lunghezza }))
		if not ok then
			warn("Scenari: trincea - " .. tostring(errore))
		end
	end
	for _, v in ipairs(sc.gruppi or {}) do
		if TENDE[v[1]] and not v.sparse then
			self:fila(g, v[1], math.ceil(v[2] * 2), v[3], v[4], v[5], v.ctx, v.verso)
		else
			self:spargi(g, v[1], v[2], v[3], v[4], v[5], v.ctx, v.verso, { galleggia = v.galleggia, riva = v.riva })
		end
	end
	-- Lungo le rive del fiume.
	if amb.fiumeZ then
		for _, v in ipairs(sc.riva or {}) do
			self:spargi(g, v[1], v[2], { -BORDO, BORDO, -BORDO, BORDO }, v[3], v[4], v.ctx, nil, { riva = true })
		end
	end
	-- Resti della battaglia attorno al campo (fuori dalla cornice), fitti dove si è combattuto.
	if sc.resti then
		self:spargi(g, "resti", sc.resti * 2, { -130, 130, -130, 130 }, 0.9, 1.2, nil, nil, { sovrapponi = true, suGhiaccio = true })
	end
	-- Vegetazione a macchie, più fitta vicino al campo, dove si guarda.
	for _, v in ipairs(sc.flora or FLORA[amb.bioma] or FLORA.Pianeggiante) do
		local nome, n, smin, smax = v[1], v[2], v[3], v[4]
		local piccolo = (Paesaggio.ingombro[nome] or 3) < 2
		n = math.floor(n * (piccolo and DENSITA_PICCOLI or DENSITA))
		local vicino, medio = math.floor(n * 0.45), math.floor(n * 0.3)
		self:macchie(g, nome, vicino, { -130, 130, -130, 130 }, smin, smax, v.ctx)
		self:macchie(g, nome, medio, { -200, 200, -200, 200 }, smin, smax, v.ctx)
		self:macchie(g, nome, n - vicino - medio, { -BORDO, BORDO, -BORDO, BORDO }, smin, smax, v.ctx)
	end
	-- I fianchi della valle: una fascia fitta di boschi o rocce, oltre i 200 studs dal centro.
	local cornice = sc.cornice
	if cornice == nil then
		cornice = CORNICE[amb.bioma] or CORNICE.Pianeggiante
	end
	for _, v in ipairs(cornice or {}) do
		self:macchie(g, v[1], v[2], { -BORDO, BORDO, -BORDO, BORDO }, v[3], v[4], v.ctx, { fascia = 200 })
	end
end

-- Dettagli bassi sparsi sul campo, tra le caselle (erba, sassi, fiori) e qualche resto dell'epoca.
function Scenari:dettagliCampo(g, caselle)
	local sc = self.scenario
	local lista = sc.dettagli or DETTAGLI[self.ambiente.bioma] or DETTAGLI.Pianeggiante
	for _ = 1, 46 do
		local x = self.rng:NextNumber(-META_CAMPO + 2, META_CAMPO - 2)
		local z = self.rng:NextNumber(-META_CAMPO + 2, META_CAMPO - 2)
		if not self.ambiente.liquida(x, z, 2) and not caselle(x, z) then
			self:metti(g, lista[self.rng:NextInteger(1, #lista)], x, z, self.rng:NextNumber(0.6, 0.9), nil, nil)
		end
	end
	for _ = 1, 8 do
		local x = self.rng:NextNumber(-META_CAMPO + 4, META_CAMPO - 4)
		local z = self.rng:NextNumber(-META_CAMPO + 4, META_CAMPO - 4)
		if not self.ambiente.liquida(x, z, 3) and not caselle(x, z) then
			self:metti(g, "resti", x, z, 0.7, nil, nil)
		end
	end
end

-- Ostacolo su una casella bloccata: un pezzo grande al centro e due piccoli attorno, dentro la casella.
function Scenari:ostacolo(g, x, z)
	local sc = self.scenario
	local lista = sc.ostacolo or OSTACOLI[self.ambiente.bioma] or OSTACOLI.Pianeggiante
	local extra = sc.contestoOstacolo or { lunghezza = 12 }
	local principale = lista[self.rng:NextInteger(1, #lista)]
	local raggio = Paesaggio.ingombro[principale] or 3
	local s = math.clamp(6 / raggio, 0.6, 1.3)
	self:metti(g, principale, x, z, s, self.rng:NextNumber() < 0.5 and 0 or 90, extra)
	for _ = 1, 2 do
		local altro = lista[self.rng:NextInteger(1, #lista)]
		local r2 = Paesaggio.ingombro[altro] or 3
		if r2 <= 4 then
			self:metti(g, altro, x + self.rng:NextNumber(-4.5, 4.5), z + self.rng:NextNumber(-4.5, 4.5), self.rng:NextNumber(0.6, 0.85), nil, extra)
		end
	end
end

return Scenari
