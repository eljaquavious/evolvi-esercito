-- Forzieri 3D delle casse (Config/AssetForzieri): il server li carica in ReplicatedStorage.Forzieri (un Model per
-- cassa, con "Base" e "Coperchio"); qui si copiano e si apre il coperchio sulla cerniera.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetForzieri = require(ReplicatedStorage.Shared.Config.AssetForzieri)

local Forzieri = {}

local APERTO = math.rad(108) -- coperchio tutto aperto

-- Server: prepara il modello caricato (InsertService) e lo mette nella cartella.
function Forzieri.prepara(id, modello, cartella)
	local base = modello:FindFirstChild("Base", true)
	local coperchio = modello:FindFirstChild("Coperchio", true)
	local asset = AssetForzieri[id]
	if not (base and coperchio and asset) then
		return nil
	end
	local m = Instance.new("Model")
	m.Name = id
	for _, p in ipairs({ base, coperchio }) do
		p.Parent = m
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = true
		p.Material = Enum.Material.SmoothPlastic
		for _, figlio in ipairs(p:GetChildren()) do
			figlio:Destroy()
		end
	end
	-- L'importazione dell'FBX lascia il perno ruotato: lo si azzera, poi lo si mette a terra al centro.
	base.PivotOffset = CFrame.new()
	coperchio.PivotOffset = CFrame.new()
	m.PrimaryPart = base
	local cerniera = coperchio.CFrame * CFrame.new(coperchio.Size * asset.cerniera)
	m:SetAttribute("CoperchioRel", base.CFrame:ToObjectSpace(coperchio.CFrame))
	m:SetAttribute("CernieraRel", base.CFrame:ToObjectSpace(CFrame.new(cerniera.Position)))
	-- Il perno del modello a terra al centro, davanti verso -Z.
	local cf, misure = m:GetBoundingBox()
	base.PivotOffset = base.CFrame:ToObjectSpace(CFrame.new(cf.Position - Vector3.new(0, misure.Y / 2, 0)))
	modello:Destroy()
	m.Parent = cartella
	return m
end

-- Copia del forziere di una cassa, o nil se non c'è (non ancora caricato o cassa senza forziere).
function Forzieri.clona(id)
	local cartella = ReplicatedStorage:FindFirstChild("Forzieri")
	local m = cartella and cartella:FindFirstChild(id)
	return m and m:Clone() or nil
end

-- Aspetta che il forziere sia caricato (al massimo "attesa" secondi).
function Forzieri.aspetta(id, attesa)
	local cartella = ReplicatedStorage:WaitForChild("Forzieri", attesa or 5)
	return cartella and cartella:WaitForChild(id, attesa or 5)
end

-- Apre il coperchio: quanto = 0 chiuso, 1 aperto (si può andare oltre per il rimbalzo).
function Forzieri.apri(modello, quanto)
	local base = modello.PrimaryPart
	local coperchio = modello:FindFirstChild("Coperchio")
	local rel = modello:GetAttribute("CoperchioRel")
	local cerniera = modello:GetAttribute("CernieraRel")
	if not (base and coperchio and rel and cerniera) then
		return
	end
	coperchio.CFrame = base.CFrame * cerniera * CFrame.Angles(APERTO * quanto, 0, 0) * cerniera:Inverse() * rel
end

return Forzieri
