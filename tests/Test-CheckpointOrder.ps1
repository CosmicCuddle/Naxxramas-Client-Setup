#requires -Version 5.1
# Test-only generated JSON. No WoW client, MPQ, recovery or journal writes.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Check([bool]$Ok,[string]$Label) {
    if (-not $Ok) { throw "TEST FAILED: $Label" }
    Write-Host "PASS: $Label" -ForegroundColor Green
}
$expected = @(
    'user_approved','staging_verified','original_v_preserved',
    'original_z_preserved','intent_v_recorded','destination_v_replaced',
    'destination_v_verified','intent_z_recorded','destination_z_replaced',
    'destination_z_verified','both_core_verified','journal_completion_recorded',
    'latest_anchor_published'
)
function Fixture([int]$Count=13,[int]$Journal=$Count,[int]$Anchor=$Journal,
    [string]$Claim='claimed_matching') {
    $events = [Array]::CreateInstance([object],$Count)
    for($i=0;$i -lt $Count;$i++) { $events[$i] = $expected[$i] }
    $value = [Array]::CreateInstance([object],6)
    $value[0] = 1
    $value[1] = 'fixture-install-123'
    $value[2] = $Journal
    $value[3] = $Anchor
    $value[4] = $Claim
    $value[5] = $events
    return ,$value
}
function Save([object]$Value) {
    $raw = ConvertTo-Json -InputObject $Value -Compress -Depth 9
    [IO.File]::WriteAllText($path,$raw,(New-Object Text.UTF8Encoding($false)))
}
function Inspect {
    return ((& $reviewer -FixturePath $path -Json | Out-String) | ConvertFrom-Json)
}
function Expect([object]$Value,[string]$Want,[string]$Why) {
    Save $Value
    $before = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    $got = Inspect
    Check ($got.classification -ceq $Want) ($Why + ' => ' + $got.classification)
    Check (-not $got.allow_file_writes -and -not $got.allow_automatic_resume -and
        -not $got.authorises_rollback) 'All outcomes forbid writes, resume and rollback'
    $after = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    Check ($before -ceq $after) 'Input fixture bytes are unchanged'
}
function Invalid([object]$Value,[string]$Why) {
    Save $Value
    $blocked = $false
    try { $null = Inspect } catch { $blocked = $true }
    Check $blocked $Why
}
$reviewer = Join-Path (Split-Path -Parent $PSScriptRoot) 'tools/Review-Naxxramas-CheckpointOrder.ps1'
$root = Join-Path ([IO.Path]::GetTempPath()) ('NaxxCheckpointFixture-' + [guid]::NewGuid().ToString('N'))
$path = Join-Path $root 'ordering-fixture.json'
try {
    $null = New-Item -ItemType Directory -Path $root
    for($n=0;$n -lt $expected.Count;$n++) {
        Expect (Fixture -Count $n) 'manual_review_incomplete_checkpoint_sequence' ("Interruption after $n of 13 proposed stages")
    }
    Expect (Fixture) 'fixture_fields_consistent_NOT_trusted' 'All 13 claimed stages are consistent, not trusted'
    Expect (Fixture -Count 13 -Anchor 12) 'manual_review_anchor_behind' 'Journal completion ahead of anchor publication'
    Expect (Fixture -Count 13 -Anchor 14) 'manual_review_older_journal_or_anchor_ahead' 'Anchor ahead of journal is possible replay'
    Expect (Fixture -Count 12 -Anchor 13) 'manual_review_older_journal_or_anchor_ahead' 'Journal is older than external anchor'
    Expect (Fixture -Count 7 -Journal 8 -Anchor 8) 'manual_review_journal_sequence_mismatch' 'Journal sequence does not equal event count'
    foreach($kind in @('missing','unreadable','wrong_installation','key_lost')) {
        Expect (Fixture -Claim $kind) 'manual_review_anchor_unavailable_or_wrong' ("Trust unavailable: "+$kind)
    }

    $outOfOrder = Fixture
    $temp = $outOfOrder[5][5]
    $outOfOrder[5][5] = $outOfOrder[5][6]
    $outOfOrder[5][6] = $temp
    Expect $outOfOrder 'manual_review_order_violation' 'Replacement verified before replacement event is rejected'
    $duplicate = Fixture
    $duplicate[5][6] = $duplicate[5][5]
    Expect $duplicate 'manual_review_order_violation' 'Duplicate stage is rejected'
    $skipped = Fixture
    $skipped[5][4] = 'intent_z_recorded'
    Expect $skipped 'manual_review_order_violation' 'Skipped V write intent is rejected'
    $unknown = Fixture
    $unknown[5][3] = 'arbitrary_write'
    Expect $unknown 'manual_review_order_violation' 'Unapproved operation is not part of the schedule'
    $replay = Fixture
    $replay[1] = 'fixture-oldinstall'
    Expect $replay 'fixture_fields_consistent_NOT_trusted' 'Fully replayed coherent journal plus anchor CANNOT be detected using caller data alone'

    $badSchema = Fixture
    $badSchema[0] = 2
    Invalid $badSchema 'Unknown version is rejected'
    $badId = Fixture
    $badId[1] = 'x'
    Invalid $badId 'Invalid installation identity rejected'
    $badSeq = Fixture
    $badSeq[2] = '13'
    Invalid $badSeq 'Sequence as JSON string rejected'
    $badAnchor = Fixture
    $badAnchor[4] = 'trusted'
    Invalid $badAnchor 'Invented trust label rejected'
    $badShape = [Array]::CreateInstance([object],7)
    $good = Fixture
    for($i=0;$i -lt 6;$i++){ $badShape[$i]=$good[$i] }
    $badShape[6]='extra'
    Invalid $badShape 'Unknown additional fields rejected'
    $tooMany = Fixture
    $tooMany[5] = [Array]::CreateInstance([object],14)
    Invalid $tooMany 'More than 13 stages rejected'

    [IO.File]::WriteAllText($path,'{"status":"ok","status":"bad"}')
    $objectBlocked=$false
    try { $null=Inspect } catch { $objectBlocked=$true }
    Check $objectBlocked 'JSON object with duplicate keys rejected'
    [IO.File]::WriteAllText($path,('x' * 8193))
    $oversizeBlocked=$false
    try { $null=Inspect } catch { $oversizeBlocked=$true }
    Check $oversizeBlocked 'Oversized JSON rejected'
    Remove-Item -LiteralPath $path
    $missingBlocked=$false
    try { $null=Inspect } catch { $missingBlocked=$true }
    Check $missingBlocked 'Missing fixture rejected without creation'

    Save (Fixture)
    $raw = (& $reviewer -FixturePath $path -Json | Out-String)
    Check (-not $raw.Contains($root)) 'Report omits local paths'
    Check (-not $raw.Contains('fixture-install-123')) 'Report omits installation identity'
    Write-Host 'All synthetic checkpoint ordering tests passed.' -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
