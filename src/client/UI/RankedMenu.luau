-- Finestra RANKED (Mattia, 22/10/2026): si apre dal pulsante Ranked o dal portale della lobby.
--   PLAY        il tuo grado con l'avanzamento verso il prossimo, il mazzo ARMY che porterai in battaglia
--               (con il rimando al menu ARMY per cambiarlo) e il pulsante per cercare un avversario.
--   LEADERBOARD classifica settimanale (RP guadagnati da lunedì) e di sempre (RP attuali).
-- Gradi e punti: Shared/Config/Gradi.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Gradi = require(ReplicatedStorage.Shared.Config.Gradi)
local Carte = require(ReplicatedStorage.Shared.Config.Carte)
local Stile = require(script.Parent.Stile)
local Carta = require(script.Parent.Carta)
local Icone = require(script.Parent.Icone)

local RankedMenu = {}

local player = Players.LocalPlayer
local remoti
local finestra, contenuto
local pagine, schede = {}, {}
local stato
local apriArmy -- funzione che apre il menu ARMY

-- Parti che cambiano.
local emblema, nomeGrado, testoPunti, barraGrado, testoStatistiche, scalaGradi
local rigaCarte, bottoneCerca, testoCerca
local inCoda = false
local tipoClassifica = "settimana"
local bottoniClassifica = {}
local listaClassifica, testoReset

local function svuota(contenitore)
	for _, figlio in ipairs(contenitore:GetChildren()) do
		if figlio:IsA("GuiObject") then
			figlio:Destroy()
		end
	end
end

local function iconaGrado(grado)
	return "rank_" .. grado.fascia.id
end

-- Scheda scura con il bordo (stile delle finestre).
local function riquadro(genitore, proprieta)
	proprieta.BackgroundColor3 = Stile.BIANCO
	proprieta.Parent = genitore
	return Stile.crea("Frame", proprieta, {
		Stile.angoli(30),
		Stile.bordo(Stile.CONTORNO, 6),
		Stile.sfumatura(Stile.PAL.notte.t, Stile.PAL.notte.d),
	})
end

-- ===================================================================== PLAY

local function aggiornaGrado()
	if not stato or not emblema then
		return
	end
	local r = stato.ranked or { punti = 0, vittorie = 0, sconfitte = 0 }
	local grado, _, prossimo = Gradi.di(r.punti)
	Icone.cambia(emblema, iconaGrado(grado))
	nomeGrado.Text = string.upper(grado.nome)
	nomeGrado.TextColor3 = grado.fascia.colore
	testoPunti.Text = Stile.numero(r.punti) .. " RP"
	if prossimo then
		local fatto = r.punti - grado.minimo
		local serve = prossimo.minimo - grado.minimo
		barraGrado:imposta(fatto / serve, ("%d / %d RP  ·  next: %s"):format(fatto, serve, string.upper(prossimo.nome)))
	else
		barraGrado:imposta(1, "MAX RANK!")
	end
	testoStatistiche.Text = ("Wins %d  ·  Losses %d\nWin +%d RP  ·  Loss -%d RP"):format(r.vittorie or 0, r.sconfitte or 0, Gradi.PUNTI_VITTORIA, Gradi.PUNTI_SCONFITTA)
	-- Scala dei gradi: accesa la fascia raggiunta.
	for i, tassello in ipairs(scalaGradi) do
		local attuale = Gradi.Fasce[i] == grado.fascia
		if tassello.icona:IsA("ImageLabel") then
			tassello.icona.ImageTransparency = attuale and 0 or 0.55
		end
		tassello.cornice.Visible = attuale
	end
end

local function aggiornaMazzo()
	if not rigaCarte or not stato then
		return
	end
	svuota(rigaCarte)
	local mazzo = stato.mazzo or {}
	for i = 1, Carte.DIMENSIONE_MAZZO do
		local tipo = mazzo[i]
		if tipo then
			local carta = Carta.crea(tipo)
			carta.Size = UDim2.fromOffset(160, 232)
			carta.LayoutOrder = i
			carta.Parent = rigaCarte
			if carta:IsA("GuiButton") then
				carta.Activated:Connect(function()
					if apriArmy then
						apriArmy()
					end
				end)
			end
		else
			Stile.crea("Frame", {
				Size = UDim2.fromOffset(160, 232),
				LayoutOrder = i,
				BackgroundColor3 = Stile.PAL.notte.d,
				BackgroundTransparency = 0.4,
				Parent = rigaCarte,
			}, { Stile.angoli(18), Stile.bordo(Stile.BIANCO, 3, 0.6) })
		end
	end
end

local function aggiornaCerca()
	if not bottoneCerca then
		return
	end
	Stile.coloraPulsante(bottoneCerca, inCoda and "rosso" or "verde")
	testoCerca.Text = inCoda and "CANCEL SEARCH" or "FIND MATCH"
	local sotto = bottoneCerca:FindFirstChild("Sotto", true)
	if sotto then
		sotto.Text = inCoda and "Searching for an opponent..." or "1v1  ·  Best of 3  ·  Random map"
	end
end

local function paginaGioca(pagina)
	-- Sinistra: grado.
	local sinistra = riquadro(pagina, { Size = UDim2.fromOffset(620, 720) })
	emblema = Icone.crea("rank_bronze", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 18),
		Size = UDim2.fromOffset(250, 250),
		Parent = sinistra,
	})
	nomeGrado = Stile.scritta({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 268),
		Size = UDim2.new(1, -40, 0, 70),
		Text = "BRONZE I",
		TextSize = 64,
		Contorno = 7,
		Parent = sinistra,
	})
	testoPunti = Stile.scritta({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 340),
		Size = UDim2.new(1, -40, 0, 44),
		Text = "0 RP",
		TextSize = 40,
		Contorno = 4,
		TextColor3 = Stile.Colori.Azzurro,
		Parent = sinistra,
	})
	barraGrado = Stile.barra({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 398),
		Size = UDim2.fromOffset(540, 50),
		Parent = sinistra,
	}, "oro", 26)
	testoStatistiche = Stile.scritta({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 466),
		Size = UDim2.new(1, -40, 0, 80),
		Text = "",
		TextSize = 30,
		Contorno = 4,
		Parent = sinistra,
	})
	-- Scala dei gradi in basso.
	local scala = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.new(1, -30, 0, 130),
		BackgroundTransparency = 1,
		Parent = sinistra,
	}, {
		Stile.crea("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	scalaGradi = {}
	for i, fascia in ipairs(Gradi.Fasce) do
		local cella = Stile.crea("Frame", { Size = UDim2.fromOffset(80, 130), LayoutOrder = i, BackgroundTransparency = 1, Parent = scala })
		local cornice = Stile.crea("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Stile.BIANCO,
			BackgroundTransparency = 0.85,
			Visible = false,
			Parent = cella,
		}, { Stile.angoli(14), Stile.bordo(fascia.colore, 3) })
		local icona = Icone.crea("rank_" .. fascia.id, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 6),
			Size = UDim2.fromOffset(72, 72),
			Parent = cella,
		})
		local nome = Stile.scritta({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 82),
			Size = UDim2.new(1, -4, 0, 36),
			Text = string.upper(fascia.nome),
			TextSize = 16,
			Contorno = 2,
			TextColor3 = fascia.colore,
			TextWrapped = true,
			Parent = cella,
		})
		nome.TextScaled = true
		Stile.crea("UITextSizeConstraint", { MaxTextSize = 16, Parent = nome })
		table.insert(scalaGradi, { icona = icona, cornice = cornice })
	end

	-- Destra: mazzo e ricerca.
	local destra = riquadro(pagina, { Position = UDim2.fromOffset(650, 0), Size = UDim2.new(1, -650, 0, 720) })
	Stile.scritta({
		Position = UDim2.fromOffset(36, 20),
		Size = UDim2.fromOffset(600, 60),
		Text = "YOUR ARMY",
		TextSize = 54,
		Contorno = 6,
		TextColor3 = Stile.Colori.Oro,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = destra,
	})
	Stile.testo({
		Position = UDim2.fromOffset(38, 82),
		Size = UDim2.fromOffset(800, 30),
		Text = "Ranked uses the cards equipped in your ARMY deck.",
		TextSize = 24,
		TextScaled = false,
		TextColor3 = Color3.fromHex("#C9CCF0"),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = destra,
	})
	local modifica = Stile.pulsante({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -30, 0, 22),
		Size = UDim2.fromOffset(280, 84),
		Parent = destra,
	}, "blu", { Testo = "EDIT ARMY", TestoSize = 38, Icona = "army", IconaSize = 62, IconaX = 10, Raggio = 22, Profondita = 7 })
	modifica.Activated:Connect(function()
		if apriArmy then
			apriArmy()
		end
	end)
	rigaCarte = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 130),
		Size = UDim2.new(1, -40, 0, 240),
		BackgroundTransparency = 1,
		Parent = destra,
	}, {
		Stile.crea("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 14),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	Stile.scritta({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 400),
		Size = UDim2.new(1, -60, 0, 80),
		Text = ("Beat another commander in a 1v1, best of 3, on a random battlefield.\nWin: a Small Crate and +%d RP."):format(Gradi.PUNTI_VITTORIA),
		TextSize = 30,
		Contorno = 4,
		Parent = destra,
	})
	local etichetta
	bottoneCerca, etichetta = Stile.pulsante({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -36),
		Size = UDim2.fromOffset(620, 170),
		Parent = destra,
	}, "verde", { Testo = "FIND MATCH", TestoSize = 78, Sotto = "1v1  ·  Best of 3  ·  Random map", SottoSize = 30, Icona = "fight", IconaSize = 120, IconaX = 20, Raggio = 34, Profondita = 12, Contorno = 6 })
	testoCerca = etichetta
	bottoneCerca.Activated:Connect(function()
		local ok, risposta = pcall(function()
			return remoti.Ranked:InvokeServer("cerca")
		end)
		if ok then
			inCoda = risposta == true
			aggiornaCerca()
		end
	end)
	-- Mentre si cerca, il pulsante pulsa piano.
	task.spawn(function()
		local scala = bottoneCerca:FindFirstChildOfClass("UIScale")
		while true do
			task.wait(0.6)
			if inCoda and finestra.Visible and scala and not bottoneCerca:GetAttribute("Sopra") then
				TweenService:Create(scala, TweenInfo.new(0.3), { Scale = 1.04 }):Play()
				task.wait(0.35)
				TweenService:Create(scala, TweenInfo.new(0.3), { Scale = 1 }):Play()
			end
		end
	end)
end

-- ===================================================================== LEADERBOARD

local COLORI_PODIO = { Color3.fromHex("#FFD23F"), Color3.fromHex("#D8E2F2"), Color3.fromHex("#E08A4A") }

local function riga(i, voce)
	local mio = voce.userId == player.UserId
	local fondo = Stile.crea("Frame", {
		Size = UDim2.new(1, -16, 0, 84),
		LayoutOrder = i,
		BackgroundColor3 = Stile.BIANCO,
		Parent = listaClassifica,
	}, {
		Stile.angoli(20),
		Stile.bordo(Stile.CONTORNO, 4),
		Stile.sfumatura(mio and Stile.PAL.blu.t or Stile.PAL.notte.t, mio and Stile.PAL.blu.b or Stile.PAL.notte.b),
	})
	Stile.scritta({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 20, 0.5, 0),
		Size = UDim2.fromOffset(90, 60),
		Text = "#" .. voce.posizione,
		TextSize = 44,
		Contorno = 5,
		TextColor3 = COLORI_PODIO[voce.posizione] or Stile.BIANCO,
		Parent = fondo,
	})
	local grado = Gradi.di(tipoClassifica == "sempre" and voce.punti or 0)
	Icone.crea(tipoClassifica == "sempre" and iconaGrado(grado) or "ranked", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 120, 0.5, 0),
		Size = UDim2.fromOffset(70, 70),
		Parent = fondo,
	})
	local nome = Stile.scritta({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 206, 0.5, 0),
		Size = UDim2.new(1, -560, 0, 50),
		Text = voce.nome .. (mio and "  (YOU)" or ""),
		TextSize = 40,
		Contorno = 4,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = fondo,
	})
	nome.TextScaled = true
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 40, Parent = nome })
	if voce.grado then
		Stile.scritta({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -230, 0.5, 0),
			Size = UDim2.fromOffset(220, 40),
			Text = string.upper(voce.grado),
			TextSize = 28,
			Contorno = 3,
			TextColor3 = grado.fascia.colore,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = fondo,
		})
	end
	Stile.scritta({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -24, 0.5, 0),
		Size = UDim2.fromOffset(200, 50),
		Text = Stile.numero(voce.punti) .. " RP",
		TextSize = 40,
		Contorno = 4,
		TextColor3 = Stile.Colori.Oro,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = fondo,
	})
end

local function caricaClassifica()
	if not listaClassifica then
		return
	end
	for tipo, bottone in pairs(bottoniClassifica) do
		Stile.coloraPulsante(bottone, tipo == tipoClassifica and "oro" or "grigio")
	end
	local resto = Gradi.fineSettimana()
	testoReset.Text = tipoClassifica == "settimana"
			and ("RP earned since Monday  ·  resets in %dd %dh"):format(resto // 86400, (resto % 86400) // 3600)
		or "Current RP of every commander"
	svuota(listaClassifica)
	local attesa = Stile.scritta({
		Size = UDim2.new(1, 0, 0, 60),
		Text = "Loading...",
		TextSize = 36,
		Contorno = 4,
		Parent = listaClassifica,
	})
	local tipo = tipoClassifica
	local ok, voci = pcall(function()
		return remoti.LeggiClassifica:InvokeServer(tipo)
	end)
	if tipo ~= tipoClassifica then
		return
	end
	attesa:Destroy()
	if not ok or not voci or #voci == 0 then
		Stile.scritta({
			Size = UDim2.new(1, 0, 0, 60),
			Text = "No ranked matches yet. Be the first!",
			TextSize = 36,
			Contorno = 4,
			Parent = listaClassifica,
		})
		return
	end
	for i, voce in ipairs(voci) do
		riga(i, voce)
	end
end

local function paginaClassifica(pagina)
	for i, voce in ipairs({ { "settimana", "WEEKLY" }, { "sempre", "ALL TIME" } }) do
		local bottone = Stile.pulsante({
			Position = UDim2.fromOffset((i - 1) * 250, 0),
			Size = UDim2.fromOffset(236, 72),
			Parent = pagina,
		}, voce[1] == tipoClassifica and "oro" or "grigio", { Testo = voce[2], TestoSize = 34, Raggio = 26, Profondita = 6, Contorno = 4 })
		bottone.Activated:Connect(function()
			if tipoClassifica ~= voce[1] then
				tipoClassifica = voce[1]
				caricaClassifica()
			end
		end)
		bottoniClassifica[voce[1]] = bottone
	end
	testoReset = Stile.testo({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 22),
		Size = UDim2.fromOffset(800, 30),
		Text = "",
		TextSize = 26,
		TextScaled = false,
		TextColor3 = Stile.Colori.TestoSecondario,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = pagina,
	})
	listaClassifica = Stile.crea("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 92),
		Size = UDim2.new(1, 0, 1, -92),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 12,
		ScrollBarImageColor3 = Stile.PAL.grigio.b,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = pagina,
	}, {
		Stile.crea("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		Stile.crea("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 10) }),
	})
end

-- ===================================================================== finestra

local function mostraScheda(nome)
	for _, s in ipairs(schede) do
		Stile.coloraPulsante(s.bottone, s.nome == nome and "blu" or "grigio")
	end
	for n, pagina in pairs(pagine) do
		pagina.Visible = n == nome
	end
	if nome == "LEADERBOARD" then
		task.spawn(caricaClassifica)
	end
end

-- apri: funzione che apre il menu ARMY (chiudendo questa finestra).
function RankedMenu.inizializza(gui, r, apri)
	remoti = r
	apriArmy = apri
	finestra, contenuto = Stile.finestra(gui, "Ranked", "Ranked", "oro", "ranked")
	local barra = Stile.crea("Frame", {
		Size = UDim2.fromOffset(700, 70),
		BackgroundTransparency = 1,
		Parent = contenuto,
	}, {
		Stile.crea("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, voce in ipairs({ { "PLAY", "fight", 170 }, { "LEADERBOARD", "ranked", 290 } }) do
		local bottone = Stile.pulsante({
			Size = UDim2.fromOffset(voce[3], 66),
			LayoutOrder = i,
			Parent = barra,
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
			mostraScheda(voce[1])
		end)
		table.insert(schede, { bottone = bottone, nome = voce[1] })
		pagine[voce[1]] = Stile.crea("Frame", {
			Name = voce[1],
			Position = UDim2.fromOffset(0, 90),
			Size = UDim2.new(1, 0, 1, -90),
			BackgroundTransparency = 1,
			Visible = i == 1,
			Parent = contenuto,
		})
	end
	paginaGioca(pagine.PLAY)
	paginaClassifica(pagine.LEADERBOARD)
end

function RankedMenu.aggiorna(nuovoStato)
	if not nuovoStato then
		return
	end
	stato = nuovoStato
	if finestra.Visible then
		aggiornaGrado()
		aggiornaMazzo()
	end
end

function RankedMenu.apri()
	finestra.Visible = true
	mostraScheda("PLAY")
	aggiornaGrado()
	aggiornaMazzo()
	task.spawn(function()
		local ok, risposta = pcall(function()
			return remoti.Ranked:InvokeServer("stato")
		end)
		if ok then
			inCoda = risposta == true
			aggiornaCerca()
		end
	end)
end

function RankedMenu.chiudi()
	finestra.Visible = false
end

function RankedMenu.alterna()
	if finestra.Visible then
		RankedMenu.chiudi()
	else
		RankedMenu.apri()
	end
end

return RankedMenu
