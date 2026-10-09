#requires -Version 5.1
# Pure verification and read-only streaming access to the pinned addon release ZIP.
# Called only by the disposable-fixture prototype. No downloads or extraction.
function Check-ZipName([string]$name) {
 if ([string]::IsNullOrWhiteSpace($name)) { throw 'ZIP has an empty entry name.' }
 $path=$name.Replace('\','/')
 if ($path.StartsWith('/') -or $path.Contains(':') -or $path.StartsWith('//')) { throw "Unsafe ZIP entry path: $path" }
 $clean=$path.TrimEnd('/')
 foreach ($part in $clean.Split('/')) {
  if (-not $part -or $part -eq '.' -or $part -eq '..' -or
      $part -match '[<>:"|?*\x00-\x1f]' -or $part.EndsWith(' ') -or
      $part.EndsWith('.') -or
      $part -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\..*)?$') {
   throw "Unsafe ZIP entry path: $path"
  }
 }
 return $path
}
function Hash-ArchiveEntry([IO.Compression.ZipArchiveEntry]$entry) {
 $stream=$entry.Open()
 $sha=[Security.Cryptography.SHA256]::Create()
 try {
  $hash=[BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','').ToLowerInvariant()
  return $hash
 } finally { $stream.Dispose(); $sha.Dispose() }
}
function Open-VerifiedAddonZip([string]$path,[object]$metadata) {
 if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'Select a local N Addon Suite ZIP.' }
 $item=Get-Item -LiteralPath $path -Force
 if ($item.Extension -ine '.zip' -or
     ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
  throw 'Addon ZIP is not a regular .zip file.'
 }
 if ($metadata.reference_release -cne 'v2.0.0' -or
     [string]$metadata.release_archive_sha256 -notmatch '^[0-9a-f]{64}$' -or
     [long]$metadata.release_archive_size_bytes -le 0) { throw 'Unknown or unpinned suite ZIP reference.' }
 if ([long]$item.Length -ne [long]$metadata.release_archive_size_bytes) { throw 'Addon ZIP file size differs from the approved release.' }
 $archiveHash=(Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
 if ($archiveHash -cne [string]$metadata.release_archive_sha256) { throw 'Addon ZIP SHA-256 mismatch; installation blocked.' }
 Add-Type -AssemblyName System.IO.Compression.FileSystem
 $archive=[IO.Compression.ZipFile]::OpenRead($item.FullName)
 try {
  # Keep the archive open with FileShare.Read to prevent normal modification
  # between validation and the subsequent staging of individual addon files.
  $seen=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
  $files=New-Object 'System.Collections.Generic.List[object]'
  $layout=$null
  $total=[long]0
  $entries=@($archive.Entries)
  if ($entries.Count -gt 15000) { throw 'Addon ZIP contains too many entries.' }
  foreach($entry in $entries) {
   $path=Check-ZipName ([string]$entry.FullName)
   $name=$path.TrimEnd('/')
   if (-not $seen.Add($name)) { throw "ZIP contains duplicate or case-colliding paths: $name" }
   $unixKind=([int64]$entry.ExternalAttributes -shr 16) -band 61440
   if ($unixKind -eq 40960) { throw "ZIP contains a symbolic link: $name" }
   if ($path.EndsWith('/')) { continue }
   if ([long]$entry.Length -gt 157286400) { throw "Oversized addon ZIP member: $name" }
   $total += [long]$entry.Length
   if ($total -gt 2147483648) { throw 'Addon ZIP exceeds the unpacked size limit.' }
   if ($entry.Length -gt 1048576 -and
      ($entry.CompressedLength -le 0 -or
       ([double]$entry.Length/[double]$entry.CompressedLength) -gt 500)) {
    throw 'Suspicious ZIP compression ratio.'
   }
   if ($name -cmatch '^Interface/AddOns/(NCore|IndividualProgressionAddon|DungeonJournal|MultiBot|NaxxLootLottery)/(.+)$') {
    $prefix='Interface/AddOns/'
    $folder=$Matches[1]
    $relative=$folder+'/'+$Matches[2]
   } elseif ($name -cmatch '^(NCore|IndividualProgressionAddon|DungeonJournal|MultiBot|NaxxLootLottery)/(.+)$') {
    $prefix=''
    $folder=$Matches[1]
    $relative=$name
   } else { continue }
   if ($null -eq $layout) { $layout=$prefix }
   if ($layout -cne $prefix) { throw 'Mixed addon ZIP root layouts.' }
   $files.Add([pscustomobject]@{relative=$relative;folder=$folder;entry=$entry;size_bytes=[long]$entry.Length})
  }
  foreach($folder in @('NCore','IndividualProgressionAddon','DungeonJournal','MultiBot','NaxxLootLottery')) {
   $toc=$folder+'/'+$folder+'.toc'
   if (@($files | Where-Object {$_.relative -ceq $toc}).Count -ne 1) { throw "Addon ZIP is missing required $toc" }
  }
  return [pscustomobject]@{archive=$archive;files=@($files.ToArray());zip_sha256=$archiveHash}
 } catch { $archive.Dispose(); throw }
}
function Stage-VerifiedAddonEntry([IO.Compression.ZipArchiveEntry]$entry,[string]$dest,[string]$expectedHash,[long]$expectedSize) {
 $parent=Split-Path -Parent $dest
 if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
  [void][IO.Directory]::CreateDirectory($parent)
 }
 if (Test-Path -LiteralPath $dest) { throw 'Refusing to overwrite an existing staged addon file.' }
 $sourceStream=$entry.Open()
 $targetStream=$null
 $bytesRead=[long]0
 try {
  $targetStream=[IO.File]::Open($dest,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write)
  $buffer=New-Object byte[] 81920
  while (($n=$sourceStream.Read($buffer,0,$buffer.Length)) -gt 0) {
   $bytesRead += [long]$n
   if ($bytesRead -gt $expectedSize) { throw 'Addon ZIP decompressed beyond its declared size.' }
   $targetStream.Write($buffer,0,$n)
  }
 } finally {
  if ($null -ne $targetStream) { $targetStream.Dispose() }
  $sourceStream.Dispose()
 }
 if ($bytesRead -ne $expectedSize -or
     (Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash.ToLowerInvariant() -cne $expectedHash) {
  throw 'Staged addon file does not match verified ZIP entry.'
 }
}
