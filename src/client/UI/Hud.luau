-- Interfaccia della lobby: in alto a sinistra il giocatore (avatar, livello, esperienza), in alto al centro
-- monete e stelle, a sinistra sei riquadri (shop, esercito, profilo, ranked, locker, codici), a destra l'avanzamento
-- della campagna per epoca, in basso il mazzo e il grande pulsante PLAY.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Epoche = require(ReplicatedStorage.Shared.Config.Epoche)
local Carte = require(ReplicatedStorage.Shared.Config.Carte)
local Campagna = require(ReplicatedStorage.Shared.Config.Campagna)
local Progressi = require(ReplicatedStorage.Shared.Config.Progressi)
local versione = require(ReplicatedStorage.Shared.Versione)
local Stile = require(script.Parent.Stile)
local Carta = require(script.Parent.Carta)

local Hud = {}

local player = Players.LocalPlayer
local azioni
local elementi = {} -- tutto quello che si nasconde fuori dalla lobby
local numeroMonete, numeroStelle, barraXp, numeroLivello, sottotitoloPlay
local mazzoCarte, mediaOvr, epocheUi, prossima, chipStelle
local mazzoMostrato -- per non ricostruire le carte se il mazzo non cambia
local avvisoLocker
local avvisoGiornaliero
local avvisoShop
local bersagli = {} -- elementi che il tutorial della lobby indica: "Shop", "Army", "Play", "Mazzo", "Campagna"...

local COLORI_EPOCA = { "oro", "blu", "rosso", "verde", "viola" }

local function nascondibile(oggetto)
	table.insert(elementi, oggetto)
	return oggetto
end

-- Esagono blu con il numero del livello.
local function distintivoLivello(proprieta)
	local fondo = Stile.icona("level", proprieta)
	local numero = Stile.scritta({
		Name = "Numero",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.6),
		Text = "1",
		TextSize = 34,
		ZIndex = (proprieta.ZIndex or 1) + 1,
		Parent = fondo,
	})
	numero.TextScaled = true
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 34, Parent = numero })
	return fondo, numero
end

-- Riquadro del giocatore: avatar vero di Roblox in un cerchio dorato, nome, barra dell'esperienza.
local function schedaGiocatore(tela)
	local scheda = nascondibile(Stile.crea("Frame", {
		Name = "Giocatore",
		Position = UDim2.fromOffset(30, 22),
		Size = UDim2.fromOffset(450, 120),
		BackgroundTransparency = 1,
		Parent = tela,
	}))
	Stile.pannelloVetro({
		Position = UDim2.fromOffset(60, 12),
		Size = UDim2.fromOffset(380, 96),
		Parent = scheda,
	}, 30)
	local cerchio = Stile.crea("Frame", {
		Size = UDim2.fromOffset(120, 120),
		BackgroundColor3 = Stile.VETRO,
		BackgroundTransparency = 0.3,
		ZIndex = 3,
		Parent = scheda,
	}, { Stile.tondo(), Stile.bordo(Stile.BIANCO, 2, 0.6) })
	local avatar = Stile.crea("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(100, 100),
		BackgroundColor3 = Color3.fromHex("#3A3D48"),
		ZIndex = 4,
		Parent = cerchio,
	}, { Stile.tondo() })
	task.spawn(function()
		local ok, immagine = pcall(function()
			return Players:GetUserThumbnailAsync(
				player.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size150x150
			)
		end)
		if ok then
			avatar.Image = immagine
		end
	end)
	local nome = Stile.scritta({
		Position = UDim2.fromOffset(134, 22),
		Size = UDim2.fromOffset(230, 40),
		Text = player.DisplayName,
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Parent = scheda,
	})
	nome.TextScaled = true
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 34, Parent = nome })
	barraXp = Stile.barra({
		Position = UDim2.fromOffset(130, 66),
		Size = UDim2.fromOffset(250, 30),
		ZIndex = 3,
		Parent = scheda,
	}, "acqua", 18)
	local _, numero = distintivoLivello({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(412, 40),
		Size = UDim2.fromOffset(76, 76),
		ZIndex = 5,
		Parent = scheda,
	})
	numeroLivello = numero
end

-- Pannello della campagna a destra: una riga per epoca con stelle e barra.
local function pannelloCampagna(tela)
	local pannello = nascondibile(Stile.pannelloVetro({
		Name = "Campagna",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -28, 0, 168),
		Size = UDim2.fromOffset(404, 152 + 100 * #Epoche.Lista),
		Parent = tela,
	}, 30))
	bersagli.Campagna = pannello
	local testata = Stile.crea("Frame", {
		Size = UDim2.new(1, 0, 0, 86),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = pannello,
	})
	-- Linea sottile sotto il titolo.
	Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, -36, 0, 2),
		BackgroundColor3 = Stile.BIANCO,
		BackgroundTransparency = 0.75,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = testata,
	})
	Stile.icona("campaign", {
		Position = UDim2.fromOffset(-14, -30),
		Size = UDim2.fromOffset(116, 116),
		ZIndex = 4,
		Parent = testata,
	})
	Stile.scritta({
		Position = UDim2.fromOffset(104, 14),
		Size = UDim2.fromOffset(190, 56),
		Text = "Campaign",
		TextSize = 44,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
		Parent = testata,
	})
	local _, testoChip = Stile.chip({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(92, 40),
		ZIndex = 4,
		Parent = testata,
	}, "notte", "0/90", 22)
	chipStelle = testoChip

	epocheUi = {}
	for i, epoca in ipairs(Epoche.Lista) do
		local y = 104 + (i - 1) * 100
		local riga = Stile.crea("Frame", {
			Position = UDim2.fromOffset(18, y),
			Size = UDim2.new(1, -36, 0, 86),
			BackgroundTransparency = 1,
			ZIndex = 2,
			Parent = pannello,
		})
		-- Riga di vetro, senza il colore dell'epoca (Mattia, 29/10/2026: sezioni meno colorate).
		local faccia = Stile.pannelloVetro({
			Size = UDim2.fromScale(1, 1),
			ZIndex = 3,
			Parent = riga,
		}, 20)
		local base = faccia
		local nomeEpoca = Stile.scritta({
			Position = UDim2.fromOffset(16, 8),
			-- Si ferma prima della stella (che comincia a 126 px dal bordo destro).
			Size = UDim2.fromOffset(210, 32),
			Text = string.upper(epoca.nome),
			TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 4,
			Parent = faccia,
		})
		-- "AGE OF GUNPOWDER" è lungo: si rimpicciolisce per non finire sotto la stella.
		nomeEpoca.TextScaled = true
		Stile.crea("UITextSizeConstraint", { MaxTextSize = 24, Parent = nomeEpoca })
		local stella = Stile.icona("star", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -92, 0, 4),
			Size = UDim2.fromOffset(34, 34),
			ZIndex = 4,
			Parent = faccia,
		})
		local conto = Stile.scritta({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 6),
			Size = UDim2.fromOffset(80, 34),
			Text = "0/" .. Campagna.livelliEpoca(i) * Campagna.STELLE_MASSIME,
			TextSize = 28,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 4,
			Parent = faccia,
		})
		local lucchetto = Stile.icona("lock", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 2),
			Size = UDim2.fromOffset(40, 40),
			ZIndex = 4,
			Visible = false,
			Parent = faccia,
		})
		local barra = Stile.barra({
			Position = UDim2.fromOffset(14, 44),
			Size = UDim2.new(1, -28, 0, 26),
			ZIndex = 4,
			Parent = faccia,
		}, i == 1 and "oro" or "verde")
		epocheUi[i] = {
			nome = nomeEpoca,
			base = base,
			faccia = faccia,
			stella = stella,
			conto = conto,
			lucchetto = lucchetto,
			barra = barra,
			pal = COLORI_EPOCA[i] or "blu",
		}
	end
	prossima = Stile.testo({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(1, -30, 0, 26),
		Text = "",
		TextSize = 22,
		TextScaled = false,
		TextColor3 = Color3.fromHex("#D4D7E2"),
		ZIndex = 2,
		Parent = pannello,
	})
end

-- azioni: { play, esercito, shop, profilo, ranked, armadio, codici, giornaliero } (funzioni)
function Hud.inizializza(gui, a)
	azioni = a
	local tela = Stile.radice(gui)

	schedaGiocatore(tela)

	-- Monete e stelle in alto al centro.
	local soldi = nascondibile(Stile.crea("Frame", {
		Name = "Soldi",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 30),
		Size = UDim2.fromOffset(560, 76),
		BackgroundTransparency = 1,
		Parent = tela,
	}))
	local _, monete, piu = Stile.pillola({
		Size = UDim2.fromOffset(270, 76),
		Parent = soldi,
	}, "coin", "0", true)
	numeroMonete = monete
	piu.Activated:Connect(azioni.shop)
	local _, stelle = Stile.pillola({
		Position = UDim2.fromOffset(318, 0),
		Size = UDim2.fromOffset(240, 76),
		Parent = soldi,
	}, "star", "0/" .. Campagna.TOTALE * Campagna.STELLE_MASSIME)
	numeroStelle = stelle
	bersagli.Monete = soldi

	-- Ingranaggio delle impostazioni in alto a destra (musica, effetti, modalità prestazioni).
	if azioni.impostazioni then
		local ingranaggio = nascondibile(Stile.pulsanteTondo({
			Name = "Impostazioni",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -28, 0, 36),
			Parent = tela,
		}, "blu", "settings", 88))
		Stile.vetro(ingranaggio)
		ingranaggio.Activated:Connect(azioni.impostazioni)
	end

	-- Sette riquadri di vetro a sinistra (il settimo, Daily, sotto gli altri). Più piccoli e distanziati
	-- (Mattia, 29/10/2026): lo spazio basta perché uno cresciuto col mouse sopra non tocchi i vicini.
	local LATO, PASSO = 150, 174
	local menu = nascondibile(Stile.crea("Frame", {
		Name = "Menu",
		Position = UDim2.fromOffset(36, 176),
		Size = UDim2.fromOffset(PASSO + LATO, PASSO * 3 + LATO),
		BackgroundTransparency = 1,
		Parent = tela,
	}))
	local function riquadro(colonna, riga, pal, icona, testo, azione)
		local bottone = Stile.riquadro({
			Position = UDim2.fromOffset(colonna * PASSO, riga * PASSO),
			Size = UDim2.fromOffset(LATO, LATO),
			Parent = menu,
		}, pal, icona, testo)
		bottone.Activated:Connect(azione)
		bersagli[testo] = bottone
		return bottone
	end
	local negozio = riquadro(0, 0, "rosso", "shop", "Shop", azioni.shop)
	-- "!" quando ci sono casse vinte da riscattare nello SHOP.
	avvisoShop = Stile.avviso(negozio)
	avvisoShop.Visible = false
	riquadro(1, 0, "blu", "army", "Army", azioni.esercito)
	riquadro(0, 1, "viola", "profile", "Profile", azioni.profilo)
	riquadro(1, 1, "oro", "ranked", "Ranked", azioni.ranked)
	local locker = riquadro(0, 2, "acqua", "locker", "Locker", azioni.armadio)
	avvisoLocker = Stile.avviso(locker)
	avvisoLocker.Visible = false
	riquadro(1, 2, "rosa", "codes", "Codes", azioni.codici)
	local giornaliero = riquadro(0, 3, "verde", "daily", "Daily", azioni.giornaliero)
	avvisoGiornaliero = Stile.avviso(giornaliero)
	avvisoGiornaliero.Visible = false

	pannelloCampagna(tela)

	-- Mazzo in basso al centro: grande come prima della riduzione dell'interfaccia (Mattia, 29/10/2026).
	-- Proprio al centro (Mattia, 11/11/2026): prima era spostato di 60 px a sinistra. La posizione vera la mette
	-- sistemaMazzo più sotto.
	local k = Stile.ingrandimento()
	local mazzo = nascondibile(Stile.pannelloVetro({
		Name = "Mazzo",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -66 * k),
		Size = UDim2.fromOffset(728, 236),
		Parent = tela,
	}, 28))
	Stile.crea("UIScale", { Scale = k, Parent = mazzo })
	Stile.scritta({
		Position = UDim2.fromOffset(24, 12),
		Size = UDim2.fromOffset(300, 40),
		Text = "Your Deck",
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = mazzo,
	})
	mediaOvr = Stile.testo({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 14),
		Size = UDim2.fromOffset(240, 32),
		Text = "",
		TextSize = 26,
		TextScaled = false,
		FontFace = Stile.FontEtichetta,
		TextColor3 = Stile.Colori.Oro,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = mazzo,
	})
	mazzoCarte = Stile.crea("Frame", {
		Position = UDim2.fromOffset(20, 56),
		Size = UDim2.new(1, -40, 0, 160),
		BackgroundTransparency = 1,
		Parent = mazzo,
	}, {
		Stile.crea("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- PLAY in basso a destra (su telefono e tablet più a sinistra, lontano dal pulsante del salto).
	-- Grande come prima della riduzione dell'interfaccia (Mattia, 29/10/2026): misure di prima per k.
	local play, _, _, sotto = Stile.pulsante({
		Name = "Play",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -28, 1, -48 * k),
		Size = UDim2.fromOffset(math.floor(424 * k), math.floor(186 * k)),
		Parent = tela,
	}, "verde", {
		-- Niente spade: la scritta usa tutta la larghezza (Mattia, 29/10/2026).
		Testo = "PLAY",
		TestoSize = math.floor(110 * k),
		Sotto = "",
		SottoSize = math.floor(34 * k),
		Raggio = 30,
		Profondita = 8,
		Contorno = 7,
	})
	sottotitoloPlay = sotto
	nascondibile(play)
	Stile.vetro(play)
	play.Activated:Connect(azioni.play)
	bersagli.Play = play
	bersagli.Mazzo = mazzo

	-- Schermi stretti (tablet 4:3, alcuni telefoni): il mazzo si sposta a sinistra per non finire sotto PLAY,
	-- senza toccare il menu dei riquadri.
	local function sistemaMazzo()
		local scala = Stile.scala()
		if scala <= 0 then
			return
		end
		local larghezza = tela.AbsoluteSize.X / scala
		local metaMazzo = 728 * k / 2
		local centro = larghezza / 2 -- al centro dello schermo (Mattia, 11/11/2026; prima 60 px a sinistra)
		local sinistraPlay = (play.AbsolutePosition.X - tela.AbsolutePosition.X) / scala
		if play.AbsoluteSize.X > 0 and centro + metaMazzo > sinistraPlay - 20 then
			centro = math.max(sinistraPlay - 20 - metaMazzo, 36 + 324 + 20 + metaMazzo)
		end
		mazzo.Position = UDim2.new(0, centro, 1, -66 * k)
	end
	Stile.ScalaCambiata:Connect(function()
		task.defer(sistemaMazzo)
	end)
	task.defer(sistemaMazzo)

	nascondibile(Stile.testo({
		Name = "Versione",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 30, 1, -12),
		Size = UDim2.fromOffset(300, 24),
		Text = "v" .. versione,
		TextSize = 20,
		TextScaled = false,
		TextColor3 = Color3.fromHex("#E8EAF6"),
		TextTransparency = 0.15,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = tela,
	}))
end

local function mostraMazzo(mazzo)
	local firma = table.concat(mazzo, ",")
	if firma == mazzoMostrato then
		return
	end
	mazzoMostrato = firma
	for _, figlio in ipairs(mazzoCarte:GetChildren()) do
		if figlio:IsA("GuiObject") then
			figlio:Destroy()
		end
	end
	local somma, quante = 0, 0
	for i = 1, Carte.DIMENSIONE_MAZZO or 6 do
		local tipo = mazzo[i]
		local cella
		if tipo then
			cella = Carta.mini(tipo, i)
			local def = Epoche.Truppe[tipo]
			somma += Carte.valutazioni(def).OVR
			quante += 1
		else
			-- Posto vuoto: sagoma tratteggiata con il "+".
			cella = Stile.crea("TextButton", {
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = Color3.fromHex("#15161C"),
				BackgroundTransparency = 0.3,
			}, {
				Stile.angoli(16),
				Stile.bordo(Stile.BIANCO, 3, 0.6),
			})
			Stile.icona("plus", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.45),
				Size = UDim2.fromOffset(48, 48),
				Parent = cella,
			})
		end
		cella.Activated:Connect(azioni.esercito)
		cella.Size = UDim2.fromOffset(106, 154)
		cella.LayoutOrder = i
		cella.Parent = mazzoCarte
	end
	mediaOvr.Text = quante > 0 and ("AVG OVR %d"):format(math.floor(somma / quante + 0.5)) or ""
end

local function stelleDi(stato, numero)
	local stelle = stato.stelle or {}
	return stelle[numero] or stelle[tostring(numero)] or 0
end

function Hud.aggiorna(stato)
	if not stato then
		return
	end
	numeroMonete.Text = Stile.numero(stato.monete)
	if avvisoShop then
		avvisoShop.Visible = next(stato.casseDaRiscattare or {}) ~= nil
	end
	local totale = 0
	for _, n in pairs(stato.stelle or {}) do
		totale += n
	end
	local massimo = Campagna.TOTALE * Campagna.STELLE_MASSIME
	numeroStelle.Text = ("%d/%d"):format(totale, massimo)
	chipStelle.Text = ("%d/%d"):format(totale, massimo)

	if stato.completata then
		sottotitoloPlay.Text = "Campaign complete!"
		prossima.Text = "CAMPAIGN COMPLETE!"
	else
		local livello = Campagna.livello(stato.livello)
		sottotitoloPlay.Text = ("Battle %d: %s"):format(stato.livello, livello.nome)
		prossima.Text = ("NEXT: BATTLE %d · %s"):format(stato.livello, string.upper(livello.nome))
	end

	-- Avanzamento per epoca: stelle prese sul massimo; le epoche non ancora raggiunte sono grigie col lucchetto.
	for i, ui in ipairs(epocheUi) do
		local per = Campagna.livelliEpoca(i)
		local primo = Campagna.primoDellEpoca(i)
		local raggiunta = stato.completata or (stato.livello or 1) >= primo
		local stelle = 0
		for n = primo, primo + per - 1 do
			stelle += stelleDi(stato, n)
		end
		-- Epoche non raggiunte: vetro più chiaro e nome spento.
		ui.faccia.BackgroundTransparency = raggiunta and 0.35 or 0.65
		ui.nome.TextTransparency = raggiunta and 0 or 0.45
		ui.conto.Visible = raggiunta
		ui.stella.Visible = raggiunta
		ui.lucchetto.Visible = not raggiunta
		ui.conto.Text = ("%d/%d"):format(stelle, per * Campagna.STELLE_MASSIME)
		ui.barra:imposta(raggiunta and stelle / (per * Campagna.STELLE_MASSIME) or 0)
	end

	local livello, xp, serve = Progressi.livello(stato.esperienza or 0)
	numeroLivello.Text = tostring(livello)
	barraXp:imposta(math.max(xp / serve, 0.04), ("%s / %s XP"):format(Stile.numero(xp), Stile.numero(serve)))
	mostraMazzo(stato.mazzo or {})
end

-- Il "!" sul riquadro Locker: ci sono titoli o cosmetici nuovi da vedere.
-- Il "!" sul riquadro Daily: c'è un premio giornaliero da ritirare.
function Hud.mostraGiornaliero(visibile)
	if avvisoGiornaliero then
		avvisoGiornaliero.Visible = visibile
	end
end

function Hud.mostraNovita(visibile)
	if avvisoLocker then
		avvisoLocker.Visible = visibile
	end
end

-- Elemento della lobby che il tutorial indica ("Play", "Mazzo", "Shop", "Army", "Daily", "Campagna"...).
function Hud.bersaglio(nome)
	return bersagli[nome]
end

-- In lobby si vede tutto; in mappa e in partita c'è la loro interfaccia al posto di questa.
function Hud.mostraLobby(visibile)
	for _, oggetto in ipairs(elementi) do
		oggetto.Visible = visibile
	end
end

return Hud
