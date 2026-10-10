#requires -Version 5.1
<#
.SYNOPSIS
  Offline, guarded extraction of a pinned N Addon Suite ZIP into a NEW folder.
.DESCRIPTION
  Default action is a read-only preview. -Extract writes ONLY to a newly created
  standalone addon source folder, never to World of Warcraft.
  The extracted folder is NOT automatically trusted for production installation.
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$ArchivePath,
 [Parameter(Mandatory=$true)][string]$OutputParent,
 [switch]$Extract
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$stage = $null
$archive = $null
function Assert([bool]$test,[string]$message) { if (-not $test) { throw $message } }
function Check-Parent([string]$path) {
 $resolved = (Resolve-Path -LiteralPath $path -ErrorAction Stop).ProviderPath
 Assert (Test-Path -LiteralPath $resolved -PathType Container) 'OutputParent must already exist as a folder.'
 $dir = Get-Item -LiteralPath $resolved
 while ($null -ne $dir) {
  Assert (-not ($dir.Attributes -band [IO.FileAttributes]::ReparsePoint)) 'Output path contains a symlink or junction.'
  Assert (-not (Test-Path -LiteralPath (Join-Path $dir.FullName 'Wow.exe') -PathType Leaf)) 'Extraction into or below a WoW client is blocked.'
  $dir = $dir.Parent
 }
 return [IO.Path]::GetFullPath($resolved)
}
function Check-EntryName([string]$p) {
 Assert (-not [string]::IsNullOrWhiteSpace($p)) 'ZIP contains an empty entry name.'
 $p = $p.Replace('\','/') # Canonicalise Windows and POSIX ZIP separators before validation.
 Assert (-not $p.StartsWith('/') -and -not $p.StartsWith('//') -and -not $p.Contains(':')) 'ZIP contains an absolute or drive-qualified path.'
 $clean = $p.TrimEnd('/')
 $components = $clean.Split('/')
 Assert ($components.Count -gt 0) 'ZIP contains an empty entry.'
 foreach ($part in $components) {
  Assert ($part -and $part -ne '.' -and $part -ne '..') 'ZIP contains a traversal component.'
  Assert ($part -notmatch '[<>:"|?*\x00-\x1f]' -and
    -not $part.EndsWith(' ') -and -not $part.EndsWith('.')) 'ZIP contains an invalid Windows path component.'
  Assert ($part -notmatch '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\..*)?$') 'ZIP contains a reserved Windows device name.'
 }
 return $clean
}
try {
 $repo = Split-Path -Parent $PSScriptRoot
 $config = Get-Content -LiteralPath (Join-Path $repo 'config/addon-suite.json') -Raw | ConvertFrom-Json
 Assert ($config.schema_version -eq 1 -and $config.reference_release -ceq 'v2.0.0') 'Unsupported addon suite policy.'
 Assert ([string]$config.release_archive_sha256 -match '^[0-9a-f]{64}$') 'Expected SHA-256 is missing.'
 $item = Get-Item -LiteralPath $ArchivePath -ErrorAction Stop
 Assert (-not $item.PSIsContainer -and $item.Extension -ieq '.zip') 'Select a local ZIP file.'
 Assert (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) 'Linked archives are not supported.'
 Assert ([long]$item.Length -eq [long]$config.release_archive_size_bytes) 'ZIP does not match expected release size.'
 $sha = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
 Assert ($sha -ceq [string]$config.release_archive_sha256) 'ZIP SHA-256 mismatch; no extraction allowed.'
 $parent = Check-Parent $OutputParent
 $dest = Join-Path $parent 'NAddonSuite-v2.0.0-extracted'
 Assert (-not (Test-Path -LiteralPath $dest)) 'Destination already exists. No files were overwritten.'
 Assert (-not ($item.FullName.StartsWith(($parent+[IO.Path]::DirectorySeparatorChar),
  [StringComparison]::OrdinalIgnoreCase) -and $item.DirectoryName -eq $dest)) 'Archive source overlaps destination.'
 Add-Type -AssemblyName System.IO.Compression.FileSystem
 $archive = [IO.Compression.ZipFile]::OpenRead($item.FullName)
 $entries = @($archive.Entries)
 Assert ($entries.Count -le 15000) 'Unexpected number of archive entries.'
 $paths = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
 $folders = @('NCore','IndividualProgressionAddon','DungeonJournal','MultiBot','NaxxLootLottery')
 $extracted = New-Object 'System.Collections.Generic.List[object]'
 $layout = $null
 $totalSize = [long]0
 foreach ($entry in $entries) {
  $name = Check-EntryName ([string]$entry.FullName)
  Assert ($paths.Add($name)) "Duplicate or case-colliding ZIP path: $name"
  $unixType = ([int64]$entry.ExternalAttributes -shr 16) -band 61440
  Assert ($unixType -ne 40960) 'Archive contains a symbolic-link entry.'
  $isDir = $entry.FullName.EndsWith('/') -or $entry.FullName.EndsWith('\')
  if ($isDir) { continue }
  Assert ([long]$entry.Length -le 157286400) 'Archive contains an excessively large single file.'
  $totalSize += [long]$entry.Length
  Assert ($totalSize -le 2147483648) 'Archive decompressed size exceeds safety limit.'
  if ($entry.Length -gt 1048576) {
   Assert ($entry.CompressedLength -gt 0 -and
    ([double]$entry.Length / [double]$entry.CompressedLength) -le 500) 'Suspicious compression ratio in archive.'
  }
  $prefix = $null
  if ($name -match '^Interface/AddOns/(NCore|IndividualProgressionAddon|DungeonJournal|MultiBot|NaxxLootLottery)/(.+)$') {
   $prefix = 'Interface/AddOns/'
   $folder = $Matches[1]
   $relative = $folder + '/' + $Matches[2]
  } elseif ($name -match '^(NCore|IndividualProgressionAddon|DungeonJournal|MultiBot|NaxxLootLottery)/(.+)$') {
   $prefix = ''
   $folder = $Matches[1]
   $relative = $name
  } else {
   # Ancillary documentation is not installed. It is still subject to path validation.
   continue
  }
  if ($null -eq $layout) { $layout = $prefix }
  Assert ($layout -ceq $prefix) 'ZIP mixes incompatible addon root layouts.'
  [void](Check-EntryName $relative)
  $extracted.Add([pscustomobject]@{entry=$entry;relative=$relative;length=[long]$entry.Length})
 }
 Assert ($extracted.Count -gt 0) 'No supported addon files found.'
 foreach ($name in $folders) {
  $toc = $name+'/'+$name+'.toc'
  Assert (@($extracted | Where-Object { $_.relative -ceq $toc }).Count -eq 1) "Missing expected addon TOC: $toc"
 }
 Write-Host "VERIFIED ZIP: $($config.release_asset_name)" -ForegroundColor Green
 Write-Host ("INSTALLABLE ADDON FILES: {0}" -f $extracted.Count)
 Write-Host ("TOTAL EXTRACTED BYTES: {0}" -f $totalSize)
 Write-Host "OUTPUT DIRECTORY: $dest"
 if (-not $Extract) { Write-Host 'READ-ONLY PREVIEW COMPLETE. No files changed.' -ForegroundColor Green; exit 0 }
 # Extraction creates a disposable temporary folder beside the final output.
 $stage = Join-Path $parent ('.naxx-extract-'+[guid]::NewGuid().ToString('N'))
 [void][IO.Directory]::CreateDirectory($stage)
 $report = New-Object 'System.Collections.Generic.List[object]'
 foreach ($e in $extracted) {
  $sub = $e.relative.Replace('/',[IO.Path]::DirectorySeparatorChar)
  $target = Join-Path $stage $sub
  $folderPath = Split-Path -Parent $target
  [void][IO.Directory]::CreateDirectory($folderPath)
  Assert (-not (Test-Path -LiteralPath $target)) 'Unexpected duplicate extraction target.'
  $reader = $e.entry.Open()
  $writer = [IO.File]::Open($target,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write)
  $written=[long]0
  try {
   $buffer=New-Object byte[] 81920
   while (($n=$reader.Read($buffer,0,$buffer.Length)) -gt 0) {
    $written += [long]$n
    Assert ($written -le [long]$e.length) 'Archive entry expanded beyond declared size.'
    $writer.Write($buffer,0,$n)
   }
  } finally { $writer.Dispose(); $reader.Dispose() }
  Assert ($written -eq [long]$e.length) 'Incomplete ZIP entry extraction.'
  $digest=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
  $report.Add([pscustomobject]@{path=$e.relative;size_bytes=$written;sha256=$digest})
 }
 # The report is informational; it is not a durable trust certificate for later edits.
 $outputReport=[ordered]@{
  schema_version=1
  release='v2.0.0'
  zip_sha256=$sha
  verified_at_utc=(Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
  note='Verified at extraction time only. A later change to this folder invalidates its provenance.'
  files=@($report.ToArray())
 }
 $reportPath=Join-Path $stage 'EXTRACTION-REPORT.json'
 [IO.File]::WriteAllText($reportPath,($outputReport|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
 Assert (-not (Test-Path -LiteralPath $dest)) 'Destination appeared during extraction; refusing overwrite.'
 [IO.Directory]::Move($stage,$dest)
 $stage=$null
 Write-Host 'EXTRACTION COMPLETE. No existing files were overwritten.' -ForegroundColor Green
 Write-Warning 'The extracted directory is not automatically authenticated for the production installer.'
} catch {
 Write-Host ("ERROR: "+$_.Exception.Message) -ForegroundColor Red
 exit 1
} finally {
 if ($null -ne $archive) { $archive.Dispose() }
 if ($stage -and (Test-Path -LiteralPath $stage)) {
  # Delete only the fresh script-owned staging directory on an unsuccessful run.
  Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
 }
}
