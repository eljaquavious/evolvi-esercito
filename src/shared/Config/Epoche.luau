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

Epoche.Lista = {
	{
		id = "Antica",
		nome = "Antiquity",
		colore = Color3.fromRGB(196, 74, 56),
		truppe = { "Legionario", "ArciereCretese", "Compagno" },
		comandanti = { "Annibale", "Cesare" },
		fortezza = "FortezzaAntica",
		mazzoIniziale = { "Legionario", "Legionario", "Legionario", "ArciereCretese", "ArciereCretese", "Compagno" },
	},
	{
		id = "Medievale",
		nome = "Medieval",
		colore = Color3.fromRGB(176, 128, 74),
		truppe = { "Spadaccino", "Arciere", "Cavaliere" },
		comandanti = { "Guglielmo", "Giovanna" },
		fortezza = "FortezzaMedievale",
		mazzoIniziale = { "Spadaccino", "Spadaccino", "Spadaccino", "Arciere", "Arciere", "Cavaliere" },
	},
	{
		id = "Novecento",
		nome = "20th Century",
		colore = Color3.fromRGB(110, 124, 76),
		truppe = { "Fante", "Mitragliere", "CarroArmato" },
		comandanti = { "Foch", "DeGaulle" },
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
		nome = "Norman Knights",
		epoca = "Medievale",
		classe = "Cavalleria",
		descrizione = "Heavy horsemen. Devastating lance charge.",
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
