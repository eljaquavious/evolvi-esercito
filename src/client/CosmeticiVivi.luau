-- Cosmetici animati e multicolori (Mattia, 10/11/2026), tutto lato client. Shared/Cosmetici3D mette il tag
-- "CosmeticoVivo" sulle parti che cambiano colore (e sul blocco delle aure), con gli attributi:
--   VivoTipo    "ciclo" (da un colore all'altro in giro) o "pulsa" (avanti e indietro tra i colori)
--   VivoColori  esadecimali separati da virgola
--   VivoPeriodo secondi di un giro
--   VivoFase    quanto questa parte è avanti nel giro (0-1): parti vicine hanno colori diversi
-- Qui si cambiano il colore della parte, della sua superficie, della sua luce e delle sue particelle.
-- Vale per i cosmetici addosso ai giocatori e per le anteprime nelle finestre (stesso tag).

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Impostazioni = require(script.Parent.UI.Impostazioni)

local CosmeticiVivi = {}

local TAG = "CosmeticoVivo"
local PASSO = 1 / 15 -- secondi tra un aggiornamento e l'altro
local DISTANZA = 150 -- oltre questa distanza dalla telecamera i cosmetici nel mondo restano fermi

local vivi = {} -- oggetto -> { tipo, colori, periodo, fase, figli }

local function registra(oggetto)
	if not oggetto:IsA("BasePart") then
		return
	end
	local colori = {}
	for h in string.gmatch(oggetto:GetAttribute("VivoColori") or "", "[^,]+") do
		local ok, c = pcall(Color3.fromHex, h)
		if ok then
			table.insert(colori, c)
		end
	end
	if #colori < 2 then
		return
	end
	vivi[oggetto] = {
		tipo = oggetto:GetAttribute("VivoTipo") or "ciclo",
		colori = colori,
		periodo = math.max(0.2, oggetto:GetAttribute("VivoPeriodo") or 3),
		fase = oggetto:GetAttribute("VivoFase") or 0,
		nelMondo = oggetto:IsDescendantOf(workspace),
	}
end

local function colore(v, t)
	local n = #v.colori
	local x = (t / v.periodo + v.fase) % 1
	if v.tipo == "pulsa" then
		-- Avanti e indietro lungo la fila dei colori.
		local p = (0.5 - 0.5 * math.cos(x * math.pi * 2)) * (n - 1)
		local i = math.min(math.floor(p), n - 2)
		return v.colori[i + 1]:Lerp(v.colori[i + 2], p - i)
	end
	local p = x * n
	local i = math.floor(p)
	return v.colori[i % n + 1]:Lerp(v.colori[(i + 1) % n + 1], p - i)
end

local function aggiorna(oggetto, v, t)
	local c = colore(v, t)
	if oggetto.Transparency < 1 then
		oggetto.Color = c
	end
	local dopo -- per le particelle: nascono di un colore e finiscono in quello che viene dopo
	for _, figlio in ipairs(oggetto:GetDescendants()) do
		if figlio:IsA("SurfaceAppearance") then
			figlio.Color = c
		elseif figlio:IsA("Light") then
			figlio.Color = c
		elseif figlio:IsA("BasePart") then
			if figlio.Material == Enum.Material.Neon then
				figlio.Color = c -- le sfere delle aure
			end
		elseif figlio:IsA("Highlight") then
			figlio.OutlineColor = c
		elseif figlio:IsA("ParticleEmitter") and not figlio:GetAttribute("VivoNo") then
			dopo = dopo or colore(v, t + v.periodo * 0.3)
			figlio.Color = ColorSequence.new(c, dopo)
		end
	end
end

function CosmeticiVivi.inizializza()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(registra)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(oggetto)
		vivi[oggetto] = nil
	end)
	for _, oggetto in ipairs(CollectionService:GetTagged(TAG)) do
		registra(oggetto)
	end
	local attesa = 0
	RunService.Heartbeat:Connect(function(dt)
		attesa += dt
		if attesa < PASSO then
			return
		end
		attesa = 0
		local camera = workspace.CurrentCamera
		local occhio = camera and camera.CFrame.Position
		local leggero = Impostazioni.prestazioni()
		local t = os.clock()
		for oggetto, v in pairs(vivi) do
			if not oggetto:IsDescendantOf(game) then
				vivi[oggetto] = nil
			elseif v.nelMondo then
				-- Addosso ai giocatori: fermi in modalità prestazioni e da lontano.
				if not leggero and occhio and (oggetto.Position - occhio).Magnitude < DISTANZA then
					aggiorna(oggetto, v, t)
				end
			else
				aggiorna(oggetto, v, t) -- anteprime nelle finestre
			end
		end
	end)
end

return CosmeticiVivi
