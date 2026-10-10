#requires -Version 5.1
<#
Disposable-fixture-only local copy/verify experiment.
NEVER run on a real WoW client. Requires exact synthetic markers, a
synthetic-only manifest, an EMPTY destination and explicit confirmation.
No real-client installation, download, archive extraction or game writes.
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$SourcePath,
 [Parameter(Mandatory=$true)][string]$DestinationPath,
 [Parameter(Mandatory=$true)][string]$ManifestPath,
 [ValidateSet('Plan','Copy','Rollback')][string]$Action='Plan',
 [switch]$ConfirmDisposableFixture,
 [ValidateRange(0,20)][int]$SimulateFailureAfter=0,
 [ValidateRange(0,20)][int]$SimulateRollbackInterruptionAfter=0
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$sourceMarker='.naxx-copy-test-source'
$destMarker='.naxx-copy-test-destination'
$stateFile='.naxx-fixture-copy-journal.json'
function Require([bool]$good,[string]$why){if(-not $good){throw $why}}
function SHA([string]$path){return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()}
function FullFolder([string]$path){
 Require (-not [string]::IsNullOrWhiteSpace($path)) 'Folder path is empty.'
 $item=Get-Item -LiteralPath $path -Force -ErrorAction Stop
 Require ([bool]$item.PSIsContainer) 'A path is not a folder.'
 return [IO.Path]::GetFullPath($item.FullName).TrimEnd([char[]]@('\','/'))
}
function Inside([string]$child,[string]$parent){
 return $child.Equals($parent,[StringComparison]::OrdinalIgnoreCase) -or
  $child.StartsWith(($parent+[IO.Path]::DirectorySeparatorChar),[StringComparison]::OrdinalIgnoreCase)
}
function NoLinkAncestors([string]$path){
 $walk=$path
 while(-not [string]::IsNullOrWhiteSpace($walk)){
  if(Test-Path -LiteralPath $walk){
   $item=Get-Item -LiteralPath $walk -Force -ErrorAction Stop
   Require (-not [bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) 'Linked/junction paths are not supported.'
  }
  $parent=[IO.Directory]::GetParent($walk)
  if($null -eq $parent){break}
  $walk=$parent.FullName
 }
}
function SafeRelative([string]$path){
 Require (-not [string]::IsNullOrWhiteSpace($path)) 'Empty manifest relative path.'
 # Small, FIXED fixture allowlist: never use this to copy arbitrary game files.
 $allowed=@('Wow.exe','Data/common.mpq','Data/enUS/locale-enUS.mpq',
            'Data/patch-V.mpq','Data/patch-Z.mpq','Data/Patch-U.mpq',
            'Data/Patch-J.mpq','Data/Patch-C.mpq')
 Require ($allowed -ccontains $path) "Fixture manifest path not allowed: $path"
 return $path.Replace('/',[IO.Path]::DirectorySeparatorChar)
}
function ProbeFile([string]$path,[object]$record){
 Require (Test-Path -LiteralPath $path -PathType Leaf) 'Source or destination fixture file is missing.'
 NoLinkAncestors $path
 Require ([long](Get-Item -LiteralPath $path -Force).Length -eq [long]$record.byte_size) 'Fixture file size differs from manifest.'
 Require ((SHA $path) -ceq [string]$record.sha256) 'Fixture file digest differs from manifest.'
}
function ReadManifest([string]$path){
 Require (Test-Path -LiteralPath $path -PathType Leaf) 'Missing fixture manifest.'
 NoLinkAncestors $path
 Require ([long](Get-Item -LiteralPath $path).Length -le 65536) 'Fixture manifest is too large.'
 $data=Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
 Require ([int]$data.schema_version -eq 1 -and
  $data.kind -ceq 'naxx_synthetic_copy_fixture' -and
  $data.synthetic_fixture -eq $true -and
  $data.complete_game_client -eq $false) 'Only purpose-made dummy copy manifests are allowed.'
 Require (@($data.files).Count -ge 3 -and @($data.files).Count -le 8) 'Expected 3-8 dummy fixture files.'
 $seen=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
 [long]$bytes=0
 foreach($record in @($data.files)){
  $relative=SafeRelative ([string]$record.relative_path)
  Require ($seen.Add([string]$record.relative_path)) 'Duplicate fixture path.'
  Require ([long]$record.byte_size -gt 0 -and [long]$record.byte_size -le 262144) 'Dummy fixture files must be smaller than 256 KiB.'
  Require ([string]$record.sha256 -cmatch '^[0-9a-f]{64}$') 'Expected lowercase SHA-256.'
  $bytes += [long]$record.byte_size
 }
 Require ($bytes -le 1048576) 'Copy fixture exceeds 1 MiB total hard limit.'
 Require ($seen.Contains('Wow.exe') -and $seen.Contains('Data/patch-V.mpq') -and
  $seen.Contains('Data/patch-Z.mpq')) 'Dummy manifest must include Wow.exe and mandatory V/Z.'
 Require (-not ($seen.Contains('Data/Patch-J.mpq') -and $seen.Contains('Data/Patch-C.mpq'))) 'Conflicting login patches J and C.'
 return $data
}
function CheckMarker([string]$root,[string]$name,[string]$value){
 $p=Join-Path $root $name
 NoLinkAncestors $p
 Require (Test-Path -LiteralPath $p -PathType Leaf) 'Synthetic test-only marker is missing.'
 Require ([string](Get-Content -LiteralPath $p -Raw).Trim() -ceq $value) 'Fixture marker content is incorrect. Real clients are forbidden.'
}
function VerifyDestinationEntries([string]$root,[object[]]$manifestFiles){
 # Fixed shape only. Empty unknown directories must block, not merely files.
 $rootNames=@('.naxx-copy-test-destination','.naxx-fixture-copy-journal.json')
 $dataNames=@()
 $localeNames=@()
 foreach($f in $manifestFiles){
  $parts=([string]$f.relative_path).Split('/')
  if($parts.Count -eq 1){$rootNames+=$parts[0]}
  elseif($parts.Count -eq 2){
   if($rootNames -cnotcontains 'Data'){$rootNames+='Data'}
   $dataNames+=$parts[1]
  }elseif($parts.Count -eq 3){
   if($rootNames -cnotcontains 'Data'){$rootNames+='Data'}
   if($dataNames -cnotcontains 'enUS'){$dataNames+='enUS'}
   $localeNames+=$parts[2]
  }
 }
 foreach($scope in @(
  @{Path=$root;Names=$rootNames},
  @{Path=(Join-Path $root 'Data');Names=$dataNames},
  @{Path=(Join-Path $root 'Data/enUS');Names=$localeNames}
 )){
  if(-not (Test-Path -LiteralPath $scope.Path)){continue}
  NoLinkAncestors $scope.Path
  Require (Test-Path -LiteralPath $scope.Path -PathType Container) 'Expected fixture folder was replaced.'
  foreach($item in @(Get-ChildItem -LiteralPath $scope.Path -Force)){
   NoLinkAncestors $item.FullName
   Require ($scope.Names -ccontains $item.Name) 'Unexpected destination file or empty folder. Manual review required.'
   if($item.PSIsContainer){
    Require ($item.Name -ceq 'Data' -or $item.Name -ceq 'enUS') 'Unexpected fixture subfolder.'
   }else{
    Require (-not ($item.Name -ceq 'Data' -or $item.Name -ceq 'enUS')) 'Fixture directory became a file.'
   }
  }
 }
}
function WriteJournal([string]$path,[object]$record){
 $json=$record|ConvertTo-Json -Depth 10
 $utf8=[Text.UTF8Encoding]::new($false)
 $bytes=$utf8.GetBytes($json+[Environment]::NewLine)
 $stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
}
try{
 $src=FullFolder $SourcePath
 $dest=FullFolder $DestinationPath
 NoLinkAncestors $src
 NoLinkAncestors $dest
 Require (-not (Inside $src $dest) -and -not (Inside $dest $src)) 'Source and destination must be separate, non-nested folders.'
 $destParent=[IO.Directory]::GetParent($dest).FullName
 $srcParent=[IO.Directory]::GetParent($src).FullName
 Require (-not $src.Equals([IO.Path]::GetPathRoot($src).TrimEnd([char[]]@('\','/')),[StringComparison]::OrdinalIgnoreCase)) 'Do not use a drive root.'
 Require (-not $dest.Equals([IO.Path]::GetPathRoot($dest).TrimEnd([char[]]@('\','/')),[StringComparison]::OrdinalIgnoreCase)) 'Do not use a drive root.'
 $repo=[IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd([char[]]@('\','/'))
 Require (-not (Inside $src $repo) -and -not (Inside $dest $repo) -and
  -not (Inside $repo $src) -and -not (Inside $repo $dest)) 'Fixture roots must not overlap the launcher repository.'
 CheckMarker $src $sourceMarker 'NAXX_SYNTHETIC_COPY_SOURCE_V1'
 CheckMarker $dest $destMarker 'NAXX_SYNTHETIC_COPY_DESTINATION_V1'
 $manifestFull=[IO.Path]::GetFullPath($ManifestPath)
 Require (-not (Inside $manifestFull $dest)) 'Do not put a manifest in destination.'
 $data=ReadManifest $manifestFull
 $rows=@($data.files)
 $journalPath=Join-Path $dest $stateFile
 if($Action -eq 'Rollback'){
  Require ($SimulateFailureAfter -eq 0) 'Copy failure injection is not valid during rollback.'
  Require ([bool]$ConfirmDisposableFixture) 'Rollback requires -ConfirmDisposableFixture.'
  Require (Test-Path -LiteralPath $journalPath -PathType Leaf) 'No fixture copy journal exists.'
  NoLinkAncestors $journalPath
  $journal=Get-Content -LiteralPath $journalPath -Raw|ConvertFrom-Json
  Require ($journal.schema_version -eq 1 -and $journal.kind -ceq 'naxx_fixture_copy_journal' -and
   $journal.destination -ceq $dest -and $journal.source -ceq $src -and
   (@('applying','copied','rolling_back') -ccontains [string]$journal.status)) 'Fixture journal is invalid; refusing rollback.'
  Require (@($journal.files).Count -eq $rows.Count) 'Fixture journal does not match manifest.'
  foreach($j in @($journal.files)){
   $rel=SafeRelative ([string]$j.relative_path)
   $match=@($rows|Where-Object {$_.relative_path -ceq [string]$j.relative_path})
   Require ($match.Count -eq 1 -and
    [string]$j.sha256 -ceq [string]$match[0].sha256 -and
    [long]$j.byte_size -eq [long]$match[0].byte_size) 'Journal and manifest disagree.'
   $target=Join-Path $dest $rel
   if(Test-Path -LiteralPath $target -PathType Leaf){ProbeFile $target $j}
   else{Require ($journal.status -cne 'copied') 'Completed fixture journal has a missing file.'}
  }
  # A previous interrupted journal transition needs explicit manual review.
  # Check this before the general unknown-destination entry scan.
  foreach($leftover in @($journalPath+'.rollback-writing',$journalPath+'.rollback-previous')){
   Require (-not (Test-Path -LiteralPath $leftover)) 'Rollback journal replacement residue requires manual review.'
  }
  # Never trust file-only recursion: an unknown EMPTY directory also blocks.
  VerifyDestinationEntries $dest $rows
  if($journal.status -cne 'rolling_back'){
   # Transition to a durable, resumable state BEFORE the first deletion.
   $journal.status='rolling_back'
   $writing=$journalPath+'.rollback-writing'
   $previous=$journalPath+'.rollback-previous'
   WriteJournal $writing $journal
   [IO.File]::Replace($writing,$journalPath,$previous)
   [IO.File]::Delete($previous)
  }
  [int]$removed=0
  foreach($j in @($journal.files)){
   $target=Join-Path $dest (SafeRelative ([string]$j.relative_path))
   VerifyDestinationEntries $dest $rows
   NoLinkAncestors $target
   if(Test-Path -LiteralPath $target -PathType Leaf){
    # Recheck immediately before deletion; never delete altered fixture files.
    ProbeFile $target $j
    [IO.File]::Delete($target)
    $removed++
    if($SimulateRollbackInterruptionAfter -gt 0 -and $removed -eq $SimulateRollbackInterruptionAfter){
     throw 'SIMULATED FIXTURE ROLLBACK INTERRUPTION; rolling_back journal retained.'
    }
   }else{
    Require (-not (Test-Path -LiteralPath $target)) 'A fixture file path changed into an unexpected object.'
   }
  }
  VerifyDestinationEntries $dest $rows
  foreach($sub in @('Data/enUS','Data')){
   $dir=Join-Path $dest ($sub.Replace('/',[IO.Path]::DirectorySeparatorChar))
   if(Test-Path -LiteralPath $dir -PathType Container){
    if(@(Get-ChildItem -LiteralPath $dir -Force).Count -eq 0){[IO.Directory]::Delete($dir)}
   }
  }
  [IO.File]::Delete($journalPath)
  Write-Host 'SYNTHETIC FIXTURE ROLLBACK VERIFIED. ORIGINAL SOURCE UNCHANGED.'
  exit 0
 }
 Require ($SimulateRollbackInterruptionAfter -eq 0) 'Rollback interruption injection is valid only during rollback.'
 Require (-not (Test-Path -LiteralPath $journalPath)) 'Existing fixture journal must be reviewed or rolled back first.'
 $destEntries=@(Get-ChildItem -LiteralPath $dest -Force)
 Require ($destEntries.Count -eq 1 -and $destEntries[0].Name -ceq $destMarker) 'Destination must contain only its marker. No overwrites allowed.'
 foreach($record in $rows){
  $rel=SafeRelative ([string]$record.relative_path)
  $path=Join-Path $src $rel
  ProbeFile $path $record
 }
 Write-Host ('FIXTURE COPY PLAN: '+$rows.Count+' synthetic files; source bytes verified.')
 if($Action -eq 'Plan'){
  Write-Host 'PLAN ONLY: no files written. Real-client copying is disabled.'
  exit 0
 }
 Require ([bool]$ConfirmDisposableFixture) 'Copy requires -ConfirmDisposableFixture.'
 Require ($SimulateFailureAfter -eq 0 -or $SimulateFailureAfter -le $rows.Count) 'Invalid simulated failure count.'
 $stage=Join-Path $destParent ('.naxx-test-copy-stage-'+[guid]::NewGuid().ToString('N'))
 Require (-not (Test-Path -LiteralPath $stage)) 'Unexpected stage collision.'
 # Hard cap is enforced above; verify available space in both staging and target.
 $bytesNeeded=[long]0
 foreach($record in $rows){$bytesNeeded += [long]$record.byte_size}
 $drive=[IO.DriveInfo]::new([IO.Path]::GetPathRoot($dest))
 Require ($drive.AvailableFreeSpace -gt ($bytesNeeded*2+1048576)) 'Insufficient disk space for stage and copy.'
 [IO.Directory]::CreateDirectory($stage)|Out-Null
 $promoted=New-Object 'System.Collections.Generic.List[string]'
 try{
  foreach($record in $rows){
   $rel=SafeRelative ([string]$record.relative_path)
   $in=Join-Path $src $rel
   $out=Join-Path $stage $rel
   [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($out))|Out-Null
   NoLinkAncestors $in
   [IO.File]::Copy($in,$out,$false)
   ProbeFile $out $record
  }
  # Final destination recheck after staging and BEFORE creating any journal.
  $destEntries=@(Get-ChildItem -LiteralPath $dest -Force)
  Require ($destEntries.Count -eq 1 -and $destEntries[0].Name -ceq $destMarker) 'Destination changed while staging. Refusing to copy.'
  $session=[ordered]@{
   schema_version=1
   kind='naxx_fixture_copy_journal'
   source=$src
   destination=$dest
   status='applying'
   files=@($rows|ForEach-Object {[ordered]@{relative_path=$_.relative_path;sha256=$_.sha256;byte_size=$_.byte_size}})
  }
  # Record ownership before promotion so an interruption is visible.
  # "applying" permits verified partial rollback after interruption.
  WriteJournal $journalPath $session
  foreach($record in $rows){
   $rel=SafeRelative ([string]$record.relative_path)
   $from=Join-Path $stage $rel
   $to=Join-Path $dest $rel
   [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($to))|Out-Null
   Require (-not (Test-Path -LiteralPath $to)) 'Destination file unexpectedly appeared.'
   [IO.File]::Move($from,$to)
   $promoted.Add($to)
   ProbeFile $to $record
   if($SimulateFailureAfter -gt 0 -and $promoted.Count -eq $SimulateFailureAfter){
    throw 'SIMULATED FIXTURE COPY FAILURE'
   }
  }
  # Complete only after verifying all destination files. Journal status is
  # changed by atomic replacement with a separate backup of the applying state.
  foreach($record in $rows){ProbeFile (Join-Path $dest (SafeRelative ([string]$record.relative_path))) $record}
  $session.status='copied'
  $writing=$journalPath+'.writing'
  $previous=$journalPath+'.previous'
  WriteJournal $writing $session
  [IO.File]::Replace($writing,$journalPath,$previous)
  [IO.File]::Delete($previous)
  Write-Host 'SYNTHETIC FIXTURE COPY SUCCESS: hashes verified; rollback journal created.'
 }catch{
  $failure=$_.Exception.Message
  # Automatic failure rollback: only files we just promoted AND still match.
  $incomplete=$false
  foreach($target in @($promoted.ToArray())){
   $rel=$target.Substring($dest.Length).TrimStart([char[]]@('\','/')).Replace([IO.Path]::DirectorySeparatorChar,'/')
   $record=@($rows|Where-Object {$_.relative_path -ceq $rel})[0]
   try{ProbeFile $target $record;[IO.File]::Delete($target)}catch{$incomplete=$true}
  }
  foreach($sub in @('Data/enUS','Data')){
   $dir=Join-Path $dest ($sub.Replace('/',[IO.Path]::DirectorySeparatorChar))
   if(Test-Path -LiteralPath $dir -PathType Container){
    if(@(Get-ChildItem -LiteralPath $dir -Force).Count -eq 0){[IO.Directory]::Delete($dir)}
   }
  }
  if(-not $incomplete -and (Test-Path -LiteralPath $journalPath)) {[IO.File]::Delete($journalPath)}
  foreach($residue in @($journalPath+'.writing',$journalPath+'.previous')){if(Test-Path -LiteralPath $residue){[IO.File]::Delete($residue)}}
  throw ('Copy failed: '+$failure+'. '+$(if($incomplete){'Manual intervention required; journal retained.'}else{'Verified partial copy rolled back.'}))
 }finally{
  if(Test-Path -LiteralPath $stage){Remove-Item -LiteralPath $stage -Recurse -Force}
 }
 exit 0
}catch{
 Write-Host ('ERROR: '+$_.Exception.Message) -ForegroundColor Red
 Write-Host 'Real WoW installations are not supported by this disposable-fixture tool.' -ForegroundColor Yellow
 exit 1
}
