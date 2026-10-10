-- Epoche e reggimenti. Per aggiungere un'epoca: una voce in Lista e i suoi reggimenti in Truppe
-- (più il modello del soldato in Shared/Modelli).
-- I nomi visibili ai giocatori sono in inglese.
--
-- Ogni carta è un reggimento: "soldati" è quanti modelli si vedono, hp e danno sono del reggimento intero.
-- Classi (triangolo di Battaglia.BATTE): Infantry batte Cavalry, Cavalry batte Ranged, Ranged batte Infantry.
-- Distanze in caselle, cadenza in attacchi al secondo, armatura = quota di danno assorbita (0-1),
-- carica = moltiplicatore del primo colpo in mischia, area = quota di danno ai reggimenti vicini al bersaglio.

local Epoche = {}

Epoche.Classi = {
	Fanteria = { nome = "Infantry", sigla = "INF" },
	Cavalleria = { nome = "Cavalry", sigla = "CAV" },
	Tiratore = { nome = "Ranged", sigla = "RNG" },
}

Epoche.Lista = {
	{
		id = "Medievale",
		nome = "Medieval",
		colore = Color3.fromRGB(176, 128, 74),
		truppe = { "Spadaccino", "Arciere", "Cavaliere" },
		mazzoIniziale = { "Spadaccino", "Spadaccino", "Spadaccino", "Arciere", "Arciere", "Cavaliere" },
	},
	{
		id = "Novecento",
		nome = "20th Century",
		colore = Color3.fromRGB(110, 124, 76),
		truppe = { "Fante", "Mitragliere", "CarroArmato" },
		mazzoIniziale = { "Fante", "Fante", "Mitragliere", "CarroArmato" },
	},
}

Epoche.Truppe = {
	Spadaccino = {
		id = "Spadaccino",
		nome = "Swordsmen",
		epoca = "Medievale",
		classe = "Fanteria",
		descrizione = "Shield wall. Holds the line against cavalry.",
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
		nome = "Archers",
		epoca = "Medievale",
		classe = "Tiratore",
		descrizione = "Volleys from afar. Weak if caught in melee.",
		soldati = 8,
		hp = 230,
		danno = 27,
		cadenza = 0.8,
		gittata = 3.6,
		velocita = 0.9,
		armatura = 0.05,
	},
	Cavaliere = {
		id = "Cavaliere",
		nome = "Knights",
		epoca = "Medievale",
		classe = "Cavalleria",
		descrizione = "Fast riders. Devastating charge on archers.",
		soldati = 5,
		hp = 430,
		danno = 34,
		cadenza = 0.8,
		gittata = 1.2,
		velocita = 2.0,
		armatura = 0.2,
		carica = 2.2,
	},
	Fante = {
		id = "Fante",
		nome = "Riflemen",
		epoca = "Novecento",
		classe = "Fanteria",
		descrizione = "Rifles and bayonets. Solid all-rounders.",
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
		nome = "Machine Gunners",
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
		nome = "Tank",
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
}

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
