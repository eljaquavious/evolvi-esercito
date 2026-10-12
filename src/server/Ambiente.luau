-- Luci, atmosfera ed effetti di colore per tutto il gioco.

local Lighting = game:GetService("Lighting")

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
	-- Sole del pomeriggio un po' basso: ombre lunghe che danno volume a terreno, alberi e soldati.
	-- La tecnologia di luce (Future, ombre vere da ogni oggetto) è in default.project.json: uno script non
	-- la può cambiare.
	Lighting.ClockTime = 16.2
	Lighting.GeographicLatitude = 41
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(70, 72, 82)
	Lighting.OutdoorAmbient = Color3.fromRGB(138, 140, 150)
	Lighting.EnvironmentDiffuseScale = 1
	-- Poca luce speculare: superfici opache, niente effetto plastica.
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.12
	Lighting.ExposureCompensation = 0.25

	effetto("Atmosphere", "Atmosfera", {
		Density = 0.3,
		Offset = 0.1,
		Color = Color3.fromRGB(196, 210, 226),
		Decay = Color3.fromRGB(112, 118, 132),
		Glare = 0.25,
		Haze = 1.7,
	})
	effetto("BloomEffect", "Bagliore", { Intensity = 0.35, Size = 24, Threshold = 1.8 })
	effetto("SunRaysEffect", "RaggiDiSole", { Intensity = 0.05, Spread = 0.6 })
	effetto("ColorCorrectionEffect", "Colore", {
		Brightness = 0.01,
		Contrast = 0.12,
		Saturation = 0.04,
		TintColor = Color3.fromRGB(255, 250, 242),
	})
	effetto("DepthOfFieldEffect", "Profondita", {
		Enabled = true,
		FarIntensity = 0.12,
		FocusDistance = 80,
		InFocusRadius = 70,
		NearIntensity = 0,
	})

	-- Nuvole vere nel cielo (al posto del cielo vuoto).
	local terreno = workspace.Terrain
	local nuvole = terreno:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	nuvole.Cover = 0.5
	nuvole.Density = 0.55
	nuvole.Color = Color3.fromRGB(250, 250, 252)
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
	}
	for materiale, colore in pairs(colori) do
		local ok, foto = pcall(MaterialService.GetBaseMaterialOverride, MaterialService, materiale)
		if ok and foto ~= "" then
			terreno:SetMaterialColor(materiale, Color3.new(1, 1, 1))
		elseif colore then
			terreno:SetMaterialColor(materiale, colore)
		end
	end
end

return Ambiente
