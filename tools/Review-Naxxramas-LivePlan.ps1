#requires -Version 5.1
# READ ONLY: real Windows planner and directory observations, never authorisation.
[CmdletBinding(DefaultParameterSetName='Compare')]
param(
 [Parameter(Mandatory=$true)][string]$ClientPath,
 [string]$PatchSourcePath,[string]$BackupRoot,
 [switch]$VanillaLogin,[switch]$VanillaLoading,[string]$RealmHost,
 [Parameter(Mandatory=$true,ParameterSetName='Capture')][switch]$Snapshot,
 [Parameter(Mandatory=$true,ParameterSetName='Compare')][string]$BaselineSnapshotPath,
 [Parameter(ParameterSetName='Compare')][switch]$Json
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
function ShaText([string]$Text){
 $sha=[Security.Cryptography.SHA256]::Create()
 try{return [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))).Replace('-','').ToLowerInvariant()}
 finally{$sha.Dispose()}
}
function FolderId([string]$Path){
 if(-not $Path){return 'none'}
 $script=Join-Path $PSScriptRoot 'Inspect-Naxxramas-DirectoryIdentity.ps1'
 $data=(& $script -ClientPath $Path -Json | Out-String) | ConvertFrom-Json
 if($data.status -cne 'observed_not_authenticated' -or $data.client_fingerprint_sha256 -cnotmatch '^[a-f0-9]{64}$'){
   throw 'Windows directory identity inspection failed.'
 }
 return [string]$data.client_fingerprint_sha256
}
function Read-Snapshot([string]$Path){
 if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){throw 'Snapshot must be an existing regular file.'}
 $cursor=[IO.Path]::GetFullPath($Path)
 while($true){
   if(Test-Path -LiteralPath $cursor){
     if(((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){
       throw 'Reparse-point/junction snapshot input is not allowed.'
     }
   }
   $parent=[IO.Directory]::GetParent($cursor)
   if($null -eq $parent){break}
   $cursor=$parent.FullName
 }
 if((Get-Item -LiteralPath $Path).Length -gt 2048){throw 'Snapshot file is too large.'}
 try{
   Add-Type -AssemblyName System.Web.Extensions -ErrorAction Stop
   $utf8=New-Object Text.UTF8Encoding($false,$true)
   $parser=New-Object System.Web.Script.Serialization.JavaScriptSerializer
   $value=$parser.DeserializeObject($utf8.GetString([IO.File]::ReadAllBytes($Path)))
   if(-not ($value -is [array]) -or $value.Count -ne 5 -or
       -not ($value[0] -is [int] -or $value[0] -is [long]) -or [int64]$value[0] -ne 1){
       throw 'Unexpected snapshot schema.'
   }
   for($i=1;$i -lt 5;$i++){
     if(-not ($value[$i] -is [string])){throw 'Snapshot field type invalid.'}
     if($value[$i] -cnotmatch '^[a-f0-9]{64}$' -and
        -not ($i -ge 3 -and $value[$i] -ceq 'none')){throw 'Snapshot digest syntax invalid.'}
   }
   return ,$value
 }catch{throw 'Invalid, malformed, oversized or unsupported snapshot JSON.'}
}
$params=@{ClientPath=$ClientPath;Json=$true}
if($PatchSourcePath){$params.PatchSourcePath=$PatchSourcePath}
if($BackupRoot){$params.BackupRoot=$BackupRoot}
if($VanillaLogin){$params.VanillaLogin=$true}
if($VanillaLoading){$params.VanillaLoading=$true}
if($RealmHost){$params.RealmHost=$RealmHost}
$planner=Join-Path $PSScriptRoot 'Plan-Naxxramas-Install.ps1'
$plan=(& $planner @params | Out-String) | ConvertFrom-Json
$paths=@('Data/patch-V.mpq','Data/patch-Z.mpq','Data/Patch-J.mpq',
 'Data/Patch-U.mpq','Data/enUS/realmlist.wtf')
if([int]$plan.schema_version -ne 1 -or
 $plan.kind -cne 'read_only_preview_not_install_authorisation' -or
 $plan.client_target -cne 'WoW 3.3.5a build 12340 enUS' -or
 @($plan.files).Count -ne 5){throw 'Unrecognized planner schema.'}
$files=@()
for($i=0;$i -lt 5;$i++){
 $p=$plan.files[$i]
 if($p.path -cne $paths[$i]){throw 'Unexpected file path in planner output.'}
 $files+=,@(
  [string]$p.path,[string]$p.kind,[bool]$p.required,[bool]$p.selected,
  [string]$p.destination_state,[string]$p.source_state,[string]$p.action,
  [bool]$p.backup_required,[string]$p.existing_sha256,
  [string]$p.existing_size_bytes,[string]$p.expected_sha256,
  [string]$p.expected_size_bytes
 )
}
$semantic=@(
 1,[string]$plan.patch_set_version,[string]$plan.client_target,
 [bool]$plan.optional_selections.vanilla_login,
 [bool]$plan.optional_selections.vanilla_loading,
 [string]$plan.realm_host,[string]$plan.status,
 [string]$plan.space_budget.mode,
 [bool]$plan.space_budget.backup_location_selected,
 [string]$plan.space_budget.client_volume_required_bytes,
 [string]$plan.space_budget.backup_volume_required_bytes,$files
)
$digest=ShaText ('NAXX-OBSERVED-PLAN-V1:'+(ConvertTo-Json -InputObject $semantic -Compress -Depth 16))
$current=@(1,$digest,(FolderId $ClientPath),(FolderId $PatchSourcePath),(FolderId $BackupRoot))
if($Snapshot){ ConvertTo-Json -InputObject $current -Compress -Depth 3;return }
$prior=Read-Snapshot $BaselineSnapshotPath
$blocks=New-Object 'System.Collections.Generic.List[string]'
if($prior[1] -cne $current[1]){$blocks.Add('file_plan_or_options_changed')}
if($prior[2] -cne $current[2]){$blocks.Add('client_folder_identity_changed')}
if($prior[3] -cne $current[3]){$blocks.Add('source_folder_identity_changed')}
if($prior[4] -cne $current[4]){$blocks.Add('backup_folder_identity_changed')}
$identical=($blocks.Count -eq 0)
if($plan.status -cne 'review_only_no_blockers'){$blocks.Add('fresh_planner_preflight_blocked')}
if(-not $BackupRoot){$blocks.Add('separate_backup_not_selected')}
$status=if($blocks.Count -eq 0){'live_plan_matches_NOT_APPROVED'}else{'manual_review_live_plan_or_preflight'}
$report=[pscustomobject][ordered]@{
 kind='read_only_live_plan_recheck'
 schema_version=1
 status=$status
 snapshot_matches_current_observation=$identical
 fresh_preflight_status=[string]$plan.status
 blockers=@($blocks.ToArray())
 review_required=$true
 allow_file_writes=$false
 allow_automatic_resume=$false
 authorises_rollback=$false
 records_real_consent=$false
 public_distribution_authorised=$false
 limitations='Snapshot is editable and unsigned; matching bytes and Win32 folder IDs do not prove ownership, consent, source rights, physical disk safety, durable latest state or absence of path races.'
}
if($Json){$report|ConvertTo-Json -Depth 4}
else{
 Write-Host ('Read-only live plan review: '+$status)
 foreach($b in $blocks){Write-Host ('Review: '+$b)}
 Write-Host 'No installation or rollback permitted.' -ForegroundColor Yellow
}
