#requires -Version 5.1
# Tests disposable miniature client/source/backup directories. Never WoW data.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
function Check([bool]$Ok,[string]$Message){
 if(-not $Ok){throw 'TEST FAILED: '+$Message}
 Write-Host ('PASS: '+$Message) -ForegroundColor Green
}
function Save([string]$Path,[string]$Value){
 [IO.File]::WriteAllText($Path,$Value,(New-Object Text.UTF8Encoding($false)))
}
function Sign([string]$Path){
 return [ordered]@{
  sha256=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
  size_bytes=[int64](Get-Item -LiteralPath $Path).Length
 }
}
function Snapshot([string]$Path){
 return (@(Get-ChildItem -LiteralPath $Path -Recurse -File -Force |
    Sort-Object FullName | ForEach-Object {
      $_.FullName.Substring($Path.Length)+':'+
       (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    }) -join '|')
}
$repo=Split-Path -Parent $PSScriptRoot
$work=Join-Path ([IO.Path]::GetTempPath()) ('NaxxExistingCopies-'+[guid]::NewGuid().ToString('N'))
$client=Join-Path $work 'client'
$source=Join-Path $work 'source'
$backup=Join-Path $work 'backup'
$tools=Join-Path $work 'tools'
$config=Join-Path $work 'config'
$history=Join-Path $config 'patch-versions'
$inspector=Join-Path $tools 'Review-Naxxramas-ExistingBackupCopies.ps1'
$params=@{ClientPath=$client;PatchSourcePath=$source;BackupRoot=$backup;Json=$true}
function Inspect([hashtable]$Parameters){
 return ((& $inspector @Parameters | Out-String) | ConvertFrom-Json)
}
function Reason([object]$Report,[string]$Value,[string]$Label){
 Check (@($Report.blockers) -ccontains $Value) $Label
}
function ReadOnly([object]$Report){
 Check ($Report.review_required -and -not $Report.backup_created -and
 -not $Report.authentic_backup_provenance_verified -and
 -not $Report.durable_backup_verified -and -not $Report.originals_backed_up_and_verified -and
 -not $Report.restores_authorised -and -not $Report.allow_file_writes -and
 -not $Report.allow_automatic_resume -and -not $Report.authorises_rollback -and
 -not $Report.records_real_consent -and -not $Report.public_distribution_authorised) 'Never certifies a backup, consent, write or restore'
}
function Refuses([hashtable]$Parameters,[string]$Message){
 $rejected=$false
 try{$null=Inspect $Parameters}catch{$rejected=$true}
 Check $rejected $Message
}
$hardlink=$null
$hardlinkMade=$false
try {
 foreach($folder in @($client,$source,$backup,$tools,$history,
  (Join-Path $client 'Data/enUS'),(Join-Path $source 'Data'),
  (Join-Path $backup 'Data/enUS'))){
  $null=New-Item -ItemType Directory -Path $folder -Force
 }
 foreach($file in @('Review-Naxxramas-ExistingBackupCopies.ps1',
  'Review-Naxxramas-BackupOriginals.ps1',
  'Inspect-Naxxramas-OpenFileHandles.ps1','Plan-Naxxramas-Install.ps1')){
  Copy-Item -LiteralPath (Join-Path $repo ('tools/'+$file)) -Destination (Join-Path $tools $file)
 }
 $patches=@('patch-V.mpq','patch-Z.mpq','Patch-J.mpq','Patch-U.mpq')
 $rules=@()
 for($i=0;$i -lt 4;$i++){
  $relative='Data/'+$patches[$i]
  $local=Join-Path $source $relative
  Save $local ('FAKE_CURRENT_'+$patches[$i])
  $fingerprint=Sign $local
  $rules+=@{path=$relative;required=($i -lt 2);allow_disable=($i -ge 2);
   sha256=$fingerprint.sha256;size_bytes=$fingerprint.size_bytes;
   public_distribution_approved=$false}
 }
 Save (Join-Path $config 'client-patches.json') (@{
  schema_version=1;target_client=@{build=12340;locale='enUS'};
  patch_set_revision=1;patch_set_version='patchset-0001';patches=$rules
 } | ConvertTo-Json -Depth 8)
 Save (Join-Path $config 'realm.json') (@{
  schema_version=1;relative_path='Data/enUS/realmlist.wtf';
  host='naxx.example.test'
 }|ConvertTo-Json -Depth 5)
 $v=Join-Path $client 'Data/patch-V.mpq'
 Save $v 'FAKE_OLD_V'
 $vSignature=Sign $v
 Save (Join-Path $history 'patchset-0000.json') (@{
  schema_version=1;revision=0;version='patchset-0000';
  patches=@(@{path='Data/patch-V.mpq';sha256=$vSignature.sha256;
   size_bytes=$vSignature.size_bytes})
 }|ConvertTo-Json -Depth 8)
 Copy-Item -LiteralPath (Join-Path $source 'Data/patch-Z.mpq') -Destination (Join-Path $client 'Data/patch-Z.mpq')
 Save (Join-Path $client 'Data/Patch-J.mpq') 'private user existing unselected J'
 $realm=Join-Path $client 'Data/enUS/realmlist.wtf'
 Save $realm 'set realmlist old.example.test'
 $fixtureExe=@'
using System.Reflection;
[assembly:AssemblyVersion("3.3.5.12340")]
[assembly:AssemblyFileVersion("3.3.5.12340")]
public static class SyntheticBackupCopyFixture {
 public static int Main(){return 0;}
}
'@
 Add-Type -TypeDefinition $fixtureExe -OutputAssembly (Join-Path $client 'Wow.exe') -OutputType ConsoleApplication -ErrorAction Stop
 $vCopy=Join-Path $backup 'Data/patch-V.mpq'
 $realmCopy=Join-Path $backup 'Data/enUS/realmlist.wtf'
 Copy-Item -LiteralPath $v -Destination $vCopy
 Copy-Item -LiteralPath $realm -Destination $realmCopy
 Save (Join-Path $backup 'unrelated-sentinel.txt') 'NEVER CHANGE THIS FILE'
 $clientBefore=Snapshot $client
 $sourceBefore=Snapshot $source
 $backupBefore=Snapshot $backup
 $r=Inspect $params
 Check ($r.status -ceq 'matching_existing_copies_observed_NOT_RECOVERY_PROOF') 'Both existing mirrored copies observed, not certified'
 Check ($r.original_candidate_count -eq 2 -and $r.observed_separate_matching_copy_count -eq 2) 'Only V and realmlist are compared and independently observed'
 Check (@($r.copies|Where-Object {$_.path -ceq 'Data/patch-V.mpq' -and $_.copy_state -ceq 'same_bytes_distinct_observed_file_object_NOT_CERTIFIED'}).Count -eq 1) 'V copy is a distinct file with matching original bytes'
 Check (@($r.copies|Where-Object {$_.path -ceq 'Data/enUS/realmlist.wtf' -and $_.copy_state -ceq 'same_bytes_distinct_observed_file_object_NOT_CERTIFIED'}).Count -eq 1) 'Realmlist copy is distinct and matches'
 Check (-not $r.blocker_count -and @($r.blockers).Count -eq 0) 'Only genuinely matching required candidates have no fixture blockers'
 ReadOnly $r
 Check ((Snapshot $client) -ceq $clientBefore -and
  (Snapshot $source) -ceq $sourceBefore -and
  (Snapshot $backup) -ceq $backupBefore) 'Reviewer changes no real fixture bytes'

 Save $realmCopy 'wrong previous realmlist bytes'
 $r=Inspect $params
 Check ($r.status -ceq 'manual_review_existing_backup_copy_blocked') 'Changed backup bytes block review'
 Reason $r 'backup_candidate_4_bytes_do_not_match_original' 'Mismatch assigned to exact realmlist candidate'
 Check ($r.observed_separate_matching_copy_count -eq 1) 'One mismatched backup cannot count as matching'
 ReadOnly $r
 Copy-Item -LiteralPath $realm -Destination $realmCopy -Force

 Remove-Item -LiteralPath $vCopy
 $r=Inspect $params
 Check ($r.status -ceq 'manual_review_existing_backup_copy_blocked') 'Missing V backup blocks review'
 Reason $r 'backup_candidate_0_missing' 'Missing mirrored V named explicitly'
 ReadOnly $r
 Copy-Item -LiteralPath $v -Destination $vCopy

 $writer=New-Object IO.FileStream($vCopy,[IO.FileMode]::Open,
   [IO.FileAccess]::ReadWrite,[IO.FileShare]::ReadWrite)
 try{ Refuses $params 'Open writer to backup file refuses read-only verification' }
 finally{$writer.Dispose()}

 # A hardlink has the same Windows FILE_ID_INFO as the source; it is not
 # independent preservation, even when its SHA-256 and byte count match.
 Remove-Item -LiteralPath $vCopy
 try {
  $null=New-Item -ItemType HardLink -Path $vCopy -Target $v -ErrorAction Stop
  $hardlink=$vCopy
  $hardlinkMade=$true
 }catch {
  Write-Host 'SKIP: hardlink fixture unavailable on this Windows runner.'
 }
 if($hardlinkMade){
  $r=Inspect $params
  Check ($r.status -ceq 'manual_review_existing_backup_copy_blocked') 'Hardlinked matching backup is refused'
  Reason $r 'backup_candidate_0_same_file_object_as_original' 'Same object cannot be a safe separate backup'
  Check (@($r.copies|Where-Object {$_.path -ceq 'Data/patch-V.mpq' -and
   $_.sha256_matches_original -and -not $_.separate_observed_file_object}).Count -eq 1) 'Matching hashes are insufficient when object ID matches'
  ReadOnly $r
  Remove-Item -LiteralPath $hardlink -Force
  $hardlinkMade=$false
 }
 if(-not (Test-Path -LiteralPath $vCopy)){
  Copy-Item -LiteralPath $v -Destination $vCopy
 }

 Save $v 'unrecognized V original file'
 $r=Inspect $params
 Check ($r.status -ceq 'manual_review_existing_backup_copy_blocked') 'Planner unknown-V preflight blocks even when backup report exists'
 Reason $r 'original_readiness_blocked' 'Original candidate checker blocker is propagated'
 Save $v 'FAKE_OLD_V'

 $noSource=$params.Clone()
 $noSource.Remove('PatchSourcePath')
 $r=Inspect $noSource
 Reason $r 'original_readiness_blocked' 'No local replacement source prevents successful readiness classification'

 $unsafe=$params.Clone()
 $unsafe.BackupRoot=$client
 Refuses $unsafe 'Backup destination cannot equal actual client root'
 $unsafe=$params.Clone()
 $unsafe.BackupRoot=$source
 Refuses $unsafe 'Backup destination cannot equal patch source'
 $raw=(& $inspector @params | Out-String)
 Check (-not $raw.Contains($work)) 'JSON never leaks Windows absolute folder paths'
 Check (-not $raw.Contains('unrelated-sentinel')) 'Review does not expose unrelated backup files'
 Check ((Get-Content -LiteralPath (Join-Path $backup 'unrelated-sentinel.txt') -Raw) -match 'NEVER CHANGE THIS FILE') 'Backup sentinel preserved'

 # Real original matching copies observed in separate file IDs still do not
 # grant installation, rollback, or a cryptographic provenance claim.
 $r=Inspect $params
 Check ($r.status -ceq 'matching_existing_copies_observed_NOT_RECOVERY_PROOF') 'Normal observations recover after synthetic tests'
 ReadOnly $r
 Write-Host 'All synthetic existing backup copy verification tests passed.' -ForegroundColor Green
}finally {
 if($hardlinkMade -and $hardlink -and (Test-Path -LiteralPath $hardlink)){
  Remove-Item -LiteralPath $hardlink -Force
 }
 if(Test-Path -LiteralPath $work){Remove-Item -LiteralPath $work -Recurse -Force}
}
