-- Partite della campagna: mappa, schieramento (carte del mazzo scelte + formazione storica), round al
-- meglio di 5 con battaglie automatiche e ordini generali all'armata, assedio della fortezza nemica sul
-- match point, stelle e ricompense.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Battaglia = require(Shared.Battaglia)
local Campagna = require(Shared.Config.Campagna)
local Epoche = require(Shared.Config.Epoche)
local Formazioni = require(Shared.Config.Formazioni)
local Progressi = require(Shared.Config.Progressi)
local Prova = require(Shared.Prova)
local Arena = require(script.Parent.Arena)
local Dati = require(script.Parent.Dati)
local Lobby = require(script.Parent.Lobby)
local MappaCampagna = require(script.Parent.MappaCampagna)

local GestoreCampagna = {}

local TICK = 0.1
-- Secondi di battaglia simulati per ogni secondo reale: sotto 1 la battaglia si gode di più, senza cambiare il bilanciamento.
local VELOCITA_BATTAGLIA = 0.75
-- Tra un round e l'altro il client mostra una cinematica breve sul campo, con i superstiti ancora lì.
local PAUSA_TRA_ROUND = 6.5
-- Secondi di battaglia dopo cui i comandanti nemici usano la loro abilità.
local ATTESA_ABILITA_NEMICA = 6

local sessioni = {}
local remoti

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
	if player.Parent then
		remoti.Truppe:FireClient(player, { tipo = "pulisci" })
	end
end

-- Posti dei reggimenti scelti secondo la formazione, lontano dalle caselle dove non ci si schiera.
local function disponi(sessione)
	local livello = sessione.livello
	local tipi = {}
	for _, indice in ipairs(sessione.scelte) do
		table.insert(tipi, sessione.mazzo[indice])
	end
	local posti = Formazioni.disponi(sessione.formazione, tipi, function(x, y)
		return not Campagna.bloccata(livello, math.floor(x + 0.5), math.floor(y + 0.5))
	end)
	sessione.piazzate = {}
	for i, indice in ipairs(sessione.scelte) do
		table.insert(sessione.piazzate, { indice = indice, tipo = tipi[i], x = posti[i][1], y = posti[i][2] })
	end
	sessione.numero = #sessione.piazzate
end

-- Formazioni per il client: tutte, con quelle ancora chiuse e il livello che le apre.
local function elencoFormazioni(player)
	local dati = Dati.ottieni(player)
	local lista = {}
	for _, f in ipairs(Formazioni.Lista) do
		table.insert(lista, {
			id = f.id,
			nome = f.nome,
			descrizione = f.descrizione,
			sblocco = f.sblocco,
			sbloccata = Formazioni.sbloccata(f.id, dati and dati.livello),
		})
	end
	return lista
end

-- Il client disegna i reggimenti schierati: gli si manda la lista ogni volta che cambia.
local function inviaSchieramento(player, sessione)
	local reggimenti = {}
	for _, piazzata in ipairs(sessione.piazzate) do
		table.insert(reggimenti, { tipo = piazzata.tipo, x = piazzata.x, y = piazzata.y })
	end
	remoti.Truppe:FireClient(player, {
		tipo = "schieramento",
		origine = sessione.arena.origine,
		colonne = Arena.COLONNE,
		righe = Arena.RIGHE,
		reggimenti = reggimenti,
	})
end

-- Inizio di un round: rimette i reggimenti dove erano nel round prima e manda al client il resoconto degli esploratori.
local function inizioRound(player, sessione)
	local livello = sessione.livello
	sessione.fase = "piazzamento"
	sessione.assedio = sessione.vinti == Campagna.ROUND_PER_VINCERE - 1 and sessione.persi < Campagna.ROUND_PER_VINCERE - 1
	sessione.armata = Campagna.armata(livello, sessione.round, sessione.assedio)
	disponi(sessione)
	inviaSchieramento(player, sessione)
	-- Niente caselle: i reggimenti stanno in formazione sul terreno.
	Arena.mostraCaselle(sessione.arena, false)
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
		usate = table.clone(sessione.scelte),
		formazione = sessione.formazione,
		formazioni = elencoFormazioni(player),
		meteo = livello.meteo,
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
	-- All'inizio sono scelte le prime carte del mazzo, nella formazione usata l'ultima volta.
	local scelte = {}
	for indice = 1, math.min(#dati.mazzo, livello.maxReggimenti) do
		table.insert(scelte, indice)
	end
	local formazione = Formazioni.sbloccata(dati.formazione, dati.livello) and dati.formazione or Formazioni.PREDEFINITA
	local sessione = {
		attiva = true,
		fase = "costruzione",
		livello = livello,
		mazzo = table.clone(dati.mazzo),
		scelte = scelte, -- indici del mazzo schierati, in ordine
		formazione = formazione,
		piazzate = {}, -- { { indice, tipo, x, y } }, calcolate da scelte e formazione
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

-- Schieramento: le carte scelte (indici del mazzo, in ordine) e la formazione (nil = resta quella di prima).
-- I reggimenti prendono subito il loro posto sul campo. Restituisce ok, messaggio, scelte.
function GestoreCampagna.schiera(player, indici, formazione)
	local sessione = sessioni[player]
	if not sessione or sessione.fase ~= "piazzamento" then
		return false, "You are not deploying troops right now."
	end
	if typeof(indici) ~= "table" then
		return false, "Invalid choice."
	end
	local scelte, viste = {}, {}
	for _, indice in ipairs(indici) do
		if typeof(indice) ~= "number" or not sessione.mazzo[indice] or viste[indice] then
			return false, "Invalid card."
		end
		viste[indice] = true
		table.insert(scelte, indice)
	end
	if #scelte > sessione.livello.maxReggimenti then
		return false, "Maximum " .. sessione.livello.maxReggimenti .. " regiments in this battle."
	end
	if formazione ~= nil and formazione ~= sessione.formazione then
		local dati = Dati.ottieni(player)
		if typeof(formazione) ~= "string" or not Formazioni.sbloccata(formazione, dati and dati.livello) then
			return false, "That formation is still locked."
		end
		sessione.formazione = formazione
		Dati.modifica(player, function(d)
			d.formazione = formazione
		end)
	end
	sessione.scelte = scelte
	disponi(sessione)
	inviaSchieramento(player, sessione)
	return true, nil, table.clone(scelte)
end

-- Battaglia ----------------------------------------------------------------

-- Posizioni dei soldati vivi per il client: id (u16), x e y in millesimi di casella (u16), angolo (u8).
local function posizioni(battaglia)
	local vivi = {}
	for _, s in ipairs(battaglia.soldati) do
		if s.vivo then
			table.insert(vivi, s)
		end
	end
	local b = buffer.create(2 + #vivi * 7)
	buffer.writeu16(b, 0, #vivi)
	for i, s in ipairs(vivi) do
		local o = 2 + (i - 1) * 7
		buffer.writeu16(b, o, s.id)
		buffer.writeu16(b, o + 2, math.clamp(math.floor(s.x * 1000 + 0.5), 0, 65535))
		buffer.writeu16(b, o + 4, math.clamp(math.floor(s.y * 1000 + 0.5), 0, 65535))
		buffer.writeu8(b, o + 6, math.floor((s.rivolto % (2 * math.pi)) / (2 * math.pi) * 256) % 256)
	end
	return b
end

-- Eventi della simulazione ridotti a quello che serve al client per animarli.
local function eventiPerClient(eventi)
	local lista = {}
	for _, e in ipairs(eventi) do
		if e.tipo == "attacco" then
			table.insert(lista, { tipo = "attacco", da = e.da, a = e.a, colpo = e.colpo, gesto = e.gesto, ritardo = e.ritardo, carica = e.carica or nil })
		elseif e.tipo == "colpo" then
			local area = nil
			if #e.area > 0 then
				area = {}
				for _, v in ipairs(e.area) do
					table.insert(area, { id = v.id, danno = v.danno })
				end
			end
			table.insert(lista, { tipo = "colpo", a = e.a, danno = e.danno, area = area })
		elseif e.tipo == "morte" then
			table.insert(lista, { tipo = "morte", id = e.id, reggimento = e.reggimentoCaduto and e.reggimento or nil })
		elseif e.tipo == "ordine" or e.tipo == "abilita" then
			table.insert(lista, e)
		end
	end
	return lista
end

-- Combatte un round; restituisce true se l'ha vinto il giocatore (nil se la sessione è stata chiusa).
local function combattiRound(player, sessione)
	if sessione.vinciSubito then
		-- Modalità prova, WIN ROUND premuto durante lo schieramento: round vinto senza combattere.
		sessione.vinciSubito = nil
		return true
	end
	local livello = sessione.livello
	local arena = sessione.arena
	local reggimenti = {}

	local id = 0
	local mieiReggimenti, reggimentiNemici = {}, {}
	for _, piazzata in ipairs(sessione.piazzate) do
		id += 1
		table.insert(reggimenti, { id = id, squadra = "giocatore", def = Epoche.Truppe[piazzata.tipo], x = piazzata.x, y = piazzata.y })
		table.insert(mieiReggimenti, { id = id, indice = piazzata.indice, tipo = piazzata.tipo })
	end
	for i, nemico in ipairs(sessione.armata) do
		table.insert(reggimenti, {
			id = 100 + i,
			squadra = "nemico",
			def = Epoche.Truppe[nemico.tipo],
			x = nemico.col,
			y = nemico.riga,
			forza = Campagna.forza(livello, sessione.round, nemico.tipo),
		})
		table.insert(reggimentiNemici, { id = 100 + i, tipo = nemico.tipo })
	end

	local ostacoli, terreno = {}, {}
	for _, t in ipairs(livello.terreno) do
		if Campagna.SOLIDI[t.tipo] then
			table.insert(ostacoli, { x = t.col, y = t.riga })
		elseif t.tipo == "fiume" or t.tipo == "collina" or t.tipo == "trincea" then
			terreno[t.col .. "," .. t.riga] = t.tipo
		end
	end

	local battaglia = Battaglia.nuova(reggimenti, { colonne = Arena.COLONNE, righe = Arena.RIGHE, ostacoli = ostacoli, terreno = terreno })
	local elenco = {}
	for _, s in ipairs(battaglia.soldati) do
		table.insert(elenco, { id = s.id, tipo = s.def.id, squadra = s.squadra, x = s.x, y = s.y, hp = s.hpMax })
	end
	Arena.mostraCaselle(arena, false)
	remoti.Truppe:FireClient(player, {
		tipo = "inizio",
		origine = arena.origine,
		colonne = Arena.COLONNE,
		righe = Arena.RIGHE,
		velocita = VELOCITA_BATTAGLIA,
		soldati = elenco,
	})
	remoti.Fase:FireClient(player, {
		fase = "battaglia",
		conto = 3,
		assedio = sessione.assedio,
		reggimenti = mieiReggimenti,
		nemici = reggimentiNemici,
	})
	task.wait(3.2) -- conto alla rovescia sul client, intanto si vede lo schieramento nemico
	if not sessione.attiva then
		return nil
	end

	sessione.battaglia = battaglia
	while sessione.attiva and not battaglia.finita and not sessione.vinciSubito do
		-- I comandanti nemici usano la loro abilità quando gli eserciti stanno per scontrarsi.
		if battaglia.tempo >= ATTESA_ABILITA_NEMICA then
			for _, r in ipairs(reggimentiNemici) do
				battaglia:attivaAbilita(r.id)
			end
		end
		local eventi = battaglia:passo(TICK * VELOCITA_BATTAGLIA)
		remoti.Truppe:FireClient(player, { tipo = "passo", posizioni = posizioni(battaglia), eventi = eventiPerClient(eventi) })
		task.wait(TICK)
	end
	sessione.battaglia = nil
	if not sessione.attiva then
		return nil
	end
	-- Modalità prova, WIN ROUND premuto in battaglia: si interrompe qui e il round è del giocatore.
	local vintoSubito = sessione.vinciSubito
	sessione.vinciSubito = nil

	for _, r in ipairs(battaglia.reggimenti) do
		if not r.vivo then
			if r.squadra == "nemico" then
				sessione.sconfitti += 1
			else
				sessione.caduti += 1
			end
		end
	end
	-- I superstiti restano sul campo per la cinematica tra i round: lo svuota round().
	sessione.superstiti = { giocatore = 0, nemico = 0 }
	for _, r in ipairs(battaglia.reggimenti) do
		if r.vivo then
			sessione.superstiti[r.squadra] += 1
		end
	end
	return vintoSubito or battaglia.vincitore == "giocatore"
end

-- Fine del livello: stelle, monete, esperienza, carta premio, avanzamento.
-- Rigiocando una battaglia vinta, probabilità che cada una carta della sua armata.
local PROBABILITA_BOTTINO = 0.4

-- Una carta dell'armata di una battaglia: prima quelle che il giocatore non ha ancora.
local function cartaDellArmata(dati, armata)
	local mancanti = {}
	for _, tipo in ipairs(armata) do
		if (dati.collezione[tipo] or 0) == 0 then
			table.insert(mancanti, tipo)
		end
	end
	local scelta = #mancanti > 0 and mancanti or armata
	return scelta[math.random(#scelta)]
end

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
	local campagnaPrima = dati.livello
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
		if vittoria and livello.numero ~= d.livello and math.random() < PROBABILITA_BOTTINO then
			-- Rigiocando una battaglia già vinta a volte cade una carta della sua armata: così si ottengono tutte.
			premio = cartaDellArmata(d, livello.armata)
			Dati.aggiungiCarta(d, premio)
		end
		if vittoria and livello.numero == d.livello then
			premio = livello.comandante or livello.premio or cartaDellArmata(d, livello.armata)
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
		nuoveFormazioni = (function()
			local nomi = {}
			if dopo.livello > campagnaPrima then
				for _, f in ipairs(Formazioni.nuoveAl(dopo.livello)) do
					table.insert(nomi, f.nome)
				end
			end
			return nomi
		end)(),
	})
end

-- Un round: battaglia, punteggio, poi il round successivo (che parte quando il giocatore preme FIGHT!) o la fine.
local function round(player, sessione)
	local vinto = combattiRound(player, sessione)
	sessione.vinciSubito = nil -- un WIN ROUND arrivato a battaglia già finita non vale per il round dopo
	if vinto == nil then
		return
	end
	if vinto then
		sessione.vinti += 1
	else
		sessione.persi += 1
	end
	sessione.fase = "round"
	local finita = sessione.vinti >= Campagna.ROUND_PER_VINCERE or sessione.persi >= Campagna.ROUND_PER_VINCERE
	remoti.Fase:FireClient(player, {
		fase = "round",
		vittoria = vinto,
		round = sessione.round,
		vinti = sessione.vinti,
		persi = sessione.persi,
		perVincere = Campagna.ROUND_PER_VINCERE,
		assedio = sessione.assedio,
		finita = finita,
		nemico = sessione.livello.nemico,
		-- Nei livelli con un boss la scena tra i round lo segue da vicino (Client/Intermezzo).
		comandante = sessione.livello.comandante,
		superstiti = sessione.superstiti,
		durata = PAUSA_TRA_ROUND - 0.5,
	})
	sessione.superstiti = nil
	task.wait(PAUSA_TRA_ROUND)
	if not sessione.attiva then
		return
	end
	-- Il campo si svuota: i reggimenti tornano al loro posto all'inizio del prossimo round.
	remoti.Truppe:FireClient(player, { tipo = "fine" })
	task.wait(1.3)
	if not sessione.attiva then
		return
	end
	if finita then
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
	-- I generali non combattono da soli: serve almeno un reggimento che li accompagni.
	local scortati = false
	for _, piazzata in ipairs(sessione.piazzate) do
		local def = Epoche.Truppe[piazzata.tipo]
		if def and not def.comandante then
			scortati = true
		end
	end
	if not scortati then
		return false, "A general never fights alone: deploy a regiment with him."
	end
	sessione.fase = "battaglia"
	task.spawn(round, player, sessione)
	return true
end

-- Ordine generale del giocatore a tutta la sua armata (uno di Battaglia.ORDINI). Restituisce ok, messaggio.
function GestoreCampagna.ordine(player, nome)
	local sessione = sessioni[player]
	local battaglia = sessione and sessione.battaglia
	if not battaglia then
		return false, "Orders can be given during the battle."
	end
	if typeof(nome) ~= "string" then
		return false
	end
	return battaglia:ordine("giocatore", nome)
end

-- Abilità del comandante "id" del giocatore, una volta per round.
function GestoreCampagna.abilita(player, id)
	local sessione = sessioni[player]
	local battaglia = sessione and sessione.battaglia
	if not battaglia or typeof(id) ~= "number" or id < 1 or id >= 100 then
		return false, "Abilities can be used during the battle."
	end
	if not battaglia:attivaAbilita(id) then
		return false, "This ability is not available right now."
	end
	return true
end

-- Modalità prova (solo in Studio): vince subito il round, in battaglia o durante lo schieramento,
-- per arrivare in fretta alla fortezza del match point o alla fine del livello.
function GestoreCampagna.vinciRound(player)
	if not Prova then
		return false
	end
	local sessione = sessioni[player]
	if not sessione or (sessione.fase ~= "piazzamento" and sessione.fase ~= "battaglia") then
		return false, "No round to win right now."
	end
	if sessione.vinciSubito then
		return true
	end
	sessione.vinciSubito = true
	if sessione.fase == "piazzamento" then
		sessione.fase = "battaglia"
		task.spawn(round, player, sessione)
	end
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
	remoti.Schiera.OnServerInvoke = GestoreCampagna.schiera
	remoti.Combatti.OnServerInvoke = GestoreCampagna.combatti
	remoti.Ordine.OnServerInvoke = GestoreCampagna.ordine
	remoti.Abilita.OnServerInvoke = GestoreCampagna.abilita
	remoti.VinciRound.OnServerInvoke = GestoreCampagna.vinciRound
	remoti.TornaLobby.OnServerInvoke = GestoreCampagna.tornaLobby
end

return GestoreCampagna
