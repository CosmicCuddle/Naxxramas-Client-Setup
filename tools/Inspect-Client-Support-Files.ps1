#requires -Version 5.1
<#
Milestone 18: read-only, local-console-only client support candidate check.
No file contents or hashes are read. Does not enumerate arbitrary names or
folders, write reports, network, copy, install, or certify base-client identity.
Run against a SEPARATE backed-up development copy of WoW.
#>
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ClientPath)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
function Require([bool]$condition,[string]$message){if(-not $condition){throw $message}}
function CheckLinks([string]$path){
 $walk=[IO.Path]::GetFullPath($path)
 while(-not [string]::IsNullOrWhiteSpace($walk)){
  if(Test-Path -LiteralPath $walk){
   $obj=Get-Item -LiteralPath $walk -Force -ErrorAction Stop
   Require (-not [bool]($obj.Attributes -band [IO.FileAttributes]::ReparsePoint)) 'Linked or junction paths are not supported.'
  }
  $parent=[IO.Directory]::GetParent($walk)
  if($null -eq $parent){break}
  $walk=$parent.FullName
 }
}
try{
 Require (-not [string]::IsNullOrWhiteSpace($ClientPath)) 'Select the development client folder.'
 $obj=Get-Item -LiteralPath $ClientPath -Force -ErrorAction Stop
 Require ([bool]$obj.PSIsContainer) 'Client selection must be a folder.'
 $root=[IO.Path]::GetFullPath($obj.FullName)
 CheckLinks $root
 $wow=Join-Path $root 'Wow.exe'
 CheckLinks $wow
 Require (Test-Path -LiteralPath $wow -PathType Leaf) 'Select the folder containing Wow.exe.'
 # Strict, frozen candidate list. None of these is an authenticated build manifest.
 # Some are optional or version-dependent; absent does not imply a broken client.
 $names=@('Wow.exe','Launcher.exe','Repair.exe','BackgroundDownloader.exe',
          'Scan.dll','Storm.dll','DivxDecoder.dll','unicows.dll',
          'WowError.exe','fmod.dll','fmodex.dll','ijl15.dll','dbghelp.dll')
 $directories=@('Data','Data/enUS','Interface','Interface/AddOns')
 [int]$present=0
 [int]$absent=0
 Write-Host 'NAXXRAMAS NON-MPQ SUPPORT FILE AUDIT - READ ONLY'
 Write-Host 'CANDIDATE FILES (not required or authenticated except that Wow.exe was selected):'
 foreach($name in $names){
  $p=Join-Path $root $name
  CheckLinks $p
  if(Test-Path -LiteralPath $p -PathType Leaf){
   $item=Get-Item -LiteralPath $p -Force -ErrorAction Stop
   $present++
   Write-Host ('  '+$name+' : present ('+[long]$item.Length+' bytes)')
  }elseif(Test-Path -LiteralPath $p){
   throw 'An expected file path is occupied by a non-file.'
  }else{
   $absent++
   Write-Host ('  '+$name+' : not present (not necessarily a problem)')
  }
 }
 Write-Host 'DIRECTORY PRESENCE (no folder contents read):'
 foreach($relative in $directories){
  $p=Join-Path $root ($relative.Replace('/',[IO.Path]::DirectorySeparatorChar))
  CheckLinks $p
  $state=if(Test-Path -LiteralPath $p -PathType Container){'present'}
   elseif(Test-Path -LiteralPath $p){throw 'An expected directory path is occupied by a non-directory.'}
   else{'not present (not necessarily a problem)'}
  Write-Host ('  '+$relative+' : '+$state)
 }
 Write-Host ('Candidate file counts: present '+$present+'; not present '+$absent+'.')
 Write-Host 'This is NOT a complete, verified, authorised or redistributable game manifest.'
 Write-Host 'No game files were opened, copied, hashed or modified; no report or upload.'
 exit 0
}catch{
 Write-Host ('AUDIT BLOCKED: '+$_.Exception.Message) -ForegroundColor Red
 Write-Host 'No game files were copied or modified; no report was saved.' -ForegroundColor Yellow
 exit 1
}
