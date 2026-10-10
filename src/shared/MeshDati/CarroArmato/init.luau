-- Generato da tools/converti_mesh.py dal modello Blender: non modificare a mano.
-- 6245 vertici, 5156 triangoli, texture 256x256. Misure in metri, assi di Roblox.
return {
	versione = 1,
	minimo = { -1.35500, -0.06000, -3.59000 },
	massimo = { 1.32100, 3.88000, 3.01960 },
	ossa = {
		{ nome = "bacino", padre = nil, posizione = { 0.00000, 1.00000, 0.00000 } },
		{ nome = "torretta", padre = "bacino", posizione = { 0.00000, 1.88000, -0.15000 } },
		{ nome = "cannone", padre = "torretta", posizione = { 0.00000, 2.28000, -1.02000 } },
		{ nome = "canna", padre = "cannone", posizione = { 0.00000, 2.28000, -3.59000 } },
	},
	vertici = 6245,
	triangoli = 5156,
	lunghezzaGeometria = 162089,
	geometria = require(script.Geometria),
	lato = 256,
	lunghezzaTexture = 196608,
	texture = require(script.Texture),
}
