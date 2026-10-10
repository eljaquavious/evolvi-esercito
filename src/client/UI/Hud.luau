-- Barra in basso al centro (monete, epoca, livello) e menu laterale della lobby.

local Stile = require(script.Parent.Stile)

local Hud = {}

local etichettaMonete, etichettaEpoca, etichettaLivello, riempimento, menu, barra

local function moneta(genitore)
	-- Moneta disegnata: niente emoji, che su alcuni dispositivi diventano quadratini.
	local disco = Stile.crea("Frame", {
		Position = UDim2.fromOffset(10, 9),
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = Stile.Colori.Oro,
		Parent = genitore,
	}, {
		Stile.angoli(16),
		Stile.bordo(Stile.Colori.OroScuro, 2.5),
		Stile.sfumatura(Color3.fromRGB(255, 236, 150), Stile.Colori.OroScuro, 120),
	})
	Stile.titolo({
		Size = UDim2.fromScale(1, 1),
		Text = "C",
		TextColor3 = Color3.fromRGB(255, 248, 210),
		Parent = disco,
	})
end

-- azioni: { campagna, esercito, shop, profilo, ranked } (funzioni)
function Hud.inizializza(gui, azioni)
	barra = Stile.crea("Frame", {
		Name = "Barra",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(520, 50),
		BackgroundTransparency = 1,
		Parent = gui,
	})

	local monete = Stile.pannello({
		Size = UDim2.new(0, 180, 1, 0),
		BackgroundColor3 = Stile.Colori.Sfondo,
		BackgroundTransparency = 0,
		Parent = barra,
	})
	moneta(monete)
	etichettaMonete = Stile.titolo({
		Position = UDim2.fromOffset(50, 9),
		Size = UDim2.new(1, -62, 1, -18),
		Text = "0",
		TextColor3 = Stile.Colori.Oro,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = monete,
	})

	local progresso = Stile.pannello({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(1, -192, 1, 0),
		BackgroundColor3 = Stile.Colori.Sfondo,
		BackgroundTransparency = 0,
		Parent = barra,
	})
	etichettaEpoca = Stile.titolo({
		Position = UDim2.fromOffset(14, 5),
		Size = UDim2.new(0.55, -14, 0, 22),
		Text = "Loading...",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = progresso,
	})
	etichettaLivello = Stile.testo({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 7),
		Size = UDim2.new(0.45, -14, 0, 18),
		Text = "",
		TextColor3 = Stile.Colori.TestoSecondario,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = progresso,
	})
	local binario = Stile.crea("Frame", {
		Position = UDim2.new(0, 14, 1, -17),
		Size = UDim2.new(1, -28, 0, 9),
		BackgroundColor3 = Stile.Colori.PannelloChiaro,
		BorderSizePixel = 0,
		Parent = progresso,
	}, { Stile.angoli(5) })
	riempimento = Stile.crea("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Stile.Colori.Oro,
		BorderSizePixel = 0,
		Parent = binario,
	}, { Stile.angoli(5), Stile.sfumatura(Stile.Colori.Oro, Stile.Colori.OroScuro, 0) })

	menu = Stile.crea("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(200, 5 * 56),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Stile.crea("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local voci = {
		{ "CAMPAIGN", Stile.Colori.Blu, azioni.campagna },
		{ "ARMY", Stile.Colori.Verde, azioni.esercito },
		{ "SHOP", Color3.fromRGB(214, 160, 40), azioni.shop },
		{ "PROFILE", Stile.Colori.Viola, azioni.profilo },
		{ "RANKED", Stile.Colori.Rosso, azioni.ranked },
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
	etichettaMonete.Text = tostring(stato.monete)
	if stato.completata then
		etichettaEpoca.Text = "Campaign complete!"
		etichettaLivello.Text = ("Level %d/%d"):format(stato.totale, stato.totale)
		riempimento.Size = UDim2.fromScale(1, 1)
	else
		etichettaEpoca.Text = string.upper(stato.epoca) .. " ERA"
		etichettaLivello.Text = ("Level %d/%d"):format(stato.livello, stato.totale)
		riempimento.Size = UDim2.fromScale((stato.livello - 1) / stato.totale, 1)
	end
end

-- In lobby si vedono barra e menu; durante una partita c'è l'intestazione della partita al loro posto.
function Hud.mostraLobby(visibile)
	menu.Visible = visibile
	barra.Visible = visibile
end

return Hud
