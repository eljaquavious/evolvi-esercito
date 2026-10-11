-- Modelli 3D del paesaggio sui campi di battaglia: il server mette alberi, rocce e oggetti come parti
-- semplici dentro un Model con gli attributi Mesh, Scala e Posa (Server/Paesaggio); qui ognuno riceve la sua
-- mesh vera (Shared/MeshDati/Natura* e Ogg_*) e le vecchie parti si nascondono, solo su questo client
-- (tranne fuoco e vetri, segnati Resta).
-- Le parti nascoste restano: i tronchi continuano a fermare chi cammina. Se la mesh non si può fare,
-- restano visibili le parti.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Mesh = require(ReplicatedStorage.Shared.Mesh)

local Paesaggio = {}

-- Le cose piccole (erba, sassi, frecce) sono tante: niente ombre (non si vedrebbero e costano).
local OMBRA_DA = 2.5

local coda = {}
local inCorso = false

local function vesti(modello)
	local nome = modello:GetAttribute("Mesh")
	local scala = modello:GetAttribute("Scala") or 1
	local posa = modello:GetAttribute("Posa")
	if not nome or not posa or not modello.Parent or modello:FindFirstChild("Mesh") or not Mesh.disponibile(nome) then
		return
	end
	local parte, centro = Mesh.copia(nome, 1)
	if not parte or not modello.Parent then
		if parte then
			parte:Destroy()
		end
		return
	end
	parte.Name = "Mesh"
	parte.Anchored = true
	parte.CanCollide = false
	parte.CanQuery = false
	parte.CanTouch = false
	parte.Size *= scala
	parte.CFrame = posa * CFrame.new(centro * scala)
	local misura = parte.Size
	parte.CastShadow = math.max(misura.X, misura.Y, misura.Z) >= OMBRA_DA
	parte.Parent = modello
	local function nascondi(vecchia)
		if vecchia:IsA("BasePart") and vecchia ~= parte and not vecchia:GetAttribute("Resta") then
			vecchia.Transparency = 1
			vecchia.CastShadow = false
		end
	end
	for _, vecchia in ipairs(modello:GetDescendants()) do
		nascondi(vecchia)
	end
	-- Parti arrivate dopo (la replica non garantisce l'ordine).
	modello.DescendantAdded:Connect(nascondi)
end

-- I campi hanno migliaia di oggetti: si vestono a gruppi, senza bloccare il gioco.
local function svuota()
	if inCorso then
		return
	end
	inCorso = true
	task.spawn(function()
		local fatti = 0
		while #coda > 0 do
			local modello = table.remove(coda)
			local ok, errore = pcall(vesti, modello)
			if not ok then
				warn("[Paesaggio] " .. tostring(errore))
			end
			fatti += 1
			if fatti % 60 == 0 then
				task.wait()
			end
		end
		inCorso = false
	end)
end

local function forse(oggetto)
	if oggetto:IsA("Model") and oggetto:GetAttribute("Mesh") then
		table.insert(coda, oggetto)
		svuota()
	end
end

function Paesaggio.inizializza()
	local arene = workspace:WaitForChild("Arene")
	arene.DescendantAdded:Connect(forse)
	for _, oggetto in ipairs(arene:GetDescendants()) do
		forse(oggetto)
	end
end

return Paesaggio
