#requires -Version 5.1
# Windows disposable FAKE files only. No client writes by production reviewer.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
function Check([bool]$OK,[string]$Label) {
 if(-not $OK){throw ('TEST FAILED: '+$Label)}
 Write-Host ('PASS: '+$Label) -ForegroundColor Green
}
function SaveJson([string]$Path,[object]$Value) {
 [IO.File]::WriteAllText($Path,(ConvertTo-Json -InputObject $Value -Depth 12 -Compress),(New-Object Text.UTF8Encoding($false)))
}
function FileHash([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function FolderId([string]$Path) {
 $result=(& (Join-Path $tools 'Inspect-Naxxramas-DirectoryIdentity.ps1') -ClientPath $Path -Json | Out-String)|ConvertFrom-Json
 return [string]$result.client_fingerprint_sha256
}
function Snapshot([string]$Path){
 return (@(Get-ChildItem -LiteralPath $Path -Recurse -File | Sort-Object FullName | ForEach-Object {
  $_.FullName.Substring($Path.Length)+':'+(FileHash $_.FullName)
 }) -join '|')
}
function Store {
 SaveJson $receiptFile $receipt
 SaveJson $authorityFile $authority
}
function Inspect {
 return ((& $reviewer -ClientPath $client -SessionDirectory $session -ReceiptFixturePath $receiptFile -AuthorityFixturePath $authorityFile -Json | Out-String)|ConvertFrom-Json)
}
function Expect([string]$Expected,[string[]]$Reasons,[string]$Label) {
 $a=Snapshot $client;$b=Snapshot $session;$c=Snapshot $claims
 $report=Inspect
 Check ($report.status -ceq $Expected) $Label
 foreach($reason in $Reasons){ Check (@($report.blockers) -ccontains $reason) ('Blocker '+$reason) }
 Check ($report.review_required -and -not $report.real_owner_authenticated -and -not $report.independent_latest_state_verified -and -not $report.approval_receipt_authenticated -and -not $report.nonce_replay_prevented -and -not $report.records_real_consent -and -not $report.allow_file_writes -and -not $report.allow_automatic_resume -and -not $report.authorises_rollback -and -not $report.authorises_file_deletion -and -not $report.public_distribution_authorised) 'No synthetic claim grants any real permission'
 Check ((Snapshot $client) -ceq $a -and (Snapshot $session) -ceq $b -and (Snapshot $claims) -ceq $c) 'All review input files remain untouched'
 return $report
}
function Reject([string]$Label){
 $failed=$false;try{$null=Inspect}catch{$failed=$true}
 Check $failed $Label
}
$root=Join-Path ([IO.Path]::GetTempPath()) ('NaxxOwnerFixture-'+[guid]::NewGuid().ToString('N'))
$client=Join-Path $root 'client'
$session=Join-Path $root 'session'
$claims=Join-Path $root 'claims'
$tools=Join-Path $root 'tools'
$receiptFile=Join-Path $claims 'receipt.json'
$authorityFile=Join-Path $claims 'authority.json'
$reviewer=Join-Path $tools 'Review-Naxxramas-RecoveryAuthority.ps1'
$now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
try{
 foreach($dir in @($client,$session,$claims,$tools,(Join-Path $client 'Data'),(Join-Path $session 'originals'))){
  $null=New-Item -ItemType Directory -Path $dir -Force
 }
 foreach($name in @('Review-Naxxramas-RecoveryAuthority.ps1','Review-Naxxramas-RecoverySafeguard.ps1','Review-Naxxramas-Recovery.ps1','Inspect-Naxxramas-OpenFileHandles.ps1','Inspect-Naxxramas-DirectoryIdentity.ps1')){
  Copy-Item -LiteralPath (Join-Path (Split-Path -Parent $PSScriptRoot) ('tools/'+$name)) -Destination $tools
 }
 $v=Join-Path $client 'Data/patch-V.mpq'
 $backup=Join-Path $session 'originals/0001.bin'
 [IO.File]::WriteAllText($v,'ORIGINAL_FAKE_V')
 [IO.File]::WriteAllText($backup,'ORIGINAL_FAKE_V')
 $sessionID='fixture-session-123'
 $manifest=[ordered]@{
  schema_version=1;kind='local_naxxramas_setup_transaction';session_id=$sessionID;status='completed';patchset='patchset-0001';target_build=12340;locale='enUS';
  operations=@(
   [ordered]@{relative_path='Data/patch-V.mpq';action='replace_after_backup';was_present=$true;before_sha256=(FileHash $v);before_size_bytes=[int64](Get-Item $v).Length;backup_relative_path='originals/0001.bin';installed_sha256=('a'*64);installed_size_bytes=17;checkpoint='verified'},
   [ordered]@{relative_path='Data/Patch-U.mpq';action='install';was_present=$false;before_sha256=$null;before_size_bytes=$null;backup_relative_path=$null;installed_sha256=('b'*64);installed_size_bytes=20;checkpoint='verified'}
  )
 }
 $sessionFile=Join-Path $session 'session.json'
 SaveJson $sessionFile $manifest
 $nonce='fixture-nonce-123'
 $receipt=@(1,'fixture-receipt-123',$sessionID,(FileHash $sessionFile),(FolderId $client),(FolderId $session),$nonce,7,($now-60),($now+1200),'explicit_confirmed')
 $authority=@(1,$sessionID,$receipt[4],$receipt[5],7,6,$nonce,'claimed_current')
 Store
 $good='caller_claims_consistent_NOT_AUTHENTICATED'
 $blocked='manual_review_ownership_and_receipt_claims_blocked'
 $r=Expect $good @() 'Matching caller claims still unauthenticated'
 Check ($r.original_recovery_status -ceq 'existing_file_states_need_no_change_NOT_AUTHENTICATED') 'Live recovery reviewer observes no necessary file changes'
 $receipt[6]='foreign-nonce-123';Store
 $null=Expect $blocked @('receipt_nonce_not_latest_claim') 'Wrong receipt nonce'
 $receipt[6]=$nonce
 $receipt[7]=6;Store
 $null=Expect $blocked @('receipt_sequence_not_latest_claim','receipt_reported_as_already_consumed') 'Stale consumed sequence'
 $receipt[7]=7
 $authority[5]=7;Store
 $null=Expect $blocked @('receipt_reported_as_already_consumed') 'Current receipt already consumed'
 $authority[5]=6
 $receipt[10]='revoked';Store
 $null=Expect $blocked @('consent_not_current') 'Revoked receipt cannot pass claim checks'
 $receipt[10]='explicit_confirmed'
 $receipt[8]=$now-1800;$receipt[9]=$now-1200;Store
 $null=Expect $blocked @('receipt_expired_according_to_local_clock') 'Expired consent window'
 $receipt[8]=$now-60;$receipt[9]=$now+1200
 $authority[7]='missing';Store
 $null=Expect $blocked @('independent_latest_state_not_proven') 'Missing claimed independent authority'
 $authority[7]='claimed_current'
 $receipt[4]='0'*64;Store
 $null=Expect $blocked @('client_directory_binding_mismatch') 'Foreign client directory fingerprint'
 $receipt[4]=FolderId $client
 $authority[3]='0'*64;Store
 $null=Expect $blocked @('session_directory_binding_mismatch') 'Wrong recovery directory fingerprint'
 $authority[3]=FolderId $session
 $receipt[2]='other-session-123';Store
 $null=Expect $blocked @('transaction_session_binding_mismatch') 'Wrong transaction/session'
 $receipt[2]=$sessionID
 $receipt[3]='0'*64;Store
 $null=Expect $blocked @('session_bytes_changed_since_receipt') 'Wrong session bytes'
 $receipt[3]=FileHash $sessionFile
 $authority[4]=5;Store
 $null=Expect $blocked @('receipt_sequence_not_latest_claim','authority_claim_sequence_inconsistent') 'Authority contradictory sequence'
 $authority[4]=7;Store
 $null=Expect $good @() 'Restored correct test claims'
 [IO.File]::WriteAllText($v,'PLAYER_CUSTOMIZED_FAKE_V')
 $r=Expect $blocked @('recovery_requires_independent_manual_review') 'Player-modified current file fails owner recovery gate'
 Check ($r.original_recovery_status -ceq 'manual_preservation_or_independent_recovery_review') 'Player bytes preserve/manual classification'
 [IO.File]::WriteAllText($v,'ORIGINAL_FAKE_V')
 $manifest.status='rollback_requested';SaveJson $sessionFile $manifest
 $null=Expect $blocked @('session_bytes_changed_since_receipt') 'Changed session data invalidates frozen receipt'
 $manifest.status='completed';SaveJson $sessionFile $manifest
 $receipt[3]=FileHash $sessionFile
 # Coordinated forgery/replay is intentionally UNDETECTABLE from claims alone.
 $receipt[6]='historic-nonce-123';$receipt[7]=3
 $authority[6]=$receipt[6];$authority[4]=3;$authority[5]=2
 Store
 $r=Expect $good @() 'Forged coherent local receipt and authority show why independent trust is required'
 Check (-not $r.approval_receipt_authenticated -and -not $r.nonce_replay_prevented) 'Coherent local replay never creates authority'
 $receipt[7]='3';Store;Reject 'Sequence must be a JSON integer'
 $receipt[7]=3;$receipt[0]=2;Store;Reject 'Unknown receipt schema rejected'
 $receipt[0]=1;$receipt[3]='invalid';Store;Reject 'Invalid checksum rejected'
 $receipt[3]=FileHash $sessionFile;Store
 [IO.File]::WriteAllText($authorityFile,('X'*4097))
 Reject 'Oversized fake latest-state claim rejected'
 Store
 $raw=(& $reviewer -ClientPath $client -SessionDirectory $session -ReceiptFixturePath $receiptFile -AuthorityFixturePath $authorityFile -Json | Out-String)
 Check (-not $raw.Contains($root) -and -not $raw.Contains($nonce) -and -not $raw.Contains((FileHash $v))) 'No paths, original hashes or receipt nonce leaked in report'
 Write-Host 'All Windows synthetic recovery owner gate tests passed.' -ForegroundColor Green
}finally{
 if(Test-Path -LiteralPath $root){Remove-Item -LiteralPath $root -Recurse -Force}
}
