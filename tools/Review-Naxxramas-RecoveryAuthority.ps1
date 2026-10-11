#requires -Version 5.1
<#
Naxxramas Client Setup — READ ONLY claimed recovery ownership/consent gate.
All receipt, owner and latest-state values are CALLER-WRITABLE JSON claims.
Nothing here signs, creates consent, consumes a nonce or authorises writes.
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$ClientPath,
 [Parameter(Mandatory=$true)][string]$SessionDirectory,
 [Parameter(Mandatory=$true)][string]$ReceiptFixturePath,
 [Parameter(Mandatory=$true)][string]$AuthorityFixturePath,
 [switch]$Json
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
function NoLinks([string]$Path) {
 $cursor=[IO.Path]::GetFullPath($Path)
 while($true){
  if(Test-Path -LiteralPath $cursor){
   $entry=Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
   if(($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){
    throw 'Junction/symlink fixture or ancestor is forbidden.'
   }
  }
  $parent=[IO.Directory]::GetParent($cursor)
  if($null -eq $parent){break}
  $cursor=$parent.FullName
 }
}
function Read-Array([string]$Path,[int]$Count,[string]$Label) {
 NoLinks $Path
 if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){
  throw "Missing $Label fixture."
 }
 $bytes=[IO.File]::ReadAllBytes($Path)
 if($bytes.Length -gt 4096){throw "$Label fixture is too large."}
 try {
  $utf8=New-Object Text.UTF8Encoding($false,$true)
  Add-Type -AssemblyName System.Web.Extensions -ErrorAction Stop
  $serializer=New-Object System.Web.Script.Serialization.JavaScriptSerializer
  $result=$serializer.DeserializeObject($utf8.GetString($bytes))
  if(-not ($result -is [array]) -or $result.Count -ne $Count)){
   throw 'Unexpected positional schema.'
  }
  return ,$result
 }catch{throw "Invalid $Label fixture JSON."}
}
function Id([object]$Value,[string]$Label) {
 if(-not ($Value -is [string]) -or $Value -cnotmatch '^[A-Za-z0-9_-]{8,80}$'){
  throw "Invalid $Label."
 }
}
function Hash([object]$Value,[string]$Label) {
 if(-not ($Value -is [string]) -or $Value -cnotmatch '^[a-f0-9]{64}$'){
  throw "Invalid $Label."
 }
}
function Num([object]$Value,[string]$Label,[int64]$Min,[int64]$Max) {
 if(-not ($Value -is [int] -or $Value -is [long]) -or
  [int64]$Value -lt $Min -or [int64]$Value -gt $Max) {
  throw "Invalid $Label."
 }
}
function AddBlock([System.Collections.Generic.List[string]]$List,[string]$Reason) {
 if(-not $List.Contains($Reason)){$List.Add($Reason)}
}
function Digest([string]$Path) {
 NoLinks $Path
 if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){
  throw 'Missing original session record.'
 }
 return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
# Strict synthetic arrays. Neither array is issued or authenticated by us.
# receipt: [1,id,sessionId,sessionSha,clientDirFp,sessionDirFp,
#           nonce,sequence,issuedUtc,expiresUtc,consentState]
# authority: [1,sessionId,clientDirFp,sessionDirFp,
#             latestIssuedSequence,consumedThroughSequence,latestNonce,state]
$receipt=Read-Array $ReceiptFixturePath 11 'receipt'
$authority=Read-Array $AuthorityFixturePath 8 'authority'
Num $receipt[0] 'receipt version' 1 1
Num $authority[0] 'authority version' 1 1
foreach($field in @(@($receipt[1],'receipt ID'),@($receipt[2],'receipt session ID'),
 @($receipt[6],'receipt nonce'),@($authority[1],'authority session ID'),
 @($authority[6],'authority nonce'))){
 Id $field[0] $field[1]
}
foreach($field in @(@($receipt[3],'receipt session digest'),
 @($receipt[4],'receipt client fingerprint'),@($receipt[5],'receipt session folder fingerprint'),
 @($authority[2],'authority client fingerprint'),@($authority[3],'authority session folder fingerprint'))){
 Hash $field[0] $field[1]
}
Num $receipt[7] 'receipt sequence' 1 1000000000
Num $receipt[8] 'issued Unix time' 1577836800 4102444800
Num $receipt[9] 'expiry Unix time' 1577836800 4102444800
Num $authority[4] 'latest sequence claim' 1 1000000000
Num $authority[5] 'consumed-through claim' 0 1000000000
if([int64]$receipt[9] -le [int64]$receipt[8] -or
 [int64]$receipt[9] -gt ([int64]$receipt[8]+3600)){
 throw 'Receipt claims invalid or excessive lifetime.'
}
if($receipt[10] -cnotin @('explicit_confirmed','pending','revoked','expired')){
 throw 'Unrecognised receipt consent claim.'
}
if($authority[7] -cnotin @('claimed_current','missing','stale','foreign_owner','unverified')){
 throw 'Unrecognised latest-state claim.'
}
$sessionRecord=Join-Path $SessionDirectory 'session.json'
$startDigest=Digest $sessionRecord
$identity=Join-Path $PSScriptRoot 'Inspect-Naxxramas-DirectoryIdentity.ps1'
$clientObservation=(& $identity -ClientPath $ClientPath -Json | Out-String)|ConvertFrom-Json
$sessionObservation=(& $identity -ClientPath $SessionDirectory -Json | Out-String)|ConvertFrom-Json
if($clientObservation.status -cne 'observed_not_authenticated' -or
 $sessionObservation.status -cne 'observed_not_authenticated' -or
 $clientObservation.client_fingerprint_sha256 -cnotmatch '^[a-f0-9]{64}$' -or
 $sessionObservation.client_fingerprint_sha256 -cnotmatch '^[a-f0-9]{64}$'){
 throw 'Windows folder identity scanner failed.'
}
$recovery=Join-Path $PSScriptRoot 'Review-Naxxramas-RecoverySafeguard.ps1'
$review=(& $recovery -ClientPath $ClientPath -SessionDirectory $SessionDirectory -Json | Out-String)|ConvertFrom-Json
if($review.kind -cne 'read_only_recovery_conflict_safeguard' -or
 [int]$review.schema_version -ne 1 -or
 $review.allow_file_writes -or $review.authorises_rollback){
 throw 'Recovery safeguard schema/denial invariant failed.'
}
$endDigest=Digest $sessionRecord
$blocks=New-Object 'System.Collections.Generic.List[string]'
if($startDigest -cne $endDigest){AddBlock $blocks 'session_changed_during_authority_review'}
$sessionId=$null
try {
 $sessionJson=[IO.File]::ReadAllText($sessionRecord,(New-Object Text.UTF8Encoding($false,$true)))|ConvertFrom-Json
 $sessionId=[string]$sessionJson.session_id
 Id $sessionId 'current recovery session ID'
}catch{throw 'Current recovery session ID could not be validated.'}
if($receipt[2] -cne $sessionId -or $authority[1] -cne $sessionId){
 AddBlock $blocks 'transaction_session_binding_mismatch'
}
if($receipt[3] -cne $endDigest){AddBlock $blocks 'session_bytes_changed_since_receipt'}
if($receipt[4] -cne $clientObservation.client_fingerprint_sha256 -or
 $authority[2] -cne $clientObservation.client_fingerprint_sha256){
 AddBlock $blocks 'client_directory_binding_mismatch'
}
if($receipt[5] -cne $sessionObservation.client_fingerprint_sha256 -or
 $authority[3] -cne $sessionObservation.client_fingerprint_sha256){
 AddBlock $blocks 'session_directory_binding_mismatch'
}
if($receipt[6] -cne $authority[6]){AddBlock $blocks 'receipt_nonce_not_latest_claim'}
if([int64]$receipt[7] -ne [int64]$authority[4]){
 AddBlock $blocks 'receipt_sequence_not_latest_claim'
}
if([int64]$authority[5] -ge [int64]$receipt[7]){
 AddBlock $blocks 'receipt_reported_as_already_consumed'
}
if([int64]$authority[5] -gt [int64]$authority[4]){
 AddBlock $blocks 'authority_claim_sequence_inconsistent'
}
if($receipt[10] -cne 'explicit_confirmed'){AddBlock $blocks 'consent_not_current'}
if($authority[7] -cne 'claimed_current'){AddBlock $blocks 'independent_latest_state_not_proven'}
$now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
if($now -lt [int64]$receipt[8]){AddBlock $blocks 'receipt_not_yet_issued_according_to_local_clock'}
if($now -ge [int64]$receipt[9]){AddBlock $blocks 'receipt_expired_according_to_local_clock'}
if($review.status -cne 'existing_file_states_need_no_change_NOT_AUTHENTICATED'){
 AddBlock $blocks 'recovery_requires_independent_manual_review'
}
# Even fully consistent caller-authored records NEVER authenticate consent.
$status=if($blocks.Count -eq 0){
 'caller_claims_consistent_NOT_AUTHENTICATED'
}else{
 'manual_review_ownership_and_receipt_claims_blocked'
}
$report=[pscustomobject][ordered]@{
 kind='read_only_recovery_owner_authority_claim_review'
 schema_version=1
 status=$status
 original_recovery_status=[string]$review.status
 blockers=@($blocks.ToArray())
 blocker_count=$blocks.Count
 review_required=$true
 live_client_and_session_folders_observed=$true
 real_owner_authenticated=$false
 independent_latest_state_verified=$false
 approval_receipt_authenticated=$false
 nonce_replay_prevented=$false
 records_real_consent=$false
 allow_file_writes=$false
 allow_automatic_resume=$false
 authorises_rollback=$false
 authorises_file_deletion=$false
 public_distribution_authorised=$false
 limitations='Receipt and latest-state authority are independently named but caller-writable JSON fixtures; coherent replay or forging both remains undetectable. The local clock and folder/file fingerprints are not authenticated. File handles close, TOCTOU remains. This does not prove owner, approval, backup provenance, protected journal state, or install/recovery permission.'
}
if($Json){$report|ConvertTo-Json -Depth 4}
else{
 Write-Host ('Recovery ownership gate: '+$status)
 foreach($block in $blocks){Write-Host ('Manual review: '+$block)}
 Write-Host 'Read-only; no consent authenticated and no file operation permitted.' -ForegroundColor Yellow
}
