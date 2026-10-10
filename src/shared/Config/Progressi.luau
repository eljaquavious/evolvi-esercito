-- Livello del giocatore ed esperienza: ogni livello chiede un po' più di esperienza del precedente.

local Progressi = {}

Progressi.XP_ROUND_VINTO = 10
Progressi.XP_ROUND_PERSO = 4
Progressi.XP_LIVELLO_VINTO = 30

function Progressi.perLivello(livello)
	return 100 + 25 * (livello - 1)
end

-- Restituisce livello, esperienza dentro il livello, esperienza necessaria per il prossimo.
function Progressi.livello(esperienza)
	local livello = 1
	local resto = esperienza
	while resto >= Progressi.perLivello(livello) do
		resto -= Progressi.perLivello(livello)
		livello += 1
	end
	return livello, resto, Progressi.perLivello(livello)
end

return Progressi
