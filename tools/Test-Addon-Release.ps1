#requires -Version 5.1
<#
 Read-only local verification of an N Addon Suite release ZIP.
 Checks official release metadata fingerprint and expected addon TOCs.
 Does not extract, install, modify or upload any files.
#>
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ArchivePath)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
try {
 $configPath=Join-Path (Split-Path -Parent $PSScriptRoot) 'config/addon-suite.json'
 $config=Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
 if ($config.schema_version -ne 1 -or $config.reference_release -ne 'v2.0.0' -or
     $config.release_archive_sha256 -notmatch '^[a-f0-9]{64}$' -or
     [long]$config.release_archive_size_bytes -le 0) {
  throw 'Missing or invalid expected release metadata.'
 }
 $item=Get-Item -LiteralPath $ArchivePath -ErrorAction Stop
 if ($item.PSIsContainer -or $item.Extension -ine '.zip') {throw 'Select the downloaded suite ZIP file, not a folder.'}
 if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {throw 'Linked archive files are not supported.'}
 if ($item.Length -ne [long]$config.release_archive_size_bytes) {
  throw ('ZIP size mismatch. Expected {0} bytes; found {1} bytes.' -f $config.release_archive_size_bytes,$item.Length)
 }
 $hash=(Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
 if ($hash -cne [string]$config.release_archive_sha256) {throw 'ZIP SHA-256 mismatch; refuse to use this archive.'}
 Add-Type -AssemblyName System.IO.Compression.FileSystem
 $archive=[IO.Compression.ZipFile]::OpenRead($item.FullName)
 try {
  $paths=@($archive.Entries | ForEach-Object {$_.FullName.Replace('\','/')})
  if ($paths.Count -gt 15000) { throw 'ZIP has an unexpected number of entries.' }
  foreach ($p in $paths) {
   if ($p.StartsWith('/') -or $p -match '(^|/)\.\.?(/|$)' -or $p -match '^[A-Za-z]:') {
    throw 'ZIP contains an unsafe path.'
   }
  }
  $expected=@('NCore','IndividualProgressionAddon','DungeonJournal','MultiBot','NaxxLootLottery')
  foreach($folder in $expected) {
   $toc=$folder+'/'+$folder+'.toc'
   if (-not @($paths | Where-Object {$_ -ceq $toc -or $_ -ceq ('Interface/AddOns/'+$toc)}).Count) {
    throw "Missing expected addon TOC within release ZIP: $toc"
   }
  }
 }
 finally { $archive.Dispose() }
 Write-Host ("VERIFIED: {0}" -f $config.release_asset_name) -ForegroundColor Green
 Write-Host ("Release: {0}; size: {1} bytes" -f $config.reference_release,$item.Length)
 Write-Host "SHA-256: $hash"
 Write-Host 'Read-only check complete. No files were changed.'
 Write-Warning 'This validates the ZIP against the recorded GitHub release fingerprint, but not any separately extracted addon folder.'
 exit 0
}
catch {
 Write-Host ("ERROR: " + $_.Exception.Message) -ForegroundColor Red
 exit 1
}
