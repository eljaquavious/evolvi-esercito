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
		"CassaAperta", -- server -> client: cosa è uscito da una cassa o pacchetto { tipo, id, nuova, quante, cassa }
	},
	Funzioni = {
		"ChiediStato",
		"ApriMappa",
		"AvviaCampagna", -- numero del livello
		"Schiera", -- carte scelte (indici del mazzo) e formazione: i reggimenti prendono posto
		"Combatti",
		"Ordine", -- in battaglia: ordine generale a tutta la tua armata (avanza, tieni, ripiega, fianchi, carica)
		"Abilita", -- in battaglia: attiva l'abilità di un tuo comandante
		"Bersaglio", -- in battaglia: bersaglio (classe, "Comandante", id di un reggimento nemico o nil) e reggimento tuo (nil = tutti)
		"VinciRound", -- modalità prova (solo in Studio): il round in corso è vinto subito
		"TornaLobby",
		"AcquistaCassa", -- id di una cassa o di un pacchetto di monete (Config/Casse)
		"InviaFeedback", -- testo del feedback (finestra Codes)
		"LeggiFeedback", -- solo il proprietario del gioco: ultimi feedback
		"SonoAdmin", -- il giocatore può leggere i feedback?
		"Ranked",
		"SalvaMazzo",
		"Equipaggia", -- tipo ("titolo"/"cosmetico"), id (nil = togli), slot
		"AcquistaOggetto", -- tipo, id: titolo o cosmetico con monete o Robux
		"RiscattaCodice", -- testo del codice
		"Preferito", -- il client avvisa che il gioco è nei Preferiti di Roblox: titolo e aura in regalo
		"Impostazioni", -- chiave (musica, effetti, prestazioni), valore (true/false): menu Settings
	},
}
