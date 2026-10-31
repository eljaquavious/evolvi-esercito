-- Mappa della campagna a pixel: l'Europa e il Mediterraneo fatti di piastrelle quadrate tutte alla stessa
-- altezza, un colore solo per la terra, su un mare piatto scuro con la cornice (Mattia, 31/10/2026: niente
-- cartina con i rilievi). Le piastrelle sono un modello fatto in Blender (Config/AssetMappa); i sentieri tra
-- le battaglie sono piastrelle di un tono più scuro. Costruita una volta all'avvio; i livelli e le tratte per
-- mare li disegna ogni client per conto suo (stelle diverse).

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MappaEuropa = require(ReplicatedStorage.Shared.Config.MappaEuropa)
local AssetMappa = require(ReplicatedStorage.Shared.Config.AssetMappa)
local Campagna = require(ReplicatedStorage.Shared.Config.Campagna)

local MappaCampagna = {}

local CELLA = MappaEuropa.CELLA

-- Dove aspetta il giocatore mentre guarda la mappa: dietro e sotto la telecamera, a sud della mappa.
MappaCampagna.ATTESA = MappaEuropa.CENTRO + Vector3.new(0, 30, -(MappaEuropa.RIGHE / 2) * CELLA - 80)

local function parte(modello, nome, misure, posizione, colore)
	local p = Instance.new("Part")
	p.Name = nome
	p.Anchored = true
	p.Size = misure
	p.Position = MappaEuropa.CENTRO + posizione
	p.Color = colore
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = modello
	return p
end

-- Mare piatto e cornice tutto attorno, con gli spigoli smussati da una fascia più bassa.
local function mareECornice(modello)
	local larghezza = MappaEuropa.COLONNE * CELLA
	local profondita = MappaEuropa.RIGHE * CELLA
	local mare = parte(modello, "Mare", Vector3.new(larghezza, 2, profondita), Vector3.new(0, -1, 0), AssetMappa.mare)
	mare.CanCollide = false
	local bordo, alto = 12, 2.4
	local function lato(misure, posizione)
		parte(modello, "Cornice", misure, posizione, AssetMappa.cornice)
		-- Fascia interna più bassa: il gradino tra mare e cornice non è uno spigolo vivo.
		local interna = misure.X > misure.Z and Vector3.new(misure.X, alto * 0.5, 2)
			or Vector3.new(2, alto * 0.5, misure.Z)
		local verso = (posizione * Vector3.new(1, 0, 1)).Unit
		parte(modello, "Cornice", interna, posizione - verso * (bordo / 2 + 1) - Vector3.new(0, alto * 0.25, 0),
			AssetMappa.cornice:Lerp(AssetMappa.mare, 0.5))
	end
	lato(Vector3.new(larghezza + bordo * 2, alto + 2, bordo), Vector3.new(0, alto / 2 - 1, profondita / 2 + bordo / 2))
	lato(Vector3.new(larghezza + bordo * 2, alto + 2, bordo), Vector3.new(0, alto / 2 - 1, -profondita / 2 - bordo / 2))
	lato(Vector3.new(bordo, alto + 2, profondita), Vector3.new(larghezza / 2 + bordo / 2, alto / 2 - 1, 0))
	lato(Vector3.new(bordo, alto + 2, profondita), Vector3.new(-larghezza / 2 - bordo / 2, alto / 2 - 1, 0))
	-- Piattaforma d'attesa del giocatore.
	local attesa = parte(modello, "Attesa", Vector3.new(12, 1, 12), MappaCampagna.ATTESA - MappaEuropa.CENTRO - Vector3.new(0, 3.5, 0),
		AssetMappa.cornice)
	attesa.Transparency = 1
end

-- Le piastrelle (modello di Blender): rimesse al loro posto con il pezzo di riferimento e colorate.
local function piastrelle(modello)
	local caricato
	for tentativo = 1, 4 do
		local ok, risultato = pcall(InsertService.LoadAsset, InsertService, AssetMappa.id)
		if ok and risultato then
			caricato = risultato
			break
		end
		warn(("[MappaCampagna] mappa non caricata (%d): %s"):format(tentativo, tostring(risultato)))
		task.wait(2)
	end
	if not caricato then
		return
	end
	local riferimento = caricato:FindFirstChild(AssetMappa.riferimento.nome, true)
	local spostamento = riferimento
			and (MappaEuropa.CENTRO + AssetMappa.riferimento.centro - riferimento.Position)
		or MappaEuropa.CENTRO
	for _, p in ipairs(caricato:GetDescendants()) do
		if p:IsA("MeshPart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.CastShadow = true
			p.Material = Enum.Material.SmoothPlastic
			p.Color = p.Name:find("^Sentiero") and AssetMappa.sentiero or AssetMappa.terra
			p.Position += spostamento
			p.Parent = modello
		end
	end
	caricato:Destroy()
end

-- Quota dei livelli per il client (ReplicatedStorage.AltezzeMappa, attributi L1, L2...): con le piastrelle
-- tutte alla stessa altezza basta il conto.
local function pubblicaAltezze()
	local altezze = Instance.new("Folder")
	altezze.Name = "AltezzeMappa"
	for numero, battaglia in ipairs(Campagna.Battaglie) do
		altezze:SetAttribute("L" .. numero, MappaEuropa.superficie(MappaEuropa.posizione(battaglia.lat, battaglia.lon)))
	end
	altezze.Parent = ReplicatedStorage
end

function MappaCampagna.costruisci()
	local modello = Instance.new("Model")
	modello.Name = "MappaCampagna"
	mareECornice(modello)
	modello.Parent = workspace
	pubblicaAltezze()
	piastrelle(modello)
	MappaCampagna.pronta = true
end

return MappaCampagna
