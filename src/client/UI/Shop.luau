-- Finestra dello shop: schede CRATES / COINS / BOOSTS (le ultime due in arrivo) e le casse in vendita.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Casse = require(ReplicatedStorage.Shared.Config.Casse)
local Epoche = require(ReplicatedStorage.Shared.Config.Epoche)
local Campagna = require(ReplicatedStorage.Shared.Config.Campagna)
local Stile = require(script.Parent.Stile)
local Notifiche = require(script.Parent.Notifiche)

local Shop = {}

local finestra, rigaCasse, inArrivo, numeroMonete
local remotiShop
local stato -- ultimo stato ricevuto (monete ed epoca raggiunta)
local schede = {} -- { bottone, nome }
local schedaAttiva = "CRATES"

-- Aspetto di ogni cassa: colore della scheda, icona e colore del nastro SOON.
local ASPETTO = {
	CassaMedievale = { pal = "blu", icona = "crate_medieval", nastro = "rosa" },
	CassaNovecento = { pal = "verde", icona = "crate_modern", nastro = "rosa" },
	CassaLeggendaria = { pal = "viola", icona = "crate_legend", nastro = "oro" },
}
local ASPETTO_ORDINE = { ASPETTO.CassaMedievale, ASPETTO.CassaNovecento, ASPETTO.CassaLeggendaria }

local function svuota(contenitore)
	for _, figlio in ipairs(contenitore:GetChildren()) do
		if figlio:IsA("GuiObject") then
			figlio:Destroy()
		end
	end
end

-- L'epoca richiesta è già raggiunta nella campagna? Senza stato si considera bloccata.
local function epocaSbloccata(idEpoca)
	if not stato or not stato.livello then
		return false
	end
	local raggiunta = Campagna.livello(stato.livello).indiceEpoca
	return (Epoche.indice(idEpoca) or math.huge) <= raggiunta
end

local function scheda(cassa, ordine, larghezza)
	local aspetto = ASPETTO[cassa.id] or ASPETTO_ORDINE[(ordine - 1) % #ASPETTO_ORDINE + 1]
	local pal = Stile.PAL[aspetto.pal]

	local riquadro = Stile.crea("Frame", {
		Name = cassa.id,
		Size = UDim2.new(0, larghezza, 1, 0),
		LayoutOrder = ordine,
		BackgroundTransparency = 1,
		Parent = rigaCasse,
	})
	-- Base scura sotto (effetto 3D) e faccia con la sfumatura.
	Stile.crea("Frame", {
		Name = "Base",
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.new(1, 0, 1, -10),
		BackgroundColor3 = pal.d,
		Parent = riquadro,
	}, { Stile.angoli(34), Stile.bordo(Stile.CONTORNO, 6) })
	local faccia = Stile.crea("Frame", {
		Name = "Faccia",
		Size = UDim2.new(1, 0, 1, -14),
		BackgroundColor3 = Stile.BIANCO,
		ClipsDescendants = true,
		Parent = riquadro,
	}, { Stile.angoli(34), Stile.bordo(Stile.CONTORNO, 6), Stile.sfumatura(pal.t, pal.b) })
	-- Bagliore dietro la cassa.
	Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 190),
		Size = UDim2.fromOffset(340, 340),
		BackgroundColor3 = Stile.BIANCO,
		BackgroundTransparency = 0.78,
		Parent = faccia,
	}, { Stile.tondo() })
	Stile.icona(aspetto.icona, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 190),
		Size = UDim2.fromOffset(280, 280),
		ZIndex = 2,
		Parent = faccia,
	})

	local nome = Stile.scritta({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 338),
		Size = UDim2.new(1, -40, 0, 62),
		Text = cassa.nome,
		TextSize = 54,
		Contorno = 6,
		ZIndex = 2,
		Parent = faccia,
	})
	nome.TextScaled = true
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 54, Parent = nome })
	Stile.testo({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 404),
		Size = UDim2.new(1, -80, 0, 64),
		Text = cassa.descrizione,
		TextSize = 26,
		TextScaled = false,
		TextWrapped = true,
		TextColor3 = pal.t:Lerp(Stile.BIANCO, 0.6),
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 2,
		Parent = faccia,
	})

	-- Le classi che si possono trovare nella cassa.
	local classi = Stile.crea("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 478),
		Size = UDim2.new(1, -40, 0, 70),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = faccia,
	}, {
		Stile.crea("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 16),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, icona in ipairs({ "cls_inf", "cls_cav", "cls_rng" }) do
		local tassello = Stile.crea("Frame", {
			Size = UDim2.fromOffset(70, 70),
			LayoutOrder = i,
			BackgroundColor3 = pal.d,
			BackgroundTransparency = 0.45,
			Parent = classi,
		}, { Stile.angoli(16) })
		Stile.icona(icona, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(52, 52),
			Parent = tassello,
		})
	end

	-- Pulsante d'acquisto: prezzo con l'icona della valuta, oppure grigio "Locked" se l'epoca non è raggiunta.
	local bloccata = cassa.richiedeEpoca ~= nil and not epocaSbloccata(cassa.richiedeEpoca)
	local bottone
	local propBottone = {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -22),
		Size = UDim2.new(1, -60, 0, 96),
		ZIndex = 3,
		Parent = faccia,
	}
	if bloccata then
		bottone = Stile.pulsante(propBottone, "grigio", {
			Testo = "Locked",
			TestoSize = 46,
			Sotto = "Requires the " .. Epoche.epoca(cassa.richiedeEpoca).nome .. " era",
			SottoSize = 22,
			Icona = "lock",
			IconaSize = 58,
			IconaX = 18,
		})
	else
		bottone = Stile.pulsante(propBottone, "verde", {
			Testo = Stile.numero(cassa.prezzo),
			TestoSize = 60,
			Icona = cassa.valuta == "Robux" and "premium" or "coin",
			IconaSize = 70,
			IconaX = 14,
		})
	end
	bottone.Activated:Connect(function()
		local ok, messaggio = remotiShop.AcquistaCassa:InvokeServer(cassa.id)
		if messaggio then
			Notifiche.mostra(messaggio, ok and Stile.Colori.Verde or nil)
		end
	end)

	-- Nastro "SOON" sull'angolo finché la cassa non è in vendita.
	if not cassa.disponibile then
		Stile.nastro({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -90, 0, 6),
			Size = UDim2.fromOffset(160, 54),
			ZIndex = 6,
			Parent = riquadro,
		}, aspetto.nastro, "SOON", 34)
	end
end

local function disegna()
	if not rigaCasse then
		return
	end
	svuota(rigaCasse)
	local n = math.max(#Casse.Lista, 1)
	local spazio = 50
	-- Il contenuto della finestra è largo 1708 pixel di progetto.
	local larghezza = math.min(536, math.floor((1708 - spazio * (n - 1)) / n))
	for i, cassa in ipairs(Casse.Lista) do
		scheda(cassa, i, larghezza)
	end
	if stato and numeroMonete then
		numeroMonete.Text = Stile.numero(stato.monete or 0)
	end
end

local function mostraScheda(nome)
	schedaAttiva = nome
	for _, s in ipairs(schede) do
		Stile.coloraPulsante(s.bottone, s.nome == nome and "blu" or "grigio")
	end
	rigaCasse.Visible = nome == "CRATES"
	inArrivo.Visible = nome ~= "CRATES"
end

function Shop.inizializza(gui, remoti)
	remotiShop = remoti
	local contenuto, fascia
	finestra, contenuto, fascia = Stile.finestra(gui, "Shop", "Shop", "rosso", "shop")

	-- Monete nella fascia del titolo.
	local _, numero = Stile.pillola({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -150, 0.5, -4),
		Size = UDim2.fromOffset(260, 70),
		ZIndex = 14,
		Parent = fascia,
	}, "coin", "0")
	numeroMonete = numero

	-- Schede in alto a sinistra.
	local barraSchede = Stile.crea("Frame", {
		Size = UDim2.fromOffset(900, 70),
		BackgroundTransparency = 1,
		Parent = contenuto,
	}, {
		Stile.crea("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, voce in ipairs({ { "CRATES", nil, 146 }, { "COINS", "coin", 176 }, { "BOOSTS", "boost", 190 } }) do
		local bottone = Stile.pulsante({
			Size = UDim2.fromOffset(voce[3], 66),
			LayoutOrder = i,
			Parent = barraSchede,
		}, voce[1] == schedaAttiva and "blu" or "grigio", {
			Testo = voce[1],
			TestoSize = 30,
			Icona = voce[2],
			IconaSize = 42,
			IconaX = 12,
			Profondita = 6,
			Raggio = 30,
			Contorno = 4,
		})
		bottone.Activated:Connect(function()
			mostraScheda(voce[1])
		end)
		table.insert(schede, { bottone = bottone, nome = voce[1] })
	end
	Stile.testo({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 20),
		Size = UDim2.fromOffset(600, 30),
		Text = "Odds are shown before every purchase",
		TextSize = 22,
		TextScaled = false,
		TextColor3 = Stile.Colori.TestoSecondario,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = contenuto,
	})

	rigaCasse = Stile.crea("Frame", {
		Position = UDim2.fromOffset(0, 112),
		Size = UDim2.new(1, 0, 1, -112),
		BackgroundTransparency = 1,
		Parent = contenuto,
	}, {
		Stile.crea("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 50),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	inArrivo = Stile.scritta({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 40),
		Size = UDim2.fromOffset(800, 90),
		Text = "Coming soon",
		TextSize = 72,
		Contorno = 7,
		TextColor3 = Stile.Colori.Azzurro,
		Visible = false,
		Parent = contenuto,
	})
	disegna()
end

-- Riceve lo stato del giocatore: monete nella fascia e casse sbloccate dall'epoca raggiunta.
function Shop.aggiorna(nuovoStato)
	if not nuovoStato then
		return
	end
	stato = nuovoStato
	disegna()
end

function Shop.apri()
	finestra.Visible = true
end

function Shop.chiudi()
	finestra.Visible = false
end

function Shop.alterna()
	finestra.Visible = not finestra.Visible
end

return Shop
