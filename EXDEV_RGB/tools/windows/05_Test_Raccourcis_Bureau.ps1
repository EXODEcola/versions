# Windows CI tests using synthetic .exe files and .lnk shortcuts: no real software affected.
$ErrorActionPreference = 'Stop'
$testRoot = Join-Path $env:RUNNER_TEMP ('exdev-shortcuts-' + [guid]::NewGuid().ToString('N'))
$desktop = Join-Path $testRoot 'Desktop'
$install = Join-Path $testRoot 'Current\EXDEV RGB'
$legacy = Join-Path $testRoot 'Old\EXDEV RGB'
$backup = Join-Path $testRoot 'Backups'
New-Item -ItemType Directory -Force -Path $desktop,$install,$legacy | Out-Null
$canonical = Join-Path $install 'EXDEV RGB.exe'
$old = Join-Path $legacy 'EXDEV RGB.exe'
Set-Content -LiteralPath $canonical -Value 'test canonical executable placeholder'
Set-Content -LiteralPath $old -Value 'test legacy executable placeholder'
$wsh = New-Object -ComObject WScript.Shell
$path = Join-Path $desktop 'EXDEV RGB.lnk'
$s = $wsh.CreateShortcut($path)
$s.TargetPath = $old
$s.WorkingDirectory = $legacy
$s.Description = 'My RGB desktop icon'
$s.IconLocation = "$old,0"
$s.Save()
$unrelated = Join-Path $desktop 'Unrelated.lnk'
$s = $wsh.CreateShortcut($unrelated)
$s.TargetPath = "$env:WINDIR\System32\notepad.exe"
$s.Save()
$namedUnrelated = Join-Path $desktop 'EXDEV RGB - unrelated.lnk'
$s = $wsh.CreateShortcut($namedUnrelated)
$s.TargetPath = "$env:WINDIR\System32\notepad.exe"
$s.Save()
$script = Join-Path $PSScriptRoot '05_Maintenir_Raccourcis_Bureau.ps1'
try {
    & $script -DesktopRoots @($desktop) -CanonicalExecutable $canonical -BackupRoot $backup
    if ($wsh.CreateShortcut($path).TargetPath -ine $old) { throw 'Dry-run changed the shortcut.' }
    if (Test-Path -LiteralPath $backup) { throw 'Dry-run unexpectedly generated backups.' }
    & $script -Apply -DesktopRoots @($desktop) -CanonicalExecutable $canonical -BackupRoot $backup
    if ($wsh.CreateShortcut($path).TargetPath -ine $canonical) { throw 'Apply did not retarget existing shortcut.' }
    if ($wsh.CreateShortcut($unrelated).TargetPath -ine "$env:WINDIR\System32\notepad.exe") { throw 'Unrelated shortcut changed.' }
    if ($wsh.CreateShortcut($namedUnrelated).TargetPath -ine "$env:WINDIR\System32\notepad.exe") { throw 'Named unrelated shortcut changed.' }
    if (@(Get-ChildItem -LiteralPath $desktop -Filter '*.lnk').Count -ne 3) { throw 'Unexpected additional or deleted shortcuts.' }
    $manifest = @(Get-ChildItem -LiteralPath $backup -Filter 'shortcuts-backup.json' -Recurse)
    if ($manifest.Count -ne 1) { throw 'Exactly one backup manifest expected.' }
    & $script -Apply -DesktopRoots @($desktop) -CanonicalExecutable $canonical -BackupRoot $backup
    if (@(Get-ChildItem -LiteralPath $backup -Filter 'shortcuts-backup.json' -Recurse).Count -ne 1) { throw 'Idempotent run wrote duplicate backup.' }
    & $script -Restore -BackupFile $manifest[0].FullName -DesktopRoots @($desktop) -BackupRoot $backup
    if ($wsh.CreateShortcut($path).TargetPath -ine $old) { throw 'Restore did not restore original shortcut.' }
    $emptyDesktop = Join-Path $testRoot 'EmptyDesktop'
    New-Item -ItemType Directory -Force -Path $emptyDesktop | Out-Null
    & $script -Apply -DesktopRoots @($emptyDesktop) -CanonicalExecutable $canonical -BackupRoot $backup
    if (@(Get-ChildItem -LiteralPath $emptyDesktop -Force).Count -ne 0) { throw 'A shortcut was created without consent.' }
    Write-Host 'PASS: preview, apply, rollback, idempotence, unrelated shortcuts, opt-out desktop.'
} finally {
    Remove-Item -LiteralPath $testRoot -Force -Recurse -ErrorAction SilentlyContinue
}