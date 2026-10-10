#requires -Version 5.1
# Component classification fixtures. No WoW files or real user reports in CI.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
$planner=Join-Path $repo 'tools/Plan-Reference-Components.ps1'
$tokens=$null;$errors=$null
[Management.Automation.Language.Parser]::ParseFile($planner,[ref]$tokens,[ref]$errors)|Out-Null
if(@($errors).Count -gt 0){throw ('PowerShell syntax errors: '+($errors -join '; '))}
$base=Join-Path ([IO.Path]::GetTempPath()) ('naxx-component-test-'+[guid]::NewGuid().ToString('N'))
try{
 foreach($folder in @('repo/tools','repo/config','reports','private-game/WTF/Account/SECRET')){
  New-Item -Path (Join-Path $base $folder) -ItemType Directory -Force|Out-Null
 }
 $stub=Join-Path $base 'repo'
 Copy-Item -LiteralPath $planner -Destination (Join-Path $stub 'tools/Plan-Reference-Components.ps1')
 foreach($cfg in @('client-patches.json','addon-suite.json','realm.json')){
  Copy-Item -LiteralPath (Join-Path (Join-Path $repo 'config') $cfg) -Destination (Join-Path (Join-Path $stub 'config') $cfg)
 }
 $policy=Get-Content -LiteralPath (Join-Path $repo 'config/client-patches.json') -Raw|ConvertFrom-Json
 $reportFile=Join-Path $base 'reports/reference.json'
 $report=[ordered]@{
  schema_version=1
  report_kind='naxxramas_reference_client_validation'
  contains_personal_paths=$false
  reads_player_settings=$false
  target_version='3.3.5a'
  expected_build=12340
  version_metadata='3, 3, 5, 12340'
  build_confirmed=$true
  locale_enUS_present=$true
  patchset='patchset-0002'
  core_patches_valid=$true
  optional_login_conflict=$false
  realmlist_present=$true
  data_mpq_count=21
  data_mpq_total_bytes=[long]17773795353
  patches=@(
   foreach($p in @($policy.patches)){
    $present=(@('Data/patch-V.mpq','Data/patch-Z.mpq','Data/Patch-U.mpq') -ccontains [string]$p.path)
    [ordered]@{
     path=[string]$p.path
     required=[bool]$p.required
     status=if($present){'verified'}else{'not_installed'}
     size_bytes=if($present){[long]$p.size_bytes}else{$null}
    }
   }
  )
  n_addons=@(
   foreach($n in @('NCore','IndividualProgressionAddon','DungeonJournal','MultiBot','NaxxLootLottery')){
    [ordered]@{name=$n;status='present'}
   }
  )
  reference_status='verified_reference'
  warnings=@()
 }
 function Write-Report(){
  $report|ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $reportFile -Encoding UTF8
 }
 Write-Report
 $run=Join-Path $stub 'tools/Plan-Reference-Components.ps1'
 function Plan([string[]]$extra){
  $response=(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $run -ReportPath $reportFile @extra 2>&1|Out-String)
  return [pscustomobject]@{code=$LASTEXITCODE;output=$response}
 }
 $r=Plan @('-VanillaLoading','-Addons','MultiBot')
 if($r.code -ne 0){throw ('Known reference report was rejected: '+$r.output)}
 $parsed=$r.output|ConvertFrom-Json
 if($parsed.kind -cne 'read_only_component_separation_plan' -or
    $parsed.safe_to_mutate_client -ne $false -or
    $parsed.plan_has_blockers -ne $false -or
    $parsed.base_client.game_archives_fully_inventoried -ne $false -or
    [long]$parsed.base_client.existing_data_mpq_total_bytes -ne [long]17773795353){
  throw 'Reference classifier made an unsafe or unsupported base client claim.'
 }
 foreach($n in @('Data/patch-V.mpq','Data/patch-Z.mpq')){
  $p=@($parsed.required_patches|Where-Object {$_.path -ceq $n})
  if($p.Count -ne 1 -or $p[0].future_action -cne 'reuse_verified_existing'){
   throw "Verified core component was not reused: $n"
  }
 }
 $u=@($parsed.optional_patches|Where-Object {$_.path -ceq 'Data/Patch-U.mpq'})[0]
 if($u.future_action -cne 'reuse_verified_existing'){throw 'Existing verified Patch U was not preserved.'}
 foreach($n in @('Data/Patch-J.mpq','Data/Patch-C.mpq')){
  $p=@($parsed.optional_patches|Where-Object {$_.path -ceq $n})[0]
  if($p.future_action -cne 'leave_absent'){throw "Unselected login patch was added: $n"}
 }
 $core=@($parsed.addons|Where-Object {$_.name -ceq 'NCore'})[0]
 $bot=@($parsed.addons|Where-Object {$_.name -ceq 'MultiBot'})[0]
 $journal=@($parsed.addons|Where-Object {$_.name -ceq 'DungeonJournal'})[0]
 if($core.future_action -cne 'verify_version_and_integrity_before_update' -or
    $bot.future_action -cne 'verify_version_and_integrity_before_update' -or
    $journal.future_action -cne 'preserve_existing_personal_addon'){
  throw 'Existing addons were incorrectly treated as a verified release or scheduled for overwrite.'
 }
 if($parsed.realm.reference_file_present -ne $true -or $parsed.realm.value_verified -ne $false){
  throw 'Realmlist contents were incorrectly treated as verified.'
 }
 $r=Plan @('-TbcLogin','-VanillaLoading')
 $p=$r.output|ConvertFrom-Json
 $c=@($p.optional_patches|Where-Object {$_.path -ceq 'Data/Patch-C.mpq'})[0]
 if($r.code -ne 0 -or $p.selected_login -cne 'tbc_c' -or
    $c.future_action -cne 'obtain_verified_source_before_install'){
  throw 'New TBC login should require verified patch source, without implicit install.'
 }
 $r=Plan @('-VanillaLogin','-TbcLogin')
 if($r.code -eq 0 -or -not $r.output.Contains('cannot both be selected')){
  throw 'Conflicting requested login patches were accepted.'
 }
 $original=Join-Path $base 'private-game/WTF/Account/SECRET/value.txt'
 [IO.File]::WriteAllText($original,'SHOULD_NOT_BE_TOUCHED')
 $hash=(Get-FileHash -LiteralPath $original -Algorithm SHA256).Hash
 $report.patches[0].status='hash_mismatch'
 $report.core_patches_valid=$false
 Write-Report
 $r=Plan @()
 $p=$r.output|ConvertFrom-Json
 if($r.code -ne 0 -or -not $p.plan_has_blockers -or
    @($p.blockers|Where-Object {$_ -like '*Mandatory core patch not verified*'}).Count -ne 1){
  throw 'Broken required V did not block future installation.'
 }
 $report.patches[0].status='verified'
 $report.core_patches_valid=$true
 $report.patches[3].status='size_mismatch'
 $report.patches[3].size_bytes=123
 Write-Report
 $r=Plan @('-VanillaLogin')
 $p=$r.output|ConvertFrom-Json
 if($r.code -ne 0 -or -not $p.plan_has_blockers){
  throw 'Existing conflicting C was not rejected when Vanilla J was requested.'
 }
 $report.patches[3].status='not_installed'
 $report.patches[3].size_bytes=$null
 $report.n_addons[0].name='PERSONAL_SECRET'
 Write-Report
 $r=Plan @()
 if($r.code -eq 0){throw 'Unexpected addon was accepted from untrusted report.'}
 if((Get-FileHash -LiteralPath $original -Algorithm SHA256).Hash -ne $hash){
  throw 'Component planner modified personal account data.'
 }
 Write-Host 'ALL REFERENCE COMPONENT CLASSIFICATION TESTS PASSED'
}finally{
 if(Test-Path -LiteralPath $base){Remove-Item -LiteralPath $base -Recurse -Force}
}
exit 0
