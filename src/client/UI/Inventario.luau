-- Finestra ARMY: il mazzo da portare in battaglia (in alto) e la collezione di carte (sotto).
-- Clic su una carta della collezione: entra nel mazzo. Clic su una carta del mazzo: esce.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Epoche = require(ReplicatedStorage.Shared.Config.Epoche)
local Carte = require(ReplicatedStorage.Shared.Config.Carte)
local Campagna = require(ReplicatedStorage.Shared.Config.Campagna)
local Stile = require(script.Parent.Stile)
local Carta = require(script.Parent.Carta)
local Notifiche = require(script.Parent.Notifiche)

local Inventario = {}

local remoti
local finestra, rigaMazzo, griglia, riepilogo
local stato -- ultimo stato ricevuto dal server
local mazzo = {} -- copia locale, modificata subito e poi confermata dal server
local salvataggi = 0

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

function disegna()
	if not finestra or not stato then
		return
	end
	svuota(rigaMazzo)
	svuota(griglia)

	local sommaOvr = 0
	for i = 1, Carte.DIMENSIONE_MAZZO do
		local cella = Stile.crea("Frame", {
			Size = UDim2.new(1 / Carte.DIMENSIONE_MAZZO, -10, 1, 0),
			LayoutOrder = i,
			BackgroundTransparency = 1,
			Parent = rigaMazzo,
		})
		local tipo = mazzo[i]
		if tipo then
			sommaOvr += Carte.valutazioni(Epoche.Truppe[tipo]).OVR
			local carta = Carta.crea(tipo)
			carta.AnchorPoint = Vector2.new(0.5, 0.5)
			carta.Position = UDim2.fromScale(0.5, 0.5)
			carta.Size = UDim2.fromScale(1, 1)
			carta.Parent = cella
			carta.Activated:Connect(function()
				togli(i)
			end)
		else
			local vuota = Stile.crea("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Stile.Colori.Pannello,
				BackgroundTransparency = 0.3,
				Parent = cella,
			}, {
				Stile.angoli(12),
				Stile.bordo(Stile.Colori.Bordo, 2, 0.4),
				Stile.crea("UIAspectRatioConstraint", { AspectRatio = Carta.PROPORZIONE }),
			})
			Stile.titolo({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.5, 0.25),
				Text = "+",
				TextColor3 = Stile.Colori.Bordo,
				Parent = vuota,
			})
		end
	end
	local media = #mazzo > 0 and math.floor(sommaOvr / #mazzo + 0.5) or 0
	riepilogo.Text = ("DECK %d/%d   ·   AVG OVR %d"):format(#mazzo, Carte.DIMENSIONE_MAZZO, media)

	local epocaRaggiunta = Campagna.livello(stato.livello).indiceEpoca
	-- Dove si sconfigge ogni comandante, per dire al giocatore come ottenerlo.
	local battagliaDel = {}
	for numero, battaglia in ipairs(Campagna.Battaglie) do
		if battaglia.comandante then
			battagliaDel[battaglia.comandante] = numero
		end
	end
	for ordine, tipo in ipairs(Epoche.carte()) do
		local def = Epoche.Truppe[tipo]
		local possedute = stato.collezione[tipo] or 0
		local libere = possedute - contaNelMazzo(tipo)
		local opzioni = {}
		if possedute == 0 and def.comandante then
			opzioni.nota = "WIN BATTLE " .. battagliaDel[tipo]
			opzioni.spenta = true
		elseif (Epoche.indice(def.epoca) or 1) > epocaRaggiunta then
			opzioni.nota = "LOCKED"
			opzioni.spenta = true
		elseif possedute == 0 then
			opzioni.nota = "NOT OWNED"
			opzioni.spenta = true
		else
			opzioni.quantita = libere
			opzioni.spenta = libere <= 0
		end
		local carta = Carta.crea(tipo, opzioni)
		-- Alta quanto la fila (meno margini e barra di scorrimento), larga in proporzione.
		local altezza = math.max(griglia.AbsoluteSize.Y - 22, 120)
		carta.Size = UDim2.fromOffset(math.floor(altezza * Carta.PROPORZIONE), altezza)
		carta.LayoutOrder = ordine
		carta.Parent = griglia
		if not opzioni.nota then
			carta.Activated:Connect(function()
				aggiungi(tipo)
			end)
		end
	end
end

function Inventario.inizializza(gui, r)
	remoti = r
	local contenuto
	finestra, contenuto = Stile.finestra(gui, "Esercito", "YOUR ARMY", Stile.Colori.Verde)

	riepilogo = Stile.titolo({
		Size = UDim2.new(0.5, 0, 0, 26),
		Text = "DECK",
		TextColor3 = Stile.Colori.Oro,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 11,
		Parent = contenuto,
	})
	Stile.testo({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 4),
		Size = UDim2.new(0.5, 0, 0, 18),
		Text = "Click a deck card to remove it",
		Font = Stile.FontTesto,
		TextColor3 = Stile.Colori.TestoSecondario,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 11,
		Parent = contenuto,
	})

	local fondoMazzo = Stile.pannello({
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 0.5, -32),
		BackgroundColor3 = Stile.Colori.Pannello,
		ZIndex = 11,
		Parent = contenuto,
	})
	rigaMazzo = Stile.crea("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 1, -20),
		BackgroundTransparency = 1,
		Parent = fondoMazzo,
	}, {
		Stile.crea("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	Stile.titolo({
		Position = UDim2.new(0, 0, 0.5, 10),
		Size = UDim2.new(0.5, 0, 0, 26),
		Text = "COLLECTION",
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 11,
		Parent = contenuto,
	})
	Stile.testo({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0.5, 14),
		Size = UDim2.new(0.5, 0, 0, 18),
		Text = "Click a card to add it to your deck",
		Font = Stile.FontTesto,
		TextColor3 = Stile.Colori.TestoSecondario,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 11,
		Parent = contenuto,
	})
	-- Una sola fila che scorre in orizzontale: le carte restano grandi anche con molte epoche.
	griglia = Stile.crea("ScrollingFrame", {
		Position = UDim2.new(0, 0, 0.5, 42),
		Size = UDim2.new(1, 0, 0.5, -42),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Stile.Colori.Bordo,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ZIndex = 11,
		Parent = contenuto,
	}, {
		Stile.crea("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Stile.crea("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 14),
		}),
	})
end

function Inventario.aggiorna(nuovoStato)
	if not nuovoStato or not nuovoStato.collezione then
		return
	end
	stato = nuovoStato
	mazzo = table.clone(stato.mazzo)
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
