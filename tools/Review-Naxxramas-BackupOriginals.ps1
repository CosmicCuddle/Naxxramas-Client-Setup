#requires -Version 5.1
<#
Naxxramas Client Setup — READ ONLY original-backup readiness review.
Joins the real installer plan with same-open-handle observations of existing
client files and separately supplied local source patches. Never backs up,
writes, creates directories, issues consent or authorises a transaction.
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$ClientPath,
 [Parameter(Mandatory=$true)][string]$BackupRoot,
 [string]$PatchSourcePath,
 [switch]$VanillaLogin,[switch]$VanillaLoading,
 [string]$RealmHost,[switch]$Json
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
function Add-Reason([System.Collections.Generic.List[string]]$List,[string]$Reason) {
 if(-not $List.Contains($Reason)){$List.Add($Reason)}
}
function Observe-Files([string]$Root,[string]$Scope) {
 $inspector=Join-Path $PSScriptRoot 'Inspect-Naxxramas-OpenFileHandles.ps1'
 $report=(& $inspector -RootPath $Root -Scope $Scope -Json | Out-String) | ConvertFrom-Json
 if($report.kind -cne 'read_only_open_file_handle_inventory' -or
    [int]$report.schema_version -ne 1 -or $report.scope -cne $Scope.ToLowerInvariant() -or
    @($report.files).Count -ne $(if($Scope -ceq 'Client'){5}else{4})) {
  throw 'Unexpected read-only file handle inspector response.'
 }
 return $report
}
$names=@('Data/patch-V.mpq','Data/patch-Z.mpq',
         'Data/Patch-J.mpq','Data/Patch-U.mpq','Data/enUS/realmlist.wtf')
$params=@{ClientPath=$ClientPath;BackupRoot=$BackupRoot;Json=$true}
if($PatchSourcePath){$params.PatchSourcePath=$PatchSourcePath}
if($VanillaLogin){$params.VanillaLogin=$true}
if($VanillaLoading){$params.VanillaLoading=$true}
if($RealmHost){$params.RealmHost=$RealmHost}
$planScript=Join-Path $PSScriptRoot 'Plan-Naxxramas-Install.ps1'
$plan=(& $planScript @params | Out-String) | ConvertFrom-Json
if($plan.kind -cne 'read_only_preview_not_install_authorisation' -or
   [int]$plan.schema_version -ne 1 -or
   $plan.client_target -cne 'WoW 3.3.5a build 12340 enUS' -or
   @($plan.files).Count -ne 5 -or
   -not [bool]$plan.space_budget.backup_location_selected) {
 throw 'Unexpected or unsupported backup-enabled read-only planner response.'
}
$client=Observe-Files $ClientPath 'Client'
$source=$null
if($PatchSourcePath){$source=Observe-Files $PatchSourcePath 'Source'}
$blocks=New-Object 'System.Collections.Generic.List[string]'
$originals=New-Object 'System.Collections.Generic.List[object]'
$observations=New-Object 'System.Collections.Generic.List[object]'
if($plan.status -cne 'review_only_no_blockers'){
 Add-Reason $blocks 'existing_installer_preflight_blocked'
}
if([string]$plan.space_budget.mode -cin @('unverified','backup_not_selected')){
 Add-Reason $blocks 'backup_volume_identity_or_location_not_reviewable'
}
for($i=0;$i -lt 5;$i++){
 $p=$plan.files[$i]
 $observed=$client.files[$i]
 if($p.path -cne $names[$i] -or $observed.path -cne $names[$i]){
  throw 'Planner and open-handle inspector path allowlists diverged.'
 }
 $existing=($observed.state -ceq 'observed_untrusted')
 if($observed.state -cnotin @('observed_untrusted','missing')){
  throw 'Unexpected open-file inspector state.'
 }
 $plannerExisting=($null -ne $p.existing_sha256)
 if($existing -ne $plannerExisting) {
  Add-Reason $blocks ('existing_file_presence_changed_'+$i)
 } elseif($existing){
  if($observed.sha256 -cne [string]$p.existing_sha256 -or
     [int64]$observed.size_bytes -ne [int64]$p.existing_size_bytes){
   Add-Reason $blocks ('existing_file_changed_since_planner_'+$i)
  }
 }
 $action=[string]$p.action
 if($action -cnotin @('no_change','leave_existing','not_selected',
                     'install','replace_after_backup','blocked')){
  throw 'Unexpected file action in planner output.'
 }
 if($action -ceq 'blocked'){
  Add-Reason $blocks ('planned_action_blocked_'+$i)
 }
 if($action -ceq 'install' -and $existing){
  Add-Reason $blocks ('install_destination_no_longer_missing_'+$i)
 }
 if($action -ceq 'replace_after_backup'){
  if(-not $existing -or -not [bool]$p.backup_required){
   Add-Reason $blocks ('original_backup_requirement_not_observed_'+$i)
  }else{
   $originals.Add([pscustomobject][ordered]@{
    path=$names[$i]
    original_size_bytes=[int64]$observed.size_bytes
    original_sha256=[string]$observed.sha256
    original_file_object_fingerprint_sha256=[string]$observed.file_object_fingerprint_sha256
    backup_state='NOT_CREATED'
   })
  }
 }
 if($action -ceq 'no_change' -and -not $existing){
  Add-Reason $blocks ('unchanged_file_disappeared_'+$i)
 }
 if(($action -ceq 'install' -or $action -ceq 'replace_after_backup') -and $i -lt 4){
  if($null -eq $source){
   Add-Reason $blocks ('selected_patch_source_not_available_'+$i)
  }else{
   $patch=$source.files[$i]
   if($patch.path -cne $names[$i]){throw 'Source inventory path order changed.'}
   if($patch.state -cne 'observed_untrusted' -or
      $patch.sha256 -cne [string]$p.expected_sha256 -or
      [int64]$patch.size_bytes -ne [int64]$p.expected_size_bytes){
    Add-Reason $blocks ('selected_patch_source_not_verified_'+$i)
   }
  }
 }
 $observations.Add([pscustomobject][ordered]@{
  path=$names[$i]
  proposed_action=$action
  existing_file_present=$existing
  backup_required=($action -ceq 'replace_after_backup')
  original_observed_same_as_plan=$(
   $existing -eq $plannerExisting -and
   (-not $existing -or ($observed.sha256 -ceq [string]$p.existing_sha256 -and
   [int64]$observed.size_bytes -eq [int64]$p.existing_size_bytes))
  )
 })
}
# This is only the selection, capacity and logical-volume preflight from the
# existing planner. It does not create or verify any backup content.
[long]$originalBytes=0
foreach($item in $originals){$originalBytes+=[long]$item.original_size_bytes}
$status=if($blocks.Count -eq 0){
 'originals_identified_NOT_BACKED_UP_NOT_APPROVED'
}else{'manual_review_backup_readiness_blocked'}
$report=[pscustomobject][ordered]@{
 kind='read_only_original_backup_candidate_review'
 schema_version=1
 status=$status
 patchset=[string]$plan.patch_set_version
 current_preflight_status=[string]$plan.status
 source_directory_selected=[bool]$PatchSourcePath
 backup_location_checked_by_planner=$true
 backup_volume_mode=[string]$plan.space_budget.mode
 estimated_backup_volume_required_bytes=[long]$plan.space_budget.backup_volume_required_bytes
 originals_total_bytes=$originalBytes
 originals_count=$originals.Count
 originals_to_preserve=@($originals.ToArray())
 file_actions=@($observations.ToArray())
 blockers=@($blocks.ToArray())
 review_required=$true
 backup_created=$false
 originals_backed_up_and_verified=$false
 allow_file_writes=$false
 allow_automatic_resume=$false
 authorises_rollback=$false
 records_real_consent=$false
 public_distribution_authorised=$false
 limitations='Observations are sequential; file handles from scanner close before this report. Planner and scanner can race. Selected backup directory and estimated capacity do not prove a backup exists or is durable. No authenticated ownership, consent, source rights, signing, journaling or installer write permission.'
}
if($Json){$report|ConvertTo-Json -Depth 6}
else{
 Write-Host 'Naxxramas — READ ONLY ORIGINAL BACKUP CANDIDATES' -ForegroundColor Cyan
 foreach($item in $originals){Write-Host ('Preserve original: '+$item.path)}
 foreach($reason in $blocks){Write-Host ('REVIEW: '+$reason)}
 Write-Host ('Classification: '+$status)
 Write-Host 'NO BACKUPS CREATED; NO FILE WRITES; NOT APPROVED.' -ForegroundColor Yellow
}
