-- Preferiti di Roblox: alla fine di un livello vinto il gioco chiede di metterlo nei Preferiti (una volta
-- per sessione) e chi lo fa riceve il titolo "Loyal Ally" e la "Loyal Aura" (Config/Ricompense, condizione
-- "preferito"). Chi lo aveva già nei Preferiti li riceve appena entra.
-- In Studio, con il place non pubblicato (PlaceId 0), la finestra di Roblox non può comparire.

local AvatarEditorService = game:GetService("AvatarEditorService")

local Notifiche = require(script.Parent.Notifiche)
local Stile = require(script.Parent.Stile)

local Preferiti = {}

local remoti
local giaPreferito = false -- dai dati del server
local chiestoOra = false -- una sola richiesta per sessione

local function avvisaServer()
	if giaPreferito then
		return
	end
	local ok, nuovo = pcall(function()
		return remoti.Preferito:InvokeServer()
	end)
	if ok and nuovo then
		giaPreferito = true
	end
end

-- Il gioco è nei Preferiti? nil se non si può sapere.
local function nelPreferiti()
	if game.PlaceId == 0 then
		return nil
	end
	local ok, risposta = pcall(function()
		return AvatarEditorService:GetFavorite(game.PlaceId, Enum.AvatarItemType.Asset)
	end)
	return ok and risposta or nil
end

-- Apre la finestra di Roblox per aggiungere il gioco ai Preferiti.
function Preferiti.chiedi()
	if giaPreferito or game.PlaceId == 0 then
		return
	end
	pcall(function()
		AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
	end)
end

-- Fine di un livello vinto: se il gioco non è ancora nei Preferiti, lo chiede (una volta per sessione).
function Preferiti.dopoVittoria()
	if giaPreferito or chiestoOra or game.PlaceId == 0 then
		return
	end
	chiestoOra = true
	task.delay(2.5, function()
		if nelPreferiti() then
			avvisaServer()
			return
		end
		Notifiche.mostra("Enjoying the war? Add the game to your Favorites and get the LOYAL ALLY title + LOYAL AURA!", Stile.Colori.Oro)
		Preferiti.chiedi()
	end)
end

function Preferiti.inizializza(r)
	remoti = r
	remoti.Stato.OnClientEvent:Connect(function(stato)
		giaPreferito = stato and stato.preferito or false
	end)
	AvatarEditorService.PromptSetFavoriteCompleted:Connect(function(_, _, esito)
		if esito == Enum.AvatarPromptResult.Success then
			avvisaServer()
		end
	end)
	-- Chi aveva già il gioco nei Preferiti riceve subito i premi.
	task.delay(5, function()
		local stato = remoti.ChiediStato:InvokeServer()
		giaPreferito = stato and stato.preferito or false
		if not giaPreferito and nelPreferiti() then
			avvisaServer()
		end
	end)
end

return Preferiti
