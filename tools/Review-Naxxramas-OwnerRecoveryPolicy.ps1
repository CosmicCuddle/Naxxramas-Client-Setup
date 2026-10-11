#requires -Version 5.1
<#
Naxxramas Client Setup — READ ONLY OFFLINE / MIGRATION / KEY RECOVERY POLICY.
ALL fields are caller-authored fixture labels, not live Windows or network
observations. NO DPAPI, credentials, accounts, time, keys, session, client,
backups, registration, token issuance, file changes or online requests.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$FixturePath,
    [switch]$Json
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest

function Read-PolicyFixture([string]$Path) {
    if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){
        throw 'Existing synthetic policy fixture required.'
    }
    $cursor=[IO.Path]::GetFullPath($Path)
    while($true){
        if(Test-Path -LiteralPath $cursor){
            $item=Get-Item -LiteralPath $cursor -Force
            if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){
                throw 'Linked fixture or reparse ancestor is forbidden.'
            }
        }
        $parent=[IO.Directory]::GetParent($cursor)
        if($null -eq $parent){break}
        $cursor=$parent.FullName
    }
    $bytes=[IO.File]::ReadAllBytes($Path)
    if($bytes.Length -gt 4096){throw 'Synthetic fixture exceeds 4 KiB.'}
    try{
        $utf8=New-Object Text.UTF8Encoding($false,$true)
        $data=$utf8.GetString($bytes)
        Add-Type -AssemblyName System.Web.Extensions -ErrorAction Stop
        $parser=New-Object System.Web.Script.Serialization.JavaScriptSerializer
        $fixture=$parser.DeserializeObject($data)
        if(-not ($fixture -is [array]) -or $fixture.Count -ne 13){
            throw 'Expected 13-element array.'
        }
        return ,$fixture
    }catch{
        throw 'Malformed or unsupported synthetic policy JSON.'
    }
}
function Enum([object]$Value,[string[]]$Options,[string]$Name){
    if(-not ($Value -is [string]) -or $Options -cnotcontains $Value){
        throw "Unsupported $Name label."
    }
}
function Block([System.Collections.Generic.List[string]]$List,[string]$Reason){
    if(-not $List.Contains($Reason)){$List.Add($Reason)}
}

# Synthetic v1 EXACTLY:
# [1, install_id, folder, user, key, authority, sequence, consent,
#  plan, backups, request, network, source_rights]
$f=Read-PolicyFixture $FixturePath
if(-not ($f[0] -is [int] -or $f[0] -is [long]) -or [int64]$f[0] -ne 1){
    throw 'Unknown policy fixture version.'
}
if(-not ($f[1] -is [string]) -or $f[1] -cnotmatch '^[A-Za-z0-9_-]{8,80}$'){
    throw 'Invalid installation fixture identifier.'
}
Enum $f[2] @('same_folder','copied','migrated','unknown') 'folder relation'
Enum $f[3] @('same_user_claim','different_user','unknown_user') 'Windows user'
Enum $f[4] @('available_claim','missing','undecryptable','foreign_user','rotated') 'credential state'
Enum $f[5] @('current_claim','offline','timeout','missing','conflict') 'authority status'
Enum $f[6] @('matches_claim','stale','ahead','missing','divergent') 'sequence comparison'
Enum $f[7] @('explicit_claim','pending','revoked','expired','missing') 'consent'
Enum $f[8] @('same_claim','changed','unknown') 'plan state'
Enum $f[9] @('same_bytes_claim','missing','mismatched','unverified') 'backup state'
Enum $f[10] @('inspect','install','resume','restore','reregister','migrate','recover_key') 'requested action'
Enum $f[11] @('online_claim','offline') 'network status'
Enum $f[12] @('rights_claimed','rights_unverified') 'source rights'

$reasons=New-Object 'System.Collections.Generic.List[string]'
if($f[2] -cne 'same_folder'){Block $reasons 'installation_folder_requires_independent_identity_review'}
if($f[2] -cin @('copied','migrated')){Block $reasons 'copy_or_migration_cannot_inherit_prior_install_approval'}
if($f[3] -cne 'same_user_claim'){Block $reasons 'windows_user_identity_not_continuous'}
if($f[4] -cne 'available_claim'){Block $reasons 'signing_credential_unavailable_or_changed'}
if($f[4] -cin @('missing','undecryptable','foreign_user')){
    Block $reasons 'lost_credential_must_not_trigger_silent_rekey'
}
if($f[4] -ceq 'rotated'){Block $reasons 'key_rotation_requires_verifiable_signed_continuity'}
if($f[11] -ceq 'offline'){
    Block $reasons 'offline_cannot_confirm_independent_latest_state'
    if($f[5] -ceq 'current_claim'){Block $reasons 'claimed_online_freshness_while_offline'}
}elseif($f[5] -cne 'current_claim'){
    Block $reasons 'independent_latest_state_not_currently_available'
}
if($f[5] -ceq 'conflict'){Block $reasons 'conflicting_or_replayed_latest_state_claim'}
if($f[6] -cne 'matches_claim'){Block $reasons 'journal_sequence_requires_manual_reconciliation'}
if($f[6] -cin @('stale','divergent')){
    Block $reasons 'possible_history_rollback_or_conflict'
}
if($f[7] -cne 'explicit_claim'){Block $reasons 'fresh_explicit_consent_claim_missing'}
if($f[7] -ceq 'revoked'){Block $reasons 'previous_consent_revoked'}
if($f[8] -cne 'same_claim'){Block $reasons 'approved_plan_not_currently_bound'}
if($f[9] -cne 'same_bytes_claim'){Block $reasons 'original_backup_not_even_claimed_matching'}
if($f[12] -ceq 'rights_unverified'){Block $reasons 'custom_patch_source_rights_not_demonstrated'}
if($f[10] -cne 'inspect'){
    Block $reasons 'requested_operation_needs_separate_genuine_owner_approval'
}
if($f[10] -ceq 'reregister'){Block $reasons 'silent_reregistration_forbidden'}
if($f[10] -ceq 'restore'){Block $reasons 'automatic_rollback_and_player_file_overwrite_forbidden'}
if($f[10] -ceq 'resume'){Block $reasons 'automatic_transaction_resume_forbidden'}
if($f[10] -ceq 'recover_key'){Block $reasons 'silent_key_recovery_forbidden'}
if($f[10] -ceq 'migrate'){Block $reasons 'manual_client_migration_registration_required'}

# The labels above are user-controlled. They do not become trusted when
# internally consistent, even if a caller claims online current authority.
$next='fresh_manual_owner_and_plan_review'
if($f[2] -cin @('copied','migrated') -or $f[10] -ceq 'migrate'){
    $next='preserve_both_copies_and_review_owner_migration'
}elseif($f[4] -cne 'available_claim' -or $f[10] -ceq 'recover_key'){
    $next='preserve_registration_and_request_manual_credential_recovery'
}elseif($f[11] -ceq 'offline' -or $f[5] -cne 'current_claim'){
    $next='defer_mutations_until_separate_latest_state_review_available'
}elseif($f[6] -cne 'matches_claim'){
    $next='preserve_all_versions_and_reconcile_journal_history'
}elseif($f[10] -ceq 'inspect' -and $reasons.Count -eq 0){
    $next='read_only_inspection_only'
}
$status=if($reasons.Count -eq 0){
    'fixture_claims_consistent_NOT_AUTHENTICATED'
}else{
    'manual_review_owner_recovery_policy_blocked'
}
$report=[pscustomobject][ordered]@{
    kind='read_only_untrusted_offline_migration_recovery_policy'
    schema_version=1
    status=$status
    blockers=@($reasons.ToArray())
    blocker_count=$reasons.Count
    recommended_manual_next_step=$next
    review_required=$true
    preserve_client_files=$true
    preserve_original_backups=$true
    allow_client_writes=$false
    allow_backup_writes=$false
    allow_automatic_resume=$false
    allow_automatic_rollback=$false
    allow_silent_reregistration=$false
    allow_silent_rekey=$false
    actual_windows_user_authenticated=$false
    actual_key_verified=$false
    independent_latest_state_verified=$false
    records_real_consent=$false
    public_patch_distribution_authorised=$false
    limitations='All fields, online/offline status, sequence, backup, rights, Windows-user and key labels are caller-controlled. No live user login, Windows key, DPAPI, independent service or trusted clock exists. Complete coherent historical replay can appear valid. No operation is authorised by any outcome.'
}
if($Json){$report|ConvertTo-Json -Depth 4}
else{
    Write-Host ('Owner recovery policy review: '+$status)
    foreach($reason in $reasons){Write-Host ('Manual review: '+$reason)}
    Write-Host ('Suggested manual workflow: '+$next)
    Write-Host 'READ ONLY: No registration, rekey, install, resume or restore.' -ForegroundColor Yellow
}
