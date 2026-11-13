# Controllo - Engagement durante la battaglia (Controllo, 13/11/2026)

Niente commit, niente push, niente Publish, place non salvato. Studio ripristinato (SimSchermo/SimTouch tolti, Play fermato).

## Errori trovati e sistemati

| # | Chi | File:riga | Cosa era sbagliato | Come sistemato | Ricollaudato | Lezione |
|---|---|---|---|---|---|---|
| 1 | Costruttore | src/shared/Battaglia.luau:1336-1350 (`passo`) | La barra CHARGE si fermava solo finché l'ORDINE dell'ala era "carica". Dopo 3 s (ATTESA_ORDINE) il giocatore poteva dare HOLD/ADVANCE: il bonus della carica (self.effetti, 6 s) restava, ma la barra ripartiva prima. Era contro la spec ("non si riempie mentre la carica è in corso") e dava un vantaggio sul bot ranked, che non lo fa | L'effetto della carica ora ha `carica = true` (riga 554). In `passo` la barra resta ferma anche finché c'è un effetto di carica della squadra non ancora finito. Il controllo sull'ordine dell'ala resta com'era | Sì, in Studio: 11 verifiche della barra OK, comprese le 2 nuove. Il test intero prima della correzione: 47 OK | Una regola "mentre X è in corso" va legata a quando X finisce davvero (l'effetto), non all'ordine visibile: gli ordini si possono cambiare dopo 3 s |
| 2 | Costruttore | test/battaglia.luau:349-355 | Il test non provava il caso "carica e poi un altro ordine" | Aggiunte 2 verifiche: HOLD dopo 3,5 s accettato, barra ancora a 0 | Sì (vedi sopra) | Per ogni regola nuova, provare nel test anche il modo di aggirarla |
| 3 | Costruttore | src/shared/Battaglia.luau:1247 (`_ferisci`) | Nella riga esistente `table.insert(eventi, {` è stato tolto lo spazio dopo la virgola: modifica non richiesta a codice esistente | Spazio rimesso | Sì (test intero 47 OK) | Non toccare le righe vicine a quella che si cambia |

## Controllato e giusto (letto nel codice e/o provato in Studio)
- Server autorevole: `Battaglia:ordine` rifiuta la carica a barra vuota prima di tutto il resto, per il giocatore (campagna e ranked) e per il bot (automatico). In Play: seconda carica subito dopo = "Your troops are catching their breath: the charge is refilling."
- Statistiche: `Ordine carica` registrato solo per le cariche accettate (2 nel round 1 del L1), PERFECT CHARGE vista dal server.
- Ranked: barra della SUA squadra a ogni giocatore, bot che carica con la stessa barra, `r.ala` mandato al client (bug vecchio, giusto anche per il lato scambiato).
- Pulsante, barra YOU/ENEMY, timer e "+N%": nascosti in mostraRound, mostraRisultato (anche nel ramo senza campo), esci e fine ranked; nascosti a fine round e a fine livello in Play. Una sola connessione RenderStepped, i task di "+N%" e del timer finiscono da soli.
- Tutorial L1: passi 6 SOUND THE CHARGE -> 7 CHARGE AGAIN (REFILLING... e poi TAP!) -> 8 SEND THE RESERVE -> ROUND OVER, barra Orders nascosta, suggerimento corto. Partita compila (sotto i 200 locali).
- L2 prima volta: NEW! ORDERS (1/2) e barra Orders. L2 rigiocato (= tutti i livelli dopo): barra Orders visibile, nessun tutorial. Tasti 5/Y, QUADRATO/CERCHIO/CROCE e L2/R2 non toccati.
- Telefono 844x390 e tablet 1024x768 (touch simulato): pulsante, NOW!, vassoio, barra Orders, barra e timer non si sovrappongono. Testi del gioco in inglese. Commenti esistenti non cancellati.
- Console: nessun errore nuovo (solo EditableMesh, DataStore in Studio, asset 203785492 già noti).

## Verdetto: APPROVATO CON CORREZIONI

## Non verificabile da Studio
- Tocco vero e clic veri sul pulsante grande (i clic MCP non arrivano alla GUI: ordini dati col remoto Ordine), tasto 5 e Y premuti davvero, controller vero.
- Suoni (tromba quando torna pieno, "ala" del +N%) e la sensazione del battito.
- Ranked tra due giocatori veri; telefono vero (solo simulazione); PC 1372x772 l'ha provato solo il Costruttore (ranked).
