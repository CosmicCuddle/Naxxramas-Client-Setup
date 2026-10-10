#requires -Version 5.1
<#
Milestone 17, local-only unknown MPQ filenames and byte sizes.
No content reads, hashes, network calls, output files or game writes.
Run on a separate backed-up development copy. Output stays in console.
#>
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ClientPath)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
function Require([bool]$ok,[string]$why){if(-not $ok){throw $why}}
function NoLink([string]$p){
 $item=Get-Item -LiteralPath $p -Force -ErrorAction Stop
 Require (-not [bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) 'Linked files/folders cannot be inspected safely.'
 return $item
}
try{
 Require (-not [string]::IsNullOrWhiteSpace($ClientPath)) 'Drag a development client folder here.'
 $root=NoLink $ClientPath
 Require ([bool]$root.PSIsContainer) 'Expected a client folder.'
 Require (Test-Path -LiteralPath (Join-Path $root.FullName 'Wow.exe') -PathType Leaf) 'Choose the folder containing Wow.exe.'
 $data=Join-Path $root.FullName 'Data'
 $locale=Join-Path $data 'enUS'
 foreach($p in @($data,$locale)){
  Require (Test-Path -LiteralPath $p -PathType Container) 'Data and Data/enUS directories are required.'
  $null=NoLink $p
 }
 $rootPattern='^(common(?:-2)?|expansion|lichking|patch(?:-[0-9]+)?|patch-[VZJCU])\.mpq$'
 $localePattern='^((?:locale|speech|expansion-locale|expansion-speech|lichking-locale|lichking-speech)-enUS|patch-enUS(?:-[0-9]+)?)\.mpq$'
 $items=New-Object 'System.Collections.Generic.List[object]'
 [int]$known=0
 foreach($scope in @(@{dir=$data;prefix='Data';pattern=$rootPattern},
                       @{dir=$locale;prefix='Data/enUS';pattern=$localePattern})){
  foreach($file in @(Get-ChildItem -LiteralPath $scope.dir -File -Force | Sort-Object Name)){
   if($file.Extension -ine '.mpq'){continue}
   $null=NoLink $file.FullName
   if($file.Name -match $scope.pattern){$known++;continue}
   $items.Add([pscustomobject]@{
    Path=([string]$scope.prefix+'/'+$file.Name)
    Bytes=[long]$file.Length
   })
  }
 }
 Write-Host 'NAXXRAMAS LOCAL MPQ CLASSIFICATION - READ ONLY'
 Write-Host ('Recognised MPQ filenames: '+$known)
 Write-Host ('Unclassified MPQs: '+$items.Count)
 Write-Host 'These files are not necessarily harmful. Never delete them based on this report.'
 if($items.Count -gt 0){
  Write-Host 'Filenames and sizes are displayed LOCALLY only:'
  foreach($f in $items){Write-Host ('  '+$f.Path+'  ('+$f.Bytes+' bytes)')}
 }else{Write-Host 'None found in the two scanned directories.'}
 Write-Host 'No report was saved. No files were changed or uploaded.'
 exit 0
}catch{
 Write-Host ('ERROR: '+$_.Exception.Message) -ForegroundColor Red
 Write-Host 'No client files were changed. No report was saved.' -ForegroundColor Yellow
 exit 1
}
