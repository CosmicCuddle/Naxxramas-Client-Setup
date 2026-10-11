#requires -Version 5.1
<#
Read-only SYNTHETIC checkpoint ordering inspector.
Checks only caller-authored timeline claims, not files, protected
registration, journal authenticity or actual flush/rename durability.
Never authorises client writes, automatic resume or rollback.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$FixturePath,
    [switch]$Json
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Read-CheckpointFixture([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw 'Synthetic checkpoint fixture must be an existing file.'
    }
    $cursor = [IO.Path]::GetFullPath($Path)
    while ($true) {
        if (Test-Path -LiteralPath $cursor) {
            $part = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
            if (($part.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw 'Linked or junction-backed fixture paths are not allowed.'
            }
        }
        $parent = [IO.Directory]::GetParent($cursor)
        if ($null -eq $parent) { break }
        $cursor = $parent.FullName
    }
    if ((Get-Item -LiteralPath $Path).Length -gt 8192) {
        throw 'Synthetic checkpoint fixture exceeds the 8 KiB limit.'
    }
    $utf8 = New-Object Text.UTF8Encoding($false,$true)
    try {
        $body = $utf8.GetString([IO.File]::ReadAllBytes($Path))
        Add-Type -AssemblyName System.Web.Extensions -ErrorAction Stop
        $parser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
        $value = $parser.DeserializeObject($body)
        if (-not ($value -is [array])) { throw 'Expected a positional JSON array.' }
        return ,$value
    } catch {
        throw 'Invalid or unsupported synthetic checkpoint fixture JSON.'
    }
}
function Require-Sequence([object]$Number,[string]$Label) {
    if (-not ($Number -is [int] -or $Number -is [long]) -or
        [int64]$Number -lt 0 -or [int64]$Number -gt 100000000) {
        throw "$Label must be a nonnegative JSON integer."
    }
}
# [version, installationId, journalSequence, anchorSequence,
#  anchorClaim, [eventNames]]
$fixture = Read-CheckpointFixture $FixturePath
if ($fixture.Count -ne 6 -or
    -not ($fixture[0] -is [int] -or $fixture[0] -is [long]) -or
    [int64]$fixture[0] -ne 1) {
    throw 'Unknown checkpoint fixture schema.'
}
if (-not ($fixture[1] -is [string]) -or
    $fixture[1] -cnotmatch '^[A-Za-z0-9_-]{8,80}$') {
    throw 'Invalid fixture installation identity.'
}
Require-Sequence $fixture[2] 'Journal sequence'
Require-Sequence $fixture[3] 'External anchor sequence'
if (-not ($fixture[4] -is [string]) -or
    $fixture[4] -cnotin @('claimed_matching','missing','unreadable','wrong_installation','key_lost')) {
    throw 'Invalid external anchor observation.'
}
$events = $fixture[5]
if (-not ($events -is [array]) -or $events.Count -gt 13) {
    throw 'Checkpoint events must be a bounded JSON array.'
}
# Ordered *hypothetical* persistence barriers. Names are policy labels;
# nothing in this tool invokes Windows flush, replace, or filesystem APIs.
$expected = @(
    'user_approved',
    'staging_verified',
    'original_v_preserved',
    'original_z_preserved',
    'intent_v_recorded',
    'destination_v_replaced',
    'destination_v_verified',
    'intent_z_recorded',
    'destination_z_replaced',
    'destination_z_verified',
    'both_core_verified',
    'journal_completion_recorded',
    'latest_anchor_published'
)
$orderValid = $true
for ($i=0; $i -lt $events.Count; $i++) {
    if (-not ($events[$i] -is [string]) -or $events[$i] -cne $expected[$i]) {
        $orderValid = $false
    }
}
$journalSeq = [int64]$fixture[2]
$anchorSeq = [int64]$fixture[3]
$status = $null
if (-not $orderValid) {
    $status = 'manual_review_order_violation'
} elseif ($journalSeq -ne $events.Count) {
    $status = 'manual_review_journal_sequence_mismatch'
} elseif ($fixture[4] -cne 'claimed_matching') {
    $status = 'manual_review_anchor_unavailable_or_wrong'
} elseif ($anchorSeq -gt $journalSeq) {
    $status = 'manual_review_older_journal_or_anchor_ahead'
} elseif ($anchorSeq -lt $journalSeq) {
    $status = 'manual_review_anchor_behind'
} elseif ($events.Count -lt $expected.Count) {
    $status = 'manual_review_incomplete_checkpoint_sequence'
} else {
    $status = 'fixture_fields_consistent_NOT_trusted'
}
$report = [pscustomobject][ordered]@{
    kind = 'read_only_untrusted_checkpoint_ordering_fixture'
    schema_version = 1
    classification = $status
    event_count = $events.Count
    expected_event_count = $expected.Count
    ordering_matches_design = $orderValid
    anchor_observation = [string]$fixture[4]
    allow_file_writes = $false
    allow_automatic_resume = $false
    authorises_rollback = $false
    limitations = 'All sequences, event labels and external anchor claims are untrusted input; a coordinated old journal and old anchor remain indistinguishable. This proves no disk flushing, persistence, trust or crash survival.'
}
if ($Json) {
    $report | ConvertTo-Json -Depth 3
} else {
    Write-Host 'Naxxramas Client Setup - READ ONLY SYNTHETIC CHECKPOINT ORDERING' -ForegroundColor Cyan
    Write-Host ("Classification: {0}" -f $status)
    Write-Host 'Never permits game-file writes, recovery or automatic resume.' -ForegroundColor Yellow
}
