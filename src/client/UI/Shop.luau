-- Finestra dello shop con le casse.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Casse = require(ReplicatedStorage.Shared.Config.Casse)
local Epoche = require(ReplicatedStorage.Shared.Config.Epoche)
local Stile = require(script.Parent.Stile)
local Notifiche = require(script.Parent.Notifiche)

local Shop = {}

local finestra

-- Disegno della cassa: corpo, coperchio, fascia e serratura.
local function disegnoCassa(genitore, colore)
	local cassa = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.08),
		Size = UDim2.fromScale(0.62, 0.34),
		BackgroundTransparency = 1,
		ZIndex = 12,
		Parent = genitore,
	}, { Stile.crea("UIAspectRatioConstraint", { AspectRatio = 1.3 }) })
	local scuro = colore:Lerp(Color3.new(0, 0, 0), 0.45)
	Stile.crea("Frame", {
		Position = UDim2.fromScale(0, 0.32),
		Size = UDim2.fromScale(1, 0.68),
		BackgroundColor3 = colore,
		ZIndex = 12,
		Parent = cassa,
	}, { Stile.angoli(6), Stile.bordo(scuro, 3), Stile.sfumatura(colore, scuro, 90) })
	Stile.crea("Frame", {
		Size = UDim2.fromScale(1, 0.36),
		BackgroundColor3 = colore:Lerp(Color3.new(1, 1, 1), 0.15),
		ZIndex = 13,
		Parent = cassa,
	}, { Stile.angoli(10), Stile.bordo(scuro, 3), Stile.sfumatura(colore:Lerp(Color3.new(1, 1, 1), 0.25), colore, 90) })
	for _, x in ipairs({ 0.14, 0.86 }) do
		Stile.crea("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(x, 0),
			Size = UDim2.fromScale(0.08, 1),
			BackgroundColor3 = Stile.Colori.Oro,
			ZIndex = 14,
			Parent = cassa,
		}, { Stile.bordo(Stile.Colori.OroScuro, 1.5) })
	end
	Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromScale(0.16, 0.22),
		BackgroundColor3 = Stile.Colori.Oro,
		ZIndex = 15,
		Parent = cassa,
	}, { Stile.angoli(4), Stile.bordo(Stile.Colori.OroScuro, 2) })
end

local function scheda(cassa, ordine, genitore, remoti)
	local riquadro = Stile.pannello({
		Size = UDim2.new(1 / #Casse.Lista, -12, 1, 0),
		LayoutOrder = ordine,
		BackgroundColor3 = cassa.colore:Lerp(Stile.Colori.Sfondo, 0.72),
		ZIndex = 11,
		Parent = genitore,
	})
	disegnoCassa(riquadro, cassa.colore)
	Stile.titolo({
		Position = UDim2.new(0, 10, 0.47, 0),
		Size = UDim2.new(1, -20, 0.09, 0),
		Text = string.upper(cassa.nome),
		TextColor3 = cassa.valuta == "Robux" and Stile.Colori.Oro or Stile.Colori.Testo,
		ZIndex = 12,
		Parent = riquadro,
	})
	Stile.testo({
		Position = UDim2.new(0, 14, 0.58, 0),
		Size = UDim2.new(1, -28, 0.12, 0),
		Text = cassa.descrizione,
		Font = Stile.FontTesto,
		TextColor3 = Stile.Colori.TestoSecondario,
		TextWrapped = true,
		ZIndex = 12,
		Parent = riquadro,
	})
	if cassa.richiedeEpoca then
		Stile.testo({
			Position = UDim2.new(0, 14, 0.71, 0),
			Size = UDim2.new(1, -28, 0.06, 0),
			Text = "Requires the " .. Epoche.epoca(cassa.richiedeEpoca).nome .. " era",
			TextColor3 = Stile.Colori.Oro,
			ZIndex = 12,
			Parent = riquadro,
		})
	end
	local prezzo = cassa.valuta == "Robux" and ("R$ " .. cassa.prezzo) or (cassa.prezzo .. " coins")
	local bottone = Stile.bottone({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(1, -24, 0.14, 0),
		Text = cassa.disponibile and prezzo or (prezzo .. "  ·  SOON"),
		ZIndex = 12,
		Parent = riquadro,
	}, cassa.disponibile and Stile.Colori.Verde or Stile.Colori.Secondario)
	bottone.Activated:Connect(function()
		local ok, messaggio = remoti.AcquistaCassa:InvokeServer(cassa.id)
		if messaggio then
			Notifiche.mostra(messaggio, ok and Stile.Colori.Verde or nil)
		end
	end)
end

function Shop.inizializza(gui, remoti)
	local contenuto
	finestra, contenuto = Stile.finestra(gui, "Shop", "SHOP  ·  CRATES", Stile.Colori.Oro)
	local griglia = Stile.crea("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 11,
		Parent = contenuto,
	}, {
		Stile.crea("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 16),
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
