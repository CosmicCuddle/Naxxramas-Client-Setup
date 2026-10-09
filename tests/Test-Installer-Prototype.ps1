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
 Copy-Item -LiteralPath (Join-Path $project 'tools/Verified-Addon-Zip.ps1') -Destination (Join-Path $fakeRepo 'tools/Verified-Addon-Zip.ps1')
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
 Copy-Item -LiteralPath (Join-Path $project 'config/addon-suite.json') -Destination (Join-Path $fakeRepo 'config/addon-suite.json')
 $suite=Join-Path $root 'addons'
 foreach($d in @('NCore','DungeonJournal','MultiBot')) { New-Item -ItemType Directory -Force -Path (Join-Path $suite $d) | Out-Null }
 foreach($d in @('NCore','DungeonJournal','MultiBot')) {
  [IO.File]::WriteAllText((Join-Path (Join-Path $suite $d) ($d+'.toc')),'## Interface: 30300')
 }
 [IO.File]::WriteAllText((Join-Path $suite 'NCore/core.lua'),'print("ncore")')
 [IO.File]::WriteAllText((Join-Path $suite 'DungeonJournal/journal.lua'),'print("journal")')
 $script=Join-Path $fakeRepo 'tools/Setup-Prototype.ps1'
 function Run([string[]]$flags) {
  $a=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$script,'-ClientPath',$game,'-PatchSourcePath',$source)+@($flags)
  $message=(& powershell.exe @a 2>&1 | Out-String)
  return [pscustomobject]@{exit=$LASTEXITCODE;text=$message}
 }
 $r=Run @('-Action','Inspect')
 if ($r.exit -ne 0 -or -not $r.text.Contains('STATE: NONE')) {throw ('Read-only empty state inspection failed: '+$r.text)}
 $r=Run @()
 if ($r.exit -ne 0 -or -not $r.text.Contains('PLAN: 3 file change(s)')) { throw ("Plan failed: "+$r.text) }
 if (Test-Path -LiteralPath (Join-Path $game '.naxxramas-setup')) {throw 'Read-only plan made client changes.'}
 $r=Run @('-Action','Install','-Apply')
 if ($r.exit -eq 0) {throw 'Missing fixture confirmation was not rejected.'}
 $r=Run @('-Action','Install','-Apply','-ConfirmDisposableFixture','-SimulateFreeBytes','0')
 if ($r.exit -eq 0 -or -not $r.text.Contains('Insufficient free disk space')) {
  throw ("Low-disk preflight did not block installation: "+$r.text)
 }
 if (Test-Path -LiteralPath (Join-Path $game '.naxxramas-setup')) {
  throw 'Low-disk validation wrote setup state.'
 }
 $r=Run @('-Action','Plan','-SimulateFreeBytes','0')
 if ($r.exit -ne 0 -or -not $r.text.Contains('Insufficient free disk space')) {
  throw 'Read-only plan failed to warn about simulated insufficient disk space.'
 }
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
 $r=Run @('-Action','Install','-Apply','-ConfirmDisposableFixture','-SimulateStagingFailureAfter','2')
 if ($r.exit -eq 0 -or -not $r.text.Contains('Simulated staging permission failure')) {
  throw ("Synthetic staging failure was not handled: "+$r.text)
 }
 if ((Get-FileHash -LiteralPath (Join-Path $game 'Data/patch-V.mpq')).Hash.ToLowerInvariant() -ne $originalV -or
     (Test-Path -LiteralPath (Join-Path $game 'Data/patch-Z.mpq')) -or
     [IO.File]::ReadAllText($realmFile) -cne 'set realmlist old.example') {
  throw 'Staging failure modified existing game files.'
 }
 if (Test-Path -LiteralPath (Join-Path $game '.naxxramas-setup/active.json')) {
  throw 'A staging-only failure created an active installation.'
 }
 if (@(Get-ChildItem -LiteralPath (Join-Path $game '.naxxramas-setup/sessions') -ErrorAction SilentlyContinue).Count -ne 0) {
  throw 'A staging-only failure left a partial session folder.'
 }
 $r=Run @('-Action','Install','-Apply','-ConfirmDisposableFixture','-SimulateFailureAfter','2')
 if ($r.exit -eq 0 -or -not $r.text.Contains('Simulated failure')) {throw ("Simulated failure test did not fail: "+$r.text)}
 if ((Get-FileHash -LiteralPath (Join-Path $game 'Data/patch-V.mpq')).Hash.ToLowerInvariant() -ne $originalV) {throw 'V was not restored on failure.'}
 if (Test-Path -LiteralPath (Join-Path $game 'Data/patch-Z.mpq')) {throw 'Failed install left new Z.'}
 if ([IO.File]::ReadAllText($realmFile) -cne 'set realmlist old.example') {throw 'Failure altered realmlist.'}
 if (Test-Path -LiteralPath (Join-Path $game '.naxxramas-setup/active.json')) {throw 'Failed install left active session.'}
 # Simulate abrupt process termination; unlike an exception, it bypasses automatic catch/rollback.
 $r=Run @('-Action','Install','-Apply','-ConfirmDisposableFixture','-SimulateCrashAfter','2')
 if ($r.exit -ne 77 -or -not $r.text.Contains('Simulated HARD interruption')) {
  throw ("Hard interruption fixture did not stop as requested: "+$r.text)
 }
 if (-not (Test-Path -LiteralPath (Join-Path $game '.naxxramas-setup/active.json'))) {
  throw 'Hard interruption did not preserve recovery state.'
 }
 $r=Run @('-Action','Inspect')
 if ($r.exit -ne 0 -or -not $r.text.Contains('STATE: APPLYING')) {
  throw ("Interrupted session was not reported read-only: "+$r.text)
 }
 # A crash can leave a .writing file while the last committed journal is intact.
 # Do not guess whether to ignore or delete it: block all recovery writes.
 $activePointer=Get-Content -LiteralPath (Join-Path $game '.naxxramas-setup/active.json') -Raw | ConvertFrom-Json
 $incomplete=Join-Path $game ('.naxxramas-setup/sessions/'+$activePointer.session+'/manifest.json.writing')
 [IO.File]::WriteAllText($incomplete,'{"partial":')
 $beforeCrashV=(Get-FileHash -LiteralPath (Join-Path $game 'Data/patch-V.mpq')).Hash
 $r=Run @('-Action','Inspect')
 if ($r.exit -ne 0 -or -not $r.text.Contains('Incomplete journal write retained')) {
  throw ("Partial journal was not reported: "+$r.text)
 }
 $r=Run @('-Action','Recover','-Apply','-ConfirmDisposableFixture')
 if ($r.exit -eq 0 -or -not $r.text.Contains('Incomplete .writing journal')) {
  throw 'A partial journal did not block all recovery.'
 }
 if ((Get-FileHash -LiteralPath (Join-Path $game 'Data/patch-V.mpq')).Hash -ne $beforeCrashV) {
  throw 'Journal inspection or refusal modified the client.'
 }
 Remove-Item -LiteralPath $incomplete -Force # Fixture-only cleanup after checking expected contents.
 # Corrupt the last committed manifest to ensure recovery refuses invalid JSON.
 $committed=Join-Path $game ('.naxxramas-setup/sessions/'+$activePointer.session+'/manifest.json')
 $originalJournal=[IO.File]::ReadAllText($committed)
 [IO.File]::WriteAllText($committed,'{"broken":')
 $r=Run @('-Action','Inspect')
 if ($r.exit -ne 0 -or -not $r.text.Contains('UNTRUSTED OR DAMAGED JOURNAL')) {
  throw 'Corrupted main journal was not identified.'
 }
 $r=Run @('-Action','Recover','-Apply','-ConfirmDisposableFixture')
 if ($r.exit -eq 0) { throw 'Damaged committed journal was accepted for recovery.' }
 if ((Get-FileHash -LiteralPath (Join-Path $game 'Data/patch-V.mpq')).Hash -ne $beforeCrashV) {
  throw 'Damaged journal recovery attempt modified the client.'
 }
 [IO.File]::WriteAllText($committed,$originalJournal)
 $r=Run @('-Action','Install','-Apply','-ConfirmDisposableFixture')
 if ($r.exit -eq 0 -or -not $r.text.Contains('interrupted installation')) {
  throw 'A second installation was allowed while recovery was pending.'
 }
 $r=Run @('-Action','Rollback','-Apply','-ConfirmDisposableFixture')
 if ($r.exit -eq 0 -or -not $r.text.Contains('Use Recover')) {
  throw 'Rollback was permitted on an incomplete transaction.'
 }
 $r=Run @('-Action','Recover','-Apply')
 if ($r.exit -eq 0) { throw 'Recovery without test fixture confirmation was permitted.' }
 # A damaged backup MUST stop recovery before changing ANY destination.
 $ptr=Get-Content -LiteralPath (Join-Path $game '.naxxramas-setup/active.json') -Raw | ConvertFrom-Json
 $originalBackup=Join-Path $game ('.naxxramas-setup/sessions/'+$ptr.session+'/backups/Data/patch-V.mpq')
 [IO.File]::WriteAllText($originalBackup,'CORRUPTED BACKUP')
 $r=Run @('-Action','Recover','-Apply','-ConfirmDisposableFixture')
 if ($r.exit -eq 0 -or -not $r.text.Contains('Damaged backup')) {
  throw 'Corrupt original backup was not detected.'
 }
 if ([IO.File]::ReadAllText((Join-Path $game 'Data/patch-V.mpq')) -cne 'new V') {
  throw 'Recovery changed the client before verifying all backups.'
 }
 [IO.File]::WriteAllText($originalBackup,'old V')
 $r=Run @('-Action','Recover','-Apply','-ConfirmDisposableFixture')
 if ($r.exit -ne 0 -or -not $r.text.Contains('ROLLBACK COMPLETE')) {
  throw ("Explicit crash recovery failed: "+$r.text)
 }
 if ((Get-FileHash -LiteralPath (Join-Path $game 'Data/patch-V.mpq')).Hash.ToLowerInvariant() -ne $originalV) {
  throw 'Recovery did not restore original patch V.'
 }
 if (Test-Path -LiteralPath (Join-Path $game 'Data/patch-Z.mpq')) {throw 'Recovery left newly created patch Z.'}
 if ([IO.File]::ReadAllText($realmFile) -cne 'set realmlist old.example') {throw 'Recovery modified untouched realmlist.'}
 $r=Run @('-Action','Install','-Apply','-ConfirmDisposableFixture','-VanillaLogin','-VanillaLoading')
 if ($r.exit -ne 0 -or -not $r.text.Contains('TEST INSTALL COMPLETE')) {throw ("Install failed: "+$r.text)}
 foreach($entry in $patches) {
  $p=Join-Path $game $entry.path
  if (-not (Test-Path -LiteralPath $p) -or (Get-FileHash -LiteralPath $p).Hash.ToLowerInvariant() -ne $entry.sha256) {throw "Missing or incorrect: $($entry.path)"}
 }
 if ([IO.File]::ReadAllText($realmFile) -cne 'set realmlist 85.190.254.242') {throw 'Realm was not configured.'}
 $r=Run @('-Action','Recover','-Apply','-ConfirmDisposableFixture')
 if ($r.exit -eq 0 -or -not $r.text.Contains('Recover is only for interrupted')) {
  throw 'Recovery could overwrite an intentionally completed installation.'
 }
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
 # The N Addon Suite is always selected with NCore, and only explicitly selected optional modules.
 $r=Run @('-Addons','DungeonJournal')
 if ($r.exit -eq 0 -or -not $r.text.Contains('require -AddonSuitePath')) {
  throw 'Selected optional addons were accepted without an addon suite.'
 }
 $r=Run @('-AddonSuitePath',$suite,'-Addons','DungeonJournal')
 if ($r.exit -ne 0 -or -not $r.text.Contains('PLAN: 7 file change(s)')) {
  throw ("Addon preview failed: "+$r.text)
 }
 if (Test-Path -LiteralPath (Join-Path $game 'Interface/AddOns/NCore')) {
  throw 'Read-only addon plan copied addon files.'
 }
 $r=Run @('-AddonSuitePath',$suite,'-Addons','DungeonJournal','-Action','Install','-Apply','-ConfirmDisposableFixture')
 if ($r.exit -ne 0 -or -not $r.text.Contains('TEST INSTALL COMPLETE')) {throw ("Addon install fixture failed: "+$r.text)}
 foreach($p in @('Interface/AddOns/NCore/NCore.toc','Interface/AddOns/NCore/core.lua',
                 'Interface/AddOns/DungeonJournal/DungeonJournal.toc','Interface/AddOns/DungeonJournal/journal.lua')) {
  if (-not (Test-Path -LiteralPath (Join-Path $game $p))) {throw "Missing addon file: $p"}
 }
 if (Test-Path -LiteralPath (Join-Path $game 'Interface/AddOns/MultiBot')) {
  throw 'Unselected optional addon MultiBot was installed.'
 }
 $addonFile=Join-Path $game 'Interface/AddOns/NCore/core.lua'
 [IO.File]::WriteAllText($addonFile,'player altered addon')
 $r=Run @('-Action','Rollback','-Apply','-ConfirmDisposableFixture')
 if ($r.exit -eq 0 -or -not $r.text.Contains('changed after setup')) {
  throw 'Rollback could overwrite player-edited addon content.'
 }
 [IO.File]::WriteAllText($addonFile,'print("ncore")')
 $r=Run @('-Action','Rollback','-Apply','-ConfirmDisposableFixture')
 if ($r.exit -ne 0) { throw ("Addon rollback failed: "+$r.text) }
 if (Test-Path -LiteralPath $addonFile -PathType Leaf) {throw 'Rollback left installer-created NCore file.'}
 if (Test-Path -LiteralPath (Join-Path $game 'Interface/AddOns/DungeonJournal/DungeonJournal.toc')) {
  throw 'Rollback left installer-created journal file.'
 }
 # A pre-existing addon folder must be protected, even when contents differ.
 New-Item -ItemType Directory -Force -Path (Join-Path $game 'Interface/AddOns/NCore') | Out-Null
 [IO.File]::WriteAllText((Join-Path $game 'Interface/AddOns/NCore/user.lua'),'user-installed')
 $r=Run @('-AddonSuitePath',$suite,'-Action','Install','-Apply','-ConfirmDisposableFixture')
 if ($r.exit -eq 0 -or -not $r.text.Contains('Refusing to merge/overwrite')) {
  throw 'Installer attempted to merge into an existing addon directory.'
 }
 if ([IO.File]::ReadAllText((Join-Path $game 'Interface/AddOns/NCore/user.lua')) -cne 'user-installed') {
  throw 'Existing addon content was modified.'
 }
 # Verified ZIP direct-source integration: no separately extracted addon directory is trusted.
 Remove-Item -LiteralPath (Join-Path $game 'Interface/AddOns/NCore') -Recurse -Force
 foreach($name in @('IndividualProgressionAddon','NaxxLootLottery')) {
  $d=Join-Path $suite $name
  New-Item -ItemType Directory -Path $d -Force | Out-Null
  [IO.File]::WriteAllText((Join-Path $d ($name+'.toc')),'## Interface: 30300')
 }
 Add-Type -AssemblyName System.IO.Compression.FileSystem
 $zip=Join-Path $root 'test-n-addon-v2.zip'
 [IO.Compression.ZipFile]::CreateFromDirectory($suite,$zip)
 $metaPath=Join-Path $fakeRepo 'config/addon-suite.json'
 $meta=Get-Content -LiteralPath $metaPath -Raw | ConvertFrom-Json
 $meta.release_archive_sha256=(Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
 $meta.release_archive_size_bytes=(Get-Item -LiteralPath $zip).Length
 $meta | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $metaPath -Encoding UTF8
 $r=Run @('-AddonSuiteArchivePath',$zip,'-Addons','DungeonJournal')
 if ($r.exit -ne 0 -or -not $r.text.Contains('PLAN: 7 file change(s)') -or
    -not $r.text.Contains('Verified addon ZIP source:')) {
  throw ("Direct ZIP plan failed: "+$r.text)
 }
 if (Test-Path -LiteralPath (Join-Path $game 'Interface/AddOns/NCore')) {
  throw 'Direct ZIP plan modified the game client.'
 }
 $r=Run @('-AddonSuiteArchivePath',$zip,'-AddonSuitePath',$suite)
 if ($r.exit -eq 0 -or -not $r.text.Contains('Specify either')) {
  throw 'Both addon sources were accepted simultaneously.'
 }
 $r=Run @('-AddonSuiteArchivePath',$zip,'-Addons','DungeonJournal','-Action','Install','-Apply','-ConfirmDisposableFixture')
 if ($r.exit -ne 0 -or -not $r.text.Contains('TEST INSTALL COMPLETE')) {
  throw ("Direct verified ZIP installation failed: "+$r.text)
 }
 foreach($name in @('NCore','DungeonJournal')) {
  if (-not (Test-Path -LiteralPath (Join-Path $game ('Interface/AddOns/'+$name+'/'+$name+'.toc')) -PathType Leaf)) {
   throw "Direct ZIP installation omitted the selected addon $name."
  }
 }
 if (Test-Path -LiteralPath (Join-Path $game 'Interface/AddOns/MultiBot')) {
  throw 'Direct ZIP installation included an unselected optional addon.'
 }
 $r=Run @('-Action','Rollback','-Apply','-ConfirmDisposableFixture')
 if ($r.exit -ne 0 -or -not $r.text.Contains('ROLLBACK COMPLETE')) {
  throw ("Verified ZIP rollback failed: "+$r.text)
 }
 if (Test-Path -LiteralPath (Join-Path $game 'Interface/AddOns/NCore/NCore.toc')) {
  throw 'Verified ZIP rollback left addon files.'
 }
 # A modified archive must be blocked before creating any transaction state.
 $tampered=Join-Path $root 'tampered-suite.zip'
 Copy-Item -LiteralPath $zip -Destination $tampered
 $raw=[IO.File]::ReadAllBytes($tampered)
 $raw[$raw.Length-1]=$raw[$raw.Length-1] -bxor 1
 [IO.File]::WriteAllBytes($tampered,$raw)
 $r=Run @('-AddonSuiteArchivePath',$tampered,'-Action','Install','-Apply','-ConfirmDisposableFixture')
 if ($r.exit -eq 0 -or -not $r.text.Contains('SHA-256 mismatch')) {
  throw 'Installer allowed an altered ZIP.'
 }
 if (Test-Path -LiteralPath (Join-Path $game '.naxxramas-setup/active.json')) {
  throw 'Altered ZIP created an active install session.'
 }
 [IO.File]::WriteAllText((Join-Path $source 'Data/patch-Z.mpq'),'tampered Z')
 $r=Run @('-Action','Install','-Apply','-ConfirmDisposableFixture')
 if ($r.exit -eq 0) {throw 'Wrong checksum should prevent installation.'}
 Write-Host 'ALL INSTALLER ALPHA FIXTURE TESTS PASSED' -ForegroundColor Green
}
finally { if (Test-Path -LiteralPath $root) {Remove-Item -LiteralPath $root -Recurse -Force} }

# Clear the last expected failure code from child PowerShell smoke tests.
exit 0
