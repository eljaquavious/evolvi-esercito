# Ricerca: tenere il giocatore dentro la battaglia (Evolvi Esercito)

Agente RICERCA, 13/11/2026. Fonti lette con Claude in Chrome (scheda nuova, nessun login). Codice letto, NON modificato.

Il buco da chiudere: Primo FIGHT 10 -> Primo round finito 6. Il 40% esce DURANTE il primo round del livello 1.

---

## 0. Cosa succede davvero nel primo round (dal codice)

Controllato nel codice prima di scriverlo:

- Il livello 1 è Thermopylae, contro "the Persians" con Immortale e ArcierePersiano (Campagna.luau:60-61). È il tutorial finché non lo vinci (GestoreCampagna.luau:188-189), e lo schieramento parte vuoto (195-197).
- Livello 1: maxReggimenti = 2 (Campagna.luau:265-266) e riserva = 1 (321-322), quindi la **prima linea è 1 solo reggimento** (324-326). Il nemico ne ha altrettanti, con la stessa riserva (275-287, 333-335). La riserva è pronta dopo 10 s di simulazione, invece di 22 (329-331).
- La forza del nemico al livello 1 è 0.92 (Campagna.luau:279-280). Il commento a Campagna.luau:273-274 dice che, in simulazione **senza ordini**, il livello 1 si vince in circa 25 s.
- La battaglia gira a VELOCITA_BATTAGLIA 0.75 (GestoreCampagna.luau:25). Quindi 25 s simulati sono circa **33 s veri**, più 3,2 s di conto alla rovescia (GestoreCampagna.luau:416). Il round lungo (60 s, Battaglia.luau:20) vale **80 s veri**.
- In quei ~33 s il giocatore ha queste mosse:
  - 1 GENERAL CHARGE: una per ala e per round (Battaglia.luau:490-491). Con un solo reggimento le ali non servono: con meno di 0.9 caselle di larghezza è tutto "centro" (Battaglia.luau:296-299).
  - la carta RESERVE, dopo ~13 s veri;
  - il clic su un nemico come bersaglio.
  - Le abilità non ci sono: il mazzo iniziale non ha comandanti (Epoche.luau:35).
- Il nemico non dà mai ordini in campagna. "Il nemico avanza sempre" (Battaglia.luau:100-101). Usa solo le abilità dopo 6 s (GestoreCampagna.luau:427-431) e manda la riserva quando vuole (433-440).
- Sullo schermo, durante la battaglia, ci sono tante cose:
  - la barra Orders con 4 pulsanti WING e 5 ordini (Partita.luau:2319-2404);
  - le carte, con RESERVE e il conto IN Ns (Partita.luau:833-859);
  - il riquadro del tutorial con i passi 6-9 (Tutorial.luau:64-94). Il 7 e l'8 sono testo, con tasti e regole.
- **Non c'è un timer del round né una misura di chi sta vincendo.** La pillola del timer si usa solo nel conto alla rovescia e nello schieramento ranked (Partita.luau:277-283, 650-660, 682-691). Le uniche barre sono quelle della vita, piccole, sopra ogni soldato (Truppe.luau:93-121).

In sintesi: nel primo round il gioco offre **una** mossa con un vero picco, la carica (con NOW! / PERFECT CHARGE!). Dopo, per 20-30 s, non chiede più niente. Si vince anche senza toccare nulla, e nessun indicatore mostra che le mosse hanno cambiato qualcosa.

---

## 1. Metodi trovati, con fonti

Formato: cosa fa / perché funziona / fonte. I numeri sono solo quelli riletti nella fonte.

### Risorsa o barra che si ricarica durante l'azione
1. **Elisir di Clash Royale.** L'elisir si rigenera da solo durante la partita e si spende per mettere le carte. Il ritmo cresce verso la fine: x1 nei primi due minuti, x2 nel terzo, poi x2 e x3 nei supplementari. Funziona perché c'è sempre qualcosa di cui tenere conto ("quando mi si riempie?"), e l'accelerazione finale crea il picco più alto alla fine.
   Fonte: https://support.supercell.com/clash-royale/en/articles/elixir.html
2. **Super di Brawl Stars.** È una barra gialla che si carica facendo e subendo danno. Quando è piena si preme il pulsante Super. Funziona perché lega il giocare bene alla ricarica del colpo forte, e la barra piena è un richiamo visivo che chiede un tocco.
   Fonte: https://brawlstarswiki.miraheze.org/wiki/Super
3. **Incantesimi di Kingdom Rush.** Call Reinforcements si ricarica in 10 s (soldati che durano 20 s). La wiki nota che non usarlo ha poco senso. Rain of Fire è un incantesimo d'area a ricarica lunga. Funziona perché una ricarica breve chiede una decisione ogni pochi secondi, sempre con lo stesso gesto.
   Fonti: https://kingdomrushtd.fandom.com/wiki/Call_Reinforcements e https://kingdomrushtd.fandom.com/wiki/Rain_of_Fire (per Rain of Fire letto solo il riassunto della ricerca, niente numeri).
4. **"Call the wave early" di Kingdom Rush.** Chi chiama l'ondata in anticipo riceve oro e accorcia le ricariche. È una scommessa rischio/premio tra due momenti di calma.
   Fonte: https://www.trueachievements.com/a382038/fearless-achievement
5. **Abilità attiva nei tower defense di Roblox.** In Tower Defense Simulator il Commander ha "Call to Arms", un'abilità attiva a tempo che accelera le torri vicine. L'abilità si usa durante l'ondata, non prima. I valori cambiano tra le wiki, quindi non li riporto.
   Fonte: https://tds.fandom.com/wiki/Commander
   Toilet Tower Defense, Anime Defenders e Mini Warriors li ho cercati ma non ho trovato fonti affidabili: non li cito.

### Micro-azione continua
6. **I soli di Plants vs Zombies.** Nei livelli di giorno il sole cade dal cielo e si tocca per raccoglierlo. Serve a comprare le piante. È un tocco facile e continuo che tiene le mani occupate anche quando non c'è da decidere.
   Fonte: https://plantsvszombies.fandom.com/wiki/Sun
   Nella stessa conferenza George Fan (GDC 2012) spiega come insegnare: una decisione utile alla volta, e via ogni pezzo d'interfaccia che non serve.
   Fonte: https://gamedesign.gg/watch/plants-vs-zombies-onboarding/
7. **Incantesimi a metà attacco in Clash of Clans.** Rage si lancia su un punto durante l'attacco: le truppe dentro diventano più veloci e più forti. Il giocatore non comanda le truppe, ma sceglie il momento e il punto.
   Fonte: https://clashofclans.fandom.com/wiki/Rage_Spell/Home_Village

### Finestre a tempo (timing, QTE)
8. **Active Reload di Gears of War.** Una lineetta corre su una barra. Se ripremi nella zona perfetta ricarichi prima e fai più danno; se sbagli, l'arma si inceppa. Secondo l'autore, così la ricarica smette di essere un'attesa passiva e il giocatore resta concentrato.
   Fonte: https://scottfinegamedesign.com/design-blog/2023/6/13/mini-mechanic-microscope-gears-of-war-reloading
9. **Quick Time Event: cosa evitare.** Sono criticati quando rompono il ritmo, arrivano senza preavviso e, se sbagli, ti fanno ripetere tutto. Funzionano meglio quando sbagliare non chiude la partita, ma dà solo un vantaggio in meno (es. God of War).
   Fonte: https://en.wikipedia.org/wiki/Quick_time_event
10. **Un tocco solo (hyper-casual).** Con un solo comando la bravura sta nel tempismo. Ogni tocco deve cambiare subito qualcosa sullo schermo, se no il giocatore dubita che il gioco l'abbia sentito.
    Fonti: https://plarmes.com/blog/one-tap-controls-in-hyper-casual-design e, per "tocco a tempo come meccanica più comune", https://gamedesigning.org/learn/hyper-casual-games/

### Auto-battler: cosa resta al giocatore mentre la battaglia va da sola
11. **Auto-battler (TFT e simili).** Tutta la scelta sta nella preparazione e lo scontro è "la rivelazione". Un errore tipico è lo scontro che devi guardare ma non riesci a leggere. Tra le idee: interrompere lo scontro una volta, pagando un prezzo.
    Fonte: https://hayao.dev/docs/codex/genre-auto-battler
12. **Art of War: Legions.** La guida del gioco consiglia di usare a mano l'abilità dell'eroe invece della modalità automatica per vincere le rivincite. Le truppe si fondono anche sul campo.
    Fonte: https://artofwar.fandom.com/wiki/Basics
13. **TABS.** Si può "possedere" un'unità a battaglia in corso e combattere con lei.
    Fonte: https://tabs.wiki.gg/wiki/Unit_Possession
    SCARTATO per noi: è troppo per il telefono e somiglia all'avatar-generale che Mattia ha bocciato.

### Feedback, juice, ritmo
14. **Juice.** È il massimo del feedback per il minimo dell'input: particelle, suono, scossa, numeri. Amplifica un buon cuore del gioco, non lo sostituisce. Va dosato perché l'informazione importante si legga per prima.
    Fonte: https://gamedesign.gg/glossary/juice/
15. **Hit-stop.** Un fermo di pochi fotogrammi al momento dell'impatto fa sentire la forza del colpo. Va tenuto per i colpi importanti: con troppi fermi il ritmo si impasta.
    Fonte: https://gamedesign.gg/glossary/hit-stop/
16. **Curva d'interesse (Jesse Schell).** L'interesse deve salire con picchi e valli fino a un culmine finale, anche dentro un singolo livello.
    Fonte: https://game-studies.fandom.com/wiki/Interest_Curve
17. **Timer visibile.** In Clash Royale (come in Counter-Strike) si sa sempre quando finisce il round. Lo stesso articolo nota che il tocco sullo schermo è l'unico gesto fisico del gioco.
    Fonte: https://www.gamedeveloper.com/design/24-competitive-ingredients-of-clash-royale
18. **Scelta significativa.** Una scelta perde valore se è cieca, falsa (il risultato è uguale), banale o già risolta.
    Fonte: https://gamedesign.gg/glossary/meaningful-choice/
    Oggi la nostra carica non perfetta e gli ordini nel livello 1 rischiano di essere scelte "false": vinci comunque.

### Primi minuti (FTUE)
19. **Primi 5 minuti.** Il giocatore si sente coinvolto quando prende decisioni, non quando passa il tempo: "Five passive minutes only spend patience" (GameDesign.gg). Servono competenza ("so farlo"), contesto e un gancio. Troppe meccaniche insieme bruciano l'apertura.
    Fonte: https://gamedesign.gg/articles/first-five-minutes/
20. **Roblox Creator Hub, tecniche di onboarding:**
    - elementi visivi al posto del testo (aiutano anche i bambini che leggono poco);
    - tutorial contestuali, che partono quando la funzione serve;
    - suggerimenti che compaiono solo a chi è fermo da un po';
    - feedback continuo: barre della vita che si aggiornano, monete che volano quando vinci.
    Fonte: https://create.roblox.com/docs/production/game-design/onboarding-techniques

---

## 2. Cosa c'è già nel nostro gioco (file:riga)

| Cosa | Dove |
|---|---|
| Round 60 s simulati, velocità 0.75 (= 80 s veri), 2 round per vincere | Battaglia.luau:20, GestoreCampagna.luau:25, Campagna.luau:49 |
| Assedio della fortezza al match point (round 2 dopo un round vinto) | GestoreCampagna.luau:116 |
| 5 ordini (Advance, Hold the Line, Fall Back, Flank Them, General Charge) per ala o per tutti | Battaglia.luau:108-116, 470-549 |
| Attesa 3 s tra due ordini alla stessa ala | Battaglia.luau:117, 488-489 |
| Carica: 6 s, una per ala per round; velocità +0.3, danno +0.1 (perfetta +0.35) | Battaglia.luau:118-125, 490-491, 535-538, 627-628 |
| Carica perfetta: nemico entro 2.5 caselle; fermo-immagine 0.35 s | Battaglia.luau:123, 529-531; GestoreCampagna.luau:31, 441-445, 689-692 |
| NOW! acceso sul pulsante della carica quando la finestra è aperta | Partita.luau:1260-1280, 2373-2403 |
| PERFECT CHARGE! e ROUTED! al centro, onda, tamburo, colpo di camera | Partita.luau:1283-1331 |
| Juice dell'ordine: tromba/tamburo, impulso sotto le truppe, grido sopra l'armata | Partita.luau:1333-1360; Truppe.luau:354, 539-546 |
| Abilità dei comandanti (1 per round, sul punto toccato), pulsante ABILITY sulla carta | Battaglia.luau:646-693; Partita.luau:887-899 |
| Riserva: pronta dopo 22 s (10 al livello 1), carta RESERVE, poi tocco sul campo | Battaglia.luau:134-138, 695-698, 756-781; Campagna.luau:329-331; Partita.luau:833-859, 917-947 |
| Riserva IA quando vuole; il nemico in campagna non dà ordini | Battaglia.luau:700-725; GestoreCampagna.luau:423-440 |
| Bot ranked: una carica sola quando gli eserciti si avvicinano | Ranked.luau:462-469 |
| Barra Orders 1100x154: riga WING (Z X C V) e 5 ordini (1-5) | Partita.luau:2319-2372 |
| Controller: X reggimento, B abilità, A riserva, croce/Y ordini, L2/R2 ala | Partita.luau:182-211, 2693-2790 |
| Tutorial battaglia: passi 6 SOUND THE CHARGE (WAIT... / CLICK!), 7 GIVE ORDERS (testo), 8 CHOOSE THE TARGET, 9 SEND THE RESERVE | Tutorial.luau:62-94 |
| Avatar che segue l'esercito | Partita.luau:1575-1643 |
| Barre della vita sopra i soldati, numeri "-N" per colpi da 25 in su, CHARGE! della cavalleria, RESERVES! | Truppe.luau:93-121, 515, 534, 590 |
| Effetti disponibili: scritta, onda, scintille, esplosione, polvere | Effetti.luau:135-280 |
| Suoni UI: tromba, carica, tamburo | Suoni.luau:138-141 |
| Statistiche dei comandi (Ordine, Bersaglio, Abilita, Riserva, ComandiPerBattaglia, UscitoInBattaglia) | Statistiche.luau:10, 145-161 |
| Test della carica "una per round" | test/battaglia.luau:321-330 |
| NON c'è: timer del round in battaglia, barra di chi vince, una carica che si ricarica, mosse richieste dal gioco | (cercato con grep in Partita, Truppe, Hud) |

Da guardare in Creator Hub (Custom events): **ComandiPerBattaglia** e **UscitoInBattaglia** sul livello "L01". Se chi esce ha 0-1 comandi, la lettura "il gioco non chiede niente" è confermata. Non ho accesso a questi dati.

---

## 3. Proposte adattate, ordinate per impatto sul buco "durante il primo round" diviso sforzo

Tutte sono **nuove** (oggi non esistono), salvo dove è scritto "c'è già".

### P1. Carica che si ricarica (barra CHARGE) con un pulsante grande unico. Impatto ALTO, sforzo MEDIO
Prende da: elisir, Super di Brawl Stars, ricarica di Kingdom Rush, Active Reload.

Cosa vede e fa il giocatore (livello 1, round 1, tempi veri):
- **0 s (FIGHT!)**: in basso a destra c'è un grande pulsante rotondo CHARGE!, già pieno e dorato.
- **~2-4 s**: le linee si avvicinano, compare NOW! (c'è già) e il bambino tocca. Arrivano PERFECT CHARGE! e il fermo-immagine (c'è già), poi il pulsante si svuota.
- **4-20 s**: il pulsante si riempie dal basso come un liquido, più in fretta a ogni nemico ucciso. Quando è pieno salta, suona la tromba e si accende.
- **~20 s**: seconda carica con NOW!. Prima c'era una carica sola in tutto il round, ora ce ne sono 2-3 nel livello 1 e 4-6 nei round lunghi.

Semplice: un solo gesto (tocca quando è pieno, meglio se c'è NOW!). Su PC: tasto 5 o clic. Controller: Y, come oggi. Le ali restano: con un'ala scelta la carica va solo a quell'ala.

Codice: Battaglia.luau (barra al posto della regola "una per ala per round"), GestoreCampagna.luau e Ranked.luau (mandare il valore al client, bot che usa la barra), Partita.luau (pulsante grande), test/battaglia.luau. Dettagli nel punto 4.

Rischi:
- Il giocatore diventa più forte se carica spesso. È voluto, ma va controllato in simulazione che il ranked resti pari: il bot usa la stessa barra.
- Il pulsante grande non deve coprire le carte sul telefono.

### P2. Barra "tiro alla fune" della battaglia + timer del round + "+N%" dopo ogni mossa. Impatto ALTO, sforzo BASSO
Prende da: feedback e barre della vita (Roblox Creator Hub), timer visibile (Clash Royale e Counter-Strike), "scontro che non si legge" (auto-battler).

Cosa vede il giocatore:
- In alto al centro, una barra blu (YOU) contro rossa (ENEMY) con le spade nel punto d'incontro. Sotto, la pillola rossa con il tempo che resta (1:20 -> 0:00).
- Quando il giocatore dà un ordine e la barra si sposta verso il blu, dopo 2 s compare accanto un "+7%" dorato con un piccolo pop: la mossa si vede.
- Quando arrivano le riserve nemiche, la barra scatta verso il rosso: tensione, e poi si risponde con la propria riserva.
- Negli ultimi 10 s il timer diventa rosso e pulsa.

Semplice: non si tocca niente, si guarda soltanto.

Codice: Truppe.luau (somma della vita per squadra), Partita.luau (barra, timer, "+N%"), GestoreCampagna.luau e Ranked.luau (durata vera del round nel messaggio "battaglia").

Rischio basso. Se la barra va sul rosso il bambino capisce che sta perdendo: è un'informazione utile, non una punizione.

### P3. Primo round snello: un solo pulsante, il tutorial a gesti. Impatto ALTO, sforzo BASSO
Prende da: PvZ (una decisione alla volta, togliere l'interfaccia che non serve), primi 5 minuti (troppe meccaniche insieme), tutorial contestuali di Roblox.

Cosa vede il giocatore nel tutorial (livello 1):
- In battaglia vede solo il pulsante grande CHARGE! di P1 e la carta della riserva.
- La barra Orders (WING + 5 ordini) non c'è. Con 1 reggimento le ali non servono comunque (Battaglia.luau:296-299).
- Il riquadro di testo cambia:
  - passo 6: una riga, "When NOW! lights up, tap CHARGE!" (con WAIT... e TAP!);
  - passo nuovo 6b: "CHARGE AGAIN!", che aspetta la seconda carica e mostra "REFILLING..." mentre si riempie;
  - passo 9 della riserva: più corto.
  - I passi 7 (GIVE ORDERS) e 8 (CHOOSE THE TARGET) escono dal livello 1.
- La barra Orders compare dal livello 2, con un passo contestuale la prima volta ("NEW! ORDERS").

Codice: Tutorial.luau (PASSI), Partita.luau (nascondere pannelloOrdini quando info.tutorial, bersaglio "caricaGrande"), GestoreCampagna.luau (indicatore "tutorialOrdini" per il primo round del livello 2).

Rischio: chi rigioca il livello 1 dopo averlo vinto non è più nel tutorial e vede la barra completa (va bene).

### P4. Carica nemica annunciata + BRACE! (parata a tempo). Impatto ALTO, sforzo MEDIO-ALTO
Prende da: Active Reload (premio e sbaglio), QTE fatti bene (preavviso, lo sbaglio non chiude la partita).

Cosa succede: dal livello 2 (mai nel tutorial) anche il nemico ha la sua barra CHARGE. Quando si riempie e le linee sono vicine:
- compare per 1,5 s "ENEMY CHARGE!" in rosso sopra la sua armata, con il suo grido;
- il pulsante grande diventa per quel momento "BRACE!" (scudo).
- Se lo tocchi in tempo: "BRACED!" e la carica nemica perde il suo bonus. Se no, la carica nemica colpisce piena.

È questa proposta che rende vero "se non tocchi, perdi qualcosa".

Codice: GestoreCampagna.luau (IA che carica, come il bot ranked), Battaglia.luau ("tieni" dato nella finestra = parata).

Rischio: rifare il bilanciamento dei livelli 2-26 (oggi tarati "senza ordini", Campagna.luau:273-274). Da fare DOPO P1-P3 e dopo aver visto i dati.

### P5. Ultimi 15 s: "FINAL PUSH!". Impatto MEDIO, sforzo BASSO (serve P1)
Prende da: elisir doppio e triplo di Clash Royale, culmine della curva d'interesse.

Cosa succede: a 15 s dalla fine compare la scritta "FINAL PUSH!", il timer diventa rosso e la barra CHARGE si riempie al doppio della velocità. C'è un picco finale anche nei round lunghi, dove oggi la fine è solo un'attesa.

Codice: Battaglia.luau (velocità di ricarica x2 quando tempo >= DURATA_MASSIMA - 15), Partita.luau (scritta e timer).

Rischio: basso. Nel livello 1 il round finisce prima, quindi non si vede.

### P6. "CLASH!" al primo contatto delle linee. Impatto MEDIO, sforzo BASSO
Prende da: hit-stop e juice.

Cosa succede: la prima volta che le due linee si toccano (Truppe.distanzaFronte < 0.3, una volta per round) arrivano un'onda grande, la scossa della camera, il tamburo e la scritta "CLASH!".

Codice: solo Partita.luau, con le funzioni che ci sono già (momento, colpoCamera, Effetti.onda).

Rischio: troppe scritte. Non deve partire se nello stesso secondo c'è PERFECT CHARGE!.

### P7. Combo e gloria a schermo. Impatto MEDIO, sforzo MEDIO
Prende da: premi a schermo (monete che volano, Creator Hub), juice.

Cosa succede:
- PERFECT CHARGE! seguito da ROUTED! entro 8 s dà "COMBO x2!".
- A fine round, nella cinematica, una riga mostra "PERFECT CHARGES 2 · ROUTED 3".
- Volendo, un piccolo premio in monete per carica perfetta, solo con monete di gioco (niente casse a Robux).

Codice: Partita.luau, GestoreCampagna.luau (fineLivello).

Rischio: inflazione delle monete.

### P8. Bottino da toccare (stile soli di PvZ). Impatto MEDIO, sforzo MEDIO, rischio ALTO
Cosa succede: quando un reggimento nemico è ROUTED, sul campo resta per 4 s uno stendardo o un sacchetto che si tocca per avere qualche moneta.

Rischi:
- Distrae dalla battaglia e sul telefono la camera si muove.
- Con il tocco sul campo si confonde con la mira della riserva e delle abilità.
- Uno stendardo potrebbe ricordare quello del generale bocciato: meglio un sacchetto.

Da tenere per dopo.

### Scartate (vincoli di Mattia)
- Possedere un'unità alla TABS, o l'avatar che combatte: c'è il "no" ai generali del 4/11.
- Bonus per chiamare la riserva prima (come le ondate di Kingdom Rush): sarebbe un potere sulla riserva, che deve restare "solo piazzare le carte" (3/11).
- QTE che, se sbagli, fanno perdere il round: contro la regola dei primi minuti (sbagliare deve costare poco).

---

## 4. Le 3 da fare SUBITO (questo giro): P1 + P2 + P3

Perché queste tre:
- Insieme trasformano i ~33 s del primo round da "guarda" a "riempi, aspetta NOW!, tocca, guarda la barra spostarsi, rifallo". È l'attesa attiva di elisir, Super e Kingdom Rush, con un gesto solo.
- Non aggiungono pulsanti: ne tolgono (P3).
- Fanno vedere l'effetto di ogni mossa (P2).
- Non toccano il bilanciamento della campagna: il nemico non cambia. Quindi niente rischio di "IA troppo forte" nei primi livelli.
- P4, l'unica che crea una vera posta, cambia l'IA e il bilanciamento: va fatta dopo, guardando i dati nuovi.

### Specifica P1: carica che si ricarica

**src/shared/Battaglia.luau**
1. Costanti nuove, vicino a Battaglia.DURATA_CARICA (riga 118):
   - `Battaglia.RICARICA_CARICA = 12`: secondi di simulazione per riempire la barra da vuota. Sono ~16 s veri: 2-3 cariche nel livello 1 (~25 s) e ~5 in un round da 60 s.
   - `Battaglia.CARICA_PER_UCCISO = 0.04`: barra in più per ogni soldato nemico ucciso dalla squadra.
   - `Battaglia.CARICA_INIZIALE = 1`: piena al FIGHT, così la prima carica (con NOW!) c'è subito, come oggi.
2. In `Battaglia.nuova` (dopo il blocco self.ali, riga 341): `self.barraCarica = { giocatore = Battaglia.CARICA_INIZIALE, nemico = Battaglia.CARICA_INIZIALE }`.
3. Funzione nuova `Battaglia:caricaPronta(squadra)`: restituisce `(self.barraCarica[squadra] or 0) >= 1`.
4. In `Battaglia:ordine` (righe 488-497):
   - Togliere la regola `nome == "carica" and stato.carica` (righe 490-491).
   - Al suo posto, PRIMA del ciclo sulle ali e per automatico vero e falso, mettere: se `nome == "carica" and not self:caricaPronta(squadra)` allora `return false, "Your troops are catching their breath: the charge is refilling."`.
   - Dopo il ciclo, se `#scelte > 0` e `nome == "carica"`: `self.barraCarica[squadra] = 0`.
   - `stato.carica` (righe 509-511) si può lasciare (non serve più) o togliere insieme ai suoi usi.
   - Tutto il resto resta com'è: le ali vuote non sprecano la carica (492-494), la carica perfetta (529-531), l'effetto (535-538).
5. In `Battaglia:passo`, dopo `self:_aggiornaOrdini()` (riga 1302): per ogni squadra, se nessuna sua ala ha `ordine == "carica"`, fare `self.barraCarica[squadra] = math.min(1, self.barraCarica[squadra] + dt / Battaglia.RICARICA_CARICA)`. La barra non si riempie mentre la carica è in corso.
6. In `Battaglia:_ferisci`, nel ramo della morte (righe 1201-1217): la squadra avversaria di `b.squadra` prende `+ Battaglia.CARICA_PER_UCCISO`, con un massimo di 1.
7. Aggiornare il commento delle righe 100-107 ("carica: una volta per round per ogni ala" diventa "quando la barra CHARGE è piena").

**test/battaglia.luau** (righe 321-330)
- Il caso "la carica si suona una volta per round" diventa due:
  - subito dopo la carica, `not b:ordine("giocatore", "carica")` (la barra si sta riempiendo);
  - dopo altri `Battaglia.RICARICA_CARICA` secondi di `b:passo(0.1)` (con la battaglia non finita), `b:ordine("giocatore", "carica")` riesce.
- Lanciare `lune run test/battaglia`: tutti OK.

**src/server/GestoreCampagna.luau**
- Nel messaggio "passo" (riga 444), aggiungere `carica = battaglia.barraCarica.giocatore`.
- Il nemico di campagna NON carica (resta per P4).

**src/server/Ranked.luau** (righe 462-469)
- Togliere il colpo singolo `caricaBot`. A ogni tick, per ogni lato bot: se `battaglia:caricaPronta(lato.squadra)` e `nemicoVicino(...)`, allora `battaglia:ordine(lato.squadra, "carica", true)`. Il bot usa la stessa barra del giocatore.
- Nel messaggio "passo" a ogni giocatore (righe 472-477), mettere il valore della SUA squadra (`battaglia.barraCarica[lato.squadra]`).
- Controllare come `eventiPer` gira le squadre per il lato "nemico" e fare lo stesso per la barra.

**src/client/UI/Partita.luau**
1. In `remoti.Truppe.OnClientEvent` (riga 2807), quando `dati.tipo == "passo"` e c'è `dati.carica`, salvarlo in una variabile `barraCarica` (0-1).
2. Pulsante nuovo `bottoneCarica`, creato in `Partita.inizializza` vicino alla barra Orders (righe 2319-2404):
   - rotondo, circa 210x210 px sulla tela 1920x1080, con `Stile.pulsante` "oro" e testo "CHARGE!";
   - AnchorPoint (1,1), a destra sopra il vassoio delle carte: la posizione va provata sul telefono 1688x780, così non copre carte, ABILITY, la riserva o la levetta;
   - dentro, un Frame "Riempimento" ancorato in basso, con altezza `UDim2.fromScale(1, barraCarica)` e ClipsDescendants sul genitore.
   - Visibile solo in fase "battaglia".
3. Spostare l'etichetta NOW! (righe 2373-2403) sul pulsante grande, o duplicarla lì. Resta la stessa logica a 10 Hz con `finestraCarica()`.
4. `caricaDisponibile()` (righe 1260-1271): al posto di `not caricheAli[ala]` usare `barraCarica >= 1`, tenendo il controllo `conTruppe`.
5. Quando `barraCarica` passa da sotto 1 a 1: `pop(bottoneCarica, ...)`, `Suoni.ui("tromba")` e un battito continuo (UIScale come NOW!) finché non viene usata. Da vuota a piena: colore grigio-oro, poi oro pieno.
6. Il clic sul pulsante chiama `daiOrdine("carica")`, che c'è già. Usa `alaScelta` (nil = tutta l'armata).
7. `aggiornaOrdini()` (righe 984-1013): il pulsante "carica" della barra diventa grigio quando `barraCarica < 1`, invece che con `caricheAli`.
8. Testi:
   - in `SPIEGAZIONE_ORDINI.carica` (righe 960-966), togliere "Once per round for each wing!" e scrivere "When the CHARGE bar is full!";
   - in Tutorial.luau:77, togliere "Each wing can CHARGE once per round."
9. Tasti: restano 5 (tastiera), Y (controller), clic o tocco.

**Collaudo richiesto al Costruttore** (Studio, livello 1 e livello 6, telefono finto 1688x780 + PC):
- La barra si riempie e si svuota; vengono 2 o più cariche nel livello 1.
- NOW! si accende sul pulsante grande.
- PERFECT CHARGE! funziona e le statistiche del server la vedono.
- Il ranked col bot non dà errori.
- 0 errori in Output.
- Annotare in stato.md ogni modifica temporanea a Studio.

### Specifica P2: barra della battaglia + timer + "+N%"

**src/client/Truppe.luau**
- Funzione nuova `Truppe.forze()`: restituisce `{ giocatore = somma s.hp, nemico = somma s.hp }` dei `soldati` con `s.vivo`.
- Gli hp ci sono già: `s.hp` scende in `evento` "colpo" (righe 518-537) e i rinforzi hanno `s.hp` (righe 579-582).

**src/server/GestoreCampagna.luau** (messaggio Fase "battaglia", righe 403-415) **e src/server/Ranked.luau** (messaggio Fase "battaglia", vicino alla riga 436)
- Aggiungere `durata = Battaglia.DURATA_MASSIMA / VELOCITA_BATTAGLIA` (secondi veri del round, 80).

**src/client/UI/Partita.luau**
1. In `Partita.inizializza`, creare un Frame "BarraBattaglia":
   - circa 640x30, in alto al centro, sotto la pillola del timer. La posizione va scelta per non coprire l'avviso: oggi `posizionaAvviso` lo sposta a 214 quando il timer è visibile (righe 273-275), quindi aggiornarlo anche per la barra.
   - Due riempimenti, AZZURRO a sinistra e ROSSO a destra (costanti alle righe 177-179). Etichette "YOU" e "ENEMY" (in ranked il nome dell'avversario). Un'icona di spade nel punto d'incontro.
2. In un RenderStepped già attivo in battaglia (per esempio quello delle righe 1535-1556), ogni 0,1 s:
   - `quota = g / (g + n)`, lisciata con `attuale += (quota - attuale) * 0.2`;
   - posizione del punto d'incontro = `attuale`.
3. "+N%": in `daiOrdine` (righe 1333-1360), se `ok`, salvare `quotaAllOrdine = attuale`. Dopo 2,5 s, se `attuale - quotaAllOrdine >= 0.03`, mostrare accanto alla barra "+N%" dorato con `pop`. Mai valori negativi.
4. Timer: in `entraBattaglia` (righe 1645-1679), finito il conto alla rovescia, salvare `fineRound = os.clock() + (dati.durata or 80)`. Poi `mostraTimer(("%d:%02d"):format(...))` 4 volte al secondo finché `fase == "battaglia"`. Sotto i 10 s: pillola che pulsa (UIScale). `mostraRound` la spegne già (riga 1692).
5. Visibilità: la barra si vede solo in fase "battaglia", e si nasconde in `mostraRound` ed `esci`. Nell'assedio resta (la fortezza conta come vita nemica); va controllato che non sembri una sconfitta certa: se serve, nell'assedio contare solo i reggimenti non `fisso`.

**Collaudo**: barra e timer leggibili sul telefono; "+N%" compare dopo PERFECT CHARGE!; niente sovrapposizioni con il tutorial (riquadro a sinistra, Tutorial.luau:180-217) o con il tabellone.

### Specifica P3: primo round snello

**src/client/UI/Partita.luau**
- In `entraBattaglia` (riga 1663): `pannelloOrdini.Visible = not (info and info.tutorial)`. Il pulsante grande di P1 è sempre visibile.
- `aggiornaSuggerimento("battaglia")` nel tutorial: solo "5 / TAP CHARGE!", senza la riga WING/ORDERS (righe 194-211).
- Nei bersagli passati a `Tutorial.inizializza`, aggiungere `caricaGrande = function() return bottoneCarica end` e `barraPiena = function() return barraCarica >= 1 and finestraCarica() end`.

**src/client/UI/Tutorial.luau** (PASSI, righe 62-94)
- Passo 6:
  - titolo "SOUND THE CHARGE!";
  - testo "When NOW! lights up, tap CHARGE!" (una riga);
  - `mostra = "caricaGrande"`, `richiamo = "CLICK!"` (diventa TAP! sul telefono), `quando = "finestraCarica"`, `attesa = "WAIT..."`, `aspetta = "ordine"`.
- Passo nuovo 6b:
  - titolo "CHARGE AGAIN!";
  - testo "The bar refills. Full + NOW! = another PERFECT CHARGE!";
  - `mostra = "caricaGrande"`, `richiamo = "CLICK!"`, `quando = "barraPiena"`, `attesa = "REFILLING..."`, `aspetta = "ordine"`;
  - `saltaCon = "round"`, così se il round finisce prima il tutorial va avanti.
- Togliere i passi 7 (GIVE ORDERS) e 8 (CHOOSE THE TARGET).
- Passo 9 riserva: testo "Tap the RESERVE card, then tap your side of the field." (resta `saltaCon = "round"`).
- Il passo "ROUND OVER" resta.

**src/server/GestoreCampagna.luau**
- In `GestoreCampagna.avvia` (vicino alla riga 189): `local tutorialOrdini = numero == 2 and not (dati.stelle and dati.stelle["2"])`, salvato nella sessione. Nel messaggio "piazzamento" (riga 159), aggiungere `tutorialOrdini = sessione.tutorialOrdini or nil`.

**Client: primo round del livello 2 con `info.tutorialOrdini`**
- Un solo riquadro contestuale sulla barra Orders, alla prima battaglia: titolo "NEW! ORDERS", testo "Tap a WING, then an order. HOLD THE LINE: they stand firm. ADVANCE: forward again.", con `mostra = "ordini"` e NEXT.
- Si può fare con una seconda lista di passi in Tutorial.luau (`Tutorial.avvia(lista)`), o con un riquadro semplice di Notifiche. Preferibile riusare Tutorial con un parametro.
- La mira (tocco su un nemico) si spiega allo stesso modo, alla seconda battaglia del livello 2 o con un suggerimento a tempo dopo 15 s senza bersagli (suggerimento a tempo del Creator Hub).

**Collaudo**:
- Simulare "bambino di 9 anni sul telefono": FIGHT, carica, seconda carica, riserva, fine round. Niente testo da leggere oltre una riga.
- Al livello 2 la barra Orders compare con il suo riquadro.
- Rigiocando il livello 1 dopo averlo vinto, la barra Orders è normale.

### Cosa NON cambia (per il Controllo)
- Riserva: resta solo "piazza le carte rimaste", senza poteri (vincolo 3/11).
- Niente generale, stendardo o buff legato all'avatar (4/11).
- Il nemico di campagna non cambia, e il bilanciamento dei 26 livelli nemmeno: cambiano solo le cariche del giocatore e del bot ranked.
- Round sempre 60 s simulati, 2 round per vincere.
