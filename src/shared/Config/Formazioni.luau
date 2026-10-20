-- Formazioni di schieramento: invece di piazzare i reggimenti casella per casella, il giocatore sceglie le
-- carte e una formazione storica, e i reggimenti prendono da soli il loro posto nella metà blu del campo.
-- Si sbloccano andando avanti nella campagna (sblocco = il livello che bisogna aver raggiunto).
-- I nomi e le descrizioni sono in inglese (si vedono nel gioco).
--
-- Ogni posto è { x, y, ruoli }: x = colonna (da 0.75 a 6.25), y = riga (da 0.75 a 2.35, più alto = più vicino
-- al nemico), ruoli in ordine di preferenza: F fanteria, C cavalleria, T tiratori, K comandanti.

local Campagna = require(script.Parent.Campagna)
local Epoche = require(script.Parent.Epoche)

local Formazioni = {}

local function p(x, y, ...)
	return { x = x, y = y, ruoli = { ... } }
end

Formazioni.Lista = {
	{
		id = "linea",
		nome = "Battle Line",
		descrizione = "The classic line: infantry in front, archers behind, cavalry on the wings.",
		sblocco = 1,
		posti = {
			p(3.5, 2.25, "F"), p(2.5, 2.25, "F"), p(4.5, 2.25, "F"), p(1.5, 2.25, "F"), p(5.5, 2.25, "F"),
			p(0.8, 1.9, "C"), p(6.2, 1.9, "C"),
			p(2.5, 1.25, "T"), p(4.5, 1.25, "T"), p(1.5, 1.2, "T"), p(5.5, 1.2, "T"),
			p(3.5, 1.25, "K", "T"),
		},
	},
	{
		id = "falange",
		nome = "Phalanx",
		descrizione = "Alexander's phalanx: a deep block of pikes in the centre, the cavalry hammer on the right.",
		sblocco = 2,
		posti = {
			p(3.0, 2.25, "F"), p(4.0, 2.25, "F"), p(3.0, 1.45, "F"), p(4.0, 1.45, "F"), p(2.0, 2.1, "F"),
			p(5.4, 2.2, "C"), p(6.2, 1.55, "C"), p(1.1, 2.0, "C"),
			p(4.9, 1.3, "K", "T"),
			p(2.0, 1.2, "T"), p(1.0, 1.15, "T"),
		},
	},
	{
		id = "triplex",
		nome = "Triplex Acies",
		descrizione = "Roman three lines in a checkerboard: hastati, principes and triarii take turns at the front.",
		sblocco = 3,
		posti = {
			p(2.0, 2.3, "F"), p(3.5, 2.3, "F"), p(5.0, 2.3, "F"), p(2.75, 1.55, "F"), p(4.25, 1.55, "F"), p(3.5, 0.85, "F"),
			p(0.8, 1.9, "C"), p(6.2, 1.9, "C"),
			p(4.8, 0.85, "K", "T"),
			p(1.3, 1.1, "T"), p(5.7, 1.1, "T"), p(2.2, 0.85, "T"),
		},
	},
	{
		id = "mezzaluna",
		nome = "Crescent",
		descrizione = "Hannibal's crescent at Cannae: the centre bulges out to draw the enemy in, the wings close around him.",
		sblocco = 4,
		posti = {
			p(3.5, 2.35, "F"), p(2.5, 2.05, "F"), p(4.5, 2.05, "F"), p(1.6, 1.6, "F"), p(5.4, 1.6, "F"),
			p(0.8, 2.3, "C"), p(6.2, 2.3, "C"),
			p(3.5, 1.25, "K", "T"),
			p(2.6, 1.0, "T"), p(4.4, 1.0, "T"),
		},
	},
	{
		id = "cuneo",
		nome = "Wedge",
		descrizione = "The boar's head: a wedge that drives through the enemy line, with heavy horsemen at the point.",
		sblocco = 7,
		posti = {
			p(3.5, 2.35, "F", "C"), -- la cavalleria, scelta per prima, la prende comunque
			p(2.7, 1.65, "F", "C"), p(4.3, 1.65, "F", "C"), p(1.9, 0.95, "F"), p(5.1, 0.95, "F"),
			p(3.5, 1.5, "K", "F"),
			p(1.0, 1.6, "T"), p(6.0, 1.6, "T"),
		},
	},
	{
		id = "muro",
		nome = "Shield Wall",
		descrizione = "The Saxon shield wall: one tight, unbroken line of shields, archers behind, horsemen in reserve.",
		sblocco = 9,
		posti = {
			p(3.5, 2.2, "F"), p(2.5, 2.2, "F"), p(4.5, 2.2, "F"), p(1.5, 2.2, "F"), p(5.5, 2.2, "F"),
			p(2.6, 1.3, "T"), p(4.4, 1.3, "T"),
			p(1.0, 1.15, "C"), p(6.0, 1.15, "C"),
			p(3.5, 0.85, "K", "T"),
		},
	},
	{
		id = "obliquo",
		nome = "Oblique Order",
		descrizione = "Epaminondas' oblique order: the strong right strikes first while the weak left hangs back.",
		sblocco = 11,
		posti = {
			p(5.6, 2.35, "F", "C"), p(4.6, 2.0, "F"), p(3.6, 1.65, "F"), p(2.6, 1.3, "F", "T"), p(1.6, 0.95, "F", "T"),
			p(6.2, 1.5, "C"),
			p(4.8, 1.1, "K", "T"),
			p(3.6, 0.8, "T"), p(0.8, 1.6, "T", "C"),
		},
	},
	-- Age of Gunpowder ---------------------------------------------------------------------------------------
	{
		id = "tercio",
		nome = "Tercio",
		descrizione = "The Spanish tercio: a great square of pikes in the centre, musketeers at its four corners.",
		sblocco = 13,
		posti = {
			p(2.9, 2.0, "F"), p(4.1, 2.0, "F"), p(3.5, 1.45, "F"), p(2.3, 1.35, "F"), p(4.7, 1.35, "F"),
			p(1.7, 2.3, "T"), p(5.3, 2.3, "T"), p(1.7, 0.8, "T"), p(5.3, 0.8, "T"),
			p(0.8, 1.6, "C"), p(6.2, 1.6, "C"),
			p(3.5, 0.75, "K", "T"),
		},
	},
	{
		id = "brigata",
		nome = "Swedish Brigade",
		descrizione = "Gustavus Adolphus' brigade: thin lines of pikes and muskets mixed together, horsemen with musket support.",
		sblocco = 14,
		posti = {
			p(3.5, 2.3, "F"), p(2.3, 2.3, "T", "F"), p(4.7, 2.3, "T", "F"), p(2.9, 1.6, "F"), p(4.1, 1.6, "F"),
			p(1.2, 2.0, "C"), p(5.8, 2.0, "C"), p(0.8, 1.3, "T", "C"), p(6.2, 1.3, "T", "C"),
			p(3.5, 0.85, "K", "T"),
			p(2.0, 1.0, "T"), p(5.0, 1.0, "T"),
		},
	},
	{
		id = "colonna",
		nome = "Attack Column",
		descrizione = "Napoleon's columns: skirmishers screen the front, deep columns of infantry punch through behind them.",
		sblocco = 16,
		posti = {
			p(2.0, 2.35, "T"), p(3.5, 2.35, "T"), p(5.0, 2.35, "T"),
			p(2.6, 1.7, "F"), p(4.4, 1.7, "F"), p(2.6, 1.0, "F"), p(4.4, 1.0, "F"),
			p(1.0, 1.4, "C"), p(6.0, 1.4, "C"),
			p(3.5, 0.85, "K", "F"),
		},
	},
	{
		id = "quadrato",
		nome = "Infantry Square",
		descrizione = "The square of Waterloo: infantry facing every side, guns and the general safe in the middle.",
		sblocco = 17,
		posti = {
			p(2.9, 2.35, "F"), p(4.1, 2.35, "F"), p(2.2, 1.55, "F"), p(4.8, 1.55, "F"), p(2.9, 0.8, "F"), p(4.1, 0.8, "F"),
			p(3.5, 1.55, "K", "T"),
			p(1.2, 2.2, "T"), p(5.8, 2.2, "T"),
			p(0.8, 1.0, "C"), p(6.2, 1.0, "C"),
		},
	},
	-- Twentieth century ---------------------------------------------------------------------------------------
	{
		id = "difesa",
		nome = "Defence in Depth",
		descrizione = "Great War defence in depth: machine guns up front, riflemen behind, tanks and reserves at the back.",
		sblocco = 19,
		posti = {
			p(3.5, 2.25, "T"), p(2.0, 2.25, "T"), p(5.0, 2.25, "T"),
			p(1.2, 1.5, "F"), p(2.75, 1.5, "F"), p(4.25, 1.5, "F"), p(5.8, 1.5, "F"),
			p(3.5, 0.8, "K", "C"),
			p(2.3, 0.8, "C"), p(4.7, 0.8, "C"),
		},
	},
	{
		id = "infiltrazione",
		nome = "Infiltration",
		descrizione = "Stormtrooper tactics: small assault groups spread wide and slip through the gaps, machine guns cover them.",
		sblocco = 21,
		posti = {
			p(1.2, 2.3, "F"), p(2.9, 2.3, "F"), p(4.6, 2.3, "F"), p(6.1, 2.2, "F"),
			p(2.0, 1.5, "T"), p(3.8, 1.5, "T"), p(5.4, 1.5, "T"),
			p(1.2, 1.0, "C", "F"), p(6.0, 1.0, "C", "F"),
			p(3.5, 0.85, "K", "T"),
		},
	},
	{
		id = "punta",
		nome = "Spearhead",
		descrizione = "Spearhead: armour massed at one point to break through, with the infantry following in its wake.",
		sblocco = 23,
		posti = {
			p(3.5, 2.35, "F", "C"), p(2.6, 2.0, "F", "C"), p(4.4, 2.0, "F", "C"),
			p(3.5, 1.5, "F"), p(2.0, 1.2, "F"), p(5.0, 1.2, "F"),
			p(1.0, 1.8, "T"), p(6.0, 1.8, "T"),
			p(3.5, 0.75, "K", "T"),
		},
	},
	{
		id = "tenaglia",
		nome = "Pincer",
		descrizione = "The Kesselschlacht: tanks on both wings race forward to encircle, the infantry holds the centre.",
		sblocco = 24,
		posti = {
			p(0.9, 2.3, "C"), p(6.1, 2.3, "C"), p(1.6, 1.7, "C", "F"), p(5.4, 1.7, "C", "F"),
			p(3.0, 1.6, "F"), p(4.0, 1.6, "F"), p(3.5, 2.1, "F"),
			p(2.6, 0.9, "T"), p(4.4, 0.9, "T"),
			p(3.5, 0.8, "K", "T"),
		},
	},
	-- Modern era ----------------------------------------------------------------------------------------------
	{
		id = "fuocoMovimento",
		nome = "Fire and Manoeuvre",
		descrizione = "One group pins the enemy with heavy fire while the other moves round the flank to strike.",
		sblocco = 25,
		posti = {
			p(1.6, 1.9, "T"), p(2.6, 1.9, "T"), p(2.1, 1.2, "T"),
			p(4.6, 2.3, "F"), p(5.6, 2.1, "F"), p(4.2, 1.6, "F"), p(3.4, 2.2, "F"),
			p(6.1, 1.4, "C"), p(5.2, 1.0, "C", "F"),
			p(3.3, 0.85, "K", "T"),
		},
	},
	{
		id = "riccio",
		nome = "Hedgehog",
		descrizione = "The perimeter of Khe Sanh: a ring of positions that holds from every side, armour at the centre.",
		sblocco = 26,
		posti = {
			p(3.5, 2.35, "F"), p(2.2, 1.95, "F"), p(4.8, 1.95, "F"), p(2.2, 1.0, "F"), p(4.8, 1.0, "F"),
			p(1.3, 1.5, "T"), p(5.7, 1.5, "T"), p(3.5, 0.8, "T"),
			p(3.0, 1.5, "C"), p(4.0, 1.5, "K", "C"),
		},
	},
}

Formazioni.perId = {}
for _, f in ipairs(Formazioni.Lista) do
	Formazioni.perId[f.id] = f
end
Formazioni.PREDEFINITA = "linea"

-- La formazione si può usare con il livello di campagna raggiunto?
function Formazioni.sbloccata(id, livelloRaggiunto)
	local f = Formazioni.perId[id]
	return f ~= nil and (livelloRaggiunto or 1) >= f.sblocco
end

-- Formazioni che si sbloccano esattamente al livello indicato (per festeggiarle).
function Formazioni.nuoveAl(livello)
	local lista = {}
	for _, f in ipairs(Formazioni.Lista) do
		if f.sblocco == livello then
			table.insert(lista, f)
		end
	end
	return lista
end

local function ruolo(def)
	if def.comandante then
		return "K"
	elseif def.classe == "Cavalleria" then
		return "C"
	elseif def.classe == "Tiratore" then
		return "T"
	end
	return "F"
end

local X_MIN, X_MAX = 0.75, Campagna.COLONNE + 0.25
local Y_MIN, Y_MAX = 0.75, Campagna.RIGHE_GIOCATORE + 0.35
local DISTANZA_MINIMA = 0.75
-- Spostamenti provati, in ordine, quando il posto della formazione cade su una casella dove non ci si schiera.
local SPOSTAMENTI = {
	{ 0.5, 0 }, { -0.5, 0 }, { 0, -0.5 }, { 0.5, -0.5 }, { -0.5, -0.5 }, { 1, 0 }, { -1, 0 }, { 0, 0.4 },
	{ 1, -0.6 }, { -1, -0.6 }, { 1.5, 0 }, { -1.5, 0 }, { 0, -1 }, { 2, 0 }, { -2, 0 },
}

-- Posti dei reggimenti: tipi = lista di tipi di carta, libero(x, y) = ci si può schierare lì.
-- Restituisce una lista parallela a tipi: { { x, y } }.
function Formazioni.disponi(id, tipi, libero)
	local f = Formazioni.perId[id] or Formazioni.perId[Formazioni.PREDEFINITA]
	local presi = {}
	local risultato = {}
	-- Prima i ruoli che hanno meno posti (comandanti, cavalleria, tiratori), poi la fanteria.
	local ordine = {}
	for i, tipo in ipairs(tipi) do
		table.insert(ordine, { i = i, ruolo = ruolo(Epoche.Truppe[tipo]) })
	end
	local priorita = { K = 1, C = 2, T = 3, F = 4 }
	table.sort(ordine, function(a, b)
		if priorita[a.ruolo] ~= priorita[b.ruolo] then
			return priorita[a.ruolo] < priorita[b.ruolo]
		end
		return a.i < b.i
	end)
	for _, r in ipairs(ordine) do
		local scelto, migliore = nil, math.huge
		for k, posto in ipairs(f.posti) do
			if not presi[k] then
				local indice = table.find(posto.ruoli, r.ruolo)
				-- Posto del suo ruolo (prima i preferiti, poi in ordine di lista), altrimenti un posto qualsiasi.
				local punteggio = (indice and (indice - 1) * 100 or 10000) + k
				if punteggio < migliore then
					scelto, migliore = k, punteggio
				end
			end
		end
		if scelto then
			presi[scelto] = true
			risultato[r.i] = { f.posti[scelto].x, f.posti[scelto].y }
		else
			risultato[r.i] = { 3.5, 1.2 }
		end
	end
	-- Posti su case, rottami o fiume: si cerca il punto libero più vicino lontano dagli altri reggimenti.
	local function lontano(x, y, escluso)
		for j, altro in ipairs(risultato) do
			if j ~= escluso and (altro[1] - x) ^ 2 + (altro[2] - y) ^ 2 < DISTANZA_MINIMA ^ 2 then
				return false
			end
		end
		return true
	end
	for i, pos in ipairs(risultato) do
		if not libero(pos[1], pos[2]) then
			for _, s in ipairs(SPOSTAMENTI) do
				local x = math.clamp(pos[1] + s[1], X_MIN, X_MAX)
				local y = math.clamp(pos[2] + s[2], Y_MIN, Y_MAX)
				if libero(x, y) and lontano(x, y, i) then
					risultato[i] = { x, y }
					break
				end
			end
		end
	end
	return risultato
end

return Formazioni
