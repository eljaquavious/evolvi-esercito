-- Partite della campagna: piazzamento, battaglia automatica e ricompense.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage.Shared
local Battaglia = require(Shared.Battaglia)
local Campagna = require(Shared.Config.Campagna)
local Epoche = require(Shared.Config.Epoche)
local Arena = require(script.Parent.Arena)
local Modelli = require(script.Parent.Modelli)
local Dati = require(script.Parent.Dati)
local Lobby = require(script.Parent.Lobby)

local GestoreCampagna = {}

local TICK = 0.1
local MONETE_SCONFITTA = 10

local sessioni = {}
local remoti

local function personaggio(player)
	local character = player.Character
	local radice = character and character:FindFirstChild("HumanoidRootPart")
	return character, radice
end

local function teletrasporta(player, posizione, blocca)
	local character, radice = personaggio(player)
	if not character then
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

local function infoTruppa(id)
	local def = Epoche.Truppe[id]
	return {
		id = def.id,
		nome = def.nome,
		classe = def.classe,
		descrizione = def.descrizione,
		hp = def.hp,
		danno = def.danno,
		gittata = def.gittata,
	}
end

function GestoreCampagna.avvia(player)
	local dati = Dati.ottieni(player)
	if not dati then
		return false, "Dati non ancora caricati, riprova tra un attimo."
	end
	local esistente = sessioni[player]
	if esistente and esistente.fase == "battaglia" then
		return false, "Hai già una battaglia in corso."
	end
	chiudiSessione(player)

	local livello = Campagna.livello(dati.livello)
	local arena = Arena.crea(player, livello.bioma)
	local sessione = {
		attiva = true,
		fase = "piazzamento",
		livello = livello,
		arena = arena,
		piazzate = {}, -- ["col,riga"] = { tipo, modello }
		numero = 0,
	}
	sessioni[player] = sessione
	teletrasporta(player, arena.belvedere, true)

	local truppe = {}
	for _, id in ipairs(livello.epoca.truppe) do
		table.insert(truppe, infoTruppa(id))
	end
	remoti.Fase:FireClient(player, {
		fase = "piazzamento",
		livello = livello.numero,
		totale = Campagna.TOTALE,
		locale = livello.locale,
		epoca = livello.epoca.nome,
		bioma = arena.bioma.nome,
		nebbia = arena.bioma.nebbia,
		maxTruppe = livello.maxTruppe,
		truppe = truppe,
		arena = arena.modello.Name,
		centro = arena.origine,
	})
	return true
end

function GestoreCampagna.casella(player, tipo, col, riga)
	local sessione = sessioni[player]
	if not sessione or sessione.fase ~= "piazzamento" then
		return false, "Non sei in fase di piazzamento."
	end
	if typeof(col) ~= "number" or typeof(riga) ~= "number" then
		return false, "Casella non valida."
	end
	col, riga = math.floor(col), math.floor(riga)
	if col < 1 or col > Arena.COLONNE or riga < 1 or riga > Campagna.RIGHE_GIOCATORE then
		return false, "Puoi piazzare le truppe solo nella tua metà del campo."
	end
	local chiave = col .. "," .. riga
	local occupata = sessione.piazzate[chiave]
	if occupata then
		occupata.modello:Destroy()
		sessione.piazzate[chiave] = nil
		sessione.numero -= 1
		return true, nil, sessione.numero
	end
	if not table.find(sessione.livello.epoca.truppe, tipo) then
		return false, "Scegli prima una truppa."
	end
	if sessione.numero >= sessione.livello.maxTruppe then
		return false, "Hai raggiunto il massimo di " .. sessione.livello.maxTruppe .. " truppe."
	end
	local posizione = Arena.posizione(sessione.arena, col, riga)
	local modello = Modelli.crea(tipo, "giocatore", CFrame.lookAt(posizione, posizione + Vector3.zAxis))
	modello.Parent = sessione.arena.truppe
	sessione.piazzate[chiave] = { tipo = tipo, modello = modello, col = col, riga = riga }
	sessione.numero += 1
	return true, nil, sessione.numero
end

local function proiettile(da, a, grande)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * (grande and 0.9 or 0.45)
	p.Color = grande and Color3.fromRGB(255, 170, 60) or Color3.fromRGB(255, 236, 160)
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Position = da
	p.Parent = workspace
	TweenService:Create(p, TweenInfo.new(0.15, Enum.EasingStyle.Linear), { Position = a }):Play()
	Debris:AddItem(p, 0.2)
end

local function rendiTrasparente(modello)
	for _, parte in ipairs(modello:GetDescendants()) do
		if parte:IsA("BasePart") and parte.Name ~= "Radice" then
			TweenService:Create(parte, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		end
	end
	Debris:AddItem(modello, 0.5)
end

local function eseguiBattaglia(player, sessione)
	local livello = sessione.livello
	local arena = sessione.arena
	local unita = {}
	local modelli = {}

	local id = 0
	for _, piazzata in pairs(sessione.piazzate) do
		id += 1
		table.insert(unita, {
			id = id,
			squadra = "giocatore",
			def = Epoche.Truppe[piazzata.tipo],
			x = piazzata.col,
			y = piazzata.riga,
		})
		modelli[id] = piazzata.modello
	end
	for i, nemico in ipairs(livello.nemici) do
		local idNemico = 100 + i
		local posizione = Arena.posizione(arena, nemico.col, nemico.riga)
		local modello = Modelli.crea(nemico.tipo, "nemico", CFrame.lookAt(posizione, posizione - Vector3.zAxis))
		modello.Parent = arena.truppe
		modelli[idNemico] = modello
		table.insert(unita, {
			id = idNemico,
			squadra = "nemico",
			def = Epoche.Truppe[nemico.tipo],
			x = nemico.col,
			y = nemico.riga,
			forza = livello.forzaNemici,
		})
	end

	remoti.Fase:FireClient(player, { fase = "battaglia" })
	task.wait(1.5) -- un momento per guardare lo schieramento nemico

	local battaglia = Battaglia.nuova(unita)
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
				local da, a = perId[evento.da], perId[evento.a]
				local altezza = Vector3.new(0, 2.5, 0)
				proiettile(Arena.posizione(arena, da.x, da.y) + altezza, Arena.posizione(arena, a.x, a.y) + altezza, da.def.id == "CarroArmato")
				local modello = modelli[evento.a]
				if modello then
					Modelli.aggiornaVita(modello, a.hp / a.hpMax)
				end
			elseif evento.tipo == "morte" then
				local modello = modelli[evento.id]
				if modello then
					rendiTrasparente(modello)
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
	local monete = vittoria and livello.ricompensa or MONETE_SCONFITTA
	local nuovaEpoca
	Dati.modifica(player, function(dati)
		dati.monete += monete
		if vittoria and livello.numero == dati.livello then
			if dati.livello < Campagna.TOTALE then
				dati.livello += 1
				if livello.ultimoDellEpoca then
					nuovaEpoca = Campagna.livello(dati.livello).epoca.nome
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
		nuovaEpoca = nuovaEpoca,
		completata = Dati.ottieni(player).campagnaCompletata,
	})
end

function GestoreCampagna.combatti(player)
	local sessione = sessioni[player]
	if not sessione or sessione.fase ~= "piazzamento" then
		return false, "Non sei in fase di piazzamento."
	end
	if sessione.numero == 0 then
		return false, "Piazza almeno una truppa prima di combattere."
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
