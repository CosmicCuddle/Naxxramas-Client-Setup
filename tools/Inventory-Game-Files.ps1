#requires -Version 5.1
<#
Read-only local game-file inventory for the Naxxramas installer.
Reads only allowlisted root game executables/libraries and *.mpq directly in
Data and Data/enUS. It NEVER opens WTF, Cache, SavedVariables, realmlist,
screenshots, logs, addons, or unknown directories. JSON is written outside WoW.
No client files are modified. This is NOT a complete-base-client manifest.
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$ClientPath,
 [Parameter(Mandatory=$true)][string]$ReportPath,
 [switch]$Quick
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
function Require([bool]$ok,[string]$message){if(-not $ok){throw $message}}
function FullFolder([string]$path){
 Require (-not [string]::IsNullOrWhiteSpace($path)) 'Client folder path is empty.'
 $item=Get-Item -LiteralPath $path -Force -ErrorAction Stop
 Require ([bool]$item.PSIsContainer) "Folder does not exist: $path"
 Require (-not [bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) 'Linked client folders are not supported.'
 return [IO.Path]::GetFullPath($item.FullName).TrimEnd([char[]]@('\','/'))
}
function Within([string]$path,[string]$root){
 return $path.Equals($root,[StringComparison]::OrdinalIgnoreCase) -or
  $path.StartsWith(($root+[IO.Path]::DirectorySeparatorChar),[StringComparison]::OrdinalIgnoreCase)
}
function DenyLinks([string]$path){
 if(Test-Path -LiteralPath $path){
  $item=Get-Item -LiteralPath $path -Force
  Require (-not [bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) "Linked file or folder is not supported: $path"
 }
}
function InspectFile([string]$absolute,[string]$relative,[string]$category,[object]$expected){
 DenyLinks $absolute
 $file=Get-Item -LiteralPath $absolute -Force -ErrorAction Stop
 Require (-not [bool]$file.PSIsContainer) "Expected a file: $relative"
 [long]$length=$file.Length
 $hash=$null
 if(-not $Quick){
  $hash=(Get-FileHash -LiteralPath $absolute -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
 }
 $integrity='not_pinned'
 if($null -ne $expected){
  $integrity=if($Quick){'not_checked_quick_mode'}
   elseif($length -eq [long]$expected.size_bytes -and $hash -ceq [string]$expected.sha256){'pinned_verified'}
   else{'pinned_mismatch'}
 }
 return [ordered]@{
  relative_path=$relative
  component=$category
  byte_size=$length
  sha256=$hash
  integrity=$integrity
 }
}
try{
 $root=FullFolder $ClientPath
 Require (Test-Path -LiteralPath (Join-Path $root 'Wow.exe') -PathType Leaf) 'Select a WoW folder containing Wow.exe.'
 $repo=Split-Path -Parent $PSScriptRoot
 $policy=Get-Content -LiteralPath (Join-Path $repo 'config/client-patches.json') -Raw | ConvertFrom-Json
 Require ([int]$policy.schema_version -eq 1 -and $policy.patch_set_version -ceq 'patchset-0002' -and
  @($policy.patches).Count -eq 5) 'Unexpected patch manifest.'
 $expectedPaths=@('Data/patch-V.mpq','Data/patch-Z.mpq','Data/Patch-J.mpq','Data/Patch-C.mpq','Data/Patch-U.mpq')
 foreach($p in $expectedPaths){
  Require (@($policy.patches|Where-Object {$_.path -ceq $p}).Count -eq 1) "Missing or duplicate pinned patch: $p"
 }
 Require (-not [string]::IsNullOrWhiteSpace($ReportPath)) 'Choose an output JSON report outside the game.'
 $output=[IO.Path]::GetFullPath($ReportPath)
 Require ([IO.Path]::GetExtension($output) -ieq '.json') 'Report must use a .json filename.'
 Require (-not (Within $output $root)) 'Do not put a report inside the WoW client.'
 $folder=[IO.Path]::GetDirectoryName($output)
 Require (Test-Path -LiteralPath $folder -PathType Container) 'Create an external report folder first.'
 DenyLinks $folder
 Require (-not (Test-Path -LiteralPath $output)) 'Report already exists. Choose another name; previous reports are protected.'
 $data=Join-Path $root 'Data'
 $locale=Join-Path $data 'enUS'
 DenyLinks $data
 DenyLinks $locale
 Require (Test-Path -LiteralPath $data -PathType Container) 'Data folder is missing.'
 Require (Test-Path -LiteralPath $locale -PathType Container) 'Data/enUS folder is missing.'
 $version=$null;$buildConfirmed=$false
 try{$version=[Diagnostics.FileVersionInfo]::GetVersionInfo((Join-Path $root 'Wow.exe')).FileVersion}catch{}
 if($version -and $version -match '(^|[.,\s])12340($|[.,\s])'){$buildConfirmed=$true}
 # Deliberately allowlisted root names. Do not enumerate/cache personal config.
 $rootNames=@('Wow.exe','Launcher.exe','Repair.exe','BackgroundDownloader.exe','Scan.dll','Storm.dll','DivxDecoder.dll','unicows.dll')
 $records=New-Object 'System.Collections.Generic.List[object]'
 foreach($name in $rootNames){
  $path=Join-Path $root $name
  if(Test-Path -LiteralPath $path -PathType Leaf){
   $records.Add((InspectFile $path $name 'client_binary_candidate' $null))
  }
 }
 # No recursion. Unknown MPQs/files stay out of the report, but are counted.
 $rootPattern='^(common(?:-2)?|expansion|lichking|patch(?:-[0-9]+)?|patch-[VZJCU])\.mpq$'
 $localePattern='^((?:base-enUS|backup-enUS|(?:locale|speech|expansion-locale|expansion-speech|lichking-locale|lichking-speech)-enUS|patch-enUS(?:-[0-9]+)?))\.mpq$'
 [int]$excludedCount=0
 foreach($scope in @(@{folder=$data;prefix='Data';pattern=$rootPattern},
                     @{folder=$locale;prefix='Data/enUS';pattern=$localePattern})){
  foreach($file in @(Get-ChildItem -LiteralPath $scope.folder -File -Force | Sort-Object Name)){
   $isMpq=$file.Extension -ieq '.mpq'
   if(-not $isMpq){continue}
   if($file.Name -notmatch $scope.pattern){$excludedCount++;continue}
   $relative=[string]$scope.prefix+'/'+$file.Name
   $pinned=@($policy.patches|Where-Object { $_.path -ieq $relative })
   Require ($pinned.Count -le 1) "Duplicate patch reference: $relative"
   $expected=if($pinned.Count -eq 1){$pinned[0]}else{$null}
   $category=if($null -eq $expected){'base_archive_candidate'}
    elseif([bool]$expected.required){'naxxramas_required_patch'}
    else{'naxxramas_optional_patch'}
   $records.Add((InspectFile $file.FullName $relative $category $expected))
  }
 }
 $missing=New-Object 'System.Collections.Generic.List[string]'
 $pinnedStatuses=New-Object 'System.Collections.Generic.List[object]'
 foreach($path in $expectedPaths){
  $entry=@($records | Where-Object {$_.relative_path -ieq $path})
  Require ($entry.Count -le 1) "Repeated file in local inventory: $path"
  $expected=@($policy.patches | Where-Object {$_.path -ceq $path})[0]
  $status=if($entry.Count -eq 0){if($expected.required){'missing_required'}else{'not_installed'}}
   else{[string]$entry[0].integrity}
  if([bool]$expected.required -and $status -cne 'pinned_verified'){$missing.Add($path)}
  $pinnedStatuses.Add([ordered]@{relative_path=$path;required=[bool]$expected.required;status=$status})
 }
 $rows=@($records.ToArray() | Sort-Object relative_path)
 [long]$total=0
 foreach($r in $rows){$total += [long]$r.byte_size}
 $report=[ordered]@{
  schema_version=1
  kind='read_only_whitelisted_game_file_inventory'
  target_version='3.3.5a'
  expected_build=12340
  wow_version_metadata=if($version){[string]$version}else{'unavailable'}
  build_confirmed=[bool]$buildConfirmed
  patchset='patchset-0002'
  scan_scope=@('allowlisted client binary filenames in root','*.mpq directly in Data','*.mpq directly in Data/enUS')
  hash_mode=if($Quick){'sizes_only_unverified'}else{'sha256_per_file'}
  inventory_complete_for_game_install=$false
  client_modified=$false
  absolute_paths_included=$false
  personal_settings_accessed=$false
  private_data_scanned=$false
  excluded_unknown_mpq_count=$excludedCount
  file_count=$rows.Count
  total_inventoried_bytes=$total
  files=$rows
  pinned_patches=@($pinnedStatuses.ToArray())
  required_patches_unverified=@($missing.ToArray())
  warnings=@(
   'File-level inventory is deliberately limited. Unknown MPQs and other game files are NOT classified as a clean base client.',
   'An existing client may have extra customised data. Never delete, redistribute or replace unknown files.',
   'Game binaries and MPQ hashes identify bytes, not redistribution rights.',
   'No WTF, Cache, account, realmlist, screenshots, AddOns, SavedVariables or logs were scanned.'
  )
 }
 $json=$report|ConvertTo-Json -Depth 12
 $bytes=[Text.UTF8Encoding]::new($false).GetBytes($json+[Environment]::NewLine)
 # Report may be generated in the launcher tools folder, never inside WoW.
 $stream=[IO.File]::Open($output,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
 Write-Host ('GAME FILE INVENTORY CREATED: '+$output)
 Write-Host ('ALLOWLISTED FILES: '+$rows.Count)
 Write-Host ('HASH MODE: '+[string]$report.hash_mode)
 Write-Host ('PINNED CORE VERIFIED: '+($missing.Count -eq 0 -and -not $Quick))
 Write-Host 'Game client files were NOT modified.'
 exit 0
}catch{
 Write-Host ('ERROR: '+$_.Exception.Message) -ForegroundColor Red
 Write-Host 'No game files were modified. An incomplete report may be discarded.' -ForegroundColor Yellow
 exit 1
}
