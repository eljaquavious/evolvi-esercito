-- Casse dello shop. I contenuti arriveranno più avanti: finché disponibile = false
-- lo shop le mostra ma non le vende.
-- Quando si aggiungono contenuti casuali pagati con Robux (anche indirettamente),
-- Roblox obbliga a mostrare le probabilità di ogni oggetto prima dell'acquisto.

local Casse = {}

Casse.Lista = {
	{
		id = "CassaMedievale",
		nome = "Medieval Crate",
		descrizione = "Regiments and banners of the Middle Ages.",
		prezzo = 250,
		valuta = "Monete",
		colore = Color3.fromRGB(176, 128, 74),
		disponibile = false,
	},
	{
		id = "CassaNovecento",
		nome = "20th Century Crate",
		descrizione = "Regiments and vehicles of the 20th century.",
		prezzo = 500,
		valuta = "Monete",
		richiedeEpoca = "Novecento",
		colore = Color3.fromRGB(110, 124, 76),
		disponibile = false,
	},
	{
		id = "CassaLeggendaria",
		nome = "Legendary Crate",
		descrizione = "The rarest rewards from every era.",
		prezzo = 99,
		valuta = "Robux",
		colore = Color3.fromRGB(214, 170, 52),
		disponibile = false,
	},
}

function Casse.trova(id)
	for _, cassa in ipairs(Casse.Lista) do
		if cassa.id == id then
			return cassa
		end
	end
	return nil
end

return Casse
