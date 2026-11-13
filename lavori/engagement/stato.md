# Stato - Engagement durante la battaglia

## Ricerca (1 di 3) - FATTA 13/11/2026
- ricerca.md scritto: P1 carica che si ricarica, P2 barra tiro alla fune + timer + "+N%", P3 primo round snello

## Costruttore (2 di 3) - FATTO 13/11/2026 (vedi costruzione.md)
### Passi
1. Lettura ricerca e codice: FATTA
2. P1 Battaglia/server/test: FATTA (non ancora provata)
   - src/shared/Battaglia.luau: RICARICA_CARICA 12, CARICA_PER_UCCISO 0.04, CARICA_INIZIALE 1, self.barraCarica,
     caricaPronta, _riempiCarica, ordine (barra al posto di "una per ala per round"), passo (ricarica), _ferisci (+uccisi)
   - test/battaglia.luau: caso carica riscritto (verifiche nuove, bersaglio MURO che non muore)
   - src/server/GestoreCampagna.luau: passo con carica/resta, Fase battaglia con durata, tutorialOrdini (avvia + piazzamento)
   - src/server/Ranked.luau: bot carica ogni volta che la barra e piena + nemico vicino; passo con carica della sua squadra e resta; durata
   - lune NON installato sul PC: il test va lanciato in Studio (execute_luau)
3. P1 client (pulsante grande): FATTO (Partita.luau: bottoneCarica rotondo 230 in basso a destra, CanvasGroup "Vasca" col liquido, NOW! a sinistra del pulsante, battito, tromba quando torna pieno)
4. P2: FATTO (Truppe.forze; Partita: barraBattaglia 640x44 sulla riga del timer, timer a sinistra della barra, conto 1:20 -> 0:00 dal server (resta), pulsa sotto 10 s, "+N%" 2,5 s dopo un ordine se >= 3%)
5. P3: FATTO (Tutorial: passi 6 SOUND THE CHARGE / 7 CHARGE AGAIN! / 8 SEND THE RESERVE, via GIVE ORDERS e TARGET; PASSI_ORDINI "NEW! ORDERS" + "CHOOSE THE TARGET" per il primo livello 2; Partita: pannelloOrdini nascosto nel tutorial, suggerimento corto)
6. Collaudo Studio: IN CORSO
   - FATTO: test Battaglia in Studio (15 OK); simulazione L1/2/6/12 (vecchia regola vs barra: L1 2 cariche in ~25 s sim, tutte vinte)
   - FATTO telefono 844x390 touch: L1 tutorial (barra Orders nascosta, passi 6 -> 7 CHARGE AGAIN -> 8 -> ROUND OVER, 2 PERFECT CHARGE nel round 1), liquido, NOW!, barra e timer, assedio round 2; L2 con NEW! ORDERS e barra Orders. Nessun errore nuovo in Output
   - BUG TROVATO E SISTEMATO: Partita oltre 200 variabili locali (Luau) -> stato in una tabella cb; colori PAL tutti grigi -> ACCENTI per liquido, barra blu/rossa e pulsante pieno
   - FATTO "+N%": compare (+6% a 2,7 s dopo la carica, ranked); prima non compariva (quota smussata) -> ora quota vera, controllo a 2,5 s e 4 s
   - FATTO bot: carica a ripetizione (prova sul server: 4 cariche in 60 s a 2,0 / 20,1 / 38,1 / 56,1)
   - FATTO PC 1372x772: nessuna sovrapposizione; BUG grafico "orecchie" grigie sopra il pulsante (Riflesso fuori dal cerchio) -> Riflesso spostato nella vasca rotonda
   - FATTO tablet 1024x768 touch: pulsante, NOW!, vassoio, barra e timer senza sovrapposizioni
   - BUG TROVATO in ranked (c'era già prima): il server non mandava l'ala dei reggimenti -> caricaDisponibile sempre falso, NOW! mai acceso. Sistemato in Ranked.luau (r.ala come in GestoreCampagna). DA RIPROVARE
   - FATTO riprova ranked: NOW! si accende, carica del giocatore PERFETTA, bot carica, carte con CENTER/LEFT/RIGHT
   - FATTO console: nessun errore nuovo (solo EditableMesh, DataStore in Studio, asset 203785492 non nostro)
7. costruzione.md: FATTO
Costruttore FINITO 13/11/2026: tocca al Controllo. Niente commit.

### Modifiche temporanee a Studio (RIPRISTINATE)
- workspace attributi SimSchermo e SimTouch: TOLTI
- CODICE TEMPORANEO ProvaDaiOrdine in src/client/UI/Partita.luau: TOLTO (Partita compila)
- Play fermato, place non salvato

## Controllo (3 di 3) - IN CORSO 13/11/2026
1. Lettura spec, costruzione.md e diff: FATTA
2. Studio: Edit, nessuna modifica temporanea finora
3. Test Battaglia in Studio (Edit, modulo clonato, niente salvato): 47 OK, 0 FAIL
4. Correzione 1: Battaglia.luau _ferisci, ripristinato lo spazio in "table.insert(eventi, {" tolto dal Costruttore
5. Play telefono: MODIFICA TEMPORANEA workspace SimSchermo=844x390 + SimTouch=true (DA TOGLIERE)
6. Play telefono 844x390: L1 tutorial passi 6 -> 7 CHARGE AGAIN -> 8 -> ROUND OVER, carica rifiutata dal server a barra vuota, PERFECT CHARGE, barra/pulsante/timer nascosti a fine round e a fine livello; L2 prima volta NEW! ORDERS + barra Orders; L2 rigiocato: barra Orders senza tutorial. 0 errori nuovi
7. Play tablet 1024x768 touch L2: nessuna sovrapposizione
8. Attributi SimSchermo/SimTouch: TOLTI (verificato in Edit, nil nil). Play fermato
9. Correzione 2: Battaglia.luau passo, la barra non si riempie finche dura il bonus della carica (effetto con carica = true) anche se l'ala riceve un altro ordine; test/battaglia.luau 2 verifiche nuove. Ricollaudato in Studio (11 OK)
10. controllo.md scritto. Controllo FINITO 13/11/2026: APPROVATO CON CORREZIONI. Niente commit, place non salvato, Studio ripristinato
