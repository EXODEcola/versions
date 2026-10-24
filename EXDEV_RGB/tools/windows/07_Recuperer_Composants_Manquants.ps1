#requires -Version 5.1
<# EXDEV RGB: export de recuperation NON DESTRUCTIF. Aucune elevation demandee.
   Ne partagez le resultat qu'apres avoir inspecte les fichiers .go. #>
[CmdletBinding()]
param(
    [string]$InstallRoot = 'C:\Program Files (x86)\EXDEV RGB',
    [string]$OutputDirectory = [Environment]::GetFolderPath('Desktop'),
    [string[]]$AdditionalSourcePaths = @()
)
$ErrorActionPreference = 'Stop'
$timestamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$root=Join-Path $env:TEMP ("EXDEV_RGB_NATIVE_EXPORT_"+[guid]::NewGuid().ToString('N'))
$stage=Join-Path $root 'Recuperation'
New-Item -ItemType Directory -Path $stage -Force | Out-Null
$entries=New-Object System.Collections.Generic.List[object]
function Copy-Exact([string]$Source,[string]$Rel) {
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) { return }
    if ([IO.Path]::GetExtension($Source) -notin @('.go','.exe','.json','.md')) { return }
    if ($Source -match '(?i)(engine\.token|secret|password|credentials|\.env)') { return }
    $dest=Join-Path $stage $Rel
    New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
    Copy-Item -LiteralPath $Source -Destination $dest -ErrorAction Stop
    $hash=(Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash
    $entries.Add([pscustomobject]@{Original=$Source;Fichier=$Rel;SHA256=$hash;Taille=(Get-Item -LiteralPath $dest).Length}) | Out-Null
}
try {
    Copy-Exact (Join-Path $InstallRoot 'Lib\Native\EXDEV_RGB_BRIDGE.exe') 'Binaires_anciens\EXDEV_RGB_BRIDGE.exe'
    Copy-Exact (Join-Path $InstallRoot 'EXDEV_RGB_INSTALLER.exe') 'Binaires_anciens\EXDEV_RGB_INSTALLER.exe'
    Copy-Exact (Join-Path $InstallRoot 'Lib\Native\capabilities.json') 'Binaires_anciens\capabilities.json'
    $sourceDirs = @((Join-Path $InstallRoot 'Lib\Source\_developer'))
    foreach($extra in $AdditionalSourcePaths) { if ($extra) { $sourceDirs+= $extra } }
    foreach($folder in $sourceDirs | Select-Object -Unique) {
        if (-not (Test-Path -LiteralPath $folder -PathType Container)) { continue }
        foreach($file in (Get-ChildItem -LiteralPath $folder -Filter '*.go' -File -ErrorAction SilentlyContinue)) {
            Copy-Exact $file.FullName ('Sources_Go\' + $file.Name)
        }
    }
    $known = @((Join-Path $env:USERPROFILE 'Downloads'), (Join-Path $env:USERPROFILE 'Documents'))
    $suggested=New-Object System.Collections.Generic.List[string]
    foreach($folder in $known) {
      if (-not (Test-Path -LiteralPath $folder -PathType Container)) { continue }
      Get-ChildItem -LiteralPath $folder -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^(?i:EXDEV[_ ]RGB).*\.(zip|7z|rar)$' } |
        Select-Object -First 25 | ForEach-Object { $suggested.Add($_.FullName) | Out-Null }
    }
    $report=[ordered]@{
      Outil='EXDEV RGB native recovery 1.6.11';Date=(Get-Date).ToString('o');
      Avis='Ce paquet peut contenir des binaires executes avec des privileges eleves. Inspecter avant partage.';
      ElementRequis=@('_developer/bridge.go','_developer/installer_wrapper.go','EXDEV_RGB_BRIDGE.exe');
      Fichiers=@($entries.ToArray());ArchivesPossibles=@($suggested.ToArray());
      ContientBridgeSource=[bool]($entries | Where-Object {$_.Fichier -eq 'Sources_Go\bridge.go'});
      ContientWrapperSource=[bool]($entries | Where-Object {$_.Fichier -eq 'Sources_Go\installer_wrapper.go'});
    }
    $report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $stage 'INVENTAIRE.json') -Encoding UTF8
    $zip=Join-Path $OutputDirectory "EXDEV_RGB_COMPOSANTS_MANQUANTS_$timestamp.zip"
    if (-not (Test-Path -LiteralPath $OutputDirectory)) { New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null }
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -Force
    Write-Host "EXPORT TERMINE : $zip" -ForegroundColor Green
    Write-Host "FICHIERS : $($entries.Count)" -ForegroundColor Cyan
    Write-Host 'Aucun fichier du logiciel installe n a ete supprime ou modifie.'
    Write-Host 'IMPORTANT : verifier le ZIP et INVENTAIRE.json avant de le partager.' -ForegroundColor Yellow
    Write-Host 'Si bridge.go ou installer_wrapper.go sont introuvables, il faudra le projet de developpement original.' -ForegroundColor Yellow
} finally {
  if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}