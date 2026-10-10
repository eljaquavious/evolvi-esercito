-- Partite della campagna: piazzamento delle carte del mazzo, battaglia automatica e ricompense.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage.Shared
local Battaglia = require(Shared.Battaglia)
local Modelli = require(Shared.Modelli)
local Campagna = require(Shared.Config.Campagna)
local Epoche = require(Shared.Config.Epoche)
local Arena = require(script.Parent.Arena)
local Dati = require(script.Parent.Dati)
local Lobby = require(script.Parent.Lobby)

local GestoreCampagna = {}

local TICK = 0.1
local MONETE_SCONFITTA = 10

local sessioni = {}
local remoti

local effetti = Instance.new("Folder")
effetti.Name = "Effetti"
effetti.Parent = workspace

local function teletrasporta(player, posizione, blocca)
	local character = player.Character
	local radice = character and character:FindFirstChild("HumanoidRootPart")
	if not radice then
		return
	end
	radice.Anchored = false
	character:PivotTo(CFrame.new(posizione))
	radice.Anchored = blocca
end

local function chiudiSessione(player)
	local sessione = sessioni[player]
	if not sessione then
		return
	end
	sessione.attiva = false
	Arena.distruggi(sessione.arena)
	sessioni[player] = nil
end

function GestoreCampagna.avvia(player)
	local dati = Dati.ottieni(player)
	if not dati then
		return false, "Loading your data, try again in a moment."
	end
	local esistente = sessioni[player]
	if esistente and esistente.fase == "battaglia" then
		return false, "You already have a battle in progress."
	end
	if #dati.mazzo == 0 then
		return false, "Your deck is empty: add some cards in the Army menu."
	end
	chiudiSessione(player)

	local livello = Campagna.livello(dati.livello)
	local arena = Arena.crea(player, livello)
	local sessione = {
		attiva = true,
		fase = "piazzamento",
		livello = livello,
		arena = arena,
		mazzo = table.clone(dati.mazzo),
		piazzate = {}, -- ["col,riga"] = { indice, tipo, modello, col, riga }
		usate = {}, -- indice del mazzo -> chiave della casella
		numero = 0,
	}
	sessioni[player] = sessione
	teletrasporta(player, arena.belvedere, true)

	remoti.Fase:FireClient(player, {
		fase = "piazzamento",
		livello = livello.numero,
		totale = Campagna.TOTALE,
		epoca = livello.epoca.nome,
		bioma = arena.bioma.nome,
		atmosfera = arena.bioma.atmosfera,
		maxReggimenti = livello.maxReggimenti,
		mazzo = sessione.mazzo,
		arena = arena.modello.Name,
		centro = arena.origine,
		righeGiocatore = Campagna.RIGHE_GIOCATORE,
	})
	return true
end

-- Indici del mazzo già sul campo, come lista (le tabelle sparse non passano bene tra server e client).
local function usate(sessione)
	local lista = {}
	for indice in pairs(sessione.usate) do
		table.insert(lista, indice)
	end
	return lista
end

-- Piazza la carta "indice" del mazzo sulla casella, o toglie il reggimento se la casella è già occupata.
function GestoreCampagna.casella(player, indice, col, riga)
	local sessione = sessioni[player]
	if not sessione or sessione.fase ~= "piazzamento" then
		return false, "You are not deploying troops right now."
	end
	if typeof(col) ~= "number" or typeof(riga) ~= "number" then
		return false, "Invalid tile."
	end
	col, riga = math.floor(col), math.floor(riga)
	if col < 1 or col > Arena.COLONNE or riga < 1 or riga > Campagna.RIGHE_GIOCATORE then
		return false, "You can only deploy on your half of the field."
	end
	for _, o in ipairs(sessione.livello.ostacoli) do
		if o.col == col and o.riga == riga then
			return false, "That tile is blocked."
		end
	end
	local chiave = col .. "," .. riga
	local occupata = sessione.piazzate[chiave]
	if occupata then
		occupata.modello:Destroy()
		sessione.piazzate[chiave] = nil
		sessione.usate[occupata.indice] = nil
		sessione.numero -= 1
		return true, nil, usate(sessione)
	end
	if typeof(indice) ~= "number" or not sessione.mazzo[indice] then
		return false, "Pick a card from your deck first."
	end
	if sessione.usate[indice] then
		return false, "That card is already on the field."
	end
	if sessione.numero >= sessione.livello.maxReggimenti then
		return false, "Maximum " .. sessione.livello.maxReggimenti .. " regiments in this level."
	end
	local tipo = sessione.mazzo[indice]
	local posizione = Arena.posizione(sessione.arena, col, riga)
	local modello = Modelli.reggimento(Epoche.Truppe[tipo], "giocatore", CFrame.lookAt(posizione, posizione + Vector3.zAxis))
	modello.Parent = sessione.arena.truppe
	sessione.piazzate[chiave] = { indice = indice, tipo = tipo, modello = modello, col = col, riga = riga }
	sessione.usate[indice] = chiave
	sessione.numero += 1
	return true, nil, usate(sessione)
end

-- Effetti visivi ----------------------------------------------------------

local function parteEffetto(proprieta)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for k, v in pairs(proprieta) do
		p[k] = v
	end
	p.Parent = effetti
	return p
end

local function proiettile(da, a, dimensione, colore, durata)
	local p = parteEffetto({
		Size = dimensione,
		Color = colore,
		CFrame = CFrame.lookAt(da, a),
	})
	TweenService:Create(p, TweenInfo.new(durata, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(a, a + (a - da)) }):Play()
	Debris:AddItem(p, durata + 0.05)
end

local function scintille(posizione, colore)
	for _ = 1, 4 do
		local p = parteEffetto({
			Size = Vector3.new(0.25, 0.25, 0.25),
			Color = colore,
			Position = posizione,
		})
		local direzione = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5).Unit * 2.5
		TweenService:Create(p, TweenInfo.new(0.25), { Position = posizione + direzione, Transparency = 1 }):Play()
		Debris:AddItem(p, 0.3)
	end
end

local function esplosione(posizione)
	local e = Instance.new("Explosion")
	e.Position = posizione
	e.BlastRadius = 5
	e.BlastPressure = 0
	e.DestroyJointRadiusPercent = 0
	e.ExplosionType = Enum.ExplosionType.NoCraters
	e.Parent = effetti
end

local function scritta(posizione, testo, colore, grande)
	local ancora = parteEffetto({ Size = Vector3.one * 0.2, Transparency = 1, Position = posizione })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(grande and 160 or 70, grande and 40 or 26)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = ancora
	local etichetta = Instance.new("TextLabel")
	etichetta.Size = UDim2.fromScale(1, 1)
	etichetta.BackgroundTransparency = 1
	etichetta.Text = testo
	etichetta.TextColor3 = colore
	etichetta.TextScaled = true
	etichetta.Font = Enum.Font.LuckiestGuy
	etichetta.TextStrokeTransparency = 0.2
	etichetta.Parent = gui
	TweenService:Create(ancora, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = posizione + Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(etichetta, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(ancora, 1)
end

local COLPI = {
	Arciere = function(da, a)
		proiettile(da, a, Vector3.new(0.12, 0.12, 2.2), Color3.fromRGB(170, 130, 80), 0.35)
		task.delay(0.12, proiettile, da + Vector3.new(1, 0, 0), a + Vector3.new(0.8, 0, 0.5), Vector3.new(0.12, 0.12, 2.2), Color3.fromRGB(170, 130, 80), 0.35)
	end,
	Fante = function(da, a)
		proiettile(da, a, Vector3.new(0.1, 0.1, 3), Color3.fromRGB(255, 230, 140), 0.12)
	end,
	Mitragliere = function(da, a)
		for i = 0, 2 do
			task.delay(i * 0.07, proiettile, da, a + Vector3.new(math.random() - 0.5, 0, math.random() - 0.5), Vector3.new(0.1, 0.1, 2.5), Color3.fromRGB(255, 220, 120), 0.1)
		end
	end,
	CarroArmato = function(da, a)
		proiettile(da, a, Vector3.new(0.6, 0.6, 1.2), Color3.fromRGB(255, 160, 60), 0.2)
		task.delay(0.2, esplosione, a)
	end,
}

local function mostraAttacco(arena, evento, attaccante, bersaglio)
	local altezza = Vector3.new(0, 2, 0)
	local da = Arena.posizione(arena, attaccante.x, attaccante.y) + altezza
	local a = Arena.posizione(arena, bersaglio.x, bersaglio.y) + altezza
	local colpo = COLPI[attaccante.def.id]
	if colpo and evento.distanza then
		colpo(da, a)
	else
		scintille(da:Lerp(a, 0.6), Color3.fromRGB(255, 240, 200))
	end
	if evento.carica then
		scritta(a + Vector3.new(0, 4, 0), "CHARGE!", Color3.fromRGB(255, 200, 60), true)
	end
	local colore = bersaglio.squadra == "giocatore" and Color3.fromRGB(255, 120, 120) or Color3.fromRGB(255, 255, 255)
	scritta(a + Vector3.new(math.random() * 2 - 1, 3, 0), "-" .. math.floor(evento.danno + 0.5), colore, false)
end

-- Battaglia ----------------------------------------------------------------

local function eseguiBattaglia(player, sessione)
	local livello = sessione.livello
	local arena = sessione.arena
	local unita, modelli = {}, {}

	local id = 0
	for _, piazzata in pairs(sessione.piazzate) do
		id += 1
		table.insert(unita, { id = id, squadra = "giocatore", def = Epoche.Truppe[piazzata.tipo], x = piazzata.col, y = piazzata.riga })
		modelli[id] = piazzata.modello
	end
	for i, nemico in ipairs(livello.nemici) do
		local idNemico = 100 + i
		local def = Epoche.Truppe[nemico.tipo]
		local posizione = Arena.posizione(arena, nemico.col, nemico.riga)
		local modello = Modelli.reggimento(def, "nemico", CFrame.lookAt(posizione, posizione - Vector3.zAxis))
		modello.Parent = arena.truppe
		modelli[idNemico] = modello
		table.insert(unita, { id = idNemico, squadra = "nemico", def = def, x = nemico.col, y = nemico.riga, forza = livello.forzaNemici })
	end

	local ostacoli = {}
	for _, o in ipairs(livello.ostacoli) do
		table.insert(ostacoli, { x = o.col, y = o.riga })
	end

	remoti.Fase:FireClient(player, { fase = "battaglia", conto = 3 })
	task.wait(3.2) -- conto alla rovescia sul client, intanto si vede lo schieramento nemico

	local battaglia = Battaglia.nuova(unita, { colonne = Arena.COLONNE, righe = Arena.RIGHE, ostacoli = ostacoli })
	local perId = {}
	for _, u in ipairs(battaglia.unita) do
		perId[u.id] = u
	end

	while sessione.attiva and not battaglia.finita do
		local eventi = battaglia:passo(TICK)
		for _, u in ipairs(battaglia.unita) do
			local modello = modelli[u.id]
			if u.vivo and modello and modello.PrimaryPart then
				local posizione = Arena.posizione(arena, u.x, u.y)
				local guarda = posizione + (u.squadra == "giocatore" and Vector3.zAxis or -Vector3.zAxis)
				if u.bersaglio then
					guarda = Arena.posizione(arena, u.bersaglio.x, u.bersaglio.y)
				end
				local cframe = CFrame.lookAt(posizione, Vector3.new(guarda.X, posizione.Y, guarda.Z))
				TweenService:Create(modello.PrimaryPart, TweenInfo.new(TICK, Enum.EasingStyle.Linear), { CFrame = cframe }):Play()
			end
		end
		for _, evento in ipairs(eventi) do
			if evento.tipo == "attacco" then
				local attaccante, bersaglio = perId[evento.da], perId[evento.a]
				mostraAttacco(arena, evento, attaccante, bersaglio)
				local colpiti = { evento.a }
				for _, v in ipairs(evento.area) do
					table.insert(colpiti, v.id)
				end
				for _, colpito in ipairs(colpiti) do
					local u = perId[colpito]
					if modelli[colpito] then
						Modelli.aggiornaVita(modelli[colpito], u.hp / u.hpMax)
					end
				end
			elseif evento.tipo == "morte" then
				local modello = modelli[evento.id]
				if modello then
					Modelli.aggiornaVita(modello, 0)
					Debris:AddItem(modello, 0.8)
					modelli[evento.id] = nil
				end
			end
		end
		task.wait(TICK)
	end

	if not sessione.attiva then
		return
	end

	local vittoria = battaglia.vincitore == "giocatore"
	local nemiciSconfitti, persi = 0, 0
	for _, u in ipairs(battaglia.unita) do
		if not u.vivo then
			if u.squadra == "nemico" then
				nemiciSconfitti += 1
			else
				persi += 1
			end
		end
	end

	local monete = vittoria and livello.ricompensa or MONETE_SCONFITTA
	local premio, nuovaEpoca
	Dati.modifica(player, function(dati)
		dati.monete += monete
		local s = dati.statistiche
		s.battaglie += 1
		s.moneteGuadagnate += monete
		s.reggimentiSconfitti += nemiciSconfitti
		s.reggimentiPersi += persi
		if vittoria then
			s.vittorie += 1
		else
			s.sconfitte += 1
		end
		if vittoria and livello.numero == dati.livello then
			premio = livello.cartaPremio
			Dati.aggiungiCarta(dati, premio)
			if dati.livello < Campagna.TOTALE then
				dati.livello += 1
				s.livelloMassimo = math.max(s.livelloMassimo, dati.livello)
				if livello.ultimoDellEpoca then
					-- L'esercito evolve: arrivano le carte iniziali della nuova epoca, che diventano il mazzo.
					local epoca = Campagna.livello(dati.livello).epoca
					nuovaEpoca = epoca.nome
					for _, tipo in ipairs(epoca.mazzoIniziale) do
						dati.collezione[tipo] = (dati.collezione[tipo] or 0) + 1
					end
					dati.mazzo = table.clone(epoca.mazzoIniziale)
				end
			else
				dati.campagnaCompletata = true
			end
		end
	end)
	sessione.fase = "risultato"
	remoti.Fase:FireClient(player, {
		fase = "risultato",
		vittoria = vittoria,
		monete = monete,
		premio = premio,
		nuovaEpoca = nuovaEpoca,
		sconfitti = nemiciSconfitti,
		persi = persi,
		completata = Dati.ottieni(player).campagnaCompletata,
	})
end

function GestoreCampagna.combatti(player)
	local sessione = sessioni[player]
	if not sessione or sessione.fase ~= "piazzamento" then
		return false, "You are not deploying troops right now."
	end
	if sessione.numero == 0 then
		return false, "Deploy at least one regiment first."
	end
	sessione.fase = "battaglia"
	task.spawn(eseguiBattaglia, player, sessione)
	return true
end

function GestoreCampagna.tornaLobby(player)
	chiudiSessione(player)
	teletrasporta(player, Lobby.SPAWN, false)
	remoti.Fase:FireClient(player, { fase = "lobby" })
	return true
end

function GestoreCampagna.giocatoreUscito(player)
	chiudiSessione(player)
end

function GestoreCampagna.inizializza(r)
	remoti = r
	remoti.AvviaCampagna.OnServerInvoke = GestoreCampagna.avvia
	remoti.Casella.OnServerInvoke = GestoreCampagna.casella
	remoti.Combatti.OnServerInvoke = GestoreCampagna.combatti
	remoti.TornaLobby.OnServerInvoke = GestoreCampagna.tornaLobby
end

return GestoreCampagna
