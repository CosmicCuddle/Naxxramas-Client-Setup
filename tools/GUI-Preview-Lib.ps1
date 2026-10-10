#requires -Version 5.1
<#
Pure argument-building helpers for the read-only Windows preview GUI.
No file operations or actual installer writes are performed here.
#>
Set-StrictMode -Version Latest
function New-NaxxPreviewRequest {
 [CmdletBinding()]
 param(
  [Parameter(Mandatory=$true)][ValidateSet('Plan','Inspect')][string]$Mode,
  [Parameter(Mandatory=$true)][string]$ClientPath,
  [string]$PatchSourcePath,
  [string]$AddonSuiteArchivePath,
  [bool]$VanillaLogin=$false,
  [bool]$TbcLogin=$false,
  [bool]$VanillaLoading=$false,
  [string[]]$Addons=@(),
  [string]$RepositoryPath=(Split-Path -Parent $PSScriptRoot)
 )
 if ($Mode -eq 'Plan' -and $VanillaLogin -and $TbcLogin) { throw 'Choose only one login screen (J or C).' }
 $client=$ClientPath.Trim()
 if (-not $client -or -not (Test-Path -LiteralPath $client -PathType Container)) {
  throw 'Choose an existing WoW client folder.'
 }
 $client=(Resolve-Path -LiteralPath $client).ProviderPath
 if (-not (Test-Path -LiteralPath (Join-Path $client 'Wow.exe') -PathType Leaf)) {
  throw 'The selected folder must contain Wow.exe.'
 }
 $script=Join-Path (Join-Path $RepositoryPath 'tools') 'Setup-Prototype.ps1'
 if (-not (Test-Path -LiteralPath $script -PathType Leaf)) {
  throw 'Setup-Prototype.ps1 is missing. Download a complete repository ZIP.'
 }
 # Intentionally never accept Apply, ConfirmDisposableFixture, Install, Rollback,
 # Recover, or any simulated failure switches from the GUI.
 $arguments=@{Action=$Mode;ClientPath=$client}
 if ($Mode -ceq 'Plan') {
  if (-not [string]::IsNullOrWhiteSpace($PatchSourcePath)) {
   if (-not (Test-Path -LiteralPath $PatchSourcePath -PathType Container)) {
    throw 'Patch source must be an existing separate folder.'
   }
   $arguments.PatchSourcePath=(Resolve-Path -LiteralPath $PatchSourcePath).ProviderPath
  }
  if (-not [string]::IsNullOrWhiteSpace($AddonSuiteArchivePath)) {
   if (-not (Test-Path -LiteralPath $AddonSuiteArchivePath -PathType Leaf)) {
    throw 'Select an existing N Addon Suite ZIP file.'
   }
   if ([IO.Path]::GetExtension($AddonSuiteArchivePath) -ine '.zip') {
    throw 'The addon source must be a .zip archive.'
   }
   $arguments.AddonSuiteArchivePath=(Resolve-Path -LiteralPath $AddonSuiteArchivePath).ProviderPath
  }
  if ($VanillaLogin) { $arguments.VanillaLogin=$true }
  if ($TbcLogin) { $arguments.TbcLogin=$true }
  if ($VanillaLoading) { $arguments.VanillaLoading=$true }
  $allowed=@('IndividualProgressionAddon','DungeonJournal','MultiBot','NaxxLootLottery')
  $chosen=New-Object 'System.Collections.Generic.List[string]'
  foreach($name in @($Addons)) {
   if ($allowed -cnotcontains $name) { throw "Unrecognised addon: $name" }
   if (-not $chosen.Contains($name)) { $chosen.Add($name) }
  }
  if ($chosen.Count -gt 0 -and -not $arguments.ContainsKey('AddonSuiteArchivePath')) {
   throw 'Choose an official N Addon Suite ZIP before selecting optional addons.'
  }
  if ($chosen.Count -gt 0) { $arguments.Addons=@($chosen.ToArray()) }
 }
 return [pscustomobject]@{
  ScriptPath=$script
  Parameters=$arguments
  Mode=$Mode
 }
}


# Downloading is distinct from read-only Plan/Inspect and never writes the client.
function New-NaxxSourceDownloadRequest {
 [CmdletBinding()]
 param(
  [Parameter(Mandatory=$true)][string]$ClientPath,
  [Parameter(Mandatory=$true)][string]$PatchSourcePath,
  [bool]$VanillaLogin=$false,
  [bool]$TbcLogin=$false,
  [bool]$VanillaLoading=$false,
  [string]$RepositoryPath=(Split-Path -Parent $PSScriptRoot)
 )
 if([string]::IsNullOrWhiteSpace($PatchSourcePath)){
  throw 'Choose an existing separate patch source folder before downloading.'
 }
 $readonly=New-NaxxPreviewRequest -Mode Plan -ClientPath $ClientPath -PatchSourcePath $PatchSourcePath -VanillaLogin $VanillaLogin -TbcLogin $TbcLogin -VanillaLoading $VanillaLoading -RepositoryPath $RepositoryPath
 $engine=Join-Path (Join-Path $RepositoryPath 'tools') 'Get-Patch-Sources.ps1'
 if(-not (Test-Path -LiteralPath $engine -PathType Leaf)){
  throw 'Get-Patch-Sources.ps1 is missing. Download the complete current launcher ZIP.'
 }
 $parameters=@{
  Action='Download'
  ConfirmDownload=$true
  ClientPath=$readonly.Parameters.ClientPath
  PatchSourcePath=$readonly.Parameters.PatchSourcePath
 }
 if($VanillaLogin){$parameters.VanillaLogin=$true}
 if($TbcLogin){$parameters.TbcLogin=$true}
 if($VanillaLoading){$parameters.VanillaLoading=$true}
 return [pscustomobject]@{ScriptPath=$engine;Parameters=$parameters;Mode='Download'}
}
