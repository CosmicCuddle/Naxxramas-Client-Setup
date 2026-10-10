#requires -Version 5.1
<#
Milestone 16: read-only consistency review of an M14 private game-files JSON.
Reads the report and pinned policy ONLY. No game reads, copies or writes.
#>
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ReportPath)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
function Require([bool]$ok,[string]$why){if(-not $ok){throw $why}}
function AllowPath([string]$p){
 if($p -in @('Wow.exe','Launcher.exe','Repair.exe','BackgroundDownloader.exe','Scan.dll','Storm.dll','DivxDecoder.dll','unicows.dll')){return $true}
 if($p -match '^Data/(common(?:-2)?|expansion|lichking|patch(?:-[0-9]+)?|patch-[VZJCU])\.mpq$'){return $true}
 if($p -match '^Data/enUS/((?:base-enUS|backup-enUS|(?:locale|speech|expansion-locale|expansion-speech|lichking-locale|lichking-speech)-enUS|patch-enUS(?:-[0-9]+)?))\.mpq$'){return $true}
 return $false
}
function NoLinks([string]$path){
 $walk=[IO.Path]::GetFullPath($path)
 while($walk){
  if(Test-Path -LiteralPath $walk){
   $item=Get-Item -LiteralPath $walk -Force -ErrorAction Stop
   Require (-not [bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) 'Linked report paths are not supported.'
  }
  $parent=[IO.Directory]::GetParent($walk)
  if($null -eq $parent){break}
  $walk=$parent.FullName
 }
}
try{
 Require (-not [string]::IsNullOrWhiteSpace($ReportPath)) 'Choose a JSON report.'
 $inputFile=[IO.Path]::GetFullPath($ReportPath)
 Require ([IO.Path]::GetExtension($inputFile) -ieq '.json' -and
  (Test-Path -LiteralPath $inputFile -PathType Leaf)) 'Expected an existing .json report.'
 NoLinks $inputFile
 Require ([long](Get-Item -LiteralPath $inputFile).Length -le 2097152) 'Report exceeds 2 MiB.'
 $r=Get-Content -LiteralPath $inputFile -Raw | ConvertFrom-Json
 Require ([int]$r.schema_version -eq 1 -and
  [string]$r.kind -ceq 'read_only_whitelisted_game_file_inventory' -and
  [string]$r.target_version -ceq '3.3.5a' -and
  [int]$r.expected_build -eq 12340 -and
  [string]$r.patchset -ceq 'patchset-0002') 'Unsupported report format, build or patchset.'
 $mode=[string]$r.hash_mode
 Require ($mode -ceq 'sha256_per_file' -or $mode -ceq 'sizes_only_unverified') 'Unknown inventory hash mode.'
 Require ($r.inventory_complete_for_game_install -ceq $false -and
  $r.client_modified -ceq $false -and
  $r.absolute_paths_included -ceq $false -and
  $r.personal_settings_accessed -ceq $false -and
  $r.private_data_scanned -ceq $false) 'Invalid safety/privacy claims.'
 Require ([int]$r.excluded_unknown_mpq_count -ge 0) 'Invalid unknown MPQ count.'
 $policy=Get-Content -LiteralPath (Join-Path (Split-Path -Parent $PSScriptRoot) 'config/client-patches.json') -Raw | ConvertFrom-Json
 Require ([int]$policy.schema_version -eq 1 -and
  [string]$policy.patch_set_version -ceq 'patchset-0002' -and
  @($policy.patches).Count -eq 5) 'Pinned patch policy is invalid.'
 $expectedNames=@('Data/patch-V.mpq','Data/patch-Z.mpq','Data/Patch-J.mpq','Data/Patch-C.mpq','Data/Patch-U.mpq')
 foreach($name in $expectedNames){
  Require (@($policy.patches|Where-Object {$_.path -ceq $name}).Count -eq 1) 'Pinned policy is incomplete.'
 }
 $files=@($r.files)
 Require ($files.Count -ge 1 -and $files.Count -le 256 -and
  [int]$r.file_count -eq $files.Count) 'Invalid report file count.'
 $seen=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
 $statuses=@{}
 [long]$sum=0
 [int]$baseArchives=0
 foreach($f in $files){
  $path=[string]$f.relative_path
  Require (AllowPath $path) 'Non-allowlisted inventory path.'
  Require ($seen.Add($path)) 'Duplicate inventory path.'
  [long]$size=$f.byte_size
  Require ($size -gt 0 -and $sum -le ([long]::MaxValue-$size)) 'Invalid file size or byte count.'
  $sum += $size
  if($mode -ceq 'sha256_per_file'){
   Require ([string]$f.sha256 -cmatch '^[0-9a-f]{64}$') 'A full inventory is missing a lowercase SHA-256.'
  }else{Require ($null -eq $f.sha256) 'Quick inventory must not claim any file hash.'}
  $pin=@($policy.patches | Where-Object {$_.path -ieq $path})
  Require ($pin.Count -le 1) 'Ambiguous pinned patch.'
  if($pin.Count -eq 1){
   $p=$pin[0]
   $cat=if([bool]$p.required){'naxxramas_required_patch'}else{'naxxramas_optional_patch'}
   $status=if($mode -ceq 'sizes_only_unverified'){'not_checked_quick_mode'}
    elseif($size -eq [long]$p.size_bytes -and [string]$f.sha256 -ceq [string]$p.sha256){'pinned_verified'}
    else{'pinned_mismatch'}
   Require ([string]$f.component -ceq $cat -and
    [string]$f.integrity -ceq $status) 'Pinned file status disagrees with policy.'
   $statuses[[string]$p.path]=$status
  }else{
   $cat=if($path -match '^Data/'){'base_archive_candidate'}else{'client_binary_candidate'}
   Require ([string]$f.component -ceq $cat -and
    [string]$f.integrity -ceq 'not_pinned') 'Unpinned file category/status is inconsistent.'
   if($cat -ceq 'base_archive_candidate'){$baseArchives++}
  }
 }
 Require ($seen.Contains('Wow.exe') -and [long]$r.total_inventoried_bytes -eq $sum) 'Missing executable or inconsistent total bytes.'
 $statusRows=@($r.pinned_patches)
 Require ($statusRows.Count -eq 5) 'Expected five patch summary rows.'
 $missing=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
 foreach($p in @($policy.patches)){
  $path=[string]$p.path
  $expected=if($statuses.ContainsKey($path)){$statuses[$path]}
   elseif([bool]$p.required){'missing_required'}else{'not_installed'}
  $matching=@($statusRows | Where-Object {$_.relative_path -ieq $path})
  Require ($matching.Count -eq 1 -and
   [string]$matching[0].relative_path -ceq $path -and
   [bool]$matching[0].required -eq [bool]$p.required -and
   [string]$matching[0].status -ceq $expected) 'Pinned patch summary is inconsistent.'
  if([bool]$p.required -and $expected -cne 'pinned_verified'){$null=$missing.Add($path)}
 }
 $unverified=@($r.required_patches_unverified)
 Require ($unverified.Count -eq $missing.Count) 'Required patch blocker list has a wrong count.'
 foreach($name in $unverified){Require ($missing.Contains([string]$name)) 'Required patch blocker list is inconsistent.'}
 Write-Host 'REPORT STRUCTURE: CONSISTENT'
 Write-Host ('HASH MODE: '+$mode)
 Write-Host ('ALLOWLISTED FILES: '+$files.Count)
 Write-Host ('BASE ARCHIVE CANDIDATES: '+$baseArchives+' (NOT full client proof)')
 Write-Host ('UNKNOWN MPQS (FILENAMES HIDDEN): '+[int]$r.excluded_unknown_mpq_count)
 Write-Host ('BUILD 12340 REPORTED: '+[bool]$r.build_confirmed)
 Write-Host ('V/Z REPORTED HASHES AGAINST POLICY: '+$(if($missing.Count -eq 0){'MATCH'}else{'MISSING, MISMATCHED OR UNVERIFIED'}))
 if($statuses.ContainsKey('Data/Patch-J.mpq') -and $statuses.ContainsKey('Data/Patch-C.mpq')){
  Write-Host 'WARNING: J/C login patches coexist; this is unsupported.' -ForegroundColor Yellow
 }
 if($mode -ceq 'sizes_only_unverified'){Write-Host 'WARNING: Quick inventory has no file hashes.' -ForegroundColor Yellow}
 Write-Host 'INSTALL/DOWNLOAD: BLOCKED. This is NOT a complete or authenticated base-game manifest.'
 Write-Host 'No game files were read, copied or modified during this report review.'
 exit 0
}catch{
 Write-Host ('REPORT REJECTED: '+$_.Exception.Message) -ForegroundColor Red
 Write-Host 'Only a JSON report and pinned local policy were read; no game files were modified.' -ForegroundColor Yellow
 exit 1
}
