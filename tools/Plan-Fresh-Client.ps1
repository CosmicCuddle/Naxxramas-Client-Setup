#requires -Version 5.1
<#
Fresh-client workflow: READ-ONLY PLAN.
No complete client source is configured; this script cannot download, extract,
install, remove, or alter a WoW client. It validates an EMPTY destination and
describes all future Naxxramas additions without claiming installation is ready.
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$DestinationPath,
 [ValidateSet('Plan')][string]$Action='Plan',
 [switch]$VanillaLogin,
 [switch]$TbcLogin,
 [switch]$VanillaLoading,
 [ValidateSet('IndividualProgressionAddon','DungeonJournal','MultiBot','NaxxLootLottery')]
 [string[]]$Addons=@()
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
function Require([bool]$condition,[string]$message){if(-not $condition){throw $message}}
function IsNested([string]$a,[string]$b){
 return $a.Equals($b,[StringComparison]::OrdinalIgnoreCase) -or
  $a.StartsWith(($b+[IO.Path]::DirectorySeparatorChar),[StringComparison]::OrdinalIgnoreCase)
}
try{
 Require (-not ($VanillaLogin -and $TbcLogin)) 'Choose only one login screen: J (Vanilla) or C (TBC).'
 Require (-not [string]::IsNullOrWhiteSpace($DestinationPath)) 'Choose an existing EMPTY folder for the fresh client.'
 $item=Get-Item -LiteralPath $DestinationPath -ErrorAction Stop
 Require ([bool]$item.PSIsContainer) 'Fresh client destination must be a folder.'
 $dest=[IO.Path]::GetFullPath($item.FullName).TrimEnd([char[]]@('\','/'))
 $repo=Split-Path -Parent $PSScriptRoot
 $repo=[IO.Path]::GetFullPath($repo).TrimEnd([char[]]@('\','/'))
 Require (-not (IsNested $dest $repo) -and -not (IsNested $repo $dest)) 'Fresh client destination must be separate from the launcher folder.'
 $drive=[IO.Path]::GetPathRoot($dest)
 Require (-not $dest.Equals($drive.TrimEnd([char[]]@('\','/')),[StringComparison]::OrdinalIgnoreCase)) 'Do not choose the drive root as the client destination.'
 foreach($protected in @($env:WINDIR,$env:ProgramFiles,[Environment]::GetEnvironmentVariable('ProgramFiles(x86)'))){
  if(-not [string]::IsNullOrWhiteSpace($protected)){
   $protected=[IO.Path]::GetFullPath($protected).TrimEnd([char[]]@('\','/'))
   Require (-not (IsNested $dest $protected) -and -not (IsNested $protected $dest)) 'Choose a normal new games folder, not a Windows system or program directory.'
  }
 }
 $walk=$dest
 while(-not [string]::IsNullOrWhiteSpace($walk)){
  $current=Get-Item -LiteralPath $walk -Force
  Require (-not ([bool]($current.Attributes -band [IO.FileAttributes]::ReparsePoint))) 'Linked/symlinked client destinations are not supported.'
  $parent=[IO.Directory]::GetParent($walk)
  if($null -eq $parent){break}
  $walk=$parent.FullName
 }
 $items=@(Get-ChildItem -LiteralPath $dest -Force -ErrorAction Stop)
 Require ($items.Count -eq 0) 'Fresh installation needs an EMPTY destination folder. Existing files will not be overwritten.'
 $manifest=Join-Path $repo 'config/base-client-source.json'
 Require (Test-Path -LiteralPath $manifest -PathType Leaf) 'Missing full-client source manifest.'
 $policy=Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json
 Require ([int]$policy.schema_version -eq 1 -and
  $policy.workflow -ceq 'full-client-fresh-install' -and
  [int]$policy.target.build -eq 12340 -and
  $policy.target.version -ceq '3.3.5a') 'Unsupported base-client source policy.'
 # This alpha must remain in the explicit blocked state even if somebody
 # edits the JSON; enabling a source requires a separately reviewed installer.
 Require ($policy.enabled -eq $false) 'Full client source manifest was enabled unexpectedly: reviewed installer implementation required.'
 Require ([string]$policy.state -ceq 'awaiting_verifiable_redistribution_authorisation') 'Unreviewed full-client source state: refusing to continue.'
 $seen=New-Object 'System.Collections.Generic.List[string]'
 foreach($name in @($Addons)){if(-not $seen.Contains($name)){$seen.Add($name)}}
 $login=if($VanillaLogin){'Vanilla Patch J'}elseif($TbcLogin){'Burning Crusade Patch C'}else{'Default Wrath login'}
 Write-Host 'FRESH CLIENT INSTALLATION PREVIEW (READ ONLY)'
 Write-Host "DESTINATION: $dest"
 Write-Host "TARGET: World of Warcraft $($policy.target.version) build $($policy.target.build) ($($policy.target.locale))"
 Write-Host 'BASE CLIENT: BLOCKED - NO VERIFIED AUTHORISED DOWNLOAD SOURCE.'
 Write-Host 'PLANNED COMPONENTS:'
 Write-Host '  1. Complete 3.3.5a client after source authorisation and SHA-256 verification'
 Write-Host '  2. Mandatory Naxxramas core patches V and Z'
 Write-Host "  3. Login visuals: $login"
 if($VanillaLoading){Write-Host '  4. Optional Vanilla loading screens: Patch U'}else{Write-Host '  4. Vanilla loading screens: not selected'}
 Write-Host '  5. N-Addon Collection: NCore required'
 if($seen.Count -gt 0){Write-Host ('  6. Optional addons: '+($seen -join ', '))}
 else{Write-Host '  6. Optional addons: not selected'}
 Write-Host '  7. Server realmlist (enUS) from config/realm.json'
 Write-Host '  8. Verified staging, protected backups, recovery and uninstall'
 Write-Host 'NO DOWNLOAD OR INSTALLATION WAS ATTEMPTED.'
 Write-Host 'FRESH CLIENT PLAN COMPLETE - BLOCKED UNTIL AUTHORISED SOURCE.'
 exit 0
}catch{
 Write-Host ('ERROR: '+$_.Exception.Message) -ForegroundColor Red
 Write-Host 'No files were created, downloaded, deleted or changed.' -ForegroundColor Yellow
 exit 1
}
