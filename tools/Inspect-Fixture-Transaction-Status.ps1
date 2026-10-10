#requires -Version 5.1
<#
M25 read-only, privacy-safe status overview for M15 disposable fixtures.
No file writes/deletion, rollback, download, network, sibling stage search,
or game-client installation. Never use this on a real WoW client.
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$SourcePath,
 [Parameter(Mandatory=$true)][string]$DestinationPath,
 [Parameter(Mandatory=$true)][string]$ManifestPath,
 [string]$StagePath=''
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
function Require([bool]$ok,[string]$why){if(-not $ok){throw $why}}
function NoLinks([string]$path){
 $walk=[IO.Path]::GetFullPath($path)
 while(-not [string]::IsNullOrWhiteSpace($walk)){
  if(Test-Path -LiteralPath $walk){
   $item=Get-Item -LiteralPath $walk -Force -ErrorAction Stop
   Require (-not [bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) 'Linked paths are blocked.'
  }
  $parent=[IO.Directory]::GetParent($walk)
  if($null -eq $parent){break}
  $walk=$parent.FullName
 }
}
function Folder([string]$path){
 Require (-not [string]::IsNullOrWhiteSpace($path)) 'Fixture root is missing.'
 NoLinks $path
 $item=Get-Item -LiteralPath $path -Force -ErrorAction Stop
 Require ([bool]$item.PSIsContainer) 'Expected a fixture folder.'
 return [IO.Path]::GetFullPath($item.FullName).TrimEnd([char[]]@('\','/'))
}
function Within([string]$child,[string]$parent){
 return $child.Equals($parent,[StringComparison]::OrdinalIgnoreCase) -or
  $child.StartsWith(($parent+[IO.Path]::DirectorySeparatorChar),[StringComparison]::OrdinalIgnoreCase)
}
function Marker([string]$root,[string]$name,[string]$value){
 $path=Join-Path $root $name
 NoLinks $path
 Require (Test-Path -LiteralPath $path -PathType Leaf) 'Fixture marker absent.'
 Require ([long](Get-Item -LiteralPath $path -Force).Length -le 256) 'Marker size invalid.'
 Require ((Get-Content -LiteralPath $path -Raw).Trim() -ceq $value) 'Fixture marker invalid.'
}
function ReadSmall([string]$path){
 NoLinks $path
 Require (Test-Path -LiteralPath $path -PathType Leaf) 'Expected fixture manifest absent.'
 Require ([long](Get-Item -LiteralPath $path -Force).Length -le 65536) 'Fixture manifest too large.'
 return (Get-Content -LiteralPath $path -Raw|ConvertFrom-Json)
}
function ManifestIsTiny([object]$m){
 Require ($m.schema_version -eq 1 -and $m.kind -ceq 'naxx_synthetic_copy_fixture' -and
  $m.synthetic_fixture -eq $true -and $m.complete_game_client -eq $false) 'Not a disposable fixture.'
 $rows=@($m.files)
 Require ($rows.Count -ge 3 -and $rows.Count -le 8) 'Wrong tiny fixture count.'
 $allowed=@('Wow.exe','Data/common.mpq','Data/enUS/locale-enUS.mpq',
  'Data/patch-V.mpq','Data/patch-Z.mpq','Data/Patch-U.mpq','Data/Patch-J.mpq','Data/Patch-C.mpq')
 $seen=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
 [long]$total=0
 foreach($row in $rows){
  $name=[string]$row.relative_path
  Require ($allowed -ccontains $name -and $seen.Add($name)) 'Invalid synthetic path.'
  Require ([long]$row.byte_size -gt 0 -and [long]$row.byte_size -le 262144 -and
   [string]$row.sha256 -cmatch '^[0-9a-f]{64}$') 'Invalid tiny size or digest.'
  $total += [long]$row.byte_size
 }
 Require ($total -le 1048576 -and $seen.Contains('Wow.exe') -and
  $seen.Contains('Data/patch-V.mpq') -and $seen.Contains('Data/patch-Z.mpq') -and
  -not ($seen.Contains('Data/Patch-J.mpq') -and $seen.Contains('Data/Patch-C.mpq'))) 'Invalid fixture layout.'
}
function RunInspector([string]$script,[string]$source,[string]$dest,[string]$manifest,[string]$stage){
 Require (Test-Path -LiteralPath $script -PathType Leaf) 'Developer read-only inspector is missing.'
 $argsList=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$script,
  '-SourcePath',$source,'-DestinationPath',$dest,'-ManifestPath',$manifest)
 if(-not [string]::IsNullOrWhiteSpace($stage)){$argsList+=@('-StagePath',$stage)}
 # Existing inspectors enforce hash, journal and stage shape. Their details are
 # intentionally suppressed: never echo arbitrary private paths or names.
 $null=(& powershell.exe @argsList 2>&1|Out-String)
 return ($LASTEXITCODE -eq 0)
}
try{
 $src=Folder $SourcePath
 $dest=Folder $DestinationPath
 Require (-not (Within $src $dest) -and -not (Within $dest $src)) 'Overlapping roots are blocked.'
 $repo=[IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd([char[]]@('\','/'))
 foreach($root in @($src,$dest)){
  Require (-not (Within $root $repo) -and -not (Within $repo $root)) 'Fixture folder overlaps tool repository.'
 }
 $manifest=[IO.Path]::GetFullPath($ManifestPath)
 NoLinks $manifest
 Require (-not (Within $manifest $dest)) 'Manifest must not be inside destination.'
 Marker $src '.naxx-copy-test-source' 'NAXX_SYNTHETIC_COPY_SOURCE_V1'
 Marker $dest '.naxx-copy-test-destination' 'NAXX_SYNTHETIC_COPY_DESTINATION_V1'
 ManifestIsTiny (ReadSmall $manifest)
 $state='NOT_CHECKED'
 $stageState='NOT_SELECTED'
 $journal=Join-Path $dest '.naxx-fixture-copy-journal.json'
 NoLinks $journal
 # Deliberately detect known interrupted replacement artifacts before
 # considering even a valid journal. Do not list their contents or names.
 $residue=$false
 foreach($suffix in @('.writing','.previous','.rollback-writing','.rollback-previous')){
  $path=$journal+$suffix
  NoLinks $path
  if(Test-Path -LiteralPath $path){$residue=$true}
 }
 if($residue){
  $state='BLOCKED_JOURNAL_REPLACEMENT_RESIDUE'
 }elseif(Test-Path -LiteralPath $journal){
  $valid=RunInspector (Join-Path $PSScriptRoot 'Inspect-Fixture-Recovery.ps1') $src $dest $manifest ''
  if(-not $valid){
   $state='BLOCKED_JOURNAL_OR_DESTINATION'
  }else{
   $j=ReadSmall $journal
   $state=switch([string]$j.status){
    'applying' {'VERIFIED_PARTIAL_APPLYING';break}
    'copied' {'VERIFIED_COPIED';break}
    'rolling_back' {'VERIFIED_PARTIAL_ROLLBACK';break}
    default {'BLOCKED_JOURNAL_STATE'}
   }
  }
 }else{
  # Without a journal only a completely empty marked destination is recognised.
  # Does not claim the owner's source files are authenticated.
  $items=@(Get-ChildItem -LiteralPath $dest -Force)
  if($items.Count -eq 1 -and $items[0].Name -ceq '.naxx-copy-test-destination' -and
   -not $items[0].PSIsContainer){
   $state='EMPTY_MARKED_DESTINATION_NO_JOURNAL'
  }else{
   $state='BLOCKED_UNEXPECTED_DESTINATION_CONTENT'
  }
 }
 if(-not [string]::IsNullOrWhiteSpace($StagePath)){
  # A stage is NEVER discovered automatically, only an explicitly nominated
  # sibling path may be examined with M22's read-only, shape-locked inspector.
  $stage=Folder $StagePath
  Require (-not (Within $stage $src) -and -not (Within $src $stage) -and
   -not (Within $stage $dest) -and -not (Within $dest $stage) -and
   -not (Within $stage $repo) -and -not (Within $repo $stage)) 'Stage overlaps protected paths.'
  if(RunInspector (Join-Path $PSScriptRoot 'Inspect-Fixture-Stage.ps1') $src $dest $manifest $stage){
   $stageState='CONSISTENT_REQUIRES_MANUAL_REVIEW'
  }else{
   $stageState='BLOCKED_UNTRUSTED_OR_CHANGED'
  }
 }
 $blocked=$state.StartsWith('BLOCKED_', [StringComparison]::Ordinal) -or
  $stageState.StartsWith('BLOCKED_', [StringComparison]::Ordinal)
 $review=($state -ne 'EMPTY_MARKED_DESTINATION_NO_JOURNAL') -or
  ($stageState -ne 'NOT_SELECTED')
 $status=if($blocked){'BLOCKED_MANUAL_REVIEW'}
  elseif($review){'REVIEW_REQUIRED'}
  else{'EMPTY_MARKED_FIXTURE'}
 Write-Host 'NAXXRAMAS SYNTHETIC TRANSACTION STATUS - READ ONLY'
 Write-Host ('TRANSACTION: '+$state)
 Write-Host ('STAGE: '+$stageState)
 Write-Host ('STATUS: '+$status)
 Write-Host 'No rollback, cleanup, repair, file copy, installation or report was performed.'
 Write-Host 'Sibling staging folders are NOT scanned. Consistency does not authorise deletion.'
 if($blocked){exit 1}
 exit 0
}catch{
 # Deliberately omit exception contents, including local path/filename details.
 Write-Host 'NAXXRAMAS SYNTHETIC TRANSACTION STATUS - READ ONLY'
 Write-Host 'TRANSACTION: BLOCKED_INVALID_FIXTURE_OR_PATH'
 Write-Host 'STAGE: UNDETERMINED'
 Write-Host 'STATUS: BLOCKED_MANUAL_REVIEW'
 Write-Host 'No files were changed. Do not attempt automatic repair or cleanup.'
 exit 1
}
