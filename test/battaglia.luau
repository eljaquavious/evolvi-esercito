-- Test della simulazione di battaglia. Si lancia con: lune run test/battaglia
-- I reggimenti sono copiati da src/shared/Config/Epoche.luau (che usa Color3 e quindi non gira fuori da Roblox).
local Battaglia = require("../src/shared/Battaglia")

local SPADACCINO = { id = "Spadaccino", classe = "Fanteria", hp = 420, danno = 30, cadenza = 1.0, gittata = 1.1, velocita = 1.0, armatura = 0.25 }
local ARCIERE = { id = "Arciere", classe = "Tiratore", hp = 230, danno = 27, cadenza = 0.8, gittata = 3.6, velocita = 0.9, armatura = 0.05 }
local CAVALIERE = { id = "Cavaliere", classe = "Cavalleria", hp = 430, danno = 34, cadenza = 0.8, gittata = 1.2, velocita = 2.0, armatura = 0.2, carica = 2.2 }
local CARRO = { id = "CarroArmato", classe = "Cavalleria", hp = 1150, danno = 105, cadenza = 0.45, gittata = 3.0, velocita = 1.0, armatura = 0.45, area = 0.4 }

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
	{ id = 1, squadra = "giocatore", def = SPADACCINO, x = 3, y = 2 },
	{ id = 101, squadra = "nemico", def = SPADACCINO, x = 4, y = 5 },
})
b:simula(0.1)
verifica("uno contro uno finisce", b.finita and b.vincitore ~= nil)

b = Battaglia.nuova({
	{ id = 1, squadra = "giocatore", def = CAVALIERE, x = 3, y = 2 },
	{ id = 2, squadra = "giocatore", def = CAVALIERE, x = 4, y = 2 },
	{ id = 101, squadra = "nemico", def = ARCIERE, x = 3, y = 6 },
	{ id = 102, squadra = "nemico", def = ARCIERE, x = 4, y = 6 },
})
verifica("due cavalieri battono due arcieri", b:simula(0.1) == "giocatore")

b = Battaglia.nuova({
	{ id = 1, squadra = "giocatore", def = SPADACCINO, x = 3, y = 2 },
	{ id = 101, squadra = "nemico", def = CAVALIERE, x = 3, y = 5 },
})
verifica("gli spadaccini reggono la carica dei cavalieri", b:simula(0.1) == "giocatore")

-- La carica: il primo colpo in mischia dei cavalieri è moltiplicato.
b = Battaglia.nuova({
	{ id = 1, squadra = "giocatore", def = CAVALIERE, x = 3, y = 2 },
	{ id = 101, squadra = "nemico", def = ARCIERE, x = 3, y = 5 },
})
local cariche = 0
for _ = 1, 400 do
	for _, evento in ipairs(b:passo(0.1)) do
		if evento.tipo == "attacco" and evento.carica then
			cariche += 1
		end
	end
	if b.finita then
		break
	end
end
verifica("i cavalieri caricano una volta sola", cariche == 1)

-- Danno ad area: il carro colpisce anche i reggimenti vicini al bersaglio.
b = Battaglia.nuova({
	{ id = 1, squadra = "giocatore", def = CARRO, x = 3, y = 2 },
	{ id = 101, squadra = "nemico", def = SPADACCINO, x = 3, y = 5 },
	{ id = 102, squadra = "nemico", def = SPADACCINO, x = 4, y = 5 },
})
local colpiAdArea = 0
for _ = 1, 400 do
	for _, evento in ipairs(b:passo(0.1)) do
		if evento.tipo == "attacco" and evento.da == 1 then
			colpiAdArea += #evento.area
		end
	end
	if b.finita then
		break
	end
end
verifica("il carro fa danno ad area", colpiAdArea > 0)

-- Gli ostacoli non si attraversano: nessun reggimento finisce dentro una casella bloccata.
b = Battaglia.nuova({
	{ id = 1, squadra = "giocatore", def = SPADACCINO, x = 3, y = 2 },
	{ id = 101, squadra = "nemico", def = SPADACCINO, x = 3, y = 5 },
}, { ostacoli = { { x = 3, y = 3.5 } } })
local dentro = false
for _ = 1, 600 do
	b:passo(0.1)
	for _, u in ipairs(b.unita) do
		local dx, dy = u.x - 3, u.y - 3.5
		if u.vivo and math.sqrt(dx * dx + dy * dy) < 0.5 then
			dentro = true
		end
	end
	if b.finita then
		break
	end
end
verifica("gli ostacoli vengono aggirati", not dentro and b.finita)

b = Battaglia.nuova({
	{ id = 1, squadra = "giocatore", def = ARCIERE, x = 1, y = 1 },
})
b:passo(0.1)
verifica("senza nemici vince chi resta", b.finita and b.vincitore == "giocatore")

-- Terreno: il fiume rallenta, la collina allunga il tiro dei tiratori.
b = Battaglia.nuova({ { id = 1, squadra = "giocatore", def = SPADACCINO, x = 3, y = 3 } }, { terreno = { ["3,3"] = "fiume", ["4,4"] = "collina" } })
local fante = b.unita[1]
verifica("il fiume rallenta", (b:_terrenoSotto(fante).velocita or 1) < 1)
local arciere = { def = ARCIERE, x = 4, y = 4 }
verifica("la collina allunga il tiro degli arcieri", b:_gittata(arciere) > ARCIERE.gittata)
verifica("la collina non allunga la mischia", b:_gittata({ def = SPADACCINO, x = 4, y = 4 }) == SPADACCINO.gittata)

-- Testuggine: i legionari prendono meno danno dalle frecce.
local function dannoSubito(def)
	b = Battaglia.nuova({
		{ id = 1, squadra = "giocatore", def = def, x = 3, y = 1 },
		{ id = 101, squadra = "nemico", def = ARCIERE, x = 3, y = 4 },
	})
	local prima = b.unita[1].hp
	for _ = 1, 30 do
		b:passo(0.1)
	end
	return prima - b.unita[1].hp
end
local LEGIONARIO = table.clone(SPADACCINO)
LEGIONARIO.velocita = 0
local TESTUGGINE = table.clone(LEGIONARIO)
TESTUGGINE.testuggine = 0.7
verifica("la testuggine riduce il danno a distanza", dannoSubito(TESTUGGINE) < dannoSubito(LEGIONARIO))

-- Aura: un comandante vicino aumenta il danno degli alleati.
local COMANDANTE = { id = "Cesare", classe = "Fanteria", hp = 700, danno = 36, cadenza = 1, gittata = 1.1, velocita = 1, armatura = 0.3, aura = 0.15, comandante = true }
b = Battaglia.nuova({
	{ id = 1, squadra = "giocatore", def = SPADACCINO, x = 3, y = 2 },
	{ id = 2, squadra = "giocatore", def = COMANDANTE, x = 4, y = 2 },
	{ id = 3, squadra = "giocatore", def = SPADACCINO, x = 1, y = 6 },
})
verifica("l'aura del comandante vale vicino", b:_aura(b.unita[1]) > 1)
verifica("l'aura non arriva lontano", b:_aura(b.unita[3]) == 1)

-- Fortezza: non si muove mai.
local FORTEZZA = { id = "FortezzaMedievale", classe = "Fortezza", hp = 1500, danno = 38, cadenza = 0.7, gittata = 4.4, velocita = 0, armatura = 0.4, fortezza = true }
b = Battaglia.nuova({
	{ id = 1, squadra = "giocatore", def = CAVALIERE, x = 3, y = 1 },
	{ id = 101, squadra = "nemico", def = FORTEZZA, x = 3, y = 6 },
})
local fortezza = b.unita[2]
local mossa = false
for _ = 1, 600 do
	b:passo(0.1)
	if fortezza.x ~= 3 or fortezza.y ~= 6 then
		mossa = true
	end
	if b.finita then
		break
	end
end
verifica("la fortezza resta ferma", not mossa)

-- Un reggimento chiuso tra il bordo e un alleato che sta già combattendo non resta fermo: gli sfila accanto.
b = Battaglia.nuova({
	{ id = 1, squadra = "giocatore", def = SPADACCINO, x = 2.8, y = 6 },
	{ id = 2, squadra = "giocatore", def = SPADACCINO, x = 3.22, y = 5.24 },
	{ id = 101, squadra = "nemico", def = table.clone(FORTEZZA), x = 4, y = 6, forza = 20 },
})
b.unita[3].danno = 0
for _ = 1, 40 do
	b:passo(0.075)
end
verifica("chi è bloccato da un alleato arriva comunque alla fortezza", b:_inGittata(b.unita[1], b.unita[3]))

print(falliti == 0 and "Tutti i test passati" or (falliti .. " test falliti"))
