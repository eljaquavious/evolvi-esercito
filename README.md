# Evolvi Esercito

Gioco Roblox stile autobattler (TFT): il tuo esercito evolve dalla preistoria all'era moderna.

Il codice è in Luau dentro `src/` e arriva in Roblox Studio tramite [Rojo](https://rojo.space).

## Cosa c'è (0.4)

Tutto il testo del gioco è in inglese; codice e commenti restano in italiano.

- **Lobby** con GUI ispirata ai TFT: menu a sinistra (SHOP, ARMY, PROFILE, RANKED), in basso al centro il bottone PLAY, la barra con le 6 carte del mazzo e la barra del livello giocatore.
- **Mappa della campagna**: PLAY (o il portale Campaign) apre un plastico dell'Europa e del Mediterraneo in Terrain, costruito da dati geografici veri (quote e fondali da AWS Terrain Tiles, costa GLOBE della NOAA; montagne esagerate). Ogni livello è una battaglia storica; un sentiero tracciato sul terreno le collega, con le tratte per mare segnate sull'acqua. I dati sono in `src/shared/Config/MappaEuropaDati.luau`, generati da uno script.
- **Campagna**: 30 battaglie in 3 epoche (Antiquity, Medieval, 20th Century), 10 per epoca. Le battaglie 5 e 10 di ogni epoca hanno un comandante boss.
- **Round**: ogni battaglia è al meglio di 5 (vince chi arriva a 3). Quando il giocatore è a un round dalla vittoria, il nemico si chiude in una fortezza (Hill Fort, Castle, Bunker) con al massimo una scorta. Prima di ogni round lo Scouts Report mostra le truppe nemiche.
- **Stelle**: 3 se non perdi round, 2 con un round perso, 1 con due. Ogni round dà esperienza per il livello giocatore.
- **Truppe storiche**: Roman Legionaries (testuggine contro le frecce), Cretan Archers, Companion Cavalry, Saxon Huscarls, English Longbowmen, Norman Knights, French Poilus, Machine Gun Crew, Sherman Tank.
- **Comandanti** (carte LEGEND): Hannibal, Julius Caesar, William the Conqueror, Joan of Arc, Ferdinand Foch, Charles de Gaulle. Si sbloccano battendoli e danno un bonus al danno dei reggimenti vicini.
- **Campo di battaglia**: una valle naturale del bioma, grande 640x640 studs, in cui il giocatore cammina anche durante la battaglia. La griglia 6x6 (caselle da 16 studs, fatte di piastrelle che seguono colline e sponde) si vede solo mentre si schiera. Fiumi con guadi (rallentano e fanno prendere più danno, non ci si piazza), colline vere (meno danno subito, più gittata per i tiratori), ostacoli naturali.
- **Carte** stile FUT con OVR, ritratto 3D e statistiche. **Army**: collezione e mazzo da 6. **Profile**: statistiche personali.
- **Shop** con casse ancora vuote ("coming soon").
- **Salvataggio** di monete, livello, stelle, esperienza, collezione, mazzo e statistiche (in Studio serve *Game Settings › Security › Enable Studio Access to API Services*).

## Struttura

| Cartella | Dove finisce in Studio | Cosa contiene |
|---|---|---|
| `src/shared` | ReplicatedStorage › Shared | Configurazione (epoche, reggimenti, comandanti, carte, biomi, battaglie, mappa d'Europa, casse), modelli 3D dei soldati e simulazione della battaglia |
| `src/server` | ServerScriptService › Server | Lobby, ambiente, arene, plastico della mappa, campagna a round, collezione, shop, salvataggi |
| `src/client` | StarterPlayer › StarterPlayerScripts › Client | Interfaccia (HUD, mappa della campagna, carte, Army, Profile, Shop, partita) |

Per aggiungere un'epoca servono una voce in `src/shared/Config/Epoche.luau` (reggimenti, comandanti, fortezza), 10 battaglie in `src/shared/Config/Campagna.luau` e i modelli in `src/shared/Modelli.luau`.

## Test

La simulazione della battaglia si può provare senza Studio con [Lune](https://lune-org.github.io/docs): `lune run test/battaglia`.

## Setup (una volta sola)

1. Installa Roblox Studio.
2. Installa Rokit (gestisce la versione di Rojo del progetto). Da PowerShell su Windows:
   ```powershell
   Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression
   ```
   Su Mac:
   ```bash
   curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
   ```
   Chiudi e riapri il terminale.
3. Clona questo repository e, dentro la cartella:
   ```
   rokit install
   rojo plugin install
   ```
   Il secondo comando installa il plugin Rojo in Studio.

## Lavorare

1. Nella cartella del progetto: `rojo serve`
2. Apri Studio con un place vuoto (Baseplate), tab **Plugins › Rojo › Connect**.
3. Premi **Play**. Nella finestra **Output** devono comparire:
   ```
   [Server] Evolvi Esercito avviato, versione 0.4.3
   [Client] Evolvi Esercito avviato, versione 0.4.3
   ```
4. Ogni volta che il codice cambia: `git pull`, Rojo aggiorna Studio da solo.
