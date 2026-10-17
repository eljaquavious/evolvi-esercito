-- Test della simulazione di battaglia. Si lancia con: lune run test/battaglia
-- I reggimenti sono copiati da src/shared/Config/Epoche.luau (che usa Color3 e quindi non gira fuori da Roblox).
local Battaglia = require("../src/shared/Battaglia")

local SPADACCINO = { id = "Spadaccino", soldati = 8, classe = "Fanteria", hp = 420, danno = 30, cadenza = 1.0, gittata = 1.1, velocita = 1.0, armatura = 0.25 }
local ARCIERE = { id = "Arciere", soldati = 8, classe = "Tiratore", hp = 230, danno = 27, cadenza = 0.8, gittata = 3.6, velocita = 0.9, armatura = 0.05 }
local CAVALIERE = { id = "Cavaliere", soldati = 5, classe = "Cavalleria", hp = 430, danno = 34, cadenza = 0.8, gittata = 1.2, velocita = 2.0, armatura = 0.2, carica = 2.2 }
local CARRO = { id = "CarroArmato", soldati = 1, classe = "Cavalleria", hp = 1150, danno = 105, cadenza = 0.45, gittata = 3.0, velocita = 1.0, armatura = 0.45, area = 0.4 }

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
local cariche, caricheDi = 0, {}
for _ = 1, 400 do
	for _, evento in ipairs(b:passo(0.1)) do
		if evento.tipo == "attacco" and evento.carica then
			cariche += 1
			caricheDi[evento.da] = (caricheDi[evento.da] or 0) + 1
		end
	end
	if b.finita then
		break
	end
end
local doppie = false
for _, n in pairs(caricheDi) do
	doppie = doppie or n > 1
end
verifica("i cavalieri caricano, ognuno una volta sola", cariche > 0 and not doppie)

-- Danno ad area: il carro colpisce anche i reggimenti vicini al bersaglio.
b = Battaglia.nuova({
	{ id = 1, squadra = "giocatore", def = CARRO, x = 3, y = 2 },
	{ id = 101, squadra = "nemico", def = SPADACCINO, x = 3, y = 5 },
	{ id = 102, squadra = "nemico", def = SPADACCINO, x = 4, y = 5 },
})
local colpiAdArea = 0
for _ = 1, 400 do
	for _, evento in ipairs(b:passo(0.1)) do
		if evento.tipo == "colpo" and evento.da == 17 then
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
	for _, u in ipairs(b.soldati) do
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
	for _ = 1, 30 do
		b:passo(0.1)
	end
	return 1 - Battaglia.vitaReggimento(b.unita[1])
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
local fortezza = b.unita[2].soldati[1]
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
b.unita[3].soldati[1].danno = 0
for _ = 1, 60 do
	b:passo(0.075)
end
local arrivati = 0
for _, s in ipairs(b.unita[1].soldati) do
	if b:_inGittata(s, b.unita[3].soldati[1]) then
		arrivati += 1
	end
end
verifica("chi è bloccato da un alleato arriva comunque alla fortezza", arrivati >= 3)

-- Due ostacoli in diagonale chiudono il passaggio (stallo visto a Thermopylae): i reggimenti li aggirano.
b = Battaglia.nuova({
	{ id = 1, squadra = "giocatore", def = SPADACCINO, x = 1.94, y = 3.06 },
	{ id = 2, squadra = "giocatore", def = SPADACCINO, x = 1.94, y = 3.06 },
	{ id = 101, squadra = "nemico", def = SPADACCINO, x = 1.06, y = 3.94 },
}, { ostacoli = { { x = 1, y = 3 }, { x = 2, y = 4 } } })
b:simula(0.075)
verifica("i reggimenti aggirano gli ostacoli in diagonale", b.vincitore == "giocatore" and b.tempo < 40)

-- Un muro di ostacoli con un solo varco: si passa dal varco.
b = Battaglia.nuova({
	{ id = 1, squadra = "giocatore", def = CAVALIERE, x = 1, y = 1 },
	{ id = 101, squadra = "nemico", def = ARCIERE, x = 1, y = 6 },
}, { ostacoli = { { x = 1, y = 3 }, { x = 2, y = 3 }, { x = 3, y = 3 }, { x = 4, y = 3 }, { x = 5, y = 3 } } })
b:simula(0.075)
verifica("si passa dal varco nel muro", b.vincitore == "giocatore" and b.tempo < 30)

-- Ogni soldato si muove per conto suo: i soldati di un reggimento non restano in formazione rigida.
b = Battaglia.nuova({
	{ id = 1, squadra = "giocatore", def = SPADACCINO, x = 2, y = 2 },
	{ id = 101, squadra = "nemico", def = SPADACCINO, x = 2, y = 5 },
	{ id = 102, squadra = "nemico", def = SPADACCINO, x = 5, y = 5 },
})
for _ = 1, 40 do
	b:passo(0.1)
end
local bersagli = {}
for _, s in ipairs(b.unita[1].soldati) do
	if s.bersaglio then
		bersagli[s.bersaglio.id] = true
	end
end
local diversi = 0
for _ in pairs(bersagli) do
	diversi += 1
end
verifica("i soldati scelgono bersagli diversi", diversi >= 3)

-- Nessuno si compenetra.
local sovrapposti = 0
for i, a in ipairs(b.soldati) do
	for j = i + 1, #b.soldati do
		local c = b.soldati[j]
		if a.vivo and c.vivo and math.sqrt((a.x - c.x) ^ 2 + (a.y - c.y) ^ 2) < (a.raggio + c.raggio) * 0.8 then
			sovrapposti += 1
		end
	end
end
verifica("i soldati non si compenetrano", sovrapposti == 0)

-- Le frecce arrivano dopo il tiro, non nello stesso istante.
b = Battaglia.nuova({
	{ id = 1, squadra = "giocatore", def = ARCIERE, x = 3, y = 1 },
	{ id = 101, squadra = "nemico", def = SPADACCINO, x = 3, y = 4 },
})
local tiri, colpiSubito = 0, 0
for _ = 1, 20 do
	for _, evento in ipairs(b:passo(0.1)) do
		if evento.tipo == "attacco" and evento.colpo == "tiro" then
			tiri += 1
			if evento.ritardo <= 0.1 then
				colpiSubito += 1
			end
		end
	end
end
verifica("gli arcieri tirano frecce che volano", tiri > 0 and colpiSubito == 0)

-- Il pilum: ogni legionario lo lancia una volta prima della mischia.
local LEGIONARI = table.clone(SPADACCINO)
LEGIONARI.id = "Legionario"
LEGIONARI.lancio = { gittata = 2.2, danno = 1.6 }
b = Battaglia.nuova({
	{ id = 1, squadra = "giocatore", def = LEGIONARI, x = 3, y = 1 },
	{ id = 101, squadra = "nemico", def = SPADACCINO, x = 3, y = 5 },
})
local lanci = {}
for _ = 1, 300 do
	for _, evento in ipairs(b:passo(0.1)) do
		if evento.tipo == "attacco" and evento.colpo == "lancio" then
			lanci[evento.da] = (lanci[evento.da] or 0) + 1
		end
	end
	if b.finita then
		break
	end
end
local lanciatori, ripetuti = 0, false
for _, n in pairs(lanci) do
	lanciatori += 1
	ripetuti = ripetuti or n > 1
end
verifica("i legionari lanciano il pilum una volta", lanciatori >= 4 and not ripetuti)

-- Ordini generali all'armata.
b = Battaglia.nuova({
	{ id = 1, squadra = "giocatore", def = SPADACCINO, x = 3, y = 2 },
	{ id = 101, squadra = "nemico", def = SPADACCINO, x = 3, y = 6 },
})
verifica("un ordine sconosciuto non vale", not b:ordine("giocatore", "balla"))
verifica("tenere la linea si può ordinare", b:ordine("giocatore", "tieni"))
verifica("tra due ordini serve una pausa", not b:ordine("giocatore", "avanza"))
local partenza = b.perReggimento[1].soldati[1].y
for _ = 1, 20 do
	b:passo(0.1)
end
verifica("chi tiene la linea non avanza", math.abs(b.perReggimento[1].soldati[1].y - partenza) < 0.05)

b = Battaglia.nuova({
	{ id = 1, squadra = "giocatore", def = SPADACCINO, x = 3, y = 2.4 },
	{ id = 101, squadra = "nemico", def = SPADACCINO, x = 3, y = 6 },
})
verifica("si può ripiegare", b:ordine("giocatore", "ripiega"))
for _ = 1, 30 do
	b:passo(0.1)
end
verifica("chi ripiega va indietro", b.perReggimento[1].soldati[1].y < 1.6)
for _ = 1, 50 do
	b:passo(0.1)
end
verifica("finita la ritirata si tiene la linea", b.ordini.giocatore == "tieni")

b = Battaglia.nuova({
	{ id = 1, squadra = "giocatore", def = CAVALIERE, x = 3, y = 1 },
	{ id = 101, squadra = "nemico", def = SPADACCINO, x = 3, y = 4 },
	{ id = 102, squadra = "nemico", def = ARCIERE, x = 5, y = 6 },
})
b:ordine("giocatore", "fianchi")
local primoBersaglio
for _ = 1, 200 do
	for _, evento in ipairs(b:passo(0.1)) do
		if evento.tipo == "attacco" and evento.da // 16 == 1 and not primoBersaglio then
			primoBersaglio = evento.a // 16
		end
	end
end
verifica("con l'aggiramento la cavalleria cerca i tiratori", primoBersaglio == 102)

b = Battaglia.nuova({
	{ id = 1, squadra = "giocatore", def = CAVALIERE, x = 3, y = 1 },
	{ id = 101, squadra = "nemico", def = SPADACCINO, x = 3, y = 6 },
})
verifica("la carica generale si ordina", b:ordine("giocatore", "carica"))
for _ = 1, 65 do
	b:passo(0.1)
end
verifica("finita la carica si torna ad avanzare", b.ordini.giocatore == "avanza")
verifica("la carica si suona una volta per round", not b:ordine("giocatore", "carica"))

-- Abilità dei comandanti: una volta sola, bonus doppio per chi è della stessa origine.
local CESARE = { id = "Cesare", soldati = 1, classe = "Fanteria", comandante = true, origine = "Rome", hp = 700, danno = 36, cadenza = 1, gittata = 1.2, velocita = 1, armatura = 0.35, abilita = { nome = "Veni, Vidi, Vici", danno = 0.2, durata = 8 } }
local ROMANI = table.clone(SPADACCINO)
ROMANI.origine = "Rome"
b = Battaglia.nuova({
	{ id = 1, squadra = "giocatore", def = CESARE, x = 1, y = 1 },
	{ id = 2, squadra = "giocatore", def = ROMANI, x = 2, y = 1 },
	{ id = 3, squadra = "giocatore", def = SPADACCINO, x = 3, y = 1 },
	{ id = 101, squadra = "nemico", def = SPADACCINO, x = 3, y = 6 },
})
verifica("l'abilità si attiva", b:attivaAbilita(1))
verifica("l'abilità si usa una volta", not b:attivaAbilita(1))
verifica("solo i comandanti hanno abilità", not b:attivaAbilita(2))
local romano, altro = b.perReggimento[2].soldati[1], b.perReggimento[3].soldati[1]
verifica("stessa origine: bonus doppio", math.abs(b:_bonus(romano, "danno") - 0.4) < 1e-6 and math.abs(b:_bonus(altro, "danno") - 0.2) < 1e-6)
local eventoAbilita = false
for _, evento in ipairs(b:passo(0.1)) do
	eventoAbilita = eventoAbilita or evento.tipo == "abilita"
end
verifica("l'abilità arriva al client come evento", eventoAbilita)
for _ = 1, 90 do
	b:passo(0.1)
end
verifica("l'abilità finisce", b:_bonus(romano, "danno") == 0)

print(falliti == 0 and "Tutti i test passati" or (falliti .. " test falliti"))
