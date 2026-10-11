#requires -Version 5.1
<#
Naxxramas Client Setup - READ ONLY synthetic approval snapshot comparison.
ALL file identities, hashes, consent and provenance are CALLER SUPPLIED.
NO installation approval is collected or authenticated by this tool.
NO client files, backups, keys or installer state are read or written.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$FixturePlanPath,
    [Parameter(Mandatory=$true)][string]$FixtureApprovalPath,
    [switch]$Json
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Read-ArrayFixture([string]$Path,[string]$Label,[bool]$MayBeMissing) {
    if (-not (Test-Path -LiteralPath $Path)) {
        if ($MayBeMissing) { return $null }
        throw "$Label must exist."
    }
    $cursor = [IO.Path]::GetFullPath($Path)
    while ($true) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw 'Linked/junction input path is not supported.'
            }
        }
        $parent = [IO.Directory]::GetParent($cursor)
        if ($null -eq $parent) { break }
        $cursor = $parent.FullName
    }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Label must be a regular file."
    }
    if ((Get-Item -LiteralPath $Path).Length -gt 16384) {
        throw "$Label exceeds the 16 KiB fixture limit."
    }
    $utf8 = New-Object Text.UTF8Encoding($false,$true)
    try {
        $raw = $utf8.GetString([IO.File]::ReadAllBytes($Path))
        Add-Type -AssemblyName System.Web.Extensions -ErrorAction Stop
        $parser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
        $data = $parser.DeserializeObject($raw)
        if (-not ($data -is [array])) { throw 'Expected a positional JSON array.' }
        return ,$data
    } catch {
        throw "$Label is not a valid positional JSON fixture."
    }
}
function Require-Id([object]$Item,[string]$Name) {
    if (-not ($Item -is [string]) -or $Item -cnotmatch '^[A-Za-z0-9_-]{8,80}$') {
        throw "Invalid $Name."
    }
}
function Require-Digest([object]$Item,[string]$Name) {
    if (-not ($Item -is [string]) -or $Item -cnotmatch '^[a-f0-9]{64}$') {
        throw "Invalid $Name."
    }
}
function Require-Version([object]$Item) {
    if (-not ($Item -is [int] -or $Item -is [long]) -or [int64]$Item -ne 1) {
        throw 'Unsupported schema version.'
    }
}
function Validate-Plan([object]$Plan) {
    # [1, installationId, folderId, backupFolderId, sourceFolderId,
    #  patchset, build, locale, [selectJ,selectU], [V,Z,J,U,realm], provenanceClaim]
    if (-not ($Plan -is [array]) -or $Plan.Count -ne 11) {
        throw 'Plan must contain exactly 11 positional fields.'
    }
    Require-Version $Plan[0]
    Require-Id $Plan[1] 'installation ID'
    Require-Digest $Plan[2] 'client directory fingerprint'
    Require-Digest $Plan[3] 'backup directory fingerprint'
    Require-Digest $Plan[4] 'local patch-source directory fingerprint'
    if (-not ($Plan[5] -is [string]) -or $Plan[5] -cnotmatch '^patchset-[0-9]{4}$') {
        throw 'Unrecognised patchset label.'
    }
    if (-not ($Plan[6] -is [int] -or $Plan[6] -is [long]) -or [int64]$Plan[6] -ne 12340) {
        throw 'Fixture expects WoW build 12340.'
    }
    if (-not ($Plan[7] -is [string]) -or $Plan[7] -cne 'enUS') {
        throw 'Fixture expects exact enUS locale.'
    }
    $options = $Plan[8]
    if (-not ($options -is [array]) -or $options.Count -ne 2 -or
        -not ($options[0] -is [bool]) -or -not ($options[1] -is [bool])) {
        throw 'Optional selections must contain exactly two JSON booleans.'
    }
    $paths = @('Data/patch-V.mpq','Data/patch-Z.mpq',
        'Data/Patch-J.mpq','Data/Patch-U.mpq','Data/enUS/realmlist.wtf')
    $ops = $Plan[9]
    if (-not ($ops -is [array]) -or $ops.Count -ne 5) {
        throw 'Five exact allowlisted operation records are required.'
    }
    for($i=0;$i -lt 5;$i++) {
        $op = $ops[$i]
        if (-not ($op -is [array]) -or $op.Count -ne 5) {
            throw 'Every operation must have five positional fields.'
        }
        if (-not ($op[0] -is [string]) -or $op[0] -cne $paths[$i]) {
            throw 'Operation path/order not in exact V/Z/J/U/realmlist allowlist.'
        }
        if (-not ($op[1] -is [string]) -or $op[1] -cnotin @(
            'install','replace_after_backup','no_change','not_selected')) {
            throw 'Invalid operation type.'
        }
        if (-not ($op[4] -is [bool])) { throw 'Backup requirement must be a JSON boolean.' }
        $action = [string]$op[1]
        if (($i -lt 2 -or $i -eq 4) -and $action -ceq 'not_selected') {
            throw 'V/Z and realmlist cannot be marked unselected.'
        }
        if ($i -eq 2 -or $i -eq 3) {
            $selected = [bool]$options[$i-2]
            if ($selected -eq ($action -ceq 'not_selected')) {
                throw 'Optional selection is inconsistent with its operation.'
            }
        }
        if ($action -ceq 'replace_after_backup') {
            Require-Digest $op[2] 'approved replacement source digest'
            Require-Digest $op[3] 'pre-existing destination digest'
            if (-not $op[4]) { throw 'Replacement must require verified original backup.' }
        } elseif ($action -ceq 'install') {
            Require-Digest $op[2] 'approved installation source digest'
            if ($op[3] -cne '-' -or $op[4]) {
                throw 'New file may not claim an original or backup requirement.'
            }
        } else {
            if ($op[2] -cne '-' -or $op[4]) {
                throw 'Unchanged/unselected file cannot have an installation source or backup action.'
            }
            if ($action -ceq 'no_change') {
                Require-Digest $op[3] 'already-present destination digest'
            } elseif ($op[3] -cne '-') {
                Require-Digest $op[3] 'preserved unselected existing digest'
            }
        }
    }
    if (-not ($Plan[10] -is [string]) -or $Plan[10] -cnotin @(
        'claimed_local_use_reviewed','unverified','redistribution_unapproved')) {
        throw 'Unsupported source provenance status.'
    }
}
function Get-PlanFixtureDigest([array]$Plan) {
    # Only already validated positional primitive/array schema reaches this function.
    # Canonical FOR THE SYNTHETIC POWERSHELL 5.1 FIXTURE ONLY.
    # Unlike the signed journal format, this digest is UNKEYED and UNTRUSTED.
    $compact = ConvertTo-Json -InputObject $Plan -Depth 16 -Compress
    $wire = 'NAXX-PLAN-FIXTURE-1:' + $compact
    $bytes = [Text.Encoding]::UTF8.GetBytes($wire)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-','').ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}
function Add-Change([System.Collections.Generic.List[string]]$List,[object]$Previous,
    [object]$Current,[string]$Reason) {
    if ($Previous -cne $Current) { $List.Add($Reason) }
}

$current = Read-ArrayFixture $FixturePlanPath 'Current plan' $false
Validate-Plan $current
$currentDigest = Get-PlanFixtureDigest $current
$approval = Read-ArrayFixture $FixtureApprovalPath 'Approval receipt' $true
$blocks = New-Object 'System.Collections.Generic.List[string]'
$match = $false
$approvalVersion = $null
$approvalDigestMatchesSnapshot = $null
$currentDigestMatchesReceipt = $null
if ($null -eq $approval) {
    $blocks.Add('approval_record_missing')
} else {
    # v1 [1, receiptId, consent, exactPlanSnapshot]
    # v2 [2, receiptId, consent, exactPlanSnapshot, declaredPlanDigest]
    # Both formats remain synthetic and completely caller-controlled.
    if (-not ($approval[0] -is [int] -or $approval[0] -is [long])) {
        throw 'Approval receipt has invalid schema version.'
    }
    $approvalVersion = [int64]$approval[0]
    if (($approvalVersion -eq 1 -and $approval.Count -ne 4) -or
        ($approvalVersion -eq 2 -and $approval.Count -ne 5) -or
        ($approvalVersion -ne 1 -and $approvalVersion -ne 2)) {
        throw 'Approval receipt has an unsupported schema or unexpected fields.'
    }
    Require-Id $approval[1] 'approval receipt ID'
    if (-not ($approval[2] -is [string]) -or $approval[2] -cnotin @(
        'explicit_confirmed','pending','revoked','expired')) {
        throw 'Unknown approval consent claim.'
    }
    Validate-Plan $approval[3]
    if ($approvalVersion -eq 2) {
        Require-Digest $approval[4] 'declared frozen plan digest'
        $snapshotDigest = Get-PlanFixtureDigest $approval[3]
        $approvalDigestMatchesSnapshot = ($snapshotDigest -ceq [string]$approval[4])
        $currentDigestMatchesReceipt = ($currentDigest -ceq [string]$approval[4])
        if (-not $approvalDigestMatchesSnapshot) {
            $blocks.Add('approval_snapshot_digest_invalid')
        }
        if (-not $currentDigestMatchesReceipt) {
            $blocks.Add('current_plan_digest_differs_from_approval')
        }
    }
    if ($approval[2] -cne 'explicit_confirmed') {
        $blocks.Add('approval_not_explicit_or_no_longer_current')
    }
    $a = $approval[3]
    $names = @('installation_identity_changed','client_directory_changed',
        'backup_directory_changed','patch_source_directory_changed',
        'patchset_changed','client_build_changed','locale_changed')
    for($i=1;$i -le 7;$i++) {
        Add-Change $blocks $a[$i] $current[$i] $names[$i-1]
    }
    for($i=0;$i -lt 2;$i++) {
        if ($a[8][$i] -cne $current[8][$i]) {
            $blocks.Add(@('optional_j_selection_changed','optional_u_selection_changed')[$i])
        }
    }
    $labels=@('core_v','core_z','optional_j','optional_u','realmlist')
    for($i=0;$i -lt 5;$i++) {
        $changed=$false
        for($k=0;$k -lt 5;$k++) {
            if ($a[9][$i][$k] -cne $current[9][$i][$k]) {
                $changed=$true
            }
        }
        if($changed){$blocks.Add('operation_changed_'+$labels[$i])}
    }
    Add-Change $blocks $a[10] $current[10] 'source_provenance_claim_changed'
}
if ($current[10] -cne 'claimed_local_use_reviewed') {
    $blocks.Add('patch_source_provenance_not_reviewed')
}
$match = ($null -ne $approval -and $blocks.Count -eq 0)
$state = if($match){'fixture_claims_match_NOT_authenticated'}else{'manual_review_approval_snapshot_mismatch'}
$report=[pscustomobject][ordered]@{
    kind='read_only_untrusted_approval_snapshot_fixture'
    schema_version=1
    status=$state
    blocker_count=$blocks.Count
    blockers=@($blocks.ToArray())
    approval_present=($null -ne $approval)
    approval_fixture_version=$approvalVersion
    approval_digest_matches_claimed_snapshot=$approvalDigestMatchesSnapshot
    current_plan_digest_matches_claimed_receipt=$currentDigestMatchesReceipt
    review_required=$true
    allow_file_writes=$false
    allow_automatic_resume=$false
    authorises_rollback=$false
    records_real_consent=$false
    public_distribution_authorised=$false
    limitations='Both v1 and v2 receipt data and plan digests are user-controlled. An unkeyed canonical JSON SHA-256 is not authenticated consent, unforgeable identity or anti-replay. No live bytes, ownership, patch rights or protected latest state verified. Never authorises installation.'
}
if($Json){$report | ConvertTo-Json -Depth 5}
else{
    Write-Host 'Naxxramas Client Setup - READ ONLY APPROVAL SNAPSHOT TEST' -ForegroundColor Cyan
    Write-Host ('Classification: {0}' -f $state)
    foreach($item in $blocks){Write-Host ('Review: {0}' -f $item)}
    Write-Host 'Never permits installation, rollback or redistribution.' -ForegroundColor Yellow
}
