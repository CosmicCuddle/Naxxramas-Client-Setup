#requires -Version 5.1
# GUI tests are HEADLESS. No WinForms dialog is opened; no game files are used.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
$gui=Join-Path $repo 'tools/Naxxramas-Preview.ps1'
$lib=Join-Path $repo 'tools/GUI-Preview-Lib.ps1'
foreach($file in @($gui,$lib)){
 $tokens=$null;$parseErrors=$null
 [Management.Automation.Language.Parser]::ParseFile($file,[ref]$tokens,[ref]$parseErrors)|Out-Null
 if(@($parseErrors).Count -gt 0){throw ("Invalid PowerShell syntax in "+$file+": "+($parseErrors -join '; '))}
}
$source=[IO.File]::ReadAllText($gui)
if($source -match '-Action\s+(Install|Rollback|Recover)' -or
   $source -notmatch "New-NaxxPreviewRequest" -or
   $source -notmatch 'Start-Job'){
 throw 'GUI is not restricted to safe asynchronous plan/inspect operations.'
}
. $lib
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('naxx-gui-check-'+[guid]::NewGuid().ToString('N'))
try{
 $repoFixture=Join-Path $fixture 'repo'
 $game=Join-Path $fixture "WoW's Client & Safety"
 $patches=Join-Path $fixture 'Patch source'
 $zip=Join-Path $fixture 'suite v2.zip'
 foreach($folder in @($game,$patches,(Join-Path $repoFixture 'tools'))) {
  New-Item -ItemType Directory -Path $folder -Force|Out-Null
 }
 [IO.File]::WriteAllBytes((Join-Path $game 'Wow.exe'),[byte[]]@(0))
 [IO.File]::WriteAllBytes($zip,[byte[]]@(1,2))
 $script=Join-Path $repoFixture 'tools/Setup-Prototype.ps1'
 $fakeScript=@'
param(
 [ValidateSet('Plan','Inspect')][string]$Action='Plan',
 [string]$ClientPath,
 [string]$PatchSourcePath,
 [string]$AddonSuiteArchivePath,
 [string[]]$Addons=@(),
 [switch]$VanillaLogin,
 [switch]$VanillaLoading
)
Write-Output "ACTION=$Action"
Write-Output "CLIENT=$ClientPath"
Write-Output ("ADDONS="+($Addons -join '|'))
Write-Output "READ-ONLY PLAN COMPLETE"
'@
 [IO.File]::WriteAllText($script,$fakeScript)
 $req=New-NaxxPreviewRequest -Mode Plan -ClientPath $game -PatchSourcePath $patches -AddonSuiteArchivePath $zip -VanillaLogin $true -VanillaLoading $true -Addons @('DungeonJournal','DungeonJournal','MultiBot') -RepositoryPath $repoFixture
 if($req.Parameters.Action -ne 'Plan' -or $req.Parameters.ContainsKey('Apply') -or
    $req.Parameters.ContainsKey('ConfirmDisposableFixture') -or
    $req.Parameters.ContainsKey('SimulateCrashAfter')) {
  throw 'Preview request gained an unsafe write-capable flag.'
 }
 if(@($req.Parameters.Addons).Count -ne 2 -or -not $req.Parameters.VanillaLogin -or
    -not $req.Parameters.VanillaLoading) {
  throw 'Optional GUI settings were not represented correctly.'
 }
 # Verify that special characters in folder names are NOT evaluated as commands.
 $job=Start-Job -ScriptBlock {
  param([string]$entry,[hashtable]$arguments)
  & $entry @arguments 2>&1 | Out-String
 } -ArgumentList $req.ScriptPath,$req.Parameters
 try {
  $null=Wait-Job -Job $job -Timeout 25
  if($job.State -ne 'Completed'){throw "Read-only background job failed: $($job.State)"}
  $text=(@(Receive-Job -Job $job -ErrorAction Stop)|ForEach-Object{[string]$_}) -join [Environment]::NewLine
  if(-not $text.Contains('ACTION=Plan') -or
     -not $text.Contains("CLIENT=$game") -or
     -not $text.Contains('ADDONS=DungeonJournal|MultiBot')) {
   throw "Plan background job arguments were altered: $text"
  }
 } finally { Remove-Job -Job $job -Force -ErrorAction SilentlyContinue }
 $command=Join-Path $repo 'tools/Naxxramas-Preview.ps1'
 $display=(& powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File $command -SmokeTest 2>&1 | Out-String)
 if ($LASTEXITCODE -ne 0 -or -not $display.Contains('GUI PREVIEW WINDOW CONSTRUCTED')) {
  throw ("Window construction smoke test failed: "+$display)
 }
  $inspect=New-NaxxPreviewRequest -Mode Inspect -ClientPath $game -PatchSourcePath $patches -AddonSuiteArchivePath $zip -VanillaLogin $true -Addons @('DungeonJournal') -RepositoryPath $repoFixture
 if(@($inspect.Parameters.Keys).Count -ne 2 -or $inspect.Parameters.Action -ne 'Inspect'){
  throw 'Inspect mode should receive only Action and ClientPath.'
 }
 $blocked=$false
 try{$null=New-NaxxPreviewRequest -Mode Install -ClientPath $game -RepositoryPath $repoFixture}catch{$blocked=$true}
 if(-not $blocked){throw 'Write actions must not be exposed through the GUI builder.'}
 $blocked=$false
 try{$null=New-NaxxPreviewRequest -Mode Plan -ClientPath $game -Addons @('DungeonJournal') -RepositoryPath $repoFixture}catch{$blocked=$true}
 if(-not $blocked){throw 'Addon checkboxes were allowed without a ZIP source.'}
 $blocked=$false
 try{$null=New-NaxxPreviewRequest -Mode Plan -ClientPath $game -AddonSuiteArchivePath $zip -Addons @('UnknownAddon') -RepositoryPath $repoFixture}catch{$blocked=$true}
 if(-not $blocked){throw 'Unknown addon option bypassed allowlist.'}
 if(Test-Path -LiteralPath (Join-Path $game '.naxxramas-setup')){throw 'GUI request builder wrote to client.'}
 Write-Host 'ALL HEADLESS GUI PREVIEW TESTS PASSED' -ForegroundColor Green
}finally{
 if(Test-Path -LiteralPath $fixture){Remove-Item -LiteralPath $fixture -Recurse -Force}
}
exit 0
