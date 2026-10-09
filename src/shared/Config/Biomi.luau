-- Biomi delle mappe di battaglia. La decorazione di ogni bioma è costruita da Server/Arena.

local Biomi = {}

Biomi.Ordine = { "Pianeggiante", "Collinoso", "Desertico", "Montagnoso", "Innevato" }

Biomi.Dati = {
	Pianeggiante = {
		nome = "Pianeggiante",
		terreno = Color3.fromRGB(98, 150, 70),
		materiale = Enum.Material.Grass,
		casellaA = Color3.fromRGB(122, 170, 88),
		casellaB = Color3.fromRGB(108, 156, 76),
		nebbia = Color3.fromRGB(190, 220, 240),
	},
	Collinoso = {
		nome = "Collinoso",
		terreno = Color3.fromRGB(86, 136, 66),
		materiale = Enum.Material.Grass,
		casellaA = Color3.fromRGB(140, 164, 92),
		casellaB = Color3.fromRGB(124, 150, 80),
		nebbia = Color3.fromRGB(200, 222, 230),
	},
	Desertico = {
		nome = "Desertico",
		terreno = Color3.fromRGB(222, 192, 130),
		materiale = Enum.Material.Sand,
		casellaA = Color3.fromRGB(236, 208, 150),
		casellaB = Color3.fromRGB(220, 190, 132),
		nebbia = Color3.fromRGB(245, 225, 190),
	},
	Montagnoso = {
		nome = "Montagnoso",
		terreno = Color3.fromRGB(112, 110, 104),
		materiale = Enum.Material.Slate,
		casellaA = Color3.fromRGB(150, 146, 136),
		casellaB = Color3.fromRGB(132, 128, 120),
		nebbia = Color3.fromRGB(180, 186, 196),
	},
	Innevato = {
		nome = "Innevato",
		terreno = Color3.fromRGB(236, 242, 248),
		materiale = Enum.Material.Snow,
		casellaA = Color3.fromRGB(226, 234, 242),
		casellaB = Color3.fromRGB(206, 216, 228),
		nebbia = Color3.fromRGB(230, 236, 244),
	},
}

return Biomi
