# Evolvi Esercito

Gioco Roblox stile autobattler (TFT): il tuo esercito evolve dalla preistoria all'era moderna.

Il codice è in Luau dentro `src/` e arriva in Roblox Studio tramite [Rojo](https://rojo.space).

## Cosa c'è nel prototipo (0.1)

- **Lobby** costruita all'avvio: portale Campagna, portale Ranked (non ancora attive), bancone dello Shop.
- **GUI**: monete, epoca e livello in alto; menu Campagna / Ranked / Shop a destra.
- **Shop** con tre casse (Medievale, Novecento, Leggendaria). I contenuti arriveranno: per ora rispondono "in arrivo".
- **Campagna**: 20 livelli, 10 per epoca (Medievale, poi Novecento). Piazzi le tue truppe nella tua metà del tabellone 8x8, premi Combatti, l'esercito nemico appare e la battaglia va da sola.
- **Truppe**: 3 per epoca, una per classe. Fanteria batte Cavalleria, Cavalleria batte Tiratori, Tiratori battono Fanteria.
- **Mappe** con 5 biomi: pianeggiante, collinoso, desertico, montagnoso, innevato.
- **Salvataggio** di monete e livello (in Studio serve *Game Settings › Security › Enable Studio Access to API Services*).

## Struttura

| Cartella | Dove finisce in Studio | Cosa contiene |
|---|---|---|
| `src/shared` | ReplicatedStorage › Shared | Configurazione (epoche, truppe, biomi, livelli, casse) e simulazione della battaglia |
| `src/server` | ServerScriptService › Server | Lobby, arene, campagna, shop, salvataggi |
| `src/client` | StarterPlayer › StarterPlayerScripts › Client | Interfaccia |

Per aggiungere un'epoca basta una voce in `src/shared/Config/Epoche.luau` con le sue truppe (e il modello in `src/server/Modelli.luau`).

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
   [Server] Evolvi Esercito avviato, versione 0.1.1
   [Client] Evolvi Esercito avviato, versione 0.1.1
   ```
4. Ogni volta che il codice cambia: `git pull`, Rojo aggiorna Studio da solo.
