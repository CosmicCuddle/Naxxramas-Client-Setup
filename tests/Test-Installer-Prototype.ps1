#requires -Version 5.1
# All test files are tiny synthetic fixtures, never real MPQ or WoW files.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$project=(Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
$engine=Join-Path $project 'tools/Setup-Prototype.ps1'
$tokens=$null;$errors=$null
[Management.Automation.Language.Parser]::ParseFile($engine,[ref]$tokens,[ref]$errors) | Out-Null
if (@($errors).Count -gt 0) { throw ("PowerShell parser errors: "+($errors -join '; ')) }
$root=Join-Path ([IO.Path]::GetTempPath()) ('naxx-alpha-'+[guid]::NewGuid().ToString('N'))
try {
 $fakeRepo=Join-Path $root 'repo'; $game=Join-Path $root 'game'; $source=Join-Path $root 'source'
 foreach($p in @('repo/tools','repo/config','game/Data/enUS','source/Data')) {
  New-Item -ItemType Directory -Force -Path (Join-Path $root $p) | Out-Null
 }
 Copy-Item -LiteralPath $engine -Destination (Join-Path $fakeRepo 'tools/Setup-Prototype.ps1')
 Copy-Item -LiteralPath (Join-Path $project 'config/realm.json') -Destination (Join-Path $fakeRepo 'config/realm.json')
 [IO.File]::WriteAllBytes((Join-Path $game 'Wow.exe'),[byte[]]@())
 [IO.File]::WriteAllText((Join-Path $game '.naxx-test-fixture'),'NAXXRAMAS_DISPOSABLE_FIXTURE_V1')
 [IO.File]::WriteAllText((Join-Path $game 'Data/patch-V.mpq'),'old V')
 $originalV=(Get-FileHash -LiteralPath (Join-Path $game 'Data/patch-V.mpq')).Hash.ToLowerInvariant()
 $realmFile=Join-Path $game 'Data/enUS/realmlist.wtf'
 [IO.File]::WriteAllText($realmFile,'set realmlist old.example')
 $files=@(
  [pscustomobject]@{name='patch-V.mpq';path='Data/patch-V.mpq';data='new V';required=$true},
  [pscustomobject]@{name='patch-Z.mpq';path='Data/patch-Z.mpq';data='new Z';required=$true},
  [pscustomobject]@{name='Patch-J.mpq';path='Data/Patch-J.mpq';data='new J';required=$false},
  [pscustomobject]@{name='Patch-U.mpq';path='Data/Patch-U.mpq';data='new U';required=$false}
 )
 $patches=@()
 foreach($entry in $files) {
  $p=Join-Path (Join-Path $source 'Data') $entry.name
  [IO.File]::WriteAllText($p,$entry.data)
  $patches+= [pscustomobject]@{
   path=$entry.path;required=$entry.required;allow_disable=(-not $entry.required)
   sha256=(Get-FileHash -LiteralPath $p).Hash.ToLowerInvariant();size_bytes=(Get-Item -LiteralPath $p).Length
  }
 }
 [pscustomobject]@{schema_version=1;patch_set_version='synthetic-test';patches=$patches} |
  ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $fakeRepo 'config/client-patches.json') -Encoding UTF8
 $script=Join-Path $fakeRepo 'tools/Setup-Prototype.ps1'
 function Run([string[]]$flags) {
  $a=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$script,'-ClientPath',$game,'-PatchSourcePath',$source)+@($flags)
  $message=(& powershell.exe @a 2>&1 | Out-String)
  return [pscustomobject]@{exit=$LASTEXITCODE;text=$message}
 }
 $r=Run @()
 if ($r.exit -ne 0 -or -not $r.text.Contains('PLAN: 3 file change(s)')) { throw ("Plan failed: "+$r.text) }
 if (Test-Path -LiteralPath (Join-Path $game '.naxxramas-setup')) {throw 'Read-only plan made client changes.'}
 $r=Run @('-Action','Install','-Apply')
 if ($r.exit -eq 0) {throw 'Missing fixture confirmation was not rejected.'}
 $marker=Join-Path $game '.naxx-test-fixture'
 Move-Item -LiteralPath $marker -Destination ($marker+'.held')
 try {
  $r=Run @('-Action','Install','-Apply','-ConfirmDisposableFixture')
  if ($r.exit -eq 0 -or -not $r.text.Contains('only disposable test clients')) {
   throw 'The installer did not block a folder lacking its disposable fixture marker.'
  }
 } finally {
  Move-Item -LiteralPath ($marker+'.held') -Destination $marker
 }
 if (Test-Path -LiteralPath (Join-Path $game '.naxxramas-setup')) {
  throw 'A rejected non-fixture install unexpectedly created setup state.'
 }
 $r=Run @('-Action','Install','-Apply','-ConfirmDisposableFixture','-SimulateFailureAfter','2')
 if ($r.exit -eq 0 -or -not $r.text.Contains('Simulated failure')) {throw ("Simulated failure test did not fail: "+$r.text)}
 if ((Get-FileHash -LiteralPath (Join-Path $game 'Data/patch-V.mpq')).Hash.ToLowerInvariant() -ne $originalV) {throw 'V was not restored on failure.'}
 if (Test-Path -LiteralPath (Join-Path $game 'Data/patch-Z.mpq')) {throw 'Failed install left new Z.'}
 if ([IO.File]::ReadAllText($realmFile) -cne 'set realmlist old.example') {throw 'Failure altered realmlist.'}
 if (Test-Path -LiteralPath (Join-Path $game '.naxxramas-setup/active.json')) {throw 'Failed install left active session.'}
 $r=Run @('-Action','Install','-Apply','-ConfirmDisposableFixture','-VanillaLogin','-VanillaLoading')
 if ($r.exit -ne 0 -or -not $r.text.Contains('TEST INSTALL COMPLETE')) {throw ("Install failed: "+$r.text)}
 foreach($entry in $patches) {
  $p=Join-Path $game $entry.path
  if (-not (Test-Path -LiteralPath $p) -or (Get-FileHash -LiteralPath $p).Hash.ToLowerInvariant() -ne $entry.sha256) {throw "Missing or incorrect: $($entry.path)"}
 }
 if ([IO.File]::ReadAllText($realmFile) -cne 'set realmlist 85.190.254.242') {throw 'Realm was not configured.'}
 $r=Run @('-Action','Install','-Apply','-ConfirmDisposableFixture')
 if ($r.exit -eq 0) {throw 'Repeat installation should not overwrite active session.'}
 [IO.File]::WriteAllText($realmFile,'set realmlist player-changed.example')
 $r=Run @('-Action','Rollback','-Apply','-ConfirmDisposableFixture')
 if ($r.exit -eq 0 -or -not $r.text.Contains('changed after setup')) {throw 'Rollback did not protect player changes.'}
 if ([IO.File]::ReadAllText($realmFile) -cne 'set realmlist player-changed.example') {throw 'Player edit was overwritten.'}
 [IO.File]::WriteAllText($realmFile,'set realmlist 85.190.254.242')
 $r=Run @('-Action','Rollback','-Apply','-ConfirmDisposableFixture')
 if ($r.exit -ne 0 -or -not $r.text.Contains('ROLLBACK COMPLETE')) {throw ("Rollback failed: "+$r.text)}
 if ((Get-FileHash -LiteralPath (Join-Path $game 'Data/patch-V.mpq')).Hash.ToLowerInvariant() -ne $originalV) {throw 'V not restored.'}
 foreach($name in @('patch-Z.mpq','Patch-J.mpq','Patch-U.mpq')) {
  if (Test-Path -LiteralPath (Join-Path (Join-Path $game 'Data') $name)) {throw "New file $name not removed."}
 }
 if ([IO.File]::ReadAllText($realmFile) -cne 'set realmlist old.example') {throw 'Original realmlist was not restored.'}
 [IO.File]::WriteAllText((Join-Path $source 'Data/patch-Z.mpq'),'tampered Z')
 $r=Run @('-Action','Install','-Apply','-ConfirmDisposableFixture')
 if ($r.exit -eq 0) {throw 'Wrong checksum should prevent installation.'}
 Write-Host 'ALL INSTALLER ALPHA FIXTURE TESTS PASSED' -ForegroundColor Green
}
finally { if (Test-Path -LiteralPath $root) {Remove-Item -LiteralPath $root -Recurse -Force} }

# Clear the last expected failure code from child PowerShell smoke tests.
exit 0
