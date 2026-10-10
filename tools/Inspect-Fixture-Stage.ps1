#requires -Version 5.1
<#
M22: read-only audit of one EXPLICIT synthetic stage directory.
No deletion, rollback, copy, report, network or enumeration of sibling directories.
Stage markers are self-declared fixture evidence, NOT strong authentication.
DO NOT use on real World of Warcraft game folders.
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$SourcePath,
 [Parameter(Mandatory=$true)][string]$DestinationPath,
 [Parameter(Mandatory=$true)][string]$ManifestPath,
 [Parameter(Mandatory=$true)][string]$StagePath
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
function Require([bool]$ok,[string]$message){if(-not $ok){throw $message}}
function FullDirectory([string]$path){
 Require (-not [string]::IsNullOrWhiteSpace($path)) 'Fixture directory missing.'
 $i=Get-Item -LiteralPath $path -Force -ErrorAction Stop
 Require ($i.PSIsContainer) 'Fixture path is not a directory.'
 return [IO.Path]::GetFullPath($i.FullName).TrimEnd([char[]]@('\','/'))
}
function Within([string]$child,[string]$parent){
 return $child.Equals($parent,[StringComparison]::OrdinalIgnoreCase) -or
  $child.StartsWith($parent+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)
}
function NoLinks([string]$path){
 $p=[IO.Path]::GetFullPath($path)
 while(-not [string]::IsNullOrWhiteSpace($p)){
  if(Test-Path -LiteralPath $p){
   $i=Get-Item -LiteralPath $p -Force -ErrorAction Stop
   Require (-not [bool]($i.Attributes -band [IO.FileAttributes]::ReparsePoint)) 'Linked paths are blocked.'
  }
  $parent=[IO.Directory]::GetParent($p)
  if($null -eq $parent){break}
  $p=$parent.FullName
 }
}
function SmallJson([string]$path){
 NoLinks $path
 Require (Test-Path -LiteralPath $path -PathType Leaf) 'Required fixture metadata is absent.'
 Require ([long](Get-Item -LiteralPath $path -Force).Length -le 65536) 'Fixture metadata exceeds size limit.'
 return (Get-Content -LiteralPath $path -Raw|ConvertFrom-Json)
}
function AssertMarker([string]$root,[string]$file,[string]$expected){
 $p=Join-Path $root $file
 NoLinks $p
 Require (Test-Path -LiteralPath $p -PathType Leaf) 'Synthetic fixture marker is missing.'
 Require ((Get-Content -LiteralPath $p -Raw).Trim() -ceq $expected) 'Synthetic fixture marker invalid.'
}
function Relative([string]$path){
 $allowed=@('Wow.exe','Data/common.mpq','Data/enUS/locale-enUS.mpq',
   'Data/patch-V.mpq','Data/patch-Z.mpq','Data/Patch-U.mpq',
   'Data/Patch-J.mpq','Data/Patch-C.mpq')
 Require ($allowed -ccontains $path) 'Non-synthetic filename in manifest or stage marker.'
 return $path.Replace('/',[IO.Path]::DirectorySeparatorChar)
}
function EntriesMatch([string]$folder,[string[]]$names){
 if(-not (Test-Path -LiteralPath $folder)){return}
 NoLinks $folder
 Require (Test-Path -LiteralPath $folder -PathType Container) 'Expected stage folder became a file.'
 foreach($item in @(Get-ChildItem -LiteralPath $folder -Force)){
  NoLinks $item.FullName
  Require ($names -ccontains $item.Name) 'Unexpected stage content or empty folder.'
  if($item.PSIsContainer){
   Require ($item.Name -ceq 'Data' -or $item.Name -ceq 'enUS') 'Unexpected stage subfolder.'
  }else{
   Require ($item.Name -cne 'Data' -and $item.Name -cne 'enUS') 'Stage folder path was replaced by a file.'
  }
 }
}
try{
 $src=FullDirectory $SourcePath
 $dest=FullDirectory $DestinationPath
 $stage=FullDirectory $StagePath
 $manifest=[IO.Path]::GetFullPath($ManifestPath)
 foreach($path in @($src,$dest,$stage,$manifest)){NoLinks $path}
 Require (-not (Within $src $dest) -and -not (Within $dest $src)) 'Source and destination overlap.'
 Require (-not (Within $stage $src) -and -not (Within $src $stage) -and
  -not (Within $stage $dest) -and -not (Within $dest $stage)) 'Stage overlaps fixture source/destination.'
 $repo=[IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd([char[]]@('\','/'))
 foreach($root in @($src,$dest,$stage)){
  Require (-not (Within $root $repo) -and -not (Within $repo $root)) 'Fixture folder overlaps tool repository.'
 }
 Require (-not (Within $manifest $stage) -and -not (Within $manifest $dest)) 'Manifest cannot reside inside stage/destination.'
 Require ([string][IO.Directory]::GetParent($stage).FullName -ieq
  [string][IO.Directory]::GetParent($dest).FullName) 'Stage must be an explicit sibling of destination.'
 Require ([IO.Path]::GetFileName($stage) -cmatch '^\.naxx-test-copy-stage-[0-9a-f]{32}$') 'Stage folder is not named as a synthetic stage.'
 AssertMarker $src '.naxx-copy-test-source' 'NAXX_SYNTHETIC_COPY_SOURCE_V1'
 AssertMarker $dest '.naxx-copy-test-destination' 'NAXX_SYNTHETIC_COPY_DESTINATION_V1'
 $m=SmallJson $manifest
 Require ([int]$m.schema_version -eq 1 -and $m.kind -ceq 'naxx_synthetic_copy_fixture' -and
  $m.synthetic_fixture -eq $true -and $m.complete_game_client -eq $false) 'Only synthetic manifests are supported.'
 $rows=@($m.files)
 Require ($rows.Count -ge 3 -and $rows.Count -le 8) 'Expected 3-8 dummy files.'
 $seen=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
 [long]$total=0
 $rootNames=@('.naxx-fixture-stage-owner.json')
 $dataNames=@()
 $localeNames=@()
 foreach($row in $rows){
  $rel=[string]$row.relative_path
  $null=Relative $rel
  Require ($seen.Add($rel)) 'Duplicate manifest filename.'
  Require ([long]$row.byte_size -gt 0 -and [long]$row.byte_size -le 262144 -and
   [string]$row.sha256 -cmatch '^[0-9a-f]{64}$') 'Manifest size or hash invalid.'
  $total += [long]$row.byte_size
  $parts=$rel.Split('/')
  if($parts.Count -eq 1){$rootNames+=$parts[0]}
  elseif($parts.Count -eq 2){
   if($rootNames -cnotcontains 'Data'){$rootNames+='Data'}
   $dataNames+=$parts[1]
  }else{
   if($rootNames -cnotcontains 'Data'){$rootNames+='Data'}
   if($dataNames -cnotcontains 'enUS'){$dataNames+='enUS'}
   $localeNames+=$parts[2]
  }
 }
 Require ($total -le 1048576 -and $seen.Contains('Wow.exe') -and
  $seen.Contains('Data/patch-V.mpq') -and $seen.Contains('Data/patch-Z.mpq') -and
  -not ($seen.Contains('Data/Patch-J.mpq') -and $seen.Contains('Data/Patch-C.mpq'))) 'Manifest lacks required tiny-fixture constraints.'
 $owner=SmallJson (Join-Path $stage '.naxx-fixture-stage-owner.json')
 Require ([int]$owner.schema_version -eq 1 -and
  $owner.kind -ceq 'naxx_synthetic_stage_marker' -and $owner.synthetic_fixture -eq $true -and
  $owner.source -ceq $src -and $owner.destination -ceq $dest -and
  $owner.stage -ceq $stage -and @($owner.files).Count -eq $rows.Count) 'Stage ownership claim does not match explicit fixture.'
 $owned=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
 foreach($r in @($owner.files)){
  $name=[string]$r.relative_path
  $null=Relative $name
  Require ($owned.Add($name)) 'Duplicate stage owner entry.'
  $matches=@($rows|Where-Object {$_.relative_path -ceq $name})
  Require ($matches.Count -eq 1 -and
   [long]$r.byte_size -eq [long]$matches[0].byte_size -and
   [string]$r.sha256 -ceq [string]$matches[0].sha256) 'Stage ownership entry differs from manifest.'
 }
 EntriesMatch $stage $rootNames
 EntriesMatch (Join-Path $stage 'Data') $dataNames
 EntriesMatch (Join-Path $stage 'Data/enUS') $localeNames
 [int]$present=0
 [int]$missing=0
 foreach($r in $rows){
  $p=Join-Path $stage (Relative ([string]$r.relative_path))
  NoLinks $p
  if(Test-Path -LiteralPath $p -PathType Leaf){
   Require ([long](Get-Item -LiteralPath $p -Force).Length -eq [long]$r.byte_size) 'Staged dummy file size differs.'
   Require ((Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant() -ceq
    [string]$r.sha256) 'Staged dummy file digest differs.'
   $present++
  }else{
   Require (-not (Test-Path -LiteralPath $p)) 'Stage expected file path is not a normal file.'
   $missing++
  }
 }
 Write-Host 'SYNTHETIC STAGE AUDIT: CONSISTENT_FOR_MANUAL_REVIEW'
 Write-Host ('HASH-VERIFIED STAGED FILES: '+$present+'; ABSENT EXPECTED FILES: '+$missing)
 Write-Host 'Ownership marker is self-declared: this DOES NOT authorise deletion.'
 Write-Host 'No staging cleanup, copying, rollback, game-file installation, or report was performed.'
 exit 0
}catch{
 Write-Host ('SYNTHETIC STAGE AUDIT: BLOCKED ('+$_.Exception.Message+')') -ForegroundColor Yellow
 Write-Host 'No files were changed. Keep the stage untouched for manual review.' -ForegroundColor Yellow
 exit 1
}
