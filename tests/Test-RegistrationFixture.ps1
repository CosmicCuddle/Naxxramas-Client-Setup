#requires -Version 5.1
# Generated fake folders only. Does not inspect a real WoW client.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Check([bool]$Condition,[string]$Message) {
    if (-not $Condition) { throw "TEST FAILED: $Message" }
    Write-Host "PASS: $Message" -ForegroundColor Green
}
function Save-Json([string]$Path,[object]$Value) {
    [IO.File]::WriteAllText($Path,(ConvertTo-Json -InputObject $Value -Compress -Depth 10),
        (New-Object Text.UTF8Encoding($false)))
}
function Snapshot([string]$Directory) {
    $entries = @(Get-ChildItem -LiteralPath $Directory -Recurse -File -Force |
        Sort-Object FullName | ForEach-Object {
            $_.FullName.Substring($Directory.Length) + ':' +
                (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        })
    return ($entries -join '|')
}
function Review([string]$Folder) {
    $params = @{ ClientPath=$Folder; FixtureRegistrationPath=$registrationPath;
        FixtureSessionPath=$sessionPath; Json=$true }
    return ((& $reviewer @params | Out-String) | ConvertFrom-Json)
}
function Require-Status([string]$Folder,[string]$Expected,[string]$Message) {
    $actual = Review $Folder
    Check ($actual.status -ceq $Expected) ($Message + " (status: " + $actual.status + ")")
    Check (-not $actual.allow_file_writes -and -not $actual.authorises_rollback) 'No fixture review authorises a client write or rollback'
}
function Invalid-Fails([string]$Folder,[string]$Message) {
    $failed = $false
    try { $null = Review $Folder } catch { $failed = $true }
    Check $failed $Message
}
$root = Join-Path ([IO.Path]::GetTempPath()) ('NaxxRegReview-' + [guid]::NewGuid().ToString('N'))
$reviewer = Join-Path (Split-Path -Parent $PSScriptRoot) 'tools/Review-Naxxramas-RegistrationFixture.ps1'
$identityScript = Join-Path (Split-Path -Parent $PSScriptRoot) 'tools/Inspect-Naxxramas-DirectoryIdentity.ps1'
try {
    $null = New-Item -ItemType Directory -Path $root
    $client = Join-Path $root 'fake-client'
    $null = New-Item -ItemType Directory -Path $client
    $null = New-Item -ItemType Directory -Path (Join-Path $client 'Data/enUS') -Force
    [IO.File]::WriteAllText((Join-Path $client 'Wow.exe'),'synthetic only')
    [IO.File]::WriteAllText((Join-Path $client 'Data/enUS/realmlist.wtf'),'test')
    $registrationPath = Join-Path $root 'registration-fixture.json'
    $sessionPath = Join-Path $root 'session-fixture.json'
    $installation = 'fixture-install-123'
    $sessionId = 'fixture-session-123'
    $identity = ((& $identityScript -ClientPath $client -Json | Out-String) | ConvertFrom-Json)
    $fingerprint = [string]$identity.client_fingerprint_sha256
    function Registration([string]$Fingerprint=$fingerprint,[int]$Sequence=3,
        [string]$InstallationId=$installation,[string]$Patchset='patchset-0001') {
        return ,@(1,$InstallationId,$Fingerprint,$Patchset,$Sequence)
    }
    function Session([int]$Sequence=3,[string]$Checkpoint='completed',
        [string]$InstallationId=$installation,[string]$Patchset='patchset-0001') {
        return ,@(1,$InstallationId,$sessionId,$Patchset,$Sequence,$Checkpoint)
    }
    function Reset-Files {
        Save-Json $registrationPath (Registration)
        Save-Json $sessionPath (Session)
    }

    Require-Status $client 'manual_review_registration_missing' 'Missing registration blocks managed status'
    Save-Json $registrationPath (Registration)
    Require-Status $client 'manual_review_session_missing' 'Missing session blocks managed status'
    Reset-Files
    $start = Snapshot $root
    $valid = Review $client
    Check ($valid.status -ceq 'fixture_fields_consistent_NOT_trusted') 'Matching synthetic fields are classified as internally consistent only'
    Check ($valid.folder_fingerprint_matches -eq $true) 'Selected directory matches registration observation'
    Check ($valid.registration_present -and $valid.session_present) 'Both source fixtures are reported present'
    Check (-not $valid.allow_file_writes -and -not $valid.authorises_rollback) 'Matching fixtures still never permit writes'
    Check ((Snapshot $root) -ceq $start) 'Read-only review leaves every fixture untouched'

    $copied = Join-Path $root 'independent-client-copy'
    Copy-Item -LiteralPath $client -Destination $copied -Recurse
    Require-Status $copied 'manual_review_folder_identity_changed' 'Copy of same game data is NOT original registered folder'
    Check ((Review $copied).folder_fingerprint_matches -eq $false) 'Copied folder fingerprint is explicitly different'

    # Explicit residual risk: if someone can forge the untrusted registration
    # to match a copied folder, the values will look internally consistent.
    # NEVER interpret a consistent fixture as trusted installer ownership.
    $copyObserved = ((& $identityScript -ClientPath $copied -Json | Out-String) | ConvertFrom-Json)
    Save-Json $registrationPath (Registration ([string]$copyObserved.client_fingerprint_sha256))
    $forged = Review $copied
    Check ($forged.status -ceq 'fixture_fields_consistent_NOT_trusted') 'Caller-controlled registration can be forged to match a copied folder'
    Check (-not $forged.allow_file_writes -and -not $forged.authorises_rollback) 'Forged-but-matching records NEVER authorise writes'
    Reset-Files

    $renamed = Join-Path $root 'renamed-client'
    Rename-Item -LiteralPath $client -NewName 'renamed-client'
    Require-Status $renamed 'fixture_fields_consistent_NOT_trusted' 'Folder rename on same filesystem preserves observed identity'
    Require-Status $client 'manual_review_folder_unavailable' 'Original path no longer exists and cannot be silently used'

    Reset-Files
    Save-Json $sessionPath (Session 2 'completed')
    Require-Status $renamed 'manual_review_stale_session' 'A session behind the registered committed sequence is blocked'
    Reset-Files
    Save-Json $sessionPath (Session 4 'completed')
    Require-Status $renamed 'manual_review_uncommitted_sequence' 'Session ahead of registered committed sequence is blocked'

    # Explicit residual risk: rolling BOTH user-controlled records backwards
    # leaves no independently protected latest-state evidence.
    Reset-Files
    Save-Json $registrationPath (Registration $fingerprint 1)
    Save-Json $sessionPath (Session 1 'completed')
    $replayed = Review $renamed
    Check ($replayed.status -ceq 'fixture_fields_consistent_NOT_trusted') 'Coordinated old registration and session replay is NOT detectable with untrusted fixtures'
    Check (-not $replayed.allow_file_writes -and -not $replayed.authorises_rollback) 'Coordinated replay cannot authorise writes'
    Reset-Files

    foreach ($checkpoint in @('planned','approved','backup_verified','write_started',
        'verified','rollback_requested','failed_recoverable')) {
        Reset-Files
        Save-Json $sessionPath (Session 3 $checkpoint)
        Require-Status $renamed 'manual_review_interrupted_or_uncommitted' ("Incomplete checkpoint " + $checkpoint + " cannot claim completion")
    }
    Reset-Files
    Save-Json $registrationPath (Registration $fingerprint 0)
    Save-Json $sessionPath (Session 0 'completed')
    Require-Status $renamed 'manual_review_interrupted_or_uncommitted' 'Zero-event completed session cannot count as valid state'

    Reset-Files
    Save-Json $sessionPath (Session 3 'completed' 'other-install-123')
    Require-Status $renamed 'manual_review_installation_mismatch' 'Different installation ID is rejected'
    Reset-Files
    Save-Json $sessionPath (Session 3 'completed' $installation 'patchset-0002')
    Require-Status $renamed 'manual_review_patchset_mismatch' 'Different patchset reference is rejected'

    Reset-Files
    Save-Json $registrationPath (Registration ('c' * 64))
    Require-Status $renamed 'manual_review_folder_identity_changed' 'Different recorded directory fingerprint mismatches live observation'

    Reset-Files
    Save-Json $sessionPath (Session 3 'invented_checkpoint')
    Invalid-Fails $renamed 'Unknown checkpoint rejected before a report is emitted'
    Reset-Files
    Save-Json $registrationPath @(1,$installation,$fingerprint,'patchset-0001',-2)
    Invalid-Fails $renamed 'Negative sequence number is rejected'
    Reset-Files
    Save-Json $registrationPath @(1,$installation,$fingerprint,'patchset-0001','3')
    Invalid-Fails $renamed 'String sequence is rejected rather than coerced into integer'
    Reset-Files
    Save-Json $sessionPath @(1,$installation,$sessionId,'patchset-0001',3,'completed','extra')
    Invalid-Fails $renamed 'Extra session fields are rejected'
    Reset-Files
    [IO.File]::WriteAllText($registrationPath,'{"schema_version":1,"schema_version":2}')
    Invalid-Fails $renamed 'Object-shaped and duplicate-property registration is rejected'
    Reset-Files
    [IO.File]::WriteAllText($registrationPath,(' ' * 16385))
    Invalid-Fails $renamed 'Oversized registration is rejected'
    Reset-Files

    $beforeFinal = Snapshot $root
    $result = Review $renamed
    Check ($result.status -eq 'fixture_fields_consistent_NOT_trusted') 'Valid synthetic state restored after all negative tests'
    Check ((Snapshot $root) -ceq $beforeFinal) 'Final read-only review leaves all inputs identical'
    $rawParams = @{ClientPath=$renamed; FixtureRegistrationPath=$registrationPath; FixtureSessionPath=$sessionPath; Json=$true}
    $raw = (& $reviewer @rawParams | Out-String)
    Check (-not $raw.Contains($root)) 'Report omits local folder paths'
    Check (-not $raw.Contains($fingerprint)) 'Report omits the local directory fingerprint'
    Write-Host 'All read-only synthetic registration and interruption tests passed.' -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $root) {
        Remove-Item -LiteralPath $root -Recurse -Force
    }
}
