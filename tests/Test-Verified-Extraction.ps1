#requires -Version 5.1
# Test only synthetic ZIPs and fake folders; never use real addon assets.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
$extractor=Join-Path $repo 'tools/Extract-Verified-Addon-Suite.ps1'
$tokens=$null;$errors=$null
[Management.Automation.Language.Parser]::ParseFile($extractor,[ref]$tokens,[ref]$errors)|Out-Null
if (@($errors).Count -ne 0) {throw ("Extractor syntax errors: "+($errors -join '; '))}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root=Join-Path ([IO.Path]::GetTempPath()) ('naxx-extract-fixture-'+[guid]::NewGuid().ToString('N'))
try {
 foreach($p in @('repo/tools','repo/config','source','output','bad-output','bad-game')) {
  New-Item -ItemType Directory -Path (Join-Path $root $p) -Force|Out-Null
 }
 Copy-Item -LiteralPath $extractor -Destination (Join-Path $root 'repo/tools/Extract-Verified-Addon-Suite.ps1')
 $folders=@('NCore','IndividualProgressionAddon','DungeonJournal','MultiBot','NaxxLootLottery')
 foreach($name in $folders) {
  $p=Join-Path $root ('source/'+$name)
  New-Item -ItemType Directory -Path $p -Force|Out-Null
  [IO.File]::WriteAllText((Join-Path $p ($name+'.toc')),'## Interface: 30300')
  [IO.File]::WriteAllText((Join-Path $p ($name+'.lua')),'print("synthetic")')
 }
 $zip=Join-Path $root 'synthetic-v2.zip'
 [IO.Compression.ZipFile]::CreateFromDirectory((Join-Path $root 'source'),$zip)
 $original=Get-Content -LiteralPath (Join-Path $repo 'config/addon-suite.json') -Raw|ConvertFrom-Json
 $cfg=$original|ConvertTo-Json -Depth 10|ConvertFrom-Json
 $cfg.release_archive_size_bytes=(Get-Item -LiteralPath $zip).Length
 $cfg.release_archive_sha256=(Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
 $cfgPath=Join-Path $root 'repo/config/addon-suite.json'
 $cfg|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $cfgPath -Encoding UTF8
 $script=Join-Path $root 'repo/tools/Extract-Verified-Addon-Suite.ps1'
 function Run([string]$archivePath,[string]$parent,[bool]$extract) {
  $argsList=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$script,'-ArchivePath',$archivePath,'-OutputParent',$parent)
  if ($extract) {$argsList+=@('-Extract')}
  $message=(& powershell.exe @argsList 2>&1|Out-String)
  return [pscustomobject]@{exit=$LASTEXITCODE;output=$message}
 }
 $parent=Join-Path $root 'output'
 $folder=Join-Path $parent 'NAddonSuite-v2.0.0-extracted'
 $r=Run $zip $parent $false
 if ($r.exit -ne 0 -or -not $r.output.Contains('READ-ONLY PREVIEW COMPLETE')) {throw ("Read-only extractor plan failed: "+$r.output)}
 if (Test-Path -LiteralPath $folder) {throw 'Preview wrote extracted addon files.'}
 $r=Run $zip $parent $true
 if ($r.exit -ne 0 -or -not $r.output.Contains('EXTRACTION COMPLETE')) {throw ("Verified synthetic extraction failed: "+$r.output)}
 foreach($name in $folders) {
  foreach($suffix in @('.toc','.lua')) {
   if (-not (Test-Path -LiteralPath (Join-Path $folder ($name+'/'+$name+$suffix)) -PathType Leaf)) {
    throw "Missing extracted synthetic addon file: $name$suffix"
   }
  }
 }
 $report=Get-Content -LiteralPath (Join-Path $folder 'EXTRACTION-REPORT.json') -Raw|ConvertFrom-Json
 if ($report.zip_sha256 -ne $cfg.release_archive_sha256 -or @($report.files).Count -ne 10) {
  throw 'Extraction report has incorrect file inventory.'
 }
 $first=(Get-FileHash -LiteralPath (Join-Path $folder 'NCore/NCore.toc')).Hash
 $r=Run $zip $parent $true
 if ($r.exit -eq 0 -or -not $r.output.Contains('Destination already exists')) {
  throw 'Extractor overwrote existing output.'
 }
 if ((Get-FileHash -LiteralPath (Join-Path $folder 'NCore/NCore.toc')).Hash -ne $first) {
  throw 'Existing output was modified.'
 }
 $other=Join-Path $root 'bad-output'
 [IO.File]::WriteAllText((Join-Path $other 'Wow.exe'),'synthetic')
 $r=Run $zip $other $true
 if ($r.exit -eq 0 -or -not $r.output.Contains('WoW client is blocked')) {
  throw 'Extractor allowed writes into a fake game folder.'
 }
 $tamper=Join-Path $root 'modified.zip'
 Copy-Item -LiteralPath $zip -Destination $tamper
 $bytes=[IO.File]::ReadAllBytes($tamper)
 $bytes[$bytes.Length-1]=$bytes[$bytes.Length-1] -bxor 1
 [IO.File]::WriteAllBytes($tamper,$bytes)
 $r=Run $tamper $other $true
 if ($r.exit -eq 0 -or -not $r.output.Contains('SHA-256 mismatch')) {
  throw 'Modified archive did not fail checksum verification.'
 }
 # Verify that traversal is rejected even when its hash is pinned in a synthetic manifest.
 $safeBad=Join-Path $root 'nonclient-output'
 New-Item -ItemType Directory -Path $safeBad -Force|Out-Null
 $badzip=Join-Path $root 'traversal.zip'
 $z=[IO.Compression.ZipFile]::Open($badzip,[IO.Compression.ZipArchiveMode]::Create)
 try {
  $e=$z.CreateEntry('../outside.txt')
  $writer=[IO.StreamWriter]::new($e.Open())
  try {$writer.Write('not allowed')}finally{$writer.Dispose()}
 }finally{$z.Dispose()}
 $cfg.release_archive_size_bytes=(Get-Item -LiteralPath $badzip).Length
 $cfg.release_archive_sha256=(Get-FileHash -LiteralPath $badzip -Algorithm SHA256).Hash.ToLowerInvariant()
 $cfg|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $cfgPath -Encoding UTF8
 $r=Run $badzip $safeBad $true
 if ($r.exit -eq 0 -or -not $r.output.Contains('traversal')) {
  throw 'Traversal path passed ZIP validation.'
 }
 # Test case-insensitive duplicate files before extracting.
 $dupe=Join-Path $root 'duplicate.zip'
 $z=[IO.Compression.ZipFile]::Open($dupe,[IO.Compression.ZipArchiveMode]::Create)
 try{
  foreach($n in @('NCore/NCore.toc','NCore/ncore.toc')) {
   $e=$z.CreateEntry($n)
   $w=[IO.StreamWriter]::new($e.Open())
   try{$w.Write('fake')}finally{$w.Dispose()}
  }
 }finally{$z.Dispose()}
 $cfg.release_archive_size_bytes=(Get-Item -LiteralPath $dupe).Length
 $cfg.release_archive_sha256=(Get-FileHash -LiteralPath $dupe -Algorithm SHA256).Hash.ToLowerInvariant()
 $cfg|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $cfgPath -Encoding UTF8
 $r=Run $dupe $safeBad $true
 if ($r.exit -eq 0 -or -not $r.output.Contains('Duplicate or case-colliding')) {
  throw ('Case-insensitive duplicate was not blocked: '+$r.output)
 }
 Write-Host 'ALL VERIFIED ZIP EXTRACTION FIXTURE TESTS PASSED' -ForegroundColor Green
}finally{
 if (Test-Path -LiteralPath $root) {Remove-Item -LiteralPath $root -Recurse -Force}
}
exit 0
