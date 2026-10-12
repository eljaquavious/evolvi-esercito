-- Cinematica prima di un livello: una breve scena muta, con musica, che racconta la battaglia vera
-- sul campo del livello, con i soldati e i generali del gioco. Bande nere, scritte brevi, SKIP.
-- La sceneggiatura di ogni battaglia è in CinematicheDati: reparti che marciano lungo delle tappe,
-- inquadrature, scritte, lanci di pilum, mischie e caduti. Tutto vive solo su questo client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modelli = require(Shared.Modelli)
local Animatore = require(script.Parent.Animatore)
local Effetti = require(script.Parent.Effetti)
local Dati = require(script.Parent.CinematicheDati)

local Cinematica = {}

local player = Players.LocalPlayer

local GARAMOND = Font.fromEnum(Enum.Font.Garamond).Family
local FONT = Font.new(GARAMOND, Enum.FontWeight.Bold)
local FONT_CORSIVO = Font.new(GARAMOND, Enum.FontWeight.Regular, Enum.FontStyle.Italic)
local BANDA = 0.11 -- altezza delle bande nere, in frazione dello schermo
local VELOCITA = { cavalleria = 15, carro = 8 } -- studs al secondo per raggiungere il posto nel reparto
local DISTANZA_MISCHIA = 4.6

local inCorso = nil -- la cinematica che sta andando, con tutto quello che va tolto alla fine
local livelloRaggiunto = 1 -- il primo livello non ancora vinto
local viste = {} -- cinematiche già viste in questa sessione

function Cinematica.aggiorna(stato)
	if stato and stato.livello then
		livelloRaggiunto = stato.livello
	end
end

-- Parte da sola solo la prima volta: per un livello non ancora vinto e non ancora vista in questa
-- sessione (se si perde e si riprova non la si rivede). In Studio sempre, per provarla.
function Cinematica.daMostrare(nome, numero)
	if not Dati[nome] then
		return false
	end
	if RunService:IsStudio() then
		return true
	end
	return numero >= livelloRaggiunto and not viste[nome]
end

function Cinematica.esiste(nome)
	return Dati[nome] ~= nil
end

function Cinematica.inCorso()
	return inCorso ~= nil
end

local function liscio(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function vettore(v)
	return Vector3.new(v[1], v[2], v[3])
end

local function avanti(angolo)
	return Vector3.new(math.sin(angolo), 0, math.cos(angolo))
end

-- Posizione (x, z) e direzione del reparto al tempo t: tra una tappa e l'altra si va in linea retta.
local function statoReparto(reparto, t)
	local tappe = reparto.tappe
	local prima = tappe[1]
	if t <= prima.t then
		return prima.x, prima.z, prima.a
	end
	for i = 2, #tappe do
		local dopo = tappe[i]
		if t <= dopo.t then
			local f = (t - prima.t) / math.max(0.01, dopo.t - prima.t)
			if dopo.liscio then
				f = liscio(f)
			end
			local a0, a1 = prima.a, dopo.a
			local da = (a1 - a0 + 180) % 360 - 180
			return prima.x + (dopo.x - prima.x) * f, prima.z + (dopo.z - prima.z) * f, a0 + da * f
		end
		prima = dopo
	end
	return prima.x, prima.z, prima.a
end

-- Le tappe ereditano dalla precedente quello che non dicono (spesso cambia solo z, o solo a).
local function completaTappe(reparto)
	local ultima = { t = 0, x = 0, z = 0, a = 0 }
	for _, tappa in ipairs(reparto.tappe) do
		tappa.x = tappa.x or ultima.x
		tappa.z = tappa.z or ultima.z
		tappa.a = tappa.a or ultima.a
		ultima = tappa
	end
end

-- Quota del terreno (solo il terreno: niente alberi o caselle), con una cache per cella di 2 studs.
local function nuovaQuota(centro)
	local parametri = RaycastParams.new()
	parametri.FilterType = Enum.RaycastFilterType.Include
	parametri.FilterDescendantsInstances = { workspace.Terrain }
	parametri.IgnoreWater = false
	local cache = {}
	return function(x, z)
		local chiave = math.floor(x / 2) .. "," .. math.floor(z / 2)
		local q = cache[chiave]
		if not q then
			local colpo = workspace:Raycast(Vector3.new(x, centro.Y + 150, z), Vector3.new(0, -320, 0), parametri)
			if not colpo then
				return centro.Y
			end
			q = colpo.Position.Y
			cache[chiave] = q
		end
		return q
	end
end

-- Nasconde (solo qui) le caselle del campo e il personaggio del giocatore: nella scena non c'entrano.
local function nascondi(stato, radice)
	if not radice then
		return
	end
	for _, pezzo in ipairs(radice:GetDescendants()) do
		if pezzo:IsA("BasePart") then
			table.insert(stato.nascosti, pezzo)
			pezzo.LocalTransparencyModifier = 1
		elseif pezzo:IsA("Decal") or pezzo:IsA("BillboardGui") or pezzo:IsA("SurfaceGui") then
			if pezzo:IsA("Decal") then
				table.insert(stato.decalNascosti, { pezzo, pezzo.Transparency })
				pezzo.Transparency = 1
			else
				table.insert(stato.guiNascoste, { pezzo, pezzo.Enabled })
				pezzo.Enabled = false
			end
		end
	end
end

-- Toglie (solo qui) alberi, tende e rocce dalle zone dove passano i reparti o la telecamera.
-- zone: { x0, z0, x1, z1 } dal centro della scena. I pezzi molto grandi (terreno, cornice) restano.
local function sgombra(stato, radice, zone)
	if not radice or not zone then
		return
	end
	for _, pezzo in ipairs(radice:GetDescendants()) do
		if pezzo:IsA("BasePart") and pezzo.LocalTransparencyModifier < 1 then
			local dimensione = pezzo.Size
			if math.max(dimensione.X, dimensione.Z) < 40 then
				local p = pezzo.Position - stato.centro
				for _, z in ipairs(zone) do
					if p.X >= z[1] and p.X <= z[3] and p.Z >= z[2] and p.Z <= z[4] then
						table.insert(stato.nascosti, pezzo)
						pezzo.LocalTransparencyModifier = 1
						break
					end
				end
			end
		end
	end
end

local function controlli(attivi)
	local ok, modulo = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)):GetControls()
	end)
	if ok and modulo then
		if attivi then
			modulo:Enable()
		else
			modulo:Disable()
		end
	end
end

local function creaInterfaccia(stato, suSkip)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Cinematica"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	stato.gui = gui

	local function banda(sopra)
		local f = Instance.new("Frame")
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0, sopra and 1 or 0)
		f.Position = UDim2.fromScale(0, sopra and 0 or 1)
		f.Size = UDim2.fromScale(1, BANDA)
		f.ZIndex = 2
		f.Parent = gui
		TweenService:Create(f, TweenInfo.new(0.8, Enum.EasingStyle.Quad), {
			Position = UDim2.fromScale(0, sopra and BANDA or 1 - BANDA),
		}):Play()
		return f
	end
	stato.bandaSopra = banda(true)
	stato.bandaSotto = banda(false)

	local nero = Instance.new("Frame")
	nero.BackgroundColor3 = Color3.new(0, 0, 0)
	nero.BorderSizePixel = 0
	nero.Size = UDim2.fromScale(1, 1)
	nero.ZIndex = 1
	nero.Parent = gui
	stato.nero = nero

	local scritta = Instance.new("TextLabel")
	scritta.BackgroundTransparency = 1
	scritta.AnchorPoint = Vector2.new(0.5, 1)
	scritta.Position = UDim2.fromScale(0.5, 1 - BANDA - 0.04)
	scritta.Size = UDim2.fromScale(0.8, 0.07)
	scritta.FontFace = FONT_CORSIVO
	scritta.TextScaled = true
	scritta.TextColor3 = Color3.fromRGB(245, 236, 214)
	scritta.TextStrokeTransparency = 0.55
	scritta.TextTransparency = 1
	scritta.TextStrokeColor3 = Color3.new(0, 0, 0)
	scritta.ZIndex = 3
	scritta.Text = ""
	scritta.Parent = gui
	local limite = Instance.new("UITextSizeConstraint")
	limite.MaxTextSize = 46
	limite.Parent = scritta
	stato.scritta = scritta

	local titolo = Instance.new("TextLabel")
	titolo.BackgroundTransparency = 1
	titolo.AnchorPoint = Vector2.new(0.5, 0.5)
	titolo.Position = UDim2.fromScale(0.5, 0.42)
	titolo.Size = UDim2.fromScale(0.8, 0.17)
	titolo.FontFace = FONT
	titolo.TextScaled = true
	titolo.TextColor3 = Color3.fromRGB(255, 226, 150)
	titolo.TextStrokeTransparency = 0.3
	titolo.TextTransparency = 1
	titolo.ZIndex = 4
	titolo.Text = ""
	titolo.Parent = gui
	stato.titolo = titolo

	local sotto = titolo:Clone()
	sotto.Position = UDim2.fromScale(0.5, 0.54)
	sotto.Size = UDim2.fromScale(0.6, 0.06)
	sotto.FontFace = FONT_CORSIVO
	sotto.TextColor3 = Color3.fromRGB(245, 236, 214)
	sotto.Parent = gui
	stato.sottotitolo = sotto

	local motto = sotto:Clone()
	motto.Position = UDim2.fromScale(0.5, 0.63)
	motto.Size = UDim2.fromScale(0.7, 0.055)
	motto.FontFace = FONT
	motto.TextColor3 = Color3.fromRGB(255, 255, 255)
	motto.Parent = gui
	stato.motto = motto

	local skip = Instance.new("TextButton")
	skip.AnchorPoint = Vector2.new(1, 0.5)
	skip.Position = UDim2.new(1, -24, 1 - BANDA / 2, 0)
	skip.Size = UDim2.fromScale(0.13, BANDA * 0.5)
	skip.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	skip.BackgroundTransparency = 0.2
	skip.FontFace = FONT
	skip.Text = "SKIP  ▸▸"
	skip.TextScaled = true
	skip.TextColor3 = Color3.fromRGB(240, 240, 240)
	skip.ZIndex = 5
	skip.AutoButtonColor = true
	local angoli = Instance.new("UICorner")
	angoli.CornerRadius = UDim.new(0.3, 0)
	angoli.Parent = skip
	local bordo = Instance.new("UIStroke")
	bordo.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bordo.Color = Color3.fromRGB(200, 200, 200)
	bordo.Transparency = 0.5
	bordo.Thickness = 1.5
	bordo.Parent = skip
	local margine = Instance.new("UIPadding")
	margine.PaddingTop = UDim.new(0.2, 0)
	margine.PaddingBottom = UDim.new(0.2, 0)
	margine.Parent = skip
	skip.Parent = gui
	skip.Activated:Connect(suSkip)
end

local function dissolvi(oggetto, proprieta, valore, durata)
	TweenService:Create(oggetto, TweenInfo.new(durata, Enum.EasingStyle.Quad), { [proprieta] = valore }):Play()
end

-- Crea i soldati di un reparto in formazione: "file" uomini per riga, "righe" righe dietro la prima.
local function creaReparto(stato, reparto, quota)
	completaTappe(reparto)
	local x, z, a = statoReparto(reparto, 0)
	reparto.soldati = {}
	local passo = reparto.passo or 3.4
	local file, righe = reparto.file or 1, reparto.righe or 1
	for r = 1, righe do
		for f = 1, file do
			-- Un po' di disordine: un reparto vero non è una scacchiera.
			local ox = (f - (file + 1) / 2) * passo + (math.random() - 0.5) * passo * 0.3
			local oz = -(r - 1) * passo + (math.random() - 0.5) * passo * 0.3
			local s = {
				reparto = reparto,
				squadra = reparto.squadra,
				offset = Vector2.new(ox, oz),
				vivo = true,
				prossimoColpo = 0,
				ritardo = math.random() * 0.6, -- non partono tutti nello stesso istante
				fila = r,
			}
			local destra = Vector3.new(math.cos(math.rad(a)), 0, -math.sin(math.rad(a)))
			local p = stato.centro + Vector3.new(x, 0, z) + destra * ox + avanti(math.rad(a)) * oz
			p = Vector3.new(p.X, quota(p.X, p.Z), p.Z)
			s.posizione = p
			s.angolo = math.rad(a)
			if stato.finita then
				return
			end
			local modello, info = Modelli.crea(reparto.tipo, reparto.squadra, CFrame.lookAt(p, p + avanti(s.angolo)))
			modello.Parent = stato.cartella
			s.modello = modello
			s.animatore = Animatore.nuovo(modello, info, reparto.tipo)
			s.velocita = VELOCITA[s.animatore.stile] or 6.5
			table.insert(reparto.soldati, s)
			table.insert(stato.soldati, s)
		end
		if r % 2 == 0 then
			task.wait()
		end
	end
end

local function postoNelReparto(stato, s, t)
	local x, z, a = statoReparto(s.reparto, math.max(0, t - s.ritardo))
	local ra = math.rad(a)
	local destra = Vector3.new(math.cos(ra), 0, -math.sin(ra))
	local p = stato.centro + Vector3.new(x, 0, z) + destra * s.offset.X + avanti(ra) * s.offset.Y
	return p, ra
end

-- Ogni tanto: chi ha un nemico a portata colpisce, e il colpito accusa il colpo.
local function mischia(stato, t)
	local mischie = stato.dati.mischie
	if not mischie or t < mischie.da or t > mischie.a then
		return
	end
	for _, s in ipairs(stato.soldati) do
		s.nemico = nil
		if s.vivo then
			local migliore, dMin = nil, DISTANZA_MISCHIA
			for _, altro in ipairs(stato.soldati) do
				if altro.vivo and altro.squadra ~= s.squadra then
					local d = Vector2.new(altro.posizione.X - s.posizione.X, altro.posizione.Z - s.posizione.Z).Magnitude
					if d < dMin then
						migliore, dMin = altro, d
					end
				end
			end
			s.nemico = migliore
			if migliore and t >= s.prossimoColpo then
				s.prossimoColpo = t + 0.7 + math.random() * 0.9
				s.animatore:attacca("mischia", 0.22 + math.random() * 0.1)
				local bersaglio = migliore
				task.delay(0.3, function()
					if bersaglio.vivo and bersaglio.modello.Parent then
						bersaglio.animatore:ferito()
						if math.random() < 0.25 then
							Effetti.scintille(bersaglio.posizione + Vector3.new(0, 2.6, 0))
						end
					end
				end)
			end
		end
	end
end

local function muori(s)
	if not s.vivo then
		return
	end
	s.vivo = false
	s.animatore:muori()
end

-- Caduti: una quota del reparto cade un po' alla volta tra "da" e "a", prima chi è in mischia.
local function cadute(stato, t)
	for _, c in ipairs(stato.dati.cadute or {}) do
		local reparto = stato.reparti[c.reparto]
		if reparto and t >= c.da then
			local f = math.clamp((t - c.da) / math.max(0.1, c.a - c.da), 0, 1)
			local dovuti = math.floor(#reparto.soldati * c.quota * f + 0.5)
			c.caduti = c.caduti or 0
			while c.caduti < dovuti do
				local scelto
				for _, s in ipairs(reparto.soldati) do
					if s.vivo and s.nemico then
						scelto = s
						break
					end
				end
				if not scelto then
					local vivi = {}
					for _, s in ipairs(reparto.soldati) do
						if s.vivo then
							table.insert(vivi, s)
						end
					end
					scelto = vivi[math.random(math.max(1, #vivi))]
				end
				if not scelto then
					break
				end
				muori(scelto)
				c.caduti += 1
			end
		end
	end
end

-- Lanci: la prima riga (o le prime "righe") del reparto lancia verso il reparto bersaglio.
local function lanci(stato, t)
	for _, l in ipairs(stato.dati.lanci or {}) do
		if not l.fatto and t >= l.t then
			l.fatto = true
			local reparto, bersaglio = stato.reparti[l.reparto], stato.reparti[l.verso]
			if reparto and bersaglio then
				for _, s in ipairs(reparto.soldati) do
					if s.vivo and s.fila <= (l.righe or 1) then
						local ritardo = math.random() * 0.35
						task.delay(ritardo, function()
							if not s.modello.Parent then
								return
							end
							s.animatore:attacca(l.colpo or "lancio", 0.4)
							task.delay(0.4, function()
								if not s.modello.Parent then
									return
								end
								local mira = bersaglio.soldati[math.random(#bersaglio.soldati)]
								local a = mira.posizione + Vector3.new(math.random() * 4 - 2, 2.4, math.random() * 4 - 2)
								local da = s.animatore:puntoTiro()
								local volo = math.clamp((a - da).Magnitude / 24, 0.5, 1.4)
								if l.colpo == "tiro" then
									Effetti.freccia(da, a, volo)
								else
									s.animatore:lasciaLancia()
									Effetti.pilum(da, a, volo)
								end
							end)
						end)
					end
				end
			end
		end
	end
end

local function aggiornaSoldati(stato, t, dt, quota)
	for _, s in ipairs(stato.soldati) do
		local prima = s.posizione
		if s.vivo then
			local posto, angoloReparto = postoNelReparto(stato, s, t)
			local verso = Vector3.new(posto.X - prima.X, 0, posto.Z - prima.Z)
			local distanza = verso.Magnitude
			local passo = math.min(distanza, s.velocita * dt, distanza * math.min(1, dt * 3) + s.velocita * dt * 0.25)
			local nuova = distanza > 0.01 and prima + verso.Unit * passo or prima
			s.posizione = Vector3.new(nuova.X, quota(nuova.X, nuova.Z), nuova.Z)
			local obiettivo = angoloReparto
			if s.nemico then
				local d = s.nemico.posizione - s.posizione
				obiettivo = math.atan2(d.X, d.Z)
			elseif distanza > 1.2 and verso.Unit:Dot(avanti(angoloReparto)) > -0.3 then
				-- Cammina guardando dove va, tranne quando arretra (il reparto resta rivolto al nemico).
				obiettivo = math.atan2(verso.X, verso.Z)
			end
			local delta = (obiettivo - s.angolo + math.pi) % (2 * math.pi) - math.pi
			s.angolo += delta * math.min(1, dt * 6)
		end
		local orizzontale = Vector3.new(s.posizione.X - prima.X, 0, s.posizione.Z - prima.Z)
		s.animatore:aggiorna(dt, dt > 0 and orizzontale.Magnitude / dt or 0)
		s.modello.PrimaryPart.CFrame = CFrame.lookAt(s.posizione, s.posizione + avanti(s.angolo))
	end
end

-- Punto di un'inquadratura: relativo al centro del campo, o al reparto che si segue.
-- L'altezza è sopra il terreno sotto quel punto (non sopra il centro del campo): rive e colline non
-- finiscono davanti all'obiettivo.
local function puntoCamera(stato, v, segui, t)
	local base = stato.centro
	if segui then
		local x, z = statoReparto(stato.reparti[segui], t)
		base += Vector3.new(x, 0, z)
	end
	local p = base + Vector3.new(v[1], 0, v[3])
	return Vector3.new(p.X, stato.quota(p.X, p.Z) + v[2], p.Z)
end

local function aggiornaCamera(stato, t)
	local camera = workspace.CurrentCamera
	local scelta
	for _, inq in ipairs(stato.dati.inquadrature) do
		if t >= inq.t then
			scelta = inq
		end
	end
	if not scelta then
		return
	end
	local f = (t - scelta.t) / scelta.durata
	f = scelta.lineare and math.clamp(f, 0, 1) or liscio(f)
	local da = puntoCamera(stato, scelta.da[1], scelta.segui, t)
	local a = puntoCamera(stato, scelta.a[1], scelta.segui, t)
	local guardaDa = puntoCamera(stato, scelta.da[2], scelta.segui, t)
	local guardaA = puntoCamera(stato, scelta.a[2], scelta.segui, t)
	local posizione = da:Lerp(a, f)
	local guarda = guardaDa:Lerp(guardaA, f)
	if scelta.scossa then
		local k = scelta.scossa
		posizione += Vector3.new(math.noise(t * 3, 1) * k, math.noise(t * 3, 2) * k, math.noise(t * 3, 3) * k)
	end
	camera.CFrame = CFrame.lookAt(posizione, guarda)
	camera.FieldOfView = scelta.fov or 55
	if stato.profondita then
		stato.profondita.Enabled = scelta.fuoco ~= nil
		if scelta.fuoco then
			stato.profondita.FocusDistance = (guarda - posizione).Magnitude * scelta.fuoco
		end
	end
end

local function aggiornaScritte(stato, t)
	for _, s in ipairs(stato.dati.scritte or {}) do
		if not s.mostrata and t >= s.t then
			s.mostrata = true
			stato.scritta.Text = s.testo
			dissolvi(stato.scritta, "TextTransparency", 0, 0.6)
			dissolvi(stato.scritta, "TextStrokeTransparency", 0.55, 0.6)
			task.delay(s.durata, function()
				if stato.scritta.Text == s.testo then
					dissolvi(stato.scritta, "TextTransparency", 1, 0.6)
					dissolvi(stato.scritta, "TextStrokeTransparency", 1, 0.6)
				end
			end)
		end
	end
	local titolo = stato.dati.titolo
	if titolo and not titolo.mostrato and t >= titolo.t then
		titolo.mostrato = true
		dissolvi(stato.nero, "BackgroundTransparency", 0.35, 1.2)
		stato.titolo.Text = titolo.testo
		stato.sottotitolo.Text = titolo.sotto or ""
		stato.motto.Text = titolo.motto or ""
		dissolvi(stato.titolo, "TextTransparency", 0, 1.2)
		task.delay(0.8, dissolvi, stato.sottotitolo, "TextTransparency", 0, 1)
		task.delay(1.8, dissolvi, stato.motto, "TextTransparency", 0, 1)
	end
end

local function finisci(stato, subito)
	if stato.finita then
		return
	end
	stato.finita = true
	if stato.connessione then
		stato.connessione:Disconnect()
	end
	if stato.musica then
		local musica = stato.musica
		dissolvi(musica, "Volume", 0, 1.2)
		task.delay(1.3, function()
			musica:Destroy()
		end)
	end
	stato.cartella:Destroy()
	Effetti.pulisci()
	for _, pezzo in ipairs(stato.nascosti) do
		if pezzo.Parent then
			pezzo.LocalTransparencyModifier = 0
		end
	end
	for _, d in ipairs(stato.decalNascosti) do
		if d[1].Parent then
			d[1].Transparency = d[2]
		end
	end
	for _, g in ipairs(stato.guiNascoste) do
		if g[1].Parent then
			g[1].Enabled = g[2]
		end
	end
	for _, effetto in ipairs(stato.effetti) do
		effetto:Destroy()
	end
	local camera = workspace.CurrentCamera
	camera.FieldOfView = 70
	camera.CameraType = Enum.CameraType.Custom
	controlli(true)
	inCorso = nil
	local gui = stato.gui
	if subito then
		-- Il giocatore è uscito: niente dissolvenza, la mappa o la lobby si vedono subito.
		gui:Destroy()
		task.spawn(stato.fine)
		return
	end
	-- Dissolvenza in uscita: il nero resta un attimo mentre il gioco rimette la sua telecamera.
	dissolvi(stato.nero, "BackgroundTransparency", 0, 0.15)
	task.delay(0.25, function()
		for _, figlio in ipairs(gui:GetChildren()) do
			if figlio:IsA("GuiObject") and figlio ~= stato.nero then
				figlio.Visible = false
			end
		end
		dissolvi(stato.nero, "BackgroundTransparency", 1, 0.6)
		task.delay(0.7, function()
			gui:Destroy()
		end)
	end)
	task.spawn(stato.fine)
end

-- Interrompe la cinematica in corso (il giocatore esce dalla partita); fine() viene chiamata comunque.
function Cinematica.ferma()
	if inCorso then
		finisci(inCorso, true)
	end
end

-- Fa partire la cinematica della battaglia "nome" sul campo centrato in "centro".
-- arena: il modello del campo (se ne nascondono le caselle). fine() viene chiamata alla fine o con SKIP.
function Cinematica.riproduci(nome, centro, arena, fine)
	local sceneggiatura = Dati[nome]
	if not sceneggiatura or inCorso then
		task.spawn(fine)
		return false
	end
	-- Ogni volta una copia: la sceneggiatura si segna cosa ha già fatto (scritte, lanci, caduti).
	local dati = table.clone(sceneggiatura)
	for _, chiave in ipairs({ "scritte", "lanci", "cadute" }) do
		if dati[chiave] then
			local copia = {}
			for i, v in ipairs(dati[chiave]) do
				copia[i] = table.clone(v)
			end
			dati[chiave] = copia
		end
	end
	if dati.titolo then
		dati.titolo = table.clone(dati.titolo)
	end

	local stato = {
		dati = dati,
		-- La scena può svolgersi lontano dal centro del campo (per esempio fuori dal fiume).
		centro = centro + Vector3.new(sceneggiatura.origine and sceneggiatura.origine[1] or 0, 0, sceneggiatura.origine and sceneggiatura.origine[2] or 0),
		fine = fine,
		soldati = {},
		reparti = {},
		nascosti = {},
		decalNascosti = {},
		guiNascoste = {},
		effetti = {},
	}
	inCorso = stato
	viste[nome] = true
	creaInterfaccia(stato, function()
		finisci(stato)
	end)
	controlli(false)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable

	stato.cartella = Instance.new("Folder")
	stato.cartella.Name = "CinematicaAttori"
	stato.cartella.Parent = workspace

	if arena then
		local tabellone = {}
		for _, figlio in ipairs(arena:GetDescendants()) do
			if figlio:IsA("Model") and string.sub(figlio.Name, 1, 8) == "Casella_" then
				table.insert(tabellone, figlio)
			end
		end
		for _, casella in ipairs(tabellone) do
			nascondi(stato, casella)
		end
	end
	nascondi(stato, player.Character)
	sgombra(stato, arena, dati.sgombra)

	-- Colori da film: un po' più di contrasto, toni caldi, profondità di campo per i primi piani.
	local colore = Instance.new("ColorCorrectionEffect")
	colore.Name = "CinematicaColore"
	colore.Contrast = 0.12
	colore.Saturation = -0.08
	colore.TintColor = dati.tinta or Color3.fromRGB(255, 244, 228)
	colore.Parent = Lighting
	table.insert(stato.effetti, colore)
	local profondita = Instance.new("DepthOfFieldEffect")
	profondita.Name = "CinematicaFuoco"
	profondita.FarIntensity = 0.45
	profondita.InFocusRadius = 18
	profondita.NearIntensity = 0
	profondita.Enabled = false
	profondita.Parent = Lighting
	table.insert(stato.effetti, profondita)
	stato.profondita = profondita

	local quota = nuovaQuota(stato.centro)
	stato.quota = quota
	-- Il terreno attorno al campo può non essere ancora arrivato: si aspetta un attimo, a schermo nero.
	local ok = pcall(function()
		player:RequestStreamAroundAsync(centro, 3)
	end)
	if not ok then
		task.wait(0.2)
	end
	-- I reparti della sceneggiatura servono a ogni visione: qui se ne usa una copia con i suoi soldati.
	for _, reparto in ipairs(dati.reparti) do
		local copia = table.clone(reparto)
		copia.tappe = {}
		for i, tappa in ipairs(reparto.tappe) do
			copia.tappe[i] = table.clone(tappa)
		end
		stato.reparti[reparto.id] = copia
		creaReparto(stato, copia, quota)
		if stato.finita then
			return true
		end
	end

	if dati.musica and dati.musica.id then
		local musica = Instance.new("Sound")
		musica.Name = "MusicaCinematica"
		musica.SoundId = dati.musica.id
		musica.Volume = dati.musica.volume or 0.6
		musica.TimePosition = dati.musica.inizio or 0
		musica.Parent = SoundService
		musica:Play()
		stato.musica = musica
	end

	dissolvi(stato.nero, "BackgroundTransparency", 1, 1.5)
	local inizio = os.clock()
	local ultimo = 0
	local prossimaMischia = 0
	stato.connessione = RunService.RenderStepped:Connect(function()
		local t = os.clock() - inizio
		local dt = math.min(0.1, t - ultimo)
		ultimo = t
		if t >= prossimaMischia then
			prossimaMischia = t + 0.2
			mischia(stato, t)
		end
		lanci(stato, t)
		cadute(stato, t)
		aggiornaSoldati(stato, t, dt, quota)
		aggiornaCamera(stato, t)
		aggiornaScritte(stato, t)
		if stato.musica and t > dati.durata - 1.5 then
			stato.musica.Volume = math.max(0, stato.musica.Volume - dt * 0.5)
		end
		if t >= dati.durata then
			finisci(stato)
		end
	end)
	return true
end

return Cinematica
