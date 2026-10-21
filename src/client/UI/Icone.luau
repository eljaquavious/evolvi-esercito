-- Icone dell'interfaccia: immagini di assets/gui caricate su Roblox (id in ImmaginiId).
-- Se un'immagine non è ancora caricata si vede un'emoji al suo posto, così il gioco funziona lo stesso.

local Id = require(script.Parent.ImmaginiId)

local Icone = {}

local EMOJI = {
	coin = "🪙",
	star = "⭐",
	shop = "🧰",
	army = "🪖",
	profile = "🏅",
	ranked = "🏆",
	campaign = "🗺️",
	fight = "⚔️",
	cls_inf = "🛡️",
	cls_cav = "🐎",
	cls_rng = "🏹",
	cls_fort = "🏰",
	close = "✖️",
	plus = "➕",
	check = "✅",
	back = "⬅️",
	lock = "🔒",
	settings = "⚙️",
	level = "🔷",
	premium = "💎",
	boost = "⚡",
	daily = "🎁",
	locker = "🎽",
	title = "📜",
	codes = "🎟️",
	crate_medieval = "🧰",
	crate_modern = "🧰",
	crate_legend = "🧰",
	crate_small = "📦",
	crate_medium = "📦",
	crate_big = "🎁",
	chest_small = "🧳",
	chest_medium = "🧳",
	chest_big = "💼",
	coins_1 = "🪙",
	coins_2 = "🪙",
	coins_3 = "💰",
	coins_4 = "💰",
	coins_5 = "💰",
	coins_6 = "🏦",
	robux = "💎",
	feedback = "💬",
	inbox = "📥",
	card_roman_legionaries = "🛡️",
	card_cretan_archers = "🏹",
	card_companion_cavalry = "🐎",
	card_saxon_huscarls = "🪓",
	card_english_longbowmen = "🎯",
	card_norman_knights = "🐴",
	card_french_poilus = "🪖",
	card_machine_gun_crew = "💥",
	card_sherman_tank = "🛞",
	card_hannibal_barca = "🐘",
	card_julius_caesar = "🏛️",
	card_william_the_conqueror = "👑",
	card_joan_of_arc = "⚜️",
	card_ferdinand_foch = "🎖️",
	card_charles_de_gaulle = "🇫🇷",
}

-- "rbxassetid://..." dell'immagine, oppure nil se non è ancora caricata.
function Icone.id(nome)
	local numero = Id[nome]
	if numero and numero ~= 0 and numero ~= "" then
		return "rbxassetid://" .. tostring(numero)
	end
	return nil
end

-- Nome dell'icona della carta di una truppa: "Roman Legionaries" -> "card_roman_legionaries".
function Icone.carta(def)
	return def.icona or (string.lower(def.nome):gsub("[^%w%s]", ""):gsub("%s+", "_"):gsub("^", "card_"))
end

-- Crea l'icona come ImageLabel (o TextLabel con emoji se l'immagine manca).
function Icone.crea(nome, proprieta)
	proprieta = proprieta or {}
	local immagine = Icone.id(nome)
	local etichetta
	if immagine then
		etichetta = Instance.new("ImageLabel")
		etichetta.Image = immagine
		etichetta.ScaleType = Enum.ScaleType.Fit
	else
		etichetta = Instance.new("TextLabel")
		etichetta.Text = EMOJI[nome] or "❔"
		etichetta.TextScaled = true
		etichetta.Font = Enum.Font.GothamBold
		etichetta.TextColor3 = Color3.new(1, 1, 1)
	end
	etichetta.Name = "Icona_" .. nome
	etichetta.BackgroundTransparency = 1
	etichetta.BorderSizePixel = 0
	local genitore = proprieta.Parent
	for k, v in pairs(proprieta) do
		if k ~= "Parent" then
			etichetta[k] = v
		end
	end
	etichetta.Parent = genitore
	return etichetta
end

-- Cambia l'icona mostrata da un'etichetta creata con Icone.crea (stessa classe, solo immagine o emoji).
function Icone.cambia(etichetta, nome)
	if etichetta:IsA("ImageLabel") then
		etichetta.Image = Icone.id(nome) or ""
	else
		etichetta.Text = EMOJI[nome] or "❔"
	end
end

-- Immagine semplice (sfondi delle carte, raggi): nil se non è caricata.
function Icone.immagine(nome)
	return Icone.id(nome)
end

return Icone
