#requires -Version 5.1
# Whitelisted file manifest verification tests with dummy files ONLY.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
$engine=Join-Path $repo 'tools/Inventory-Game-Files.ps1'
$tokens=$null;$errors=$null
[Management.Automation.Language.Parser]::ParseFile($engine,[ref]$tokens,[ref]$errors)|Out-Null
if(@($errors).Count -gt 0){throw ('Inventory script failed parser: '+($errors -join '; '))}
$base=Join-Path ([IO.Path]::GetTempPath()) ('naxx-gamefiles-test-'+[guid]::NewGuid().ToString('N'))
try{
 foreach($dir in @('repo/tools','repo/config','game/Data/enUS','game/WTF/Account/SECRET_PERSON','game/Interface/AddOns/PersonalAddon','game/Screenshots','reports')){
  New-Item -Path (Join-Path $base $dir) -ItemType Directory -Force|Out-Null
 }
 $repoTest=Join-Path $base 'repo'
 $game=Join-Path $base 'game'
 Copy-Item -LiteralPath $engine -Destination (Join-Path $repoTest 'tools/Inventory-Game-Files.ps1')
 $policy=Get-Content -LiteralPath (Join-Path $repo 'config/client-patches.json') -Raw | ConvertFrom-Json
 [IO.File]::WriteAllText((Join-Path $game 'Wow.exe'),'DUMMY EXECUTABLE: NEVER A VERIFIED BUILD')
 [IO.File]::WriteAllText((Join-Path $game 'Launcher.exe'),'dummy launcher')
 [IO.File]::WriteAllText((Join-Path $game 'ijl15.dll'),'DUMMY JPEG SUPPORT')
 [IO.File]::WriteAllText((Join-Path $game 'DBGHELP.DLL'),'DUMMY DEBUG SUPPORT')
 [IO.File]::WriteAllText((Join-Path $game 'fmodex.dll'),'DUMMY OTHER ROOT CANDIDATE')
 [IO.File]::WriteAllText((Join-Path $game 'Data/common.MPQ'),'dummy base MPQ')
 [IO.File]::WriteAllText((Join-Path $game 'Data/enUS/locale-enUS.MPQ'),'dummy locale archive')
 [IO.File]::WriteAllText((Join-Path $game 'Data/enUS/base-enUS.MPQ'),'dummy base locale resource')
 [IO.File]::WriteAllText((Join-Path $game 'Data/enUS/BACKUP-enUS.mpq'),'dummy locale backup')
 [IO.File]::WriteAllText((Join-Path $game 'Data/enUS/realmlist.wtf'),'PRIVATE_REALM_VALUE')
 [IO.File]::WriteAllText((Join-Path $game 'Data/PRIVATE_NAME.mpq'),'DO_NOT_SHOW_FILENAME')
 $private=Join-Path $game 'WTF/Account/SECRET_PERSON/sensitive.txt'
 [IO.File]::WriteAllText($private,'VERY_PRIVATE_ACCOUNT_DATA')
 [IO.File]::WriteAllText((Join-Path $game 'Interface/AddOns/PersonalAddon/PersonalAddon.toc'),'SECRET_ADDON_INFO')
 [IO.File]::WriteAllText((Join-Path $game 'Screenshots/private.jpg'),'PRIVATE_SCREENSHOT')
 foreach($p in @($policy.patches)){
  if($p.path -in @('Data/patch-V.mpq','Data/patch-Z.mpq','Data/Patch-U.mpq')){
   $dst=Join-Path $game ($p.path.Replace('/',[IO.Path]::DirectorySeparatorChar))
   [IO.File]::WriteAllText($dst,('fixture-'+[string]$p.path))
   $p.size_bytes=[long](Get-Item -LiteralPath $dst).Length
   $p.sha256=(Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash.ToLowerInvariant()
  }
 }
 $policy|ConvertTo-Json -Depth 15|Set-Content -LiteralPath (Join-Path $repoTest 'config/client-patches.json') -Encoding UTF8
 $testScript=Join-Path $repoTest 'tools/Inventory-Game-Files.ps1'
 $output=Join-Path $base 'reports/files-full.json'
 $before=(Get-FileHash -LiteralPath $private -Algorithm SHA256).Hash
 function Run([string]$out,[string[]]$options){
  $result=(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $testScript -ClientPath $game -ReportPath $out @options 2>&1|Out-String)
  return [pscustomobject]@{Code=$LASTEXITCODE;Text=$result}
 }
 $r=Run $output @()
 if($r.Code -ne 0 -or -not (Test-Path -LiteralPath $output)){throw ('Full inventory failed: '+$r.Text)}
 $report=Get-Content -LiteralPath $output -Raw|ConvertFrom-Json
 if($report.kind -cne 'read_only_whitelisted_game_file_inventory' -or
    $report.hash_mode -cne 'sha256_per_file' -or
    $report.inventory_complete_for_game_install -ne $false -or
    $report.build_confirmed -ne $false -or
    $report.excluded_unknown_mpq_count -ne 1 -or
    $report.client_modified -ne $false -or
    $report.absolute_paths_included -ne $false){
  throw 'Inventory metadata incorrectly reports completeness, privacy or trust.'
 }
 foreach($n in @('Data/patch-V.mpq','Data/patch-Z.mpq','Data/Patch-U.mpq')){
  $file=@($report.files|Where-Object {$_.relative_path -ceq $n})
  if($file.Count -ne 1 -or $file[0].integrity -cne 'pinned_verified' -or
     [string]::IsNullOrWhiteSpace([string]$file[0].sha256)){
   throw "Pinned fixture patch was not verified: $n"
  }
 }
 foreach($n in @('Data/Patch-J.mpq','Data/Patch-C.mpq')){
  $patch=@($report.pinned_patches|Where-Object {$_.relative_path -ceq $n})
  if($patch.Count -ne 1 -or $patch[0].status -cne 'not_installed'){throw 'Optional J/C status was incorrect.'}
 }
 if(@($report.files|Where-Object {$_.relative_path -ceq 'Data/common.MPQ'}).Count -ne 1 -or
    @($report.files|Where-Object {$_.relative_path -ceq 'Data/enUS/locale-enUS.MPQ'}).Count -ne 1){
  throw 'Case-insensitive game archives were not enumerated.'
 }
 foreach($n in @('Data/enUS/base-enUS.MPQ','Data/enUS/BACKUP-enUS.mpq')){
  $found=@($report.files|Where-Object {$_.relative_path -ceq $n})
  if($found.Count -ne 1 -or $found[0].component -cne 'base_archive_candidate' -or
    $found[0].integrity -cne 'not_pinned' -or [string]::IsNullOrWhiteSpace([string]$found[0].sha256)){
   throw ('New locale candidate not correctly classified: '+$n)
  }
 }
 foreach($n in @('ijl15.dll','DBGHELP.DLL')){
  $match=@($report.files|Where-Object {$_.relative_path -ceq $n})
  if($match.Count -ne 1 -or $match[0].component -cne 'client_binary_candidate' -or
     $match[0].integrity -cne 'not_pinned' -or [long]$match[0].byte_size -le 0 -or
     [string]$match[0].sha256 -cnotmatch '^[0-9a-f]{64}$'){
   throw ('Full inventory missing a valid unpinned candidate: '+$n)
  }
 }
 if(@($report.files|Where-Object {$_.relative_path -ieq 'fmodex.dll'}).Count -ne 0){
  throw 'Root file outside M14 allowlist appeared in report.'
 }
 $text=Get-Content -LiteralPath $output -Raw
 foreach($forbidden in @('SECRET_PERSON','VERY_PRIVATE_ACCOUNT_DATA','PRIVATE_NAME','DO_NOT_SHOW_FILENAME','PRIVATE_REALM_VALUE','PersonalAddon','SECRET_ADDON_INFO','PRIVATE_SCREENSHOT','DUMMY OTHER ROOT CANDIDATE','fmodex.dll',$game)){
  if($text.Contains($forbidden)){throw 'Private data leaked into manifest: '+$forbidden}
 }
 $quickFile=Join-Path $base 'reports/files-quick.json'
 $quickRun=Run $quickFile @('-Quick')
 if($quickRun.Code -ne 0){throw ('Quick inventory failed: '+$quickRun.Text)}
 $quick=Get-Content -LiteralPath $quickFile -Raw|ConvertFrom-Json
 foreach($n in @('ijl15.dll','DBGHELP.DLL')){
  $match=@($quick.files|Where-Object {$_.relative_path -ceq $n})
  if($match.Count -ne 1 -or $null -ne $match[0].sha256 -or
     $match[0].integrity -cne 'not_pinned'){
   throw ('Quick mode falsely verified or omitted '+$n)
  }
 }
 if($quick.hash_mode -cne 'sizes_only_unverified' -or
    @($quick.files|Where-Object {$null -ne $_.sha256}).Count -ne 0 -or
    @($quick.pinned_patches|Where-Object {$_.required -and $_.status -cne 'not_checked_quick_mode'}).Count -ne 0){
  throw 'Quick mode was incorrectly treated as hash verified.'
 }
 $duplicate=Run $output @()
 if($duplicate.Code -eq 0 -or -not $duplicate.Text.Contains('already exists')){throw 'Existing report was overwritten.'}
 $unsafe=Run (Join-Path $game 'client-report.json') @()
 if($unsafe.Code -eq 0 -or -not $unsafe.Text.Contains('inside the WoW client')){
  throw 'Report inside game was not rejected.'
 }
 [IO.File]::WriteAllText((Join-Path $game 'Data/patch-Z.mpq'),'tampered')
 $tamperFile=Join-Path $base 'reports/files-tampered.json'
 $tamperRun=Run $tamperFile @()
 if($tamperRun.Code -ne 0){throw ('Tamper test scanner failed: '+$tamperRun.Text)}
 $tamper=Get-Content -LiteralPath $tamperFile -Raw|ConvertFrom-Json
 $z=@($tamper.pinned_patches|Where-Object {$_.relative_path -ceq 'Data/patch-Z.mpq'})[0]
 if($z.status -cne 'pinned_mismatch'){throw 'Corrupted mandatory patch was incorrectly verified.'}
 if((Get-FileHash -LiteralPath $private -Algorithm SHA256).Hash -ne $before){throw 'Client personal data was modified.'}
 if(Test-Path -LiteralPath (Join-Path $game 'client-report.json')){throw 'A report was written into game.'}
 Write-Host 'ALL WHITELISTED GAME FILE INVENTORY TESTS PASSED'
}finally{
 if(Test-Path -LiteralPath $base){Remove-Item -LiteralPath $base -Recurse -Force}
}
exit 0
