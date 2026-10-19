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

local COLORI_EPOCA = { "oro", "blu", "rosso", "verde" }

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
	Stile.crea("Frame", {
		Position = UDim2.fromOffset(60, 12),
		Size = UDim2.fromOffset(380, 96),
		BackgroundColor3 = Stile.BIANCO,
		Parent = scheda,
	}, { Stile.angoli(30), Stile.bordo(Stile.CONTORNO, 5), Stile.sfumatura(Stile.PAL.notte.t, Stile.PAL.notte.d) })
	local cerchio = Stile.crea("Frame", {
		Size = UDim2.fromOffset(120, 120),
		BackgroundColor3 = Stile.BIANCO,
		ZIndex = 3,
		Parent = scheda,
	}, { Stile.tondo(), Stile.bordo(Stile.CONTORNO, 5), Stile.sfumatura(Stile.PAL.oro.t, Stile.PAL.oro.b) })
	local avatar = Stile.crea("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(100, 100),
		BackgroundColor3 = Color3.fromHex("#DDE6FF"),
		ZIndex = 4,
		Parent = cerchio,
	}, { Stile.tondo(), Stile.bordo(Stile.CONTORNO, 3) })
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
	local pannello = nascondibile(Stile.crea("Frame", {
		Name = "Campagna",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -28, 0, 168),
		Size = UDim2.fromOffset(404, 152 + 100 * #Epoche.Lista),
		BackgroundColor3 = Color3.fromHex("#F4F6FF"),
		Parent = tela,
	}, { Stile.angoli(30), Stile.bordo(Stile.CONTORNO, 6) }))
	local testata = Stile.crea("Frame", {
		Size = UDim2.new(1, 0, 0, 86),
		BackgroundColor3 = Stile.BIANCO,
		ZIndex = 2,
		Parent = pannello,
	}, { Stile.angoli(30), Stile.sfumatura(Stile.PAL.arancio.t, Stile.PAL.arancio.b) })
	Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = Stile.PAL.arancio.b,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = testata,
	})
	Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 3),
		Size = UDim2.new(1, 0, 0, 5),
		BackgroundColor3 = Stile.CONTORNO,
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
		local base = Stile.crea("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Stile.PAL[COLORI_EPOCA[i] or "blu"].d,
			ZIndex = 2,
			Parent = riga,
		}, { Stile.angoli(20), Stile.bordo(Stile.CONTORNO, 5) })
		local faccia = Stile.crea("Frame", {
			Size = UDim2.new(1, 0, 1, -6),
			BackgroundColor3 = Stile.BIANCO,
			ZIndex = 3,
			Parent = riga,
		}, {
			Stile.angoli(20),
			Stile.sfumatura(Stile.PAL[COLORI_EPOCA[i] or "blu"].t, Stile.PAL[COLORI_EPOCA[i] or "blu"].b),
		})
		local nomeEpoca = Stile.scritta({
			Position = UDim2.fromOffset(16, 6),
			Size = UDim2.fromOffset(240, 36),
			Text = string.upper(epoca.nome),
			TextSize = 28,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 4,
			Parent = faccia,
		})
		-- "AGE OF GUNPOWDER" è lungo: si rimpicciolisce per non finire sotto la stella.
		nomeEpoca.TextScaled = true
		Stile.crea("UITextSizeConstraint", { MaxTextSize = 28, Parent = nomeEpoca })
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
			Text = "0/" .. Campagna.LIVELLI_PER_EPOCA * Campagna.STELLE_MASSIME,
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
		TextColor3 = Stile.Colori.TestoSecondario,
		ZIndex = 2,
		Parent = pannello,
	})
end

-- azioni: { play, esercito, shop, profilo, ranked, armadio, codici } (funzioni)
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

	-- Sei riquadri a sinistra.
	local menu = nascondibile(Stile.crea("Frame", {
		Name = "Menu",
		Position = UDim2.fromOffset(30, 168),
		Size = UDim2.fromOffset(380, 596),
		BackgroundTransparency = 1,
		Parent = tela,
	}))
	local function riquadro(x, y, pal, icona, testo, azione)
		local bottone = Stile.riquadro({
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(180, 186),
			Parent = menu,
		}, pal, icona, testo)
		bottone.Activated:Connect(azione)
		return bottone
	end
	riquadro(0, 0, "rosso", "shop", "Shop", azioni.shop)
	riquadro(200, 0, "blu", "army", "Army", azioni.esercito)
	riquadro(0, 206, "viola", "profile", "Profile", azioni.profilo)
	local ranked = riquadro(200, 206, "oro", "ranked", "Ranked", azioni.ranked)
	Stile.nastro({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -36, 0, 4),
		Size = UDim2.fromOffset(104, 38),
		ZIndex = 8,
		Parent = ranked,
	}, "rosa", "SOON", 24)
	local locker = riquadro(0, 412, "acqua", "locker", "Locker", azioni.armadio)
	avvisoLocker = Stile.avviso(locker)
	avvisoLocker.Visible = false
	riquadro(200, 412, "rosa", "codes", "Codes", azioni.codici)

	pannelloCampagna(tela)

	-- Mazzo in basso al centro.
	local mazzo = nascondibile(Stile.pannello({
		Name = "Mazzo",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, -60, 1, -66),
		Size = UDim2.fromOffset(728, 236),
		Parent = tela,
	}, 0.2))
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

	-- PLAY in basso a destra.
	local play, _, _, sotto = Stile.pulsante({
		Name = "Play",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -30, 1, -48),
		Size = UDim2.fromOffset(424, 186),
		Parent = tela,
	}, "verde", {
		Testo = "PLAY",
		TestoSize = 96,
		Icona = "fight",
		IconaSize = 120,
		IconaX = 22,
		Sotto = "",
		SottoSize = 30,
		Raggio = 30,
		Profondita = 12,
		Contorno = 7,
	})
	sottotitoloPlay = sotto
	nascondibile(play)
	play.Activated:Connect(azioni.play)

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
				BackgroundColor3 = Color3.fromHex("#15163A"),
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
	local per = Campagna.LIVELLI_PER_EPOCA
	for i, ui in ipairs(epocheUi) do
		local primo = (i - 1) * per + 1
		local raggiunta = stato.completata or (stato.livello or 1) >= primo
		local stelle = 0
		for n = primo, primo + per - 1 do
			stelle += stelleDi(stato, n)
		end
		local pal = Stile.PAL[raggiunta and ui.pal or "grigio"]
		ui.base.BackgroundColor3 = pal.d
		ui.faccia:FindFirstChildOfClass("UIGradient").Color = ColorSequence.new(pal.t, pal.b)
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
function Hud.mostraNovita(visibile)
	if avvisoLocker then
		avvisoLocker.Visible = visibile
	end
end

-- In lobby si vede tutto; in mappa e in partita c'è la loro interfaccia al posto di questa.
function Hud.mostraLobby(visibile)
	for _, oggetto in ipairs(elementi) do
		oggetto.Visible = visibile
	end
end

return Hud
