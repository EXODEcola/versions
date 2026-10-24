#requires -Version 5.1
$ErrorActionPreference='Stop'
$root=Join-Path $env:TEMP ('EXDEV_RGB_NATIVE_TEST_'+[guid]::NewGuid().ToString('N'))
try {
  $install=Join-Path $root 'install'
  $out=Join-Path $root 'out'
  foreach($dir in @((Join-Path $install 'Lib\Native'),(Join-Path $install 'Lib\Source\_developer'),$out)){New-Item -ItemType Directory -Path $dir -Force | Out-Null}
  'TEST_BRIDGE' | Set-Content -LiteralPath (Join-Path $install 'Lib\Native\EXDEV_RGB_BRIDGE.exe')
  'TEST_INSTALLER' | Set-Content -LiteralPath (Join-Path $install 'EXDEV_RGB_INSTALLER.exe')
  'SECRET - NOT TO EXPORT' | Set-Content -LiteralPath (Join-Path $install 'Lib\Native\engine.token')
  'package main' | Set-Content -LiteralPath (Join-Path $install 'Lib\Source\_developer\bridge.go')
  'package main' | Set-Content -LiteralPath (Join-Path $install 'Lib\Source\_developer\installer_wrapper.go')
  & (Join-Path $PSScriptRoot '07_Recuperer_Composants_Manquants.ps1') -InstallRoot $install -OutputDirectory $out
  $zip=Get-ChildItem -LiteralPath $out -Filter '*.zip' | Select-Object -First 1
  if (-not $zip) {throw 'No ZIP created'}
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive=[IO.Compression.ZipFile]::OpenRead($zip.FullName)
  try{
    $names=@($archive.Entries|ForEach-Object{$_.FullName.Replace([char]92,[char]47)})
    foreach($needed in @('Sources_Go/bridge.go','Sources_Go/installer_wrapper.go','Binaires_anciens/EXDEV_RGB_BRIDGE.exe','Binaires_anciens/EXDEV_RGB_INSTALLER.exe','INVENTAIRE.json')){
      if($names -notcontains $needed){throw "Missing $needed; zip entries: $($names -join ', ')"}
    }
    if ($names | Where-Object {$_ -match '(?i)engine\.token|secret'}){throw 'Sensitive file was exported'}
  }finally{$archive.Dispose()}
  if (-not (Test-Path -LiteralPath (Join-Path $install 'Lib\Native\engine.token'))){throw 'Original token deleted'}
  Write-Host 'PASS: native components recovery (non destructive)' -ForegroundColor Green
}finally{if (Test-Path -LiteralPath $root){Remove-Item -LiteralPath $root -Recurse -Force}}