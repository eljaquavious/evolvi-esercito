-- Cielo e luce del client: il preset "lobby" (tramonto sulla cittadella) quando si è in lobby, il preset
-- "campo" (quello del server) quando si esce per la mappa o le battaglie. I preset sono in Config/Luci.
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

local function applica(nome, durata)
	if attuale == nome then
		return
	end
	attuale = nome
	for _, t in ipairs(tween) do
		t:Cancel()
	end
	table.clear(tween)
	for classe, proprieta in pairs(Luci[nome]) do
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

function Cielo.inLobby()
	return attuale == "lobby"
end

return Cielo
