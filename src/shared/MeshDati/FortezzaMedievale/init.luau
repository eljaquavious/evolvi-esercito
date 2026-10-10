-- Generato da tools/converti_mesh.py dal modello Blender: non modificare a mano.
-- 8468 vertici, 4840 triangoli, texture 512x512. Misure in metri, assi di Roblox.
return {
	versione = 1,
	minimo = { -4.72000, -0.50000, -6.95000 },
	massimo = { 4.72000, 11.60000, 4.72000 },
	ossa = {
		{ nome = "bacino", padre = nil, posizione = { 0.00000, 1.00000, 0.00000 } },
		{ nome = "tiro1", padre = "bacino", posizione = { 3.20000, 5.90000, -3.20000 } },
		{ nome = "tiro2", padre = "bacino", posizione = { -3.20000, 5.90000, -3.20000 } },
		{ nome = "tiro3", padre = "bacino", posizione = { 3.20000, 5.90000, 3.20000 } },
		{ nome = "tiro4", padre = "bacino", posizione = { -3.20000, 5.90000, 3.20000 } },
		{ nome = "tiro5", padre = "bacino", posizione = { 0.00000, 6.30000, -4.10000 } },
		{ nome = "tiro6", padre = "bacino", posizione = { 0.00000, 8.90000, 0.70000 } },
	},
	vertici = 8468,
	triangoli = 4840,
	lunghezzaGeometria = 206876,
	geometria = require(script.Geometria),
	lato = 512,
	lunghezzaTexture = 786432,
	texture = table.concat({ require(script.Texture1), require(script.Texture2), require(script.Texture3), require(script.Texture4) }),
}
