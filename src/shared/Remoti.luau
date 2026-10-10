-- Nomi degli eventi tra server e client. Il server li crea in ReplicatedStorage.Remoti.

return {
	Eventi = {
		"Stato", -- server -> client: monete, livello, epoca
		"Notifica", -- server -> client: messaggio breve
		"ApriShop", -- server -> client
		"Fase", -- server -> client: lobby, piazzamento, battaglia, risultato
	},
	Funzioni = {
		"ChiediStato",
		"AvviaCampagna",
		"Casella", -- piazza o rimuove una truppa
		"Combatti",
		"TornaLobby",
		"AcquistaCassa",
		"Ranked",
		"SalvaMazzo",
	},
}
