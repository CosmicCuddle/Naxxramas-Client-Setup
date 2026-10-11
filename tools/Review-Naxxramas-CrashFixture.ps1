#requires -Version 5.1
<#
Naxxramas Client Setup - READ ONLY synthetic crash-boundary classifier.
The only input is an explicitly provided UNTRUSTED fixture JSON array.
This tool does not inspect or change a WoW client, a backup or any journal.
It does not prove durability, ownership or recovery safety.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$FixturePath,
    [switch]$Json
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Read-Fixture([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw 'The selected crash scenario fixture must be an existing ordinary file.'
    }
    $cursor = [IO.Path]::GetFullPath($Path)
    while ($true) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw 'Linked/junction fixture inputs are rejected.'
            }
        }
        $parent = [IO.Directory]::GetParent($cursor)
        if ($null -eq $parent) { break }
        $cursor = $parent.FullName
    }
    if ((Get-Item -LiteralPath $Path).Length -gt 16384) {
        throw 'Crash fixture exceeds 16 KiB.'
    }
    $utf8 = New-Object System.Text.UTF8Encoding($false,$true)
    try {
        $raw = $utf8.GetString([IO.File]::ReadAllBytes($Path))
        Add-Type -AssemblyName System.Web.Extensions -ErrorAction Stop
        $decoder = New-Object System.Web.Script.Serialization.JavaScriptSerializer
        $parsed = $decoder.DeserializeObject($raw)
        if (-not ($parsed -is [array])) { throw 'The fixture must be an array.' }
        return ,$parsed
    } catch {
        throw 'Malformed crash-boundary fixture JSON or unsupported top-level schema.'
    }
}
function Need-Name([object]$Value,[string]$Label) {
    if (-not ($Value -is [string]) -or $Value -cnotmatch '^[A-Za-z0-9_-]{8,80}$') {
        throw "Invalid $Label."
    }
}
function OneOf([object]$Value,[string[]]$Allowed,[string]$Label) {
    if (-not ($Value -is [string]) -or $Allowed -cnotcontains $Value) {
        throw "Unknown $Label."
    }
}

# Positional layout avoids duplicate JSON property-name ambiguity.
# [version, session_id, patchset, checkpoint, anchor_claim, [V fields], [Z fields]]
# Per core patch: [path, action, backup, destination, file_checkpoint]
$record = Read-Fixture $FixturePath
if ($record.Count -ne 7 -or
    -not ($record[0] -is [int] -or $record[0] -is [long]) -or
    [int64]$record[0] -ne 1) {
    throw 'Unsupported crash fixture schema.'
}
Need-Name $record[1] 'fixture session ID'
if (-not ($record[2] -is [string]) -or $record[2] -cnotmatch '^patchset-[0-9]{4}$') {
    throw 'Unsupported fixture patchset label.'
}
$checkpoints = @('planned','staged','backup_started','backups_verified',
    'intent_durable','write_started','files_verified','finalising',
    'completed','rollback_requested')
OneOf $record[3] $checkpoints 'session checkpoint'
OneOf $record[4] @('matches','missing','stale','ahead','unverified') 'external anchor claim'

$expected = @('Data/patch-V.mpq','Data/patch-Z.mpq')
$fileStates = @('planned','staged','backup_started','backup_verified',
    'intent_durable','write_started','write_verified','committed')
$entries = New-Object 'System.Collections.Generic.List[object]'
for ($i=0; $i -lt 2; $i++) {
    $item = $record[5+$i]
    if (-not ($item -is [array]) -or $item.Count -ne 5) {
        throw 'Core patch event must contain exactly five fields.'
    }
    if (-not ($item[0] -is [string]) -or $item[0] -cne $expected[$i]) {
        throw 'Fixture core files must be V then Z with exact permitted paths.'
    }
    OneOf $item[1] @('install','replace_after_backup') 'file action'
    OneOf $item[2] @('not_required','missing','verified','corrupt') 'backup observation'
    OneOf $item[3] @('absent','original','installed','modified','missing','unknown') 'destination observation'
    OneOf $item[4] $fileStates 'file checkpoint'
    if ($item[1] -ceq 'install' -and $item[2] -cne 'not_required') {
        throw 'Newly created files cannot claim an original backup.'
    }
    if ($item[1] -ceq 'replace_after_backup' -and $item[2] -ceq 'not_required') {
        throw 'Replacement must have an original backup claim.'
    }
    $entries.Add([pscustomobject][ordered]@{
        path = [string]$item[0]
        action = [string]$item[1]
        backup = [string]$item[2]
        destination = [string]$item[3]
        file_checkpoint = [string]$item[4]
    })
}

$v = $entries[0]
$z = $entries[1]
$classification = $null
$reasons = New-Object 'System.Collections.Generic.List[string]'

# Relative priority is intentional: loss of a backup and a changed player
# file must not be concealed by a generic "session incomplete" diagnosis.
if ($record[4] -cne 'matches') {
    $classification = 'manual_review_unverified_anchor'
    $reasons.Add('The caller-supplied latest-state anchor claim is not matching.')
}
if (-not $classification -and @($entries | Where-Object {
    $_.destination -eq 'modified' -or $_.destination -eq 'unknown'
}).Count -gt 0) {
    $classification = 'manual_review_destination_conflict'
    $reasons.Add('A destination has unexpected or unrecognised content; preserve it.')
}
if (-not $classification -and @($entries | Where-Object {
    $_.destination -eq 'missing' -or
    ($record[3] -ceq 'completed' -and $_.destination -eq 'absent')
}).Count -gt 0) {
    $classification = 'manual_review_missing_destination'
    $reasons.Add('A required core patch is absent; do not infer it was deleted by this installer.')
}
if (-not $classification -and @($entries | Where-Object {
    $_.action -eq 'replace_after_backup' -and
    $_.backup -ne 'verified' -and
    $_.destination -in @('installed','modified','missing')
}).Count -gt 0) {
    $classification = 'manual_review_original_backup_unavailable'
    $reasons.Add('A replacement may have happened without a verified original backup.')
}
if (-not $classification -and @($entries | Where-Object {
    $_.action -eq 'replace_after_backup' -and $_.backup -eq 'corrupt'
}).Count -gt 0) {
    $classification = 'manual_review_original_backup_corrupt'
    $reasons.Add('A claimed original backup is corrupt and must be preserved for examination.')
}
if (-not $classification -and @($entries | Where-Object {
    $_.destination -eq 'installed' -and $_.file_checkpoint -in
    @('planned','staged','backup_started','backup_verified')
}).Count -gt 0) {
    $classification = 'manual_review_write_without_intent'
    $reasons.Add('An installed file is observed before the fixture records write intent.')
}
if (-not $classification -and @($entries | Where-Object {
    $_.file_checkpoint -in @('write_started','intent_durable') -and
    $_.destination -eq 'installed'
}).Count -gt 0) {
    $classification = 'manual_review_ambiguous_commit'
    $reasons.Add('File bytes appear installed but the corresponding file checkpoint is not verified.')
}
if (-not $classification -and $v.destination -ne $z.destination -and
    ($v.destination -eq 'installed' -or $z.destination -eq 'installed')) {
    $classification = 'manual_review_partial_core'
    $reasons.Add('V and Z are not simultaneously in their expected installed state.')
}
if (-not $classification -and ($record[3] -cne 'completed' -or
    $v.destination -cne 'installed' -or $z.destination -cne 'installed' -or
    $v.file_checkpoint -cne 'committed' -or $z.file_checkpoint -cne 'committed')) {
    $classification = 'manual_review_incomplete_or_inconsistent_session'
    $reasons.Add('Both mandatory patches and a completed, verified session are not consistently observed.')
}
if (-not $classification) {
    $classification = 'fixture_fields_consistent_NOT_trusted'
    $reasons.Add('These user-provided fixture claims are self-consistent, NOT authenticated or crash-durable.')
}

$report = [pscustomobject][ordered]@{
    kind = 'read_only_untrusted_crash_boundary_fixture'
    schema_version = 1
    classification = $classification
    claimed_checkpoint = [string]$record[3]
    core_files = @($entries.ToArray())
    observations_only = $true
    allow_file_writes = $false
    allow_automatic_resume = $false
    authorises_rollback = $false
    reasons = @($reasons.ToArray())
    limitations = 'Caller-provided data; no actual files, backups, signed journals or protected anchors were examined. Classification never grants install or rollback rights and cannot demonstrate crash durability.'
}
if ($Json) {
    $report | ConvertTo-Json -Depth 6
} else {
    Write-Host 'Naxxramas Client Setup - SYNTHETIC CRASH CLASSIFIER (READ ONLY)' -ForegroundColor Cyan
    Write-Host ("Classification: {0}" -f $classification)
    Write-Host 'No files changed. No automatic installation, resume or rollback is authorised.' -ForegroundColor Yellow
}
