-- Finestra PROFILE: a sinistra avatar, livello, epoca e progressi; a destra le statistiche personali.

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Epoche = require(ReplicatedStorage.Shared.Config.Epoche)
local Campagna = require(ReplicatedStorage.Shared.Config.Campagna)
local Progressi = require(ReplicatedStorage.Shared.Config.Progressi)
local Ricompense = require(ReplicatedStorage.Shared.Config.Ricompense)
local Stile = require(script.Parent.Stile)

local Profilo = {}

local player = Players.LocalPlayer
local finestra, griglia
local testoTitolo
local numeroLivello, chipEpoca, testoLivello, testoXp, barraXp, testoCampagna, barraCampagna
local stato

-- Livelli della campagna completati: stesso conto di sempre.
local function campagnaFatta(st, s)
	return math.max(s.livelloMassimo or 1, st.livello or 1) - (st.completata and 0 or 1)
end

-- { titolo, colore, icona, funzione(stato, statistiche) -> testo (nil = dato non disponibile) }
local VOCI = {
	{ "BATTLES", "blu", "fight", function(_, s)
		return s.battaglie
	end },
	{ "VICTORIES", "verde", "ranked", function(_, s)
		return s.vittorie
	end },
	{ "DEFEATS", "rosso", "close", function(_, s)
		return s.sconfitte
	end },
	{ "WIN RATE", "oro", "boost", function(_, s)
		if s.battaglie == nil or s.vittorie == nil then
			return nil
		end
		if s.battaglie == 0 then
			return "-"
		end
		return math.floor(s.vittorie / s.battaglie * 100 + 0.5) .. "%"
	end },
	{ "ENEMIES DEFEATED", "arancio", "cls_inf", function(_, s)
		return s.reggimentiSconfitti
	end },
	{ "REGIMENTS LOST", "grigio", "cls_fort", function(_, s)
		return s.reggimentiPersi
	end },
	{ "CARDS OWNED", "viola", "army", function(st)
		if not st.collezione then
			return nil
		end
		local tutte = Epoche.carte()
		local n = 0
		for _, tipo in ipairs(tutte) do
			if (st.collezione[tipo] or 0) > 0 then
				n += 1
			end
		end
		return ("%d/%d"):format(n, #tutte)
	end },
	{ "COMMANDERS", "rosa", "profile", function(st)
		if not st.collezione then
			return nil
		end
		local n, totale = 0, 0
		for _, epoca in ipairs(Epoche.Lista) do
			for _, tipo in ipairs(epoca.comandanti) do
				totale += 1
				if (st.collezione[tipo] or 0) > 0 then
					n += 1
				end
			end
		end
		return ("%d/%d"):format(n, totale)
	end },
	{ "STARS", "oro", "star", function(st)
		if not st.stelle then
			return nil
		end
		local n = 0
		for _, stelle in pairs(st.stelle) do
			n += stelle
		end
		return ("%d/%d"):format(n, Campagna.TOTALE * Campagna.STELLE_MASSIME)
	end },
	{ "COINS EARNED", "arancio", "coin", function(_, s)
		return s.moneteGuadagnate and Stile.numero(s.moneteGuadagnate)
	end },
	{ "CAMPAIGN", "acqua", "campaign", function(st, s)
		if not st.livello or not st.totale then
			return nil
		end
		return ("%d/%d"):format(campagnaFatta(st, s), st.totale)
	end },
	{ "PLAYER LEVEL", "blu", "level", function(st)
		if st.esperienza == nil then
			return nil
		end
		return (Progressi.livello(st.esperienza))
	end },
}

-- Riquadro di una statistica: blocco colorato con l'icona, etichetta e numero grande.
local function riquadro(ordine, titolo, pal, icona, valore)
	pal = Stile.PAL[pal]
	local cella = Stile.crea("Frame", {
		LayoutOrder = ordine,
		BackgroundTransparency = 1,
		Parent = griglia,
	})
	-- Base scura sotto per l'effetto 3D.
	Stile.crea("Frame", {
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 1, -8),
		BackgroundColor3 = pal.d,
		Parent = cella,
	}, { Stile.angoli(24), Stile.bordo(Stile.CONTORNO, 5) })
	local faccia = Stile.crea("Frame", {
		Size = UDim2.new(1, 0, 1, -12),
		BackgroundColor3 = Stile.BIANCO,
		ClipsDescendants = true,
		Parent = cella,
	}, { Stile.angoli(24), Stile.bordo(Stile.CONTORNO, 5), Stile.sfumatura(Stile.BIANCO, Color3.fromHex("#E9ECFA")) })
	local blocco = Stile.crea("Frame", {
		Size = UDim2.new(0, 124, 1, 0),
		BackgroundColor3 = Stile.BIANCO,
		BorderSizePixel = 0,
		Parent = faccia,
	}, { Stile.angoli(24), Stile.sfumatura(pal.t, pal.b) })
	-- Copre l'angolo arrotondato a destra del blocco e fa da linea di separazione.
	Stile.crea("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 24, 1, 0),
		BackgroundColor3 = Stile.BIANCO,
		BorderSizePixel = 0,
		Parent = blocco,
	}, { Stile.sfumatura(pal.t, pal.b) })
	Stile.crea("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 2, 0, 0),
		Size = UDim2.new(0, 5, 1, 0),
		BackgroundColor3 = Stile.CONTORNO,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = blocco,
	})
	Stile.crea("Frame", {
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.new(1, -20, 0, 40),
		BackgroundColor3 = Stile.BIANCO,
		BackgroundTransparency = 0.72,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = blocco,
	}, { Stile.angoli(16) })
	Stile.icona(icona, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, -2, 0.5, 0),
		Size = UDim2.fromOffset(86, 86),
		ZIndex = 3,
		Parent = blocco,
	})
	Stile.testo({
		Position = UDim2.fromOffset(148, 36),
		Size = UDim2.new(1, -160, 0, 28),
		Text = titolo,
		TextSize = 22,
		TextScaled = false,
		TextColor3 = Stile.Colori.TestoSecondario,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = faccia,
	})
	local numero = Stile.scritta({
		Position = UDim2.fromOffset(146, 72),
		Size = UDim2.new(1, -164, 0, 70),
		Text = tostring(valore),
		TextSize = 62,
		Contorno = 5,
		TextColor3 = pal.b,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = faccia,
	})
	numero.TextScaled = true
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 62, Parent = numero })
end

local function disegna()
	if not stato or not stato.statistiche then
		return
	end
	-- Scheda del giocatore.
	local livello, resto, necessario = Progressi.livello(stato.esperienza or 0)
	numeroLivello.Text = tostring(livello)
	testoLivello.Text = "LEVEL " .. livello
	testoXp.Text = ("%s / %s XP"):format(Stile.numero(resto), Stile.numero(necessario))
	barraXp:imposta(resto / necessario)
	local nomeEpoca = string.upper(tostring(stato.epoca or ""))
	-- "MODERN ERA" e "AGE OF GUNPOWDER" hanno già la parola.
	chipEpoca.Text = nomeEpoca .. ((string.find(nomeEpoca, "ERA") or string.find(nomeEpoca, "AGE")) and "" or " ERA")
	local titolo = Ricompense.titolo(stato.titolo or Ricompense.TITOLO_INIZIALE) or Ricompense.titolo(Ricompense.TITOLO_INIZIALE)
	testoTitolo.Text = "« " .. string.upper(titolo.nome) .. " »"
	testoTitolo.TextColor3 = Color3.fromHex(Ricompense.Rarita[titolo.rarita].colore)
	local totale = stato.totale or Campagna.TOTALE
	local fatta = campagnaFatta(stato, stato.statistiche)
	testoCampagna.Text = ("%d / %d"):format(fatta, totale)
	barraCampagna:imposta(totale > 0 and fatta / totale or 0)

	-- Statistiche: solo quelle che lo stato fornisce davvero.
	for _, figlio in ipairs(griglia:GetChildren()) do
		if figlio:IsA("GuiObject") then
			figlio:Destroy()
		end
	end
	for i, voce in ipairs(VOCI) do
		local valore = voce[4](stato, stato.statistiche)
		if valore ~= nil then
			riquadro(i, voce[1], voce[2], voce[3], valore)
		end
	end
end

-- Riga "TITOLO ........ valore" sopra una barra.
local function etichettaRiga(genitore, y, testo, colore)
	local sinistra = Stile.testo({
		Position = UDim2.fromOffset(40, y),
		Size = UDim2.new(0.5, -40, 0, 32),
		Text = testo,
		TextSize = 26,
		TextScaled = false,
		TextColor3 = Stile.BIANCO,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = genitore,
	})
	local destra = Stile.testo({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -40, 0, y),
		Size = UDim2.new(0.6, -40, 0, 32),
		Text = "",
		TextSize = 24,
		TextScaled = false,
		TextColor3 = colore,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = genitore,
	})
	return sinistra, destra
end

function Profilo.inizializza(gui)
	local contenuto
	finestra, contenuto = Stile.finestra(gui, "Profilo", "Profile", "viola", "profile")

	-- Scheda del giocatore a sinistra.
	local scheda = Stile.pannello({
		Size = UDim2.new(0, 520, 1, 0),
		BackgroundColor3 = Color3.fromHex("#2E2566"),
		BackgroundTransparency = 0,
		Parent = contenuto,
	})
	Stile.bordo(Stile.CONTORNO, 6).Parent = scheda

	-- Avatar nell'anello dorato.
	local anello = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 56),
		Size = UDim2.fromOffset(250, 250),
		BackgroundColor3 = Stile.BIANCO,
		Parent = scheda,
	}, { Stile.tondo(), Stile.bordo(Stile.CONTORNO, 5), Stile.sfumatura(Stile.PAL.oro.t, Stile.PAL.oro.b) })
	local avatar = Stile.crea("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -28, 1, -28),
		BackgroundColor3 = Color3.fromHex("#DDE6F7"),
		ScaleType = Enum.ScaleType.Crop,
		Parent = anello,
	}, { Stile.tondo(), Stile.bordo(Stile.CONTORNO, 4) })
	task.spawn(function()
		local ok, immagine = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
		end)
		if ok then
			avatar.Image = immagine
		end
	end)

	-- Esagono del livello sull'angolo dell'avatar.
	local esagono = Stile.icona("level", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 118, 0, 290),
		Size = UDim2.fromOffset(96, 96),
		ZIndex = 3,
		Parent = scheda,
	})
	numeroLivello = Stile.scritta({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.6),
		Text = "1",
		TextSize = 44,
		Contorno = 4,
		ZIndex = 4,
		Parent = esagono,
	})
	numeroLivello.TextScaled = true
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 44, Parent = numeroLivello })

	local nome = Stile.scritta({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 320),
		Size = UDim2.new(1, -60, 0, 70),
		Text = player.DisplayName,
		TextSize = 62,
		Contorno = 6,
		Parent = scheda,
	})
	nome.TextScaled = true
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 62, Parent = nome })
	-- Il titolo scelto nel Locker, nel colore della sua rarità.
	testoTitolo = Stile.scritta({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 392),
		Size = UDim2.new(1, -60, 0, 36),
		Text = "",
		TextSize = 30,
		Contorno = 3,
		FontFace = Stile.FontEtichetta,
		Parent = scheda,
	})
	local _, testoEpoca = Stile.chip({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 446),
		Size = UDim2.fromOffset(270, 54),
		Parent = scheda,
	}, "blu", "ERA", 28)
	chipEpoca = testoEpoca

	-- Livello del giocatore e campagna con le barre.
	testoLivello, testoXp = etichettaRiga(scheda, 548, "LEVEL 1", Stile.PAL.acqua.t)
	barraXp = Stile.barra({
		Position = UDim2.fromOffset(40, 588),
		Size = UDim2.new(1, -80, 0, 40),
		Parent = scheda,
	}, "acqua")
	local _, destraCampagna = etichettaRiga(scheda, 662, "CAMPAIGN", Stile.PAL.oro.t)
	testoCampagna = destraCampagna
	barraCampagna = Stile.barra({
		Position = UDim2.fromOffset(40, 702),
		Size = UDim2.new(1, -80, 0, 40),
		Parent = scheda,
	}, "oro")

	-- Griglia 3x4 delle statistiche a destra.
	griglia = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(1, -556, 1, 0),
		BackgroundTransparency = 1,
		Parent = contenuto,
	}, {
		Stile.crea("UIGridLayout", {
			CellSize = UDim2.new(1 / 3, -16, 1 / 4, -18),
			CellPadding = UDim2.fromOffset(24, 24),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

function Profilo.aggiorna(nuovoStato)
	if not nuovoStato then
		return
	end
	stato = nuovoStato
	if finestra.Visible then
		disegna()
	end
end

function Profilo.apri()
	finestra.Visible = true
	disegna()
end

function Profilo.chiudi()
	finestra.Visible = false
end

function Profilo.alterna()
	if finestra.Visible then
		Profilo.chiudi()
	else
		Profilo.apri()
	end
end

return Profilo
