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

-- Quanto brilla ogni rarità durante l'apertura (Mattia, 1/11/2026: "quelle più alte devono proprio essere
-- shiny"): 0 piatta, 1 un riflesso che passa, 2 anche bordo e scritta metallici che girano e scintille,
-- 3 come 2 ma arcobaleno olografico e più scintille.
local BRILLO = {
	r_comune = 0,
	r_bronzo = 0,
	r_raro = 1,
	r_argento = 1,
	r_epico = 2,
	r_oro = 2,
	r_leggendario = 3,
	r_leggenda = 3,
	r_esclusivo = 3,
}

local ARCOBALENO = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 72, 96)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 196, 60)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(110, 255, 130)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(70, 205, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(196, 110, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 72, 96)),
})

-- Riflesso metallico: il colore della rarità con bande bianche.
local function metallo(pal)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, pal.t),
		ColorSequenceKeypoint.new(0.25, Stile.BIANCO),
		ColorSequenceKeypoint.new(0.5, pal.t),
		ColorSequenceKeypoint.new(0.75, Stile.BIANCO),
		ColorSequenceKeypoint.new(1, pal.t),
	})
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
			parola = string.upper(Carte.NOMI_RARITA[rarita]),
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
			parola = rarita.nome,
			leggenda = c.rarita == "leggendario",
		}
	end
	return {
		nastro = "COINS!",
		palNastro = "oro",
		pal = "r_oro",
		livello = 1,
		sotto = "Coins added to your treasury!",
		parola = "+" .. Stile.numero(risultato.quante),
		monete = true,
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

-- Le parti che fanno brillare una casella. animazioni riceve le funzioni da chiamare a ogni fotogramma col tempo.
local function brilla(f, pal, livello, animazioni, alto)
	local fase = math.random() * 10
	-- Arcobaleno olografico sul fondo che gira piano.
	if livello >= 3 then
		local olo = Stile.crea("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Stile.BIANCO,
			BackgroundTransparency = 0.68,
			ZIndex = 84, -- sotto l'icona
			Parent = f,
		}, { Stile.angoli(20) })
		local g = Stile.crea("UIGradient", { Color = ARCOBALENO, Parent = olo })
		table.insert(animazioni, function(tempo)
			g.Rotation = (tempo + fase) * 70
		end)
	end
	-- Riflesso bianco in diagonale che attraversa la casella, poi una pausa.
	local riflesso = Stile.crea("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Stile.BIANCO,
		ZIndex = 85,
		Parent = f,
	}, { Stile.angoli(20) })
	local forza = ({ 0.45, 0.6, 0.75 })[livello]
	local g = Stile.crea("UIGradient", {
		Rotation = 25,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.4, 1),
			NumberSequenceKeypoint.new(0.5, 1 - forza),
			NumberSequenceKeypoint.new(0.6, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = riflesso,
	})
	local periodo = ({ 2.4, 1.6, 1.1 })[livello]
	table.insert(animazioni, function(tempo)
		local k = ((tempo + fase) % periodo) / periodo
		g.Offset = Vector2.new(-1.1 + k * 3, 0) -- oltre 1 è fuori: la pausa tra un riflesso e l'altro
	end)
	if livello < 2 then
		return
	end
	-- Fondo metallico: bande chiare e scure in diagonale che scivolano piano, come una lamina.
	local fondo = f:FindFirstChildOfClass("UIGradient")
	local chiaro = pal.t:Lerp(Stile.BIANCO, 0.55)
	fondo.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, chiaro),
		ColorSequenceKeypoint.new(0.22, pal.t),
		ColorSequenceKeypoint.new(0.42, pal.b),
		ColorSequenceKeypoint.new(0.5, chiaro),
		ColorSequenceKeypoint.new(0.58, pal.b),
		ColorSequenceKeypoint.new(0.8, pal.t),
		ColorSequenceKeypoint.new(1, pal.d),
	})
	fondo.Rotation = 55
	table.insert(animazioni, function(tempo)
		fondo.Offset = Vector2.new(math.sin((tempo + fase) * 1.6) * 0.18, 0)
	end)
	-- Bordo più spesso, metallico (o arcobaleno), che gira attorno alla casella.
	local bordo = f:FindFirstChildOfClass("UIStroke")
	bordo.Color = Stile.BIANCO
	bordo.Thickness = 6
	local gb = Stile.crea("UIGradient", { Color = livello >= 3 and ARCOBALENO or metallo(pal), Parent = bordo })
	-- Scritta della rarità che luccica.
	alto.TextColor3 = Stile.BIANCO
	local gs = Stile.crea("UIGradient", { Color = livello >= 3 and ARCOBALENO or metallo(pal), Parent = alto })
	table.insert(animazioni, function(tempo)
		gb.Rotation = (tempo + fase) * 160
		gs.Offset = Vector2.new(math.sin((tempo + fase) * 2.5) * 0.5, 0)
	end)
	-- Scintille: stelline a quattro punte che si accendono e si spengono.
	for i = 1, livello >= 3 and 7 or 4 do
		local stella = Stile.crea("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(math.random(18, LARGO_CASELLA - 18), math.random(40, ALTO_CASELLA - 50)),
			Size = UDim2.fromOffset(34, 34),
			BackgroundTransparency = 1,
			ZIndex = 87,
			Parent = f,
		})
		for _, misura in ipairs({ Vector2.new(5, 34), Vector2.new(34, 5) }) do
			Stile.crea("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(misura.X, misura.Y),
				BackgroundColor3 = Stile.BIANCO,
				ZIndex = 87,
				Parent = stella,
			}, { Stile.tondo() })
		end
		local scala = Stile.crea("UIScale", { Scale = 0, Parent = stella })
		local velocita, inizio = 2 + math.random() * 1.5, math.random() * 6
		table.insert(animazioni, function(tempo)
			local s = math.max(0, math.sin((tempo + inizio) * velocita))
			scala.Scale = s ^ 4
			stella.Rotation = (tempo + inizio) * 90
		end)
	end
end

local function casella(voce, genitore, x, animazioni)
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
	f:SetAttribute("Brillo", BRILLO[voce.pal] or 0)
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
	if (BRILLO[voce.pal] or 0) > 0 and animazioni then
		brilla(f, pal, BRILLO[voce.pal], animazioni, alto)
	end
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

-- Mostra la striscia e aspetta che si fermi. È larga quanto lo schermo (Mattia, 5/11/2026): largo = larghezza
-- dello schermo in pixel di progetto.
local function striscia(centro, risultato, cassa, largo)
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

	local LARGO = math.floor(largo)
	-- Caselle dopo quella vinta: abbastanza da riempire la metà destra dello schermo quando la striscia si ferma.
	local CASELLE = VINCENTE + math.ceil(LARGO / 2 / (LARGO_CASELLA + SPAZIO_CASELLE)) + 2
	local finestra = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(LARGO + 24, ALTO_CASELLA + 24),
		BackgroundColor3 = Stile.VETRO,
		BackgroundTransparency = 0.15,
		ZIndex = 83,
		Parent = centro,
	}, { Stile.bordo(Stile.BIANCO, 3, 0.6) })
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
	local animazioni = {}
	for i = 1, CASELLE do
		local voce = i == VINCENTE and vinta or (#elenco > 0 and aCaso(elenco) or vinta)
		caselle[i] = casella(voce, fila, (i - 1) * (LARGO_CASELLA + SPAZIO_CASELLE), animazioni)
	end
	local tempo = 0
	local giro = RunService.RenderStepped:Connect(function(dt)
		tempo += dt
		for _, passo in ipairs(animazioni) do
			passo(tempo)
		end
	end)

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
	local inizioX = 0 -- la prima casella sul bordo sinistro: la striscia è piena fin dall'inizio
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

	-- La casella vinta esce dalla striscia (Mattia, 1/11/2026): sale sopra la fila, cresce un poco con un
	-- rimbalzo e dondola, con l'alone del suo colore dietro; le altre si spengono.
	local vincitrice = caselle[VINCENTE]
	local pal = palDi(vinta.pal) or Stile.RARITA_ACCESE.r_comune
	local x = 12 + fila.Position.X.Offset + vincitrice.Position.X.Offset
	vincitrice.Parent = finestra
	vincitrice.Position = UDim2.fromOffset(x, 12)
	vincitrice.ZIndex = 92
	local alone = Stile.crea("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x + LARGO_CASELLA / 2, 12 + ALTO_CASELLA / 2),
		Size = UDim2.fromOffset(260, 260),
		Image = Icone.immagine("glow") or "",
		ImageColor3 = pal.t,
		ImageTransparency = 1,
		BackgroundTransparency = 1,
		ZIndex = 91,
		Parent = finestra,
	})
	local scala = Stile.crea("UIScale", { Parent = vincitrice })
	local salita = 40
	tween(vincitrice, 0.4, { Position = UDim2.fromOffset(x, 12 - salita) }, Enum.EasingStyle.Back)
	tween(scala, 0.4, { Scale = 1.14 }, Enum.EasingStyle.Back)
	tween(alone, 0.4, {
		ImageTransparency = 0.15,
		Size = UDim2.fromOffset(520, 520),
		Position = UDim2.fromOffset(x + LARGO_CASELLA / 2, 12 + ALTO_CASELLA / 2 - salita),
	})
	table.insert(animazioni, function(t)
		alone.Rotation = t * 30
	end)
	local bordo = vincitrice:FindFirstChildOfClass("UIStroke")
	if (vincitrice:GetAttribute("Brillo") or 0) < 2 then
		bordo.Color = Stile.Colori.Oro
	end
	bordo.Thickness = 7
	for _, c in ipairs(caselle) do
		if c ~= vincitrice then
			tween(c, 0.4, { BackgroundTransparency = 0.5 })
		end
	end
	-- Dondola due volte mentre sale.
	task.spawn(function()
		for _, angolo in ipairs({ -4, 3, -1.5, 0 }) do
			tween(vincitrice, 0.14, { Rotation = angolo }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait(0.14)
		end
	end)
	task.wait(1.3)
	giro:Disconnect()
	finestra:Destroy()
end

-- Rivelazione della ricompensa (Mattia, 5/11/2026: "dev'essere molto più appariscente, migliore la rarità
-- migliore l'animazione ... deve occupare molto schermo", niente più raggi e bagliori). Il dorso della carta
-- arriva e trema, si gira (più giri per le rarità alte) e la ricompensa esplode fuori: lampo del suo colore,
-- onde d'urto, coriandoli, scossa dello schermo e il nome della rarità enorme. Tutto cresce col livello:
-- 0 bronzo/comune, 1 argento/raro, 2 oro/epico, 3 leggenda/leggendario/esclusivo.
local CORIANDOLI = { 26, 44, 75, 120 } -- quanti ne esplodono all'uscita, per livello
local PIOGGIA = { 0, 0, 16, 38 } -- quanti ne cadono al secondo dopo, per livello
local PUNTI = { "", "!", "!!", "!!!" }
local COLORI_ARCOBALENO = {
	Color3.fromRGB(255, 72, 96),
	Color3.fromRGB(255, 196, 60),
	Color3.fromRGB(110, 255, 130),
	Color3.fromRGB(70, 205, 255),
	Color3.fromRGB(196, 110, 255),
	Color3.fromRGB(255, 120, 220),
}

local function coloreCoriandolo(pal, livello)
	if livello >= 3 and math.random() < 0.65 then
		return COLORI_ARCOBALENO[math.random(#COLORI_ARCOBALENO)]
	end
	local r = math.random(3)
	return r == 1 and pal.t or (r == 2 and pal.b or Stile.BIANCO)
end

-- Anima per "durata" secondi chiamando passo(t) con t da 0 a 1.
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

-- Stellina a quattro punte (due barrette incrociate).
local function stella(genitore, lato, z)
	local s = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(lato, lato),
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = genitore,
	})
	for _, misura in ipairs({ Vector2.new(lato * 0.16, lato), Vector2.new(lato, lato * 0.16) }) do
		Stile.crea("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(misura.X, misura.Y),
			BackgroundColor3 = Stile.BIANCO,
			ZIndex = z,
			Parent = s,
		}, { Stile.tondo() })
	end
	return s
end

local function mostra(risultato)
	occupato = true
	local cassa = Casse.trova(risultato.cassa)
	local info = descrivi(risultato)
	local pal = palDi(info.pal) or Stile.PAL.blu
	local livello = info.livello or BRILLO[info.pal] or 1
	local tela = Stile.radice(gui)
	local W, H = tela.Size.X.Offset, tela.Size.Y.Offset

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

	-- La scena della rivelazione: un punto al centro dello schermo, le misure in pixel di progetto da lì.
	local scena = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		ZIndex = 82,
		Parent = velo,
	})
	-- Fondo del colore della rarità (dal basso), arcobaleno che gira per la leggenda.
	local tinta
	if livello >= 1 then
		tinta = Stile.crea("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Stile.BIANCO,
			BackgroundTransparency = 1,
			ZIndex = 81,
			Parent = velo,
		})
		local g = Stile.crea("UIGradient", {
			Rotation = -90,
			Color = livello >= 3 and ARCOBALENO or ColorSequence.new(pal.b, pal.d),
			Transparency = NumberSequence.new(0.35, 1),
			Parent = tinta,
		})
		tinta:SetAttribute("Rotazione", livello >= 3)
		tinta = { f = tinta, g = g }
	end

	local hc = math.floor(H * 0.54) -- altezza della carta: più di metà schermo
	local lc = math.floor(hc * Carta.PROPORZIONE)
	local cy = math.floor(-H * 0.13) -- centro della carta

	-- Coriandoli e scintille: un solo ciclo li muove tutti.
	local particelle = {}
	local function coriandolo(x, y, vx, vy, gravita, durata, z, lato)
		local w = (lato or math.random(16, 30))
		local f = Stile.crea("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, w * 0.55),
			BackgroundColor3 = coloreCoriandolo(pal, livello),
			BorderSizePixel = 0,
			ZIndex = z,
			Parent = scena,
		})
		table.insert(particelle, {
			f = f, x = x, y = y, vx = vx, vy = vy, g = gravita, w = w, vita = 0, durata = durata,
			r = math.random() * 360, vr = (math.random() - 0.5) * 900, fase = math.random() * 6,
		})
	end
	local scintille = {}
	local galleggia -- la carta dondola quando è fuori
	local riflessi = {}
	local pioggia = 0
	local tempo = 0
	local giro = RunService.RenderStepped:Connect(function(dt)
		tempo += dt
		dt = math.min(dt, 1 / 20)
		for i = #particelle, 1, -1 do
			local p = particelle[i]
			p.vita += dt
			p.vy += p.g * dt
			p.vx *= 1 - math.min(1, 1.1 * dt)
			p.x += (p.vx + (p.g < 400 and math.sin(p.vita * 3 + p.fase) * 70 or 0)) * dt
			p.y += p.vy * dt
			p.r += p.vr * dt
			local k = p.vita / p.durata
			if k >= 1 or p.y > H * 0.5 + 60 then
				p.f:Destroy()
				table.remove(particelle, i)
			else
				p.f.Position = UDim2.fromOffset(p.x, p.y)
				p.f.Rotation = p.r
				-- Si girano nell'aria come foglietti.
				p.f.Size = UDim2.fromOffset(p.w * (0.25 + 0.75 * math.abs(math.cos(p.vita * 7 + p.fase))), p.w * 0.55)
				p.f.BackgroundTransparency = k > 0.7 and (k - 0.7) / 0.3 or 0
			end
		end
		-- Pioggia di coriandoli su tutta la larghezza (oro e leggenda).
		if PIOGGIA[livello + 1] > 0 and galleggia then
			pioggia += dt * PIOGGIA[livello + 1]
			while pioggia >= 1 do
				pioggia -= 1
				coriandolo((math.random() - 0.5) * W, -H * 0.5 - 30, (math.random() - 0.5) * 80, 260 + math.random() * 220, 0, 6, 3)
			end
		end
		for _, s in ipairs(scintille) do
			local v = math.max(0, math.sin((tempo + s.inizio) * s.velocita))
			s.scala.Scale = v ^ 4
			s.f.Rotation = (tempo + s.inizio) * 90
		end
		if galleggia then
			galleggia(tempo)
		end
		for _, r in ipairs(riflessi) do
			r(tempo)
		end
		if tinta and tinta.f:GetAttribute("Rotazione") then
			tinta.g.Offset = Vector2.new(math.sin(tempo * 0.7) * 0.3, 0)
			tinta.g.Rotation = -90 + math.sin(tempo * 0.5) * 25
		end
	end)

	-- Onda d'urto: un anello del colore della rarità che si allarga fino ai bordi dello schermo.
	local function onda(ritardo, spessore)
		task.delay(ritardo, function()
			if not scena.Parent then
				return
			end
			local anello = Stile.crea("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(0, cy),
				Size = UDim2.fromOffset(lc, lc),
				BackgroundTransparency = 1,
				ZIndex = 4,
				Parent = scena,
			}, { Stile.tondo() })
			local tratto = Stile.crea("UIStroke", {
				Color = livello >= 3 and COLORI_ARCOBALENO[math.random(#COLORI_ARCOBALENO)] or pal.t,
				Thickness = spessore,
				Parent = anello,
			})
			local fino = math.max(W, H) * 1.25
			tween(anello, 0.8, { Size = UDim2.fromOffset(fino, fino) }, Enum.EasingStyle.Quart)
			tween(tratto, 0.8, { Thickness = 3, Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.85, function()
				anello:Destroy()
			end)
		end)
	end

	-- Scossa dello schermo.
	local function scossa(forza, durata)
		task.spawn(function()
			anima(durata, function(t)
				local a = forza * (1 - t)
				scena.Position = UDim2.new(0.5, (math.random() - 0.5) * 2 * a, 0.5, (math.random() - 0.5) * 2 * a)
			end)
			scena.Position = UDim2.fromScale(0.5, 0.5)
		end)
	end

	-- La ricompensa si prepara subito, nascosta, così le sue immagini sono già caricate quando esce.
	local supporto = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(0, cy),
		Size = UDim2.fromOffset(lc, hc),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Visible = false,
		Parent = scena,
	})
	local scalaCarta = Stile.crea("UIScale", { Scale = 1.45 + livello * 0.1, Parent = supporto })
	local superficie -- dove passano riflesso e olografia
	if risultato.tipo == "truppa" then
		local carta = Carta.crea(risultato.id)
		carta.Size = UDim2.fromScale(1, 1)
		carta.ZIndex = 10
		carta.Parent = supporto
		superficie = carta:FindFirstChild("Corpo")
	elseif risultato.tipo == "cosmetico" then
		local c = Config.cosmetico(risultato.id)
		local scatola = Stile.crea("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(math.floor(hc * 0.86), math.floor(hc * 0.86)),
			BackgroundColor3 = Stile.BIANCO,
			ZIndex = 10,
			Parent = supporto,
		}, { Stile.angoli(36), Stile.bordo(Stile.CONTORNO, 7), Stile.sfumatura(pal.t, pal.b) })
		Armadio.anteprimaCosmetico(c, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.9, 0.9),
			ZIndex = 11,
			Parent = scatola,
		})
		Armadio.segnaNuovo(c.id)
		supporto.Size = scatola.Size
		superficie = scatola
	else
		Stile.icona("coins_4", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(hc * 0.8, hc * 0.8),
			ZIndex = 11,
			Parent = supporto,
		})
	end
	local immagini = {}
	for _, d in ipairs(supporto:GetDescendants()) do
		if d:IsA("ImageLabel") then
			table.insert(immagini, d)
		end
	end
	task.spawn(function()
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(immagini)
		end)
	end)

	-- 1) Le casse: forziere, poi la striscia dei premi a tutta larghezza. I pacchetti di monete no.
	if cassa and risultato.tipo ~= "monete" then
		forziere(centro, cassa, pal)
		striscia(centro, risultato, cassa, W)
	end

	-- 2) Il dorso della carta entra dal basso, grande, del colore della rarità.
	local dorso = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(0, H * 0.5 + hc),
		Size = UDim2.fromOffset(lc, hc),
		Rotation = -12,
		BackgroundColor3 = Stile.BIANCO,
		ZIndex = 10,
		Parent = scena,
	}, {
		Stile.angoli(30),
		Stile.crea("UIGradient", {
			Rotation = 55,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, pal.t),
				ColorSequenceKeypoint.new(0.5, pal.b),
				ColorSequenceKeypoint.new(1, pal.d),
			}),
		}),
	})
	local bordoDorso = Stile.bordo(Stile.CONTORNO, 8)
	bordoDorso.Parent = dorso
	Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -44, 1, -44),
		BackgroundTransparency = 1,
		ZIndex = 11,
		Parent = dorso,
	}, { Stile.angoli(20), Stile.bordo(Stile.BIANCO, 5, 0.35) })
	-- Stemma: due rombi uno dentro l'altro.
	local stemma = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(lc * 0.42, lc * 0.42),
		Rotation = 45,
		BackgroundColor3 = pal.d,
		ZIndex = 12,
		Parent = dorso,
	}, { Stile.angoli(14), Stile.bordo(Stile.BIANCO, 6) })
	Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = pal.t,
		ZIndex = 13,
		Parent = stemma,
	}, { Stile.angoli(8) })
	local scalaDorso = Stile.crea("UIScale", { Parent = dorso })
	suonoUnaVolta(SUONO_CADUTA, 0.5, 1.2)
	tween(dorso, 0.45, { Position = UDim2.fromOffset(0, cy), Rotation = 0 }, Enum.EasingStyle.Back)
	task.wait(0.55)

	-- 3) Trema: una volta in più per ogni livello, sempre più forte, e il bordo si accende.
	for i = 1, 1 + livello do
		suonoUnaVolta(SUONO_SCOSSA, 0.5, 0.95 + i * 0.1)
		local forza = 3 + i * 2.5
		bordoDorso.Color = Stile.CONTORNO:Lerp(pal.t, i / (1 + livello))
		bordoDorso.Thickness = 8 + i * 2
		for _ = 1, 5 + i * 2 do
			local a = math.random() * math.pi * 2
			local v = 300 + math.random() * 300
			coriandolo(math.cos(a) * lc * 0.5, cy + math.sin(a) * hc * 0.5, math.cos(a) * v, math.sin(a) * v, 600, 0.7, 9, 12)
		end
		anima(0.3, function(t)
			local oscilla = math.sin(t * math.pi * 6) * (1 - t)
			dorso.Rotation = oscilla * forza
			scalaDorso.Scale = 1 + (i - 1) * 0.035 + math.sin(t * math.pi) * 0.06
		end)
		task.wait(math.max(0.05, 0.2 - i * 0.04))
	end

	-- 4) Si gira: mezzo giro per il bronzo, sempre più giri e più veloci per le rarità alte.
	local mezzi = 1 + livello
	local fine = math.pi * (mezzi - 0.5)
	anima(0.3 + 0.13 * livello, function(t)
		local k = t * t
		dorso.Size = UDim2.fromOffset(math.max(1, lc * math.abs(math.cos(k * fine))), hc)
		scalaDorso.Scale = 1 + livello * 0.035 + k * 0.08
	end)
	dorso:Destroy()

	-- 5) Esce la ricompensa.
	supporto.Visible = true
	tween(scalaCarta, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	suonoUnaVolta(SUONO_APERTURA, 0.6, 1 + livello * 0.06)

	-- Lampo del colore della rarità su tutto lo schermo.
	local lampo = Stile.crea("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = livello >= 1 and pal.t:Lerp(Stile.BIANCO, 0.45) or Stile.BIANCO,
		BackgroundTransparency = ({ 0.5, 0.25, 0.05, 0 })[livello + 1],
		ZIndex = 95,
		Parent = velo,
	})
	tween(lampo, 0.45 + livello * 0.12, { BackgroundTransparency = 1 })
	task.delay(1, function()
		lampo:Destroy()
	end)
	if tinta then
		tween(tinta.f, 0.6, { BackgroundTransparency = livello >= 3 and 0.35 or 0.5 })
	end
	for i = 1, 1 + livello do
		onda((i - 1) * 0.12, 26 + livello * 10)
	end
	for _ = 1, CORIANDOLI[livello + 1] do
		local a = math.random() * math.pi * 2
		local v = 700 + math.random() * (900 + livello * 450)
		coriandolo(0, cy, math.cos(a) * v, math.sin(a) * v - 350, 1500, 1.6 + math.random() * 1.2, 12)
	end
	if livello >= 2 then
		scossa(10 * livello, 0.35 + 0.1 * livello)
	end

	-- La carta galleggia e dondola piano.
	galleggia = function(t)
		supporto.Position = UDim2.fromOffset(0, cy + math.sin(t * 1.7) * 9)
		supporto.Rotation = math.sin(t * 1.1) * 2.2
	end

	-- Riflesso che passa sulla carta (argento in su) e olografia (oro in su).
	if superficie and livello >= 1 then
		local function velatura(z)
			local f = Stile.crea("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, -8, 1, -8),
				BackgroundColor3 = Stile.BIANCO,
				ZIndex = z,
				Parent = superficie,
			}, { Stile.angoli(18) })
			if superficie.Name == "Corpo" then
				-- Dentro la carta le misure sono quelle di progetto (200x290). Lo scudo ha i lati dritti fino a
				-- circa 250, poi la punta: la velatura si ferma lì, se no esce dalla sagoma.
				f.AnchorPoint = Vector2.new(0, 0)
				f.Position = UDim2.fromOffset(2, 2)
				f.Size = UDim2.fromOffset(196, 244)
			end
			return f
		end
		if livello >= 2 then
			local olo = velatura(48)
			olo.BackgroundTransparency = livello >= 3 and 0.72 or 0.8
			local g = Stile.crea("UIGradient", { Color = livello >= 3 and ARCOBALENO or metallo(pal), Parent = olo })
			table.insert(riflessi, function(t)
				g.Rotation = t * 60
			end)
		end
		local lama = velatura(49)
		local forza = ({ 0.55, 0.7, 0.85 })[livello]
		local g = Stile.crea("UIGradient", {
			Rotation = 25,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.42, 1),
				NumberSequenceKeypoint.new(0.5, 1 - forza),
				NumberSequenceKeypoint.new(0.58, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = lama,
		})
		local periodo = ({ 2.2, 1.6, 1.15 })[livello]
		table.insert(riflessi, function(t)
			local k = (t % periodo) / periodo
			g.Offset = Vector2.new(-1.1 + k * 3, 0)
		end)
	end

	-- Scintille attorno alla carta (argento in su).
	for _ = 1, ({ 0, 5, 9, 16 })[livello + 1] do
		local s = stella(scena, math.random(34, 62), 11)
		local a = math.random() * math.pi * 2
		local d = 0.62 + math.random() * 0.5
		s.Position = UDim2.fromOffset(math.cos(a) * lc * d, cy + math.sin(a) * hc * d * 0.62)
		table.insert(scintille, {
			f = s,
			scala = Stile.crea("UIScale", { Scale = 0, Parent = s }),
			velocita = 2 + math.random() * 1.6,
			inizio = math.random() * 6,
		})
	end

	-- 6) Il nome della rarità, enorme, sbatte sotto la carta; il nastro scende sopra.
	local parola = Stile.scritta({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(0, math.floor(H * 0.205)),
		Size = UDim2.fromOffset(math.min(W * 0.92, 1500), math.floor(H * 0.12)),
		Text = info.parola .. (info.monete and "" or PUNTI[livello + 1]),
		TextSize = math.floor(H * 0.12),
		Contorno = 10,
		Rotation = -3,
		TextTransparency = 1,
		ZIndex = 15,
		Parent = scena,
	})
	parola.TextColor3 = livello >= 1 and Stile.BIANCO or pal.t
	local contornoParola = parola:FindFirstChild("Contorno")
	contornoParola.Transparency = 1
	if livello >= 1 then
		local gp = Stile.crea("UIGradient", {
			Color = livello >= 3 and ARCOBALENO or metallo(pal),
			Rotation = 15,
			Parent = parola,
		})
		table.insert(riflessi, function(t)
			gp.Offset = Vector2.new(math.sin(t * 2.2) * 0.5, 0)
		end)
	end
	local scalaParola = Stile.crea("UIScale", { Scale = 3, Parent = parola })
	task.delay(0.12, function()
		tween(scalaParola, 0.32, { Scale = 1 }, Enum.EasingStyle.Back)
		tween(parola, 0.2, { TextTransparency = 0 })
		tween(contornoParola, 0.2, { Transparency = 0 })
		task.wait(0.3)
		if parola.Parent and livello >= 1 then
			scossa(6 + livello * 3, 0.25)
		end
	end)
	local nastro = Stile.nastro({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(0, -H * 0.5 - 100),
		Size = UDim2.fromOffset(580, 100),
		Rotation = -3,
		ZIndex = 16,
		Parent = scena,
	}, info.palNastro, info.nastro, 60)
	tween(nastro, 0.45, { Position = UDim2.fromOffset(0, math.floor(cy - hc / 2 - 34)) }, Enum.EasingStyle.Back)

	task.wait(0.5)

	-- 7) Sotto: cosa hai ottenuto e i pulsanti.
	local sotto = Stile.scritta({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(0, math.floor(H * 0.3)),
		Size = UDim2.fromOffset(math.min(W * 0.9, 1100), 56),
		Text = info.sotto,
		TextSize = 50,
		Contorno = 6,
		ZIndex = 17,
		Parent = scena,
	})
	local scalaSotto = Stile.crea("UIScale", { Scale = 0, Parent = sotto })
	tween(scalaSotto, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)

	local bottoni = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(0, math.floor(H * 0.4)),
		Size = UDim2.fromOffset(560, 100),
		BackgroundTransparency = 1,
		ZIndex = 18,
		Parent = scena,
	}, {
		Stile.crea("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 20),
		}),
	})
	local scalaBottoni = Stile.crea("UIScale", { Scale = 0, Parent = bottoni })
	task.delay(0.15, function()
		tween(scalaBottoni, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	local function chiudi()
		giro:Disconnect()
		velo:Destroy()
		occupato = false
		finito()
	end
	if risultato.tipo == "cosmetico" then
		local indossa = Stile.pulsante({ Size = UDim2.fromOffset(260, 96), ZIndex = 19, Parent = bottoni }, "verde", {
			Testo = "EQUIP",
			TestoSize = 46,
			Raggio = 24,
		})
		indossa.Activated:Connect(function()
			remoti.Equipaggia:InvokeServer("cosmetico", risultato.id)
			chiudi()
		end)
	end
	local bene = Stile.pulsante({ Size = UDim2.fromOffset(260, 96), ZIndex = 19, Parent = bottoni }, "blu", {
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
