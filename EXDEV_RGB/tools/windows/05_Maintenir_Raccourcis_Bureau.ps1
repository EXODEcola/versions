#requires -Version 5.1
<#
.SYNOPSIS
  EXDEV RGB: reconcile only existing desktop shortcuts after a verified upgrade.
.DESCRIPTION
  Default preview does not modify anything. -Apply backs up recognized .lnk
  files before retargeting them to the canonical EXDEV RGB.exe. No shortcut is
  created if the user has deleted it. -Restore can restore originals safely.
  No process, service, native driver, scheduled task or RGB setting is touched.
  This is a Windows installer helper, not a replacement for a signed installer.
.EXAMPLE
  .\05_Maintenir_Raccourcis_Bureau.ps1
.EXAMPLE
  .\05_Maintenir_Raccourcis_Bureau.ps1 -Apply
#>
[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$Restore,
    [string]$BackupFile,
    [string]$CanonicalExecutable,
    [string]$BackupRoot = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'EXDEV_RGB_Diagnostics\ShortcutBackups'),
    [string[]]$DesktopRoots
)
$ErrorActionPreference = 'Stop'
if ($Apply -and $Restore) { throw 'Use -Apply or -Restore, not both.' }

function Normalize-Path([string]$p) {
    if ([string]::IsNullOrWhiteSpace($p)) { return '' }
    $expanded = [Environment]::ExpandEnvironmentVariables($p.Trim().Trim('"'))
    try { return [IO.Path]::GetFullPath($expanded).TrimEnd('\') }
    catch { return '' }
}
function Resolve-Canonical {
    if (-not [string]::IsNullOrWhiteSpace($CanonicalExecutable)) {
        return (Normalize-Path $CanonicalExecutable)
    }
    # The product's uninstall key is the installation authority; do not guess a
    # version from a stale shortcut or a ZIP extraction directory.
    $keys = @(
      'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\EXDEV RGB',
      'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\EXDEV RGB',
      'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\EXDEV RGB'
    )
    foreach ($key in $keys) {
        $item = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
        if ($null -eq $item -or [string]::IsNullOrWhiteSpace([string]$item.InstallLocation)) { continue }
        $exe = Normalize-Path (Join-Path ([string]$item.InstallLocation) 'EXDEV RGB.exe')
        if ($exe -and (Test-Path -LiteralPath $exe -PathType Leaf)) { return $exe }
    }
    return ''
}
function Is-ExdevShortcut([string]$linkName, [string]$target) {
    $target = Normalize-Path $target
    if (-not $target) { return $false }
    $file = [IO.Path]::GetFileName($target)
    if ($file -ieq 'EXDEV RGB.exe') {
        # Exact application executable name plus recognizable EXDEV directory.
        return ($target -match '(?i)[\\/](EXDEV RGB|EXDEV_RGB(?:[_-][^\\/]+)?)[\\/]')
    }
    if ($file -ieq 'EXDEV RGB Companion.exe' -and $linkName -match '(?i)^EXDEV RGB(?:\b|\s)') {
        return ($target -match '(?i)[\\/]EXDEV RGB Companion[\\/]')
    }
    return $false
}
function Get-Roots {
    $values = if ($null -ne $DesktopRoots -and $DesktopRoots.Count -gt 0) {
        @($DesktopRoots)
    } else {
        @([Environment]::GetFolderPath('DesktopDirectory'), [Environment]::GetFolderPath('CommonDesktopDirectory'))
    }
    return @($values | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { Normalize-Path $_ } | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) } |
        Select-Object -Unique)
}
function Within-Roots([string]$path, [string[]]$roots) {
    $normalized = Normalize-Path $path
    foreach ($root in $roots) {
        # Immediate children only: intentional safeguard against arbitrary restores.
        if ([IO.Path]::GetDirectoryName($normalized) -ieq $root) { return $true }
    }
    return $false
}
$roots = @(Get-Roots)
if ($roots.Count -eq 0) { throw 'No existing Windows desktop directory found.' }
$canonical = Resolve-Canonical
if (-not $Restore -and (-not $canonical -or [IO.Path]::GetFileName($canonical) -ine 'EXDEV RGB.exe' -or
    -not (Test-Path -LiteralPath $canonical -PathType Leaf))) {
    throw 'Canonical EXDEV RGB.exe not found in the installed product directory. No changes.'
}

$wsh = New-Object -ComObject WScript.Shell
if ($Restore) {
    if (-not $BackupFile -or -not (Test-Path -LiteralPath $BackupFile -PathType Leaf)) { throw 'Provide -BackupFile pointing to an existing backup manifest.' }
    $record = Get-Content -LiteralPath $BackupFile -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($record.Schema -ne 'EXDEV RGB Desktop Shortcut Backup v1' -or @($record.Entries).Count -eq 0) { throw 'Unrecognized EXDEV RGB shortcut backup.' }
    $base = [IO.Path]::GetDirectoryName((Normalize-Path $BackupFile))
    # Validate every item before modifying any item.
    foreach ($entry in @($record.Entries)) {
        $path = Normalize-Path ([string]$entry.Path)
        $name = [string]$entry.BackupName
        if (-not (Within-Roots $path $roots) -or [IO.Path]::GetExtension($path) -ine '.lnk' -or
            $name -notmatch '^[a-f0-9]{32}\.lnk$') { throw 'Unsafe backup entry; refusing restoration.' }
        $source = Join-Path $base $name
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing backup shortcut: $name" }
        $hash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
        if ($hash -ine [string]$entry.SHA256) { throw "Backup hash mismatch: $name" }
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Current shortcut missing; refusing to overwrite: $path" }
        $current = $wsh.CreateShortcut($path)
        if ((Normalize-Path $current.TargetPath) -ine (Normalize-Path ([string]$record.CanonicalExecutable))) {
            throw "Shortcut changed since repair; refusing overwrite: $path"
        }
    }
    foreach ($entry in @($record.Entries)) {
        Copy-Item -LiteralPath (Join-Path $base ([string]$entry.BackupName)) -Destination ([string]$entry.Path) -Force
        Write-Host "Restored: $($entry.Path)" -ForegroundColor Green
    }
    return
}

$matches = @()
foreach ($root in $roots) {
    foreach ($file in @(Get-ChildItem -LiteralPath $root -File -Filter '*.lnk' -ErrorAction SilentlyContinue)) {
        try {
            $link = $wsh.CreateShortcut($file.FullName)
            $oldTarget = Normalize-Path ([string]$link.TargetPath)
            if (-not (Is-ExdevShortcut $file.BaseName $oldTarget)) { continue }
            if ($oldTarget -ieq $canonical) { continue }
            $matches += [pscustomobject]@{ Path=$file.FullName; OldTarget=$oldTarget; NewTarget=$canonical }
        } catch { Write-Warning "Skipping unreadable shortcut $($file.FullName): $_" }
    }
}
Write-Host "EXDEV RGB Desktop shortcuts requiring migration: $($matches.Count)"
foreach ($item in $matches) { Write-Host " - $($item.Path)`n     from: $($item.OldTarget)`n       to: $($item.NewTarget)" }
if ($matches.Count -eq 0) { Write-Host 'No changes needed. No shortcut will be created.'; return }
if (-not $Apply) { Write-Host 'PREVIEW ONLY. Run with -Apply after a verified application upgrade.' -ForegroundColor Cyan; return }

# Back up originals first. Do not modify any shortcut unless *all* backups exist.
$backupDir = Join-Path $BackupRoot (Get-Date -Format 'yyyyMMdd-HHmmss-fff')
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
$entries = @()
foreach ($item in $matches) {
    $filename = ([guid]::NewGuid().ToString('N') + '.lnk')
    $backupPath = Join-Path $backupDir $filename
    Copy-Item -LiteralPath $item.Path -Destination $backupPath -ErrorAction Stop
    $entries += [pscustomobject]@{ Path=$item.Path; BackupName=$filename; SHA256=(Get-FileHash -LiteralPath $backupPath -Algorithm SHA256).Hash; OldTarget=$item.OldTarget }
}
$manifestPath = Join-Path $backupDir 'shortcuts-backup.json'
$manifest = [ordered]@{ Schema='EXDEV RGB Desktop Shortcut Backup v1'; Date=(Get-Date).ToString('o'); CanonicalExecutable=$canonical; Entries=$entries }
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
$check = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (@($check.Entries).Count -ne $matches.Count) { throw 'Backup manifest verification failed: no shortcut changed.' }

$changed = @()
try {
    foreach ($item in $matches) {
        $shortcut = $wsh.CreateShortcut($item.Path)
        if ((Normalize-Path $shortcut.TargetPath) -ine $item.OldTarget) { throw "Shortcut was modified externally: $($item.Path)" }
        $shortcut.TargetPath = $canonical
        $shortcut.WorkingDirectory = Split-Path -Parent $canonical
        # Keep custom shortcut name, hotkey and description; replace icon only
        # when it used the obsolete EXDEV binary or had no icon.
        if ([string]::IsNullOrWhiteSpace([string]$shortcut.IconLocation) -or
            ([string]$shortcut.IconLocation -match '(?i)EXDEV')) {
            $shortcut.IconLocation = "$canonical,0"
        }
        # Legacy Companion's Electron flags must not be carried to the new app.
        if ($item.OldTarget -match '(?i)EXDEV RGB Companion\.exe$') { $shortcut.Arguments = '' }
        $shortcut.Save()
        $changed += $item.Path
        Write-Host "Updated: $($item.Path)" -ForegroundColor Green
    }
} catch {
    $err = $_
    foreach ($path in $changed) {
        $entry = $entries | Where-Object { $_.Path -eq $path } | Select-Object -First 1
        if ($entry) { Copy-Item -LiteralPath (Join-Path $backupDir $entry.BackupName) -Destination $path -Force }
    }
    throw "Shortcut migration failed; changed shortcuts rolled back: $err"
}
Write-Host "BACKUP: $manifestPath" -ForegroundColor Green
Write-Host 'Existing EXDEV shortcuts repaired. No new shortcut created; installed app, Native Engine, profiles and FAN LOCK unchanged.'