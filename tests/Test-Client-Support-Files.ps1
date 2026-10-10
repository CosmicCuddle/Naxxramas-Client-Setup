#requires -Version 5.1
# Synthetic fixtures only. No Blizzard binaries, accounts or client archives.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
$tool=Join-Path $repo 'tools/Inspect-Client-Support-Files.ps1'
$tokens=$null;$parseErrors=$null
[Management.Automation.Language.Parser]::ParseFile($tool,[ref]$tokens,[ref]$parseErrors)|Out-Null
if(@($parseErrors).Count -gt 0){throw ('Support auditor failed to parse: '+($parseErrors -join '; '))}
$base=Join-Path ([IO.Path]::GetTempPath()) ('naxx-support-audit-test-'+[guid]::NewGuid().ToString('N'))
try{
 foreach($relative in @('game/Data/enUS','game/Interface/AddOns/PrivateAddon',
   'game/WTF/Account/PRIVATE_OWNER','game/Screenshots','game/Cache','game/Logs','no-wow/Data/enUS')){
  New-Item -Path (Join-Path $base $relative) -ItemType Directory -Force|Out-Null
 }
 $game=Join-Path $base 'game'
 $private=Join-Path $game 'WTF/Account/PRIVATE_OWNER/secret.txt'
 $privateValue='PRIVATE_DATA_NEVER_READ_OR_DISPLAY'
 [IO.File]::WriteAllText($private,$privateValue)
 [IO.File]::WriteAllText((Join-Path $game 'Wow.exe'),'FAKE EXE NOT A REAL GAME')
 [IO.File]::WriteAllText((Join-Path $game 'fmodex.dll'),'FAKE LIBRARY')
 [IO.File]::WriteAllText((Join-Path $game 'Interface/AddOns/PrivateAddon/secret.toc'),'PRIVATE_ADDON_DATA')
 [IO.File]::WriteAllText((Join-Path $game 'Screenshots/private.png'),'PRIVATE_IMAGE')
 [IO.File]::WriteAllText((Join-Path $game 'Cache/secret.txt'),'PRIVATE_CACHE')
 [IO.File]::WriteAllText((Join-Path $game 'Logs/secret.log'),'PRIVATE_LOG')
 [IO.File]::WriteAllText((Join-Path $game 'Data/enUS/realmlist.wtf'),'PRIVATE_REALMLIST')
 $countBefore=@(Get-ChildItem -LiteralPath $base -Recurse -File -Force).Count
 $hashBefore=(Get-FileHash -LiteralPath $private -Algorithm SHA256).Hash
 $r=(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tool -ClientPath $game 2>&1|Out-String)
 if($LASTEXITCODE -ne 0){throw ('Synthetic support audit failed: '+$r)}
 foreach($required in @('NAXXRAMAS NON-MPQ SUPPORT FILE AUDIT','Wow.exe : present',
  'fmodex.dll : present','Launcher.exe : not present',
  'Data/enUS : present','Interface/AddOns : present',
  'Candidate file counts: present 2; not present 11.',
  'This is NOT a complete, verified','no report or upload')){
  if(-not $r.Contains($required)){throw ('Missing expected result: '+$required)}
 }
 foreach($forbidden in @('PRIVATE_OWNER','PRIVATE_DATA_NEVER_READ_OR_DISPLAY','PRIVATE_REALMLIST',
   'PRIVATE_ADDON_DATA','PRIVATE_IMAGE','PRIVATE_CACHE','PRIVATE_LOG','secret.txt',$game)){
  if($r.Contains($forbidden)){throw 'Private content/path leaked in console.'}
 }
 if(@(Get-ChildItem -LiteralPath $base -Recurse -File -Force).Count -ne $countBefore){
  throw 'Support audit wrote a file.'
 }
 if((Get-FileHash -LiteralPath $private -Algorithm SHA256).Hash -cne $hashBefore){
  throw 'Support audit modified private fixture file.'
 }
 $bad=(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tool -ClientPath (Join-Path $base 'no-wow') 2>&1|Out-String)
 if($LASTEXITCODE -eq 0 -or -not $bad.Contains('Select the folder containing Wow.exe')){
  throw 'Folder without Wow.exe not rejected.'
 }
 Write-Host 'ALL NON-MPQ SUPPORT AUDIT FIXTURE TESTS PASSED'
}finally{
 if(Test-Path -LiteralPath $base){Remove-Item -LiteralPath $base -Recurse -Force}
}
exit 0
