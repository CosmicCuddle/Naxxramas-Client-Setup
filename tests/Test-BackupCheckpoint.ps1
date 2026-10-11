#requires -Version 5.1
# Test-only backup copy experiments inside a fresh, disposable Windows folder.
# The production checkpoint reviewer NEVER creates, deletes or restores files.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
function Check([bool]$Good,[string]$Message){
 if(-not $Good){throw ('TEST FAILED: '+$Message)}
 Write-Host ('PASS: '+$Message) -ForegroundColor Green
}
function Put([string]$File,[string]$Text){
 [IO.File]::WriteAllText($File,$Text,(New-Object Text.UTF8Encoding($false)))
}
function Sig([string]$File){
 return [ordered]@{
  sha256=(Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash.ToLowerInvariant()
  size_bytes=[long](Get-Item -LiteralPath $File).Length
 }
}
function Tree([string]$Folder){
 return (@(Get-ChildItem -LiteralPath $Folder -Recurse -File -Force |
  Sort-Object FullName | ForEach-Object{
   $_.FullName.Substring($Folder.Length)+':' +
   (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
  }) -join '|')
}
function Hash([string]$Text){
 $sha=[Security.Cryptography.SHA256]::Create()
 try{return [BitConverter]::ToString($sha.ComputeHash(
  [Text.Encoding]::UTF8.GetBytes($Text))).Replace('-','').ToLowerInvariant()}
 finally{$sha.Dispose()}
}
$repo=Split-Path -Parent $PSScriptRoot
$work=Join-Path ([IO.Path]::GetTempPath()) ('NaxxTxBackup-'+[guid]::NewGuid().ToString('N'))
$client=Join-Path $work 'client'
$source=Join-Path $work 'source'
$backup=Join-Path $work 'backup'
$config=Join-Path $work 'config'
$history=Join-Path $config 'patch-versions'
$tools=Join-Path $work 'tools'
$txnId='synthetic-txn-0001'
$txn=Join-Path (Join-Path $backup 'transactions') $txnId
$originals=Join-Path $txn 'originals'
$stage=Join-Path $txn 'stage'
$checkpoint=Join-Path $txn 'checkpoint.json'
$reviewer=Join-Path $tools 'Review-Naxxramas-BackupCheckpoint.ps1'
$params=@{ClientPath=$client;PatchSourcePath=$source;BackupRoot=$backup;
 TransactionId=$txnId;Json=$true}
function ReadReview{
 return ((& $reviewer @params | Out-String)|ConvertFrom-Json)
}
function HasReason([object]$Result,[string]$Reason,[string]$Why){
 Check (@($Result.blockers) -ccontains $Reason) $Why
}
function Safe([object]$Result){
 Check ($Result.review_required -and -not $Result.backup_created -and
 -not $Result.checkpoint_authenticated -and -not $Result.durable_backup_verified -and
 -not $Result.originals_backed_up_and_verified -and
 -not $Result.allow_file_writes -and -not $Result.allow_automatic_resume -and
 -not $Result.authorises_rollback -and -not $Result.records_real_consent -and
 -not $Result.public_distribution_authorised) 'No checkpoint result authorises install or recovery'
}
function SetPhase([string]$Phase,[string]$Fingerprint){
 Put $checkpoint (ConvertTo-Json -InputObject @(
  1,$txnId,$Phase,$Fingerprint) -Compress)
}
function CandidateHash {
 $argsMap=@{ClientPath=$client;PatchSourcePath=$source;BackupRoot=$originals;Json=$true}
 $plan=(& (Join-Path $tools 'Review-Naxxramas-BackupOriginals.ps1') @argsMap | Out-String)|ConvertFrom-Json
 Check ([int]$plan.originals_count -eq 2) 'Test plan identifies exactly two originals'
 $claims=@()
 foreach($r in @($plan.originals_to_preserve)){
  $claims+=,@([string]$r.path,[long]$r.original_size_bytes,
   [string]$r.original_sha256,
   [string]$r.original_file_object_fingerprint_sha256)
 }
 return (Hash ('NAXX-ORIGINAL-CANDIDATES-FIXTURE-1:'+
   (ConvertTo-Json -InputObject $claims -Compress -Depth 9)))
}
try {
 foreach($folder in @($client,$source,$backup,$tools,$history,
  (Join-Path $client 'Data/enUS'),(Join-Path $source 'Data'),
  (Join-Path $originals 'Data/enUS'),(Join-Path $stage 'Data/enUS'))){
  $null=New-Item -ItemType Directory -Path $folder -Force
 }
 foreach($name in @('Plan-Naxxramas-Install.ps1',
  'Inspect-Naxxramas-OpenFileHandles.ps1',
  'Review-Naxxramas-BackupOriginals.ps1',
  'Review-Naxxramas-ExistingBackupCopies.ps1',
  'Review-Naxxramas-BackupCheckpoint.ps1')){
  Copy-Item -LiteralPath (Join-Path $repo ('tools/'+$name)) -Destination (Join-Path $tools $name)
 }
 $policy=@()
 $names=@('patch-V.mpq','patch-Z.mpq','Patch-J.mpq','Patch-U.mpq')
 for($i=0;$i -lt 4;$i++){
  $local=Join-Path $source ('Data/'+$names[$i])
  Put $local ('FAKE_NEW_'+$names[$i])
  $signature=Sig $local
  $policy+=@{path=('Data/'+$names[$i]);required=($i -lt 2);
   allow_disable=($i -ge 2);size_bytes=$signature.size_bytes;
   sha256=$signature.sha256;public_distribution_approved=$false}
 }
 Put (Join-Path $config 'client-patches.json') (@{
  schema_version=1;target_client=@{build=12340;locale='enUS'};
  patch_set_revision=1;patch_set_version='patchset-0001';patches=$policy
 }|ConvertTo-Json -Depth 8)
 Put (Join-Path $config 'realm.json') (@{
  schema_version=1;relative_path='Data/enUS/realmlist.wtf';
  host='naxx.example.test'
 }|ConvertTo-Json -Depth 6)
 $v=Join-Path $client 'Data/patch-V.mpq'
 $realm=Join-Path $client 'Data/enUS/realmlist.wtf'
 Put $v 'FAKE_OLDER_V_ORIGINAL'
 $old=Sig $v
 Put (Join-Path $history 'patchset-0000.json') (@{
  schema_version=1;revision=0;version='patchset-0000';
  patches=@(@{path='Data/patch-V.mpq';size_bytes=$old.size_bytes;sha256=$old.sha256})
 }|ConvertTo-Json -Depth 8)
 Copy-Item -LiteralPath (Join-Path $source 'Data/patch-Z.mpq') -Destination (Join-Path $client 'Data/patch-Z.mpq')
 Put $realm 'set realmlist old.example.test'
 $exe=@'
using System.Reflection;
[assembly:AssemblyVersion("3.3.5.12340")]
[assembly:AssemblyFileVersion("3.3.5.12340")]
public static class BackupTransactionFixture {
 public static int Main(){return 0;}
}
'@
 Add-Type -TypeDefinition $exe -OutputAssembly (Join-Path $client 'Wow.exe') -OutputType ConsoleApplication -ErrorAction Stop
 Put (Join-Path $backup 'do-not-touch.txt') 'existing backup sentinel'
 $initialClient=Tree $client
 $initialSource=Tree $source
 $fingerprint=CandidateHash
 SetPhase 'prepared' $fingerprint
 $r=ReadReview
 HasReason $r 'checkpoint_not_claimed_copy_checked' 'Prepared phase alone cannot pass'
 HasReason $r 'required_existing_original_copies_not_matching' 'Absent original copies are blocked'
 Safe $r
 # This is a deliberately limited fixture-only copy exercise.
 # FileMode.CreateNew prohibits silently overwriting an existing copy.
 $vCopy=Join-Path $originals 'Data/patch-V.mpq'
 $realmCopy=Join-Path $originals 'Data/enUS/realmlist.wtf'
 $part=Join-Path $stage 'Data/patch-V.mpq.part'
 [IO.Directory]::CreateDirectory((Split-Path -Parent $vCopy))|Out-Null
 function CopyNew([string]$From,[string]$To){
  $read=New-Object IO.FileStream($From,[IO.FileMode]::Open,
   [IO.FileAccess]::Read,[IO.FileShare]::Read)
  try{
   $write=New-Object IO.FileStream($To,[IO.FileMode]::CreateNew,
    [IO.FileAccess]::Write,[IO.FileShare]::None)
   try{$read.CopyTo($write);$write.Flush($true)}
   finally{$write.Dispose()}
  }finally{$read.Dispose()}
 }
 SetPhase 'copy_started' $fingerprint
 CopyNew $v $part
 $r=ReadReview
 HasReason $r 'uncommitted_partial_original_copies_present' 'Interrupted staged .part file is detected'
 Check ($r.partial_copy_count -eq 1) 'Exactly one leftover partial copy observed'
 Safe $r
 [IO.File]::Move($part,$vCopy)
 $r=ReadReview
 HasReason $r 'checkpoint_not_claimed_copy_checked' 'Copied one original is not a completed checkpoint'
 HasReason $r 'required_existing_original_copies_not_matching' 'Missing other original stays blocked'
 CopyNew $realm $realmCopy
 SetPhase 'copy_staged' $fingerprint
 $r=ReadReview
 HasReason $r 'checkpoint_not_claimed_copy_checked' 'Staged files are not a checked checkpoint'
 Check ($r.separate_matching_copy_count -eq 2) 'Both staged fake originals have matching bytes'
 Safe $r
 $duplicateDenied=$false
 try{CopyNew $v $vCopy}catch{$duplicateDenied=$true}
 Check $duplicateDenied 'CreateNew cannot overwrite pre-existing original backup'
 SetPhase 'copy_checked' $fingerprint
 $r=ReadReview
 Check ($r.status -ceq 'checkpoint_claims_and_bytes_match_NOT_DURABLE_NOT_AUTHENTICATED') 'Matching checked claims remain unauthenticated and not durable'
 Check ($r.blocker_count -eq 0 -and $r.partial_copy_count -eq 0) 'No observed incomplete copy for matching fixture'
 Safe $r

 Put $realmCopy 'tampered fake backup'
 $r=ReadReview
 HasReason $r 'required_existing_original_copies_not_matching' 'Byte tampering after staging blocked'
 Safe $r
 Put $realmCopy 'set realmlist old.example.test'
 Put $checkpoint (ConvertTo-Json -InputObject @(1,$txnId,'copy_checked',('0'*64)) -Compress)
 $r=ReadReview
 HasReason $r 'claimed_original_snapshot_changed' 'Stale or fabricated claimed fingerprint detected'
 Safe $r
 SetPhase 'copy_checked' $fingerprint
 # A forged coherent local checkpoint can be made by the same user;
 # this test MUST NOT call it a durable or authentic restore permission.
 $r=ReadReview
 Check (-not $r.checkpoint_authenticated -and -not $r.originals_backed_up_and_verified) 'Recomputed checkpoint never creates trust'

 Put $realm 'set realmlist changed-again.example.test'
 $r=ReadReview
 HasReason $r 'claimed_original_snapshot_changed' 'Edited original after receipt invalidates claimed original digest'
 Safe $r
 Put $realm 'set realmlist old.example.test'

 $invalid=$false
 try{
  $bad=$params.Clone();$bad.TransactionId='../traversal'
  $null=((& $reviewer @bad | Out-String)|ConvertFrom-Json)
 }catch{$invalid=$true}
 Check $invalid 'Transaction path traversal rejected'
 $invalid=$false
 Put $checkpoint '{"claim":1,"claim":2}'
 try{$null=ReadReview}catch{$invalid=$true}
 Check $invalid 'Object/duplicate key checkpoint rejected'
 SetPhase 'copy_checked' $fingerprint
 $r=ReadReview
 Check ($r.status -ceq 'checkpoint_claims_and_bytes_match_NOT_DURABLE_NOT_AUTHENTICATED') 'Fixture returns to coherent read-only state'
 Check ((Tree $client) -ceq $initialClient -and (Tree $source) -ceq $initialSource) 'Test writer never changed any client/source bytes'
 Check ((Get-Content -LiteralPath (Join-Path $backup 'do-not-touch.txt') -Raw) -match 'existing backup sentinel') 'Previously existing backup sentinel never changed'
 $stdout=(& $reviewer @params | Out-String)
 Check (-not $stdout.Contains($work)) 'Read-only report hides absolute temporary paths'
 Write-Host 'All transaction-scoped read-only backup checkpoint tests passed.' -ForegroundColor Green
} finally {
 if(Test-Path -LiteralPath $work){Remove-Item -LiteralPath $work -Recurse -Force}
}
