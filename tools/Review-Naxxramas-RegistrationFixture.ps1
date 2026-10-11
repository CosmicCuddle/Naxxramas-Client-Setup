#requires -Version 5.1
<#
Naxxramas Client Setup - READ ONLY registration/session fixture review.
The registration and session are USER-SUPPLIED, UNAUTHENTICATED TEST ARRAYS.
Passing this check NEVER permits installation, deletion, or rollback.
No files, folders, registry values or keys are created or changed.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ClientPath,
    [Parameter(Mandatory=$true)][string]$FixtureRegistrationPath,
    [Parameter(Mandatory=$true)][string]$FixtureSessionPath,
    [switch]$Json
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-UnlinkedFile([string]$Path) {
    $cursor = [IO.Path]::GetFullPath($Path)
    while ($true) {
        if (Test-Path -LiteralPath $cursor) {
            $entry = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
            if (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw 'A linked or junction-backed fixture path was rejected.'
            }
        }
        $parent = [IO.Directory]::GetParent($cursor)
        if ($null -eq $parent) { break }
        $cursor = $parent.FullName
    }
}
function Read-ArrayFixture([string]$Path,[string]$Name) {
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    Assert-UnlinkedFile $Path
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Name must refer to an ordinary fixture file."
    }
    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    if ($item.Length -gt 16384) { throw "$Name exceeds the 16 KiB fixture limit." }
    $utf8 = New-Object System.Text.UTF8Encoding($false,$true)
    try {
        $raw = $utf8.GetString([IO.File]::ReadAllBytes($item.FullName))
        Add-Type -AssemblyName System.Web.Extensions -ErrorAction Stop
        $serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
        $value = $serializer.DeserializeObject($raw)
        if (-not ($value -is [array])) { throw 'Top level was not an array.' }
        return ,$value
    } catch {
        throw "$Name is not a valid JSON fixture array."
    }
}
function Require-Id([object]$Value,[string]$Name) {
    if (-not ($Value -is [string]) -or $Value -cnotmatch '^[A-Za-z0-9_-]{8,80}$') {
        throw "$Name must be a safe 8-80 character identifier."
    }
}
function Require-Hash([object]$Value,[string]$Name) {
    if (-not ($Value -is [string]) -or $Value -cnotmatch '^[a-f0-9]{64}$') {
        throw "$Name must contain lowercase SHA-256."
    }
}
function Require-Sequence([object]$Value,[string]$Name) {
    if ((-not ($Value -is [int] -or $Value -is [long])) -or
        [int64]$Value -lt 0 -or [int64]$Value -gt 100000000) {
        throw "$Name must be a JSON integer between 0 and 100000000."
    }
}
function Validate-Registration([array]$Value) {
    # No object dictionaries or duplicate JSON keys: fixed positional schema.
    if ($Value.Count -ne 5 -or -not ($Value[0] -is [int] -or $Value[0] -is [long]) -or
        [int64]$Value[0] -ne 1) {
        throw 'Unrecognised registration fixture schema.'
    }
    Require-Id $Value[1] 'Registration installation ID'
    Require-Hash $Value[2] 'Registered folder fingerprint'
    if (-not ($Value[3] -is [string]) -or $Value[3] -cnotmatch '^patchset-[0-9]{4}$') {
        throw 'Invalid registration patchset.'
    }
    Require-Sequence $Value[4] 'Registration latest committed sequence'
}
function Validate-Session([array]$Value) {
    if ($Value.Count -ne 6 -or -not ($Value[0] -is [int] -or $Value[0] -is [long]) -or
        [int64]$Value[0] -ne 1) {
        throw 'Unrecognised session fixture schema.'
    }
    Require-Id $Value[1] 'Session installation ID'
    Require-Id $Value[2] 'Session ID'
    if (-not ($Value[3] -is [string]) -or $Value[3] -cnotmatch '^patchset-[0-9]{4}$') {
        throw 'Invalid session patchset.'
    }
    Require-Sequence $Value[4] 'Session latest event sequence'
    if (-not ($Value[5] -is [string]) -or $Value[5] -cnotin @(
        'planned','approved','backup_verified','write_started',
        'verified','completed','rollback_requested','failed_recoverable'
    )) {
        throw 'Unknown session fixture checkpoint.'
    }
}

$registration = Read-ArrayFixture $FixtureRegistrationPath 'Registration'
$session = Read-ArrayFixture $FixtureSessionPath 'Session'
if ($null -ne $registration) { Validate-Registration $registration }
if ($null -ne $session) { Validate-Session $session }

$status = $null
$folderMatch = $null
if ($null -eq $registration) {
    $status = 'manual_review_registration_missing'
} elseif ($null -eq $session) {
    $status = 'manual_review_session_missing'
} else {
    $inspector = Join-Path $PSScriptRoot 'Inspect-Naxxramas-DirectoryIdentity.ps1'
    try {
        $identity = (& $inspector -ClientPath $ClientPath -Json | Out-String) | ConvertFrom-Json -ErrorAction Stop
        if ($identity.status -cne 'observed_not_authenticated' -or
            $identity.client_fingerprint_sha256 -cnotmatch '^[a-f0-9]{64}$') {
            throw 'Unexpected directory identity output.'
        }
        $folderMatch = ([string]$identity.client_fingerprint_sha256 -ceq [string]$registration[2])
    } catch {
        $status = 'manual_review_folder_unavailable'
    }
    if (-not $status) {
        if (-not $folderMatch) {
            $status = 'manual_review_folder_identity_changed'
        } elseif ([string]$session[1] -cne [string]$registration[1]) {
            $status = 'manual_review_installation_mismatch'
        } elseif ([string]$session[3] -cne [string]$registration[3]) {
            $status = 'manual_review_patchset_mismatch'
        } elseif ([int64]$session[4] -lt [int64]$registration[4]) {
            $status = 'manual_review_stale_session'
        } elseif ([int64]$session[4] -gt [int64]$registration[4]) {
            $status = 'manual_review_uncommitted_sequence'
        } elseif ([string]$session[5] -cne 'completed' -or [int64]$session[4] -eq 0) {
            $status = 'manual_review_interrupted_or_uncommitted'
        } else {
            $status = 'fixture_fields_consistent_NOT_trusted'
        }
    }
}
$report = [pscustomobject][ordered]@{
    kind = 'read_only_untrusted_registration_fixture'
    schema_version = 1
    status = $status
    folder_fingerprint_matches = $folderMatch
    registration_present = ($null -ne $registration)
    session_present = ($null -ne $session)
    allow_file_writes = $false
    authorises_rollback = $false
    limitations = 'Registration, sequence and session are caller-controlled unauthenticated fixtures. Even consistent fields cannot prove approval, secure ownership, journal integrity or latest committed state.'
}
if ($Json) {
    $report | ConvertTo-Json -Depth 4
} else {
    Write-Host 'Naxxramas Client Setup - UNTRUSTED REGISTRATION FIXTURE REVIEW' -ForegroundColor Cyan
    Write-Host "Review status: $status"
    Write-Host 'No game files changed. NEVER use this preview to authorise a write.' -ForegroundColor Yellow
}
