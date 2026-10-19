-- Epoche, reggimenti storici, comandanti e fortezze. Per aggiungere un'epoca: una voce in Lista,
-- i suoi reggimenti in Truppe e i modelli in Shared/Modelli. I nomi visibili ai giocatori sono in inglese.
--
-- Ogni carta è un reggimento: "soldati" è quanti modelli si vedono, hp e danno sono del reggimento intero.
-- Classi (triangolo di Battaglia.BATTE): Infantry batte Cavalry, Cavalry batte Ranged, Ranged batte Infantry.
-- Distanze in caselle, cadenza in attacchi al secondo, armatura = quota di danno assorbita (0-1),
-- carica = moltiplicatore del primo colpo in mischia, area = quota di danno ai reggimenti vicini al bersaglio,
-- testuggine = moltiplicatore del danno subito da reggimenti a distanza,
-- aura (comandanti) = danno in più per gli alleati vicini.

local Epoche = {}

Epoche.Classi = {
	Fanteria = { nome = "Infantry", sigla = "INF" },
	Cavalleria = { nome = "Cavalry", sigla = "CAV" },
	Tiratore = { nome = "Ranged", sigla = "RNG" },
	Fortezza = { nome = "Fortress", sigla = "FORT" },
}

-- truppe = tutte le carte dell'epoca: prima le tre del mazzo iniziale, poi quelle delle armate nemiche
-- (Campagna.Battaglie[].armata), che si ottengono vincendo le loro battaglie.
Epoche.Lista = {
	{
		id = "Antica",
		nome = "Antiquity",
		colore = Color3.fromRGB(196, 74, 56),
		truppe = {
			"Legionario", "ArciereCretese", "Compagno", "Oplita",
			"Immortale", "ArcierePersiano", "CavalleriaPersiana",
			"LanciereLibico", "FrombolieroBaleare", "CavalleriaNumidica", "Elefante",
			"GuerrieroGallico", "ArciereGallico", "CavalleriaGallica", "CavalleriaGermanica",
		},
		comandanti = { "Annibale", "Cesare" },
		fortezza = "FortezzaAntica",
		mazzoIniziale = { "Legionario", "Legionario", "Legionario", "ArciereCretese", "ArciereCretese", "Compagno" },
	},
	{
		id = "Medievale",
		nome = "Medieval",
		colore = Color3.fromRGB(176, 128, 74),
		truppe = {
			"Spadaccino", "Arciere", "Cavaliere",
			"FanteUmayyade", "ArciereArabo", "CavalleriaAraba",
			"FanteNormanno", "ArciereNormanno", "CavaliereNormanno",
			"FanteAyyubide", "ArciereAyyubide", "Mamelucco",
			"SergenteTeutonico", "BalestriereTeutonico", "CavaliereTeutonico",
			"UomoDArme", "BalestriereGenovese",
		},
		comandanti = { "Guglielmo", "Saladino", "Giovanna" },
		fortezza = "FortezzaMedievale",
		mazzoIniziale = { "Spadaccino", "Spadaccino", "Spadaccino", "Arciere", "Arciere", "Cavaliere" },
	},
	{
		id = "Polvere",
		nome = "Age of Gunpowder",
		colore = Color3.fromRGB(150, 70, 60),
		truppe = {
			"PicchiereSvedese", "MoschettiereSvedese", "CorazziereSvedese",
			"Giannizzero", "CannoneOttomano", "Sipahi",
			"FanteriaDiLinea", "Artiglieria", "Corazziere",
		},
		comandanti = { "GustavoAdolfo", "Napoleone" },
		fortezza = "FortezzaModerna",
		mazzoIniziale = { "PicchiereSvedese", "PicchiereSvedese", "PicchiereSvedese", "MoschettiereSvedese", "MoschettiereSvedese", "CorazziereSvedese" },
	},
	{
		id = "Novecento",
		nome = "20th Century",
		colore = Color3.fromRGB(110, 124, 76),
		truppe = {
			"Fante", "Mitragliere", "CarroArmato",
			"FanteOttomano", "MitraglieriOttomani",
			"Stosstruppen", "MitraglieriTedeschi",
			"FanteBritannico", "CarroMarkV",
			"FucilieriSovietici", "MitraglieriSovietici", "T34",
			"Granatieri", "MG42", "Panzer",
			"FanteFranciaLibera",
		},
		comandanti = { "Foch", "Rommel", "DeGaulle" },
		fortezza = "FortezzaNovecento",
		mazzoIniziale = { "Fante", "Fante", "Fante", "Mitragliere", "Mitragliere", "CarroArmato" },
	},
}

Epoche.Truppe = {
	-- Antichità ---------------------------------------------------------------
	Legionario = {
		id = "Legionario",
		origine = "Rome",
		nome = "Roman Legionaries",
		epoca = "Antica",
		classe = "Fanteria",
		descrizione = "Testudo formation: shields up against arrows.",
		soldati = 8,
		hp = 380,
		danno = 26,
		cadenza = 1.0,
		gittata = 1.1,
		velocita = 0.9,
		armatura = 0.25,
		testuggine = 0.7,
		-- Ogni legionario lancia il pilum una volta, prima di arrivare in mischia.
		lancio = { gittata = 2.2, danno = 1.6 },
	},
	ArciereCretese = {
		id = "ArciereCretese",
		origine = "Greece",
		nome = "Cretan Archers",
		epoca = "Antica",
		classe = "Tiratore",
		descrizione = "Famed mercenary bowmen. Quick volleys.",
		soldati = 8,
		hp = 200,
		danno = 21,
		cadenza = 0.95,
		gittata = 3.4,
		velocita = 1.0,
		armatura = 0.05,
	},
	Compagno = {
		id = "Compagno",
		origine = "Greece",
		nome = "Companion Cavalry",
		epoca = "Antica",
		classe = "Cavalleria",
		descrizione = "Alexander's elite riders. Brutal charge.",
		soldati = 5,
		hp = 360,
		danno = 29,
		cadenza = 0.8,
		gittata = 1.2,
		velocita = 2.1,
		armatura = 0.15,
		carica = 2.4,
	},

	-- Medioevo ----------------------------------------------------------------
	Spadaccino = {
		id = "Spadaccino",
		origine = "England",
		nome = "Saxon Huscarls",
		epoca = "Medievale",
		classe = "Fanteria",
		descrizione = "Shield wall and long axes. Holds the line.",
		soldati = 8,
		hp = 420,
		danno = 30,
		cadenza = 1.0,
		gittata = 1.1,
		velocita = 1.0,
		armatura = 0.25,
	},
	Arciere = {
		id = "Arciere",
		origine = "England",
		nome = "English Longbowmen",
		epoca = "Medievale",
		classe = "Tiratore",
		descrizione = "Longbows that outrange every archer.",
		soldati = 8,
		hp = 230,
		danno = 27,
		cadenza = 0.8,
		gittata = 3.9,
		velocita = 0.9,
		armatura = 0.05,
	},
	Cavaliere = {
		id = "Cavaliere",
		origine = "France",
		nome = "French Knights",
		epoca = "Medievale",
		classe = "Cavalleria",
		descrizione = "The flower of French chivalry. Devastating lance charge.",
		soldati = 5,
		hp = 430,
		danno = 34,
		cadenza = 0.8,
		gittata = 1.2,
		velocita = 2.0,
		armatura = 0.2,
		carica = 2.2,
	},

	-- Novecento ---------------------------------------------------------------
	Fante = {
		id = "Fante",
		origine = "France",
		nome = "French Poilus",
		epoca = "Novecento",
		classe = "Fanteria",
		descrizione = "Rifles and bayonets. They shall not pass.",
		soldati = 8,
		hp = 640,
		danno = 46,
		cadenza = 1.0,
		gittata = 2.2,
		velocita = 1.0,
		armatura = 0.15,
	},
	Mitragliere = {
		id = "Mitragliere",
		origine = "France",
		nome = "Machine Gun Crew",
		epoca = "Novecento",
		classe = "Tiratore",
		descrizione = "Suppressing fire. Shreds infantry.",
		soldati = 3,
		hp = 400,
		danno = 16,
		cadenza = 3.0,
		gittata = 4.0,
		velocita = 0.7,
		armatura = 0.15,
	},
	CarroArmato = {
		id = "CarroArmato",
		origine = "USA",
		nome = "Sherman Tank",
		epoca = "Novecento",
		classe = "Cavalleria",
		descrizione = "Armored. Shells hit everything nearby.",
		soldati = 1,
		hp = 1150,
		danno = 105,
		cadenza = 0.45,
		gittata = 3.0,
		velocita = 1.0,
		armatura = 0.45,
		area = 0.4,
	},

	-- Comandanti: boss della campagna; battuti la prima volta, diventano carte leggendarie ----------
	Annibale = {
		id = "Annibale",
		origine = "Carthage",
		abilita = { nome = "Pincer Attack", velocita = 0.3, danno = 0.12, durata = 8 },
		nome = "Hannibal Barca",
		epoca = "Antica",
		classe = "Cavalleria",
		comandante = true,
		descrizione = "Carthage's genius. Nearby allies hit harder.",
		soldati = 1,
		hp = 620,
		danno = 36,
		cadenza = 0.9,
		gittata = 1.2,
		velocita = 1.8,
		armatura = 0.3,
		carica = 1.8,
		aura = 0.15,
	},
	Cesare = {
		id = "Cesare",
		origine = "Rome",
		abilita = { nome = "Veni, Vidi, Vici", danno = 0.2, durata = 8 },
		nome = "Julius Caesar",
		epoca = "Antica",
		classe = "Fanteria",
		comandante = true,
		descrizione = "Veni, vidi, vici. Nearby allies hit harder.",
		soldati = 1,
		hp = 700,
		danno = 36,
		cadenza = 1.0,
		gittata = 1.2,
		velocita = 1.0,
		armatura = 0.35,
		aura = 0.15,
	},
	Guglielmo = {
		id = "Guglielmo",
		origine = "France",
		abilita = { nome = "Norman Charge", cariche = true, danno = 0.15, durata = 6 },
		nome = "William the Conqueror",
		epoca = "Medievale",
		classe = "Cavalleria",
		comandante = true,
		descrizione = "Duke of Normandy. Nearby allies hit harder.",
		soldati = 1,
		hp = 700,
		danno = 42,
		cadenza = 0.9,
		gittata = 1.2,
		velocita = 1.8,
		armatura = 0.35,
		carica = 2.0,
		aura = 0.15,
	},
	Giovanna = {
		id = "Giovanna",
		origine = "France",
		abilita = { nome = "Divine Inspiration", cura = 0.15, difesa = 0.15, durata = 8 },
		nome = "Joan of Arc",
		epoca = "Medievale",
		classe = "Fanteria",
		comandante = true,
		descrizione = "The Maid of Orleans. Nearby allies hit much harder.",
		soldati = 1,
		hp = 780,
		danno = 40,
		cadenza = 1.0,
		gittata = 1.2,
		velocita = 1.1,
		armatura = 0.4,
		aura = 0.15,
	},
	Foch = {
		id = "Foch",
		origine = "France",
		abilita = { nome = "Grand Offensive", danno = 0.2, velocita = 0.15, durata = 8 },
		nome = "Ferdinand Foch",
		epoca = "Novecento",
		classe = "Fanteria",
		comandante = true,
		descrizione = "Marshal of France. Nearby allies hit harder.",
		soldati = 1,
		hp = 1000,
		danno = 58,
		cadenza = 1.0,
		gittata = 2.4,
		velocita = 1.0,
		armatura = 0.3,
		aura = 0.15,
	},
	DeGaulle = {
		id = "DeGaulle",
		origine = "France",
		abilita = { nome = "Free France", difesa = 0.2, danno = 0.1, durata = 10 },
		nome = "Charles de Gaulle",
		epoca = "Novecento",
		classe = "Fanteria",
		comandante = true,
		descrizione = "Leader of Free France. Nearby allies hit much harder.",
		soldati = 1,
		hp = 1100,
		danno = 60,
		cadenza = 1.0,
		gittata = 2.4,
		velocita = 1.0,
		armatura = 0.35,
		aura = 0.2,
	},

	-- Fortezze: difendono il nemico quando ti manca una sola vittoria. Non si muovono e non sono carte. ----
	FortezzaAntica = {
		id = "FortezzaAntica",
		nome = "Hill Fort",
		epoca = "Antica",
		classe = "Fortezza",
		fortezza = true,
		descrizione = "Palisade and watchtowers.",
		soldati = 1,
		hp = 760,
		danno = 40,
		cadenza = 1.0,
		gittata = 4.2,
		velocita = 0,
		armatura = 0.25,
	},
	FortezzaMedievale = {
		id = "FortezzaMedievale",
		nome = "Castle",
		epoca = "Medievale",
		classe = "Fortezza",
		fortezza = true,
		descrizione = "Stone walls and towers.",
		soldati = 1,
		hp = 880,
		danno = 50,
		cadenza = 1.0,
		gittata = 4.4,
		velocita = 0,
		armatura = 0.28,
	},
	FortezzaNovecento = {
		id = "FortezzaNovecento",
		nome = "Bunker",
		epoca = "Novecento",
		classe = "Fortezza",
		fortezza = true,
		descrizione = "Concrete and machine guns.",
		soldati = 1,
		hp = 1150,
		danno = 62,
		cadenza = 1.0,
		gittata = 4.6,
		velocita = 0,
		armatura = 0.28,
	},
}


-- Fortezza dell'età della polvere da sparo: forte bastionato a stella con i cannoni.
Epoche.Truppe.FortezzaModerna = {
	id = "FortezzaModerna",
	nome = "Star Fort",
	epoca = "Polvere",
	classe = "Fortezza",
	fortezza = true,
	descrizione = "Bastions, earthworks and cannons.",
	soldati = 1,
	hp = 1000,
	danno = 56,
	cadenza = 1.0,
	gittata = 4.5,
	velocita = 0,
	armatura = 0.28,
}

-- Armate nemiche delle battaglie (Campagna.Battaglie[].armata), fedeli alla storia. Le statistiche partono
-- dall'archetipo della classe nell'epoca (i reggimenti del mazzo iniziale) e cambiano solo dove serve.
local ARCHETIPI = {
	Antica = {
		Fanteria = { soldati = 8, hp = 380, danno = 26, cadenza = 1.0, gittata = 1.1, velocita = 0.9, armatura = 0.22 },
		Tiratore = { soldati = 8, hp = 200, danno = 21, cadenza = 0.95, gittata = 3.4, velocita = 1.0, armatura = 0.05 },
		Cavalleria = { soldati = 5, hp = 360, danno = 29, cadenza = 0.8, gittata = 1.2, velocita = 2.1, armatura = 0.15, carica = 2.2 },
	},
	Medievale = {
		Fanteria = { soldati = 8, hp = 420, danno = 30, cadenza = 1.0, gittata = 1.1, velocita = 1.0, armatura = 0.25 },
		Tiratore = { soldati = 8, hp = 230, danno = 26, cadenza = 0.8, gittata = 3.7, velocita = 0.9, armatura = 0.05 },
		Cavalleria = { soldati = 5, hp = 430, danno = 34, cadenza = 0.8, gittata = 1.2, velocita = 2.0, armatura = 0.2, carica = 2.2 },
	},
	Polvere = {
		Fanteria = { soldati = 8, hp = 520, danno = 36, cadenza = 0.9, gittata = 1.2, velocita = 1.0, armatura = 0.18 },
		Tiratore = { soldati = 8, hp = 300, danno = 34, cadenza = 0.7, gittata = 3.4, velocita = 0.9, armatura = 0.08 },
		Cavalleria = { soldati = 5, hp = 540, danno = 40, cadenza = 0.8, gittata = 1.2, velocita = 2.0, armatura = 0.22, carica = 2.2 },
	},
	Novecento = {
		Fanteria = { soldati = 8, hp = 640, danno = 46, cadenza = 1.0, gittata = 2.2, velocita = 1.0, armatura = 0.15 },
		Tiratore = { soldati = 3, hp = 400, danno = 16, cadenza = 3.0, gittata = 4.0, velocita = 0.7, armatura = 0.15 },
		Cavalleria = { soldati = 1, hp = 1150, danno = 105, cadenza = 0.45, gittata = 3.0, velocita = 1.0, armatura = 0.45, area = 0.4 },
	},
}

local function reggimento(id, epoca, classe, origine, nome, descrizione, cambi)
	local def = table.clone(ARCHETIPI[epoca][classe])
	def.id, def.epoca, def.classe, def.origine, def.nome, def.descrizione = id, epoca, classe, origine, nome, descrizione
	for k, v in pairs(cambi or {}) do
		def[k] = v
	end
	Epoche.Truppe[id] = def
end

-- Antichità --------------------------------------------------------------------------------------------
reggimento("Oplita", "Antica", "Fanteria", "Greece", "Spartan Hoplites", "Three hundred held the pass of Thermopylae.", { hp = 400, armatura = 0.3, danno = 27, velocita = 0.85 })
reggimento("Immortale", "Antica", "Fanteria", "Persia", "Persian Immortals", "The King's guard: ten thousand, always.", { hp = 360, danno = 25, armatura = 0.18, velocita = 1.0 })
reggimento("ArcierePersiano", "Antica", "Tiratore", "Persia", "Persian Archers", "Arrows that blot out the sun.", { cadenza = 1.1, danno = 18 })
reggimento("CavalleriaPersiana", "Antica", "Cavalleria", "Persia", "Persian Cavalry", "Scale-armored riders of the Great King.", { hp = 380, armatura = 0.2 })
reggimento("LanciereLibico", "Antica", "Fanteria", "Carthage", "Libyan Spearmen", "Veterans of Hannibal in Roman armor.", { hp = 400, armatura = 0.24 })
reggimento("FrombolieroBaleare", "Antica", "Tiratore", "Carthage", "Balearic Slingers", "Lead bullets from the islands. Deadly aim.", { danno = 24, gittata = 3.2, cadenza = 0.9 })
reggimento("CavalleriaNumidica", "Antica", "Cavalleria", "Carthage", "Numidian Cavalry", "Light riders with javelins. Fast and elusive.", { velocita = 2.5, hp = 300, armatura = 0.08, carica = 1.8 })
reggimento("Elefante", "Antica", "Cavalleria", "Carthage", "War Elephants", "Living towers that trample everything.", { soldati = 2, hp = 820, danno = 44, velocita = 1.3, armatura = 0.3, carica = 2.6, area = 0.25, veicolo = true })
reggimento("GuerrieroGallico", "Antica", "Fanteria", "Gaul", "Gallic Warriors", "Long swords and a fearsome first charge.", { danno = 30, armatura = 0.12, velocita = 1.1, carica = 1.4 })
reggimento("ArciereGallico", "Antica", "Tiratore", "Gaul", "Gallic Archers", "Hunters of the forests of Gaul.")
reggimento("CavalleriaGallica", "Antica", "Cavalleria", "Gaul", "Gallic Horsemen", "Noble riders in mail, proud and brave.", { armatura = 0.2 })
reggimento("CavalleriaGermanica", "Antica", "Cavalleria", "Rome", "Germanic Cavalry", "Caesar's wild riders from beyond the Rhine.", { danno = 31, armatura = 0.1, velocita = 2.2 })

-- Medioevo ----------------------------------------------------------------------------------------------
reggimento("FanteUmayyade", "Medievale", "Fanteria", "Arabia", "Umayyad Spearmen", "The Caliphate's march into Europe.")
reggimento("ArciereArabo", "Medievale", "Tiratore", "Arabia", "Arab Archers", "Quick volleys from composite bows.", { cadenza = 0.95, danno = 23, gittata = 3.5 })
reggimento("CavalleriaAraba", "Medievale", "Cavalleria", "Arabia", "Arab Cavalry", "Swift desert horsemen.", { velocita = 2.3, hp = 400 })
reggimento("FanteNormanno", "Medievale", "Fanteria", "France", "Norman Spearmen", "Kite shields and spears of Normandy.")
reggimento("ArciereNormanno", "Medievale", "Tiratore", "France", "Norman Archers", "They shot high at Hastings.")
reggimento("CavaliereNormanno", "Medievale", "Cavalleria", "France", "Norman Knights", "William's mailed horsemen.", { armatura = 0.22 })
reggimento("FanteAyyubide", "Medievale", "Fanteria", "Egypt", "Ayyubid Spearmen", "Saladin's quilted infantry.", { hp = 400, velocita = 1.05 })
reggimento("ArciereAyyubide", "Medievale", "Tiratore", "Egypt", "Ayyubid Archers", "Arrows rain on the thirsty crusaders.", { cadenza = 0.95, danno = 24 })
reggimento("Mamelucco", "Medievale", "Cavalleria", "Egypt", "Mamluk Lancers", "Elite slave-soldiers of the Sultan.", { danno = 36, armatura = 0.24 })
reggimento("SergenteTeutonico", "Medievale", "Fanteria", "Germany", "Teutonic Sergeants", "The Order's grey-cloaked foot soldiers.", { armatura = 0.28 })
reggimento("BalestriereTeutonico", "Medievale", "Tiratore", "Germany", "Teutonic Crossbowmen", "Bolts that pierce mail.", { danno = 34, cadenza = 0.6, gittata = 3.4, armatura = 0.12 })
reggimento("CavaliereTeutonico", "Medievale", "Cavalleria", "Germany", "Teutonic Knights", "Iron monks in white mantles.", { hp = 470, armatura = 0.28, velocita = 1.8 })
reggimento("UomoDArme", "Medievale", "Fanteria", "France", "French Men-at-Arms", "Plate armor and poleaxes.", { hp = 450, danno = 33, armatura = 0.32, velocita = 0.85 })
reggimento("BalestriereGenovese", "Medievale", "Tiratore", "France", "Genoese Crossbowmen", "Mercenaries behind tall pavise shields.", { danno = 33, cadenza = 0.6, gittata = 3.5, armatura = 0.14 })

-- Età della polvere da sparo ------------------------------------------------------------------------------
reggimento("PicchiereSvedese", "Polvere", "Fanteria", "Sweden", "Swedish Pikemen", "A hedge of pikes no rider can break.", { carica = nil, armatura = 0.22, danno = 34 })
reggimento("MoschettiereSvedese", "Polvere", "Tiratore", "Sweden", "Swedish Musketeers", "Salvo fire, Gustavus' new way of war.")
reggimento("CorazziereSvedese", "Polvere", "Cavalleria", "Sweden", "Swedish Cuirassiers", "Hakkapeliitta: they charge sword in hand.")
reggimento("Giannizzero", "Polvere", "Fanteria", "Ottoman Empire", "Janissaries", "The Sultan's elite. Muskets, then the blade.", { gittata = 2.0, danno = 38 })
reggimento("CannoneOttomano", "Polvere", "Tiratore", "Ottoman Empire", "Ottoman Bombard", "Giant guns that broke the walls of Constantinople.", { soldati = 2, hp = 360, danno = 90, cadenza = 0.25, gittata = 4.4, velocita = 0.5, armatura = 0.2, area = 0.4, veicolo = true })
reggimento("Sipahi", "Polvere", "Cavalleria", "Ottoman Empire", "Sipahi Cavalry", "Feudal horsemen of the Ottoman Empire.", { velocita = 2.2, armatura = 0.18 })
reggimento("FanteriaDiLinea", "Polvere", "Fanteria", "France", "French Line Infantry", "Muskets, bayonets and the drums of the Empire.", { gittata = 2.0, hp = 540 })
reggimento("Artiglieria", "Polvere", "Tiratore", "France", "French Artillery", "Napoleon's favourite weapon.", { soldati = 2, hp = 380, danno = 75, cadenza = 0.3, gittata = 4.2, velocita = 0.5, armatura = 0.2, area = 0.35, veicolo = true })
reggimento("Corazziere", "Polvere", "Cavalleria", "France", "French Cuirassiers", "Steel breastplates, a wall of horses.", { hp = 580, armatura = 0.28, velocita = 1.8 })

-- Novecento ----------------------------------------------------------------------------------------------
reggimento("FanteOttomano", "Novecento", "Fanteria", "Ottoman Empire", "Ottoman Infantry", "They held the heights of Gallipoli.", { armatura = 0.18 })
reggimento("MitraglieriOttomani", "Novecento", "Tiratore", "Ottoman Empire", "Ottoman Machine Gunners", "Maxim guns on the cliffs.")
reggimento("Stosstruppen", "Novecento", "Fanteria", "Germany", "German Stormtroopers", "Grenades and infiltration tactics.", { danno = 50, velocita = 1.1, armatura = 0.12 })
reggimento("MitraglieriTedeschi", "Novecento", "Tiratore", "Germany", "German Machine Gunners", "The MG 08: the butcher of the Western Front.", { danno = 17 })
reggimento("FanteBritannico", "Novecento", "Fanteria", "Britain", "British Tommies", "Fifteen aimed shots a minute.", { cadenza = 1.1 })
reggimento("CarroMarkV", "Novecento", "Cavalleria", "Britain", "Mark V Tank", "The rhomboid monster that broke the trenches.", { hp = 1000, danno = 70, cadenza = 0.6, gittata = 2.5, velocita = 0.6, armatura = 0.4, area = 0.2, veicolo = true })
reggimento("FucilieriSovietici", "Novecento", "Fanteria", "USSR", "Soviet Riflemen", "Not one step back.", { hp = 680, armatura = 0.12 })
reggimento("MitraglieriSovietici", "Novecento", "Tiratore", "USSR", "Soviet Machine Gunners", "The Maxim on wheels, with its steel shield.", { hp = 430 })
reggimento("T34", "Novecento", "Cavalleria", "USSR", "T-34 Tank", "Sloped armor and wide tracks.", { hp = 1100, danno = 100, velocita = 1.15, veicolo = true })
reggimento("Granatieri", "Novecento", "Fanteria", "Germany", "German Grenadiers", "Veterans of the Atlantic Wall.")
reggimento("MG42", "Novecento", "Tiratore", "Germany", "MG 42 Team", "Hitler's buzzsaw: 1,200 rounds a minute.", { cadenza = 3.6, danno = 15 })
reggimento("Panzer", "Novecento", "Cavalleria", "Germany", "Panzer IV", "The workhorse of the Panzer divisions.", { hp = 1250, danno = 110, velocita = 0.9, armatura = 0.5, veicolo = true })
reggimento("FanteFranciaLibera", "Novecento", "Fanteria", "France", "Free French Infantry", "Leclerc's men, first into Paris.")
Epoche.Truppe.CarroArmato.veicolo = true

-- Comandanti nuovi ---------------------------------------------------------------------------------------
Epoche.Truppe.Saladino = {
	id = "Saladino",
	origine = "Egypt",
	abilita = { nome = "Horns of Hattin", danno = 0.15, velocita = 0.2, durata = 8 },
	nome = "Saladin",
	epoca = "Medievale",
	classe = "Cavalleria",
	comandante = true,
	descrizione = "Sultan of Egypt and Syria. Nearby allies hit harder.",
	soldati = 1,
	hp = 740,
	danno = 42,
	cadenza = 0.9,
	gittata = 1.2,
	velocita = 1.9,
	armatura = 0.32,
	carica = 2.0,
	aura = 0.15,
}
Epoche.Truppe.GustavoAdolfo = {
	id = "GustavoAdolfo",
	origine = "Sweden",
	abilita = { nome = "Swedish Salvo", danno = 0.25, durata = 7 },
	nome = "Gustavus Adolphus",
	epoca = "Polvere",
	classe = "Cavalleria",
	comandante = true,
	descrizione = "The Lion of the North. Nearby allies hit harder.",
	soldati = 1,
	hp = 860,
	danno = 50,
	cadenza = 0.9,
	gittata = 1.2,
	velocita = 1.8,
	armatura = 0.3,
	carica = 2.0,
	aura = 0.15,
}
Epoche.Truppe.Napoleone = {
	id = "Napoleone",
	origine = "France",
	abilita = { nome = "Grande Armée", danno = 0.15, velocita = 0.15, difesa = 0.1, durata = 10 },
	nome = "Napoleon Bonaparte",
	epoca = "Polvere",
	classe = "Fanteria",
	comandante = true,
	descrizione = "Emperor of the French. Nearby allies hit much harder.",
	soldati = 1,
	hp = 920,
	danno = 50,
	cadenza = 1.0,
	gittata = 1.2,
	velocita = 1.0,
	armatura = 0.35,
	aura = 0.2,
}
Epoche.Truppe.Rommel = {
	id = "Rommel",
	origine = "Germany",
	abilita = { nome = "Blitzkrieg", velocita = 0.35, danno = 0.15, cariche = true, durata = 8 },
	nome = "Erwin Rommel",
	epoca = "Novecento",
	classe = "Fanteria",
	comandante = true,
	descrizione = "The Desert Fox. Nearby allies hit harder.",
	soldati = 1,
	hp = 1050,
	danno = 58,
	cadenza = 1.0,
	gittata = 2.4,
	velocita = 1.1,
	armatura = 0.3,
	aura = 0.15,
}

-- Le carte che un giocatore può avere: reggimenti e comandanti, nell'ordine delle epoche.
function Epoche.carte()
	local lista = {}
	for _, epoca in ipairs(Epoche.Lista) do
		for _, tipo in ipairs(epoca.truppe) do
			table.insert(lista, tipo)
		end
		for _, tipo in ipairs(epoca.comandanti) do
			table.insert(lista, tipo)
		end
	end
	return lista
end

-- Testo dell'abilità di un comandante, dai suoi numeri: "+20% damage, +30% speed for 8s".
function Epoche.testoAbilita(def)
	local a = def and def.abilita
	if not a then
		return nil
	end
	local parti = {}
	local function percento(valore, cosa)
		if valore then
			table.insert(parti, ("+%d%% %s"):format(math.floor(valore * 100 + 0.5), cosa))
		end
	end
	if a.cura then
		table.insert(parti, ("heals %d%%"):format(math.floor(a.cura * 100 + 0.5)))
	end
	if a.cariche then
		table.insert(parti, "cavalry charges again")
	end
	percento(a.danno, "damage")
	percento(a.velocita, "speed")
	percento(a.difesa, "defense")
	return ("All your regiments: %s for %ds. Double for %s troops."):format(table.concat(parti, ", "), a.durata, def.origine)
end

function Epoche.indice(id)
	for i, epoca in ipairs(Epoche.Lista) do
		if epoca.id == id then
			return i
		end
	end
	return nil
end

function Epoche.epoca(id)
	return Epoche.Lista[Epoche.indice(id) or 1]
end

return Epoche
