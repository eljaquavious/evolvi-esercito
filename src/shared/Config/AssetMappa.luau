-- Mappa della campagna a pixel (tools/blender/mappa_pixel.py, caricata con tools/carica-truppe.ps1 -Prefisso "EYA mappa").
-- Un Model con le MeshPart "Terra_<x>_<y>" (piastrelle di terra) e "Sentiero_<n>" (piastrelle dei sentieri).
-- riferimento = centro di un pezzo rispetto al centro della mappa (MappaEuropa.CENTRO): serve a rimettere il
-- modello al suo posto qualunque spostamento faccia l'importazione.

return {
	id = 72784027439321,
	riferimento = { nome = "Terra_0_0", centro = Vector3.new(352, 0.4, 280) },
	-- Un solo colore per la terra (Mattia, 31/10/2026: "monocolore"), i sentieri di un tono più scuro.
	terra = Color3.fromRGB(236, 230, 212),
	sentiero = Color3.fromRGB(196, 174, 136),
	mare = Color3.fromRGB(40, 52, 76),
	cornice = Color3.fromRGB(24, 31, 46),
}
