-- Shop: casse delle truppe, casse dei cosmetici e pacchetti di monete.
-- Da ogni cassa esce UNA sola cosa (Mattia, 21/10/2026).
--
-- Casse delle truppe: esce sempre un reggimento. "nuova" = probabilità che sia una carta che non hai;
-- altrimenti è una copia di una carta che hai già (le copie servono: nel mazzo si mettono più copie).
-- La Big dà sempre una carta nuova. "pesi" = probabilità della rarità (Shared/Config/Carte.rarita):
-- bronze Antichità, silver Medioevo e Polvere, gold Novecento ed Era Moderna, legend i comandanti.
--
-- Casse dei cosmetici: cosmetici che si trovano SOLO qui (Ricompense.Cosmetici con cassa = true),
-- mai un doppione. "pesi" = probabilità della rarità del cosmetico.
--
-- Robux: prodotto = id del Developer Product (Creator Dashboard > il gioco > Monetization > Developer Products);
-- 0 finché non è creato. In Studio (modalità prova) gli acquisti in Robux con prodotto 0 vengono regalati,
-- per collaudare. Roblox obbliga a mostrare le probabilità prima dell'acquisto: lo shop le mostra.

local Casse = {}

Casse.Truppe = {
	{
		id = "CassaPiccola",
		nome = "Small Crate",
		descrizione = "One regiment from any era. Often a copy of one you already have.",
		monete = 200,
		nuova = 0.35,
		pesi = { bronze = 60, silver = 30, gold = 10, legend = 0 },
		icona = "crate_small",
		colore = Color3.fromRGB(196, 140, 84), -- piedistallo nella lobby
		pal = "verde",
	},
	{
		id = "CassaMedia",
		nome = "Medium Crate",
		descrizione = "One regiment, with a better chance of a new one.",
		monete = 750,
		nuova = 0.65,
		pesi = { bronze = 38, silver = 37, gold = 25, legend = 0 },
		icona = "crate_medium",
		colore = Color3.fromRGB(60, 130, 230), -- piedistallo nella lobby
		pal = "blu",
	},
	{
		id = "CassaGrande",
		nome = "Big Crate",
		descrizione = "A NEW regiment, guaranteed. Commanders can drop!",
		robux = { prezzo = 99, prodotto = 0 },
		nuova = 1,
		pesi = { bronze = 20, silver = 36, gold = 40, legend = 4 },
		icona = "crate_big",
		colore = Color3.fromRGB(214, 60, 70), -- piedistallo nella lobby
		pal = "oro",
	},
}

Casse.Cosmetici = {
	{
		id = "ArmeriaPiccola",
		nome = "Small Armory Crate",
		descrizione = "One crate-only cosmetic. Never a duplicate.",
		monete = 600,
		pesi = { comune = 70, raro = 24, epico = 5, leggendario = 1 },
		icona = "chest_small",
		colore = Color3.fromRGB(40, 200, 210), -- piedistallo nella lobby
		pal = "acqua",
	},
	{
		id = "ArmeriaMedia",
		nome = "Medium Armory Crate",
		descrizione = "Better odds of epic and legendary gear.",
		-- Ogni cosa costa almeno 80 R$, circa 1 euro (Mattia, 24/10/2026).
		robux = { prezzo = 89, prodotto = 0 },
		pesi = { comune = 35, raro = 38, epico = 21, leggendario = 6 },
		icona = "chest_medium",
		colore = Color3.fromRGB(150, 70, 230), -- piedistallo nella lobby
		pal = "viola",
	},
	{
		id = "ArmeriaGrande",
		nome = "Big Armory Crate",
		descrizione = "No commons. The best shot at legendary gear.",
		robux = { prezzo = 149, prodotto = 0 },
		pesi = { comune = 0, raro = 40, epico = 42, leggendario = 18 },
		icona = "chest_big",
		colore = Color3.fromRGB(255, 70, 200), -- piedistallo nella lobby
		pal = "rosa",
	},
}

-- Pacchetti di monete (solo Robux). Il più piccolo costa 80 R$ (circa 1 euro, il minimo voluto da Mattia);
-- più grande è il pacchetto, più monete per ogni Robux (da 12,5 a 22).
Casse.Monete = {
	{ id = "Monete1", monete = 1000, robux = { prezzo = 80, prodotto = 0 }, icona = "coins_1" },
	{ id = "Monete2", monete = 2500, robux = { prezzo = 169, prodotto = 0 }, icona = "coins_2" },
	{ id = "Monete3", monete = 6000, robux = { prezzo = 369, prodotto = 0 }, icona = "coins_3" },
	{ id = "Monete4", monete = 10000, robux = { prezzo = 599, prodotto = 0 }, icona = "coins_4" },
	{ id = "Monete5", monete = 15000, robux = { prezzo = 799, prodotto = 0 }, icona = "coins_5" },
	{ id = "Monete6", monete = 40000, robux = { prezzo = 1799, prodotto = 0 }, icona = "coins_6", migliore = true },
}

local indice = {}
for _, gruppo in ipairs({ { Casse.Truppe, "truppe" }, { Casse.Cosmetici, "cosmetici" }, { Casse.Monete, "monete" } }) do
	for _, voce in ipairs(gruppo[1]) do
		indice[voce.id] = { voce = voce, tipo = gruppo[2] }
	end
end

-- id -> voce, tipo ("truppe", "cosmetici", "monete").
function Casse.trova(id)
	local v = indice[id]
	if v then
		return v.voce, v.tipo
	end
	return nil
end

-- Pesi -> probabilità (0-1) che sommano a 1, solo per le chiavi con peso > 0.
function Casse.probabilita(pesi)
	local totale = 0
	for _, p in pairs(pesi) do
		totale += p
	end
	local risultato = {}
	for k, p in pairs(pesi) do
		if p > 0 then
			risultato[k] = p / totale
		end
	end
	return risultato
end

-- Percentuale da mostrare: "35%", "2.5%", "0.4%".
function Casse.percentuale(p)
	local x = p * 100
	if x >= 10 or math.abs(x - math.floor(x + 0.5)) < 0.05 then
		return ("%d%%"):format(math.floor(x + 0.5))
	end
	return ("%.1f%%"):format(x)
end

return Casse
