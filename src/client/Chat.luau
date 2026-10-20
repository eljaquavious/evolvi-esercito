-- Chat: accanto al nome di chi scrive compare il suo titolo, nel colore della rarità (come sulla targhetta).
-- Il server mette titolo e colore negli attributi del giocatore (Server/Aspetto).

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local Chat = {}

local function sicuro(testo)
	return (string.gsub(testo, "[<>&]", { ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;" }))
end

function Chat.inizializza()
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		return
	end
	TextChatService.OnIncomingMessage = function(messaggio)
		local fonte = messaggio.TextSource
		local player = fonte and Players:GetPlayerByUserId(fonte.UserId)
		local titolo = player and player:GetAttribute("Titolo")
		if not titolo then
			return nil
		end
		local colore = player:GetAttribute("TitoloColore") or "#FFFFFF"
		local proprieta = Instance.new("TextChatMessageProperties")
		proprieta.PrefixText = ('<font color="%s">[%s]</font> %s'):format(colore, sicuro(titolo), messaggio.PrefixText)
		return proprieta
	end
end

return Chat
