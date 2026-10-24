-- Finestra LOCKER: schede COSMETICS (cosmetici da indossare in lobby), TITLES (titolo sopra la testa)
-- e CODES (codici della community). Più il riquadro che festeggia un titolo o un cosmetico appena ottenuto.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config.Ricompense)
local Cosmetici3D = require(ReplicatedStorage.Shared.Cosmetici3D)
local Stile = require(script.Parent.Stile)
local Notifiche = require(script.Parent.Notifiche)
local Preferiti = require(script.Parent.Preferiti)

local Armadio = {}

local player = Players.LocalPlayer
local remoti, gui
local finestra, contenuto, numeroMonete, contatore
local pagine = {} -- nome scheda -> Frame
local schede = {} -- { bottone, nome }
local schedaAttiva = "COSMETICS"
local filtroSlot = nil -- nil = tutti
local stato
local grigliaCosmetici, grigliaTitoli, chipFiltri = nil, nil, {}
local slotUi = {} -- slot -> { nome, togli }
local anteprimaVp, anteprimaMondo, anteprimaCamera, angolo = nil, nil, nil, 0
local targhettaTitolo, targhettaNome, testoTitoloScelto
local casellaCodice, esitoCodice, testoPremioFeedback
local nuovi = {} -- id -> true: ottenuti in questa sessione e non ancora visti (per il "!" e il nastro NEW)
local inCoda = {} -- sblocchi da festeggiare quando si torna in lobby
local puoMostrare = function()
	return true
end
local suNovita -- funzione(bool): accende o spegne il "!" sul riquadro della lobby

local ARANCIO_SCURO = Color3.fromHex("#15163A")

local function svuota(contenitore)
	for _, figlio in ipairs(contenitore:GetChildren()) do
		if figlio:IsA("GuiObject") then
			figlio:Destroy()
		end
	end
end

local function posseduto(tipo, id)
	if not stato then
		return false
	end
	local miei = tipo == "titolo" and stato.titoli or stato.cosmetici
	return miei ~= nil and miei[id] == true
end

local function indossato(tipo, oggetto)
	if not stato then
		return false
	end
	if tipo == "titolo" then
		return (stato.titolo or Config.TITOLO_INIZIALE) == oggetto.id
	end
	return (stato.indossati or {})[oggetto.slot] == oggetto.id
end

local function aggiornaNovita()
	if suNovita then
		suNovita(next(nuovi) ~= nil)
	end
end

-- ===================================================================== anteprime 3D

-- Da dove si guarda ogni tipo di cosmetico: elmi di tre quarti davanti, armature davanti, schiena da dietro.
local DIREZIONE = {
	Testa = Vector3.new(-0.75, 0.45, -1),
	Corpo = Vector3.new(-0.55, 0.25, -1),
	Schiena = Vector3.new(0.6, 0.25, 1),
	Aura = Vector3.new(-0.5, 0.35, -1),
}

local function luci(vp)
	vp.Ambient = Color3.fromRGB(150, 150, 165)
	vp.LightColor = Color3.fromRGB(255, 246, 230)
	vp.LightDirection = Vector3.new(-0.6, -1, -0.8)
end

-- Inquadra un modello nella telecamera della ViewportFrame.
local function inquadra(camera, modello, direzione, margine)
	local cf, misura = modello:GetBoundingBox()
	local raggio = misura.Magnitude / 2
	local distanza = raggio / math.tan(math.rad(camera.FieldOfView / 2)) * (margine or 1.05)
	camera.CFrame = CFrame.lookAt(cf.Position + direzione.Unit * distanza, cf.Position)
end

-- ViewportFrame con il modello 3D del cosmetico.
local function anteprimaCosmetico(oggetto, proprieta)
	proprieta.BackgroundTransparency = 1
	local vp = Stile.crea("ViewportFrame", proprieta)
	luci(vp)
	local modello = Cosmetici3D.costruisci(oggetto.id, oggetto.slot)
	if modello then
		modello.Parent = vp
		local camera = Stile.crea("Camera", { FieldOfView = 30, Parent = vp })
		vp.CurrentCamera = camera
		inquadra(camera, modello, DIREZIONE[oggetto.slot] or DIREZIONE.Testa)
	end
	return vp
end

Armadio.anteprimaCosmetico = anteprimaCosmetico

-- Il personaggio del giocatore, copiato con i cosmetici addosso, che gira lentamente.
local function aggiornaManichino()
	if not anteprimaMondo then
		return
	end
	anteprimaMondo:ClearAllChildren()
	local personaggio = player.Character
	if not personaggio then
		return
	end
	local archiviabile = personaggio.Archivable
	personaggio.Archivable = true
	local copia = personaggio:Clone()
	personaggio.Archivable = archiviabile
	if not copia then
		return
	end
	for _, d in ipairs(copia:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") or d:IsA("BillboardGui") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local radice = copia:FindFirstChild("HumanoidRootPart")
	if radice then
		radice.Transparency = 1
	end
	copia:PivotTo(CFrame.new())
	copia.Parent = anteprimaMondo
end

local function giraManichino(dt)
	if not (anteprimaVp and anteprimaVp.Visible and finestra.Visible and pagine.COSMETICS.Visible) then
		return
	end
	angolo += dt * 0.5
	local modello = anteprimaMondo:FindFirstChildOfClass("Model")
	if not modello then
		return
	end
	local cf, misura = modello:GetBoundingBox()
	local distanza = misura.Y / 2 / math.tan(math.rad(anteprimaCamera.FieldOfView / 2)) * 1.25
	local direzione = Vector3.new(math.sin(angolo), 0.18, -math.cos(angolo))
	anteprimaCamera.CFrame = CFrame.lookAt(cf.Position + direzione.Unit * distanza, cf.Position)
end

-- ===================================================================== pezzi comuni

-- Pulsante in basso di un oggetto: EQUIP, EQUIPPED, prezzo o LOCKED, secondo lo stato.
local function pulsanteOggetto(tipo, oggetto, proprieta, testoSize)
	testoSize = testoSize or 34
	local mio = posseduto(tipo, oggetto.id)
	local addosso = mio and indossato(tipo, oggetto)
	local bottone
	if addosso then
		bottone = Stile.pulsante(proprieta, "blu", {
			Testo = "EQUIPPED",
			TestoSize = testoSize,
			Icona = "check",
			IconaSize = testoSize + 8,
			IconaX = 10,
			Profondita = 6,
		})
		bottone.Activated:Connect(function()
			if tipo == "cosmetico" then
				-- Premuto di nuovo, il cosmetico si toglie.
				local ok, messaggio = remoti.Equipaggia:InvokeServer(tipo, nil, oggetto.slot)
				if not ok and messaggio then
					Notifiche.mostra(messaggio, Stile.Colori.Rosso)
				end
			end
		end)
	elseif mio then
		bottone = Stile.pulsante(proprieta, "verde", { Testo = "EQUIP", TestoSize = testoSize, Profondita = 6 })
		bottone.Activated:Connect(function()
			local ok, messaggio = remoti.Equipaggia:InvokeServer(tipo, oggetto.id)
			if not ok and messaggio then
				Notifiche.mostra(messaggio, Stile.Colori.Rosso)
			end
		end)
	elseif oggetto.monete or oggetto.robux then
		local robux = oggetto.robux ~= nil
		bottone = Stile.pulsante(proprieta, robux and "viola" or "oro", {
			Testo = robux and ("R$ " .. oggetto.robux.prezzo) or Stile.numero(oggetto.monete),
			TestoSize = testoSize,
			Icona = robux and "premium" or "coin",
			IconaSize = testoSize + 12,
			IconaX = 8,
			Profondita = 6,
		})
		bottone.Activated:Connect(function()
			local ok, messaggio = remoti.AcquistaOggetto:InvokeServer(tipo, oggetto.id)
			if messaggio then
				Notifiche.mostra(messaggio, ok and Stile.Colori.Verde or Stile.Colori.Rosso)
			end
		end)
	else
		local attuale, obiettivo = Config.avanzamento(oggetto, stato or {})
		local testo = "LOCKED"
		if oggetto.condizione and obiettivo > 1 then
			testo = ("%s / %s"):format(Stile.numero(math.min(attuale, obiettivo)), Stile.numero(obiettivo))
		elseif oggetto.soloCodice then
			testo = "CODE ONLY"
		elseif oggetto.cassa then
			testo = "CRATES"
		end
		bottone = Stile.pulsante(proprieta, "grigio", {
			Testo = testo,
			TestoSize = testoSize - 4,
			Icona = "lock",
			IconaSize = testoSize + 4,
			IconaX = 10,
			Profondita = 6,
		})
		bottone.Activated:Connect(function()
			Notifiche.mostra(Config.comeSbloccare(oggetto))
			if oggetto.cassa and Armadio.apriShop then
				Armadio.apriShop()
			end
			if oggetto.condizione and oggetto.condizione[1] == "preferito" then
				Preferiti.chiedi()
			end
		end)
	end
	return bottone
end

-- Nastro "NEW" sugli oggetti appena ottenuti.
local function nastroNuovo(genitore, oggetto)
	if nuovi[oggetto.id] then
		Stile.nastro({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -40, 0, 8),
			Size = UDim2.fromOffset(98, 40),
			ZIndex = 8,
			Parent = genitore,
		}, "rosso", "NEW", 26)
	end
end

-- Base scura + faccia sfumata, come i riquadri delle statistiche del profilo.
local function tessera(genitore, pal, proprieta)
	proprieta.BackgroundTransparency = 1
	proprieta.Parent = genitore
	local cella = Stile.crea("Frame", proprieta)
	Stile.crea("Frame", {
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 1, -8),
		BackgroundColor3 = pal.d,
		Parent = cella,
	}, { Stile.angoli(26), Stile.bordo(Stile.CONTORNO, 5) })
	local faccia = Stile.crea("Frame", {
		Name = "Faccia",
		Size = UDim2.new(1, 0, 1, -12),
		BackgroundColor3 = Stile.BIANCO,
		Parent = cella,
	}, { Stile.angoli(26), Stile.bordo(Stile.CONTORNO, 5), Stile.sfumatura(Stile.BIANCO, Color3.fromHex("#E4E9FA")) })
	return cella, faccia
end

local function ordina(lista, tipo)
	local copia = table.clone(lista)
	local posizione = {}
	for i, o in ipairs(lista) do
		posizione[o.id] = i
	end
	table.sort(copia, function(a, b)
		-- Prima quelli posseduti, poi l'ordine della lista.
		local pa, pb = posseduto(tipo, a.id), posseduto(tipo, b.id)
		if pa ~= pb then
			return pa
		end
		return posizione[a.id] < posizione[b.id]
	end)
	return copia
end

-- ===================================================================== scheda COSMETICS

local function cartaCosmetico(oggetto, ordine)
	local rarita = Config.Rarita[oggetto.rarita]
	local pal = Stile.PAL[rarita.pal]
	local mio = posseduto("cosmetico", oggetto.id)
	local cella, faccia = tessera(grigliaCosmetici, pal, { LayoutOrder = ordine })
	-- Vetrina colorata col modello 3D.
	local vetrina = Stile.crea("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 0, 156),
		BackgroundColor3 = Stile.BIANCO,
		ClipsDescendants = true,
		Parent = faccia,
	}, { Stile.angoli(20), Stile.bordo(Stile.CONTORNO, 4), Stile.sfumatura(pal.t, pal.b) })
	Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(150, 150),
		BackgroundColor3 = Stile.BIANCO,
		BackgroundTransparency = 0.75,
		Parent = vetrina,
	}, { Stile.tondo() })
	local vp = anteprimaCosmetico(oggetto, {
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = vetrina,
	})
	if not mio then
		vp.ImageColor3 = Color3.fromRGB(120, 120, 135)
		vp.ImageTransparency = 0.1
	end
	Stile.chip({
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(136, 32),
		ZIndex = 3,
		Parent = vetrina,
	}, rarita.pal, rarita.nome, 18)
	local nomeSlot = ""
	for _, s in ipairs(Config.Slot) do
		if s.id == oggetto.slot then
			nomeSlot = s.nome
		end
	end
	Stile.testo({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 12),
		Size = UDim2.fromOffset(90, 26),
		Text = nomeSlot,
		TextSize = 20,
		TextScaled = false,
		TextColor3 = Stile.BIANCO,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
		Parent = vetrina,
	})
	local nome = Stile.scritta({
		Position = UDim2.fromOffset(14, 170),
		Size = UDim2.new(1, -28, 0, 38),
		Text = oggetto.nome,
		TextSize = 32,
		TextColor3 = Stile.BIANCO,
		Parent = faccia,
	})
	nome.TextScaled = true
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 32, Parent = nome })
	Stile.testo({
		Position = UDim2.fromOffset(14, 208),
		Size = UDim2.new(1, -28, 0, 50),
		Text = Config.comeSbloccare(oggetto),
		TextSize = 22,
		TextScaled = false,
		TextWrapped = true,
		TextColor3 = Stile.Colori.TestoSecondario,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = faccia,
	})
	pulsanteOggetto("cosmetico", oggetto, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(1, -28, 0, 60),
		Parent = faccia,
	}, 30)
	nastroNuovo(cella, oggetto)
end

local function disegnaCosmetici()
	svuota(grigliaCosmetici)
	local lista = {}
	for _, o in ipairs(Config.Cosmetici) do
		if filtroSlot == nil or o.slot == filtroSlot then
			table.insert(lista, o)
		end
	end
	for i, oggetto in ipairs(ordina(lista, "cosmetico")) do
		cartaCosmetico(oggetto, i)
	end
	for slot, chip in pairs(chipFiltri) do
		Stile.coloraPulsante(chip, (slot == (filtroSlot or "TUTTI")) and "blu" or "grigio")
	end
	-- Cosa hai addosso, nel pannello a sinistra.
	for _, s in ipairs(Config.Slot) do
		local ui = slotUi[s.id]
		local id = stato and stato.indossati and stato.indossati[s.id]
		local oggetto = id and Config.cosmetico(id)
		ui.nome.Text = oggetto and oggetto.nome or "Empty"
		ui.nome.TextColor3 = oggetto and Stile.BIANCO or Color3.fromHex("#8F8CC0")
		ui.togli.Visible = oggetto ~= nil
	end
end

local function paginaCosmetici(pagina)
	-- A sinistra: il tuo personaggio che gira e cosa indossi.
	local pannello = Stile.pannello({
		Size = UDim2.new(0, 470, 1, 0),
		BackgroundColor3 = Color3.fromHex("#2E2566"),
		BackgroundTransparency = 0,
		Parent = pagina,
	})
	Stile.bordo(Stile.CONTORNO, 6).Parent = pannello
	Stile.scritta({
		Position = UDim2.fromOffset(0, 14),
		Size = UDim2.new(1, 0, 0, 44),
		Text = "YOUR COMMANDER",
		TextSize = 36,
		Parent = pannello,
	})
	local palco = Stile.crea("Frame", {
		Position = UDim2.fromOffset(20, 66),
		Size = UDim2.new(1, -40, 0, 340),
		BackgroundColor3 = Stile.BIANCO,
		ClipsDescendants = true,
		Parent = pannello,
	}, {
		Stile.angoli(22),
		Stile.bordo(Stile.CONTORNO, 4),
		Stile.sfumatura(Color3.fromHex("#5C6BC0"), Color3.fromHex("#1E1F45")),
	})
	anteprimaVp = Stile.crea("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = palco,
	})
	luci(anteprimaVp)
	anteprimaMondo = Stile.crea("WorldModel", { Parent = anteprimaVp })
	anteprimaCamera = Stile.crea("Camera", { FieldOfView = 35, Parent = anteprimaVp })
	anteprimaVp.CurrentCamera = anteprimaCamera

	for i, s in ipairs(Config.Slot) do
		local riga = Stile.crea("Frame", {
			Position = UDim2.fromOffset(20, 418 + (i - 1) * 70),
			Size = UDim2.new(1, -40, 0, 60),
			BackgroundColor3 = ARANCIO_SCURO,
			Parent = pannello,
		}, { Stile.angoli(18), Stile.bordo(Stile.CONTORNO, 4) })
		Stile.chip({
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 8, 0.5, 0),
			Size = UDim2.fromOffset(104, 44),
			Parent = riga,
		}, "acqua", s.nome, 22)
		local nome = Stile.testo({
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 126, 0.5, 0),
			Size = UDim2.new(1, -196, 0, 34),
			Text = "Empty",
			TextSize = 26,
			TextScaled = false,
			TextColor3 = Stile.BIANCO,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = riga,
		})
		local togli = Stile.pulsanteTondo({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, -2),
			Visible = false,
			Parent = riga,
		}, "rosso", "close", 50)
		togli.Activated:Connect(function()
			remoti.Equipaggia:InvokeServer("cosmetico", nil, s.id)
		end)
		slotUi[s.id] = { nome = nome, togli = togli }
	end

	-- A destra: filtri e griglia dei cosmetici.
	local destra = Stile.crea("Frame", {
		Position = UDim2.fromOffset(500, 0),
		Size = UDim2.new(1, -500, 1, 0),
		BackgroundTransparency = 1,
		Parent = pagina,
	})
	local filtri = Stile.crea("Frame", {
		Size = UDim2.new(1, 0, 0, 60),
		BackgroundTransparency = 1,
		Parent = destra,
	}, {
		Stile.crea("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local voci = { { "TUTTI", "ALL", 110 } }
	for _, s in ipairs(Config.Slot) do
		table.insert(voci, { s.id, s.nome, 130 })
	end
	for i, voce in ipairs(voci) do
		local chip = Stile.pulsante({
			Size = UDim2.fromOffset(voce[3], 56),
			LayoutOrder = i,
			Parent = filtri,
		}, i == 1 and "blu" or "grigio", { Testo = voce[2], TestoSize = 26, Profondita = 5, Raggio = 28, Contorno = 4 })
		chip.Activated:Connect(function()
			filtroSlot = voce[1] ~= "TUTTI" and voce[1] or nil
			disegnaCosmetici()
		end)
		chipFiltri[voce[1]] = chip
	end
	grigliaCosmetici = Stile.crea("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 74),
		Size = UDim2.new(1, 0, 1, -74),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 12,
		ScrollBarImageColor3 = Stile.CONTORNO,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = destra,
	}, {
		Stile.crea("UIGridLayout", {
			CellSize = UDim2.fromOffset(282, 340),
			CellPadding = UDim2.fromOffset(16, 18),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Stile.crea("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 16) }),
	})
end

-- ===================================================================== scheda TITLES

local function rigaTitolo(oggetto, ordine)
	local rarita = Config.Rarita[oggetto.rarita]
	local pal = Stile.PAL[rarita.pal]
	local mio = posseduto("titolo", oggetto.id)
	local cella, faccia = tessera(grigliaTitoli, pal, { LayoutOrder = ordine, Size = UDim2.new(1, 0, 0, 144) })
	faccia.ClipsDescendants = true
	-- Fascia colorata a sinistra con la rarità.
	local fascia = Stile.crea("Frame", {
		Size = UDim2.new(0, 18, 1, 0),
		BackgroundColor3 = Stile.BIANCO,
		BorderSizePixel = 0,
		Parent = faccia,
	}, { Stile.sfumatura(pal.t, pal.b) })
	fascia.ZIndex = 2
	local titolo = Stile.scritta({
		Position = UDim2.fromOffset(36, 12),
		Size = UDim2.new(1, -300, 0, 50),
		Text = string.upper(oggetto.nome),
		TextSize = 40,
		Contorno = 4,
		TextColor3 = mio and Color3.fromHex(rarita.colore) or Color3.fromHex("#9EA3C2"),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = faccia,
	})
	titolo.TextScaled = true
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 40, Parent = titolo })
	Stile.chip({
		Position = UDim2.fromOffset(36, 70),
		Size = UDim2.fromOffset(130, 30),
		Parent = faccia,
	}, rarita.pal, rarita.nome, 17)
	Stile.testo({
		Position = UDim2.fromOffset(178, 70),
		Size = UDim2.new(1, -440, 0, 30),
		Text = Config.comeSbloccare(oggetto),
		TextSize = 20,
		TextScaled = false,
		TextWrapped = true,
		TextColor3 = Stile.Colori.TestoSecondario,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = faccia,
	})
	if not mio and oggetto.condizione then
		local attuale, obiettivo = Config.avanzamento(oggetto, stato or {})
		if obiettivo > 1 then
			local barra = Stile.barra({
				Position = UDim2.fromOffset(36, 106),
				Size = UDim2.new(1, -310, 0, 18),
				Parent = faccia,
			}, rarita.pal)
			barra:imposta(attuale / obiettivo)
		end
	end
	pulsanteOggetto("titolo", oggetto, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -18, 0.5, 0),
		Size = UDim2.fromOffset(250, 76),
		Parent = faccia,
	}, 30)
	nastroNuovo(cella, oggetto)
end

local function disegnaTitoli()
	svuota(grigliaTitoli)
	for i, oggetto in ipairs(ordina(Config.Titoli, "titolo")) do
		rigaTitolo(oggetto, i)
	end
	local scelto = Config.titolo(stato and stato.titolo or Config.TITOLO_INIZIALE) or Config.titolo(Config.TITOLO_INIZIALE)
	targhettaTitolo.Text = "« " .. string.upper(scelto.nome) .. " »"
	targhettaTitolo.TextColor3 = Color3.fromHex(Config.Rarita[scelto.rarita].colore)
	testoTitoloScelto.Text = "Everyone in the lobby sees your title above your head."
end

local function paginaTitoli(pagina)
	local pannello = Stile.pannello({
		Size = UDim2.new(0, 470, 1, 0),
		BackgroundColor3 = Color3.fromHex("#2E2566"),
		BackgroundTransparency = 0,
		Parent = pagina,
	})
	Stile.bordo(Stile.CONTORNO, 6).Parent = pannello
	Stile.scritta({
		Position = UDim2.fromOffset(0, 14),
		Size = UDim2.new(1, 0, 0, 44),
		Text = "YOUR NAMEPLATE",
		TextSize = 36,
		Parent = pannello,
	})
	-- Come ti vedono gli altri: avatar e la targhetta sopra.
	local cielo = Stile.crea("Frame", {
		Position = UDim2.fromOffset(20, 66),
		Size = UDim2.new(1, -40, 0, 470),
		BackgroundColor3 = Stile.BIANCO,
		ClipsDescendants = true,
		Parent = pannello,
	}, {
		Stile.angoli(22),
		Stile.bordo(Stile.CONTORNO, 4),
		Stile.sfumatura(Color3.fromHex("#7FC8FF"), Color3.fromHex("#3B5BB5")),
	})
	targhettaNome = Stile.scritta({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 36),
		Size = UDim2.new(1, -30, 0, 56),
		Text = player.DisplayName,
		TextSize = 50,
		Contorno = 5,
		Parent = cielo,
	})
	targhettaNome.TextScaled = true
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 50, Parent = targhettaNome })
	targhettaTitolo = Stile.scritta({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96),
		Size = UDim2.new(1, -30, 0, 44),
		Text = "",
		TextSize = 36,
		Contorno = 4,
		FontFace = Stile.FontEtichetta,
		Parent = cielo,
	})
	targhettaTitolo.TextScaled = true
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 36, Parent = targhettaTitolo })
	local avatar = Stile.crea("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 10),
		Size = UDim2.fromOffset(320, 320),
		BackgroundTransparency = 1,
		Parent = cielo,
	})
	task.spawn(function()
		local ok, immagine = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.AvatarBust, Enum.ThumbnailSize.Size420x420)
		end)
		if ok then
			avatar.Image = immagine
		end
	end)
	testoTitoloScelto = Stile.testo({
		Position = UDim2.fromOffset(30, 560),
		Size = UDim2.new(1, -60, 0, 120),
		Text = "",
		TextSize = 26,
		TextScaled = false,
		TextWrapped = true,
		TextColor3 = Color3.fromHex("#B9B4E8"),
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = pannello,
	})

	grigliaTitoli = Stile.crea("ScrollingFrame", {
		Position = UDim2.fromOffset(500, 0),
		Size = UDim2.new(1, -500, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 12,
		ScrollBarImageColor3 = Stile.CONTORNO,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = pagina,
	}, {
		Stile.crea("UIListLayout", {
			Padding = UDim.new(0, 14),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Stile.crea("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 18) }),
	})
end

-- ===================================================================== scheda CODES

local function riscatta()
	local testo = casellaCodice.Text
	local ok, messaggio = remoti.RiscattaCodice:InvokeServer(testo)
	esitoCodice.Text = messaggio or ""
	esitoCodice.TextColor3 = ok and Stile.PAL.verde.t or Stile.BIANCO
	if ok then
		casellaCodice.Text = ""
		Notifiche.mostra(messaggio, Stile.Colori.Verde)
	end
end

-- Finestra dei feedback (solo per il proprietario del gioco): i più recenti in alto.
local function apriInbox()
	local tela = Stile.radice(gui)
	local velo = Stile.crea("TextButton", {
		Name = "Inbox",
		Text = "",
		AutoButtonColor = false,
		Position = UDim2.fromOffset(0, -200),
		Size = UDim2.new(1, 0, 1, 400),
		BackgroundColor3 = Stile.CONTORNO,
		BackgroundTransparency = 0.35,
		ZIndex = 70,
		Parent = tela,
	})
	local pannello = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(1400, 860),
		BackgroundColor3 = Color3.fromHex("#F4F6FF"),
		ZIndex = 71,
		Parent = velo,
	}, { Stile.angoli(36), Stile.bordo(Stile.CONTORNO, 7) })
	Stile.scritta({
		Position = UDim2.fromOffset(40, 20),
		Size = UDim2.fromOffset(900, 70),
		Text = "Feedback Inbox",
		TextSize = 60,
		Contorno = 6,
		TextColor3 = Stile.Colori.Oro,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 72,
		Parent = pannello,
	})
	local chiudi = Stile.chiudi({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -16, 0, 20),
		ZIndex = 80,
		Parent = pannello,
	})
	chiudi.Activated:Connect(function()
		velo:Destroy()
	end)
	local lista = Stile.crea("ScrollingFrame", {
		Position = UDim2.fromOffset(30, 110),
		Size = UDim2.new(1, -60, 1, -140),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 12,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 72,
		Parent = pannello,
	}, {
		Stile.crea("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local attesa = Stile.testo({
		Size = UDim2.new(1, 0, 0, 40),
		Text = "Loading...",
		TextSize = 30,
		TextScaled = false,
		ZIndex = 73,
		Parent = lista,
	})
	local voci = remoti.LeggiFeedback:InvokeServer() or {}
	attesa.Text = #voci == 0 and "No feedback in the last 14 days." or (#voci .. " feedback (last 14 days)")
	for i, v in ipairs(voci) do
		local scheda = Stile.crea("Frame", {
			Size = UDim2.new(1, -20, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = i,
			BackgroundColor3 = Stile.BIANCO,
			ZIndex = 73,
			Parent = lista,
		}, {
			Stile.angoli(20),
			Stile.bordo(Stile.CONTORNO, 4),
			Stile.crea("UIPadding", {
				PaddingTop = UDim.new(0, 12),
				PaddingBottom = UDim.new(0, 14),
				PaddingLeft = UDim.new(0, 20),
				PaddingRight = UDim.new(0, 20),
			}),
			Stile.crea("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		Stile.testo({
			Size = UDim2.new(1, 0, 0, 28),
			Text = ("%s  ·  campaign Lv.%s  ·  %s UTC"):format(tostring(v.nome), tostring(v.livello), os.date("!%d/%m/%Y %H:%M", v.t or 0)),
			TextSize = 24,
			TextScaled = false,
			TextColor3 = Stile.Colori.TestoSecondario,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1,
			ZIndex = 74,
			Parent = scheda,
		})
		Stile.testo({
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = tostring(v.testo),
			TextSize = 28,
			TextScaled = false,
			TextWrapped = true,
			FontFace = Stile.FontTesto,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2,
			ZIndex = 74,
			Parent = scheda,
		})
	end
end

local function paginaCodici(pagina)
	local LATO_X, LATO_Y = 820, 660
	local riga = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(LATO_X * 2 + 40, LATO_Y),
		BackgroundTransparency = 1,
		Parent = pagina,
	}, {
		Stile.crea("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 40),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- Riquadro colorato con alone, icona, titolo e sottotitolo. Restituisce la faccia, il sottotitolo e la cornice.
	local function riquadro(ordine, palA, palB, icona, titolo, sottotitolo)
		local cornice = Stile.crea("Frame", {
			Size = UDim2.fromOffset(LATO_X, LATO_Y),
			LayoutOrder = ordine,
			BackgroundTransparency = 1,
			Parent = riga,
		})
		local _, faccia = tessera(cornice, palA, { Size = UDim2.fromScale(1, 1) })
		faccia:FindFirstChildOfClass("UIGradient").Color = ColorSequence.new(palA.t, palB.b)
		for i, lato in ipairs({ 210, 160 }) do
			Stile.crea("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0, 104),
				Size = UDim2.fromOffset(lato, lato),
				BackgroundColor3 = Stile.BIANCO,
				BackgroundTransparency = 0.82 - i * 0.08,
				Parent = faccia,
			}, { Stile.tondo() })
		end
		Stile.icona(icona, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 104),
			Size = UDim2.fromOffset(160, 160),
			ZIndex = 2,
			Parent = faccia,
		})
		Stile.scritta({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 186),
			Size = UDim2.new(1, -60, 0, 66),
			Text = titolo,
			TextSize = 60,
			Contorno = 6,
			ZIndex = 2,
			Parent = faccia,
		})
		local sotto = Stile.testo({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 254),
			Size = UDim2.new(1, -80, 0, 64),
			Text = sottotitolo,
			TextSize = 26,
			TextScaled = false,
			TextWrapped = true,
			TextColor3 = Color3.fromHex("#FFF2FB"),
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 2,
			Parent = faccia,
		})
		return faccia, sotto, cornice
	end

	-- CODICI ------------------------------------------------------------------------------------
	local faccia = riquadro(1, Stile.PAL.rosa, Stile.PAL.viola, "codes", "Redeem a Code",
		"New codes drop with every update. Follow us so you don't miss them!")
	local campo = Stile.crea("Frame", {
		Position = UDim2.fromOffset(50, 330),
		Size = UDim2.new(1, -100, 0, 104),
		BackgroundColor3 = Stile.BIANCO,
		ZIndex = 2,
		Parent = faccia,
	}, { Stile.angoli(26), Stile.bordo(Stile.CONTORNO, 6) })
	casellaCodice = Stile.crea("TextBox", {
		Position = UDim2.fromOffset(26, 0),
		Size = UDim2.new(1, -52, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
		PlaceholderText = "Enter code...",
		PlaceholderColor3 = Color3.fromHex("#A7A9C7"),
		TextColor3 = Stile.Colori.TestoScuro,
		FontFace = Stile.FontTitolo,
		TextSize = 50,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Parent = campo,
	})
	casellaCodice.FocusLost:Connect(function(invio)
		if invio then
			riscatta()
		end
	end)
	local bottone = Stile.pulsante({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 456),
		Size = UDim2.fromOffset(360, 110),
		ZIndex = 2,
		Parent = faccia,
	}, "verde", { Testo = "REDEEM", TestoSize = 54, Icona = "check", IconaSize = 66, IconaX = 16, Raggio = 26 })
	bottone.Activated:Connect(riscatta)
	esitoCodice = Stile.scritta({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 586),
		Size = UDim2.new(1, -60, 0, 40),
		Text = "",
		TextSize = 30,
		Contorno = 4,
		ZIndex = 2,
		Parent = faccia,
	})
	esitoCodice.TextScaled = true
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 30, Parent = esitoCodice })

	-- FEEDBACK ----------------------------------------------------------------------------------
	local facciaF, sottoF, corniceF = riquadro(2, Stile.PAL.acqua, Stile.PAL.blu, "feedback", "Send Feedback",
		"Tell us what you love and what to fix. Your first feedback earns +150 coins!")
	testoPremioFeedback = sottoF
	local campoF = Stile.crea("Frame", {
		Position = UDim2.fromOffset(50, 322),
		Size = UDim2.new(1, -100, 0, 132),
		BackgroundColor3 = Stile.BIANCO,
		ZIndex = 2,
		Parent = facciaF,
	}, { Stile.angoli(24), Stile.bordo(Stile.CONTORNO, 6) })
	local casellaF = Stile.crea("TextBox", {
		Position = UDim2.fromOffset(20, 10),
		Size = UDim2.new(1, -40, 1, -34),
		BackgroundTransparency = 1,
		Text = "",
		PlaceholderText = "Your feedback...",
		PlaceholderColor3 = Color3.fromHex("#A7A9C7"),
		TextColor3 = Stile.Colori.TestoScuro,
		FontFace = Stile.FontTesto,
		TextSize = 26,
		MultiLine = true,
		TextWrapped = true,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 3,
		Parent = campoF,
	})
	local contaF = Stile.testo({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -4),
		Size = UDim2.fromOffset(120, 22),
		Text = "0/500",
		TextSize = 20,
		TextScaled = false,
		TextColor3 = Color3.fromHex("#A7A9C7"),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
		Parent = campoF,
	})
	casellaF:GetPropertyChangedSignal("Text"):Connect(function()
		if #casellaF.Text > 500 then
			casellaF.Text = string.sub(casellaF.Text, 1, 500)
		end
		contaF.Text = #casellaF.Text .. "/500"
	end)
	local esitoF = Stile.scritta({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 586),
		Size = UDim2.new(1, -60, 0, 40),
		Text = "",
		TextSize = 30,
		Contorno = 4,
		ZIndex = 2,
		Parent = facciaF,
	})
	esitoF.TextScaled = true
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 30, Parent = esitoF })
	local invia = Stile.pulsante({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 466),
		Size = UDim2.fromOffset(360, 100),
		ZIndex = 2,
		Parent = facciaF,
	}, "verde", { Testo = "SEND", TestoSize = 52, Icona = "feedback", IconaSize = 64, IconaX = 16, Raggio = 26 })
	local inviando = false
	invia.Activated:Connect(function()
		if inviando then
			return
		end
		inviando = true
		esitoF.Text = "Sending..."
		esitoF.TextColor3 = Stile.BIANCO
		local ok, messaggio = remoti.InviaFeedback:InvokeServer(casellaF.Text)
		esitoF.Text = messaggio or ""
		esitoF.TextColor3 = ok and Stile.PAL.verde.t or Stile.BIANCO
		if ok then
			casellaF.Text = ""
			Notifiche.mostra(messaggio, Stile.Colori.Verde)
		end
		inviando = false
	end)

	-- Solo il proprietario del gioco: pulsante INBOX per leggere i feedback.
	task.spawn(function()
		local ok, admin = pcall(function()
			return remoti.SonoAdmin:InvokeServer()
		end)
		if not (ok and admin) then
			return
		end
		local inbox = Stile.pulsante({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, -20),
			Size = UDim2.fromOffset(200, 70),
			ZIndex = 6,
			Parent = corniceF,
		}, "oro", { Testo = "INBOX", TestoSize = 32, Icona = "inbox", IconaSize = 50, IconaX = 10, Raggio = 22, Profondita = 6 })
		inbox.Activated:Connect(apriInbox)
	end)
end

-- ===================================================================== finestra

local function mostraScheda(nome)
	schedaAttiva = nome
	for _, s in ipairs(schede) do
		Stile.coloraPulsante(s.bottone, s.nome == nome and "blu" or "grigio")
	end
	for n, pagina in pairs(pagine) do
		pagina.Visible = n == nome
	end
	if nome == "COSMETICS" then
		aggiornaManichino()
	end
end

local function disegna()
	if not stato then
		return
	end
	disegnaCosmetici()
	disegnaTitoli()
	numeroMonete.Text = Stile.numero(stato.monete or 0)
	local miei, totale = 0, 0
	for _, lista in ipairs({ { Config.Titoli, stato.titoli }, { Config.Cosmetici, stato.cosmetici } }) do
		for _, o in ipairs(lista[1]) do
			totale += 1
			if lista[2] and lista[2][o.id] then
				miei += 1
			end
		end
	end
	contatore.Text = ("UNLOCKED %d/%d"):format(miei, totale)
end

function Armadio.inizializza(g, r, opzioni)
	gui, remoti = g, r
	opzioni = opzioni or {}
	puoMostrare = opzioni.puoMostrare or puoMostrare
	local fascia
	finestra, contenuto, fascia = Stile.finestra(gui, "Armadio", "Locker", "acqua", "locker")
	local _, numero = Stile.pillola({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -150, 0.5, -4),
		Size = UDim2.fromOffset(260, 70),
		ZIndex = 14,
		Parent = fascia,
	}, "coin", "0")
	numeroMonete = numero

	local barraSchede = Stile.crea("Frame", {
		Size = UDim2.fromOffset(1000, 70),
		BackgroundTransparency = 1,
		Parent = contenuto,
	}, {
		Stile.crea("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, voce in ipairs({ { "COSMETICS", "locker", 250 }, { "TITLES", "title", 196 }, { "CODES", "codes", 184 } }) do
		local bottone = Stile.pulsante({
			Size = UDim2.fromOffset(voce[3], 66),
			LayoutOrder = i,
			Parent = barraSchede,
		}, voce[1] == schedaAttiva and "blu" or "grigio", {
			Testo = voce[1],
			TestoSize = 30,
			Icona = voce[2],
			IconaSize = 48,
			IconaX = 10,
			Profondita = 6,
			Raggio = 30,
			Contorno = 4,
		})
		bottone.Activated:Connect(function()
			mostraScheda(voce[1])
		end)
		table.insert(schede, { bottone = bottone, nome = voce[1] })
		local pagina = Stile.crea("Frame", {
			Name = voce[1],
			Position = UDim2.fromOffset(0, 96),
			Size = UDim2.new(1, 0, 1, -96),
			BackgroundTransparency = 1,
			Visible = voce[1] == schedaAttiva,
			Parent = contenuto,
		})
		pagine[voce[1]] = pagina
	end
	local _, testo = Stile.chip({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(300, 52),
		Parent = contenuto,
	}, "notte", "UNLOCKED 0/0", 26)
	contatore = testo

	paginaCosmetici(pagine.COSMETICS)
	paginaTitoli(pagine.TITLES)
	paginaCodici(pagine.CODES)

	RunService.RenderStepped:Connect(giraManichino)
	-- Quando il personaggio rinasce, il manichino si rifà.
	player.CharacterAdded:Connect(function()
		task.wait(2)
		if finestra.Visible then
			aggiornaManichino()
		end
	end)

	-- Festeggia gli sblocchi quando il giocatore è in lobby (non in mezzo a una battaglia).
	remoti.Sblocco.OnClientEvent:Connect(function(lista)
		for _, s in ipairs(lista) do
			nuovi[s.id] = true
			table.insert(inCoda, s)
		end
		-- Se il Locker è già aperto le novità si vedono subito: niente "!" sul riquadro.
		if not finestra.Visible then
			aggiornaNovita()
		end
		if finestra.Visible then
			disegna()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			if #inCoda > 0 and puoMostrare() and not Armadio.festeggiando then
				Armadio.festeggia()
			end
		end
	end)
end

function Armadio.aggiorna(nuovoStato)
	if not nuovoStato then
		return
	end
	local prima = stato
	stato = nuovoStato
	if testoPremioFeedback then
		testoPremioFeedback.Text = stato.feedbackPremiato and "Tell us what you love and what to fix. We read every message!"
			or "Tell us what you love and what to fix. Your first feedback earns +150 coins!"
	end
	if finestra.Visible then
		disegna()
		-- I cosmetici addosso sono cambiati: il manichino si rifà quando il server li ha messi.
		local firmaPrima = prima and prima.indossati and table.concat({ prima.indossati.Testa or "", prima.indossati.Corpo or "", prima.indossati.Schiena or "" }, "|")
		local firma = stato.indossati and table.concat({ stato.indossati.Testa or "", stato.indossati.Corpo or "", stato.indossati.Schiena or "" }, "|")
		if firma ~= firmaPrima then
			task.delay(0.5, aggiornaManichino)
		end
	end
end

function Armadio.apri(scheda)
	finestra.Visible = true
	mostraScheda(scheda or schedaAttiva)
	disegna()
	-- Aperta la finestra, le novità sono viste: il "!" sparisce (il nastro NEW resta fino alla prossima apertura).
	task.delay(0.2, function()
		nuovi = {}
		aggiornaNovita()
	end)
end

function Armadio.chiudi()
	finestra.Visible = false
end

function Armadio.alterna(scheda)
	if finestra.Visible and (scheda == nil or scheda == schedaAttiva) then
		Armadio.chiudi()
	else
		Armadio.apri(scheda)
	end
end

function Armadio.aperta()
	return finestra.Visible
end

-- Un cosmetico appena trovato in una cassa: nastro NEW nel Locker e "!" sul riquadro della lobby.
function Armadio.segnaNuovo(id)
	nuovi[id] = true
	aggiornaNovita()
end

function Armadio.collegaNovita(funzione)
	suNovita = funzione
	aggiornaNovita()
end

-- ===================================================================== festeggiamento

-- Riquadro al centro: "NEW TITLE!" / "NEW COSMETIC!" con l'oggetto, EQUIP e AWESOME.
-- Se ne arrivano tanti insieme (ad esempio al primo ingresso dopo un aggiornamento) se ne mostrano tre,
-- gli altri sono riassunti in una notifica.
function Armadio.festeggia()
	if #inCoda > 3 then
		local resto = #inCoda - 3
		inCoda = { inCoda[1], inCoda[2], inCoda[3] }
		Notifiche.mostra(("+%d more unlocked: open your Locker!"):format(resto), Stile.Colori.Oro)
	end
	local voce = table.remove(inCoda, 1)
	local oggetto = voce and Config.trova(voce.tipo, voce.id)
	if not oggetto then
		return
	end
	Armadio.festeggiando = true
	local rarita = Config.Rarita[oggetto.rarita]
	local pal = Stile.PAL[rarita.pal]
	local tela = Stile.radice(gui)
	local velo = Stile.crea("TextButton", {
		Name = "Sblocco",
		Text = "",
		AutoButtonColor = false,
		Position = UDim2.fromOffset(0, -200),
		Size = UDim2.new(1, 0, 1, 400),
		BackgroundColor3 = Stile.CONTORNO,
		BackgroundTransparency = 0.35,
		ZIndex = 60,
		Parent = tela,
	})
	local alone = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(860, 860),
		BackgroundColor3 = pal.t,
		BackgroundTransparency = 0.8,
		ZIndex = 61,
		Parent = velo,
	}, { Stile.tondo() })
	Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.75, 0.75),
		BackgroundColor3 = pal.t,
		BackgroundTransparency = 0.6,
		ZIndex = 61,
		Parent = alone,
	}, { Stile.tondo() })
	local riquadro = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(620, 640),
		BackgroundTransparency = 1,
		ZIndex = 62,
		Parent = velo,
	})
	local _, faccia = tessera(riquadro, pal, { Size = UDim2.fromScale(1, 1), ZIndex = 62 })
	faccia:FindFirstChildOfClass("UIGradient").Color = ColorSequence.new(pal.t, pal.b)
	Stile.nastro({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(520, 86),
		Rotation = -3,
		ZIndex = 70,
		Parent = riquadro,
	}, "rosso", voce.tipo == "titolo" and "NEW TITLE!" or "NEW COSMETIC!", 54)
	if voce.tipo == "cosmetico" then
		anteprimaCosmetico(oggetto, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 60),
			Size = UDim2.fromOffset(330, 300),
			ZIndex = 64,
			Parent = faccia,
		})
	else
		Stile.icona("title", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 70),
			Size = UDim2.fromOffset(180, 180),
			ZIndex = 64,
			Parent = faccia,
		})
		local scritta = Stile.scritta({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 262),
			Size = UDim2.new(1, -60, 0, 80),
			Text = "« " .. string.upper(oggetto.nome) .. " »",
			TextSize = 60,
			Contorno = 6,
			TextColor3 = Color3.fromHex(rarita.colore),
			ZIndex = 64,
			Parent = faccia,
		})
		scritta.TextScaled = true
		Stile.crea("UITextSizeConstraint", { MaxTextSize = 60, Parent = scritta })
	end
	if voce.tipo == "cosmetico" then
		local nome = Stile.scritta({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 360),
			Size = UDim2.new(1, -60, 0, 60),
			Text = oggetto.nome,
			TextSize = 52,
			Contorno = 5,
			ZIndex = 64,
			Parent = faccia,
		})
		nome.TextScaled = true
		Stile.crea("UITextSizeConstraint", { MaxTextSize = 52, Parent = nome })
	end
	Stile.chip({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 428),
		Size = UDim2.fromOffset(190, 40),
		ZIndex = 64,
		Parent = faccia,
	}, "notte", rarita.nome, 24)
	local indossa = Stile.pulsante({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(0.5, -10, 1, -26),
		Size = UDim2.fromOffset(260, 96),
		ZIndex = 64,
		Parent = faccia,
	}, "verde", { Testo = "EQUIP", TestoSize = 46, Raggio = 24 })
	local bene = Stile.pulsante({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0.5, 10, 1, -26),
		Size = UDim2.fromOffset(260, 96),
		ZIndex = 64,
		Parent = faccia,
	}, "blu", { Testo = "AWESOME", TestoSize = 42, Raggio = 24 })

	local scala = Stile.crea("UIScale", { Scale = 0.6, Parent = riquadro })
	TweenService:Create(scala, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local tempo = 0
	local giro = RunService.RenderStepped:Connect(function(dt)
		tempo += dt
		local s = 1 + math.sin(tempo * 3) * 0.05
		alone.Size = UDim2.fromOffset(860 * s, 860 * s)
	end)
	local function chiudi()
		giro:Disconnect()
		velo:Destroy()
		Armadio.festeggiando = false
	end
	indossa.Activated:Connect(function()
		remoti.Equipaggia:InvokeServer(voce.tipo, oggetto.id)
		chiudi()
	end)
	bene.Activated:Connect(chiudi)
	Stile.seleziona(bene)
end

return Armadio
