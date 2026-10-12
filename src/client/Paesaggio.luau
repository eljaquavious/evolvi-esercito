-- Modelli 3D del paesaggio sui campi di battaglia: il server mette alberi, rocce e oggetti come parti
-- semplici dentro un Model con gli attributi Mesh, Scala e Posa (Server/Paesaggio); qui ognuno riceve la sua
-- mesh vera (Shared/MeshDati/Natura* e Ogg_*) e le vecchie parti si nascondono, solo su questo client
-- (tranne fuoco e vetri, segnati Resta).
-- Le parti nascoste restano: i tronchi continuano a fermare chi cammina. Se la mesh non si può fare,
-- restano visibili le parti.

local ContentProvider = game:GetService("ContentProvider")
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

-- Modelli fotografici (SurfaceAppearance PBR clonate dal server): se una texture non arriva (errore di rete
-- "NetFail" al primo caricamento) il modello resta bianco. Ogni texture si precarica una volta; se fallisce si
-- ritenta e, appena arriva, le SurfaceAppearance che la usano si sostituiscono con una copia (che la ricarica).
local MAPPE = { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" }
local TENTATIVI = 4

local statoTexture = {} -- id -> "carico" | "ok"
local chiUsa = {} -- id -> { SurfaceAppearance = true }

local function rinfresca(id)
	local lista = chiUsa[id]
	chiUsa[id] = nil
	for sa in pairs(lista or {}) do
		if sa.Parent then
			local copia = sa:Clone()
			copia.Parent = sa.Parent
			sa:Destroy()
		end
	end
end

local function precarica(id)
	statoTexture[id] = "carico"
	task.spawn(function()
		local fallito = false
		for tentativo = 1, TENTATIVI do
			local esito
			pcall(ContentProvider.PreloadAsync, ContentProvider, { id }, function(_, stato)
				esito = stato
			end)
			if esito == Enum.AssetFetchStatus.Success then
				statoTexture[id] = "ok"
				if fallito then
					rinfresca(id)
				end
				chiUsa[id] = nil
				return
			end
			fallito = true
			task.wait(2 ^ tentativo)
		end
		statoTexture[id] = nil -- il prossimo modello che la usa ritenta
		chiUsa[id] = nil
	end)
end

local function guardaTexture(sa)
	for _, mappa in ipairs(MAPPE) do
		local ok, id = pcall(function()
			return sa[mappa]
		end)
		if ok and type(id) == "string" and id ~= "" then
			local stato = statoTexture[id]
			if stato ~= "ok" then
				chiUsa[id] = chiUsa[id] or {}
				chiUsa[id][sa] = true
				if stato == nil then
					precarica(id)
				end
			end
		end
	end
end

function Paesaggio.inizializza()
	local arene = workspace:WaitForChild("Arene")
	arene.DescendantAdded:Connect(function(oggetto)
		forse(oggetto)
		if oggetto:IsA("SurfaceAppearance") then
			guardaTexture(oggetto)
		end
	end)
	for _, oggetto in ipairs(arene:GetDescendants()) do
		forse(oggetto)
		if oggetto:IsA("SurfaceAppearance") then
			guardaTexture(oggetto)
		end
	end
end

return Paesaggio
