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

-- Cielo e tempo delle battaglie (Campagna.Battaglie[].meteo): ognuno cambia solo alcuni valori del preset
-- "campo" (stessi nomi), così torna tutto a posto quando si rimette il campo o la lobby.
-- particelle = pioggia o neve che cadono attorno alla telecamera (Client/Meteo).
-- Chi non indica Atmosphere.Color tiene il colore del bioma.
local function C(r, g, b)
	return Color3.fromRGB(r, g, b)
end

Luci.meteo = {
	sereno = {},
	caldo = {
		Lighting = { ClockTime = 13.6, Brightness = 3.4, OutdoorAmbient = C(150, 140, 128), ExposureCompensation = 0.3 },
		Atmosphere = { Density = 0.34, Haze = 2.2, Glare = 0.5 },
		BloomEffect = { Intensity = 0.45 },
		ColorCorrectionEffect = { Saturation = 0.08, TintColor = C(255, 244, 226) },
		Clouds = { Cover = 0.3, Density = 0.4 },
	},
	polvere = {
		Lighting = { ClockTime = 15, Brightness = 2.8, OutdoorAmbient = C(150, 134, 112) },
		Atmosphere = { Density = 0.45, Offset = 0.05, Color = C(214, 186, 140), Decay = C(150, 116, 80), Haze = 2.8, Glare = 0.4 },
		ColorCorrectionEffect = { Saturation = -0.05, TintColor = C(255, 236, 210) },
		Clouds = { Cover = 0.35, Density = 0.45, Color = C(240, 226, 206) },
	},
	nuvoloso = {
		Lighting = { ClockTime = 12.5, Brightness = 1.7, Ambient = C(78, 80, 88), OutdoorAmbient = C(124, 128, 138), ShadowSoftness = 0.6, ExposureCompensation = 0.35 },
		Atmosphere = { Density = 0.36, Haze = 2.2, Glare = 0 },
		BloomEffect = { Intensity = 0.25 },
		SunRaysEffect = { Intensity = 0 },
		ColorCorrectionEffect = { Saturation = -0.12, Contrast = 0.08, TintColor = C(236, 240, 246) },
		Clouds = { Cover = 0.86, Density = 0.75, Color = C(196, 200, 208) },
	},
	pioggia = {
		Lighting = { ClockTime = 14, Brightness = 1.3, Ambient = C(74, 78, 86), OutdoorAmbient = C(112, 118, 128), ShadowSoftness = 0.75, ExposureCompensation = 0.4 },
		Atmosphere = { Density = 0.42, Haze = 2.6, Color = C(170, 178, 188), Decay = C(100, 106, 116), Glare = 0 },
		BloomEffect = { Intensity = 0.2 },
		SunRaysEffect = { Intensity = 0 },
		ColorCorrectionEffect = { Saturation = -0.18, Contrast = 0.1, TintColor = C(220, 228, 238) },
		Clouds = { Cover = 0.95, Density = 0.9, Color = C(150, 154, 162) },
		particelle = "pioggia",
	},
	neve = {
		Lighting = { ClockTime = 12, Brightness = 1.9, OutdoorAmbient = C(150, 156, 170), ShadowSoftness = 0.5 },
		Atmosphere = { Density = 0.42, Haze = 2.4, Color = C(214, 224, 238), Decay = C(150, 160, 176), Glare = 0 },
		SunRaysEffect = { Intensity = 0 },
		ColorCorrectionEffect = { Saturation = -0.1, TintColor = C(236, 244, 255) },
		Clouds = { Cover = 0.88, Density = 0.7, Color = C(225, 230, 238) },
		particelle = "neve",
	},
	nebbia = {
		Lighting = { ClockTime = 9, Brightness = 1.6, OutdoorAmbient = C(140, 142, 148), ShadowSoftness = 0.7 },
		Atmosphere = { Density = 0.64, Offset = 0, Haze = 3.4, Color = C(200, 204, 210), Decay = C(150, 154, 160), Glare = 0 },
		SunRaysEffect = { Intensity = 0 },
		ColorCorrectionEffect = { Saturation = -0.15, TintColor = C(232, 236, 240) },
		DepthOfFieldEffect = { FarIntensity = 0.2 },
		Clouds = { Cover = 0.8, Density = 0.6, Color = C(214, 216, 220) },
	},
	alba = {
		Lighting = { ClockTime = 6.7, Brightness = 2.2, Ambient = C(80, 72, 78), OutdoorAmbient = C(140, 120, 120) },
		Atmosphere = { Density = 0.4, Haze = 2.4, Color = C(255, 206, 176), Decay = C(140, 96, 110), Glare = 0.6 },
		SunRaysEffect = { Intensity = 0.12 },
		ColorCorrectionEffect = { Saturation = 0.06, TintColor = C(255, 236, 224) },
		Clouds = { Cover = 0.45, Color = C(255, 222, 210) },
	},
	tramonto = {
		Lighting = { ClockTime = 17.9, Brightness = 2.4, OutdoorAmbient = C(150, 112, 100) },
		Atmosphere = { Density = 0.36, Haze = 2.2, Color = C(255, 186, 140), Decay = C(130, 80, 90), Glare = 0.8 },
		SunRaysEffect = { Intensity = 0.14 },
		ColorCorrectionEffect = { Saturation = 0.1, TintColor = C(255, 232, 214) },
		Clouds = { Cover = 0.55, Color = C(255, 200, 180) },
	},
}

-- Cittadella: tramonto di guerra. Sole basso e arancio, foschia calda sulle montagne, nuvole spesse
-- tinte di rosa; dentro la luce la fanno i bracieri, quindi l'ambiente resta scuro e caldo.
Luci.lobby = {
	Lighting = {
		ClockTime = 17.55,
		GeographicLatitude = 30,
		Brightness = 2.6,
		-- Abbastanza chiaro e poco colorato: con meno i muri e la cupola diventano neri e tutto arancione.
		Ambient = Color3.fromRGB(104, 94, 96),
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
	BloomEffect = { Intensity = 0.4, Size = 30, Threshold = 1.8 },
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
