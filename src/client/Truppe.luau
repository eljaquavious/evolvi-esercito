-- I soldati sul campo, tutti disegnati e animati dal client.
-- Il server simula la battaglia (Shared/Battaglia) e manda qui, sul remoto "Truppe":
--   schieramento: i reggimenti del giocatore piazzati sulle caselle (fermi, in formazione);
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

local Truppe = {}

local CASELLA = 16
local SEGUI = 12 -- quanto in fretta il modello raggiunge la posizione ricevuta (1/s)
local ALTEZZA_COLPO = { cavalleria = 3.6, carro = 3, fortezza = 6 }

local cartella = Instance.new("Folder")
cartella.Name = "TruppeClient"
cartella.Parent = workspace

local campo = nil -- { origine, colonne, righe }
local schierati = {} -- chiave casella -> { soldati }
local soldati = {} -- id -> soldato in battaglia
local velocitaBattaglia = 0.75
local numeroBattaglia = 0 -- per non svuotare una battaglia nuova con il ritardo della vecchia
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
	gui.Size = UDim2.new(2.6, 0, 0.32, 0)
	gui.StudsOffset = Vector3.new(0, s.altezza + 0.9, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 220
	gui.Enabled = false
	local sfondo = Instance.new("Frame")
	sfondo.Size = UDim2.fromScale(1, 1)
	sfondo.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
	sfondo.BorderSizePixel = 0
	sfondo.Parent = gui
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

local function svuotaBattaglia(subito)
	for _, s in pairs(soldati) do
		togli(s, subito)
	end
	soldati = {}
end

local function impostaCampo(dati)
	if not campo or campo.origine ~= dati.origine then
		quote = {}
	end
	campo = { origine = dati.origine, colonne = dati.colonne, righe = dati.righe }
end

-- Reggimenti del giocatore sulle caselle durante lo schieramento.
local function schieramento(dati)
	impostaCampo(dati)
	local visti = {}
	for _, r in ipairs(dati.reggimenti) do
		local chiave = r.col .. "," .. r.riga .. ":" .. r.tipo
		visti[chiave] = true
		if not schierati[chiave] then
			local def = Epoche.Truppe[r.tipo]
			local gruppo = {}
			for _, offset in ipairs(Battaglia.formazione(def.soldati, def)) do
				local s = nuovoSoldato(r.tipo, "giocatore", punto(r.col + offset[1], r.riga + offset[2]), 0)
				table.insert(gruppo, s)
			end
			schierati[chiave] = gruppo
		end
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

local function inizio(dati)
	impostaCampo(dati)
	svuotaSchierati()
	svuotaBattaglia(true)
	Effetti.pulisci()
	numeroBattaglia += 1
	velocitaBattaglia = dati.velocita or 0.75
	for _, d in ipairs(dati.soldati) do
		local angolo = d.squadra == "giocatore" and 0 or math.pi
		local s = nuovoSoldato(d.tipo, d.squadra, punto(d.x, d.y), angolo)
		s.id = d.id
		s.hpMax = d.hp
		s.hp = d.hp
		barraVita(s)
		soldati[d.id] = s
	end
end

local function puntoColpo(s)
	return s.posizione + Vector3.new(0, s.altezzaColpo, 0)
end

-- Proiettile del tipo giusto, che parte alla fine del gesto.
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
		elseif stile == "arco" then
			Effetti.freccia(da, a, volo)
		elseif stile == "fortezza" then
			local cima = attaccante.posizione + Vector3.new(math.random() * 8 - 4, attaccante.altezza * 0.8, math.random() * 8 - 4)
			if attaccante.tipo == "FortezzaNovecento" then
				Effetti.sparo(cima, a, volo)
			else
				Effetti.freccia(cima, a, volo)
			end
		elseif stile == "carro" then
			Effetti.granata(attaccante.posizione + direzione(attaccante.angolo) * 6 + Vector3.new(0, 4, 0), bersaglio.posizione, volo)
		elseif stile == "mitragliatrice" then
			for i = 0, 2 do
				task.delay(i * 0.06, Effetti.sparo, da, a + Vector3.new(math.random() - 0.5, 0, math.random() - 0.5), volo)
			end
		else
			Effetti.sparo(da, a, volo)
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
					Effetti.scintille(attaccante.posizione:Lerp(bersaglio.posizione, 0.6) + Vector3.new(0, 2.2, 0))
				end
			end)
		else
			tiro(attaccante, bersaglio, e)
		end
		if e.carica then
			Effetti.scritta(puntoColpo(bersaglio) + Vector3.new(0, 3, 0), "CHARGE!", Color3.fromRGB(255, 200, 60), true)
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
	elseif e.tipo == "morte" then
		local s = soldati[e.id]
		if s and s.vivo then
			s.vivo = false
			s.animatore:muori()
			if s.barra then
				s.barra.Enabled = false
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
		if s and s.vivo then
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
			aggiorna(s, dt, t)
		end
	end
end)

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
			svuotaSchierati()
			svuotaBattaglia(true)
			Effetti.pulisci()
		end
	end)
end

return Truppe
