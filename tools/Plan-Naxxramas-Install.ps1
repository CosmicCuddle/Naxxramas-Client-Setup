#requires -Version 5.1
<#
Naxxramas Client Setup - READ-ONLY installer planner.
No files, directories, reports, registry settings or game configuration are written.
The result describes possible future operations, NOT an approved install transaction.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ClientPath,
    [string]$PatchSourcePath,
    [string]$BackupRoot,
    [switch]$VanillaLogin,
    [switch]$VanillaLoading,
    [string]$RealmHost,
    [switch]$Json
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-NoLinks([string]$Path) {
    $cursor = [IO.Path]::GetFullPath($Path)
    while ($true) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Linked files or directories are not permitted in this preview: $cursor"
            }
        }
        $parent = [IO.Directory]::GetParent($cursor)
        if ($null -eq $parent) { break }
        $cursor = $parent.FullName
    }
}
function Require-Root([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw 'Select an existing folder containing a WoW client.'
    }
    Assert-NoLinks $Path
    $full = (Resolve-Path -LiteralPath $Path).ProviderPath
    Assert-NoLinks $full
    $canonical = [IO.Path]::GetFullPath($full)
    if ($canonical.TrimEnd([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar).Equals(
        ([IO.Path]::GetPathRoot($canonical)).TrimEnd([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar),
        [StringComparison]::OrdinalIgnoreCase)) {
        throw 'A volume root cannot be selected as a client, source or backup directory.'
    }
    return $canonical
}
function Normalise-Directory([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    $volumeRoot = [IO.Path]::GetPathRoot($full)
    if ($full.Equals($volumeRoot,[StringComparison]::OrdinalIgnoreCase)) { return $full }
    return $full.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
}
function Is-SameOrChild([string]$One,[string]$Two) {
    $oneFull = Normalise-Directory $One
    $twoFull = Normalise-Directory $Two
    if ($oneFull.Equals($twoFull,[StringComparison]::OrdinalIgnoreCase)) { return $true }
    $prefix = if ($twoFull.EndsWith([string][IO.Path]::DirectorySeparatorChar)) {
        $twoFull
    } else {
        $twoFull + [IO.Path]::DirectorySeparatorChar
    }
    return $oneFull.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)
}
function Patch-At([string]$Root,[string]$Relative) {
    $candidate = Join-Path $Root ($Relative.Replace('/',[IO.Path]::DirectorySeparatorChar))
    Assert-NoLinks $candidate
    if (Test-Path -LiteralPath $candidate -PathType Container) { throw "Expected a file, found a directory: $Relative" }
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    return $null
}
function Fingerprint([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force
    Assert-NoLinks $item.FullName
    return [pscustomobject]@{
        sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
        size_bytes = [int64]$item.Length
    }
}
function Matches([object]$Actual,[object]$Expected) {
    return $null -ne $Actual -and
      ([string]$Actual.sha256).Equals([string]$Expected.sha256,[StringComparison]::OrdinalIgnoreCase) -and
      [int64]$Actual.size_bytes -eq [int64]$Expected.size_bytes
}
function Get-AvailableSpaceBytes([string]$Directory) {
    # Kept in a tiny, isolated function so fixture tests can simulate failures
    # without changing real disk capacity or introducing a production override.
    $drive = New-Object System.IO.DriveInfo -ArgumentList ([IO.Path]::GetPathRoot($Directory))
    if (-not $drive.IsReady) { throw 'Destination drive is not ready.' }
    return [int64]$drive.AvailableFreeSpace
}
function Get-StorageKey([string]$Directory) {
    # A drive-root comparison is only a conservative preview approximation.
    # Future write-capable code must determine true volume identity and recheck.
    return ([IO.Path]::GetPathRoot($Directory)).ToUpperInvariant()
}
function Hash-Bytes([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

$repo = Split-Path -Parent $PSScriptRoot
$patchManifest = Get-Content -LiteralPath (Join-Path $repo 'config/client-patches.json') -Raw | ConvertFrom-Json
$realm = Get-Content -LiteralPath (Join-Path $repo 'config/realm.json') -Raw | ConvertFrom-Json
if ([int]$patchManifest.schema_version -ne 1 -or [int]$patchManifest.patch_set_revision -lt 1 -or
    [string]$patchManifest.target_client.locale -ne 'enUS' -or [int]$patchManifest.target_client.build -ne 12340) {
    throw 'Unsupported client policy; use the latest reviewed repository.'
}
if ([int]$realm.schema_version -ne 1 -or [string]$realm.relative_path -cne 'Data/enUS/realmlist.wtf') {
    throw 'Unsupported realmlist policy.'
}
$expectedPaths = @('Data/patch-V.mpq','Data/patch-Z.mpq','Data/Patch-J.mpq','Data/Patch-U.mpq')
if (@($patchManifest.patches).Count -ne 4) { throw 'Expected exactly four patch policy entries.' }
for ($i=0; $i -lt 4; $i++) {
    $p = $patchManifest.patches[$i]
    if ([string]$p.path -cne $expectedPaths[$i] -or
        [bool]$p.required -ne ($i -lt 2) -or
        [string]$p.sha256 -notmatch '^[a-fA-F0-9]{64}$' -or [int64]$p.size_bytes -le 0) {
        throw 'Unexpected or incomplete patch policy; no preview generated.'
    }
}

$dest = Require-Root $ClientPath
$sourceRoot = $null
if ($PatchSourcePath) {
    $sourceRoot = Require-Root $PatchSourcePath
    if ((Is-SameOrChild $sourceRoot $dest) -or (Is-SameOrChild $dest $sourceRoot)) {
        throw 'Patch source and client destination must be separate, non-nested folders.'
    }
}
$backupRoot = $null
if ($BackupRoot) {
    $backupRoot = Require-Root $BackupRoot
    if ((Is-SameOrChild $backupRoot $dest) -or (Is-SameOrChild $dest $backupRoot)) {
        throw 'Backup and client destination must be separate, non-nested folders.'
    }
    if ($sourceRoot -and ((Is-SameOrChild $backupRoot $sourceRoot) -or
        (Is-SameOrChild $sourceRoot $backupRoot))) {
        throw 'Backup and patch source must be separate, non-nested folders.'
    }
}
$blockers = New-Object 'System.Collections.Generic.List[string]'
$warnings = New-Object 'System.Collections.Generic.List[string]'
$items = New-Object 'System.Collections.Generic.List[object]'

$wow = Join-Path $dest 'Wow.exe'
Assert-NoLinks $wow
if (-not (Test-Path -LiteralPath $wow -PathType Leaf)) {
    $blockers.Add('Wow.exe is missing.')
} else {
    $version = $null
    try { $version = [Diagnostics.FileVersionInfo]::GetVersionInfo($wow).FileVersion } catch {}
    if (-not ($version -and $version -match '(^|[.,\s])12340($|[.,\s])')) {
        $blockers.Add('WoW build 12340 could not be confirmed from Wow.exe metadata.')
    }
}
$dataDir = Join-Path $dest 'Data'
$localeDir = Join-Path $dataDir 'enUS'
Assert-NoLinks $localeDir
if (-not (Test-Path -LiteralPath $localeDir -PathType Container)) {
    $blockers.Add('Data/enUS is missing.')
}

# History is used for classification only. It never authorises an unreviewed update.
$history = @()
$historyDir = Join-Path $repo 'config/patch-versions'
if (Test-Path -LiteralPath $historyDir -PathType Container) {
    foreach ($entry in @(Get-ChildItem -LiteralPath $historyDir -Filter 'patchset-*.json' -File)) {
        Assert-NoLinks $entry.FullName
        $h = Get-Content -LiteralPath $entry.FullName -Raw | ConvertFrom-Json
        if ([int]$h.revision -lt [int]$patchManifest.patch_set_revision) { $history += $h }
    }
}
function State-Of([object]$Signature,[object]$Policy) {
    if ($null -eq $Signature) { return 'missing' }
    if (Matches $Signature $Policy) { return 'current' }
    foreach ($h in $history) {
        foreach ($old in @($h.patches)) {
            if ([string]$old.path -ceq [string]$Policy.path -and (Matches $Signature $old)) {
                return 'known_older'
            }
        }
    }
    return 'unknown'
}

foreach ($patch in @($patchManifest.patches)) {
    $path = [string]$patch.path
    $required = [bool]$patch.required
    $selected = $required -or
        ($path -ceq 'Data/Patch-J.mpq' -and [bool]$VanillaLogin) -or
        ($path -ceq 'Data/Patch-U.mpq' -and [bool]$VanillaLoading)
    $existingFile = Patch-At $dest $path
    $existing = if ($existingFile) { Fingerprint $existingFile } else { $null }
    $existingState = State-Of $existing $patch

    # Sources are explicitly supplied local files; never download any MPQs.
    $sourceFile = if ($sourceRoot) { Patch-At $sourceRoot $path } else { $null }
    $available = if ($sourceFile) { Fingerprint $sourceFile } else { $null }
    $sourceState = State-Of $available $patch
    $action = 'blocked'
    $reason = ''
    if (-not $selected) {
        $action = if ($existingFile) { 'leave_existing' } else { 'not_selected' }
        $reason = 'Optional patch was not selected; no removal or replacement is proposed.'
        if ($existingState -eq 'unknown') {
            $warnings.Add("$path exists with an unrecognised hash; it will be left untouched.")
        }
    } elseif ($existingState -eq 'current') {
        $action = 'no_change'
        $reason = 'Existing patch matches the pinned SHA-256 and byte size.'
    } elseif ($existingState -eq 'unknown') {
        $reason = 'Existing patch is unrecognised; manual review is required before replacement.'
        $blockers.Add("$path has an unrecognised installed version.")
    } elseif ($sourceState -ne 'current') {
        $reason = 'No matching current-version local patch source was supplied.'
        $blockers.Add("$path requires a verified local source (patchset $($patchManifest.patch_set_version)).")
    } elseif ($existingState -eq 'known_older') {
        $action = 'replace_after_backup'
        $reason = 'Known older version; backup and explicit approval required in a future installer.'
    } else {
        $action = 'install'
        $reason = 'Missing patch; an independently supplied matching local file is available.'
    }
    $items.Add([pscustomobject][ordered]@{
        path = $path
        kind = 'patch'
        required = $required
        selected = [bool]$selected
        destination_state = $existingState
        source_state = $sourceState
        action = $action
        backup_required = ($action -eq 'replace_after_backup')
        existing_sha256 = $(if ($existing) { $existing.sha256 } else { $null })
        existing_size_bytes = $(if ($existing) { $existing.size_bytes } else { $null })
        expected_sha256 = [string]$patch.sha256
        expected_size_bytes = [int64]$patch.size_bytes
        reason = $reason
    })
}

if ($VanillaLogin -and $VanillaLoading) {
    $warnings.Add('J and U contain overlapping loading-screen textures; joint in-game precedence is untested.')
}
$realmTargetHost = if ($RealmHost) { [string]$RealmHost } else { [string]$realm.host }
if (-not $realmTargetHost -or $realmTargetHost.Length -gt 253 -or
    $realmTargetHost -notmatch '^[A-Za-z0-9][A-Za-z0-9.-]*[A-Za-z0-9]$' -or
    $realmTargetHost.Contains('..')) {
    throw 'Invalid realmlist hostname/IP; enter a plain address without a port, scheme or commands.'
}
$line = "set realmlist $realmTargetHost"
$desired = [Text.Encoding]::ASCII.GetBytes($line)
$realmPath = Join-Path $dest 'Data/enUS/realmlist.wtf'
Assert-NoLinks $realmPath
$realmAction = 'install'
$realmState = 'missing'
$realmBeforeHash = $null
$realmBeforeSize = $null
$realmReason = 'Missing realmlist; future setup could create it after approval.'
if (Test-Path -LiteralPath $realmPath -PathType Container) { throw 'realmlist.wtf is a folder, not a file.' }
if (Test-Path -LiteralPath $realmPath -PathType Leaf) {
    $realmBeforeSize = [int64](Get-Item -LiteralPath $realmPath).Length
    if ($realmBeforeSize -gt 4096) {
        $realmState='unrecognised'
        $realmAction='blocked'
        $realmReason='Existing realmlist is unusually large; manual review is required.'
        $blockers.Add('The existing realmlist is too large to safely preview.')
    } else {
        $original = [IO.File]::ReadAllBytes($realmPath)
        $realmBeforeHash = Hash-Bytes $original
        $text = [Text.Encoding]::ASCII.GetString($original)
        if ($text -ceq $line -or $text -ceq ($line + "`r`n") -or $text -ceq ($line + "`n")) {
            $realmState='matching'
            $realmAction='no_change'
            $realmReason='Realmlist already contains the expected address.'
        } elseif ($text -match '(?m)^\s*set\s+realmlist\s+(\S+)\s*$') {
            if ($Matches[1] -eq $realmTargetHost) {
                $realmState='matching_with_other_content'
                $realmAction='leave_existing'
                $realmReason='Expected address is present with additional content; preserve player file.'
            } else {
                $realmState='different'
                $realmAction='replace_after_backup'
                $realmReason='Different address; future setup would require an exact backup and user approval.'
            }
        } else {
            $realmState='unrecognised'
            $realmAction='blocked'
            $realmReason='Existing realmlist has unrecognised contents; preserve for manual review.'
            $blockers.Add('Existing realmlist contents are unrecognised.')
        }
    }
}
$items.Add([pscustomobject][ordered]@{
    path = 'Data/enUS/realmlist.wtf'
    kind = 'configuration'
    required = $true
    selected = $true
    destination_state = $realmState
    source_state = 'generated_from_realm_policy'
    action = $realmAction
    backup_required = ($realmAction -eq 'replace_after_backup')
    existing_sha256 = $realmBeforeHash
    existing_size_bytes = $realmBeforeSize
    expected_sha256 = (Hash-Bytes $desired)
    expected_size_bytes = [int64]$desired.Length
    reason = $realmReason
})

# Conservative READ-ONLY budget. Future writes must independently verify true
# volume identity, both capacities, real staging layout and free-space changes.
[int64]$newBytes = 0
[int64]$originalBytes = 0
foreach ($entry in $items) {
    if ($entry.action -in @('install','replace_after_backup')) {
        $newBytes += [int64]$entry.expected_size_bytes
        if ($entry.backup_required) { $originalBytes += [int64]$entry.existing_size_bytes }
    }
}
[int64]$clientNeeded = 0
[int64]$backupNeeded = 0
if ($newBytes -gt 0) {
    $clientNeeded = (2 * $newBytes) + 67108864 # staging plus same-volume temp + 64 MiB
    if ($backupRoot) {
        $backupNeeded = $originalBytes + 67108864 # immutable backups and journal reserve
    } else {
        # Legacy single-volume estimate, not an approved future backup location.
        $clientNeeded += $originalBytes
        $warnings.Add('Select a separate backup directory before any future write-capable installation.')
    }
}
$spaceMode = 'backup_not_selected'
if ($backupRoot) {
    $spaceMode = if ((Get-StorageKey $backupRoot) -eq (Get-StorageKey $dest)) {
        'shared_volume'
    } else { 'separate_volumes' }
    $warnings.Add('Volume identity uses drive roots in this preview only; revalidate actual volumes before future writes.')
}
[int64]$needed = $clientNeeded + $backupNeeded
[int64]$clientCheckBytes = if ($spaceMode -eq 'shared_volume') { $needed } else { $clientNeeded }
if ($clientNeeded -gt 0) {
    try {
        $availableBytes = Get-AvailableSpaceBytes $dest
        if ($availableBytes -lt 0) {
            $blockers.Add('Available destination space was invalid; preview must be blocked.')
        } elseif ($availableBytes -lt $clientCheckBytes) {
            $blockers.Add('Insufficient destination free space for estimated staging and backups.')
        }
    } catch {
        $blockers.Add('Could not verify free space on the destination drive.')
    }
}
if ($backupRoot -and $spaceMode -eq 'separate_volumes' -and $backupNeeded -gt 0) {
    try {
        $backupAvailableBytes = Get-AvailableSpaceBytes $backupRoot
        if ($backupAvailableBytes -lt 0) {
            $blockers.Add('Available backup space was invalid; preview must be blocked.')
        } elseif ($backupAvailableBytes -lt $backupNeeded) {
            $blockers.Add('Insufficient backup drive space for estimated originals and journal.')
        }
    } catch {
        $blockers.Add('Could not verify free space on the backup drive.')
    }
}
$warnings.Add('This is only a read-only preview. It does not authorise copying or distributing MPQ files.')
if (@($patchManifest.patches | Where-Object { -not [bool]$_.public_distribution_approved }).Count -gt 0) {
    $warnings.Add('Patch redistribution rights have not been approved; no downloads or public package may be offered.')
}

$plan = [pscustomobject][ordered]@{
    schema_version = 1
    kind = 'read_only_preview_not_install_authorisation'
    patch_set_version = [string]$patchManifest.patch_set_version
    client_target = 'WoW 3.3.5a build 12340 enUS'
    optional_selections = [pscustomobject]@{
        vanilla_login = [bool]$VanillaLogin
        vanilla_loading = [bool]$VanillaLoading
    }
    realm_host = $realmTargetHost
    estimated_space_bytes = $needed
    space_budget = [pscustomobject][ordered]@{
        mode = $spaceMode
        backup_location_selected = [bool]$backupRoot
        client_volume_required_bytes = $clientNeeded
        backup_volume_required_bytes = $backupNeeded
        combined_volume_required_bytes = $(if ($spaceMode -eq 'shared_volume') { $needed } else { $null })
        approximation_only = $true
    }
    status = $(if ($blockers.Count -eq 0) { 'review_only_no_blockers' } else { 'blocked' })
    blockers = @($blockers.ToArray())
    warnings = @($warnings.ToArray())
    files = @($items.ToArray())
}
if ($Json) {
    $plan | ConvertTo-Json -Depth 12
} else {
    Write-Host ''
    Write-Host 'Naxxramas Client - READ ONLY INSTALL PLAN' -ForegroundColor Cyan
    Write-Host "Patch reference: $($plan.patch_set_version)"
    foreach ($entry in $items) {
        Write-Host ("{0,-22} {1} ({2})" -f $entry.action.ToUpperInvariant(),$entry.path,$entry.destination_state)
    }
    Write-Host ("Estimated staging and backup space: {0:N0} bytes" -f $needed)
    Write-Host "Storage mode: $($plan.space_budget.mode); client budget: $clientNeeded bytes; backup budget: $backupNeeded bytes"
    foreach ($message in $warnings) { Write-Warning $message }
    foreach ($message in $blockers) { Write-Host "BLOCKED: $message" -ForegroundColor Red }
    Write-Host "Preview status: $($plan.status)"
    Write-Host 'NO FILES WERE CHANGED. This is not an installer.' -ForegroundColor Green
}
