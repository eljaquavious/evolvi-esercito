-- Biomi delle mappe di battaglia. Terreno e decorazioni sono costruiti da Server/Arena.

local Biomi = {}

Biomi.Ordine = { "Pianeggiante", "Collinoso", "Desertico", "Montagnoso", "Innevato" }

Biomi.Dati = {
	Pianeggiante = {
		nome = "Plains",
		materiale = Enum.Material.Grass,
		materialeRilievi = Enum.Material.Grass,
		casella = Color3.fromRGB(150, 196, 110),
		atmosfera = Color3.fromRGB(199, 220, 236),
	},
	Collinoso = {
		nome = "Hills",
		materiale = Enum.Material.Grass,
		materialeRilievi = Enum.Material.LeafyGrass,
		casella = Color3.fromRGB(160, 186, 104),
		atmosfera = Color3.fromRGB(206, 222, 226),
	},
	Desertico = {
		nome = "Desert",
		materiale = Enum.Material.Sand,
		materialeRilievi = Enum.Material.Sand,
		casella = Color3.fromRGB(240, 214, 160),
		atmosfera = Color3.fromRGB(246, 222, 184),
	},
	Montagnoso = {
		nome = "Mountains",
		materiale = Enum.Material.Ground,
		materialeRilievi = Enum.Material.Rock,
		casella = Color3.fromRGB(170, 160, 146),
		atmosfera = Color3.fromRGB(184, 192, 204),
	},
	Innevato = {
		nome = "Snow",
		materiale = Enum.Material.Snow,
		materialeRilievi = Enum.Material.Glacier,
		casella = Color3.fromRGB(226, 236, 246),
		atmosfera = Color3.fromRGB(228, 236, 246),
	},
}

return Biomi
