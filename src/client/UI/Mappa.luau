-- Mappa della campagna, stile Clash of Clans: il plastico d'Europa (costruito dal server) con sopra
-- i livelli collegati da un sentiero, le stelle conquistate e il pannello per attaccare.
-- Livelli e sentiero sono parti locali di questo client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Campagna = require(ReplicatedStorage.Shared.Config.Campagna)
local MappaEuropa = require(ReplicatedStorage.Shared.Config.MappaEuropa)
local Biomi = require(ReplicatedStorage.Shared.Config.Biomi)
local Stile = require(script.Parent.Stile)
local Carta = require(script.Parent.Carta)
local Notifiche = require(script.Parent.Notifiche)

local Mappa = {}

local remoti
local aperta = false
local stato
local selezionato = 1
local zoom = 1

local cartella -- parti locali dei livelli
local costruitaConMisure = false -- true se i nodi stanno sulle quote misurate dal server
local nodi = {} -- numero -> { base, gui, stelle }
local puntini = {} -- numero -> lista di puntini del tratto che porta a quel livello

local interfaccia, titoloStelle, pannello, nomeLivello, dettagli, stellePannello, bottoneAttacca, spazioBoss
local ambienteSalvato
local connessioneAnimazione

local ORO = Color3.fromRGB(255, 206, 84)
local GRIGIO = Color3.fromRGB(120, 120, 130)
local ARANCIO = Color3.fromRGB(255, 130, 40)

-- Mari, scritti sul plastico per orientarsi.
-- { nome, lat, lon, scala }: i mari a nord sono più lontani dalla telecamera, quindi più grandi.
local MARI = {
	{ "ATLANTIC OCEAN", 45.5, -6.5, 1 },
	{ "MEDITERRANEAN SEA", 34.6, 19, 1 },
	{ "NORTH SEA", 56, 3.5, 1.7 },
	{ "BLACK SEA", 43.4, 34.5, 1.2 },
	{ "BALTIC SEA", 58, 19.5, 1.6 },
}

-- Quote dei livelli misurate dal server sul Terrain vero (vedi MappaCampagna); se mancano, una stima.
local function quotaMisurata(numero)
	local altezze = ReplicatedStorage:FindFirstChild("AltezzeMappa")
	return altezze and altezze:GetAttribute("L" .. numero)
end

local function misureComplete()
	for numero = 1, Campagna.TOTALE do
		if not quotaMisurata(numero) then
			return false
		end
	end
	return true
end

local function posizioneLivello(numero)
	local b = Campagna.Battaglie[numero]
	local punto = MappaEuropa.posizione(b.lat, b.lon)
	return Vector3.new(punto.X, quotaMisurata(numero) or MappaEuropa.superficie(punto), punto.Z)
end

local function stelleDi(numero)
	return stato and stato.stelle and stato.stelle[tostring(numero)] or 0
end

local function sbloccato(numero)
	return stato and numero <= stato.livello
end

local function parteLocale(proprieta)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(proprieta) do
		p[k] = v
	end
	p.Parent = cartella
	return p
end

local function etichettaMare(testo, lat, lon, scala)
	local ancora = parteLocale({ Size = Vector3.one * 0.2, Transparency = 1, Position = MappaEuropa.posizione(lat, lon) + Vector3.new(0, 2, 0) })
	local gui = Instance.new("BillboardGui")
	-- Misure in studs: la scritta rimpicciolisce con la distanza e i mari vicini non si sovrappongono.
	gui.Size = UDim2.new(#testo * 9 * scala, 0, 18 * scala, 0)
	gui.LightInfluence = 0
	gui.Parent = ancora
	Stile.testo({
		Size = UDim2.fromScale(1, 1),
		Text = testo,
		Font = Stile.FontTitolo,
		TextColor3 = Color3.fromRGB(220, 240, 255),
		TextTransparency = 0.35,
		Parent = gui,
	})
end

local function costruisci()
	costruitaConMisure = misureComplete()
	cartella = Instance.new("Folder")
	cartella.Name = "MappaLivelli"
	cartella.Parent = workspace
	for _, mare in ipairs(MARI) do
		etichettaMare(mare[1], mare[2], mare[3], mare[4])
	end
	for numero, battaglia in ipairs(Campagna.Battaglie) do
		local posizione = posizioneLivello(numero)
		local boss = battaglia.comandante ~= nil
		local diametro = boss and 9 or 6.5
		local base = parteLocale({
			Name = "Livello" .. numero,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.2, diametro, diametro),
			CFrame = CFrame.new(posizione + Vector3.new(0, 0.45, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Neon,
			CanQuery = true,
		})
		base:SetAttribute("Livello", numero)
		parteLocale({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1, diametro + 1.2, diametro + 1.2),
			CFrame = CFrame.new(posizione + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(40, 32, 26),
			Material = Enum.Material.SmoothPlastic,
		})
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(120, 70)
		gui.StudsOffset = Vector3.new(0, 6, 0)
		gui.LightInfluence = 0
		gui.AlwaysOnTop = true
		gui.Parent = base
		local numeroTesto = Stile.titolo({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromOffset(60, 30),
			Text = boss and "BOSS" or tostring(numero),
			Parent = gui,
		})
		local stelle = Stile.titolo({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -30),
			Size = UDim2.fromOffset(90, 26),
			Text = "",
			Font = Stile.Font,
			TextColor3 = ORO,
			Parent = gui,
		})
		local nome = Stile.titolo({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -54),
			Size = UDim2.fromOffset(120, 18),
			Text = battaglia.nome,
			Visible = false,
			Parent = gui,
		})
		nodi[numero] = { base = base, gui = gui, stelle = stelle, numero = numeroTesto, nome = nome }

		-- Tratto di sentiero dal livello precedente (calcolato insieme alla mappa). Sulla terra è tracciato
		-- nel Terrain dal server; qui si aggiungono le tratte per mare e le luci del prossimo tratto.
		puntini[numero] = {}
		local celle = MappaEuropa.Sentieri[numero] or {}
		local passo = 0
		for i = 1, #celle, 2 do
			local colonna, riga = celle[i], celle[i + 1]
			local centro = MappaEuropa.posizioneCella(colonna, riga)
			passo += 1
			if not MappaEuropa.terra(colonna, riga) then
				if passo % 2 == 0 then
					table.insert(puntini[numero], { mare = true, parte = parteLocale({
						Size = Vector3.new(2.2, 0.3, 2.2),
						Position = centro + Vector3.new(0, 0.25, 0),
						Material = Enum.Material.SmoothPlastic,
					}) })
				end
			elseif passo % 3 == 0 then
				table.insert(puntini[numero], { mare = false, parte = parteLocale({
					Shape = Enum.PartType.Ball,
					Size = Vector3.one * 1.6,
					Position = Vector3.new(centro.X, MappaEuropa.superficie(centro) + 0.3, centro.Z),
					Material = Enum.Material.Neon,
				}) })
			end
		end
	end
end

local function aggiornaNodi()
	for numero, nodo in pairs(nodi) do
		local stelle = stelleDi(numero)
		local colore
		if stelle > 0 then
			colore = ORO
		elseif sbloccato(numero) then
			colore = ARANCIO
		else
			colore = GRIGIO
		end
		nodo.base.Color = colore
		nodo.base.Transparency = sbloccato(numero) and 0 or 0.3
		nodo.stelle.Text = sbloccato(numero) and string.rep("★", stelle) .. string.rep("☆", Campagna.STELLE_MASSIME - stelle) or ""
		nodo.numero.TextColor3 = sbloccato(numero) and Color3.new(1, 1, 1) or Color3.fromRGB(170, 170, 180)
		nodo.nome.Visible = numero == selezionato
		-- Luci lungo il sentiero dell'epoca: oro i tratti fatti, arancio il prossimo, bianche tenui
		-- quelli ancora da fare. Le epoche non ancora raggiunte non si illuminano.
		local prossimo = sbloccato(numero) and stelle == 0
		local epocaRaggiunta = stato and Campagna.livello(numero).indiceEpoca <= Campagna.livello(stato.livello).indiceEpoca
		for _, punto in ipairs(puntini[numero]) do
			if stelle > 0 then
				punto.parte.Color, punto.parte.Transparency = ORO, 0
			elseif prossimo then
				punto.parte.Color, punto.parte.Transparency = ARANCIO, 0
			elseif epocaRaggiunta then
				punto.parte.Color, punto.parte.Transparency = Color3.fromRGB(245, 245, 245), 0.45
			else
				punto.parte.Color = Color3.fromRGB(245, 245, 245)
				punto.parte.Transparency = punto.mare and 0.6 or 1
			end
		end
	end
end

local function aggiornaCamera(istantanea)
	local bersaglio = posizioneLivello(selezionato)
	-- Più ci si allontana, più la telecamera guarda il centro della mappa: niente cielo vuoto ai lati.
	local centro = MappaEuropa.CENTRO + Vector3.new(0, 0, -40)
	bersaglio = bersaglio:Lerp(Vector3.new(centro.X, bersaglio.Y, centro.Z), math.clamp((zoom - 1) / 2, 0, 0.85))
	-- Il giocatore aspetta a sud del plastico: chiede di caricare il terreno attorno al livello guardato.
	task.spawn(pcall, Players.LocalPlayer.RequestStreamAroundAsync, Players.LocalPlayer, bersaglio)
	local cframe = CFrame.lookAt(bersaglio + Vector3.new(0, 120, -95) * zoom, bersaglio)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	if istantanea then
		camera.CFrame = cframe
	else
		TweenService:Create(camera, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = cframe }):Play()
	end
end

local function aggiornaPannello()
	local livello = Campagna.livello(selezionato)
	nomeLivello.Text = ("%d. %s"):format(selezionato, string.upper(livello.nome))
	local righe = {
		("%s  ·  %s era  ·  %s"):format(livello.anno, livello.epoca.nome, Biomi.Dati[livello.bioma].nome),
		("Enemy regiments: %d  ·  Your regiments: %d"):format(livello.numeroNemici, livello.maxReggimenti),
	}
	local fiume = false
	for _, t in ipairs(livello.terreno) do
		fiume = fiume or t.tipo == "fiume"
	end
	if fiume then
		table.insert(righe, "A river crosses the battlefield.")
	end
	table.insert(righe, ("Reward: %d coins"):format(livello.ricompensa))
	dettagli.Text = table.concat(righe, "\n")
	local stelle = stelleDi(selezionato)
	stellePannello.Text = string.rep("★", stelle) .. string.rep("☆", Campagna.STELLE_MASSIME - stelle)

	for _, figlio in ipairs(spazioBoss:GetChildren()) do
		if figlio:IsA("GuiObject") then
			figlio:Destroy()
		end
	end
	spazioBoss.Visible = livello.comandante ~= nil
	-- Il pannello è alto quanto serve: testo (o carta del boss) e sotto il bottone, senza vuoti.
	local larghezzaTesto = livello.comandante and -150 or -32
	nomeLivello.Size = UDim2.new(1, larghezzaTesto, 0, 34)
	dettagli.Size = UDim2.new(1, larghezzaTesto, 0, 200)
	local altezzaTesto = math.max(#righe * 20, dettagli.TextBounds.Y) -- le righe lunghe vanno a capo
	dettagli.Size = UDim2.new(1, larghezzaTesto, 0, altezzaTesto)
	local fondo = 84 + altezzaTesto
	if livello.comandante then
		fondo = math.max(fondo, 14 + 160)
	end
	pannello.Size = UDim2.fromOffset(460, fondo + 12 + 56 + 14)
	if livello.comandante then
		local carta = Carta.crea(livello.comandante)
		carta.Size = UDim2.fromScale(1, 1)
		carta.Parent = spazioBoss
	end

	if sbloccato(selezionato) then
		bottoneAttacca.Text = "ATTACK"
		bottoneAttacca.BackgroundColor3 = ARANCIO
		bottoneAttacca.AutoButtonColor = true
	else
		bottoneAttacca.Text = "LOCKED"
		bottoneAttacca.BackgroundColor3 = GRIGIO
		bottoneAttacca.AutoButtonColor = false
	end
	local totale = 0
	for _, n in pairs(stato.stelle or {}) do
		totale += n
	end
	titoloStelle.Text = ("★ %d/%d"):format(totale, Campagna.TOTALE * Campagna.STELLE_MASSIME)
end

local function seleziona(numero, istantanea)
	selezionato = math.clamp(numero, 1, Campagna.TOTALE)
	aggiornaNodi()
	aggiornaPannello()
	aggiornaCamera(istantanea)
end

local function impostaAmbiente()
	local atmosfera = Lighting:FindFirstChildOfClass("Atmosphere")
	local profondita = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
	ambienteSalvato = {
		atmosfera = atmosfera and { atmosfera.Density, atmosfera.Haze },
		profondita = profondita and profondita.Enabled,
	}
	if atmosfera then
		atmosfera.Density = 0.12
		atmosfera.Haze = 0.3
	end
	if profondita then
		profondita.Enabled = false
	end
end

local function ripristinaAmbiente()
	if not ambienteSalvato then
		return
	end
	local atmosfera = Lighting:FindFirstChildOfClass("Atmosphere")
	local profondita = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
	if atmosfera and ambienteSalvato.atmosfera then
		atmosfera.Density, atmosfera.Haze = ambienteSalvato.atmosfera[1], ambienteSalvato.atmosfera[2]
	end
	if profondita and ambienteSalvato.profondita ~= nil then
		profondita.Enabled = ambienteSalvato.profondita
	end
	ambienteSalvato = nil
end

local function nodoSotto(posizioneSchermo)
	local raggio = workspace.CurrentCamera:ScreenPointToRay(posizioneSchermo.X, posizioneSchermo.Y)
	local parametri = RaycastParams.new()
	parametri.FilterType = Enum.RaycastFilterType.Include
	parametri.FilterDescendantsInstances = { cartella }
	local colpo = workspace:Raycast(raggio.Origin, raggio.Direction * 2000, parametri)
	return colpo and colpo.Instance:GetAttribute("Livello")
end

function Mappa.apri(dati)
	-- Costruita prima che il server misurasse le quote: rifalla sulle quote vere.
	if cartella and not costruitaConMisure and misureComplete() then
		cartella:Destroy()
		cartella = nil
		nodi, puntini = {}, {}
	end
	if not cartella then
		costruisci()
	end
	aperta = true
	cartella.Parent = workspace
	impostaAmbiente()
	interfaccia.Visible = true
	zoom = 1
	seleziona(math.min(dati.livello or (stato and stato.livello) or 1, Campagna.TOTALE), true)
	-- Il livello da giocare pulsa.
	connessioneAnimazione = RunService.RenderStepped:Connect(function()
		local nodo = stato and nodi[math.min(stato.livello, Campagna.TOTALE)]
		if nodo and stelleDi(stato.livello) == 0 then
			nodo.base.Transparency = 0.15 + 0.15 * math.sin(os.clock() * 5)
		end
	end)
end

function Mappa.chiudi()
	if not aperta then
		return
	end
	aperta = false
	interfaccia.Visible = false
	if cartella then
		cartella.Parent = nil
	end
	if connessioneAnimazione then
		connessioneAnimazione:Disconnect()
		connessioneAnimazione = nil
	end
	ripristinaAmbiente()
end

function Mappa.aperta()
	return aperta
end

function Mappa.aggiorna(nuovoStato)
	stato = nuovoStato
	if aperta then
		aggiornaNodi()
		aggiornaPannello()
	end
end

function Mappa.inizializza(gui, r)
	remoti = r
	interfaccia = Stile.crea("Frame", {
		Name = "Mappa",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})

	local intestazione = Stile.pannello({
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.fromOffset(360, 56),
		BackgroundColor3 = Stile.Colori.Sfondo,
		BackgroundTransparency = 0.1,
		Parent = interfaccia,
	})
	Stile.titolo({
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(0.55, -16, 1, -20),
		Text = "CAMPAIGN",
		TextColor3 = ORO,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = intestazione,
	})
	titoloStelle = Stile.titolo({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 12),
		Size = UDim2.new(0.45, -16, 1, -24),
		Text = "",
		Font = Stile.Font,
		TextColor3 = ORO,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = intestazione,
	})

	local chiudi = Stile.bottone({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 10),
		Size = UDim2.fromOffset(56, 52),
		Text = "X",
		Parent = interfaccia,
	}, Stile.Colori.Rosso)
	chiudi.Activated:Connect(function()
		remoti.TornaLobby:InvokeServer()
	end)

	-- Frecce per scorrere i livelli e zoom.
	local comandi = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(4 * 62, 56),
		BackgroundTransparency = 1,
		Parent = interfaccia,
	}, { Stile.crea("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }) })
	local voci = {
		{ "<", function() seleziona(selezionato - 1) end },
		{ ">", function() seleziona(selezionato + 1) end },
		{ "-", function() zoom = math.min(zoom * 1.4, 3.2); aggiornaCamera() end },
		{ "+", function() zoom = math.max(zoom / 1.4, 0.45); aggiornaCamera() end },
	}
	for i, voce in ipairs(voci) do
		local b = Stile.bottone({ Size = UDim2.fromOffset(54, 54), Text = voce[1], LayoutOrder = i, Parent = comandi }, Stile.Colori.Secondario)
		b.Activated:Connect(voce[2])
	end

	pannello = Stile.pannello({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(460, 250),
		BackgroundColor3 = Color3.fromRGB(60, 44, 30),
		Parent = interfaccia,
	})
	nomeLivello = Stile.titolo({
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -150, 0, 34),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = pannello,
	})
	stellePannello = Stile.testo({
		Position = UDim2.fromOffset(16, 48),
		Size = UDim2.fromOffset(120, 30),
		Text = "",
		Font = Stile.Font,
		TextColor3 = ORO,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = pannello,
	})
	dettagli = Stile.testo({
		Position = UDim2.fromOffset(16, 84),
		Size = UDim2.new(1, -150, 0, 90),
		Text = "",
		Font = Stile.FontTesto,
		TextScaled = false,
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = pannello,
	})
	spazioBoss = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(112, 160),
		BackgroundTransparency = 1,
		Parent = pannello,
	})
	bottoneAttacca = Stile.bottone({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -14),
		Size = UDim2.new(1, -28, 0, 56),
		Text = "ATTACK",
		Parent = pannello,
	}, ARANCIO)
	bottoneAttacca.Activated:Connect(function()
		if not sbloccato(selezionato) then
			Notifiche.mostra("Win the previous battles to unlock this one.")
			return
		end
		-- Il server costruisce il campo di battaglia: qualche istante.
		Notifiche.mostra("Marching to " .. Campagna.Battaglie[selezionato].nome .. "...")
		local ok, messaggio = remoti.AvviaCampagna:InvokeServer(selezionato)
		if not ok and messaggio then
			Notifiche.mostra(messaggio, Stile.Colori.Rosso)
		end
	end)

	UserInputService.InputBegan:Connect(function(input, usatoDaGui)
		if not aperta or usatoDaGui then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local numero = nodoSotto(Vector2.new(input.Position.X, input.Position.Y))
			if numero then
				seleziona(numero)
			end
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if aperta and input.UserInputType == Enum.UserInputType.MouseWheel then
			zoom = math.clamp(zoom * (input.Position.Z > 0 and 1 / 1.2 or 1.2), 0.45, 3.2)
			aggiornaCamera()
		end
	end)
	-- Il server manda "mappa" quando il giocatore entra nel portale o preme PLAY.
	remoti.Fase.OnClientEvent:Connect(function(dati)
		if dati.fase == "mappa" then
			Mappa.apri(dati)
		elseif aperta then
			Mappa.chiudi()
		end
	end)
end

return Mappa
