-- Finestra PROFILE: avatar, progresso nella campagna e statistiche personali.

local Players = game:GetService("Players")

local Stile = require(script.Parent.Stile)

local Profilo = {}

local player = Players.LocalPlayer
local finestra, sottotitolo, griglia
local stato

-- { titolo, funzione(stato, statistiche) -> testo, colore }
local VOCI = {
	{ "BATTLES", function(_, s) return s.battaglie end },
	{ "VICTORIES", function(_, s) return s.vittorie end, Stile.Colori.Verde },
	{ "DEFEATS", function(_, s) return s.sconfitte end, Stile.Colori.Rosso },
	{ "WIN RATE", function(_, s)
		if s.battaglie == 0 then
			return "-"
		end
		return math.floor(s.vittorie / s.battaglie * 100 + 0.5) .. "%"
	end, Stile.Colori.Oro },
	{ "ENEMY REGIMENTS DEFEATED", function(_, s) return s.reggimentiSconfitti end },
	{ "REGIMENTS LOST", function(_, s) return s.reggimentiPersi end },
	{ "COINS EARNED", function(_, s) return s.moneteGuadagnate end, Stile.Colori.Oro },
	{ "HIGHEST LEVEL", function(st, s) return ("%d/%d"):format(math.max(s.livelloMassimo, st.livello), st.totale) end },
	{ "CARDS OWNED", function(st)
		local n = 0
		for _, quante in pairs(st.collezione) do
			n += quante
		end
		return n
	end, Stile.Colori.Viola },
}

local function disegna()
	if not stato or not stato.statistiche then
		return
	end
	sottotitolo.Text = stato.completata and "Campaign complete"
		or ("%s Era  ·  Level %d/%d"):format(stato.epoca, stato.livello, stato.totale)
	for _, figlio in ipairs(griglia:GetChildren()) do
		if figlio:IsA("GuiObject") then
			figlio:Destroy()
		end
	end
	for i, voce in ipairs(VOCI) do
		local riquadro = Stile.pannello({
			LayoutOrder = i,
			BackgroundColor3 = Stile.Colori.Pannello,
			ZIndex = 11,
			Parent = griglia,
		})
		Stile.titolo({
			Position = UDim2.fromScale(0.06, 0.12),
			Size = UDim2.fromScale(0.88, 0.48),
			Text = tostring(voce[2](stato, stato.statistiche)),
			TextColor3 = voce[3] or Stile.Colori.Testo,
			ZIndex = 12,
			Parent = riquadro,
		})
		Stile.testo({
			Position = UDim2.fromScale(0.06, 0.64),
			Size = UDim2.fromScale(0.88, 0.22),
			Text = voce[1],
			TextColor3 = Stile.Colori.TestoSecondario,
			ZIndex = 12,
			Parent = riquadro,
		})
	end
end

function Profilo.inizializza(gui)
	local contenuto
	finestra, contenuto = Stile.finestra(gui, "Profilo", "PROFILE", Stile.Colori.Viola)

	local scheda = Stile.pannello({
		Size = UDim2.new(0.3, -10, 1, 0),
		BackgroundColor3 = Stile.Colori.Pannello,
		ZIndex = 11,
		Parent = contenuto,
	})
	local avatar = Stile.crea("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.06),
		Size = UDim2.fromScale(0.8, 0.46),
		BackgroundColor3 = Stile.Colori.PannelloChiaro,
		ZIndex = 12,
		Parent = scheda,
	}, {
		Stile.angoli(200),
		Stile.bordo(Stile.Colori.Oro, 3),
		Stile.crea("UIAspectRatioConstraint", { AspectRatio = 1 }),
	})
	task.spawn(function()
		local ok, immagine = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
		end)
		if ok then
			avatar.Image = immagine
		end
	end)
	Stile.titolo({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.fromScale(0.9, 0.1),
		Text = player.DisplayName,
		ZIndex = 12,
		Parent = scheda,
	})
	Stile.testo({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.67),
		Size = UDim2.fromScale(0.9, 0.06),
		Text = "@" .. player.Name,
		Font = Stile.FontTesto,
		TextColor3 = Stile.Colori.TestoSecondario,
		ZIndex = 12,
		Parent = scheda,
	})
	sottotitolo = Stile.testo({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.8),
		Size = UDim2.fromScale(0.9, 0.08),
		Text = "",
		TextColor3 = Stile.Colori.Oro,
		ZIndex = 12,
		Parent = scheda,
	})

	griglia = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.7, -10, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 11,
		Parent = contenuto,
	}, {
		Stile.crea("UIGridLayout", {
			CellSize = UDim2.new(1 / 3, -8, 1 / 3, -8),
			CellPadding = UDim2.fromOffset(12, 12),
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
