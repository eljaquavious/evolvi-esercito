-- Nomi degli eventi tra server e client. Il server li crea in ReplicatedStorage.Remoti.

return {
	Eventi = {
		"Stato", -- server -> client: monete, livello, epoca
		"Notifica", -- server -> client: messaggio breve
		"ApriShop", -- server -> client
		"ApriEsercito", -- server -> client: il tavolo ARMY della lobby apre il mazzo
		"Fase", -- server -> client: lobby, mappa, piazzamento, battaglia, round, risultato
		"Truppe", -- server -> client: soldati da disegnare (schieramento, inizio, passo, fine, pulisci)
	},
	Funzioni = {
		"ChiediStato",
		"ApriMappa",
		"AvviaCampagna", -- numero del livello
		"Casella", -- piazza o rimuove una truppa
		"Combatti",
		"Ordine", -- in battaglia: un tuo reggimento attacca un reggimento nemico
		"Abilita", -- in battaglia: attiva l'abilità di un tuo comandante
		"VinciRound", -- modalità prova (solo in Studio): il round in corso è vinto subito
		"TornaLobby",
		"AcquistaCassa",
		"Ranked",
		"SalvaMazzo",
	},
}
