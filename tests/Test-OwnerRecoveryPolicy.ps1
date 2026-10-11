#requires -Version 5.1
# All fixtures are disposable JSON labels. No WoW files, accounts or keys.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
function Check([bool]$OK,[string]$Label){
    if(-not $OK){throw ('TEST FAILED: '+$Label)}
    Write-Host ('PASS: '+$Label) -ForegroundColor Green
}
function Baseline{
    return ,@(1,'synthetic-install-123','same_folder','same_user_claim',
      'available_claim','current_claim','matches_claim','explicit_claim',
      'same_claim','same_bytes_claim','inspect','online_claim','rights_claimed')
}
function Save([object]$Value){
    [IO.File]::WriteAllText($fixture,(ConvertTo-Json -InputObject $Value -Compress -Depth 8),
      (New-Object Text.UTF8Encoding($false)))
}
function Inspect {
    return ((& $inspector -FixturePath $fixture -Json | Out-String) | ConvertFrom-Json)
}
function Test-Outcome([object]$Policy,[string]$ExpectedStatus,
  [string[]]$ExpectedReasons,[string]$ExpectedNext,[string]$Label){
    Save $Policy
    $before=(Get-FileHash -LiteralPath $fixture -Algorithm SHA256).Hash
    $r=Inspect
    Check ($r.status -ceq $ExpectedStatus) ($Label+': status')
    foreach($reason in $ExpectedReasons){
        Check (@($r.blockers) -ccontains $reason) ('Blocker: '+$reason)
    }
    if($ExpectedNext){
        Check ($r.recommended_manual_next_step -ceq $ExpectedNext) ('Manual next step: '+$ExpectedNext)
    }
    Check ($r.blocker_count -eq @($r.blockers).Count) 'Blocker count is consistent'
    Check ($r.review_required -and $r.preserve_client_files -and $r.preserve_original_backups -and
      -not $r.allow_client_writes -and -not $r.allow_backup_writes -and
      -not $r.allow_automatic_resume -and -not $r.allow_automatic_rollback -and
      -not $r.allow_silent_reregistration -and -not $r.allow_silent_rekey -and
      -not $r.actual_windows_user_authenticated -and -not $r.actual_key_verified -and
      -not $r.independent_latest_state_verified -and -not $r.records_real_consent -and
      -not $r.public_patch_distribution_authorised) 'Policy never permits destructive or registration actions'
    Check ((Get-FileHash -LiteralPath $fixture -Algorithm SHA256).Hash -ceq $before) 'Inspector never changes fixture bytes'
    return $r
}
function Must-Throw([object]$Value,[string]$Label){
    Save $Value
    $threw=$false;try{$null=Inspect}catch{$threw=$true}
    Check $threw $Label
}
$root=Join-Path ([IO.Path]::GetTempPath()) ('NaxxOwnerRecovery-'+[guid]::NewGuid().ToString('N'))
$fixture=Join-Path $root 'policy.json'
$inspector=Join-Path (Split-Path -Parent $PSScriptRoot) 'tools/Review-Naxxramas-OwnerRecoveryPolicy.ps1'
$blocked='manual_review_owner_recovery_policy_blocked'
$good='fixture_claims_consistent_NOT_AUTHENTICATED'
try{
    $null=New-Item -ItemType Directory -Path $root
    $r=Test-Outcome (Baseline) $good @() 'read_only_inspection_only' 'All synthetic labels internally match, still untrusted'
    Check ($r.blocker_count -eq 0 -and -not $r.independent_latest_state_verified) 'Claimed online trust is never real authenticated trust'

    $v=Baseline;$v[2]='copied'
    $null=Test-Outcome $v $blocked @('installation_folder_requires_independent_identity_review','copy_or_migration_cannot_inherit_prior_install_approval') 'preserve_both_copies_and_review_owner_migration' 'Copied client cannot inherit old approval'
    $v=Baseline;$v[2]='migrated';$v[10]='migrate'
    $null=Test-Outcome $v $blocked @('manual_client_migration_registration_required','copy_or_migration_cannot_inherit_prior_install_approval') 'preserve_both_copies_and_review_owner_migration' 'Moving computers requires reviewed migration'
    $v=Baseline;$v[2]='unknown'
    $null=Test-Outcome $v $blocked @('installation_folder_requires_independent_identity_review') '' 'Unknown folder identity'
    $v=Baseline;$v[3]='different_user'
    $null=Test-Outcome $v $blocked @('windows_user_identity_not_continuous') '' 'Different Windows account'
    $v=Baseline;$v[3]='unknown_user'
    $null=Test-Outcome $v $blocked @('windows_user_identity_not_continuous') '' 'Unknown Windows account'

    foreach($key in @('missing','undecryptable','foreign_user')){
        $v=Baseline;$v[4]=$key
        $null=Test-Outcome $v $blocked @('signing_credential_unavailable_or_changed','lost_credential_must_not_trigger_silent_rekey') 'preserve_registration_and_request_manual_credential_recovery' ('Key unavailable: '+$key)
    }
    $v=Baseline;$v[4]='rotated'
    $null=Test-Outcome $v $blocked @('key_rotation_requires_verifiable_signed_continuity') 'preserve_registration_and_request_manual_credential_recovery' 'Key rotation cannot be silently adopted'
    $v=Baseline;$v[10]='recover_key'
    $null=Test-Outcome $v $blocked @('silent_key_recovery_forbidden','requested_operation_needs_separate_genuine_owner_approval') 'preserve_registration_and_request_manual_credential_recovery' 'Key recovery request is not a grant'
    $v=Baseline;$v[10]='reregister'
    $null=Test-Outcome $v $blocked @('silent_reregistration_forbidden') '' 'Reregistration never happens silently'

    $v=Baseline;$v[11]='offline';$v[5]='offline'
    $null=Test-Outcome $v $blocked @('offline_cannot_confirm_independent_latest_state') 'defer_mutations_until_separate_latest_state_review_available' 'Offline mode preserves files'
    $v=Baseline;$v[11]='offline';$v[5]='current_claim'
    $null=Test-Outcome $v $blocked @('claimed_online_freshness_while_offline') 'defer_mutations_until_separate_latest_state_review_available' 'No invented freshness when offline'
    foreach($state in @('timeout','missing','conflict')){
        $v=Baseline;$v[5]=$state
        $expected=@('independent_latest_state_not_currently_available')
        if($state -ceq 'conflict'){$expected+=@('conflicting_or_replayed_latest_state_claim')}
        $null=Test-Outcome $v $blocked $expected 'defer_mutations_until_separate_latest_state_review_available' ('Unavailable or conflicting authority: '+$state)
    }
    foreach($state in @('stale','ahead','missing','divergent')){
        $v=Baseline;$v[6]=$state
        $expected=@('journal_sequence_requires_manual_reconciliation')
        if($state -cin @('stale','divergent')){$expected+=@('possible_history_rollback_or_conflict')}
        $null=Test-Outcome $v $blocked $expected 'preserve_all_versions_and_reconcile_journal_history' ('Journal history state: '+$state)
    }
    foreach($consent in @('pending','expired','missing','revoked')){
        $v=Baseline;$v[7]=$consent
        $expected=@('fresh_explicit_consent_claim_missing')
        if($consent -ceq 'revoked'){$expected+=@('previous_consent_revoked')}
        $null=Test-Outcome $v $blocked $expected '' ('Consent: '+$consent)
    }
    foreach($state in @('changed','unknown')){
        $v=Baseline;$v[8]=$state
        $null=Test-Outcome $v $blocked @('approved_plan_not_currently_bound') '' ('Plan: '+$state)
    }
    foreach($state in @('missing','mismatched','unverified')){
        $v=Baseline;$v[9]=$state
        $null=Test-Outcome $v $blocked @('original_backup_not_even_claimed_matching') '' ('Backup: '+$state)
    }
    foreach($op in @('install','resume','restore')){
        $v=Baseline;$v[10]=$op
        $expected=@('requested_operation_needs_separate_genuine_owner_approval')
        if($op -ceq 'resume'){$expected+=@('automatic_transaction_resume_forbidden')}
        if($op -ceq 'restore'){$expected+=@('automatic_rollback_and_player_file_overwrite_forbidden')}
        $null=Test-Outcome $v $blocked $expected '' ('Request for '+$op+' does not make it permissible')
    }
    $v=Baseline;$v[12]='rights_unverified'
    $null=Test-Outcome $v $blocked @('custom_patch_source_rights_not_demonstrated') '' 'Custom MPQ rights are not established'

    $v=Baseline;$v[2]='migrated';$v[3]='different_user';$v[4]='foreign_user'
    $v[5]='offline';$v[6]='stale';$v[7]='revoked';$v[9]='mismatched'
    $v[10]='restore';$v[11]='offline';$v[12]='rights_unverified'
    $null=Test-Outcome $v $blocked @('copy_or_migration_cannot_inherit_prior_install_approval','lost_credential_must_not_trigger_silent_rekey','offline_cannot_confirm_independent_latest_state','possible_history_rollback_or_conflict','previous_consent_revoked','original_backup_not_even_claimed_matching','automatic_rollback_and_player_file_overwrite_forbidden') 'preserve_both_copies_and_review_owner_migration' 'Multiple concurrent recovery failures remain blocked'

    # A coherent replay of every caller-controlled local label remains invisible.
    $historic=Baseline;$historic[1]='old-fixture-install-123'
    $r=Test-Outcome $historic $good @() 'read_only_inspection_only' 'Whole historical snapshot can still appear internally consistent'
    Check (-not $r.actual_windows_user_authenticated) 'Coherent replay never becomes real identity'

    $v=Baseline;$v[0]=2;Must-Throw $v 'Unknown policy fixture version rejected'
    $v=Baseline;$v[0]='1';Must-Throw $v 'Version string rejected'
    $v=Baseline;$v[1]='a';Must-Throw $v 'Malformed ID rejected'
    $v=Baseline;$v[2]='MIGRATED';Must-Throw $v 'Case-altered enum rejected'
    $v=Baseline;$v[5]='verified_online';Must-Throw $v 'Unsupported cryptographic claim rejected'
    $v=Baseline;$v[10]='delete_client';Must-Throw $v 'Unallowlisted operation rejected'
    $v=Baseline;$v[12]='licensed_public';Must-Throw $v 'Unproven public distribution claim rejected'
    $v=Baseline;$v[13]='extra';Must-Throw $v 'Extra schema field rejected'
    $v=Baseline;$v[12]=$null;Must-Throw $v 'Null field rejected'
    [IO.File]::WriteAllText($fixture,'{"consent":"good","consent":"bad"}')
    $failed=$false;try{$null=Inspect}catch{$failed=$true}
    Check $failed 'Object input and duplicate JSON keys rejected'
    [IO.File]::WriteAllText($fixture,('x'*4097))
    $failed=$false;try{$null=Inspect}catch{$failed=$true}
    Check $failed 'Oversize policy rejected'
    Remove-Item -LiteralPath $fixture -Force
    $failed=$false;try{$null=Inspect}catch{$failed=$true}
    Check $failed 'Missing policy not silently created'

    Save (Baseline)
    $raw=(& $inspector -FixturePath $fixture -Json | Out-String)
    Check (-not $raw.Contains($root)) 'No local fixture directory disclosed'
    Check (-not $raw.Contains('synthetic-install-123')) 'No installation identifier disclosed'
    Check (-not (Test-Path -LiteralPath (Join-Path $root 'new-registration'))) 'No registration or key material created'
    Write-Host 'All offline/migration/owner recovery policy fixtures passed.' -ForegroundColor Green
}finally{
    if(Test-Path -LiteralPath $root){Remove-Item -LiteralPath $root -Recurse -Force}
}
