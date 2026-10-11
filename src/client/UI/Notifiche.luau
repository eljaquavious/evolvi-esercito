-- Messaggi brevi in alto al centro dello schermo: pillola blu notte con una striscia colorata.

local TweenService = game:GetService("TweenService")

local Stile = require(script.Parent.Stile)

local Notifiche = {}

local contenitore

function Notifiche.inizializza(gui)
	contenitore = Stile.crea("Frame", {
		Name = "Notifiche",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 150),
		Size = UDim2.fromOffset(900, 400),
		BackgroundTransparency = 1,
		ZIndex = 50,
		Parent = Stile.radice(gui),
	}, {
		Stile.crea("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

function Notifiche.mostra(messaggio, colore)
	if not contenitore then
		return
	end
	colore = colore or Stile.Colori.Azzurro
	local riquadro = Stile.crea("Frame", {
		Size = UDim2.fromOffset(0, 64),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Stile.BIANCO,
		ZIndex = 50,
		Parent = contenitore,
	}, {
		Stile.tondo(),
		Stile.bordo(Stile.CONTORNO, 5),
		Stile.sfumatura(Stile.PAL.notte.t, Stile.PAL.notte.d),
		Stile.crea("UIPadding", { PaddingLeft = UDim.new(0, 40), PaddingRight = UDim.new(0, 30) }),
	})
	local striscia = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -24, 0.5, 0),
		Size = UDim2.fromOffset(12, 34),
		BackgroundColor3 = colore,
		ZIndex = 51,
		Parent = riquadro,
	}, { Stile.tondo() })
	local etichetta = Stile.scritta({
		Size = UDim2.fromOffset(0, 64),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = messaggio,
		TextSize = 30,
		TextWrapped = false,
		TextColor3 = colore:Lerp(Stile.BIANCO, 0.55),
		ZIndex = 51,
		Parent = riquadro,
	})
	local scala = Stile.crea("UIScale", { Scale = 0.6, Parent = riquadro })
	TweenService:Create(scala, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(3, function()
		local info = TweenInfo.new(0.35)
		TweenService:Create(riquadro, info, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(etichetta, info, { TextTransparency = 1 }):Play()
		TweenService:Create(striscia, info, { BackgroundTransparency = 1 }):Play()
		for _, bordo in ipairs({ riquadro:FindFirstChildWhichIsA("UIStroke"), etichetta:FindFirstChildWhichIsA("UIStroke") }) do
			TweenService:Create(bordo, info, { Transparency = 1 }):Play()
		end
		task.wait(0.35)
		riquadro:Destroy()
	end)
end

return Notifiche
