#requires -Version 5.1
# Milestone 16: synthetic-only JSON review tests.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
$scanner=Join-Path $repo 'tools/Inventory-Game-Files.ps1'
$reviewer=Join-Path $repo 'tools/Review-Game-File-Report.ps1'
foreach($file in @($scanner,$reviewer)){
 $tokens=$null;$errors=$null
 [Management.Automation.Language.Parser]::ParseFile($file,[ref]$tokens,[ref]$errors)|Out-Null
 if(@($errors).Count -ne 0){throw ('PowerShell parsing failed: '+($errors -join '; '))}
}
$base=Join-Path ([IO.Path]::GetTempPath()) ('naxx-report-review-test-'+[guid]::NewGuid().ToString('N'))
try{
 foreach($rel in @('repo/tools','repo/config','client/Data/enUS','reports')){
  New-Item -Path (Join-Path $base $rel) -ItemType Directory -Force|Out-Null
 }
 $fakeRepo=Join-Path $base 'repo'
 $client=Join-Path $base 'client'
 $fakeScan=Join-Path $fakeRepo 'tools/Inventory-Game-Files.ps1'
 $fakeReview=Join-Path $fakeRepo 'tools/Review-Game-File-Report.ps1'
 Copy-Item -LiteralPath $scanner -Destination $fakeScan
 Copy-Item -LiteralPath $reviewer -Destination $fakeReview
 [IO.File]::WriteAllText((Join-Path $client 'Wow.exe'),'DUMMY ONLY WOW.EXE')
 [IO.File]::WriteAllText((Join-Path $client 'Data/common.MPQ'),'DUMMY COMMON')
 [IO.File]::WriteAllText((Join-Path $client 'Data/enUS/locale-enUS.MPQ'),'DUMMY LOCALE')
 [IO.File]::WriteAllText((Join-Path $client 'Data/enUS/base-enUS.MPQ'),'DUMMY BASE LOCALE')
 [IO.File]::WriteAllText((Join-Path $client 'Data/enUS/backup-enUS.MPQ'),'DUMMY BACKUP LOCALE')
 $policy=Get-Content -LiteralPath (Join-Path $repo 'config/client-patches.json') -Raw|ConvertFrom-Json
 foreach($p in @($policy.patches)){
  if([string]$p.path -in @('Data/patch-V.mpq','Data/patch-Z.mpq','Data/Patch-U.mpq')){
   $dest=Join-Path $client ([string]$p.path).Replace('/',[IO.Path]::DirectorySeparatorChar)
   [IO.File]::WriteAllText($dest,('SYNTHETIC '+[string]$p.path))
   $p.size_bytes=[long](Get-Item -LiteralPath $dest).Length
   $p.sha256=(Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash.ToLowerInvariant()
  }
 }
 $policy|ConvertTo-Json -Depth 15|Set-Content -LiteralPath (Join-Path $fakeRepo 'config/client-patches.json') -Encoding UTF8
 function Scan([string]$dest,[string[]]$options){
  $output=(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $fakeScan -ClientPath $client -ReportPath $dest @options 2>&1|Out-String)
  if($LASTEXITCODE -ne 0){throw ('Dummy scanner failed: '+$output)}
 }
 function Review([string]$file){
  $out=(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $fakeReview -ReportPath $file 2>&1|Out-String)
  return [pscustomobject]@{Code=$LASTEXITCODE;Text=$out}
 }
 function WriteReport([object]$obj,[string]$name){
  $where=Join-Path (Join-Path $base 'reports') $name
  $obj|ConvertTo-Json -Depth 15|Set-Content -LiteralPath $where -Encoding UTF8
  return $where
 }
 $full=Join-Path $base 'reports/full.json'
 Scan $full @()
 $fullHash=(Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
 $good=Review $full
 if($good.Code -ne 0 -or -not $good.Text.Contains('REPORT STRUCTURE: CONSISTENT') -or
    -not $good.Text.Contains('V/Z REPORTED HASHES AGAINST POLICY: MATCH') -or
    -not $good.Text.Contains('INSTALL/DOWNLOAD: BLOCKED')){throw ('Correct full scan rejected: '+$good.Text)}
 $rpt=Get-Content -LiteralPath $full -Raw|ConvertFrom-Json
 foreach($name in @('Data/enUS/base-enUS.MPQ','Data/enUS/backup-enUS.MPQ')){
  $found=@($rpt.files|Where-Object {$_.relative_path -ceq $name})
  if($found.Count -ne 1 -or $found[0].component -cne 'base_archive_candidate' -or
    $found[0].integrity -cne 'not_pinned'){
   throw ('Locale MPQ not accepted by M16 reviewer: '+$name)
  }
 }

 $quick=Join-Path $base 'reports/quick.json'
 Scan $quick @('-Quick')
 $q=Review $quick
 if($q.Code -ne 0 -or -not $q.Text.Contains('MISSING, MISMATCHED OR UNVERIFIED') -or
    -not $q.Text.Contains('Quick inventory has no file hashes')){throw ('Quick scan falsely trusted: '+$q.Text)}
 $r=Get-Content -LiteralPath $full -Raw|ConvertFrom-Json
 $r.files[0].relative_path='WTF/PRIVATE_ACCOUNT_DATA.xml'
 $bad=Review (WriteReport $r 'private-path.json')
 if($bad.Code -eq 0 -or -not $bad.Text.Contains('Non-allowlisted inventory path') -or
    $bad.Text.Contains('PRIVATE_ACCOUNT_DATA')){throw 'Private or unknown report path incorrectly handled.'}
 $r=Get-Content -LiteralPath $full -Raw|ConvertFrom-Json
 $v=@($r.files|Where-Object {$_.relative_path -ieq 'Data/patch-V.mpq'})[0]
 $v.sha256=('0'*64)
 $bad=Review (WriteReport $r 'forged-patch.json')
 if($bad.Code -eq 0 -or -not $bad.Text.Contains('status disagrees')){throw 'Forged V patch claim accepted.'}
 $r=Get-Content -LiteralPath $full -Raw|ConvertFrom-Json
 $r.files += $r.files[0]
 $r.file_count=[int]$r.file_count+1
 $r.total_inventoried_bytes=[long]$r.total_inventoried_bytes+[long]$r.files[0].byte_size
 if((Review (WriteReport $r 'duplicate.json')).Code -eq 0){throw 'Duplicate path accepted.'}
 $r=Get-Content -LiteralPath $quick -Raw|ConvertFrom-Json
 $r.files[0].sha256=('a'*64)
 if((Review (WriteReport $r 'quick-hash.json')).Code -eq 0){throw 'Quick scan falsely supplied a hash.'}
 $r=Get-Content -LiteralPath $full -Raw|ConvertFrom-Json
 $r.absolute_paths_included=$true
 if((Review (WriteReport $r 'unsafe.json')).Code -eq 0){throw 'Unsafe report flags accepted.'}
 $r=Get-Content -LiteralPath $full -Raw|ConvertFrom-Json
 $z=@($r.files|Where-Object {$_.relative_path -ieq 'Data/patch-Z.mpq'})[0]
 $z.sha256=('b'*64);$z.integrity='pinned_mismatch'
 @($r.pinned_patches|Where-Object {$_.relative_path -ieq 'Data/patch-Z.mpq'})[0].status='pinned_mismatch'
 $r.required_patches_unverified=@('Data/patch-Z.mpq')
 $mismatch=Review (WriteReport $r 'honest-mismatch.json')
 if($mismatch.Code -ne 0 -or -not $mismatch.Text.Contains('MISSING, MISMATCHED OR UNVERIFIED')){
  throw ('Correctly labeled damage must be reported without claiming success: '+$mismatch.Text)
 }
 if((Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash -cne $fullHash){throw 'Report was changed by reviewer.'}
 if((Get-Content -LiteralPath (Join-Path $client 'Wow.exe') -Raw) -cne 'DUMMY ONLY WOW.EXE'){throw 'Fixture client was modified.'}
 Write-Host 'ALL PRIVATE INVENTORY REVIEW TESTS PASSED'
}finally{
 if(Test-Path -LiteralPath $base){Remove-Item -LiteralPath $base -Recurse -Force}
}
exit 0
