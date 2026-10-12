-- Codici per la community. Sta sul server, così i giocatori non possono leggerli dal client.
--
-- Per aggiungere un codice copia una riga e cambia:
--   codice  = la parola da scrivere (maiuscole e minuscole non contano, niente spazi)
--   monete  = monete regalate (facoltativo)
--   titolo  = id di un titolo in Shared/Config/Ricompense.luau (facoltativo)
--   cosmetico = id di un cosmetico in Shared/Config/Ricompense.luau (facoltativo)
--   scade   = data di scadenza "AAAA-MM-GG" (facoltativo: senza, il codice vale per sempre)
-- Ogni giocatore può usare ogni codice una volta sola.

return {
	{ codice = "WELCOME", monete = 250 },
	{ codice = "FOUNDER", monete = 500, titolo = "Fondatore", scade = "2027-03-31" },
}
