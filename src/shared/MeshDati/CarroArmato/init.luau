-- Generato da tools/blocchi (Sherman con forme arrotondate): non modificare a mano.
-- 21378 vertici, 13728 triangoli, texture 1024x1024. Misure in metri, assi di Roblox.
return {
	versione = 1,
	minimo = { -1.32200, 0.00000, -3.35000 },
	massimo = { 1.32200, 3.30000, 2.92784 },
	ossa = {
		{ nome = "bacino", padre = nil, posizione = { 0.00000, 1.00000, 0.00000 } },
		{ nome = "torretta", padre = "bacino", posizione = { 0.00000, 1.86000, 0.25000 } },
		{ nome = "cannone", padre = "torretta", posizione = { 0.00000, 2.20000, -0.62000 } },
		{ nome = "canna", padre = "cannone", posizione = { 0.00000, 2.20000, -3.35000 } },
	},
	vertici = 21378,
	triangoli = 13728,
	lunghezzaGeometria = 531314,
	geometria = table.concat({ require(script.Geometria1), require(script.Geometria2) }),
	lato = 1024,
	lunghezzaTexture = 3145728,
	texture = table.concat({ require(script.Texture1), require(script.Texture2) }),
}
