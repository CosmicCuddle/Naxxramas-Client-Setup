#requires -Version 5.1
# Synthetic-client-only copy/verify/rollback safety. No WoW binaries or MPQs.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
$engine=Join-Path $repo 'tools/Test-Client-Copy-Fixture.ps1'
$tokens=$null;$errs=$null
[Management.Automation.Language.Parser]::ParseFile($engine,[ref]$tokens,[ref]$errs)|Out-Null
if(@($errs).Count -ne 0){throw ('Copy fixture PowerShell syntax: '+($errs -join '; '))}
$base=Join-Path ([IO.Path]::GetTempPath()) ('naxx-fixture-copy-test-'+[guid]::NewGuid().ToString('N'))
try{
 foreach($folder in @('repo/tools','src/Data/enUS','dest','manifests','unmarked','dest-populated','dest-nested')){
  New-Item -ItemType Directory -Path (Join-Path $base $folder) -Force|Out-Null
 }
 $stub=Join-Path $base 'repo'
 $script=Join-Path $stub 'tools/Test-Client-Copy-Fixture.ps1'
 Copy-Item -LiteralPath $engine -Destination $script
 $src=Join-Path $base 'src'
 $dst=Join-Path $base 'dest'
 $sourceMarker=Join-Path $src '.naxx-copy-test-source'
 $destMarker=Join-Path $dst '.naxx-copy-test-destination'
 [IO.File]::WriteAllText($sourceMarker,"NAXX_SYNTHETIC_COPY_SOURCE_V1")
 [IO.File]::WriteAllText($destMarker,"NAXX_SYNTHETIC_COPY_DESTINATION_V1")
 $pathNames=@('Wow.exe','Data/common.mpq','Data/enUS/locale-enUS.mpq','Data/patch-V.mpq','Data/patch-Z.mpq','Data/Patch-U.mpq')
 $files=@(
  foreach($name in $pathNames){
   $p=Join-Path $src ($name.Replace('/',[IO.Path]::DirectorySeparatorChar))
   [IO.File]::WriteAllText($p,('ONLY SYNTHETIC DATA '+$name))
   [ordered]@{
    relative_path=$name
    byte_size=[long](Get-Item -LiteralPath $p).Length
    sha256=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant()
   }
  }
 )
 $manifestFile=Join-Path $base 'manifests/dummy.json'
 $manifest=[ordered]@{schema_version=1;kind='naxx_synthetic_copy_fixture';synthetic_fixture=$true;complete_game_client=$false;files=$files}
 function Save-Manifest(){ $manifest|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $manifestFile -Encoding UTF8 }
 Save-Manifest
 function Call([string]$dest,[string]$action,[string[]]$extra){
  $out=(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script -SourcePath $src -DestinationPath $dest -ManifestPath $manifestFile -Action $action @extra 2>&1 | Out-String)
  return [pscustomobject]@{code=$LASTEXITCODE;text=$out}
 }
 $beforeSrc=Get-FileHash -LiteralPath (Join-Path $src 'Data/patch-V.mpq') -Algorithm SHA256
 $p=Call $dst 'Plan' @()
 if($p.code -ne 0 -or -not $p.text.Contains('PLAN ONLY')){throw ('Fixture plan failed: '+$p.text)}
 if(@(Get-ChildItem -LiteralPath $dst -Force).Count -ne 1){throw 'Fixture Plan created files.'}
 $noConfirm=Call $dst 'Copy' @()
 if($noConfirm.code -eq 0 -or -not $noConfirm.text.Contains('-ConfirmDisposableFixture')){throw 'Fixture copy ran without explicit approval.'}
 $ok=Call $dst 'Copy' @('-ConfirmDisposableFixture')
 if($ok.code -ne 0 -or -not $ok.text.Contains('SYNTHETIC FIXTURE COPY SUCCESS')){throw ('Fixture copy failed: '+$ok.text)}
 $journal=Join-Path $dst '.naxx-fixture-copy-journal.json'
 if(-not(Test-Path -LiteralPath $journal)){throw 'Missing fixture journal.'}
 $j=Get-Content -LiteralPath $journal -Raw|ConvertFrom-Json
 if($j.status -cne 'copied' -or @($j.files).Count -ne $files.Count){throw 'Fixture journal was not committed after verification.'}
 foreach($f in $files){
  $target=Join-Path $dst ($f.relative_path.Replace('/',[IO.Path]::DirectorySeparatorChar))
  if(-not(Test-Path -LiteralPath $target) -or (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant() -cne $f.sha256){
   throw ('Copied fixture has wrong bytes: '+$f.relative_path)
  }
 }
 $repeat=Call $dst 'Copy' @('-ConfirmDisposableFixture')
 if($repeat.code -eq 0){throw 'A second copy was allowed over an existing installation.'}
 $noRollback=Call $dst 'Rollback' @()
 if($noRollback.code -eq 0){throw 'Fixture rollback ran without confirmation.'}
 # Never erase modified files owned by user.
 [IO.File]::AppendAllText((Join-Path $dst 'Data/common.mpq'),'owner changed this')
 $tampered=Call $dst 'Rollback' @('-ConfirmDisposableFixture')
 if($tampered.code -eq 0 -or -not (Test-Path -LiteralPath $journal)){
  throw 'Tampered fixture was incorrectly removed by rollback.'
 }
 # Restore exact original bytes and safely roll back.
 Copy-Item -LiteralPath (Join-Path $src 'Data/common.mpq') -Destination (Join-Path $dst 'Data/common.mpq') -Force
 $rolled=Call $dst 'Rollback' @('-ConfirmDisposableFixture')
 if($rolled.code -ne 0 -or -not $rolled.text.Contains('ROLLBACK VERIFIED')){throw ('Fixture rollback failed: '+$rolled.text)}
 if(@(Get-ChildItem -LiteralPath $dst -Recurse -File -Force).Count -ne 1 -or
    -not(Test-Path -LiteralPath $destMarker)){throw 'Rollback did not restore empty marked destination.'}
 # M21: rollback must be resumable after interruption after two confirmed deletions.
 $second=Call $dst 'Copy' @('-ConfirmDisposableFixture')
 if($second.code -ne 0 -or -not $second.text.Contains('SYNTHETIC FIXTURE COPY SUCCESS')){
  throw ('Fixture recopy for interruption test failed: '+$second.text)
 }
 # No unexpected empty directories: protect owner-created contents.
 $empty=Join-Path $dst 'Data/owner-empty'
 [IO.Directory]::CreateDirectory($empty)|Out-Null
 $blocked=Call $dst 'Rollback' @('-ConfirmDisposableFixture')
 if($blocked.code -eq 0 -or -not (Test-Path -LiteralPath $empty) -or
   -not (Test-Path -LiteralPath $journal)){
  throw ('Unknown empty folder was not protected: '+$blocked.text)
 }
 [IO.Directory]::Delete($empty)
 # A stray sidecar from an interrupted journal replacement must block deletion.
 $sidecar=$journal+'.rollback-writing'
 [IO.File]::WriteAllText($sidecar,'DUMMY INTERRUPTED STATE')
 $sidecarBlocked=Call $dst 'Rollback' @('-ConfirmDisposableFixture')
 if($sidecarBlocked.code -eq 0 -or -not $sidecarBlocked.text.Contains('replacement residue')){
  throw ('Rollback sidecar handling mismatch (exit '+$sidecarBlocked.code+'): '+$sidecarBlocked.text)
 }
 [IO.File]::Delete($sidecar)
 $halted=Call $dst 'Rollback' @('-ConfirmDisposableFixture','-SimulateRollbackInterruptionAfter','2')
 if($halted.code -eq 0 -or -not $halted.text.Contains('SIMULATED FIXTURE ROLLBACK INTERRUPTION')){
  throw ('Expected controlled rollback interruption: '+$halted.text)
 }
 $haltedState=Get-Content -LiteralPath $journal -Raw|ConvertFrom-Json
 if($haltedState.status -cne 'rolling_back' -or -not(Test-Path -LiteralPath $destMarker)){
  throw 'Interrupted rollback did not leave durable journal and marker.'
 }
 if(@(Get-ChildItem -LiteralPath $dst -Recurse -File -Force).Count -ne ($files.Count-2+2)){
  throw 'Interrupted rollback unexpectedly changed the number of fixture files.'
 }
 # On resumption: tampered remaining fixture must stay, journal retained.
 $remaining=Join-Path $dst 'Data/patch-Z.mpq'
 [IO.File]::AppendAllText($remaining,'OWNER MODIFIED')
 $unsafeResume=Call $dst 'Rollback' @('-ConfirmDisposableFixture')
 if($unsafeResume.code -eq 0 -or -not (Test-Path -LiteralPath $journal) -or
   -not (Test-Path -LiteralPath $remaining)){
  throw 'An altered fixture was deleted during resumed rollback.'
 }
 Copy-Item -LiteralPath (Join-Path $src 'Data/patch-Z.mpq') -Destination $remaining -Force
 $resume=Call $dst 'Rollback' @('-ConfirmDisposableFixture')
 if($resume.code -ne 0 -or -not $resume.text.Contains('ROLLBACK VERIFIED')){
  throw ('Resuming an interrupted fixture rollback failed: '+$resume.text)
 }
 if(@(Get-ChildItem -LiteralPath $dst -Recurse -File -Force).Count -ne 1 -or
   -not (Test-Path -LiteralPath $destMarker)){throw 'Resumed rollback did not restore marker-only destination.'}
 $partial=Call $dst 'Copy' @('-ConfirmDisposableFixture','-SimulateFailureAfter','2')
 if($partial.code -eq 0 -or -not $partial.text.Contains('Verified partial copy rolled back')){
  throw ('Simulated failure did not clean up partial copy: '+$partial.text)
 }
 if(@(Get-ChildItem -LiteralPath $dst -Recurse -File -Force).Count -ne 1){throw 'Simulated failure left altered destination.'}
 $populated=Join-Path $base 'dest-populated'
 [IO.File]::WriteAllText((Join-Path $populated '.naxx-copy-test-destination'),'NAXX_SYNTHETIC_COPY_DESTINATION_V1')
 [IO.File]::WriteAllText((Join-Path $populated 'personal-file.txt'),'SAVE THIS FILE')
 $busy=Call $populated 'Copy' @('-ConfirmDisposableFixture')
 if($busy.code -eq 0 -or -not(Test-Path -LiteralPath (Join-Path $populated 'personal-file.txt'))){
  throw 'Copy accepted existing personal files.'
 }
 $unmarked=Call (Join-Path $base 'unmarked') 'Copy' @('-ConfirmDisposableFixture')
 if($unmarked.code -eq 0){throw 'Unmarked destination was incorrectly accepted.'}
 # Out-of-allowlist and traversal manifest entries must not copy anything.
 $manifest.files[2].relative_path='WTF/Account/private.txt'
 Save-Manifest
 $invalid=Call $dst 'Copy' @('-ConfirmDisposableFixture')
 if($invalid.code -eq 0){throw 'Unsafe fixture relative path was accepted.'}
 $manifest.files[2].relative_path=$pathNames[2]
 $manifest.synthetic_fixture=$false
 Save-Manifest
 $notSynthetic=Call $dst 'Copy' @('-ConfirmDisposableFixture')
 if($notSynthetic.code -eq 0){throw 'Real/non-synthetic manifest was accepted.'}
 $manifest.synthetic_fixture=$true
 $manifest.files[0].byte_size=536870912
 Save-Manifest
 $big=Call $dst 'Copy' @('-ConfirmDisposableFixture')
 if($big.code -eq 0){throw 'Oversized potential real-client file was accepted.'}
 if((Get-FileHash -LiteralPath (Join-Path $src 'Data/patch-V.mpq') -Algorithm SHA256).Hash -ne $beforeSrc.Hash){
  throw 'Source files were altered by fixture-copy operations.'
 }
 Write-Host 'ALL DISPOSABLE CLIENT COPY AND VERIFIED ROLLBACK TESTS PASSED'
}finally{
 if(Test-Path -LiteralPath $base){Remove-Item -LiteralPath $base -Recurse -Force}
}
exit 0
