-- Simulazione della battaglia automatica, a passi di tempo fissi.
-- Non usa API di Roblox: gira uguale sul server e nei test.
-- Le posizioni sono in caselle: x = colonna (1-8), y = riga (1-8).
-- Le righe 1-4 sono del giocatore, le righe 5-8 del nemico.

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

local RAGGIO = 0.45
local MIN_X, MAX_X, MIN_Y, MAX_Y = 1, 8, 1, 8
local ANGOLI = { 0, 0.6, -0.6, 1.2, -1.2 }

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

-- unita: lista di { id = numero, squadra = "giocatore" | "nemico", def = truppa, x, y, forza = moltiplicatore opzionale }
function Battaglia.nuova(unita)
	local self = setmetatable({}, Battaglia)
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
		})
	end
	table.sort(self.unita, function(a, b)
		return a.id < b.id
	end)
	return self
end

function Battaglia:_inGittata(u, b)
	return distanza(u, b) <= u.def.gittata + 0.05
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

-- Una posizione è libera se è nel tabellone e non si avvicina troppo a un'altra truppa.
function Battaglia:_libero(u, x, y)
	if x < MIN_X or x > MAX_X or y < MIN_Y or y > MAX_Y then
		return false
	end
	local minimo = (RAGGIO * 2) ^ 2
	for _, altro in ipairs(self.unita) do
		if altro ~= u and altro.vivo then
			local dx, dy = altro.x - x, altro.y - y
			local nuova = dx * dx + dy * dy
			if nuova < minimo then
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
	local passo = math.min(u.def.velocita * dt, d - u.def.gittata * 0.9)
	if passo <= 0 then
		return
	end
	local dirX, dirY = dx / d, dy / d
	for _, angolo in ipairs(ANGOLI) do
		local c, s = math.cos(angolo), math.sin(angolo)
		local nx = u.x + (dirX * c - dirY * s) * passo
		local ny = u.y + (dirX * s + dirY * c) * passo
		if self:_libero(u, nx, ny) then
			u.x, u.y = nx, ny
			return
		end
	end
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
-- { tipo = "attacco", da, a, danno, distanza } e { tipo = "morte", id }.
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
						local danno = u.danno * Battaglia.moltiplicatore(u.def.classe, b.def.classe)
						b.hp = b.hp - danno
						u.ricarica = 1 / u.def.cadenza
						table.insert(eventi, {
							tipo = "attacco",
							da = u.id,
							a = b.id,
							danno = danno,
							distanza = distanza(u, b) > 1.5,
						})
						if b.hp <= 0 then
							b.hp = 0
							b.vivo = false
							table.insert(eventi, { tipo = "morte", id = b.id })
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
