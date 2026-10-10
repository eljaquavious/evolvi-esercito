-- Genera i campi di battaglia fuori da Studio (Arena + Scenari + Paesaggio) con un Terrain finto, per
-- trovare errori e per l'anteprima: per ogni livello scrive un JSON con il rilievo, i materiali e le parti.
-- Si lancia con: lune run test/campi [cartella di uscita] [livello]
-- L'anteprima si disegna con: python3 tools/anteprima_campi.py <cartella>
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")

local uscita = process.args[1] or "/tmp/campi"
local soloLivello = tonumber(process.args[2] or "")
if not fs.isDir(uscita) then
	fs.writeDir(uscita)
end

local Vector3, Enum = roblox.Vector3, roblox.Enum
-- Il CFrame.lookAt di Lune 0.8 restituisce la rotazione trasposta: lo si rifà come in Roblox.
local CFrame = setmetatable({
	lookAt = function(da, verso, alto)
		local avanti = (verso - da).Unit
		local destra = avanti:Cross(alto or Vector3.yAxis).Unit
		return roblox.CFrame.fromMatrix(da, destra, destra:Cross(avanti), -avanti)
	end,
}, { __index = roblox.CFrame })

-- Generatore deterministico al posto di Random.
local Random = {
	new = function(seme)
		local stato = math.floor(seme or 1) % 2147483647
		if stato <= 0 then
			stato += 2147483646
		end
		local r = {}
		local function avanti()
			stato = (stato * 48271) % 2147483647
			return stato / 2147483647
		end
		function r:NextNumber(a, b)
			a, b = a or 0, b or 1
			return a + (b - a) * avanti()
		end
		function r:NextInteger(a, b)
			return math.min(b, a + math.floor((b - a + 1) * avanti()))
		end
		return r
	end,
}

-- Terrain finto: una griglia di colonne (passo 2 studs) con quota del suolo, materiale e pelo dell'acqua.
local PASSO = 2
local terreno -- { x0, z0, n, suolo = {}, mat = {}, acqua = {} }
local function nuovoTerreno(centro, lato)
	local n = lato / PASSO
	terreno = { x0 = centro.X - lato / 2, z0 = centro.Z - lato / 2, n = n, suolo = {}, mat = {}, acqua = {} }
end
local function indice(x, z)
	local i = math.floor((x - terreno.x0) / PASSO)
	local k = math.floor((z - terreno.z0) / PASSO)
	if i < 0 or k < 0 or i >= terreno.n or k >= terreno.n then
		return nil
	end
	return i * terreno.n + k
end
local Terrain = {}
function Terrain:WriteVoxels(regione, voxel, materiali, occupazione)
	local minimo = regione.CFrame.Position - regione.Size / 2
	for i, piano in ipairs(materiali) do
		for k = 1, #piano[1] do
			local suolo, mat, acqua = minimo.Y, "Air", nil
			for j = 1, #piano do
				local m, o = materiali[i][j][k], occupazione[i][j][k]
				local y0 = minimo.Y + (j - 1) * voxel
				if m == Enum.Material.Water then
					acqua = y0 + o * voxel
				elseif m ~= Enum.Material.Air and o > 0 then
					suolo, mat = y0 + o * voxel, m.Name
				end
			end
			local x = minimo.X + (i - 0.5) * voxel
			local z = minimo.Z + (k - 0.5) * voxel
			for di = -0.5, 0.5 do
				for dk = -0.5, 0.5 do
					local id = indice(x + di * PASSO, z + dk * PASSO)
					if id then
						terreno.suolo[id], terreno.mat[id], terreno.acqua[id] = suolo, mat, acqua
					end
				end
			end
		end
	end
end
local function scava(dentro, fondo, materiale)
	for id, suolo in pairs(terreno.suolo) do
		local i, k = id // terreno.n, id % terreno.n
		local x, z = terreno.x0 + (i + 0.5) * PASSO, terreno.z0 + (k + 0.5) * PASSO
		if dentro(x, z) then
			local f = fondo(x, z)
			if f and f < suolo then
				terreno.suolo[id] = f
				terreno.mat[id] = materiale or terreno.mat[id]
			end
		end
	end
end
function Terrain:FillBall(centro, raggio, materiale)
	if materiale ~= Enum.Material.Air then
		return
	end
	scava(function(x, z)
		return (x - centro.X) ^ 2 + (z - centro.Z) ^ 2 < raggio * raggio
	end, function(x, z)
		return centro.Y - math.sqrt(math.max(0, raggio * raggio - (x - centro.X) ^ 2 - (z - centro.Z) ^ 2))
	end, "Mud")
end
function Terrain:FillBlock(cf, size, materiale)
	if materiale ~= Enum.Material.Air or size.X > 400 then
		return
	end
	scava(function(x, z)
		local p = cf:PointToObjectSpace(Vector3.new(x, cf.Position.Y, z))
		return math.abs(p.X) < size.X / 2 and math.abs(p.Z) < size.Z / 2
	end, function()
		return cf.Position.Y - size.Y / 2
	end, "Mud")
end
local function quotaTerreno(x, z)
	local id = indice(x, z)
	return id and terreno.suolo[id]
end

local avvisi = {}
local ambienteBase = {
	Vector3 = Vector3,
	Vector2 = roblox.Vector2,
	CFrame = CFrame,
	Color3 = roblox.Color3,
	Enum = Enum,
	Instance = roblox.Instance,
	Region3 = roblox.Region3,
	Random = Random,
	RaycastParams = { new = function() return {} end },
	task = { wait = function() end },
	warn = function(...)
		table.insert(avvisi, table.concat({ ... }, " "))
	end,
	__terrain = Terrain,
	__raycast = function(origine, direzione)
		local y = quotaTerreno(origine.X, origine.Z)
		return y and { Position = Vector3.new(origine.X, y, origine.Z) }
	end,
}
local spazio = roblox.Instance.new("Folder")
ambienteBase.workspace = spazio

local moduli = {}
local function cartella(percorso)
	local figli = {}
	for _, nome in ipairs(fs.readDir(percorso)) do
		local pieno = percorso .. "/" .. nome
		if fs.isDir(pieno) then
			figli[nome] = cartella(pieno)
		elseif nome:match("%.luau$") then
			figli[nome:gsub("%.luau$", "")] = { __modulo = pieno }
		end
	end
	return figli
end
local alberi = { server = cartella("src/server"), shared = cartella("src/shared") }
local ReplicatedStorage = { Shared = alberi.shared }

local function carica(percorso, genitore)
	if moduli[percorso] then
		return moduli[percorso]
	end
	local sorgente = fs.readFile(percorso)
	sorgente = sorgente:gsub("workspace%.Terrain", "__terrain"):gsub("workspace:Raycast%(", "__raycast(")
	local env = table.clone(ambienteBase)
	env.script = { Parent = genitore }
	env.game = { GetService = function(_, nome)
		return nome == "ReplicatedStorage" and ReplicatedStorage or {}
	end }
	env.require = function(m)
		if type(m) == "table" and m.__modulo then
			local dir = m.__modulo:match("^(.*)/[^/]+$")
			local padre = dir == "src/server" and alberi.server or (dir == "src/shared/Config" and alberi.shared.Config or alberi.shared)
			return carica(m.__modulo, padre)
		end
		error("require non gestito: " .. tostring(m))
	end
	local f = luau.load(sorgente, { debugName = percorso, environment = env })
	moduli[percorso] = f()
	return moduli[percorso]
end

local Campagna = carica("src/shared/Config/Campagna.luau", alberi.shared.Config)
local Arena = carica("src/server/Arena.luau", alberi.server)

local function tondo(v)
	return math.floor(v * 100 + 0.5) / 100
end

local riepilogo = {}
for numero = 1, Campagna.TOTALE do
	if soloLivello and numero ~= soloLivello then
		continue
	end
	local livello = Campagna.livello(numero)
	avvisi = {}
	-- Il campo nello slot 1: origine (4200, 0, 0), lato 640.
	nuovoTerreno(Vector3.new(4200, 0, 0), 640)
	local inizio = os.clock()
	local ok, arena = pcall(Arena.crea, { UserId = numero }, livello)
	local tempo = os.clock() - inizio
	if not ok then
		print(("%2d %-16s ERRORE %s"):format(numero, livello.nome, tostring(arena)))
		continue
	end
	local parti = {}
	local conteggio = 0
	for _, p in ipairs(arena.modello:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 1 and not p:FindFirstAncestor("Tabellone") then
			conteggio += 1
			local c = { p.CFrame:GetComponents() }
			for i, v in ipairs(c) do
				c[i] = tondo(v)
			end
			local forma = p.ClassName == "WedgePart" and "Wedge" or p.Shape.Name
			if p:FindFirstChildOfClass("SpecialMesh") then
				forma = "Sphere"
			end
			table.insert(parti, {
				f = forma,
				s = { tondo(p.Size.X), tondo(p.Size.Y), tondo(p.Size.Z) },
				c = c,
				k = { math.floor(p.Color.R * 255 + 0.5), math.floor(p.Color.G * 255 + 0.5), math.floor(p.Color.B * 255 + 0.5) },
				m = p.Material.Name,
				t = tondo(p.Transparency),
			})
		end
	end
	local suolo, mat, acqua = {}, {}, {}
	local nomiMat, idMat = {}, {}
	for id = 0, terreno.n * terreno.n - 1 do
		suolo[id + 1] = tondo(terreno.suolo[id] or 0)
		local m = terreno.mat[id] or "Air"
		if not idMat[m] then
			table.insert(nomiMat, m)
			idMat[m] = #nomiMat
		end
		mat[id + 1] = idMat[m]
		acqua[id + 1] = terreno.acqua[id] and tondo(terreno.acqua[id]) or false
	end
	local caselle = {}
	for _, t in ipairs(livello.terreno) do
		table.insert(caselle, { t.col, t.riga, t.tipo })
	end
	fs.writeFile(("%s/%02d.json"):format(uscita, numero), serde.encode("json", {
		nome = livello.nome,
		bioma = livello.bioma,
		epoca = livello.epoca.id,
		origine = { arena.origine.X, arena.origine.Y, arena.origine.Z },
		terreno = { x0 = terreno.x0, z0 = terreno.z0, n = terreno.n, passo = PASSO, suolo = suolo, mat = mat, nomi = nomiMat, acqua = acqua },
		parti = parti,
		caselle = caselle,
	}))
	print(("%2d %-16s %5d parti  %.2fs  avvisi %d"):format(numero, livello.nome, conteggio, tempo, #avvisi))
	for i = 1, math.min(#avvisi, 5) do
		print("     " .. avvisi[i])
	end
	Arena.distruggi(arena)
	table.insert(riepilogo, conteggio)
end
