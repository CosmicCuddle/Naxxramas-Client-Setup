#requires -Version 5.1
# Synthetic recovery-decision tests. Never use a real game client or real MPQ.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Expect([bool]$Condition,[string]$Message) {
    if (-not $Condition) { throw "TEST FAILED: $Message" }
    Write-Host "PASS: $Message" -ForegroundColor Green
}
function Write-Text([string]$Path,[string]$Text) {
    [IO.File]::WriteAllBytes($Path,[Text.Encoding]::ASCII.GetBytes($Text))
}
function Sign([string]$Path) {
    return [pscustomobject]@{
        sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
        size_bytes = [int64](Get-Item -LiteralPath $Path).Length
    }
}
function Snapshot([string]$Path) {
    $parts = @(
        Get-ChildItem -LiteralPath $Path -Recurse -File |
          Sort-Object -Property FullName |
          ForEach-Object {
            $_.FullName.Substring($Path.Length) + ':' +
                (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
          }
    )
    return ($parts -join '|')
}

$root = Join-Path ([IO.Path]::GetTempPath()) ('NaxxRecoveryFixture-' + [guid]::NewGuid().ToString('N'))
$client = Join-Path $root 'client'
$session = Join-Path $root 'session'
$inspector = Join-Path (Split-Path -Parent $PSScriptRoot) 'tools/Review-Naxxramas-Recovery.ps1'
try {
    foreach ($path in @($client,$session,(Join-Path $client 'Data'),
          (Join-Path $session 'originals'))) {
        $null = New-Item -ItemType Directory -Path $path -Force
    }
    $v = Join-Path $client 'Data/patch-V.mpq'
    $u = Join-Path $client 'Data/Patch-U.mpq'
    $backupV = Join-Path $session 'originals/0001.bin'
    Write-Text $v 'test-installed-V'
    Write-Text $u 'test-installed-U'
    Write-Text $backupV 'test-original-V'
    $old = Sign $backupV
    $newV = Sign $v
    $newU = Sign $u

    function Make-Manifest {
        $manifestData = [ordered]@{
            schema_version = 1
            kind = 'local_naxxramas_setup_transaction'
            session_id = 'fixture-session-001'
            status = 'completed'
            patchset = 'patchset-0001'
            target_build = 12340
            locale = 'enUS'
            operations = @(
                [ordered]@{
                    relative_path = 'Data/patch-V.mpq'
                    action = 'replace_after_backup'
                    was_present = $true
                    before_sha256 = $old.sha256
                    before_size_bytes = $old.size_bytes
                    backup_relative_path = 'originals/0001.bin'
                    installed_sha256 = $newV.sha256
                    installed_size_bytes = $newV.size_bytes
                    checkpoint = 'verified'
                },
                [ordered]@{
                    relative_path = 'Data/Patch-U.mpq'
                    action = 'install'
                    was_present = $false
                    before_sha256 = $null
                    before_size_bytes = $null
                    backup_relative_path = $null
                    installed_sha256 = $newU.sha256
                    installed_size_bytes = $newU.size_bytes
                    checkpoint = 'verified'
                }
            )
        }
        return $manifestData
    }
    function Store-Manifest([object]$Data) {
        $Data | ConvertTo-Json -Depth 12 |
          Set-Content -LiteralPath (Join-Path $session 'session.json') -Encoding UTF8
    }
    function Preview {
        $beforeClient = Snapshot $client
        $beforeSession = Snapshot $session
        $raw = & $inspector -ClientPath $client -SessionDirectory $session -Json | Out-String
        Expect ((Snapshot $client) -ceq $beforeClient) 'Recovery preview leaves client files untouched'
        Expect ((Snapshot $session) -ceq $beforeSession) 'Recovery preview leaves backups and journal untouched'
        Expect (-not $raw.Contains($root)) 'Recovery report excludes absolute fixture paths'
        return ($raw | ConvertFrom-Json)
    }
    function Row([object]$Report,[string]$Relative) {
        return @($Report.operations | Where-Object { $_.relative_path -eq $Relative })[0]
    }
    function Must-Throw([string]$Message) {
        $failed = $false
        try {
            $null = & $inspector -ClientPath $client -SessionDirectory $session -Json 2>&1 | Out-String
        } catch { $failed = $true }
        Expect $failed $Message
    }

    $originalManifest = Make-Manifest
    Store-Manifest $originalManifest
    $report = Preview
    Expect ($report.status -eq 'review_only_no_conflicts') 'Verified session reports no conflicts'
    Expect ((Row $report 'Data/patch-V.mpq').proposed_recovery -eq 'restore_after_approval') 'Previously replaced patch requires verified original backup'
    Expect ((Row $report 'Data/Patch-U.mpq').proposed_recovery -eq 'remove_after_approval') 'Created optional patch is only suggested for removal'
    Expect ((Row $report 'Data/patch-V.mpq').backup_state -eq 'verified') 'Original backup is SHA-256 checked'

    Write-Text $v 'player-custom-edit'
    $report = Preview
    Expect ((Row $report 'Data/patch-V.mpq').proposed_recovery -eq 'conflict_preserve_current') 'Player-edited core patch is preserved'
    Expect ($report.status -eq 'manual_conflict_review_required') 'Changed-file conflict blocks automatic recovery'

    Write-Text $v 'test-installed-V'
    Remove-Item -LiteralPath $backupV
    $report = Preview
    Expect ((Row $report 'Data/patch-V.mpq').proposed_recovery -eq 'blocked_backup_unavailable') 'Missing original backup blocks restore'

    Write-Text $backupV 'tampered-backup'
    $report = Preview
    Expect ((Row $report 'Data/patch-V.mpq').backup_state -eq 'corrupt_or_wrong_version') 'Corrupted backup is detected'
    Expect ((Row $report 'Data/patch-V.mpq').proposed_recovery -eq 'blocked_backup_unavailable') 'Corrupt backup cannot be used'

    Write-Text $backupV 'test-original-V'
    Write-Text $v 'test-original-V'
    Remove-Item -LiteralPath $u
    $report = Preview
    Expect ((Row $report 'Data/patch-V.mpq').proposed_recovery -eq 'already_original') 'Previously restored original needs no modification'
    Expect ((Row $report 'Data/Patch-U.mpq').proposed_recovery -eq 'already_absent') 'Previously removed created file needs no modification'

    Write-Text $v 'test-installed-V'
    Write-Text $u 'test-installed-U'
    $bad = Make-Manifest
    $bad.operations[0].relative_path = '../WTF/Account'
    Store-Manifest $bad
    Must-Throw 'Path traversal or unlisted file is rejected'

    $bad = Make-Manifest
    $bad.operations[1].relative_path = 'Data/patch-V.mpq'
    Store-Manifest $bad
    Must-Throw 'Duplicate recovery operation is rejected'

    $bad = Make-Manifest
    $bad.operations[0].backup_relative_path = '../private.txt'
    Store-Manifest $bad
    Must-Throw 'Unsafe backup relative path is rejected'

    $bad = Make-Manifest
    $bad.operations[0].installed_sha256 = 'bad-hash'
    Store-Manifest $bad
    Must-Throw 'Invalid expected installed checksum is rejected'

    $bad = Make-Manifest
    $bad.operations[0].action = 'install'
    Store-Manifest $bad
    Must-Throw 'Inconsistent original presence and action is rejected'

    $bad = Make-Manifest
    $bad.status = 'unknown_status'
    Store-Manifest $bad
    Must-Throw 'Unknown session state is rejected'

    # A matching file hash does NOT prove an incomplete journal was committed.
    $incomplete = Make-Manifest
    $incomplete.status = 'planned'
    Store-Manifest $incomplete
    $report = Preview
    Expect ((Row $report 'Data/patch-V.mpq').proposed_recovery -eq 'blocked_incomplete_journal') 'Planned session cannot offer restoration'
    Expect ((Row $report 'Data/Patch-U.mpq').proposed_recovery -eq 'blocked_incomplete_journal') 'Planned session cannot offer removal'
    Expect ($report.status -eq 'manual_conflict_review_required') 'Uncommitted plan requires manual review'

    $incomplete = Make-Manifest
    $incomplete.status = 'failed_recoverable'
    Store-Manifest $incomplete
    $report = Preview
    Expect ((Row $report 'Data/patch-V.mpq').proposed_recovery -eq 'blocked_incomplete_journal') 'Interrupted session cannot automatically restore'

    $incomplete = Make-Manifest
    $incomplete.operations[0].checkpoint = 'write_started'
    Store-Manifest $incomplete
    $report = Preview
    Expect ((Row $report 'Data/patch-V.mpq').proposed_recovery -eq 'blocked_incomplete_journal') 'Unverified file checkpoint blocks restoration'
    Expect ((Row $report 'Data/Patch-U.mpq').proposed_recovery -eq 'remove_after_approval') 'Verified separate operation retains its review suggestion'

    $bad = Make-Manifest
    $bad.operations[0].checkpoint = 'invalid_checkpoint'
    Store-Manifest $bad
    Must-Throw 'Unknown checkpoint is rejected rather than interpreted'

    $bad = Make-Manifest
    $bad.operations[1].action = 'replace_after_backup'
    $bad.operations[1].was_present = $true
    $bad.operations[1].before_sha256 = $old.sha256
    $bad.operations[1].before_size_bytes = $old.size_bytes
    $bad.operations[1].backup_relative_path = 'originals/0001.bin'
    Store-Manifest $bad
    Must-Throw 'Shared backup alias between operations is rejected'

    Store-Manifest (Make-Manifest)
    $nested = Join-Path $client 'session-nested'
    $null = New-Item -ItemType Directory -Path $nested -Force
    $nestedRejected = $false
    try {
        $null = & $inspector -ClientPath $client -SessionDirectory $nested -Json 2>&1 | Out-String
    } catch { $nestedRejected = $true }
    Expect $nestedRejected 'Nested client/session folders are rejected'

    Write-Host ''
    Write-Host 'All read-only recovery preview fixture tests passed.' -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $root) {
        Remove-Item -LiteralPath $root -Recurse -Force
    }
}
