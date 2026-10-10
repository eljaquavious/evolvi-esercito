-- Interfaccia della lobby: pulsanti grandi a sinistra (shop, esercito, profilo, ranked), monete e stelle
-- in basso a sinistra, al centro il pulsante PLAY con il mazzo e il livello del giocatore sotto.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modelli = require(ReplicatedStorage.Shared.Modelli)
local Campagna = require(ReplicatedStorage.Shared.Config.Campagna)
local Progressi = require(ReplicatedStorage.Shared.Config.Progressi)
local versione = require(ReplicatedStorage.Shared.Versione)
local Stile = require(script.Parent.Stile)
local Carta = require(script.Parent.Carta)

local Hud = {}

local player = Players.LocalPlayer
local azioni
local sinistra, soldi, centro, etichettaVersione
local etichettaMonete, etichettaStelle, sottotitoloPlay, barraMazzo, numeroLivello, prossimoLivello, riempimentoXp, testoXp
local mazzoMostrato -- per non ricostruire le mini carte se il mazzo non cambia

-- Icona 3D in un ViewportFrame: il modello viene inquadrato da davanti, un po' di lato.
local function icona3D(genitore, modello, proprieta)
	local vista = Stile.crea("ViewportFrame", {
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 170, 170),
		LightColor = Color3.fromRGB(255, 244, 230),
		LightDirection = Vector3.new(-1, -1.4, 1),
		Parent = genitore,
	})
	for k, v in pairs(proprieta) do
		vista[k] = v
	end
	modello.Parent = vista
	local cframe, dimensione = modello:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.CFrame = CFrame.lookAt(cframe.Position + Vector3.new(-0.5, 0.35, -1).Unit * dimensione.Magnitude * 1.7, cframe.Position)
	camera.Parent = vista
	vista.CurrentCamera = camera
	return vista
end

local function modelloCassa()
	local modello = Instance.new("Model")
	local function parte(dimensione, posizione, colore, materiale)
		local p = Instance.new("Part")
		p.Size = dimensione
		p.Position = posizione
		p.Color = colore
		p.Material = materiale
		p.Parent = modello
	end
	parte(Vector3.new(3, 2, 2.2), Vector3.new(0, 1, 0), Color3.fromRGB(176, 120, 64), Enum.Material.WoodPlanks)
	parte(Vector3.new(3.1, 0.6, 2.3), Vector3.new(0, 2.2, 0), Color3.fromRGB(150, 98, 50), Enum.Material.WoodPlanks)
	for _, x in ipairs({ -1.1, 1.1 }) do
		parte(Vector3.new(0.3, 2.8, 2.35), Vector3.new(x, 1.3, 0), Color3.fromRGB(230, 184, 70), Enum.Material.Metal)
	end
	parte(Vector3.new(0.5, 0.6, 0.2), Vector3.new(0, 1.7, -1.2), Color3.fromRGB(230, 184, 70), Enum.Material.Metal)
	return modello
end

local function modelloSpade()
	local modello = Instance.new("Model")
	for _, angolo in ipairs({ 40, -40 }) do
		local lama = Instance.new("Part")
		lama.Size = Vector3.new(0.35, 4, 0.12)
		lama.CFrame = CFrame.Angles(0, 0, math.rad(angolo)) * CFrame.new(0, 1, 0)
		lama.Color = Color3.fromRGB(200, 204, 214)
		lama.Material = Enum.Material.Metal
		lama.Parent = modello
		local elsa = Instance.new("Part")
		elsa.Size = Vector3.new(1.2, 0.25, 0.2)
		elsa.CFrame = CFrame.Angles(0, 0, math.rad(angolo)) * CFrame.new(0, -0.9, 0)
		elsa.Color = Color3.fromRGB(230, 184, 70)
		elsa.Material = Enum.Material.Metal
		elsa.Parent = modello
	end
	return modello
end

-- Pulsante grande con icona a sinistra e scritta.
local function pulsante(genitore, ordine, testo, colore, azione)
	local bottone = Stile.crea("TextButton", {
		Size = UDim2.new(1, 0, 0, 74),
		LayoutOrder = ordine,
		BackgroundColor3 = colore,
		AutoButtonColor = true,
		Text = "",
		Parent = genitore,
	}, {
		Stile.angoli(14),
		Stile.bordo(Color3.new(1, 1, 1), 2.5, 0.15),
		Stile.sfumatura(colore:Lerp(Color3.new(1, 1, 1), 0.2), colore:Lerp(Color3.new(0, 0, 0), 0.3), 90),
	})
	local spazioIcona = Stile.crea("Frame", {
		Position = UDim2.fromOffset(6, 4),
		Size = UDim2.new(0, 70, 1, -8),
		BackgroundTransparency = 1,
		Parent = bottone,
	})
	local scritta = Stile.titolo({
		Position = UDim2.fromOffset(80, 0),
		Size = UDim2.new(1, -90, 1, 0),
		Text = testo,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = bottone,
	})
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 30, Parent = scritta })
	bottone.Activated:Connect(azione)
	return spazioIcona
end

local function moneta(genitore, dimensione)
	local disco = Stile.crea("Frame", {
		Size = UDim2.fromOffset(dimensione, dimensione),
		BackgroundColor3 = Stile.Colori.Oro,
		Parent = genitore,
	}, {
		Stile.angoli(dimensione),
		Stile.bordo(Stile.Colori.OroScuro, 3),
		Stile.sfumatura(Color3.fromRGB(255, 236, 150), Stile.Colori.OroScuro, 120),
	})
	Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.6, 0.6),
		BackgroundTransparency = 1,
		Parent = disco,
	}, { Stile.angoli(dimensione), Stile.bordo(Stile.Colori.OroScuro, 2, 0.3) })
	return disco
end

-- azioni: { play, esercito, shop, profilo, ranked } (funzioni)
function Hud.inizializza(gui, a)
	azioni = a

	-- Colonna di sinistra.
	sinistra = Stile.crea("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.42, 0),
		Size = UDim2.fromOffset(230, 4 * 82),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Stile.crea("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	icona3D(pulsante(sinistra, 1, "SHOP", Color3.fromRGB(214, 70, 70), azioni.shop), modelloCassa(), { Size = UDim2.fromScale(1, 1) })
	icona3D(pulsante(sinistra, 2, "ARMY", Color3.fromRGB(70, 150, 220), azioni.esercito), Modelli.soldato("Legionario", "giocatore"), { Size = UDim2.fromScale(1, 1) })
	local spazioProfilo = pulsante(sinistra, 3, "PROFILE", Color3.fromRGB(140, 90, 210), azioni.profilo)
	local avatar = Stile.crea("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.9),
		BackgroundColor3 = Color3.fromRGB(60, 40, 90),
		Parent = spazioProfilo,
	}, { Stile.angoli(40), Stile.crea("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	task.spawn(function()
		local ok, immagine = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		if ok then
			avatar.Image = immagine
		end
	end)
	icona3D(pulsante(sinistra, 4, "RANKED", Color3.fromRGB(70, 70, 86), azioni.ranked), modelloSpade(), { Size = UDim2.fromScale(1, 1) })

	-- Monete e stelle in basso a sinistra.
	soldi = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -18),
		Size = UDim2.fromOffset(230, 120),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	moneta(soldi, 52).Position = UDim2.fromOffset(0, 4)
	Stile.titolo({ Position = UDim2.fromOffset(62, 0), Size = UDim2.fromOffset(160, 26), Text = "Coins", TextXAlignment = Enum.TextXAlignment.Left, Parent = soldi })
	etichettaMonete = Stile.titolo({
		Position = UDim2.fromOffset(62, 26),
		Size = UDim2.fromOffset(160, 32),
		Text = "0",
		TextColor3 = Stile.Colori.Oro,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = soldi,
	})
	Stile.titolo({
		Position = UDim2.fromOffset(4, 70),
		Size = UDim2.fromOffset(44, 44),
		Text = "★",
		Font = Stile.Font,
		TextColor3 = Stile.Colori.Oro,
		Parent = soldi,
	})
	Stile.titolo({ Position = UDim2.fromOffset(62, 66), Size = UDim2.fromOffset(160, 26), Text = "Stars", TextXAlignment = Enum.TextXAlignment.Left, Parent = soldi })
	etichettaStelle = Stile.titolo({
		Position = UDim2.fromOffset(62, 92),
		Size = UDim2.fromOffset(160, 28),
		Text = "0/" .. Campagna.TOTALE * Campagna.STELLE_MASSIME,
		TextColor3 = Stile.Colori.Oro,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = soldi,
	})

	-- Centro in basso: PLAY, mazzo, livello del giocatore.
	centro = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(500, 240),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local play = Stile.bottone({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(240, 74),
		Text = "",
		Parent = centro,
	}, Color3.fromRGB(60, 190, 80))
	play.Activated:Connect(azioni.play)
	-- Il bottone ha un padding: le due scritte stanno dentro l'area senza padding.
	play:FindFirstChildOfClass("UIPadding"):Destroy()
	Stile.titolo({
		Position = UDim2.fromScale(0, 0.08),
		Size = UDim2.fromScale(1, 0.56),
		Text = "PLAY",
		Parent = play,
	})
	sottotitoloPlay = Stile.testo({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(1, -20, 0, 18),
		Text = "",
		TextColor3 = Color3.fromRGB(230, 255, 230),
		TextStrokeTransparency = 0.5,
		Parent = play,
	})

	barraMazzo = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 86),
		Size = UDim2.fromOffset(6 * 66 + 5 * 8, 80),
		BackgroundTransparency = 1,
		Parent = centro,
	}, {
		Stile.crea("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local livello = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(480, 44),
		BackgroundTransparency = 1,
		Parent = centro,
	})
	Stile.testo({ Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(40, 16), Text = "Lv.", TextXAlignment = Enum.TextXAlignment.Left, Parent = livello })
	numeroLivello = Stile.titolo({
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.fromOffset(44, 28),
		Text = "1",
		TextColor3 = Color3.fromRGB(120, 190, 255),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = livello,
	})
	local binario = Stile.crea("Frame", {
		Position = UDim2.fromOffset(48, 20),
		Size = UDim2.new(1, -96, 0, 20),
		BackgroundColor3 = Stile.Colori.Sfondo,
		BackgroundTransparency = 0.2,
		Parent = livello,
	}, { Stile.angoli(6), Stile.bordo(Color3.new(1, 1, 1), 1.5, 0.4) })
	riempimentoXp = Stile.crea("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = binario,
	}, { Stile.angoli(6), Stile.sfumatura(Color3.fromRGB(60, 140, 255), Color3.fromRGB(150, 210, 255), 0) })
	testoXp = Stile.testo({
		Position = UDim2.fromOffset(8, 2),
		Size = UDim2.new(1, -16, 1, -4),
		Text = "",
		ZIndex = 3,
		TextStrokeTransparency = 0.4,
		Parent = binario,
	})
	prossimoLivello = Stile.titolo({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 16),
		Size = UDim2.fromOffset(44, 28),
		Text = "2",
		TextColor3 = Color3.fromRGB(120, 190, 255),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = livello,
	})

	etichettaVersione = Stile.testo({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -10, 1, -6),
		Size = UDim2.fromOffset(120, 16),
		Text = "v" .. versione,
		Font = Stile.FontTesto,
		TextColor3 = Color3.fromRGB(220, 220, 230),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextStrokeTransparency = 0.5,
		Parent = gui,
	})
end

local function mostraMazzo(mazzo)
	local firma = table.concat(mazzo, ",")
	if firma == mazzoMostrato then
		return
	end
	mazzoMostrato = firma
	for _, figlio in ipairs(barraMazzo:GetChildren()) do
		if figlio:IsA("GuiObject") then
			figlio:Destroy()
		end
	end
	for i = 1, 6 do
		local tipo = mazzo[i]
		local cella
		if tipo then
			cella = Carta.mini(tipo, i)
			cella.Activated:Connect(azioni.esercito)
		else
			cella = Stile.crea("TextButton", {
				Text = "",
				BackgroundColor3 = Stile.Colori.Sfondo,
				BackgroundTransparency = 0.35,
			}, {
				Stile.angoli(8),
				Stile.bordo(Color3.new(1, 1, 1), 1.5, 0.5),
				Stile.crea("UIAspectRatioConstraint", { AspectRatio = 0.82 }),
			})
			cella.Activated:Connect(azioni.esercito)
		end
		cella.Size = UDim2.new(0, 66, 1, 0)
		cella.LayoutOrder = i
		cella.Parent = barraMazzo
	end
end

function Hud.aggiorna(stato)
	if not stato then
		return
	end
	etichettaMonete.Text = tostring(stato.monete)
	local stelle = 0
	for _, n in pairs(stato.stelle or {}) do
		stelle += n
	end
	etichettaStelle.Text = ("%d/%d"):format(stelle, Campagna.TOTALE * Campagna.STELLE_MASSIME)
	if stato.completata then
		sottotitoloPlay.Text = "Campaign complete!"
	else
		local livello = Campagna.livello(stato.livello)
		sottotitoloPlay.Text = ("Battle %d: %s"):format(stato.livello, livello.nome)
	end
	local livello, xp, serve = Progressi.livello(stato.esperienza or 0)
	numeroLivello.Text = tostring(livello)
	prossimoLivello.Text = tostring(livello + 1)
	riempimentoXp.Size = UDim2.fromScale(math.clamp(xp / serve, 0.02, 1), 1)
	testoXp.Text = ("%d / %d XP"):format(xp, serve)
	mostraMazzo(stato.mazzo or {})
end

-- In lobby si vede tutto; in mappa e in partita c'è la loro interfaccia al posto di questa.
function Hud.mostraLobby(visibile)
	sinistra.Visible = visibile
	soldi.Visible = visibile
	centro.Visible = visibile
	etichettaVersione.Visible = visibile
end

return Hud
