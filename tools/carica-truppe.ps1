# Carica su Roblox (Open Cloud) i file delle truppe (FBX e texture PNG, da tools/blocchi/esporta_fbx.py) e annota gli
# id in assets-truppe/ids.json. La chiave resta nel file chiave-roblox.txt, non viene mai stampata.
# Uso: .\tools\carica-truppe.ps1 -File assets-truppe/Legionario/Legionario.fbx,assets-truppe/Legionario/Legionario.png
param(
	[Parameter(Mandatory = $true)][string[]]$File,
	[string]$UserId = "2310327136",
	[string]$Prefisso = "EYA truppa"
)

$radice = Split-Path -Parent $PSScriptRoot
$chiave = (Get-Content (Join-Path $radice "chiave-roblox.txt") -Raw).Trim()
$fileIds = Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) "assets-truppe") "ids.json"
$ids = @{}
if (Test-Path $fileIds) {
	$letti = Get-Content $fileIds -Raw | ConvertFrom-Json
	foreach ($p in $letti.PSObject.Properties) { $ids[$p.Name] = $p.Value }
}
$richiesta = Join-Path $env:TEMP "richiesta-asset-truppa.json"

foreach ($percorso in $File) {
	$f = Get-Item $percorso
	$nome = $f.BaseName
	$chiaveId = $f.Name
	if ($ids.ContainsKey($chiaveId)) { Write-Output "= $chiaveId $($ids[$chiaveId])"; continue }
	$est = $f.Extension.ToLower()
	if ($est -eq ".png") { $tipo = "Image"; $mime = "image/png" }
	elseif ($est -eq ".fbx") { $tipo = "Model"; $mime = "model/fbx" }
	else { Write-Output "! $chiaveId : estensione non gestita"; continue }

	# Roblox accetta nomi fino a 50 caratteri.
	$titolo = "$Prefisso $nome"
	if ($titolo.Length -gt 50) { $titolo = $titolo.Substring(0, 50) }
	$json = @{
		assetType = $tipo
		displayName = $titolo
		description = "Evolve Your Army troop model"
		creationContext = @{ creator = @{ userId = $UserId } }
	} | ConvertTo-Json -Depth 5 -Compress
	[System.IO.File]::WriteAllText($richiesta, $json, (New-Object System.Text.UTF8Encoding $false))

	$risposta = & curl.exe -s -X POST "https://apis.roblox.com/assets/v1/assets" `
		-H "x-api-key: $chiave" `
		-F "request=<$richiesta;type=application/json" `
		-F "fileContent=@$($f.FullName);type=$mime"
	$operazione = $null
	try { $operazione = $risposta | ConvertFrom-Json } catch {}
	if (-not $operazione -or -not $operazione.path) { Write-Output "! $chiaveId : errore: $risposta"; continue }

	$id = $null; $errore = $null
	for ($i = 0; $i -lt 60 -and -not $id -and -not $errore; $i++) {
		Start-Sleep -Seconds 2
		$testo = & curl.exe -s "https://apis.roblox.com/assets/v1/$($operazione.path)" -H "x-api-key: $chiave"
		try { $stato = $testo | ConvertFrom-Json } catch { continue }
		if ($stato.done) {
			if ($stato.response.assetId) { $id = $stato.response.assetId } else { $errore = $testo }
		}
	}
	if ($id) {
		$ids[$chiaveId] = $id
		($ids | ConvertTo-Json) | Set-Content $fileIds -Encoding utf8
		Write-Output "+ $chiaveId $id"
	} elseif ($errore) {
		Write-Output "! $chiaveId : operazione fallita: $errore"
	} else {
		Write-Output "! $chiaveId : non finito in tempo ($($operazione.path))"
	}
	Start-Sleep -Milliseconds 400
}
