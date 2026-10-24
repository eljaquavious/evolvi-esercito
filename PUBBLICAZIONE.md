# Pubblicazione di Evolve Your Army

Lista dei passi per pubblicare il gioco (24/10/2026). [M] = lo fa Mattia, [C] = lo fa Claude.
I nomi dei menu sono quelli di Roblox Studio e del Creator Dashboard (create.roblox.com).

## Fase 1 — Pubblicare il place (privato), circa 15 minuti
1. [M] Studio: File > Save (o chiedere a Claude "salva").
2. [M] Studio: File > Publish to Roblox (Alt+P) > "Create new experience".
   - Name: Evolve Your Army
   - Description: quella della fase 5 (si può cambiare dopo).
   - Creator: il tuo account (o il gruppo, se vuoi che sia del gruppo).
   - Genre: Strategy.
   - Devices: Computer, Phone, Tablet, Console (VR no).
3. [M] Studio: Home > Game Settings > Security: accendi "Enable Studio Access to API Services".
   Serve per provare in Studio salvataggi, feedback e classifiche.
4. [M] Game Settings > Places (o Options): giocatori massimi per server = 8.
   La ranked cerca avversari solo nello stesso server, ma ogni battaglia della campagna costruisce un campo
   intero: con 8 si trova un avversario senza pesare troppo sul server.
5. [M] Game Settings > Permissions: per ora lascia Private (si apre a tutti nella fase 6).

## Fase 2 — Prodotti in Robux, circa 30 minuti
6. [M] Creator Dashboard > il gioco > Monetization > Developer Products > Create: i 16 prodotti qui sotto
   (nome, prezzo; icona facoltativa, la prepara Claude se la vuoi).
7. [M] Copia l'id di ogni prodotto e mandalo a Claude (anche tutti insieme in un messaggio).
8. [C] Mette gli id in Config/Casse e Config/Ricompense, ricarica il codice in Studio, prova un acquisto
   (in Studio gli acquisti sono finti, non costano Robux) e salva.
9. [M] File > Publish to Roblox (ogni volta che il codice cambia va ripubblicato).

| # | Nome del prodotto | Robux | Dove sta nel codice |
|---|---|---|---|
| 1 | Big Crate | 99 | Config/Casse, CassaGrande |
| 2 | Medium Armory Crate | 89 | Config/Casse, ArmeriaMedia |
| 3 | Big Armory Crate | 149 | Config/Casse, ArmeriaGrande |
| 4 | 1,000 Coins | 80 | Config/Casse, Monete1 |
| 5 | 2,500 Coins | 169 | Config/Casse, Monete2 |
| 6 | 6,000 Coins | 369 | Config/Casse, Monete3 |
| 7 | 10,000 Coins | 599 | Config/Casse, Monete4 |
| 8 | 15,000 Coins | 799 | Config/Casse, Monete5 |
| 9 | 40,000 Coins | 1799 | Config/Casse, Monete6 |
| 10 | Title: The Magnificent | 99 | Config/Ricompense, Magnifico |
| 11 | Title: Warmonger | 89 | Config/Ricompense, Guerrafondaio |
| 12 | Title: The Unbreakable | 149 | Config/Ricompense, Indistruttibile |
| 13 | Title: Lord of War | 249 | Config/Ricompense, SignoreGuerra |
| 14 | Golden Cuirass | 149 | Config/Ricompense, CorazzaOro |
| 15 | Imperial Eagle | 99 | Config/Ricompense, Aquila |
| 16 | Royal Aura | 149 | Config/Ricompense, AuraReale |

## Fase 3 — Questionario e regole, circa 15 minuti
10. [M] Creator Dashboard > il gioco > Audience (o Configure) > Maturity & Compliance Questionnaire.
    Risposte probabili: violenza leggera senza sangue (soldati a blocchi che combattono), niente linguaggio
    volgare, chat di Roblox normale, "paid random items" = sì (le casse a pagamento).
    Le probabilità delle casse sono già mostrate nello shop, come chiede Roblox.
11. [M] Se Roblox lo chiede per rendere pubblico un gioco: email verificata e verifica a due passaggi
    sull'account.

## Fase 4 — Prove sul gioco pubblicato, circa 30 minuti
12. [M+C] Studio > Test > Clients and Servers, 2 giocatori: una ranked vera tra due giocatori.
13. [M] Gioca dal sito (privato): fai un livello, esci, rientra. I progressi devono restare.
14. [M] Manda un feedback, poi apri Codes > INBOX: deve comparire.
15. [M] Dopo una ranked: la classifica (Ranked > LEADERBOARD) deve mostrarti.
16. [M] Prova sul telefono (app Roblox): PLAY, FIGHT!, ordini, shop.

## Fase 5 — Pagina del gioco: testi e immagini (le facciamo insieme)
17. [C] Descrizione in inglese (e titolo breve per la ricerca).
18. [C+M] Icona 512x512: Claude la prepara (render da Studio + grafica).
19. [C+M] Miniature 1920x1080 (fino a 10): Claude le prepara da Studio (battaglie, lobby, shop, carte).
20. [M] Trailer (facoltativo, fino a 30 secondi): Claude scrive il copione delle scene, Mattia registra con
    il registratore di Roblox (Esc > Record) o con OBS. Si carica come video nelle miniature.
21. [C] Crediti dei modelli CC0 (assets-foto/crediti.txt) nella descrizione o in un cartello nella lobby.

## Fase 6 — Apertura
22. [M] Game Settings > Permissions: Public. Salva e ripubblica.
23. [C] Codici per il lancio in src/server/ListaCodici.luau (ci sono WELCOME e FOUNDER).
24. [M] Condividi il link. I feedback arrivano in Codes > INBOX.
