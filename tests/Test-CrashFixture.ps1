#requires -Version 5.1
# Disposable JSON records only; no client file reads/writes.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
function Check([bool]$OK,[string]$Label) {
    if (-not $OK) { throw "TEST FAILED: $Label" }
    Write-Host "PASS: $Label" -ForegroundColor Green
}
function V([string]$Action='replace_after_backup',[string]$Backup='verified',[string]$Destination='installed',[string]$Phase='committed') {
    return ,@('Data/patch-V.mpq',$Action,$Backup,$Destination,$Phase)
}
function Z([string]$Action='replace_after_backup',[string]$Backup='verified',[string]$Destination='installed',[string]$Phase='committed') {
    return ,@('Data/patch-Z.mpq',$Action,$Backup,$Destination,$Phase)
}
function Scenario([string]$Checkpoint='completed',[string]$Anchor='matches',[object]$FileV=(V),[object]$FileZ=(Z)) {
    return ,@(1,'fixture-session-123','patchset-0001',$Checkpoint,$Anchor,$FileV,$FileZ)
}
function Save([object]$Fixture) {
    $json = ConvertTo-Json -InputObject $Fixture -Compress -Depth 12
    [IO.File]::WriteAllText($inputFile,$json,(New-Object Text.UTF8Encoding($false)))
}
function Inspect {
    return ((& $inspector -FixturePath $inputFile -Json | Out-String) | ConvertFrom-Json)
}
function Expect([object]$Fixture,[string]$Expected,[string]$Description) {
    Save $Fixture
    $before = (Get-FileHash -LiteralPath $inputFile -Algorithm SHA256).Hash
    $result = Inspect
    Check ($result.classification -ceq $Expected) ($Description + ': ' + $result.classification)
    Check (-not $result.allow_file_writes -and -not $result.allow_automatic_resume -and -not $result.authorises_rollback) 'Never authorises writes, resume or rollback'
    Check ((Get-FileHash -LiteralPath $inputFile -Algorithm SHA256).Hash -ceq $before) 'Review does not change fixture bytes'
}
function Invalid([object]$Fixture,[string]$Description) {
    Save $Fixture
    $failed = $false
    try { $null = Inspect } catch { $failed = $true }
    Check $failed $Description
}
$root = Join-Path ([IO.Path]::GetTempPath()) ('NaxxCrashFixture-' + [guid]::NewGuid().ToString('N'))
$inputFile = Join-Path $root 'crash.json'
$inspector = Join-Path (Split-Path -Parent $PSScriptRoot) 'tools/Review-Naxxramas-CrashFixture.ps1'
try {
    $null = New-Item -ItemType Directory -Path $root
    Expect (Scenario) 'fixture_fields_consistent_NOT_trusted' 'Finished V/Z fixture is only internally consistent'
    Expect (Scenario -FileV (V 'install' 'not_required') -FileZ (Z 'install' 'not_required')) 'fixture_fields_consistent_NOT_trusted' 'Both new files remain untrusted'
    Expect (Scenario -Checkpoint 'planned' -FileV (V 'replace_after_backup' 'missing' 'original' 'planned') -FileZ (Z 'replace_after_backup' 'missing' 'original' 'planned')) 'manual_review_incomplete_or_inconsistent_session' 'Before backup'
    Expect (Scenario -Checkpoint 'staged' -FileV (V 'replace_after_backup' 'missing' 'original' 'staged') -FileZ (Z 'replace_after_backup' 'missing' 'original' 'staged')) 'manual_review_incomplete_or_inconsistent_session' 'During staging'
    Expect (Scenario -Checkpoint 'backup_started' -FileV (V 'replace_after_backup' 'missing' 'original' 'backup_started') -FileZ (Z 'replace_after_backup' 'missing' 'original' 'planned')) 'manual_review_incomplete_or_inconsistent_session' 'Interrupted backup copy'
    Expect (Scenario -Checkpoint 'backup_started' -FileV (V 'replace_after_backup' 'corrupt' 'original' 'backup_started')) 'manual_review_original_backup_corrupt' 'Corrupt original before client write'
    Expect (Scenario -Checkpoint 'backups_verified' -FileV (V 'replace_after_backup' 'verified' 'original' 'backup_verified') -FileZ (Z 'replace_after_backup' 'verified' 'original' 'backup_verified')) 'manual_review_incomplete_or_inconsistent_session' 'After backups'
    Expect (Scenario -Checkpoint 'intent_durable' -FileV (V 'replace_after_backup' 'verified' 'original' 'intent_durable') -FileZ (Z 'replace_after_backup' 'verified' 'original' 'intent_durable')) 'manual_review_incomplete_or_inconsistent_session' 'After intent'
    Expect (Scenario -Checkpoint 'write_started' -FileV (V 'replace_after_backup' 'verified' 'installed' 'write_started') -FileZ (Z 'replace_after_backup' 'verified' 'original' 'intent_durable')) 'manual_review_ambiguous_commit' 'After V rename before verified checkpoint'
    Expect (Scenario -Checkpoint 'write_started' -FileV (V 'replace_after_backup' 'verified' 'installed' 'write_verified') -FileZ (Z 'replace_after_backup' 'verified' 'original' 'planned')) 'manual_review_partial_core' 'Between V and Z'
    Expect (Scenario -Checkpoint 'write_started' -FileV (V 'replace_after_backup' 'verified' 'installed' 'staged')) 'manual_review_write_without_intent' 'Installed bytes without recorded intent'
    Expect (Scenario -Checkpoint 'files_verified' -FileV (V 'replace_after_backup' 'verified' 'installed' 'write_verified') -FileZ (Z 'replace_after_backup' 'verified' 'installed' 'write_verified')) 'manual_review_incomplete_or_inconsistent_session' 'After V/Z verification without commits'
    Expect (Scenario -Checkpoint 'finalising') 'manual_review_incomplete_or_inconsistent_session' 'Before final session completion'
    Expect (Scenario -FileV (V 'replace_after_backup' 'verified' 'installed' 'write_verified')) 'manual_review_incomplete_or_inconsistent_session' 'Completed claim with uncommitted V'
    Expect (Scenario -Checkpoint 'rollback_requested') 'manual_review_incomplete_or_inconsistent_session' 'Rollback never automatically resumes'
    foreach ($claim in @('missing','stale','ahead','unverified')) {
        Expect (Scenario -Anchor $claim) 'manual_review_unverified_anchor' ("Anchor claim " + $claim)
    }
    Expect (Scenario -FileV (V 'replace_after_backup' 'verified' 'modified')) 'manual_review_destination_conflict' 'Preserve player edit'
    Expect (Scenario -FileZ (Z 'replace_after_backup' 'verified' 'unknown')) 'manual_review_destination_conflict' 'Preserve unknown contents'
    Expect (Scenario -FileV (V 'replace_after_backup' 'missing')) 'manual_review_original_backup_unavailable' 'Replaced file with no backup'
    Expect (Scenario -FileV (V 'replace_after_backup' 'corrupt')) 'manual_review_original_backup_unavailable' 'Corrupt original after replacement'
    Expect (Scenario -FileV (V 'replace_after_backup' 'verified' 'missing')) 'manual_review_missing_destination' 'Missing destination after replace'

    Invalid @(2,'fixture-session-123','patchset-0001','completed','matches',(V),(Z)) 'Unknown schema rejected'
    Invalid @(1,'fixture-session-123','patchset-0001','completed','matches',(V)) 'Missing Z record rejected'
    Invalid (Scenario -FileV @('Data/patch-Z.mpq','replace_after_backup','verified','installed','committed')) 'Unexpected V path rejected'
    Invalid (Scenario -FileV @('Data/patch-V.mpq','replace_after_backup','not_required','installed','committed')) 'Backup omitted on replacement rejected'
    Invalid (Scenario -FileV @('Data/patch-V.mpq','install','verified','installed','committed')) 'Created file cannot claim backup'
    Invalid (Scenario -FileV @('Data/patch-V.mpq','replace_after_backup','verified','installed','committed','extra')) 'Additional fields rejected'
    Invalid (Scenario -Checkpoint 'unrecognised') 'Unknown session checkpoint rejected'
    Invalid (Scenario -Anchor 'trusted') 'Invented trust state rejected'

    [IO.File]::WriteAllText($inputFile,'{"session":1,"session":2}')
    $objectRejected = $false
    try { $null = Inspect } catch { $objectRejected = $true }
    Check $objectRejected 'Object and duplicate JSON properties rejected'
    [IO.File]::WriteAllText($inputFile,('x' * 16385))
    $bigRejected = $false
    try { $null = Inspect } catch { $bigRejected = $true }
    Check $bigRejected 'Oversized JSON rejected'
    Remove-Item -LiteralPath $inputFile
    $missingRejected = $false
    try { $null = Inspect } catch { $missingRejected = $true }
    Check $missingRejected 'Missing fixture rejected without creating it'
    Save (Scenario)
    $output = (& $inspector -FixturePath $inputFile -Json | Out-String)
    Check (-not $output.Contains($root)) 'No absolute fixture path disclosed'
    Check (-not $output.Contains('fixture-session-123')) 'Session ID not disclosed'
    Check (-not (Test-Path -LiteralPath (Join-Path $root 'created'))) 'No generated output files'
    Write-Host 'All read-only synthetic crash-boundary tests passed.' -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
