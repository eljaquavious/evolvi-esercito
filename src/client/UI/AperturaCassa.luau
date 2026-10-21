-- Apertura di una cassa: la cassa trema al centro dello schermo, un lampo, poi la ricompensa
-- (la carta del reggimento, il cosmetico o le monete). Arriva dall'evento CassaAperta del server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Casse = require(ReplicatedStorage.Shared.Config.Casse)
local Carte = require(ReplicatedStorage.Shared.Config.Carte)
local Epoche = require(ReplicatedStorage.Shared.Config.Epoche)
local Config = require(ReplicatedStorage.Shared.Config.Ricompense)
local Stile = require(script.Parent.Stile)
local Icone = require(script.Parent.Icone)
local Carta = require(script.Parent.Carta)
local Armadio = require(script.Parent.Armadio)

local AperturaCassa = {}

local gui, remoti
local coda = {}
local occupato = false
local allaFine = {} -- funzioni chiamate quando l'ultima cassa in coda è stata chiusa

-- Una cassa sta per aprirsi o è aperta: gli elenchi (shop, locker) aspettano a mostrare la novità.
function AperturaCassa.inCorso()
	return occupato or #coda > 0
end

function AperturaCassa.alTermine(funzione)
	table.insert(allaFine, funzione)
end

local function finito()
	if #coda == 0 then
		for _, f in ipairs(allaFine) do
			task.spawn(f)
		end
	end
end

-- Colori della rarità della carta per l'alone.
local PAL_CARTE = { bronze = "arancio", silver = "blu", gold = "oro", legend = "viola" }

local function tween(oggetto, tempo, proprieta, stile, direzione)
	local t = TweenService:Create(oggetto, TweenInfo.new(tempo, stile or Enum.EasingStyle.Quad, direzione or Enum.EasingDirection.Out), proprieta)
	t:Play()
	return t
end

-- Contenuto della ricompensa dentro il riquadro: restituisce il nastro, il colore e cosa disegnare.
local function descrivi(risultato)
	if risultato.tipo == "truppa" then
		local def = Epoche.Truppe[risultato.id]
		local rarita = Carte.rarita(def)
		return {
			nastro = risultato.nuova and "NEW REGIMENT!" or "+1 COPY",
			palNastro = risultato.nuova and "rosso" or "blu",
			pal = PAL_CARTE[rarita],
			sotto = risultato.nuova and (def.nome .. " joins your army!")
				or ("%s: you now have %d copies"):format(def.nome, risultato.copie or 2),
			leggenda = rarita == "legend",
		}
	elseif risultato.tipo == "cosmetico" then
		local c = Config.cosmetico(risultato.id)
		local rarita = Config.Rarita[c.rarita]
		return {
			nastro = "NEW GEAR!",
			palNastro = "rosso",
			pal = rarita.pal,
			sotto = c.nome,
			chip = rarita.nome,
			leggenda = c.rarita == "leggendario",
		}
	end
	return {
		nastro = "COINS!",
		palNastro = "oro",
		pal = "oro",
		sotto = "+" .. Stile.numero(risultato.quante) .. " coins",
	}
end

local function mostra(risultato)
	occupato = true
	local cassa = Casse.trova(risultato.cassa)
	local info = descrivi(risultato)
	local pal = Stile.PAL[info.pal] or Stile.PAL.blu
	local tela = Stile.radice(gui)

	local velo = Stile.crea("TextButton", {
		Name = "AperturaCassa",
		Text = "",
		AutoButtonColor = false,
		Position = UDim2.fromOffset(0, -200),
		Size = UDim2.new(1, 0, 1, 400),
		BackgroundColor3 = Stile.CONTORNO,
		BackgroundTransparency = 0.25,
		ZIndex = 80,
		Parent = tela,
	})
	local centro = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(10, 10),
		BackgroundTransparency = 1,
		ZIndex = 81,
		Parent = velo,
	})
	local raggi
	local immagineRaggi = Icone.immagine("rays")
	if immagineRaggi then
		raggi = Stile.crea("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(900, 900),
			Image = immagineRaggi,
			ImageColor3 = pal.t,
			ImageTransparency = 0.4,
			BackgroundTransparency = 1,
			ZIndex = 81,
			Parent = centro,
		})
	end
	local tempo = 0
	local giro = RunService.RenderStepped:Connect(function(dt)
		tempo += dt
		if raggi then
			raggi.Rotation = tempo * 25
		end
	end)

	-- 1) La cassa trema sempre più forte.
	local icona = Stile.icona(cassa and cassa.icona or "crate_small", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(380, 380),
		ZIndex = 83,
		Parent = centro,
	})
	local scalaIcona = Stile.crea("UIScale", { Scale = 0.3, Parent = icona })
	tween(scalaIcona, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	task.wait(0.4)
	local durata = 1.3
	local inizio = os.clock()
	while os.clock() - inizio < durata do
		local k = (os.clock() - inizio) / durata
		icona.Rotation = math.sin(os.clock() * (30 + 30 * k)) * (4 + 14 * k)
		scalaIcona.Scale = 1 + 0.12 * k
		RunService.RenderStepped:Wait()
	end

	-- 2) Lampo bianco: la cassa sparisce.
	local lampo = Stile.crea("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Stile.BIANCO,
		BackgroundTransparency = 0,
		ZIndex = 95,
		Parent = velo,
	})
	icona:Destroy()
	tween(lampo, 0.5, { BackgroundTransparency = 1 })
	task.delay(0.5, function()
		lampo:Destroy()
	end)

	-- 3) La ricompensa.
	local riquadro = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(640, 720),
		BackgroundTransparency = 1,
		ZIndex = 84,
		Parent = centro,
	})
	local scala = Stile.crea("UIScale", { Scale = 0.5, Parent = riquadro })
	tween(scala, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	Stile.nastro({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(520, 90),
		Rotation = -3,
		ZIndex = 92,
		Parent = riquadro,
	}, info.palNastro, info.nastro, 56)

	if risultato.tipo == "truppa" then
		local carta = Carta.crea(risultato.id)
		carta.AnchorPoint = Vector2.new(0.5, 0)
		carta.Position = UDim2.new(0.5, 0, 0, 70)
		carta.Size = UDim2.fromOffset(math.floor(440 * Carta.PROPORZIONE), 440)
		carta.ZIndex = 86
		carta.Parent = riquadro
	elseif risultato.tipo == "cosmetico" then
		local c = Config.cosmetico(risultato.id)
		Stile.crea("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 80),
			Size = UDim2.fromOffset(440, 420),
			BackgroundColor3 = Stile.BIANCO,
			ZIndex = 85,
			Parent = riquadro,
		}, { Stile.angoli(30), Stile.bordo(Stile.CONTORNO, 6), Stile.sfumatura(pal.t, pal.b) })
		Armadio.anteprimaCosmetico(c, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 100),
			Size = UDim2.fromOffset(400, 380),
			ZIndex = 86,
			Parent = riquadro,
		})
		Armadio.segnaNuovo(c.id)
	else
		Stile.icona("coins_4", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 90),
			Size = UDim2.fromOffset(380, 380),
			ZIndex = 86,
			Parent = riquadro,
		})
	end

	local sotto = Stile.scritta({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 522),
		Size = UDim2.fromOffset(900, 56),
		Text = info.sotto,
		TextSize = 50,
		Contorno = 6,
		ZIndex = 88,
		Parent = riquadro,
	})
	sotto.TextScaled = true
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 50, Parent = sotto })
	if info.chip then
		Stile.chip({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 584),
			Size = UDim2.fromOffset(210, 44),
			ZIndex = 88,
			Parent = riquadro,
		}, info.pal, info.chip, 26)
	end
	if info.leggenda then
		-- Le leggendarie si fanno notare: l'alone pulsa.
		task.spawn(function()
			while raggi and raggi.Parent do
				tween(raggi, 0.5, { ImageTransparency = 0.1 })
				task.wait(0.5)
				if not raggi.Parent then
					break
				end
				tween(raggi, 0.5, { ImageTransparency = 0.45 })
				task.wait(0.5)
			end
		end)
	end

	local bottoni = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(560, 100),
		BackgroundTransparency = 1,
		ZIndex = 88,
		Parent = riquadro,
	}, {
		Stile.crea("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 20),
		}),
	})
	local function chiudi()
		giro:Disconnect()
		velo:Destroy()
		occupato = false
		finito()
	end
	if risultato.tipo == "cosmetico" then
		local indossa = Stile.pulsante({ Size = UDim2.fromOffset(260, 96), ZIndex = 89, Parent = bottoni }, "verde", {
			Testo = "EQUIP",
			TestoSize = 46,
			Raggio = 24,
		})
		indossa.Activated:Connect(function()
			remoti.Equipaggia:InvokeServer("cosmetico", risultato.id)
			chiudi()
		end)
	end
	local bene = Stile.pulsante({ Size = UDim2.fromOffset(260, 96), ZIndex = 89, Parent = bottoni }, "blu", {
		Testo = "AWESOME",
		TestoSize = 42,
		Raggio = 24,
	})
	bene.Activated:Connect(chiudi)
end

function AperturaCassa.inizializza(g, r)
	gui, remoti = g, r
	remoti.CassaAperta.OnClientEvent:Connect(function(risultato)
		table.insert(coda, risultato)
	end)
	task.spawn(function()
		while true do
			task.wait(0.2)
			if not occupato and #coda > 0 then
				local risultato = table.remove(coda, 1)
				local ok, errore = pcall(mostra, risultato)
				if not ok then
					warn("[AperturaCassa] " .. tostring(errore))
					occupato = false
					finito()
				end
			end
		end
	end)
end

return AperturaCassa
