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

-- Canne, 216 a.C.: le legioni sfondano il centro di Annibale, che arretra apposta; i fanti africani
-- chiudono ai lati e la cavalleria punica, messa in fuga quella romana, chiude alle spalle.
Dati["Cannae"] = {
	durata = 31.5,
	-- "Bravest Of The Braves" (Kosinus, APM), dalla libreria musicale di Roblox: si può usare in ogni gioco.
	musica = { id = "rbxassetid://1839315075", volume = 0.7 },
	-- Il fiume (l'Ofanto) attraversa il campo a z = 0: la battaglia si svolge sulla riva sud.
	origine = { 0, -42 },
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
			{ t = 0, x = -62, z = 18, a = 180 }, { t = 8.5 }, { t = 12, x = -50, z = -24 }, { t = 15.5, x = -72, z = -66 },
			{ t = 19.5, x = -32, z = -26, a = 45 }, { t = 23, x = -11, z = -8, a = 0 }, { t = 31, z = -7 },
		} },
		{ id = "cavalleriaD", tipo = "Compagno", squadra = "nemico", file = 3, righe = 2, passo = 5, tappe = {
			{ t = 0, x = 62, z = 18, a = 180 }, { t = 8.5 }, { t = 12, x = 50, z = -24 }, { t = 15.5, x = 72, z = -66 },
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

return Dati
