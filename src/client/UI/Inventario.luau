-- Finestra ARMY: il mazzo da portare in battaglia (in alto), la collezione di carte con i filtri per classe (sotto)
-- e a destra il dettaglio della carta selezionata con il pulsante Add/Remove.
-- Clic su una carta del mazzo: esce dal mazzo. Clic su una carta della collezione: la seleziona.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Epoche = require(ReplicatedStorage.Shared.Config.Epoche)
local Carte = require(ReplicatedStorage.Shared.Config.Carte)
local Campagna = require(ReplicatedStorage.Shared.Config.Campagna)
local Battaglia = require(ReplicatedStorage.Shared.Battaglia)
local Stile = require(script.Parent.Stile)
local Carta = require(script.Parent.Carta)
local Notifiche = require(script.Parent.Notifiche)

local Inventario = {}

local remoti
local finestra, rigaMazzo, griglia, dettaglio
local titoloMazzo, chipMedia, chipCollezione, numeroMonete
local schede = {} -- pulsanti dei filtri: { bottone, classe }
local stato -- ultimo stato ricevuto dal server
local mazzo = {} -- copia locale, modificata subito e poi confermata dal server
local salvataggi = 0
local filtro -- nil = tutte, altrimenti la classe (Fanteria, Cavalleria, Tiratore)
local selezionato -- tipo della carta mostrata nel dettaglio

-- Colore del chip dell'epoca nel dettaglio.
local PAL_EPOCA = { Antica = "arancio", Medievale = "grigio", Novecento = "oro", Moderna = "oro" }

local LARGHEZZA_SINISTRA = 1220

local carteGriglia = {} -- tipo -> { carta, nota, firma } (carte della collezione già create)

local function contaNelMazzo(tipo)
	local n = 0
	for _, t in ipairs(mazzo) do
		if t == tipo then
			n += 1
		end
	end
	return n
end

local function svuota(contenitore)
	for _, figlio in ipairs(contenitore:GetChildren()) do
		if figlio:IsA("GuiObject") then
			figlio:Destroy()
		end
	end
end

-- Titolo scuro con contorno bianco ("Deck 6/6", "Collection") sul fondo chiaro della finestra.
local function titoloScuro(proprieta)
	proprieta.TextColor3 = Stile.CONTORNO
	proprieta.Contorno = proprieta.Contorno or 4
	local etichetta = Stile.scritta(proprieta)
	etichetta.Contorno.Color = Stile.BIANCO
	return etichetta
end

local disegna

local function salva()
	salvataggi += 1
	local numero = salvataggi
	local ok, messaggio = remoti.SalvaMazzo:InvokeServer(mazzo)
	if not ok and numero == salvataggi then
		-- Il server ha rifiutato: si torna al mazzo salvato.
		mazzo = table.clone(stato.mazzo)
		disegna()
		if messaggio then
			Notifiche.mostra(messaggio, Stile.Colori.Rosso)
		end
	end
end

local function aggiungi(tipo)
	if #mazzo >= Carte.DIMENSIONE_MAZZO then
		Notifiche.mostra("Your deck is full: remove a card first.", Stile.Colori.Rosso)
		return
	end
	if contaNelMazzo(tipo) >= (stato.collezione[tipo] or 0) then
		return
	end
	table.insert(mazzo, tipo)
	disegna()
	task.spawn(salva)
end

local function togli(indice)
	table.remove(mazzo, indice)
	disegna()
	task.spawn(salva)
end

-- Toglie dal mazzo l'ultima copia di "tipo".
local function togliTipo(tipo)
	for i = #mazzo, 1, -1 do
		if mazzo[i] == tipo then
			togli(i)
			return
		end
	end
end

-- Nota delle carte che non si possono usare (bloccate, da sbloccare, non possedute), oppure nil.
local battagliaDel
local function notaCarta(tipo)
	local def = Epoche.Truppe[tipo]
	local possedute = stato.collezione[tipo] or 0
	if not battagliaDel then
		-- Dove si sconfigge ogni comandante, per dire al giocatore come ottenerlo.
		battagliaDel = {}
		for numero, battaglia in ipairs(Campagna.Battaglie) do
			if battaglia.comandante then
				battagliaDel[battaglia.comandante] = numero
			end
		end
	end
	local epocaRaggiunta = Campagna.livello(stato.livello).indiceEpoca
	if possedute == 0 and def.comandante then
		return "WIN BATTLE " .. tostring(battagliaDel[tipo] or "?")
	elseif (Epoche.indice(def.epoca) or 1) > epocaRaggiunta then
		return "LOCKED"
	elseif possedute == 0 then
		return "NOT OWNED"
	end
	return nil
end

-- Distintivo nell'angolo in alto a destra di una carta della collezione: spunta verde se è nel mazzo,
-- "xN" rosso con le copie ancora libere.
local function distintivi(carta, nelMazzo, libere)
	local colonna = Stile.crea("Frame", {
		Name = "Distintivi",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(1, -10, 0, -14),
		Size = UDim2.fromOffset(52, 100),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = carta,
	}, {
		Stile.crea("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	if nelMazzo then
		local tondo = Stile.crea("Frame", {
			Name = "NelMazzo",
			Size = UDim2.fromOffset(46, 46),
			BackgroundColor3 = Stile.BIANCO,
			LayoutOrder = 1,
			ZIndex = 5,
			Parent = colonna,
		}, { Stile.tondo(), Stile.bordo(Stile.BIANCO, 4), Stile.sfumatura(Stile.PAL.verde.t, Stile.PAL.verde.b) })
		Stile.icona("check", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.8, 0.8),
			ZIndex = 6,
			Parent = tondo,
		})
	end
	if libere > 0 then
		local bollino = Stile.crea("Frame", {
			Name = "Libere",
			Size = UDim2.fromOffset(48, 32),
			BackgroundColor3 = Stile.BIANCO,
			LayoutOrder = 2,
			ZIndex = 5,
			Parent = colonna,
		}, { Stile.tondo(), Stile.bordo(Stile.CONTORNO, 3), Stile.sfumatura(Stile.PAL.rosso.t, Stile.PAL.rosso.b) })
		Stile.scritta({
			Size = UDim2.fromScale(1, 1),
			Text = "x" .. libere,
			TextSize = 20,
			Contorno = 2,
			ZIndex = 6,
			Parent = bollino,
		})
	end
end

-- Riga "STRONG VS ..." / "WEAK VS ..." con l'icona della classe.
local function rigaClasse(genitore, y, classe, forte)
	local icone = { Fanteria = "cls_inf", Cavalleria = "cls_cav", Tiratore = "cls_rng" }
	Stile.icona(icone[classe] or "cls_inf", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 18, 0, y),
		Size = UDim2.fromOffset(42, 42),
		ZIndex = 3,
		Parent = genitore,
	})
	Stile.testo({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 72, 0, y),
		Size = UDim2.new(1, -86, 0, 30),
		Text = (forte and "STRONG VS " or "WEAK VS ") .. string.upper(Epoche.Classi[classe].nome),
		TextSize = 26,
		TextScaled = false,
		FontFace = Stile.FontTitolo,
		TextColor3 = forte and Stile.PAL.verde.t or Stile.PAL.rosso.t,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Parent = genitore,
	})
end

-- Pannello di destra: carta grande, nome, epoca, soldati, punti di forza e pulsante Add/Remove.
local function disegnaDettaglio()
	svuota(dettaglio)
	local tipo = selezionato
	if not tipo or not Epoche.Truppe[tipo] then
		Stile.testo({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -40, 0, 80),
			Text = "Select a card to see its details",
			TextSize = 28,
			TextScaled = false,
			TextWrapped = true,
			TextColor3 = Stile.Colori.Azzurro,
			Parent = dettaglio,
		})
		return
	end
	local def = Epoche.Truppe[tipo]
	local nota = notaCarta(tipo)

	local grande = Carta.crea(tipo, { nota = nota, spenta = nota ~= nil })
	grande.AnchorPoint = Vector2.new(0.5, 0)
	grande.Position = UDim2.new(0.5, 0, 0, 24)
	grande.Size = UDim2.fromOffset(290, 420)
	grande.Active = false
	grande.Parent = dettaglio

	local nome = Stile.scritta({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 452),
		Size = UDim2.new(1, -30, 0, 56),
		Text = def.nome,
		TextSize = 46,
		Contorno = 5,
		ZIndex = 2,
		Parent = dettaglio,
	})
	nome.TextScaled = true
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 46, Parent = nome })

	-- Chip dell'epoca e dei soldati.
	local riga = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 518),
		Size = UDim2.new(1, -40, 0, 50),
		BackgroundTransparency = 1,
		Parent = dettaglio,
	}, {
		Stile.crea("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 16),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	Stile.chip({
		Size = UDim2.fromOffset(180, 46),
		LayoutOrder = 1,
		Parent = riga,
	}, PAL_EPOCA[def.epoca] or "grigio", string.upper(Epoche.epoca(def.epoca).nome), 24)
	Stile.chip({
		Size = UDim2.fromOffset(120, 46),
		LayoutOrder = 2,
		Parent = riga,
	}, "blu", ("x%d MEN"):format((def.soldati or 1) + (def.guardia and def.guardia.numero or 0)), 24)
	-- Origine: le abilità dei comandanti valgono doppio per le truppe della stessa origine.
	if def.origine then
		Stile.chip({
			Size = UDim2.fromOffset(150, 46),
			LayoutOrder = 3,
			Parent = riga,
		}, "verde", string.upper(def.origine), 24)
	end

	-- Triangolo delle classi (le fortezze non sono nella collezione).
	local batte = Battaglia.BATTE[def.classe]
	local battutoDa
	for attacco, difesa in pairs(Battaglia.BATTE) do
		if difesa == def.classe then
			battutoDa = attacco
		end
	end
	if def.abilita then
		-- I comandanti mostrano la loro abilità al posto del triangolo delle classi.
		local riquadro = Stile.crea("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 586),
			Size = UDim2.new(1, -40, 0, 112),
			BackgroundColor3 = Color3.fromHex("#15163A"),
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			Parent = dettaglio,
		}, { Stile.angoli(20) })
		Stile.testo({
			Position = UDim2.fromOffset(18, 8),
			Size = UDim2.new(1, -36, 0, 32),
			Text = "ABILITY: " .. string.upper(def.abilita.nome),
			TextSize = 26,
			TextScaled = false,
			FontFace = Stile.FontTitolo,
			TextColor3 = Stile.Colori.Oro,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 3,
			Parent = riquadro,
		})
		local testo = Stile.testo({
			Position = UDim2.fromOffset(18, 42),
			Size = UDim2.new(1, -36, 0, 64),
			Text = Epoche.testoAbilita(def),
			TextSize = 20,
			TextScaled = false,
			TextWrapped = true,
			TextColor3 = Stile.BIANCO,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 3,
			Parent = riquadro,
		})
		Stile.crea("UITextSizeConstraint", { MaxTextSize = 20, Parent = testo })
	elseif batte or battutoDa then
		local riquadro = Stile.crea("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 586),
			Size = UDim2.new(1, -40, 0, 112),
			BackgroundColor3 = Color3.fromHex("#15163A"),
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			Parent = dettaglio,
		}, { Stile.angoli(20) })
		if batte then
			rigaClasse(riquadro, battutoDa and 32 or 56, batte, true)
		end
		if battutoDa then
			rigaClasse(riquadro, batte and 80 or 56, battutoDa, false)
		end
	end

	-- Pulsante: come il vecchio clic sulla carta (entra nel mazzo / esce dal mazzo).
	local possedute = stato.collezione[tipo] or 0
	local nelMazzo = contaNelMazzo(tipo)
	local libere = possedute - nelMazzo
	local pieno = #mazzo >= Carte.DIMENSIONE_MAZZO
	local azione, pal, testo, icona
	if nota then
		azione, pal, testo, icona = nil, "grigio", nota, "lock"
	elseif nelMazzo > 0 and (libere <= 0 or pieno) then
		azione, pal, testo, icona = "togli", "rosso", "Remove", "close"
	elseif libere > 0 then
		azione, pal, testo, icona = "aggiungi", "verde", "Add", "plus"
	else
		azione, pal, testo, icona = nil, "grigio", "In deck", "check"
	end
	local bottone = Stile.pulsante({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(1, -40, 0, 92),
		Parent = dettaglio,
	}, pal, { Testo = testo, TestoSize = 50, Icona = icona, IconaSize = 52, IconaX = 22 })
	bottone.Activated:Connect(function()
		if azione == "aggiungi" then
			aggiungi(tipo)
		elseif azione == "togli" then
			togliTipo(tipo)
		end
	end)
end

function disegna()
	if not finestra or not stato then
		return
	end
	svuota(rigaMazzo)
	numeroMonete.Text = Stile.numero(stato.monete or 0)

	-- Mazzo: sei posti, vuoti con un "+".
	local sommaOvr = 0
	for i = 1, Carte.DIMENSIONE_MAZZO do
		local tipo = mazzo[i]
		if tipo then
			sommaOvr += Carte.valutazioni(Epoche.Truppe[tipo]).OVR
			local carta = Carta.crea(tipo)
			carta.Size = UDim2.fromOffset(163, 236)
			carta.LayoutOrder = i
			carta.Parent = rigaMazzo
			carta.Activated:Connect(function()
				selezionato = tipo
				togli(i)
			end)
		else
			local vuota = Stile.crea("Frame", {
				Size = UDim2.fromOffset(163, 220),
				LayoutOrder = i,
				BackgroundColor3 = Color3.fromHex("#C9D1EE"),
				Parent = rigaMazzo,
			}, { Stile.angoli(18), Stile.bordo(Color3.fromHex("#A3ADD6"), 4) })
			Stile.scritta({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(80, 80),
				Text = "+",
				TextSize = 72,
				Contorno = 5,
				TextColor3 = Color3.fromHex("#A3ADD6"),
				Parent = vuota,
			})
		end
	end
	local media = #mazzo > 0 and math.floor(sommaOvr / #mazzo + 0.5) or 0
	titoloMazzo.Text = ("Deck %d/%d"):format(#mazzo, Carte.DIMENSIONE_MAZZO)
	chipMedia.Text = "AVG OVR " .. media

	-- Collezione, filtrata per classe.
	local tutte = Epoche.carte()
	local conteggio = 0
	for _, tipo in ipairs(tutte) do
		if (stato.collezione[tipo] or 0) > 0 then
			conteggio += 1
		end
	end
	chipCollezione.Text = ("%d/%d"):format(conteggio, #tutte)
	for _, scheda in ipairs(schede) do
		Stile.coloraPulsante(scheda.bottone, scheda.classe == filtro and "blu" or "grigio")
	end

	if selezionato == nil then
		selezionato = mazzo[1] or tutte[1]
	end
	-- Le carte della collezione si creano una volta sola (sono tante: rifarle tutte a ogni carta messa o tolta
	-- dal mazzo bloccava il gioco); si rifà solo la carta la cui nota cambia, il resto si aggiorna.
	for ordine, tipo in ipairs(tutte) do
		local def = Epoche.Truppe[tipo]
		local possedute = stato.collezione[tipo] or 0
		local nelMazzo = contaNelMazzo(tipo)
		local nota = notaCarta(tipo)
		local voce = carteGriglia[tipo]
		if not voce or voce.nota ~= nota then
			if voce then
				voce.carta:Destroy()
			end
			local carta = Carta.crea(tipo, { nota = nota, spenta = nota ~= nil })
			carta.LayoutOrder = ordine
			carta.Parent = griglia
			carta.Activated:Connect(function()
				selezionato = tipo
				disegna()
			end)
			voce = { carta = carta, nota = nota }
			carteGriglia[tipo] = voce
		end
		voce.carta.Visible = filtro == nil or def.classe == filtro
		local firma = nota and "" or (tostring(nelMazzo > 0) .. "|" .. (possedute - nelMazzo))
		if voce.firma ~= firma then
			voce.firma = firma
			local vecchi = voce.carta:FindFirstChild("Distintivi")
			if vecchi then
				vecchi:Destroy()
			end
			if not nota then
				distintivi(voce.carta, nelMazzo > 0, possedute - nelMazzo)
			end
		end
		Carta.seleziona(voce.carta, tipo == selezionato)
	end
	disegnaDettaglio()
end

-- Pulsante di un filtro della collezione.
local function schedaFiltro(genitore, ordine, testo, icona, larghezza, classe)
	local bottone = Stile.pulsante({
		Size = UDim2.fromOffset(larghezza, 60),
		LayoutOrder = ordine,
		Parent = genitore,
	}, classe == filtro and "blu" or "grigio", {
		Testo = testo,
		TestoSize = 30,
		Icona = icona,
		IconaSize = 40,
		IconaX = 12,
		Profondita = 6,
		Raggio = 30,
		Contorno = 4,
	})
	bottone.Activated:Connect(function()
		filtro = classe
		disegna()
	end)
	table.insert(schede, { bottone = bottone, classe = classe })
end

function Inventario.inizializza(gui, r)
	remoti = r
	local contenuto, fascia
	finestra, contenuto, fascia = Stile.finestra(gui, "Esercito", "Your Army", "blu", "army")

	-- Monete nella fascia del titolo.
	local _, numero = Stile.pillola({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -150, 0.5, -4),
		Size = UDim2.fromOffset(260, 70),
		ZIndex = 14,
		Parent = fascia,
	}, "coin", "0")
	numeroMonete = numero

	-- Colonna sinistra: mazzo e collezione.
	local sinistra = Stile.crea("Frame", {
		Size = UDim2.new(0, LARGHEZZA_SINISTRA, 1, 0),
		BackgroundTransparency = 1,
		Parent = contenuto,
	})

	titoloMazzo = titoloScuro({
		Position = UDim2.fromOffset(4, 0),
		Size = UDim2.fromOffset(220, 60),
		Text = "Deck 0/6",
		TextSize = 52,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = sinistra,
	})
	local _, testoMedia = Stile.chip({
		Position = UDim2.fromOffset(236, 6),
		Size = UDim2.fromOffset(220, 50),
		Parent = sinistra,
	}, "oro", "AVG OVR 0", 28)
	chipMedia = testoMedia
	Stile.testo({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 16),
		Size = UDim2.fromOffset(500, 30),
		Text = "Click a deck card to remove it",
		TextSize = 22,
		TextScaled = false,
		TextColor3 = Stile.Colori.TestoSecondario,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = sinistra,
	})

	local vassoioMazzo = Stile.vassoio({
		Position = UDim2.fromOffset(0, 70),
		Size = UDim2.new(1, 0, 0, 270),
		Parent = sinistra,
	})
	rigaMazzo = Stile.crea("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = vassoioMazzo,
	}, {
		Stile.crea("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 22),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- Intestazione della collezione con i filtri.
	titoloScuro({
		Position = UDim2.fromOffset(4, 356),
		Size = UDim2.fromOffset(240, 56),
		Text = "Collection",
		TextSize = 48,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = sinistra,
	})
	local _, testoCollezione = Stile.chip({
		Position = UDim2.fromOffset(256, 364),
		Size = UDim2.fromOffset(120, 42),
		Parent = sinistra,
	}, "notte", "0/0", 24)
	chipCollezione = testoCollezione
	local filtri = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 352),
		Size = UDim2.fromOffset(800, 64),
		BackgroundTransparency = 1,
		Parent = sinistra,
	}, {
		Stile.crea("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	schedaFiltro(filtri, 1, "ALL", nil, 110, nil)
	schedaFiltro(filtri, 2, "INFANTRY", "cls_inf", 226, "Fanteria")
	schedaFiltro(filtri, 3, "CAVALRY", "cls_cav", 214, "Cavalleria")
	schedaFiltro(filtri, 4, "RANGED", "cls_rng", 204, "Tiratore")

	local vassoioCollezione = Stile.vassoio({
		Position = UDim2.fromOffset(0, 424),
		Size = UDim2.new(1, 0, 1, -424),
		Parent = sinistra,
	})
	-- Griglia che scorre in verticale se le carte non ci stanno.
	griglia = Stile.crea("ScrollingFrame", {
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 10,
		ScrollBarImageColor3 = Stile.CONTORNO,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = vassoioCollezione,
	}, {
		Stile.crea("UIGridLayout", {
			CellSize = UDim2.fromOffset(124, 180),
			CellPadding = UDim2.fromOffset(16, 12),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Stile.crea("UIPadding", {
			PaddingTop = UDim.new(0, 16),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 20),
			PaddingBottom = UDim.new(0, 10),
		}),
	})

	-- Pannello di destra con il dettaglio della carta selezionata.
	dettaglio = Stile.pannello({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(1, -(LARGHEZZA_SINISTRA + 30), 1, 0),
		BackgroundColor3 = Stile.PAL.notte.b,
		BackgroundTransparency = 0,
		Parent = contenuto,
	})
	Stile.bordo(Stile.CONTORNO, 5).Parent = dettaglio
end

function Inventario.aggiorna(nuovoStato)
	if not nuovoStato or not nuovoStato.collezione then
		return
	end
	stato = nuovoStato
	mazzo = table.clone(stato.mazzo)
	numeroMonete.Text = Stile.numero(stato.monete or 0)
	if finestra.Visible then
		disegna()
	end
end

function Inventario.apri()
	finestra.Visible = true
	disegna()
end

function Inventario.chiudi()
	finestra.Visible = false
end

function Inventario.alterna()
	if finestra.Visible then
		Inventario.chiudi()
	else
		Inventario.apri()
	end
end

return Inventario
