-- Esporta le sceneggiature delle cinematiche (src/client/CinematicheDati.luau) in JSON, per controllarle
-- fuori da Studio con tools/controlla_cinematiche.py (soldati in acqua, telecamera nel terreno, oggetti
-- sulla strada). Si lancia con: lune run test/cinematiche [file di uscita]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")

local uscita = process.args[1] or "/tmp/cinematiche.json"
local sorgente = fs.readFile("src/client/CinematicheDati.luau")
local Color3 = { fromRGB = function(r, g, b)
	return { r, g, b }
end }
local Dati = luau.load(sorgente, { debugName = "CinematicheDati", environment = { Color3 = Color3 } })()
fs.writeFile(uscita, serde.encode("json", Dati))
print("scritto " .. uscita)
