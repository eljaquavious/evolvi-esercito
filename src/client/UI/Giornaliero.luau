-- Finestra del premio giornaliero: 7 caselle (Day 1-7), quella di oggi evidenziata, CLAIM per ritirarlo.
-- I dati arrivano con lo stato (stato.giornaliero, da Server/Giornaliero); si apre da sola in lobby quando
-- c'è un premio da ritirare (una volta per sessione) e dal riquadro "Daily" a sinistra.

local Stile = require(script.Parent.Stile)
local Notifiche = require(script.Parent.Notifiche)

local Giornaliero = {}

local remoti, schermo, finestra, bottone, etichetta
local caselle = {} -- numero -> { fondo, spunta, nome }
local info -- ultimo stato.giornaliero ricevuto
local ricevuto = 0 -- os.clock() quando è arrivato (per il conto alla rovescia)
local inAttesa = false

local function durata(secondi)
	secondi = math.max(0, math.floor(secondi))
	return ("%dh %02dm"):format(secondi // 3600, (secondi % 3600) // 60)
end

local function ridisegna()
	if not info or not finestra then
		return
	end
	for numero, c in ipairs(caselle) do
		-- Già ritirati in questo giro: quelli prima del prossimo (se oggi è già preso, anche il "prossimo" è di domani).
		local fatto = numero < info.prossimo
		local oggi = numero == info.prossimo and info.disponibile
		c.fondo.BackgroundColor3 = oggi and Stile.Colori.Oro or Color3.fromRGB(228, 233, 250)
		c.fondo.BackgroundTransparency = fatto and 0.45 or 0
		c.spunta.Visible = fatto
		c.nome.Text = oggi and "TODAY" or ("DAY " .. numero)
	end
	if info.disponibile then
		Stile.coloraPulsante(bottone, "verde")
		etichetta.Text = "CLAIM"
	else
		Stile.coloraPulsante(bottone, "grigio")
		etichetta.Text = "Next in " .. durata(info.mancano - (os.clock() - ricevuto))
	end
end

local function casella(contenuto, numero, premio)
	local larghezza = 186
	local fondo = Stile.vassoio({
		Position = UDim2.fromOffset((numero - 1) * (larghezza + 18), 0),
		Size = UDim2.fromOffset(larghezza, 300),
		ZIndex = 12,
		Parent = contenuto,
	})
	local nome = Stile.scritta({
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.new(1, 0, 0, 40),
		Text = "DAY " .. numero,
		TextSize = 34,
		ZIndex = 13,
		Parent = fondo,
	})
	Stile.icona(premio.cassa and "crate_small" or "coin", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 62),
		Size = UDim2.fromOffset(120, 120),
		ZIndex = 13,
		Parent = fondo,
	})
	Stile.scritta({
		Position = UDim2.fromOffset(6, 192),
		Size = UDim2.new(1, -12, 0, 44),
		Text = "+" .. Stile.numero(premio.monete),
		TextSize = 40,
		ZIndex = 13,
		Parent = fondo,
	})
	if premio.cassa then
		Stile.scritta({
			Position = UDim2.fromOffset(6, 240),
			Size = UDim2.new(1, -12, 0, 40),
			Text = "+ Small Crate",
			TextSize = 26,
			ZIndex = 13,
			Parent = fondo,
		})
	end
	local spunta = Stile.icona("check", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(110, 110),
		Visible = false,
		ZIndex = 15,
		Parent = fondo,
	})
	caselle[numero] = { fondo = fondo, spunta = spunta, nome = nome }
end

local function costruisci(premi)
	local contenuto
	finestra, contenuto = Stile.finestra(schermo, "Giornaliero", "Daily Reward", "verde", "daily")
	finestra.Size = UDim2.fromOffset(1520, 620)
	for numero, premio in ipairs(premi) do
		casella(contenuto, numero, premio)
	end
	bottone, etichetta = Stile.pulsante({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(460, 110),
		ZIndex = 13,
		Parent = contenuto,
	}, "verde", { Testo = "CLAIM", TestoSize = 52 })
	for _, d in ipairs(bottone:GetDescendants()) do
		if d:IsA("GuiObject") then
			d.ZIndex = 14
		end
	end
	bottone.Activated:Connect(function()
		if inAttesa or not info or not info.disponibile then
			return
		end
		inAttesa = true
		local ok, messaggio = remoti.RitiraGiornaliero:InvokeServer()
		inAttesa = false
		if messaggio then
			Notifiche.mostra(messaggio, not ok and Stile.Colori.Rosso or nil)
		end
		if ok then
			finestra.Visible = false
		end
	end)
	ridisegna()
end

-- gui: la ScreenGui del gioco. La finestra si costruisce al primo stato (servono i premi del server).
function Giornaliero.inizializza(gui, r)
	remoti = r
	schermo = gui
	task.spawn(function()
		while true do
			task.wait(20)
			if finestra and finestra.Visible then
				ridisegna()
			end
		end
	end)
end

function Giornaliero.aggiorna(stato)
	if typeof(stato) ~= "table" or typeof(stato.giornaliero) ~= "table" then
		return
	end
	info = stato.giornaliero
	ricevuto = os.clock()
	if not finestra then
		costruisci(info.premi)
	end
	ridisegna()
end

-- C'è un premio da ritirare oggi?
function Giornaliero.disponibile()
	return info ~= nil and info.disponibile
end

function Giornaliero.apri()
	if finestra then
		ridisegna()
		finestra.Visible = true
	end
end

function Giornaliero.chiudi()
	if finestra then
		finestra.Visible = false
	end
end

function Giornaliero.alterna()
	if finestra then
		if finestra.Visible then
			finestra.Visible = false
		else
			Giornaliero.apri()
		end
	end
end

return Giornaliero
