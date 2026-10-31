-- Mappa della campagna a pixel (tools/blender/mappa_pixel.py, caricata con tools/carica-truppe.ps1 -Prefisso "EYA mappa").
-- Un Model con le MeshPart "Terra_<x>_<y>" (piastrelle di terra) e "Sentiero_<n>" (piastrelle dei sentieri).
-- riferimento = centro di un pezzo rispetto al centro della mappa (MappaEuropa.CENTRO): serve a rimettere il
-- modello al suo posto qualunque spostamento faccia l'importazione.

return {
	id = 139595262339860,
	riferimento = { nome = "Terra_0_0", centro = Vector3.new(352, 0.4, 280) },
	-- Il colore (verde tinta unita, sentieri di terra battuta) e il bordo nero sono nella texture del modello
	-- (Mattia, 1/11/2026). Questi servono solo se la texture manca.
	terra = Color3.fromRGB(96, 172, 72),
	sentiero = Color3.fromRGB(178, 150, 98),
	mare = Color3.fromRGB(40, 52, 76),
	cornice = Color3.fromRGB(24, 31, 46),
}
