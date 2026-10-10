-- Generato da tools/converti_mesh.py dal modello Blender: non modificare a mano.
-- 6360 vertici, 4372 triangoli, texture 512x512. Misure in metri, assi di Roblox.
return {
	versione = 1,
	minimo = { -4.90000, -0.50000, -6.18924 },
	massimo = { 4.90000, 7.48000, 4.90000 },
	ossa = {
		{ nome = "bacino", padre = nil, posizione = { 0.00000, 1.00000, 0.00000 } },
		{ nome = "tiro1", padre = "bacino", posizione = { 2.10000, 5.30000, -3.90000 } },
		{ nome = "tiro2", padre = "bacino", posizione = { -2.10000, 5.30000, -3.90000 } },
		{ nome = "tiro3", padre = "bacino", posizione = { 0.00000, 4.60000, -4.10000 } },
		{ nome = "tiro4", padre = "bacino", posizione = { 3.50000, 4.90000, 3.50000 } },
		{ nome = "tiro5", padre = "bacino", posizione = { -3.50000, 4.90000, 3.50000 } },
	},
	vertici = 6360,
	triangoli = 4372,
	lunghezzaGeometria = 159800,
	geometria = require(script.Geometria),
	lato = 512,
	lunghezzaTexture = 786432,
	texture = table.concat({ require(script.Texture1), require(script.Texture2), require(script.Texture3) }),
}
