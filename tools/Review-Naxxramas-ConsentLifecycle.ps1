#requires -Version 5.1
<#
Naxxramas Client Setup: read-only, synthetic single-use approval lifecycle.
Every receipt, clock value, plan hash and event is caller-controlled test data.
NO keys, DPAPI, game files, installation state, real consent or writes.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$FixturePath,
    [switch]$Json
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest

function Read-Fixture([string]$Path) {
    if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){
        throw 'An existing ordinary JSON fixture is required.'
    }
    $cursor=[IO.Path]::GetFullPath($Path)
    while($true){
        if(Test-Path -LiteralPath $cursor){
            $item=Get-Item -LiteralPath $cursor -Force
            if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){
                throw 'Fixture junctions, links and reparse ancestors are forbidden.'
            }
        }
        $parent=[IO.Directory]::GetParent($cursor)
        if($null -eq $parent){break}
        $cursor=$parent.FullName
    }
    if((Get-Item -LiteralPath $Path).Length -gt 8192){throw 'Fixture exceeds 8 KiB.'}
    try{
        $bytes=[IO.File]::ReadAllBytes($Path)
        $utf8=New-Object Text.UTF8Encoding($false,$true)
        $raw=$utf8.GetString($bytes)
        Add-Type -AssemblyName System.Web.Extensions -ErrorAction Stop
        $parser=New-Object System.Web.Script.Serialization.JavaScriptSerializer
        $value=$parser.DeserializeObject($raw)
        if(-not ($value -is [array])){throw 'Array required.'}
        return ,$value
    }catch{
        throw 'Invalid UTF-8, JSON or synthetic lifecycle fixture array.'
    }
}
function Require-Number([object]$Value,[string]$Name){
    if((-not ($Value -is [int] -or $Value -is [long])) -or
        [int64]$Value -lt 1 -or [int64]$Value -gt 4102444800){
        throw "$Name must be a bounded JSON integer."
    }
}
function Require-Identifier([object]$Value,[string]$Name){
    if(-not ($Value -is [string]) -or $Value -cnotmatch '^[A-Za-z0-9_-]{8,80}$'){
        throw "Invalid $Name."
    }
}
function Require-Hash([object]$Value,[string]$Name){
    if(-not ($Value -is [string]) -or $Value -cnotmatch '^[a-f0-9]{64}$'){
        throw "Invalid $Name."
    }
}
function Add-Block([System.Collections.Generic.List[string]]$List,[string]$Reason){
    if(-not $List.Contains($Reason)){$List.Add($Reason)}
}

# [1, installationId, nonce, frozenPlanHash, observedPlanHash,
#  issuedUnix, expiresUnix, observedUnix, anchorClaim, events]
# Event: [sequence, 'issued'|'approved'|'use_started'|'finished'|'revoked',
#         nonce, frozenPlanHash, eventUnix]
$f=Read-Fixture $FixturePath
if($f.Count -ne 10 -or -not ($f[0] -is [int] -or $f[0] -is [long]) -or
   [int64]$f[0] -ne 1){throw 'Unknown lifecycle fixture schema.'}
Require-Identifier $f[1] 'installation identifier'
Require-Identifier $f[2] 'synthetic nonce'
Require-Hash $f[3] 'frozen plan digest'
Require-Hash $f[4] 'currently observed plan digest'
foreach($index in @(5,6,7)){Require-Number $f[$index] 'fixture time'}
if([int64]$f[5] -lt 946684800 -or [int64]$f[6] -le [int64]$f[5] -or
   [int64]$f[6] -gt ([int64]$f[5]+3600)){
    throw 'Issued/expiry claims must have a positive maximum one-hour window.'
}
if(-not ($f[8] -is [string]) -or $f[8] -cnotin @(
    'claimed_current','missing','older','ahead','unverified')){
    throw 'Unrecognised authority claim.'
}
$events=$f[9]
if(-not ($events -is [array]) -or $events.Count -gt 12){
    throw 'A bounded events array is required.'
}
$names=@('issued','approved','use_started','finished','revoked')
$states=New-Object 'System.Collections.Generic.List[string]'
$blocks=New-Object 'System.Collections.Generic.List[string]'
$previousTime=[int64]$f[5]
for($i=0;$i -lt $events.Count;$i++){
    $e=$events[$i]
    if(-not ($e -is [array]) -or $e.Count -ne 5){
        throw 'Event is not the fixed five-field array.'
    }
    if(-not ($e[0] -is [int] -or $e[0] -is [long]) -or
        [int64]$e[0] -ne ($i+1)){
        Add-Block $blocks 'event_sequence_invalid'
    }
    if(-not ($e[1] -is [string]) -or $names -cnotcontains $e[1]){
        throw 'Unrecognised event state.'
    }
    Require-Identifier $e[2] 'event nonce'
    Require-Hash $e[3] 'event plan digest'
    Require-Number $e[4] 'event timestamp'
    $states.Add([string]$e[1])
    if($e[2] -cne $f[2] -or $e[3] -cne $f[3]){
        Add-Block $blocks 'event_binding_mismatch'
    }
    if([int64]$e[4] -lt $previousTime -or [int64]$e[4] -gt [int64]$f[7]){
        Add-Block $blocks 'event_timestamp_inconsistent'
    }
    if($e[1] -ceq 'approved' -or $e[1] -ceq 'use_started'){
        if([int64]$e[4] -ge [int64]$f[6]){
            Add-Block $blocks 'approval_or_use_after_expiry'
        }
    }
    $previousTime=[int64]$e[4]
}
# Strict allowed prefixes; anything after 'revoked' or 'finished' is forbidden.
# Revocation after use_started is modelled as an unresolved interrupted
# transaction requiring human investigation, never a way to undo writes.
$sequence=$states.ToArray() -join ','
$valid=@('',
    'issued','issued,approved','issued,approved,use_started',
    'issued,approved,use_started,finished',
    'issued,revoked','issued,approved,revoked',
    'issued,approved,use_started,revoked') -ccontains $sequence
if(-not $valid){Add-Block $blocks 'illegal_lifecycle_transition'}
if(@($states | Where-Object {$_ -ceq 'use_started'}).Count -gt 1){
    Add-Block $blocks 'repeated_use_attempt'
}
if(@($states | Where-Object {$_ -ceq 'approved'}).Count -gt 1){
    Add-Block $blocks 'repeated_approval_event'
}
if([int64]$f[7] -lt [int64]$f[5]){Add-Block $blocks 'observation_before_issue'}
if($f[3] -cne $f[4]){Add-Block $blocks 'current_plan_differs_from_approved_digest'}
if($f[8] -cne 'claimed_current'){Add-Block $blocks 'latest_state_authority_unverified'}
if([int64]$f[7] -ge [int64]$f[6]){Add-Block $blocks 'consent_window_expired'}

if($states.Contains('revoked')){Add-Block $blocks 'consent_revoked'}
if($states.Contains('use_started')){Add-Block $blocks 'consent_already_used_or_transaction_started'}
if($states.Contains('finished')){Add-Block $blocks 'consent_already_consumed'}
if(-not $states.Contains('approved')){Add-Block $blocks 'explicit_consent_not_observed'}

$status=if($blocks.Count -eq 0 -and $sequence -ceq 'issued,approved'){
    'fixture_claims_unused_NOT_AUTHENTICATED'
}else{
    'manual_review_consent_lifecycle_blocked'
}
$report=[pscustomobject][ordered]@{
    kind='read_only_untrusted_single_use_consent_fixture'
    schema_version=1
    status=$status
    event_count=$events.Count
    blockers=@($blocks.ToArray())
    blocker_count=$blocks.Count
    review_required=$true
    allow_file_writes=$false
    allow_automatic_resume=$false
    authorises_rollback=$false
    records_real_consent=$false
    permits_token_consumption=$false
    limitations='All timestamps, IDs, hashes, event history and anchor claims are caller-controlled. Rolling the event list back from used to approved can appear unused. No time authority, real consent, nonce store, key, monotonic log, live file or journal is checked.'
}
if($Json){$report | ConvertTo-Json -Depth 4}
else{
    Write-Host ('Synthetic consent review: '+$status)
    foreach($reason in $blocks){Write-Host ('Review: '+$reason)}
    Write-Host 'Read-only. Never use this fixture to approve or perform a client write.' -ForegroundColor Yellow
}
