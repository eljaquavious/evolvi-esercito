-- Nomi degli eventi tra server e client. Il server li crea in ReplicatedStorage.Remoti.

return {
	Eventi = {
		"Stato", -- server -> client: monete, livello, epoca
		"Notifica", -- server -> client: messaggio breve
		"ApriShop", -- server -> client
		"ApriEsercito", -- server -> client: il tavolo ARMY della lobby apre il mazzo
		"Fase", -- server -> client: lobby, mappa, piazzamento, battaglia, round, risultato
		"Truppe", -- server -> client: soldati da disegnare (schieramento, inizio, passo, fine, pulisci)
		"Sblocco", -- server -> client: titoli e cosmetici appena ottenuti { { tipo, id } }
	},
	Funzioni = {
		"ChiediStato",
		"ApriMappa",
		"AvviaCampagna", -- numero del livello
		"Schiera", -- carte scelte (indici del mazzo) e formazione: i reggimenti prendono posto
		"Combatti",
		"Ordine", -- in battaglia: ordine generale a tutta la tua armata (avanza, tieni, ripiega, fianchi, carica)
		"Abilita", -- in battaglia: attiva l'abilità di un tuo comandante
		"VinciRound", -- modalità prova (solo in Studio): il round in corso è vinto subito
		"TornaLobby",
		"AcquistaCassa",
		"Ranked",
		"SalvaMazzo",
		"Equipaggia", -- tipo ("titolo"/"cosmetico"), id (nil = togli), slot
		"AcquistaOggetto", -- tipo, id: titolo o cosmetico con monete o Robux
		"RiscattaCodice", -- testo del codice
	},
}
