#requires -Version 5.1
<#
Naxxramas Client Setup — PLAYER-READABLE READ-ONLY INSTALLATION REVIEW.
Connects the real local read-only installer planner to an accessible
file-by-file summary. This is NOT a consent dialog or an install engine.
No client, source, backup, game config, report or registry file is written.
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
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest

$paths=@('Data/patch-V.mpq','Data/patch-Z.mpq',
    'Data/Patch-J.mpq','Data/Patch-U.mpq','Data/enUS/realmlist.wtf')
$names=@('Required core patch V','Required core patch Z',
    'Optional Vanilla login screen (J)','Optional Vanilla loading screens (U)',
    'Realm address settings')
$actions=@{
    no_change='Keep existing file unchanged'
    leave_existing='Preserve existing file (not replacing it)'
    not_selected='Not selected; leave it alone'
    install='Would add a new file after separate approval'
    replace_after_backup='Would replace ONLY after an exact original backup and separate approval'
    blocked='Blocked: existing files must be preserved for review'
}
$planner=Join-Path $PSScriptRoot 'Plan-Naxxramas-Install.ps1'
$params=@{ClientPath=$ClientPath;Json=$true}
if($PatchSourcePath){$params.PatchSourcePath=$PatchSourcePath}
if($BackupRoot){$params.BackupRoot=$BackupRoot}
if($VanillaLogin){$params.VanillaLogin=$true}
if($VanillaLoading){$params.VanillaLoading=$true}
if($RealmHost){$params.RealmHost=$RealmHost}

$plan=(& $planner @params | Out-String) | ConvertFrom-Json
if($null -eq $plan -or
   [int]$plan.schema_version -ne 1 -or
   $plan.kind -cne 'read_only_preview_not_install_authorisation' -or
   $plan.client_target -cne 'WoW 3.3.5a build 12340 enUS' -or
   [string]$plan.patch_set_version -cnotmatch '^patchset-[A-Za-z0-9_-]{4,40}$' -or
   $plan.status -cnotin @('review_only_no_blockers','blocked') -or
   @($plan.files).Count -ne 5){
    throw 'The local planner returned an unsupported preview; no review can be shown.'
}
if($null -eq $plan.space_budget -or
    $plan.space_budget.mode -cnotin @('backup_not_selected','shared_volume','separate_volumes','unverified')){
    throw 'Unsupported planner backup budget.'
}
$rows=New-Object 'System.Collections.Generic.List[object]'
[long]$originalBytes=0
[int]$addCount=0
[int]$replaceCount=0
[int]$keepCount=0
[int]$blockedCount=0
for($i=0;$i -lt 5;$i++){
    $item=$plan.files[$i]
    $action=[string]$item.action
    if([string]$item.path -cne $paths[$i] -or
        -not $actions.ContainsKey($action) -or
        [bool]$item.backup_required -ne ($action -ceq 'replace_after_backup') -or
        [bool]$item.required -ne ($i -lt 2 -or $i -eq 4)){
        throw 'The planner file list or backup requirements have changed unexpectedly.'
    }
    if($i -lt 2 -and -not [bool]$item.selected){
        throw 'Mandatory core patches cannot be unselected.'
    }
    if($i -eq 2 -and [bool]$item.selected -ne [bool]$VanillaLogin){
        throw 'Vanilla login choice does not match the local preview.'
    }
    if($i -eq 3 -and [bool]$item.selected -ne [bool]$VanillaLoading){
        throw 'Vanilla loading choice does not match the local preview.'
    }
    if($i -eq 4 -and -not [bool]$item.selected){
        throw 'Realmlist choice unexpectedly absent.'
    }
    switch($action){
        install {$addCount++}
        replace_after_backup {
            if($null -eq $item.existing_size_bytes -or
                [long]$item.existing_size_bytes -lt 0){
                throw 'Missing original-file size in replacement preview.'
            }
            $replaceCount++
            $originalBytes+=[long]$item.existing_size_bytes
        }
        blocked {$blockedCount++}
        default {$keepCount++}
    }
    $rows.Add([pscustomobject][ordered]@{
        name=$names[$i]
        relative_path=$paths[$i]
        mandatory=[bool]$item.required
        selected=[bool]$item.selected
        current_state=[string]$item.destination_state
        proposed_action=$action
        player_explanation=$actions[$action]
        original_backup_required=($action -ceq 'replace_after_backup')
        original_backup_created=$false
    })
}
if([long]$plan.space_budget.client_volume_required_bytes -lt 0 -or
  [long]$plan.space_budget.backup_volume_required_bytes -lt 0){
    throw 'Invalid negative storage estimate.'
}
if($null -eq $plan.realm_host -or
    [string]$plan.realm_host -notmatch '^[A-Za-z0-9][A-Za-z0-9.-]*[A-Za-z0-9]$'){
    throw 'Unsupported realm address supplied by local planner.'
}
$concerns=New-Object 'System.Collections.Generic.List[string]'
foreach($reason in @($plan.blockers)){
    if(-not [string]::IsNullOrWhiteSpace([string]$reason)){
        $concerns.Add([string]$reason)
    }
}
if($blockedCount -gt 0 -and @($plan.blockers).Count -eq 0){
    $concerns.Add('One or more files cannot be safely planned; review their current versions.')
}
if(($addCount+$replaceCount) -gt 0 -and
   -not [bool]$plan.space_budget.backup_location_selected){
    $concerns.Add('No separate backup folder was selected. Select one before any future changes.')
}
if($plan.space_budget.mode -ceq 'unverified'){
    $concerns.Add('The backup storage identity could not be verified.')
}
if($plan.status -ceq 'blocked' -and $concerns.Count -eq 0){
    $concerns.Add('Local preflight reported a blocker; do not proceed.')
}
$notes=New-Object 'System.Collections.Generic.List[string]'
foreach($warning in @($plan.warnings)){
    if(-not [string]::IsNullOrWhiteSpace([string]$warning)){
        $notes.Add([string]$warning)
    }
}
$notes.Add('No original backups have been created or verified by this preview.')
$notes.Add('Existing client and optional patch files will not be modified by this preview.')
$notes.Add('Patch redistribution has not been approved; supply only legitimately owned local sources.')
$notes.Add('This preview does not record approval, consume a token or authorise installation or recovery.')

$blocked=($plan.status -cne 'review_only_no_blockers' -or $concerns.Count -gt 0)
$status=if($blocked){
    'read_only_player_review_BLOCKED_MANUAL_REVIEW'
}else{
    'read_only_player_review_NO_PREFLIGHT_BLOCKERS_NOT_APPROVED'
}
$report=[pscustomobject][ordered]@{
    kind='read_only_player_facing_installation_review'
    schema_version=1
    status=$status
    client_target=[string]$plan.client_target
    patch_set_version=[string]$plan.patch_set_version
    realm_address=[string]$plan.realm_host
    vanilla_login_selected=[bool]$plan.optional_selections.vanilla_login
    vanilla_loading_selected=[bool]$plan.optional_selections.vanilla_loading
    file_reviews=@($rows.ToArray())
    file_count=$rows.Count
    unchanged_or_unselected_count=$keepCount
    proposed_new_file_count=$addCount
    proposed_replace_after_backup_count=$replaceCount
    blocked_file_count=$blockedCount
    original_bytes_that_would_need_backup=$originalBytes
    separate_backup_folder_selected=[bool]$plan.space_budget.backup_location_selected
    storage_mode=[string]$plan.space_budget.mode
    estimated_client_staging_bytes=[long]$plan.space_budget.client_volume_required_bytes
    estimated_backup_storage_bytes=[long]$plan.space_budget.backup_volume_required_bytes
    concerns=@($concerns.ToArray())
    notes=@($notes.ToArray())
    review_required=$true
    read_only=$true
    client_files_modified=$false
    original_backups_created=$false
    file_writes_authorised=$false
    automatic_resume_authorised=$false
    rollback_authorised=$false
    genuine_user_consent_collected=$false
    public_patch_distribution_authorised=$false
    limitations='Summarises one existing read-only planner inspection, not an atomic snapshot. Files can change before/after inspection. No live ownership, authentic consent, protected one-use token, durable original backup, write engine, automatic recovery or distribution permission.'
}
if($Json){
    $report | ConvertTo-Json -Depth 6
}else{
    $lines=New-Object 'System.Collections.Generic.List[string]'
    $lines.Add('NAXXRAMAS CLIENT SETUP')
    $lines.Add('INSTALLATION REVIEW ONLY - NOTHING WILL BE CHANGED')
    $lines.Add('')
    $lines.Add(('Client: '+$report.client_target))
    $lines.Add(('Patch set: '+$report.patch_set_version))
    $lines.Add(('Realm address: '+$report.realm_address))
    $lines.Add(('Optional login screen J: '+$(if($report.vanilla_login_selected){'selected'}else{'not selected'})))
    $lines.Add(('Optional loading screens U: '+$(if($report.vanilla_loading_selected){'selected'}else{'not selected'})))
    $lines.Add('')
    $lines.Add('PROPOSED FILE ACTIONS')
    foreach($row in $rows){
        $lines.Add(('- '+$row.name))
        $lines.Add(('  '+$row.player_explanation))
        if($row.original_backup_required){
            $lines.Add('  Your existing original would need an exact verified backup first.')
        }
    }
    $lines.Add('')
    $lines.Add('BACKUP AND SPACE')
    $lines.Add(('Existing original files needing backup: '+$replaceCount))
    $lines.Add(('Total size of those originals: '+$originalBytes+' bytes'))
    $lines.Add(('Separate backup folder selected: '+$(if($report.separate_backup_folder_selected){'Yes'}else{'No'})))
    $lines.Add(('Estimated client staging: '+$report.estimated_client_staging_bytes+' bytes'))
    $lines.Add(('Estimated backup capacity: '+$report.estimated_backup_storage_bytes+' bytes'))
    $lines.Add('These are estimates, not storage reserved or copies already saved.')
    $lines.Add('')
    if($concerns.Count -gt 0){
        $lines.Add('ISSUES THAT NEED REVIEW')
        foreach($reason in $concerns){$lines.Add(('- '+$reason))}
        $lines.Add('')
    }
    $lines.Add('IMPORTANT NOTES')
    foreach($note in $notes){$lines.Add(('- '+$note))}
    $lines.Add('')
    $lines.Add(('Result: '+$report.status))
    $lines.Add('No action button or approval is provided. All changes remain disabled.')
    Write-Output ($lines -join [Environment]::NewLine)
}
