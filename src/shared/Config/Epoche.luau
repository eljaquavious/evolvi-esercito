-- Epoche e truppe. Per aggiungere un'epoca: una voce in Lista e le sue truppe in Truppe.
-- Le classi seguono il triangolo di Battaglia.BATTE:
-- Fanteria batte Cavalleria, Cavalleria batte Tiratore, Tiratore batte Fanteria.
-- Le distanze sono in caselle, la cadenza in attacchi al secondo.

local Epoche = {}

Epoche.Lista = {
	{
		id = "Medievale",
		nome = "Medievale",
		colore = Color3.fromRGB(176, 128, 74),
		truppe = { "Spadaccino", "Arciere", "Cavaliere" },
	},
	{
		id = "Novecento",
		nome = "Novecento",
		colore = Color3.fromRGB(110, 124, 76),
		truppe = { "Fante", "Mitragliere", "CarroArmato" },
	},
}

Epoche.Truppe = {
	Spadaccino = {
		id = "Spadaccino",
		nome = "Spadaccino",
		epoca = "Medievale",
		classe = "Fanteria",
		descrizione = "Resistente, combatte corpo a corpo.",
		hp = 130,
		danno = 14,
		cadenza = 1.0,
		gittata = 1.1,
		velocita = 1.4,
	},
	Arciere = {
		id = "Arciere",
		nome = "Arciere",
		epoca = "Medievale",
		classe = "Tiratore",
		descrizione = "Colpisce da lontano, fragile.",
		hp = 70,
		danno = 11,
		cadenza = 0.9,
		gittata = 4.5,
		velocita = 1.2,
	},
	Cavaliere = {
		id = "Cavaliere",
		nome = "Cavaliere",
		epoca = "Medievale",
		classe = "Cavalleria",
		descrizione = "Veloce, piomba sui tiratori.",
		hp = 140,
		danno = 16,
		cadenza = 0.8,
		gittata = 1.2,
		velocita = 2.6,
	},
	Fante = {
		id = "Fante",
		nome = "Fante",
		epoca = "Novecento",
		classe = "Fanteria",
		descrizione = "Fucile e baionetta, solido.",
		hp = 210,
		danno = 22,
		cadenza = 1.0,
		gittata = 2.5,
		velocita = 1.4,
	},
	Mitragliere = {
		id = "Mitragliere",
		nome = "Mitragliere",
		epoca = "Novecento",
		classe = "Tiratore",
		descrizione = "Raffiche rapide da lontano, lento.",
		hp = 120,
		danno = 8,
		cadenza = 3.0,
		gittata = 5.0,
		velocita = 0.9,
	},
	CarroArmato = {
		id = "CarroArmato",
		nome = "Carro armato",
		epoca = "Novecento",
		classe = "Cavalleria",
		descrizione = "Corazzato, spara colpi pesanti.",
		hp = 330,
		danno = 42,
		cadenza = 0.5,
		gittata = 3.5,
		velocita = 1.3,
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

return Epoche
