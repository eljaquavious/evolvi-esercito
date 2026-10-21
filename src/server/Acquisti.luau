-- Acquisti in Robux (Developer Products). Roblox accetta UNA sola funzione ProcessReceipt per gioco:
-- qui c'è quella, e gli altri moduli registrano i loro prodotti con Acquisti.registra.
--
-- In Studio (modalità prova) i prodotti con id 0 non esistono ancora su Roblox: l'acquisto viene
-- regalato subito, così casse e pacchetti si possono collaudare prima di creare i prodotti.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prova = require(ReplicatedStorage.Shared.Prova)
local Dati = require(script.Parent.Dati)

local Acquisti = {}

local gestori = {} -- id del prodotto -> funzione(player) che dà quello che è stato comprato

-- Registra un prodotto: alla ricevuta viene chiamata dai(player); deve restituire true se ha dato tutto.
function Acquisti.registra(prodotto, dai)
	if prodotto and prodotto ~= 0 then
		gestori[prodotto] = dai
	end
end

-- Apre la finestra di Roblox per comprare il prodotto. In prova, con id 0, regala subito.
-- Restituisce ok, messaggio.
function Acquisti.chiedi(player, prodotto, dai)
	if not prodotto or prodotto == 0 then
		if Prova then
			task.spawn(dai, player)
			return true
		end
		return false, "Robux purchases are coming soon!"
	end
	gestori[prodotto] = gestori[prodotto] or dai
	MarketplaceService:PromptProductPurchase(player, prodotto)
	return true
end

-- Roblox può mandare di nuovo una ricevuta già consegnata: le ultime si ricordano nei dati del giocatore.
local MAX_RICEVUTE = 50

local function ricevuta(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local dai = gestori[info.ProductId]
	local dati = player and Dati.ottieni(player)
	if not dati or not dai then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	for _, id in ipairs(dati.ricevute) do
		if id == info.PurchaseId then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end
	local ok, dato = pcall(dai, player)
	if not ok or dato == false then
		warn("[Acquisti] Prodotto " .. info.ProductId .. " non consegnato: " .. tostring(dato))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Dati.modifica(player, function(d)
		table.insert(d.ricevute, info.PurchaseId)
		while #d.ricevute > MAX_RICEVUTE do
			table.remove(d.ricevute, 1)
		end
	end)
	-- Salva subito: se il server si spegne ora, l'acquisto non si perde.
	Dati.salva(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function Acquisti.inizializza()
	MarketplaceService.ProcessReceipt = ricevuta
end

return Acquisti
