-- Simulazione della battaglia automatica, soldato per soldato, a passi di tempo fissi.
-- Ogni carta è un reggimento, ma in battaglia ogni suo soldato si muove e combatte da solo:
-- sceglie il nemico più vicino, ci va incontro e lo attacca. I colpi partono e arrivano dopo un po'
-- (il tempo del gesto e del volo della freccia), così il client li può animare.
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

-- Ingombro di un soldato (raggio, in caselle: una casella è 16 studs).
local RAGGI = {
	fante = 0.065,
	cavallo = 0.13,
	carro = 0.3,
	fortezza = 0.75,
}
local RAGGIO_OSTACOLO = 0.5
local RAGGIO_AREA = 0.32
local RAGGIO_AURA = 2.2
-- Distanza in più dal bersaglio entro cui un colpo in mischia arriva (oltre ai due ingombri).
local PORTATA_MISCHIA = 0.05
-- Oltre questa gittata (in caselle) si tira da lontano.
local GITTATA_MISCHIA = 1.5
local RIPENSA = 0.4 -- ogni quanto un soldato rivaluta il bersaglio (secondi)
local AFFOLLAMENTO = 0.09 -- un nemico già attaccato da altri sembra più lontano di tanto per ognuno

-- Tempi dei colpi: gesto prima che il colpo parta e velocità del proiettile (caselle al secondo).
-- Chi non è in tabella colpisce in mischia con un gesto di 0.3 secondi.
Battaglia.TEMPI = {
	ArciereCretese = { gesto = 0.45, volo = 3.6 },
	Arciere = { gesto = 0.55, volo = 4 },
	Fante = { gesto = 0.2, volo = 40 },
	Foch = { gesto = 0.2, volo = 40 },
	DeGaulle = { gesto = 0.2, volo = 40 },
	Mitragliere = { gesto = 0.05, volo = 40 },
	CarroArmato = { gesto = 0.35, volo = 9 },
	FortezzaAntica = { gesto = 0.3, volo = 3.6 },
	FortezzaMedievale = { gesto = 0.3, volo = 4 },
	FortezzaNovecento = { gesto = 0.05, volo = 40 },
	FortezzaModerna = { gesto = 0.3, volo = 7 },
	-- Armate nemiche: archi, fionde, balestre, moschetti, cannoni, fucili, mitragliatrici, carri.
	ArcierePersiano = { gesto = 0.45, volo = 3.6 },
	ArciereGallico = { gesto = 0.5, volo = 3.8 },
	ArciereArabo = { gesto = 0.45, volo = 3.8 },
	ArciereNormanno = { gesto = 0.5, volo = 3.8 },
	ArciereAyyubide = { gesto = 0.45, volo = 3.8 },
	FrombolieroBaleare = { gesto = 0.4, volo = 4.5 },
	BalestriereTeutonico = { gesto = 0.3, volo = 6 },
	BalestriereGenovese = { gesto = 0.3, volo = 6 },
	Giannizzero = { gesto = 0.25, volo = 30 },
	MoschettiereSvedese = { gesto = 0.25, volo = 30 },
	FanteriaDiLinea = { gesto = 0.25, volo = 30 },
	CannoneOttomano = { gesto = 0.4, volo = 7 },
	Artiglieria = { gesto = 0.35, volo = 8 },
	FanteOttomano = { gesto = 0.2, volo = 40 },
	Stosstruppen = { gesto = 0.2, volo = 40 },
	FanteBritannico = { gesto = 0.2, volo = 40 },
	FucilieriSovietici = { gesto = 0.2, volo = 40 },
	Granatieri = { gesto = 0.2, volo = 40 },
	FanteFranciaLibera = { gesto = 0.2, volo = 40 },
	Rommel = { gesto = 0.2, volo = 40 },
	MitraglieriOttomani = { gesto = 0.05, volo = 40 },
	MitraglieriTedeschi = { gesto = 0.05, volo = 40 },
	MitraglieriSovietici = { gesto = 0.05, volo = 40 },
	MG42 = { gesto = 0.05, volo = 40 },
	CarroMarkV = { gesto = 0.35, volo = 9 },
	T34 = { gesto = 0.35, volo = 9 },
	Panzer = { gesto = 0.35, volo = 9 },
	-- Era moderna: fucili d'assalto, mitragliatrici, carri; carri e mitragliatrici come nel Novecento.
	MarineUSA = { gesto = 0.2, volo = 40 },
	FanteNVA = { gesto = 0.2, volo = 40 },
	FantePVA = { gesto = 0.2, volo = 40 },
	Giap = { gesto = 0.2, volo = 40 },
	PengDehuai = { gesto = 0.2, volo = 40 },
	MitraglieriM60 = { gesto = 0.05, volo = 40 },
	MitraglieriNVA = { gesto = 0.05, volo = 40 },
	MitraglieriPVA = { gesto = 0.05, volo = 40 },
	M48Patton = { gesto = 0.35, volo = 9 },
	PT76 = { gesto = 0.35, volo = 9 },
}
local GESTO_MISCHIA = 0.3
-- Lancio del pilum: una volta sola, prima della mischia.
local GESTO_LANCIO = 0.45
local VOLO_LANCIO = 2.6

-- Ordini generali che il giocatore dà a tutta la sua armata (il nemico avanza sempre):
--   avanza: ogni soldato va contro il nemico più vicino;
--   tieni: la linea resta dov'è e si muove solo contro chi arriva vicino, con un po' di difesa in più;
--   ripiega: ritirata ordinata di RIPIEGO caselle verso le proprie retrovie, poi si tiene la nuova linea:
--     il nemico che insegue si allunga e arriva a pezzi;
--   fianchi: la cavalleria gira larga sull'ala più vicina e piomba sui tiratori nemici, fanti e tiratori tengono;
--   carica: carica generale, una volta per round: tutti avanzano più veloci e la cavalleria ricarica.
Battaglia.ORDINI = { "avanza", "tieni", "ripiega", "fianchi", "carica" }
-- Nomi visibili nel gioco (inglese) e grido sopra l'armata quando arriva l'ordine.
Battaglia.NOMI_ORDINI = {
	avanza = { nome = "Advance", grido = "ADVANCE!" },
	tieni = { nome = "Hold the Line", grido = "HOLD THE LINE!" },
	ripiega = { nome = "Fall Back", grido = "FALL BACK!" },
	fianchi = { nome = "Flank Them", grido = "ON THEIR FLANKS!" },
	carica = { nome = "General Charge", grido = "CHARGE!" },
}
Battaglia.ATTESA_ORDINE = 3 -- secondi di battaglia tra un ordine e il successivo
Battaglia.DURATA_CARICA = 6
local RIPIEGO = 1.5
local DURATA_RIPIEGO = 6 -- dopo tanto chi ripiega si ferma comunque e tiene la linea
local INGAGGIO = 0.9 -- chi tiene la linea va contro un nemico solo se è entro tanto oltre la sua portata
local DIFESA_IN_LINEA = 0.15
local SCARTO_LINEA = 0.3 -- chi tiene la linea ed è stato spinto più in là di tanto torna al suo posto

-- Effetti del terreno della casella su cui sta un soldato.
Battaglia.TERRENO = {
	fiume = { velocita = 0.45, dannoSubito = 1.2 },
	collina = { dannoSubito = 0.8, gittataTiratori = 0.7 },
	trincea = { dannoSubito = 0.6 },
}

-- Strade attorno agli ostacoli: una griglia fine di punti in cui un soldato ci sta.
local PASSO_GRIGLIA = 0.25
local MARGINE_STRADA = 0.1 + RAGGIO_OSTACOLO
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

-- Ingombro di un soldato del reggimento "def".
function Battaglia.raggio(def)
	if def.fortezza then
		return RAGGI.fortezza
	elseif def.veicolo then -- carri armati, cannoni, elefanti
		return RAGGI.carro
	elseif def.classe == "Cavalleria" then
		return RAGGI.cavallo
	end
	return RAGGI.fante
end

-- Dove stanno i soldati di un reggimento attorno al centro della casella, in caselle.
-- "avanti" è +1 se il nemico è verso le righe alte, -1 altrimenti.
function Battaglia.formazione(numero, def)
	if numero <= 1 then
		return { { 0, 0 } }
	end
	local cavalli = def and def.classe == "Cavalleria"
	local passoX = cavalli and 0.3 or 0.2
	local passoY = cavalli and 0.36 or 0.24
	local perRiga = numero <= 3 and numero or math.ceil(numero / 2)
	local righe = math.ceil(numero / perRiga)
	local lista = {}
	for i = 0, numero - 1 do
		local riga = i // perRiga
		local inRiga = riga == righe - 1 and numero - riga * perRiga or perRiga
		local colonna = i % perRiga
		local x = (colonna - (inRiga - 1) / 2) * passoX + (riga % 2) * 0.03
		local y = ((righe - 1) / 2 - riga) * passoY
		table.insert(lista, { x, y })
	end
	return lista
end

-- Soldati di un reggimento: { def, x, y } attorno al centro (stesse coordinate di formazione). Un generale con la
-- guardia (def.guardia) sta subito dietro ai suoi soldati di scorta, che hanno le statistiche del loro reparto.
function Battaglia.composizione(def)
	local lista = {}
	local guardia = def.guardia
	if guardia and guardia.def then
		local gdef = guardia.def
		local dietro = math.huge
		for _, offset in ipairs(Battaglia.formazione(guardia.numero, gdef)) do
			table.insert(lista, { def = gdef, x = offset[1], y = offset[2] + 0.12 })
			dietro = math.min(dietro, offset[2] + 0.12)
		end
		table.insert(lista, 1, { def = def, x = 0, y = dietro - (def.classe == "Cavalleria" and 0.36 or 0.26) })
		return lista
	end
	for _, offset in ipairs(Battaglia.formazione(math.max(1, def.soldati or 1), def)) do
		table.insert(lista, { def = def, x = offset[1], y = offset[2] })
	end
	return lista
end

local function distanza(a, b)
	local dx, dy = a.x - b.x, a.y - b.y
	return math.sqrt(dx * dx + dy * dy)
end

-- reggimenti: lista di { id = numero (1-4000), squadra = "giocatore" | "nemico", def, x, y, forza = moltiplicatore opzionale }
-- opzioni: { colonne, righe, ostacoli = { { x, y } }, terreno = { ["col,riga"] = "fiume" | "collina" | "trincea" } }
-- Ogni soldato ha id = id del reggimento * 16 + numero (1-15).
function Battaglia.nuova(reggimenti, opzioni)
	opzioni = opzioni or {}
	local self = setmetatable({}, Battaglia)
	self.colonne = opzioni.colonne or 6
	self.righe = opzioni.righe or 6
	self.ostacoli = opzioni.ostacoli or {}
	self.terreno = opzioni.terreno or {}
	self.reggimenti = {}
	self.soldati = {}
	self.perId = {}
	self.colpi = {} -- colpi partiti che devono ancora arrivare
	self.effetti = {} -- abilità dei comandanti in corso: { squadra, origine, fine, danno, velocita, difesa }
	self.eventiInAttesa = {} -- eventi nati fuori da un passo (ordini, abilità): escono col passo dopo
	self.perReggimento = {}
	self.ordini = { giocatore = "avanza", nemico = "avanza" }
	self.ultimoOrdine = { giocatore = -math.huge, nemico = -math.huge }
	self.caricaUsata = {}
	self.mire = { giocatore = {}, nemico = {} } -- bersagli scelti: [id del proprio reggimento o 0 = tutti] -> filtro
	self.tempo = 0
	self.finita = false
	self.vincitore = nil
	local ordinati = table.clone(reggimenti)
	table.sort(ordinati, function(a, b)
		return a.id < b.id
	end)
	for _, r in ipairs(ordinati) do
		local def = r.def
		local forza = r.forza or 1
		local numero = math.max(1, def.soldati or 1)
		local reggimento = {
			id = r.id,
			squadra = r.squadra,
			def = def,
			x = r.x,
			y = r.y,
			soldati = {},
			vivo = true,
			hpMax = def.hp * forza,
			abilitaUsata = false,
		}
		local avanti = r.squadra == "giocatore" and 1 or -1
		local hpTotale = 0
		for i, posto in ipairs(Battaglia.composizione(def)) do
			-- Ogni soldato ha la sua parte del reparto da cui viene (la guardia di un generale ha quella del suo reparto).
			local sdef = posto.def
			local parti = sdef == def and numero or math.max(1, sdef.soldati or 1)
			hpTotale += sdef.hp * forza / parti
			local s = {
				id = r.id * 16 + i,
				numero = i,
				reggimento = reggimento,
				squadra = r.squadra,
				def = sdef,
				x = r.x + posto.x * avanti,
				y = r.y + posto.y * avanti,
				raggio = Battaglia.raggio(sdef),
				hpMax = sdef.hp * forza / parti,
				hp = sdef.hp * forza / parti,
				danno = sdef.danno * forza / parti,
				-- I soldati non colpiscono tutti nello stesso istante.
				ricarica = ((i * 0.37) % 1) / (sdef.cadenza * 2),
				vivo = true,
				bersaglio = nil,
				ripensa = 0,
				caricaUsata = false,
				lancioUsato = not sdef.lancio,
				rivolto = r.squadra == "giocatore" and 0 or math.pi,
				inMarcia = false,
				inMischia = false,
				girato = false, -- ordine "fianchi": la cavalleria ha già girato attorno all'ala
			}
			-- Posto da tenere con gli ordini "tieni" e "ripiega".
			s.ax, s.ay = s.x, s.y
			table.insert(reggimento.soldati, s)
			table.insert(self.soldati, s)
			self.perId[s.id] = s
		end
		reggimento.hpMax = hpTotale -- con la guardia di un generale è più della vita del solo generale
		table.insert(self.reggimenti, reggimento)
		self.perReggimento[reggimento.id] = reggimento
	end
	-- Compatibilità con chi guardava i reggimenti come "unità".
	self.unita = self.reggimenti
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

-- Effetti del terreno sotto il soldato (tabella vuota se il terreno è normale).
function Battaglia:_terrenoSotto(u)
	local tipo = self.terreno[math.floor(u.x + 0.5) .. "," .. math.floor(u.y + 0.5)]
	return Battaglia.TERRENO[tipo] or {}
end

function Battaglia:_gittata(u)
	local gittata = u.def.gittata
	if gittata > GITTATA_MISCHIA then
		gittata = gittata + (self:_terrenoSotto(u).gittataTiratori or 0)
	end
	return gittata
end

local function tiratore(def)
	return def.gittata > GITTATA_MISCHIA
end

-- Distanza tra i centri entro cui u colpisce b.
function Battaglia:_portata(u, b)
	if tiratore(u.def) then
		return self:_gittata(u) + b.raggio
	end
	return u.raggio + b.raggio + PORTATA_MISCHIA + math.max(0, u.def.gittata - 1.1)
end

function Battaglia:_inGittata(u, b)
	return distanza(u, b) <= self:_portata(u, b) + 1e-3
end

-- Il pilum si lancia da più lontano della mischia ma non troppo.
function Battaglia:_puoLanciare(u, b)
	if u.lancioUsato then
		return false
	end
	local d = distanza(u, b)
	return d <= u.def.lancio.gittata and d > self:_portata(u, b) + 0.25
end

-- Bonus al danno dato dal comandante alleato più vicino (il migliore tra quelli a portata).
function Battaglia:_aura(u)
	local migliore = 0
	for _, altro in ipairs(self.soldati) do
		if altro ~= u and altro.vivo and altro.squadra == u.squadra and altro.def.aura and distanza(u, altro) <= RAGGIO_AURA then
			migliore = math.max(migliore, altro.def.aura)
		end
	end
	return 1 + migliore
end

-- Somma dei bonus "campo" (danno, velocita, difesa) delle abilità in corso per il soldato u: chi è della
-- stessa origine del comandante prende il doppio.
function Battaglia:_bonus(u, campo)
	local totale = 0
	for _, e in ipairs(self.effetti) do
		if e.squadra == u.squadra and e[campo] and self.tempo < e.fine then
			totale = totale + e[campo] * (u.def.origine ~= nil and u.def.origine == e.origine and 2 or 1)
		end
	end
	return totale
end

-- Cambia l'ordine generale della squadra (uno di Battaglia.ORDINI). Restituisce false e il motivo se non si può.
function Battaglia:ordine(squadra, nome, automatico)
	if self.finita or not table.find(Battaglia.ORDINI, nome) or not self.ordini[squadra] then
		return false, "Unknown order."
	end
	if self.ordini[squadra] == nome then
		return false, nil
	end
	if not automatico and self.tempo - self.ultimoOrdine[squadra] < Battaglia.ATTESA_ORDINE then
		return false, "Your officers are still carrying out the last order."
	end
	if nome == "carica" then
		if self.caricaUsata[squadra] then
			return false, "The general charge can be sounded once per round."
		end
		self.caricaUsata[squadra] = true
		table.insert(self.effetti, { squadra = squadra, fine = self.tempo + Battaglia.DURATA_CARICA, velocita = 0.3, danno = 0.1 })
	end
	self.ordini[squadra] = nome
	if not automatico then
		self.ultimoOrdine[squadra] = self.tempo
	end
	local avanti = squadra == "giocatore" and 1 or -1
	for _, s in ipairs(self.soldati) do
		if s.vivo and s.squadra == squadra then
			s.ax, s.ay = s.x, s.y
			s.girato = false
			s.ripensa = 0
			if nome == "ripiega" then
				s.ay = math.clamp(s.y - RIPIEGO * avanti, 0.7, self.righe + 0.3)
			elseif nome == "carica" and s.def.carica then
				s.caricaUsata = false
			end
		end
	end
	table.insert(self.eventiInAttesa, { tipo = "ordine", squadra = squadra, ordine = nome, automatico = automatico or nil })
	return true
end

-- Bersagli (Mattia, 20/10/2026: "ordini più dettagliati, targetta questo, quest'altro"). filtro = una classe
-- ("Fanteria", "Cavalleria", "Tiratore"), "Comandante", l'id di un reggimento nemico, oppure nil (nessuno: ognuno
-- sceglie il nemico più vicino). proprio = id di un reggimento della squadra (solo lui) o nil (tutta l'armata,
-- e allora vale anche per chi aveva un bersaglio suo). Restituisce false e il motivo se non si può.
Battaglia.CLASSI_BERSAGLIO = { Fanteria = true, Cavalleria = true, Tiratore = true, Comandante = true }
function Battaglia:bersaglio(squadra, filtro, proprio)
	local mire = self.mire[squadra]
	if self.finita or not mire then
		return false, nil
	end
	if filtro ~= nil and not Battaglia.CLASSI_BERSAGLIO[filtro] then
		local r = self.perReggimento[filtro]
		if not (r and r.vivo and r.squadra ~= squadra) then
			return false, "That regiment cannot be targeted."
		end
	end
	if proprio ~= nil then
		local r = self.perReggimento[proprio]
		if not (r and r.vivo and r.squadra == squadra) then
			return false, "That regiment is no longer on the field."
		end
		mire[proprio] = filtro or false -- false = libero anche se tutta l'armata ha un bersaglio
	else
		table.clear(mire)
		mire[0] = filtro
	end
	for _, s in ipairs(self.soldati) do
		if s.vivo and s.squadra == squadra and (proprio == nil or s.reggimento.id == proprio) then
			s.ripensa = 0
		end
	end
	table.insert(self.eventiInAttesa, { tipo = "bersaglio", squadra = squadra, filtro = filtro, reggimento = proprio })
	return true
end

-- Il nemico "altro" va bene per il filtro di bersaglio?
local function adatto(altro, filtro)
	if type(filtro) == "number" then
		return altro.reggimento.id == filtro
	elseif filtro == "Comandante" then
		return altro.def.comandante == true
	end
	return altro.def.classe == filtro
end

-- Filtro di bersaglio che vale per il soldato u (quello del suo reggimento prima di quello di tutta l'armata).
function Battaglia:_mira(u)
	local mire = self.mire[u.squadra]
	local suo = mire[u.reggimento.id]
	if suo ~= nil then
		return suo or nil
	end
	return mire[0]
end

-- Ordini che finiscono da soli: la carica dopo DURATA_CARICA torna avanzata, la ritirata finita (o durata
-- troppo) diventa una linea da tenere.
function Battaglia:_aggiornaOrdini()
	for squadra, nome in pairs(self.ordini) do
		local trascorso = self.tempo - self.ultimoOrdine[squadra]
		if nome == "carica" and trascorso >= Battaglia.DURATA_CARICA then
			self:ordine(squadra, "avanza", true)
		elseif nome == "ripiega" then
			local tutti = true
			for _, s in ipairs(self.soldati) do
				if s.vivo and s.squadra == squadra and s.def.velocita > 0 and (s.x - s.ax) ^ 2 + (s.y - s.ay) ^ 2 > 0.15 ^ 2 then
					tutti = false
					break
				end
			end
			if tutti or trascorso >= DURATA_RIPIEGO then
				self:ordine(squadra, "tieni", true)
			end
		end
	end
end

-- Abilità del comandante "id": una volta per battaglia, mentre è vivo.
function Battaglia:attivaAbilita(id)
	local r = self.perReggimento[id]
	local a = r and r.def.abilita
	if self.finita or not a or not r.vivo or r.abilitaUsata then
		return false
	end
	r.abilitaUsata = true
	table.insert(self.effetti, {
		squadra = r.squadra,
		origine = r.def.origine,
		fine = self.tempo + (a.durata or 8),
		danno = a.danno,
		velocita = a.velocita,
		difesa = a.difesa,
	})
	for _, s in ipairs(self.soldati) do
		if s.vivo and s.squadra == r.squadra then
			local doppio = s.def.origine ~= nil and s.def.origine == r.def.origine
			if a.cura then
				s.hp = math.min(s.hpMax, s.hp + s.hpMax * a.cura * (doppio and 2 or 1))
			end
			if a.cariche and s.def.carica then
				s.caricaUsata = false
			end
		end
	end
	table.insert(self.eventiInAttesa, { tipo = "abilita", reggimento = id, squadra = r.squadra, tipoCarta = r.def.id, durata = a.durata or 8 })
	return true
end

-- Sceglie il nemico da attaccare: il più vicino, ma chi ha già tanti addosso conta come più lontano.
-- Con l'ordine "fianchi" la cavalleria preferisce i tiratori nemici (finché ce ne sono).
-- Con un bersaglio scelto (Battaglia:bersaglio) va sul più vicino tra quelli adatti, finché ce ne sono.
function Battaglia:_bersaglio(u, dt)
	local attuale = u.bersaglio
	local filtro = self:_mira(u)
	u.ripensa = u.ripensa - dt
	if attuale and attuale.vivo and (self:_inGittata(u, attuale) or u.ripensa > 0)
		and (filtro == nil or u.senzaMira or adatto(attuale, filtro)) then
		return attuale
	end
	u.ripensa = RIPENSA
	local mischia = not tiratore(u.def)
	local cercaTiratori = false
	if filtro == nil and self.ordini[u.squadra] == "fianchi" and u.def.classe == "Cavalleria" then
		for _, altro in ipairs(self.soldati) do
			if altro.vivo and altro.squadra ~= u.squadra and altro.def.classe == "Tiratore" then
				cercaTiratori = true
				break
			end
		end
	end
	local migliore, punteggioMin = nil, math.huge
	local mirato, punteggioMirato = nil, math.huge
	for _, altro in ipairs(self.soldati) do
		if altro.vivo and altro.squadra ~= u.squadra then
			local punteggio = distanza(u, altro) - altro.raggio
			if mischia and altro ~= attuale then
				punteggio = punteggio + (altro.assalitori or 0) * AFFOLLAMENTO
			end
			if (not cercaTiratori or altro.def.classe == "Tiratore") and punteggio < punteggioMin then
				migliore, punteggioMin = altro, punteggio
			end
			if filtro ~= nil and punteggio < punteggioMirato and adatto(altro, filtro) then
				mirato, punteggioMirato = altro, punteggio
			end
		end
	end
	-- Se del bersaglio scelto non resta nessuno, si combatte come senza bersaglio.
	u.senzaMira = filtro ~= nil and mirato == nil
	if mirato then
		migliore = mirato
	end
	if attuale and attuale.assalitori and attuale ~= migliore then
		attuale.assalitori = attuale.assalitori - 1
	end
	if migliore and migliore ~= attuale and mischia then
		migliore.assalitori = (migliore.assalitori or 0) + 1
	end
	u.bersaglio = migliore
	return migliore
end

-- Posto del comandante: i generali non combattono mai da soli (richiesta di Mattia). Seguono la loro guardia
-- (i soldati di scorta della loro carta), appena dietro; se la guardia cade, stanno attaccati al reggimento
-- della loro squadra più vicino (se muore, al più vicino tra quelli rimasti).
-- Restituisce x, y del posto, oppure nil se non resta nessun reggimento.
function Battaglia:_postoComandante(u)
	local avanti = u.squadra == "giocatore" and 1 or -1
	local gx, gy, gn = 0, 0, 0
	for _, s in ipairs(u.reggimento.soldati) do
		if s.vivo and s ~= u and not s.def.comandante then
			gx, gy, gn = gx + s.x, gy + s.y, gn + 1
		end
	end
	if gn > 0 then
		return gx / gn, math.clamp(gy / gn - 0.3 * avanti, 0.6, self.righe + 0.4)
	end
	local scorta = u.scorta
	if not (scorta and scorta.vivo) then
		scorta = nil
		local migliore = math.huge
		for _, r in ipairs(self.reggimenti) do
			if r.vivo and r.squadra == u.squadra and not r.def.comandante then
				for _, s in ipairs(r.soldati) do
					if s.vivo then
						local d = distanza(u, s)
						if d < migliore then
							scorta, migliore = r, d
						end
					end
				end
			end
		end
		u.scorta = scorta
	end
	if not scorta then
		return nil
	end
	local sx, sy, n = 0, 0, 0
	for _, s in ipairs(scorta.soldati) do
		if s.vivo then
			sx, sy, n = sx + s.x, sy + s.y, n + 1
		end
	end
	if n == 0 then
		return nil
	end
	-- Dietro alla fortezza (che è grande) un po' di più che dietro a un reggimento.
	local dietro = scorta.def.fortezza and 0.9 or 0.45
	return sx / n, math.clamp(sy / n - dietro * avanti, 0.6, self.righe + 0.4)
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
function Battaglia:_vistaLibera(x0, y0, x1, y1, raggio)
	local margine = (raggio or RAGGI.fante) + RAGGIO_OSTACOLO + 0.01
	for _, o in ipairs(self.ostacoli) do
		local partenza = math.sqrt((o.x - x0) ^ 2 + (o.y - y0) ^ 2)
		if distanzaDalSegmento(o.x, o.y, x0, y0, x1, y1) < math.min(margine, partenza) - 1e-6 then
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
function Battaglia:_campo(b, portata)
	local chiave = b.id .. ":" .. math.floor(portata * 10 + 0.5)
	local campo = self.campi[chiave]
	if campo and self.tempo - campo.tempo < VALIDITA_CAMPO and math.abs(campo.x - b.x) + math.abs(campo.y - b.y) < 0.3 then
		return campo.distanze
	end
	local distanze = {}
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
	local raggiungibile = math.max(portata * 0.9, PASSO_GRIGLIA * 0.75)
	for k = 1, self.larghezzaGriglia * self.altezzaGriglia do
		if self.nodoLibero[k] then
			local x, y = self:_nodo(k)
			if (x - b.x) ^ 2 + (y - b.y) ^ 2 <= raggiungibile ^ 2 then
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

-- Prossima tappa verso il bersaglio quando un ostacolo copre la strada dritta.
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
					if costo < migliore and self:_vistaLibera(u.x, u.y, x, y, u.raggio) then
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
		if not self:_vistaLibera(u.x, u.y, x, y, u.raggio) then
			break
		end
		k, tx, ty = prossimo, x, y
	end
	return tx, ty
end

-- Passo verso il bersaglio (gli scontri con gli altri soldati si sistemano dopo, in _separa).
function Battaglia:_muovi(u, b, dt, portata)
	local dx, dy = b.x - u.x, b.y - u.y
	local d = math.sqrt(dx * dx + dy * dy)
	local velocita = u.def.velocita * (self:_terrenoSotto(u).velocita or 1) * (1 + self:_bonus(u, "velocita"))
	local passo = math.min(velocita * dt, d - portata * 0.92)
	if passo <= 0 or d < 1e-6 then
		return
	end
	local dirX, dirY = dx / d, dy / d
	if #self.ostacoli > 0 and not self:_vistaLibera(u.x, u.y, b.x, b.y, u.raggio) then
		local tx, ty = self:_tappa(u, b, portata)
		local lunghezza = tx and math.sqrt((tx - u.x) ^ 2 + (ty - u.y) ^ 2) or 0
		if lunghezza > 1e-3 then
			dirX, dirY = (tx - u.x) / lunghezza, (ty - u.y) / lunghezza
		end
	end
	u.x = u.x + dirX * passo
	u.y = u.y + dirY * passo
	u.rivolto = math.atan2(dirX, dirY)
	u.inMarcia = true
end

-- Una passata di spinte tra soldati sovrapposti.
function Battaglia:_spingi()
	local soldati = self.soldati
	local n = #soldati
	for i = 1, n do
		local a = soldati[i]
		if a.vivo then
			for j = i + 1, n do
				local b = soldati[j]
				if b.vivo then
					local dx, dy = b.x - a.x, b.y - a.y
					local minimo = a.raggio + b.raggio
					local d2 = dx * dx + dy * dy
					if d2 < minimo * minimo then
						local d = math.sqrt(d2)
						if d < 1e-6 then
							-- Esattamente sovrapposti: si separano lungo una direzione fissa ma diversa per coppia.
							local angolo = (a.id * 0.618 + b.id * 0.31) % 1 * math.pi * 2
							dx, dy, d = math.sin(angolo), math.cos(angolo), 1
							d2 = 0
						end
						local sovrapposto = minimo - math.sqrt(d2)
						local pesoA = a.def.velocita == 0 and 0 or (a.inMischia and 0.35 or 1)
						local pesoB = b.def.velocita == 0 and 0 or (b.inMischia and 0.35 or 1)
						local totale = pesoA + pesoB
						if totale > 0 then
							local nx, ny = dx / d, dy / d
							a.x = a.x - nx * sovrapposto * pesoA / totale
							a.y = a.y - ny * sovrapposto * pesoA / totale
							b.x = b.x + nx * sovrapposto * pesoB / totale
							b.y = b.y + ny * sovrapposto * pesoB / totale
						end
					end
				end
			end
		end
	end
end

-- Nessuno si compenetra: chi si sovrappone viene spinto via. Chi sta combattendo si sposta meno,
-- le fortezze e gli ostacoli mai. Infine tutti restano nel campo.
function Battaglia:_separa()
	local soldati = self.soldati
	for _ = 1, 3 do
		self:_spingi()
	end
	for _, s in ipairs(soldati) do
		if s.vivo and s.def.velocita > 0 then
			for _, o in ipairs(self.ostacoli) do
				local dx, dy = s.x - o.x, s.y - o.y
				local minimo = s.raggio + RAGGIO_OSTACOLO
				local d2 = dx * dx + dy * dy
				if d2 < minimo * minimo then
					local d = math.sqrt(d2)
					if d < 1e-6 then
						dx, dy, d = 0, -1, 1
					end
					s.x = o.x + dx / d * minimo
					s.y = o.y + dy / d * minimo
				end
			end
			s.x = math.clamp(s.x, 0.55, self.colonne + 0.45)
			s.y = math.clamp(s.y, 0.55, self.righe + 0.45)
		end
	end
end

-- Danno di un colpo, prima dell'armatura del bersaglio.
function Battaglia:_dannoBase(u, b, lancio)
	local d = distanza(u, b) - u.raggio - b.raggio
	local danno = u.danno * Battaglia.moltiplicatore(u.def.classe, b.def.classe) * self:_aura(u) * (1 + self:_bonus(u, "danno"))
	if lancio then
		danno = danno * u.def.lancio.danno
	end
	local daLontano = lancio or tiratore(u.def)
	if tiratore(u.def) and d < 0.25 then
		danno = danno * Battaglia.MALUS_TIRATORE_IN_MISCHIA
	end
	-- Testuggine: gli scudi alzati riducono i colpi da lontano.
	if b.def.testuggine and daLontano then
		danno = danno * b.def.testuggine
	end
	local carica = false
	if u.def.carica and not u.caricaUsata and not daLontano then
		danno = danno * u.def.carica
		u.caricaUsata = true
		carica = true
	end
	return danno, carica
end

function Battaglia:_ferisci(b, danno, eventi, attaccante)
	if not b.vivo then
		return 0
	end
	-- Chi tiene la linea ed è fermo para meglio.
	local inLinea = self.ordini[b.squadra] == "tieni" and not b.inMarcia
	local reale = danno * (1 - (b.def.armatura or 0)) * (self:_terrenoSotto(b).dannoSubito or 1)
		* (1 - math.min(0.6, self:_bonus(b, "difesa") + (inLinea and DIFESA_IN_LINEA or 0)))
	b.hp = b.hp - reale
	if b.hp <= 0 then
		b.hp = 0
		b.vivo = false
		if b.bersaglio and b.bersaglio.assalitori then
			b.bersaglio.assalitori = math.max(0, b.bersaglio.assalitori - 1)
		end
		local reggimento = b.reggimento
		local ancoraVivo = false
		for _, s in ipairs(reggimento.soldati) do
			if s.vivo then
				ancoraVivo = true
				break
			end
		end
		reggimento.vivo = ancoraVivo
		table.insert(eventi, { tipo = "morte", id = b.id, da = attaccante, reggimento = reggimento.id, reggimentoCaduto = not ancoraVivo })
	end
	return reale
end

-- Vita rimasta al reggimento (0-1).
function Battaglia.vitaReggimento(reggimento)
	local totale = 0
	for _, s in ipairs(reggimento.soldati) do
		totale = totale + s.hp
	end
	return totale / reggimento.hpMax
end

function Battaglia:_controllaFine()
	local vivi = { giocatore = 0, nemico = 0 }
	local vita = { giocatore = 0, nemico = 0 }
	for _, r in ipairs(self.reggimenti) do
		if r.vivo then
			vivi[r.squadra] = vivi[r.squadra] + 1
			vita[r.squadra] = vita[r.squadra] + Battaglia.vitaReggimento(r)
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

-- Colpi che arrivano a segno in questo passo.
function Battaglia:_arrivi(eventi)
	local rimasti = {}
	for _, c in ipairs(self.colpi) do
		if c.arrivo <= self.tempo + 1e-9 then
			local b = c.bersaglio
			-- Chi è già caduto non si può colpire: la freccia finisce a terra.
			if b.vivo then
				local evento = { tipo = "colpo", da = c.da, a = b.id, area = {} }
				table.insert(eventi, evento)
				evento.danno = self:_ferisci(b, c.danno, eventi, c.da)
				if c.area then
					for _, vicino in ipairs(self.soldati) do
						if vicino ~= b and vicino.vivo and vicino.squadra == b.squadra and distanza(vicino, b) <= RAGGIO_AREA + vicino.raggio then
							local inflitto = self:_ferisci(vicino, c.danno * c.area, eventi, c.da)
							table.insert(evento.area, { id = vicino.id, danno = inflitto })
						end
					end
				end
			end
		else
			table.insert(rimasti, c)
		end
	end
	self.colpi = rimasti
end

-- Avanza di dt secondi. Restituisce gli eventi del passo:
-- { tipo = "attacco", da, a, colpo = "mischia" | "tiro" | "lancio", ritardo, gesto, carica }
-- { tipo = "colpo", da, a, danno, area = { { id, danno } } }
-- { tipo = "morte", id, da, reggimento, reggimentoCaduto }
-- { tipo = "ordine", squadra, ordine, automatico } e { tipo = "abilita", reggimento, squadra, tipoCarta, durata }
function Battaglia:passo(dt)
	local eventi = self.eventiInAttesa
	self.eventiInAttesa = {}
	if self.finita then
		return eventi
	end
	self.tempo = self.tempo + dt
	self:_aggiornaOrdini()
	for _, u in ipairs(self.soldati) do
		if u.vivo then
			u.inMarcia = false
			u.ricarica = math.max(0, u.ricarica - dt)
			local b = self:_bersaglio(u, dt)
			local ordine = self.ordini[u.squadra]
			local mobile = u.def.velocita > 0
			local lontanoDalPosto = (u.x - u.ax) ^ 2 + (u.y - u.ay) ^ 2
			-- Il generale segue il suo reggimento: combatte solo chi gli arriva a tiro, non va mai all'attacco da solo.
			local postoX, postoY
			if u.def.comandante and mobile then
				postoX, postoY = self:_postoComandante(u)
				if not postoX then
					-- Rimasto senza reggimenti: resta dov'è e si difende (il round finisce comunque entro DURATA_MASSIMA).
					postoX, postoY = u.x, u.y
				end
			end
			if ordine == "ripiega" and mobile and lontanoDalPosto > 0.15 ^ 2 then
				-- Ritirata: chi non è ancora al suo nuovo posto ci va, senza fermarsi a combattere.
				u.inMischia = false
				self:_muovi(u, { id = "posto" .. u.id, x = u.ax, y = u.ay }, dt, 0)
			elseif b then
				local portata = self:_portata(u, b)
				local lancia = u.def.lancio and self:_puoLanciare(u, b)
				local inGittata = distanza(u, b) <= portata + 1e-3
				u.inMischia = inGittata and not tiratore(u.def)
				if inGittata or lancia then
					u.rivolto = math.atan2(b.x - u.x, b.y - u.y)
					if u.ricarica <= 0 then
						local danno, carica = self:_dannoBase(u, b, lancia)
						local tempi = Battaglia.TEMPI[u.def.id]
						local colpo, gesto, volo
						if lancia then
							u.lancioUsato = true
							colpo, gesto, volo = "lancio", GESTO_LANCIO, VOLO_LANCIO
						elseif tempi then
							colpo, gesto, volo = "tiro", tempi.gesto, tempi.volo
						else
							colpo, gesto = "mischia", GESTO_MISCHIA
						end
						local ritardo = gesto + (volo and distanza(u, b) / volo or 0)
						u.ricarica = lancia and 1.2 or 1 / u.def.cadenza
						table.insert(self.colpi, {
							arrivo = self.tempo + ritardo,
							da = u.id,
							bersaglio = b,
							danno = danno,
							area = u.def.area,
						})
						table.insert(eventi, {
							tipo = "attacco",
							da = u.id,
							a = b.id,
							colpo = colpo,
							gesto = gesto,
							ritardo = ritardo,
							carica = carica,
						})
					end
				elseif postoX then
					-- Un nemico vicino (entro INGAGGIO oltre la sua portata) il generale lo va a combattere, senza
					-- allontanarsi troppo dalla sua scorta (Mattia: "si attaccano alle armate ma non combattono").
					local vicino = distanza(u, b) <= portata + INGAGGIO
					local dalPosto = (b.x - postoX) ^ 2 + (b.y - postoY) ^ 2
					if vicino and dalPosto <= (portata + INGAGGIO + 0.6) ^ 2 then
						self:_muovi(u, b, dt, portata)
					elseif (u.x - postoX) ^ 2 + (u.y - postoY) ^ 2 > 0.3 ^ 2 then
						self:_muovi(u, { id = "scorta" .. u.id, x = postoX, y = postoY }, dt, 0)
					else
						u.rivolto = math.atan2(b.x - u.x, b.y - u.y)
					end
				elseif mobile then
					-- Con "tieni", dopo una ritirata e con "fianchi" (tranne la cavalleria) la linea resta ferma:
					-- si va incontro solo a un nemico ormai vicino, e chi è stato spinto via torna al suo posto.
					-- Chi ha un bersaglio scelto (e ancora in campo) ci va anche se la linea tiene.
					local mira = self:_mira(u) ~= nil and not u.senzaMira
					local inLinea = not mira and (ordine == "tieni" or ordine == "ripiega" or (ordine == "fianchi" and u.def.classe ~= "Cavalleria"))
					if inLinea then
						if not tiratore(u.def) and distanza(u, b) <= portata + INGAGGIO then
							self:_muovi(u, b, dt, portata)
						elseif lontanoDalPosto > SCARTO_LINEA ^ 2 then
							self:_muovi(u, { id = "posto" .. u.id, x = u.ax, y = u.ay }, dt, 0)
						else
							u.rivolto = math.atan2(b.x - u.x, b.y - u.y)
						end
					elseif ordine == "fianchi" and not u.girato and distanza(u, b) > 1.5 then
						-- Aggiramento: prima larga sull'ala più vicina fino all'altezza del bersaglio, poi dentro.
						local ala = u.x < (self.colonne + 1) / 2 and 0.75 or self.colonne + 0.25
						if math.abs(u.x - ala) < 0.5 and math.abs(u.y - b.y) < 0.6 then
							u.girato = true
							self:_muovi(u, b, dt, portata)
						else
							self:_muovi(u, { id = "ala" .. u.id, x = ala, y = b.y }, dt, 0)
						end
					else
						self:_muovi(u, b, dt, portata)
					end
				end
			end
		end
	end
	self:_separa()
	self:_arrivi(eventi)
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
