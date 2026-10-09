-- Test della simulazione di battaglia. Si lancia con: lune run test/battaglia
local Battaglia = require("../src/shared/Battaglia")

local SPADACCINO = { id = "Spadaccino", classe = "Fanteria", hp = 130, danno = 14, cadenza = 1, gittata = 1.1, velocita = 1.4 }
local ARCIERE = { id = "Arciere", classe = "Tiratore", hp = 70, danno = 11, cadenza = 0.9, gittata = 4.5, velocita = 1.2 }
local CAVALIERE = { id = "Cavaliere", classe = "Cavalleria", hp = 140, danno = 16, cadenza = 0.8, gittata = 1.2, velocita = 2.6 }

local falliti = 0
local function verifica(nome, condizione)
	print((condizione and "OK   " or "FAIL ") .. nome)
	if not condizione then
		falliti += 1
	end
end

verifica("la fanteria batte la cavalleria", Battaglia.moltiplicatore("Fanteria", "Cavalleria") > 1)
verifica("la cavalleria soffre la fanteria", Battaglia.moltiplicatore("Cavalleria", "Fanteria") < 1)
verifica("stessa classe: danno normale", Battaglia.moltiplicatore("Tiratore", "Tiratore") == 1)

local b = Battaglia.nuova({
	{ id = 1, squadra = "giocatore", def = SPADACCINO, x = 4, y = 3 },
	{ id = 101, squadra = "nemico", def = SPADACCINO, x = 5, y = 6 },
})
b:simula(0.1)
verifica("uno contro uno finisce", b.finita and b.vincitore ~= nil)

b = Battaglia.nuova({
	{ id = 1, squadra = "giocatore", def = CAVALIERE, x = 4, y = 3 },
	{ id = 2, squadra = "giocatore", def = CAVALIERE, x = 5, y = 3 },
	{ id = 101, squadra = "nemico", def = ARCIERE, x = 4, y = 8 },
	{ id = 102, squadra = "nemico", def = ARCIERE, x = 5, y = 8 },
})
verifica("due cavalieri battono due arcieri", b:simula(0.1) == "giocatore")

b = Battaglia.nuova({
	{ id = 1, squadra = "giocatore", def = ARCIERE, x = 1, y = 1 },
})
b:passo(0.1)
verifica("senza nemici vince chi resta", b.finita and b.vincitore == "giocatore")

print(falliti == 0 and "Tutti i test passati" or (falliti .. " test falliti"))
