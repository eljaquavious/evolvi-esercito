-- Animazioni degli avatar dei giocatori calcolate a ogni fotogramma (8/11/2026): al posto di quelle standard di
-- Roblox per fermo, camminata e corsa, le andature di Andature (la camminata è la stessa delle truppe).
-- Ogni client spegne lo script Animate del proprio personaggio (così non partono e non si replicano le
-- animazioni standard) e anima tutti i personaggi vicini muovendo le articolazioni con .Transform.
-- Camminata a velocità normale (lobby e battaglia, 30), corsa sul tappeto veloce (58).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Andature = require(script.Parent.Andature)

local Avatar = {}

local player = Players.LocalPlayer

-- Articolazione delle andature -> Motor6D dell'avatar (R15 e R6).
local GIUNTI_R15 = {
	bacino = "Root",
	torace = "Waist",
	testa = "Neck",
	["braccio.R"] = "RightShoulder",
	["braccio.L"] = "LeftShoulder",
	["avambraccio.R"] = "RightElbow",
	["avambraccio.L"] = "LeftElbow",
	["coscia.R"] = "RightHip",
	["coscia.L"] = "LeftHip",
	["stinco.R"] = "RightKnee",
	["stinco.L"] = "LeftKnee",
	["piede.R"] = "RightAnkle",
	["piede.L"] = "LeftAnkle",
}
local GIUNTI_R6 = {
	bacino = "RootJoint",
	testa = "Neck",
	["braccio.R"] = "Right Shoulder",
	["braccio.L"] = "Left Shoulder",
	["coscia.R"] = "Right Hip",
	["coscia.L"] = "Left Hip",
}

local VELOCITA_CORSA = 44 -- sopra questa velocità (studs/s) si corre: il tappeto va a 58, la lobby a 30
local DISTANZA = 260 -- oltre, gli avatar restano fermi (non si vedono)
-- Braccia dei giocatori più vicine al corpo che nelle truppe (Mattia, 10/11/2026): un terzo dell'apertura.
local OPZIONI = { apertura = 0.33 }

local personaggi = {} -- character -> stato

local function spegniAnimate(character)
	local animate = character:FindFirstChild("Animate")
	if animate and animate:IsA("LocalScript") then
		animate.Disabled = true
	end
	local umanoide = character:FindFirstChildOfClass("Humanoid")
	local animator = umanoide and umanoide:FindFirstChildOfClass("Animator")
	if animator then
		for _, traccia in ipairs(animator:GetPlayingAnimationTracks()) do
			traccia:Stop(0)
		end
	end
end

-- Articolazioni del personaggio: Motor6D (avatar classici) o AnimationConstraint (avatar nuovi di Roblox, con
-- il telaio nell'Attachment0). Per ognuna la rotazione del telaio: le rotazioni si danno negli assi della
-- parte madre e si portano negli assi dell'articolazione (T = C0⁻¹ · R · C0).
local function giunti(character, umanoide)
	local nomi = umanoide.RigType == Enum.HumanoidRigType.R15 and GIUNTI_R15 or GIUNTI_R6
	local motori = {}
	for _, m in ipairs(character:GetDescendants()) do
		if m:IsA("Motor6D") then
			motori[m.Name] = { motore = m, c0 = m.C0.Rotation }
		elseif m:IsA("AnimationConstraint") and m.Attachment0 then
			motori[m.Name] = { motore = m, c0 = m.Attachment0.CFrame.Rotation }
		end
	end
	local risultato = {}
	for articolazione, nome in pairs(nomi) do
		risultato[articolazione] = motori[nome]
	end
	return risultato
end

local function aggiungi(character)
	if personaggi[character] then
		return
	end
	local umanoide = character:WaitForChild("Humanoid", 10)
	local radice = character:WaitForChild("HumanoidRootPart", 10)
	if not umanoide or not radice or not character.Parent then
		return
	end
	-- Le articolazioni arrivano dopo l'umanoide: si aspetta il bacino.
	character:WaitForChild(umanoide.RigType == Enum.HumanoidRigType.R15 and "LowerTorso" or "Torso", 10)
	task.wait(0.2)
	if not character.Parent then
		return
	end
	if Players:GetPlayerFromCharacter(character) == player then
		spegniAnimate(character)
		-- Animate potrebbe ripartire o venire aggiunto dopo: si rispegne.
		character.ChildAdded:Connect(function(figlio)
			if figlio.Name == "Animate" then
				task.defer(spegniAnimate, character)
			end
		end)
	end
	local stato = {
		umanoide = umanoide,
		radice = radice,
		giunti = giunti(character, umanoide),
		fase = 0,
		tempo = math.random() * 10,
		cammina = 0,
		corsa = 0,
		aria = 0,
	}
	-- Se l'avatar cambia (vestiti, scala) le articolazioni si rileggono.
	character.DescendantAdded:Connect(function(d)
		if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then
			task.defer(function()
				stato.giunti = giunti(character, umanoide)
			end)
		end
	end)
	personaggi[character] = stato
	character.AncestryChanged:Connect(function(_, padre)
		if not padre then
			personaggi[character] = nil
		end
	end)
end

local parametriTerra = RaycastParams.new()
parametriTerra.FilterType = Enum.RaycastFilterType.Exclude

local function inAria(character, stato)
	local u = stato.umanoide
	if Players:GetPlayerFromCharacter(character) == player then
		local st = u:GetState()
		return st == Enum.HumanoidStateType.Freefall or st == Enum.HumanoidStateType.Jumping
	end
	-- Gli altri: il terreno sotto i piedi.
	parametriTerra.FilterDescendantsInstances = { character }
	local altezza = u.HipHeight + stato.radice.Size.Y / 2 + 1.2
	return workspace:Raycast(stato.radice.Position, Vector3.new(0, -altezza, 0), parametriTerra) == nil
end

local function anima(character, stato, dt)
	local u, radice = stato.umanoide, stato.radice
	stato.tempo += dt
	-- Velocità dallo spostamento vero, smussata: AssemblyLinearVelocity a volte vale 0 un fotogramma sì e uno no.
	local posizione = radice.Position
	local spostamento = (stato.ultima and dt > 0) and (posizione - stato.ultima) / dt or Vector3.zero
	stato.ultima = posizione
	if spostamento.Magnitude > 200 then
		spostamento = Vector3.zero -- teletrasporto
	end
	stato.v = (stato.v or Vector3.zero):Lerp(spostamento, math.min(1, dt * 8))
	local v = stato.v
	local velocita = Vector3.new(v.X, 0, v.Z).Magnitude
	local aria = inAria(character, stato) and 1 or 0
	local cammina = math.clamp((velocita - 0.5) / 5, 0, 1)
	local corsa = math.clamp((velocita - VELOCITA_CORSA) / 10, 0, 1)
	local k = math.min(1, dt * 10)
	stato.cammina += (cammina - stato.cammina) * k
	stato.corsa += (corsa - stato.corsa) * math.min(1, dt * 5)
	stato.aria += (aria - stato.aria) * math.min(1, dt * 12)
	-- Ritmo dei passi: cresce con la velocità ma meno che in proporzione (velocità del gioco alte).
	local passi = 0.9 + math.min(velocita, 70) * 0.03
	stato.fase = (stato.fase + dt * passi) % 1

	local posa
	if u.Sit then
		posa = Andature.seduto()
	else
		posa = Andature.fermo(stato.tempo, OPZIONI)
		if stato.cammina > 0.01 then
			local passo = Andature.cammina(stato.fase, OPZIONI)
			if stato.corsa > 0.01 then
				passo = Andature.miscela(passo, Andature.corsaGiocatore(stato.fase), stato.corsa)
			end
			posa = Andature.miscela(posa, passo, stato.cammina)
		end
		if stato.aria > 0.01 then
			posa = Andature.miscela(posa, Andature.aria(v.Y > 0), stato.aria)
		end
	end
	for articolazione, g in pairs(stato.giunti) do
		local cf = posa[articolazione]
		if g.motore.Parent then
			g.motore.Transform = cf and (g.c0:Inverse() * cf * g.c0) or CFrame.identity
		end
	end
end

local function passo(dt)
	local camera = workspace.CurrentCamera
	local occhio = camera and camera.CFrame.Position
	for character, stato in pairs(personaggi) do
		local radice = stato.radice
		if radice.Parent and stato.umanoide.Health > 0 then
			if not occhio or (radice.Position - occhio).Magnitude < DISTANZA then
				anima(character, stato, dt)
			end
		end
	end
end

function Avatar.inizializza()
	local function seguiGiocatore(p)
		p.CharacterAdded:Connect(function(character)
			task.spawn(aggiungi, character)
		end)
		if p.Character then
			task.spawn(aggiungi, p.Character)
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		seguiGiocatore(p)
	end
	Players.PlayerAdded:Connect(seguiGiocatore)
	-- Dopo le animazioni di Roblox e prima della fisica: il Transform scritto qui è quello che si vede.
	RunService.PreSimulation:Connect(passo)
end

return Avatar
