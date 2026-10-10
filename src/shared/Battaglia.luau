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

function Battaglia:_muovi(u, bersaglio, dt)
	local dx, dy = bersaglio.x - u.x, bersaglio.y - u.y
	local d = math.sqrt(dx * dx + dy * dy)
	local velocita = u.def.velocita * (self:_terrenoSotto(u).velocita or 1)
	local passo = math.min(velocita * dt, d - self:_portata(u, bersaglio) * 0.9)
	if passo <= 0 then
		return
	end
	local dirX, dirY = dx / d, dy / d
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
