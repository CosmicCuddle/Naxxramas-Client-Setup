#requires -Version 5.1
<#
Naxxramas reference-client inspection (read only against the game client).
Verifies mandatory V/Z and WoW.exe version; J/C/U and N-Addon Collection are
optional. The JSON report contains no account data, personal paths or game files.
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$ClientPath,
 [string]$ReportPath
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest

function Require([bool]$ok,[string]$why){if(-not $ok){throw $why}}
function Inside([string]$item,[string]$directory){
 return $item.Equals($directory,[StringComparison]::OrdinalIgnoreCase) -or
  $item.StartsWith(($directory+[IO.Path]::DirectorySeparatorChar),[StringComparison]::OrdinalIgnoreCase)
}
function RootPath([string]$path){
 Require (-not [string]::IsNullOrWhiteSpace($path)) 'Select the folder containing Wow.exe.'
 $folder=Get-Item -LiteralPath $path -ErrorAction Stop
 Require ([bool]$folder.PSIsContainer) 'Client path must be a folder.'
 Require (-not ([bool]($folder.Attributes -band [IO.FileAttributes]::ReparsePoint))) 'Linked/junction client roots are not supported.'
 return [IO.Path]::GetFullPath($folder.FullName).TrimEnd([char[]]@('\','/'))
}
function NoLinked([string]$path){
 if(Test-Path -LiteralPath $path){
  Require (-not ([bool]((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint))) 'A linked client file or folder cannot be verified.'
 }
}
function CheckOne([string]$root,[object]$entry){
 $relative=[string]$entry.path
 $target=Join-Path $root ($relative.Replace('/',[IO.Path]::DirectorySeparatorChar))
 NoLinked $target
 if(-not (Test-Path -LiteralPath $target -PathType Leaf)){
  return [ordered]@{path=$relative;required=[bool]$entry.required;status=if($entry.required){'missing_required'}else{'not_installed'};size_bytes=$null}
 }
 $file=Get-Item -LiteralPath $target -Force
 if([long]$file.Length -ne [long]$entry.size_bytes){
  return [ordered]@{path=$relative;required=[bool]$entry.required;status='size_mismatch';size_bytes=[long]$file.Length}
 }
 $actual=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
 $status=if($actual -ceq [string]$entry.sha256){'verified'}else{'hash_mismatch'}
 return [ordered]@{path=$relative;required=[bool]$entry.required;status=$status;size_bytes=[long]$file.Length}
}

try{
 $root=RootPath $ClientPath
 $repo=Split-Path -Parent $PSScriptRoot
 $policyPath=Join-Path $repo 'config/client-patches.json'
 Require (Test-Path -LiteralPath $policyPath -PathType Leaf) 'Current patch policy is missing.'
 $policy=Get-Content -LiteralPath $policyPath -Raw|ConvertFrom-Json
 Require ([int]$policy.schema_version -eq 1 -and $policy.patch_set_version -ceq 'patchset-0002') 'Unexpected patch reference version.'
 $expected=@('Data/patch-V.mpq','Data/patch-Z.mpq','Data/Patch-J.mpq','Data/Patch-C.mpq','Data/Patch-U.mpq')
 Require (@($policy.patches).Count -eq 5) 'Expected five pinned patch references.'
 foreach($name in $expected){
  Require (@($policy.patches|Where-Object {$_.path -ceq $name}).Count -eq 1) "Unexpected or duplicate patch reference: $name"
 }
 $wow=Join-Path $root 'Wow.exe'
 NoLinked $wow
 $wowPresent=Test-Path -LiteralPath $wow -PathType Leaf
 $version=$null
 $buildConfirmed=$false
 if($wowPresent){
  try{$version=[Diagnostics.FileVersionInfo]::GetVersionInfo($wow).FileVersion}catch{}
  if($version -and $version -match '(^|[.,\s])12340($|[.,\s])'){$buildConfirmed=$true}
 }
 $data=Join-Path $root 'Data'
 $locale=Join-Path $data 'enUS'
 NoLinked $data
 NoLinked $locale
 $localePresent=Test-Path -LiteralPath $locale -PathType Container

 $patches=New-Object 'System.Collections.Generic.List[object]'
 foreach($entry in @($policy.patches)){$patches.Add((CheckOne $root $entry))}
 $coreValid=(@($patches|Where-Object {$_.required -and $_.status -ceq 'verified'}).Count -eq 2)
 $optionalConflict=(@($patches|Where-Object {$_.path -ceq 'Data/Patch-J.mpq' -and $_.status -ne 'not_installed'}).Count -eq 1) -and
   (@($patches|Where-Object {$_.path -ceq 'Data/Patch-C.mpq' -and $_.status -ne 'not_installed'}).Count -eq 1)

 # Count only MPQs directly in Data or enUS; do not inspect settings,
 # screenshots, logs, Cache, WTF, account or SavedVariables.
 [long]$mpqBytes=0
 [int]$mpqCount=0
 foreach($folder in @($data,$locale)){
  if(Test-Path -LiteralPath $folder -PathType Container){
   foreach($item in @(Get-ChildItem -LiteralPath $folder -File -Filter '*.mpq' -ErrorAction Stop)){
    if(-not [bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint)){
     $mpqCount++;$mpqBytes+=[long]$item.Length
    }
   }
  }
 }
 $addonRoot=Join-Path $root 'Interface/AddOns'
 $addonNames=@('NCore','IndividualProgressionAddon','DungeonJournal','MultiBot','NaxxLootLottery')
 $addons=New-Object 'System.Collections.Generic.List[object]'
 foreach($addon in $addonNames){
  $toc=Join-Path (Join-Path $addonRoot $addon) ($addon+'.toc')
  $addons.Add([ordered]@{name=$addon;status=if(Test-Path -LiteralPath $toc -PathType Leaf){'present'}else{'not_installed'}})
 }
 $realmExists=Test-Path -LiteralPath (Join-Path $locale 'realmlist.wtf') -PathType Leaf
 $warnings=New-Object 'System.Collections.Generic.List[string]'
 if(-not $wowPresent){$warnings.Add('Wow.exe is missing.')}
 elseif(-not $buildConfirmed){$warnings.Add('Wow.exe build 12340 is not confirmed by executable metadata.')}
 if(-not $localePresent){$warnings.Add('Data/enUS is missing.')}
 if(-not $coreValid){$warnings.Add('Mandatory V and Z do not both match their pinned SHA-256 and byte sizes.')}
 if($optionalConflict){$warnings.Add('Vanilla J and TBC C are both present. These optional login patches conflict.')}
 $ready=$wowPresent -and $buildConfirmed -and $localePresent -and $coreValid -and -not $optionalConflict
 $summary=[ordered]@{
  schema_version=1
  report_kind='naxxramas_reference_client_validation'
  contains_personal_paths=$false
  reads_player_settings=$false
  target_version='3.3.5a'
  expected_build=12340
  version_metadata=if($version){[string]$version}else{'unavailable'}
  build_confirmed=[bool]$buildConfirmed
  locale_enUS_present=[bool]$localePresent
  patchset=[string]$policy.patch_set_version
  core_patches_valid=[bool]$coreValid
  optional_login_conflict=[bool]$optionalConflict
  realmlist_present=[bool]$realmExists
  # Realmlist contents and IP address are intentionally never read or returned.
  data_mpq_count=$mpqCount
  data_mpq_total_bytes=$mpqBytes
  patches=@($patches.ToArray())
  n_addons=@($addons.ToArray())
  personal_data_skipped=@('WTF','Cache','Screenshots','Logs','Errors','SavedVariables','realmlist.wtf contents')
  reference_status=if($ready){'verified_reference'}else{'needs_review'}
  warnings=@($warnings.ToArray())
 }
 $json=($summary | ConvertTo-Json -Depth 10)
 if(-not [string]::IsNullOrWhiteSpace($ReportPath)){
  $file=[IO.Path]::GetFullPath($ReportPath)
  Require ([IO.Path]::GetExtension($file) -ieq '.json') 'Report filename must end in .json.'
  Require (-not (Inside $file $root)) 'Never save the reference report inside the WoW client.'
  $parent=[IO.Path]::GetDirectoryName($file)
  Require (Test-Path -LiteralPath $parent -PathType Container) 'Create the separate report folder first.'
  NoLinked $parent
  Require (-not (Test-Path -LiteralPath $file)) 'A report already exists at that path; choose a different filename.'
  $utf8=[Text.UTF8Encoding]::new($false)
  $bytes=$utf8.GetBytes($json+[Environment]::NewLine)
  $stream=[IO.File]::Open($file,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
  try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
  Write-Host "SANITISED CLIENT REFERENCE REPORT CREATED: $file"
  Write-Host "STATUS: $($summary.reference_status)"
 }else{
  Write-Output $json
 }
 exit 0
}catch{
 Write-Host ('ERROR: '+$_.Exception.Message) -ForegroundColor Red
 Write-Host 'The WoW client was not modified.'
 exit 1
}
