-- Suoni del gioco, solo sul client: la musica del livello (tesa nello schieramento, di guerra in battaglia)
-- e i rumori della battaglia (spade, spari, frecce, esplosioni, grida di guerra).
-- Audio dalla libreria di Roblox (musica APM, effetti Pro Sound Effects) e dal Creator Store (gratuiti).
-- In battaglia gli eventi sono tantissimi: ogni rumore ha una pausa minima e un massimo di copie insieme,
-- così si sente il fragore senza saturare. Le grida restano basse (scelta di Mattia).

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Suoni = {}

local function gruppo(nome, volume)
	local g = SoundService:FindFirstChild(nome)
	if not g then
		g = Instance.new("SoundGroup")
		g.Name = nome
		g.Volume = volume
		g.Parent = SoundService
	end
	return g
end

local gruppoEffetti = gruppo("Effetti", 0.4) -- ben sotto la musica (UI/Impostazioni lo rimette a 0.4 o a 0)
local gruppoMusica = gruppo("Musica", 1)

local function id(n)
	return "rbxassetid://" .. n
end

-- volume = volume della singola copia; pausa = secondi minimi tra due copie; massimo = copie che suonano insieme.
local EFFETTI = {
	-- "Shield Clang As Hit Metal Sword" 1 e 2 (Pro Sound Effects), "sword parry / clash" (Creator Store).
	spada = { ids = { 9119072660, 9119072674, 5763723309 }, volume = 0.32, pausa = 0.08, massimo = 6 },
	-- Colpi di fucile singoli (Creator Store).
	sparo = { ids = { 92011177452282, 76727380063178 }, volume = 0.26, pausa = 0.07, massimo = 6 },
	-- "Machine Gun Bursts 12" (Pro Sound Effects): raffica corta.
	raffica = { ids = { 9116361236 }, volume = 0.3, pausa = 0.15, massimo = 3 },
	-- "Arrow Out Whooshing Pass By 1" (Pro Sound Effects).
	freccia = { ids = { 9113166206 }, volume = 0.2, pausa = 0.18, massimo = 4 },
	-- "Dirt Explosion 1" (Pro Sound Effects).
	esplosione = { ids = { 9114086657 }, volume = 0.45, pausa = 0.25, massimo = 3 },
	-- Il colpo di partenza di un cannone o di un carro: la stessa esplosione, più bassa.
	cannonata = { ids = { 9114086657 }, volume = 0.3, pausa = 0.3, massimo = 2 },
	-- "Excited Foreign Crowd" 5 e 3 (Pro Sound Effects): uomini che gridano. Bassi.
	grido = { ids = { 9114360647, 9114360486 }, volume = 0.08, pausa = 3.5, massimo = 1 },
	-- Un soldato che urla mentre colpisce: "Male Scream Short Yelling Bursts" 2, 6, 7, 11 (Pro Sound Effects).
	urlo = { ids = { 9125651079, 9125651083, 9125651408, 9125652676 }, volume = 0.08, pausa = 0.7, massimo = 2 },
	-- Un soldato che cade: le versioni brevi degli stessi (1, 4, 5, 8, 9, 16).
	morte = { ids = { 9125650883, 9125652443, 9125652432, 9125652675, 9125651364, 9125652949 }, volume = 0.26, pausa = 0.12, massimo = 4 },
}

-- Oltre questa distanza dalla telecamera un rumore non si suona nemmeno.
local DISTANZA_MASSIMA = 380

local stato = {} -- nome -> { ultimo = os.clock(), attivi = n }
for nome in pairs(EFFETTI) do
	stato[nome] = { ultimo = 0, attivi = 0 }
end

-- Rumore di battaglia nel punto "posizione" (Vector3). Senza posizione si sente ovunque, come la musica.
function Suoni.effetto(nome, posizione)
	local conf = EFFETTI[nome]
	local s = stato[nome]
	if not conf then
		return
	end
	local adesso = os.clock()
	if adesso - s.ultimo < conf.pausa or s.attivi >= conf.massimo then
		return
	end
	local camera = workspace.CurrentCamera
	if posizione and camera and (camera.CFrame.Position - posizione).Magnitude > DISTANZA_MASSIMA then
		return
	end
	s.ultimo = adesso
	s.attivi += 1
	local suono = Instance.new("Sound")
	suono.SoundId = id(conf.ids[math.random(#conf.ids)])
	suono.Volume = conf.volume
	suono.PlaybackSpeed = 0.92 + math.random() * 0.16
	suono.SoundGroup = gruppoEffetti
	suono.RollOffMode = Enum.RollOffMode.InverseTapered
	suono.RollOffMinDistance = 45
	suono.RollOffMaxDistance = DISTANZA_MASSIMA
	local appiglio
	if posizione then
		appiglio = Instance.new("Attachment")
		appiglio.WorldPosition = posizione
		appiglio.Parent = workspace.Terrain
		suono.Parent = appiglio
	else
		suono.Parent = SoundService
	end
	local finito = false
	local function fine()
		if finito then
			return
		end
		finito = true
		s.attivi -= 1
		if appiglio then
			appiglio:Destroy()
		else
			suono:Destroy()
		end
	end
	suono.Ended:Connect(fine)
	-- Se l'audio non si carica, Ended non arriva mai: si libera il posto lo stesso.
	task.delay(6, fine)
	suono:Play()
end

-- ===================================================================== musica

-- Una lista di brani per momento: suonano uno dopo l'altro, partendo da uno a caso.
local MUSICA = {
	-- "Territory Conquest Alternate 2" (Pablo Pico, APM): percussioni meccaniche, tese e decise.
	-- "Cinematic Tension 15 E 2" (APM).
	schieramento = { volume = 0.32, ids = { 9041879299, 91611560835347 } },
	-- "Battleground", "On the Warpath", "Drums of Combat a", "Fight For A Tomorrow" (APM).
	battaglia = { volume = 0.3, ids = { 9048541013, 1837240654, 1841476670, 1848108091 } },
	-- Lobby e mappa: musica tranquilla (Mattia voleva qualcosa come "Morning of D-Day" di HOI4, che non si può
	-- usare su Roblox): "Mountainside Awakening - Leads Only", "Soleil Levant", "Slow Movement" (APM).
	lobby = { volume = 0.22, ids = { 9043694722, 1837591314, 1836331268 } },
}

local DISSOLVENZA = 1.6

local brani = {} -- momento -> { suono, indice }
local attuale = nil

local function prossimoBrano(momento)
	local conf = MUSICA[momento]
	local b = brani[momento]
	b.indice = b.indice % #conf.ids + 1
	b.suono.SoundId = id(conf.ids[b.indice])
	b.suono.TimePosition = 0
end

local function branoDi(momento)
	local b = brani[momento]
	if b then
		return b
	end
	local conf = MUSICA[momento]
	local suono = Instance.new("Sound")
	suono.Name = "Musica_" .. momento
	suono.Volume = 0
	suono.SoundGroup = gruppoMusica
	suono.Parent = SoundService
	b = { suono = suono, indice = math.random(#conf.ids) - 1 }
	brani[momento] = b
	prossimoBrano(momento)
	suono.Ended:Connect(function()
		if attuale == momento then
			prossimoBrano(momento)
			suono:Play()
		end
	end)
	return b
end

local function sfuma(suono, volume, poi)
	local t = TweenService:Create(suono, TweenInfo.new(DISSOLVENZA, Enum.EasingStyle.Sine), { Volume = volume })
	if poi then
		t.Completed:Connect(function(esito)
			if esito == Enum.PlaybackState.Completed then
				poi()
			end
		end)
	end
	t:Play()
end

-- momento: "schieramento", "battaglia" o nil (silenzio). Il brano interrotto riprende da dove era rimasto.
function Suoni.musica(momento)
	if momento == attuale then
		return
	end
	local prima = attuale and brani[attuale]
	attuale = momento
	if prima then
		local suono = prima.suono
		sfuma(suono, 0, function()
			if suono.Volume == 0 then
				suono:Pause()
			end
		end)
	end
	if momento and MUSICA[momento] then
		local b = branoDi(momento)
		if b.suono.IsPaused and b.suono.TimePosition > 0 then
			b.suono:Resume()
		else
			b.suono:Play()
		end
		sfuma(b.suono, MUSICA[momento].volume)
	end
end

-- Fine del livello: la musica sfuma e la prossima volta i brani ricominciano da capo.
function Suoni.fermaMusica()
	Suoni.musica(nil)
	for momento, b in pairs(brani) do
		task.delay(DISSOLVENZA + 0.1, function()
			if attuale ~= momento then
				b.suono:Stop()
				prossimoBrano(momento)
			end
		end)
	end
end

return Suoni
