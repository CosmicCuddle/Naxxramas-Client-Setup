#requires -Version 5.1
<#
READ ONLY / SYNTHETIC FIXTURES ONLY.
Validates a proposed signed journal wire format against a caller-supplied TEST key.
NOT a trusted production journal verifier or authority for recovery or writes.
No game files, journal files or keys are created or changed.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$EnvelopePath,
    [Parameter(Mandatory=$true)][string]$AnchorPath,
    [Parameter(Mandatory=$true)][string]$FixtureKeyPath,
    [string]$FixtureWitnessPath,
    [string]$FixtureWitnessKeyPath,
    [switch]$Json
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Check-Path([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    $cursor = $full
    while ($true) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw 'Linked paths and junctions are not accepted for fixture validation.'
            }
        }
        $parent = [IO.Directory]::GetParent($cursor)
        if ($null -eq $parent) { break }
        $cursor = $parent.FullName
    }
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        throw 'A required fixture file is missing.'
    }
    return $full
}
function Read-FixtureJson([string]$Path) {
    $f = Check-Path $Path
    if ((Get-Item -LiteralPath $f).Length -gt 65536) {
        throw 'Fixture JSON exceeds the 64 KiB input limit.'
    }
    $decoder = New-Object System.Text.UTF8Encoding($false,$true)
    $raw = $decoder.GetString([IO.File]::ReadAllBytes($f))
    # Use the Windows .NET JSON reader so a top-level JSON array retains
    # its exact shape instead of PowerShell pipeline array enumeration.
    try {
        Add-Type -AssemblyName System.Web.Extensions -ErrorAction Stop
        $serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
        $parsed = $serializer.DeserializeObject($raw)
        if (-not ($parsed -is [array])) { throw 'Expected a JSON array.' }
        return ,$parsed
    } catch { throw 'Fixture JSON must be a valid top-level array.' }
}
function Require-Hex([string]$Value) {
    if ($Value -cnotmatch '^[0-9a-f]{64}$') { throw 'Malformed signed SHA-256/HMAC field.' }
    return $Value
}
function Require-Id([string]$Value) {
    if ($Value -cnotmatch '^[A-Za-z0-9_-]{8,80}$') {
        throw 'Invalid signed installation or session identifier.'
    }
}
function Require-Number([string]$Value) {
    if ($Value -cnotmatch '^(0|[1-9][0-9]{0,17})$') {
        throw 'Invalid non-negative canonical integer.'
    }
    $parsed = [int64]0
    if (-not [int64]::TryParse($Value,[ref]$parsed)) { throw 'Integer exceeds supported range.' }
    return $parsed
}
function Digest([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant() }
    finally { $sha.Dispose() }
}
function Mac([byte[]]$Key,[byte[]]$Bytes) {
    $hmac = New-Object Security.Cryptography.HMACSHA256(,$Key)
    try { return ([BitConverter]::ToString($hmac.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant() }
    finally { $hmac.Dispose() }
}
function Compare-Hex([string]$A,[string]$B) {
    # Equal-length checks are already enforced by Require-Hex.
    $difference = 0
    for ($i=0; $i -lt 64; $i++) {
        $difference = $difference -bor (([int][char]$A[$i]) -bxor ([int][char]$B[$i]))
    }
    return $difference -eq 0
}
function Decode-AsciiPayload([string]$Encoded) {
    if ($Encoded.Length -gt 8192 -or $Encoded -cnotmatch '^[A-Za-z0-9+/]+={0,2}$') {
        throw 'Malformed or oversized signed payload encoding.'
    }
    try { $bytes = [Convert]::FromBase64String($Encoded) }
    catch { throw 'Signed payload has invalid base64.' }
    if ([Convert]::ToBase64String($bytes) -cne $Encoded) {
        throw 'Noncanonical base64 signed payload.'
    }
    foreach ($b in $bytes) {
        if ($b -lt 32 -or $b -gt 126) { throw 'Signed event contains non-ASCII or control bytes.' }
    }
    return ,$bytes
}

if ([bool]$FixtureWitnessPath -ne [bool]$FixtureWitnessKeyPath) {
    throw 'Fixture witness and independent witness key must be supplied together.'
}
$envelope = Read-FixtureJson $EnvelopePath
$anchor = Read-FixtureJson $AnchorPath
$keyFile = Check-Path $FixtureKeyPath
if ($envelope.Count -ne 2 -or [string]$envelope[0] -cne '2') {
    throw 'Unknown signed fixture envelope version.'
}
if ($anchor.Count -ne 6 -or [string]$anchor[0] -cne '2') {
    throw 'Unknown signed fixture anchor version.'
}
$events = $envelope[1]
if (-not ($events -is [array]) -or $events.Count -lt 1 -or $events.Count -gt 8) {
    throw 'Fixture envelope requires 1 to 8 signed events.'
}
$key = [IO.File]::ReadAllBytes($keyFile)
if ($key.Length -ne 32) { throw 'Fixture key must contain exactly 32 bytes.' }
$allowed = @('Data/patch-V.mpq','Data/patch-Z.mpq','Data/Patch-J.mpq',
    'Data/Patch-U.mpq','Data/enUS/realmlist.wtf')
$zero = ('0' * 64)
$previous = $zero
$expectedSession = [string]$anchor[1]
$expectedInstallation = [string]$anchor[2]
Require-Id $expectedSession
Require-Id $expectedInstallation
$anchorSequence = Require-Number ([string]$anchor[3])
$anchorHead = Require-Hex ([string]$anchor[4])
$anchorMac = Require-Hex ([string]$anchor[5])
$fixturePrefix = 'NXA2|' + $expectedSession + '|' + $expectedInstallation +
    '|' + $anchorSequence + '|' + $anchorHead
$anchorComputed = Mac $key ([Text.Encoding]::ASCII.GetBytes($fixturePrefix))
if (-not (Compare-Hex $anchorMac $anchorComputed)) { throw 'Fixture anchor HMAC verification failed.' }
$sessionPatchset = $null
$lastState = $null
for ($i=0; $i -lt $events.Count; $i++) {
    $pair = $events[$i]
    if (-not ($pair -is [array]) -or $pair.Count -ne 2) {
        throw 'Signed fixture event must be a two-element array.'
    }
    $encoded = [string]$pair[0]
    $provided = Require-Hex ([string]$pair[1])
    $bytes = Decode-AsciiPayload $encoded
    $computed = Mac $key $bytes
    if (-not (Compare-Hex $provided $computed)) {
        throw 'Signed fixture event HMAC verification failed.'
    }
    $fields = ([Text.Encoding]::ASCII.GetString($bytes)) -split '\|'
    if ($fields.Count -ne 15 -or $fields[0] -cne 'NXJ2') {
        throw 'Incorrect signed fixture event field count or format.'
    }
    if ($fields[1] -cne $expectedSession -or $fields[2] -cne $expectedInstallation) {
        throw 'Signed event installation/session identity does not match the anchor.'
    }
    $seq = Require-Number $fields[3]
    if ($seq -ne ($i+1)) { throw 'Out-of-order, missing or duplicate signed event sequence.' }
    if ($fields[4] -cnotmatch '^patchset-[0-9]{4}$') {
        throw 'Unrecognised signed patchset.'
    }
    if ($null -eq $sessionPatchset) { $sessionPatchset = $fields[4] }
    elseif ($fields[4] -cne $sessionPatchset) { throw 'Signed patchset changed within session.' }
    if ($fields[5] -cnotin @('planned','approved','backup_verified','write_started','verified')) {
        throw 'Unknown signed journal checkpoint state.'
    }
    if ($allowed -cnotcontains $fields[6]) { throw 'Path is not in exact Naxxramas allowlist.' }
    if ($fields[7] -cnotin @('install','replace_after_backup')) { throw 'Unknown operation.' }
    if ($fields[8] -cne $previous) { throw 'Signed event chain link does not match predecessor.' }
    $isNew = $fields[7] -ceq 'install'
    if ($isNew) {
        if ($fields[9] -cne '-' -or $fields[11] -cne '-' -or $fields[13] -cne '-') {
            throw 'Created file cannot claim an original backup.'
        }
    } else {
        $null = Require-Hex $fields[9]
        $null = Require-Number $fields[11]
        if ($fields[13] -cnotmatch '^originals/[0-9]{4}\.bin$') {
            throw 'Unsafe original backup relative path.'
        }
    }
    $null = Require-Hex $fields[10]
    $null = Require-Number $fields[12]
    if ($fields[14] -cne '12340') { throw 'Unsupported signed client build.' }
    $previous = Digest $bytes
    $lastState = $fields[5]
}
if ($anchorSequence -ne $events.Count -or $anchorHead -cne $previous) {
    throw 'Stale, truncated or mismatched signed fixture anchor/head.'
}

# Optional INDEPENDENT FIXTURE WITNESS. This is caller-supplied test data,
# not a protected Windows trust anchor. The witness key is deliberately
# separate from the journal HMAC key to exercise independent trust paths.
$witnessStatus = 'not_supplied'
if ($FixtureWitnessPath) {
    $witness = Read-FixtureJson $FixtureWitnessPath
    if ($witness.Count -ne 6 -or [string]$witness[0] -cne '2') {
        throw 'Unknown independent fixture witness version.'
    }
    $witnessSession = [string]$witness[1]
    $witnessInstallation = [string]$witness[2]
    Require-Id $witnessSession
    Require-Id $witnessInstallation
    $witnessSequence = Require-Number ([string]$witness[3])
    $witnessHead = Require-Hex ([string]$witness[4])
    $witnessSignature = Require-Hex ([string]$witness[5])
    $witnessKeyFile = Check-Path $FixtureWitnessKeyPath
    $witnessKey = [IO.File]::ReadAllBytes($witnessKeyFile)
    if ($witnessKey.Length -ne 32) { throw 'Independent fixture witness key must be 32 bytes.' }
    $witnessPayload = 'NXW2|' + $witnessSession + '|' + $witnessInstallation +
        '|' + $witnessSequence + '|' + $witnessHead
    $witnessComputed = Mac $witnessKey ([Text.Encoding]::ASCII.GetBytes($witnessPayload))
    if (-not (Compare-Hex $witnessSignature $witnessComputed)) {
        throw 'Independent fixture witness signature verification failed.'
    }
    if ($witnessSession -cne $expectedSession -or
        $witnessInstallation -cne $expectedInstallation) {
        throw 'Fixture witness belongs to a different session or installation.'
    }
    if ($witnessSequence -ne $anchorSequence -or $witnessHead -cne $anchorHead) {
        throw 'Signed journal and anchor disagree with independently supplied latest fixture witness; possible coordinated replay or stale witness.'
    }
    $witnessStatus = 'matches_independent_fixture'
}
$summary = [pscustomobject][ordered]@{
    kind = 'synthetic_hmac_chain_fixture_not_production_authority'
    schema_version = 2
    status = 'fixture_chain_and_anchor_match'
    event_count = $events.Count
    session_id = $expectedSession
    installation_id = $expectedInstallation
    patchset = $sessionPatchset
    last_checkpoint = $lastState
    witness_status = $witnessStatus
    limitations = 'Fixture witness and keys are caller-supplied, not a protected monotonic Windows trust anchor; replay safety is not established for a real installer, and no writes are authorised.'
}
if ($Json) { $summary | ConvertTo-Json -Depth 4 }
else {
    Write-Host 'Naxxramas signed journal — SYNTHETIC FIXTURE CHECK' -ForegroundColor Cyan
    Write-Host "Validated $($summary.event_count) event(s) against the supplied fixture key and anchor."
    Write-Host "Independent fixture witness: $($summary.witness_status)"
    Write-Host 'NO FILES WERE CHANGED. Not a production journal trust decision.' -ForegroundColor Yellow
}
