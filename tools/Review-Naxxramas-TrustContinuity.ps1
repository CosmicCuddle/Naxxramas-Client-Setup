#requires -Version 5.1
<#
Naxxramas Client Setup - READ-ONLY synthetic trust continuity review.
Accepts caller-controlled labels, NOT production registration evidence.
No DPAPI calls, keys, client files, rollback, source downloads or writes.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$FixturePath,
    [switch]$Json
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Read-TrustFixture([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw 'Existing ordinary JSON fixture required.'
    }
    $cursor = [IO.Path]::GetFullPath($Path)
    while ($true) {
        if (Test-Path -LiteralPath $cursor) {
            $node = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
            if (($node.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw 'Linked or reparse-point fixture paths are forbidden.'
            }
        }
        $parent = [IO.Directory]::GetParent($cursor)
        if ($null -eq $parent) { break }
        $cursor = $parent.FullName
    }
    if ((Get-Item -LiteralPath $Path).Length -gt 8192) {
        throw 'Fixture is larger than 8 KiB.'
    }
    $utf8 = New-Object System.Text.UTF8Encoding($false,$true)
    try {
        $raw = $utf8.GetString([IO.File]::ReadAllBytes($Path))
        Add-Type -AssemblyName System.Web.Extensions -ErrorAction Stop
        $deserializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
        $parsed = $deserializer.DeserializeObject($raw)
        if (-not ($parsed -is [array])) { throw 'Expected positional JSON array.' }
        return ,$parsed
    } catch {
        throw 'Fixture has invalid UTF-8, JSON or top-level array shape.'
    }
}
function Require-Choice([object]$Value,[string[]]$Allowed,[string]$Label) {
    if (-not ($Value -is [string]) -or $Allowed -cnotcontains $Value) {
        throw "Unsupported $Label."
    }
}
function Require-Sequence([object]$Value,[string]$Label) {
    if (-not ($Value -is [int] -or $Value -is [long]) -or
        [int64]$Value -lt 0 -or [int64]$Value -gt 100000000) {
        throw "$Label must be a JSON integer in the allowed range."
    }
}

# [1, installation_id, folder_state, registration_state, key_state,
#  anchor_state, anchor_sequence, journal_sequence, session_checkpoint,
#  original_backup_state, source_provenance, preview_consent]
# ALL values, even "available" or "verified", are UNTRUSTED CLAIMS.
$r = Read-TrustFixture $FixturePath
if ($r.Count -ne 12 -or
    -not ($r[0] -is [int] -or $r[0] -is [long]) -or [int64]$r[0] -ne 1) {
    throw 'Unknown trust-continuity fixture version or field count.'
}
if (-not ($r[1] -is [string]) -or $r[1] -cnotmatch '^[A-Za-z0-9_-]{8,80}$') {
    throw 'Invalid synthetic installation ID.'
}
Require-Choice $r[2] @('same_object','renamed_same_object','copied_or_replaced','moved_volume','missing','unverified') 'folder identity'
Require-Choice $r[3] @('claimed_registered','missing','damaged','foreign_installation','replayed','unverified') 'registration'
Require-Choice $r[4] @('claimed_available','missing','cannot_decrypt','different_windows_account','new_computer','unverified') 'key continuity'
Require-Choice $r[5] @('claimed_present','missing','damaged','unverified','older_snapshot','foreign_installation') 'independent latest anchor'
Require-Sequence $r[6] 'Anchor sequence'
Require-Sequence $r[7] 'Journal sequence'
Require-Choice $r[8] @('claimed_completed','incomplete','missing','invalid','rollback_in_progress') 'session checkpoint'
Require-Choice $r[9] @('claimed_verified','missing','damaged','unverified','foreign_installation') 'original backup'
Require-Choice $r[10] @('claimed_verified_local','missing','unapproved_provenance','unverified') 'patch source'
Require-Choice $r[11] @('preview_acknowledged','missing','expired') 'user preview consent'

$blocks = New-Object 'System.Collections.Generic.List[string]'
if ($r[2] -cnotin @('same_object','renamed_same_object')) { $blocks.Add('folder_identity_not_confirmed') }
if ($r[3] -cne 'claimed_registered') { $blocks.Add('registration_unavailable_or_disputed') }
if ($r[4] -cne 'claimed_available') { $blocks.Add('key_unavailable_or_account_changed') }
if ($r[5] -cne 'claimed_present') { $blocks.Add('independent_latest_anchor_not_confirmed') }
if ([int64]$r[7] -lt [int64]$r[6]) { $blocks.Add('journal_older_than_anchor') }
if ([int64]$r[7] -gt [int64]$r[6]) { $blocks.Add('anchor_older_than_journal') }
if ($r[8] -cne 'claimed_completed' -or [int64]$r[7] -eq 0) { $blocks.Add('session_not_confirmed_complete') }
if ($r[9] -cne 'claimed_verified') { $blocks.Add('original_backup_unverified') }
if ($r[10] -cne 'claimed_verified_local') { $blocks.Add('patch_provenance_unverified') }
if ($r[11] -cne 'preview_acknowledged') { $blocks.Add('user_preview_not_current') }

# A matching snapshot can be replayed coherently, including registration,
# DPAPI-labelled key state, the journal, anchor and supposed consent.
$status = if ($blocks.Count -eq 0) {
    'fixture_claims_consistent_NOT_authenticated'
} else {
    'manual_review_trust_continuity_blocked'
}
$nextStep = if ($blocks.Count -eq 0) {
    'Do not automatically adopt or modify this client; matching caller-controlled records are insufficient proof. Seek separately authenticated registration, provenance and current explicit user consent.'
} else {
    'Preserve existing client files and exact original backups. Do not re-key, re-register, restore or overwrite automatically; perform independent manual verification before proposing a new plan.'
}
$report = [pscustomobject][ordered]@{
    kind = 'read_only_untrusted_trust_continuity_fixture'
    schema_version = 1
    status = $status
    blockers = @($blocks.ToArray())
    blocker_count = $blocks.Count
    manual_review_required = $true
    allow_file_writes = $false
    allow_automatic_resume = $false
    authorises_rollback = $false
    allow_silent_reregistration = $false
    preserve_existing_backups = $true
    recommended_manual_action = $nextStep
    limitations = 'All labels and both sequences are caller-controlled. No client, DPAPI key, protected registration, independent monotonic anchor, genuine approval, patch hashes or backup bytes were checked; fully coordinated replay cannot be detected.'
}
if ($Json) {
    $report | ConvertTo-Json -Depth 5
} else {
    Write-Host 'Naxxramas Client Setup - SYNTHETIC TRUST CONTINUITY (READ ONLY)' -ForegroundColor Cyan
    Write-Host ("Classification: {0}" -f $status)
    foreach ($block in $blocks) { Write-Host ("Manual review: {0}" -f $block) }
    Write-Host 'Never authorises client writes, rollback or silent registration.' -ForegroundColor Yellow
}
