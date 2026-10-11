-- Nomi degli eventi tra server e client. Il server li crea in ReplicatedStorage.Remoti.

return {
	Eventi = {
		"Stato", -- server -> client: monete, livello, epoca
		"Notifica", -- server -> client: messaggio breve
		"ApriShop", -- server -> client
		"Fase", -- server -> client: lobby, mappa, piazzamento, battaglia, round, risultato
		"Truppe", -- server -> client: soldati da disegnare (schieramento, inizio, passo, fine, pulisci)
	},
	Funzioni = {
		"ChiediStato",
		"ApriMappa",
		"AvviaCampagna", -- numero del livello
		"Casella", -- piazza o rimuove una truppa
		"Combatti",
		"VinciRound", -- modalità prova (solo in Studio): il round in corso è vinto subito
		"TornaLobby",
		"AcquistaCassa",
		"Ranked",
		"SalvaMazzo",
	},
}
