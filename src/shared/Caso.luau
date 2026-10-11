-- Numeri a caso ripetibili, con la stessa interfaccia di Random (NextNumber, NextInteger). A differenza di
-- Random dà gli stessi numeri anche fuori da Roblox (test/oggetti.luau con Lune): così un oggetto del
-- paesaggio costruito nel gioco con un seme è identico a quello da cui tools/paesaggio ha fatto il modello 3D.

local Caso = {}
Caso.__index = Caso

function Caso.new(seme)
	local stato = math.floor(seme or 1) % 2147483647
	if stato <= 0 then
		stato += 2147483646
	end
	return setmetatable({ stato = stato }, Caso)
end

local function avanti(self)
	self.stato = (self.stato * 48271) % 2147483647
	return self.stato / 2147483647
end

function Caso:NextNumber(a, b)
	a, b = a or 0, b or 1
	return a + (b - a) * avanti(self)
end

function Caso:NextInteger(a, b)
	return math.min(b, a + math.floor((b - a + 1) * avanti(self)))
end

return Caso
