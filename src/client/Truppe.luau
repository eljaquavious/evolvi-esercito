-- I soldati sul campo, tutti disegnati e animati dal client.
-- Il server simula la battaglia (Shared/Battaglia) e manda qui, sul remoto "Truppe":
--   schieramento: i reggimenti del giocatore al loro posto nella formazione scelta (fermi);
--   inizio: tutti i soldati dei due eserciti al via; passo: posizioni ed eventi a ogni tick;
--   fine / pulisci: il campo si svuota.
-- Ogni soldato è un modello di Shared/Modelli mosso dolcemente verso l'ultima posizione ricevuta,
-- con l'animazione di Animatore (marcia, colpi, caduta) e i proiettili di Effetti.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Battaglia = require(Shared.Battaglia)
local Modelli = require(Shared.Modelli)
local Epoche = require(Shared.Config.Epoche)
local Animatore = require(script.Parent.Animatore)
local Effetti = require(script.Parent.Effetti)
local Suoni = require(script.Parent.Suoni)

local Truppe = {}

local CASELLA = 16
local SEGUI = 12 -- quanto in fretta il modello raggiunge la posizione ricevuta (1/s)
local ALTEZZA_COLPO = { cavalleria = 3.6, carro = 3, fortezza = 6 }

local cartella = Instance.new("Folder")
cartella.Name = "TruppeClient"
cartella.Parent = workspace

local campo = nil -- { origine, colonne, righe }
local schierati = {} -- "x,y:tipo" -> { soldati }
local soldati = {} -- id -> soldato in battaglia
local velocitaBattaglia = 0.75
local SOLDATI_PER_FRAME = 16
local numeroBattaglia = 0 -- per non svuotare una battaglia nuova con il ritardo della vecchia
local versioneSchieramento = 0 -- l'ultimo schieramento ricevuto: costruire i modelli può sospendere chi li riceve
local quote = {} -- cache delle quote del terreno per cella di 2 studs

local parametriTerreno = RaycastParams.new()
parametriTerreno.FilterType = Enum.RaycastFilterType.Include
parametriTerreno.FilterDescendantsInstances = { workspace.Terrain }
parametriTerreno.IgnoreWater = true

local function quota(x, z)
	local chiave = math.floor(x / 2) .. "," .. math.floor(z / 2)
	local q = quote[chiave]
	if not q then
		local colpo = workspace:Raycast(Vector3.new(x, campo.origine.Y + 120, z), Vector3.new(0, -260, 0), parametriTerreno)
		if not colpo then
			-- Terreno non ancora caricato: si riprova la prossima volta.
			return campo.origine.Y + 3
		end
		q = colpo.Position.Y
		quote[chiave] = q
	end
	return q
end

-- Punto a terra per coordinate del campo (colonna, riga), anche non intere.
local function punto(x, y)
	local wx = campo.origine.X + (x - (campo.colonne + 1) / 2) * CASELLA
	local wz = campo.origine.Z + (y - (campo.righe + 1) / 2) * CASELLA
	return Vector3.new(wx, quota(wx, wz), wz)
end

local function direzione(angolo)
	return Vector3.new(math.sin(angolo), 0, math.cos(angolo))
end

local function barraVita(s)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Vita"
	-- In pixel: da vicino non diventa enorme.
	gui.Size = UDim2.fromOffset(40, 6)
	gui.StudsOffset = Vector3.new(0, s.altezza + 0.9, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 160
	gui.Enabled = false
	local sfondo = Instance.new("Frame")
	sfondo.Size = UDim2.fromScale(1, 1)
	sfondo.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
	sfondo.BorderSizePixel = 0
	sfondo.Parent = gui
	local bordo = Instance.new("UIStroke")
	bordo.Color = Color3.fromRGB(0, 0, 0)
	bordo.Thickness = 1
	bordo.Parent = sfondo
	local riempimento = Instance.new("Frame")
	riempimento.Name = "Riempimento"
	riempimento.Size = UDim2.fromScale(1, 1)
	riempimento.BackgroundColor3 = Modelli.COLORI_SQUADRA[s.squadra]
	riempimento.BorderSizePixel = 0
	riempimento.Parent = sfondo
	gui.Parent = s.modello.PrimaryPart
	s.barra = gui
	s.riempimento = riempimento
end

local function nuovoSoldato(tipo, squadra, posizione, angolo)
	local def = Epoche.Truppe[tipo]
	local diametro = Battaglia.raggio(def) * 2 * CASELLA * (def.fortezza and 1.1 or 1.25)
	local cf = CFrame.lookAt(posizione, posizione + direzione(angolo))
	local modello, info = Modelli.crea(tipo, squadra, cf, { cerchio = diametro, comandante = def.comandante })
	modello.Parent = cartella
	local _, dimensione = modello:GetBoundingBox()
	local s = {
		tipo = tipo,
		def = def,
		squadra = squadra,
		modello = modello,
		animatore = Animatore.nuovo(modello, info, tipo),
		posizione = posizione,
		obiettivo = posizione,
		angolo = angolo,
		angoloObiettivo = angolo,
		altezza = math.min(dimensione.Y, 12),
		vivo = true,
		-- Le fortezze sono edifici: non si spostano e non si girano verso il bersaglio.
		fisso = def.fortezza == true,
	}
	s.altezzaColpo = ALTEZZA_COLPO[s.animatore.stile] or 2.4
	return s
end

local function togli(s, subito)
	if subito then
		s.modello:Destroy()
		return
	end
	-- Dissolvenza del corpo caduto.
	for _, p in ipairs(s.modello:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "Radice" then
			TweenService:Create(p, TweenInfo.new(1), { Transparency = 1 }):Play()
		end
	end
	task.delay(1.1, function()
		s.modello:Destroy()
	end)
end

local function svuotaSchierati()
	for _, gruppo in pairs(schierati) do
		for _, s in ipairs(gruppo) do
			togli(s, true)
		end
	end
	schierati = {}
end

-- Segnale rosso "TARGET" sopra il reggimento nemico scelto come bersaglio (sopra un suo soldato vivo).
local mira = { reggimento = nil, gui = nil }

local function aggiornaMira()
	if mira.gui then
		mira.gui:Destroy()
		mira.gui = nil
	end
	if not mira.reggimento then
		return
	end
	for idSoldato, s in pairs(soldati) do
		if s.vivo and idSoldato // 16 == mira.reggimento and s.modello.PrimaryPart then
			local gui = Instance.new("BillboardGui")
			gui.Name = "Mira"
			gui.AlwaysOnTop = true
			gui.Size = UDim2.fromOffset(110, 70)
			gui.StudsOffsetWorldSpace = Vector3.new(0, s.altezza + 4, 0)
			gui.LightInfluence = 0
			local testo = Instance.new("TextLabel")
			testo.BackgroundTransparency = 1
			testo.Size = UDim2.fromScale(1, 1)
			testo.Text = "TARGET\n▼"
			testo.TextScaled = true
			testo.Font = Enum.Font.FredokaOne
			testo.TextColor3 = Color3.fromRGB(255, 70, 60)
			local bordo = Instance.new("UIStroke")
			bordo.Thickness = 3
			bordo.Color = Color3.fromRGB(40, 10, 10)
			bordo.Parent = testo
			testo.Parent = gui
			gui.Adornee = s.modello.PrimaryPart
			gui.Parent = s.modello
			mira.gui = gui
			return
		end
	end
	mira.reggimento = nil -- del reggimento non resta nessuno
end

-- id del reggimento nemico da segnare, o nil per togliere il segnale.
function Truppe.segnaBersaglio(idReggimento)
	mira.reggimento = idReggimento
	aggiornaMira()
end

-- Il soldato vivo più vicino a un punto dello schermo (clic del mouse, in pixel del viewport), entro "raggio"
-- pixel: restituisce la sua squadra e l'id del suo reggimento, o nil.
function Truppe.reggimentoSulloSchermo(x, y, raggio)
	local camera = workspace.CurrentCamera
	local migliore, distanzaMin = nil, raggio or 60
	for _, s in pairs(soldati) do
		if s.vivo and s.id then
			local p, davanti = camera:WorldToViewportPoint(s.posizione + Vector3.new(0, s.altezza / 2, 0))
			if davanti then
				local d = math.sqrt((p.X - x) ^ 2 + (p.Y - y) ^ 2)
				if d < distanzaMin then
					migliore, distanzaMin = s, d
				end
			end
		end
	end
	if not migliore then
		return nil
	end
	return migliore.squadra, migliore.id // 16
end

local function svuotaBattaglia(subito)
	for _, s in pairs(soldati) do
		togli(s, subito)
	end
	soldati = {}
	mira.reggimento = nil
	aggiornaMira()
end

local function impostaCampo(dati)
	if not campo or campo.origine ~= dati.origine then
		quote = {}
	end
	campo = { origine = dati.origine, colonne = dati.colonne, righe = dati.righe }
end

-- Reggimenti del giocatore al loro posto durante lo schieramento.
local function schieramento(dati)
	impostaCampo(dati)
	versioneSchieramento += 1
	local versione = versioneSchieramento
	local visti = {}
	for _, r in ipairs(dati.reggimenti) do
		local chiave = ("%.2f,%.2f:%s"):format(r.x, r.y, r.tipo)
		visti[chiave] = true
		if not schierati[chiave] then
			local def = Epoche.Truppe[r.tipo]
			local gruppo = {}
			-- Segnato subito: costruire un modello per la prima volta sospende questa funzione, e nel
			-- frattempo può arrivare un altro schieramento (che non deve rifare lo stesso gruppo) o l'inizio
			-- della battaglia (che lo toglie).
			schierati[chiave] = gruppo
			-- Il generale con la sua guardia del corpo, come in battaglia.
			for _, posto in ipairs(Battaglia.composizione(def)) do
				local s = nuovoSoldato(posto.def.id, "giocatore", punto(r.x + posto.x, r.y + posto.y), 0)
				if schierati[chiave] ~= gruppo then
					togli(s, true)
					break
				end
				table.insert(gruppo, s)
			end
		end
	end
	-- Se intanto è arrivato uno schieramento più recente, è lui a dire quali gruppi restano.
	if versione ~= versioneSchieramento then
		return
	end
	for chiave, gruppo in pairs(schierati) do
		if not visti[chiave] then
			for _, s in ipairs(gruppo) do
				togli(s, true)
			end
			schierati[chiave] = nil
		end
	end
end

-- Centro dei soldati vivi di un reggimento (nil se non ne restano).
local function centroReggimento(id)
	local somma, n = Vector3.zero, 0
	for idSoldato, s in pairs(soldati) do
		if s.vivo and idSoldato // 16 == id then
			somma += s.posizione
			n += 1
		end
	end
	return n > 0 and somma / n or nil
end

-- Centro dei soldati vivi di una squadra (nil se non ne restano).
local function centroSquadra(squadra)
	local somma, n = Vector3.zero, 0
	for _, s in pairs(soldati) do
		if s.vivo and s.squadra == squadra then
			somma += s.posizione
			n += 1
		end
	end
	return n > 0 and somma / n or nil
end

local function inizio(dati)
	impostaCampo(dati)
	svuotaSchierati()
	svuotaBattaglia(true)
	Effetti.pulisci()
	numeroBattaglia += 1
	local numero = numeroBattaglia
	velocitaBattaglia = dati.velocita or 0.75
	for i, d in ipairs(dati.soldati) do
		local angolo = d.squadra == "giocatore" and 0 or math.pi
		local s = nuovoSoldato(d.tipo, d.squadra, punto(d.x, d.y), angolo)
		if numero ~= numeroBattaglia then
			-- Mentre si costruiva il modello il campo è stato svuotato o è partita un'altra battaglia.
			togli(s, true)
			return
		end
		s.id = d.id
		s.hpMax = d.hp
		s.hp = d.hp
		barraVita(s)
		soldati[d.id] = s
		-- Nelle epoche antiche i reggimenti hanno fino a 8 uomini: crearli tutti nello stesso frame blocca il
		-- client per un attimo. Si creano a blocchi durante il conto alla rovescia, che dura più di tre secondi.
		if i % SOLDATI_PER_FRAME == 0 then
			task.wait()
			if numero ~= numeroBattaglia then
				return
			end
		end
	end
end

local function puntoColpo(s)
	return s.posizione + Vector3.new(0, s.altezzaColpo, 0)
end

-- Proiettile del tipo giusto, che parte alla fine del gesto.
-- Proiettili diversi da quelli dello stile di animazione: fionde e balestre (che mirano come un fucile).
local PROIETTILI = {
	FrombolieroBaleare = "sasso",
	BalestriereTeutonico = "dardo",
	BalestriereGenovese = "dardo",
}

local function tiro(attaccante, bersaglio, evento)
	local gesto = evento.gesto / velocitaBattaglia
	local volo = math.max(0.05, (evento.ritardo - evento.gesto) / velocitaBattaglia)
	local stile = attaccante.animatore.stile
	task.delay(gesto, function()
		if not attaccante.modello.Parent then
			return
		end
		local da = attaccante.animatore:puntoTiro()
		local a = puntoColpo(bersaglio) + Vector3.new(math.random() - 0.5, math.random() * 0.6 - 0.3, math.random() - 0.5)
		if evento.colpo == "lancio" then
			attaccante.animatore:lasciaLancia()
			Effetti.pilum(da, a, volo)
			Suoni.effetto("freccia", da)
		elseif stile == "arco" then
			Effetti.freccia(da, a, volo)
			Suoni.effetto("freccia", da)
		elseif stile == "fortezza" then
			-- Le fortezze hanno i punti di tiro (torri, feritoie) come Attachment "Tiro" (Modelli).
			if not attaccante.tiri then
				attaccante.tiri = {}
				for _, d in ipairs(attaccante.modello:GetDescendants()) do
					if d:IsA("Attachment") and d.Name == "Tiro" then
						table.insert(attaccante.tiri, d)
					end
				end
			end
			local tiri = attaccante.tiri
			local cima = #tiri > 0 and tiri[math.random(#tiri)].WorldPosition
				or attaccante.posizione + Vector3.new(math.random() * 8 - 4, attaccante.altezza * 0.8, math.random() * 8 - 4)
			if attaccante.tipo == "FortezzaNovecento" then
				Effetti.sparo(cima, a, volo)
				Suoni.effetto("sparo", cima)
			else
				Effetti.freccia(cima, a, volo)
				Suoni.effetto("freccia", cima)
			end
		elseif PROIETTILI[attaccante.tipo] == "sasso" then
			Effetti.sasso(da, a, volo)
			Suoni.effetto("freccia", da)
		elseif PROIETTILI[attaccante.tipo] == "dardo" then
			Effetti.freccia(da, a, volo)
			Suoni.effetto("freccia", da)
		elseif stile == "carro" then
			-- Carri e cannoni: dalla bocca del cannone (osso "canna"), con il colpo che rimbomba.
			local bocca = attaccante.animatore.giunti.canna and da
				or attaccante.posizione + direzione(attaccante.angolo) * 6 + Vector3.new(0, 4, 0)
			Effetti.granata(bocca, bersaglio.posizione, volo)
			Suoni.effetto("cannonata", bocca)
		elseif stile == "mitragliatrice" then
			for i = 0, 2 do
				task.delay(i * 0.06, Effetti.sparo, da, a + Vector3.new(math.random() - 0.5, 0, math.random() - 0.5), volo)
			end
			Suoni.effetto("raffica", da)
		else
			Effetti.sparo(da, a, volo)
			Suoni.effetto("sparo", da)
		end
	end)
end

local function evento(e)
	if e.tipo == "attacco" then
		local attaccante, bersaglio = soldati[e.da], soldati[e.a]
		if not attaccante or not bersaglio then
			return
		end
		attaccante.animatore:attacca(e.colpo, e.gesto / velocitaBattaglia)
		if e.colpo == "mischia" then
			task.delay(e.gesto / velocitaBattaglia, function()
				if attaccante.vivo then
					local punto = attaccante.posizione:Lerp(bersaglio.posizione, 0.6) + Vector3.new(0, 2.2, 0)
					Effetti.scintille(punto)
					Suoni.effetto("spada", punto)
					-- Grida durante la mischia: qualche soldato urla colpendo, ogni tanto tutto il reparto.
					local caso = math.random()
					if caso < 0.18 then
						Suoni.effetto("urlo", attaccante.posizione)
					elseif caso < 0.24 then
						Suoni.effetto("grido", attaccante.posizione)
					end
				end
			end)
		else
			tiro(attaccante, bersaglio, e)
			-- Anche i fanti che sparano o lanciano gridano, ogni tanto.
			if attaccante.def.classe == "Fanteria" and math.random() < 0.08 then
				Suoni.effetto("urlo", attaccante.posizione)
			end
		end
		if e.carica then
			Effetti.scritta(puntoColpo(bersaglio) + Vector3.new(0, 3, 0), "CHARGE!", Color3.fromRGB(255, 200, 60), true)
			Suoni.effetto("grido", attaccante.posizione)
		end
	elseif e.tipo == "colpo" then
		local colpiti = { { id = e.a, danno = e.danno } }
		for _, v in ipairs(e.area or {}) do
			table.insert(colpiti, v)
		end
		for _, c in ipairs(colpiti) do
			local s = soldati[c.id]
			if s then
				s.hp = math.max(0, s.hp - c.danno)
				s.animatore:ferito()
				if s.barra then
					s.barra.Enabled = s.hp > 0 and s.hp < s.hpMax
					s.riempimento.Size = UDim2.fromScale(s.hp / s.hpMax, 1)
				end
				if c.danno >= 25 then
					local colore = s.squadra == "giocatore" and Color3.fromRGB(255, 120, 120) or Color3.fromRGB(255, 255, 255)
					Effetti.scritta(puntoColpo(s) + Vector3.new(0, 1.5, 0), "-" .. math.floor(c.danno + 0.5), colore, false)
				end
			end
		end
	elseif e.tipo == "ordine" then
		-- Ordine generale: il grido sopra l'armata che lo riceve.
		local centro = centroSquadra(e.squadra)
		local nome = Battaglia.NOMI_ORDINI[e.ordine]
		if centro and nome then
			local colore = e.squadra == "giocatore" and Color3.fromRGB(120, 200, 255) or Color3.fromRGB(255, 110, 100)
			Effetti.scritta(centro + Vector3.new(0, 9, 0), nome.grido, colore, true)
			Suoni.effetto("grido", centro)
		end
	elseif e.tipo == "abilita" then
		local centro = centroReggimento(e.reggimento)
		local def = Epoche.Truppe[e.tipoCarta]
		if centro and def and def.abilita then
			Effetti.scritta(centro + Vector3.new(0, 8, 0), string.upper(def.abilita.nome) .. "!", Color3.fromRGB(255, 210, 70), true)
		end
		-- Scintille dorate su tutti i soldati della squadra che ricevono il bonus.
		for _, s in pairs(soldati) do
			if s.vivo and s.squadra == e.squadra then
				Effetti.scintille(s.posizione + Vector3.new(0, s.altezzaColpo, 0), Color3.fromRGB(255, 214, 90))
			end
		end
	elseif e.tipo == "morte" then
		local s = soldati[e.id]
		if s and s.vivo then
			s.vivo = false
			s.animatore:muori()
			-- Uomini che cadono: un grido; carri e fortezze esplodono.
			if s.fisso or s.animatore.stile == "carro" then
				Suoni.effetto("esplosione", s.posizione)
			else
				Suoni.effetto("morte", s.posizione + Vector3.new(0, 2, 0))
			end
			if s.barra then
				s.barra.Enabled = false
			end
			if mira.reggimento == e.id // 16 and mira.gui and mira.gui.Parent == s.modello then
				aggiornaMira() -- il segnale passa a un altro soldato del reggimento
			end
			task.delay(4, function()
				if soldati[e.id] == s then
					soldati[e.id] = nil
					togli(s)
				end
			end)
		end
	end
end

-- Posizioni dal server: per ogni soldato vivo id (u16), x e y (u16, millesimi di casella), angolo (u8).
local function passo(dati)
	local b = dati.posizioni
	local n = buffer.readu16(b, 0)
	for i = 0, n - 1 do
		local o = 2 + i * 7
		local s = soldati[buffer.readu16(b, o)]
		if s and s.vivo and not s.fisso then
			s.obiettivo = punto(buffer.readu16(b, o + 2) / 1000, buffer.readu16(b, o + 4) / 1000)
			s.angoloObiettivo = buffer.readu8(b, o + 6) / 256 * 2 * math.pi
		end
	end
	for _, e in ipairs(dati.eventi) do
		evento(e)
	end
end

local function angoloVerso(attuale, obiettivo, t)
	local d = (obiettivo - attuale + math.pi) % (2 * math.pi) - math.pi
	return attuale + d * t
end

local function aggiorna(s, dt, t)
	local prima = s.posizione
	if s.vivo then
		s.posizione = prima:Lerp(s.obiettivo, t)
		s.angolo = angoloVerso(s.angolo, s.angoloObiettivo, t)
	end
	local orizzontale = Vector3.new(s.posizione.X - prima.X, 0, s.posizione.Z - prima.Z)
	local velocita = dt > 0 and orizzontale.Magnitude / dt or 0
	s.animatore:aggiorna(dt, velocita)
	s.modello.PrimaryPart.CFrame = CFrame.lookAt(s.posizione, s.posizione + direzione(s.angolo))
end

RunService.RenderStepped:Connect(function(dt)
	local t = 1 - math.exp(-SEGUI * dt)
	for _, s in pairs(soldati) do
		aggiorna(s, dt, t)
	end
	for _, gruppo in pairs(schierati) do
		for _, s in ipairs(gruppo) do
			-- Se il terreno è arrivato dopo lo schieramento (streaming), si rimettono i piedi a terra.
			if campo then
				local o = s.obiettivo
				s.obiettivo = Vector3.new(o.X, quota(o.X, o.Z), o.Z)
			end
			aggiorna(s, dt, t)
		end
	end
end)

-- Centro dei superstiti di una squadra, per la cinematica tra i round (nil se non ne restano).
function Truppe.centro(squadra)
	return centroSquadra(squadra)
end

-- Il soldato di un tipo (il boss) in campo: posizione, angolo e se è vivo; nil se non c'è (ancora) o è già
-- stato tolto. Serve alla cinematica tra i round dei livelli con un comandante.
function Truppe.soldato(tipo, squadra)
	local trovato
	for _, s in pairs(soldati) do
		if s.tipo == tipo and s.squadra == squadra and (not trovato or (s.vivo and not trovato.vivo)) then
			trovato = s
		end
	end
	if not trovato then
		return nil
	end
	return { posizione = trovato.posizione, angolo = trovato.angolo, vivo = trovato.vivo, altezza = trovato.altezza }
end

-- Cinematica tra i round: i superstiti della squadra sconfitta ripiegano verso le loro retrovie, gli altri
-- restano e li guardano andare via. tipoFermo = un tipo (il boss in primo piano) che resta dov'è.
function Truppe.ritirata(squadra, durata, tipoFermo)
	if not campo then
		return
	end
	local indietro = squadra == "giocatore" and -1 or 1
	local numero = numeroBattaglia
	-- Niente barre della vita: da vicino coprono l'inquadratura.
	for _, s in pairs(soldati) do
		if s.barra then
			s.barra.Enabled = false
		end
		if tipoFermo and s.tipo == tipoFermo and s.vivo then
			s.obiettivo = s.posizione
			s.angoloObiettivo = s.angolo
			s.fermoIntermezzo = true
		end
	end
	local inizio = os.clock()
	task.spawn(function()
		while os.clock() - inizio < durata and numero == numeroBattaglia do
			for _, s in pairs(soldati) do
				if s.vivo and s.squadra == squadra and not s.fisso and not s.fermoIntermezzo then
					s.obiettivo = s.obiettivo + Vector3.new(0, 0, indietro * CASELLA * 0.035)
					s.obiettivo = Vector3.new(s.obiettivo.X, quota(s.obiettivo.X, s.obiettivo.Z), s.obiettivo.Z)
					s.angoloObiettivo = indietro > 0 and 0 or math.pi
				end
			end
			task.wait(0.05)
		end
	end)
end

function Truppe.inizializza(remoti)
	remoti.Truppe.OnClientEvent:Connect(function(dati)
		if dati.tipo == "schieramento" then
			schieramento(dati)
		elseif dati.tipo == "inizio" then
			inizio(dati)
		elseif dati.tipo == "passo" then
			passo(dati)
		elseif dati.tipo == "fine" then
			local numero = numeroBattaglia
			task.delay(1.2, function()
				if numero == numeroBattaglia then
					svuotaBattaglia(false)
				end
			end)
		elseif dati.tipo == "pulisci" then
			numeroBattaglia += 1
			svuotaSchierati()
			svuotaBattaglia(true)
			Effetti.pulisci()
		end
	end)
end

return Truppe
