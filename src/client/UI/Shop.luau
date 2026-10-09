-- Finestra dello shop con le casse.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Casse = require(ReplicatedStorage.Shared.Config.Casse)
local Stile = require(script.Parent.Stile)
local Notifiche = require(script.Parent.Notifiche)

local Shop = {}

local finestra

local function scheda(cassa, ordine, genitore, remoti)
	local carta = Stile.pannello({
		Size = UDim2.new(1 / 3, -12, 1, 0),
		LayoutOrder = ordine,
		BackgroundColor3 = Stile.Colori.PannelloChiaro,
		Parent = genitore,
	})
	-- Disegno della cassa: un blocco colorato con una fascia.
	local disegno = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.new(0.55, 0, 0.36, 0),
		BackgroundColor3 = cassa.colore,
		BorderSizePixel = 0,
		Parent = carta,
	}, {
		Stile.angoli(8),
		Stile.crea("UIAspectRatioConstraint", { AspectRatio = 1.25 }),
		Stile.crea("UIGradient", {
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150)),
			Rotation = 90,
		}),
	})
	Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.4),
		Size = UDim2.new(1, 0, 0.14, 0),
		BackgroundColor3 = Color3.fromRGB(40, 36, 30),
		BorderSizePixel = 0,
		Parent = disegno,
	})
	Stile.testo({
		Position = UDim2.new(0, 10, 0.44, 0),
		Size = UDim2.new(1, -20, 0.1, 0),
		Text = cassa.nome,
		Font = Stile.FontTitolo,
		Parent = carta,
	})
	Stile.testo({
		Position = UDim2.new(0, 10, 0.55, 0),
		Size = UDim2.new(1, -20, 0.16, 0),
		Text = cassa.descrizione,
		TextColor3 = Stile.Colori.TestoSecondario,
		TextWrapped = true,
		Parent = carta,
	})
	local prezzo = cassa.valuta == "Robux" and ("R$ " .. cassa.prezzo) or ("🪙 " .. cassa.prezzo)
	local bottone = Stile.bottone({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(1, -24, 0.16, 0),
		Text = cassa.disponibile and prezzo or (prezzo .. " · Presto"),
		Parent = carta,
	}, cassa.disponibile and Stile.Colori.Verde or Stile.Colori.PannelloChiaro:Lerp(Stile.Colori.Oro, 0.35))
	bottone.Activated:Connect(function()
		local ok, messaggio = remoti.AcquistaCassa:InvokeServer(cassa.id)
		if messaggio then
			Notifiche.mostra(messaggio, ok and Stile.Colori.Verde or nil)
		end
	end)
end

function Shop.inizializza(gui, remoti)
	finestra = Stile.pannello({
		Name = "Shop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.62, 0.62),
		BackgroundColor3 = Stile.Colori.Sfondo,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	})
	Stile.crea("UISizeConstraint", { MinSize = Vector2.new(340, 300), MaxSize = Vector2.new(860, 520), Parent = finestra })
	Stile.testo({
		Position = UDim2.fromOffset(20, 14),
		Size = UDim2.new(1, -90, 0, 36),
		Text = "SHOP · CASSE",
		Font = Stile.FontTitolo,
		TextColor3 = Stile.Colori.Oro,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = finestra,
	})
	local chiudi = Stile.bottone({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(40, 36),
		Text = "X",
		Parent = finestra,
	}, Stile.Colori.Rosso)
	chiudi.Activated:Connect(function()
		finestra.Visible = false
	end)

	local griglia = Stile.crea("Frame", {
		Position = UDim2.fromOffset(20, 64),
		Size = UDim2.new(1, -40, 1, -84),
		BackgroundTransparency = 1,
		Parent = finestra,
	}, {
		Stile.crea("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 18),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, cassa in ipairs(Casse.Lista) do
		scheda(cassa, i, griglia, remoti)
	end
end

function Shop.apri()
	finestra.Visible = true
end

function Shop.chiudi()
	finestra.Visible = false
end

function Shop.alterna()
	finestra.Visible = not finestra.Visible
end

return Shop
