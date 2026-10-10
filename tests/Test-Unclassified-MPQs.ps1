#requires -Version 5.1
# Synthetic-only validation of read-only, local-only MPQ classification.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
$tool=Join-Path $repo 'tools/Inspect-Unclassified-MPQs.ps1'
$tokens=$null;$errors=$null
[Management.Automation.Language.Parser]::ParseFile($tool,[ref]$tokens,[ref]$errors)|Out-Null
if(@($errors).Count -ne 0){throw ('PowerShell parser errors: '+($errors -join '; '))}
$root=Join-Path ([IO.Path]::GetTempPath()) ('naxx-mpq-classify-'+[guid]::NewGuid().ToString('N'))
try{
 foreach($r in @('game/Data/enUS','game/WTF/Account/SECRET','game/Interface/AddOns/Secret')){
  New-Item -Path (Join-Path $root $r) -ItemType Directory -Force|Out-Null
 }
 $game=Join-Path $root 'game'
 foreach($r in @('Wow.exe','Data/common.MPQ','Data/Patch-U.mpq','Data/enUS/locale-enUS.MPQ',
                   'Data/backup-enUS.MPQ','Data/enUS/base-enUS.MPQ','Data/enUS/BACKUP-enUS.mpq',
                   'Data/enUS/owner-unclassified.MpQ',
                   'Data/ignore.txt','WTF/Account/SECRET/config.txt','Interface/AddOns/Secret/SECRET.toc')){
  $p=Join-Path $game $r.Replace('/',[IO.Path]::DirectorySeparatorChar)
  [IO.File]::WriteAllText($p,'DUMMY FIXTURE ONLY')
 }
 $before=(Get-FileHash -LiteralPath (Join-Path $game 'Data/backup-enUS.MPQ') -Algorithm SHA256).Hash
 $output=(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tool -ClientPath $game 2>&1|Out-String)
 if($LASTEXITCODE -ne 0){throw ('Classification failed: '+$output)}
 foreach($fragment in @('Recognised MPQ filenames: 5','Unclassified MPQs: 2',
  'Data/backup-enUS.MPQ','Data/enUS/owner-unclassified.MpQ',
  'No report was saved. No files were changed or uploaded.')){
  if(-not $output.Contains($fragment)){throw ('Expected classification missing: '+$fragment)}
 }
 foreach($secret in @('SECRET','Data/common.MPQ','Data/Patch-U.mpq','Data/enUS/locale-enUS.MPQ','Data/enUS/base-enUS.MPQ','Data/enUS/BACKUP-enUS.mpq','Data/ignore.txt')){
  if($output.Contains($secret)){throw 'Allowed or private filename was unexpectedly printed.'}
 }
 if((Get-FileHash -LiteralPath (Join-Path $game 'Data/backup-enUS.MPQ') -Algorithm SHA256).Hash -cne $before){
  throw 'Fixture archive modified.'
 }
 if(@(Get-ChildItem -LiteralPath $root -Recurse -File -Force).Count -ne 11){throw 'Unexpected report or file was created.'}
 Write-Host 'ALL LOCAL MPQ CLASSIFICATION TESTS PASSED'
}finally{
 if(Test-Path -LiteralPath $root){Remove-Item -LiteralPath $root -Recurse -Force}
}
exit 0
