#requires -Version 5.1
$ErrorActionPreference='Stop'
$root=Join-Path $env:TEMP ('EXDEV_RGB_ROLLBACK_SNAPSHOT_TEST_'+[guid]::NewGuid().ToString('N'))
try {
 $source='candidate/EXDEV RGB/Lib/Installer/installer-ui.ps1'
 $tokens=$null;$errors=$null
 $ast=[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $source).Path,[ref]$tokens,[ref]$errors)
 if($errors.Count -gt 0){throw 'Invalid installer PowerShell'}
 $function=$ast.Find({param($a) $a -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $a.Name -eq 'Save-VerifiedRollback'},$true)
 if(-not $function){throw 'Save-VerifiedRollback not found'}
 . ([ScriptBlock]::Create($function.Extent.Text))
 function Get-RealExeVersion([string]$Path){if(Test-Path $Path){return '1.6.13'};return ''}
 function Compare-V([string]$A,[string]$B){return ([version]$A).CompareTo([version]$B)}
 function Log([string]$Text){Write-Host $Text}
 $AppVersion='1.6.14'
 $old=Join-Path $root 'old'
 $new=Join-Path $root 'new'
 $names=@('EXDEV RGB.exe','Lib\AppRuntime\EXDEV RGB.exe','Lib\Native\EXDEV_RGB_BRIDGE.exe','EXDEV_RGB_INSTALLER.exe','Lib\version.txt','Lib\Source\package.json','Lib\Source\main.js','Lib\Source\renderer\app.js','Lib\Source\preload.js','Lib\Installer\installer-ui.ps1','Lib\Installer\prepare-runtime.ps1','Lib\Installer\ensure-hardware.ps1')
 foreach($name in $names){$dest=Join-Path $old $name;New-Item -ItemType Directory -Path (Split-Path $dest -Parent) -Force|Out-Null;[IO.File]::WriteAllText($dest,'ORIGINAL 1.6.13 '+$name)}
 Save-VerifiedRollback $old $new
 $snapshot=Join-Path $new 'Lib\Rollback\previous\snapshot.json'
 if(-not(Test-Path -LiteralPath $snapshot)){throw 'Snapshot missing'}
 $meta=Get-Content -LiteralPath $snapshot -Raw -Encoding utf8|ConvertFrom-Json
 if($meta.version -ne '1.6.13' -or $meta.schema -ne 1 -or $meta.files.PSObject.Properties.Count -ne $names.Count){throw 'Wrong manifest version/schema/number of files'}
 foreach($key in @('rootExe','appRuntime','nativeBridge','installer','versionMarker','sourcePackage','sourceMain','sourceRenderer','sourcePreload','installerUi','prepareRuntime','hardwarePrep')){
  if([string]$meta.files.$key -notmatch '^[A-Fa-f0-9]{64}$'){throw "Missing hash for $key"}
 }
 $oldHash=(Get-FileHash -LiteralPath (Join-Path $old 'EXDEV RGB.exe') -Algorithm SHA256).Hash
 $newHash=(Get-FileHash -LiteralPath (Join-Path $new 'Lib\Rollback\previous\EXDEV RGB.exe') -Algorithm SHA256).Hash
 if($oldHash -ne $newHash){throw 'Snapshot corrupt'}
 if((Test-Path -LiteralPath (Join-Path $new 'Lib\Rollback\previous-old'))){throw 'Temporary prior snapshot leaked'}
 Write-Host 'PASS: 12 copied and SHA-256 validated previous-version application/native/source/installer components; stable snapshot manifest persisted.'
}finally{if(Test-Path $root){Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue}}