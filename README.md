# Evolvi Esercito

Gioco Roblox stile autobattler (TFT): il tuo esercito evolve dalla preistoria all'era moderna.

Il codice è in Luau dentro `src/` e arriva in Roblox Studio tramite [Rojo](https://rojo.space).

## Struttura

| Cartella | Dove finisce in Studio |
|---|---|
| `src/shared` | ReplicatedStorage › Shared |
| `src/server` | ServerScriptService › Server |
| `src/client` | StarterPlayer › StarterPlayerScripts › Client |

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
   [Server] Evolvi Esercito avviato, versione 0.0.1
   [Client] Evolvi Esercito avviato, versione 0.0.1
   ```
4. Ogni volta che il codice cambia: `git pull`, Rojo aggiorna Studio da solo.
