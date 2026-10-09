-- Messaggi brevi in alto al centro dello schermo.

local TweenService = game:GetService("TweenService")

local Stile = require(script.Parent.Stile)

local Notifiche = {}

local contenitore

function Notifiche.inizializza(gui)
	contenitore = Stile.crea("Frame", {
		Name = "Notifiche",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.11),
		Size = UDim2.fromScale(0.5, 0.3),
		BackgroundTransparency = 1,
		ZIndex = 50,
		Parent = gui,
	}, {
		Stile.crea("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

function Notifiche.mostra(messaggio, colore)
	if not contenitore then
		return
	end
	local riquadro = Stile.pannello({
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Stile.Colori.Sfondo,
		BackgroundTransparency = 0.1,
		ZIndex = 50,
		Parent = contenitore,
	})
	local etichetta = Stile.testo({
		Size = UDim2.new(1, -20, 1, -12),
		Position = UDim2.fromOffset(10, 6),
		Text = messaggio,
		TextColor3 = colore or Stile.Colori.Testo,
		ZIndex = 51,
		Parent = riquadro,
	})
	task.delay(3, function()
		local info = TweenInfo.new(0.4)
		TweenService:Create(riquadro, info, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(etichetta, info, { TextTransparency = 1 }):Play()
		local bordo = riquadro:FindFirstChildWhichIsA("UIStroke")
		if bordo then
			TweenService:Create(bordo, info, { Transparency = 1 }):Play()
		end
		task.wait(0.4)
		riquadro:Destroy()
	end)
end

return Notifiche
