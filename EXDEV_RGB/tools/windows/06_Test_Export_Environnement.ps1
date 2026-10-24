#requires -Version 5.1
$ErrorActionPreference='Stop'
$root=Join-Path $env:TEMP ('EXDEV-RGB-SOURCE-TEST-' + [guid]::NewGuid().ToString('N'))
try {
 $source=Join-Path $root 'Source'
 $output=Join-Path $root 'output'
 New-Item -ItemType Directory -Force -Path (Join-Path $source 'src'), (Join-Path $source 'node_modules'), (Join-Path $source 'dist\win-unpacked\resources'), $output | Out-Null
 'console.log("valid source")' | Set-Content -LiteralPath (Join-Path $source 'src\index.ts')
 '{"name":"EXDEV RGB"}' | Set-Content -LiteralPath (Join-Path $source 'package.json')
 'SECRET=DO_NOT_COPY' | Set-Content -LiteralPath (Join-Path $source '.env')
 'NOT_SOURCE' | Set-Content -LiteralPath (Join-Path $source 'node_modules\junk.ts')
 'FAKE_ASAR' | Set-Content -LiteralPath (Join-Path $source 'dist\win-unpacked\resources\app.asar')
 & (Join-Path $PSScriptRoot '06_Exporter_Sources_EXDEV.ps1') -SourceDirectory $source -OutputDirectory $output
 $zipfile=Get-ChildItem -LiteralPath $output -Filter '*.zip' | Select-Object -First 1
 if (-not $zipfile) { throw 'ZIP non créé' }
 Add-Type -AssemblyName System.IO.Compression.FileSystem
 $z=[IO.Compression.ZipFile]::OpenRead($zipfile.FullName)
 try {
   $names=@($z.Entries | ForEach-Object { $_.FullName.Replace('\','/') })
   if ($names -notcontains 'Source/src/index.ts') { throw 'Le fichier TypeScript est absent' }
   if ($names -notcontains 'Source/package.json') { throw 'Le package.json est absent' }
   if (@($names | Where-Object { $_ -match 'node_modules|\.env|app\.asar' }).Count -gt 0) { throw 'Des fichiers exclus ont été collectés' }
 } finally { $z.Dispose() }
 & (Join-Path $PSScriptRoot '06_Exporter_Sources_EXDEV.ps1') -SourceDirectory $source -OutputDirectory $output -IncludeAppAsar
 $newZip=Get-ChildItem -LiteralPath $output -Filter '*.zip' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
 $z=[IO.Compression.ZipFile]::OpenRead($newZip.FullName)
 try {
  if (@($z.Entries | Where-Object { $_.FullName.Replace('\','/') -eq 'PackagedElectron/app.asar' }).Count -lt 1) { throw 'L''option ASAR n''a pas fonctionné' }
 } finally { $z.Dispose() }
 Write-Host 'Tests source export OK'
} finally { if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force } }