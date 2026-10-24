#requires -Version 5.1
<# Make an offline user-settings backup without deleting any files.
   Quit EXDEV RGB completely from the system tray before running.
#>
[CmdletBinding()]
param([string]$BackupRoot = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'EXDEV_RGB_Sauvegardes'))
$ErrorActionPreference = 'Stop'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
$destination = Join-Path $BackupRoot ("EXDEV_RGB_profils_$stamp.zip")
$stage = Join-Path ([IO.Path]::GetTempPath()) ('EXDEV_RGB_PROFILE_STAGE_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage -Force | Out-Null
$records = New-Object System.Collections.Generic.List[object]
try {
    $folders = @(
        @($env:APPDATA,'Roaming','EXDEV RGB'),
        @($env:APPDATA,'Roaming','EXDEV_RGB'),
        @($env:APPDATA,'Roaming','exdev-rgb'),
        @($env:LOCALAPPDATA,'Local','EXDEV RGB'),
        @($env:LOCALAPPDATA,'Local','EXDEV_RGB'),
        @($env:LOCALAPPDATA,'Local','exdev-rgb')
    )
    $copied = 0
    foreach ($parts in $folders) {
        $root,$scope,$name = $parts
        if (-not $root) { continue }
        $src = Join-Path $root $name
        if (-not (Test-Path -LiteralPath $src -PathType Container)) { continue }
        $label = "${scope}_" + ($name -replace '[^a-zA-Z0-9_-]','_')
        $target = Join-Path $stage $label
        Copy-Item -LiteralPath $src -Destination $target -Recurse -Force -ErrorAction Stop
        $copied++
        $records.Add([pscustomobject]@{ Scope=$scope; FolderName=$name; BackupFolder=$label })
    }
    if ($copied -eq 0) {
        throw 'Aucun dossier de preferences EXDEV connu trouve. Ne desinstallez rien avant de localiser les parametres.'
    }
    @('Sauvegarde EXDEV RGB — ne contient que les dossiers utilisateurs detectes.',
      'Fermer completement EXDEV RGB avant sauvegarde pour une copie coherente.',
      "Date : $(Get-Date -Format o)") | Set-Content -LiteralPath (Join-Path $stage 'README.txt') -Encoding UTF8
    $records | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $stage 'manifest.json') -Encoding UTF8
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::CreateFromDirectory($stage,$destination)
    $zip = [IO.Compression.ZipFile]::OpenRead($destination)
    try {
        if ($zip.Entries.Count -le 1) { throw 'Archive generee vide ou incomplete.' }
    } finally { $zip.Dispose() }
    $sha = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
    Write-Host "Sauvegarde creee : $destination" -ForegroundColor Green
    Write-Host "Dossiers sauvegardes : $copied | SHA-256 : $sha"
    Write-Host 'Conservez ce ZIP hors du dossier d installation. Aucun fichier d origine n a ete efface.'
} finally {
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
}