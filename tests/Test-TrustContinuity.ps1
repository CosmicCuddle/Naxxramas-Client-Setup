#requires -Version 5.1
# Disposable untrusted JSON only; no actual client, game files or keys.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Check([bool]$Ok,[string]$Label) {
    if (-not $Ok) { throw "TEST FAILED: $Label" }
    Write-Host "PASS: $Label" -ForegroundColor Green
}
function Baseline {
    return ,@(1,'synthetic-install-123','same_object','claimed_registered',
        'claimed_available','claimed_present',13,13,'claimed_completed',
        'claimed_verified','claimed_verified_local','preview_acknowledged')
}
function Save([object]$Value) {
    $raw = ConvertTo-Json -InputObject $Value -Compress -Depth 5
    [IO.File]::WriteAllText($fixturePath,$raw,(New-Object System.Text.UTF8Encoding($false)))
}
function Inspect {
    return ((& $inspector -FixturePath $fixturePath -Json | Out-String) | ConvertFrom-Json)
}
function Review([object]$Fixture,[string]$Expected,[string[]]$RequiredBlockers,[string]$Description) {
    Save $Fixture
    $before = (Get-FileHash -LiteralPath $fixturePath -Algorithm SHA256).Hash
    $result = Inspect
    Check ($result.status -ceq $Expected) ($Description + ': ' + $result.status)
    $denied = $result.manual_review_required -and -not $result.allow_file_writes -and
        -not $result.allow_automatic_resume -and -not $result.authorises_rollback -and
        -not $result.allow_silent_reregistration -and $result.preserve_existing_backups
    Check $denied 'Never permit automatic write, resume, rollback, registration or backup deletion'
    $seen = @($result.blockers)
    Check ($seen.Count -eq [int]$result.blocker_count) 'All blocker counts match reported issues'
    foreach($block in $RequiredBlockers) {
        Check ($seen -ccontains $block) ('Exposes independent blocker: ' + $block)
    }
    Check ($before -ceq (Get-FileHash -LiteralPath $fixturePath -Algorithm SHA256).Hash) 'Input fixture bytes remain unchanged'
}
function Rejection([object]$Fixture,[string]$Description) {
    Save $Fixture
    $blocked = $false
    try { $null = Inspect } catch { $blocked = $true }
    Check $blocked $Description
}
$root = Join-Path ([IO.Path]::GetTempPath()) ('NaxxTrustReview-' + [guid]::NewGuid().ToString('N'))
$fixturePath = Join-Path $root 'trust.json'
$inspector = Join-Path (Split-Path -Parent $PSScriptRoot) 'tools/Review-Naxxramas-TrustContinuity.ps1'
$blockedStatus = 'manual_review_trust_continuity_blocked'
try {
    $null = New-Item -ItemType Directory -Path $root
    Review (Baseline) 'fixture_claims_consistent_NOT_authenticated' @() 'All matching records remain unauthenticated claims'
    $f = Baseline; $f[2]='renamed_same_object'
    Review $f 'fixture_claims_consistent_NOT_authenticated' @() 'Renamed observed folder is not automatically approved'

    foreach($name in @('copied_or_replaced','moved_volume','missing','unverified')) {
        $f=Baseline; $f[2]=$name
        Review $f $blockedStatus @('folder_identity_not_confirmed') ('Folder scenario '+$name)
    }
    foreach($name in @('missing','damaged','foreign_installation','replayed','unverified')) {
        $f=Baseline; $f[3]=$name
        Review $f $blockedStatus @('registration_unavailable_or_disputed') ('Registration scenario '+$name)
    }
    foreach($name in @('missing','cannot_decrypt','different_windows_account','new_computer','unverified')) {
        $f=Baseline; $f[4]=$name
        Review $f $blockedStatus @('key_unavailable_or_account_changed') ('Key scenario '+$name)
    }
    foreach($name in @('missing','damaged','unverified','older_snapshot','foreign_installation')) {
        $f=Baseline; $f[5]=$name
        Review $f $blockedStatus @('independent_latest_anchor_not_confirmed') ('Anchor scenario '+$name)
    }
    $f=Baseline; $f[7]=12
    Review $f $blockedStatus @('journal_older_than_anchor') 'Older journal versus newer anchor'
    $f=Baseline; $f[6]=12
    Review $f $blockedStatus @('anchor_older_than_journal') 'Older anchor versus newer journal'
    foreach($name in @('incomplete','missing','invalid','rollback_in_progress')) {
        $f=Baseline; $f[8]=$name
        Review $f $blockedStatus @('session_not_confirmed_complete') ('Journal checkpoint '+$name)
    }
    $f=Baseline; $f[6]=0; $f[7]=0
    Review $f $blockedStatus @('session_not_confirmed_complete') 'Zero-sequence completed claim'
    foreach($name in @('missing','damaged','unverified','foreign_installation')) {
        $f=Baseline; $f[9]=$name
        Review $f $blockedStatus @('original_backup_unverified') ('Backup '+$name)
    }
    foreach($name in @('missing','unapproved_provenance','unverified')) {
        $f=Baseline; $f[10]=$name
        Review $f $blockedStatus @('patch_provenance_unverified') ('Patch source '+$name)
    }
    foreach($name in @('missing','expired')) {
        $f=Baseline; $f[11]=$name
        Review $f $blockedStatus @('user_preview_not_current') ('Preview consent '+$name)
    }

    $f=Baseline
    $f[2]='copied_or_replaced'; $f[3]='missing'; $f[4]='different_windows_account'
    $f[5]='older_snapshot'; $f[6]=13; $f[7]=12; $f[8]='incomplete'
    $f[9]='damaged'; $f[10]='unapproved_provenance'; $f[11]='expired'
    Review $f $blockedStatus @(
        'folder_identity_not_confirmed','registration_unavailable_or_disputed',
        'key_unavailable_or_account_changed','independent_latest_anchor_not_confirmed',
        'journal_older_than_anchor','session_not_confirmed_complete',
        'original_backup_unverified','patch_provenance_unverified',
        'user_preview_not_current'
    ) 'All independent failures are exposed together'

    # Deliberate security limitation: fully replayed coherent old state.
    $replay=Baseline; $replay[1]='oldinstall-123'; $replay[6]=4; $replay[7]=4
    Review $replay 'fixture_claims_consistent_NOT_authenticated' @() 'Fully coherent old records evade detection without external trust'

    $wrongVersion=Baseline; $wrongVersion[0]=2
    Rejection $wrongVersion 'Unsupported schema version rejected'
    $short=[Array]::CreateInstance([object],11)
    $base=Baseline; for($i=0;$i -lt 11;$i++){ $short[$i]=$base[$i] }
    Rejection $short 'Missing field rejected'
    $extra=[Array]::CreateInstance([object],13)
    for($i=0;$i -lt 12;$i++){ $extra[$i]=$base[$i] }; $extra[12]='x'
    Rejection $extra 'Extra field rejected'
    $invalidId=Baseline; $invalidId[1]='x'
    Rejection $invalidId 'Invalid ID rejected'
    $stringSeq=Baseline; $stringSeq[6]='13'
    Rejection $stringSeq 'String sequence rejected'
    $floatSeq=Baseline; $floatSeq[7]=1.5
    Rejection $floatSeq 'Fractional sequence rejected'
    $negativeSeq=Baseline; $negativeSeq[7]=-1
    Rejection $negativeSeq 'Negative sequence rejected'
    $wrongKey=Baseline; $wrongKey[4]='confirmed_trusted'
    Rejection $wrongKey 'Invented key status rejected'
    $caseChange=Baseline; $caseChange[2]='SAME_OBJECT'
    Rejection $caseChange 'Case-altered status rejected'

    [IO.File]::WriteAllText($fixturePath,'{"state":"good","state":"bad"}')
    $badObject=$false; try { $null=Inspect } catch { $badObject=$true }
    Check $badObject 'Object and duplicate JSON properties rejected'
    [IO.File]::WriteAllText($fixturePath,('x' * 8193))
    $tooLarge=$false; try { $null=Inspect } catch { $tooLarge=$true }
    Check $tooLarge 'Oversized fixture rejected'
    Remove-Item -LiteralPath $fixturePath
    $missingFile=$false; try { $null=Inspect } catch { $missingFile=$true }
    Check $missingFile 'Missing fixture not silently recreated'

    Save (Baseline)
    $raw=(& $inspector -FixturePath $fixturePath -Json | Out-String)
    Check (-not $raw.Contains($root)) 'No local path disclosed'
    Check (-not $raw.Contains('synthetic-install-123')) 'No installation identity disclosed'
    Check (-not (Test-Path -LiteralPath (Join-Path $root 'registered-client'))) 'No registration or output directory created'
    Write-Host 'All read-only synthetic trust-continuity tests passed.' -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
