#requires -Version 5.1
<# Strict offline 1.6.11 package integrity / structural verification.
   Does NOT execute the installer or change the host.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ZipPath,
    [string]$ExpectedSHA256 = 'E1FF4F31D7DA73D6F514F61AFE9F559D11F4CC7985B1CA5865DA2E0881D48535',
    [long]$ExpectedSize = 5966175
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $ZipPath -PathType Leaf)) { throw "Fichier absent : $ZipPath" }
$actualSize = (Get-Item -LiteralPath $ZipPath).Length
if ($actualSize -ne $ExpectedSize) { throw "Taille incorrecte : $actualSize ; attendue : $ExpectedSize" }
$hash = (Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256).Hash
if ($hash -ine $ExpectedSHA256) { throw "SHA-256 NON CONFORME : $hash" }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $ZipPath).ProviderPath)
try {
    if ($zip.Entries.Count -eq 0) { throw 'Archive ZIP vide.' }
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $installer = $false
    $totalUncompressed = [long]0
    foreach ($entry in $zip.Entries) {
        $path = $entry.FullName.Replace('\','/')
        if ([IO.Path]::IsPathRooted($path) -or $path.StartsWith('/') -or $path -match '^[A-Za-z]:') { throw "Chemin absolu interdit : $path" }
        if (@($path.Split('/') | Where-Object { $_ -eq '..' }).Count -gt 0) { throw "Chemin parent interdit : $path" }
        if (-not $seen.Add($path)) { throw "Entree dupliquee : $path" }
        $totalUncompressed += [long]$entry.Length
        if ($totalUncompressed -gt 2GB) { throw 'Archive ZIP trop volumineuse une fois decompressee.' }
        if ($path.Split('/')[-1] -ieq 'EXDEV_RGB_INSTALLER.exe') { $installer = $true }
    }
    if (-not $installer) { throw 'Installateur EXDEV_RGB_INSTALLER.exe absent du ZIP.' }
    Write-Host 'CONTROLE OK — empreinte, taille et structure ZIP concordent.' -ForegroundColor Green
    Write-Host "SHA-256 : $hash"
    Write-Host "Fichiers dans le ZIP : $($zip.Entries.Count)"
    Write-Host 'ATTENTION : ceci ne valide ni la signature, ni le demarrage sous Windows, ni le fonctionnement RGB.'
} finally { $zip.Dispose() }