-- Menu Settings: togliere la musica, togliere gli effetti sonori, modalità prestazioni.
-- Le scelte si salvano con i progressi (remoto Impostazioni) e arrivano di nuovo con lo stato.
-- Modalità prestazioni: niente ombre, niente bagliore/raggi di sole/sfocatura, meno particelle
-- (meteo, esplosioni) e mantelli fermi. Gli altri moduli chiedono Impostazioni.prestazioni().

local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local Stile = require(script.Parent.Stile)

local Impostazioni = {}

local valori = { musica = true, effetti = true, prestazioni = false }
local remoti, finestra
local interruttori = {} -- chiave -> funzione che ridisegna il pulsante
local cambiato = Instance.new("BindableEvent")
Impostazioni.Cambiato = cambiato.Event

local VOCI = {
	{ chiave = "musica", nome = "Music", descrizione = "Battle music, menus and cutscenes." },
	{ chiave = "effetti", nome = "Sound Effects", descrizione = "Swords, shots, explosions and war cries." },
	{ chiave = "prestazioni", nome = "Performance Mode", descrizione = "No shadows or glow, fewer particles. For slower devices." },
}

local POST_EFFETTI = { "BloomEffect", "SunRaysEffect", "DepthOfFieldEffect" }
local SPENTO = "SpentoDaPrestazioni" -- attributo sugli effetti spenti da qui, da riaccendere dopo

local function gruppo(nome)
	local g = SoundService:FindFirstChild(nome)
	if not g then
		g = Instance.new("SoundGroup")
		g.Name = nome
		g.Volume = 1
		g.Parent = SoundService
	end
	return g
end

-- Le luci cambiano spesso (meteo, mappa, cinematiche): in modalità prestazioni si rispegne tutto ogni mezzo secondo.
local function applicaLuci()
	if valori.prestazioni then
		Lighting.GlobalShadows = false
		for _, effetto in ipairs(Lighting:GetChildren()) do
			if table.find(POST_EFFETTI, effetto.ClassName) and effetto.Enabled then
				effetto.Enabled = false
				effetto:SetAttribute(SPENTO, true)
			end
		end
	end
end

local function applica()
	gruppo("Musica").Volume = valori.musica and 1 or 0
	-- Effetti ben sotto la musica (richiesta di Mattia): 0.4 invece di 1.
	gruppo("Effetti").Volume = valori.effetti and 0.4 or 0
	if valori.prestazioni then
		applicaLuci()
	else
		Lighting.GlobalShadows = true
		for _, effetto in ipairs(Lighting:GetChildren()) do
			if effetto:GetAttribute(SPENTO) then
				effetto:SetAttribute(SPENTO, nil)
				effetto.Enabled = true
			end
		end
	end
	for _, ridisegna in pairs(interruttori) do
		ridisegna()
	end
	cambiato:Fire()
end

function Impostazioni.musica()
	return valori.musica
end

function Impostazioni.effetti()
	return valori.effetti
end

function Impostazioni.prestazioni()
	return valori.prestazioni
end

local function cambia(chiave)
	valori[chiave] = not valori[chiave]
	applica()
	task.spawn(function()
		remoti.Impostazioni:InvokeServer(chiave, valori[chiave])
	end)
end

-- Una riga del menu: nome, spiegazione e interruttore ON/OFF.
local function riga(contenuto, voce, ordine)
	local fondo = Stile.vassoio({
		Position = UDim2.fromOffset(0, (ordine - 1) * 150),
		Size = UDim2.new(1, 0, 0, 130),
		ZIndex = 12,
		Parent = contenuto,
	})
	Stile.scritta({
		Position = UDim2.fromOffset(30, 18),
		Size = UDim2.new(1, -300, 0, 50),
		Text = voce.nome,
		TextSize = 44,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 13,
		Parent = fondo,
	})
	Stile.testo({
		Position = UDim2.fromOffset(30, 74),
		Size = UDim2.new(1, -300, 0, 34),
		Text = voce.descrizione,
		TextSize = 26,
		TextScaled = false,
		TextColor3 = Stile.Colori.TestoSecondario,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 13,
		Parent = fondo,
	})
	local bottone, etichetta = Stile.pulsante({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -24, 0.5, 0),
		Size = UDim2.fromOffset(220, 90),
		ZIndex = 13,
		Parent = fondo,
	}, "verde", { Testo = "ON", TestoSize = 46 })
	for _, d in ipairs(bottone:GetDescendants()) do
		if d:IsA("GuiObject") then
			d.ZIndex = 14
		end
	end
	interruttori[voce.chiave] = function()
		local acceso = valori[voce.chiave]
		Stile.coloraPulsante(bottone, acceso and "verde" or "grigio")
		etichetta.Text = acceso and "ON" or "OFF"
	end
	interruttori[voce.chiave]()
	bottone.Activated:Connect(function()
		cambia(voce.chiave)
	end)
end

function Impostazioni.inizializza(gui, r)
	remoti = r
	local contenuto
	finestra, contenuto = Stile.finestra(gui, "Impostazioni", "Settings", "blu", "settings")
	finestra.Size = UDim2.fromOffset(1000, 640)
	for i, voce in ipairs(VOCI) do
		riga(contenuto, voce, i)
	end
	applica()
	task.spawn(function()
		while true do
			task.wait(0.5)
			applicaLuci()
		end
	end)
end

-- Valori salvati, dallo stato mandato dal server.
function Impostazioni.aggiorna(stato)
	local salvate = stato and stato.impostazioni
	if typeof(salvate) ~= "table" then
		return
	end
	local diverso = false
	for chiave in pairs(valori) do
		if typeof(salvate[chiave]) == "boolean" and salvate[chiave] ~= valori[chiave] then
			valori[chiave] = salvate[chiave]
			diverso = true
		end
	end
	if diverso then
		applica()
	end
end

function Impostazioni.apri()
	finestra.Visible = true
end

function Impostazioni.chiudi()
	finestra.Visible = false
end

function Impostazioni.alterna()
	finestra.Visible = not finestra.Visible
end

return Impostazioni
