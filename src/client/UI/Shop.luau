-- Finestra dello shop, una pagina che scorre con quattro sezioni (le schede in alto ci saltano):
--   ~ Troop Crates ~   Small / Medium / Big, con le probabilità per rarità
--   ~ Armory Crates ~  casse dei cosmetici, con le probabilità e tutti i cosmetici che si possono trovare
--   ~ Titles ~         titoli in vendita (monete o Robux)
--   ~ Coin Packs ~     pacchetti di monete (Robux)
-- Cosa esce da una cassa lo mostra AperturaCassa (evento CassaAperta del server).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Casse = require(ReplicatedStorage.Shared.Config.Casse)
local Carte = require(ReplicatedStorage.Shared.Config.Carte)
local Epoche = require(ReplicatedStorage.Shared.Config.Epoche)
local Config = require(ReplicatedStorage.Shared.Config.Ricompense)
local Stile = require(script.Parent.Stile)
local Icone = require(script.Parent.Icone)
local Notifiche = require(script.Parent.Notifiche)
local Armadio = require(script.Parent.Armadio)
local AperturaCassa = require(script.Parent.AperturaCassa)

local Shop = {}

local finestra, pagina, numeroMonete
local remotiShop
local stato
local costruita = false
local sezioni = {} -- nome scheda -> Frame dell'intestazione (per saltarci)
local schede = {} -- { bottone, nome }
local dinamici = {} -- funzioni che aggiornano le parti che cambiano con lo stato (posseduti, monete)

local LARGHEZZA = 1690 -- contenuto della pagina (1708 meno la barra di scorrimento)

local function hex(h)
	return Color3.fromHex(h)
end

-- Colori dei riquadri delle rarità delle carte (come i cartoncini di Carta).
local RARITA_CARTE = {
	bronze = { hex("#FFD9A8"), hex("#C8752F") },
	silver = { hex("#FFFFFF"), hex("#8FA3CF") },
	gold = { hex("#FFF2A0"), hex("#F09A00") },
	legend = { hex("#FF6AD5"), hex("#5A2BFF") },
}
-- Ritratto di esempio per ogni rarità.
local ESEMPIO_CARTE = { bronze = "Legionario", silver = "Cavaliere", gold = "CarroArmato", legend = "Napoleone" }

local function svuota(contenitore)
	for _, figlio in ipairs(contenitore:GetChildren()) do
		if figlio:IsA("GuiObject") then
			figlio:Destroy()
		end
	end
end

-- Scheda 3D colorata (base scura sotto, faccia con sfumatura). Restituisce il riquadro e la faccia.
local function scheda(genitore, pal, proprieta, raggio)
	pal = type(pal) == "string" and Stile.PAL[pal] or pal
	proprieta.BackgroundTransparency = 1
	proprieta.Parent = genitore
	local riquadro = Stile.crea("Frame", proprieta)
	Stile.crea("Frame", {
		Name = "Base",
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.new(1, 0, 1, -10),
		BackgroundColor3 = pal.d,
		Parent = riquadro,
	}, { Stile.angoli(raggio or 30), Stile.bordo(Stile.CONTORNO, 6) })
	local faccia = Stile.crea("Frame", {
		Name = "Faccia",
		Size = UDim2.new(1, 0, 1, -14),
		BackgroundColor3 = Stile.BIANCO,
		ClipsDescendants = true,
		Parent = riquadro,
	}, { Stile.angoli(raggio or 30), Stile.bordo(Stile.CONTORNO, 6), Stile.sfumatura(pal.t, pal.b, 90) })
	-- Righe diagonali chiare, come nelle schede dei giochi simulator.
	for i = 0, 2 do
		Stile.crea("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.55 + i * 0.07, 0, 0.5, 0),
			Size = UDim2.new(0, 34 - i * 8, 3, 0),
			Rotation = 28,
			BackgroundColor3 = Stile.BIANCO,
			BackgroundTransparency = 0.88,
			BorderSizePixel = 0,
			Parent = faccia,
		})
	end
	return riquadro, faccia
end

-- Pulsante verde con il prezzo (monete o Robux). Restituisce il pulsante.
local function pulsantePrezzo(proprieta, voce, sotto)
	local robux = voce.robux ~= nil
	local prezzo = robux and voce.robux.prezzo or voce.monete
	local alto = proprieta.Size.Y.Offset
	local bottone = Stile.pulsante(proprieta, "verde", {
		Testo = Stile.numero(prezzo),
		TestoSize = math.floor(alto * 0.5),
		Icona = robux and "robux" or "coin",
		IconaSize = math.floor(alto * 0.62),
		IconaX = 16,
		Sotto = sotto,
		SottoSize = sotto and math.floor(alto * 0.2) or nil,
		Raggio = 22,
	})
	return bottone
end

local function intestazione(testo, chiave, ordine)
	local riga = Stile.crea("Frame", {
		Name = "Sezione_" .. chiave,
		Size = UDim2.fromOffset(LARGHEZZA, 84),
		BackgroundTransparency = 1,
		LayoutOrder = ordine,
		Parent = pagina,
	})
	Stile.scritta({
		Size = UDim2.fromScale(1, 1),
		Text = "~ " .. testo .. " ~",
		TextSize = 62,
		Contorno = 7,
		TextColor3 = Stile.Colori.Oro,
		Parent = riga,
	})
	sezioni[chiave] = riga
	return riga
end

local function compra(id)
	local ok, messaggio = remotiShop.AcquistaCassa:InvokeServer(id)
	if messaggio then
		Notifiche.mostra(messaggio, ok and Stile.Colori.Verde or nil)
	end
end

-- Riquadro di una probabilità: fondo del colore della rarità, immagine, nome sopra e percentuale grande sotto.
local function riquadroProbabilita(genitore, ordine, colori, titolo, percentuale, disegnaImmagine)
	local tassello = Stile.crea("Frame", {
		Size = UDim2.fromOffset(150, 176),
		LayoutOrder = ordine,
		BackgroundColor3 = Stile.BIANCO,
		Parent = genitore,
	}, { Stile.angoli(18), Stile.bordo(Stile.CONTORNO, 5), Stile.sfumatura(colori[1], colori[2]) })
	disegnaImmagine(tassello)
	local nome = Stile.scritta({
		Position = UDim2.fromOffset(6, 4),
		Size = UDim2.new(1, -12, 0, 30),
		Text = titolo,
		TextSize = 26,
		Contorno = 3,
		ZIndex = 4,
		Parent = tassello,
	})
	nome.TextScaled = true
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 26, Parent = nome })
	Stile.scritta({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -2),
		Size = UDim2.new(1, -16, 0, 46),
		Text = percentuale,
		TextSize = 42,
		Contorno = 5,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Stile.Colori.Oro,
		ZIndex = 4,
		Parent = tassello,
	})
	return tassello
end

local function rigaTasselli(genitore, x, y)
	return Stile.crea("Frame", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(900, 186),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = genitore,
	}, {
		Stile.crea("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 14),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})
end

-- Banner di una cassa: icona grande a sinistra, nome e descrizione, probabilità, prezzo a destra.
local function banner(cassa, tipo, ordine)
	local riquadro, faccia = scheda(pagina, cassa.pal, {
		Name = cassa.id,
		Size = UDim2.fromOffset(LARGHEZZA, 360),
		LayoutOrder = ordine,
	})
	local raggi = Icone.immagine("rays")
	if raggi then
		Stile.crea("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(180, 175),
			Size = UDim2.fromOffset(420, 420),
			Image = raggi,
			ImageTransparency = 0.55,
			BackgroundTransparency = 1,
			Parent = faccia,
		})
	end
	Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(180, 175),
		Size = UDim2.fromOffset(270, 270),
		BackgroundColor3 = Stile.BIANCO,
		BackgroundTransparency = 0.8,
		Parent = faccia,
	}, { Stile.tondo() })
	local icona = Stile.icona(cassa.icona, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(180, 175),
		Size = UDim2.fromOffset(290, 290),
		ZIndex = 2,
		Parent = faccia,
	})
	-- La cassa ondeggia piano.
	TweenService:Create(icona, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = 4 }):Play()

	local titolo = Stile.scritta({
		Position = UDim2.fromOffset(350, 16),
		Size = UDim2.fromOffset(820, 70),
		Text = string.upper(cassa.nome),
		TextSize = 64,
		Contorno = 7,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Parent = faccia,
	})
	titolo.TextScaled = true
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 64, Parent = titolo })
	Stile.scritta({
		Position = UDim2.fromOffset(352, 84),
		Size = UDim2.fromOffset(900, 34),
		Text = cassa.descrizione,
		TextSize = 30,
		Contorno = 4,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Parent = faccia,
	})

	local riga = rigaTasselli(faccia, 350, 128)
	local probabilita = Casse.probabilita(cassa.pesi)
	if tipo == "truppe" then
		for i, r in ipairs(Carte.RARITA) do
			if probabilita[r] then
				local def = Epoche.Truppe[ESEMPIO_CARTE[r]]
				riquadroProbabilita(riga, i, RARITA_CARTE[r], string.upper(Carte.NOMI_RARITA[r]), Casse.percentuale(probabilita[r]), function(t)
					Stile.icona(def and Icone.carta(def) or "army", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.new(0.5, 0, 0.5, -4),
						Size = UDim2.fromOffset(118, 118),
						ZIndex = 3,
						Parent = t,
					})
				end)
			end
		end
		-- Probabilità che sia una carta nuova (le altre volte è una copia di una che hai).
		local nuova = Stile.crea("Frame", {
			Size = UDim2.fromOffset(190, 176),
			LayoutOrder = 10,
			BackgroundColor3 = Stile.BIANCO,
			Parent = riga,
		}, { Stile.angoli(18), Stile.bordo(Stile.CONTORNO, 5), Stile.sfumatura(Stile.PAL.rosso.t, Stile.PAL.rosso.b) })
		Stile.scritta({
			Position = UDim2.fromOffset(6, 10),
			Size = UDim2.new(1, -12, 0, 34),
			Text = "NEW CARD",
			TextSize = 30,
			Contorno = 4,
			ZIndex = 3,
			Parent = nuova,
		})
		Stile.scritta({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.55),
			Size = UDim2.new(1, -12, 0, 70),
			Text = Casse.percentuale(cassa.nuova),
			TextSize = 66,
			Contorno = 6,
			TextColor3 = Stile.Colori.Oro,
			ZIndex = 3,
			Parent = nuova,
		})
		Stile.scritta({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -12, 0, 26),
			Text = cassa.nuova >= 1 and "guaranteed!" or "or a copy",
			TextSize = 24,
			Contorno = 3,
			ZIndex = 3,
			Parent = nuova,
		})
	else
		for i, r in ipairs({ "comune", "raro", "epico", "leggendario" }) do
			if probabilita[r] then
				local rarita = Config.Rarita[r]
				local pal = Stile.PAL[rarita.pal]
				-- Il cosmetico più bello di quella rarità come esempio.
				local esempio
				for _, c in ipairs(Config.Cosmetici) do
					if c.cassa and c.rarita == r then
						esempio = c
					end
				end
				riquadroProbabilita(riga, i, { pal.t, pal.b }, rarita.nome, Casse.percentuale(probabilita[r]), function(t)
					if esempio then
						Armadio.anteprimaCosmetico(esempio, {
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.new(0.5, 0, 0.5, -2),
							Size = UDim2.fromOffset(130, 120),
							ZIndex = 3,
							Parent = t,
						})
					end
				end)
			end
		end
	end

	-- Prezzo a destra: "1 Regiment" / "1 Item" sotto, come una confezione.
	local bottone = pulsantePrezzo({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -30, 1, -30),
		Size = UDim2.fromOffset(360, 130),
		ZIndex = 4,
		Parent = faccia,
	}, cassa, tipo == "truppe" and "1 Regiment" or "1 Item")
	bottone.Activated:Connect(function()
		compra(cassa.id)
	end)
	if cassa.robux then
		Stile.nastro({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -120, 0, 16),
			Size = UDim2.fromOffset(200, 60),
			ZIndex = 8,
			Parent = riquadro,
		}, "rosso", cassa.nuova == 1 and "NEW CARD!" or "BEST ODDS", 30)
	end
	return riquadro
end

-- Tutti i cosmetici dell'armeria, con il segno di spunta su quelli che hai già.
local function collezioneArmeria(ordine)
	local lista = {}
	for _, c in ipairs(Config.Cosmetici) do
		if c.cassa then
			table.insert(lista, c)
		end
	end
	table.sort(lista, function(a, b)
		local ra, rb = Config.Rarita[a.rarita].ordine, Config.Rarita[b.rarita].ordine
		if ra ~= rb then
			return ra > rb
		end
		return a.nome < b.nome
	end)
	local colonne = 9
	local lato = math.floor((LARGHEZZA - 16 * (colonne - 1)) / colonne)
	local griglia = Stile.crea("Frame", {
		Name = "Armeria",
		Size = UDim2.fromOffset(LARGHEZZA, math.ceil(#lista / colonne) * (lato + 50 + 16)),
		BackgroundTransparency = 1,
		LayoutOrder = ordine,
		Parent = pagina,
	}, {
		Stile.crea("UIGridLayout", {
			CellSize = UDim2.fromOffset(lato, lato + 50),
			CellPadding = UDim2.fromOffset(16, 16),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, c in ipairs(lista) do
		local rarita = Config.Rarita[c.rarita]
		local pal = Stile.PAL[rarita.pal]
		local tassello = Stile.crea("Frame", {
			LayoutOrder = i,
			BackgroundColor3 = Stile.BIANCO,
			Parent = griglia,
		}, { Stile.angoli(18), Stile.bordo(Stile.CONTORNO, 5), Stile.sfumatura(pal.t, pal.b) })
		Armadio.anteprimaCosmetico(c, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 6),
			Size = UDim2.fromOffset(lato - 16, lato - 16),
			ZIndex = 2,
			Parent = tassello,
		})
		local nome = Stile.scritta({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -30),
			Size = UDim2.new(1, -10, 0, 26),
			Text = c.nome,
			TextSize = 24,
			Contorno = 3,
			ZIndex = 3,
			Parent = tassello,
		})
		nome.TextScaled = true
		Stile.crea("UITextSizeConstraint", { MaxTextSize = 24, Parent = nome })
		Stile.scritta({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -6),
			Size = UDim2.new(1, -10, 0, 22),
			Text = rarita.nome,
			TextSize = 20,
			Contorno = 3,
			TextColor3 = Color3.fromHex(rarita.colore),
			ZIndex = 3,
			Parent = tassello,
		})
		local spunta = Stile.icona("check", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(46, 46),
			ZIndex = 4,
			Visible = false,
			Parent = tassello,
		})
		table.insert(dinamici, function()
			spunta.Visible = stato ~= nil and stato.cosmetici ~= nil and stato.cosmetici[c.id] == true
		end)
	end
end

-- Titoli in vendita: tre per riga.
local function titoli(ordine)
	local lista = {}
	for _, t in ipairs(Config.Titoli) do
		if t.monete or t.robux then
			table.insert(lista, t)
		end
	end
	local colonne = 3
	local larghezza = math.floor((LARGHEZZA - 24 * (colonne - 1)) / colonne)
	local griglia = Stile.crea("Frame", {
		Name = "Titoli",
		Size = UDim2.fromOffset(LARGHEZZA, math.ceil(#lista / colonne) * (230 + 24)),
		BackgroundTransparency = 1,
		LayoutOrder = ordine,
		Parent = pagina,
	}, {
		Stile.crea("UIGridLayout", {
			CellSize = UDim2.fromOffset(larghezza, 230),
			CellPadding = UDim2.fromOffset(24, 24),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, t in ipairs(lista) do
		local rarita = Config.Rarita[t.rarita]
		local _, faccia = scheda(griglia, "notte", { LayoutOrder = i }, 26)
		Stile.icona("title", {
			Position = UDim2.fromOffset(18, 18),
			Size = UDim2.fromOffset(90, 90),
			ZIndex = 2,
			Parent = faccia,
		})
		local nome = Stile.scritta({
			Position = UDim2.fromOffset(120, 22),
			Size = UDim2.new(1, -140, 0, 54),
			Text = "[" .. t.nome .. "]",
			TextSize = 46,
			Contorno = 5,
			TextColor3 = Color3.fromHex(rarita.colore),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 2,
			Parent = faccia,
		})
		nome.TextScaled = true
		Stile.crea("UITextSizeConstraint", { MaxTextSize = 46, Parent = nome })
		Stile.chip({
			Position = UDim2.fromOffset(122, 80),
			Size = UDim2.fromOffset(170, 36),
			ZIndex = 2,
			Parent = faccia,
		}, rarita.pal, rarita.nome, 22)
		local bottone = pulsantePrezzo({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -16),
			Size = UDim2.new(1, -40, 0, 84),
			ZIndex = 3,
			Parent = faccia,
		}, t)
		local posseduto = Stile.pulsante({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -16),
			Size = UDim2.new(1, -40, 0, 84),
			ZIndex = 3,
			Visible = false,
			Parent = faccia,
		}, "grigio", { Testo = "OWNED", TestoSize = 40, Icona = "check", IconaSize = 56, IconaX = 16, Raggio = 22 })
		bottone.Activated:Connect(function()
			local ok, messaggio = remotiShop.AcquistaOggetto:InvokeServer("titolo", t.id)
			if messaggio then
				Notifiche.mostra(messaggio, ok and Stile.Colori.Verde or nil)
			end
		end)
		table.insert(dinamici, function()
			local mio = stato ~= nil and stato.titoli ~= nil and stato.titoli[t.id] == true
			bottone.Visible = not mio
			posseduto.Visible = mio
		end)
	end
end

-- Pacchetti di monete: tre per riga.
local function pacchettiMonete(ordine)
	local colonne = 3
	local larghezza = math.floor((LARGHEZZA - 24 * (colonne - 1)) / colonne)
	local griglia = Stile.crea("Frame", {
		Name = "Monete",
		Size = UDim2.fromOffset(LARGHEZZA, math.ceil(#Casse.Monete / colonne) * (330 + 24)),
		BackgroundTransparency = 1,
		LayoutOrder = ordine,
		Parent = pagina,
	}, {
		Stile.crea("UIGridLayout", {
			CellSize = UDim2.fromOffset(larghezza, 330),
			CellPadding = UDim2.fromOffset(24, 24),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, pacchetto in ipairs(Casse.Monete) do
		local riquadro, faccia = scheda(griglia, pacchetto.migliore and "oro" or "acqua", { LayoutOrder = i }, 26)
		local raggi = Icone.immagine("rays")
		if raggi then
			Stile.crea("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0, 100),
				Size = UDim2.fromOffset(300, 300),
				Image = raggi,
				ImageTransparency = 0.6,
				BackgroundTransparency = 1,
				Parent = faccia,
			})
		end
		Stile.icona(pacchetto.icona, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 100),
			Size = UDim2.fromOffset(180, 180),
			ZIndex = 2,
			Parent = faccia,
		})
		local scritta = Stile.scritta({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 180),
			Size = UDim2.new(1, -30, 0, 50),
			Text = "+" .. Stile.numero(pacchetto.monete) .. " COINS",
			TextSize = 46,
			Contorno = 5,
			ZIndex = 3,
			Parent = faccia,
		})
		scritta.RichText = true
		scritta.Text = ('<font color="#7CF56E">+%s</font> COINS'):format(Stile.numero(pacchetto.monete))
		local bottone = pulsantePrezzo({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -16),
			Size = UDim2.new(1, -60, 0, 84),
			ZIndex = 3,
			Parent = faccia,
		}, pacchetto)
		bottone.Activated:Connect(function()
			compra(pacchetto.id)
		end)
		if pacchetto.migliore then
			Stile.nastro({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0, 120, 0, 18),
				Size = UDim2.fromOffset(220, 58),
				Rotation = -6,
				ZIndex = 8,
				Parent = riquadro,
			}, "rosso", "BEST DEAL!", 30)
		end
	end
end

local function aggiornaDinamici()
	if stato and numeroMonete then
		numeroMonete.Text = Stile.numero(stato.monete or 0)
	end
	for _, f in ipairs(dinamici) do
		f()
	end
end

local function costruisci()
	if costruita then
		return
	end
	costruita = true
	svuota(pagina)
	dinamici = {}
	intestazione("Troop Crates", "TROOPS", 1)
	for i, cassa in ipairs(Casse.Truppe) do
		banner(cassa, "truppe", 1 + i)
	end
	intestazione("Armory Crates", "ARMORY", 10)
	for i, cassa in ipairs(Casse.Cosmetici) do
		banner(cassa, "cosmetici", 10 + i)
	end
	local nota = Stile.scritta({
		Size = UDim2.fromOffset(LARGHEZZA, 44),
		Text = "Gear found ONLY in Armory Crates. You never get an item you already own!",
		TextSize = 30,
		Contorno = 4,
		LayoutOrder = 14,
		Parent = pagina,
	})
	nota.TextColor3 = Stile.Colori.Azzurro
	collezioneArmeria(15)
	intestazione("Titles", "TITLES", 20)
	titoli(21)
	intestazione("Coin Packs", "COINS", 30)
	pacchettiMonete(31)
	aggiornaDinamici()
end

local function vaiA(nome)
	for _, s in ipairs(schede) do
		Stile.coloraPulsante(s.bottone, s.nome == nome and "blu" or "grigio")
	end
	local riga = sezioni[nome]
	if not riga then
		return
	end
	local y = riga.AbsolutePosition.Y - pagina.AbsolutePosition.Y + pagina.CanvasPosition.Y
	-- AbsolutePosition è in pixel dello schermo: si riporta ai pixel di progetto della tela.
	local scala = Stile.scala()
	y = y / (scala > 0 and scala or 1)
	TweenService:Create(pagina, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CanvasPosition = Vector2.new(0, math.max(0, y - 6)),
	}):Play()
end

function Shop.inizializza(gui, remoti)
	remotiShop = remoti
	AperturaCassa.alTermine(function()
		if finestra.Visible then
			aggiornaDinamici()
		end
	end)
	local contenuto, fascia
	finestra, contenuto, fascia = Stile.finestra(gui, "Shop", "Shop", "verde", "shop")

	-- Monete nella fascia del titolo.
	local _, numero = Stile.pillola({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -150, 0.5, -4),
		Size = UDim2.fromOffset(260, 70),
		ZIndex = 14,
		Parent = fascia,
	}, "coin", "0")
	numeroMonete = numero

	-- Schede in alto: saltano alla sezione.
	local barraSchede = Stile.crea("Frame", {
		Size = UDim2.fromOffset(1100, 70),
		BackgroundTransparency = 1,
		Parent = contenuto,
	}, {
		Stile.crea("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, voce in ipairs({
		{ "TROOPS", "army", 200 },
		{ "ARMORY", "locker", 210 },
		{ "TITLES", "title", 190 },
		{ "COINS", "coin", 176 },
	}) do
		local bottone = Stile.pulsante({
			Size = UDim2.fromOffset(voce[3], 66),
			LayoutOrder = i,
			Parent = barraSchede,
		}, i == 1 and "blu" or "grigio", {
			Testo = voce[1],
			TestoSize = 30,
			Icona = voce[2],
			IconaSize = 46,
			IconaX = 10,
			Profondita = 6,
			Raggio = 30,
			Contorno = 4,
		})
		bottone.Activated:Connect(function()
			vaiA(voce[1])
		end)
		table.insert(schede, { bottone = bottone, nome = voce[1] })
	end
	Stile.testo({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 20),
		Size = UDim2.fromOffset(560, 30),
		Text = "Every crate gives exactly ONE reward",
		TextSize = 24,
		TextScaled = false,
		TextColor3 = Stile.Colori.TestoSecondario,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = contenuto,
	})

	pagina = Stile.crea("ScrollingFrame", {
		Name = "Pagina",
		Position = UDim2.fromOffset(0, 86),
		Size = UDim2.new(1, 0, 1, -86),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 12,
		ScrollBarImageColor3 = Stile.PAL.grigio.b,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = contenuto,
	}, {
		Stile.crea("UIListLayout", {
			Padding = UDim.new(0, 22),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Stile.crea("UIPadding", { PaddingBottom = UDim.new(0, 30), PaddingTop = UDim.new(0, 4) }),
	})
end

-- Riceve lo stato del giocatore: monete e oggetti posseduti.
function Shop.aggiorna(nuovoStato)
	if not nuovoStato then
		return
	end
	stato = nuovoStato
	-- Mentre si apre una cassa l'elenco non cambia: la novità si vede alla fine dell'animazione.
	if finestra.Visible and not AperturaCassa.inCorso() then
		aggiornaDinamici()
	end
end

function Shop.apri()
	finestra.Visible = true
	costruisci()
	aggiornaDinamici()
end

function Shop.chiudi()
	finestra.Visible = false
end

function Shop.alterna()
	if finestra.Visible then
		Shop.chiudi()
	else
		Shop.apri()
	end
end

-- Usato da AperturaCassa per sapere se lo shop è aperto.
function Shop.aperto()
	return finestra.Visible
end

return Shop
