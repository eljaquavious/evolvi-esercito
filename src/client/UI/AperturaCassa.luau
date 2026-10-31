-- Apertura di una cassa: il forziere 3D cade, trema e si apre, poi la striscia dei premi scorre e si ferma su
-- quello vinto, un lampo, poi la ricompensa
-- (la carta del reggimento, il cosmetico o le monete). Arriva dall'evento CassaAperta del server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Casse = require(ReplicatedStorage.Shared.Config.Casse)
local Carte = require(ReplicatedStorage.Shared.Config.Carte)
local Epoche = require(ReplicatedStorage.Shared.Config.Epoche)
local Config = require(ReplicatedStorage.Shared.Config.Ricompense)
local Stile = require(script.Parent.Stile)
local Icone = require(script.Parent.Icone)
local Carta = require(script.Parent.Carta)
local Armadio = require(script.Parent.Armadio)
local Forzieri = require(ReplicatedStorage.Shared.Forzieri)

local AperturaCassa = {}

local gui, remoti
local coda = {}
local occupato = false
local allaFine = {} -- funzioni chiamate quando l'ultima cassa in coda è stata chiusa

-- Una cassa sta per aprirsi o è aperta: gli elenchi (shop, locker) aspettano a mostrare la novità.
function AperturaCassa.inCorso()
	return occupato or #coda > 0
end

function AperturaCassa.alTermine(funzione)
	table.insert(allaFine, funzione)
end

local function finito()
	if #coda == 0 then
		for _, f in ipairs(allaFine) do
			task.spawn(f)
		end
	end
end

-- Colori della rarità della carta per l'alone.
local PAL_CARTE = { bronze = "r_bronzo", silver = "r_argento", gold = "r_oro", legend = "r_leggenda" }

-- Colori delle rarità: accesi durante l'apertura (Stile.RARITA_ACCESE), il resto come la tavolozza.
local function palDi(nome)
	return Stile.RARITA_ACCESE[nome] or Stile.PAL[nome]
end

local function tween(oggetto, tempo, proprieta, stile, direzione)
	local t = TweenService:Create(oggetto, TweenInfo.new(tempo, stile or Enum.EasingStyle.Quad, direzione or Enum.EasingDirection.Out), proprieta)
	t:Play()
	return t
end

-- Contenuto della ricompensa dentro il riquadro: restituisce il nastro, il colore e cosa disegnare.
local function descrivi(risultato)
	if risultato.tipo == "truppa" then
		local def = Epoche.Truppe[risultato.id]
		local rarita = Carte.rarita(def)
		return {
			nastro = risultato.nuova and "NEW REGIMENT!" or "+1 COPY",
			palNastro = risultato.nuova and "rosso" or "blu",
			pal = PAL_CARTE[rarita],
			sotto = risultato.nuova and (def.nome .. " joins your army!")
				or ("%s: you now have %d copies"):format(def.nome, risultato.copie or 2),
			leggenda = rarita == "legend",
		}
	elseif risultato.tipo == "cosmetico" then
		local c = Config.cosmetico(risultato.id)
		local rarita = Config.Rarita[c.rarita]
		return {
			nastro = "NEW GEAR!",
			palNastro = "rosso",
			pal = rarita.pal,
			sotto = c.nome,
			chip = rarita.nome,
			leggenda = c.rarita == "leggendario",
		}
	end
	return {
		nastro = "COINS!",
		palNastro = "oro",
		pal = "oro",
		sotto = "+" .. Stile.numero(risultato.quante) .. " coins",
	}
end

-- Striscia dei premi (Mattia, 31/10/2026, come le casse dei simulatori Roblox): una fila di caselle scorre da
-- destra a sinistra, rallenta e si ferma con il premio vinto sotto l'indicatore al centro.
local LARGO_CASELLA, ALTO_CASELLA, SPAZIO_CASELLE = 200, 250, 14
local CASELLE, VINCENTE = 46, 40 -- caselle in tutto, posizione di quella vinta
local DURATA_STRISCIA = 5.5

local suonoScatto = Instance.new("Sound")
suonoScatto.SoundId = "rbxasset://sounds/clickfast.wav"
suonoScatto.Volume = 0.5

-- Suoni del forziere (Pro Sound Effects): cade, trema, si apre.
local function suonoUnaVolta(id, volume, velocita)
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. id
	s.Volume = volume
	s.PlaybackSpeed = velocita or 1
	s.Parent = game:GetService("SoundService")
	s.Ended:Connect(function()
		s:Destroy()
	end)
	task.delay(6, function()
		s:Destroy()
	end)
	s:Play()
end
local SUONO_CADUTA, SUONO_SCOSSA, SUONO_APERTURA = 9113766605, 9120888471, 9116418035

-- Il forziere 3D della cassa al centro dello schermo: cade, trema tre volte sempre più forte con la luce che
-- filtra, poi il coperchio si spalanca. Senza forziere (non ancora caricato) si salta.
local function forziere(centro, cassa, pal)
	local modello = Forzieri.clona(cassa.id) or (Forzieri.aspetta(cassa.id, 1.5) and Forzieri.clona(cassa.id))
	if not modello then
		return
	end
	local vista = Stile.crea("ViewportFrame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(820, 700),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(165, 160, 175),
		LightColor = Color3.fromRGB(255, 245, 225),
		LightDirection = Vector3.new(-0.5, -1, 0.7),
		ZIndex = 83,
		Parent = centro,
	})
	-- Luce dietro il forziere: cresce a ogni scossa e esplode all'apertura.
	local luce = Stile.crea("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(520, 520),
		Image = Icone.immagine("glow") or "",
		ImageColor3 = pal.t,
		ImageTransparency = 1,
		BackgroundTransparency = 1,
		ZIndex = 82,
		Parent = centro,
	})
	local camera = Instance.new("Camera")
	camera.FieldOfView = 28
	camera.Parent = vista
	vista.CurrentCamera = camera
	modello.Parent = vista
	local _, misure = modello:GetBoundingBox()
	local guarda = Vector3.new(0, misure.Y * 0.48, 0)
	local distanza = misure.X * 4.4
	camera.CFrame = CFrame.lookAt(guarda + Vector3.new(-0.42, 0.5, -1).Unit * distanza, guarda)

	local function posa(altezza, inclina, gira, schiaccia)
		modello:PivotTo(CFrame.new(0, altezza, 0) * CFrame.Angles(0, gira or 0, inclina or 0))
		vista.Size = UDim2.fromOffset(820, 700 * (schiaccia or 1))
	end
	local function anima(durata, passo)
		local inizio = os.clock()
		while true do
			local t = math.min((os.clock() - inizio) / durata, 1)
			passo(t)
			if t >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
	end

	-- 1) Cade dall'alto e rimbalza.
	Forzieri.apri(modello, 0)
	suonoUnaVolta(SUONO_CADUTA, 0.6)
	anima(0.55, function(t)
		local k = TweenService:GetValue(t, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
		posa((1 - k) * misure.Y * 2.2, 0, math.rad(-12) * (1 - k))
		Forzieri.apri(modello, 0)
	end)
	task.wait(0.25)

	-- 2) Tre scosse, sempre più forti; il coperchio si solleva un poco e la luce filtra.
	for i = 1, 3 do
		suonoUnaVolta(SUONO_SCOSSA, 0.5, 0.9 + i * 0.08)
		local forza = 0.05 + i * 0.035
		tween(luce, 0.25, { ImageTransparency = 0.75 - i * 0.18, Size = UDim2.fromOffset(460 + i * 90, 460 + i * 90) })
		anima(0.32, function(t)
			local onda = math.sin(t * math.pi * 4) * (1 - t)
			posa(math.sin(t * math.pi) * 0.25 * i, onda * forza * 1.6, onda * forza * 0.6)
			Forzieri.apri(modello, math.sin(t * math.pi) * (0.03 + i * 0.025))
		end)
		task.wait(0.28 - i * 0.05)
	end

	-- 3) Il coperchio si spalanca con un rimbalzo; la luce esplode.
	suonoUnaVolta(SUONO_APERTURA, 0.55)
	tween(luce, 0.35, { ImageTransparency = 0, Size = UDim2.fromOffset(1100, 1100) })
	anima(0.45, function(t)
		local k = TweenService:GetValue(t, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		posa(0, 0, 0, 1 + math.sin(t * math.pi) * 0.04)
		Forzieri.apri(modello, k)
	end)
	task.wait(0.55)
	-- Il forziere si allontana e lascia il posto alla striscia.
	tween(luce, 0.4, { ImageTransparency = 1 })
	anima(0.3, function(t)
		vista.ImageTransparency = t
		vista.Size = UDim2.fromOffset(820 * (1 + t * 0.3), 700 * (1 + t * 0.3))
	end)
	vista:Destroy()
	luce:Destroy()
end

local function unoSu(p)
	return ("1 IN %d"):format(math.max(1, math.floor(1 / math.max(p, 0.0001) + 0.5)))
end

-- Le voci che possono uscire dalla cassa, con la probabilità della loro rarità.
-- Ogni voce: { truppa = id } o { cosmetico = id }, rarita (nome da mostrare), pal, p.
local function voci(cassa, tipo)
	local elenco = {}
	local probabilita = Casse.probabilita(cassa.pesi)
	if tipo == "truppe" then
		for _, id in ipairs(Epoche.carte()) do
			local r = Carte.rarita(Epoche.Truppe[id])
			if probabilita[r] then
				table.insert(elenco, { truppa = id, rarita = string.upper(Carte.NOMI_RARITA[r]), pal = PAL_CARTE[r], p = probabilita[r] })
			end
		end
	else
		for _, c in ipairs(Config.Cosmetici) do
			if c.cassa and probabilita[c.rarita] then
				local r = Config.Rarita[c.rarita]
				table.insert(elenco, { cosmetico = c.id, rarita = r.nome, pal = r.pal, p = probabilita[c.rarita] })
			end
		end
	end
	return elenco, probabilita
end

-- La voce del premio vinto (anche se, per caso, non fosse nell'elenco).
local function voceVinta(risultato, cassa)
	local probabilita = Casse.probabilita(cassa.pesi)
	if risultato.tipo == "truppa" then
		local r = Carte.rarita(Epoche.Truppe[risultato.id])
		return { truppa = risultato.id, rarita = string.upper(Carte.NOMI_RARITA[r]), pal = PAL_CARTE[r], p = probabilita[r] or 0.01 }
	end
	local c = Config.cosmetico(risultato.id)
	local r = Config.Rarita[c.rarita]
	return { cosmetico = c.id, rarita = r.nome, pal = r.pal, p = probabilita[c.rarita] or 0.01 }
end

-- Estrae una voce a caso rispettando le probabilità delle rarità (come il server).
local function aCaso(elenco)
	local x = math.random()
	local somma = 0
	for _, v in ipairs(elenco) do
		-- p è la probabilità della rarità: divisa per quante voci ha quella rarità.
		somma += v.p / v.quante
		if x <= somma then
			return v
		end
	end
	return elenco[#elenco]
end

local function casella(voce, genitore, x)
	local pal = palDi(voce.pal) or Stile.RARITA_ACCESE.r_comune
	local f = Stile.crea("Frame", {
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.fromOffset(LARGO_CASELLA, ALTO_CASELLA),
		BackgroundColor3 = Stile.BIANCO,
		ZIndex = 84,
		Parent = genitore,
	}, {
		Stile.angoli(20),
		Stile.bordo(pal.t, 4),
		Stile.sfumatura(pal.b, pal.d, 90),
	})
	local nome
	if voce.truppa then
		local def = Epoche.Truppe[voce.truppa]
		nome = def.nome
		Stile.icona(Icone.carta(def), {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 122),
			Size = UDim2.fromOffset(132, 132),
			ZIndex = 85,
			Parent = f,
		})
	else
		local c = Config.cosmetico(voce.cosmetico)
		nome = c.nome
		Armadio.anteprimaCosmetico(c, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 122),
			Size = UDim2.fromOffset(150, 140),
			ZIndex = 85,
			Parent = f,
		})
	end
	local alto = Stile.scritta({
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 0, 30),
		Text = voce.rarita .. " · " .. unoSu(voce.p),
		TextSize = 22,
		Contorno = 3,
		ZIndex = 86,
		Parent = f,
	})
	alto.TextColor3 = pal.t:Lerp(Stile.BIANCO, 0.2)
	Stile.scritta({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -10),
		Size = UDim2.new(1, -16, 0, 36),
		Text = string.upper(nome),
		TextSize = 26,
		Contorno = 3,
		ZIndex = 86,
		Parent = f,
	})
	return f
end

-- Mostra la striscia e aspetta che si fermi.
local function striscia(centro, risultato, cassa)
	local _, tipo = Casse.trova(cassa.id)
	local elenco = voci(cassa, tipo)
	local perRarita = {}
	for _, v in ipairs(elenco) do
		perRarita[v.rarita] = (perRarita[v.rarita] or 0) + 1
	end
	for _, v in ipairs(elenco) do
		v.quante = perRarita[v.rarita]
	end
	local vinta = voceVinta(risultato, cassa)

	local LARGO = 1180
	local finestra = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(LARGO + 24, ALTO_CASELLA + 24),
		BackgroundColor3 = Stile.VETRO,
		BackgroundTransparency = 0.15,
		ZIndex = 83,
		Parent = centro,
	}, { Stile.angoli(26), Stile.bordo(Stile.BIANCO, 3, 0.6) })
	local scalaFinestra = Stile.crea("UIScale", { Scale = 0.6, Parent = finestra })
	tween(scalaFinestra, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	local vista = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(LARGO, ALTO_CASELLA),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 84,
		Parent = finestra,
	})
	local fila = Stile.crea("Frame", {
		Size = UDim2.fromOffset(CASELLE * (LARGO_CASELLA + SPAZIO_CASELLE), ALTO_CASELLA),
		BackgroundTransparency = 1,
		ZIndex = 84,
		Parent = vista,
	})
	local caselle = {}
	for i = 1, CASELLE do
		local voce = i == VINCENTE and vinta or (#elenco > 0 and aCaso(elenco) or vinta)
		caselle[i] = casella(voce, fila, (i - 1) * (LARGO_CASELLA + SPAZIO_CASELLE))
	end

	-- Indicatore al centro: barra bianca con un rombo dorato sopra e sotto.
	local indicatore = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(8, ALTO_CASELLA + 60),
		BackgroundColor3 = Stile.BIANCO,
		ZIndex = 90,
		Parent = finestra,
	}, { Stile.tondo(), Stile.bordo(Stile.CONTORNO, 2) })
	for _, y in ipairs({ 0, 1 }) do
		Stile.crea("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, y),
			Size = UDim2.fromOffset(34, 34),
			Rotation = 45,
			BackgroundColor3 = Stile.Colori.Oro,
			ZIndex = 91,
			Parent = indicatore,
		}, { Stile.angoli(6), Stile.bordo(Stile.CONTORNO, 3) })
	end

	-- Dove finisce: il centro della casella vinta sotto l'indicatore, spostato un po' a caso dentro la casella.
	local passo = LARGO_CASELLA + SPAZIO_CASELLE
	local scarto = (math.random() - 0.5) * LARGO_CASELLA * 0.7
	local inizioX = LARGO / 2 - LARGO_CASELLA / 2 - passo * 2
	local fineX = LARGO / 2 - ((VINCENTE - 1) * passo + LARGO_CASELLA / 2) + scarto
	fila.Position = UDim2.fromOffset(inizioX, 0)
	-- Le icone delle carte arrivano dalla rete: si aspetta che siano pronte (al massimo 2 s), così nessuna
	-- casella passa vuota.
	local immagini = {}
	for _, d in ipairs(fila:GetDescendants()) do
		if d:IsA("ImageLabel") then
			table.insert(immagini, d)
		end
	end
	local pronte = false
	task.spawn(function()
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(immagini)
		end)
		pronte = true
	end)
	local attesa = os.clock()
	while not pronte and os.clock() - attesa < 2 do
		task.wait()
	end
	task.wait(0.2)

	local suono = suonoScatto:Clone()
	suono.Parent = game:GetService("SoundService")
	local ultima = -1
	local inizio = os.clock()
	while true do
		local t = math.min((os.clock() - inizio) / DURATA_STRISCIA, 1)
		-- Parte veloce e rallenta molto alla fine (quinta potenza).
		local k = 1 - (1 - t) ^ 5
		local x = inizioX + (fineX - inizioX) * k
		fila.Position = UDim2.fromOffset(x, 0)
		local sotto = math.floor((LARGO / 2 - x) / passo)
		if sotto ~= ultima then
			ultima = sotto
			suono.PlaybackSpeed = 0.9 + math.random() * 0.2
			suono:Play()
		end
		if t >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end
	suono:Destroy()

	-- La casella vinta si illumina e cresce.
	local vincitrice = caselle[VINCENTE]
	vincitrice.ZIndex = 88
	local scala = Stile.crea("UIScale", { Parent = vincitrice })
	tween(scala, 0.3, { Scale = 1.08 }, Enum.EasingStyle.Back)
	local bordo = vincitrice:FindFirstChildOfClass("UIStroke")
	bordo.Color = Stile.Colori.Oro
	bordo.Thickness = 7
	for _, c in ipairs(caselle) do
		if c ~= vincitrice then
			tween(c, 0.4, { BackgroundTransparency = 0.5 })
		end
	end
	task.wait(1.1)
	finestra:Destroy()
end

local function mostra(risultato)
	occupato = true
	local cassa = Casse.trova(risultato.cassa)
	local info = descrivi(risultato)
	local pal = palDi(info.pal) or Stile.PAL.blu
	local tela = Stile.radice(gui)

	local velo = Stile.crea("TextButton", {
		Name = "AperturaCassa",
		Text = "",
		AutoButtonColor = false,
		Position = UDim2.fromOffset(0, -200),
		Size = UDim2.new(1, 0, 1, 400),
		BackgroundColor3 = Stile.CONTORNO,
		BackgroundTransparency = 0.1,
		ZIndex = 80,
		Parent = tela,
	})
	local centro = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(10, 10),
		BackgroundTransparency = 1,
		ZIndex = 81,
		Parent = velo,
	})
	local raggi
	local immagineRaggi = Icone.immagine("rays")
	if immagineRaggi then
		raggi = Stile.crea("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(900, 900),
			Image = immagineRaggi,
			ImageColor3 = pal.t,
			ImageTransparency = 0.4,
			BackgroundTransparency = 1,
			ZIndex = 81,
			Parent = centro,
		})
	end
	local tempo = 0
	local giro = RunService.RenderStepped:Connect(function(dt)
		tempo += dt
		if raggi then
			raggi.Rotation = tempo * 25
		end
	end)

	-- 1) Le casse: la striscia dei premi scorre e si ferma su quello vinto. I pacchetti di monete no.
	if cassa and risultato.tipo ~= "monete" then
		if raggi then
			raggi.Visible = false
		end
		forziere(centro, cassa, pal)
		striscia(centro, risultato, cassa)
		if raggi then
			raggi.Visible = true
		end
	end

	-- 2) Lampo bianco, poi la ricompensa grande.
	local lampo = Stile.crea("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Stile.BIANCO,
		BackgroundTransparency = 0,
		ZIndex = 95,
		Parent = velo,
	})
	tween(lampo, 0.5, { BackgroundTransparency = 1 })
	task.delay(0.5, function()
		lampo:Destroy()
	end)

	-- 3) La ricompensa.
	local riquadro = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(640, 720),
		BackgroundTransparency = 1,
		ZIndex = 84,
		Parent = centro,
	})
	local scala = Stile.crea("UIScale", { Scale = 0.5, Parent = riquadro })
	tween(scala, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	Stile.nastro({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(520, 90),
		Rotation = -3,
		ZIndex = 92,
		Parent = riquadro,
	}, info.palNastro, info.nastro, 56)

	if risultato.tipo == "truppa" then
		local carta = Carta.crea(risultato.id)
		carta.AnchorPoint = Vector2.new(0.5, 0)
		carta.Position = UDim2.new(0.5, 0, 0, 70)
		carta.Size = UDim2.fromOffset(math.floor(440 * Carta.PROPORZIONE), 440)
		carta.ZIndex = 86
		carta.Parent = riquadro
	elseif risultato.tipo == "cosmetico" then
		local c = Config.cosmetico(risultato.id)
		Stile.crea("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 80),
			Size = UDim2.fromOffset(440, 420),
			BackgroundColor3 = Stile.BIANCO,
			ZIndex = 85,
			Parent = riquadro,
		}, { Stile.angoli(30), Stile.bordo(Stile.CONTORNO, 6), Stile.sfumatura(pal.t, pal.b) })
		Armadio.anteprimaCosmetico(c, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 100),
			Size = UDim2.fromOffset(400, 380),
			ZIndex = 86,
			Parent = riquadro,
		})
		Armadio.segnaNuovo(c.id)
	else
		Stile.icona("coins_4", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 90),
			Size = UDim2.fromOffset(380, 380),
			ZIndex = 86,
			Parent = riquadro,
		})
	end

	local sotto = Stile.scritta({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 522),
		Size = UDim2.fromOffset(900, 56),
		Text = info.sotto,
		TextSize = 50,
		Contorno = 6,
		ZIndex = 88,
		Parent = riquadro,
	})
	sotto.TextScaled = true
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 50, Parent = sotto })
	if info.chip then
		Stile.chip({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 584),
			Size = UDim2.fromOffset(210, 44),
			ZIndex = 88,
			Parent = riquadro,
		}, info.pal, info.chip, 26)
	end
	if info.leggenda then
		-- Le leggendarie si fanno notare: l'alone pulsa.
		task.spawn(function()
			while raggi and raggi.Parent do
				tween(raggi, 0.5, { ImageTransparency = 0.1 })
				task.wait(0.5)
				if not raggi.Parent then
					break
				end
				tween(raggi, 0.5, { ImageTransparency = 0.45 })
				task.wait(0.5)
			end
		end)
	end

	local bottoni = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(560, 100),
		BackgroundTransparency = 1,
		ZIndex = 88,
		Parent = riquadro,
	}, {
		Stile.crea("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 20),
		}),
	})
	local function chiudi()
		giro:Disconnect()
		velo:Destroy()
		occupato = false
		finito()
	end
	if risultato.tipo == "cosmetico" then
		local indossa = Stile.pulsante({ Size = UDim2.fromOffset(260, 96), ZIndex = 89, Parent = bottoni }, "verde", {
			Testo = "EQUIP",
			TestoSize = 46,
			Raggio = 24,
		})
		indossa.Activated:Connect(function()
			remoti.Equipaggia:InvokeServer("cosmetico", risultato.id)
			chiudi()
		end)
	end
	local bene = Stile.pulsante({ Size = UDim2.fromOffset(260, 96), ZIndex = 89, Parent = bottoni }, "blu", {
		Testo = "AWESOME",
		TestoSize = 42,
		Raggio = 24,
	})
	bene.Activated:Connect(chiudi)
	Stile.seleziona(bene)
end

function AperturaCassa.inizializza(g, r)
	gui, remoti = g, r
	remoti.CassaAperta.OnClientEvent:Connect(function(risultato)
		table.insert(coda, risultato)
	end)
	task.spawn(function()
		while true do
			task.wait(0.2)
			if not occupato and #coda > 0 then
				local risultato = table.remove(coda, 1)
				local ok, errore = pcall(mostra, risultato)
				if not ok then
					warn("[AperturaCassa] " .. tostring(errore))
					occupato = false
					finito()
				end
			end
		end
	end)
end

return AperturaCassa
