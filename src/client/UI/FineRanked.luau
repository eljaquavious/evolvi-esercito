-- Fine di una ranked: l'avatar del vincitore al centro (copiato dal suo personaggio) che salta e gira tra
-- raggi e coriandoli, con il nome, il punteggio e la musica della vittoria (la avvia Partita).
-- Il pulsante LOBBY riporta in lobby. Chi vince riceve una Small Crate, che si apre dopo l'animazione.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Stile = require(script.Parent.Stile)
local Icone = require(script.Parent.Icone)

local FineRanked = {}

local gui, remoti
local velo, giro
local bottoneLobby -- nascosto finché la cassa vinta non è stata aperta

local COLORI_CORIANDOLI = { "#FFD23F", "#5CC8FF", "#FF6B6B", "#7CF56E", "#C77DFF", "#FF8AD8" }

function FineRanked.chiudi()
	if giro then
		giro:Disconnect()
		giro = nil
	end
	if velo then
		velo:Destroy()
		velo = nil
	end
end

-- Copia del personaggio del vincitore, ferma, senza script né suoni (nil se non c'è).
local function copiaPersonaggio(userId)
	local vincitore = userId and Players:GetPlayerByUserId(userId)
	local personaggio = vincitore and vincitore.Character
	if not personaggio then
		return nil
	end
	local archiviabile = personaggio.Archivable
	personaggio.Archivable = true
	local copia = personaggio:Clone()
	personaggio.Archivable = archiviabile
	if not copia then
		return nil
	end
	for _, d in ipairs(copia:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") or d:IsA("BillboardGui") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local radice = copia:FindFirstChild("HumanoidRootPart")
	if radice then
		radice.Transparency = 1
	end
	copia:PivotTo(CFrame.new())
	return copia
end

function FineRanked.mostra(dati)
	FineRanked.chiudi()
	local tela = Stile.radice(gui)
	local vinto = dati.vittoria
	local pal = vinto and Stile.PAL.oro or Stile.PAL.blu
	velo = Stile.crea("Frame", {
		Name = "FineRanked",
		Position = UDim2.fromOffset(0, -200),
		Size = UDim2.new(1, 0, 1, 400),
		BackgroundColor3 = Stile.CONTORNO,
		BackgroundTransparency = 0.3,
		ZIndex = 70,
		Parent = tela,
	})
	local centro = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -40),
		Size = UDim2.fromOffset(10, 10),
		BackgroundTransparency = 1,
		ZIndex = 71,
		Parent = velo,
	})
	local raggi
	local immagine = Icone.immagine("rays")
	if immagine then
		raggi = Stile.crea("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(1000, 1000),
			Image = immagine,
			ImageColor3 = pal.t,
			ImageTransparency = 0.35,
			BackgroundTransparency = 1,
			ZIndex = 71,
			Parent = centro,
		})
	end
	-- Podio sotto l'avatar.
	Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(0, 190),
		Size = UDim2.fromOffset(360, 60),
		BackgroundColor3 = Stile.BIANCO,
		ZIndex = 72,
		Parent = centro,
	}, { Stile.angoli(20), Stile.bordo(Stile.CONTORNO, 6), Stile.sfumatura(Stile.PAL.oro.t, Stile.PAL.oro.b) })

	-- L'avatar del vincitore in una ViewportFrame.
	local vp = Stile.crea("ViewportFrame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(460, 460),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(160, 160, 175),
		LightColor = Color3.fromRGB(255, 246, 230),
		LightDirection = Vector3.new(-0.6, -1, -0.8),
		ZIndex = 73,
		Parent = centro,
	})
	local mondo = Stile.crea("WorldModel", { Parent = vp })
	local camera = Stile.crea("Camera", { FieldOfView = 30, Parent = vp })
	vp.CurrentCamera = camera
	local avatar = copiaPersonaggio(dati.vincitoreId)
	if avatar then
		avatar.Parent = mondo
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.5, -15), Vector3.new(0, 0, 0))
	else
		-- Il vincitore non c'è più (o è il bot di prova): un trofeo al suo posto.
		vp.Visible = false
		Stile.icona("ranked", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(320, 320),
			ZIndex = 73,
			Parent = centro,
		})
	end

	Stile.nastro({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(0, -290),
		Size = UDim2.fromOffset(560, 100),
		Rotation = -3,
		ZIndex = 80,
		Parent = centro,
	}, vinto and "oro" or "rosso", vinto and "VICTORY!" or "DEFEAT", 64)
	local nome = Stile.scritta({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(0, 262),
		Size = UDim2.fromOffset(900, 70),
		Text = ("🏆 %s WINS!"):format(string.upper(dati.vincitore or "")),
		TextSize = 60,
		Contorno = 7,
		TextColor3 = Stile.Colori.Oro,
		ZIndex = 80,
		Parent = centro,
	})
	nome.TextScaled = true
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 60, Parent = nome })
	local righe = { ("Rounds %d - %d"):format(dati.vinti or 0, dati.persi or 0) }
	if dati.ritirato then
		table.insert(righe, "Your opponent left the match.")
	end
	if dati.cassa then
		table.insert(righe, "Reward: a Small Crate!")
	elseif not vinto then
		table.insert(righe, "Better luck next time, commander.")
	end
	Stile.scritta({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(0, 336),
		Size = UDim2.fromOffset(900, 80),
		Text = table.concat(righe, "\n"),
		TextSize = 34,
		Contorno = 4,
		ZIndex = 80,
		Parent = centro,
	})
	bottoneLobby = Stile.pulsante({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(0, 430),
		Size = UDim2.fromOffset(320, 110),
		ZIndex = 81,
		Visible = not dati.cassa,
		Parent = centro,
	}, "verde", { Testo = "LOBBY", TestoSize = 54, Icona = "army", IconaSize = 80, Profondita = 10, Raggio = 26 })
	if dati.cassa then
		local questo = bottoneLobby
		task.delay(15, function()
			if questo.Parent then
				questo.Visible = true
				Stile.seleziona(questo)
			end
		end)
	end
	bottoneLobby.Activated:Connect(function()
		remoti.TornaLobby:InvokeServer()
	end)

	-- Coriandoli che cadono.
	local coriandoli = {}
	for i = 1, 60 do
		local c = Stile.crea("Frame", {
			Position = UDim2.new(math.random(), 0, 0, -math.random(0, 900)),
			Size = UDim2.fromOffset(math.random(10, 18), math.random(18, 30)),
			Rotation = math.random(0, 360),
			BackgroundColor3 = Color3.fromHex(COLORI_CORIANDOLI[i % #COLORI_CORIANDOLI + 1]),
			BorderSizePixel = 0,
			ZIndex = 75,
			Parent = velo,
		})
		table.insert(coriandoli, { frame = c, velocita = math.random(140, 320), giro = math.random(-200, 200), onda = math.random() * 6 })
	end

	local scala = Stile.crea("UIScale", { Scale = 0.4, Parent = centro })
	TweenService:Create(scala, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local tempo = 0
	local altezza = tela.AbsoluteSize.Y / math.max(Stile.scala(), 0.01) + 400
	giro = RunService.RenderStepped:Connect(function(dt)
		tempo += dt
		if raggi then
			raggi.Rotation = tempo * 20
		end
		if avatar and avatar.Parent then
			-- Salta di gioia e gira su se stesso.
			local salto = math.abs(math.sin(tempo * 3.2)) * 1.4
			avatar:PivotTo(CFrame.new(0, salto - 0.6, 0) * CFrame.Angles(0, tempo * 1.6, 0))
		end
		for _, c in ipairs(coriandoli) do
			local y = c.frame.Position.Y.Offset + c.velocita * dt
			if y > altezza then
				y = -40
			end
			c.frame.Position = UDim2.new(c.frame.Position.X.Scale + math.sin(tempo * 2 + c.onda) * 0.0006, 0, 0, y)
			c.frame.Rotation += c.giro * dt
		end
	end)
end

-- La cassa vinta è stata aperta: compare il pulsante LOBBY.
function FineRanked.cassaAperta()
	if bottoneLobby and bottoneLobby.Parent then
		bottoneLobby.Visible = true
		Stile.seleziona(bottoneLobby)
	end
end

function FineRanked.inizializza(g, r)
	gui, remoti = g, r
end

return FineRanked
