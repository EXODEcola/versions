#requires -Version 5.1
<# EXDEV RGB - Windows read-only diagnostic (1.6.11)
   Does not install, delete, modify services, drivers, registry or hardware settings.
#>
[CmdletBinding()]
param(
    [string] $OutputRoot = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'EXDEV_RGB_Diagnostics')
)
$ErrorActionPreference = 'Stop'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$output = Join-Path $OutputRoot $stamp
New-Item -ItemType Directory -Force -Path $output | Out-Null
$errors = New-Object System.Collections.Generic.List[string]
$lookupPattern = '(?i)EXDEV[ _-]*RGB|EXDEV_RGB|EXDEV\\RGB'
function Try-Collect([string]$Name, [scriptblock]$Action) {
    try { return @(& $Action) } catch {
        $script:errors.Add("$Name : $($_.Exception.Message)")
        return @()
    }
}
function Short-Path([string]$Value) {
    if (-not $Value) { return $Value }
    $s = $Value
    foreach ($entry in @(@($env:USERPROFILE,'%USERPROFILE%'),@($env:APPDATA,'%APPDATA%'),@($env:LOCALAPPDATA,'%LOCALAPPDATA%'))) {
        if ($entry[0]) { $s = $s.Replace([string]$entry[0],[string]$entry[1]) }
    }
    return $s
}

$version = '1.6.11-audit.1'
$installDirs = New-Object System.Collections.Generic.List[string]
foreach ($root in @(${env:ProgramFiles(x86)},$env:ProgramFiles,$env:LOCALAPPDATA,$env:APPDATA)) {
    if (-not $root) { continue }
    foreach ($suffix in @('EXDEV RGB','EXDEV_RGB','exdev-rgb')) {
        $candidate = Join-Path $root $suffix
        if ((Test-Path -LiteralPath $candidate) -and -not $installDirs.Contains($candidate)) { $installDirs.Add($candidate) }
    }
}
$installRecords = @(Try-Collect 'uninstall registry' {
    $roots = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
               'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
               'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall')
    foreach ($root in $roots) {
        if (-not (Test-Path $root)) { continue }
        foreach ($item in (Get-ChildItem -Path $root -ErrorAction SilentlyContinue)) {
            $p = Get-ItemProperty -LiteralPath $item.PSPath -ErrorAction SilentlyContinue
            if ($p.DisplayName -match $lookupPattern) {
                [pscustomobject]@{ Name=[string]$p.DisplayName; Version=[string]$p.DisplayVersion;
                    InstallLocation=(Short-Path ([string]$p.InstallLocation)); Registry=$item.Name }
                if ($p.InstallLocation -and (Test-Path -LiteralPath $p.InstallLocation) -and
                    -not $installDirs.Contains([string]$p.InstallLocation)) { $installDirs.Add([string]$p.InstallLocation) }
            }
        }
    }
})

$executables = @(Try-Collect 'executables' {
    foreach ($dir in $installDirs) {
        if (-not (Test-Path -LiteralPath $dir -PathType Container)) { continue }
        Get-ChildItem -LiteralPath $dir -Recurse -File -Filter '*.exe' -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '(?i)EXDEV|RGB|BRIDGE|INSTALLER' } |
            Select-Object -First 35 |
            ForEach-Object {
                $vi = $_.VersionInfo
                [pscustomobject]@{
                    Path=(Short-Path $_.FullName); Name=$_.Name
                    FileVersion=[string]$vi.FileVersion; ProductVersion=[string]$vi.ProductVersion
                    Bytes=$_.Length; Modified=$_.LastWriteTime.ToString('s')
                    SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
                }
            }
    }
})

$processes = @(Try-Collect 'process list' {
    Get-CimInstance Win32_Process | Where-Object {
        $_.Name -match '(?i)EXDEV|pawnio' -or ($_.ExecutablePath -and $_.ExecutablePath -match $lookupPattern)
    } | ForEach-Object {
        [pscustomobject]@{ Name=$_.Name; PID=$_.ProcessId; Executable=(Short-Path $_.ExecutablePath) }
    }
})

$autorun = @(Try-Collect 'Run registry' {
    $roots = @('HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
      'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
      'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run')
    foreach ($root in $roots) {
        if (-not (Test-Path $root)) { continue }
        $properties = (Get-ItemProperty -Path $root).PSObject.Properties
        foreach ($property in $properties) {
            if ($property.Name -match '^PS(Path|ParentPath|ChildName|Drive|Provider)$') { continue }
            if (([string]$property.Name -match $lookupPattern) -or
                ([string]$property.Value -match $lookupPattern)) {
                [pscustomobject]@{ Hive=$root; Name=$property.Name; Command=(Short-Path ([string]$property.Value)) }
            }
        }
    }
})

$shortcuts = @(Try-Collect 'startup shortcuts' {
    $shell = New-Object -ComObject WScript.Shell
    $folders = @([Environment]::GetFolderPath('Startup'),[Environment]::GetFolderPath('CommonStartup'))
    foreach ($folder in $folders) {
        if (-not $folder -or -not (Test-Path -LiteralPath $folder)) { continue }
        foreach ($file in (Get-ChildItem -LiteralPath $folder -Filter '*.lnk' -File -ErrorAction SilentlyContinue)) {
            $link = $shell.CreateShortcut($file.FullName)
            if ($file.Name -match $lookupPattern -or $link.TargetPath -match $lookupPattern) {
                [pscustomobject]@{ Shortcut=(Short-Path $file.FullName); Target=(Short-Path $link.TargetPath);
                    Arguments=[string]$link.Arguments }
            }
        }
    }
})

$tasks = @(Try-Collect 'scheduled tasks' {
    Get-ScheduledTask -ErrorAction Stop | ForEach-Object {
        $task = $_
        $act = @($task.Actions | ForEach-Object { "$( $_.Execute ) $( $_.Arguments )" }) -join ' | '
        if ($task.TaskName -match $lookupPattern -or $act -match $lookupPattern) {
            [pscustomobject]@{ Name=$task.TaskName; Path=$task.TaskPath; State=[string]$task.State;
                Command=(Short-Path $act); IsNativeEngine=[bool]($task.TaskName -match '(?i)native.*engine|engine.*native') }
        }
    }
})

$services = @(Try-Collect 'services and drivers' {
    Get-CimInstance Win32_Service | Where-Object {
        $_.Name -match '(?i)EXDEV|pawnio' -or $_.DisplayName -match '(?i)EXDEV|pawnio'
    } | ForEach-Object {
        [pscustomobject]@{ Name=$_.Name; DisplayName=$_.DisplayName; State=$_.State;
            StartMode=$_.StartMode; Executable=(Short-Path $_.PathName) }
    }
    Get-CimInstance Win32_SystemDriver | Where-Object {
        $_.Name -match '(?i)pawnio|EXDEV' -or $_.DisplayName -match '(?i)pawnio|EXDEV'
    } | ForEach-Object {
        [pscustomobject]@{ Name=$_.Name; DisplayName=$_.DisplayName; State=$_.State;
            StartMode=$_.StartMode; Executable=(Short-Path $_.PathName) }
    }
})

$ram = @(Try-Collect 'physical DIMM info' {
    Get-CimInstance Win32_PhysicalMemory | ForEach-Object {
        [pscustomobject]@{ BankLabel=$_.BankLabel; DeviceLocator=$_.DeviceLocator;
            Manufacturer=$_.Manufacturer; PartNumber=([string]$_.PartNumber).Trim();
            SizeGB=[math]::Round($_.Capacity / 1GB,1); SMBIOSMemoryType=$_.SMBIOSMemoryType }
    }
})

$settings = @(Try-Collect 'configuration directory inventory' {
    foreach ($root in @($env:APPDATA,$env:LOCALAPPDATA)) {
        if (-not $root) { continue }
        foreach ($sub in @('EXDEV RGB','EXDEV_RGB','exdev-rgb')) {
            $dir = Join-Path $root $sub
            if (Test-Path -LiteralPath $dir -PathType Container) {
                $files = @(Get-ChildItem -LiteralPath $dir -Recurse -File -ErrorAction SilentlyContinue)
                [pscustomobject]@{ Path=(Short-Path $dir); FileCount=$files.Count;
                    TotalMB=[math]::Round((($files | Measure-Object Length -Sum).Sum / 1MB),1) }
            }
        }
    }
})

$nativeFiles = @(Try-Collect 'Native diagnostics' {
    foreach ($dir in $installDirs) {
        foreach ($relative in @('Lib\Native\hardware-status.json','Lib\Native\ram-smbus-debug.log',
                                'hardware-status.json','ram-smbus-debug.log')) {
            $candidate = Join-Path $dir $relative
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                $file = Get-Item -LiteralPath $candidate
                [pscustomobject]@{ Path=(Short-Path $file.FullName); Bytes=$file.Length;
                    Modified=$file.LastWriteTime.ToString('s') }
            }
        }
    }
})

$report = [ordered]@{
    ToolkitVersion = $version; Timestamp=(Get-Date).ToString('o')
    WindowsVersion = [Environment]::OSVersion.VersionString; PowerShell=$PSVersionTable.PSVersion.ToString()
    InstallRecords = $installRecords; Executables = $executables; Processes = $processes
    RegistryAutoruns = $autorun; StartupShortcuts=$shortcuts; ScheduledTasks=$tasks
    ServicesAndDrivers=$services; PhysicalDIMMs=$ram; SettingsDirectories=$settings
    NativeLogs=$nativeFiles; CollectionErrors=@($errors)
}
$jsonPath = Join-Path $output 'audit.json'
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
$duplicates = @($autorun).Count + @($shortcuts).Count + @($tasks | Where-Object { -not $_.IsNativeEngine }).Count
$runningLegacy = @($processes | Where-Object { $_.Name -match '(?i)EXDEV' -and $_.Executable -match '1[._]6[._]8' }).Count
$notes = @(
    'EXDEV RGB - audit local en lecture seule',
    "Rapport : $jsonPath",
    "Exe trouves : $($executables.Count)",
    "Entre(es) Run : $($autorun.Count); raccourcis Startup : $($shortcuts.Count); taches EXDEV applicatives : $(@($tasks | Where-Object { -not $_.IsNativeEngine }).Count)",
    "Total declencheurs app potentiels : $duplicates (une investigation est necessaire s'il y en a plusieurs)",
    "Barrettes physiques SMBIOS : $($ram.Count)",
    "Processus correspondant aux anciens chemins 1.6.8 : $runningLegacy (estimation indicative)",
    "Erreurs de collecte : $($errors.Count)",
    'Aucune modification n a ete effectuee.',
    'IMPORTANT : relire audit.json avant de le partager ; noms de PC, chemins et informations locales peuvent apparaitre.'
)
$notes | Set-Content -LiteralPath (Join-Path $output 'LIRE-MOI.txt') -Encoding UTF8
$notes | ForEach-Object { Write-Host $_ }