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
	-- Un testo è già un indirizzo completo (i suoni che Roblox installa col gioco: rbxasset://sounds/...).
	return type(n) == "string" and n or "rbxassetid://" .. n
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
	-- Un reggimento che tocca terra quando si schiera: il tonfo di un salto (suono di Roblox), più grave.
	atterra = { ids = { "rbxasset://sounds/action_jump_land.mp3" }, volume = 0.9, pausa = 0.05, massimo = 4, velocita = 0.62 },
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
	suono.PlaybackSpeed = (conf.velocita or 1) * (0.92 + math.random() * 0.16)
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

-- ===================================================================== interfaccia

-- Suoni di pulsanti, carte e ordini (6/11/2026, idea presa da come lavora Nintendo): ogni azione risponde SUBITO
-- con un suono breve, prima ancora che il server confermi; azioni opposte si rispondono (schierare una carta sale
-- di tono, ritirarla scende); ripetere la stessa azione cambia appena il tono, così l'orecchio non si stanca.
-- Tutti nel gruppo Effetti: "remove sound effects" nelle impostazioni spegne anche questi.
-- varia = quanto cambia il tono a caso (0.03 = 3%); canale = un suono lungo che si interrompe se ne parte un altro
-- dello stesso canale (due trombe non suonano mai insieme).
local UI = {
	-- "Roblox_UI_Small_Click" (Roblox): passare sopra un pulsante col mouse, piano.
	sopra = { ids = { 15675032796 }, volume = 0.35, pausa = 0.06, varia = 0.04 },
	-- "Roblox_UI_Bright_Click" (Roblox): pressione di un pulsante.
	premi = { ids = { 15675059323 }, volume = 0.8, pausa = 0.03, varia = 0.03 },
	-- "Roblox_UI_Delete" (Roblox): azione rifiutata (prima linea piena, ordine non valido).
	errore = { ids = { 15675075163 }, volume = 0.7, pausa = 0.15 },
	-- "Roblox_UI_Paper_Swipe" (Roblox): carta giocata o ritirata; il tono lo sceglie chi chiama.
	carta = { ids = { 15675037413 }, volume = 0.9, pausa = 0.02 },
	-- "Roblox_UI_Whoosh_04" (Roblox): scelta di un'ala o di un proprio reggimento.
	ala = { ids = { 15675012262 }, volume = 0.6, pausa = 0.05 },
	-- "Roblox_UI_Sweep" (Roblox): nemico scelto come bersaglio.
	mira = { ids = { 15675046931 }, volume = 0.6, pausa = 0.1, varia = 0.04 },
	-- "Bugle Call (a)" e "(b)" (APM, KPM): tromba per Advance; "Bugle Call (c)": la carica.
	tromba = { ids = { 1842335206, 1842335210 }, volume = 0.55, pausa = 0.25, canale = "tromba" },
	carica = { ids = { 1842368482 }, volume = 0.7, pausa = 0.25, canale = "tromba" },
	-- "Drama Sting 16" (APM, Sonoton): un colpo grave, per Hold the Line, Fall Back e Flank Them.
	tamburo = { ids = { 1846902656 }, volume = 0.6, pausa = 0.25, canale = "tromba" },
}

-- Caricati subito, in sottofondo: il primo clic deve suonare senza ritardo.
task.spawn(function()
	local lista = {}
	for _, conf in pairs(UI) do
		for _, n in ipairs(conf.ids) do
			table.insert(lista, id(n))
		end
	end
	table.insert(lista, id(EFFETTI.atterra.ids[1]))
	-- Con oggetti Sound, non con i soli indirizzi: con gli indirizzi Roblox prova a caricarli come immagini
	-- e scrive "Asset type does not match" per gli audio APM.
	local suoni = {}
	for _, indirizzo in ipairs(lista) do
		local suono = Instance.new("Sound")
		suono.SoundId = indirizzo
		table.insert(suoni, suono)
	end
	pcall(function()
		game:GetService("ContentProvider"):PreloadAsync(suoni)
	end)
	for _, suono in ipairs(suoni) do
		suono:Destroy()
	end
end)

local ultimoUi = {}
local canali = {}

-- Suono d'interfaccia "nome" (vedi UI). tono = moltiplica la velocità (1.12 = un tono sopra, 0.89 = sotto).
function Suoni.ui(nome, tono)
	local conf = UI[nome]
	if not conf then
		return
	end
	local adesso = os.clock()
	if adesso - (ultimoUi[nome] or 0) < conf.pausa then
		return
	end
	ultimoUi[nome] = adesso
	local suono = Instance.new("Sound")
	suono.SoundId = id(conf.ids[math.random(#conf.ids)])
	suono.Volume = conf.volume
	suono.PlaybackSpeed = (tono or 1) * (1 + (math.random() * 2 - 1) * (conf.varia or 0))
	suono.SoundGroup = gruppoEffetti
	suono.Parent = SoundService
	if conf.canale then
		local prima = canali[conf.canale]
		if prima and prima.Parent then
			TweenService:Create(prima, TweenInfo.new(0.12), { Volume = 0 }):Play()
			task.delay(0.15, prima.Destroy, prima)
		end
		canali[conf.canale] = suono
	end
	suono.Ended:Connect(function()
		suono:Destroy()
	end)
	task.delay(8, function()
		suono:Destroy()
	end)
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
	-- Lobby e mappa: musica eroica ma non da battaglia. I brani tranquilli di prima ("Mountainside Awakening",
	-- "Soleil Levant", "Slow Movement") a Mattia non piacevano (31/10/2026).
	-- "The Rise of Kings" (DistroKid), "Salute To Freedom", "Adventure Story", "Fanfare to a Big Country",
	-- "Confident Of Victory A" (APM).
	lobby = { volume = 0.24, ids = { 128045338895178, 1845463084, 1845453439, 1842288980, 1848195601 } },
	-- Round vinto, cinematica tra i round: musica "vittoriosa a metà" (Mattia, 20/10/2026).
	-- "Conquering Heroes Link", "Glorious Morning Link" (APM), circa 13 s. Ripartono sempre da capo.
	roundVinto = { volume = 0.34, ids = { 83315768373322, 100735630401429 }, daCapo = true },
	-- Battaglia vinta (il gioco intero): "Homecoming Of The Victorious", "March of Justice 30A" (APM).
	vittoria = { volume = 0.36, ids = { 1838608860, 1835323453 }, daCapo = true },
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
		if MUSICA[momento].daCapo then
			-- Brani brevi per un momento preciso: ogni volta il brano dopo, dall'inizio.
			if b.suono.TimePosition > 0 then
				prossimoBrano(momento)
			end
			b.suono:Play()
		elseif b.suono.IsPaused and b.suono.TimePosition > 0 then
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
