-- Gioca tutti i livelli della campagna con il mazzo iniziale dell'epoca e confronta la simulazione
-- nuova (soldato per soldato) con quella vecchia (a reggimenti), se presente in /tmp/BattagliaVecchia.luau.
-- Si lancia con: lune run test/scansione
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function carica(percorso, ambiente)
	local sorgente = fs.readFile(percorso)
	return luau.load(sorgente, { debugName = percorso, environment = ambiente })()
end

local Color3 = { fromRGB = function() return {} end, new = function() return {} end }
-- Generatore deterministico al posto di Random (la sequenza non è quella di Roblox, ma è stabile).
local Random = {
	new = function(seme)
		local stato = math.floor(seme or 1) % 2147483647
		if stato <= 0 then stato += 2147483646 end
		local r = {}
		local function avanti()
			stato = (stato * 48271) % 2147483647
			return stato / 2147483647
		end
		function r:NextNumber(a, b)
			a, b = a or 0, b or 1
			return a + (b - a) * avanti()
		end
		function r:NextInteger(a, b)
			return math.min(b, a + math.floor((b - a + 1) * avanti()))
		end
		return r
	end,
}
local Epoche = carica("src/shared/Config/Epoche.luau", { Color3 = Color3 })
local Campagna = carica("src/shared/Config/Campagna.luau", {
	Color3 = Color3,
	Random = Random,
	script = { Parent = { Epoche = true } },
	require = function() return Epoche end,
})
local Nuova = require("../src/shared/Battaglia")
local Vecchia = fs.isFile("/tmp/BattagliaVecchia.luau") and carica("/tmp/BattagliaVecchia.luau", {}) or nil

local function schieramento(livello)
	local mazzo = livello.epoca.mazzoIniziale
	local posti = { { 2, 3 }, { 4, 3 }, { 3, 3 }, { 3, 1 }, { 4, 1 }, { 5, 2 }, { 1, 2 }, { 6, 3 } }
	local unita, i = {}, 0
	for _, tipo in ipairs(mazzo) do
		if i >= livello.maxReggimenti then
			break
		end
		-- Fanti davanti, tiratori dietro, cavalli ai lati.
		local def = Epoche.Truppe[tipo]
		local scelta
		for k, p in ipairs(posti) do
			local riga = p[2]
			local adatto = (def.classe == "Fanteria" and riga == 3) or (def.classe == "Tiratore" and riga == 1) or (def.classe == "Cavalleria" and riga == 2)
			if adatto and not Campagna.bloccata(livello, p[1], p[2]) then
				scelta = table.remove(posti, k)
				break
			end
		end
		if not scelta then
			for k, p in ipairs(posti) do
				if not Campagna.bloccata(livello, p[1], p[2]) then
					scelta = table.remove(posti, k)
					break
				end
			end
		end
		if scelta then
			i += 1
			table.insert(unita, { id = i, squadra = "giocatore", def = def, x = scelta[1], y = scelta[2] })
		end
	end
	return unita
end

local function gioca(Modulo, livello, round, assedio)
	local unita = schieramento(livello)
	for i, nemico in ipairs(Campagna.armata(livello, round, assedio)) do
		table.insert(unita, { id = 100 + i, squadra = "nemico", def = Epoche.Truppe[nemico.tipo], x = nemico.col, y = nemico.riga, forza = Campagna.forza(livello, round, nemico.tipo) })
	end
	local ostacoli, terreno = {}, {}
	for _, t in ipairs(livello.terreno) do
		if t.tipo == "ostacolo" then
			table.insert(ostacoli, { x = t.col, y = t.riga })
		elseif t.tipo == "fiume" or t.tipo == "collina" then
			terreno[t.col .. "," .. t.riga] = t.tipo
		end
	end
	local b = Modulo.nuova(unita, { colonne = 6, righe = 6, ostacoli = ostacoli, terreno = terreno })
	local inizio = os.clock()
	local vincitore = b:simula(0.075)
	return vincitore == "giocatore", b.tempo, os.clock() - inizio
end

local vinteN, vinteV, totale, cpuMax = 0, 0, 0, 0
for numero = 1, Campagna.TOTALE do
	local livello = Campagna.livello(numero)
	local riga = string.format("%2d %-16s", numero, livello.nome)
	for round = 1, 3 do
		local assedio = round == 3
		local vN, tN, cpu = gioca(Nuova, livello, round, assedio)
		cpuMax = math.max(cpuMax, cpu / (tN / 0.075))
		totale += 1
		if vN then vinteN += 1 end
		riga ..= string.format("  N:%s %4.1fs", vN and "W" or "l", tN)
		if Vecchia then
			local vV, tV = gioca(Vecchia, livello, round, assedio)
			if vV then vinteV += 1 end
			riga ..= string.format(" V:%s %4.1fs", vV and "W" or "l", tV)
		end
	end
	print(riga)
end
print(string.format("vinti nuova %d/%d, vecchia %d/%d; passo più lento %.2f ms", vinteN, totale, vinteV, totale, cpuMax * 1000))
