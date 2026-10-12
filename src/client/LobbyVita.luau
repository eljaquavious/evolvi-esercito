-- Vita della Cittadella (la lobby costruita da Server/Lobby), tutta lato client:
--   cielo e luce del tramonto quando si è in lobby (Cielo), quelli del campo quando si esce;
--   giocatori veloci in lobby e ancora di più sui tappeti colorati (attributo "Corsia"), con un po' di
--   campo visivo in più mentre si corre;
--   i soldati e le statue sui piedistalli (attributo "Esposizione"), con il respiro di Animatore;
--   casse dell'armeria che girano, vortici dei portali, fari antiaerei che spazzano il cielo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modelli = require(Shared.Modelli)
local Animatore = require(script.Parent.Animatore)
local Cielo = require(script.Parent.Cielo)

local LobbyVita = {}

local VELOCITA_LOBBY = 30
local VELOCITA_TAPPETO = 58
local VELOCITA_CAMPO = 16
local FOV = 70
local FOV_CORSA = 80

local player = Players.LocalPlayer
local inLobby = true
local animati = {} -- { animatore }
local giranti = {} -- { modello, base, gradi }
local spirali = {} -- { modello, base, gradi }
local fasci = {} -- { parte, base, fase }
local sulTappeto = false
local tweenFov

local parametriTappeto = RaycastParams.new()
parametriTappeto.FilterType = Enum.RaycastFilterType.Include

local function umanoide()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid"), character and character:FindFirstChild("HumanoidRootPart")
end

local function impostaFov(valore)
	if tweenFov then
		tweenFov:Cancel()
	end
	tweenFov = TweenService:Create(workspace.CurrentCamera, TweenInfo.new(0.35, Enum.EasingStyle.Sine), { FieldOfView = valore })
	tweenFov:Play()
end

local function impostaVelocita()
	local u = umanoide()
	if not u then
		return
	end
	if not inLobby then
		u.WalkSpeed = VELOCITA_CAMPO
	else
		u.WalkSpeed = sulTappeto and VELOCITA_TAPPETO or VELOCITA_LOBBY
	end
end

local function entraInLobby(transizione)
	inLobby = true
	-- Dopo Mappa e Partita, che al ritorno ripristinano i valori del campo.
	task.delay(0.15, function()
		if inLobby then
			Cielo.lobby(transizione and 1.2 or 0)
		end
	end)
	impostaVelocita()
end

local function esceDallaLobby()
	inLobby = false
	sulTappeto = false
	Cielo.campo()
	impostaVelocita()
	impostaFov(FOV)
end

-- Soldati di un piedistallo, in file e colonne, rivolti dove guarda il piano.
local function popola(piano)
	local tipo = piano:GetAttribute("Esposizione")
	local righe = piano:GetAttribute("Righe") or 1
	local colonne = piano:GetAttribute("Colonne") or 1
	local scala = piano:GetAttribute("Scala") or 1
	local statua = piano:GetAttribute("Statua") == true
	local cf = piano.CFrame
	local sopra = piano.Size.Y / 2
	local dx = (piano.Size.X - 2.4) / colonne
	local dz = (piano.Size.Z - 2.4) / righe
	for r = 1, righe do
		for c = 1, colonne do
			local x = -piano.Size.X / 2 + 1.2 + (c - 0.5) * dx
			local z = -piano.Size.Z / 2 + 1.2 + (r - 0.5) * dz
			-- Le file dietro sfalsate di mezzo passo, come un reggimento vero.
			if righe > 1 and r % 2 == 0 then
				x += dx * 0.25
			end
			local posizione = (cf * CFrame.new(x, sopra, z)).Position
			local ok, modello, info = pcall(Modelli.crea, tipo, "giocatore", CFrame.lookAt(posizione, posizione + cf.LookVector))
			if ok and modello then
				if scala ~= 1 then
					pcall(modello.ScaleTo, modello, scala)
				end
				modello.Parent = piano.Parent
				for _, parte in ipairs(modello:GetDescendants()) do
					if parte:IsA("BasePart") then
						parte.CanCollide = false
						parte.CanQuery = false
						parte.CanTouch = false
					end
				end
				if not statua and (info.mesh or next(info.giunti)) then
					local a = Animatore.nuovo(modello, info, tipo)
					table.insert(animati, a)
				end
			end
			task.wait()
		end
	end
end

local function prepara(lobby)
	parametriTappeto.FilterDescendantsInstances = { lobby }
	for _, oggetto in ipairs(lobby:GetDescendants()) do
		if oggetto:IsA("Model") and oggetto:GetAttribute("Gira") then
			table.insert(giranti, { modello = oggetto, base = oggetto:GetPivot(), gradi = oggetto:GetAttribute("Gira") })
		elseif oggetto:IsA("Model") and oggetto:GetAttribute("Spirale") then
			table.insert(spirali, { modello = oggetto, base = oggetto:GetPivot(), gradi = oggetto:GetAttribute("Spirale") })
		elseif oggetto:IsA("BasePart") and oggetto.Name == "Fascio" then
			table.insert(fasci, { parte = oggetto, base = oggetto:GetAttribute("Base"), fase = #fasci * 1.7 })
		end
	end
	-- I modelli dopo il resto: costruirli può richiedere qualche frame.
	for _, oggetto in ipairs(lobby:GetDescendants()) do
		if oggetto:IsA("BasePart") and oggetto:GetAttribute("Esposizione") then
			popola(oggetto)
		end
	end
end

local tempo = 0
local controllo = 0

local function aggiorna(dt)
	if not inLobby then
		return
	end
	tempo += dt
	for _, a in ipairs(animati) do
		a:aggiorna(dt, 0)
	end
	for _, g in ipairs(giranti) do
		g.modello:PivotTo(g.base * CFrame.new(0, math.sin(tempo * 1.6 + g.gradi) * 0.35, 0) * CFrame.Angles(0, math.rad(tempo * g.gradi), 0))
	end
	for _, s in ipairs(spirali) do
		s.modello:PivotTo(s.base * CFrame.Angles(0, 0, math.rad(tempo * s.gradi)))
	end
	for _, f in ipairs(fasci) do
		if f.base then
			local yaw = tempo * 0.12 + f.fase
			local pitch = math.rad(52 + 16 * math.sin(tempo * 0.27 + f.fase))
			local dir = Vector3.new(math.cos(pitch) * math.cos(yaw), math.sin(pitch), math.cos(pitch) * math.sin(yaw))
			local meta = f.parte.Size.X / 2
			f.parte.CFrame = CFrame.lookAt(f.base + dir * meta, f.base + dir * (meta + 1)) * CFrame.Angles(0, math.rad(90), 0)
		end
	end

	-- Tappeti veloci: si controlla cosa c'è sotto i piedi dieci volte al secondo.
	controllo += dt
	if controllo >= 0.1 then
		controllo = 0
		local u, radice = umanoide()
		if u and radice then
			local colpo = workspace:Raycast(radice.Position, Vector3.new(0, -6, 0), parametriTappeto)
			local ora = colpo ~= nil and colpo.Instance:GetAttribute("Corsia") == true
			if ora ~= sulTappeto then
				sulTappeto = ora
				impostaFov(ora and FOV_CORSA or FOV)
			end
			local voluta = sulTappeto and VELOCITA_TAPPETO or VELOCITA_LOBBY
			if u.WalkSpeed ~= voluta then
				u.WalkSpeed = voluta
			end
		end
	end
end

function LobbyVita.inizializza(remoti)
	Cielo.lobby(0)
	remoti.Fase.OnClientEvent:Connect(function(dati)
		if dati.fase == "lobby" then
			entraInLobby(true)
		elseif inLobby then
			esceDallaLobby()
		end
	end)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid")
		impostaVelocita()
	end)
	impostaVelocita()
	RunService.RenderStepped:Connect(aggiorna)
	task.spawn(function()
		local lobby = workspace:WaitForChild("Lobby", 60)
		if lobby then
			-- La lobby arriva dal server a pezzi: si aspetta che ci siano i piedistalli.
			task.wait(2)
			prepara(lobby)
		end
	end)
end

return LobbyVita
