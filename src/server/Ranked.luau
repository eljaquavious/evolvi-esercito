-- Ranked: 1 contro 1 tra due giocatori dello stesso server, al meglio dei 3 round (Mattia, 21/10/2026).
-- Mappa a caso tra quelle della campagna (con gli ostacoli resi simmetrici, così nessuno parte avvantaggiato),
-- si schierano le carte del proprio mazzo (menu ARMY), fino al massimo dell'ultimo livello della campagna.
-- Niente cinematiche tra i round; alla fine il client mostra l'avatar del vincitore con la musica.
-- Chi vince riceve una Small Crate.
--
-- Il primo giocatore è la squadra "giocatore" (file in basso, lato -Z), il secondo la squadra "nemico" (file in
-- alto). Al secondo il server manda tutto con le squadre scambiate: il suo client lo disegna come "giocatore"
-- (colori, carte, clic sui soldati) e gira solo la telecamera (girato = true). Le coordinate restano quelle vere.
--
-- In Studio (modalità prova), da soli in coda per qualche secondo, si gioca contro un avversario finto (bot)
-- per collaudare.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Battaglia = require(Shared.Battaglia)
local Campagna = require(Shared.Config.Campagna)
local Epoche = require(Shared.Config.Epoche)
local Formazioni = require(Shared.Config.Formazioni)
local Prova = require(Shared.Prova)
local Arena = require(script.Parent.Arena)
local Dati = require(script.Parent.Dati)
local Lobby = require(script.Parent.Lobby)
local Shop = require(script.Parent.Shop)
local Classifica = require(script.Parent.Classifica)
local Gradi = require(Shared.Config.Gradi)

local Ranked = {}

local ROUND_PER_VINCERE = 2 -- al meglio dei 3
local TEMPO_SCHIERAMENTO = 45 -- secondi per schierarsi al primo round
local TEMPO_SCHIERAMENTO_DOPO = 25 -- ai round successivi
local PAUSA_TRA_ROUND = 3.5
local TICK = 0.1
local VELOCITA_BATTAGLIA = 0.75
local ATTESA_BOT = 6 -- secondi da soli in coda prima del bot (solo in Studio)
local CASSA_VITTORIA = "CassaPiccola"
local DURATA_FINALE = 4 -- secondi di animazione del vincitore prima che si apra la cassa

local remoti
local occupato -- funzione(player): true se è in una partita della campagna (la imposta init.server)
local coda = {} -- giocatori in attesa, in ordine
local partite = {} -- player -> partita
local codaDal = {} -- player -> os.clock() dell'ingresso in coda

local function opposta(squadra)
	return squadra == "giocatore" and "nemico" or "giocatore"
end

local function notifica(player, testo)
	if player and player.Parent then
		remoti.Notifica:FireClient(player, testo)
	end
end

local function teletrasporta(player, destinazione)
	local character = player.Character
	local radice = character and character:FindFirstChild("HumanoidRootPart")
	if not radice then
		return
	end
	radice.Anchored = false
	character:PivotTo(destinazione)
	radice.AssemblyLinearVelocity = Vector3.zero
end

-- Mazzo della ranked: le carte equipaggiate nel menu ARMY (Mattia, 22/10/2026).
local function mazzoDa(dati)
	return table.clone(dati.mazzo)
end

-- Terreno della mappa reso simmetrico (girato di 180° attorno al centro): vale la metà del giocatore in basso
-- più la prima riga della terra di nessuno, ricopiata dall'altra parte. Il fiume si toglie (una riga sola non
-- si può specchiare).
local function terrenoSimmetrico(terreno)
	local C, R = Campagna.COLONNE, Campagna.RIGHE
	local meta = R // 2
	local nuovo, preso = {}, {}
	for _, t in ipairs(terreno) do
		if t.riga <= meta and t.tipo ~= "fiume" and t.tipo ~= "guado" then
			local chiave1 = t.col .. "," .. t.riga
			local chiave2 = (C + 1 - t.col) .. "," .. (R + 1 - t.riga)
			if not preso[chiave1] then
				table.insert(nuovo, { col = t.col, riga = t.riga, tipo = t.tipo })
				preso[chiave1] = true
			end
			if not preso[chiave2] then
				table.insert(nuovo, { col = C + 1 - t.col, riga = R + 1 - t.riga, tipo = t.tipo })
				preso[chiave2] = true
			end
		end
	end
	return nuovo
end

local function specchio(x, y)
	return Campagna.COLONNE + 1 - x, Campagna.RIGHE + 1 - y
end

-- ===================================================================== schieramento

local function maxReggimenti()
	return Campagna.livello(Campagna.TOTALE).maxReggimenti
end

-- Posti dei reggimenti scelti: la formazione li mette nelle file in basso; per la squadra "nemico" si specchiano.
local function disponi(partita, lato)
	local tipi = {}
	for _, indice in ipairs(lato.scelte) do
		table.insert(tipi, lato.mazzo[indice])
	end
	local livello = partita.livello
	local posti = Formazioni.disponi(lato.formazione, tipi, function(x, y)
		local cx, cy = math.floor(x + 0.5), math.floor(y + 0.5)
		if lato.squadra == "nemico" then
			cx, cy = specchio(cx, cy)
		end
		return not Campagna.bloccata(livello, cx, cy)
	end)
	lato.piazzate = {}
	for i, indice in ipairs(lato.scelte) do
		local x, y = posti[i][1], posti[i][2]
		if lato.squadra == "nemico" then
			x, y = specchio(x, y)
		end
		table.insert(lato.piazzate, { indice = indice, tipo = tipi[i], x = x, y = y })
	end
end

local function inviaSchieramento(partita, lato)
	if lato.bot or not lato.player.Parent then
		return
	end
	local reggimenti = {}
	for _, p in ipairs(lato.piazzate) do
		table.insert(reggimenti, { tipo = p.tipo, x = p.x, y = p.y })
	end
	remoti.Truppe:FireClient(lato.player, {
		tipo = "schieramento",
		origine = partita.arena.origine,
		colonne = Arena.COLONNE,
		righe = Arena.RIGHE,
		reggimenti = reggimenti,
		angolo = lato.squadra == "nemico" and math.pi or 0,
	})
end

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

local function avversarioDi(partita, lato)
	return partita.lati[1] == lato and partita.lati[2] or partita.lati[1]
end

local function inizioRound(partita)
	partita.fase = "piazzamento"
	partita.pronti = {}
	local tempo = partita.round == 1 and TEMPO_SCHIERAMENTO or TEMPO_SCHIERAMENTO_DOPO
	partita.scadenza = os.clock() + tempo
	local livello = partita.livello
	for _, lato in ipairs(partita.lati) do
		disponi(partita, lato)
		if not lato.bot and lato.player.Parent then
			local altro = avversarioDi(partita, lato)
			inviaSchieramento(partita, lato)
			remoti.Fase:FireClient(lato.player, {
				fase = "piazzamento",
				ranked = true,
				girato = lato.squadra == "nemico",
				avversario = altro.nome,
				limite = tempo,
				livello = 0,
				totale = Campagna.TOTALE,
				nome = livello.nome,
				anno = livello.anno,
				epoca = livello.epoca.nome,
				bioma = partita.arena.bioma.nome,
				atmosfera = partita.arena.bioma.atmosfera,
				maxReggimenti = maxReggimenti(),
				mazzo = lato.mazzo,
				usate = table.clone(lato.scelte),
				formazione = lato.formazione,
				formazioni = elencoFormazioni(lato.player),
				meteo = livello.meteo,
				arena = partita.arena.modello.Name,
				centro = partita.arena.origine,
				righeGiocatore = Campagna.RIGHE_GIOCATORE,
				round = partita.round,
				vinti = lato.punti,
				persi = altro.punti,
				perVincere = ROUND_PER_VINCERE,
				esploratori = {},
			})
		end
	end
	Arena.mostraCaselle(partita.arena, false)
	-- Allo scadere del tempo si combatte comunque.
	local round = partita.round
	task.delay(tempo, function()
		if partita.attiva and partita.fase == "piazzamento" and partita.round == round then
			Ranked.avviaBattaglia(partita)
		end
	end)
	task.delay(math.max(0, tempo - 10), function()
		if partita.attiva and partita.fase == "piazzamento" and partita.round == round then
			for _, lato in ipairs(partita.lati) do
				if not lato.bot and not partita.pronti[lato] then
					notifica(lato.player, "10 seconds left to deploy!")
				end
			end
		end
	end)
end

-- ===================================================================== battaglia

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

-- Eventi per il client; per la squadra "nemico" le squadre sono scambiate.
local function eventiPer(eventi, scambia)
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
		elseif e.tipo == "ordine" or e.tipo == "abilita" or e.tipo == "bersaglio" then
			if scambia and e.squadra then
				local copia = table.clone(e)
				copia.squadra = opposta(e.squadra)
				table.insert(lista, copia)
			else
				table.insert(lista, e)
			end
		end
	end
	return lista
end

local function idBase(lato)
	return lato.squadra == "giocatore" and 0 or 100
end

local function suoReggimento(lato, id)
	local base = idBase(lato)
	return typeof(id) == "number" and id > base and id < base + 100
end

local function combattiRound(partita)
	local reggimenti = {}
	local perLato = {}
	for _, lato in ipairs(partita.lati) do
		perLato[lato] = {}
		for i, p in ipairs(lato.piazzate) do
			local id = idBase(lato) + i
			table.insert(reggimenti, { id = id, squadra = lato.squadra, def = Epoche.Truppe[p.tipo], x = p.x, y = p.y })
			table.insert(perLato[lato], { id = id, indice = p.indice, tipo = p.tipo })
		end
	end
	local ostacoli, terreno = {}, {}
	for _, t in ipairs(partita.livello.terreno) do
		if Campagna.SOLIDI[t.tipo] then
			table.insert(ostacoli, { x = t.col, y = t.riga })
		elseif t.tipo == "collina" or t.tipo == "trincea" then
			terreno[t.col .. "," .. t.riga] = t.tipo
		end
	end
	local battaglia = Battaglia.nuova(reggimenti, { colonne = Arena.COLONNE, righe = Arena.RIGHE, ostacoli = ostacoli, terreno = terreno })
	for _, lato in ipairs(partita.lati) do
		if not lato.bot and lato.player.Parent then
			local scambia = lato.squadra == "nemico"
			local elenco = {}
			for _, s in ipairs(battaglia.soldati) do
				table.insert(elenco, {
					id = s.id,
					tipo = s.def.id,
					squadra = scambia and opposta(s.squadra) or s.squadra,
					x = s.x,
					y = s.y,
					hp = s.hpMax,
					angolo = s.squadra == "giocatore" and 0 or math.pi,
				})
			end
			remoti.Truppe:FireClient(lato.player, {
				tipo = "inizio",
				origine = partita.arena.origine,
				colonne = Arena.COLONNE,
				righe = Arena.RIGHE,
				velocita = VELOCITA_BATTAGLIA,
				soldati = elenco,
			})
			local nemici = {}
			for _, r in ipairs(perLato[avversarioDi(partita, lato)]) do
				table.insert(nemici, { id = r.id, tipo = r.tipo })
			end
			remoti.Fase:FireClient(lato.player, {
				fase = "battaglia",
				ranked = true,
				conto = 3,
				reggimenti = perLato[lato],
				nemici = nemici,
			})
		end
	end
	task.wait(3.2)
	if not partita.attiva then
		return nil
	end
	partita.battaglia = battaglia
	local abilitaBot = false
	while partita.attiva and not battaglia.finita and not partita.vinciSubito do
		-- Il bot usa le abilità dei suoi comandanti quando gli eserciti si avvicinano.
		if not abilitaBot and battaglia.tempo >= 6 then
			abilitaBot = true
			for _, lato in ipairs(partita.lati) do
				if lato.bot then
					for _, r in ipairs(perLato[lato]) do
						battaglia:attivaAbilita(r.id)
					end
				end
			end
		end
		local eventi = battaglia:passo(TICK * VELOCITA_BATTAGLIA)
		local pos = posizioni(battaglia)
		for _, lato in ipairs(partita.lati) do
			if not lato.bot and lato.player.Parent then
				remoti.Truppe:FireClient(lato.player, { tipo = "passo", posizioni = pos, eventi = eventiPer(eventi, lato.squadra == "nemico") })
			end
		end
		task.wait(TICK)
	end
	partita.battaglia = nil
	if not partita.attiva then
		return nil
	end
	-- Modalità prova: WIN ROUND premuto da un giocatore vero.
	if partita.vinciSubito then
		local squadra = partita.vinciSubito
		partita.vinciSubito = nil
		return squadra
	end
	return battaglia.vincitore
end

local function fine(partita, vincitore, ritirato)
	partita.fase = "risultato"
	partita.attiva = false
	local perdente = avversarioDi(partita, vincitore)
	-- Punti ranked (Config/Gradi): +30 a chi vince, -20 a chi perde (mai sotto 0), anche settimanali.
	local settimana = Gradi.settimana()
	local function punti(l, vinto)
		if l.bot or not Dati.ottieni(l.player) then
			return
		end
		local prima = Dati.ottieni(l.player).ranked.punti
		Dati.modifica(l.player, function(d)
			local r = d.ranked
			if r.settimana ~= settimana then
				r.settimana = settimana
				r.puntiSettimana = 0
			end
			local cambio = vinto and Gradi.PUNTI_VITTORIA or -Gradi.PUNTI_SCONFITTA
			r.punti = math.max(0, r.punti + cambio)
			r.puntiSettimana = math.max(0, r.puntiSettimana + cambio)
			if vinto then
				r.vittorie += 1
				d.statistiche.vittorieRanked += 1
			else
				r.sconfitte += 1
			end
			d.statistiche.battaglie += 1
		end)
		local r = Dati.ottieni(l.player).ranked
		l.puntiPrima, l.puntiDopo = prima, r.punti
		Classifica.registra(l.player, r.punti, r.puntiSettimana)
	end
	punti(vincitore, true)
	-- Anche chi è uscito a metà perde i punti (se i suoi dati sono ancora qui).
	punti(perdente, false)
	for _, lato in ipairs(partita.lati) do
		if not lato.bot and lato.player.Parent then
			local altro = avversarioDi(partita, lato)
			remoti.Fase:FireClient(lato.player, {
				fase = "risultato",
				ranked = true,
				vittoria = lato == vincitore,
				vincitore = vincitore.nome,
				vincitoreId = (not vincitore.bot) and vincitore.player.UserId or nil,
				perdente = perdente.nome,
				vinti = lato.punti,
				persi = altro.punti,
				ritirato = ritirato or nil,
				cassa = lato == vincitore and not vincitore.bot,
				puntiPrima = lato.puntiPrima,
				puntiDopo = lato.puntiDopo,
				durata = DURATA_FINALE,
			})
		end
	end
	if not vincitore.bot then
		task.delay(DURATA_FINALE, function()
			if vincitore.player.Parent then
				Shop.regala(vincitore.player, CASSA_VITTORIA)
			end
		end)
	end
	-- Il campo resta finché i giocatori non tornano in lobby (o al massimo un minuto).
	task.delay(60, function()
		Ranked.chiudi(partita)
	end)
end

local function round(partita)
	local squadraVincente = combattiRound(partita)
	if squadraVincente == nil then
		return
	end
	local vincitore
	for _, lato in ipairs(partita.lati) do
		if lato.squadra == squadraVincente then
			vincitore = lato
		end
	end
	vincitore.punti += 1
	partita.fase = "round"
	local finita = vincitore.punti >= ROUND_PER_VINCERE
	for _, lato in ipairs(partita.lati) do
		if not lato.bot and lato.player.Parent then
			local altro = avversarioDi(partita, lato)
			remoti.Fase:FireClient(lato.player, {
				fase = "round",
				ranked = true,
				vittoria = lato == vincitore,
				round = partita.round,
				vinti = lato.punti,
				persi = altro.punti,
				perVincere = ROUND_PER_VINCERE,
				finita = finita,
				avversario = altro.nome,
			})
		end
	end
	task.wait(PAUSA_TRA_ROUND)
	if not partita.attiva then
		return
	end
	for _, lato in ipairs(partita.lati) do
		if not lato.bot and lato.player.Parent then
			remoti.Truppe:FireClient(lato.player, { tipo = "fine" })
		end
	end
	task.wait(1.3)
	if not partita.attiva then
		return
	end
	if finita then
		fine(partita, vincitore)
	else
		partita.round += 1
		inizioRound(partita)
	end
end

function Ranked.avviaBattaglia(partita)
	if partita.fase ~= "piazzamento" then
		return
	end
	-- Chi non ha schierato nulla schiera le sue carte migliori.
	for _, lato in ipairs(partita.lati) do
		if #lato.scelte == 0 then
			for i = 1, math.min(#lato.mazzo, maxReggimenti()) do
				table.insert(lato.scelte, i)
			end
			disponi(partita, lato)
		end
	end
	partita.fase = "battaglia"
	task.spawn(round, partita)
end

-- ===================================================================== partita

local function lato(player, squadra)
	local dati = Dati.ottieni(player)
	local mazzo = mazzoDa(dati)
	local scelte = {}
	for i = 1, math.min(#mazzo, maxReggimenti()) do
		table.insert(scelte, i)
	end
	return {
		player = player,
		nome = player.DisplayName,
		squadra = squadra,
		mazzo = mazzo,
		scelte = scelte,
		formazione = Formazioni.sbloccata(dati.formazione, dati.livello) and dati.formazione or Formazioni.PREDEFINITA,
		piazzate = {},
		punti = 0,
	}
end

-- Avversario finto per collaudare in Studio: carte a caso fra tutte, niente comandanti.
local function latoBot(squadra)
	local tutte = {}
	for _, tipo in ipairs(Epoche.carte()) do
		if not Epoche.Truppe[tipo].comandante then
			table.insert(tutte, tipo)
		end
	end
	local mazzo = {}
	for _ = 1, maxReggimenti() do
		table.insert(mazzo, tutte[math.random(#tutte)])
	end
	local scelte = {}
	for i = 1, #mazzo do
		table.insert(scelte, i)
	end
	return {
		bot = true,
		nome = "Training Dummy",
		squadra = squadra,
		mazzo = mazzo,
		scelte = scelte,
		formazione = Formazioni.PREDEFINITA,
		piazzate = {},
		punti = 0,
	}
end

local function crea(a, b)
	-- Mappa a caso tra le battaglie della campagna, con gli ostacoli simmetrici.
	local base = Campagna.livello(math.random(1, Campagna.TOTALE))
	local livello = table.clone(base)
	livello.terreno = terrenoSimmetrico(base.terreno)
	local partita = {
		attiva = true,
		fase = "costruzione",
		livello = livello,
		round = 1,
		lati = { lato(a, "giocatore"), b and lato(b, "nemico") or latoBot("nemico") },
	}
	for _, l in ipairs(partita.lati) do
		if not l.bot then
			partite[l.player] = partita
			notifica(l.player, ("RANKED: %s vs %s at %s! Get ready..."):format(partita.lati[1].nome, partita.lati[2].nome, livello.nome))
		end
	end
	local arena = Arena.crea(a, livello)
	if not partita.attiva then
		Arena.distruggi(arena)
		return
	end
	partita.arena = arena
	for _, l in ipairs(partita.lati) do
		if not l.bot and l.player.Parent then
			teletrasporta(l.player, l.squadra == "giocatore" and arena.arrivo or arena.arrivoOpposto)
		end
	end
	inizioRound(partita)
end

function Ranked.chiudi(partita)
	if partita.chiusa then
		return
	end
	partita.chiusa = true
	partita.attiva = false
	if partita.arena then
		Arena.distruggi(partita.arena)
	end
	for _, l in ipairs(partita.lati) do
		if not l.bot and partite[l.player] == partita then
			partite[l.player] = nil
			if l.player.Parent then
				remoti.Truppe:FireClient(l.player, { tipo = "pulisci" })
			end
		end
	end
end

local function togliDallaCoda(player)
	local i = table.find(coda, player)
	if i then
		table.remove(coda, i)
	end
	codaDal[player] = nil
	return i ~= nil
end

local function abbina()
	-- Chi nel frattempo è entrato in una battaglia della campagna o è uscito lascia la coda.
	for i = #coda, 1, -1 do
		local p = coda[i]
		if not p.Parent or (occupato and occupato(p)) or partite[p] then
			togliDallaCoda(p)
		end
	end
	while #coda >= 2 do
		local a = table.remove(coda, 1)
		local b = table.remove(coda, 1)
		codaDal[a], codaDal[b] = nil, nil
		task.spawn(crea, a, b)
	end
end

-- Pulsante RANKED: entra in coda, oppure esce se c'era già. Il portale della lobby (soloEntra) non fa
-- uscire dalla coda: lo si tocca più volte camminandoci dentro.
function Ranked.richiesta(player, soloEntra)
	if partite[player] then
		if not soloEntra then
			notifica(player, "You are already in a ranked match.")
		end
		return false
	end
	if soloEntra and table.find(coda, player) then
		return false
	end
	if togliDallaCoda(player) then
		notifica(player, "Ranked search cancelled.")
		return false
	end
	local dati = Dati.ottieni(player)
	if not dati then
		notifica(player, "Loading your data, try again in a moment.")
		return false
	end
	if occupato and occupato(player) then
		notifica(player, "Finish your campaign battle first.")
		return false
	end
	if #dati.mazzo == 0 then
		notifica(player, "Your ARMY deck is empty: add some cards first.")
		return false
	end
	table.insert(coda, player)
	codaDal[player] = os.clock()
	notifica(player, "Searching for an opponent... (press RANKED again to cancel)")
	abbina()
	if Prova then
		task.delay(ATTESA_BOT, function()
			if codaDal[player] and table.find(coda, player) and os.clock() - codaDal[player] >= ATTESA_BOT - 0.1 then
				togliDallaCoda(player)
				notifica(player, "Studio test: no opponent found, you face a training dummy.")
				task.spawn(crea, player, nil)
			end
		end)
	end
	return true
end

function Ranked.inCoda(player)
	return table.find(coda, player) ~= nil
end

function Ranked.inPartita(player)
	return partite[player] ~= nil
end

local function latoDi(player)
	local partita = partite[player]
	if not partita then
		return nil
	end
	for _, l in ipairs(partita.lati) do
		if l.player == player then
			return partita, l
		end
	end
	return nil
end

function Ranked.schiera(player, indici, formazione)
	local partita, l = latoDi(player)
	if not partita or partita.fase ~= "piazzamento" then
		return false, "You are not deploying troops right now."
	end
	if typeof(indici) ~= "table" then
		return false, "Invalid choice."
	end
	local scelte, viste = {}, {}
	for _, indice in ipairs(indici) do
		if typeof(indice) ~= "number" or not l.mazzo[indice] or viste[indice] then
			return false, "Invalid card."
		end
		viste[indice] = true
		table.insert(scelte, indice)
	end
	if #scelte > maxReggimenti() then
		return false, "Maximum " .. maxReggimenti() .. " regiments in ranked."
	end
	if formazione ~= nil and formazione ~= l.formazione then
		local dati = Dati.ottieni(player)
		if typeof(formazione) ~= "string" or not Formazioni.sbloccata(formazione, dati and dati.livello) then
			return false, "That formation is still locked."
		end
		l.formazione = formazione
	end
	l.scelte = scelte
	disponi(partita, l)
	inviaSchieramento(partita, l)
	return true, nil, table.clone(scelte)
end

function Ranked.combatti(player)
	local partita, l = latoDi(player)
	if not partita or partita.fase ~= "piazzamento" then
		return false, "You are not deploying troops right now."
	end
	if #l.scelte == 0 then
		return false, "Deploy at least one regiment first."
	end
	partita.pronti[l] = true
	for _, altro in ipairs(partita.lati) do
		if not altro.bot and altro.player.Parent and not partita.pronti[altro] then
			notifica(altro.player, l.nome .. " is ready to fight!")
			return true, "Ready! Waiting for your opponent..."
		end
	end
	Ranked.avviaBattaglia(partita)
	return true
end

function Ranked.ordine(player, nome)
	local partita, l = latoDi(player)
	local battaglia = partita and partita.battaglia
	if not battaglia then
		return false, "Orders can be given during the battle."
	end
	if typeof(nome) ~= "string" then
		return false
	end
	return battaglia:ordine(l.squadra, nome)
end

function Ranked.bersaglio(player, filtro, proprio)
	local partita, l = latoDi(player)
	local battaglia = partita and partita.battaglia
	if not battaglia then
		return false, "Targets can be given during the battle."
	end
	if filtro ~= nil and typeof(filtro) ~= "string" and typeof(filtro) ~= "number" then
		return false
	end
	if typeof(filtro) == "number" and suoReggimento(l, filtro) then
		return false
	end
	if proprio ~= nil and not suoReggimento(l, proprio) then
		return false
	end
	return battaglia:bersaglio(l.squadra, filtro, proprio)
end

function Ranked.abilita(player, id)
	local partita, l = latoDi(player)
	local battaglia = partita and partita.battaglia
	if not battaglia or not suoReggimento(l, id) then
		return false, "Abilities can be used during the battle."
	end
	if not battaglia:attivaAbilita(id) then
		return false, "This ability is not available right now."
	end
	return true
end

-- Modalità prova: WIN ROUND.
function Ranked.vinciRound(player)
	local partita, l = latoDi(player)
	if not Prova or not partita then
		return false
	end
	if partita.fase == "battaglia" then
		partita.vinciSubito = l.squadra
		return true
	elseif partita.fase == "piazzamento" then
		Ranked.avviaBattaglia(partita)
		partita.vinciSubito = l.squadra
		return true
	end
	return false
end

function Ranked.tornaLobby(player)
	local partita = partite[player]
	if partita and partita.fase ~= "risultato" then
		return false, "Finish the ranked match first."
	end
	partite[player] = nil
	if partita then
		-- Se nessun giocatore vero è più nella partita, il campo si toglie subito.
		local resta = false
		for _, l in ipairs(partita.lati) do
			if not l.bot and partite[l.player] == partita then
				resta = true
			end
		end
		if not resta then
			Ranked.chiudi(partita)
		end
	end
	remoti.Truppe:FireClient(player, { tipo = "pulisci" })
	teletrasporta(player, Lobby.SPAWN)
	remoti.Fase:FireClient(player, { fase = "lobby" })
	return true
end

-- Chi esce a metà partita perde: vince l'altro.
function Ranked.giocatoreUscito(player)
	togliDallaCoda(player)
	local partita, l = latoDi(player)
	if not partita then
		return
	end
	partite[player] = nil
	if partita.attiva and partita.fase ~= "risultato" then
		local altro = avversarioDi(partita, l)
		altro.punti = math.max(altro.punti, ROUND_PER_VINCERE)
		fine(partita, altro, true)
	end
	local resta = false
	for _, x in ipairs(partita.lati) do
		if not x.bot and partite[x.player] == partita then
			resta = true
		end
	end
	if not resta then
		Ranked.chiudi(partita)
	end
end

-- funzioneOccupato(player): true se il giocatore è in una battaglia della campagna.
function Ranked.inizializza(r, funzioneOccupato)
	remoti = r
	occupato = funzioneOccupato
	Players.PlayerRemoving:Connect(Ranked.giocatoreUscito)
end

return Ranked
