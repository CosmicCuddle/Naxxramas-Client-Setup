#requires -Version 5.1
<#
Naxxramas Client Setup — READ ONLY recovery conflict safeguard.
Two recovery reviews + read-only held file-handle observations.
All decisions are *human-review classifications*, NEVER write authority.
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$ClientPath,
 [Parameter(Mandatory=$true)][string]$SessionDirectory,
 [switch]$Json
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$allowed=@('Data/patch-V.mpq','Data/patch-Z.mpq','Data/Patch-J.mpq',
           'Data/Patch-U.mpq','Data/enUS/realmlist.wtf')
function Read-SafeSession([string]$File) {
 if(-not (Test-Path -LiteralPath $File -PathType Leaf)){throw 'Recovery manifest absent.'}
 $cursor=[IO.Path]::GetFullPath($File)
 while($true){
  if(Test-Path -LiteralPath $cursor){
   if(((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){
    throw 'Recovery manifest is a link or has a linked ancestor.'
   }
  }
  $parent=[IO.Directory]::GetParent($cursor)
  if($null -eq $parent){break}
  $cursor=$parent.FullName
 }
 $bytes=[IO.File]::ReadAllBytes($File)
 if($bytes.Length -gt 1048576){throw 'Recovery manifest too large.'}
 $hashTool=[Security.Cryptography.SHA256]::Create()
 try{$fingerprint=[BitConverter]::ToString($hashTool.ComputeHash($bytes)).Replace('-','').ToLowerInvariant()}
 finally{$hashTool.Dispose()}
 try{
  $utf8=New-Object Text.UTF8Encoding($false,$true)
  $raw=$utf8.GetString($bytes)
  $manifest=$raw|ConvertFrom-Json
 }catch{throw 'Invalid recovery session manifest.'}
 return [pscustomobject]@{manifest=$manifest;digest=$fingerprint}
}
$manifestFile=Join-Path $SessionDirectory 'session.json'
$before=Read-SafeSession $manifestFile
$legacy=Join-Path $PSScriptRoot 'Review-Naxxramas-Recovery.ps1'
$scanner=Join-Path $PSScriptRoot 'Inspect-Naxxramas-OpenFileHandles.ps1'
$params=@{ClientPath=$ClientPath;SessionDirectory=$SessionDirectory;Json=$true}
$first=(& $legacy @params | Out-String)|ConvertFrom-Json
if($first.kind -cne 'read_only_recovery_preview_not_restore_authorisation' -or
   [int]$first.schema_version -ne 1){throw 'Unexpected recovery preview schema.'}
$inventory=(& $scanner -RootPath $ClientPath -Scope Client -Json | Out-String)|ConvertFrom-Json
if($inventory.kind -cne 'read_only_open_file_handle_inventory' -or
   @($inventory.files).Count -ne 5){throw 'Unexpected held-handle inventory response.'}
$second=(& $legacy @params | Out-String)|ConvertFrom-Json
$after=Read-SafeSession $manifestFile
if($second.kind -cne $first.kind -or [int]$second.schema_version -ne 1){
 throw 'Recovery preview schema changed between inspections.'
}
$blocks=New-Object 'System.Collections.Generic.List[string]'
if($before.digest -cne $after.digest){$blocks.Add('session_record_changed_during_review')}
if($first.status -cne $second.status -or
   @($first.operations).Count -ne @($second.operations).Count){
 $blocks.Add('recovery_preview_changed_during_review')
}
$opLines1=@($first.operations|ForEach-Object{
 @([string]$_.relative_path,[string]$_.current_state,[string]$_.backup_state,
   [string]$_.proposed_recovery,[string]$_.checkpoint_state) -join '/'
}) -join '|'
$opLines2=@($second.operations|ForEach-Object{
 @([string]$_.relative_path,[string]$_.current_state,[string]$_.backup_state,
   [string]$_.proposed_recovery,[string]$_.checkpoint_state) -join '/'
}) -join '|'
if($opLines1 -cne $opLines2 -and
   -not $blocks.Contains('recovery_preview_changed_during_review')){
 $blocks.Add('recovery_preview_changed_during_review')
}
$manifestOps=@($after.manifest.operations)
if($manifestOps.Count -ne @($second.operations).Count){
 throw 'Recovery manifest operation count differs from preview.'
}
$rows=New-Object 'System.Collections.Generic.List[object]'
for($i=0;$i -lt @($second.operations).Count;$i++){
 $row=$second.operations[$i]
 $claim=$manifestOps[$i]
 $path=[string]$row.relative_path
 $idx=[Array]::IndexOf($allowed,$path)
 if($idx -lt 0 -or [string]$claim.relative_path -cne $path){
  throw 'Recovery manifest operation allowlist or order differs from preview.'
 }
 $obs=$inventory.files[$idx]
 if($obs.path -cne $path){throw 'Inventory path order changed.'}
 $present=($obs.state -ceq 'observed_untrusted')
 if($obs.state -cnotin @('observed_untrusted','missing')){
  throw 'Unrecognized open-handle observation.'
 }
 $currentState='missing'
 if($present){
  $size=[int64]$obs.size_bytes
  if($obs.sha256 -ceq [string]$claim.installed_sha256 -and
      $size -eq [int64]$claim.installed_size_bytes){
   $currentState='installed_signature'
  }elseif([bool]$claim.was_present -and
     $obs.sha256 -ceq [string]$claim.before_sha256 -and
     $size -eq [int64]$claim.before_size_bytes){
   $currentState='original_signature'
  }else{$currentState='unknown_changed_signature'}
 }
 $stable=($currentState -ceq [string]$row.current_state)
 if(-not $stable){$blocks.Add('client_file_changed_during_review_'+$idx)}
 $prior=[string]$row.proposed_recovery
 $reviewState=switch($prior){
  'already_original' {'preserve_original_no_action'}
  'already_absent' {'preserve_absence_no_action'}
  'conflict_preserve_current' {'preserve_player_changed_file_manual_review'}
  'blocked_backup_unavailable' {'preserve_file_missing_or_wrong_backup'}
  'blocked_incomplete_journal' {'preserve_file_incomplete_record'}
  'restore_after_approval' {'potential_restore_requires_independent_approval'}
  'remove_after_approval' {'potential_removal_requires_independent_approval'}
  default {throw 'Unexpected recovery preview classification.'}
 }
 if(-not $stable){$reviewState='preserve_file_changed_during_review'}
 if($prior -cin @('restore_after_approval','remove_after_approval')){
  if(-not $blocks.Contains('authentic_single_use_consent_and_journal_missing')){
   $blocks.Add('authentic_single_use_consent_and_journal_missing')
  }
 }
 if($reviewState -cnotin @('preserve_original_no_action','preserve_absence_no_action')){
  if(-not $blocks.Contains('manual_non_destructive_recovery_review_required')){
   $blocks.Add('manual_non_destructive_recovery_review_required')
  }
 }
 $rows.Add([pscustomobject][ordered]@{
  path=$path
  current_held_handle_state=$currentState
  consistent_with_recovery_preview=$stable
  legacy_preview_suggestion=$prior
  review_classification=$reviewState
  preserve_current_data=$true
  installation_or_rollback_authorised=$false
 })
}
$status=if($blocks.Count -eq 0){
 'existing_file_states_need_no_change_NOT_AUTHENTICATED'
}else{
 'manual_preservation_or_independent_recovery_review'
}
$report=[pscustomobject][ordered]@{
 kind='read_only_recovery_conflict_safeguard'
 schema_version=1
 status=$status
 inspection_passes=2
 checked_files=$rows.Count
 files=@($rows.ToArray())
 blockers=@($blocks.ToArray())
 review_required=$true
 preserve_player_changes=$true
 allow_file_writes=$false
 allow_automatic_resume=$false
 authorises_rollback=$false
 authorises_file_deletion=$false
 records_real_consent=$false
 protected_journal_authority_verified=$false
 public_distribution_authorised=$false
 limitations='Session/installed/before hashes are user-controlled and not authenticated. Two legacy reads and held-file observations are not atomic, could miss A-B-A and post-check edits. Backup provenance, signing, independent latest state, owner consent, durable originals, write safety and actual restore are not implemented.'
}
if($Json){$report|ConvertTo-Json -Depth 5}
else{
 Write-Host ('Read-only recovery safety: '+$status)
 foreach($entry in $rows){Write-Host ($entry.path+': '+$entry.review_classification)}
 Write-Host 'All current files are preserved; no recovery action is approved.' -ForegroundColor Yellow
}
