-- Forzieri 3D delle casse (tools/blender/forzieri.py, caricati con tools/carica-truppe.ps1 -Prefisso "EYA forziere").
-- Ogni asset è un Model con due MeshPart: "Base" e "Coperchio".
-- cerniera = dove gira il coperchio, in frazioni del suo ingombro (Coperchio.Size) dal centro, assi di Roblox:
--   dietro (+Z) e un po' sotto il centro. misure = ingombro del forziere chiuso in Blender (studs), per le proporzioni.

return {
	CassaPiccola = { id = 125609266613869, cerniera = Vector3.new(0, -0.2969, 0.5), misure = Vector3.new(4.16, 3.12, 3.05) },
	CassaMedia = { id = 129942498589694, cerniera = Vector3.new(0, -0.2969, 0.5), misure = Vector3.new(4.43, 3.12, 3.05) },
	CassaGrande = { id = 116790773172270, cerniera = Vector3.new(0, -0.3076, 0.5), misure = Vector3.new(4.43, 3.51, 3.05) },
	ArmeriaPiccola = { id = 73416329701204, cerniera = Vector3.new(0, -0.2969, 0.5), misure = Vector3.new(4.43, 3.12, 3.05) },
	ArmeriaMedia = { id = 96441901227745, cerniera = Vector3.new(0, -0.3076, 0.5), misure = Vector3.new(4.43, 3.2, 3.05) },
	ArmeriaGrande = { id = 106101776059848, cerniera = Vector3.new(0, -0.3076, 0.5), misure = Vector3.new(4.43, 3.51, 3.05) },
}
