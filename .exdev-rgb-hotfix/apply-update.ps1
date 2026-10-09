param([Parameter(Mandatory=$true)][string]$PackageRoot)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$TargetVersion='1.6.0'
Add-Type -AssemblyName System.Windows.Forms

$script:InstallRoot=$null
$script:RollbackExe=$null
$script:ReplacementCommitted=$false

function RV($p,$n){try{return [string](Get-ItemProperty -LiteralPath $p -Name $n -ErrorAction Stop).$n}catch{return ''}}
function Start-EXDEV([string]$root){if(!$root){return};$exe=Join-Path $root 'EXDEV RGB.exe';if(Test-Path -LiteralPath $exe){try{Start-Process -FilePath $exe -WorkingDirectory $root|Out-Null}catch{}}}
function Fail([string]$m){
  try{if($script:ReplacementCommitted -and $script:RollbackExe -and (Test-Path -LiteralPath $script:RollbackExe) -and $script:InstallRoot){Copy-Item -LiteralPath $script:RollbackExe -Destination (Join-Path $script:InstallRoot 'EXDEV RGB.exe') -Force -ErrorAction SilentlyContinue};Start-EXDEV $script:InstallRoot}catch{}
  try{[Windows.Forms.MessageBox]::Show($m,'EXDEV RGB - Mise a jour 1.6.0','OK','Error')|Out-Null}catch{}
  exit 1
}
function FindRoot{
  $c=New-Object 'System.Collections.Generic.List[string]'
  foreach($p in @('HKLM:\Software\EXDEV\EXDEV RGB','HKCU:\Software\EXDEV\EXDEV RGB')){$v=RV $p 'InstallLocation';if($v){$c.Add($v)}}
  foreach($p in @('Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall\EXDEV RGB','Registry::HKEY_LOCAL_MACHINE\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\EXDEV RGB','Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Uninstall\EXDEV RGB')){$v=RV $p 'InstallLocation';if($v){$c.Add($v)}}
  foreach($b in @([Environment]::GetFolderPath('ProgramFiles'),[Environment]::GetFolderPath('ProgramFilesX86'))){if($b){$c.Add((Join-Path $b 'EXDEV RGB'))}}
  foreach($x in $c){if($x -and (Test-Path (Join-Path $x 'EXDEV RGB.exe')) -and (Test-Path (Join-Path $x 'Lib\Source'))){return [IO.Path]::GetFullPath($x).TrimEnd('\')}}
  return $null
}
function Verify($p){
  $m=Get-Content (Join-Path $p 'payload-manifest.json') -Raw -Encoding UTF8|ConvertFrom-Json
  foreach($q in $m.files.PSObject.Properties){$r=[string]$q.Name;if($r.Contains('..') -or [IO.Path]::IsPathRooted($r)){throw 'Chemin interdit dans le manifeste.'};$f=Join-Path $p ($r-replace '/','\');if(!(Test-Path -LiteralPath $f)){throw "Fichier absent: $r"};$actual=(Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash.ToUpperInvariant();if($actual -ne ([string]$q.Value).ToUpperInvariant()){throw "Integrite invalide: $r"}}
}
function Copy-PayloadTree([string]$src,[string]$dst){if(!(Test-Path -LiteralPath $src)){return};Get-ChildItem -LiteralPath $src -Recurse -File|ForEach-Object{$rel=$_.FullName.Substring($src.Length).TrimStart('\');$target=Join-Path $dst $rel;New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent)|Out-Null;Copy-Item -LiteralPath $_.FullName -Destination $target -Force}}
function Write-Utf8NoBom([string]$path,[string]$text){[IO.File]::WriteAllText($path,$text,[Text.UTF8Encoding]::new($false))}

function Patch-RamLink([string]$SourceDir){
  $registry=Join-Path $SourceDir 'backend\drivers\registry.js'
  $native=Join-Path $SourceDir 'backend\native.js'
  if(!(Test-Path -LiteralPath $registry) -or !(Test-Path -LiteralPath $native)){throw 'Backend RAM EXDEV introuvable.'}

  $r=Get-Content -LiteralPath $registry -Raw -Encoding UTF8
  if($r -notmatch 'async function ramRuntimeStatus\('){
    $anchor=@"
async function liveCapabilities() {
  if (!bridgeInstalled()) return { ok:false, bridgeInstalled:false, drivers:{} };
  try { return await invokeBridge(['capabilities'], 6000); }
  catch (e) { return { ok:false, bridgeInstalled:true, error:e.message, drivers:{} }; }
}
"@
    $addition=@"
async function ramRuntimeStatus() {
  const bridge = bridgeInstalled();
  const moduleInstalled = pawnioModuleInstalled();
  if (!bridge) return { ready:false, bridgeInstalled:false, moduleInstalled, state:'bridge-missing', source:'none' };
  if (!moduleInstalled) return { ready:false, bridgeInstalled:true, moduleInstalled:false, state:'module-missing', source:'filesystem' };
  let engineError = '';
  try {
    const status = await engineRequest('/v1/status', null, 2800);
    const pawn = status?.pawnio || {};
    if (status?.ok === true && pawn?.installed === true) return { ready:true, bridgeInstalled:true, moduleInstalled:true, state:pawn.state || 'ready', source:'engine', engine:true };
    if (pawn?.state) engineError = pawn.state;
  } catch (e) { engineError = e?.message || 'engine-unreachable'; }
  try {
    const live = await liveCapabilities();
    const pawn = live?.pawnio || {};
    const cap = live?.drivers?.['corsair-ddr5'] || {};
    if (cap.write === true && pawn.installed === true) return { ready:true, bridgeInstalled:true, moduleInstalled:true, state:pawn.state || 'ready', source:'bridge-cli', engine:false };
    return { ready:false, bridgeInstalled:true, moduleInstalled:true, state:pawn.state || 'driver-missing', source:'bridge-cli', engine:false, error:live?.error || engineError };
  } catch (e) { return { ready:false, bridgeInstalled:true, moduleInstalled:true, state:'runtime-unreachable', source:'none', engine:false, error:e?.message || engineError }; }
}
"@
    if(-not $r.Contains($anchor)){throw 'Point de patch registry.js non trouve.'}
    $r=$r.Replace($anchor,$anchor+$addition)
    $oldExport="module.exports = { appRoot, bridgePath, bridgeInstalled, bridgeCapabilities, bridgeAvailable, invokeBridge, liveCapabilities, pawnioModulePath, pawnioModuleInstalled, engineTokenPath, engineRequest, canHandle, apply, applyEffect };"
    $newExport="module.exports = { appRoot, bridgePath, bridgeInstalled, bridgeCapabilities, bridgeAvailable, invokeBridge, liveCapabilities, ramRuntimeStatus, pawnioModulePath, pawnioModuleInstalled, engineTokenPath, engineRequest, canHandle, apply, applyEffect };"
    if(-not $r.Contains($oldExport)){throw 'Export registry.js non trouve.'}
    $r=$r.Replace($oldExport,$newExport)
    Write-Utf8NoBom $registry $r
  }

  $n=Get-Content -LiteralPath $native -Raw -Encoding UTF8
  if($n -notmatch 'const runtime=await drivers\.ramRuntimeStatus'){
    $old=@"
  const live=await drivers.liveCapabilities().catch(()=>({}));
  const ramCap=live?.drivers?.['corsair-ddr5']||{};
  const pawnState=live?.pawnio?.state||(!drivers.pawnioModuleInstalled()?'module-missing':'driver-missing');

  return [...groups.entries()].map(([part,modules],i)=>{
    const first=modules[0]||{};const profile=corsairProfile(part);const allowed=policy.isAllowedCorsair(part);
    const ready=allowed&&drivers.bridgeInstalled()&&ramCap.write===true;
"@
    $new=@"
  const runtime=await drivers.ramRuntimeStatus().catch(e=>({ready:false,state:'runtime-error',source:'none',error:e?.message||String(e)}));
  const pawnState=runtime?.state||(!drivers.pawnioModuleInstalled()?'module-missing':'driver-missing');

  return [...groups.entries()].map(([part,modules],i)=>{
    const first=modules[0]||{};const profile=corsairProfile(part);const allowed=policy.isAllowedCorsair(part);
    const ready=allowed&&runtime?.ready===true;
"@
    if(-not $n.Contains($old)){throw 'Point de patch scanRam native.js non trouve.'}
    $n=$n.Replace($old,$new)
    if($n -notmatch "ramRuntimeSource"){$n=$n.Replace("driverKey:allowed?'corsair-ddr5':null,writable:ready,driverState,pawnioState:pawnState,evidence:","driverKey:allowed?'corsair-ddr5':null,writable:ready,driverState,pawnioState:pawnState,ramRuntimeSource:runtime?.source||'none',evidence:")}
    Write-Utf8NoBom $native $n
  }
}

try{
  $P=Join-Path $PackageRoot 'Lib\Patch';Verify $P;$R=FindRoot;if(!$R){throw 'Installation EXDEV RGB 1.4.5 introuvable.'};$script:InstallRoot=$R
  $S=Join-Path $R 'Lib\Source';$I=Join-Path $R 'Lib\Installer';$QSrc=Join-Path $P 'Payload\Source';$QInstaller=Join-Path $P 'Payload\Installer';$ld=Join-Path $R 'Lib\Logs';New-Item -ItemType Directory -Force -Path $ld|Out-Null
  $rb=Join-Path $R 'Lib\Rollback\1.6.0-hotfix';New-Item -ItemType Directory -Force -Path $rb|Out-Null;$oldExe=Join-Path $R 'EXDEV RGB.exe';$script:RollbackExe=Join-Path $rb 'EXDEV RGB.previous.exe';if(Test-Path -LiteralPath $oldExe){Copy-Item -LiteralPath $oldExe -Destination $script:RollbackExe -Force}

  Copy-PayloadTree $QSrc $S
  Copy-PayloadTree $QInstaller $I
  Patch-RamLink $S

  $prep=Join-Path $I 'prepare-runtime.ps1';if(!(Test-Path -LiteralPath $prep)){throw 'prepare-runtime.ps1 introuvable.'}
  & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $prep -RootDir $R -SourceDir $S -LogFile (Join-Path $ld 'update-1.6.0-hotfix.log')
  if($LASTEXITCODE -ne 0){throw "Preparation/compilation echouee: $LASTEXITCODE"}

  $hsPath=Join-Path $R 'Lib\Native\hardware-status.json';if(!(Test-Path -LiteralPath $hsPath)){throw 'Etat materiel EXDEV introuvable apres reparation.'};$hs=Get-Content -LiteralPath $hsPath -Raw -Encoding UTF8|ConvertFrom-Json
  if(-not $hs.ready -and -not $hs.rebootRequired){throw ('Liaison RAM/SMBus non reparee: '+([string]$hs.error))}

  $built=Join-Path $S 'dist\EXDEV RGB.exe';if(!(Test-Path -LiteralPath $built)){throw 'Executable 1.6.0 compile introuvable.'}
  Get-Process -Name 'EXDEV RGB' -ErrorAction SilentlyContinue|Stop-Process -Force -ErrorAction SilentlyContinue;Start-Sleep -Milliseconds 350
  $rt=Join-Path $R 'Lib\AppRuntime';New-Item -ItemType Directory -Force -Path $rt|Out-Null;Copy-Item -LiteralPath $built -Destination (Join-Path $rt 'EXDEV RGB.exe') -Force;Copy-Item -LiteralPath $built -Destination $oldExe -Force;$script:ReplacementCommitted=$true
  foreach($f in @((Join-Path $rt 'version.txt'),(Join-Path $R 'Lib\installed-version.txt'),(Join-Path $R 'Lib\version.txt'))){[IO.File]::WriteAllText($f,$TargetVersion+"`r`n",[Text.UTF8Encoding]::new($false))}
  foreach($p in @('HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\EXDEV RGB','HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\EXDEV RGB')){try{if(Test-Path $p){Set-ItemProperty $p DisplayVersion $TargetVersion -Force}}catch{}}
  try{if(Test-Path 'HKLM:\Software\EXDEV\EXDEV RGB'){Set-ItemProperty 'HKLM:\Software\EXDEV\EXDEV RGB' Version $TargetVersion -Force}}catch{}
  Start-EXDEV $R
  if($hs.rebootRequired){[Windows.Forms.MessageBox]::Show('EXDEV RGB 1.6.0 est installe. Windows demande un redemarrage avant le controle SMBus de la RAM.','EXDEV RGB 1.6.0','OK','Information')|Out-Null}
  exit 0
}catch{Fail("La mise a jour EXDEV RGB 1.6.0 a echoue.`r`n`r`n"+$_.Exception.Message+"`r`n`r`nL ancienne application a ete relancee automatiquement.")}
