param(
  [Parameter(Mandatory=$true)][string]$RootDir,
  [Parameter(Mandatory=$true)][string]$LogFile,
  [switch]$ElevatedChild
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$nativeDir = Join-Path $RootDir 'Lib\Native'
$pawnDir = Join-Path $nativeDir 'PawnIO'
$thirdParty = Join-Path $RootDir 'Lib\ThirdParty\PawnIO'
$statusPath = Join-Path $nativeDir 'hardware-status.json'
$tokenPath = Join-Path $nativeDir 'engine.token'
$bridgePath = Join-Path $nativeDir 'EXDEV_RGB_BRIDGE.exe'
$taskName = 'EXDEV RGB Native Engine'
$enginePort = 47651
$setupUrl = 'https://github.com/namazso/PawnIO.Setup/releases/download/2.2.0/PawnIO_setup.exe'
$setupSha = '1F519A22E47187F70A1379A48CA604981C4FCF694F4E65B734AAA74A9FBA3032'
$modulesUrl = 'https://github.com/namazso/PawnIO.Modules/releases/download/0.2.11/release_0_2_11.zip'
$modulesSha = '43608CB89BC84247FEF1368A139013F7D043E17DB6D6C8DFC9B46BF0905A81F4'

New-Item -ItemType Directory -Force -Path $pawnDir,$thirdParty,(Split-Path -Parent $LogFile) | Out-Null

function Log([string]$text) {
  $line = '[EXDEV Hardware] ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' ' + $text
  Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
}
function Is-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p = New-Object Security.Principal.WindowsPrincipal($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Driver-Installed {
  try {
    $svc = Get-CimInstance Win32_SystemDriver -Filter "Name='PawnIO'" -ErrorAction Stop
    if($svc) { return $true }
  } catch {}
  try {
    $pnp = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -match '^ROOT\\PAWNIO' -or $_.FriendlyName -match '^PawnIO' } | Select-Object -First 1
    if($pnp) { return $true }
  } catch {}
  return $false
}
function Task-Exists {
  try { return [bool](Get-ScheduledTask -TaskName $taskName -ErrorAction Stop) } catch { return $false }
}
function Task-NeedsUpdate {
  try {
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
    $action = @($task.Actions)[0]
    if(-not $action) { return $true }
    $actualExe = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables([string]$action.Execute)).TrimEnd('\')
    $wantedExe = [IO.Path]::GetFullPath($bridgePath).TrimEnd('\')
    $actualWd = [string]$action.WorkingDirectory
    if($actualExe -ine $wantedExe) { return $true }
    if([string]::IsNullOrWhiteSpace($actualWd)) { return $true }
    if([IO.Path]::GetFullPath($actualWd).TrimEnd('\') -ine [IO.Path]::GetFullPath($RootDir).TrimEnd('\')) { return $true }
    return $false
  } catch { return $true }
}
function Download-Verified([string]$url,[string]$destination,[string]$sha256) {
  if(Test-Path $destination) {
    try { if((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToUpperInvariant() -eq $sha256) { return } } catch {}
    Remove-Item -LiteralPath $destination -Force -ErrorAction SilentlyContinue
  }
  Log "Download $url"
  Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $destination
  $actual = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToUpperInvariant()
  if($actual -ne $sha256) {
    Remove-Item -LiteralPath $destination -Force -ErrorAction SilentlyContinue
    throw "SHA256 invalide pour $([IO.Path]::GetFileName($destination)). Attendu=$sha256 Recu=$actual"
  }
}
function Ensure-Token {
  if(-not (Test-Path $tokenPath) -or ((Get-Item $tokenPath).Length -lt 24)) {
    $raw = ([guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N'))
    [IO.File]::WriteAllText($tokenPath,$raw,[Text.UTF8Encoding]::new($false))
  }
}
function Register-EngineTask {
  Ensure-Token
  if(-not (Test-Path $bridgePath)) { throw 'EXDEV_RGB_BRIDGE.exe absent.' }
  $user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
  $args = 'serve --port ' + $enginePort + ' --token-file "' + $tokenPath + '"'
  $action = New-ScheduledTaskAction -Execute $bridgePath -Argument $args -WorkingDirectory $RootDir
  $trigger = New-ScheduledTaskTrigger -AtLogOn -User $user
  $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
  $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
  Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
  Log "Scheduled task '$taskName' registered for $user"
}
function Start-Engine {
  try { Stop-Process -Name 'EXDEV_RGB_BRIDGE' -Force -ErrorAction SilentlyContinue } catch {}
  Start-Sleep -Milliseconds 200
  Start-ScheduledTask -TaskName $taskName -ErrorAction Stop
  Start-Sleep -Milliseconds 900
}
function Engine-Reachable {
  try {
    $c = New-Object Net.Sockets.TcpClient
    $ar = $c.BeginConnect('127.0.0.1',$enginePort,$null,$null)
    if(-not $ar.AsyncWaitHandle.WaitOne(1200)) { $c.Close(); return $false }
    $c.EndConnect($ar); $c.Close(); return $true
  } catch { return $false }
}
function Self-Elevate {
  $arg = '-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $PSCommandPath + '" -RootDir "' + $RootDir + '" -LogFile "' + $LogFile + '" -ElevatedChild'
  Log 'Elevation UAC unique demandee pour installer/verifier le moteur materiel.'
  $p = Start-Process -FilePath 'powershell.exe' -ArgumentList $arg -Verb RunAs -WindowStyle Hidden -Wait -PassThru
  if($p.ExitCode -ne 0) { throw "La preparation elevee a retourne le code $($p.ExitCode)." }
}

$status = [ordered]@{
  timestamp = (Get-Date).ToString('o')
  pawnioVersion = '2.2.0'
  pawnioModulesVersion = '0.2.11'
  driverInstalled = $false
  moduleInstalled = $false
  engineTaskInstalled = $false
  engineReachable = $false
  rebootRequired = $false
  ready = $false
  error = $null
}

try {
  $moduleTarget = Join-Path $pawnDir 'SmbusPIIX4.bin'
  if(-not (Test-Path $moduleTarget)) {
    $zip = Join-Path $thirdParty 'PawnIO.Modules_0.2.11.zip'
    Download-Verified $modulesUrl $zip $modulesSha
    $extract = Join-Path $env:TEMP ('EXDEV_PawnIO_Modules_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $extract | Out-Null
    try {
      Expand-Archive -LiteralPath $zip -DestinationPath $extract -Force
      $module = Get-ChildItem -LiteralPath $extract -Recurse -File -Filter 'SmbusPIIX4.bin' | Select-Object -First 1
      if(-not $module) { throw 'SmbusPIIX4.bin introuvable dans le package officiel PawnIO.Modules.' }
      Copy-Item -LiteralPath $module.FullName -Destination $moduleTarget -Force
      Log 'Module SmbusPIIX4.bin installe.'
    } finally { Remove-Item -LiteralPath $extract -Recurse -Force -ErrorAction SilentlyContinue }
  }
  $status.moduleInstalled = Test-Path $moduleTarget

  $needAdmin = (-not (Driver-Installed)) -or (-not (Task-Exists)) -or (Task-NeedsUpdate)
  if($needAdmin -and -not (Is-Admin)) {
    Self-Elevate
    if(Test-Path $statusPath) {
      Get-Content -LiteralPath $statusPath -Raw -Encoding UTF8 | Write-Output
      exit 0
    }
  }

  if(-not (Driver-Installed)) {
    if(-not (Is-Admin)) { throw 'Droits administrateur requis pour installer PawnIO.' }
    $setup = Join-Path $thirdParty 'PawnIO_setup_2.2.0.exe'
    Download-Verified $setupUrl $setup $setupSha
    Log 'Installation du pilote PawnIO 2.2.0.'
    $proc = Start-Process -FilePath $setup -ArgumentList '-install','-silent' -Wait -PassThru
    Log "PawnIO setup exit code=$($proc.ExitCode)"
    if($proc.ExitCode -eq 3010 -or $proc.ExitCode -eq 1641) { $status.rebootRequired = $true }
    elseif($proc.ExitCode -ne 0) { throw "L'installation PawnIO a retourne le code $($proc.ExitCode)." }
    Start-Sleep -Milliseconds 900
  }

  if((-not (Task-Exists)) -or (Task-NeedsUpdate)) {
    if(-not (Is-Admin)) { throw 'Droits administrateur requis pour enregistrer EXDEV Native Engine.' }
    Register-EngineTask
  }
  Ensure-Token
  try { Start-Engine } catch { Log ('Start engine: ' + $_.Exception.Message) }

  $status.driverInstalled = Driver-Installed
  $status.engineTaskInstalled = Task-Exists
  $status.engineReachable = Engine-Reachable

  # Hotfix 1.6.0: a task can exist while pointing to a stale bridge/token or simply
  # not be running. Rebind it once instead of reporting a false ready state.
  if($status.driverInstalled -and $status.moduleInstalled -and -not $status.rebootRequired -and -not $status.engineReachable -and (Is-Admin)) {
    Log 'Native Engine non joignable: recreation de la liaison RAM/SMBus.'
    Register-EngineTask
    Start-Engine
    $status.engineTaskInstalled = Task-Exists
    $status.engineReachable = Engine-Reachable
  }

  if(-not $status.driverInstalled -and -not $status.rebootRequired) { throw 'PawnIO ne semble pas installe.' }
  if($status.driverInstalled -and $status.moduleInstalled -and -not $status.rebootRequired -and -not $status.engineReachable) { throw 'EXDEV Native Engine non joignable apres reparation.' }
  $status.ready = [bool]($status.driverInstalled -and $status.moduleInstalled -and $status.engineTaskInstalled -and $status.engineReachable -and -not $status.rebootRequired)
  if($status.rebootRequired) { Log 'Redemarrage Windows requis avant acces SMBus.' }
  elseif($status.ready) { Log 'Transport SMBus EXDEV et moteur eleve prets.' }
} catch {
  $status.error = $_.Exception.Message
  Log ('Erreur: ' + $status.error)
}

$status | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $statusPath -Encoding UTF8
$status | ConvertTo-Json -Compress -Depth 4 | Write-Output
exit 0
