-- Cielo e luce del client: il preset "lobby" (tramonto sulla cittadella) quando si è in lobby, il preset
-- "campo" (quello del server) sulla mappa, e in battaglia il campo con il meteo del livello. I preset sono
-- in Config/Luci.
-- Mappa e Partita salvano e ripristinano qualche valore dell'atmosfera: prima di farlo chiamano
-- Cielo.campo(), così salvano sempre i valori del campo e non quelli della lobby.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Luci = require(ReplicatedStorage.Shared:WaitForChild("Config"):WaitForChild("Luci"))

local Cielo = {}

local attuale = nil
local tween = {}

local function oggetti(classe)
	if classe == "Lighting" then
		return Lighting
	elseif classe == "Clouds" then
		return workspace.Terrain:FindFirstChildOfClass("Clouds")
	end
	return Lighting:FindFirstChildOfClass(classe)
end

local function applica(nome, durata, preset)
	if attuale == nome then
		return
	end
	attuale = nome
	for _, t in ipairs(tween) do
		t:Cancel()
	end
	table.clear(tween)
	for classe, proprieta in pairs(preset or Luci[nome]) do
		local oggetto = oggetti(classe)
		if oggetto then
			local animabili = {}
			for k, v in pairs(proprieta) do
				if durata and durata > 0 and typeof(v) ~= "boolean" then
					animabili[k] = v
				else
					oggetto[k] = v
				end
			end
			if next(animabili) then
				local t = TweenService:Create(oggetto, TweenInfo.new(durata, Enum.EasingStyle.Sine), animabili)
				t:Play()
				table.insert(tween, t)
			end
		end
	end
end

-- Subito, senza transizione: chi lo chiama sta per leggere o cambiare l'atmosfera.
function Cielo.campo()
	applica("campo")
end

function Cielo.lobby(durata)
	applica("lobby", durata)
end

-- Cielo di una battaglia: il preset "campo" con il colore dell'aria del bioma e sopra il meteo del livello
-- (Luci.meteo). Restituisce le particelle del meteo (pioggia, neve) o nil.
function Cielo.battaglia(meteo, coloreBioma)
	local extra = Luci.meteo[meteo] or {}
	local preset = {}
	for classe, proprieta in pairs(Luci.campo) do
		preset[classe] = table.clone(proprieta)
	end
	if coloreBioma then
		preset.Atmosphere.Color = coloreBioma
		preset.Atmosphere.Decay = coloreBioma:Lerp(Color3.new(0, 0, 0), 0.3)
	end
	for classe, proprieta in pairs(extra) do
		if type(proprieta) == "table" and preset[classe] then
			for k, v in pairs(proprieta) do
				preset[classe][k] = v
			end
		end
	end
	applica("battaglia:" .. tostring(meteo) .. ":" .. tostring(coloreBioma), nil, preset)
	return extra.particelle
end

function Cielo.inLobby()
	return attuale == "lobby"
end

return Cielo
