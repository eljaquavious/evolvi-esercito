-- Carica all'avvio i modelli delle truppe caricati come asset (Config/AssetTruppe) e li mette in
-- ReplicatedStorage.ModelliTruppe, uno per tipo (la MeshPart con le ossa), pronti da copiare (Shared/Modelli).
-- InsertService può caricare solo asset del proprietario del gioco: i modelli sono dell'account di Mattia.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetTruppe = require(ReplicatedStorage.Shared.Config.AssetTruppe)

local ModelliAsset = {}

local TENTATIVI = 3

local function prepara(tipo, modello)
	local parte = modello:FindFirstChildWhichIsA("MeshPart", true)
	if not parte then
		return nil
	end
	parte.Parent = nil
	modello:Destroy()
	-- Le pose dell'importazione e l'AnimationController non servono: le ossa le muove Client/Animatore.
	for _, figlio in ipairs(parte:GetChildren()) do
		if not figlio:IsA("Bone") then
			figlio:Destroy()
		end
	end
	parte.Name = tipo
	parte.Anchored = false
	parte.CanCollide = false
	parte.CanQuery = false
	parte.CanTouch = false
	parte.Massless = true
	parte.CastShadow = true
	-- Opaco come i modelli fatti a runtime (la SmoothPlastic luccica).
	parte.Material = Enum.Material.Fabric
	return parte
end

function ModelliAsset.carica()
	local cartella = Instance.new("Folder")
	cartella.Name = "ModelliTruppe"
	cartella.Parent = ReplicatedStorage
	for tipo, asset in pairs(AssetTruppe) do
		task.spawn(function()
			for tentativo = 1, TENTATIVI do
				local ok, modello = pcall(InsertService.LoadAsset, InsertService, asset.id)
				if ok and modello then
					local parte = prepara(tipo, modello)
					if parte then
						parte.Parent = cartella
						return
					end
				end
				if tentativo == TENTATIVI then
					warn(("[ModelliAsset] %s (%d) non caricato: %s"):format(tipo, asset.id, tostring(modello)))
				end
				task.wait(1)
			end
		end)
	end
end

return ModelliAsset
