-- Simulazione della battaglia automatica tra reggimenti, a passi di tempo fissi.
-- Non usa API di Roblox: gira uguale sul server e nei test.
-- Le posizioni sono in caselle: x = colonna, y = riga. Il giocatore parte dalle righe basse.

local Battaglia = {}
Battaglia.__index = Battaglia

-- Ogni classe batte quella indicata e perde contro quella che la batte.
Battaglia.BATTE = {
	Fanteria = "Cavalleria",
	Cavalleria = "Tiratore",
	Tiratore = "Fanteria",
}
Battaglia.BONUS = 1.5
Battaglia.MALUS = 0.75
Battaglia.DURATA_MASSIMA = 90
-- I tiratori presi in mischia colpiscono a metà.
Battaglia.MALUS_TIRATORE_IN_MISCHIA = 0.5
-- Un reggimento decimato colpisce meno forte: a vita zero farebbe questa quota del danno.
Battaglia.FORZA_MINIMA = 0.4

local RAGGIO = 0.42
-- La fortezza è grande: si colpisce da più lontano e le si gira attorno più al largo.
local RAGGIO_FORTEZZA = 0.75
local RAGGIO_OSTACOLO = 0.5
local RAGGIO_AREA = 1.0
local RAGGIO_AURA = 2.2

-- Effetti del terreno della casella su cui sta un reggimento.
Battaglia.TERRENO = {
	fiume = { velocita = 0.45, dannoSubito = 1.2 },
	collina = { dannoSubito = 0.8, gittataTiratori = 0.7 },
}
local ANGOLI = { 0, 0.6, -0.6, 1.2, -1.2, 1.8, -1.8 }

-- Strade attorno agli ostacoli: una griglia fine di punti in cui un reggimento ci sta.
local PASSO_GRIGLIA = 0.25
local MARGINE_STRADA = RAGGIO + RAGGIO_OSTACOLO + 0.04
-- Un tragitto dritto è libero se non passa più vicino di così a un ostacolo (o se se ne allontana).
local MARGINE_VISTA = RAGGIO + RAGGIO_OSTACOLO + 0.01
-- Ogni quanto si ricalcolano le distanze verso un bersaglio (secondi di battaglia).
local VALIDITA_CAMPO = 0.5
local VICINI = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }

function Battaglia.moltiplicatore(classeAttacco, classeDifesa)
	if Battaglia.BATTE[classeAttacco] == classeDifesa then
		return Battaglia.BONUS
	end
	if Battaglia.BATTE[classeDifesa] == classeAttacco then
		return Battaglia.MALUS
	end
	return 1
end

local function distanza(a, b)
	local dx, dy = a.x - b.x, a.y - b.y
	return math.sqrt(dx * dx + dy * dy)
end

-- unita: lista di { id = numero, squadra = "giocatore" | "nemico", def = reggimento, x, y, forza = moltiplicatore opzionale }
-- opzioni: { colonne, righe, ostacoli = { { x, y } }, terreno = { ["col,riga"] = "fiume" | "collina" } }
function Battaglia.nuova(unita, opzioni)
	opzioni = opzioni or {}
	local self = setmetatable({}, Battaglia)
	self.colonne = opzioni.colonne or 6
	self.righe = opzioni.righe or 6
	self.ostacoli = opzioni.ostacoli or {}
	self.terreno = opzioni.terreno or {}
	self.unita = {}
	self.tempo = 0
	self.finita = false
	self.vincitore = nil
	for _, u in ipairs(unita) do
		local forza = u.forza or 1
		table.insert(self.unita, {
			id = u.id,
			squadra = u.squadra,
			def = u.def,
			x = u.x,
			y = u.y,
			hpMax = u.def.hp * forza,
			hp = u.def.hp * forza,
			danno = u.def.danno * forza,
			ricarica = 0,
			vivo = true,
			bersaglio = nil,
			caricaUsata = false,
		})
	end
	table.sort(self.unita, function(a, b)
		return a.id < b.id
	end)
	self.larghezzaGriglia = math.floor((self.colonne - 1) / PASSO_GRIGLIA + 0.5) + 1
	self.altezzaGriglia = math.floor((self.righe - 1) / PASSO_GRIGLIA + 0.5) + 1
	self.nodoLibero = {}
	for j = 0, self.altezzaGriglia - 1 do
		for i = 0, self.larghezzaGriglia - 1 do
			local x, y = 1 + i * PASSO_GRIGLIA, 1 + j * PASSO_GRIGLIA
			local libero = true
			for _, o in ipairs(self.ostacoli) do
				if (o.x - x) ^ 2 + (o.y - y) ^ 2 < MARGINE_STRADA ^ 2 then
					libero = false
					break
				end
			end
			self.nodoLibero[j * self.larghezzaGriglia + i + 1] = libero
		end
	end
	self.campi = {}
	return self
end

-- Effetti del terreno sotto il reggimento (tabella vuota se il terreno è normale).
function Battaglia:_terrenoSotto(u)
	local tipo = self.terreno[math.floor(u.x + 0.5) .. "," .. math.floor(u.y + 0.5)]
	return Battaglia.TERRENO[tipo] or {}
end

function Battaglia:_gittata(u)
	local gittata = u.def.gittata
	if gittata > 2 then
		gittata = gittata + (self:_terrenoSotto(u).gittataTiratori or 0)
	end
	return gittata
end

local function ingombro(u)
	return u.def.fortezza and RAGGIO_FORTEZZA or RAGGIO
end

-- Distanza da cui u colpisce b (contata dal centro di b).
function Battaglia:_portata(u, b)
	return self:_gittata(u) + ingombro(b) - RAGGIO
end

function Battaglia:_inGittata(u, b)
	return distanza(u, b) <= self:_portata(u, b) + 0.05
end

-- Bonus al danno dato dal comandante alleato più vicino (il migliore tra quelli a portata).
function Battaglia:_aura(u)
	local migliore = 0
	for _, altro in ipairs(self.unita) do
		if altro ~= u and altro.vivo and altro.squadra == u.squadra and altro.def.aura and distanza(u, altro) <= RAGGIO_AURA then
			migliore = math.max(migliore, altro.def.aura)
		end
	end
	return 1 + migliore
end

-- Tiene il bersaglio finché è vivo e a tiro, altrimenti sceglie il nemico più vicino.
function Battaglia:_bersaglio(u)
	local attuale = u.bersaglio
	if attuale and attuale.vivo and self:_inGittata(u, attuale) then
		return attuale
	end
	local migliore, dMin = nil, math.huge
	for _, altro in ipairs(self.unita) do
		if altro.vivo and altro.squadra ~= u.squadra then
			local d = distanza(u, altro)
			if d < dMin then
				migliore, dMin = altro, d
			end
		end
	end
	u.bersaglio = migliore
	return migliore
end

-- Una posizione è libera se è nel tabellone, fuori dagli ostacoli e non si avvicina troppo a un altro reggimento.
-- passaAlleati: il reggimento può sfilare tra gli alleati (quando non ha altre strade).
function Battaglia:_libero(u, x, y, passaAlleati)
	if x < 1 or x > self.colonne or y < 1 or y > self.righe then
		return false
	end
	for _, o in ipairs(self.ostacoli) do
		local dx, dy = o.x - x, o.y - y
		if dx * dx + dy * dy < (RAGGIO + RAGGIO_OSTACOLO) ^ 2 then
			return false
		end
	end
	for _, altro in ipairs(self.unita) do
		if altro ~= u and altro.vivo and not (passaAlleati and altro.squadra == u.squadra) then
			local dx, dy = altro.x - x, altro.y - y
			local nuova = dx * dx + dy * dy
			if nuova < (ingombro(u) + ingombro(altro)) ^ 2 then
				local ax, ay = altro.x - u.x, altro.y - u.y
				if nuova < ax * ax + ay * ay then
					return false
				end
			end
		end
	end
	return true
end

local function distanzaDalSegmento(px, py, x0, y0, x1, y1)
	local dx, dy = x1 - x0, y1 - y0
	local l2 = dx * dx + dy * dy
	local t = l2 > 0 and math.clamp(((px - x0) * dx + (py - y0) * dy) / l2, 0, 1) or 0
	local cx, cy = x0 + dx * t - px, y0 + dy * t - py
	return math.sqrt(cx * cx + cy * cy)
end

-- Vero se andando dritto da (x0, y0) a (x1, y1) non si urta nessun ostacolo. Chi è già
-- rasente a un ostacolo può comunque allontanarsene o costeggiarlo.
function Battaglia:_vistaLibera(x0, y0, x1, y1)
	for _, o in ipairs(self.ostacoli) do
		local partenza = math.sqrt((o.x - x0) ^ 2 + (o.y - y0) ^ 2)
		if distanzaDalSegmento(o.x, o.y, x0, y0, x1, y1) < math.min(MARGINE_VISTA, partenza) - 1e-6 then
			return false
		end
	end
	return true
end

function Battaglia:_nodo(k)
	local i, j = (k - 1) % self.larghezzaGriglia, (k - 1) // self.larghezzaGriglia
	return 1 + i * PASSO_GRIGLIA, 1 + j * PASSO_GRIGLIA, i, j
end

-- Vicini di un nodo raggiungibili senza tagliare l'angolo di un ostacolo.
function Battaglia:_vicini(k)
	local w, h = self.larghezzaGriglia, self.altezzaGriglia
	local _, _, i, j = self:_nodo(k)
	local risultato = {}
	for _, v in ipairs(VICINI) do
		local ni, nj = i + v[1], j + v[2]
		if ni >= 0 and ni < w and nj >= 0 and nj < h then
			local n = nj * w + ni + 1
			local diagonaleLibera = v[1] == 0 or v[2] == 0
				or (self.nodoLibero[j * w + ni + 1] and self.nodoLibero[nj * w + i + 1])
			if self.nodoLibero[n] and diagonaleLibera then
				table.insert(risultato, { n, PASSO_GRIGLIA * math.sqrt(v[1] * v[1] + v[2] * v[2]) })
			end
		end
	end
	return risultato
end

-- Distanza a piedi da ogni nodo fino a un punto da cui si colpisce il bersaglio (nil = irraggiungibile).
-- Calcolata una volta per bersaglio e gittata, rifatta quando il bersaglio si sposta o passa del tempo.
function Battaglia:_campo(b, portata)
	local chiave = b.id .. ":" .. math.floor(portata * 10 + 0.5)
	local campo = self.campi[chiave]
	if campo and self.tempo - campo.tempo < VALIDITA_CAMPO and math.abs(campo.x - b.x) + math.abs(campo.y - b.y) < 0.3 then
		return campo.distanze
	end
	local distanze = {}
	-- Coda con priorità (heap binario) di { distanza, nodo }.
	local heap = {}
	local function inserisci(d, k)
		table.insert(heap, { d, k })
		local i = #heap
		while i > 1 do
			local padre = i // 2
			if heap[padre][1] <= heap[i][1] then
				break
			end
			heap[padre], heap[i] = heap[i], heap[padre]
			i = padre
		end
	end
	local function estrai()
		local primo = heap[1]
		local ultimo = table.remove(heap)
		if #heap > 0 then
			heap[1] = ultimo
			local i = 1
			while true do
				local a, c = i * 2, i * 2 + 1
				local minimo = i
				if heap[a] and heap[a][1] < heap[minimo][1] then
					minimo = a
				end
				if heap[c] and heap[c][1] < heap[minimo][1] then
					minimo = c
				end
				if minimo == i then
					break
				end
				heap[minimo], heap[i] = heap[i], heap[minimo]
				i = minimo
			end
		end
		return primo
	end
	for k = 1, self.larghezzaGriglia * self.altezzaGriglia do
		if self.nodoLibero[k] then
			local x, y = self:_nodo(k)
			if (x - b.x) ^ 2 + (y - b.y) ^ 2 <= (portata * 0.9) ^ 2 then
				distanze[k] = 0
				inserisci(0, k)
			end
		end
	end
	while #heap > 0 do
		local voce = estrai()
		local d, k = voce[1], voce[2]
		if d <= distanze[k] then
			for _, v in ipairs(self:_vicini(k)) do
				local n, costo = v[1], d + v[2]
				if not distanze[n] or costo < distanze[n] then
					distanze[n] = costo
					inserisci(costo, n)
				end
			end
		end
	end
	self.campi[chiave] = { tempo = self.tempo, x = b.x, y = b.y, distanze = distanze }
	return distanze
end

-- Prossima tappa verso il bersaglio quando un ostacolo copre la strada dritta: il punto più avanti
-- della strada più corta che si vede ancora da dove si è. nil se il bersaglio è irraggiungibile.
function Battaglia:_tappa(u, b, portata)
	local distanze = self:_campo(b, portata)
	local w, h = self.larghezzaGriglia, self.altezzaGriglia
	local ci, cj = math.floor((u.x - 1) / PASSO_GRIGLIA + 0.5), math.floor((u.y - 1) / PASSO_GRIGLIA + 0.5)
	local partenza, migliore = nil, math.huge
	for dj = -2, 2 do
		for di = -2, 2 do
			local i, j = ci + di, cj + dj
			if i >= 0 and i < w and j >= 0 and j < h then
				local k = j * w + i + 1
				if distanze[k] then
					local x, y = self:_nodo(k)
					local costo = distanze[k] + math.sqrt((x - u.x) ^ 2 + (y - u.y) ^ 2)
					if costo < migliore and self:_vistaLibera(u.x, u.y, x, y) then
						partenza, migliore = k, costo
					end
				end
			end
		end
	end
	if not partenza then
		return nil
	end
	local k = partenza
	local tx, ty = self:_nodo(k)
	for _ = 1, 24 do
		local prossimo, dMin = nil, distanze[k]
		for _, v in ipairs(self:_vicini(k)) do
			local n = v[1]
			if distanze[n] and distanze[n] < dMin then
				prossimo, dMin = n, distanze[n]
			end
		end
		if not prossimo then
			break
		end
		local x, y = self:_nodo(prossimo)
		if not self:_vistaLibera(u.x, u.y, x, y) then
			break
		end
		k, tx, ty = prossimo, x, y
	end
	return tx, ty
end

function Battaglia:_muovi(u, bersaglio, dt)
	local dx, dy = bersaglio.x - u.x, bersaglio.y - u.y
	local d = math.sqrt(dx * dx + dy * dy)
	local velocita = u.def.velocita * (self:_terrenoSotto(u).velocita or 1)
	local portata = self:_portata(u, bersaglio)
	local passo = math.min(velocita * dt, d - portata * 0.9)
	if passo <= 0 then
		return
	end
	local dirX, dirY = dx / d, dy / d
	-- Un ostacolo copre la strada dritta: si va verso la prossima tappa della strada che lo aggira.
	if #self.ostacoli > 0 and not self:_vistaLibera(u.x, u.y, bersaglio.x, bersaglio.y) then
		local tx, ty = self:_tappa(u, bersaglio, portata)
		local lunghezza = tx and math.sqrt((tx - u.x) ^ 2 + (ty - u.y) ^ 2) or 0
		if lunghezza > 1e-3 then
			dirX, dirY = (tx - u.x) / lunghezza, (ty - u.y) / lunghezza
		end
	end
	-- Prima cerca una strada libera; se gli alleati la chiudono tutta, sfila in mezzo a loro
	-- invece di restare fermo dietro chi sta già combattendo.
	for _, passaAlleati in ipairs({ false, true }) do
		for _, angolo in ipairs(ANGOLI) do
			local c, s = math.cos(angolo), math.sin(angolo)
			local nx = u.x + (dirX * c - dirY * s) * passo
			local ny = u.y + (dirX * s + dirY * c) * passo
			if self:_libero(u, nx, ny, passaAlleati) then
				u.x, u.y = nx, ny
				return
			end
		end
	end
end

-- Danno di un colpo, prima dell'armatura del bersaglio.
function Battaglia:_dannoBase(u, b, d)
	local forza = Battaglia.FORZA_MINIMA + (1 - Battaglia.FORZA_MINIMA) * (u.hp / u.hpMax)
	local danno = u.danno * forza * Battaglia.moltiplicatore(u.def.classe, b.def.classe) * self:_aura(u)
	if u.def.gittata > 2 and d < 1.3 then
		danno = danno * Battaglia.MALUS_TIRATORE_IN_MISCHIA
	end
	-- Testuggine: gli scudi alzati riducono i colpi da lontano.
	if b.def.testuggine and d > 1.5 then
		danno = danno * b.def.testuggine
	end
	local carica = false
	if u.def.carica and not u.caricaUsata and d < 1.5 then
		danno = danno * u.def.carica
		u.caricaUsata = true
		carica = true
	end
	return danno, carica
end

function Battaglia:_ferisci(b, danno, eventi, attaccante)
	local reale = danno * (1 - (b.def.armatura or 0)) * (self:_terrenoSotto(b).dannoSubito or 1)
	b.hp = b.hp - reale
	if b.hp <= 0 then
		b.hp = 0
		b.vivo = false
		table.insert(eventi, { tipo = "morte", id = b.id, da = attaccante })
	end
	return reale
end

function Battaglia:_controllaFine()
	local vivi = { giocatore = 0, nemico = 0 }
	local vita = { giocatore = 0, nemico = 0 }
	for _, u in ipairs(self.unita) do
		if u.vivo then
			vivi[u.squadra] = vivi[u.squadra] + 1
			vita[u.squadra] = vita[u.squadra] + u.hp / u.hpMax
		end
	end
	if vivi.giocatore == 0 or vivi.nemico == 0 then
		self.finita = true
		self.vincitore = vivi.giocatore > 0 and "giocatore" or "nemico"
	elseif self.tempo >= Battaglia.DURATA_MASSIMA then
		self.finita = true
		self.vincitore = vita.giocatore > vita.nemico and "giocatore" or "nemico"
	end
end

-- Avanza di dt secondi. Restituisce gli eventi del passo:
-- { tipo = "attacco", da, a, danno, distanza, carica, area = { { id, danno } } } e { tipo = "morte", id, da }.
function Battaglia:passo(dt)
	local eventi = {}
	if self.finita then
		return eventi
	end
	self.tempo = self.tempo + dt
	for _, u in ipairs(self.unita) do
		if u.vivo then
			u.ricarica = math.max(0, u.ricarica - dt)
			local b = self:_bersaglio(u)
			if b then
				if self:_inGittata(u, b) then
					if u.ricarica <= 0 then
						-- Distanza tra i bordi: vicino alla fortezza si è in mischia anche un po' più lontano.
						local d = distanza(u, b) - (ingombro(u) - RAGGIO) - (ingombro(b) - RAGGIO)
						local base, carica = self:_dannoBase(u, b, d)
						u.ricarica = 1 / u.def.cadenza
						local evento = {
							tipo = "attacco",
							da = u.id,
							a = b.id,
							distanza = d > 1.5,
							carica = carica,
							area = {},
						}
						table.insert(eventi, evento)
						evento.danno = self:_ferisci(b, base, eventi, u.id)
						if u.def.area then
							for _, vicino in ipairs(self.unita) do
								if vicino ~= b and vicino.vivo and vicino.squadra == b.squadra and distanza(vicino, b) <= RAGGIO_AREA then
									local inflitto = self:_ferisci(vicino, base * u.def.area, eventi, u.id)
									table.insert(evento.area, { id = vicino.id, danno = inflitto })
								end
							end
						end
					end
				else
					self:_muovi(u, b, dt)
				end
			end
		end
	end
	self:_controllaFine()
	return eventi
end

-- Simula fino alla fine senza pause. Usata nei test.
function Battaglia:simula(dt)
	while not self.finita do
		self:passo(dt)
	end
	return self.vincitore
end

return Battaglia
