#requires -Version 5.1
# Reference client inspection tests: no original game assets, no public client data.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
$inspector=Join-Path $repo 'tools/Inspect-Reference-Client.ps1'
$tokens=$null;$errs=$null
[Management.Automation.Language.Parser]::ParseFile($inspector,[ref]$tokens,[ref]$errs)|Out-Null
if(@($errs).Count -ne 0){throw ('Reference inspector syntax error: '+($errs -join '; '))}
$base=Join-Path ([IO.Path]::GetTempPath()) ('naxx-ref-test-'+[guid]::NewGuid().ToString('N'))
try{
 foreach($dir in @('repo/tools','repo/config','game/Data/enUS','game/WTF/Account/PRIVATE_ACCOUNT','reports','game/Interface/AddOns/NCore')){
  New-Item -ItemType Directory -Path (Join-Path $base $dir) -Force|Out-Null
 }
 $repoStub=Join-Path $base 'repo'
 $game=Join-Path $base 'game'
 $script=Join-Path $repoStub 'tools/Inspect-Reference-Client.ps1'
 Copy-Item -LiteralPath $inspector -Destination $script
 [IO.File]::WriteAllBytes((Join-Path $game 'Wow.exe'),[byte[]]@(0,1,2,3))
 $policy=Get-Content -LiteralPath (Join-Path $repo 'config/client-patches.json') -Raw | ConvertFrom-Json
 foreach($entry in @($policy.patches)){
  if($entry.required){
   $path=Join-Path $game ($entry.path.Replace('/',[IO.Path]::DirectorySeparatorChar))
   [IO.File]::WriteAllText($path,('synthetic-'+$entry.path))
   $entry.size_bytes=[long](Get-Item -LiteralPath $path).Length
   $entry.sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
  }
 }
 $policy|ConvertTo-Json -Depth 14 | Set-Content -LiteralPath (Join-Path $repoStub 'config/client-patches.json') -Encoding UTF8
 $secret='PRIVATE_VALUE_NEVER_REPORT_THIS'
 $sensitive=Join-Path $game 'WTF/Account/PRIVATE_ACCOUNT/secret.txt'
 [IO.File]::WriteAllText($sensitive,$secret)
 [IO.File]::WriteAllText((Join-Path $game 'Data/enUS/realmlist.wtf'),('set realmlist '+$secret))
 $original=(Get-FileHash -LiteralPath $sensitive -Algorithm SHA256).Hash
 function Inspect([string[]]$extra){
  $out=(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script -ClientPath $game @extra 2>&1 | Out-String)
  return [pscustomobject]@{Code=$LASTEXITCODE;Output=$out}
 }
 $r=Inspect @()
 if($r.Code -ne 0){throw ('Could not inspect dummy client: '+$r.Output)}
 $report=$r.Output | ConvertFrom-Json
 if($report.core_patches_valid -ne $true -or $report.build_confirmed -ne $false -or
    $report.reference_status -ne 'needs_review' -or $report.locale_enUS_present -ne $true){
  throw 'Synthetic client was incorrectly accepted as a validated real WoW build.'
 }
 if(@($report.patches | Where-Object {$_.required -and $_.status -eq 'verified'}).Count -ne 2){
  throw 'Synthetic V/Z fingerprints were not both validated.'
 }
 if(@($report.patches | Where-Object {-not $_.required -and $_.status -ne 'not_installed'}).Count -ne 0){
  throw 'Missing optional J/C/U were not treated as optional.'
 }
 if(@($report.n_addons|Where-Object {$_.status -eq 'present'}).Count -ne 0){
  throw 'A folder without a matching TOC was incorrectly treated as an installed addon.'
 }
 if($r.Output.Contains($secret) -or $r.Output.Contains('PRIVATE_ACCOUNT') -or
    $r.Output.Contains($game) -or $r.Output.Contains('85.190.') -or
    $r.Output.Contains('set realmlist')){
  throw 'Reference report includes private directory data or realm contents.'
 }
 $reportPath=Join-Path $base 'reports/client-reference.json'
 $saved=Inspect @('-ReportPath',$reportPath)
 if($saved.Code -ne 0 -or -not (Test-Path -LiteralPath $reportPath -PathType Leaf)){
  throw ('Could not save a report outside game folder: '+$saved.Output)
 }
 $savedData=Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
 if($savedData.core_patches_valid -ne $true){throw 'Saved report is incomplete.'}
 $duplicate=Inspect @('-ReportPath',$reportPath)
 if($duplicate.Code -eq 0 -or -not $duplicate.Output.Contains('already exists')){
  throw 'Report inspector overwrote an existing file.'
 }
 $unsafe=Inspect @('-ReportPath',(Join-Path $game 'private-report.json'))
 if($unsafe.Code -eq 0 -or -not $unsafe.Output.Contains('inside the WoW client')){
  throw 'Report inspector wrote a report inside game.'
 }
 $fakeJ=Join-Path $game 'Data/Patch-J.mpq'
 $fakeC=Join-Path $game 'Data/Patch-C.mpq'
 [IO.File]::WriteAllText($fakeJ,'dummy-J')
 [IO.File]::WriteAllText($fakeC,'dummy-C')
 $both=Inspect @()
 if($both.Code -ne 0 -or -not ($both.Output|ConvertFrom-Json).optional_login_conflict){
  throw 'Reference inspection missed conflicting J/C.'
 }
 Remove-Item -LiteralPath $fakeJ,$fakeC -Force
 [IO.File]::WriteAllText((Join-Path $game 'Data/patch-Z.mpq'),'corrupted Z')
 $corrupted=Inspect @()
 if($corrupted.Code -ne 0 -or ($corrupted.Output|ConvertFrom-Json).core_patches_valid){
  throw 'Corrupted mandatory Z did not invalidate reference.'
 }
 if((Get-FileHash -LiteralPath $sensitive -Algorithm SHA256).Hash -ne $original){
  throw 'Private game data was modified.'
 }
 if(Test-Path -LiteralPath (Join-Path $game 'private-report.json')){
  throw 'Inspector wrote a report into the client.'
 }
 Write-Host 'ALL SANITISED REFERENCE CLIENT INSPECTION TESTS PASSED'
}finally{
 if(Test-Path -LiteralPath $base){Remove-Item -LiteralPath $base -Recurse -Force}
}
exit 0
