#requires -Version 5.1
<#
READ ONLY transaction-scoped original-backup checkpoint review.
A caller-supplied local checkpoint is NEVER authenticated or a write grant.
Production tools only read existing local files; no stage/copy/replace/restore.
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$ClientPath,
 [Parameter(Mandatory=$true)][string]$BackupRoot,
 [Parameter(Mandatory=$true)][string]$TransactionId,
 [string]$PatchSourcePath,
 [switch]$VanillaLogin,[switch]$VanillaLoading,[string]$RealmHost,
 [switch]$Json
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($TransactionId -cnotmatch '^[A-Za-z0-9_-]{8,80}$'){
 throw 'Invalid transaction identifier.'
}
function Assert-NoLinks([string]$Path){
 $current=[IO.Path]::GetFullPath($Path)
 while($true){
  if(Test-Path -LiteralPath $current){
   $item=Get-Item -LiteralPath $current -Force -ErrorAction Stop
   if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){
    throw 'Linked/junction transaction input is forbidden.'
   }
  }
  $parent=[IO.Directory]::GetParent($current)
  if($null -eq $parent){break}
  $current=$parent.FullName
 }
}
function Digest([string]$Value){
 $sha=[Security.Cryptography.SHA256]::Create()
 try{
  return [BitConverter]::ToString(
   $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Value))).Replace('-','').ToLowerInvariant()
 }finally{$sha.Dispose()}
}
# Only caller-owned existing local directories. The lower-level planner and
# file inspector also reject nested client/source and unsafe reparse paths.
Assert-NoLinks $BackupRoot
$transactionRoot=Join-Path (Join-Path $BackupRoot 'transactions') $TransactionId
$originalsRoot=Join-Path $transactionRoot 'originals'
$checkpointPath=Join-Path $transactionRoot 'checkpoint.json'
foreach($path in @($transactionRoot,$originalsRoot,$checkpointPath)){
 Assert-NoLinks $path
}
if(-not (Test-Path -LiteralPath $originalsRoot -PathType Container)){
 throw 'Existing transaction-scoped originals folder is required.'
}
if(-not (Test-Path -LiteralPath $checkpointPath -PathType Leaf)){
 throw 'Existing checkpoint claim file is required.'
}
if((Get-Item -LiteralPath $checkpointPath -Force).Length -gt 4096){
 throw 'Checkpoint fixture is too large.'
}
try {
 Add-Type -AssemblyName System.Web.Extensions -ErrorAction Stop
 $utf8=New-Object Text.UTF8Encoding($false,$true)
 $parser=New-Object System.Web.Script.Serialization.JavaScriptSerializer
 $claim=$parser.DeserializeObject($utf8.GetString(
  [IO.File]::ReadAllBytes($checkpointPath)))
 if(-not ($claim -is [array]) -or $claim.Count -ne 4 -or
   -not ($claim[0] -is [int] -or $claim[0] -is [long]) -or
   [int64]$claim[0] -ne 1 -or
   -not ($claim[1] -is [string]) -or $claim[1] -cne $TransactionId -or
   -not ($claim[2] -is [string]) -or
   $claim[2] -cnotin @('prepared','copy_started','copy_staged','copy_checked') -or
   -not ($claim[3] -is [string]) -or $claim[3] -cnotmatch '^[a-f0-9]{64}$'){
    throw 'Bad checkpoint schema.'
 }
}catch{
 throw 'Checkpoint claim must be strict UTF-8 four-field JSON with a valid transaction and phase.'
}
$params=@{ClientPath=$ClientPath;BackupRoot=$originalsRoot;Json=$true}
if($PatchSourcePath){$params.PatchSourcePath=$PatchSourcePath}
if($VanillaLogin){$params.VanillaLogin=$true}
if($VanillaLoading){$params.VanillaLoading=$true}
if($RealmHost){$params.RealmHost=$RealmHost}
$originalsInspector=Join-Path $PSScriptRoot 'Review-Naxxramas-BackupOriginals.ps1'
$copiesInspector=Join-Path $PSScriptRoot 'Review-Naxxramas-ExistingBackupCopies.ps1'
$plan=(& $originalsInspector @params | Out-String) | ConvertFrom-Json
$comparison=(& $copiesInspector @params | Out-String) | ConvertFrom-Json
if($plan.kind -cne 'read_only_original_backup_candidate_review' -or
   $comparison.kind -cne 'read_only_existing_backup_copy_comparison' -or
   [int]$plan.originals_count -ne [int]$comparison.original_candidate_count){
 throw 'Incompatible original-readiness and backup-copy observations.'
}
$semantic=@()
foreach($entry in @($plan.originals_to_preserve)){
 if($entry.path -cnotin @('Data/patch-V.mpq','Data/patch-Z.mpq',
       'Data/Patch-J.mpq','Data/Patch-U.mpq','Data/enUS/realmlist.wtf') -or
    $entry.original_sha256 -cnotmatch '^[a-f0-9]{64}$'){
  throw 'Invalid original candidate.'
 }
 $semantic+=,@([string]$entry.path,[long]$entry.original_size_bytes,
  [string]$entry.original_sha256,
  [string]$entry.original_file_object_fingerprint_sha256)
}
$digest=Digest ('NAXX-ORIGINAL-CANDIDATES-FIXTURE-1:' +
 (ConvertTo-Json -InputObject $semantic -Compress -Depth 9))
$reasons=New-Object 'System.Collections.Generic.List[string]'
if($claim[3] -cne $digest){$reasons.Add('claimed_original_snapshot_changed')}
if($plan.status -cne 'originals_identified_NOT_BACKED_UP_NOT_APPROVED'){
 $reasons.Add('original_readiness_not_clear')
}
if($comparison.status -cnotin @(
 'matching_existing_copies_observed_NOT_RECOVERY_PROOF',
 'no_original_replacements_to_compare_NOT_APPROVED')){
 $reasons.Add('required_existing_original_copies_not_matching')
}
if(@($plan.originals_to_preserve).Count -eq 0){
 $reasons.Add('no_original_copy_needed_for_this_plan')
}
if($claim[2] -cne 'copy_checked'){
 $reasons.Add('checkpoint_not_claimed_copy_checked')
}
# A .part file for any known candidate indicates potentially interrupted
# staging. A copied final file must not be treated as recoverable while
# leftover temporary data remains. Inspect only allowlisted names.
$partCount=0
foreach($item in @($plan.originals_to_preserve)){
 $part=Join-Path (Join-Path $transactionRoot 'stage') (([string]$item.path)+'.part')
 Assert-NoLinks $part
 if(Test-Path -LiteralPath $part){
  $partCount++
 }
}
if($partCount -gt 0){$reasons.Add('uncommitted_partial_original_copies_present')}
$classification=if($reasons.Count -eq 0){
 'checkpoint_claims_and_bytes_match_NOT_DURABLE_NOT_AUTHENTICATED'
}else{
 'manual_review_transaction_backup_checkpoint_blocked'
}
$report=[pscustomobject][ordered]@{
 kind='read_only_transaction_scoped_backup_checkpoint'
 schema_version=1
 status=$classification
 checkpoint_claim_phase=[string]$claim[2]
 originals_count=[int]$plan.originals_count
 separate_matching_copy_count=[int]$comparison.observed_separate_matching_copy_count
 partial_copy_count=$partCount
 blockers=@($reasons.ToArray())
 blocker_count=$reasons.Count
 review_required=$true
 backup_created=$false
 checkpoint_authenticated=$false
 durable_backup_verified=$false
 originals_backed_up_and_verified=$false
 allow_file_writes=$false
 allow_automatic_resume=$false
 authorises_rollback=$false
 records_real_consent=$false
 public_distribution_authorised=$false
 limitations='Untrusted caller-writable checkpoint; matching claim cannot prove backup creation, durability, nonreplay, independent media or owner consent. Repeated read-only checks close handles between scans, are not atomic and cannot justify any installation/rollback.'
}
if($Json){$report|ConvertTo-Json -Depth 4}
else{
 Write-Host ('Read-only backup checkpoint: '+$classification)
 foreach($reason in $reasons){Write-Host ('Review: '+$reason)}
 Write-Host 'Matching checkpoint claims are never permission to write or restore.' -ForegroundColor Yellow
}
