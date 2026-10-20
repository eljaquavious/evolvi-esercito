-- Cinematica breve tra un round e l'altro (5-6 secondi): bande nere, una scritta sull'esito del round
-- ("The Persians are falling back!") e la telecamera che scorre sul campo, con i superstiti ancora lì.
-- Chi ha perso il round ripiega verso le sue retrovie. Tutto vive solo su questo client.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Truppe = require(script.Parent.Truppe)
local Epoche = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Epoche"))

local Intermezzo = {}

-- Frasi dei boss (inglese, storiche dove possibile): vince = il boss ha vinto il round, perde = l'ha perso.
local FRASI_BOSS = {
	Annibale = { vince = "We will either find a way, or make one.", perde = "Carthage does not kneel!" },
	Cesare = { vince = "Veni, vidi, vici.", perde = "The die is cast. Again!" },
	Guglielmo = { vince = "England is mine by right!", perde = "Look at me! I live, and by God I will win!" },
	Saladino = { vince = "The Horns of Hattin will be your grave.", perde = "Hold the water! Hold the hill!" },
	Giovanna = { vince = "Fear not! God is with us!", perde = "I am not afraid. I was born for this." },
	GustavoAdolfo = { vince = "God with us!", perde = "Forward, for the King of Sweden!" },
	Napoleone = { vince = "Impossible is not a French word.", perde = "The Guard dies, it does not surrender!" },
	Foch = { vince = "Situation excellent. I attack!", perde = "Hold! Hold at all costs!" },
	Rommel = { vince = "Sweat saves blood.", perde = "The first hours will be decisive!" },
	DeGaulle = { vince = "Paris, liberated by her own people!", perde = "France has lost a battle, not the war!" },
	Giap = { vince = "The jungle fights with us.", perde = "We will fight for as long as it takes." },
	PengDehuai = { vince = "The mountains and the snow are on our side.", perde = "Attack again tonight!" },
}

local player = Players.LocalPlayer

local GARAMOND = Font.fromEnum(Enum.Font.Garamond).Family
local FONT = Font.new(GARAMOND, Enum.FontWeight.Bold)
local FONT_CORSIVO = Font.new(GARAMOND, Enum.FontWeight.Regular, Enum.FontStyle.Italic)
local BANDA = 0.11 -- altezza delle bande nere, come nelle cinematiche dei livelli

local inCorso = nil -- { gui, connessione, fine }

-- La telecamera non deve finire dentro una collina: se sotto c'è terreno più alto, la si alza.
local soloTerreno = RaycastParams.new()
soloTerreno.FilterType = Enum.RaycastFilterType.Include
soloTerreno.FilterDescendantsInstances = { workspace.Terrain }
local function sopraTerreno(cf)
	local p = cf.Position
	local colpo = workspace:Raycast(p + Vector3.new(0, 200, 0), Vector3.new(0, -400, 0), soloTerreno)
	if colpo and p.Y < colpo.Position.Y + 3 then
		return cf + Vector3.new(0, colpo.Position.Y + 3 - p.Y, 0)
	end
	return cf
end

local function maiuscola(testo)
	return (string.gsub(testo, "^%l", string.upper))
end

-- La scritta dell'esito. nemico = nome dell'esercito nemico ("the Persians").
local function frase(dati)
	local n = dati.nemico or "the enemy"
	local N = maiuscola(n)
	local perVincere = dati.perVincere or 3
	local scelte
	if dati.vittoria then
		if dati.finita then
			scelte = { ("Victory! %s are routed!"):format(N), ("%s flee the field!"):format(N) }
		elseif dati.vinti == perVincere - 1 and dati.persi < perVincere - 1 then
			scelte = { ("%s retreat behind their walls!"):format(N) }
		else
			scelte = { ("%s are falling back!"):format(N), ("%s are wavering!"):format(N), ("The line of %s is breaking!"):format(n) }
		end
	elseif dati.finita then
		scelte = { ("Defeat... %s hold the field."):format(N) }
	elseif dati.persi == perVincere - 1 then
		scelte = { "Our army is on the brink!", "One more blow and we are finished!" }
	else
		scelte = { ("%s press the attack!"):format(N), "Our lines are breaking!", "We fall back to regroup!" }
	end
	return scelte[math.random(#scelte)]
end

local function etichetta(gui, testo, font, altezza, y, trasparenza)
	local e = Instance.new("TextLabel")
	e.AnchorPoint = Vector2.new(0.5, 0.5)
	e.Position = UDim2.fromScale(0.5, y)
	e.Size = UDim2.fromScale(0.8, altezza)
	e.BackgroundTransparency = 1
	e.FontFace = font
	e.Text = testo
	e.TextScaled = true
	e.TextColor3 = Color3.fromRGB(245, 238, 222)
	e.TextTransparency = 1
	e.TextStrokeTransparency = 1
	e.TextStrokeColor3 = Color3.new(0, 0, 0)
	e.ZIndex = 3
	e.Parent = gui
	TweenService:Create(e, TweenInfo.new(0.6), { TextTransparency = trasparenza, TextStrokeTransparency = 0.5 }):Play()
	return e
end

local function chiudi(subito)
	local stato = inCorso
	if not stato then
		return
	end
	inCorso = nil
	stato.connessione:Disconnect()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	local umanoide = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if umanoide then
		camera.CameraSubject = umanoide
	end
	if subito then
		stato.gui:Destroy()
	else
		for _, oggetto in ipairs(stato.gui:GetDescendants()) do
			if oggetto:IsA("TextLabel") then
				TweenService:Create(oggetto, TweenInfo.new(0.35), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			elseif oggetto:IsA("Frame") then
				TweenService:Create(oggetto, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
			end
		end
		task.delay(0.4, function()
			stato.gui:Destroy()
		end)
	end
	if stato.fine then
		task.spawn(stato.fine)
	end
end

function Intermezzo.ferma()
	chiudi(true)
end

function Intermezzo.inCorso()
	return inCorso ~= nil
end

-- dati: la fase "round" del server (vittoria, round, vinti, persi, perVincere, finita, nemico, durata).
-- centro = centro del campo. fine = chiamata quando la cinematica finisce (anche se fermata).
function Intermezzo.riproduci(dati, centro, fine)
	chiudi(true)
	local durata = math.clamp(dati.durata or 5.5, 3, 7)
	local vincitore = dati.vittoria and "giocatore" or "nemico"
	local perdente = dati.vittoria and "nemico" or "giocatore"
	-- Il giocatore parte dalle righe basse, cioè verso -Z: il nemico sta verso +Z.
	local versoPerdente = Vector3.new(0, 0, perdente == "nemico" and 1 or -1)
	local da = Truppe.centro(vincitore) or (centro - versoPerdente * 24)
	local superstitiPerdenti = Truppe.centro(perdente)
	local verso = superstitiPerdenti or (da + versoPerdente * 40)
	local direzione = Vector3.new(verso.X - da.X, 0, verso.Z - da.Z)
	direzione = direzione.Magnitude > 1 and direzione.Unit or versoPerdente
	local lato = Vector3.new(-direzione.Z, 0, direzione.X)
	local partenza, arrivo
	if superstitiPerdenti then
		-- Da dietro i vincitori, verso chi ripiega.
		partenza = CFrame.lookAt(da - direzione * 30 + lato * 10 + Vector3.new(0, 18, 0), verso + Vector3.new(0, 2, 0))
		arrivo = CFrame.lookAt(da - direzione * 14 - lato * 4 + Vector3.new(0, 11, 0), verso + Vector3.new(0, 3, 0))
	else
		-- Del nemico non resta nessuno: i vincitori visti di fronte, dal campo dove stava.
		partenza = CFrame.lookAt(da + direzione * 34 + lato * 12 + Vector3.new(0, 16, 0), da + Vector3.new(0, 2, 0))
		arrivo = CFrame.lookAt(da + direzione * 18 - lato * 5 + Vector3.new(0, 8, 0), da + Vector3.new(0, 3, 0))
	end

	-- Livello con un boss: la scena è sua. Vivo in campo = primo piano con il nome e una sua frase; caduto =
	-- la telecamera sul punto dove è caduto; non ancora in campo (primo round) = si annuncia che arriva.
	local righeBoss
	local bossFermo -- il boss vivo in primo piano non ripiega con gli altri
	local def = dati.comandante and Epoche.Truppe[dati.comandante]
	if def then
		local boss = Truppe.soldato(dati.comandante, "nemico")
		local frasi = FRASI_BOSS[dati.comandante] or {}
		local nome = string.upper(def.nome)
		if boss and boss.vivo then
			local fronte = Vector3.new(math.sin(boss.angolo), 0, math.cos(boss.angolo))
			if fronte.Magnitude < 0.5 then
				fronte = -versoPerdente
			end
			local fianco = Vector3.new(-fronte.Z, 0, fronte.X)
			local testa = boss.posizione + Vector3.new(0, math.min(boss.altezza or 6, 9) * 0.8, 0)
			partenza = CFrame.lookAt(boss.posizione + fronte * 16 + fianco * 6 + Vector3.new(0, 7, 0), testa)
			arrivo = CFrame.lookAt(boss.posizione + fronte * 8 + fianco * 2.5 + Vector3.new(0, 4, 0), testa)
			righeBoss = { nome, "\"" .. ((dati.vittoria and frasi.perde) or (not dati.vittoria and frasi.vince) or "") .. "\"" }
			bossFermo = dati.comandante
		elseif boss then
			partenza = CFrame.lookAt(boss.posizione + Vector3.new(10, 22, 10), boss.posizione)
			arrivo = CFrame.lookAt(boss.posizione + Vector3.new(6, 12, 6), boss.posizione)
			righeBoss = { ("%s HAS FALLEN!"):format(nome), "The enemy army has lost its commander." }
		elseif not dati.finita then
			righeBoss = { ("%s TAKES THE FIELD!"):format(nome), "He will lead the next attack himself." }
		end
	end

	partenza = sopraTerreno(partenza)
	arrivo = sopraTerreno(arrivo)
	Truppe.ritirata(perdente, durata, bossFermo)

	local gui = Instance.new("ScreenGui")
	gui.Name = "Intermezzo"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.ResetOnSpawn = false
	for _, sopra in ipairs({ true, false }) do
		local banda = Instance.new("Frame")
		banda.AnchorPoint = Vector2.new(0, sopra and 1 or 0)
		banda.Position = UDim2.fromScale(0, sopra and 0 or 1)
		banda.Size = UDim2.fromScale(1, BANDA)
		banda.BackgroundColor3 = Color3.new(0, 0, 0)
		banda.BorderSizePixel = 0
		banda.ZIndex = 2
		banda.Parent = gui
		TweenService:Create(banda, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
			Position = UDim2.fromScale(0, sopra and BANDA or 1 - BANDA),
		}):Play()
	end
	gui.Parent = player:WaitForChild("PlayerGui")
	task.delay(0.35, function()
		if inCorso and inCorso.gui == gui then
			if righeBoss then
				-- Il nome del boss in oro, sotto la sua frase, poi l'esito del round più piccolo.
				local titolo = etichetta(gui, righeBoss[1], FONT, 0.07, 0.62, 0)
				titolo.TextColor3 = Color3.fromRGB(255, 214, 110)
				etichetta(gui, righeBoss[2], FONT_CORSIVO, 0.05, 0.7, 0)
				etichetta(gui, frase(dati), FONT, 0.04, 0.77, 0.1)
			else
				etichetta(gui, frase(dati), FONT, 0.075, 0.72, 0)
			end
			etichetta(gui, ("Round %d  ·  %d - %d"):format(dati.round or 1, dati.vinti or 0, dati.persi or 0), FONT_CORSIVO, 0.04, 0.8 + (righeBoss and 0.03 or 0), 0.15)
		end
	end)

	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = partenza
	local inizio = os.clock()
	local stato = { gui = gui, fine = fine }
	stato.connessione = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - inizio) / durata, 0, 1)
		local liscio = t * t * (3 - 2 * t)
		camera.CFrame = partenza:Lerp(arrivo, liscio)
		if t >= 1 and inCorso == stato then
			chiudi(false)
		end
	end)
	inCorso = stato
end

return Intermezzo
