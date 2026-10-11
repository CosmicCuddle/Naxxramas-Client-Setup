#requires -Version 5.1
# Disposable synthetic JSON only. No WoW client, secret, key or durable journal.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest

function Check([bool]$Ok,[string]$Why){
    if(-not $Ok){throw "TEST FAILED: $Why"}
    Write-Host ("PASS: "+$Why) -ForegroundColor Green
}
$issue=1791720000
$hash='a'*64
$nonce='nonce-fixture-123'
$blocked='manual_review_consent_lifecycle_blocked'
$ready='fixture_claims_unused_NOT_AUTHENTICATED'
function Events([string[]]$Names=@('issued','approved')){
    $out=@()
    for($i=0;$i -lt $Names.Count;$i++){
        $out+=,@(($i+1),$Names[$i],$nonce,$hash,($issue+($i*60)))
    }
    return ,$out
}
function Fixture([object]$Items=(Events)){
    return ,@(1,'installation-123',$nonce,$hash,$hash,$issue,($issue+600),($issue+180),'claimed_current',$Items)
}
function Save([object]$Value){
    $json=ConvertTo-Json -InputObject $Value -Depth 10 -Compress
    [IO.File]::WriteAllText($path,$json,(New-Object Text.UTF8Encoding($false)))
}
function Inspect{
    return ((& $reviewer -FixturePath $path -Json | Out-String) | ConvertFrom-Json)
}
function Expect([object]$Fixture,[string]$Status,[string[]]$Reasons,[string]$Why){
    Save $Fixture
    $before=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    $result=Inspect
    Check ($result.status -ceq $Status) ($Why+': '+$result.status)
    Check ($result.review_required -and -not $result.allow_file_writes -and
        -not $result.allow_automatic_resume -and -not $result.authorises_rollback -and
        -not $result.records_real_consent -and -not $result.permits_token_consumption) 'No simulated event permits a real operation'
    $blocks=@($result.blockers)
    Check ($blocks.Count -eq [int]$result.blocker_count) 'Reported blocker count is exact'
    foreach($reason in $Reasons){
        Check ($blocks -ccontains $reason) ('Blocks: '+$reason)
    }
    Check ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ceq $before) 'Inspection preserves fixture bytes'
}
function Invalid([object]$Value,[string]$Why){
    Save $Value
    $failed=$false
    try{$null=Inspect}catch{$failed=$true}
    Check $failed $Why
}
$root=Join-Path ([IO.Path]::GetTempPath()) ('NaxxConsentReview-'+[guid]::NewGuid().ToString('N'))
$path=Join-Path $root 'consent.json'
$reviewer=Join-Path (Split-Path -Parent $PSScriptRoot) 'tools/Review-Naxxramas-ConsentLifecycle.ps1'
try{
    $null=New-Item -ItemType Directory -Path $root
    Expect (Fixture) $ready @() 'Issued and approved within window is only a claimed unused token'
    Expect (Fixture (Events @())) $blocked @('explicit_consent_not_observed') 'No event means no consent'
    Expect (Fixture (Events @('issued'))) $blocked @('explicit_consent_not_observed') 'Issued but never approved'
    Expect (Fixture (Events @('issued','revoked'))) $blocked @('consent_revoked','explicit_consent_not_observed') 'Revocation before approval'
    Expect (Fixture (Events @('issued','approved','revoked'))) $blocked @('consent_revoked') 'Revocation after approval'
    Expect (Fixture (Events @('issued','approved','use_started'))) $blocked @('consent_already_used_or_transaction_started') 'Token burned before proposed transaction'
    Expect (Fixture (Events @('issued','approved','use_started','finished'))) $blocked @('consent_already_consumed') 'Finished transaction cannot reuse token'
    Expect (Fixture (Events @('issued','approved','use_started','revoked'))) $blocked @('consent_revoked','consent_already_used_or_transaction_started') 'Cancellation after claimed write start does not automatically undo changes'
    Expect (Fixture (Events @('issued','approved','use_started','use_started'))) $blocked @('repeated_use_attempt','illegal_lifecycle_transition') 'Repeated transaction use is detected'
    Expect (Fixture (Events @('issued','approved','approved'))) $blocked @('repeated_approval_event','illegal_lifecycle_transition') 'Repeated approval is detected'
    Expect (Fixture (Events @('issued','approved','finished'))) $blocked @('illegal_lifecycle_transition') 'Finished without start is invalid'
    Expect (Fixture (Events @('issued','revoked','approved'))) $blocked @('illegal_lifecycle_transition','consent_revoked') 'Revoked token cannot be reapproved'
    Expect (Fixture (Events @('issued','approved','use_started','finished','revoked'))) $blocked @('illegal_lifecycle_transition','consent_revoked') 'Late revocation does not make completed session valid'
    Expect (Fixture (Events @('approved'))) $blocked @('illegal_lifecycle_transition') 'Approval without issuance invalid'

    $v=Fixture; $v[4]='b'*64
    Expect $v $blocked @('current_plan_differs_from_approved_digest') 'Plan hash changed after approval'
    $v=Fixture; $v[8]='older'
    Expect $v $blocked @('latest_state_authority_unverified') 'Reported latest anchor older'
    foreach($claim in @('missing','ahead','unverified')){
        $v=Fixture; $v[8]=$claim
        Expect $v $blocked @('latest_state_authority_unverified') ('Authority claim '+$claim)
    }
    $v=Fixture; $v[7]=$issue+600
    Expect $v $blocked @('consent_window_expired') 'Consent validity window expired at boundary'
    $v=Fixture; $v[7]=$issue-1
    Expect $v $blocked @('observation_before_issue','event_timestamp_inconsistent') 'Clock observation precedes issuance'
    $v=Fixture; $v[9][1][4]=$issue+650; $v[7]=$issue+700
    Expect $v $blocked @('approval_or_use_after_expiry') 'Approval after expiry never becomes usable'
    $v=Fixture; $v[9][1][4]=$issue-1
    Expect $v $blocked @('event_timestamp_inconsistent') 'Event timestamp regresses'
    $v=Fixture; $v[9][1][2]='other-nonce-123'
    Expect $v $blocked @('event_binding_mismatch') 'Event nonce must match frozen consent'
    $v=Fixture; $v[9][1][3]='0'*64
    Expect $v $blocked @('event_binding_mismatch') 'Event plan digest must match frozen approval'
    $v=Fixture; $v[9][1][0]=4
    Expect $v $blocked @('event_sequence_invalid') 'Skipped event index invalid'
    $v=Fixture; $v[9][1][0]=1
    Expect $v $blocked @('event_sequence_invalid') 'Duplicate event index invalid'

    # A complete caller-controlled replay of a historic issued+approved list
    # cannot be identified without a separately trusted latest-use authority.
    $historic=Fixture; $historic[1]='older-install-123'
    Expect $historic $ready @() 'Coherent old history falsely appears unused; never authenticates'

    $v=Fixture; $v[0]=2
    Invalid $v 'Wrong schema version rejected'
    $v=Fixture; $v[1]='x'
    Invalid $v 'Installation ID syntax enforced'
    $v=Fixture; $v[2]='x'
    Invalid $v 'Nonce syntax enforced'
    $v=Fixture; $v[3]='not-a-digest'
    Invalid $v 'Malformed frozen SHA-256 rejected'
    $v=Fixture; $v[8]='secure'
    Invalid $v 'Unknown authority claim rejected'
    $v=Fixture; $v[5]='1791720000'
    Invalid $v 'Timestamp must be integer not string'
    $v=Fixture; $v[6]=$issue+3601
    Invalid $v 'Approval lifetime above 1 hour rejected'
    $v=Fixture; $v[6]=$issue
    Invalid $v 'Zero-length approval lifetime rejected'
    $v=Fixture; $v[9][0][1]='hidden_write'
    Invalid $v 'Unknown event type rejected'
    $v=Fixture; $v[9][0][4]='1791720000'
    Invalid $v 'Event timestamp must be JSON integer'
    $v=Fixture; $v[9][0]+=@('extra')
    Invalid $v 'Extra event field rejected'
    $v=Fixture; $v[9]=@('text')
    Invalid $v 'String event rejected'

    [IO.File]::WriteAllText($path,'{"state":"issued","state":"approved"}')
    $failed=$false;try{$null=Inspect}catch{$failed=$true}
    Check $failed 'Duplicate-property object input rejected'
    [IO.File]::WriteAllText($path,('X'*8193))
    $failed=$false;try{$null=Inspect}catch{$failed=$true}
    Check $failed 'Oversized synthetic fixture rejected'
    Remove-Item -LiteralPath $path
    $failed=$false;try{$null=Inspect}catch{$failed=$true}
    Check $failed 'Missing file not created by reviewer'

    Save (Fixture)
    $raw=(& $reviewer -FixturePath $path -Json | Out-String)
    Check (-not $raw.Contains($root)) 'No local fixture path disclosed'
    Check (-not $raw.Contains($nonce)) 'No consent nonce disclosed'
    Check (-not $raw.Contains($hash)) 'No plan SHA disclosed'
    Check (-not (Test-Path -LiteralPath (Join-Path $root 'auth-state'))) 'No persistent authority created'
    Write-Host 'All synthetic consent lifecycle tests passed.' -ForegroundColor Green
}finally{
    if(Test-Path -LiteralPath $root){Remove-Item -LiteralPath $root -Force -Recurse}
}
