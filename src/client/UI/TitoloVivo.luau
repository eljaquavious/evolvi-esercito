-- Titoli animati e multicolori (Mattia, 10/11/2026). L'effetto di un titolo sta in Config/Ricompense
-- (campo "effetto"); qui si colora la scritta con un UIGradient e, se l'effetto si muove, lo si aggiorna.
--
-- Tipi di effetto:
--   sfumato    = più colori fermi, da sinistra a destra (multicolore)
--   scorre     = più colori che scorrono lungo la scritta (multicolore e animato)
--   arcobaleno = tutti i colori che scorrono (multicolore e animato)
--   pulsa      = la scritta passa piano da un colore all'altro (animato)
--   lampo      = un colore solo, con un riflesso chiaro che la attraversa (animato)
--
-- La targhetta sopra la testa la crea il server (Server/Aspetto): mette sull'etichetta il tag "TitoloVivo"
-- e l'attributo "TitoloId", e qui ogni client la anima per conto suo.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Ricompense)

local TitoloVivo = {}

local TAG = "TitoloVivo"
local NOME = "EffettoTitolo"
local PUNTI = 13 -- colori lungo la scritta (un ColorSequence ne regge 20)
local PASSO = 1 / 20 -- secondi tra un aggiornamento e l'altro
local BIANCO = Color3.new(1, 1, 1)
local FERMI = { sfumato = true }

local tavolozze = setmetatable({}, { __mode = "k" }) -- effetto -> { Color3 }
local vivi = {} -- etichetta -> { sfumatura, effetto }

local function tavolozza(effetto)
	local t = tavolozze[effetto]
	if not t then
		t = {}
		for i, h in ipairs(effetto.colori or {}) do
			t[i] = Color3.fromHex(h)
		end
		tavolozze[effetto] = t
	end
	return t
end

-- Colore lungo una fila di colori: aperta (da primo a ultimo) o chiusa ad anello (dopo l'ultimo torna il primo).
local function lungo(colori, x, anello)
	local n = #colori
	if n == 0 then
		return BIANCO
	elseif n == 1 then
		return colori[1]
	end
	local p
	if anello then
		p = (x % 1) * n
	else
		p = math.clamp(x, 0, 1) * (n - 1)
	end
	local i = math.floor(p)
	local a = colori[i % n + 1]
	local b = colori[(i + 1) % n + 1]
	if not anello and i >= n - 1 then
		return colori[n]
	end
	return a:Lerp(b, p - i)
end

-- Colore dell'effetto nel punto x della scritta (0 = sinistra, 1 = destra) al tempo t.
function TitoloVivo.colore(effetto, x, t)
	local colori = tavolozza(effetto)
	local periodo = effetto.periodo or 3
	local tipo = effetto.tipo
	if tipo == "arcobaleno" then
		return Color3.fromHSV((x * 0.8 - t / periodo) % 1, 0.7, 1)
	elseif tipo == "scorre" then
		return lungo(colori, x * 0.8 - t / periodo, true)
	elseif tipo == "pulsa" then
		return lungo(colori, 0.5 - 0.5 * math.cos(t / periodo * math.pi * 2), false)
	elseif tipo == "lampo" then
		-- Il riflesso attraversa la scritta nel primo 45% del periodo, poi una pausa.
		local centro = (t % periodo) / (periodo * 0.45) * 1.5 - 0.25
		local k = math.max(0, 1 - math.abs(x - centro) / 0.2)
		return (colori[1] or BIANCO):Lerp(colori[2] or BIANCO, k)
	end
	return lungo(colori, x, false)
end

local function sequenza(effetto, t)
	local punti = table.create(PUNTI)
	for i = 0, PUNTI - 1 do
		local x = i / (PUNTI - 1)
		punti[i + 1] = ColorSequenceKeypoint.new(x, TitoloVivo.colore(effetto, x, t))
	end
	return ColorSequence.new(punti)
end

-- Mette (o toglie) l'effetto del titolo su una scritta. Chi chiama imposta prima TextColor3 al colore
-- normale: se il titolo ha un effetto, qui la scritta diventa bianca e il colore lo dà la sfumatura.
-- titolo = nil toglie l'effetto.
function TitoloVivo.applica(etichetta, titolo)
	vivi[etichetta] = nil
	local vecchia = etichetta:FindFirstChild(NOME)
	if vecchia then
		vecchia:Destroy()
	end
	local effetto = titolo and titolo.effetto
	if not effetto then
		return
	end
	etichetta.TextColor3 = BIANCO
	local sfumatura = Instance.new("UIGradient")
	sfumatura.Name = NOME
	sfumatura.Color = sequenza(effetto, os.clock())
	sfumatura.Parent = etichetta
	if not FERMI[effetto.tipo] then
		vivi[etichetta] = { sfumatura = sfumatura, effetto = effetto }
	end
end

-- Il titolo scritto per la chat (RichText): una lettera per colore. Gli effetti di un colore solo restano di quel colore.
function TitoloVivo.testoChat(titolo, testo)
	local effetto = titolo and titolo.effetto
	if not effetto then
		return nil
	end
	local n = #testo
	local parti = table.create(n)
	for i = 1, n do
		local lettera = string.sub(testo, i, i)
		local x = n > 1 and (i - 1) / (n - 1) or 0
		local c = (effetto.tipo == "pulsa" or effetto.tipo == "lampo") and tavolozza(effetto)[1] or TitoloVivo.colore(effetto, x, 0)
		lettera = string.gsub(lettera, "[<>&]", { ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;" })
		parti[i] = ('<font color="#%s">%s</font>'):format((c or BIANCO):ToHex(), lettera)
	end
	return table.concat(parti)
end

local function segui(etichetta)
	if not etichetta:IsA("TextLabel") then
		return
	end
	local function aggiorna()
		local titolo = Config.titolo(etichetta:GetAttribute("TitoloId"))
		if titolo then
			etichetta.TextColor3 = Color3.fromHex(Config.Rarita[titolo.rarita].colore)
		end
		TitoloVivo.applica(etichetta, titolo)
	end
	etichetta:GetAttributeChangedSignal("TitoloId"):Connect(aggiorna)
	aggiorna()
end

function TitoloVivo.inizializza()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(segui)
	for _, etichetta in ipairs(CollectionService:GetTagged(TAG)) do
		segui(etichetta)
	end
end

local attesa = 0
RunService.Heartbeat:Connect(function(dt)
	attesa += dt
	if attesa < PASSO then
		return
	end
	attesa = 0
	local t = os.clock()
	for etichetta, v in pairs(vivi) do
		if not v.sfumatura.Parent or not etichetta:IsDescendantOf(game) then
			vivi[etichetta] = nil
		else
			v.sfumatura.Color = sequenza(v.effetto, t)
		end
	end
end)

return TitoloVivo
