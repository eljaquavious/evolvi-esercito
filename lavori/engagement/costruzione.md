# Costruzione - Engagement durante la battaglia (Costruttore, 13/11/2026)

Niente commit, niente push, niente Publish, place non salvato. Tutto il codice è sincronizzato da Rojo.

## P1 - Carica che si ricarica (barra CHARGE + pulsante grande)
- `src/shared/Battaglia.luau`
  - costanti `RICARICA_CARICA = 12` (secondi simulati da vuota a piena), `CARICA_PER_UCCISO = 0.04`, `CARICA_INIZIALE = 1`
  - `Battaglia.nuova`: `self.barraCarica = { giocatore, nemico }`
  - `Battaglia:ordine`: la carica si rifiuta se la barra non è piena ("Your troops are catching their breath..."); accettata svuota la barra. Tolta la vecchia regola "una carica per ala per round" (`stato.carica` resta solo informativo)
  - nuove `Battaglia:caricaPronta(squadra)` e `Battaglia:_riempiCarica(squadra, quanto)`
  - `Battaglia:passo`: la barra si riempie solo quando nessuna ala di quella squadra sta caricando
  - `Battaglia:_ferisci`: ogni nemico ucciso dà +0.04 alla barra di chi uccide
- `test/battaglia.luau`: il caso "una volta per round" è riscritto (barra piena all'inizio, svuotata, carica subito dopo rifiutata, tempo di ricarica, carica di nuovo accettata, anche la carica automatica del bot rispetta la barra)
- `src/server/Ranked.luau` (round): il bot carica ogni volta che `caricaPronta` e il nemico è vicino (prima: una volta sola). Il "passo" porta `carica` (barra della SUA squadra) e `resta`
- `src/server/GestoreCampagna.luau`: il "passo" porta `carica` e `resta`. Il nemico della campagna non carica (come prima)
- `src/client/UI/Partita.luau` (`inizializza`, blocco `do ... end`): pulsante rotondo `CaricaGrande` 230 px in basso a destra (`Stile.pulsante`), con una `CanvasGroup` "Vasca" e il liquido dorato che sale. Quando torna pieno salta, suona la tromba e diventa oro; quando è pieno batte. NOW! sta a sinistra del pulsante. Tasto 5 e Y del gamepad premono lo stesso pulsante. `caricaDisponibile` e `aggiornaOrdini` usano `cb.barraCarica`; `daiOrdine` la svuota subito

## P2 - Barra tiro alla fune, timer, "+N%"
- `src/client/Truppe.luau`: nuova `Truppe.forze()` (somma della vita dei soldati vivi per squadra, fortezze escluse)
- `Partita.luau`
  - `BarraBattaglia` 640x44: blu YOU contro rosso ENEMY (in ranked il nome dell'avversario), spade sul confine, aggiornata 10 volte al secondo e smussata
  - timer `m:ss` dal server (`resta`), pulsa negli ultimi 10 s (`entraBattaglia`)
  - in `daiOrdine`, dopo un ordine accettato: "+N%" dorato accanto alla barra se la quota è salita di almeno 3%. Si controlla a 2,5 s e a 4 s
  - `cb.mostraComandiBattaglia` mostra o nasconde tutto nei passaggi di fase
- Server: la Fase "battaglia" porta `durata` (campagna e ranked)

## P3 - Primo round snello
- `src/client/UI/Tutorial.luau`: i passi della battaglia ora sono 6 SOUND THE CHARGE! (pulsante grande), 7 CHARGE AGAIN! (aspetta la barra piena) e 8 SEND THE RESERVE. Tolti da L1 GIVE ORDERS e CHOOSE THE TARGET. Nuova lista `PASSI_ORDINI` ("NEW! ORDERS" + "CHOOSE THE TARGET"), con `Tutorial.avvia("ordini")`. `passoCheMostra` cerca nella lista attiva
- `Partita.luau`: nel tutorial la barra Orders è nascosta e il suggerimento è corto. Al primo livello 2 (`dati.tutorialOrdini`) parte la lista ordini
- `GestoreCampagna.luau` (`avvia`): `tutorialOrdini = numero == 2 and nessuna stella al 2`, mandato col piazzamento

## Scelte diverse dalla spec, e perché
- Colori: tutti gli `Stile.PAL` sono lo stesso grigio grafite (scelta di Mattia), quindi il liquido, il pulsante pieno e la barra blu/rossa usano `Stile.ACCENTI` (oro/blu/rosso). Se il Controllo vuole meno colore, si cambia lì
- NOW! a sinistra del pulsante e non sopra (sopra il tutorial mette la freccia TAP!). Il vecchio NOW! della barra Orders si accende solo se il pulsante grande non c'è
- Timer sulla stessa riga della barra, a sinistra: niente spazio verticale in più, e l'avviso scende a 214
- "+N%" usa la quota vera (non quella smussata, che a 2,5 s non arrivava mai al 3%), con un secondo controllo a 4 s
- Le fortezze non contano mai nella barra (nell'assedio la barra sembrava una sconfitta certa)
- Il passo "CHARGE AGAIN!" aspetta solo la barra piena (non anche NOW!), e poi aspetta l'ordine. "CHOOSE THE TARGET" passa a livello 2, nella stessa battaglia di NEW! ORDERS
- Le cariche del bot non contano mai come perfette (come prima)
- Stato della carica e della barra in una tabella `cb` in Partita: il modulo aveva superato il limite Luau di 200 variabili locali
- BUG GIÀ ESISTENTE trovato e sistemato (`Ranked.luau`, dopo `Battaglia.nuova`): il ranked non mandava al client l'ala di ogni reggimento, quindi `caricaDisponibile` era sempre falso. NOW! non si accendeva mai in ranked, e le carte non avevano l'etichetta LEFT/CENTER/RIGHT. Ora `r.ala` arriva come in `GestoreCampagna`. L'ala è vista dalla parte della propria squadra, quindi va bene anche per chi gioca scambiato
- Ritocco grafico: il `Riflesso` di `Stile.pulsante` è spostato dentro la Vasca rotonda. Largo e basso com'era, usciva dal cerchio in due "orecchie" grigie

## Collaudo fatto (Studio MCP)
- Test Battaglia lanciato in Studio (lune non è installato sul PC): 15 OK, compreso il caso "gli uccisi riempiono la barra"
- Simulazione sul campo vero 6x6, vecchia regola contro barra, 8 partite ciascuna: L1 1 carica contro 2, L2 1 contro 3, L6 e L12 1 contro 4. Tutte vinte
- Bot (prova sul server): 4 cariche in 60 s (2,0 / 20,1 / 38,1 / 56,1 s)
- Telefono 844x390 touch, L1 col tutorial: barra Orders nascosta, passi 6 → 7 CHARGE AGAIN (REFILLING...) → 8 → ROUND OVER, 2 PERFECT CHARGE nel round 1. Liquido, NOW!, barra e timer funzionano; nell'assedio del round 2 la barra è giusta. L2: NEW! ORDERS (1/2), formazioni e barra Orders visibili, l'ordine hold funziona
- PC 1372x772 (ranked col bot): nessuna sovrapposizione tra pulsante, vassoio carte, barra Orders, tabellone e barra
- Tablet 1024x768 touch (ranked col bot): NOW! sta tra il vassoio e il pulsante senza toccarli. Dopo il fix dell'ala, in ranked NOW! si accende, la carica del giocatore è PERFETTA, il bot carica, e le carte mostrano CENTER/LEFT/RIGHT
- "+N%": visto "+6%" 2,7 s dopo una carica in ranked
- Console: nessun errore nuovo. Restano gli avvisi EditableMesh, il DataStore bloccato in Studio e un asset 203785492 che non è nel nostro codice: c'erano già prima

## Non verificato
- Il tocco vero sul pulsante: i clic MCP non arrivano alla GUI e VirtualInputManager non è permesso. Gli ordini sono stati dati con un aggancio temporaneo che chiama la stessa `daiOrdine` del pulsante, ora tolto. `Activated` del pulsante, tasto 5 e Y non sono stati premuti davvero
- Suoni (tromba, "ala") e sensazione del battito: da sentire/vedere a mano
- Un ranked fra due giocatori veri (solo col bot)
- Telefono vero (solo simulazione SimSchermo/SimTouch)

## Modifiche temporanee a Studio
- Attributi `SimSchermo` e `SimTouch` su workspace: TOLTI (verificato in Edit)
- BindableFunction `ProvaDaiOrdine` in `Partita.luau`: TOLTA (Partita compila, la parola non c'è più)
- `VELOCITA_BATTAGLIA` e `SBLOCCA_TUTTO_IN_PROVA` non toccati. Play fermato, Studio non riavviato, place non salvato
