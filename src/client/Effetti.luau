-- Proiettili ed effetti della battaglia, solo sul client: frecce e pilum che volano ad arco e restano
-- piantati, pallottole traccianti con la vampata, granate del carro con l'esplosione, scintille e scritte.

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Effetti = {}

local cartella = Instance.new("Folder")
cartella.Name = "EffettiBattaglia"
cartella.Parent = workspace

local LEGNO = Color3.fromRGB(122, 84, 48)
local FERRO = Color3.fromRGB(150, 152, 158)
local PIUME = Color3.fromRGB(236, 230, 214)

local function parte(proprieta)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(proprieta) do
		p[k] = v
	end
	return p
end

-- Modello di un proiettile lungo l'asse -Z (la punta davanti).
local function asta(lunghezza, spessore, punta, piume)
	local modello = Instance.new("Model")
	local fusto = parte({ Size = Vector3.new(spessore, spessore, lunghezza), Color = LEGNO, Material = Enum.Material.Wood })
	fusto.Parent = modello
	modello.PrimaryPart = fusto
	local ferro = parte({ Size = Vector3.new(spessore * 2.4, spessore * 1.2, punta), Color = FERRO, Material = Enum.Material.Metal })
	ferro.CFrame = CFrame.new(0, 0, -lunghezza / 2 - punta / 2 + 0.05)
	ferro.Parent = modello
	if piume then
		local penne = parte({ Size = Vector3.new(spessore * 3, spessore * 0.3, 0.35), Color = PIUME })
		penne.CFrame = CFrame.new(0, 0, lunghezza / 2 - 0.25)
		penne.Parent = modello
		local penne2 = penne:Clone()
		penne2.CFrame = penne.CFrame * CFrame.Angles(0, 0, math.pi / 2)
		penne2.Parent = modello
	end
	return modello
end

-- Fa volare un modello da "da" ad "a" in "durata" secondi, ad arco alto "arco" studs, girato secondo la traiettoria.
-- Arrivato resta piantato per un po', poi sparisce.
local function vola(modello, da, a, durata, arco, piantato)
	modello.Parent = cartella
	local inizio = os.clock()
	local function posizione(t)
		local p = da:Lerp(a, t)
		return p + Vector3.new(0, arco * 4 * t * (1 - t), 0)
	end
	local connessione
	connessione = RunService.RenderStepped:Connect(function()
		local t = math.min(1, (os.clock() - inizio) / durata)
		local p = posizione(t)
		local dopo = posizione(math.min(1, t + 0.02))
		if (dopo - p).Magnitude < 1e-3 then
			dopo = p + (a - da).Unit * 0.1
		end
		modello:PivotTo(CFrame.lookAt(p, dopo))
		if t >= 1 then
			connessione:Disconnect()
			if piantato then
				-- Si pianta un po' nel terreno o nel bersaglio.
				modello:PivotTo(CFrame.lookAt(p, dopo) * CFrame.new(0, 0, -0.5))
				task.delay(2.5, function()
					for _, pezzo in ipairs(modello:GetChildren()) do
						TweenService:Create(pezzo, TweenInfo.new(0.6), { Transparency = 1 }):Play()
					end
				end)
				Debris:AddItem(modello, 3.2)
			else
				modello:Destroy()
			end
		end
	end)
end

function Effetti.freccia(da, a, durata)
	local distanza = (a - da).Magnitude
	vola(asta(2.2, 0.09, 0.3, true), da, a, durata, math.clamp(distanza * 0.18, 1.5, 14), true)
end

function Effetti.pilum(da, a, durata)
	local distanza = (a - da).Magnitude
	vola(asta(3.8, 0.13, 0.9, false), da, a, durata, math.clamp(distanza * 0.14, 1.5, 9), true)
end

local function vampata(posizione, colore, dimensione)
	local p = parte({ Size = Vector3.one * dimensione, Shape = Enum.PartType.Ball, Color = colore, Material = Enum.Material.Neon, Position = posizione })
	local luce = Instance.new("PointLight")
	luce.Color = colore
	luce.Range = 10
	luce.Brightness = 3
	luce.Parent = p
	p.Parent = cartella
	TweenService:Create(p, TweenInfo.new(0.08), { Size = Vector3.one * dimensione * 0.3, Transparency = 1 }):Play()
	Debris:AddItem(p, 0.12)
end

function Effetti.sparo(da, a, durata)
	vampata(da, Color3.fromRGB(255, 210, 120), 0.7)
	local traccia = parte({ Size = Vector3.new(0.08, 0.08, 2.4), Color = Color3.fromRGB(255, 226, 150), Material = Enum.Material.Neon })
	traccia.CFrame = CFrame.lookAt(da, a)
	traccia.Parent = cartella
	TweenService:Create(traccia, TweenInfo.new(math.max(0.05, durata), Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(a, a + (a - da)) }):Play()
	Debris:AddItem(traccia, math.max(0.05, durata) + 0.03)
end

function Effetti.esplosione(posizione)
	local e = Instance.new("Explosion")
	e.Position = posizione
	e.BlastRadius = 6
	e.BlastPressure = 0
	e.DestroyJointRadiusPercent = 0
	e.ExplosionType = Enum.ExplosionType.NoCraters
	e.Parent = cartella
	for _ = 1, 6 do
		local polvere = parte({ Size = Vector3.one * 2, Shape = Enum.PartType.Ball, Color = Color3.fromRGB(120, 104, 86), Material = Enum.Material.SmoothPlastic, Transparency = 0.2, Position = posizione })
		polvere.Parent = cartella
		local verso = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.2, math.random() - 0.5).Unit * 5
		TweenService:Create(polvere, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = posizione + verso, Size = Vector3.one * 4.5, Transparency = 1 }):Play()
		Debris:AddItem(polvere, 1)
	end
end

function Effetti.granata(da, a, durata)
	vampata(da, Color3.fromRGB(255, 180, 90), 1.6)
	local proiettile = parte({ Size = Vector3.new(0.4, 0.4, 1), Color = Color3.fromRGB(255, 170, 80), Material = Enum.Material.Neon })
	proiettile.Parent = cartella
	proiettile.CFrame = CFrame.lookAt(da, a)
	TweenService:Create(proiettile, TweenInfo.new(durata, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(a, a + (a - da)) }):Play()
	Debris:AddItem(proiettile, durata)
	task.delay(durata, Effetti.esplosione, a)
end

-- Scintille del metallo che sbatte (o schizzi di polvere).
function Effetti.scintille(posizione, colore)
	for _ = 1, 5 do
		local p = parte({ Size = Vector3.one * 0.18, Color = colore or Color3.fromRGB(255, 236, 190), Material = Enum.Material.Neon, Position = posizione })
		p.Parent = cartella
		local verso = Vector3.new(math.random() - 0.5, math.random() * 0.9, math.random() - 0.5).Unit * 1.8
		TweenService:Create(p, TweenInfo.new(0.22), { Position = posizione + verso, Transparency = 1 }):Play()
		Debris:AddItem(p, 0.25)
	end
end

function Effetti.scritta(posizione, testo, colore, grande)
	local ancora = parte({ Size = Vector3.one * 0.2, Transparency = 1, Position = posizione })
	ancora.Parent = cartella
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(grande and 160 or 60, grande and 40 or 22)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 250
	gui.Parent = ancora
	local etichetta = Instance.new("TextLabel")
	etichetta.Size = UDim2.fromScale(1, 1)
	etichetta.BackgroundTransparency = 1
	etichetta.Text = testo
	etichetta.TextColor3 = colore
	etichetta.TextScaled = true
	etichetta.Font = Enum.Font.LuckiestGuy
	etichetta.TextStrokeTransparency = 0.2
	etichetta.Parent = gui
	TweenService:Create(ancora, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = posizione + Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(etichetta, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(ancora, 1)
end

function Effetti.pulisci()
	cartella:ClearAllChildren()
end

return Effetti
