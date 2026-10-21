-- Lobby: la Cittadella, una fortezza chiusa in cima a una montagna al tramonto. Viene costruita all'avvio
-- del server. Al centro la Rotonda del comando (cupola con l'oculo, tavolo di guerra con il plastico
-- d'Europa e le bandierine delle battaglie); da lì quattro ali, ognuna con il suo colore e il suo tappeto
-- che porta dritto all'ingresso:
--   nord (blu)   Galleria delle Epoche: tre sale (Antichità, Medioevo, Novecento) e il portale CAMPAIGN;
--   est (rosso)  Arena Ranked: gradinate, podio e il portale RANKED (ancora chiuso);
--   ovest (oro)  Armeria: casse dello shop sui piedistalli, rastrelliere, bancone SHOP;
--   sud (verde)  Sala degli Eroi: le statue dei sei comandanti e il tavolo ARMY.
-- Qui solo la struttura ferma. Il client (LobbyVita) ci mette i soldati e le statue (attributo
-- "Esposizione"), fa girare casse, portali e fari, accelera chi cammina sui tappeti (attributo "Corsia")
-- e cambia cielo e luce quando si è in lobby.
-- Nord è -Z, est +X. Il pavimento è a y = 1.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MappaEuropa = require(ReplicatedStorage.Shared.Config.MappaEuropa)
local Campagna = require(ReplicatedStorage.Shared.Config.Campagna)
local Epoche = require(ReplicatedStorage.Shared.Config.Epoche)
local Casse = require(ReplicatedStorage.Shared.Config.Casse)

local Lobby = {}

-- Tutta la cittadella è disegnata qui sotto a misura 1 e poi ingrandita di SCALA attorno al centro della
-- Rotonda (Mattia, 18/10/2026: "troppo chiusa, in ogni caso più grande"). Montagna e fari ne tengono conto.
local SCALA = 1.35

-- Si nasce nella Rotonda, a sud del tavolo, guardando verso la Galleria e il portale della campagna.
Lobby.SPAWN = CFrame.lookAt(Vector3.new(0, 4, 32 * SCALA), Vector3.new(0, 4, 0))

local terrain = workspace.Terrain

local PAVIMENTO = 1
local R_ROTONDA = 46 -- raggio interno della Rotonda
local ALTEZZA_ROTONDA = 34

local PIETRA = Color3.fromRGB(156, 146, 132)
local PIETRA_CHIARA = Color3.fromRGB(196, 186, 168)
local PIETRA_SCURA = Color3.fromRGB(92, 86, 80)
local LEGNO = Color3.fromRGB(104, 70, 42)
local LEGNO_SCURO = Color3.fromRGB(64, 44, 30)
local FERRO = Color3.fromRGB(58, 58, 62)
local ORO = Color3.fromRGB(214, 168, 72)
local MARMO = Color3.fromRGB(226, 220, 208)
local CEMENTO = Color3.fromRGB(130, 128, 120)
local SACCHI = Color3.fromRGB(150, 132, 96)

-- Colori delle ali, gli stessi dei pulsanti della GUI.
local BLU = Color3.fromRGB(64, 150, 255)
local ROSSO = Color3.fromRGB(240, 70, 64)
local GIALLO = Color3.fromRGB(255, 190, 50)
local VERDE = Color3.fromRGB(80, 200, 90)

local ROSSO_ROMANO = Color3.fromRGB(150, 30, 30)
local BLU_REALE = Color3.fromRGB(36, 60, 140)
local OLIVA = Color3.fromRGB(86, 96, 58)

local FONT = Enum.Font.FredokaOne

---------------------------------------------------------------------------------------------------------
-- Mattoncini

local function blocco(genitore, proprieta)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.Slate
	for k, v in pairs(proprieta) do
		p[k] = v
	end
	p.Parent = genitore
	return p
end

-- Parte a scatola da dimensione, posizione/CFrame, colore e materiale.
local function scatola(genitore, dimensione, dove, colore, materiale, extra)
	local p = blocco(genitore, {
		Size = dimensione,
		CFrame = typeof(dove) == "CFrame" and dove or CFrame.new(dove),
		Color = colore,
		Material = materiale or Enum.Material.Slate,
	})
	if extra then
		for k, v in pairs(extra) do
			p[k] = v
		end
	end
	return p
end

-- Cilindro in piedi: "posizione" è il centro.
local function colonna(genitore, altezza, diametro, posizione, colore, materiale)
	return blocco(genitore, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(altezza, diametro, diametro),
		CFrame = CFrame.new(posizione) * CFrame.Angles(0, 0, math.rad(90)),
		Color = colore,
		Material = materiale or Enum.Material.Slate,
	})
end

-- Cilindro con l'asse lungo la direzione "verso" del CFrame dato (per dischi appesi ai muri, botti a terra...).
local function disco(genitore, spessore, diametro, cframe, colore, materiale)
	return blocco(genitore, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(spessore, diametro, diametro),
		CFrame = cframe * CFrame.Angles(0, math.rad(90), 0),
		Color = colore,
		Material = materiale or Enum.Material.Slate,
	})
end

local function sfera(genitore, diametro, posizione, colore, materiale)
	return blocco(genitore, {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * diametro,
		Position = posizione,
		Color = colore,
		Material = materiale or Enum.Material.Slate,
	})
end

local function luce(parte, colore, raggio, intensita, ombre)
	local l = Instance.new("PointLight")
	l.Color = colore
	l.Range = raggio
	l.Brightness = intensita
	l.Shadows = ombre == true
	l.Parent = parte
	return l
end

local function faretto(parte, colore, raggio, intensita, angolo, faccia)
	local l = Instance.new("SpotLight")
	l.Color = colore
	l.Range = raggio
	l.Brightness = intensita
	l.Angle = angolo
	l.Face = faccia or Enum.NormalId.Bottom
	l.Shadows = true
	l.Parent = parte
	return l
end

-- Scritta su una faccia di una parte: titolo grande e, se c'è, sottotitolo più piccolo sotto.
local function insegna(parte, titolo, colore, faccia, sottotitolo)
	local gui = Instance.new("SurfaceGui")
	gui.Face = faccia or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.15
	gui.MaxDistance = 400
	local function riga(testo, y, altezza, col, spessore)
		local etichetta = Instance.new("TextLabel")
		etichetta.AnchorPoint = Vector2.new(0.5, 0)
		etichetta.Position = UDim2.fromScale(0.5, y)
		etichetta.Size = UDim2.fromScale(0.94, altezza)
		etichetta.BackgroundTransparency = 1
		etichetta.Text = testo
		etichetta.TextColor3 = col
		etichetta.TextScaled = true
		etichetta.Font = FONT
		etichetta.Parent = gui
		local bordo = Instance.new("UIStroke")
		bordo.Thickness = spessore
		bordo.Color = Color3.fromRGB(27, 22, 54)
		bordo.Parent = etichetta
	end
	if sottotitolo then
		riga(titolo, 0.04, 0.6, colore, 6)
		riga(sottotitolo, 0.66, 0.3, Color3.fromRGB(255, 248, 230), 4)
	else
		riga(titolo, 0.08, 0.84, colore, 6)
	end
	gui.Parent = parte
	return gui
end

-- Cartello di legno scuro con cornice dorata, la faccia scritta guarda "verso".
local function cartello(genitore, centro, verso, larghezza, altezza, titolo, colore, sottotitolo)
	local cf = CFrame.lookAt(centro, centro + verso)
	local tavola = scatola(genitore, Vector3.new(larghezza, altezza, 0.6), cf, LEGNO_SCURO, Enum.Material.Wood)
	scatola(genitore, Vector3.new(larghezza + 0.8, 0.4, 0.8), cf * CFrame.new(0, altezza / 2, 0), ORO, Enum.Material.Slate)
	scatola(genitore, Vector3.new(larghezza + 0.8, 0.4, 0.8), cf * CFrame.new(0, -altezza / 2, 0), ORO, Enum.Material.Slate)
	insegna(tavola, titolo, colore, Enum.NormalId.Front, sottotitolo)
	return tavola
end

local function prompt(parte, azione, oggetto, callback, distanza)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = azione
	p.ObjectText = oggetto
	p.HoldDuration = 0
	p.MaxActivationDistance = distanza or 14
	p.RequiresLineOfSight = false
	p.Triggered:Connect(callback)
	p.Parent = parte
	return p
end

-- Zona invisibile che chiama callback(player) quando un giocatore ci entra.
local function soglia(genitore, dimensione, cframe, callback)
	local zona = scatola(genitore, dimensione, cframe, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, {
		Name = "Soglia",
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
	local ultimo = {}
	zona.Touched:Connect(function(colpito)
		local player = Players:GetPlayerFromCharacter(colpito.Parent)
		if not player then
			return
		end
		-- Scatta solo entrando: chi resta dentro continua a toccarla e non la fa ripartire.
		local adesso = os.clock()
		local prima = ultimo[player]
		ultimo[player] = adesso
		if prima and adesso - prima < 2.5 then
			return
		end
		callback(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		ultimo[player] = nil
	end)
	return zona
end

local function fuoco(genitore, posizione, dimensione, coloreLuce, raggio, ombre)
	local fiamma = scatola(genitore, Vector3.new(0.6, 0.6, 0.6), posizione, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local f = Instance.new("Fire")
	f.Size = dimensione
	f.Heat = dimensione * 1.6
	f.Color = Color3.fromRGB(255, 150, 60)
	f.SecondaryColor = Color3.fromRGB(255, 60, 20)
	f.Parent = fiamma
	luce(fiamma, coloreLuce or Color3.fromRGB(255, 160, 90), raggio or 18, 1.6, ombre)
	return fiamma
end

-- Torcia a muro: "verso" è la direzione in cui sporge dal muro.
local function torcia(genitore, posizione, verso)
	local cf = CFrame.lookAt(posizione, posizione + verso)
	scatola(genitore, Vector3.new(0.6, 0.6, 1.6), cf * CFrame.new(0, 0, -0.4), FERRO, Enum.Material.Metal)
	scatola(genitore, Vector3.new(0.7, 2.2, 0.7), cf * CFrame.new(0, 0.9, -1.1) * CFrame.Angles(math.rad(-18), 0, 0), LEGNO, Enum.Material.Wood)
	fuoco(genitore, (cf * CFrame.new(0, 2.3, -1.5)).Position, 2.2, nil, 18, false)
end

-- Braciere a terra su tre zampe.
local function braciere(genitore, posizione, scala, coloreLuce, raggio)
	scala = scala or 1
	for i = 0, 2 do
		local a = i * math.pi * 2 / 3
		local piede = posizione + Vector3.new(math.cos(a) * 1.2 * scala, 1.6 * scala, math.sin(a) * 1.2 * scala)
		scatola(genitore, Vector3.new(0.5, 3.4, 0.5) * scala, CFrame.lookAt(piede, posizione + Vector3.new(0, 3.2 * scala, 0)) * CFrame.Angles(math.rad(90), 0, 0), FERRO, Enum.Material.Metal)
	end
	colonna(genitore, 1.2 * scala, 4 * scala, posizione + Vector3.new(0, 3.4 * scala, 0), FERRO, Enum.Material.Metal)
	colonna(genitore, 0.4 * scala, 3.4 * scala, posizione + Vector3.new(0, 4 * scala, 0), Color3.fromRGB(255, 120, 40), Enum.Material.Neon)
	return fuoco(genitore, posizione + Vector3.new(0, 4.6 * scala, 0), 5 * scala, coloreLuce, raggio or 36, true)
end

-- Stendardo appeso: telo con bordo e un emblema dorato a rombo. Il telo guarda "verso".
local function stendardo(genitore, centro, verso, colore, larghezza, altezza)
	larghezza = larghezza or 6
	altezza = altezza or 14
	local cf = CFrame.lookAt(centro, centro + verso)
	scatola(genitore, Vector3.new(larghezza, altezza, 0.2), cf, colore, Enum.Material.Fabric)
	scatola(genitore, Vector3.new(larghezza + 1, 0.5, 0.5), cf * CFrame.new(0, altezza / 2 + 0.2, 0), LEGNO_SCURO, Enum.Material.Wood)
	scatola(genitore, Vector3.new(larghezza, 0.5, 0.25), cf * CFrame.new(0, -altezza / 2 + 0.6, -0.05), ORO, Enum.Material.Fabric)
	scatola(genitore, Vector3.new(larghezza * 0.42, larghezza * 0.42, 0.25), cf * CFrame.new(0, altezza * 0.12, -0.08) * CFrame.Angles(0, 0, math.rad(45)), ORO, Enum.Material.Fabric)
	-- Coda a punta.
	for lato = -1, 1, 2 do
		scatola(genitore, Vector3.new(larghezza * 0.6, larghezza * 0.3, 0.2), cf * CFrame.new(lato * larghezza * 0.2, -altezza / 2 - larghezza * 0.12, 0) * CFrame.Angles(0, 0, lato * math.rad(-30)), colore, Enum.Material.Fabric)
	end
end

-- Muro diritto da "a" a "b" (punti a terra), spesso "spessore", da y0 a y1, con finestre:
-- { centro = distanza da a, larghezza, basso, alto }. Restituisce le parti.
local function muro(genitore, a, b, y0, y1, spessore, colore, materiale, finestre)
	local lungo = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local lunghezza = lungo.Magnitude
	local dir = lungo.Unit
	local base = CFrame.lookAt(Vector3.new(a.X, 0, a.Z), Vector3.new(a.X, 0, a.Z) + dir)
	local parti = {}
	local function pezzo(t0, t1, ya, yb)
		if t1 - t0 < 0.05 or yb - ya < 0.05 then
			return
		end
		table.insert(parti, scatola(genitore, Vector3.new(spessore, yb - ya, t1 - t0), base * CFrame.new(0, (ya + yb) / 2, -(t0 + t1) / 2), colore, materiale))
	end
	finestre = finestre or {}
	table.sort(finestre, function(x, y)
		return x.centro < y.centro
	end)
	local t = 0
	for _, f in ipairs(finestre) do
		local inizio, fine = f.centro - f.larghezza / 2, f.centro + f.larghezza / 2
		pezzo(t, inizio, y0, y1)
		pezzo(inizio, fine, y0, f.basso)
		pezzo(inizio, fine, f.alto, y1)
		t = fine
	end
	pezzo(t, lunghezza, y0, y1)
	return parti, base
end

-- Ricorda una parte come tappeto veloce: il client accelera chi ci cammina sopra.
local function corsia(parte)
	parte:SetAttribute("Corsia", true)
	return parte
end

-- Tappeto di moquette da "a" a "b" (a terra), largo "larghezza". Tutti i tappeti sono di un solo colore,
-- marrone scuro quasi nero, senza cornice né frange (scelta di Mattia, 19/10/2026): "colore" e "aperto"
-- restano per chi lo chiama ma non cambiano più l'aspetto.
local MOQUETTE = Color3.fromRGB(40, 30, 24)
local function tappeto(genitore, a, b, larghezza, _colore, _aperto)
	local medio = (a + b) / 2
	local cf = CFrame.lookAt(Vector3.new(medio.X, PAVIMENTO, medio.Z), Vector3.new(b.X, PAVIMENTO, b.Z))
	local lunghezza = (Vector3.new(b.X, 0, b.Z) - Vector3.new(a.X, 0, a.Z)).Magnitude
	return corsia(scatola(genitore, Vector3.new(larghezza, 0.3, lunghezza), cf * CFrame.new(0, 0.15, 0), MOQUETTE, Enum.Material.Fabric))
end

---------------------------------------------------------------------------------------------------------
-- Pezzi grandi

-- Anello di muro attorno a "centro": n segmenti, salta quelli vicini agli angoli delle porte
-- (radianti; la porta ha un architrave da yPorta in su).
local function anelloMura(genitore, centro, raggio, spessore, altezza, n, porte, colore, materiale, yPorta)
	local passo = math.pi * 2 / n
	local larghezza = 2 * (raggio + spessore) * math.tan(passo / 2) + 0.3
	for i = 0, n - 1 do
		local a = i * passo
		local porta = false
		for _, p in ipairs(porte) do
			local d = math.abs(((a - p + math.pi) % (math.pi * 2)) - math.pi)
			if d < passo * 1.6 then
				porta = true
			end
		end
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local pos = centro + dir * (raggio + spessore / 2)
		local cf = CFrame.lookAt(pos, centro)
		if porta then
			scatola(genitore, Vector3.new(larghezza, altezza - yPorta, spessore), cf * CFrame.new(0, PAVIMENTO + (altezza + yPorta) / 2, 0), colore, materiale)
		else
			scatola(genitore, Vector3.new(larghezza, altezza, spessore), cf * CFrame.new(0, PAVIMENTO + altezza / 2, 0), colore, materiale)
			-- Zoccolo scuro in basso.
			scatola(genitore, Vector3.new(larghezza, 3, 0.6), cf * CFrame.new(0, PAVIMENTO + 1.5, -spessore / 2 - 0.3), PIETRA_SCURA, Enum.Material.Slate)
		end
	end
end

-- Cupola a pannelli sopra un cerchio di raggio "raggio" a quota "base", con l'oculo aperto in cima.
local function cupola(genitore, centro, raggio, n, anelli, raggioOculo, colore, coloreCostole)
	local fineAngolo = math.acos(raggioOculo / raggio)
	local passo = math.pi * 2 / n
	for k = 0, anelli - 1 do
		local p0 = fineAngolo * k / anelli
		local p1 = fineAngolo * (k + 1) / anelli
		local pm = (p0 + p1) / 2
		local altezzaArco = 2 * raggio * math.sin((p1 - p0) / 2) + 0.4
		local larghezza = 2 * raggio * math.cos(p0) * math.sin(passo / 2) * 1.08
		for i = 0, n - 1 do
			local a = (i + (k % 2) * 0.5) * passo
			local pos = centro + Vector3.new(math.cos(a) * math.cos(pm) * raggio, math.sin(pm) * raggio, math.sin(a) * math.cos(pm) * raggio)
			local cf = CFrame.lookAt(pos, centro)
			scatola(genitore, Vector3.new(larghezza, altezzaArco, 2.2), cf, colore, Enum.Material.Slate, { CastShadow = true })
		end
	end
	-- Costole dorate dal muro all'oculo.
	for i = 0, 11 do
		local a = i * math.pi / 6
		for k = 0, 9 do
			local p0 = fineAngolo * k / 10
			local p1 = fineAngolo * (k + 1) / 10
			local q0 = centro + Vector3.new(math.cos(a) * math.cos(p0), math.sin(p0), math.sin(a) * math.cos(p0)) * (raggio - 1.4)
			local q1 = centro + Vector3.new(math.cos(a) * math.cos(p1), math.sin(p1), math.sin(a) * math.cos(p1)) * (raggio - 1.4)
			scatola(genitore, Vector3.new(1.4, 1, (q1 - q0).Magnitude + 0.3), CFrame.lookAt((q0 + q1) / 2, q1), coloreCostole, Enum.Material.Wood)
		end
	end
	-- Anello dell'oculo.
	for i = 0, 23 do
		local a = i * math.pi / 12
		local pos = centro + Vector3.new(math.cos(a) * (raggioOculo + 0.6), math.sin(fineAngolo) * raggio + 0.4, math.sin(a) * (raggioOculo + 0.6))
		scatola(genitore, Vector3.new(3.2, 2.2, 1.8), CFrame.lookAt(pos, Vector3.new(centro.X, pos.Y, centro.Z)), ORO, Enum.Material.Slate)
	end
	return centro.Y + math.sin(fineAngolo) * raggio
end

-- Portale: anello di pietra con un vortice di luce che il client fa girare. "cf" è a terra al centro e
-- guarda verso chi arriva. Entrarci (o il prompt) chiama callback(player).
local function portale(genitore, nome, cf, colore, titolo, sottotitolo, callback, chiuso)
	local modello = Instance.new("Model")
	modello.Name = nome
	-- Con l'insegna sopra deve stare sotto i soffitti delle sale (30).
	local raggio = 9
	local centro = cf * CFrame.new(0, PAVIMENTO + 2 + raggio + 1.2, 0)
	-- Basamento a gradini.
	scatola(modello, Vector3.new(32, 1, 12), cf * CFrame.new(0, PAVIMENTO + 0.5, 1), PIETRA_SCURA, Enum.Material.Slate)
	scatola(modello, Vector3.new(28, 1, 9), cf * CFrame.new(0, PAVIMENTO + 1.5, 1.5), PIETRA, Enum.Material.Slate)
	-- Anello.
	local n = 30
	for i = 0, n - 1 do
		local a = i * math.pi * 2 / n
		local pos = centro * CFrame.new(math.cos(a) * (raggio + 1.4), math.sin(a) * (raggio + 1.4), 0)
		local blocchetto = scatola(modello, Vector3.new(2 * math.pi * (raggio + 1.4) / n + 0.5, 3.2, 3.6), pos * CFrame.Angles(0, 0, a + math.pi / 2), i % 5 == 0 and ORO or PIETRA_SCURA, Enum.Material.Slate)
		if i % 5 == 0 then
			blocchetto.Size += Vector3.new(0.4, 0.8, 0.6)
		end
	end
	-- Pilastri ai lati.
	for lato = -1, 1, 2 do
		scatola(modello, Vector3.new(4, 18, 5), cf * CFrame.new(lato * 14, PAVIMENTO + 2 + 9, 1), PIETRA, Enum.Material.Slate)
		scatola(modello, Vector3.new(5, 1.4, 6), cf * CFrame.new(lato * 14, PAVIMENTO + 20.6, 1), ORO, Enum.Material.Slate)
		fuoco(modello, (cf * CFrame.new(lato * 14, PAVIMENTO + 22.2, 1)).Position, 3, colore:Lerp(Color3.fromRGB(255, 170, 90), 0.5), 24, false)
	end
	-- Vortice: disco luminoso e quattro bracci a spirale (il client li fa girare).
	local velo = disco(modello, 0.3, raggio * 2 + 0.4, centro, colore, Enum.Material.Neon)
	velo.Name = "Velo"
	velo.Transparency = chiuso and 0.6 or 0.35
	velo.CanCollide = false
	velo.CastShadow = false
	-- Luce contenuta: più forte tinge del colore del portale tutta la sala e i soldati in mostra.
	luce(velo, colore, 30, 1.1, false)
	local spirale = Instance.new("Model")
	spirale.Name = "Spirale"
	for braccio = 0, 3 do
		for k = 1, 6 do
			local a = braccio * math.pi / 2 + k * 0.42
			local r = k * raggio / 6.6
			local pezzo = scatola(spirale, Vector3.new(1.4 + k * 0.45, 0.7, 0.2), centro * CFrame.new(math.cos(a) * r, math.sin(a) * r, -0.3) * CFrame.Angles(0, 0, a + math.pi / 2), colore:Lerp(Color3.new(1, 1, 1), 0.6), Enum.Material.Neon, {
				CanCollide = false,
				CastShadow = false,
				Transparency = 0.2,
			})
			pezzo.Name = "Braccio"
		end
	end
	spirale.WorldPivot = centro
	spirale:SetAttribute("Spirale", chiuso and 25 or 70)
	spirale.Parent = modello
	local scintille = Instance.new("ParticleEmitter")
	scintille.Color = ColorSequence.new(colore:Lerp(Color3.new(1, 1, 1), 0.7))
	scintille.LightEmission = 1
	scintille.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	scintille.Transparency = NumberSequence.new(0.1, 1)
	scintille.Lifetime = NumberRange.new(1.2, 2)
	scintille.Rate = chiuso and 6 or 30
	scintille.Speed = NumberRange.new(2, 5)
	scintille.SpreadAngle = Vector2.new(180, 180)
	scintille.Parent = velo

	if chiuso then
		-- Saracinesca abbassata: il portale c'è ma non si passa.
		for i = -4, 4 do
			scatola(modello, Vector3.new(0.7, raggio * 2.2, 0.7), centro * CFrame.new(i * 2.4, 0, -1.6), FERRO, Enum.Material.Metal)
		end
		for _, y in ipairs({ -6, 0, 6 }) do
			scatola(modello, Vector3.new(raggio * 2.1, 0.6, 0.6), centro * CFrame.new(0, y, -1.9), FERRO, Enum.Material.Metal)
		end
	end
	local soglia_ = soglia(modello, Vector3.new(raggio * 1.8, raggio * 2, 4), centro * CFrame.new(0, 0, chiuso and -3.4 or -1), callback)
	prompt(soglia_, chiuso and "Join queue" or "Enter", titolo, callback, 16)
	-- Insegna sopra l'anello, un po' in avanti: tutta sotto il soffitto e le travi (29.6).
	cartello(modello, (cf * CFrame.new(0, PAVIMENTO + 26.3, -2.4)).Position, cf.LookVector, 22, 4.2, titolo, colore, sottotitolo)
	modello.Parent = genitore
	return modello
end

-- Piedistallo da esposizione: il client ci mette sopra "numero" modelli di "tipo" in "righe" file,
-- rivolti verso "verso". Davanti la targa con il nome.
local function esposizione(genitore, centro, verso, tipo, righe, colonne, scala, larghezza, profondita, coloreBordo, targa)
	local cf = CFrame.lookAt(centro, centro + verso)
	local base = scatola(genitore, Vector3.new(larghezza, 1.4, profondita), cf * CFrame.new(0, PAVIMENTO + 0.7, 0), PIETRA_SCURA, Enum.Material.Slate)
	local piano = scatola(genitore, Vector3.new(larghezza - 1, 0.4, profondita - 1), cf * CFrame.new(0, PAVIMENTO + 1.6, 0), coloreBordo, Enum.Material.Fabric)
	piano.Name = "Esposizione"
	piano:SetAttribute("Esposizione", tipo)
	piano:SetAttribute("Righe", righe)
	piano:SetAttribute("Colonne", colonne)
	piano:SetAttribute("Scala", scala)
	if targa then
		local cartellino = scatola(genitore, Vector3.new(math.min(larghezza - 2, 9), 1.6, 0.4), cf * CFrame.new(0, PAVIMENTO + 1.2, -profondita / 2 - 0.25) * CFrame.Angles(math.rad(-20), 0, 0), LEGNO_SCURO, Enum.Material.Wood)
		insegna(cartellino, targa, ORO)
	end
	return piano
end

-- Finestre: distanza dal punto "a" del muro, larghezza, altezza da terra, cima.
local function finestre(centri, larghezza, basso, alto)
	local lista = {}
	for _, c in ipairs(centri) do
		table.insert(lista, { centro = c, larghezza = larghezza, basso = PAVIMENTO + basso, alto = PAVIMENTO + alto })
	end
	return lista
end

---------------------------------------------------------------------------------------------------------
-- La montagna e il cielo: la cittadella è in cima a un picco, intorno altre vette innevate e,
-- lontano, i fumi delle battaglie.

local function montagne()
	-- Il picco sotto la cittadella. La cima resta a y = -4, una cella sotto i pavimenti: il terreno
	-- è a celle di 4 e arrotonda, più in alto spunterebbe sopra pavimenti e tappeti.
	terrain:FillCylinder(CFrame.new(0, -64, 0), 120, 260 * SCALA, Enum.Material.Rock)
	terrain:FillCylinder(CFrame.new(0, -150, 0), 80, 360 * SCALA, Enum.Material.Rock)
	terrain:FillCylinder(CFrame.new(0, -6, 0), 4, 280 * SCALA, Enum.Material.Slate)
	local rng = Random.new(7)
	for i = 1, 26 do
		local a = i / 26 * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local distanza = rng:NextNumber(420, 900)
		local raggio = rng:NextNumber(90, 190)
		local centro = Vector3.new(math.cos(a) * distanza, rng:NextNumber(-170, -90), math.sin(a) * distanza)
		terrain:FillBall(centro, raggio, Enum.Material.Rock)
		-- Cima innevata.
		local cima = centro + Vector3.new(0, raggio * 0.72, 0)
		terrain:FillBall(cima, raggio * 0.42, Enum.Material.Snow)
		terrain:FillBall(cima + Vector3.new(rng:NextNumber(-20, 20), raggio * 0.12, rng:NextNumber(-20, 20)), raggio * 0.28, Enum.Material.Snow)
	end
	-- Fondovalle lontano, coperto dalla foschia.
	terrain:FillBlock(CFrame.new(0, -260, 0), Vector3.new(2400, 40, 2400), Enum.Material.Ground)
end

local function fumiDiGuerra(genitore)
	local rng = Random.new(11)
	for i = 1, 7 do
		local a = rng:NextNumber(0, math.pi * 2)
		local distanza = rng:NextNumber(650, 1000)
		local pos = Vector3.new(math.cos(a) * distanza, rng:NextNumber(-120, -60), math.sin(a) * distanza)
		local sorgente = scatola(genitore, Vector3.new(30, 2, 30), pos, Color3.new(0, 0, 0), Enum.Material.SmoothPlastic, {
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
		})
		local fumo = Instance.new("ParticleEmitter")
		fumo.Color = ColorSequence.new(Color3.fromRGB(70, 60, 58), Color3.fromRGB(130, 120, 118))
		fumo.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 30), NumberSequenceKeypoint.new(1, 100) })
		fumo.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.7, 0.75), NumberSequenceKeypoint.new(1, 1) })
		fumo.Lifetime = NumberRange.new(20, 28)
		fumo.Rate = 0.8
		fumo.Speed = NumberRange.new(10, 14)
		fumo.SpreadAngle = Vector2.new(8, 8)
		fumo.Acceleration = Vector3.new(4, 1.5, 2)
		fumo.RotSpeed = NumberRange.new(-8, 8)
		fumo.Rotation = NumberRange.new(0, 360)
		fumo.LightInfluence = 1
		fumo.Parent = sorgente
		local bagliore = Instance.new("ParticleEmitter")
		bagliore.Color = ColorSequence.new(Color3.fromRGB(255, 120, 40))
		bagliore.LightEmission = 1
		bagliore.Size = NumberSequence.new(26, 6)
		bagliore.Transparency = NumberSequence.new(0.4, 1)
		bagliore.Lifetime = NumberRange.new(1.5, 2.5)
		bagliore.Rate = 3
		bagliore.Speed = NumberRange.new(2, 5)
		bagliore.Parent = sorgente
	end
end

-- Fari antiaerei fuori dalle mura: il client fa oscillare i fasci nel cielo.
local function fari(genitore)
	-- Sulle diagonali, lontano dalle ali: i fasci puntano verso l'esterno e non attraversano le sale.
	for i = 1, 4 do
		local a = math.pi / 4 + (i - 1) * math.pi / 2
		local base = Vector3.new(math.cos(a) * 90 * SCALA, PAVIMENTO + 2, math.sin(a) * 90 * SCALA)
		local faro = Instance.new("Model")
		faro.Name = "Faro"
		local fascio = blocco(faro, {
			Name = "Fascio",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(700, 9, 9),
			CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.new(350, 0, 0),
			Color = Color3.fromRGB(255, 244, 214),
			Material = Enum.Material.Neon,
			Transparency = 0.9,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
		})
		fascio:SetAttribute("Base", base)
		faro:SetAttribute("Faro", i)
		faro.Parent = genitore
	end
end

---------------------------------------------------------------------------------------------------------
-- Rotonda del comando

-- Plastico d'Europa sul tavolo: celle accorpate per riga quando hanno la stessa quota.
local function plastico(genitore, centro, larghezza, profondita)
	local PASSO = 5
	local colonne = math.floor(MappaEuropa.COLONNE / PASSO)
	local righe = math.floor(MappaEuropa.RIGHE / PASSO)
	local cx, cz = larghezza / colonne, profondita / righe
	local SCALA = 0.065
	local function quota(c, r)
		local massimo, terra = 0, 0
		for dc = 0, PASSO - 1 do
			for dr = 0, PASSO - 1 do
				local col, riga = c * PASSO + dc, r * PASSO + dr
				if MappaEuropa.terra(col, riga) then
					terra += 1
					massimo = math.max(massimo, MappaEuropa.altezzaStuds(col, riga))
				end
			end
		end
		if terra < PASSO * PASSO * 0.45 then
			return nil
		end
		return math.floor((0.25 + massimo * SCALA) / 0.12 + 0.5) * 0.12
	end
	local function colore(h)
		if h > 1.7 then
			return Color3.fromRGB(236, 234, 228)
		elseif h > 1.3 then
			return Color3.fromRGB(128, 108, 84)
		elseif h > 0.9 then
			return Color3.fromRGB(150, 140, 92)
		end
		-- Più di metà delle celle sta sotto 0.9: le pianure verdi fanno riconoscere l'Europa.
		return Color3.fromRGB(108, 146, 78)
	end
	for r = 0, righe - 1 do
		local c = 0
		while c < colonne do
			local h = quota(c, r)
			if h then
				local fine = c
				while fine + 1 < colonne and quota(fine + 1, r) == h do
					fine += 1
				end
				local x = -larghezza / 2 + (c + fine + 1) / 2 * cx
				local z = -profondita / 2 + (r + 0.5) * cz
				scatola(genitore, Vector3.new((fine - c + 1) * cx, h, cz), centro + Vector3.new(x, h / 2, z), colore(h), Enum.Material.Fabric, { CastShadow = true })
				c = fine + 1
			else
				c += 1
			end
		end
	end
	-- Bandierine sulle battaglie della campagna, del colore dell'epoca (come la GUI: oro, blu, verde).
	local coloriEpoca = { Color3.fromRGB(255, 196, 60), Color3.fromRGB(70, 150, 255), Color3.fromRGB(230, 70, 70), Color3.fromRGB(90, 200, 90), Color3.fromRGB(170, 90, 230) }
	for numero, battaglia in ipairs(Campagna.Battaglie) do
		local indiceEpoca = Campagna.epocaDi(numero)
		if battaglia.lat and battaglia.lon then
			local col, riga = MappaEuropa.cella(battaglia.lat, battaglia.lon)
			local x = -larghezza / 2 + col / PASSO * cx
			local z = -profondita / 2 + riga / PASSO * cz
			local h = quota(math.floor(col / PASSO), math.floor(riga / PASSO)) or 0.2
			local piede = centro + Vector3.new(x, h, z)
			colonna(genitore, 2.2, 0.12, piede + Vector3.new(0, 1.1, 0), Color3.fromRGB(230, 220, 200), Enum.Material.Wood)
			local colore_ = coloriEpoca[indiceEpoca] or ORO
			scatola(genitore, Vector3.new(0.08, 0.6, 0.9), CFrame.new(piede + Vector3.new(0, 1.85, 0.45)), colore_, Enum.Material.Fabric)
		end
	end
end

local function rotonda(lobby)
	local m = Instance.new("Model")
	m.Name = "Rotonda"
	local centro = Vector3.new(0, 0, 0)
	-- Pavimento: tutto moquette scura di un colore solo, senza anelli né linee (scelta di Mattia, 19/10/2026).
	-- Il disco grande sta un filo più basso dei pavimenti delle ali, che gli passano sopra alle porte.
	colonna(m, 1, (R_ROTONDA + 6) * 2, Vector3.new(0, PAVIMENTO - 0.53, 0), MOQUETTE, Enum.Material.Fabric)

	local ALI = {
		{ angolo = -math.pi / 2, colore = BLU, titolo = "CAMPAIGN", sotto = "Gallery of Eras" },
		{ angolo = 0, colore = ROSSO, titolo = "RANKED", sotto = "Arena" },
		{ angolo = math.pi, colore = GIALLO, titolo = "SHOP", sotto = "Armory" },
		{ angolo = math.pi / 2, colore = VERDE, titolo = "ARMY", sotto = "Hall of Heroes" },
	}
	local porte = {}
	for _, ala in ipairs(ALI) do
		table.insert(porte, ala.angolo)
		local dir = Vector3.new(math.cos(ala.angolo), 0, math.sin(ala.angolo))
		-- Tappeto dal tavolo alla porta (veloce).
		tappeto(m, dir * 19, dir * (R_ROTONDA + 2), 7, ala.colore, "b")
		-- Insegna sopra la porta, rivolta al centro (i soffitti delle ali cominciano dietro, a 45).
		cartello(m, dir * (R_ROTONDA - 2.2) + Vector3.new(0, PAVIMENTO + 29.5, 0), -dir, 22, 5.6, ala.titolo, ala.colore, ala.sotto)
		-- Cornice luminosa della porta, del colore dell'ala.
		local destra = Vector3.new(-dir.Z, 0, dir.X)
		for lato = -1, 1, 2 do
			scatola(m, Vector3.new(0.5, 25, 0.5), CFrame.new(dir * (R_ROTONDA - 0.3) + destra * lato * 12.6 + Vector3.new(0, PAVIMENTO + 12.5, 0)), ala.colore, Enum.Material.Neon, { CastShadow = false })
			colonna(m, 26, 3.4, dir * (R_ROTONDA - 0.6) + destra * lato * 14.4 + Vector3.new(0, PAVIMENTO + 13, 0), PIETRA_CHIARA, Enum.Material.Limestone)
		end
		scatola(m, Vector3.new(0.5, 0.5, 25.7), CFrame.lookAt(dir * (R_ROTONDA - 0.3) + Vector3.new(0, PAVIMENTO + 25.2, 0), dir * (R_ROTONDA - 0.3) + destra + Vector3.new(0, PAVIMENTO + 25.2, 0)), ala.colore, Enum.Material.Neon, { CastShadow = false })
	end
	anelloMura(m, centro, R_ROTONDA, 4, ALTEZZA_ROTONDA, 36, porte, PIETRA, Enum.Material.Cobblestone, 25)
	local cima = cupola(m, Vector3.new(0, PAVIMENTO + ALTEZZA_ROTONDA, 0), R_ROTONDA + 2, 32, 6, 10, Color3.fromRGB(60, 66, 88), Color3.fromRGB(150, 112, 60))
	-- Cornicione tra muro e cupola.
	for i = 0, 35 do
		local a = i * math.pi / 18
		local pos = Vector3.new(math.cos(a) * (R_ROTONDA - 0.5), PAVIMENTO + ALTEZZA_ROTONDA - 0.5, math.sin(a) * (R_ROTONDA - 0.5))
		scatola(m, Vector3.new(8.6, 1.6, 3), CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0)), ORO, Enum.Material.Slate)
	end

	-- Colonne e stendardi tra le porte, torce sulle colonne.
	for quadrante = 0, 3 do
		local a0 = quadrante * math.pi / 2
		for k, frazione in ipairs({ 0.3, 0.5, 0.7 }) do
			local a = a0 + frazione * math.pi / 2
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			colonna(m, ALTEZZA_ROTONDA, 3.6, dir * (R_ROTONDA - 2) + Vector3.new(0, PAVIMENTO + ALTEZZA_ROTONDA / 2, 0), PIETRA_CHIARA, Enum.Material.Limestone)
			colonna(m, 1.4, 5, dir * (R_ROTONDA - 2) + Vector3.new(0, PAVIMENTO + 0.7, 0), PIETRA_SCURA, Enum.Material.Slate)
			colonna(m, 1.4, 5, dir * (R_ROTONDA - 2) + Vector3.new(0, PAVIMENTO + ALTEZZA_ROTONDA - 1.6, 0), ORO, Enum.Material.Slate)
			if k == 2 then
				torcia(m, dir * (R_ROTONDA - 4) + Vector3.new(0, PAVIMENTO + 11, 0), -dir)
			end
		end
		for _, frazione in ipairs({ 0.4, 0.6 }) do
			local a = a0 + frazione * math.pi / 2
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			-- Colore dello stendardo: quello dell'ala più vicina.
			local vicino = (a0 + (frazione < 0.5 and 0 or math.pi / 2)) % (math.pi * 2)
			local colori = { [0] = Color3.fromRGB(150, 36, 34), [1] = Color3.fromRGB(40, 110, 50), [2] = Color3.fromRGB(170, 120, 30), [3] = Color3.fromRGB(34, 70, 150) }
			local indice = math.floor(vicino / (math.pi / 2) + 0.5) % 4
			stendardo(m, dir * (R_ROTONDA - 0.3) + Vector3.new(0, PAVIMENTO + 18, 0), -dir, colori[indice], 6.5, 16)
		end
	end

	-- Tavolo di guerra con il plastico.
	colonna(m, 1.2, 40, Vector3.new(0, PAVIMENTO + 0.6, 0), PIETRA_SCURA, Enum.Material.Slate)
	colonna(m, 1.2, 36, Vector3.new(0, PAVIMENTO + 1.8, 0), PIETRA, Enum.Material.Slate)
	scatola(m, Vector3.new(30, 2.6, 24), Vector3.new(0, PAVIMENTO + 3.7, 0), LEGNO_SCURO, Enum.Material.Wood)
	scatola(m, Vector3.new(31.6, 0.8, 25.6), Vector3.new(0, PAVIMENTO + 5.2, 0), LEGNO, Enum.Material.WoodPlanks)
	for lato = -1, 1, 2 do
		scatola(m, Vector3.new(31.6, 0.6, 0.8), Vector3.new(0, PAVIMENTO + 5.8, lato * 12.4), ORO, Enum.Material.Slate)
		scatola(m, Vector3.new(0.8, 0.6, 25.6), Vector3.new(lato * 15.4, PAVIMENTO + 5.8, 0), ORO, Enum.Material.Slate)
	end
	local mare = scatola(m, Vector3.new(30, 0.2, 24), Vector3.new(0, PAVIMENTO + 5.7, 0), Color3.fromRGB(46, 78, 104), Enum.Material.Fabric)
	plastico(m, mare.Position + Vector3.new(0, 0.1, 0), 29.6, 23.6)

	-- Lampadario ad anello sopra il tavolo.
	local yLampadario = PAVIMENTO + 24
	for i = 0, 15 do
		local a = i * math.pi / 8
		local pos = Vector3.new(math.cos(a) * 13, yLampadario, math.sin(a) * 13)
		scatola(m, Vector3.new(5.4, 0.7, 0.9), CFrame.lookAt(pos, Vector3.new(0, yLampadario, 0)) * CFrame.Angles(0, math.rad(90), 0), FERRO, Enum.Material.Metal)
		if i % 2 == 0 then
			colonna(m, 1.2, 0.8, pos + Vector3.new(0, 0.9, 0), Color3.fromRGB(236, 226, 200), Enum.Material.SmoothPlastic)
			local f = fuoco(m, pos + Vector3.new(0, 1.8, 0), 1.2, Color3.fromRGB(255, 180, 110), 0, false)
			f:FindFirstChildOfClass("PointLight"):Destroy()
		end
	end
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		local da = Vector3.new(math.cos(a) * 13, yLampadario, math.sin(a) * 13)
		local a2 = Vector3.new(0, cima, 0)
		scatola(m, Vector3.new(0.3, 0.3, (a2 - da).Magnitude), CFrame.lookAt((da + a2) / 2, a2), FERRO, Enum.Material.Metal)
	end
	local centroLuce = scatola(m, Vector3.new(1, 1, 1), Vector3.new(0, yLampadario - 1, 0), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, { Transparency = 1, CanCollide = false })
	luce(centroLuce, Color3.fromRGB(255, 226, 196), 34, 1, true)

	-- Lama di luce dall'oculo sul tavolo, con il pulviscolo.
	local lama = colonna(m, cima - PAVIMENTO - 6, 17, Vector3.new(0, (cima + PAVIMENTO + 6) / 2, 0), Color3.fromRGB(255, 222, 170), Enum.Material.Neon)
	lama.Transparency = 0.97
	lama.CanCollide = false
	lama.CanQuery = false
	lama.CastShadow = false
	local polvere = Instance.new("ParticleEmitter")
	polvere.Color = ColorSequence.new(Color3.fromRGB(255, 230, 190))
	polvere.LightEmission = 0.8
	polvere.Size = NumberSequence.new(0.18)
	polvere.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.3), NumberSequenceKeypoint.new(1, 1) })
	polvere.Lifetime = NumberRange.new(8, 12)
	polvere.Rate = 14
	polvere.Speed = NumberRange.new(0.3, 0.8)
	polvere.SpreadAngle = Vector2.new(180, 180)
	polvere.Parent = lama
	local sole = scatola(m, Vector3.new(1, 1, 1), Vector3.new(0, cima - 2, 0), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, { Transparency = 1, CanCollide = false })
	-- Luce quasi bianca e non troppo forte: sul plastico devono leggersi i colori, non l'arancio.
	faretto(sole, Color3.fromRGB(255, 244, 228), 60, 1.4, 36)

	-- Quattro bracieri attorno al tavolo.
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		braciere(m, Vector3.new(math.cos(a) * 25, PAVIMENTO, math.sin(a) * 25), 1.1)
	end
	m.Parent = lobby
end

---------------------------------------------------------------------------------------------------------
-- Galleria delle Epoche (nord) e portale della campagna

-- Stile delle sale della Galleria, una per epoca nell'ordine di Epoche.Lista.
local SALE_EPOCHE = {
	Antica = {
		nome = "ANTIQUITY", pavimento = MARMO, materiale = Enum.Material.Marble,
		muri = Color3.fromRGB(214, 196, 162), materialeMuri = Enum.Material.Limestone, drappo = ROSSO_ROMANO, decoro = "colonne",
	},
	Medievale = {
		nome = "MIDDLE AGES", pavimento = Color3.fromRGB(120, 112, 104), materiale = Enum.Material.Cobblestone,
		muri = Color3.fromRGB(128, 120, 110), materialeMuri = Enum.Material.Cobblestone, drappo = BLU_REALE, decoro = "vetrate",
	},
	Polvere = {
		nome = "AGE OF GUNPOWDER", pavimento = Color3.fromRGB(128, 92, 60), materiale = Enum.Material.WoodPlanks,
		muri = Color3.fromRGB(190, 160, 128), materialeMuri = Enum.Material.Brick, drappo = Color3.fromRGB(150, 60, 50), decoro = "lampadari",
	},
	Novecento = {
		nome = "20TH CENTURY", pavimento = CEMENTO, materiale = Enum.Material.Concrete,
		muri = Color3.fromRGB(116, 114, 108), materialeMuri = Enum.Material.Concrete, drappo = OLIVA, decoro = "travi",
	},
	Moderna = {
		nome = "MODERN ERA", pavimento = Color3.fromRGB(150, 138, 110), materiale = Enum.Material.Concrete,
		muri = Color3.fromRGB(176, 160, 124), materialeMuri = Enum.Material.Concrete, drappo = Color3.fromRGB(150, 122, 76), decoro = "travi",
	},
}
local PASSO_FILA = 10 -- profondità di una fila di piedistalli
local POSTI_X = { -16, -7, 7, 16 } -- quattro piedistalli per fila, due per lato del tappeto
local SPAZIO_SALA = 12 -- spazio libero all'inizio e alla fine di ogni sala

-- Quanti soldati e quanto grandi su un piedistallo: fanti e tiratori a gruppi di quattro, cavalieri e
-- mitraglieri da soli, veicoli ed elefanti rimpiccioliti, la fortezza in piccolo.
local function comeEsporre(tipo)
	local def = Epoche.Truppe[tipo]
	if def.fortezza then
		return 1, 1, 0.42
	elseif def.veicolo then
		return 1, 1, def.classe == "Cavalleria" and def.soldati == 1 and 0.55 or 0.75
	elseif def.classe == "Cavalleria" or def.soldati < 8 then
		return 1, 1, 1
	end
	return 2, 2, 1
end

-- Galleria delle Epoche (nord, -Z): una sala per epoca con un piedistallo per ogni reggimento che si può avere
-- (anche quelli delle armate nemiche) e la fortezza dell'epoca, poi il portale della campagna.
local function galleria(lobby, callback)
	local m = Instance.new("Model")
	m.Name = "Galleria"
	local X = 22 -- mezza larghezza interna
	local ALTO = 30
	local Z0 = -40 -- inizio (dentro il muro della Rotonda)
	local sale = {}
	local z = -48
	for _, epoca in ipairs(Epoche.Lista) do
		local pezzi = table.clone(epoca.truppe)
		table.insert(pezzi, epoca.fortezza)
		local file = math.ceil(#pezzi / #POSTI_X)
		local lunghezza = file * PASSO_FILA + SPAZIO_SALA * 2
		table.insert(sale, { epoca = epoca, stile = SALE_EPOCHE[epoca.id] or SALE_EPOCHE.Antica, z0 = z, z1 = z - lunghezza, pezzi = pezzi })
		z -= lunghezza
	end
	local Z1 = z
	for i, sala in ipairs(sale) do
		local st = sala.stile
		local z0 = i == 1 and Z0 or sala.z0
		local lunghezza = z0 - sala.z1
		scatola(m, Vector3.new(X * 2 + 8, 1, lunghezza), Vector3.new(0, PAVIMENTO - 0.5, (z0 + sala.z1) / 2), st.pavimento, st.materiale)
		-- Muri laterali con un finestrone ogni due file: da lì si vedono le montagne e il tramonto.
		local centri = {}
		for c = 18, lunghezza - 10, 20 do
			table.insert(centri, c)
		end
		for lato = -1, 1, 2 do
			muro(m, Vector3.new(lato * (X + 2), 0, z0), Vector3.new(lato * (X + 2), 0, sala.z1), PAVIMENTO, PAVIMENTO + ALTO, 4, st.muri, st.materialeMuri,
				finestre(centri, st.decoro == "travi" and 4 or 6, 9, st.decoro == "travi" and 20 or 24))
		end
		-- Soffitto (la prima sala comincia dietro il muro della Rotonda) e travi.
		local zTetto = i == 1 and -45 or z0
		scatola(m, Vector3.new(X * 2 + 8, 2, zTetto - sala.z1), Vector3.new(0, PAVIMENTO + ALTO + 1, (zTetto + sala.z1) / 2), st.muri:Lerp(Color3.new(0, 0, 0), 0.35), st.materialeMuri)
		for k = 0, math.floor((z0 - sala.z1) / 8) do
			scatola(m, Vector3.new(X * 2, 1.6, 1.4), Vector3.new(0, PAVIMENTO + ALTO - 0.6, z0 - 2 - k * 8), st.decoro == "travi" and FERRO or LEGNO_SCURO,
				st.decoro == "travi" and Enum.Material.Metal or Enum.Material.Wood)
		end
		-- Arco d'ingresso con il nome dell'epoca.
		local za = sala.z0 - 0.5
		for lato = -1, 1, 2 do
			scatola(m, Vector3.new(4, ALTO, 3), Vector3.new(lato * (X - 2), PAVIMENTO + ALTO / 2, za), st.muri:Lerp(Color3.new(0, 0, 0), 0.15), st.materialeMuri)
		end
		scatola(m, Vector3.new(X * 2, 5, 3), Vector3.new(0, PAVIMENTO + ALTO - 2.5, za), st.muri:Lerp(Color3.new(0, 0, 0), 0.15), st.materialeMuri)
		cartello(m, Vector3.new(0, PAVIMENTO + ALTO - 7.6, za + 1.8), Vector3.new(0, 0, 1), 26, 3.4, st.nome, ORO)
		braciere(m, Vector3.new(-6, PAVIMENTO, sala.z0 - 4), 0.85)
		braciere(m, Vector3.new(6, PAVIMENTO, sala.z0 - 4), 0.85)
		-- Decori della sala.
		for k = 0, math.floor((lunghezza - SPAZIO_SALA) / PASSO_FILA) do
			local zk = sala.z0 - SPAZIO_SALA + 2 - k * PASSO_FILA
			if zk > sala.z1 + 4 then
				for lato = -1, 1, 2 do
					if st.decoro == "colonne" then
						colonna(m, ALTO - 2, 2.6, Vector3.new(lato * (X - 1.6), PAVIMENTO + (ALTO - 2) / 2, zk), MARMO, Enum.Material.Marble)
					elseif st.decoro == "travi" then
						scatola(m, Vector3.new(1.6, ALTO, 1.6), Vector3.new(lato * (X - 1), PAVIMENTO + ALTO / 2, zk), FERRO, Enum.Material.Metal)
					elseif k % 2 == 0 then
						torcia(m, Vector3.new(lato * X, PAVIMENTO + 13, zk), Vector3.new(-lato, 0, 0))
					end
				end
				if st.decoro == "lampadari" or st.decoro == "travi" then
					local lampada = scatola(m, Vector3.new(st.decoro == "travi" and 1.4 or 3, 0.5, st.decoro == "travi" and 1.4 or 3),
						Vector3.new(0, PAVIMENTO + ALTO - 4, zk), st.decoro == "travi" and Color3.fromRGB(255, 236, 190) or ORO, Enum.Material.Neon, { CastShadow = false })
					faretto(lampada, Color3.fromRGB(255, 226, 180), 40, 2.2, 70)
				end
			end
		end
		for lato = -1, 1, 2 do
			stendardo(m, Vector3.new(lato * (X - 0.4), PAVIMENTO + 20, sala.z0 - 6), Vector3.new(-lato, 0, 0), st.drappo, 3, 10)
		end
		-- I piedistalli: quattro per fila, rivolti al tappeto e un po' verso chi arriva.
		for j, tipo in ipairs(sala.pezzi) do
			local fila = math.floor((j - 1) / #POSTI_X)
			local x = POSTI_X[(j - 1) % #POSTI_X + 1]
			local zp = sala.z0 - SPAZIO_SALA - fila * PASSO_FILA - PASSO_FILA / 2
			local verso = Vector3.new(x < 0 and 1 or -1, 0, 0.45).Unit
			local righe, colonne, scala = comeEsporre(tipo)
			local def = Epoche.Truppe[tipo]
			esposizione(m, Vector3.new(x, 0, zp), verso, tipo, righe, colonne, scala, 7.5, 8, st.drappo, string.upper(def.nome))
		end
	end
	-- Muro di fondo, tappeto veloce al centro fino al portale e il portale della campagna.
	scatola(m, Vector3.new(X * 2 + 8, ALTO + 2, 4), Vector3.new(0, PAVIMENTO + ALTO / 2, Z1 - 2), sale[#sale].stile.muri, Enum.Material.Concrete)
	tappeto(m, Vector3.new(0, 0, -48), Vector3.new(0, 0, Z1 + 12), 7, BLU, "a")
	portale(m, "PortaleCampagna", CFrame.lookAt(Vector3.new(0, 0, Z1 + 6), Vector3.new(0, 0, 0)), BLU, "CAMPAIGN", "Conquer history", callback)
	m.Parent = lobby
end

---------------------------------------------------------------------------------------------------------
-- Arena Ranked (est)

-- Gradinata ad anello attorno a "centro" da raggio r0 a r1, alta y1, con i varchi { angolo, mezza ampiezza }
-- (radianti).
local function gradinata(genitore, centro, r0, r1, y1, n, varchi, colore, materiale)
	local passo = math.pi * 2 / n
	local larghezza = 2 * r1 * math.tan(passo / 2) + 0.3
	for i = 0, n - 1 do
		local a = (i + 0.5) * passo
		local libero = true
		for _, v in ipairs(varchi) do
			local d = math.abs(((a - v[1] + math.pi) % (math.pi * 2)) - math.pi)
			if d < v[2] then
				libero = false
			end
		end
		if libero then
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local r = (r0 + r1) / 2
			scatola(genitore, Vector3.new(larghezza, y1, r1 - r0), CFrame.lookAt(centro + dir * r + Vector3.new(0, PAVIMENTO + y1 / 2, 0), centro + Vector3.new(0, PAVIMENTO + y1 / 2, 0)), colore, materiale)
		end
	end
end

local function arena(lobby, callback)
	local m = Instance.new("Model")
	m.Name = "ArenaRanked"
	local centro = Vector3.new(112, 0, 0)
	local R = 40
	local ALTO = 30
	-- Corridoio dalla Rotonda.
	scatola(m, Vector3.new(30, 1, 28), Vector3.new(58, PAVIMENTO - 0.5, 0), Color3.fromRGB(90, 80, 76), Enum.Material.Slate)
	for lato = -1, 1, 2 do
		muro(m, Vector3.new(44, 0, lato * 15), Vector3.new(74, 0, lato * 15), PAVIMENTO, PAVIMENTO + 26, 4, PIETRA, Enum.Material.Cobblestone)
		torcia(m, Vector3.new(60, PAVIMENTO + 10, lato * 12.8), Vector3.new(0, 0, -lato))
	end
	-- Il tetto comincia dietro il muro della Rotonda (a 45), per non coprire l'insegna della porta.
	scatola(m, Vector3.new(28, 2, 34), Vector3.new(59, PAVIMENTO + 27, 0), PIETRA_SCURA, Enum.Material.Slate)
	tappeto(m, Vector3.new(48, 0, 0), Vector3.new(84, 0, 0), 7, ROSSO, "a")

	-- Pavimento, sabbia al centro, gradinate.
	colonna(m, 1, (R + 4) * 2, centro + Vector3.new(0, PAVIMENTO - 0.53, 0), Color3.fromRGB(88, 78, 72), Enum.Material.Slate)
	colonna(m, 1, 46, centro + Vector3.new(0, PAVIMENTO - 0.44, 0), Color3.fromRGB(196, 164, 116), Enum.Material.Sand)
	colonna(m, 1, 48, centro + Vector3.new(0, PAVIMENTO - 0.46, 0), ROSSO:Lerp(Color3.new(0, 0, 0), 0.4), Enum.Material.Slate)
	-- A ovest il passaggio dal corridoio, a est lo spazio per il portale.
	local varchi = { { math.pi, 0.25 }, { 0, 0.62 } }
	gradinata(m, centro, 26, R, 2, 28, varchi, Color3.fromRGB(150, 140, 128), Enum.Material.Cobblestone)
	gradinata(m, centro, 30, R, 4, 28, varchi, Color3.fromRGB(140, 130, 118), Enum.Material.Cobblestone)
	gradinata(m, centro, 34, R, 6, 28, varchi, Color3.fromRGB(130, 120, 110), Enum.Material.Cobblestone)
	anelloMura(m, centro, R, 4, ALTO, 28, { math.pi }, PIETRA, Enum.Material.Cobblestone, 25)

	-- Tetto ad anello aperto al centro, con le travi incrociate contro il cielo.
	for i = 0, 27 do
		local a = i * math.pi * 2 / 28
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local r = (R + 4 + 22) / 2
		scatola(m, Vector3.new(2 * (R + 4) * math.tan(math.pi / 28) + 0.4, 2, R + 4 - 22), CFrame.lookAt(centro + dir * r + Vector3.new(0, PAVIMENTO + ALTO + 1, 0), centro + Vector3.new(0, PAVIMENTO + ALTO + 1, 0)), PIETRA_SCURA, Enum.Material.Slate)
	end
	for k = 0, 2 do
		local a = k * math.pi / 3
		scatola(m, Vector3.new(46, 1.6, 1.6), CFrame.new(centro + Vector3.new(0, PAVIMENTO + ALTO + 0.5, 0)) * CFrame.Angles(0, a, 0), FERRO, Enum.Material.Metal)
	end

	-- Podio dei migliori al centro.
	local gradini = {
		{ x = 0, h = 4.5, colore = Color3.fromRGB(230, 184, 60), testo = "1" },
		{ x = -6.4, h = 3, colore = Color3.fromRGB(190, 196, 206), testo = "2" },
		{ x = 6.4, h = 2, colore = Color3.fromRGB(196, 124, 70), testo = "3" },
	}
	for _, g in ipairs(gradini) do
		local blocco_ = scatola(m, Vector3.new(6, g.h, 6), CFrame.lookAt(centro + Vector3.new(0, PAVIMENTO + g.h / 2, g.x), centro + Vector3.new(-10, PAVIMENTO + g.h / 2, g.x)), g.colore, Enum.Material.Slate)
		insegna(blocco_, g.testo, Color3.fromRGB(255, 255, 255))
	end
	local alto_ = scatola(m, Vector3.new(1, 1, 1), centro + Vector3.new(0, PAVIMENTO + ALTO - 2, 0), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, { Transparency = 1, CanCollide = false })
	faretto(alto_, Color3.fromRGB(255, 200, 150), 50, 3, 30)

	-- Gli stemmi dei gradi sul muro, rivolti al centro.
	local gradi = {
		{ "BRONZE", Color3.fromRGB(196, 124, 70) },
		{ "SILVER", Color3.fromRGB(190, 196, 206) },
		{ "GOLD", Color3.fromRGB(240, 190, 60) },
		{ "DIAMOND", Color3.fromRGB(90, 210, 240) },
		{ "LEGEND", Color3.fromRGB(200, 90, 240) },
	}
	for i, grado in ipairs(gradi) do
		local a = math.pi / 2 + (i - 3) * 0.32 -- lato sud dell'arena, di fronte al podio
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		for _, segno in ipairs({ 1, -1 }) do
			local d = Vector3.new(dir.X, 0, dir.Z * segno)
			local pos = centro + d * (R - 0.4) + Vector3.new(0, PAVIMENTO + 18, 0)
			disco(m, 0.8, 7, CFrame.lookAt(pos, centro + Vector3.new(0, pos.Y, 0)), grado[2], Enum.Material.Slate)
			-- La cornice di ferro sta dietro lo stemma colorato (davanti lo copriva tutto).
			disco(m, 0.9, 7.8, CFrame.lookAt(pos + d * 0.15, centro + Vector3.new(0, pos.Y, 0)), FERRO, Enum.Material.Metal)
			local tavola = scatola(m, Vector3.new(8, 1.8, 0.4), CFrame.lookAt(pos + Vector3.new(0, -5.2, 0) - d * 0.3, centro + Vector3.new(0, pos.Y - 5.2, 0)), LEGNO_SCURO, Enum.Material.Wood)
			insegna(tavola, grado[1], grado[2])
		end
	end
	-- Stendardi rossi e bracieri.
	for _, a in ipairs({ math.pi * 0.72, math.pi * 1.28, math.pi * 0.25, math.pi * 1.75 }) do
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		stendardo(m, centro + dir * (R - 0.3) + Vector3.new(0, PAVIMENTO + 18, 0), -dir, Color3.fromRGB(150, 28, 28), 6, 16)
	end
	for _, a in ipairs({ math.pi * 0.85, math.pi * 1.15, math.pi * 0.15, math.pi * 1.85 }) do
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		braciere(m, centro + dir * 23.5, 1)
	end
	-- Il portale ranked (chiuso finché le ranked non ci sono).
	portale(m, "PortaleRanked", CFrame.lookAt(centro + Vector3.new(R - 8, 0, 0), centro), ROSSO, "RANKED", "Coming soon", callback, true)
	m.Parent = lobby
end

---------------------------------------------------------------------------------------------------------
-- Armeria (ovest): lo shop

local function rastrelliera(genitore, centro, verso, epoca)
	local cf = CFrame.lookAt(centro, centro + verso)
	for lato = -1, 1, 2 do
		scatola(genitore, Vector3.new(0.6, 8, 0.6), cf * CFrame.new(lato * 4, PAVIMENTO + 4, 0), LEGNO, Enum.Material.Wood)
	end
	scatola(genitore, Vector3.new(9, 0.5, 1.2), cf * CFrame.new(0, PAVIMENTO + 1.2, -0.4), LEGNO, Enum.Material.Wood)
	scatola(genitore, Vector3.new(9, 0.5, 0.6), cf * CFrame.new(0, PAVIMENTO + 6.6, 0), LEGNO, Enum.Material.Wood)
	for i = -3, 3 do
		local x = i * 1.15
		if epoca == 1 then
			-- Lance con la punta.
			scatola(genitore, Vector3.new(0.22, 8.4, 0.22), cf * CFrame.new(x, PAVIMENTO + 5.4, -0.3), LEGNO, Enum.Material.Wood)
			scatola(genitore, Vector3.new(0.5, 1.1, 0.12), cf * CFrame.new(x, PAVIMENTO + 10, -0.3), Color3.fromRGB(170, 170, 176), Enum.Material.Metal)
		elseif epoca == 2 then
			-- Spade con l'elsa.
			scatola(genitore, Vector3.new(0.35, 4.6, 0.1), cf * CFrame.new(x, PAVIMENTO + 4, -0.3), Color3.fromRGB(176, 178, 186), Enum.Material.Metal)
			scatola(genitore, Vector3.new(1.3, 0.25, 0.25), cf * CFrame.new(x, PAVIMENTO + 6.4, -0.3), ORO, Enum.Material.Slate)
			scatola(genitore, Vector3.new(0.25, 1.2, 0.25), cf * CFrame.new(x, PAVIMENTO + 7.1, -0.3), LEGNO_SCURO, Enum.Material.Wood)
		else
			-- Fucili.
			scatola(genitore, Vector3.new(0.3, 3, 0.45), cf * CFrame.new(x, PAVIMENTO + 2.9, -0.3), LEGNO, Enum.Material.Wood)
			scatola(genitore, Vector3.new(0.16, 3.6, 0.16), cf * CFrame.new(x, PAVIMENTO + 6, -0.3), FERRO, Enum.Material.Metal)
		end
	end
end

local function botte(genitore, posizione)
	colonna(genitore, 3, 2.4, posizione + Vector3.new(0, 1.5, 0), LEGNO, Enum.Material.WoodPlanks)
	for _, y in ipairs({ 0.4, 2.6 }) do
		colonna(genitore, 0.3, 2.5, posizione + Vector3.new(0, y, 0), FERRO, Enum.Material.Metal)
	end
end

local function cassa(genitore, posizione, lato, colore)
	scatola(genitore, Vector3.one * lato, posizione + Vector3.new(0, lato / 2, 0), colore or LEGNO, Enum.Material.WoodPlanks)
	for _, y in ipairs({ 0.15, lato - 0.15 }) do
		scatola(genitore, Vector3.new(lato + 0.1, 0.3, lato + 0.1), CFrame.new(posizione + Vector3.new(0, y, 0)), LEGNO_SCURO, Enum.Material.Wood)
	end
end

local function armeria(lobby, callback)
	local m = Instance.new("Model")
	m.Name = "Armeria"
	local X0, X1 = -44, -124
	local Z = 26
	local ALTO = 28
	scatola(m, Vector3.new(X0 - X1, 1, Z * 2 + 8), Vector3.new((X0 + X1) / 2, PAVIMENTO - 0.5, 0), Color3.fromRGB(120, 86, 56), Enum.Material.WoodPlanks)
	for lato = -1, 1, 2 do
		muro(m, Vector3.new(X0, 0, lato * (Z + 2)), Vector3.new(X1, 0, lato * (Z + 2)), PAVIMENTO, PAVIMENTO + ALTO, 4, Color3.fromRGB(140, 92, 70), Enum.Material.Brick, finestre({ 22, 50 }, 6, 12, 22))
	end
	scatola(m, Vector3.new(4, ALTO + 2, Z * 2 + 8), Vector3.new(X1 - 2, PAVIMENTO + ALTO / 2, 0), Color3.fromRGB(140, 92, 70), Enum.Material.Brick)
	-- Il tetto comincia dietro il muro della Rotonda (a 45), per non coprire l'insegna della porta.
	scatola(m, Vector3.new(-45 - (X1 - 2), 2, Z * 2 + 8), Vector3.new((-45 + X1 - 2) / 2, PAVIMENTO + ALTO + 1, 0), LEGNO_SCURO, Enum.Material.WoodPlanks)
	-- Capriate del tetto.
	for x = X0 - 6, X1 + 4, -10 do
		scatola(m, Vector3.new(1.6, 1.6, Z * 2), Vector3.new(x, PAVIMENTO + ALTO - 4, 0), LEGNO_SCURO, Enum.Material.Wood)
		for lato = -1, 1, 2 do
			scatola(m, Vector3.new(1.2, 1.2, Z * 1.08), CFrame.new(x, PAVIMENTO + ALTO - 1.8, lato * Z / 2) * CFrame.Angles(lato * math.rad(8), 0, 0), LEGNO_SCURO, Enum.Material.Wood)
		end
		scatola(m, Vector3.new(1, 4, 1), Vector3.new(x, PAVIMENTO + ALTO - 2, 0), LEGNO_SCURO, Enum.Material.Wood)
	end
	tappeto(m, Vector3.new(-48, 0, 0), Vector3.new(-104, 0, 0), 7, GIALLO, "a")

	-- Le tre casse delle truppe su piedistalli illuminati (il client le fa girare).
	for i, info in ipairs(Casse.Truppe) do
		local z = (i - 2) * 14
		local x = -80
		local pos = Vector3.new(x, 0, z + (i == 2 and 0 or 0))
		colonna(m, 1.6, 9, pos + Vector3.new(0, PAVIMENTO + 0.8, 0), PIETRA_SCURA, Enum.Material.Slate)
		colonna(m, 0.5, 7.6, pos + Vector3.new(0, PAVIMENTO + 1.85, 0), info.colore, Enum.Material.Neon).Transparency = 0.2
		local scatolone = Instance.new("Model")
		scatolone.Name = "Cassa"
		local corpo = scatola(scatolone, Vector3.new(4.4, 3.6, 3.4), pos + Vector3.new(0, PAVIMENTO + 5.4, 0), info.colore, Enum.Material.WoodPlanks)
		scatola(scatolone, Vector3.new(4.6, 1.2, 3.6), pos + Vector3.new(0, PAVIMENTO + 7.6, 0), info.colore:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.WoodPlanks)
		for _, dx in ipairs({ -1.6, 1.6 }) do
			scatola(scatolone, Vector3.new(0.4, 4.9, 3.7), pos + Vector3.new(dx, PAVIMENTO + 5.9, 0), FERRO, Enum.Material.Metal)
		end
		scatola(scatolone, Vector3.new(0.9, 1, 0.3), pos + Vector3.new(0, PAVIMENTO + 6.9, -1.85), ORO, Enum.Material.Slate)
		scatolone.PrimaryPart = corpo
		scatolone:SetAttribute("Gira", 30 + i * 6)
		scatolone.Parent = m
		local raggi = scatola(m, Vector3.new(1, 1, 1), pos + Vector3.new(0, PAVIMENTO + ALTO - 3, 0), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, { Transparency = 1, CanCollide = false })
		faretto(raggi, info.colore:Lerp(Color3.new(1, 1, 1), 0.5), 40, 3, 24)
		local cartellino = scatola(m, Vector3.new(7, 1.4, 0.4), CFrame.lookAt(pos + Vector3.new(4.6, PAVIMENTO + 1.6, 0), pos + Vector3.new(12, PAVIMENTO + 0.6, 0)), LEGNO_SCURO, Enum.Material.Wood)
		insegna(cartellino, info.nome:upper(), ORO)
	end

	-- Bancone in fondo con l'insegna e le monete.
	local banco = scatola(m, Vector3.new(4, 4.4, 22), Vector3.new(-110, PAVIMENTO + 2.2, 0), LEGNO, Enum.Material.WoodPlanks)
	scatola(m, Vector3.new(5, 0.6, 23), Vector3.new(-110, PAVIMENTO + 4.7, 0), LEGNO_SCURO, Enum.Material.Wood)
	for i = 0, 6 do
		colonna(m, 0.25, 1.4, Vector3.new(-110 + (i % 2) * 0.6, PAVIMENTO + 5.1 + i * 0.25, 6 + (i % 3) * 0.3), ORO, Enum.Material.Slate)
	end
	cartello(m, Vector3.new(-121, PAVIMENTO + 17, 0), Vector3.new(1, 0, 0), 28, 7, "SHOP", GIALLO, "Crates & gear")
	for _, z in ipairs({ -9, 9 }) do
		local lanterna = scatola(m, Vector3.new(1.2, 1.6, 1.2), Vector3.new(-110, PAVIMENTO + 5.8, z), Color3.fromRGB(255, 210, 140), Enum.Material.Neon)
		luce(lanterna, Color3.fromRGB(255, 190, 120), 22, 1.6, true)
	end
	prompt(banco, "Open shop", "SHOP", callback, 16)
	soglia(m, Vector3.new(6, 8, 22), CFrame.new(-104, PAVIMENTO + 4, 0), callback)

	-- Rastrelliere, casse e botti lungo i muri.
	for i, x in ipairs({ -58, -72, -94 }) do
		for lato = -1, 1, 2 do
			rastrelliera(m, Vector3.new(x, 0, lato * (Z - 0.8)), Vector3.new(0, 0, -lato), i)
		end
	end
	for _, pos in ipairs({ Vector3.new(-118, 0, 20), Vector3.new(-118, 0, -20), Vector3.new(-50, 0, 21), Vector3.new(-50, 0, -21) }) do
		cassa(m, pos, 3.6)
		cassa(m, pos + Vector3.new(pos.X < -100 and 3.8 or -3.8, 0, 0), 3.2, Color3.fromRGB(96, 80, 54))
		cassa(m, pos + Vector3.new(0, 3.6, 0), 2.8, Color3.fromRGB(120, 92, 60))
		botte(m, pos + Vector3.new(0, 0, pos.Z > 0 and -4 or 4))
	end
	for _, pos in ipairs({ Vector3.new(-64, PAVIMENTO, 0), Vector3.new(-96, PAVIMENTO, 0) }) do
		braciere(m, pos + Vector3.new(0, 0, 18), 0.9)
		braciere(m, pos + Vector3.new(0, 0, -18), 0.9)
	end
	m.Parent = lobby
end

---------------------------------------------------------------------------------------------------------
-- Sala degli Eroi (sud): le statue dei comandanti e il tavolo dell'esercito

local function eroi(lobby, callback)
	local m = Instance.new("Model")
	m.Name = "SalaEroi"
	local Z0, Z1 = 44, 164
	local X = 26
	local ALTO = 32
	scatola(m, Vector3.new(X * 2 + 8, 1, Z1 - Z0), Vector3.new(0, PAVIMENTO - 0.5, (Z0 + Z1) / 2), MARMO, Enum.Material.Marble)
	for lato = -1, 1, 2 do
		muro(m, Vector3.new(lato * (X + 2), 0, Z0), Vector3.new(lato * (X + 2), 0, Z1), PAVIMENTO, PAVIMENTO + ALTO, 4, PIETRA_CHIARA, Enum.Material.Limestone, finestre({ 18, 38, 58, 78, 98 }, 6, 10, 27))
	end
	scatola(m, Vector3.new(X * 2 + 8, ALTO + 2, 4), Vector3.new(0, PAVIMENTO + ALTO / 2, Z1 + 2), PIETRA_CHIARA, Enum.Material.Limestone)
	-- Il soffitto comincia dietro il muro della Rotonda (a 45), per non coprire l'insegna della porta.
	scatola(m, Vector3.new(X * 2 + 8, 2, Z1 + 2 - 45), Vector3.new(0, PAVIMENTO + ALTO + 1, (45 + Z1 + 2) / 2), Color3.fromRGB(70, 60, 54), Enum.Material.Slate)
	for z = Z0 + 6, Z1 - 2, 10 do
		scatola(m, Vector3.new(X * 2, 2, 1.6), Vector3.new(0, PAVIMENTO + ALTO - 1, z), ORO, Enum.Material.Slate)
	end
	tappeto(m, Vector3.new(0, 0, 48), Vector3.new(0, 0, 148), 7, VERDE, "a")

	-- Le statue: tutti i comandanti, nell'ordine delle epoche, alternati a destra e a sinistra del tappeto.
	local comandanti = {}
	for _, epoca in ipairs(Epoche.Lista) do
		for _, id in ipairs(epoca.comandanti) do
			table.insert(comandanti, id)
		end
	end
	for i, id in ipairs(comandanti) do
		local lato = i % 2 == 1 and -1 or 1
		local z = 58 + math.floor((i - 1) / 2) * 16 -- 12 statue: le ultime restano davanti al tavolo ARMY
		local pos = Vector3.new(lato * 15, 0, z)
		local verso = Vector3.new(-lato, 0, -0.25).Unit
		colonna(m, 1.2, 10, pos + Vector3.new(0, PAVIMENTO + 0.6, 0), PIETRA_SCURA, Enum.Material.Slate)
		colonna(m, 3, 8, pos + Vector3.new(0, PAVIMENTO + 2.7, 0), MARMO, Enum.Material.Marble)
		colonna(m, 0.5, 8.6, pos + Vector3.new(0, PAVIMENTO + 4.3, 0), ORO, Enum.Material.Slate)
		local piano = scatola(m, Vector3.new(5, 0.2, 5), CFrame.lookAt(pos + Vector3.new(0, PAVIMENTO + 4.6, 0), pos + Vector3.new(0, PAVIMENTO + 4.6, 0) + verso), MARMO, Enum.Material.Marble, { Transparency = 1 })
		piano.Name = "Esposizione"
		piano:SetAttribute("Esposizione", id)
		piano:SetAttribute("Righe", 1)
		piano:SetAttribute("Colonne", 1)
		piano:SetAttribute("Scala", 2.1)
		piano:SetAttribute("Statua", true)
		local def = Epoche.Truppe[id]
		local targa = scatola(m, Vector3.new(7.4, 2.2, 0.4), CFrame.lookAt(pos + verso * 4.1 + Vector3.new(0, PAVIMENTO + 2.7, 0), pos + verso * 10 + Vector3.new(0, PAVIMENTO + 2.7, 0)), LEGNO_SCURO, Enum.Material.Wood)
		insegna(targa, def and def.nome:upper() or id, ORO, Enum.NormalId.Front, def and def.abilita and def.abilita.nome or nil)
		local alto_ = scatola(m, Vector3.new(1, 1, 1), pos + Vector3.new(-lato * 5, PAVIMENTO + ALTO - 3, 0), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, { Transparency = 1, CanCollide = false })
		local l = faretto(alto_, Color3.fromRGB(255, 220, 170), 44, 2.6, 26)
		l.Face = Enum.NormalId.Bottom
		alto_.CFrame = CFrame.lookAt(alto_.Position, pos + Vector3.new(0, PAVIMENTO + 8, 0)) * CFrame.Angles(math.rad(90), 0, 0)
		braciere(m, pos + Vector3.new(lato * 7, PAVIMENTO, 0), 0.7, nil, 22)
	end

	-- Tavolo dell'esercito in fondo, con le carte del mazzo sparse e l'insegna ARMY.
	local tavolo = scatola(m, Vector3.new(18, 3.6, 7), Vector3.new(0, PAVIMENTO + 1.8, 152), LEGNO_SCURO, Enum.Material.Wood)
	scatola(m, Vector3.new(19, 0.5, 8), Vector3.new(0, PAVIMENTO + 3.85, 152), Color3.fromRGB(40, 90, 50), Enum.Material.Fabric)
	local rng = Random.new(3)
	for i = 1, 6 do
		scatola(m, Vector3.new(1.6, 0.08, 2.3), CFrame.new(-6 + i * 1.9, PAVIMENTO + 4.15, 152 + rng:NextNumber(-1, 1)) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0), i <= 2 and Color3.fromRGB(240, 196, 70) or i <= 4 and Color3.fromRGB(200, 206, 214) or Color3.fromRGB(206, 140, 80), Enum.Material.SmoothPlastic)
	end
	for _, x in ipairs({ -7, 7 }) do
		local candela = scatola(m, Vector3.new(0.6, 1.4, 0.6), Vector3.new(x, PAVIMENTO + 4.8, 153.5), Color3.fromRGB(236, 226, 200), Enum.Material.SmoothPlastic)
		fuoco(m, candela.Position + Vector3.new(0, 1, 0), 0.8, Color3.fromRGB(255, 190, 120), 16, true)
	end
	cartello(m, Vector3.new(0, PAVIMENTO + 18, Z1 - 0.4), Vector3.new(0, 0, -1), 26, 7, "ARMY", VERDE, "Build your deck")
	for lato = -1, 1, 2 do
		stendardo(m, Vector3.new(lato * 18, PAVIMENTO + 17, Z1 - 0.3), Vector3.new(0, 0, -1), Color3.fromRGB(40, 110, 50), 7, 18)
	end
	prompt(tavolo, "Manage army", "ARMY", callback, 16)
	soglia(m, Vector3.new(18, 8, 5), CFrame.new(0, PAVIMENTO + 4, 146.5), callback)
	m.Parent = lobby
end

---------------------------------------------------------------------------------------------------------

-- callback: { campagna, ranked, shop, esercito } = function(player)
-- Ingrandisce la cittadella (già costruita a misura 1) di SCALA attorno al centro del pavimento.
-- ScaleTo non tocca luci, prompt e attributi: si sistemano a mano. I soldati e le statue sui piedistalli
-- li mette il client (LobbyVita) con l'attributo "Scala": crescono solo statue e fortezze, che erano già
-- ridimensionate. I soldati restano a misura 1: ridimensionarli costringe Roblox a copiare la mesh di
-- ognuno e la memoria per le mesh finisce (provato il 18/10/2026).
local function ingrandisci(lobby)
	lobby.WorldPivot = CFrame.new(0, PAVIMENTO, 0)
	lobby:ScaleTo(SCALA)
	for _, d in ipairs(lobby:GetDescendants()) do
		if d:IsA("Light") then
			d.Range = math.min(60, d.Range * SCALA)
		elseif d:IsA("ProximityPrompt") then
			d.MaxActivationDistance *= SCALA
		elseif d:IsA("BasePart") and d:GetAttribute("Esposizione") and (d:GetAttribute("Scala") or 1) ~= 1 then
			d:SetAttribute("Scala", d:GetAttribute("Scala") * SCALA)
		end
	end
end

function Lobby.costruisci(callback)
	montagne()
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Transparency = 1
		baseplate.CanCollide = false
		for _, figlio in ipairs(baseplate:GetChildren()) do
			if figlio:IsA("Texture") or figlio:IsA("Decal") then
				figlio:Destroy()
			end
		end
	end

	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	rotonda(lobby)
	galleria(lobby, callback.campagna)
	arena(lobby, callback.ranked)
	armeria(lobby, callback.shop)
	eroi(lobby, callback.esercito)
	ingrandisci(lobby)
	local esterno = Instance.new("Folder")
	esterno.Name = "Esterno"
	fumiDiGuerra(esterno)
	fari(esterno)
	esterno.Parent = lobby
	lobby.Parent = workspace

	-- Sposta lo spawn della Baseplate nella Rotonda e lo rende invisibile.
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation")
	if spawn then
		spawn.CFrame = Lobby.SPAWN - Vector3.new(0, 3, 0)
		spawn.Transparency = 1
		spawn.CanCollide = false
		for _, figlio in ipairs(spawn:GetChildren()) do
			if figlio:IsA("Decal") then
				figlio:Destroy()
			end
		end
	end
	return lobby
end

return Lobby
