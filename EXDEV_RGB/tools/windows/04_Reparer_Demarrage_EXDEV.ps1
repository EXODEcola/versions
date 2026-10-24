#requires -Version 5.1
<#
.EXDEV RGB 1.6.11 startup repair (manual, reversible)
Default: preview only. -Apply: back up and remove only two known stale Run values.
-Restore -BackupFile path: restore the values from the backup.
The installed EXDEV RGB launcher and Native Engine task are not modified.
#>
[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$Restore,
    [string]$BackupFile,
    [string]$BackupRoot = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'EXDEV_RGB_Diagnostics\Autoruns')
)
$ErrorActionPreference='Stop'
if ($Apply -and $Restore) { throw 'Choose -Apply OR -Restore, not both.' }
$key = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
$allowed = @(
    [pscustomobject]@{ Name = 'electron.app.Electron'; Markers = @('EXDEV_RGB_Native_v0.2', 'node_modules\electron\dist\electron.exe') },
    [pscustomobject]@{ Name = 'electron.app.EXDEV RGB Companion'; Markers = @('EXDEV RGB Companion\EXDEV RGB Companion.exe') }
)
function Read-RunValue([string]$name) {
    $values = Get-ItemProperty -LiteralPath $key -ErrorAction Stop
    $p = $values.PSObject.Properties[$name]
    if ($null -eq $p) { return $null }
    return [string]$p.Value
}
function Is-Recognized([string]$name,[string]$command) {
    foreach ($rule in $allowed) {
        if ($rule.Name -cne $name) { continue }
        foreach ($marker in $rule.Markers) {
            if ($command.IndexOf($marker,[StringComparison]::OrdinalIgnoreCase) -lt 0) { return $false }
        }
        return $true
    }
    return $false
}
if ($Restore) {
    if ([string]::IsNullOrWhiteSpace($BackupFile) -or -not (Test-Path -LiteralPath $BackupFile -PathType Leaf)) { throw 'Provide an existing -BackupFile.' }
    $record = Get-Content -LiteralPath $BackupFile -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($record.Schema -ne 'EXDEV RGB Legacy Run Backup v1' -or @($record.Entries).Count -eq 0) { throw 'Not an EXDEV startup backup.' }
    foreach ($entry in @($record.Entries)) {
        $name=[string]$entry.Name; $command=[string]$entry.Command
        if (-not (Is-Recognized $name $command)) { throw "Unrecognized backup value: $name" }
        $existing=Read-RunValue $name
        if ($null -ne $existing -and $existing -cne $command) { throw "Run value $name already exists with a different target; refusing overwrite." }
    }
    foreach ($entry in @($record.Entries)) { New-ItemProperty -LiteralPath $key -Name ([string]$entry.Name) -Value ([string]$entry.Command) -PropertyType String -Force | Out-Null }
    Write-Host 'Legacy entries restored from backup. You may see multiple EXDEV launches again at next sign-in.' -ForegroundColor Yellow
    return
}
if (-not (Test-Path -LiteralPath $key)) { Write-Host 'No user Run registry key exists. No changes.'; return }
$matches=@()
foreach ($rule in $allowed) {
    $current=Read-RunValue $rule.Name
    if ($null -eq $current) { continue }
    if (-not (Is-Recognized $rule.Name $current)) {
        Write-Warning "Run value '$($rule.Name)' exists but targets something unexpected; it will NOT be removed."
        continue
    }
    $matches += [pscustomobject]@{ Name = $rule.Name; Command = $current }
}
$main = Read-RunValue 'fr.exdev.rgbcompanion'
if ($null -eq $main) { Write-Warning 'Canonical fr.exdev.rgbcompanion Run value was NOT detected. Main autostart requires manual review.' }
else { Write-Host "Official Run value kept unchanged: fr.exdev.rgbcompanion -> $main" }
Write-Host "Recognized old Run values: $($matches.Count)"
foreach ($item in $matches) { Write-Host " - $($item.Name) -> $($item.Command)" }
if ($matches.Count -eq 0) { Write-Host 'Nothing to repair.'; return }
if (-not $Apply) { Write-Host 'PREVIEW ONLY: no changes. Run again with -Apply to back up and disable ONLY these recognized values.' -ForegroundColor Cyan; return }
if (-not $main -or $main.IndexOf('EXDEV RGB.exe',[StringComparison]::OrdinalIgnoreCase) -lt 0) {
    throw 'Canonical autostart path not confirmed. Aborting without modifications.'
}
New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$backup=Join-Path $BackupRoot "EXDEV_RGB_Legacy_Run_$stamp.json"
$payload=[ordered]@{ Schema='EXDEV RGB Legacy Run Backup v1'; Created=(Get-Date).ToString('o'); Registry=$key; Entries=@($matches) }
$payload | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $backup -Encoding UTF8 -ErrorAction Stop
$verified=Get-Content -LiteralPath $backup -Raw -Encoding UTF8 | ConvertFrom-Json
if (@($verified.Entries).Count -ne $matches.Count) { throw 'Backup validation failed; no registry value removed.' }
foreach ($item in $matches) {
    $current=Read-RunValue $item.Name
    if ($null -eq $current -or $current -cne $item.Command) { throw "Run value changed during operation; refused to remove $($item.Name). Backup kept: $backup" }
    Remove-ItemProperty -LiteralPath $key -Name $item.Name -ErrorAction Stop
    Write-Host "Disabled old app launcher: $($item.Name)" -ForegroundColor Green
}
Write-Host "BACKUP: $backup" -ForegroundColor Green
Write-Host 'Leave the EXDEV RGB Native Engine task, PawnIO, installed files and profile directory untouched.'
Write-Host 'Close EXDEV RGB normally and sign out/in to test startup. In case of a regression, restore with -Restore -BackupFile <path>.'