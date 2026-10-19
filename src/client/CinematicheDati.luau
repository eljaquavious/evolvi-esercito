-- Sceneggiature delle cinematiche prima dei livelli (vedi Cinematica). Coordinate in studs dal centro
-- del campo: z > 0 è il lato nemico, il giocatore arriva da z < 0. Angoli "a" in gradi: 0 guarda verso
-- il nemico (+z), 180 verso il giocatore, 90 verso +x.
--
-- reparti: soldati in formazione ("file" per riga, "righe" dietro la prima) che seguono le tappe.
-- origine: dove si svolge la scena rispetto al centro del campo (x, z), per esempio per stare fuori dal fiume.
-- sgombra: zone { x0, z0, x1, z1 } dove si nascondono alberi, tende e rocce (passano soldati o telecamera).
-- inquadrature: dalla posizione/punto guardato "da" a quelli "a"; con "segui" si muovono col reparto.
-- L'altezza di posizione e punto guardato è sopra il terreno sotto di loro.
-- lanci: la prima riga di un reparto lancia pilum (o tira frecce) verso un altro reparto.
-- mischie: tra "da" e "a" chi ha un nemico vicino combatte. cadute: quota di un reparto che cade.
-- Le scritte sono in inglese, come tutto il gioco. Niente dialoghi.

local Dati = {}

-- Musica per epoca, dalla libreria musicale di Roblox (APM): si può usare in ogni gioco.
local ANTICA = { id = "rbxassetid://1839315075", volume = 0.7 } -- "Bravest Of The Braves" (Kosinus), 59,6 s
local MEDIEVALE = { id = "rbxassetid://1836104037", volume = 0.7 } -- "Determined Epic Theme (Alt 2)" (Marc Dall'Anese), 67,5 s
local NOVECENTO = { id = "rbxassetid://1839466301", volume = 0.75 } -- "War Of Heroes" (Kosinus), tamburi di guerra, 36,4 s

-- Scorciatoie per le sceneggiature qui sotto.
local function R(id, tipo, squadra, file, righe, tappe, passo)
	return { id = id, tipo = tipo, squadra = squadra, file = file, righe = righe, tappe = tappe, passo = passo }
end

local function T(t, x, z, a, liscio)
	return { t = t, x = x, z = z, a = a, liscio = liscio }
end

-- Inquadratura: da (posizione, punto guardato) ad a (posizione, punto guardato) in "durata" secondi.
local function I(t, durata, da, guardaDa, a, guardaA, opzioni)
	local inq = { t = t, durata = durata, da = { da, guardaDa }, a = { a, guardaA } }
	for k, v in pairs(opzioni or {}) do
		inq[k] = v
	end
	inq.fov = inq.fov or 55
	return inq
end

local function S(t, testo, durata)
	return { t = t, testo = testo, durata = durata or 3.6 }
end

local SCRIVI = "Can you rewrite history?" -- chi gioca sta dalla parte di chi perse
local RIPETI = "Your turn to make history." -- chi gioca sta dalla parte di chi vinse
local TIENI = "Can you hold the line?"

-- Canne, 216 a.C.: le legioni sfondano il centro di Annibale, che arretra apposta; i fanti africani
-- chiudono ai lati e la cavalleria punica, messa in fuga quella romana, chiude alle spalle.
Dati["Cannae"] = {
	durata = 31.5,
	-- "Bravest Of The Braves" (Kosinus, APM), dalla libreria musicale di Roblox: si può usare in ogni gioco.
	musica = ANTICA,
	-- Il fiume (l'Ofanto) attraversa il campo a z = 0: la battaglia si svolge sulla riva sud.
	origine = { 0, -55 },
	sgombra = { { -100, -125, 100, 35 }, { -165, -160, -90, -100 } },
	tinta = Color3.fromRGB(255, 240, 220),
	reparti = {
		-- Roma
		{ id = "legioneS", tipo = "Legionario", squadra = "giocatore", file = 6, righe = 4, tappe = {
			{ t = 0, x = -19, z = -95, a = 0 }, { t = 13, z = -9 }, { t = 15, z = -1.5 }, { t = 23, z = 9 }, { t = 31, z = 10 },
		} },
		{ id = "legioneC", tipo = "Legionario", squadra = "giocatore", file = 6, righe = 4, tappe = {
			{ t = 0, x = 0, z = -95, a = 0 }, { t = 13, z = -9 }, { t = 15, z = -1.5 }, { t = 23, z = 9 }, { t = 31, z = 10 },
		} },
		{ id = "legioneD", tipo = "Legionario", squadra = "giocatore", file = 6, righe = 4, tappe = {
			{ t = 0, x = 19, z = -95, a = 0 }, { t = 13, z = -9 }, { t = 15, z = -1.5 }, { t = 23, z = 9 }, { t = 31, z = 10 },
		} },
		{ id = "equitiS", tipo = "Compagno", squadra = "giocatore", file = 3, righe = 2, passo = 5, tappe = {
			{ t = 0, x = -50, z = -103, a = 0 }, { t = 11.5, z = -28 }, { t = 13, x = -52, z = -32 }, { t = 18, x = -95, z = -120 },
		} },
		{ id = "equitiD", tipo = "Compagno", squadra = "giocatore", file = 3, righe = 2, passo = 5, tappe = {
			{ t = 0, x = 50, z = -103, a = 0 }, { t = 11.5, z = -28 }, { t = 13, x = 52, z = -32 }, { t = 18, x = 95, z = -120 },
		} },
		-- Cartagine: al centro Galli e Iberi, ai lati i fanti africani (con armi romane prese in battaglia).
		{ id = "galliS", tipo = "Spadaccino", squadra = "nemico", file = 6, righe = 3, tappe = {
			{ t = 0, x = -10, z = 2, a = 180 }, { t = 15.5 }, { t = 23, z = 12.5 }, { t = 31, z = 13.5 },
		} },
		{ id = "galliD", tipo = "Spadaccino", squadra = "nemico", file = 6, righe = 3, tappe = {
			{ t = 0, x = 10, z = 2, a = 180 }, { t = 15.5 }, { t = 23, z = 12.5 }, { t = 31, z = 13.5 },
		} },
		{ id = "africaniS", tipo = "Legionario", squadra = "nemico", file = 4, righe = 4, tappe = {
			{ t = 0, x = -37, z = 18, a = 180 }, { t = 15.5 }, { t = 22.5, x = -31, z = 4, a = 90, liscio = true }, { t = 31, x = -30.5, z = 5 },
		} },
		{ id = "africaniD", tipo = "Legionario", squadra = "nemico", file = 4, righe = 4, tappe = {
			{ t = 0, x = 37, z = 18, a = 180 }, { t = 15.5 }, { t = 22.5, x = 31, z = 4, a = -90, liscio = true }, { t = 31, x = 30.5, z = 5 },
		} },
		{ id = "cavalleriaS", tipo = "Compagno", squadra = "nemico", file = 3, righe = 2, passo = 5, tappe = {
			{ t = 0, x = -62, z = 18, a = 180 }, { t = 8.5 }, { t = 12, x = -50, z = -19 }, { t = 15.5, x = -72, z = -66 },
			{ t = 19.5, x = -32, z = -26, a = 45 }, { t = 23, x = -11, z = -8, a = 0 }, { t = 31, z = -7 },
		} },
		{ id = "cavalleriaD", tipo = "Compagno", squadra = "nemico", file = 3, righe = 2, passo = 5, tappe = {
			{ t = 0, x = 62, z = 18, a = 180 }, { t = 8.5 }, { t = 12, x = 50, z = -19 }, { t = 15.5, x = 72, z = -66 },
			{ t = 19.5, x = 32, z = -26, a = -45 }, { t = 23, x = 11, z = -8, a = 0 }, { t = 31, z = -7 },
		} },
		{ id = "annibale", tipo = "Annibale", squadra = "nemico", tappe = {
			{ t = 0, x = 0, z = 30, a = 180 }, { t = 16 }, { t = 20, z = 25 },
		} },
	},
	inquadrature = {
		-- La piana dall'alto: le legioni avanzano.
		{ t = 0, durata = 5.5, fov = 50, da = { { -150, 80, -190 }, { 0, 0, -10 } }, a = { { -105, 58, -150 }, { 0, 0, -25 } } },
		-- Annibale aspetta davanti ai suoi.
		{ t = 5.5, durata = 5, fov = 40, fuoco = 1, da = { { 8, 5.5, 13 }, { 0, 4.5, 30 } }, a = { { 3.5, 5, 20 }, { 0, 5, 30 } } },
		-- Accanto alle legioni che marciano: il lancio dei pilum e l'urto.
		{ t = 10.5, durata = 5, fov = 55, segui = "legioneS", da = { { -18, 3.5, 7 }, { 8, 3, -4 } }, a = { { -16, 3, 3 }, { 10, 3, 4 } } },
		-- Dall'alto: il centro cede, i lati chiudono, la cavalleria arriva alle spalle.
		{ t = 15.5, durata = 9, fov = 55, da = { { 0, 70, -88 }, { 0, 0, 2 } }, a = { { 0, 100, -48 }, { 0, 0, 4 } } },
		-- In mezzo all'accerchiamento, poi su verso il titolo.
		{ t = 24.5, durata = 7, fov = 60, scossa = 0.12, lineare = true, da = { { -40, 4, -16 }, { 0, 3, 5 } }, a = { { -36, 14, 22 }, { 0, 2, 2 } } },
	},
	lanci = {
		{ t = 12.3, reparto = "legioneS", verso = "galliS" },
		{ t = 12.3, reparto = "legioneC", verso = "galliS" },
		{ t = 12.4, reparto = "legioneD", verso = "galliD" },
	},
	mischie = { da = 11.5, a = 31.5 },
	cadute = {
		{ reparto = "equitiS", da = 12, a = 14, quota = 0.5 },
		{ reparto = "equitiD", da = 12, a = 14, quota = 0.5 },
		{ reparto = "galliS", da = 13.5, a = 23, quota = 0.3 },
		{ reparto = "galliD", da = 13.5, a = 23, quota = 0.3 },
		{ reparto = "legioneS", da = 19, a = 31, quota = 0.5 },
		{ reparto = "legioneC", da = 17, a = 31, quota = 0.35 },
		{ reparto = "legioneD", da = 19, a = 31, quota = 0.5 },
		{ reparto = "africaniS", da = 22, a = 31, quota = 0.1 },
		{ reparto = "africaniD", da = 22, a = 31, quota = 0.1 },
	},
	scritte = {
		{ t = 1, durata = 3.8, testo = "Apulia, southern Italy. Summer, 216 BC." },
		{ t = 6, durata = 3.6, testo = "Hannibal waits for Rome, with a plan." },
		{ t = 11, durata = 3.6, testo = "Eighty thousand Romans march to crush him." },
		{ t = 16.5, durata = 3, testo = "His center gives way..." },
		{ t = 20.5, durata = 3.2, testo = "...and the trap closes." },
	},
	titolo = { t = 27, testo = "CANNAE", sotto = "216 BC", motto = "Can you rewrite history?" },
}

-- Gaugamela, 331 a.C.: tu sei Alessandro. La falange tiene il centro, i Compagni si spostano a destra,
-- la cavalleria persiana li segue e nella linea si apre un varco: Alessandro ci si butta, dritto su Dario.
Dati["Gaugamela"] = {
	durata = 31,
	musica = ANTICA,
	sgombra = { { -110, -80, 135, 120 }, { 20, 90, 120, 180 } },
	reparti = {
		R("falangeS", "Legionario", "giocatore", 6, 4, { T(0, -19, -40, 0), T(15.5, nil, 0.5), T(24.5), T(31, nil, 12) }),
		R("falangeC", "Legionario", "giocatore", 6, 4, { T(0, 0, -40, 0), T(15.5, nil, 0.5), T(24.5), T(31, nil, 12) }),
		R("falangeD", "Legionario", "giocatore", 6, 4, { T(0, 19, -40, 0), T(15.5, nil, 0.5), T(24.5), T(31, nil, 12) }),
		R("compagni", "Compagno", "giocatore", 3, 3, {
			T(0, 40, -44, 0), T(9, 68, -26), T(13.5, 70, -14), T(16.5, 45, 6, -60), T(21, 8, 38, -40), T(31, -2, 56, -20),
		}, 5),
		R("arcieri", "ArciereCretese", "nemico", 8, 2, { T(0, -6, 14, 180), T(15), T(17, nil, 16), T(23.5), T(24.5, nil, 19.4, 0, true), T(31, -40, 55) }),
		R("persianiS", "Legionario", "nemico", 6, 3, { T(0, -27, 4, 180), T(24), T(25, nil, 10.8, 0, true), T(31, -30, 46) }),
		R("persianiC", "Legionario", "nemico", 6, 3, { T(0, -8, 4, 180), T(24), T(25, nil, 10.8, 0, true), T(31, -10, 46) }),
		R("cavalleriaPersiana", "Compagno", "nemico", 3, 3, {
			T(0, 32, 10, 180), T(8.5), T(14.5, 80, -6, -90), T(22, 86, -4), T(31, 120, 30, 0),
		}, 5),
		R("guardia", "Compagno", "nemico", 2, 2, { T(0, 10, 50, 180), T(21), T(31, 26, 120, 0) }, 5),
	},
	inquadrature = {
		I(0, 6, { 70, 70, 150 }, { 0, 0, 0 }, { 40, 55, 115 }, { 0, 0, -12 }, { fov = 50 }),
		I(6, 5, { -34, 6, 30 }, { -6, 4, 12 }, { -26, 5, 26 }, { 0, 6, -25 }, { fov = 45 }),
		I(11, 5, { -6, 5, -15 }, { 4, 3, 6 }, { -9, 5, -12 }, { -10, 3, 14 }, { segui = "compagni" }),
		I(16, 8, { 20, 90, -65 }, { 20, 0, 15 }, { 20, 110, -35 }, { 10, 0, 25 }),
		I(24, 7, { -50, 4, 22 }, { 5, 4, 45 }, { -46, 16, -2 }, { 5, 2, 40 }, { lineare = true, scossa = 0.12, fov = 60 }),
	},
	lanci = {
		{ t = 6.3, reparto = "arcieri", verso = "falangeC", colpo = "tiro", ripeti = 3, ogni = 1.4, righe = 2 },
	},
	mischie = { da = 14, a = 31 },
	cadute = {
		{ reparto = "falangeC", da = 7, a = 10, quota = 0.08 },
		{ reparto = "persianiC", da = 17, a = 30, quota = 0.35 },
		{ reparto = "persianiS", da = 18, a = 30, quota = 0.25 },
		{ reparto = "cavalleriaPersiana", da = 15, a = 24, quota = 0.3 },
		{ reparto = "guardia", da = 20.5, a = 24, quota = 0.5 },
		{ reparto = "falangeS", da = 17, a = 30, quota = 0.1 },
	},
	scritte = {
		S(1, "Mesopotamia, 331 BC. Darius waits with the might of Persia.", 4),
		S(6.3, "His army is three times larger."),
		S(11.3, "Alexander leads his Companions to the right..."),
		S(16.5, "...the Persians stretch their line to follow, and a gap opens.", 3.8),
		S(21, "Alexander charges through it, straight at Darius.", 3.4),
	},
	titolo = { t = 27, testo = "GAUGAMELA", sotto = "331 BC", motto = RIPETI },
}

-- Termopili, 480 a.C.: tu sei con i Greci che tengono il passo tra la montagna (x < -85) e il mare
-- (x > 120). Le frecce persiane, poi un'ondata dopo l'altra contro il muro di scudi.
Dati["Thermopylae"] = {
	durata = 31,
	musica = ANTICA,
	sgombra = { { -70, -75, 100, 120 } },
	reparti = {
		R("greciS", "Legionario", "giocatore", 6, 4, { T(0, -19, -6, 0), T(12), T(13, nil, -4.5), T(31, nil, -5) }),
		R("greciC", "Legionario", "giocatore", 6, 4, { T(0, 0, -6, 0), T(12), T(13, nil, -4.5), T(31, nil, -5) }),
		R("greciD", "Legionario", "giocatore", 6, 4, { T(0, 19, -6, 0), T(12), T(13, nil, -4.5), T(31, nil, -5) }),
		R("arcieri", "ArciereCretese", "nemico", 10, 2, { T(0, 0, 110, 180) }),
		R("ondataS", "Spadaccino", "nemico", 6, 3, { T(0, -19, 62, 180), T(13, nil, -1) }),
		R("ondataC", "Spadaccino", "nemico", 6, 3, { T(0, 0, 62, 180), T(13, nil, -1) }),
		R("ondataD", "Spadaccino", "nemico", 6, 3, { T(0, 19, 62, 180), T(13, nil, -1) }),
		R("immortaliS", "Legionario", "nemico", 6, 3, { T(0, -10, 100, 180), T(14), T(24, nil, 10) }),
		R("immortaliD", "Legionario", "nemico", 6, 3, { T(0, 10, 100, 180), T(14), T(24, nil, 10) }),
	},
	inquadrature = {
		I(0, 6, { 70, 60, -135 }, { 0, 0, 25 }, { 40, 45, -105 }, { 0, 0, 30 }, { fov = 50 }),
		I(6, 5, { -9.5, 9, -27 }, { 0, 3, 20 }, { -9.5, 8, -22 }, { 0, 3, 30 }, { fov = 45 }),
		I(11, 5, { 45, 5, -6 }, { 0, 4, 12 }, { 38, 5, -1 }, { 0, 4, 0 }),
		I(16, 8, { 0, 70, -72 }, { 0, 0, 8 }, { 0, 90, -48 }, { 0, 0, 12 }),
		I(24, 7, { -38, 4, -2 }, { 0, 4, 2 }, { -33, 15, -30 }, { 0, 2, 5 }, { lineare = true, scossa = 0.12, fov = 60 }),
	},
	lanci = {
		{ t = 10.4, reparto = "arcieri", verso = "greciC", colpo = "tiro", ripeti = 4, ogni = 1.2, righe = 2 },
		{ t = 10.6, reparto = "greciS", verso = "ondataS", colpo = "lancio" },
		{ t = 10.6, reparto = "greciD", verso = "ondataD", colpo = "lancio" },
	},
	mischie = { da = 12.5, a = 31 },
	cadute = {
		{ reparto = "ondataS", da = 13.5, a = 22, quota = 0.65 },
		{ reparto = "ondataC", da = 13.5, a = 22, quota = 0.65 },
		{ reparto = "ondataD", da = 13.5, a = 22, quota = 0.65 },
		{ reparto = "immortaliS", da = 23, a = 31, quota = 0.35 },
		{ reparto = "immortaliD", da = 23, a = 31, quota = 0.35 },
		{ reparto = "greciC", da = 11, a = 31, quota = 0.15 },
		{ reparto = "greciS", da = 18, a = 31, quota = 0.1 },
		{ reparto = "greciD", da = 18, a = 31, quota = 0.1 },
	},
	scritte = {
		S(1, "Thermopylae, 480 BC. The Persian Empire invades Greece.", 4),
		S(6.3, "A few thousand Greeks block the narrow pass."),
		S(11.3, "Persian arrows blot out the sun."),
		S(16.5, "Wave after wave breaks on the Spartan shields.", 3.8),
		S(21, "For three days, the pass holds.", 3.4),
	},
	titolo = { t = 27, testo = "THERMOPYLAE", sotto = "480 BC", motto = TIENI },
}

-- Zama, 202 a.C.: tu sei Scipione. Le legioni reggono l'urto di Annibale, la cavalleria romana mette in
-- fuga quella cartaginese e torna a colpire alle spalle.
Dati["Zama"] = {
	durata = 31,
	musica = ANTICA,
	sgombra = { { -120, -75, 120, 85 }, { -150, -170, -60, -110 } },
	reparti = {
		R("legioneS", "Legionario", "giocatore", 6, 4, { T(0, -19, -60, 0), T(14, nil, -12), T(16, nil, -3), T(31, nil, -2) }),
		R("legioneC", "Legionario", "giocatore", 6, 4, { T(0, 0, -60, 0), T(14, nil, -12), T(16, nil, -3), T(31, nil, -2) }),
		R("legioneD", "Legionario", "giocatore", 6, 4, { T(0, 19, -60, 0), T(14, nil, -12), T(16, nil, -3), T(31, nil, -2) }),
		R("cavalleriaS", "Compagno", "giocatore", 3, 3, {
			T(0, -50, -55, 0), T(8), T(12.5, -55, -2), T(16.5, -82, 40), T(20, -35, 52, 120), T(24, -10, 11, 180, true), T(31, nil, 12),
		}, 5),
		R("cavalleriaD", "Compagno", "giocatore", 3, 3, {
			T(0, 50, -55, 0), T(8), T(12.5, 55, -2), T(16.5, 82, 40), T(20, 35, 52, -120), T(24, 10, 11, 180, true), T(31, nil, 12),
		}, 5),
		R("cartaginesiS", "Legionario", "nemico", 6, 3, { T(0, -19, 30, 180), T(14, nil, 0.5) }),
		R("cartaginesiC", "Legionario", "nemico", 6, 3, { T(0, 0, 30, 180), T(14, nil, 0.5) }),
		R("cartaginesiD", "Legionario", "nemico", 6, 3, { T(0, 19, 30, 180), T(14, nil, 0.5) }),
		R("numidiS", "Compagno", "nemico", 3, 2, { T(0, -50, 25, 180), T(8), T(12.5, -55, 2), T(16.5, -95, 70, 0) }, 5),
		R("numidiD", "Compagno", "nemico", 3, 2, { T(0, 50, 25, 180), T(8), T(12.5, 55, 2), T(16.5, 95, 70, 0) }, 5),
		R("annibale", "Annibale", "nemico", 1, 1, { T(0, 0, 50, 180), T(22), T(26, nil, 44) }),
	},
	inquadrature = {
		I(0, 5.5, { -120, 70, -150 }, { 0, 0, 0 }, { -80, 55, -120 }, { 0, 0, 10 }, { fov = 50 }),
		I(5.5, 5, { 9, 5.5, 37 }, { 0, 4.5, 50 }, { 4, 5, 41 }, { 0, 5, 50 }, { fov = 40, fuoco = 1 }),
		I(10.5, 5, { 14, 5, -16 }, { -2, 3, 4 }, { 12, 5, -12 }, { -4, 3, 8 }, { segui = "cavalleriaS" }),
		I(15.5, 8.5, { 0, 90, -75 }, { 0, 0, 10 }, { 0, 105, -40 }, { 0, 0, 15 }),
		I(24, 7, { -42, 4, 0 }, { 0, 4, 8 }, { -36, 15, -28 }, { 0, 2, 6 }, { lineare = true, scossa = 0.12, fov = 60 }),
	},
	lanci = {
		{ t = 12.3, reparto = "legioneS", verso = "cartaginesiS", colpo = "lancio" },
		{ t = 12.3, reparto = "legioneC", verso = "cartaginesiC", colpo = "lancio" },
		{ t = 12.4, reparto = "legioneD", verso = "cartaginesiD", colpo = "lancio" },
	},
	mischie = { da = 11.5, a = 31 },
	cadute = {
		{ reparto = "numidiS", da = 12, a = 16, quota = 0.35 },
		{ reparto = "numidiD", da = 12, a = 16, quota = 0.35 },
		{ reparto = "cartaginesiS", da = 22, a = 31, quota = 0.4 },
		{ reparto = "cartaginesiC", da = 17, a = 31, quota = 0.35 },
		{ reparto = "cartaginesiD", da = 22, a = 31, quota = 0.4 },
		{ reparto = "legioneC", da = 16, a = 31, quota = 0.12 },
	},
	scritte = {
		S(1, "North Africa, 202 BC. Rome finally faces Hannibal at home.", 4),
		S(6, "Hannibal has never lost a battle in Italy."),
		S(11, "But this time, Rome's cavalry is stronger."),
		S(16.5, "Scipio's horsemen chase Hannibal's off the field...", 3.6),
		S(20.5, "...and come back to strike from behind.", 3.4),
	},
	titolo = { t = 27, testo = "ZAMA", sotto = "202 BC", motto = RIPETI },
}

-- Gergovia, 52 a.C.: tu sei Cesare. Le legioni salgono verso l'oppidum sull'altopiano (z > 110 sul campo),
-- i Galli di Vercingetorige scendono dal pendio e le respingono. La scena è spostata verso l'altopiano.
Dati["Gergovia"] = {
	durata = 31,
	musica = ANTICA,
	origine = { 0, 60 },
	sgombra = { { -80, -95, 80, 95 } },
	reparti = {
		R("legioneS", "Legionario", "giocatore", 6, 4, { T(0, -19, -70, 0), T(16, nil, 42), T(18, nil, 43), T(26, nil, 24), T(31, nil, -8, 180) }),
		R("legioneC", "Legionario", "giocatore", 6, 4, { T(0, 0, -70, 0), T(16, nil, 42), T(18, nil, 43), T(26, nil, 24), T(31, nil, -8, 180) }),
		R("legioneD", "Legionario", "giocatore", 6, 4, { T(0, 19, -70, 0), T(16, nil, 42), T(18, nil, 43), T(26, nil, 24), T(31, nil, -8, 180) }),
		R("cesare", "Cesare", "giocatore", 1, 1, { T(0, 32, -30, 0) }),
		R("galliS", "Spadaccino", "nemico", 6, 3, { T(0, -19, 78, 180), T(15), T(18, nil, 46.5), T(26, nil, 27.5) }),
		R("galliC", "Spadaccino", "nemico", 6, 3, { T(0, 0, 78, 180), T(15), T(18, nil, 46.5), T(26, nil, 27.5) }),
		R("galliD", "Spadaccino", "nemico", 6, 3, { T(0, 19, 78, 180), T(15), T(18, nil, 46.5), T(26, nil, 27.5) }),
		R("arcieri", "ArciereCretese", "nemico", 8, 2, { T(0, 0, 90, 180) }),
	},
	inquadrature = {
		I(0, 6, { -90, 45, -125 }, { 0, 10, 60 }, { -60, 38, -95 }, { 0, 10, 60 }, { fov = 50 }),
		I(6, 5, { 26, 5, -18 }, { 32, 4.5, -30 }, { 28, 5, -23 }, { 32, 5, -30 }, { fov = 40, fuoco = 1 }),
		I(11, 5, { -20, 6.5, 6 }, { 8, 3.5, -2 }, { -18, 6.5, 2 }, { 10, 3.5, 6 }, { segui = "legioneS" }),
		I(16, 8, { 0, 70, -30 }, { 0, 10, 50 }, { 0, 90, -10 }, { 0, 10, 45 }),
		I(24, 7, { -42, 7, 20 }, { 0, 6, 30 }, { -36, 15, -10 }, { 0, 4, 25 }, { lineare = true, scossa = 0.12, fov = 60 }),
	},
	lanci = {
		{ t = 12, reparto = "arcieri", verso = "legioneC", colpo = "tiro", ripeti = 3, ogni = 1.3, righe = 2 },
		{ t = 14.5, reparto = "legioneS", verso = "galliS", colpo = "lancio" },
		{ t = 14.5, reparto = "legioneD", verso = "galliD", colpo = "lancio" },
	},
	mischie = { da = 16.5, a = 31 },
	cadute = {
		{ reparto = "legioneS", da = 18, a = 31, quota = 0.4 },
		{ reparto = "legioneC", da = 13, a = 31, quota = 0.45 },
		{ reparto = "legioneD", da = 18, a = 31, quota = 0.4 },
		{ reparto = "galliC", da = 18, a = 26, quota = 0.15 },
	},
	scritte = {
		S(1, "Gaul, 52 BC. Caesar besieges the hill fort of Gergovia.", 4),
		S(6.3, "He orders his legions to storm the heights."),
		S(11.3, "They climb almost to the walls..."),
		S(16.5, "...then the Gauls of Vercingetorix pour down the slope.", 3.8),
		S(21, "Caesar suffers his first defeat in Gaul.", 3.4),
	},
	titolo = { t = 27, testo = "GERGOVIA", sotto = "52 BC", motto = SCRIVI },
}

-- Alesia, 52 a.C.: tu sei con i Galli venuti a liberare Vercingetorige. Assaltano le linee di Cesare,
-- poi Cesare manda la riserva di cavalleria sul fianco e l'assalto si spezza.
Dati["Alesia"] = {
	durata = 31,
	musica = ANTICA,
	sgombra = { { -90, -100, 90, 60 } },
	reparti = {
		R("galliS", "Spadaccino", "giocatore", 6, 4, { T(0, -19, -82, 0), T(13, nil, 4.5), T(26), T(31, nil, -40, 180) }),
		R("galliC", "Spadaccino", "giocatore", 6, 4, { T(0, 0, -82, 0), T(13, nil, 4.5), T(26), T(31, nil, -40, 180) }),
		R("galliD", "Spadaccino", "giocatore", 6, 4, { T(0, 19, -82, 0), T(13, nil, 4.5), T(26), T(31, nil, -40, 180) }),
		R("romaniS", "Legionario", "nemico", 6, 3, { T(0, -19, 8, 180) }),
		R("romaniC", "Legionario", "nemico", 6, 3, { T(0, 0, 8, 180) }),
		R("romaniD", "Legionario", "nemico", 6, 3, { T(0, 19, 8, 180) }),
		R("arcieri", "ArciereCretese", "nemico", 10, 2, { T(0, 0, 22, 180) }),
		R("cesare", "Cesare", "nemico", 1, 1, { T(0, 0, 34, 180), T(16), T(20, nil, 29) }),
		R("riserva", "Compagno", "nemico", 3, 3, { T(0, 62, 32, 180), T(16), T(19.5, 52, -10, -150), T(23, 31, -2, -90, true), T(31, 30.5, -3) }, 5),
	},
	inquadrature = {
		I(0, 6, { -100, 60, -150 }, { 0, 0, 40 }, { -70, 50, -120 }, { 0, 0, 50 }, { fov = 50 }),
		I(6, 5, { 7, 5, 28 }, { 0, 4.5, 34 }, { 4, 5, 30 }, { 0, 5, 34 }, { fov = 40, fuoco = 1 }),
		I(11, 5, { -32, 5, 4 }, { 0, 3, 0 }, { -27, 5, 2 }, { 0, 3, 6 }, { segui = "galliC" }),
		I(16, 8, { 10, 80, -70 }, { 10, 0, 10 }, { 10, 100, -40 }, { 10, 0, 12 }),
		I(24, 7, { 48, 5, -16 }, { 20, 4, 2 }, { 52, 16, -42 }, { 10, 2, 0 }, { lineare = true, scossa = 0.12, fov = 60 }),
	},
	lanci = {
		{ t = 9, reparto = "arcieri", verso = "galliC", colpo = "tiro", ripeti = 3, ogni = 1.3, righe = 2 },
		{ t = 11.5, reparto = "romaniS", verso = "galliS", colpo = "lancio" },
		{ t = 11.5, reparto = "romaniC", verso = "galliC", colpo = "lancio" },
		{ t = 11.6, reparto = "romaniD", verso = "galliD", colpo = "lancio" },
	},
	mischie = { da = 12.5, a = 31 },
	cadute = {
		{ reparto = "galliS", da = 11, a = 31, quota = 0.4 },
		{ reparto = "galliC", da = 11, a = 31, quota = 0.4 },
		{ reparto = "galliD", da = 20, a = 31, quota = 0.55 },
		{ reparto = "romaniC", da = 14, a = 26, quota = 0.15 },
	},
	scritte = {
		S(1, "Alesia, 52 BC. Caesar has walled Vercingetorix inside the hill fort.", 4.2),
		S(6.3, "All of Gaul comes to break the siege."),
		S(11.3, "They hurl themselves at the Roman lines..."),
		S(16.5, "...until Caesar sends in his last reserve.", 3.6),
		S(21, "The Gauls break. Vercingetorix surrenders.", 3.4),
	},
	titolo = { t = 27, testo = "ALESIA", sotto = "52 BC", motto = SCRIVI },
}

-- Hattin, 1187: tu sei con i crociati, assetati, tra la sterpaglia che Saladino ha incendiato. Gli arcieri
-- saraceni tirano dai lati, la cavalleria chiude alle spalle; l'ultima carica dei cavalieri fallisce.
Dati["Hattin"] = {
	durata = 31,
	musica = MEDIEVALE,
	sgombra = { { -110, -100, 110, 70 } },
	reparti = {
		R("fantiS", "Spadaccino", "giocatore", 6, 4, { T(0, -22, -70, 0), T(12, nil, -20) }),
		R("fantiD", "Spadaccino", "giocatore", 6, 4, { T(0, 22, -70, 0), T(12, nil, -20) }),
		R("cavalieri", "Cavaliere", "giocatore", 3, 3, { T(0, 0, -75, 0), T(12, nil, -20), T(19), T(23, nil, 13.5) }, 5),
		R("saraceni", "Cavaliere", "nemico", 3, 3, { T(0, 0, 45, 180), T(19), T(23, nil, 17) }, 5),
		R("arcieriS", "Arciere", "nemico", 6, 2, { T(0, -80, 30, 90), T(4), T(14, -52, -26) }),
		R("arcieriD", "Arciere", "nemico", 6, 2, { T(0, 80, 30, -90), T(4), T(14, 52, -26) }),
		R("accerchiaS", "Cavaliere", "nemico", 3, 2, { T(0, -95, -45, 0), T(16), T(22, -15, -34, 0) }, 5),
		R("accerchiaD", "Cavaliere", "nemico", 3, 2, { T(0, 95, -45, 0), T(16), T(22, 15, -34, 0) }, 5),
	},
	inquadrature = {
		I(0, 6, { -80, 60, -140 }, { 0, 0, -30 }, { -55, 48, -115 }, { 0, 0, -20 }, { fov = 50 }),
		I(6, 5, { 6, 5, 10 }, { 0, 4, 0 }, { 4, 5, 7 }, { 0, 4.5, 0 }, { segui = "cavalieri", fov = 45 }),
		I(11, 5, { -30, 6, -45 }, { 0, 3, 0 }, { -25, 8, -40 }, { 0, 3, 5 }),
		I(16, 8, { 0, 85, -80 }, { 0, 0, -15 }, { 0, 105, -60 }, { 0, 0, -10 }),
		I(24, 7, { -40, 4, -8 }, { 0, 4, 0 }, { -34, 15, -45 }, { 0, 2, -10 }, { lineare = true, scossa = 0.12, fov = 60 }),
	},
	fuochi = {
		{ t = 9, x = -32, z = 2, raggio = 12, n = 3 },
		{ t = 9.5, x = 32, z = 2, raggio = 12, n = 3 },
		{ t = 10, x = 0, z = 65, raggio = 30, n = 4 },
		{ t = 10.5, x = -45, z = -55, raggio = 10, n = 2, soloFumo = true },
		{ t = 10.5, x = 45, z = -55, raggio = 10, n = 2, soloFumo = true },
	},
	lanci = {
		{ t = 13.5, reparto = "arcieriS", verso = "fantiS", colpo = "tiro", ripeti = 5, ogni = 1.3, righe = 2 },
		{ t = 13.8, reparto = "arcieriD", verso = "fantiD", colpo = "tiro", ripeti = 5, ogni = 1.3, righe = 2 },
	},
	mischie = { da = 18, a = 31 },
	cadute = {
		{ reparto = "fantiS", da = 15, a = 31, quota = 0.35 },
		{ reparto = "fantiD", da = 15, a = 31, quota = 0.35 },
		{ reparto = "cavalieri", da = 21, a = 30, quota = 0.6 },
		{ reparto = "saraceni", da = 22, a = 30, quota = 0.2 },
	},
	scritte = {
		S(1, "The Holy Land, 1187. The crusaders march under a burning sun.", 4),
		S(6.3, "Cut off from water, they head for the Horns of Hattin."),
		S(11.3, "Saladin sets the dry grass on fire."),
		S(16.5, "Arrows rain down from every side...", 3.6),
		S(21, "...and the knights' last charge fails.", 3.4),
	},
	titolo = { t = 27, testo = "HATTIN", sotto = "1187", motto = SCRIVI },
}

-- Lago Peipus, 1242: tu sei con Novgorod, sul lago ghiacciato. I Cavalieri Teutonici caricano a cuneo,
-- il centro di Nevskij cede ma non si rompe, la sua cavalleria li prende ai lati e li mette in fuga.
Dati["Lake Peipus"] = {
	durata = 31,
	musica = MEDIEVALE,
	sgombra = { { -100, -80, 100, 130 } },
	reparti = {
		R("centro", "Spadaccino", "giocatore", 6, 4, { T(0, 0, -10, 0), T(13), T(17, nil, -17.5), T(31, nil, -16) }),
		R("arcieri", "Arciere", "giocatore", 8, 2, { T(0, 0, -32, 0) }),
		R("fiancoS", "Cavaliere", "giocatore", 3, 2, { T(0, -45, -25, 0), T(16), T(21, -16.5, 0, 90, true), T(23, -16, -2), T(31, -10, 30, 0) }, 5),
		R("fiancoD", "Cavaliere", "giocatore", 3, 2, { T(0, 45, -25, 0), T(16), T(21, 16.5, 0, -90, true), T(23, 16, -2), T(31, 10, 30, 0) }, 5),
		R("punta", "Cavaliere", "nemico", 2, 1, { T(0, 0, 90, 180), T(13, nil, -6.5), T(17, nil, -14), T(23, nil, -12), T(24, nil, -12, 0, true), T(31, nil, 60) }, 5),
		R("cuneo", "Cavaliere", "nemico", 4, 1, { T(0, 0, 95, 180), T(13, nil, -1.5), T(17, nil, -9), T(23, nil, -7), T(24, nil, -7, 0, true), T(31, nil, 65) }, 5),
		R("coda", "Cavaliere", "nemico", 6, 2, { T(0, 0, 100, 180), T(13, nil, 3.5), T(17, nil, -4), T(23, nil, -2), T(24, nil, 3, 0, true), T(31, nil, 75) }, 5),
		R("fanti", "Spadaccino", "nemico", 6, 3, { T(0, 0, 118, 180), T(13, nil, 21.5), T(17, nil, 14), T(23, nil, 16), T(24, nil, 22.8, 0, true), T(31, nil, 90) }),
	},
	inquadrature = {
		I(0, 6, { 90, 60, -140 }, { 0, 0, 20 }, { 60, 48, -110 }, { 0, 0, 25 }, { fov = 50 }),
		I(6, 5, { 4, 4, -16 }, { 0, 4, 6 }, { 3, 4, -12 }, { 0, 4, 8 }, { segui = "punta", fov = 45 }),
		I(11, 5, { -21, 5, -40 }, { 0, 4, 0 }, { -17, 5, -34 }, { 0, 4, 0 }),
		I(16, 8, { 0, 85, -72 }, { 0, 0, -10 }, { 0, 105, -47 }, { 0, 0, -5 }),
		I(24, 7, { -42, 4, -5 }, { 0, 4, 5 }, { -36, 15, -35 }, { 0, 2, 5 }, { lineare = true, scossa = 0.12, fov = 60 }),
	},
	lanci = {
		{ t = 7.5, reparto = "arcieri", verso = "coda", colpo = "tiro", ripeti = 3, ogni = 1.4, righe = 2 },
	},
	mischie = { da = 12.5, a = 31 },
	cadute = {
		{ reparto = "punta", da = 14, a = 28, quota = 0.5 },
		{ reparto = "cuneo", da = 15, a = 28, quota = 0.4 },
		{ reparto = "coda", da = 20, a = 30, quota = 0.35 },
		{ reparto = "centro", da = 13, a = 22, quota = 0.25 },
	},
	scritte = {
		S(1, "Lake Peipus, 1242. The battle on the ice.", 4),
		S(6.3, "The Teutonic Knights charge in an iron wedge."),
		S(11.3, "Alexander Nevsky's line bends, but does not break."),
		S(16.5, "His horsemen strike from both sides...", 3.6),
		S(21, "...and the knights flee across the ice.", 3.4),
	},
	titolo = { t = 27, testo = "LAKE PEIPUS", sotto = "1242", motto = RIPETI },
}

-- Hastings, 1066: tu sei con i Sassoni di Aroldo sul crinale di Senlac (z > 70 sul campo, la scena è
-- spostata lì). I Normanni di Guglielmo caricano, fingono la fuga, i Sassoni li inseguono giù dal colle.
Dati["Hastings"] = {
	durata = 31,
	musica = MEDIEVALE,
	origine = { 0, 40 },
	sgombra = { { -80, -95, 80, 70 } },
	reparti = {
		R("sassoniS", "Spadaccino", "giocatore", 6, 4, { T(0, -19, 35, 180), T(19), T(22, nil, 0), T(31, nil, 1) }),
		R("sassoniC", "Spadaccino", "giocatore", 6, 4, { T(0, 0, 35, 180) }),
		R("sassoniD", "Spadaccino", "giocatore", 6, 4, { T(0, 19, 35, 180), T(19), T(22, nil, 0), T(31, nil, 1) }),
		R("arcieri", "Arciere", "nemico", 8, 2, { T(0, 0, -28, 0) }),
		R("cavalieriS", "Cavaliere", "nemico", 3, 3, {
			T(0, -14, -55, 0), T(11), T(15, nil, 31.5), T(18), T(18.6, nil, 21.5, 180, true), T(22, nil, -14), T(25, nil, -4, 0, true), T(31, nil, -2),
		}, 5),
		R("cavalieriD", "Cavaliere", "nemico", 3, 3, {
			T(0, 14, -55, 0), T(11), T(15, nil, 31.5), T(18), T(18.6, nil, 21.5, 180, true), T(22, nil, -14), T(25, nil, -4, 0, true), T(31, nil, -2),
		}, 5),
		R("guglielmo", "Guglielmo", "nemico", 1, 1, { T(0, 34, -40, 0), T(20), T(24, 30, -18) }),
	},
	inquadrature = {
		I(0, 6, { -100, 55, -130 }, { 0, 5, 30 }, { -70, 45, -100 }, { 0, 5, 35 }, { fov = 50 }),
		I(6, 5, { 30, 5.5, -28 }, { 34, 5, -40 }, { 32, 5.5, -32 }, { 34, 5, -40 }, { fov = 40, fuoco = 1 }),
		I(11, 5, { -22, 5, 6 }, { 6, 3, -4 }, { -20, 5, 2 }, { 8, 4, 8 }, { segui = "cavalieriS" }),
		I(16, 9, { 0, 85, -82 }, { 0, 5, 5 }, { 0, 105, -57 }, { 0, 5, 5 }),
		I(25, 6.5, { -45, 7, 10 }, { -19, 4, 0 }, { -40, 16, -20 }, { -10, 3, 5 }, { lineare = true, scossa = 0.12, fov = 60 }),
	},
	lanci = {
		{ t = 7, reparto = "arcieri", verso = "sassoniC", colpo = "tiro", ripeti = 3, ogni = 1.4, righe = 2 },
	},
	mischie = { da = 14, a = 31 },
	cadute = {
		{ reparto = "sassoniS", da = 23, a = 31, quota = 0.6 },
		{ reparto = "sassoniD", da = 23, a = 31, quota = 0.6 },
		{ reparto = "sassoniC", da = 8, a = 31, quota = 0.15 },
		{ reparto = "cavalieriS", da = 15, a = 31, quota = 0.2 },
		{ reparto = "cavalieriD", da = 15, a = 31, quota = 0.2 },
	},
	scritte = {
		S(1, "England, 1066. King Harold's Saxons hold Senlac Hill.", 4),
		S(6.3, "William of Normandy has come to take the crown."),
		S(11.3, "His knights charge uphill against the shield wall."),
		S(16.5, "The Normans pretend to flee...", 3.6),
		S(20.5, "...and the Saxons break ranks to chase them.", 3.8),
	},
	titolo = { t = 27, testo = "HASTINGS", sotto = "1066", motto = SCRIVI },
}

-- Crécy, 1346: tu sei con i Francesi. I balestrieri genovesi aprono, gli archi lunghi inglesi li travolgono,
-- poi i cavalieri francesi caricano ondata dopo ondata sotto la pioggia di frecce.
Dati["Crecy"] = {
	durata = 31,
	musica = MEDIEVALE,
	sgombra = { { -80, -90, 80, 50 } },
	reparti = {
		R("genovesi", "Arciere", "giocatore", 8, 2, { T(0, 0, -30, 0), T(6), T(9, nil, -8), T(11), T(14, nil, -50, 180) }),
		R("cavalieriS", "Cavaliere", "giocatore", 3, 3, { T(0, -20, -64, 0), T(13), T(19, nil, 16.5) }, 5),
		R("cavalieriC", "Cavaliere", "giocatore", 3, 3, { T(0, 0, -70, 0), T(14), T(20, nil, 16.5) }, 5),
		R("cavalieriD", "Cavaliere", "giocatore", 3, 3, { T(0, 20, -64, 0), T(13), T(19, nil, 16.5) }, 5),
		R("uominiArme", "Spadaccino", "nemico", 6, 3, { T(0, 0, 20, 180) }),
		R("arciS", "Arciere", "nemico", 6, 2, { T(0, -26, 20, 180) }),
		R("arciD", "Arciere", "nemico", 6, 2, { T(0, 26, 20, 180) }),
	},
	inquadrature = {
		I(0, 6, { -110, 60, -130 }, { 0, 0, 0 }, { -80, 50, -100 }, { 0, 0, 10 }, { fov = 50 }),
		I(6, 5, { -20, 4, 6 }, { 4, 3, 0 }, { -18, 4, 4 }, { 4, 3, 10 }, { segui = "genovesi" }),
		I(11, 5, { 44, 5, 14 }, { 26, 4, 20 }, { 40, 5, 12 }, { 10, 3, -20 }),
		I(16, 8, { 0, 80, -75 }, { 0, 0, 0 }, { 0, 100, -50 }, { 0, 0, 5 }),
		I(24, 7, { -45, 4, 0 }, { 0, 4, 12 }, { -40, 15, -28 }, { 0, 2, 8 }, { lineare = true, scossa = 0.12, fov = 60 }),
	},
	lanci = {
		{ t = 9.2, reparto = "genovesi", verso = "uominiArme", colpo = "tiro", righe = 2 },
		{ t = 10, reparto = "arciS", verso = "genovesi", colpo = "tiro", ripeti = 2, ogni = 1.3, righe = 2 },
		{ t = 10.2, reparto = "arciD", verso = "genovesi", colpo = "tiro", ripeti = 2, ogni = 1.3, righe = 2 },
		{ t = 14, reparto = "arciS", verso = "cavalieriS", colpo = "tiro", ripeti = 5, ogni = 1.1, righe = 2 },
		{ t = 14.2, reparto = "arciD", verso = "cavalieriD", colpo = "tiro", ripeti = 5, ogni = 1.1, righe = 2 },
	},
	mischie = { da = 18, a = 31 },
	cadute = {
		{ reparto = "genovesi", da = 10.5, a = 13, quota = 0.4 },
		{ reparto = "cavalieriS", da = 14.5, a = 27, quota = 0.5 },
		{ reparto = "cavalieriC", da = 16, a = 28, quota = 0.4 },
		{ reparto = "cavalieriD", da = 14.5, a = 27, quota = 0.5 },
		{ reparto = "uominiArme", da = 19, a = 30, quota = 0.1 },
	},
	scritte = {
		S(1, "Northern France, 1346. The English wait on a ridge near Crecy.", 4),
		S(6.3, "Genoese crossbowmen lead the French attack."),
		S(11.3, "But the English longbows shoot faster, and farther."),
		S(16.5, "The French knights charge, wave after wave...", 3.6),
		S(21, "...into a storm of arrows.", 3.4),
	},
	titolo = { t = 27, testo = "CRECY", sotto = "1346", motto = SCRIVI },
}

-- Tours, 732: tu sei con i Franchi di Carlo Martello, a muro di scudi sulla riva sud del fiume. Le cariche
-- omayyadi si infrangono, poi si sparge la voce che il loro campo è attaccato e tornano indietro.
Dati["Tours"] = {
	durata = 31,
	musica = MEDIEVALE,
	origine = { 0, -60 },
	sgombra = { { -90, -80, 110, 40 } },
	reparti = {
		R("franchiS", "Spadaccino", "giocatore", 6, 4, { T(0, -19, -6, 0) }),
		R("franchiC", "Spadaccino", "giocatore", 6, 4, { T(0, 0, -6, 0) }),
		R("franchiD", "Spadaccino", "giocatore", 6, 4, { T(0, 19, -6, 0) }),
		R("cavS", "Cavaliere", "nemico", 3, 3, {
			T(0, -12, 28, 180), T(4), T(9, nil, -2.5), T(12), T(15, nil, 22), T(17), T(20, nil, -2.5), T(23), T(29, 70, 15, 60),
		}, 5),
		R("cavD", "Cavaliere", "nemico", 3, 3, {
			T(0, 12, 28, 180), T(4.5), T(9.5, nil, -2.5), T(12), T(15, nil, 22), T(17.5), T(20.5, nil, -2.5), T(23), T(29, 90, 5, 70),
		}, 5),
		R("arcieri", "Arciere", "nemico", 8, 2, { T(0, 45, 25, 180) }),
	},
	inquadrature = {
		I(0, 6, { -100, 55, -120 }, { 0, 0, 0 }, { -70, 45, -95 }, { 0, 0, 10 }, { fov = 50 }),
		I(6, 5, { -34, 6.5, 6 }, { 0, 4, -8 }, { -30, 6.5, 4 }, { 0, 4, -6 }),
		I(11, 5, { -20, 6.5, -8 }, { 4, 3.5, 4 }, { -18, 6.5, -4 }, { 4, 3, -6 }, { segui = "cavS" }),
		I(16, 8, { 0, 80, -60 }, { 0, 0, 10 }, { 0, 95, -35 }, { 20, 0, 15 }),
		I(24, 7, { -40, 7, -15 }, { 0, 4, -5 }, { -35, 15, -40 }, { 0, 2, -5 }, { lineare = true, scossa = 0.12, fov = 60 }),
	},
	fuochi = {
		{ t = 17, x = 100, z = -5, raggio = 12, n = 4 },
	},
	lanci = {
		{ t = 5, reparto = "arcieri", verso = "franchiC", colpo = "tiro", ripeti = 2, ogni = 1.4, righe = 2 },
	},
	mischie = { da = 8.5, a = 24 },
	cadute = {
		{ reparto = "cavS", da = 9, a = 13, quota = 0.25 },
		{ reparto = "cavD", da = 9, a = 13, quota = 0.25 },
		{ reparto = "cavS", da = 20, a = 23, quota = 0.15 },
		{ reparto = "cavD", da = 20, a = 23, quota = 0.15 },
		{ reparto = "franchiC", da = 9, a = 22, quota = 0.12 },
	},
	scritte = {
		S(1, "Gaul, 732. An Umayyad army marches north from Spain.", 4),
		S(6.3, "Charles Martel's Franks lock their shields."),
		S(11.3, "Charge after charge breaks against the wall."),
		S(16.5, "Then a rumor spreads: their camp is under attack!", 3.6),
		S(21, "The Umayyad army turns back.", 3.4),
	},
	titolo = { t = 27, testo = "TOURS", sotto = "732", motto = RIPETI },
}

-- Orléans, 1429: tu sei con gli Inglesi che assediano la città. Giovanna d'Arco guida i Francesi lungo la
-- riva contro le bastie inglesi e le prende una dopo l'altra. La scena sta sulla riva sud, lontano dal fiume.
Dati["Orleans"] = {
	durata = 31,
	musica = MEDIEVALE,
	origine = { 0, -62 },
	sgombra = { { -90, -45, 110, 30 } },
	reparti = {
		R("inglesi", "Spadaccino", "giocatore", 6, 3, { T(0, -10, 0, 90), T(25), T(31, -70, 0, -90) }),
		R("arcieriS", "Arciere", "giocatore", 4, 2, { T(0, -16, -18, 90), T(24), T(30, -75, -20, -90) }),
		R("arcieriD", "Arciere", "giocatore", 4, 2, { T(0, -16, 18, 90), T(24), T(30, -75, 20, -90) }),
		R("colonna1", "Spadaccino", "nemico", 4, 4, { T(0, 95, -8, -90), T(14, -6.5), T(25), T(31, -40) }),
		R("colonna2", "Spadaccino", "nemico", 4, 4, { T(0, 98, 8, -90), T(14.5, -6.5), T(25), T(31, -40) }),
		R("giovanna", "Giovanna", "nemico", 1, 1, { T(0, 100, 0, -90), T(14, -5), T(25), T(31, -38) }),
	},
	inquadrature = {
		I(0, 6, { -60, 55, -90 }, { 20, 0, 20 }, { -40, 45, -70 }, { 30, 0, 30 }, { fov = 50 }),
		I(6, 5, { -10, 6.5, 3 }, { 0, 4.5, 0 }, { -7, 6.5, 2 }, { 0, 5, 0 }, { segui = "giovanna", fov = 40, fuoco = 1 }),
		I(11, 5, { 20, 7, -30 }, { 0, 4, 0 }, { 14, 7, -26 }, { -10, 4, 0 }),
		I(16, 8, { -20, 75, -60 }, { 0, 0, 0 }, { -10, 95, -40 }, { 0, 0, 0 }),
		I(24, 7, { -30, 6.5, -35 }, { -10, 4, 0 }, { -35, 15, -55 }, { -10, 2, 0 }, { lineare = true, scossa = 0.12, fov = 60 }),
	},
	lanci = {
		{ t = 8, reparto = "arcieriS", verso = "colonna1", colpo = "tiro", ripeti = 4, ogni = 1.3, righe = 2 },
		{ t = 8.3, reparto = "arcieriD", verso = "colonna2", colpo = "tiro", ripeti = 4, ogni = 1.3, righe = 2 },
	},
	mischie = { da = 13, a = 31 },
	cadute = {
		{ reparto = "inglesi", da = 16, a = 30, quota = 0.45 },
		{ reparto = "arcieriS", da = 18, a = 30, quota = 0.3 },
		{ reparto = "arcieriD", da = 18, a = 30, quota = 0.3 },
		{ reparto = "colonna1", da = 9, a = 20, quota = 0.15 },
		{ reparto = "colonna2", da = 9, a = 20, quota = 0.15 },
	},
	scritte = {
		S(1, "Orleans, 1429. The English have besieged the city for months.", 4),
		S(6.3, "Then a girl in armor arrives: Joan of Arc."),
		S(11.3, "She leads the French against the English forts..."),
		S(16.5, "...and takes them, one after another.", 3.6),
		S(21, "In nine days, the siege is broken.", 3.4),
	},
	titolo = { t = 27, testo = "ORLEANS", sotto = "1429", motto = SCRIVI },
}

-- Gallipoli, 1915: tu sei con gli Anzac sbarcati nella baia (il mare è dietro, z < -185). Salgono verso le
-- trincee turche sulle creste (z = 92 sul campo, la scena è spostata in su) e le mitragliatrici li fermano.
Dati["Gallipoli"] = {
	durata = 31,
	musica = NOVECENTO,
	origine = { 0, 40 },
	sgombra = { { -80, -125, 80, 45 }, { 12, 56, 34, 72 } },
	reparti = {
		R("anzacS", "Fante", "giocatore", 6, 3, { T(0, -19, -75, 0), T(9, nil, -45), T(17, nil, 22), T(31, nil, 24) }),
		R("anzacC", "Fante", "giocatore", 6, 3, { T(0, 0, -75, 0), T(9, nil, -45), T(17, nil, 22), T(31, nil, 24) }),
		R("anzacD", "Fante", "giocatore", 6, 3, { T(0, 19, -75, 0), T(9, nil, -45), T(17, nil, 22), T(31, nil, 24) }),
		R("ondataS", "Fante", "giocatore", 6, 2, { T(0, -10, -110, 0), T(14, nil, -100), T(24, nil, 5), T(31, nil, 8) }),
		R("ondataD", "Fante", "giocatore", 6, 2, { T(0, 10, -110, 0), T(14, nil, -100), T(24, nil, 5), T(31, nil, 8) }),
		R("turchiS", "Fante", "nemico", 6, 1, { T(0, -32, 54, 180) }),
		R("turchiC", "Fante", "nemico", 6, 1, { T(0, 0, 54, 180) }),
		R("turchiD", "Fante", "nemico", 6, 1, { T(0, 32, 54, 180) }),
		R("mitragliaS", "Mitragliere", "nemico", 1, 1, { T(0, -16, 53, 180) }),
		R("mitragliaD", "Mitragliere", "nemico", 1, 1, { T(0, 16, 53, 180) }),
	},
	inquadrature = {
		I(0, 6, { 40, 30, -235 }, { 0, 15, 50 }, { 25, 28, -200 }, { 0, 15, 50 }, { fov = 50 }),
		I(6, 5, { 21, 7, 62 }, { 10, 3, 20 }, { 19, 7, 60 }, { 5, 3, 0 }, { fov = 50 }),
		I(11, 5, { -16, 5.5, 8 }, { 6, 3, -2 }, { -14, 5.5, 4 }, { 6, 3, 10 }, { segui = "anzacS" }),
		I(16, 8, { 0, 70, -50 }, { 0, 5, 30 }, { 0, 90, -30 }, { 0, 5, 30 }),
		I(24, 7, { -42, 7, 10 }, { 0, 5, 30 }, { -36, 16, -20 }, { 0, 3, 25 }, { lineare = true, scossa = 0.15, fov = 60 }),
	},
	esplosioni = {
		{ t = 1.5, x = 0, z = 70, raggio = 40, n = 8, durata = 7 },
		{ t = 12.5, x = 0, z = 5, raggio = 30, n = 9, durata = 14 },
	},
	lanci = {
		{ t = 10.5, reparto = "mitragliaS", verso = "anzacS", colpo = "tiro", ripeti = 20, ogni = 0.5 },
		{ t = 10.7, reparto = "mitragliaD", verso = "anzacD", colpo = "tiro", ripeti = 20, ogni = 0.5 },
		{ t = 12, reparto = "turchiC", verso = "anzacC", colpo = "tiro", ripeti = 6, ogni = 1.6, quota = 0.7 },
		{ t = 12.4, reparto = "turchiS", verso = "anzacS", colpo = "tiro", ripeti = 6, ogni = 1.6, quota = 0.7 },
		{ t = 12.8, reparto = "turchiD", verso = "anzacD", colpo = "tiro", ripeti = 6, ogni = 1.6, quota = 0.7 },
		{ t = 16, reparto = "anzacC", verso = "turchiC", colpo = "tiro", ripeti = 3, ogni = 2, quota = 0.6 },
		{ t = 21, reparto = "mitragliaS", verso = "ondataS", colpo = "tiro", ripeti = 18, ogni = 0.5 },
		{ t = 21.2, reparto = "mitragliaD", verso = "ondataD", colpo = "tiro", ripeti = 18, ogni = 0.5 },
	},
	cadute = {
		{ reparto = "anzacS", da = 12, a = 24, quota = 0.6 },
		{ reparto = "anzacC", da = 12, a = 24, quota = 0.55 },
		{ reparto = "anzacD", da = 12, a = 24, quota = 0.6 },
		{ reparto = "ondataS", da = 21, a = 31, quota = 0.5 },
		{ reparto = "ondataD", da = 21, a = 31, quota = 0.5 },
		{ reparto = "turchiC", da = 3, a = 10, quota = 0.15 },
	},
	scritte = {
		S(1, "Gallipoli, 1915. The Allies land on the Turkish coast.", 4),
		S(6.3, "Above the beach, the cliffs bristle with trenches."),
		S(11.3, "The Anzacs charge uphill..."),
		S(16.5, "...straight into machine-gun fire.", 3.6),
		S(21, "After eight months, the Allies give up.", 3.4),
	},
	titolo = { t = 27, testo = "GALLIPOLI", sotto = "1915", motto = SCRIVI },
}

-- Verdun, 1916: tu sei con i Francesi nella trincea (z = -100 sul campo, dove c'è un tratto scavato:
-- la scena è spostata lì). Il bombardamento, poi l'assalto tedesco respinto.
Dati["Verdun"] = {
	durata = 31,
	musica = NOVECENTO,
	origine = { 110, -75 },
	sgombra = { { -80, -85, 80, -33 }, { -80, -20, 80, 40 } },
	reparti = {
		R("francesiS", "Fante", "giocatore", 6, 2, { T(0, -19, -25, 0) }),
		R("francesiC", "Fante", "giocatore", 6, 2, { T(0, 0, -25, 0) }),
		R("francesiD", "Fante", "giocatore", 6, 2, { T(0, 19, -25, 0) }),
		R("mitragliaS", "Mitragliere", "giocatore", 1, 1, { T(0, -32, -24, 0) }),
		R("mitragliaD", "Mitragliere", "giocatore", 1, 1, { T(0, 32, -24, 0) }),
		R("tedeschiS", "Fante", "nemico", 6, 3, { T(0, -19, 16, 180), T(7), T(19, nil, -10), T(22, nil, -20.4), T(26), T(31, nil, 15, 0) }),
		R("tedeschiC", "Fante", "nemico", 6, 3, { T(0, 0, 16, 180), T(7), T(19, nil, -10), T(22, nil, -20.4), T(26), T(31, nil, 15, 0) }),
		R("tedeschiD", "Fante", "nemico", 6, 3, { T(0, 19, 16, 180), T(7), T(19, nil, -10), T(22, nil, -20.4), T(26), T(31, nil, 15, 0) }),
	},
	inquadrature = {
		I(0, 6, { -90, 55, -110 }, { 0, 0, -20 }, { -65, 45, -90 }, { 0, 0, -15 }, { fov = 50 }),
		I(6, 5, { -9.5, 9, -40 }, { 0, 3, -20 }, { -6.5, 9.5, -38 }, { 0, 3, 5 }, { fov = 50 }),
		I(11, 5, { -18, 4, -8 }, { 4, 3, 2 }, { -16, 4, -6 }, { 4, 3, -4 }, { segui = "tedeschiS" }),
		I(16, 8, { 0, 75, -80 }, { 0, 0, -5 }, { 0, 95, -60 }, { 0, 0, -5 }),
		I(24, 7, { -42, 7, -36 }, { 0, 4, -24 }, { -36, 15, -60 }, { 0, 2, -20 }, { lineare = true, scossa = 0.15, fov = 60 }),
	},
	esplosioni = {
		{ t = 0.5, x = 0, z = -26, raggio = 32, n = 16, durata = 9 },
		{ t = 12, x = 0, z = 0, raggio = 25, n = 5, durata = 8 },
	},
	lanci = {
		{ t = 11, reparto = "mitragliaS", verso = "tedeschiS", colpo = "tiro", ripeti = 22, ogni = 0.5 },
		{ t = 11.2, reparto = "mitragliaD", verso = "tedeschiD", colpo = "tiro", ripeti = 22, ogni = 0.5 },
		{ t = 12, reparto = "francesiC", verso = "tedeschiC", colpo = "tiro", ripeti = 5, ogni = 1.7, quota = 0.7 },
		{ t = 12.5, reparto = "francesiS", verso = "tedeschiS", colpo = "tiro", ripeti = 5, ogni = 1.7, quota = 0.7 },
		{ t = 13, reparto = "francesiD", verso = "tedeschiD", colpo = "tiro", ripeti = 5, ogni = 1.7, quota = 0.7 },
		{ t = 13, reparto = "tedeschiC", verso = "francesiC", colpo = "tiro", ripeti = 3, ogni = 2, quota = 0.5 },
	},
	mischie = { da = 21, a = 27 },
	cadute = {
		{ reparto = "francesiS", da = 1, a = 9, quota = 0.15 },
		{ reparto = "francesiC", da = 1, a = 9, quota = 0.15 },
		{ reparto = "francesiD", da = 1, a = 9, quota = 0.15 },
		{ reparto = "francesiC", da = 20, a = 28, quota = 0.1 },
		{ reparto = "tedeschiS", da = 12, a = 29, quota = 0.5 },
		{ reparto = "tedeschiC", da = 12, a = 29, quota = 0.5 },
		{ reparto = "tedeschiD", da = 12, a = 29, quota = 0.5 },
	},
	scritte = {
		S(1, "Verdun, 1916. The longest battle of the war.", 4),
		S(6.3, "A storm of German shells falls on the French lines."),
		S(11.3, "Then the German infantry attacks."),
		S(16.5, "\"They shall not pass.\"", 3.6),
		S(21, "For ten months, the French line holds.", 3.4),
	},
	titolo = { t = 27, testo = "VERDUN", sotto = "1916", motto = TIENI },
}

-- Amiens, 1918: tu sei con i Tedeschi nella trincea (z = -115 sul campo, la scena è spostata lì).
-- Dalla nebbia escono i carri armati alleati di Foch e la linea crolla.
Dati["Amiens"] = {
	durata = 31,
	musica = NOVECENTO,
	origine = { 0, -75 },
	nebbia = 0.45,
	sgombra = { { -80, -110, 80, -46 }, { -80, -34, 80, 100 } },
	reparti = {
		R("tedeschiS", "Fante", "giocatore", 6, 2, { T(0, -19, -40, 0), T(22), T(31, nil, -100, 180) }),
		R("tedeschiC", "Fante", "giocatore", 6, 2, { T(0, 0, -40, 0), T(22), T(31, nil, -100, 180) }),
		R("tedeschiD", "Fante", "giocatore", 6, 2, { T(0, 19, -40, 0), T(22), T(31, nil, -100, 180) }),
		R("mitragliaS", "Mitragliere", "giocatore", 1, 1, { T(0, -32, -39, 0) }),
		R("mitragliaD", "Mitragliere", "giocatore", 1, 1, { T(0, 32, -39, 0) }),
		R("carri", "CarroArmato", "nemico", 4, 1, { T(0, 0, 70, 180), T(3), T(22, nil, -30), T(31, nil, -31) }, 14),
		R("fantiS", "Fante", "nemico", 6, 2, { T(0, -14, 85, 180), T(4), T(22, nil, -18), T(31, nil, -24) }),
		R("fantiD", "Fante", "nemico", 6, 2, { T(0, 14, 85, 180), T(4), T(22, nil, -18), T(31, nil, -24) }),
		R("foch", "Foch", "nemico", 1, 1, { T(0, 36, 46, 180) }),
	},
	inquadrature = {
		I(0, 6, { -80, 50, -110 }, { 0, 0, 10 }, { -60, 40, -90 }, { 0, 0, 20 }, { fov = 50 }),
		I(6, 5, { 32, 5, 36 }, { 36, 4.5, 46 }, { 34, 5, 39 }, { 36, 4.8, 46 }, { fov = 40, fuoco = 1 }),
		I(11, 5, { 14, 7, -25 }, { 0, 4, 0 }, { 12, 7, -20 }, { 0, 4, 0 }, { segui = "carri" }),
		I(16, 8, { 0, 75, -95 }, { 0, 0, -30 }, { 0, 95, -80 }, { 0, 0, -30 }),
		I(24, 7, { -44, 7.5, -54 }, { 0, 4, -40 }, { -40, 15, -78 }, { 0, 2, -35 }, { lineare = true, scossa = 0.15, fov = 60 }),
	},
	esplosioni = {
		{ t = 8, x = 0, z = -40, raggio = 30, n = 10, durata = 13 },
	},
	lanci = {
		{ t = 9, reparto = "carri", verso = "tedeschiC", colpo = "tiro", ripeti = 6, ogni = 2 },
		{ t = 10, reparto = "mitragliaS", verso = "fantiS", colpo = "tiro", ripeti = 22, ogni = 0.5 },
		{ t = 10.2, reparto = "mitragliaD", verso = "fantiD", colpo = "tiro", ripeti = 22, ogni = 0.5 },
		{ t = 12, reparto = "tedeschiC", verso = "fantiS", colpo = "tiro", ripeti = 4, ogni = 2, quota = 0.7 },
		{ t = 12.5, reparto = "tedeschiD", verso = "fantiD", colpo = "tiro", ripeti = 4, ogni = 2, quota = 0.7 },
		{ t = 14, reparto = "fantiS", verso = "tedeschiS", colpo = "tiro", ripeti = 4, ogni = 2, quota = 0.6 },
	},
	cadute = {
		{ reparto = "tedeschiS", da = 11, a = 28, quota = 0.4 },
		{ reparto = "tedeschiC", da = 11, a = 28, quota = 0.4 },
		{ reparto = "tedeschiD", da = 11, a = 28, quota = 0.4 },
		{ reparto = "mitragliaS", da = 15, a = 21, quota = 1 },
		{ reparto = "fantiS", da = 12, a = 24, quota = 0.2 },
		{ reparto = "fantiD", da = 12, a = 24, quota = 0.2 },
	},
	scritte = {
		S(1, "Amiens, August 1918. A thick fog covers the German lines.", 4),
		S(6.3, "Marshal Foch has prepared a surprise."),
		S(11.3, "Hundreds of tanks roll out of the mist."),
		S(16.5, "The German front collapses.", 3.6),
		S(21, "Ludendorff calls it \"the black day of the German army.\"", 3.6),
	},
	titolo = { t = 27, testo = "AMIENS", sotto = "1918", motto = SCRIVI },
}

-- Stalingrado, 1942: tu sei con i Sovietici tra le rovine, con il Volga alle spalle (il fiume del campo,
-- a z = 0: la scena è spostata a sud). I Tedeschi attaccano, poi l'Armata Rossa li chiude dai lati.
Dati["Stalingrad"] = {
	durata = 31,
	musica = NOVECENTO,
	origine = { 0, -30 },
	sgombra = { { -100, -115, 100, 12 } },
	reparti = {
		R("sovieticiS", "Fante", "giocatore", 6, 2, { T(0, -19, -2, 180) }),
		R("sovieticiC", "Fante", "giocatore", 6, 2, { T(0, 0, -2, 180) }),
		R("sovieticiD", "Fante", "giocatore", 6, 2, { T(0, 19, -2, 180) }),
		R("mitragliaS", "Mitragliere", "giocatore", 1, 1, { T(0, -32, -1, 180) }),
		R("mitragliaD", "Mitragliere", "giocatore", 1, 1, { T(0, 32, -1, 180) }),
		R("rinforziS", "Fante", "giocatore", 6, 2, { T(0, -88, -55, 90), T(19), T(27, -31.5, -14, 90) }),
		R("rinforziD", "Fante", "giocatore", 6, 2, { T(0, 88, -55, -90), T(19), T(27, 31.5, -14, -90) }),
		R("tedeschiS", "Fante", "nemico", 6, 3, { T(0, -19, -90, 0), T(8), T(18, nil, -30), T(22, nil, -5.5), T(31, nil, -6) }),
		R("tedeschiC", "Fante", "nemico", 6, 3, { T(0, 0, -90, 0), T(8), T(18, nil, -30), T(22, nil, -5.5), T(31, nil, -6) }),
		R("tedeschiD", "Fante", "nemico", 6, 3, { T(0, 19, -90, 0), T(8), T(18, nil, -30), T(22, nil, -5.5), T(31, nil, -6) }),
		R("carro", "CarroArmato", "nemico", 1, 1, { T(0, 40, -105, 0), T(5), T(20, 40, -45) }),
	},
	inquadrature = {
		I(0, 6, { 80, 60, 40 }, { 0, 0, -40 }, { 60, 48, 25 }, { 0, 0, -45 }, { fov = 50 }),
		I(6, 5, { -9.5, 9, 14 }, { 0, 2, -30 }, { -9.5, 8, 11 }, { 0, 2, -45 }, { fov = 50 }),
		I(11, 5, { -18, 4, 8 }, { 4, 3, -2 }, { -16, 4, 4 }, { 4, 3, 10 }, { segui = "tedeschiS" }),
		I(16, 9, { 0, 85, 30 }, { 0, 0, -30 }, { 0, 105, 15 }, { 0, 0, -30 }),
		I(25, 6.5, { -48, 5, -12 }, { 0, 4, -25 }, { -42, 15, 6 }, { 0, 2, -22 }, { lineare = true, scossa = 0.15, fov = 60 }),
	},
	fuochi = {
		{ t = 0, x = -55, z = -60, raggio = 14, n = 3 },
		{ t = 0, x = 58, z = -22, raggio = 10, n = 2 },
		{ t = 0, x = 20, z = -95, raggio = 15, n = 2, soloFumo = true },
	},
	esplosioni = {
		{ t = 2, x = 0, z = -12, raggio = 40, n = 8, durata = 14 },
	},
	lanci = {
		{ t = 9, reparto = "carro", verso = "sovieticiC", colpo = "tiro", ripeti = 5, ogni = 2.2 },
		{ t = 10, reparto = "mitragliaS", verso = "tedeschiS", colpo = "tiro", ripeti = 22, ogni = 0.5 },
		{ t = 10.2, reparto = "mitragliaD", verso = "tedeschiD", colpo = "tiro", ripeti = 22, ogni = 0.5 },
		{ t = 11, reparto = "sovieticiC", verso = "tedeschiC", colpo = "tiro", ripeti = 5, ogni = 1.8, quota = 0.7 },
		{ t = 12, reparto = "tedeschiC", verso = "sovieticiC", colpo = "tiro", ripeti = 3, ogni = 2, quota = 0.5 },
		{ t = 24, reparto = "rinforziS", verso = "tedeschiS", colpo = "tiro", ripeti = 2, ogni = 1.5, quota = 0.6 },
		{ t = 24.3, reparto = "rinforziD", verso = "tedeschiD", colpo = "tiro", ripeti = 2, ogni = 1.5, quota = 0.6 },
	},
	mischie = { da = 21, a = 31 },
	cadute = {
		{ reparto = "tedeschiS", da = 16, a = 30, quota = 0.5 },
		{ reparto = "tedeschiC", da = 16, a = 30, quota = 0.4 },
		{ reparto = "tedeschiD", da = 16, a = 30, quota = 0.5 },
		{ reparto = "sovieticiC", da = 10, a = 24, quota = 0.25 },
		{ reparto = "sovieticiS", da = 14, a = 24, quota = 0.15 },
	},
	scritte = {
		S(1, "Stalingrad, winter 1942.", 4),
		S(6.3, "The Germans fight for every street and every house."),
		S(11.3, "With their backs to the Volga, the Soviets refuse to fall."),
		S(16.5, "Then the Red Army strikes from both sides...", 3.6),
		S(21, "...and the trap closes around the Germans.", 3.4),
	},
	titolo = { t = 27, testo = "STALINGRAD", sotto = "1942", motto = RIPETI },
}

-- Normandia, 1944: tu sei con gli Alleati nel bocage. Carri e fanteria avanzano insieme, campo dopo campo,
-- contro le mitragliatrici nascoste nelle siepi.
Dati["Normandy"] = {
	durata = 31,
	musica = NOVECENTO,
	sgombra = { { -70, -100, 70, 50 } },
	reparti = {
		R("alleatiS", "Fante", "giocatore", 6, 2, { T(0, -18, -85, 0), T(4), T(18, nil, -20), T(22), T(26, nil, 20.5), T(31, nil, 40) }),
		R("alleatiD", "Fante", "giocatore", 6, 2, { T(0, 18, -85, 0), T(4), T(18, nil, -20), T(22), T(26, nil, 20.5), T(31, nil, 40) }),
		R("carri", "CarroArmato", "giocatore", 2, 1, { T(0, 0, -80, 0), T(4), T(20, nil, -10), T(31, nil, 20) }, 16),
		R("tedeschiS", "Fante", "nemico", 6, 2, { T(0, -18, 24, 180), T(25), T(31, nil, 70, 0) }),
		R("tedeschiD", "Fante", "nemico", 6, 2, { T(0, 18, 24, 180), T(25), T(31, nil, 70, 0) }),
		R("mitragliaS", "Mitragliere", "nemico", 1, 1, { T(0, -34, 22, 180) }),
		R("mitragliaD", "Mitragliere", "nemico", 1, 1, { T(0, 34, 22, 180) }),
	},
	inquadrature = {
		I(0, 6, { -90, 55, -120 }, { 0, 0, 0 }, { -65, 45, -95 }, { 0, 0, 10 }, { fov = 50 }),
		I(6, 5, { 40, 4, 30 }, { 30, 3, 0 }, { 38, 4, 29 }, { 25, 3, -20 }, { fov = 50 }),
		I(11, 5, { -12, 5, 8 }, { 6, 3, -2 }, { -10, 5, 5 }, { 6, 3, 6 }, { segui = "carri" }),
		I(16, 8, { 0, 75, -70 }, { 0, 0, 0 }, { 0, 95, -45 }, { 0, 0, 5 }),
		I(24, 7, { -44, 4, 5 }, { 0, 4, 18 }, { -38, 15, -25 }, { 0, 2, 15 }, { lineare = true, scossa = 0.15, fov = 60 }),
	},
	esplosioni = {
		{ t = 9, x = 0, z = -35, raggio = 25, n = 5, durata = 8 },
		{ t = 15, x = 0, z = 24, raggio = 30, n = 6, durata = 8 },
	},
	lanci = {
		{ t = 8, reparto = "mitragliaS", verso = "alleatiS", colpo = "tiro", ripeti = 14, ogni = 0.5 },
		{ t = 8.2, reparto = "mitragliaD", verso = "alleatiD", colpo = "tiro", ripeti = 14, ogni = 0.5 },
		{ t = 10, reparto = "tedeschiS", verso = "alleatiS", colpo = "tiro", ripeti = 4, ogni = 2, quota = 0.6 },
		{ t = 10.5, reparto = "tedeschiD", verso = "alleatiD", colpo = "tiro", ripeti = 4, ogni = 2, quota = 0.6 },
		{ t = 11, reparto = "carri", verso = "tedeschiS", colpo = "tiro", ripeti = 5, ogni = 2 },
		{ t = 14, reparto = "alleatiS", verso = "tedeschiS", colpo = "tiro", ripeti = 4, ogni = 1.7, quota = 0.7 },
		{ t = 14.5, reparto = "alleatiD", verso = "tedeschiD", colpo = "tiro", ripeti = 4, ogni = 1.7, quota = 0.7 },
	},
	mischie = { da = 25, a = 31 },
	cadute = {
		{ reparto = "mitragliaS", da = 14, a = 20, quota = 1 },
		{ reparto = "mitragliaD", da = 15, a = 21, quota = 1 },
		{ reparto = "tedeschiS", da = 15, a = 30, quota = 0.45 },
		{ reparto = "tedeschiD", da = 15, a = 30, quota = 0.45 },
		{ reparto = "alleatiS", da = 9, a = 22, quota = 0.2 },
		{ reparto = "alleatiD", da = 9, a = 22, quota = 0.2 },
	},
	scritte = {
		S(1, "Normandy, June 1944. After D-Day, the Allies push inland.", 4),
		S(6.3, "Every hedgerow hides a German gun."),
		S(11.3, "Tanks and infantry advance together..."),
		S(16.5, "...field by field...", 3.6),
		S(21, "...until the German front breaks.", 3.4),
	},
	titolo = { t = 27, testo = "NORMANDY", sotto = "1944", motto = RIPETI },
}

-- Parigi, 1944: tu sei con i Tedeschi alle barricate sulla riva sud della Senna (la scena è spostata a sud
-- del fiume). Arrivano i carri francesi, la guarnigione si arrende e De Gaulle sfila in trionfo.
Dati["Paris"] = {
	durata = 31,
	musica = NOVECENTO,
	origine = { 0, -60 },
	sgombra = { { -90, -115, 90, 25 } },
	reparti = {
		R("tedeschiS", "Fante", "giocatore", 6, 2, { T(0, -18, 10, 180), T(24), T(25.5, nil, 16), T(31, -75, 16, -90) }),
		R("tedeschiD", "Fante", "giocatore", 6, 2, { T(0, 18, 10, 180), T(24), T(25.5, nil, 16), T(31, 75, 16, 90) }),
		R("mitraglia", "Mitragliere", "giocatore", 1, 1, { T(0, 0, 9, 180) }),
		R("carri", "CarroArmato", "nemico", 2, 1, { T(0, 0, -95, 0), T(3), T(18, nil, -12), T(31, nil, -4) }, 13),
		R("francesiS", "Fante", "nemico", 6, 2, { T(0, -22, -100, 0), T(4), T(20, nil, -15), T(24, nil, 6.5) }),
		R("francesiD", "Fante", "nemico", 6, 2, { T(0, 22, -100, 0), T(4), T(20, nil, -15), T(24, nil, 6.5) }),
		R("degaulle", "DeGaulle", "nemico", 1, 1, { T(0, 0, -75, 0), T(22), T(31, nil, -38) }),
	},
	inquadrature = {
		I(0, 6, { -50, 60, -130 }, { 0, 25, 300 }, { -35, 50, -105 }, { 0, 35, 315 }, { fov = 50 }),
		I(6, 5, { -8, 6.5, 18 }, { 0, 3, -20 }, { -5, 6.5, 16 }, { 0, 3, -40 }, { fov = 50 }),
		I(11, 5, { -12, 5, 8 }, { 6, 3, -2 }, { -10, 5, 5 }, { 6, 3, 6 }, { segui = "carri" }),
		I(16, 8, { 0, 75, -70 }, { 0, 0, 0 }, { 0, 95, -50 }, { 0, 0, 0 }),
		I(24, 7, { 6, 6.5, 10 }, { 0, 4.5, 0 }, { 10, 12, 18 }, { 0, 4, 0 }, { segui = "degaulle", fov = 45, lineare = true }),
	},
	esplosioni = {
		{ t = 13, x = 0, z = 10, raggio = 25, n = 6, durata = 8 },
	},
	lanci = {
		{ t = 8, reparto = "tedeschiS", verso = "francesiS", colpo = "tiro", ripeti = 4, ogni = 1.8, quota = 0.7 },
		{ t = 8.5, reparto = "tedeschiD", verso = "francesiD", colpo = "tiro", ripeti = 4, ogni = 1.8, quota = 0.7 },
		{ t = 9, reparto = "mitraglia", verso = "francesiS", colpo = "tiro", ripeti = 12, ogni = 0.5 },
		{ t = 12, reparto = "carri", verso = "tedeschiS", colpo = "tiro", ripeti = 4, ogni = 2 },
		{ t = 14, reparto = "francesiS", verso = "tedeschiS", colpo = "tiro", ripeti = 4, ogni = 1.7, quota = 0.7 },
		{ t = 14.5, reparto = "francesiD", verso = "tedeschiD", colpo = "tiro", ripeti = 4, ogni = 1.7, quota = 0.7 },
	},
	mischie = { da = 23, a = 31 },
	cadute = {
		{ reparto = "mitraglia", da = 15, a = 17, quota = 1 },
		{ reparto = "tedeschiS", da = 14, a = 26, quota = 0.45 },
		{ reparto = "tedeschiD", da = 14, a = 26, quota = 0.45 },
		{ reparto = "francesiS", da = 9, a = 22, quota = 0.15 },
		{ reparto = "francesiD", da = 9, a = 22, quota = 0.15 },
	},
	scritte = {
		S(1, "Paris, August 1944. The city rises against the occupiers.", 4),
		S(6.3, "German troops dig in behind the barricades."),
		S(11.3, "French tanks roll into the city."),
		S(16.5, "The German garrison surrenders...", 3.6),
		S(21, "...and De Gaulle marches in triumph.", 3.4),
	},
	titolo = { t = 27, testo = "PARIS", sotto = "1944", motto = SCRIVI },
}

-- Armate fedeli alla storia (Mattia, 18/10/2026): nelle scene non si vedono più le carte del giocatore usate per
-- tutti, ma le truppe vere di ogni esercito (Config/Epoche). Qui si cambia solo il tipo dei reparti delle
-- sceneggiature qui sopra (id del reparto -> tipo); posizioni e movimenti restano quelli.
-- passo = distanza tra i soldati, per i reparti di modelli grandi (gli elefanti).
local FEDELI = {
	Gaugamela = {
		falangeS = "Oplita", falangeC = "Oplita", falangeD = "Oplita", arcieri = "ArcierePersiano",
		persianiS = "Immortale", persianiC = "Immortale", cavalleriaPersiana = "CavalleriaPersiana", guardia = "CavalleriaPersiana",
	},
	Thermopylae = {
		greciS = "Oplita", greciC = "Oplita", greciD = "Oplita", arcieri = "ArcierePersiano",
		ondataS = "Immortale", ondataC = "Immortale", ondataD = "Immortale", immortaliS = "Immortale", immortaliD = "Immortale",
	},
	Zama = {
		cavalleriaS = "CavalleriaNumidica", cavalleriaD = "CavalleriaNumidica", -- i Numidi di Massinissa, alleati di Roma
		cartaginesiS = "LanciereLibico", cartaginesiC = { tipo = "Elefante", passo = 7 }, cartaginesiD = "LanciereLibico",
		numidiS = "CavalleriaNumidica", numidiD = "CavalleriaNumidica",
	},
	Gergovia = { galliS = "GuerrieroGallico", galliC = "GuerrieroGallico", galliD = "GuerrieroGallico", arcieri = "ArciereGallico" },
	Alesia = { galliS = "GuerrieroGallico", galliC = "GuerrieroGallico", galliD = "GuerrieroGallico", riserva = "CavalleriaGermanica" },
	Tours = { franchiS = "FanteNormanno", franchiC = "FanteNormanno", franchiD = "FanteNormanno", cavS = "CavalleriaAraba", cavD = "CavalleriaAraba", arcieri = "ArciereArabo" },
	Hastings = { arcieri = "ArciereNormanno", cavalieriS = "CavaliereNormanno", cavalieriD = "CavaliereNormanno" },
	Hattin = {
		fantiS = "FanteNormanno", fantiD = "FanteNormanno", cavalieri = "CavaliereNormanno", saraceni = "Mamelucco",
		arcieriS = "ArciereAyyubide", arcieriD = "ArciereAyyubide", accerchiaS = "Mamelucco", accerchiaD = "Mamelucco",
	},
	["Lake Peipus"] = {
		fiancoS = "CavaliereNormanno", fiancoD = "CavaliereNormanno",
		punta = "CavaliereTeutonico", cuneo = "CavaliereTeutonico", coda = "CavaliereTeutonico", fanti = "SergenteTeutonico",
	},
	Crecy = { genovesi = "BalestriereGenovese" },
	Orleans = { colonna1 = "UomoDArme", colonna2 = "UomoDArme" },
	Gallipoli = {
		anzacS = "FanteBritannico", anzacC = "FanteBritannico", anzacD = "FanteBritannico", ondataS = "FanteBritannico", ondataD = "FanteBritannico",
		turchiS = "FanteOttomano", turchiC = "FanteOttomano", turchiD = "FanteOttomano", mitragliaS = "MitraglieriOttomani", mitragliaD = "MitraglieriOttomani",
	},
	Verdun = { tedeschiS = "Stosstruppen", tedeschiC = "Stosstruppen", tedeschiD = "Stosstruppen" },
	Amiens = {
		tedeschiS = "Stosstruppen", tedeschiC = "Stosstruppen", tedeschiD = "Stosstruppen", mitragliaS = "MitraglieriTedeschi", mitragliaD = "MitraglieriTedeschi",
		carri = "CarroMarkV", fantiS = "FanteBritannico",
	},
	Stalingrad = {
		sovieticiS = "FucilieriSovietici", sovieticiC = "FucilieriSovietici", sovieticiD = "FucilieriSovietici",
		mitragliaS = "MitraglieriSovietici", mitragliaD = "MitraglieriSovietici", rinforziS = "FucilieriSovietici", rinforziD = "FucilieriSovietici",
		tedeschiS = "Granatieri", tedeschiC = "Granatieri", tedeschiD = "Granatieri", carro = "Panzer",
	},
	Normandy = {
		alleatiS = "FanteFranciaLibera", alleatiD = "FanteFranciaLibera",
		tedeschiS = "Granatieri", tedeschiD = "Granatieri", mitragliaS = "MG42", mitragliaD = "MG42",
	},
	Paris = { tedeschiS = "Granatieri", tedeschiD = "Granatieri", mitraglia = "MG42", francesiS = "FanteFranciaLibera", francesiD = "FanteFranciaLibera" },
}
for nome, mappa in pairs(FEDELI) do
	for _, reparto in ipairs(Dati[nome] and Dati[nome].reparti or {}) do
		local nuovo = mappa[reparto.id]
		if type(nuovo) == "table" then
			reparto.tipo = nuovo.tipo
			reparto.passo = nuovo.passo or reparto.passo
		elseif nuovo then
			reparto.tipo = nuovo
		end
	end
end

return Dati
