#requires -Version 5.1
<#
M20 synthetic-fixture-only recovery readiness audit.
READ ONLY, no file writes/deletion/network; never use on any real WoW client.
Checks partial "applying" journals and complete "copied" journals.
A READY result is an inspection, not an automatic rollback/installer.
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$SourcePath,
 [Parameter(Mandatory=$true)][string]$DestinationPath,
 [Parameter(Mandatory=$true)][string]$ManifestPath
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
function Require([bool]$ok,[string]$reason){if(-not $ok){throw $reason}}
function FullDir([string]$p){
 Require (-not [string]::IsNullOrWhiteSpace($p)) 'Fixture directory is missing.'
 $item=Get-Item -LiteralPath $p -Force -ErrorAction Stop
 Require ([bool]$item.PSIsContainer) 'Expected a fixture directory.'
 return [IO.Path]::GetFullPath($item.FullName).TrimEnd([char[]]@('\','/'))
}
function Within([string]$child,[string]$parent){
 return $child.Equals($parent,[StringComparison]::OrdinalIgnoreCase) -or
  $child.StartsWith(($parent+[IO.Path]::DirectorySeparatorChar),[StringComparison]::OrdinalIgnoreCase)
}
function NoLinks([string]$path){
 $p=[IO.Path]::GetFullPath($path)
 while(-not [string]::IsNullOrWhiteSpace($p)){
  if(Test-Path -LiteralPath $p){
   $i=Get-Item -LiteralPath $p -Force -ErrorAction Stop
   Require (-not [bool]($i.Attributes -band [IO.FileAttributes]::ReparsePoint)) 'Linked or junction paths are blocked.'
  }
  $parent=[IO.Directory]::GetParent($p)
  if($null -eq $parent){break}
  $p=$parent.FullName
 }
}
function CheckMarker([string]$root,[string]$name,[string]$expected){
 $p=Join-Path $root $name
 NoLinks $p
 Require (Test-Path -LiteralPath $p -PathType Leaf) 'Synthetic fixture marker is missing.'
 Require ([string](Get-Content -LiteralPath $p -Raw).Trim() -ceq $expected) 'Synthetic marker content is not valid.'
}
function Rel([string]$s){
 $names=@('Wow.exe','Data/common.mpq','Data/enUS/locale-enUS.mpq',
          'Data/patch-V.mpq','Data/patch-Z.mpq','Data/Patch-U.mpq',
          'Data/Patch-J.mpq','Data/Patch-C.mpq')
 Require ($names -ccontains $s) 'Non-synthetic manifest or journal path.'
 return $s.Replace('/',[IO.Path]::DirectorySeparatorChar)
}
function ReadSmallJson([string]$path,[long]$limit){
 NoLinks $path
 Require (Test-Path -LiteralPath $path -PathType Leaf) 'Fixture JSON file is missing.'
 Require ([long](Get-Item -LiteralPath $path -Force).Length -le $limit) 'Fixture JSON is excessively large.'
 return (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json)
}
function Candidate([object]$obj){
 $relative=[string]$obj.relative_path
 $null=Rel $relative
 Require ([long]$obj.byte_size -gt 0 -and [long]$obj.byte_size -le 262144) 'Fixture file size outside tiny test limit.'
 Require ([string]$obj.sha256 -cmatch '^[0-9a-f]{64}$') 'Fixture manifest digest invalid.'
 return $relative
}
function ContainsExactOnly([string]$folder,[string[]]$names){
 NoLinks $folder
 if(-not (Test-Path -LiteralPath $folder -PathType Container)){return $false}
 $ok=$true
 foreach($item in @(Get-ChildItem -LiteralPath $folder -Force)){
  NoLinks $item.FullName
  if($names -cnotcontains [string]$item.Name){$ok=$false}
 }
 return $ok
}
try{
 $src=FullDir $SourcePath
 $dest=FullDir $DestinationPath
 NoLinks $src; NoLinks $dest
 Require (-not (Within $src $dest) -and -not (Within $dest $src)) 'Source/destination overlap is forbidden.'
 $repo=[IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd([char[]]@('\','/'))
 Require (-not (Within $src $repo) -and -not (Within $dest $repo) -and
  -not (Within $repo $src) -and -not (Within $repo $dest)) 'Fixture roots overlap tool repository.'
 CheckMarker $src '.naxx-copy-test-source' 'NAXX_SYNTHETIC_COPY_SOURCE_V1'
 CheckMarker $dest '.naxx-copy-test-destination' 'NAXX_SYNTHETIC_COPY_DESTINATION_V1'
 $manifestFull=[IO.Path]::GetFullPath($ManifestPath)
 Require (-not (Within $manifestFull $dest)) 'Manifest must be outside destination.'
 $m=ReadSmallJson $manifestFull 65536
 Require ([int]$m.schema_version -eq 1 -and
  [string]$m.kind -ceq 'naxx_synthetic_copy_fixture' -and
  $m.synthetic_fixture -ceq $true -and
  $m.complete_game_client -ceq $false) 'Only disposable synthetic fixture manifests are allowed.'
 $rows=@($m.files)
 Require ($rows.Count -ge 3 -and $rows.Count -le 8) 'Expected 3-8 synthetic fixture files.'
 $seen=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
 [long]$total=0
 foreach($row in $rows){
  $p=Candidate $row
  Require ($seen.Add($p)) 'Duplicate fixture manifest entry.'
  $total += [long]$row.byte_size
 }
 Require ($total -le 1048576) 'Synthetic fixture exceeds 1 MiB.'
 Require ($seen.Contains('Wow.exe') -and $seen.Contains('Data/patch-V.mpq') -and
  $seen.Contains('Data/patch-Z.mpq')) 'Synthetic manifest lacks mandatory test files.'
 Require (-not ($seen.Contains('Data/Patch-J.mpq') -and $seen.Contains('Data/Patch-C.mpq'))) 'Synthetic manifest includes conflicting J/C choices.'
 $jfile=Join-Path $dest '.naxx-fixture-copy-journal.json'
 $j=ReadSmallJson $jfile 65536
 Require ([int]$j.schema_version -eq 1 -and
  [string]$j.kind -ceq 'naxx_fixture_copy_journal' -and
  [string]$j.source -ceq $src -and [string]$j.destination -ceq $dest -and
  (@('applying','copied') -ccontains [string]$j.status)) 'Journal does not identify this exact disposable fixture.'
 $entries=@($j.files)
 Require ($entries.Count -eq $rows.Count) 'Journal file count disagrees with manifest.'
 $seenJournal=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
 foreach($row in $entries){
  $p=Candidate $row
  Require ($seenJournal.Add($p)) 'Duplicate journal entry.'
  $match=@($rows|Where-Object {$_.relative_path -ceq $p})
  Require ($match.Count -eq 1 -and [long]$match[0].byte_size -eq [long]$row.byte_size -and
    [string]$match[0].sha256 -ceq [string]$row.sha256) 'Journal differs from synthetic manifest.'
 }
 # Check a fixed directory tree; do not enumerate unknown directories.
 # Unknown files AND unknown empty folders must block readiness.
 $rootItems=@('.naxx-copy-test-destination','.naxx-fixture-copy-journal.json','Data')
 if($seen.Contains('Wow.exe')){$rootItems+= 'Wow.exe'}
 Require (ContainsExactOnly $dest $rootItems) 'Unexpected destination root entries or linked paths.'
 $allowedData=@('enUS')
 foreach($row in $rows){$p=[string]$row.relative_path;if($p -match '^Data/[^/]+$'){$allowedData+=($p -split '/')[1]}}
 if(Test-Path -LiteralPath (Join-Path $dest 'Data')){
  Require (ContainsExactOnly (Join-Path $dest 'Data') $allowedData) 'Unexpected Data entries or linked paths.'
 }
 $allowedLocale=@()
 foreach($row in $rows){$p=[string]$row.relative_path;if($p -match '^Data/enUS/[^/]+$'){$allowedLocale+=($p -split '/')[2]}}
 $enUS=Join-Path $dest 'Data/enUS'
 if(Test-Path -LiteralPath $enUS){
  Require (ContainsExactOnly $enUS $allowedLocale) 'Unexpected locale entries or linked paths.'
 }
 [int]$present=0
 [int]$absent=0
 foreach($row in $rows){
  $target=Join-Path $dest (Rel ([string]$row.relative_path))
  NoLinks $target
  if(Test-Path -LiteralPath $target -PathType Leaf){
   Require ([long](Get-Item -LiteralPath $target -Force).Length -eq [long]$row.byte_size) 'Destination file size changed; manual review needed.'
   $sha=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
   Require ($sha -ceq [string]$row.sha256) 'Destination file bytes changed; manual review needed.'
   $present++
  }elseif(Test-Path -LiteralPath $target){
   throw 'Expected fixture file path is not a normal file.'
  }else{
   $absent++
  }
 }
 Require ($j.status -ceq 'applying' -or $absent -eq 0) 'Completed journal is missing a file.'
 Write-Host 'SYNTHETIC RECOVERY AUDIT: READY_FOR_MANUAL_ROLLBACK'
 Write-Host ('JOURNAL STATE: '+[string]$j.status)
 Write-Host ('VERIFIED DESTINATION FILES: '+$present+'; MISSING TEST FILES: '+$absent)
 Write-Host 'Use the existing fixture-only Rollback action separately, with explicit confirmation.'
 Write-Host 'No automatic recovery, deletion, copying or installation was attempted.'
 Write-Host 'Orphan staging folders outside the destination are NOT inspected or cleaned.'
 exit 0
}catch{
 Write-Host ('SYNTHETIC RECOVERY AUDIT: BLOCKED ('+$_.Exception.Message+')') -ForegroundColor Yellow
 Write-Host 'No files were modified, deleted or copied. Manual review is required.' -ForegroundColor Yellow
 exit 1
}
