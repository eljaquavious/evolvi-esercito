# Evolvi Esercito

Gioco Roblox stile autobattler (TFT): il tuo esercito evolve dalla preistoria all'era moderna.

Il codice è in Luau dentro `src/` e arriva in Roblox Studio tramite [Rojo](https://rojo.space).

## Cosa c'è (0.2)

Tutto il testo del gioco è in inglese; codice e commenti restano in italiano.

- **Lobby** costruita all'avvio: portale Campaign, portale Ranked (non ancora attive), bancone dello Shop.
- **GUI**: monete e avanzamento in alto; menu CAMPAIGN / ARMY / SHOP / PROFILE / RANKED a destra.
- **Carte**: ogni truppa è una carta stile FUT con OVR, ritratto 3D e statistiche (ATK, HP, SPD, RNG, DEF, MEN).
- **Army**: collezione di carte e mazzo da 6 carte da portare in battaglia.
- **Profile**: avatar e statistiche personali (battaglie, vittorie, win rate, reggimenti sconfitti...).
- **Shop** con tre casse (Medieval, 20th Century, Legendary). I contenuti arriveranno: per ora rispondono "coming soon".
- **Campagna**: 20 livelli, 10 per epoca (Medieval, poi 20th Century). Tabellone 6x6: piazzi i reggimenti del mazzo nelle 3 file blu, premi FIGHT!, l'esercito nemico appare e la battaglia va da sola. Vincere un livello la prima volta dà una carta.
- **Reggimenti**: ogni carta è un gruppo di soldati (da 1 carro a 8 uomini) che cadono man mano che il reggimento perde vita. Classi: Infantry batte Cavalry, Cavalry batte Ranged, Ranged batte Infantry. Cavalieri con carica, carro con danno ad area, armature.
- **Mappe** con 5 biomi (Plains, Hills, Desert, Mountains, Snow) e ostacoli sul campo.
- **Salvataggio** di monete, livello, collezione, mazzo e statistiche (in Studio serve *Game Settings › Security › Enable Studio Access to API Services*).

## Struttura

| Cartella | Dove finisce in Studio | Cosa contiene |
|---|---|---|
| `src/shared` | ReplicatedStorage › Shared | Configurazione (epoche, reggimenti, carte, biomi, livelli, casse), modelli 3D dei soldati e simulazione della battaglia |
| `src/server` | ServerScriptService › Server | Lobby, ambiente, arene, campagna, collezione, shop, salvataggi |
| `src/client` | StarterPlayer › StarterPlayerScripts › Client | Interfaccia (HUD, carte, Army, Profile, Shop, partita) |

Per aggiungere un'epoca basta una voce in `src/shared/Config/Epoche.luau` con i suoi reggimenti (e il modello del soldato in `src/shared/Modelli.luau`).

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
   [Server] Evolvi Esercito avviato, versione 0.2.0
   [Client] Evolvi Esercito avviato, versione 0.2.0
   ```
4. Ogni volta che il codice cambia: `git pull`, Rojo aggiorna Studio da solo.
