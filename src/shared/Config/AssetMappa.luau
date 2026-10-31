-- Mappa della campagna a pixel (tools/blender/mappa_pixel.py, caricata con tools/carica-truppe.ps1 -Prefisso "EYA mappa").
-- Un Model con le MeshPart "Terra_<x>_<y>" (piastrelle di terra, una macchia sola senza righe tra i quadrati) e
-- "Bordo_<x>_<y>" (il contorno nero della costa).
-- riferimento = centro di un pezzo rispetto al centro della mappa (MappaEuropa.CENTRO): serve a rimettere il
-- modello al suo posto qualunque spostamento faccia l'importazione.

return {
	id = 115905704272872,
	riferimento = { nome = "Terra_0_0", centro = Vector3.new(352, 0.4, 280) },
	-- Verde tinta unita un po' più scuro, contorno nero spesso, niente sentieri (Mattia, 1/11/2026).
	terra = Color3.fromRGB(56, 124, 46),
	bordo = Color3.fromRGB(14, 16, 12),
	mare = Color3.fromRGB(40, 52, 76),
	cornice = Color3.fromRGB(24, 31, 46),
}
