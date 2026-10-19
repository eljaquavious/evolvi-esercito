-- Luci, atmosfera ed effetti di colore per tutto il gioco.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Luci = require(ReplicatedStorage.Shared.Config.Luci)

local Ambiente = {}

local function effetto(classe, nome, proprieta)
	local esistente = Lighting:FindFirstChildOfClass(classe)
	local e = esistente or Instance.new(classe)
	e.Name = nome
	for k, v in pairs(proprieta) do
		e[k] = v
	end
	e.Parent = Lighting
	return e
end

function Ambiente.imposta()
	-- La tecnologia di luce (Future, ombre vere da ogni oggetto) è in default.project.json: uno script non
	-- la può cambiare. I valori sono il preset "campo" di Config/Luci; in lobby il client mette il suo.
	local preset = Luci.campo
	for k, v in pairs(preset.Lighting) do
		Lighting[k] = v
	end
	Lighting.GlobalShadows = true

	effetto("Atmosphere", "Atmosfera", preset.Atmosphere)
	effetto("BloomEffect", "Bagliore", preset.BloomEffect)
	effetto("SunRaysEffect", "RaggiDiSole", preset.SunRaysEffect)
	effetto("ColorCorrectionEffect", "Colore", preset.ColorCorrectionEffect)
	effetto("DepthOfFieldEffect", "Profondita", preset.DepthOfFieldEffect)

	-- Nuvole vere nel cielo (al posto del cielo vuoto).
	local terreno = workspace.Terrain
	local nuvole = terreno:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	for k, v in pairs(preset.Clouds) do
		nuvole[k] = v
	end
	nuvole.Parent = terreno

	-- Colori del terreno un po' più naturali (meno saturi). Il colore moltiplica la texture: se in
	-- MaterialService c'è un materiale fotografico per quel tipo di terreno resta bianco, così la foto si
	-- vede com'è (prima l'erba diventava verde scuro piatto e il fango quasi nero).
	local MaterialService = game:GetService("MaterialService")
	local colori = {
		[Enum.Material.Grass] = Color3.fromRGB(98, 118, 60),
		[Enum.Material.LeafyGrass] = Color3.fromRGB(104, 120, 66),
		[Enum.Material.Ground] = Color3.fromRGB(118, 104, 78),
		[Enum.Material.Mud] = Color3.fromRGB(96, 80, 62),
		[Enum.Material.Sand] = Color3.fromRGB(176, 154, 116),
		[Enum.Material.Rock] = Color3.fromRGB(112, 110, 106),
		[Enum.Material.Sandstone] = false,
		[Enum.Material.Snow] = false,
		[Enum.Material.Ice] = false,
		[Enum.Material.Cobblestone] = false,
		[Enum.Material.Salt] = false, -- i lastrici di Costantinopoli (MaterialService): bianco, la texture è già colorata
		[Enum.Material.Asphalt] = false,
	}
	-- Con la foto però l'erba ha un colore suo: Grass colora anche i fili d'erba 3D (bianco = verde acido) e
	-- LeafyGrass un po' meno saturo, così il prato fotografico non è troppo acceso.
	-- La sabbia fotografica da sola è grigiastra (sembrava neve sporca): una tinta calda la fa dorata, e
	-- un po' meno calda l'arenaria.
	-- Il ghiaccio del lago (T4_Ice003) è verdastro: un filo di blu-grigio lo fa sembrare ghiaccio d'acqua dolce.
	local coloriFoto = {
		[Enum.Material.Grass] = Color3.fromRGB(160, 168, 112),
		[Enum.Material.LeafyGrass] = Color3.fromRGB(225, 212, 180),
		[Enum.Material.Sand] = Color3.fromRGB(255, 222, 168),
		[Enum.Material.Sandstone] = Color3.fromRGB(250, 228, 196),
		[Enum.Material.Ice] = Color3.fromRGB(228, 238, 246),
	}
	for materiale, colore in pairs(colori) do
		local ok, foto = pcall(MaterialService.GetBaseMaterialOverride, MaterialService, materiale)
		if ok and foto ~= "" then
			terreno:SetMaterialColor(materiale, coloriFoto[materiale] or Color3.new(1, 1, 1))
		elseif colore then
			terreno:SetMaterialColor(materiale, colore)
		end
	end
end

return Ambiente
