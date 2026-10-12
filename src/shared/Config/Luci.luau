-- Luce, cielo e atmosfera del gioco: "campo" per le battaglie e la mappa (la imposta il server all'avvio),
-- "lobby" per la cittadella (la applica il client quando il giocatore è in lobby e la toglie quando esce).
-- Ogni preset elenca le proprietà di Lighting e quelle degli effetti, per nome di classe.

local Luci = {}

Luci.campo = {
	-- Sole del pomeriggio un po' basso: ombre lunghe che danno volume a terreno, alberi e soldati.
	Lighting = {
		ClockTime = 16.2,
		GeographicLatitude = 41,
		Brightness = 3,
		Ambient = Color3.fromRGB(70, 72, 82),
		OutdoorAmbient = Color3.fromRGB(138, 140, 150),
		EnvironmentDiffuseScale = 1,
		-- Poca luce speculare: superfici opache, niente effetto plastica.
		EnvironmentSpecularScale = 0.3,
		ShadowSoftness = 0.12,
		ExposureCompensation = 0.25,
	},
	Atmosphere = {
		Density = 0.3,
		Offset = 0.1,
		Color = Color3.fromRGB(196, 210, 226),
		Decay = Color3.fromRGB(112, 118, 132),
		Glare = 0.25,
		Haze = 1.7,
	},
	BloomEffect = { Intensity = 0.35, Size = 24, Threshold = 1.8 },
	SunRaysEffect = { Intensity = 0.05, Spread = 0.6 },
	ColorCorrectionEffect = {
		Brightness = 0.01,
		Contrast = 0.12,
		Saturation = 0.04,
		TintColor = Color3.fromRGB(255, 250, 242),
	},
	DepthOfFieldEffect = { Enabled = true, FarIntensity = 0.12, FocusDistance = 80, InFocusRadius = 70, NearIntensity = 0 },
	Clouds = { Cover = 0.5, Density = 0.55, Color = Color3.fromRGB(250, 250, 252) },
}

-- Cittadella: tramonto di guerra. Sole basso e arancio, foschia calda sulle montagne, nuvole spesse
-- tinte di rosa; dentro la luce la fanno i bracieri, quindi l'ambiente resta scuro e caldo.
Luci.lobby = {
	Lighting = {
		ClockTime = 17.55,
		GeographicLatitude = 30,
		Brightness = 2.6,
		Ambient = Color3.fromRGB(58, 46, 44),
		OutdoorAmbient = Color3.fromRGB(120, 96, 92),
		EnvironmentDiffuseScale = 0.8,
		EnvironmentSpecularScale = 0.2,
		ShadowSoftness = 0.2,
		ExposureCompensation = 0.35,
	},
	Atmosphere = {
		Density = 0.36,
		Offset = 0.15,
		Color = Color3.fromRGB(255, 190, 150),
		Decay = Color3.fromRGB(120, 74, 92),
		Glare = 0.7,
		Haze = 2.4,
	},
	BloomEffect = { Intensity = 0.55, Size = 30, Threshold = 1.4 },
	SunRaysEffect = { Intensity = 0.12, Spread = 0.8 },
	ColorCorrectionEffect = {
		Brightness = 0.02,
		Contrast = 0.16,
		Saturation = 0.1,
		TintColor = Color3.fromRGB(255, 238, 222),
	},
	-- Niente sfocatura in lobby: le insegne lontane devono leggersi.
	DepthOfFieldEffect = { Enabled = false },
	Clouds = { Cover = 0.64, Density = 0.6, Color = Color3.fromRGB(255, 214, 200) },
}

return Luci
