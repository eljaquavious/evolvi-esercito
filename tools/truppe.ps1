# Rifà e ricarica su Roblox le truppe indicate, dall'inizio alla fine:
#   1) tools/blocchi/nuove.py (Python di Blender) le costruisce in assets-truppe/_dati (solo le truppe nuove);
#   2) Blender le esporta in FBX con le ossa (tools/blocchi/esporta_fbx.py);
#   3) tools/carica-truppe.ps1 le carica (prima si dimentica l'id vecchio);
#   4) tools/blocchi/asset_luau.py riscrive src/shared/Config/AssetTruppe.luau.
# Uso: .\tools\truppe.ps1 Immortale,ArcierePersiano      (-SoloEsporta per le truppe vecchie già in MeshDati)
param([Parameter(Mandatory = $true)][string[]]$Nomi, [switch]$SoloEsporta)

$radice = Split-Path -Parent $PSScriptRoot
$python = "C:\Program Files\Blender Foundation\Blender 5.2\5.2\python\bin\python.exe"
$blender = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
$env:PYTHONPATH = Join-Path $env:LOCALAPPDATA "evolvi-pylib"

if (-not $SoloEsporta) {
	& $python (Join-Path $radice "tools\blocchi\nuove.py") @Nomi
	if ($LASTEXITCODE -ne 0) { Write-Output "! costruzione fallita"; exit 1 }
}
$env:PYTHONPATH = ""
& $blender --background --factory-startup --python (Join-Path $radice "tools\blocchi\esporta_fbx.py") -- @Nomi 2>&1 |
	Select-String -Pattern "esportato|Error|Traceback" | ForEach-Object { Write-Output $_.Line }

$fileIds = Join-Path $radice "assets-truppe\ids.json"
$ids = @{}
(Get-Content $fileIds -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $ids[$_.Name] = $_.Value }
foreach ($n in $Nomi) { $ids.Remove("$n.fbx") | Out-Null }
($ids | ConvertTo-Json) | Set-Content $fileIds -Encoding utf8
$file = $Nomi | ForEach-Object { Join-Path $radice "assets-truppe\$_\$_.fbx" }
& (Join-Path $PSScriptRoot "carica-truppe.ps1") -File $file

& $python (Join-Path $radice "tools\blocchi\asset_luau.py")
