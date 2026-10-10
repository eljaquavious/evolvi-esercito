-- Generato da tools/converti_mesh.py dal modello Blender: non modificare a mano.
-- 4286 vertici, 3497 triangoli, texture 512x512. Misure in metri, assi di Roblox.
return {
	versione = 1,
	minimo = { -5.80009, -0.43077, -5.56524 },
	massimo = { 5.80052, 4.90000, 5.60034 },
	ossa = {
		{ nome = "bacino", padre = nil, posizione = { 0.00000, 1.00000, 0.00000 } },
		{ nome = "tiro1", padre = "bacino", posizione = { 1.45000, 1.35000, -2.95000 } },
		{ nome = "tiro2", padre = "bacino", posizione = { -1.45000, 1.35000, -2.95000 } },
		{ nome = "tiro3", padre = "bacino", posizione = { -1.50000, 3.50000, -1.00000 } },
		{ nome = "tiro4", padre = "bacino", posizione = { 3.90000, 1.00000, -2.20000 } },
		{ nome = "tiro5", padre = "bacino", posizione = { -3.90000, 1.00000, -2.20000 } },
	},
	vertici = 4286,
	triangoli = 3497,
	lunghezzaGeometria = 110996,
	geometria = require(script.Geometria),
	lato = 512,
	lunghezzaTexture = 786432,
	texture = table.concat({ require(script.Texture1), require(script.Texture2), require(script.Texture3) }),
}
