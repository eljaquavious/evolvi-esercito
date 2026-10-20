-- Mantelli che si muovono, tutto lato client: il telo del cosmetico Mantello (Cosmetici3D) è saldato al
-- busto con un Weld per fascia; qui ogni fascia ruota attorno alla sua cerniera, all'indietro quando il
-- personaggio corre o cade e con un leggero ondeggiare da fermo. Le fasce sono a catena: quella sotto
-- segue quella sopra e si apre un po' di più.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Impostazioni = require(script.Parent.UI.Impostazioni)

local Mantelli = {}

local DISTANZA = 120 -- oltre questa distanza dalla telecamera i mantelli restano fermi
local VELOCITA_PIENA = 34 -- a questa velocità il mantello è tutto sollevato
local SOLLEVATO = { math.rad(28), math.rad(16), math.rad(12) } -- apertura massima di ogni fascia
local ONDA = math.rad(2.5)
local PRONTEZZA = 6 -- quanto in fretta il telo insegue la posizione voluta

local stati = {} -- modello -> { sollevato, fase }

local function ruotaAttorno(punto, angolo)
	-- Il telo pende verso +Z (la schiena): un angolo negativo attorno a X lo porta indietro e in alto.
	return CFrame.new(punto) * CFrame.Angles(-angolo, 0, 0) * CFrame.new(-punto)
end

local function aggiornaMantello(modello, radice, dt, tempo)
	local stato = stati[modello]
	if not stato then
		stato = { sollevato = 0, fase = math.random() * math.pi * 2, saldature = {} }
		for _, p in ipairs(modello:GetDescendants()) do
			local fascia = p:IsA("BasePart") and p:GetAttribute("Fascia")
			local weld = fascia and p:FindFirstChild("Telo")
			if weld and weld:IsA("Weld") and weld:GetAttribute("Base") then
				table.insert(stato.saldature, { weld = weld, fascia = fascia, base = weld:GetAttribute("Base") })
			end
		end
		stati[modello] = stato
	end
	local v = radice.AssemblyLinearVelocity
	local orizzontale = Vector3.new(v.X, 0, v.Z)
	-- Corre in avanti o di lato: il telo vola indietro; all'indietro il vento lo spinge sul corpo, quindi poco.
	local avanti = orizzontale:Dot(radice.CFrame.LookVector)
	local spinta = math.max(avanti, orizzontale.Magnitude * 0.4) + math.max(-v.Y, 0) * 0.5
	local voluto = math.clamp(spinta / VELOCITA_PIENA, 0, 1)
	stato.sollevato += (voluto - stato.sollevato) * math.min(1, dt * PRONTEZZA)

	local catena = CFrame.identity
	local trasformazioni = {}
	for i = 1, #SOLLEVATO do
		local punto = modello:GetAttribute("Cerniera" .. i)
		if not punto then
			break
		end
		local onda = ONDA * (1 + math.sin(tempo * (1.6 + i * 0.35) + stato.fase - i * 0.7)) * 0.5 * i
		catena = catena * ruotaAttorno(punto, SOLLEVATO[i] * stato.sollevato + onda)
		trasformazioni[i] = catena
	end
	for _, s in ipairs(stato.saldature) do
		local t = trasformazioni[s.fascia]
		if t then
			s.weld.C0 = t * s.base
		end
	end
end

function Mantelli.inizializza()
	RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		local tempo = os.clock()
		local visti = {}
		for _, giocatore in ipairs(Players:GetPlayers()) do
			local personaggio = giocatore.Character
			local radice = personaggio and personaggio:FindFirstChild("HumanoidRootPart")
			local cartella = personaggio and personaggio:FindFirstChild("Cosmetici")
			local modello = cartella and cartella:FindFirstChild("Mantello")
			if modello and radice and camera and not Impostazioni.prestazioni() and (radice.Position - camera.CFrame.Position).Magnitude < DISTANZA then
				visti[modello] = true
				aggiornaMantello(modello, radice, dt, tempo)
			end
		end
		for modello in pairs(stati) do
			if not visti[modello] and not modello.Parent then
				stati[modello] = nil
			end
		end
	end)
end

return Mantelli
