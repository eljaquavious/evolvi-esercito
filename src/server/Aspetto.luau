-- Aspetto dei giocatori: i cosmetici indossati e la targhetta con nome e titolo sopra la testa.
-- Funziona su qualsiasi avatar (R15 o R6) e in qualsiasi lobby: si aggancia al personaggio, non al mondo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Ricompense)
local Cosmetici3D = require(ReplicatedStorage.Shared.Cosmetici3D)
local Progressi = require(ReplicatedStorage.Shared.Config.Progressi)

local Aspetto = {}

local CARTELLA = "Cosmetici"
local ATTRIBUTO = "NascostoDaCosmetico" -- sugli accessori dell'avatar coperti da un cosmetico

-- Accessori dell'avatar che un cosmetico copre: cappelli e capelli sotto l'elmo, zaini sotto lo scudo...
local COPERTI = {
	Testa = { [Enum.AccessoryType.Hat] = true, [Enum.AccessoryType.Hair] = true },
	Corpo = {
		[Enum.AccessoryType.Front] = true,
		[Enum.AccessoryType.Neck] = true,
		[Enum.AccessoryType.Waist] = true,
		[Enum.AccessoryType.Shoulder] = true,
	},
	Schiena = { [Enum.AccessoryType.Back] = true },
}

local function nascondiAccessori(personaggio, slotOccupati)
	for _, accessorio in ipairs(personaggio:GetChildren()) do
		if accessorio:IsA("Accessory") then
			local maniglia = accessorio:FindFirstChild("Handle")
			if maniglia and maniglia:IsA("BasePart") then
				-- Sotto i copricapi i capelli non si vedono (scelta di Mattia); solo la corona d'alloro
				-- (lasciaCapelli) li lascia vedere, perché è una ghirlanda e la testa sembrava pelata (20/10/2026).
				local coperto = false
				for slot, cosmetico in pairs(slotOccupati) do
					local tipi = COPERTI[slot]
					local capelliLiberi = cosmetico.lasciaCapelli and accessorio.AccessoryType == Enum.AccessoryType.Hair
					if tipi and tipi[accessorio.AccessoryType] and not capelliLiberi then
						coperto = true
					end
				end
				local nascosto = accessorio:GetAttribute(ATTRIBUTO)
				if coperto and nascosto == nil then
					accessorio:SetAttribute(ATTRIBUTO, maniglia.Transparency)
					maniglia.Transparency = 1
				elseif not coperto and nascosto ~= nil then
					maniglia.Transparency = nascosto
					accessorio:SetAttribute(ATTRIBUTO, nil)
				end
			end
		end
	end
end

local function scritta(genitore, testo, posizione, altezza, colore, font)
	local etichetta = Instance.new("TextLabel")
	etichetta.BackgroundTransparency = 1
	etichetta.Position = posizione
	etichetta.Size = UDim2.fromScale(1, altezza)
	etichetta.Text = testo
	etichetta.TextScaled = true
	etichetta.FontFace = font
	etichetta.TextColor3 = colore
	local bordo = Instance.new("UIStroke")
	bordo.Color = Color3.fromHex("#1B1636")
	bordo.Thickness = 2.5
	bordo.Parent = etichetta
	etichetta.Parent = genitore
	return etichetta
end

-- Targhetta sopra la testa: livello e nome in bianco, titolo sotto nel colore della sua rarità.
local function targhetta(player, personaggio, idTitolo, livello)
	local testa = personaggio:FindFirstChild("Head")
	if not testa then
		return
	end
	local umanoide = personaggio:FindFirstChildOfClass("Humanoid")
	if umanoide then
		umanoide.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local gui = testa:FindFirstChild("Targhetta")
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "Targhetta"
		gui.Size = UDim2.fromScale(7, 1.7)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 3.9, 0) -- sopra elmi e stendardi
		gui.MaxDistance = 80
		gui.LightInfluence = 0
		gui.ResetOnSpawn = false
		scritta(gui, player.DisplayName, UDim2.fromScale(0, 0), 0.56, Color3.new(1, 1, 1), Font.fromEnum(Enum.Font.FredokaOne)).Name = "Nome"
		scritta(gui, "", UDim2.fromScale(0, 0.58), 0.42, Color3.new(1, 1, 1), Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Heavy)).Name = "Titolo"
		gui.Parent = testa
	end
	-- Livello del giocatore in oro prima del nome.
	local nome = gui:FindFirstChild("Nome")
	nome.RichText = true
	nome.Text = ('<font color="#FFD23F">Lv.%d</font>  %s'):format(livello or 1, player.DisplayName)
	local titolo = Config.titolo(idTitolo) or Config.titolo(Config.TITOLO_INIZIALE)
	-- Il titolo compare anche accanto al nome nella chat (Client/Chat legge questi attributi).
	player:SetAttribute("Titolo", titolo.nome)
	player:SetAttribute("TitoloColore", Config.Rarita[titolo.rarita].colore)
	player:SetAttribute("Livello", livello or 1)
	local etichetta = gui:FindFirstChild("Titolo")
	etichetta.Text = "« " .. string.upper(titolo.nome) .. " »"
	etichetta.TextColor3 = Color3.fromHex(Config.Rarita[titolo.rarita].colore)
end

local ultimo = {} -- player -> { personaggio, firma }: per non rivestire il personaggio a ogni moneta guadagnata

-- Rimette addosso al personaggio i cosmetici indossati e aggiorna la targhetta.
-- Si può chiamare a ogni cambio dei dati: se titolo e cosmetici sono gli stessi non fa niente.
-- forza: veste anche se l'avatar non risulta ancora caricato (dopo l'attesa di nuovoPersonaggio).
function Aspetto.aggiorna(player, dati, forza)
	local personaggio = player.Character
	-- Finché l'avatar non è caricato le parti del corpo possono ancora essere sostituite:
	-- ci pensa nuovoPersonaggio, appena è pronto.
	if not personaggio or not dati or not personaggio:FindFirstChild("Head") or not (forza or player:HasAppearanceLoaded()) then
		return
	end
	local livello = Progressi.livello(dati.esperienza or 0)
	local firma = tostring(dati.titolo) .. "|" .. livello
	for _, slot in ipairs(Config.Slot) do
		firma ..= "|" .. tostring(dati.indossati[slot.id])
	end
	local prima = ultimo[player]
	if prima and prima.personaggio == personaggio and prima.firma == firma then
		return
	end
	ultimo[player] = { personaggio = personaggio, firma = firma }
	local cartella = personaggio:FindFirstChild(CARTELLA)
	if cartella then
		cartella:Destroy()
	end
	cartella = Instance.new("Folder")
	cartella.Name = CARTELLA
	local occupati = {}
	for _, slot in ipairs(Config.Slot) do
		local id = dati.indossati[slot.id]
		if id and dati.cosmetici[id] and Config.cosmetico(id) then
			local modello = Cosmetici3D.indossa(personaggio, id, slot.id)
			if modello then
				modello.Parent = cartella
				occupati[slot.id] = Config.cosmetico(id)
			end
		end
	end
	cartella.Parent = personaggio
	nascondiAccessori(personaggio, occupati)
	targhetta(player, personaggio, dati.titolo, livello)
end

-- ottieniDati: funzione player -> dati (Dati.ottieni), così questo modulo non dipende da Dati.
function Aspetto.inizializza(ottieniDati)
	local function nuovoPersonaggio(player, personaggio)
		-- Aspetta che l'avatar abbia testa, busto e accessori, poi veste il personaggio.
		personaggio:WaitForChild("Head", 10)
		local inizio = os.clock()
		while not player:HasAppearanceLoaded() and os.clock() - inizio < 6 do
			task.wait(0.1)
		end
		task.wait(0.2)
		if player.Character == personaggio then
			ultimo[player] = nil
			Aspetto.aggiorna(player, ottieniDati(player), true)
		end
	end
	local function entrato(player)
		player.CharacterAdded:Connect(function(personaggio)
			nuovoPersonaggio(player, personaggio)
		end)
		if player.Character then
			task.spawn(nuovoPersonaggio, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(entrato)
	Players.PlayerRemoving:Connect(function(player)
		ultimo[player] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		entrato(player)
	end
end

return Aspetto
