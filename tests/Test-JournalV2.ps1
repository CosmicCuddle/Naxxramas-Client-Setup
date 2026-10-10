#requires -Version 5.1
# All data, including key material, are generated locally in a throwaway fixture.
# This test never reads a real WoW client, private journals, or proprietary MPQs.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert([bool]$Condition,[string]$Message) {
    if (-not $Condition) { throw "TEST FAILED: $Message" }
    Write-Host "PASS: $Message" -ForegroundColor Green
}
function SHA([byte[]]$Value) {
    $hash = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hash.ComputeHash($Value))).Replace('-','').ToLowerInvariant() }
    finally { $hash.Dispose() }
}
function HMAC([byte[]]$Value,[byte[]]$Secret) {
    $h = New-Object Security.Cryptography.HMACSHA256(,$Secret)
    try { return ([BitConverter]::ToString($h.ComputeHash($Value))).Replace('-','').ToLowerInvariant() }
    finally { $h.Dispose() }
}
function Save-Json([string]$Path,[object]$Value) {
    $json = ConvertTo-Json -InputObject $Value -Depth 12 -Compress
    [IO.File]::WriteAllText($Path,$json,(New-Object Text.UTF8Encoding($false)))
}
function Snap([string]$Directory) {
    $entries = @(Get-ChildItem -LiteralPath $Directory -File -Recurse |
        Sort-Object FullName | ForEach-Object {
            $_.FullName.Substring($Directory.Length) + ':' +
                (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        })
    return ($entries -join '|')
}
function Verify-ExpectedFailure([string]$Name) {
    $failed = $false
    try { $null = & $validator -EnvelopePath $envelopeFile -AnchorPath $anchorFile -FixtureKeyPath $keyFile -Json 2>&1 | Out-String }
    catch { $failed = $true }
    Assert $failed $Name
}
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('NaxxSignedJournal-' + [guid]::NewGuid().ToString('N'))
$validator = Join-Path (Split-Path -Parent $PSScriptRoot) 'tools/Inspect-Naxxramas-JournalV2.ps1'
try {
    $null = New-Item -ItemType Directory -Path $fixture
    $envelopeFile = Join-Path $fixture 'envelope.json'
    $anchorFile = Join-Path $fixture 'anchor.json'
    $keyFile = Join-Path $fixture 'fixture-private-key.bin'
    # Separate synthetic witness directory and independently generated key.
    # These are NOT DPAPI-protected and cannot anchor real production state.
    $witnessDir = Join-Path $fixture 'fixture-independent-witness'
    $null = New-Item -ItemType Directory -Path $witnessDir
    $witnessFile = Join-Path $witnessDir 'latest-witness.json'
    $witnessKeyFile = Join-Path $witnessDir 'witness-fixture-key.bin'
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    $secret = New-Object byte[] 32
    try { $rng.GetBytes($secret) } finally { $rng.Dispose() }
    [IO.File]::WriteAllBytes($keyFile,$secret)
    $witnessSecret = New-Object byte[] 32
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($witnessSecret) } finally { $rng.Dispose() }
    [IO.File]::WriteAllBytes($witnessKeyFile,$witnessSecret)
    $sid = 'fixture-session-1234'
    $iid = 'fixture-install-123'
    $fakeOld = ('a' * 64)
    $fakeNew = ('b' * 64)
    $zero = ('0' * 64)

    function Make-Event([int]$Sequence,[string]$Previous,[string]$State,
        [string]$Path='Data/patch-V.mpq',[string]$Action='replace_after_backup',
        [string]$Backup='originals/0001.bin') {
        $beforeHash = if ($Action -eq 'install') { '-' } else { $fakeOld }
        $beforeSize = if ($Action -eq 'install') { '-' } else { '20' }
        $backupValue = if ($Action -eq 'install') { '-' } else { $Backup }
        $payload = @('NXJ2',$sid,$iid,[string]$Sequence,'patchset-0001',$State,
            $Path,$Action,$Previous,$beforeHash,$fakeNew,$beforeSize,'22',$backupValue,'12340') -join '|'
        $bytes = [Text.Encoding]::ASCII.GetBytes($payload)
        return ,@([Convert]::ToBase64String($bytes),(HMAC $bytes $secret))
    }
    function Make-Anchor([int]$Sequence,[string]$Head) {
        $toSign = 'NXA2|' + $sid + '|' + $iid + '|' + $Sequence + '|' + $Head
        $mac = HMAC ([Text.Encoding]::ASCII.GetBytes($toSign)) $secret
        return ,@(2,$sid,$iid,$Sequence,$Head,$mac)
    }
    function Make-Witness([object]$LatestAnchor) {
        $text = 'NXW2|' + $LatestAnchor[1] + '|' + $LatestAnchor[2] +
            '|' + $LatestAnchor[3] + '|' + $LatestAnchor[4]
        $signature = HMAC ([Text.Encoding]::ASCII.GetBytes($text)) $witnessSecret
        return ,@(2,$LatestAnchor[1],$LatestAnchor[2],$LatestAnchor[3],$LatestAnchor[4],$signature)
    }
    function Store-Witness([object]$LatestAnchor) {
        Save-Json $witnessFile (Make-Witness $LatestAnchor)
    }
    function Inspect-WithWitness {
        $output = & $validator -EnvelopePath $envelopeFile -AnchorPath $anchorFile -FixtureKeyPath $keyFile -FixtureWitnessPath $witnessFile -FixtureWitnessKeyPath $witnessKeyFile -Json | Out-String
        return ($output | ConvertFrom-Json)
    }
    function Witness-Failure([string]$Message) {
        $failed = $false
        try { $null = Inspect-WithWitness } catch { $failed = $true }
        Assert $failed $Message
    }
    function Make-Valid {
        $first = Make-Event 1 $zero 'planned'
        $firstHash = SHA ([Convert]::FromBase64String($first[0]))
        $second = Make-Event 2 $firstHash 'approved' 'Data/patch-Z.mpq' 'install'
        $secondHash = SHA ([Convert]::FromBase64String($second[0]))
        $bundle = @(
            2,
            @($first,$second)
        )
        return [pscustomobject]@{
            Envelope = $bundle
            Anchor = (Make-Anchor 2 $secondHash)
            FirstHash = $firstHash
        }
    }
    function Store-Valid {
        $v = Make-Valid
        Save-Json $envelopeFile $v.Envelope
        Save-Json $anchorFile $v.Anchor
        return $v
    }
    $valid = Store-Valid
    $before = Snap $fixture
    $raw = & $validator -EnvelopePath $envelopeFile -AnchorPath $anchorFile -FixtureKeyPath $keyFile -Json | Out-String
    $result = $raw | ConvertFrom-Json
    Assert ($result.status -eq 'fixture_chain_and_anchor_match') 'Valid two-event synthetic chain and anchor accepted'
    Assert ($result.event_count -eq 2) 'Inspector counts both signed events'
    Assert ($result.patchset -eq 'patchset-0001') 'Inspector validates signed patchset'
    Assert ($result.last_checkpoint -eq 'approved') 'Last synthetic state is reported'
    Assert (-not $raw.Contains($fixture)) 'Report does not expose absolute fixture file paths'
    Assert ((Snap $fixture) -ceq $before) 'Successful fixture validation makes no file changes'

    $v = Store-Valid
    $v.Envelope[1][1][1] = ('f' * 64)
    Save-Json $envelopeFile $v.Envelope
    Verify-ExpectedFailure 'Modified event signature is rejected'

    $v = Store-Valid
    $pair = $v.Envelope[1][0]
    $v.Envelope[1][0] = $v.Envelope[1][1]
    $v.Envelope[1][1] = $pair
    Save-Json $envelopeFile $v.Envelope
    Verify-ExpectedFailure 'Reordered journal events are rejected'

    $v = Store-Valid
    Save-Json $anchorFile (Make-Anchor 1 $v.FirstHash)
    Verify-ExpectedFailure 'Older anchor does not match the latest journal chain'

    $v = Store-Valid
    $v.Envelope[1][1] = Make-Event 2 $zero 'approved' 'Data/patch-Z.mpq' 'install'
    Save-Json $envelopeFile $v.Envelope
    $head = SHA ([Convert]::FromBase64String($v.Envelope[1][1][0]))
    Save-Json $anchorFile (Make-Anchor 2 $head)
    Verify-ExpectedFailure 'Re-signed broken predecessor hash is rejected'

    $v = Store-Valid
    $v.Envelope[1][1] = Make-Event 2 $v.FirstHash 'approved' '../WTF/Account' 'install'
    Save-Json $envelopeFile $v.Envelope
    $head = SHA ([Convert]::FromBase64String($v.Envelope[1][1][0]))
    Save-Json $anchorFile (Make-Anchor 2 $head)
    Verify-ExpectedFailure 'Even a correctly signed forbidden path is rejected'

    $v = Store-Valid
    $v.Envelope[1][1] = Make-Event 2 $v.FirstHash 'unknown_state' 'Data/patch-Z.mpq' 'install'
    Save-Json $envelopeFile $v.Envelope
    $head = SHA ([Convert]::FromBase64String($v.Envelope[1][1][0]))
    Save-Json $anchorFile (Make-Anchor 2 $head)
    Verify-ExpectedFailure 'Unsupported signed event state is rejected'

    $v = Store-Valid
    $v.Envelope[1][0] = @('not valid base64','f' * 64)
    Save-Json $envelopeFile $v.Envelope
    Verify-ExpectedFailure 'Malformed base64 payload is rejected'

    $v = Store-Valid
    $v.Envelope = @(2,@(@($v.Envelope[1][0][0],$v.Envelope[1][0][1])))
    Save-Json $envelopeFile $v.Envelope
    Verify-ExpectedFailure 'Incomplete chain rejected against latest anchor'

    $v = Store-Valid
    $v.Anchor[2] = 'another-install-99'
    Save-Json $anchorFile $v.Anchor
    Verify-ExpectedFailure 'Tampered anchor installation ID fails MAC validation'

    $v = Store-Valid
    $otherSecret = New-Object byte[] 32
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($otherSecret) } finally { $rng.Dispose() }
    [IO.File]::WriteAllBytes($keyFile,$otherSecret)
    Verify-ExpectedFailure 'Wrong external fixture key invalidates the entire chain'
    [IO.File]::WriteAllBytes($keyFile,$secret)

    $v = Store-Valid
    $v.Envelope[1][0] = @($v.Envelope[1][0][0],$v.Envelope[1][0][1],'extra')
    Save-Json $envelopeFile $v.Envelope
    Verify-ExpectedFailure 'Extra event array fields are rejected'

    # Independently keyed witness is a *separate synthetic fixture*. A
    # coordinated replay of old journal+matching anchor can otherwise pass.
    $v = Store-Valid
    Store-Witness $v.Anchor
    $witnessBaseline = Snap $fixture
    $withWitness = Inspect-WithWitness
    Assert ($withWitness.witness_status -eq 'matches_independent_fixture') 'Independent fixture witness matches latest chain'
    Assert ((Snap $fixture) -ceq $witnessBaseline) 'Witness inspection does not modify any input'

    $v = Store-Valid
    Store-Witness $v.Anchor
    # Preserve the exact [version, [[base64, mac]]] structure. PowerShell
    # array arguments can otherwise flatten this singleton event pair.
    $singleEventList = [Array]::CreateInstance([object],1)
    $singleEventList[0] = $v.Envelope[1][0]
    $olderEnvelope = [Array]::CreateInstance([object],2)
    $olderEnvelope[0] = 2
    $olderEnvelope[1] = $singleEventList
    Save-Json $envelopeFile $olderEnvelope
    Save-Json $anchorFile (Make-Anchor 1 $v.FirstHash)
    $unwitnessed = (& $validator -EnvelopePath $envelopeFile -AnchorPath $anchorFile -FixtureKeyPath $keyFile -Json | Out-String) | ConvertFrom-Json
    Assert ($unwitnessed.status -eq 'fixture_chain_and_anchor_match') 'Old chain plus matching old anchor can pass unpinned fixture checks'
    Assert ($unwitnessed.witness_status -eq 'not_supplied') 'Unwitnessed inspection explicitly reports absent external state'
    Witness-Failure 'Independent newer witness rejects coordinated replay of signed journal AND anchor'

    $v = Store-Valid
    Store-Witness (Make-Anchor 1 $v.FirstHash)
    Witness-Failure 'Older but valid witness is rejected when journal is newer'

    $v = Store-Valid
    Store-Witness $v.Anchor
    $wrongWitness = Make-Witness $v.Anchor
    $wrongWitness[4] = ('e' * 64)
    Save-Json $witnessFile $wrongWitness
    Witness-Failure 'Modified independent witness digest fails HMAC verification'

    $v = Store-Valid
    Store-Witness $v.Anchor
    $differentSession = Make-Witness $v.Anchor
    $differentSession[1] = 'another-session-11'
    $payload = 'NXW2|' + $differentSession[1] + '|' + $differentSession[2] + '|' +
        $differentSession[3] + '|' + $differentSession[4]
    $differentSession[5] = HMAC ([Text.Encoding]::ASCII.GetBytes($payload)) $witnessSecret
    Save-Json $witnessFile $differentSession
    Witness-Failure 'Validly signed independent witness for another session is rejected'

    $v = Store-Valid
    Store-Witness $v.Anchor
    $otherWitnessKey = New-Object byte[] 32
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($otherWitnessKey) } finally { $rng.Dispose() }
    [IO.File]::WriteAllBytes($witnessKeyFile,$otherWitnessKey)
    Witness-Failure 'Wrong independent witness key is rejected'
    [IO.File]::WriteAllBytes($witnessKeyFile,$witnessSecret)

    $v = Store-Valid
    Store-Witness $v.Anchor
    $witnessMissingKeyRejected = $false
    try {
        $null = & $validator -EnvelopePath $envelopeFile -AnchorPath $anchorFile -FixtureKeyPath $keyFile -FixtureWitnessPath $witnessFile -Json 2>&1 | Out-String
    } catch { $witnessMissingKeyRejected = $true }
    Assert $witnessMissingKeyRejected 'Witness must have its own independently supplied fixture key'

    $v = Store-Valid
    Store-Witness $v.Anchor
    $oldSnapshot = Snap $fixture
    $result = (& $validator -EnvelopePath $envelopeFile -AnchorPath $anchorFile -FixtureKeyPath $keyFile -Json | Out-String) | ConvertFrom-Json
    Assert ($result.status -eq 'fixture_chain_and_anchor_match') 'Valid fixture still accepted after negative tests'
    Assert ((Snap $fixture) -ceq $oldSnapshot) 'Successful inspector run never modifies its fixture files'
    Write-Host 'All synthetic signed-journal fixture tests passed.' -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $fixture) {
        Remove-Item -LiteralPath $fixture -Recurse -Force
    }
}
