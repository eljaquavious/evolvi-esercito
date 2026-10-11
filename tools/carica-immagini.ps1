# Carica su Roblox le immagini dell'interfaccia (assets/gui/*.png) con la Open Cloud API
# e scrive gli id in src/client/UI/ImmaginiId.luau.
#
# Serve una chiave API Open Cloud con il permesso "Assets: Read e Write", salvata in
# chiave-roblox.txt nella cartella del progetto (il file è in .gitignore: non finisce su GitHub).
#
# Uso (PowerShell, dalla cartella del progetto):
#   .\tools\carica-immagini.ps1 -UserId 123456789
# Le immagini già presenti in ImmaginiId.luau vengono saltate; -Tutte le ricarica tutte.

param(
	[Parameter(Mandatory = $true)][string]$UserId,
	[switch]$Tutte
)

$ErrorActionPreference = "Stop"
$radice = Split-Path -Parent $PSScriptRoot
$fileChiave = Join-Path $radice "chiave-roblox.txt"
$cartella = Join-Path $radice "assets\gui"
$uscita = Join-Path $radice "src\client\UI\ImmaginiId.luau"

if (-not (Test-Path $fileChiave)) { throw "Manca chiave-roblox.txt nella cartella del progetto." }
$chiave = (Get-Content $fileChiave -Raw).Trim()

# Id già caricati.
$ids = [ordered]@{}
if (Test-Path $uscita) {
	foreach ($riga in Get-Content $uscita) {
		if ($riga -match '^\s*([a-z0-9_]+)\s*=\s*(\d+),') { $ids[$Matches[1]] = $Matches[2] }
	}
}

function Scrivi-Id {
	$righe = @(
		"-- Id Roblox delle immagini in assets/gui (nome del file senza .png -> id numerico).",
		"-- File generato da tools/carica-immagini.ps1: non modificarlo a mano.",
		"-- Finché è vuoto l'interfaccia usa delle emoji al posto delle icone.",
		"return {"
	)
	foreach ($nome in ($ids.Keys | Sort-Object)) { $righe += "`t$nome = $($ids[$nome])," }
	$righe += "}"
	[System.IO.File]::WriteAllText($uscita, ($righe -join "`n") + "`n", (New-Object System.Text.UTF8Encoding $false))
}

$richiesta = Join-Path $env:TEMP "richiesta-asset.json"
foreach ($file in Get-ChildItem $cartella -Filter *.png | Sort-Object Name) {
	$nome = $file.BaseName
	if ($ids.Contains($nome) -and -not $Tutte) { Write-Host "= $nome (già caricata)"; continue }

	$json = @{
		assetType = "Image"
		displayName = "EYA $nome"
		description = "Evolve Your Army UI"
		creationContext = @{ creator = @{ userId = $UserId } }
	} | ConvertTo-Json -Depth 5 -Compress
	[System.IO.File]::WriteAllText($richiesta, $json, (New-Object System.Text.UTF8Encoding $false))

	$risposta = & curl.exe -s -X POST "https://apis.roblox.com/assets/v1/assets" `
		-H "x-api-key: $chiave" `
		-F "request=<$richiesta;type=application/json" `
		-F "fileContent=@$($file.FullName);type=image/png"
	try { $operazione = $risposta | ConvertFrom-Json } catch { Write-Warning "$nome : risposta non valida: $risposta"; continue }
	if (-not $operazione.path) { Write-Warning "$nome : errore: $risposta"; continue }

	# Il caricamento è asincrono: si aspetta che l'operazione finisca.
	$id = $null
	for ($i = 0; $i -lt 30 -and -not $id; $i++) {
		Start-Sleep -Seconds 2
		$stato = & curl.exe -s "https://apis.roblox.com/assets/v1/$($operazione.path)" -H "x-api-key: $chiave" | ConvertFrom-Json
		if ($stato.done) { $id = $stato.response.assetId }
	}
	if ($id) {
		$ids[$nome] = $id
		Write-Host "+ $nome -> $id"
		Scrivi-Id
	} else {
		Write-Warning "$nome : caricamento non finito in tempo, riprova più tardi."
	}
	Start-Sleep -Milliseconds 400
}
Scrivi-Id
Write-Host "Fatto: $($ids.Count) immagini in ImmaginiId.luau"
