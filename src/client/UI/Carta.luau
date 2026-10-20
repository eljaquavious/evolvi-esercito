-- Carta di un reggimento in stile carte dei giochi di calcio: OVR, classe, icona disegnata, nome e statistiche.
-- Colore della carta per epoca: Antichità bronzo, Medioevo argento, Novecento oro, comandanti LEGEND viola-azzurro.
-- La carta è disegnata in una tela 200x290 dentro il pulsante e si adatta a qualsiasi dimensione.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Epoche = require(ReplicatedStorage.Shared.Config.Epoche)
local Carte = require(ReplicatedStorage.Shared.Config.Carte)
local Stile = require(script.Parent.Stile)
local Icone = require(script.Parent.Icone)

local Carta = {}

Carta.PROPORZIONE = 200 / 290 -- larghezza / altezza
local L, A = 200, 290

local function hex(h)
	return Color3.fromHex(h)
end

-- Rarità per epoca: sfumatura del cartoncino, fondo del ritratto, colore del testo.
local RARITA = {
	bronze = { stop = { hex("#FFE0BC"), hex("#F0A462"), hex("#A95A24") }, fondo = { hex("#FFF0DE"), hex("#E9A764") } },
	silver = { stop = { hex("#FFFFFF"), hex("#CCD9F2"), hex("#7D91BD") }, fondo = { hex("#FFFFFF"), hex("#A9BCE3") } },
	gold = { stop = { hex("#FFF7B8"), hex("#FFD23F"), hex("#E68700") }, fondo = { hex("#FFFBE0"), hex("#FFC233") } },
	legend = { stop = { hex("#FF6AD5"), hex("#9B5CFF"), hex("#36C8FF") }, fondo = { hex("#FFD6F6"), hex("#8C4BFF") } },
}
local PER_EPOCA = { Antica = "bronze", Medievale = "silver", Novecento = "gold", Moderna = "gold" }

local ICONE_CLASSE = { Fanteria = "cls_inf", Cavalleria = "cls_cav", Tiratore = "cls_rng", Fortezza = "cls_fort" }

function Carta.rarita(def)
	return def.comandante and "legend" or PER_EPOCA[def.epoca] or "silver"
end

function Carta.iconaClasse(def)
	return ICONE_CLASSE[def.classe] or "cls_inf"
end

-- Colore principale della carta (per bordi e sfondi di chi la mostra).
function Carta.tema(def)
	local r = RARITA[Carta.rarita(def)]
	return { r.stop[1], r.stop[3], r.stop[2], Stile.Colori.TestoScuro }
end

-- Tiene la tela interna 200x290 grande quanto il pulsante.
local function adattaScala(carta, corpo, scala)
	local function aggiorna()
		local fuori = carta.AbsoluteSize.X
		local dentro = corpo.AbsoluteSize.X
		if fuori < 1 or dentro < 1 then
			return
		end
		local nuova = fuori * scala.Scale / dentro
		if math.abs(nuova - scala.Scale) > 0.002 then
			scala.Scale = nuova
		end
	end
	carta:GetPropertyChangedSignal("AbsoluteSize"):Connect(aggiorna)
	corpo:GetPropertyChangedSignal("AbsoluteSize"):Connect(aggiorna)
	task.defer(aggiorna)
end

local function etichetta(genitore, x, y, w, h, testo, dimensione, colore, allinea, font, z)
	return Stile.testo({
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		Text = testo,
		TextSize = dimensione,
		TextScaled = false,
		FontFace = font or Stile.FontEtichetta,
		TextColor3 = colore,
		TextXAlignment = allinea or Enum.TextXAlignment.Center,
		ZIndex = z or 4,
		Parent = genitore,
	})
end

local function scritta(genitore, x, y, w, h, testo, dimensione, contorno, z, allinea)
	return Stile.scritta({
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		Text = testo,
		TextSize = dimensione,
		TextScaled = false,
		Contorno = contorno,
		TextXAlignment = allinea or Enum.TextXAlignment.Center,
		ZIndex = z or 4,
		Parent = genitore,
	})
end

-- Fondo della carta: immagine a forma di scudo se caricata, altrimenti cornice disegnata con i Frame.
local function fondo(corpo, rarita)
	local r = RARITA[rarita]
	local immagine = Icone.immagine("card_" .. rarita)
	local ombra = Icone.immagine("card_shadow")
	if ombra then
		Stile.crea("ImageLabel", {
			Name = "Ombra",
			Position = UDim2.fromOffset(-8, -1),
			Size = UDim2.fromOffset(L + 16, A + 16),
			Image = ombra,
			ImageTransparency = 0.6,
			BackgroundTransparency = 1,
			ZIndex = 1,
			Parent = corpo,
		})
	end
	if immagine then
		return Stile.crea("ImageLabel", {
			Name = "Fondo",
			Position = UDim2.fromOffset(-8, -8),
			Size = UDim2.fromOffset(L + 16, A + 16),
			Image = immagine,
			BackgroundTransparency = 1,
			ZIndex = 2,
			Parent = corpo,
		})
	end
	local cornice = Stile.crea("Frame", {
		Name = "Fondo",
		Size = UDim2.fromOffset(L, A - 16),
		BackgroundColor3 = Stile.BIANCO,
		ZIndex = 2,
		Parent = corpo,
	}, {
		Stile.angoli(18),
		Stile.bordo(Stile.CONTORNO, 5),
		Stile.crea("UIGradient", {
			Rotation = 55,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, r.stop[1]),
				ColorSequenceKeypoint.new(0.5, r.stop[2]),
				ColorSequenceKeypoint.new(1, r.stop[3]),
			}),
		}),
	})
	Stile.crea("Frame", {
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(176, 144),
		BackgroundColor3 = Stile.BIANCO,
		ZIndex = 2,
		Parent = cornice,
	}, { Stile.angoli(12), Stile.bordo(Stile.CONTORNO, 3), Stile.sfumatura(r.fondo[1], r.fondo[2], 60) })
	Stile.crea("Frame", {
		Position = UDim2.fromOffset(6, 160),
		Size = UDim2.fromOffset(188, 34),
		BackgroundColor3 = Stile.CONTORNO,
		BackgroundTransparency = 0.08,
		ZIndex = 2,
		Parent = cornice,
	}, { Stile.angoli(8) })
	return cornice
end

-- Crea la carta di "tipo". opzioni: { quantita = numero, nota = testo (carta bloccata), spenta = bool }
-- Restituisce un TextButton: dimensione e posizione le decide chi la usa (proporzione Carta.PROPORZIONE).
function Carta.crea(tipo, opzioni)
	opzioni = opzioni or {}
	local def = Epoche.Truppe[tipo]
	local v = Carte.valutazioni(def)
	local rarita = Carta.rarita(def)
	local leggenda = rarita == "legend"
	local colore = leggenda and Stile.BIANCO or Stile.Colori.TestoScuro

	local carta = Stile.crea("TextButton", {
		Name = "Carta_" .. tipo,
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(L, A),
	}, {
		Stile.crea("UIAspectRatioConstraint", { AspectRatio = Carta.PROPORZIONE }),
	})
	carta:SetAttribute("Tipo", tipo)
	local corpo = Stile.crea("Frame", {
		Name = "Corpo",
		Size = UDim2.fromOffset(L, A),
		BackgroundTransparency = 1,
		Parent = carta,
	})
	adattaScala(carta, corpo, Stile.crea("UIScale", { Parent = corpo }))

	fondo(corpo, rarita)

	-- Icona disegnata della carta.
	Stile.icona(Icone.carta(def), {
		Name = "Arte",
		Position = UDim2.fromOffset(64, 18),
		Size = UDim2.fromOffset(124, 124),
		ZIndex = 3,
		Parent = corpo,
	})

	-- OVR e classe in alto a sinistra.
	scritta(corpo, 4, 14, 68, 54, tostring(v.OVR), 50, 5)
	Stile.icona(Carta.iconaClasse(def), {
		Position = UDim2.fromOffset(16, 76),
		Size = UDim2.fromOffset(44, 44),
		ZIndex = 4,
		Parent = corpo,
	})
	scritta(corpo, 8, 120, 60, 20, Epoche.Classi[def.classe].sigla, 16, 2)

	if leggenda then
		Stile.nastro({
			Position = UDim2.fromOffset(116, 4),
			Size = UDim2.fromOffset(82, 26),
			ZIndex = 5,
			Parent = corpo,
		}, "oro", "LEGEND", 15)
		Stile.icona("star", {
			Position = UDim2.fromOffset(160, 118),
			Size = UDim2.fromOffset(30, 30),
			ZIndex = 4,
			Parent = corpo,
		})
	end

	-- Nome sulla fascia scura.
	local nome = etichetta(corpo, 12, 163, 176, 28, string.upper(def.nome), 17, Stile.BIANCO)
	nome.TextScaled = true
	Stile.crea("UITextSizeConstraint", { MaxTextSize = 17, Parent = nome })

	-- Statistiche su due colonne: ATK SPD DEF | HP RNG MEN.
	local righe = { { "ATK", "HP" }, { "SPD", "RNG" }, { "DEF", "MEN" } }
	for r, coppia in ipairs(righe) do
		local y = 216 + (r - 1) * 21
		for c, chiave in ipairs(coppia) do
			local x = 30 + (c - 1) * 84
			local valore = chiave == "MEN" and (def.soldati or 1) + (def.guardia and def.guardia.numero or 0) or v[chiave]
			local numero = etichetta(
				corpo,
				x - 34,
				y - 18,
				60,
				22,
				tostring(valore),
				19,
				colore,
				Enum.TextXAlignment.Right,
				Stile.FontTitolo
			)
			if leggenda then
				Stile.crea("UIStroke", { Color = Stile.CONTORNO, Thickness = 2, Parent = numero })
			end
			local chiaveEtichetta = etichetta(corpo, x + 31, y - 15, 44, 16, chiave, 13, colore, Enum.TextXAlignment.Left)
			chiaveEtichetta.TextTransparency = 0.15
		end
	end
	if not Icone.immagine("card_" .. rarita) then
		Stile.crea("Frame", {
			Position = UDim2.fromOffset(99, 202),
			Size = UDim2.fromOffset(2, 56),
			BackgroundColor3 = colore,
			BackgroundTransparency = 0.65,
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = corpo,
		})
	end

	if opzioni.quantita then
		local bollino = Stile.crea("Frame", {
			Name = "Quantita",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(190, 8),
			Size = UDim2.fromOffset(58, 44),
			BackgroundColor3 = Stile.BIANCO,
			ZIndex = 8,
			Parent = corpo,
		}, { Stile.tondo(), Stile.bordo(Stile.CONTORNO, 4), Stile.sfumatura(Stile.PAL.rosso.t, Stile.PAL.rosso.b) })
		scritta(bollino, 0, 0, 58, 44, "x" .. opzioni.quantita, 26, 3, 9)
	end

	if opzioni.nota then
		carta:SetAttribute("Nota", opzioni.nota)
	end
	Carta.spegni(carta, opzioni.spenta or opzioni.nota ~= nil, opzioni.nota)
	return carta
end

-- Velo scuro sulla carta (bloccata, già schierata...). testo: scritta sul velo.
-- Con la nota di una carta bloccata si vede anche il lucchetto.
function Carta.spegni(carta, spenta, testo)
	local corpo = carta:FindFirstChild("Corpo")
	if not corpo then
		return
	end
	local velo = corpo:FindFirstChild("Velo")
	if velo then
		velo:Destroy()
	end
	if not spenta then
		return
	end
	local immagine = Icone.immagine("card_veil")
	if immagine then
		velo = Stile.crea("ImageLabel", {
			Name = "Velo",
			Position = UDim2.fromOffset(-8, -8),
			Size = UDim2.fromOffset(L + 16, A + 16),
			Image = immagine,
			ImageTransparency = 0.38,
			BackgroundTransparency = 1,
			ZIndex = 10,
			Parent = corpo,
		})
	else
		velo = Stile.crea("Frame", {
			Name = "Velo",
			Size = UDim2.fromOffset(L, A - 16),
			BackgroundColor3 = Stile.CONTORNO,
			BackgroundTransparency = 0.38,
			ZIndex = 10,
			Parent = corpo,
		}, { Stile.angoli(18) })
	end
	local o = immagine and 8 or 0 -- l'immagine del velo sporge di 8 px su ogni lato
	local bloccata = testo ~= nil and testo == carta:GetAttribute("Nota")
	if bloccata then
		Stile.icona("lock", {
			Position = UDim2.fromOffset(58 + o, 22 + o),
			Size = UDim2.fromOffset(84, 84),
			ZIndex = 11,
			Parent = velo,
		})
		local t = scritta(velo, 6 + o, 120 + o, L - 12, 26, testo, 19, 4, 11)
		t.TextScaled = true
		Stile.crea("UITextSizeConstraint", { MaxTextSize = 19, Parent = t })
	elseif testo then
		local t = scritta(velo, 6 + o, 78 + o, L - 12, 34, testo, 26, 4, 11)
		t.TextScaled = true
		Stile.crea("UITextSizeConstraint", { MaxTextSize = 26, Parent = t })
	end
end

-- Evidenzia la carta selezionata con un alone dorato.
function Carta.seleziona(carta, selezionata)
	local corpo = carta:FindFirstChild("Corpo")
	if not corpo then
		return
	end
	local alone = corpo:FindFirstChild("Alone")
	if selezionata and not alone then
		local immagine = Icone.immagine("card_glow")
		if immagine then
			Stile.crea("ImageLabel", {
				Name = "Alone",
				Position = UDim2.fromOffset(-30, -30),
				Size = UDim2.fromOffset(L + 60, A + 60),
				Image = immagine,
				BackgroundTransparency = 1,
				ZIndex = 0,
				Parent = corpo,
			})
		else
			Stile.crea("Frame", {
				Name = "Alone",
				Position = UDim2.fromOffset(-10, -10),
				Size = UDim2.fromOffset(L + 20, A + 4),
				BackgroundColor3 = Stile.Colori.Oro,
				BackgroundTransparency = 0.2,
				ZIndex = 0,
				Parent = corpo,
			}, { Stile.angoli(24), Stile.bordo(Stile.BIANCO, 4) })
		end
		carta.Rotation = 0
	elseif not selezionata and alone then
		alone:Destroy()
	end
end

-- Carta piccola (barra del mazzo, nemici): la stessa carta, con il numero dello slot se serve.
function Carta.mini(tipo, numero)
	local carta = Carta.crea(tipo)
	carta.Name = "Mini_" .. tipo
	if numero then
		carta:SetAttribute("Slot", numero)
	end
	return carta
end

return Carta
