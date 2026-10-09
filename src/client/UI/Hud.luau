-- Barra in alto (monete, epoca, livello) e menu laterale della lobby.

local Stile = require(script.Parent.Stile)

local Hud = {}

local etichettaMonete, etichettaProgresso, menu, barra

-- azioni: { campagna = fn, ranked = fn, shop = fn }
function Hud.inizializza(gui, azioni)
	barra = Stile.pannello({
		Name = "Barra",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.new(0, 460, 0, 46),
		BackgroundColor3 = Stile.Colori.Sfondo,
		BackgroundTransparency = 0.15,
		Parent = gui,
	})
	etichettaMonete = Stile.testo({
		Size = UDim2.new(0.34, -10, 1, -14),
		Position = UDim2.fromOffset(12, 7),
		Text = "0 monete",
		TextColor3 = Stile.Colori.Oro,
		Font = Stile.FontTitolo,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = barra,
	})
	etichettaProgresso = Stile.testo({
		Size = UDim2.new(0.66, -14, 1, -16),
		Position = UDim2.new(0.34, 0, 0, 8),
		Text = "Caricamento…",
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = barra,
	})

	menu = Stile.crea("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.new(0, 190, 0, 3 * 58),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Stile.crea("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local voci = {
		{ "Campagna", Stile.Colori.Blu, azioni.campagna },
		{ "Ranked", Stile.Colori.Rosso, azioni.ranked },
		{ "Shop", Color3.fromRGB(196, 150, 40), azioni.shop },
	}
	for i, voce in ipairs(voci) do
		local bottone = Stile.bottone({
			Size = UDim2.new(1, 0, 0, 48),
			Text = voce[1],
			LayoutOrder = i,
			Parent = menu,
		}, voce[2])
		bottone.Activated:Connect(voce[3])
	end
end

function Hud.aggiorna(stato)
	if not stato then
		return
	end
	etichettaMonete.Text = stato.monete .. " monete"
	if stato.completata then
		etichettaProgresso.Text = "Campagna completata!"
	else
		etichettaProgresso.Text = ("Epoca %s · Livello %d/%d"):format(stato.epoca, stato.livello, stato.totale)
	end
end

-- In lobby si vedono barra e menu; durante una partita c'è l'intestazione della partita al loro posto.
function Hud.mostraLobby(visibile)
	menu.Visible = visibile
	barra.Visible = visibile
end

return Hud
