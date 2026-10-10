-- Partite della campagna: mappa, piazzamento delle carte del mazzo, round al meglio di 5 con battaglie
-- automatiche, assedio della fortezza nemica sul match point, stelle e ricompense.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage.Shared
local Battaglia = require(Shared.Battaglia)
local Modelli = require(Shared.Modelli)
local Campagna = require(Shared.Config.Campagna)
local Epoche = require(Shared.Config.Epoche)
local Progressi = require(Shared.Config.Progressi)
local Arena = require(script.Parent.Arena)
local Dati = require(script.Parent.Dati)
local Lobby = require(script.Parent.Lobby)
local MappaCampagna = require(script.Parent.MappaCampagna)

local GestoreCampagna = {}

local TICK = 0.1
-- Secondi di battaglia simulati per ogni secondo reale: sotto 1 la battaglia si gode di più, senza cambiare il bilanciamento.
local VELOCITA_BATTAGLIA = 0.75
local PAUSA_TRA_ROUND = 2.8

local sessioni = {}
local remoti

local effetti = Instance.new("Folder")
effetti.Name = "Effetti"
effetti.Parent = workspace

-- destinazione: Vector3 o CFrame (che dice anche dove guardare).
local function teletrasporta(player, destinazione, blocca)
	local character = player.Character
	local radice = character and character:FindFirstChild("HumanoidRootPart")
	if not radice then
		return
	end
	radice.Anchored = false
	character:PivotTo(typeof(destinazione) == "CFrame" and destinazione or CFrame.new(destinazione))
	radice.AssemblyLinearVelocity = Vector3.zero
	radice.Anchored = blocca
end

local function chiudiSessione(player)
	local sessione = sessioni[player]
	if not sessione then
		return
	end
	sessione.attiva = false
	if sessione.arena then
		Arena.distruggi(sessione.arena)
	end
	sessioni[player] = nil
end

-- Indici del mazzo già sul campo, come lista (le tabelle sparse non passano bene tra server e client).
local function usate(sessione)
	local lista = {}
	for indice in pairs(sessione.usate) do
		table.insert(lista, indice)
	end
	return lista
end

local function modelloGiocatore(sessione, tipo, col, riga)
	local posizione = Arena.posizione(sessione.arena, col, riga)
	local modello = Modelli.reggimento(Epoche.Truppe[tipo], "giocatore", CFrame.lookAt(posizione, posizione + Vector3.zAxis))
	modello.Parent = sessione.arena.truppe
	return modello
end

-- Inizio di un round: rimette i reggimenti dove erano nel round prima e manda al client il resoconto degli esploratori.
local function inizioRound(player, sessione)
	local livello = sessione.livello
	sessione.fase = "piazzamento"
	sessione.assedio = sessione.vinti == Campagna.ROUND_PER_VINCERE - 1 and sessione.persi < Campagna.ROUND_PER_VINCERE - 1
	sessione.armata = Campagna.armata(livello, sessione.round, sessione.assedio)
	for _, piazzata in pairs(sessione.piazzate) do
		piazzata.modello = modelloGiocatore(sessione, piazzata.tipo, piazzata.col, piazzata.riga)
	end
	Arena.mostraCaselle(sessione.arena, true)
	local esploratori = {}
	for _, nemico in ipairs(sessione.armata) do
		table.insert(esploratori, nemico.tipo)
	end
	remoti.Fase:FireClient(player, {
		fase = "piazzamento",
		livello = livello.numero,
		totale = Campagna.TOTALE,
		nome = livello.nome,
		anno = livello.anno,
		epoca = livello.epoca.nome,
		bioma = sessione.arena.bioma.nome,
		atmosfera = sessione.arena.bioma.atmosfera,
		maxReggimenti = livello.maxReggimenti,
		mazzo = sessione.mazzo,
		usate = usate(sessione),
		arena = sessione.arena.modello.Name,
		centro = sessione.arena.origine,
		righeGiocatore = Campagna.RIGHE_GIOCATORE,
		round = sessione.round,
		vinti = sessione.vinti,
		persi = sessione.persi,
		perVincere = Campagna.ROUND_PER_VINCERE,
		assedio = sessione.assedio,
		esploratori = esploratori,
		fiume = sessione.arena.rigaFiume ~= nil,
	})
end

-- numero: livello da giocare; senza, il prossimo livello non ancora vinto.
function GestoreCampagna.avvia(player, numero)
	local dati = Dati.ottieni(player)
	if not dati then
		return false, "Loading your data, try again in a moment."
	end
	local esistente = sessioni[player]
	if esistente and (esistente.fase == "battaglia" or esistente.fase == "costruzione") then
		return false, "You already have a battle in progress."
	end
	if #dati.mazzo == 0 then
		return false, "Your deck is empty: add some cards in the Army menu."
	end
	if typeof(numero) ~= "number" then
		numero = dati.livello
	end
	numero = math.floor(numero)
	if numero < 1 or numero > math.min(dati.livello, Campagna.TOTALE) then
		return false, "Win the previous battles to unlock this one."
	end
	chiudiSessione(player)

	-- Il campo si costruisce in qualche istante: intanto la sessione esiste già, così un secondo
	-- clic non ne apre un'altra e se il giocatore esce il campo viene distrutto.
	local livello = Campagna.livello(numero)
	local sessione = {
		attiva = true,
		fase = "costruzione",
		livello = livello,
		mazzo = table.clone(dati.mazzo),
		piazzate = {}, -- ["col,riga"] = { indice, tipo, modello, col, riga }
		usate = {}, -- indice del mazzo -> chiave della casella
		numero = 0,
		round = 1,
		vinti = 0,
		persi = 0,
		sconfitti = 0,
		caduti = 0,
	}
	sessioni[player] = sessione
	local arena = Arena.crea(player, livello)
	if not sessione.attiva or sessioni[player] ~= sessione or not player.Parent then
		Arena.distruggi(arena)
		return false
	end
	sessione.arena = arena
	sessione.fase = "piazzamento"
	-- Il giocatore entra nel campo a piedi: si muove liberamente anche durante la battaglia.
	teletrasporta(player, arena.arrivo, false)
	inizioRound(player, sessione)
	return true
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
	if Campagna.bloccata(sessione.livello, col, riga) then
		return false, "You can't deploy there."
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
		return false, "Maximum " .. sessione.livello.maxReggimenti .. " regiments in this battle."
	end
	local tipo = sessione.mazzo[indice]
	sessione.piazzate[chiave] = { indice = indice, tipo = tipo, modello = modelloGiocatore(sessione, tipo, col, riga), col = col, riga = riga }
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

-- Raffica di frecce ad arco: più frecce sparse attorno al bersaglio.
local function frecce(da, a, numero)
	for i = 1, numero do
		local scarto = Vector3.new(math.random() * 3 - 1.5, 0, math.random() * 3 - 1.5)
		local partenza = da + Vector3.new(math.random() * 2 - 1, 0, 0)
		task.delay((i - 1) * 0.06, proiettile, partenza, a + scarto, Vector3.new(0.22, 0.22, 2.8), Color3.fromRGB(240, 220, 170), 0.4)
	end
end

local function sparo(da, a)
	proiettile(da, a, Vector3.new(0.12, 0.12, 3), Color3.fromRGB(255, 230, 140), 0.12)
end

local function raffica(da, a)
	for i = 0, 2 do
		task.delay(i * 0.07, proiettile, da, a + Vector3.new(math.random() - 0.5, 0, math.random() - 0.5), Vector3.new(0.12, 0.12, 2.5), Color3.fromRGB(255, 220, 120), 0.1)
	end
end

local COLPI = {
	Arciere = function(da, a)
		frecce(da, a, 4)
	end,
	ArciereCretese = function(da, a)
		frecce(da, a, 4)
	end,
	FortezzaAntica = function(da, a)
		frecce(da + Vector3.new(0, 4, 0), a, 3)
	end,
	FortezzaMedievale = function(da, a)
		frecce(da + Vector3.new(0, 5, 0), a, 4)
	end,
	FortezzaNovecento = raffica,
	Fante = sparo,
	Foch = sparo,
	DeGaulle = sparo,
	Mitragliere = raffica,
	CarroArmato = function(da, a)
		proiettile(da, a, Vector3.new(0.6, 0.6, 1.2), Color3.fromRGB(255, 160, 60), 0.2)
		task.delay(0.2, esplosione, a)
	end,
}

local function mostraAttacco(arena, evento, attaccante, bersaglio)
	local altezza = Vector3.new(0, 2.6, 0)
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

-- Combatte un round; restituisce true se l'ha vinto il giocatore (nil se la sessione è stata chiusa).
local function combattiRound(player, sessione)
	local livello = sessione.livello
	local arena = sessione.arena
	local unita, modelli = {}, {}

	local id = 0
	for _, piazzata in pairs(sessione.piazzate) do
		id += 1
		table.insert(unita, { id = id, squadra = "giocatore", def = Epoche.Truppe[piazzata.tipo], x = piazzata.col, y = piazzata.riga })
		modelli[id] = piazzata.modello
	end
	for i, nemico in ipairs(sessione.armata) do
		local idNemico = 100 + i
		local def = Epoche.Truppe[nemico.tipo]
		local posizione = Arena.posizione(arena, nemico.col, nemico.riga)
		local modello = Modelli.reggimento(def, "nemico", CFrame.lookAt(posizione, posizione - Vector3.zAxis))
		modello.Parent = arena.truppe
		modelli[idNemico] = modello
		table.insert(unita, {
			id = idNemico,
			squadra = "nemico",
			def = def,
			x = nemico.col,
			y = nemico.riga,
			forza = Campagna.forza(livello, sessione.round, nemico.tipo),
		})
	end

	local ostacoli, terreno = {}, {}
	for _, t in ipairs(livello.terreno) do
		if t.tipo == "ostacolo" then
			table.insert(ostacoli, { x = t.col, y = t.riga })
		elseif t.tipo == "fiume" or t.tipo == "collina" then
			terreno[t.col .. "," .. t.riga] = t.tipo
		end
	end

	Arena.mostraCaselle(arena, false)
	remoti.Fase:FireClient(player, { fase = "battaglia", conto = 3, assedio = sessione.assedio })
	task.wait(3.2) -- conto alla rovescia sul client, intanto si vede lo schieramento nemico
	if not sessione.attiva then
		return nil
	end

	local battaglia = Battaglia.nuova(unita, { colonne = Arena.COLONNE, righe = Arena.RIGHE, ostacoli = ostacoli, terreno = terreno })
	local perId = {}
	for _, u in ipairs(battaglia.unita) do
		perId[u.id] = u
	end

	while sessione.attiva and not battaglia.finita do
		local eventi = battaglia:passo(TICK * VELOCITA_BATTAGLIA)
		for _, u in ipairs(battaglia.unita) do
			local modello = modelli[u.id]
			-- Le fortezze non si muovono e non si girano.
			if u.vivo and modello and modello.PrimaryPart and not u.def.fortezza then
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
		return nil
	end

	for _, u in ipairs(battaglia.unita) do
		if not u.vivo then
			if u.squadra == "nemico" then
				sessione.sconfitti += 1
			else
				sessione.caduti += 1
			end
		end
	end
	-- Il campo si svuota: i reggimenti tornano al loro posto all'inizio del prossimo round.
	task.wait(1)
	for _, modello in pairs(modelli) do
		modello:Destroy()
	end
	for _, piazzata in pairs(sessione.piazzate) do
		piazzata.modello = nil
	end
	return battaglia.vincitore == "giocatore"
end

-- Fine del livello: stelle, monete, esperienza, carta premio, avanzamento.
local function fineLivello(player, sessione)
	local livello = sessione.livello
	local vittoria = sessione.vinti >= Campagna.ROUND_PER_VINCERE
	local stelle = vittoria and Campagna.stelle(sessione.persi) or 0
	local dati = Dati.ottieni(player)
	local stellePrima = Dati.stelle(dati, livello.numero)
	-- Rigiocare un livello già vinto rende metà monete.
	local monete = vittoria and livello.ricompensa or 15 + 5 * sessione.vinti
	if stellePrima > 0 then
		monete = math.floor(monete / 2)
	end
	local esperienza = sessione.vinti * Progressi.XP_ROUND_VINTO + sessione.persi * Progressi.XP_ROUND_PERSO
		+ (vittoria and Progressi.XP_LIVELLO_VINTO or 0)
	local livelloPrima = Progressi.livello(dati.esperienza)
	local premio, nuovaEpoca
	Dati.modifica(player, function(d)
		d.monete += monete
		d.esperienza += esperienza
		local s = d.statistiche
		s.battaglie += 1
		s.moneteGuadagnate += monete
		s.reggimentiSconfitti += sessione.sconfitti
		s.reggimentiPersi += sessione.caduti
		if vittoria then
			s.vittorie += 1
		else
			s.sconfitte += 1
		end
		if stelle > stellePrima then
			d.stelle[tostring(livello.numero)] = stelle
		end
		if vittoria and livello.numero == d.livello then
			premio = livello.cartaPremio
			Dati.aggiungiCarta(d, premio)
			if d.livello < Campagna.TOTALE then
				d.livello += 1
				s.livelloMassimo = math.max(s.livelloMassimo, d.livello)
				if livello.ultimoDellEpoca then
					-- L'esercito evolve: arrivano le carte iniziali della nuova epoca, che diventano il mazzo.
					local epoca = Campagna.livello(d.livello).epoca
					nuovaEpoca = epoca.nome
					for _, tipo in ipairs(epoca.mazzoIniziale) do
						d.collezione[tipo] = (d.collezione[tipo] or 0) + 1
					end
					d.mazzo = table.clone(epoca.mazzoIniziale)
				end
			else
				d.campagnaCompletata = true
			end
		end
	end)
	sessione.fase = "risultato"
	local dopo = Dati.ottieni(player)
	remoti.Fase:FireClient(player, {
		fase = "risultato",
		vittoria = vittoria,
		nome = livello.nome,
		numero = livello.numero,
		prossimo = vittoria and math.min(livello.numero + 1, dopo.livello) or livello.numero,
		vinti = sessione.vinti,
		persi = sessione.persi,
		stelle = stelle,
		nuoveStelle = stelle > stellePrima,
		monete = monete,
		esperienza = esperienza,
		nuovoLivelloGiocatore = Progressi.livello(dopo.esperienza) > livelloPrima and Progressi.livello(dopo.esperienza) or nil,
		premio = premio,
		nuovaEpoca = nuovaEpoca,
		sconfitti = sessione.sconfitti,
		persiReggimenti = sessione.caduti,
		completata = dopo.campagnaCompletata,
	})
end

-- Un round: battaglia, punteggio, poi il round successivo (che parte quando il giocatore preme FIGHT!) o la fine.
local function round(player, sessione)
	local vinto = combattiRound(player, sessione)
	if vinto == nil then
		return
	end
	if vinto then
		sessione.vinti += 1
	else
		sessione.persi += 1
	end
	sessione.fase = "round"
	remoti.Fase:FireClient(player, {
		fase = "round",
		vittoria = vinto,
		round = sessione.round,
		vinti = sessione.vinti,
		persi = sessione.persi,
		perVincere = Campagna.ROUND_PER_VINCERE,
		assedio = sessione.assedio,
	})
	task.wait(PAUSA_TRA_ROUND)
	if not sessione.attiva then
		return
	end
	if sessione.vinti >= Campagna.ROUND_PER_VINCERE or sessione.persi >= Campagna.ROUND_PER_VINCERE then
		fineLivello(player, sessione)
	else
		sessione.round += 1
		inizioRound(player, sessione)
	end
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
	task.spawn(round, player, sessione)
	return true
end

-- Apre la mappa della campagna: il giocatore aspetta vicino al plastico (per lo streaming) e il client mostra i livelli.
function GestoreCampagna.apriMappa(player)
	local dati = Dati.ottieni(player)
	if not dati then
		return false, "Loading your data, try again in a moment."
	end
	if not MappaCampagna.pronta then
		return false, "The campaign map is still being built: try again in a moment."
	end
	local esistente = sessioni[player]
	if esistente and (esistente.fase == "battaglia" or esistente.fase == "costruzione") then
		return false, "You already have a battle in progress."
	end
	chiudiSessione(player)
	teletrasporta(player, MappaCampagna.ATTESA, true)
	remoti.Fase:FireClient(player, { fase = "mappa", livello = dati.livello })
	return true
end

function GestoreCampagna.tornaLobby(player)
	local esistente = sessioni[player]
	if esistente and esistente.fase == "battaglia" then
		return false, "Finish the battle first."
	end
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
	remoti.ApriMappa.OnServerInvoke = GestoreCampagna.apriMappa
	remoti.Casella.OnServerInvoke = GestoreCampagna.casella
	remoti.Combatti.OnServerInvoke = GestoreCampagna.combatti
	remoti.TornaLobby.OnServerInvoke = GestoreCampagna.tornaLobby
end

return GestoreCampagna
