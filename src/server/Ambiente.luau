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
	Lighting.ClockTime = 15.2
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(70, 70, 80)
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 140)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25

	effetto("Atmosphere", "Atmosfera", {
		Density = 0.32,
		Offset = 0.15,
		Color = Color3.fromRGB(199, 214, 230),
		Decay = Color3.fromRGB(106, 112, 125),
		Glare = 0.2,
		Haze = 1.4,
	})
	effetto("BloomEffect", "Bagliore", { Intensity = 0.6, Size = 28, Threshold = 1.6 })
	effetto("SunRaysEffect", "RaggiDiSole", { Intensity = 0.06, Spread = 0.7 })
	effetto("ColorCorrectionEffect", "Colore", { Brightness = 0.02, Contrast = 0.08, Saturation = 0.12 })
	effetto("DepthOfFieldEffect", "Profondita", {
		Enabled = true,
		FarIntensity = 0.12,
		FocusDistance = 80,
		InFocusRadius = 70,
		NearIntensity = 0,
	})
end

return Ambiente
