#requires -Version 5.1
# Synthetic ZIP test only. No real addon binaries downloaded.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
$verifier=Join-Path $repo 'tools/Test-Addon-Release.ps1'
$tokens=$null;$errors=$null
[Management.Automation.Language.Parser]::ParseFile($verifier,[ref]$tokens,[ref]$errors) | Out-Null
if (@($errors).Count -gt 0) {throw ("Addon verifier PowerShell syntax errors: "+($errors -join '; '))}
$real=Get-Content -LiteralPath (Join-Path $repo 'config/addon-suite.json') -Raw | ConvertFrom-Json
if ($real.reference_release -ne 'v2.0.0' -or $real.release_archive_sha256 -notmatch '^[a-f0-9]{64}$' -or
    $real.release_asset_name -ne 'N-Addon-Collection-v2.0.0.zip' -or
    [long]$real.release_archive_size_bytes -le 0) {
 throw 'Official N Addon Suite v2.0.0 reference is not pinned.'
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root=Join-Path ([IO.Path]::GetTempPath()) ('naxx-ziptest-'+[guid]::NewGuid().ToString('N'))
try {
 $fakeRepo=Join-Path $root 'repo';$source=Join-Path $root 'source'
 foreach($p in @('repo/config','repo/tools','source')) {
  New-Item -Path (Join-Path $root $p) -ItemType Directory -Force | Out-Null
 }
 Copy-Item -LiteralPath $verifier -Destination (Join-Path $fakeRepo 'tools/Test-Addon-Release.ps1')
 $names=@('NCore','IndividualProgressionAddon','DungeonJournal','MultiBot','NaxxLootLottery')
 foreach($name in $names) {
  $path=Join-Path $source $name
  New-Item -Path $path -ItemType Directory -Force | Out-Null
  [IO.File]::WriteAllText((Join-Path $path ($name+'.toc')),'## Interface: 30300')
 }
 $zip=Join-Path $root 'N-Addon-Collection-v2.0.0.zip'
 [IO.Compression.ZipFile]::CreateFromDirectory($source,$zip)
 $fake=$real | ConvertTo-Json -Depth 10 | ConvertFrom-Json
 $fake.release_archive_sha256=(Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
 $fake.release_archive_size_bytes=(Get-Item -LiteralPath $zip).Length
 $configPath=Join-Path $fakeRepo 'config/addon-suite.json'
 $fake | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $configPath -Encoding UTF8
 $tool=Join-Path $fakeRepo 'tools/Test-Addon-Release.ps1'
 function CheckZip([string]$selectedZip) {
  $output=(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tool -ArchivePath $selectedZip 2>&1 | Out-String)
  return [pscustomobject]@{code=$LASTEXITCODE;text=$output}
 }
 $result=CheckZip $zip
 if ($result.code -ne 0 -or -not $result.text.Contains('VERIFIED:')) {
  throw ('Expected matching fake suite ZIP to verify: '+$result.text)
 }
 $data=[IO.File]::ReadAllBytes($zip)
 $data[$data.Length-1]=$data[$data.Length-1] -bxor 1
 [IO.File]::WriteAllBytes($zip,$data)
 $result=CheckZip $zip
 if ($result.code -eq 0 -or -not $result.text.Contains('SHA-256 mismatch')) {
  throw 'Tampered fake ZIP passed the verifier.'
 }
 $missingSource=Join-Path $root 'missing-source'
 $missingCore=Join-Path $missingSource 'NCore'
 New-Item -Path $missingCore -ItemType Directory -Force | Out-Null
 [IO.File]::WriteAllText((Join-Path $missingCore 'NCore.toc'),'## Interface: 30300')
 $missingZip=Join-Path $root 'incomplete-suite.zip'
 [IO.Compression.ZipFile]::CreateFromDirectory($missingSource,$missingZip)
 $fake.release_archive_sha256=(Get-FileHash -LiteralPath $missingZip -Algorithm SHA256).Hash.ToLowerInvariant()
 $fake.release_archive_size_bytes=(Get-Item -LiteralPath $missingZip).Length
 $fake | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $configPath -Encoding UTF8
 $result=CheckZip $missingZip
 if ($result.code -eq 0 -or -not $result.text.Contains('Missing expected addon TOC')) {
  throw ('Incomplete but checksum-matching ZIP was not rejected: '+$result.text)
 }
 Write-Host 'Addon Suite archive fingerprint and tamper tests passed.' -ForegroundColor Green
}
finally {if (Test-Path -LiteralPath $root) {Remove-Item -LiteralPath $root -Recurse -Force}}
exit 0
