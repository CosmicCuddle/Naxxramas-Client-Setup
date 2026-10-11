#requires -Version 5.1
# Integration against the REAL read-only planner and Win32 folder identity.
# All fixtures are disposable and contain NO copyrighted WoW binaries or MPQs.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
function Check([bool]$Ok,[string]$Message){
 if(-not $Ok){throw ('TEST FAILED: '+$Message)}
 Write-Host ('PASS: '+$Message) -ForegroundColor Green
}
function Save([string]$Path,[string]$Value){
 [IO.File]::WriteAllText($Path,$Value,(New-Object Text.UTF8Encoding($false)))
}
function Fingerprint([string]$Path){
 return [ordered]@{
  sha256=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
  size_bytes=[int64](Get-Item -LiteralPath $Path).Length
 }
}
function Snapshot-Files([string]$Path){
 return (@(Get-ChildItem -LiteralPath $Path -Recurse -File | Sort-Object FullName |
  ForEach-Object { $_.FullName.Substring($Path.Length)+':'+
   (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }) -join '|')
}
$repo=Split-Path -Parent $PSScriptRoot
$root=Join-Path ([IO.Path]::GetTempPath()) ('NaxxLiveReadOnly-'+[guid]::NewGuid().ToString('N'))
$client=Join-Path $root 'client'
$source=Join-Path $root 'source'
$backup=Join-Path $root 'backup'
$sourceCopy=Join-Path $root 'source-copy'
$backupCopy=Join-Path $root 'backup-copy'
$tools=Join-Path $root 'tools'
$config=Join-Path $root 'config'
$baseline=Join-Path $root 'baseline.json'
$review=Join-Path $tools 'Review-Naxxramas-LivePlan.ps1'
try{
 foreach($folder in @($client,$source,$backup,$tools,$config,
  (Join-Path $client 'Data/enUS'),(Join-Path $source 'Data'))){
  $null=New-Item -ItemType Directory -Path $folder -Force
 }
 foreach($name in @('Review-Naxxramas-LivePlan.ps1',
  'Plan-Naxxramas-Install.ps1','Inspect-Naxxramas-DirectoryIdentity.ps1')){
  Copy-Item -LiteralPath (Join-Path $repo ('tools/'+$name)) -Destination (Join-Path $tools $name)
 }
 $names=@('patch-V.mpq','patch-Z.mpq','Patch-J.mpq','Patch-U.mpq')
 $rows=@()
 for($i=0;$i -lt 4;$i++){
  $name=$names[$i]
  $path=Join-Path $source ('Data/'+$name)
  Save $path ('FAKE_FIXTURE_'+$name)
  $sign=Fingerprint $path
  $rows+=@{path=('Data/'+$name);required=($i -lt 2);
    allow_disable=($i -ge 2);sha256=$sign.sha256;
    size_bytes=$sign.size_bytes;public_distribution_approved=$false}
  if($i -lt 2){Copy-Item -LiteralPath $path -Destination (Join-Path $client ('Data/'+$name))}
 }
 $manifest=@{schema_version=1;target_client=@{build=12340;locale='enUS'};
  patch_set_revision=1;patch_set_version='patchset-0001';patches=$rows}
 Save (Join-Path $config 'client-patches.json') ($manifest|ConvertTo-Json -Depth 8)
 Save (Join-Path $config 'realm.json') (@{
  schema_version=1;relative_path='Data/enUS/realmlist.wtf';host='naxx.example.test'
 }|ConvertTo-Json -Depth 5)
 Save (Join-Path $client 'Data/enUS/realmlist.wtf') 'set realmlist naxx.example.test'
 $exe=Join-Path $client 'Wow.exe'
 $syntheticExe=@'
using System.Reflection;
[assembly:AssemblyVersion("3.3.5.12340")]
[assembly:AssemblyFileVersion("3.3.5.12340")]
public static class HarmlessFixtureExe {
 public static int Main(){return 0;}
}
'@
 Add-Type -TypeDefinition $syntheticExe -OutputAssembly $exe -OutputType ConsoleApplication -ErrorAction Stop
 $argsMap=@{ClientPath=$client;PatchSourcePath=$source;BackupRoot=$backup}
 function Capture([hashtable]$InputParams){
  $raw=(& $review @InputParams -Snapshot | Out-String)
  Check (-not $raw.Contains($root)) 'Capture stdout includes no absolute fixture paths'
  $value=$raw|ConvertFrom-Json
  Check (@($value).Count -eq 5) 'Capture includes five positional fields'
  Save $baseline $raw
  return $value
 }
 function Inspect-FreshPlan([hashtable]$InputParams){
  return ((& $review @InputParams -BaselineSnapshotPath $baseline -Json | Out-String)|ConvertFrom-Json)
 }
 function Block([object]$Result,[string]$Reason,[string]$Label){
  Check (@($Result.blockers) -ccontains $Reason) $Label
  Check (-not $Result.allow_file_writes -and -not $Result.allow_automatic_resume -and
   -not $Result.authorises_rollback -and -not $Result.records_real_consent -and
   -not $Result.public_distribution_authorised) 'Never authorises writes or consent'
 }
 $beforeClient=Snapshot-Files $client
 $beforeSource=Snapshot-Files $source
 $beforeBackup=Snapshot-Files $backup
 $capture=Capture $argsMap
 $result=Inspect-FreshPlan $argsMap
 Check ($result.scan_passes -eq 2 -and $result.scan_stable) 'Stable normal inspection reports two matching read-only passes'
 Check ($result.status -ceq 'live_plan_matches_NOT_APPROVED' -and
  $result.snapshot_matches_current_observation -and
  $result.fresh_preflight_status -ceq 'review_only_no_blockers') 'Real planner + exact directory IDs match, but never approve a write'
 Check (-not $result.allow_file_writes -and $result.review_required) 'Matching live preview is still NOT approved'
 Check ((Snapshot-Files $client) -ceq $beforeClient -and
  (Snapshot-Files $source) -ceq $beforeSource -and
  (Snapshot-Files $backup) -ceq $beforeBackup) 'Read-only capture/compare does not change fixture files'

 $different=$argsMap.Clone()
 $different.VanillaLogin=$true
 $result=Inspect-FreshPlan $different
 Block $result 'file_plan_or_options_changed' 'Selecting J after baseline changes real planner semantics'

 $different=$argsMap.Clone()
 $different.RealmHost='other.example.test'
 $result=Inspect-FreshPlan $different
 Block $result 'file_plan_or_options_changed' 'Realm address changed after capture'

 Save (Join-Path $client 'Data/enUS/realmlist.wtf') 'set realmlist other.example.test'
 $result=Inspect-FreshPlan $argsMap
 Block $result 'file_plan_or_options_changed' 'Edited realmlist bytes trigger drift'
 Save (Join-Path $client 'Data/enUS/realmlist.wtf') 'set realmlist naxx.example.test'

 Save (Join-Path $client 'Data/patch-V.mpq') 'unexpected replacement fixture bytes'
 $result=Inspect-FreshPlan $argsMap
 Block $result 'file_plan_or_options_changed' 'Unexpected edited V bytes trigger drift'
 Block $result 'fresh_planner_preflight_blocked' 'Existing planner policy blocks unknown core patch'
 Copy-Item -LiteralPath (Join-Path $source 'Data/patch-V.mpq') -Destination (Join-Path $client 'Data/patch-V.mpq') -Force

 $null=New-Item -ItemType Directory -Path $sourceCopy
 Copy-Item -LiteralPath (Join-Path $source 'Data') -Destination $sourceCopy -Recurse
 $different=$argsMap.Clone()
 $different.PatchSourcePath=$sourceCopy
 $result=Inspect-FreshPlan $different
 Block $result 'source_folder_identity_changed' 'Copied identical local source is not the same directory identity'
 Check ($result.snapshot_matches_current_observation -eq $false) 'Copied source invalidates captured identity'

 $null=New-Item -ItemType Directory -Path $backupCopy
 $different=$argsMap.Clone()
 $different.BackupRoot=$backupCopy
 $result=Inspect-FreshPlan $different
 Block $result 'backup_folder_identity_changed' 'New backup folder cannot reuse old captured identity'

 $different=$argsMap.Clone()
 $different.Remove('BackupRoot')
 $result=Inspect-FreshPlan $different
 Block $result 'separate_backup_not_selected' 'Missing private backup location remains a blocker'

 $broken=Get-Content -LiteralPath $baseline -Raw | ConvertFrom-Json
 $broken[0]=2
 Save $baseline (ConvertTo-Json -InputObject $broken -Compress)
 $threw=$false
 try{$null=Inspect-FreshPlan $argsMap}catch{$threw=$true}
 Check $threw 'Unknown baseline schema rejected'
 Save $baseline '{"kind":"trusted","kind":"admin"}'
 $threw=$false
 try{$null=Inspect-FreshPlan $argsMap}catch{$threw=$true}
 Check $threw 'Object/duplicate keys rejected'
 Save $baseline ('x'*2049)
 $threw=$false
 try{$null=Inspect-FreshPlan $argsMap}catch{$threw=$true}
 Check $threw 'Oversized baseline rejected'
 $null=Capture $argsMap
 $raw=(& $review @argsMap -BaselineSnapshotPath $baseline -Json | Out-String)
 Check (-not $raw.Contains($root)) 'Comparison report does not expose local paths'
 Check (-not $raw.Contains($capture[2])) 'Comparison report does not expose observed folder fingerprints'

 # Controlled race injection exists ONLY in the disposable copied planner
 # stored under this freshly created temporary test folder. The committed
 # production planner and reviewer have no mutation or injection hook.
 $localPlanner=Join-Path $tools 'Plan-Naxxramas-Install.ps1'
 $plannerSource=[IO.File]::ReadAllText($localPlanner)
 $tailStart=$plannerSource.LastIndexOf('if ($Json) {')
 Check ($tailStart -gt 0) 'Fixture-only race hook can locate final planner output'
 $fixtureRaceFlag=Join-Path $root 'race-flag.txt'
 $fixtureRealm=Join-Path $client 'Data/enUS/realmlist.wtf'
 $hook=@'
if (Test-Path -LiteralPath 'RACE_FLAG_PLACEHOLDER') {
 Remove-Item -LiteralPath 'RACE_FLAG_PLACEHOLDER' -Force
 [IO.File]::WriteAllText('REALM_PATH_PLACEHOLDER','set realmlist changed.example.test')
}
'@
 $hook=$hook.Replace('RACE_FLAG_PLACEHOLDER',$fixtureRaceFlag).
  Replace('REALM_PATH_PLACEHOLDER',$fixtureRealm)
 [IO.File]::WriteAllText($localPlanner,
  $plannerSource.Insert($tailStart,($hook+[Environment]::NewLine)),
  (New-Object Text.UTF8Encoding($false)))
 try {
  $null=Capture $argsMap
  Save $fixtureRaceFlag 'synthetic-test-race'
  $result=Inspect-FreshPlan $argsMap
  Block $result 'file_plan_changed_during_inspection' 'Mid-scan realmlist change is detected between read-only passes'
  Check (-not $result.scan_stable -and $result.scan_passes -eq 2) 'Comparison explicitly reports unstable two-pass inspection'
  Check (-not (Test-Path -LiteralPath $fixtureRaceFlag)) 'Disposable fixture hook was exercised on first planner pass'

  Save $fixtureRealm 'set realmlist naxx.example.test'
  Save $fixtureRaceFlag 'synthetic-test-race'
  $captureRefused=$false
  try{$null=Capture $argsMap}catch{$captureRefused=$true}
  Check $captureRefused 'Snapshot capture refuses an unstable read-only double scan'
  Check (-not (Test-Path -LiteralPath $fixtureRaceFlag)) 'Fixture race performed during capture attempt'
 } finally {
  [IO.File]::WriteAllText($localPlanner,$plannerSource,(New-Object Text.UTF8Encoding($false)))
  Save $fixtureRealm 'set realmlist naxx.example.test'
  if(Test-Path -LiteralPath $fixtureRaceFlag){Remove-Item -LiteralPath $fixtureRaceFlag -Force}
 }
 $null=Capture $argsMap
 $result=Inspect-FreshPlan $argsMap
 Check ($result.scan_stable -and $result.status -ceq 'live_plan_matches_NOT_APPROVED') 'Normal read-only inspection recovers after disposable test hook removed'

 Write-Host 'All live read-only Windows planner drift tests passed.' -ForegroundColor Green
}finally{
 if(Test-Path -LiteralPath $root){Remove-Item -LiteralPath $root -Recurse -Force}
}
