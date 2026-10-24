#requires -Version 5.1
<#
Read-only EXDEV RGB source collector for rebuilding the official Windows installer.
Does NOT install, remove, stop, restart, or modify EXDEV RGB / services / registry.
Does NOT export AppData, profiles, driver tokens or installer logs.
Review the ZIP manually before sharing: source files may embed private configuration.
#>
[CmdletBinding()]
param(
    [string]$SourceDirectory,
    [string]$InstallDirectory,
    [string]$OutputDirectory = [Environment]::GetFolderPath('Desktop'),
    [switch]$IncludeAppAsar
)
$ErrorActionPreference = 'Stop'
function Get-InstallDirectory {
    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\EXDEV RGB',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\EXDEV RGB',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\EXDEV RGB'
    )
    foreach ($key in $keys) {
        if (-not (Test-Path -LiteralPath $key)) { continue }
        $entry = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
        if ($entry -and $entry.InstallLocation -and (Test-Path -LiteralPath $entry.InstallLocation -PathType Container)) {
            return [string]$entry.InstallLocation
        }
    }
    $paths = @(
        (Join-Path ${env:ProgramFiles(x86)} 'EXDEV RGB'),
        (Join-Path $env:ProgramFiles 'EXDEV RGB')
    )
    foreach ($path in $paths) { if (Test-Path -LiteralPath $path -PathType Container) { return $path } }
    throw 'EXDEV RGB introuvable. Relancez avec -InstallDirectory "C:\...\EXDEV RGB".'
}
if (-not $SourceDirectory) {
    if (-not $InstallDirectory) { $InstallDirectory = Get-InstallDirectory }
    $SourceDirectory = Join-Path $InstallDirectory 'Lib\Source'
}
if (-not (Test-Path -LiteralPath $SourceDirectory -PathType Container)) {
    throw "Dossier source introuvable : $SourceDirectory"
}
$sourceRoot = (Resolve-Path -LiteralPath $SourceDirectory).ProviderPath.TrimEnd('\')
$skipDirs = @('node_modules','.git','.cache','.next','coverage','win-unpacked','dist','out','bin','obj','tmp','temp','logs','backups','.vs','.idea','packages')
$includeExt = @('.ts','.tsx','.js','.jsx','.mjs','.cjs','.json','.jsonc','.css','.scss','.sass','.less','.html','.vue','.svelte',
                '.cpp','.c','.cc','.cxx','.h','.hpp','.hh','.rc','.iss','.nsi','.nsh','.cs','.csproj','.vcxproj','.sln',
                '.xml','.yml','.yaml','.md','.mdx','.txt','.toml','.svg','.ico','.png','.jpg','.jpeg','.webp','.woff2','.lock','.ps1','.cmd','.bat','.sh','.gitignore','.gitattributes')
$blockedNames = @('engine.token','hardware-status.json','ram-smbus-debug.log','.env','.env.local','.env.production','.env.development',
                  'credentials.json','service-account.json','secrets.json','token.json','settings.json','config.private.json',
                  'id_rsa','id_ed25519','known_hosts')
$blockedExt = @('.pfx','.p12','.pem','.key','.cer','.crt','.kdbx','.db','.sqlite','.sqlite3','.log','.dmp','.bak','.zip','.7z','.rar','.exe','.dll','.sys','.msi','.msix','.msixbundle','.node','.map')
$files = New-Object System.Collections.Generic.List[object]
$excluded = 0
$oversize = 0
$pending = New-Object 'System.Collections.Generic.Stack[string]'
$pending.Push($sourceRoot)
while ($pending.Count -gt 0) {
    $folder = $pending.Pop()
    foreach ($item in Get-ChildItem -LiteralPath $folder -Force -ErrorAction Stop) {
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { $excluded++; continue }
        if ($item.PSIsContainer) {
            if ($skipDirs -contains $item.Name.ToLowerInvariant()) { $excluded++; continue }
            $pending.Push($item.FullName)
            continue
        }
        $relative = $item.FullName.Substring($sourceRoot.Length).TrimStart([char]92,[char]47)
        $name = $item.Name.ToLowerInvariant()
        $ext = $item.Extension.ToLowerInvariant()
        if (($blockedNames -contains $name) -or ($blockedExt -contains $ext) -or
            $name.StartsWith('.env.') -or ($name -match '(^|[_.-])(secret|credential|privatekey|password|apikey|api-key)([_.-]|$)')) {
            $excluded++; continue
        }
        if (($includeExt -notcontains $ext) -and ($includeExt -notcontains $name)) { $excluded++; continue }
        if ($item.Length -gt 40MB) { $oversize++; continue }
        $files.Add([pscustomobject]@{ Path=$item.FullName; Relative=$relative; Bytes=$item.Length })
    }
}
$asarCandidate = Join-Path $sourceRoot 'dist\win-unpacked\resources\app.asar'
$foundAsar = Test-Path -LiteralPath $asarCandidate -PathType Leaf
if ($files.Count -eq 0 -and -not ($IncludeAppAsar -and $foundAsar)) {
    Write-Warning "Aucun fichier source exportable dans $sourceRoot."
    if ($foundAsar) { Write-Host 'Une archive Electron app.asar existe. Relancez avec -IncludeAppAsar si vous voulez aussi exporter le paquet applicatif (à inspecter avant partage).' }
    return
}
if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) { New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$stage = Join-Path $env:TEMP ("EXDEV_RGB_EXPORT_" + [guid]::NewGuid().ToString('N'))
$target = Join-Path $OutputDirectory "EXDEV_RGB_SOURCES_$stamp.zip"
New-Item -ItemType Directory -Path (Join-Path $stage 'Source') -Force | Out-Null
try {
    foreach ($file in $files) {
        $to = Join-Path (Join-Path $stage 'Source') $file.Relative
        $parent = Split-Path -Parent $to
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
        Copy-Item -LiteralPath $file.Path -Destination $to -ErrorAction Stop
    }
    if ($IncludeAppAsar -and $foundAsar) {
        $asarTarget = Join-Path $stage 'PackagedElectron'
        New-Item -ItemType Directory -Path $asarTarget -Force | Out-Null
        Copy-Item -LiteralPath $asarCandidate -Destination (Join-Path $asarTarget 'app.asar') -ErrorAction Stop
    }
    $extensions = @($files | Group-Object { [IO.Path]::GetExtension($_.Relative) } | Sort-Object Count -Descending |
      ForEach-Object { "{0}: {1}" -f $_.Name, $_.Count })
    $report = @(
      'EXDEV RGB - EXPORT TECHNIQUE DES SOURCES',
      "Date : $(Get-Date -Format s)",
      "Nombre de fichiers source : $($files.Count)",
      "Fichiers exclus volontairement : $excluded", 
      "Fichiers trop gros exclus : $oversize",
      "app.asar trouvé : $foundAsar",
      "app.asar inclus : $([bool]($IncludeAppAsar -and $foundAsar))",
      '', 'Types de fichiers:',
      $extensions,
      '', 'IMPORTANT: OUVREZ ET INSPECTEZ L''ARCHIVE AVANT DE LA PARTAGER.',
      'Le contenu source peut comporter des URL privees ou des cles integrees dans le code.',
      'Aucun profil AppData, engine.token, mot de passe, journal, .env, driver PawnIO ou binaire systeme n''est exporte.'
    )
    $report | Set-Content -LiteralPath (Join-Path $stage 'LIRE_AVANT_PARTAGE.txt') -Encoding UTF8
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $target -CompressionLevel Optimal -Force
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($target)
    try {
        if ($zip.Entries.Count -eq 0) { throw 'Archive vide.' }
    } finally { $zip.Dispose() }
    $hash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
    Write-Host "EXPORT CREE : $target" -ForegroundColor Green
    Write-Host "FICHIERS : $($files.Count) | EXCLUS : $excluded | SHA-256 : $hash"
    Write-Host 'OUVREZ LE ZIP et controlez les sources avant de me le transmettre.' -ForegroundColor Yellow
    if (-not $foundAsar) { Write-Warning 'Aucune app.asar detectee a son emplacement habituel. Certaines ressources compilées peuvent manquer.' }
} finally {
    if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Force -Recurse -ErrorAction SilentlyContinue }
}