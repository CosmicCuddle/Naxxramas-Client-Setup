#requires -Version 5.1
<#
Naxxramas verified patch source downloader (never installs into WoW).
Plan: no writes. Download: explicit confirmation; writes to separate patch source only.
Developer-only synthetic fixture source uses marker-locked local copies for CI.
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$ClientPath,
 [Parameter(Mandatory=$true)][string]$PatchSourcePath,
 [ValidateSet('Plan','Download')][string]$Action='Plan',
 [switch]$VanillaLogin,
 [switch]$TbcLogin,
 [switch]$VanillaLoading,
 [switch]$ConfirmDownload,
 [switch]$SyntheticFixture,
 [string]$TestFixtureSourcePath
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
function Require([bool]$ok,[string]$message){if(-not $ok){throw $message}}
function Resolve-Folder([string]$path){
 Require (Test-Path -LiteralPath $path -PathType Container) "Choose an existing folder: $path"
 $item=Get-Item -LiteralPath $path -Force
 Require (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) "Linked folder forbidden: $path"
 return [IO.Path]::GetFullPath($item.FullName).TrimEnd([char[]]@('\','/'))
}
function Nested([string]$left,[string]$right){
 return $left.Equals($right,[StringComparison]::OrdinalIgnoreCase) -or
 $left.StartsWith(($right+[IO.Path]::DirectorySeparatorChar),[StringComparison]::OrdinalIgnoreCase)
}
function Refuse-Link([string]$path){
 if(Test-Path -LiteralPath $path) {
  Require (-not ((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) "Unsafe linked source or target: $path"
 }
}
function Digest([string]$path){
 return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Matches([string]$path,[object]$patch){
 Refuse-Link $path
 if(-not (Test-Path -LiteralPath $path -PathType Leaf)){return $false}
 return ([long](Get-Item -LiteralPath $path -Force).Length -eq [long]$patch.size_bytes) -and
  ((Digest $path) -ceq [string]$patch.sha256)
}
try {
 $repo=Split-Path -Parent $PSScriptRoot
 $client=Resolve-Folder $ClientPath
 $source=Resolve-Folder $PatchSourcePath
 Require (Test-Path -LiteralPath (Join-Path $client 'Wow.exe') -PathType Leaf) 'Client must contain Wow.exe.'
 Require (-not (Nested $source $client) -and -not (Nested $client $source)) 'Patch folder and WoW client must be separate, non-nested folders.'
 Require (-not (Nested $source $repo) -and -not (Nested $repo $source)) 'Patch folder must be outside the launcher repository and preview package.'
 Require (-not ($VanillaLogin -and $TbcLogin)) 'Only one login screen may be selected: J (Vanilla) or C (TBC).'
 $existingJ=Test-Path -LiteralPath (Join-Path $client 'Data/Patch-J.mpq') -PathType Leaf
 $existingC=Test-Path -LiteralPath (Join-Path $client 'Data/Patch-C.mpq') -PathType Leaf
 Require (-not ($existingJ -and $existingC)) 'Client already contains conflicting J and C login patches. Resolve manually after backups.'
 Require (-not ($TbcLogin -and $existingJ)) 'TBC C cannot be chosen while Vanilla J exists in the client.'
 Require (-not ($VanillaLogin -and $existingC)) 'Vanilla J cannot be chosen while TBC C exists in the client.'
 $policy=Get-Content -LiteralPath (Join-Path $repo 'config/client-patches.json') -Raw | ConvertFrom-Json
 $sources=Get-Content -LiteralPath (Join-Path $repo 'config/patch-downloads.json') -Raw | ConvertFrom-Json
 Require ([int]$policy.schema_version -eq 1 -and $policy.patch_set_version -ceq 'patchset-0002') 'Unsupported patchset version for patch source download.'
 Require ([int]$sources.schema_version -eq 1 -and $sources.version -ceq $policy.patch_set_version) 'Patch download links do not match the pinned patchset.'
 $allowed=@('Data/patch-V.mpq','Data/patch-Z.mpq','Data/Patch-J.mpq','Data/Patch-C.mpq','Data/Patch-U.mpq')
 Require (@($policy.patches).Count -eq 5 -and @($sources.entries).Count -eq 5) 'Unexpected patch manifest contents.'
 foreach($p in @($policy.patches)){
  $path=[string]$p.path
  Require ($allowed -ccontains $path) "Unrecognised patch in manifest: $path"
  Require (@($policy.patches | Where-Object {$_.path -ceq $path}).Count -eq 1) "Duplicate patch in manifest: $path"
  $links=@($sources.entries | Where-Object {$_.path -ceq $path})
  Require ($links.Count -eq 1) "Missing or repeated trusted download URL for: $path"
  $release=if($path -ceq 'Data/patch-V.mpq'){'v1.0.6.8.4'}elseif($path -ceq 'Data/patch-Z.mpq'){'v1.0.6.7'}else{'optional-v1.0'}
  $url='https://github.com/CosmicCuddle/Naxxramas-Server-Patches/releases/download/'+$release+'/'+[IO.Path]::GetFileName($path)
  Require ($links[0].url -ceq $url -and $links[0].release -ceq $release) "Non-pinned GitHub patch link: $path"
  Require ([string]$p.sha256 -cmatch '^[0-9a-f]{64}$' -and [long]$p.size_bytes -gt 0) "Missing pinned fingerprint: $path"
 }
 $fixture=$null
 if($TestFixtureSourcePath -or $SyntheticFixture){
  Require ($SyntheticFixture -and -not [string]::IsNullOrWhiteSpace($TestFixtureSourcePath)) 'Synthetic downloads require both fixture arguments.'
  $fixture=Resolve-Folder $TestFixtureSourcePath
  $mark='NAXX_PATCH_SOURCE_TEST_V1'
  foreach($where in @($repo,$client,$fixture)){
   Require ((Test-Path -LiteralPath (Join-Path $where '.naxx-download-test-fixture') -PathType Leaf) -and
    [IO.File]::ReadAllText((Join-Path $where '.naxx-download-test-fixture')).Trim() -ceq $mark) 'Synthetic downloads require marker-locked disposable fixtures.'
  }
  Require (-not (Nested $fixture $client) -and -not (Nested $fixture $source)) 'Test fixture sources must be separate.'
 }
 if($Action -eq 'Download'){
  Require ($ConfirmDownload) 'Downloading is opt-in. ConfirmDownload must be specified.'
 }
 $dataDir=Join-Path $source 'Data'
 Refuse-Link $dataDir
 $selection=@('Data/patch-V.mpq','Data/patch-Z.mpq')
 if($VanillaLogin){$selection+= 'Data/Patch-J.mpq'}
 if($TbcLogin){$selection+= 'Data/Patch-C.mpq'}
 if($VanillaLoading){$selection+= 'Data/Patch-U.mpq'}
 $work=New-Object 'System.Collections.Generic.List[object]'
 Write-Host "PATCH SOURCES: $($policy.patch_set_version)"
 Write-Host "DOWNLOAD DESTINATION: $source"
 foreach($path in $selection){
  $p=@($policy.patches | Where-Object {$_.path -ceq $path})[0]
  $destination=Join-Path $source ($path.Replace('/',[IO.Path]::DirectorySeparatorChar))
  $installed=Join-Path $client ($path.Replace('/',[IO.Path]::DirectorySeparatorChar))
  if(Matches $installed $p){Write-Host "ALREADY INSTALLED: $path";continue}
  if(Test-Path -LiteralPath $destination) {
   Require (Matches $destination $p) "Patch source file exists but has wrong size or hash. Refusing overwrite: $path"
   Write-Host "SOURCE VERIFIED: $path"
   continue
  }
  $item=@($sources.entries | Where-Object {$_.path -ceq $path})[0]
  $work.Add([pscustomobject]@{path=$path;patch=$p;url=[string]$item.url;destination=$destination})
  Write-Host ("DOWNLOAD NEEDED: {0} ({1:N1} MB)" -f $path,([long]$p.size_bytes/1MB))
 }
 Write-Host ("NEEDED: {0} patch download(s)" -f $work.Count)
 if($Action -eq 'Plan'){Write-Host 'PATCH DOWNLOAD PLAN COMPLETE. No files changed.';exit 0}
 if($work.Count -gt 0 -and -not (Test-Path -LiteralPath $dataDir)){
  New-Item -ItemType Directory -Path $dataDir -ErrorAction Stop | Out-Null
 }
 Refuse-Link $dataDir
 foreach($entry in @($work.ToArray())){
  Refuse-Link $entry.destination
  Require (-not (Test-Path -LiteralPath $entry.destination)) "Download destination appeared during operation: $($entry.path)"
  $temporary=Join-Path $dataDir ('.naxx-download-'+[guid]::NewGuid().ToString('N')+'.partial')
  try{
   if($SyntheticFixture){
    $fake=Join-Path $fixture ($entry.path.Replace('/',[IO.Path]::DirectorySeparatorChar))
    Refuse-Link $fake
    Require (Test-Path -LiteralPath $fake -PathType Leaf) "Missing synthetic patch source: $($entry.path)"
    Copy-Item -LiteralPath $fake -Destination $temporary -ErrorAction Stop
   }else{
    Write-Host "Fetching official release: $($entry.url)"
    [Net.ServicePointManager]::SecurityProtocol=[Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -UseBasicParsing -Uri $entry.url -OutFile $temporary -MaximumRedirection 5 -TimeoutSec 180 -ErrorAction Stop | Out-Null
   }
   Require (Matches $temporary $entry.patch) "Downloaded data failed SHA-256 or size verification: $($entry.path)"
   Require (-not (Test-Path -LiteralPath $entry.destination)) "Download destination became occupied: $($entry.path)"
   Move-Item -LiteralPath $temporary -Destination $entry.destination -ErrorAction Stop
   Write-Host "DOWNLOADED AND VERIFIED: $($entry.path)"
  }finally{
   if(Test-Path -LiteralPath $temporary){Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue}
  }
 }
 Write-Host 'PATCH DOWNLOAD COMPLETE. Patch files saved ONLY in the separate source folder; the WoW client was not modified.'
 exit 0
}catch{
 Write-Host ('ERROR: '+$_.Exception.Message) -ForegroundColor Red
 Write-Host 'No WoW client changes were made. Check the separate patch source folder.' -ForegroundColor Yellow
 exit 1
}
