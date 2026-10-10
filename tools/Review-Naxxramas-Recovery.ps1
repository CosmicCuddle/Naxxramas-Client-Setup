#requires -Version 5.1
<#
Naxxramas Client Setup - READ-ONLY recovery decision preview.
Inspects a local session.json and compares the saved before/after signatures
to client and backup files. NO filesystem write/delete/rename operations.
Never use this report alone as authorisation to restore or delete a file.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ClientPath,
    [Parameter(Mandatory=$true)][string]$SessionDirectory,
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
                throw 'Refusing a path containing a junction or symbolic link.'
            }
        }
        $parent = [IO.Directory]::GetParent($cursor)
        if ($null -eq $parent) { break }
        $cursor = $parent.FullName
    }
}
function Require-Directory([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw 'Required client or session directory does not exist.'
    }
    Assert-NoLinks $Path
    $full = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Path).ProviderPath)
    $volumeRoot = [IO.Path]::GetPathRoot($full)
    if ($full.TrimEnd([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar).Equals(
        $volumeRoot.TrimEnd([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar),
        [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Select a specific folder, not a drive or share root.'
    }
    return $full
}
function Normalise([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    $root = [IO.Path]::GetPathRoot($full)
    if ($full.Equals($root,[StringComparison]::OrdinalIgnoreCase)) { return $full }
    return $full.TrimEnd([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar)
}
function Within([string]$Path,[string]$ContainerPath) {
    $one = Normalise $Path
    $root = Normalise $ContainerPath
    if ($one.Equals($root,[StringComparison]::OrdinalIgnoreCase)) { return $true }
    $prefix = if ($root.EndsWith([string][IO.Path]::DirectorySeparatorChar)) { $root }
              else { $root + [IO.Path]::DirectorySeparatorChar }
    return $one.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)
}
function Signature([string]$Path) {
    Assert-NoLinks $Path
    if (Test-Path -LiteralPath $Path -PathType Container) {
        throw 'A recovery operation points at a folder instead of a file.'
    }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    $info = Get-Item -LiteralPath $Path -Force
    return [pscustomobject]@{
        sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
        size_bytes = [int64]$info.Length
    }
}
function Signature-Matches([object]$Actual,[string]$Hash,[int64]$Size) {
    return $null -ne $Actual -and
        $Actual.sha256.Equals($Hash,[StringComparison]::OrdinalIgnoreCase) -and
        [int64]$Actual.size_bytes -eq $Size
}
function Must-Hash([object]$Value,[string]$Label) {
    if ($null -eq $Value -or [string]$Value -cnotmatch '^[a-fA-F0-9]{64}$') {
        throw "Invalid $Label checksum in session manifest."
    }
    return ([string]$Value).ToLowerInvariant()
}
function Must-Size([object]$Value,[string]$Label) {
    if ($null -eq $Value) { throw "Missing $Label size in session manifest." }
    $parsed = [int64]0
    if (-not [int64]::TryParse([string]$Value,[ref]$parsed) -or $parsed -lt 0) {
        throw "Invalid $Label size in session manifest."
    }
    return $parsed
}

$client = Require-Directory $ClientPath
$session = Require-Directory $SessionDirectory
if ((Within $client $session) -or (Within $session $client)) {
    throw 'Client and recovery session directories must be separate, non-nested locations.'
}
$manifestFile = Join-Path $session 'session.json'
Assert-NoLinks $manifestFile
if (-not (Test-Path -LiteralPath $manifestFile -PathType Leaf)) {
    throw 'Missing session.json in the selected recovery session folder.'
}
if ((Get-Item -LiteralPath $manifestFile -Force).Length -gt 1048576) {
    throw 'Recovery session manifest exceeds the 1 MiB size limit.'
}
$manifest = Get-Content -LiteralPath $manifestFile -Raw -Encoding UTF8 | ConvertFrom-Json
if ([int]$manifest.schema_version -ne 1 -or
    [string]$manifest.kind -cne 'local_naxxramas_setup_transaction' -or
    [string]$manifest.session_id -cnotmatch '^[A-Za-z0-9_-]{8,80}$' -or
    [string]$manifest.patchset -cnotmatch '^patchset-[0-9]{4}$' -or
    [int]$manifest.target_build -ne 12340 -or [string]$manifest.locale -cne 'enUS') {
    throw 'Unrecognised recovery session schema or target.'
}
$validStates = @('planned','validated','approved','staging','backing_up','committing',
    'verifying','completed','failed_recoverable','rollback_requested','restoring',
    'conflict_requires_review','restored','cancelled','blocked','support_required')
if ($validStates -cnotcontains [string]$manifest.status) {
    throw 'Unrecognised recovery session state.'
}
$rows = @($manifest.operations)
if ($rows.Count -lt 1 -or $rows.Count -gt 5) {
    throw 'Recovery session must contain between 1 and 5 operations.'
}
$allowed = @('Data/patch-V.mpq','Data/patch-Z.mpq','Data/Patch-J.mpq',
    'Data/Patch-U.mpq','Data/enUS/realmlist.wtf')
$seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
$results = New-Object 'System.Collections.Generic.List[object]'
$conflictCount = 0

foreach ($op in $rows) {
    $relative = [string]$op.relative_path
    if ($allowed -cnotcontains $relative) {
        throw 'Session lists a file outside the exact five-path Naxxramas recovery allowlist.'
    }
    if (-not $seen.Add($relative)) {
        throw 'Duplicate file in recovery operations.'
    }
    $action = [string]$op.action
    if ($action -cnotin @('install','replace_after_backup')) {
        throw 'Recovery only understands installed or backup-first replacement operations.'
    }
    if ($op.was_present -isnot [bool]) {
        throw 'Recovery operation must explicitly declare original file existence.'
    }
    $wasPresent = [bool]$op.was_present
    if (($wasPresent -and $action -cne 'replace_after_backup') -or
        (-not $wasPresent -and $action -cne 'install')) {
        throw 'Recovery action does not agree with original file existence.'
    }
    $afterHash = Must-Hash $op.installed_sha256 'installed'
    $afterSize = Must-Size $op.installed_size_bytes 'installed'
    $beforeHash = $null
    $beforeSize = $null
    $backupSignature = $null
    $backupState = 'not_applicable'

    if ($wasPresent) {
        $beforeHash = Must-Hash $op.before_sha256 'original'
        $beforeSize = Must-Size $op.before_size_bytes 'original'
        $backupRelative = [string]$op.backup_relative_path
        if ($backupRelative -cnotmatch '^originals/[0-9]{4}\.bin$') {
            throw 'Recovery backup path is not a safe, expected relative filename.'
        }
        $backupFile = Join-Path $session ($backupRelative.Replace('/',[IO.Path]::DirectorySeparatorChar))
        $backupSignature = Signature $backupFile
        $backupState = if ($null -eq $backupSignature) { 'missing' }
          elseif (Signature-Matches $backupSignature $beforeHash $beforeSize) { 'verified' }
          else { 'corrupt_or_wrong_version' }
    } else {
        if ($null -ne $op.before_sha256 -or $null -ne $op.before_size_bytes -or
            $null -ne $op.backup_relative_path) {
            throw 'Newly installed file may not claim an original-file backup.'
        }
    }

    $clientFile = Join-Path $client ($relative.Replace('/',[IO.Path]::DirectorySeparatorChar))
    $current = Signature $clientFile
    $decision = ''
    $reason = ''
    if ($wasPresent -and (Signature-Matches $current $beforeHash $beforeSize)) {
        $decision = 'already_original'
        $reason = 'Current file already matches the pre-install version; no restoration needed.'
    } elseif ($null -eq $current -and -not $wasPresent) {
        $decision = 'already_absent'
        $reason = 'File was originally absent and is currently absent; no removal needed.'
    } elseif (Signature-Matches $current $afterHash $afterSize) {
        if ($wasPresent) {
            if ($backupState -eq 'verified') {
                $decision = 'restore_after_approval'
                $reason = 'Current file matches the recorded installed version; exact original backup verified.'
            } else {
                $decision = 'blocked_backup_unavailable'
                $reason = 'Current file matches installed state but its exact original backup is missing or corrupt.'
            }
        } else {
            $decision = 'remove_after_approval'
            $reason = 'Current file matches what the session says it created; future rollback could remove after consent.'
        }
    } else {
        $decision = 'conflict_preserve_current'
        $reason = 'Current contents differ from both original and installed signatures, or a prior file is now missing. Never overwrite automatically.'
    }
    if ($decision -eq 'blocked_backup_unavailable' -or $decision -eq 'conflict_preserve_current') {
        $conflictCount++
    }

    $results.Add([pscustomobject][ordered]@{
        relative_path = $relative
        original_existed = $wasPresent
        recorded_action = $action
        current_state = if ($null -eq $current) { 'missing' }
          elseif (Signature-Matches $current $afterHash $afterSize) { 'installed_signature' }
          elseif ($wasPresent -and (Signature-Matches $current $beforeHash $beforeSize)) { 'original_signature' }
          else { 'unknown_changed_signature' }
        backup_state = $backupState
        proposed_recovery = $decision
        reason = $reason
    })
}
$plan = [pscustomobject][ordered]@{
    schema_version = 1
    kind = 'read_only_recovery_preview_not_restore_authorisation'
    session_id = [string]$manifest.session_id
    recorded_session_status = [string]$manifest.status
    patchset = [string]$manifest.patchset
    status = if ($conflictCount -gt 0) { 'manual_conflict_review_required' } else { 'review_only_no_conflicts' }
    conflict_count = $conflictCount
    operations = @($results.ToArray())
    warning = 'READ ONLY: no files were created, changed, restored or removed. A future restoration engine must recheck every file and obtain consent.'
}
if ($Json) {
    $plan | ConvertTo-Json -Depth 10
} else {
    Write-Host ''
    Write-Host 'Naxxramas Client - READ ONLY RECOVERY PREVIEW' -ForegroundColor Cyan
    Write-Host "Session: $($plan.session_id), reference: $($plan.patchset)"
    foreach ($entry in @($plan.operations)) {
        Write-Host ("{0,-31} {1} (backup: {2})" -f
            $entry.proposed_recovery,$entry.relative_path,$entry.backup_state)
    }
    Write-Host "Review status: $($plan.status), conflicts: $($plan.conflict_count)"
    Write-Host $plan.warning -ForegroundColor Yellow
}
