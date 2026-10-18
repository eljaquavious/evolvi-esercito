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
local Epoche = require(ReplicatedStorage.Shared.Config.Epoche)
local Cielo = require(script.Parent.Parent.Cielo)
local Stile = require(script.Parent.Stile)
local Carta = require(script.Parent.Carta)
local Icone = require(script.Parent.Icone)
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

-- Interfaccia 2D (sulla tela 1920x1080 di Stile.radice).
local interfaccia, pannello, cielo, chipBattaglia, nomeLivello, infoLivello, dettagli
local stellePannello = {} -- le 3 stelle in alto a destra nel pannello
local scudi = {} -- i 5 scudi della difficoltà
local spazioNemici, contaNemici, spazioPremi, testoMonetePremio, tesseraCarta, iconaCarta
local bottoneAttacca, testoAttacca, iconaAttacca
local chipEpoca, numeroStelle, numeroMonete
local schede = {} -- linguette delle epoche in basso a sinistra
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
		FontFace = Stile.FontTitolo,
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
		-- Etichetta sopra il livello: bollino tondo col numero, stelline sotto, "BOSS" sopra.
		-- Le BillboardGui non stanno sulla tela di Stile.radice: misure in pixel veri dello schermo.
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(160, 136)
		gui.StudsOffset = Vector3.new(0, 6, 0)
		gui.LightInfluence = 0
		gui.AlwaysOnTop = true
		gui.Parent = base
		local fila = Stile.crea("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromOffset(78, 24),
			BackgroundTransparency = 1,
			Parent = gui,
		}, {
			Stile.crea("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 1),
			}),
		})
		local stelline = {}
		for i = 1, Campagna.STELLE_MASSIME do
			stelline[i] = Stile.icona("star", { Size = UDim2.fromOffset(24, 24), LayoutOrder = i, Parent = fila })
		end
		local bollino = Stile.crea("Frame", {
			Name = "Bollino",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -16),
			Size = UDim2.fromOffset(58, 58),
			BackgroundColor3 = Stile.BIANCO,
			Parent = gui,
		}, { Stile.tondo(), Stile.bordo(Stile.CONTORNO, 4) })
		local sfumaturaBollino = Stile.sfumatura(Stile.PAL.grigio.t, Stile.PAL.grigio.b)
		sfumaturaBollino.Parent = bollino
		Stile.crea("Frame", {
			Position = UDim2.fromScale(0.22, 0.08),
			Size = UDim2.fromScale(0.56, 0.32),
			BackgroundColor3 = Stile.BIANCO,
			BackgroundTransparency = 0.7,
			Parent = bollino,
		}, { Stile.tondo() })
		local numeroTesto = Stile.scritta({
			Size = UDim2.fromScale(1, 1),
			Text = tostring(numero),
			TextSize = numero >= 10 and 28 or 32,
			Contorno = 3,
			Parent = bollino,
		})
		local lucchetto = Stile.icona("lock", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.6, 0.6),
			Visible = false,
			Parent = bollino,
		})
		local chipBoss
		if boss then
			chipBoss = Stile.chip({
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -82),
				Size = UDim2.fromOffset(72, 26),
				Parent = gui,
			}, "rosso", "BOSS", 18)
			chipBoss:FindFirstChildOfClass("UIStroke").Thickness = 3
		end
		-- Nome della battaglia, solo sul livello selezionato.
		local nome = Stile.scritta({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, boss and -110 or -82),
			Size = UDim2.fromOffset(160, 24),
			Text = battaglia.nome,
			TextSize = 20,
			Contorno = 3,
			Visible = false,
			Parent = gui,
		})
		nodi[numero] = {
			base = base,
			gui = gui,
			stelle = stelline,
			fila = fila,
			bollino = bollino,
			sfumatura = sfumaturaBollino,
			numero = numeroTesto,
			lucchetto = lucchetto,
			nome = nome,
		}

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

-- Rende più o meno trasparente un'icona (immagine o emoji: Icone.crea può dare l'una o l'altra).
local function sfumaIcona(icona, trasparenza)
	if icona:IsA("ImageLabel") then
		icona.ImageTransparency = trasparenza
	elseif icona:IsA("TextLabel") then
		icona.TextTransparency = trasparenza
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
		-- Bollino: oro se vinto, verde se è il prossimo da giocare, grigio col lucchetto se bloccato.
		local pal = stelle > 0 and Stile.PAL.oro or (sbloccato(numero) and Stile.PAL.verde or Stile.PAL.grigio)
		nodo.sfumatura.Color = ColorSequence.new(pal.t, pal.b)
		nodo.numero.Visible = sbloccato(numero) and true or false
		nodo.lucchetto.Visible = not sbloccato(numero)
		local lato = numero == selezionato and 66 or 58
		nodo.bollino.Size = UDim2.fromOffset(lato, lato)
		nodo.fila.Visible = stelle > 0
		for i, stellina in ipairs(nodo.stelle) do
			sfumaIcona(stellina, i <= stelle and 0 or 0.65)
		end
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

-- Tipi di truppa dell'armata nemica (primo round, più l'eventuale comandante), senza ripetizioni.
local function tipiNemici(livello)
	local tipi, visti = {}, {}
	local function aggiungi(tipo)
		if tipo and not visti[tipo] and Epoche.Truppe[tipo] then
			visti[tipo] = true
			table.insert(tipi, tipo)
		end
	end
	aggiungi(livello.comandante)
	for _, reggimento in ipairs(Campagna.armata(livello, 1, false)) do
		aggiungi(reggimento.tipo)
	end
	return tipi
end

-- Difficoltà da 1 a 5 scudi: cresce col posto del livello nella sua epoca (il primo → 1 scudo, l'ultimo → 5),
-- che è anche quello che fa crescere numero e forza dei nemici.
local function difficolta(livello)
	return math.clamp(math.ceil(livello.grado / 2), 1, 5)
end

local function svuota(contenitore)
	for _, figlio in ipairs(contenitore:GetChildren()) do
		if figlio:IsA("GuiObject") then
			figlio:Destroy()
		end
	end
end

-- Epoca raggiunta dal giocatore (quella del prossimo livello da giocare).
local function epocaRaggiunta()
	return stato and Campagna.livello(math.min(stato.livello, Campagna.TOTALE)).indiceEpoca or 1
end

local function aggiornaSchede(epocaScelta)
	for i, scheda in ipairs(schede) do
		local raggiunta = i <= epocaRaggiunta()
		Stile.coloraPulsante(scheda.bottone, i == epocaScelta and "blu" or "grigio")
		scheda.lucchetto.Visible = not raggiunta
		local sinistra = raggiunta and 0 or 44
		scheda.etichetta.Position = UDim2.new(0, sinistra + 8, 0.5, 0)
		scheda.etichetta.Size = UDim2.new(1, -sinistra - 16, 0, 40)
	end
end

local function aggiornaPannello()
	local livello = Campagna.livello(selezionato)
	local stelle = stelleDi(selezionato)
	local bioma = Biomi.Dati[livello.bioma]

	-- Testata: colore del bioma, numero della battaglia, nome e stelle conquistate.
	local colore = bioma and bioma.casella or Color3.fromRGB(150, 196, 110)
	cielo:FindFirstChildOfClass("UIGradient").Color =
		ColorSequence.new(colore:Lerp(Stile.BIANCO, 0.2), colore:Lerp(Color3.new(0, 0, 0), 0.4))
	chipBattaglia.Text = "BATTLE " .. selezionato
	nomeLivello.Text = livello.nome
	for i, stella in ipairs(stellePannello) do
		sfumaIcona(stella, i <= stelle and 0 or 0.7)
	end

	infoLivello.Text = ("%s · %s ERA"):format(livello.anno, string.upper(livello.epoca.nome))
	local fiume, trincee = false, false
	for _, t in ipairs(livello.terreno) do
		fiume = fiume or t.tipo == "fiume"
		trincee = trincee or t.tipo == "trincea"
	end
	local righe = { bioma and bioma.nome or livello.bioma }
	if fiume then
		table.insert(righe, "River crossing")
	end
	if trincee then
		table.insert(righe, "Trenches")
	end
	table.insert(righe, ("Your regiments: %d"):format(livello.maxReggimenti))
	dettagli.Text = table.concat(righe, " · ")

	local scudiPieni = difficolta(livello)
	for i, scudo in ipairs(scudi) do
		sfumaIcona(scudo, i <= scudiPieni and 0 or 0.75)
	end

	-- Armata nemica: le carte dei reggimenti che si incontrano (e del comandante, se c'è).
	svuota(spazioNemici)
	local tipi = tipiNemici(livello)
	local larghezza = #tipi >= 4 and 94 or 118
	for i, tipo in ipairs(tipi) do
		local carta = Carta.mini(tipo)
		carta.Size = UDim2.fromOffset(larghezza, math.floor(larghezza / Carta.PROPORZIONE))
		carta.LayoutOrder = i
		carta.Parent = spazioNemici
	end
	contaNemici.Text = ("%d REGIMENTS"):format(livello.numeroNemici)

	-- Premi: monete e, alla prima vittoria, una carta.
	testoMonetePremio.Text = Stile.numero(livello.ricompensa)
	local defPremio = stelle == 0 and livello.cartaPremio and Epoche.Truppe[livello.cartaPremio]
	tesseraCarta.Visible = defPremio and true or false
	if defPremio then
		Icone.cambia(iconaCarta, Icone.carta(defPremio))
	end
	spazioPremi.Monete.Size = UDim2.new(defPremio and 0.5 or 1, defPremio and -6 or 0, 1, 0)

	if sbloccato(selezionato) then
		Stile.coloraPulsante(bottoneAttacca, "rosso")
		testoAttacca.Text = "ATTACK"
		Icone.cambia(iconaAttacca, "fight")
	else
		Stile.coloraPulsante(bottoneAttacca, "grigio")
		testoAttacca.Text = "LOCKED"
		Icone.cambia(iconaAttacca, "lock")
	end

	-- Barra in alto: epoca, stelle totali e monete.
	chipEpoca.Text = string.upper(livello.epoca.nome)
	local totale = 0
	for _, n in pairs(stato and stato.stelle or {}) do
		totale += n
	end
	numeroStelle.Text = ("%d/%d"):format(totale, Campagna.TOTALE * Campagna.STELLE_MASSIME)
	numeroMonete.Text = Stile.numero(stato and stato.monete or 0)
	aggiornaSchede(livello.indiceEpoca)
end

local function seleziona(numero, istantanea)
	selezionato = math.clamp(numero, 1, Campagna.TOTALE)
	aggiornaNodi()
	aggiornaPannello()
	aggiornaCamera(istantanea)
end

-- Aria limpida sulla mappa, per vedere tutta l'Europa.
local DENSITA_MAPPA = 0.12

local function impostaAmbiente()
	Cielo.campo()
	local atmosfera = Lighting:FindFirstChildOfClass("Atmosphere")
	local profondita = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
	ambienteSalvato = {
		atmosfera = atmosfera and { atmosfera.Density, atmosfera.Haze },
		profondita = profondita and profondita.Enabled,
	}
	if atmosfera then
		atmosfera.Density = DENSITA_MAPPA
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
	-- Solo se l'aria è ancora quella della mappa: se nel frattempo è partita una battaglia, il suo meteo
	-- (nebbia, pioggia...) è già al suo posto e non va sovrascritto.
	if atmosfera and ambienteSalvato.atmosfera and math.abs(atmosfera.Density - DENSITA_MAPPA) < 0.001 then
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

-- Etichetta grigia in maiuscolo del pannello ("DIFFICULTY", "ENEMY ARMY"...).
local function etichettaSezione(genitore, y, testo)
	return Stile.testo({
		Position = UDim2.fromOffset(26, y),
		Size = UDim2.new(1, -52, 0, 30),
		Text = testo,
		TextSize = 24,
		TextScaled = false,
		TextColor3 = Stile.Colori.TestoSecondario,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = genitore,
	})
end

-- Tessera blu notte dei premi (monete, carta).
local function tesseraPremio(proprieta, icona, testo)
	proprieta.BackgroundColor3 = Stile.BIANCO
	local tessera = Stile.crea("Frame", proprieta, {
		Stile.angoli(20),
		Stile.bordo(Stile.CONTORNO, 4),
		Stile.sfumatura(Stile.PAL.notte.t, Stile.PAL.notte.d),
	})
	local immagine = Stile.icona(icona, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(64, 64),
		Parent = tessera,
	})
	local scritta = Stile.scritta({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.new(1, -92, 0, 44),
		Text = testo,
		TextSize = 38,
		Contorno = 4,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = tessera,
	})
	scritta.TextScaled = true
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 38, Parent = scritta })
	return tessera, scritta, immagine
end

function Mappa.inizializza(gui, r)
	remoti = r
	local tela = Stile.radice(gui)
	interfaccia = Stile.crea("Frame", {
		Name = "Mappa",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = tela,
	})

	-- In alto a sinistra: indietro (torna alla lobby) e targa arancione "Campaign" con l'epoca.
	local indietro = Stile.pulsanteTondo({
		Name = "Indietro",
		Position = UDim2.fromOffset(26, 20),
	}, "blu", "back", 100)
	indietro.Parent = interfaccia
	indietro.Activated:Connect(function()
		remoti.TornaLobby:InvokeServer()
	end)

	local targa = Stile.crea("Frame", {
		Name = "Targa",
		Position = UDim2.fromOffset(150, 24),
		Size = UDim2.fromOffset(560, 92),
		BackgroundColor3 = Stile.BIANCO,
		Parent = interfaccia,
	}, { Stile.angoli(26), Stile.bordo(Stile.CONTORNO, 6), Stile.sfumatura(Stile.PAL.arancio.t, Stile.PAL.arancio.b) })
	Stile.crea("Frame", {
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0.4, 0),
		BackgroundColor3 = Stile.BIANCO,
		BackgroundTransparency = 0.75,
		Parent = targa,
	}, { Stile.angoli(18) })
	Stile.icona("campaign", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -8, 0.5, -4),
		Size = UDim2.fromOffset(118, 118),
		ZIndex = 2,
		Parent = targa,
	})
	Stile.scritta({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 116, 0.5, 0),
		Size = UDim2.fromOffset(250, 70),
		Text = "Campaign",
		TextSize = 60,
		Contorno = 6,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = targa,
	})
	local _, etichettaEpoca = Stile.chip({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(170, 50),
		Parent = targa,
	}, "notte", "", 26)
	chipEpoca = etichettaEpoca

	-- In alto al centro: stelle conquistate e monete.
	local _, stelleNumero = Stile.pillola({
		Name = "Stelle",
		Position = UDim2.fromOffset(770, 30),
		Size = UDim2.fromOffset(240, 78),
		Parent = interfaccia,
	}, "star", "0/90")
	numeroStelle = stelleNumero
	local _, moneteNumero, piu = Stile.pillola({
		Name = "Monete",
		Position = UDim2.fromOffset(1066, 30),
		Size = UDim2.fromOffset(270, 78),
		Parent = interfaccia,
	}, "coin", "0", true)
	numeroMonete = moneteNumero
	piu.Activated:Connect(function()
		Notifiche.mostra("Visit the shop in the lobby to get more coins.")
	end)

	-- In basso a sinistra: linguette delle epoche (portano al livello da giocare di quell'epoca).
	local larghezzeSchede = { 206, 200, 290 }
	local x = 26
	for i, epoca in ipairs(Epoche.Lista) do
		local larghezza = larghezzeSchede[i] or 220
		local bottone, etichetta, faccia = Stile.pulsante({
			Name = "Epoca" .. i,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, x, 1, -22),
			Size = UDim2.fromOffset(larghezza, 72),
			Parent = interfaccia,
		}, "grigio", { Testo = string.upper(epoca.nome), TestoSize = 32, Raggio = 36, Profondita = 7 })
		local lucchetto = Stile.icona("lock", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 14, 0.5, 0),
			Size = UDim2.fromOffset(40, 40),
			Visible = false,
			Parent = faccia,
		})
		schede[i] = { bottone = bottone, etichetta = etichetta, lucchetto = lucchetto }
		bottone.Activated:Connect(function()
			if i > epocaRaggiunta() then
				Notifiche.mostra("Win the previous era to unlock " .. epoca.nome .. ".")
				return
			end
			-- Il livello da giocare se è in questa epoca, altrimenti l'ultimo dell'epoca.
			local ultimo = i * Campagna.LIVELLI_PER_EPOCA
			seleziona(math.min(stato and stato.livello or 1, ultimo, Campagna.TOTALE))
		end)
		x += larghezza + 12
	end

	-- Frecce per scorrere i livelli e zoom: piccoli pulsanti tondi accanto alle epoche.
	local comandi = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, x + 18, 1, -22),
		Size = UDim2.fromOffset(4 * 76, 72),
		BackgroundTransparency = 1,
		Parent = interfaccia,
	}, {
		Stile.crea("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		}),
	})
	local voci = {
		{ "<", function() seleziona(selezionato - 1) end },
		{ ">", function() seleziona(selezionato + 1) end },
		{ "-", function() zoom = math.min(zoom * 1.4, 3.2); aggiornaCamera() end },
		{ "+", function() zoom = math.max(zoom / 1.4, 0.45); aggiornaCamera() end },
	}
	for i, voce in ipairs(voci) do
		local b = Stile.pulsante({
			Size = UDim2.fromOffset(66, 66),
			LayoutOrder = i,
			Parent = comandi,
		}, "blu", { Testo = voce[1], TestoSize = 40, Raggio = 33, Profondita = 6, Contorno = 4 })
		b.Activated:Connect(voce[2])
	end

	-- A destra: pannello bianco della battaglia selezionata.
	local lato = Stile.crea("Frame", {
		Name = "Lato",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -28, 0, 146),
		Size = UDim2.fromOffset(456, 904),
		BackgroundTransparency = 1,
		Parent = interfaccia,
	})
	Stile.crea("Frame", {
		Name = "Ombra",
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Stile.CONTORNO,
		BackgroundTransparency = 0.55,
		Parent = lato,
	}, { Stile.angoli(36) })
	pannello = Stile.crea("Frame", {
		Name = "Pannello",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Stile.Colori.PannelloChiaro,
		Parent = lato,
	}, { Stile.angoli(36), Stile.bordo(Stile.CONTORNO, 7) })

	-- Testata colorata col bioma della battaglia.
	cielo = Stile.crea("Frame", {
		Name = "Testata",
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 0, 226),
		BackgroundColor3 = Stile.BIANCO,
		Parent = pannello,
	}, { Stile.angoli(30), Stile.sfumatura(Stile.BIANCO, Stile.BIANCO) })
	Stile.crea("Frame", {
		Name = "Ombra",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Stile.CONTORNO,
		Parent = cielo,
	}, {
		Stile.angoli(30),
		Stile.crea("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.45, 0.9),
				NumberSequenceKeypoint.new(1, 0.35),
			}),
		}),
	})
	local _, etichettaBattaglia = Stile.chip({
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.fromOffset(176, 46),
		Parent = cielo,
	}, "verde", "BATTLE 1", 26)
	chipBattaglia = etichettaBattaglia
	local filaStelle = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 14),
		Size = UDim2.fromOffset(138, 46),
		BackgroundTransparency = 1,
		Parent = cielo,
	}, {
		Stile.crea("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2),
		}),
	})
	for i = 1, Campagna.STELLE_MASSIME do
		stellePannello[i] = Stile.icona("star", { Size = UDim2.fromOffset(44, 44), LayoutOrder = i, Parent = filaStelle })
	end
	nomeLivello = Stile.scritta({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 18, 1, -12),
		Size = UDim2.new(1, -36, 0, 76),
		Text = "",
		TextSize = 68,
		Contorno = 6,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = cielo,
	})
	nomeLivello.TextScaled = true
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 68, Parent = nomeLivello })

	-- Anno, epoca e dettagli del campo.
	infoLivello = Stile.testo({
		Position = UDim2.fromOffset(26, 246),
		Size = UDim2.new(1, -52, 0, 32),
		Text = "",
		TextSize = 27,
		TextScaled = false,
		TextColor3 = Stile.Colori.TestoSecondario,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = pannello,
	})
	dettagli = Stile.testo({
		Position = UDim2.fromOffset(26, 280),
		Size = UDim2.new(1, -52, 0, 26),
		Text = "",
		TextSize = 21,
		TextScaled = false,
		FontFace = Stile.FontTesto,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = pannello,
	})

	-- Difficoltà: 5 scudi, quelli pieni accesi.
	etichettaSezione(pannello, 326, "DIFFICULTY")
	for i = 1, 5 do
		scudi[i] = Stile.icona("cls_inf", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -24 - (5 - i) * 46, 0, 341),
			Size = UDim2.fromOffset(44, 44),
			Parent = pannello,
		})
	end

	-- Armata nemica.
	etichettaSezione(pannello, 380, "ENEMY ARMY")
	contaNemici = Stile.testo({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -26, 0, 383),
		Size = UDim2.fromOffset(200, 26),
		Text = "",
		TextSize = 20,
		TextScaled = false,
		TextColor3 = Stile.Colori.TestoSecondario,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = pannello,
	})
	spazioNemici = Stile.crea("Frame", {
		Name = "Nemici",
		Position = UDim2.fromOffset(18, 414),
		Size = UDim2.new(1, -36, 0, 176),
		BackgroundTransparency = 1,
		Parent = pannello,
	}, {
		Stile.crea("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})

	-- Premi.
	etichettaSezione(pannello, 604, "REWARDS")
	spazioPremi = Stile.crea("Frame", {
		Name = "Premi",
		Position = UDim2.fromOffset(20, 640),
		Size = UDim2.new(1, -40, 0, 84),
		BackgroundTransparency = 1,
		Parent = pannello,
	})
	local _, testoMonete = tesseraPremio({ Name = "Monete", Size = UDim2.new(0.5, -6, 1, 0), Parent = spazioPremi }, "coin", "0")
	testoMonetePremio = testoMonete
	local tessera, _, icona = tesseraPremio({
		Name = "Carta",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.5, -6, 1, 0),
		Parent = spazioPremi,
	}, "card_roman_legionaries", "CARD")
	tesseraCarta, iconaCarta = tessera, icona

	-- ATTACCA: grande pulsante rosso (grigio "LOCKED" se la battaglia è bloccata).
	local bottone, etichetta, faccia = Stile.pulsante({
		Name = "Attacca",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -22),
		Size = UDim2.new(1, -40, 0, 130),
		Parent = pannello,
	}, "rosso", { Testo = "ATTACK", TestoSize = 68, Icona = "fight", IconaSize = 90, IconaX = 22, Raggio = 26, Profondita = 10 })
	bottoneAttacca, testoAttacca, iconaAttacca = bottone, etichetta, faccia:FindFirstChild("Icona")
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
