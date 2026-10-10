#requires -Version 5.1
<#
Classify a sanitised reference-client report into future installation
components. Read-only: this script never opens or modifies any game client.
It does not establish a redistributable full-client source.
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$ReportPath,
 [switch]$VanillaLogin,
 [switch]$TbcLogin,
 [switch]$VanillaLoading,
 [ValidateSet('IndividualProgressionAddon','DungeonJournal','MultiBot','NaxxLootLottery')]
 [string[]]$Addons=@()
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
function Require([bool]$valid,[string]$why){if(-not $valid){throw $why}}
function UniqueEntry([object[]]$all,[string]$name,[string]$field){
 $found=@($all | Where-Object {([string]$_.$field) -ceq $name})
 Require ($found.Count -eq 1) "Report must contain exactly one $name entry."
 return $found[0]
}
try {
 Require (-not ($VanillaLogin -and $TbcLogin)) 'Vanilla J and TBC C cannot both be selected.'
 Require (-not [string]::IsNullOrWhiteSpace($ReportPath)) 'Select a client-reference JSON report.'
 $item=Get-Item -LiteralPath $ReportPath -ErrorAction Stop
 Require (-not [bool]$item.PSIsContainer) 'Reference report must be a JSON file.'
 Require ($item.Extension -ieq '.json' -and $item.Length -gt 0 -and $item.Length -le 1048576) 'Reference report must be JSON no larger than 1 MiB.'
 Require (-not [bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) 'Linked reference reports are not supported.'
 $report=Get-Content -LiteralPath $item.FullName -Raw -Encoding UTF8|ConvertFrom-Json
 $repo=Split-Path -Parent $PSScriptRoot
 $patchPolicy=Get-Content -LiteralPath (Join-Path $repo 'config/client-patches.json') -Raw|ConvertFrom-Json
 $addonPolicy=Get-Content -LiteralPath (Join-Path $repo 'config/addon-suite.json') -Raw|ConvertFrom-Json
 $realmPolicy=Get-Content -LiteralPath (Join-Path $repo 'config/realm.json') -Raw|ConvertFrom-Json
 Require ([int]$report.schema_version -eq 1 -and
  $report.report_kind -ceq 'naxxramas_reference_client_validation' -and
  $report.contains_personal_paths -eq $false -and
  $report.reads_player_settings -eq $false) 'Report is not a supported sanitised reference report.'
 Require ($report.target_version -ceq '3.3.5a' -and
  [int]$report.expected_build -eq 12340 -and
  $report.patchset -ceq $patchPolicy.patch_set_version -and
  $report.patchset -ceq 'patchset-0002') 'Reference report build or patchset is not current.'
 Require ([int]$patchPolicy.schema_version -eq 1 -and @($patchPolicy.patches).Count -eq 5) 'Patch manifest is invalid.'
 Require ([int]$addonPolicy.schema_version -eq 1 -and
  $addonPolicy.required_framework -ceq 'NCore' -and
  @($addonPolicy.optional_modules).Count -eq 4) 'Addon catalog is invalid.'
 Require ([int]$realmPolicy.schema_version -eq 1 -and
  $realmPolicy.relative_path -ceq 'Data/enUS/realmlist.wtf') 'Realm configuration is invalid.'
 $expectedPaths=@('Data/patch-V.mpq','Data/patch-Z.mpq','Data/Patch-J.mpq','Data/Patch-C.mpq','Data/Patch-U.mpq')
 $expectedAddons=@('NCore','IndividualProgressionAddon','DungeonJournal','MultiBot','NaxxLootLottery')
 Require (@($report.patches).Count -eq $expectedPaths.Count -and
  @($report.n_addons).Count -eq $expectedAddons.Count) 'Incomplete or unrecognised reference report component set.'
 foreach($name in $expectedPaths){
  $null=UniqueEntry @($report.patches) $name 'path'
  $null=UniqueEntry @($patchPolicy.patches) $name 'path'
 }
 foreach($name in $expectedAddons){
  $null=UniqueEntry @($report.n_addons) $name 'name'
 }
 foreach($name in @($addonPolicy.optional_modules)){
  Require ($expectedAddons -ccontains [string]$name) 'Unexpected optional addon in catalog.'
 }
 $chosen=New-Object 'System.Collections.Generic.List[string]'
 foreach($name in @($Addons)){
  Require (@($addonPolicy.optional_modules) -ccontains $name) "Unknown optional addon selection: $name"
  if(-not $chosen.Contains($name)){$chosen.Add($name)}
 }
 $want=@('Data/patch-V.mpq','Data/patch-Z.mpq')
 if($VanillaLogin){$want+= 'Data/Patch-J.mpq'}
 if($TbcLogin){$want+= 'Data/Patch-C.mpq'}
 if($VanillaLoading){$want+= 'Data/Patch-U.mpq'}
 $j=UniqueEntry @($report.patches) 'Data/Patch-J.mpq' 'path'
 $c=UniqueEntry @($report.patches) 'Data/Patch-C.mpq' 'path'
 $conflicting=([string]$j.status -cne 'not_installed') -and ([string]$c.status -cne 'not_installed')
 $incompatibleChoice=($VanillaLogin -and [string]$c.status -cne 'not_installed') -or
  ($TbcLogin -and [string]$j.status -cne 'not_installed')
 $patchEntries=New-Object 'System.Collections.Generic.List[object]'
 $blockers=New-Object 'System.Collections.Generic.List[string]'
 foreach($name in $expectedPaths){
  $p=UniqueEntry @($report.patches) $name 'path'
  $policy=UniqueEntry @($patchPolicy.patches) $name 'path'
  Require ([bool]$p.required -eq [bool]$policy.required) "Required/optional mismatch for $name."
  $status=[string]$p.status
  Require (@('verified','not_installed','missing_required','size_mismatch','hash_mismatch') -ccontains $status) "Unknown patch status: $name"
  if($status -ceq 'verified'){
   Require ([long]$p.size_bytes -eq [long]$policy.size_bytes) "Inconsistent verified file size in reference report: $name"
  }
  $selected=$want -ccontains $name
  $action=if($selected){
   if($status -ceq 'verified'){'reuse_verified_existing'}
   elseif($status -ceq 'not_installed' -or $status -ceq 'missing_required'){'obtain_verified_source_before_install'}
   else{'blocked_mismatched_existing_file'}
  }else{
   if($status -ceq 'not_installed'){'leave_absent'}
   else{'preserve_existing_untouched'}
  }
  if([bool]$policy.required -and $status -cne 'verified'){
   $blockers.Add("Mandatory core patch not verified: $name")
  }
  if($selected -and $action -ceq 'blocked_mismatched_existing_file'){
   $blockers.Add("Selected patch is mismatched: $name")
  }
  $patchEntries.Add([ordered]@{
   path=$name
   required=[bool]$policy.required
   selected=[bool]$selected
   reference_status=$status
   future_action=$action
  })
 }
 if(-not [bool]$report.build_confirmed){$blockers.Add('Wow.exe build 12340 is not confirmed.')}
 if(-not [bool]$report.locale_enUS_present){$blockers.Add('Data/enUS is missing.')}
 if($conflicting -or [bool]$report.optional_login_conflict){
  $blockers.Add('Conflicting Vanilla J and TBC C login patches already exist.')
 }
 if($incompatibleChoice){$blockers.Add('Selected login screen conflicts with an existing login patch.')}
 $addonEntries=New-Object 'System.Collections.Generic.List[object]'
 foreach($name in $expectedAddons){
  $a=UniqueEntry @($report.n_addons) $name 'name'
  $status=[string]$a.status
  Require (@('present','not_installed') -ccontains $status) "Unexpected addon status: $name"
  $selected=($name -ceq 'NCore') -or $chosen.Contains($name)
  # Presence is not a verified release version or file hash.
  $action=if($selected){
   if($status -ceq 'present'){'verify_version_and_integrity_before_update'}
   else{'obtain_and_verify_release_before_install'}
  }else{
   if($status -ceq 'present'){'preserve_existing_personal_addon'}
   else{'leave_absent'}
  }
  $addonEntries.Add([ordered]@{
   name=$name
   required=($name -ceq 'NCore')
   selected=[bool]$selected
   reference_status=$status
   future_action=$action
  })
 }
 Require ([long]$report.data_mpq_total_bytes -ge 0 -and
  [int]$report.data_mpq_count -ge 0) 'Invalid MPQ inventory totals.'
 $result=[ordered]@{
  schema_version=1
  kind='read_only_component_separation_plan'
  source='sanitised_owner_reference_report'
  patchset=[string]$report.patchset
  build_expected=12340
  build_confirmed=[bool]$report.build_confirmed
  base_client=[ordered]@{
   game_archives_fully_inventoried=$false
   game_file_checksums_available=$false
   existing_data_mpq_count=[int]$report.data_mpq_count
   existing_data_mpq_total_bytes=[long]$report.data_mpq_total_bytes
   next_step='A separate read-only full file inventory and an authorized base-client source are required; never infer a complete clean base from totals.'
  }
  required_patches=@($patchEntries.ToArray()|Where-Object {$_.required})
  optional_patches=@($patchEntries.ToArray()|Where-Object {-not $_.required})
  addons=@($addonEntries.ToArray())
  realm=[ordered]@{
   relative_path=[string]$realmPolicy.relative_path
   reference_file_present=[bool]$report.realmlist_present
   value_verified=$false
   future_action='backup_then_verify_or_configure_in_disposable_test_copy'
  }
  selected_login=if($VanillaLogin){'vanilla_j'}elseif($TbcLogin){'tbc_c'}else{'wotlk_default'}
  safe_to_mutate_client=$false
  plan_has_blockers=($blockers.Count -gt 0)
  blockers=@($blockers.ToArray())
  notes=@(
   'Presence of addon TOC files is not proof of pinned GitHub release identity.',
   'Never remove or overwrite personal addons or unselected visual patches.',
   'No contents of account folders, settings, SavedVariables or realmlist were accessed.',
   'This report is not a runnable installer and cannot establish full-client redistribution rights.'
  )
 }
 $result|ConvertTo-Json -Depth 12
 exit 0
}catch{
 Write-Host ('ERROR: '+$_.Exception.Message) -ForegroundColor Red
 Write-Host 'No files or game clients were modified.' -ForegroundColor Yellow
 exit 1
}
