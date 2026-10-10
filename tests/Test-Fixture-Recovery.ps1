#requires -Version 5.1
# M20 metadata/hash-only read-only recovery auditor; disposable dummy data ONLY.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
$engine=Join-Path $repo 'tools/Inspect-Fixture-Recovery.ps1'
$tokens=$null;$errors=$null
[Management.Automation.Language.Parser]::ParseFile($engine,[ref]$tokens,[ref]$errors)|Out-Null
if(@($errors).Count -ne 0){throw ('Recovery scanner parse errors: '+($errors -join '; '))}
$base=Join-Path ([IO.Path]::GetTempPath()) ('naxx-recovery-audit-test-'+[guid]::NewGuid().ToString('N'))
try{
 foreach($r in @('repo/tools','source/Data/enUS','dest','manifests','not-fixture')){
  New-Item -ItemType Directory -Path (Join-Path $base $r) -Force|Out-Null
 }
 $runner=Join-Path $base 'repo/tools/Inspect-Fixture-Recovery.ps1'
 Copy-Item -LiteralPath $engine -Destination $runner
 $src=Join-Path $base 'source'
 $dest=Join-Path $base 'dest'
 $manifest=Join-Path $base 'manifests/fake.json'
 $journal=Join-Path $dest '.naxx-fixture-copy-journal.json'
 [IO.File]::WriteAllText((Join-Path $src '.naxx-copy-test-source'),'NAXX_SYNTHETIC_COPY_SOURCE_V1')
 [IO.File]::WriteAllText((Join-Path $dest '.naxx-copy-test-destination'),'NAXX_SYNTHETIC_COPY_DESTINATION_V1')
 $names=@('Wow.exe','Data/common.mpq','Data/patch-V.mpq','Data/patch-Z.mpq','Data/enUS/locale-enUS.mpq')
 $rows=@(
  foreach($name in $names){
   $f=Join-Path $src ($name.Replace('/',[IO.Path]::DirectorySeparatorChar))
   [IO.File]::WriteAllText($f,('DUMMY SYNTHETIC: '+$name))
   [ordered]@{relative_path=$name;byte_size=[long](Get-Item -LiteralPath $f).Length;sha256=(Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash.ToLowerInvariant()}
  }
 )
 $m=[ordered]@{schema_version=1;kind='naxx_synthetic_copy_fixture';synthetic_fixture=$true;complete_game_client=$false;files=$rows}
 $j=[ordered]@{schema_version=1;kind='naxx_fixture_copy_journal';source=$src;destination=$dest;status='applying';files=$rows}
 function SaveJson([object]$object,[string]$path){$object|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $path -Encoding UTF8}
 SaveJson $m $manifest
 SaveJson $j $journal
 function Run([string]$destination){
  $out=(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -SourcePath $src -DestinationPath $destination -ManifestPath $manifest 2>&1|Out-String)
  return [pscustomobject]@{code=$LASTEXITCODE;message=$out}
 }
 function ExpectReady([string]$needle){
  $p=Run $dest
  if($p.code -ne 0 -or -not $p.message.Contains('READY_FOR_MANUAL_ROLLBACK') -or -not $p.message.Contains($needle)){
   throw ('Expected ready, got: '+$p.message)
  }
 }
 function ExpectBlocked([string]$label){
  $p=Run $dest
  if($p.code -eq 0 -or -not $p.message.Contains('AUDIT: BLOCKED')){
   throw ('Expected block for '+$label+': '+$p.message)
  }
 }
 $sourceDigest=(Get-FileHash -LiteralPath (Join-Path $src 'Data/patch-Z.mpq') -Algorithm SHA256).Hash
 $beforeFileCount=@(Get-ChildItem -LiteralPath $base -Recurse -File -Force).Count
 ExpectReady 'VERIFIED DESTINATION FILES: 0; MISSING TEST FILES: 5'
 # Simulate an abrupt stop after two completed file promotions: the journal stays 'applying'.
 [IO.File]::Copy((Join-Path $src 'Wow.exe'),(Join-Path $dest 'Wow.exe'))
 [IO.Directory]::CreateDirectory((Join-Path $dest 'Data'))|Out-Null
 [IO.File]::Copy((Join-Path $src 'Data/patch-V.mpq'),(Join-Path $dest 'Data/patch-V.mpq'))
 ExpectReady 'VERIFIED DESTINATION FILES: 2; MISSING TEST FILES: 3'
 # A 'copied' journal must always have all files present.
 $j.status='copied';SaveJson $j $journal
 ExpectBlocked 'copied-but-missing'
 $j.status='applying';SaveJson $j $journal
 # Detect byte tampering and refuse to call rollback safe.
 [IO.File]::AppendAllText((Join-Path $dest 'Data/patch-V.mpq'),'PERSONAL MODIFICATION')
 ExpectBlocked 'tampered file'
 [IO.File]::Delete((Join-Path $dest 'Data/patch-V.mpq'))
 [IO.File]::Copy((Join-Path $src 'Data/patch-V.mpq'),(Join-Path $dest 'Data/patch-V.mpq'))
 ExpectReady 'VERIFIED DESTINATION FILES: 2'
 # Unknown file blocks, even if its contents are not inspected.
 [IO.File]::WriteAllText((Join-Path $dest 'Data/something-else.txt'),'NEVER REMOVE THIS')
 ExpectBlocked 'unknown file'
 [IO.File]::Delete((Join-Path $dest 'Data/something-else.txt'))
 # Unknown EMPTY directory also blocks readiness.
 [IO.Directory]::CreateDirectory((Join-Path $dest 'Data/owner-notes'))|Out-Null
 ExpectBlocked 'unknown empty directory'
 [IO.Directory]::Delete((Join-Path $dest 'Data/owner-notes'))
 # Unexpected journal paths or hashes are always refused.
 $j.files[0].sha256=('b'*64);SaveJson $j $journal
 ExpectBlocked 'forged journal'
 $j.files[0].sha256=$rows[0].sha256;SaveJson $j $journal
 ExpectReady 'VERIFIED DESTINATION FILES: 2'
 [IO.File]::Delete($journal)
 ExpectBlocked 'missing journal'
 SaveJson $j $journal
 $noMarker=Run (Join-Path $base 'not-fixture')
 if($noMarker.code -eq 0 -or -not $noMarker.message.Contains('AUDIT: BLOCKED')){throw 'Unmarked directory was accepted.'}
 if((Get-FileHash -LiteralPath (Join-Path $src 'Data/patch-Z.mpq') -Algorithm SHA256).Hash -cne $sourceDigest){throw 'Source was modified.'}
 if(@(Get-ChildItem -LiteralPath $base -Recurse -File -Force).Count -ne ($beforeFileCount+3)){
  throw 'Auditor unexpectedly wrote or removed fixture files.'
 }
 Write-Host 'ALL SYNTHETIC RECOVERY READINESS TESTS PASSED'
}finally{
 if(Test-Path -LiteralPath $base){Remove-Item -LiteralPath $base -Recurse -Force}
}
exit 0
