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
 throw 'GUI unexpectedly includes an install action or lacks background work safeguards.'
}
# Verify classic launcher composition and strictly read-only controls.
$guiBlob=[IO.File]::ReadAllText($gui)
foreach($needle in @(
 'NAXXRAMAS',
 'INSTALLATION OPTIONS',
 'LATEST NEWS',
 'launcher-art.png',
 'launcher-logo.png',
 'assets/default',
 '$artImage.SizeMode=[Windows.Forms.PictureBoxSizeMode]::Zoom',
 '$artLayout.RowCount=1',
 'LAUNCHER ARTWORK UNAVAILABLE',
 '$mode.TextAlign=',
 'READ-ONLY',
 '$form.AcceptButton=$preview',
 '$form.Add_KeyDown',
 '$cancel.Add_Click',
 'CLASSIC LAUNCHER LAYOUT TEST PASSED',
 '$result.AccessibleName=',
 'New-NaxxPreviewRequest',
 'New-NaxxSourceDownloadRequest',
 'New-NaxxFreshPreviewRequest',
 'FRESH CLIENT SELECTOR SAFETY TEST PASSED',
 'Fresh client - planning only',
 'Get-NaxxBrowseInitialFolder (Normalize-NaxxInputPath $box.Text)',
 'EMPTY FOLDER BROWSE TEST PASSED',
 'DIRECT CTRL+V PATH TEST PASSED',
 'Normalize-NaxxInputPath',
 '$download.Add_Click',
 'Get patches',
 'Confirm patch-source download',
 'TBC login (C)',
 '$tbc.Add_CheckedChanged',
 '-TbcLogin $tbc.Checked'
)){
 if(-not $guiBlob.Contains($needle)){throw ("Missing classic launcher feature: "+$needle)}
}
foreach($forbidden in @(
 'Choose artwork...',
 'Included artwork - can be replaced',
 'Personal artwork - overrides default',
 'assets/local',
 '$artPick',
 '$artBar',
 '[string]$ArtRoot',
 '$artPick.Add_Click'
)){
 if($guiBlob.Contains($forbidden)){throw ("Players can still select artwork: "+$forbidden)}
}
foreach($forbidden in @('$paste.Add_Click','Get-NaxxCopiedPath','Convert-NaxxCopiedPath')){
 if($guiBlob.Contains($forbidden)){throw ('Unwanted Paste control logic remains: '+$forbidden)}
}
if($guiBlob.Contains('Test-Path -LiteralPath $box.Text')){
 throw 'Browse still sends empty text fields directly to Test-Path.'
}
if($guiBlob.Contains('$art.Add_Paint')){
 throw 'Old manually painted artwork frame was not removed.'
}
if($guiBlob -match '-Action\s+(Install|Rollback|Recover)' -or
   $guiBlob -match 'Invoke-WebRequest|Start-BitsTransfer'){
 throw 'Classic preview unexpectedly exposes installation or network commands.'
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
 [switch]$TbcLogin,
 [switch]$VanillaLoading
)
Write-Output "ACTION=$Action"
Write-Output "CLIENT=$ClientPath"
Write-Output ("ADDONS="+($Addons -join '|'))
Write-Output "READ-ONLY PLAN COMPLETE"
'@
 [IO.File]::WriteAllText($script,$fakeScript)
 # A synthetic download stub is only used to validate the GUI argument builder.
 [IO.File]::WriteAllText((Join-Path $repoFixture 'tools/Get-Patch-Sources.ps1'),'param()')
 [IO.File]::WriteAllText((Join-Path $repoFixture 'tools/Plan-Fresh-Client.ps1'),'param()')
 $freshRequest=New-NaxxFreshPreviewRequest -DestinationPath $patches -TbcLogin $true -VanillaLoading $true -Addons @('DungeonJournal') -RepositoryPath $repoFixture
 if($freshRequest.Mode -ne 'FreshPlan' -or $freshRequest.Parameters.Action -ne 'Plan' -or
    $freshRequest.Parameters.ContainsKey('Apply') -or
    $freshRequest.Parameters.ContainsKey('ConfirmDownload') -or
    $freshRequest.Parameters.ContainsKey('ClientPath') -or
    -not $freshRequest.Parameters.TbcLogin){
  throw 'Fresh preview requested unsafe operations.'
 }
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
 if ($LASTEXITCODE -ne 0 -or -not $display.Contains('GUI PREVIEW WINDOW CONSTRUCTED') -or -not $display.Contains('EMPTY FOLDER BROWSE TEST PASSED') -or -not $display.Contains('DIRECT CTRL+V PATH TEST PASSED') -or -not $display.Contains('FRESH CLIENT SELECTOR SAFETY TEST PASSED')) {
  throw ("Window construction smoke test failed: "+$display)
 }
 # Verify the fixed default image is loaded from a copy of the repository,
 # then replace ONLY launcher-art.png and verify the executable code is unchanged.
 $artRepo=Join-Path $fixture 'default-art-package'
 $artTools=Join-Path $artRepo 'tools'
 $artAssets=Join-Path $artRepo 'assets/default'
 foreach($dir in @($artTools,$artAssets)){
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
 }
 Copy-Item -LiteralPath $gui -Destination (Join-Path $artTools 'Naxxramas-Preview.ps1')
 Copy-Item -LiteralPath $lib -Destination (Join-Path $artTools 'GUI-Preview-Lib.ps1')
 Add-Type -AssemblyName System.Drawing
 $fixedPath=Join-Path $artAssets 'launcher-art.png'
 $packagedGui=Join-Path $artTools 'Naxxramas-Preview.ps1'
 $sameCode=(Get-FileHash -LiteralPath $packagedGui -Algorithm SHA256).Hash
 $previousArtHash=$null
 foreach($shade in @([Drawing.Color]::DarkRed,[Drawing.Color]::DarkBlue)){
  $bitmap=[Drawing.Bitmap]::new(80,40)
  try{
   $drawing=[Drawing.Graphics]::FromImage($bitmap)
   try{$drawing.Clear($shade)}finally{$drawing.Dispose()}
   $bitmap.Save($fixedPath,[Drawing.Imaging.ImageFormat]::Png)
  }finally{$bitmap.Dispose()}
  $newArtHash=(Get-FileHash -LiteralPath $fixedPath -Algorithm SHA256).Hash.ToLowerInvariant()
  if($previousArtHash -and $previousArtHash -eq $newArtHash){throw 'Replaced artwork was identical.'}
  $display=(& powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File $packagedGui -SmokeTest 2>&1 | Out-String)
  if($LASTEXITCODE -ne 0 -or -not $display.Contains('EMPTY FOLDER BROWSE TEST PASSED') -or -not $display.Contains('DIRECT CTRL+V PATH TEST PASSED') -or -not $display.Contains('FRESH CLIENT SELECTOR SAFETY TEST PASSED') -or -not $display.Contains("DEFAULT ARTWORK SHA256: $newArtHash") -or
     -not $display.Contains('CLASSIC LAUNCHER LAYOUT TEST PASSED')){
   throw ("Fixed default artwork smoke test failed: "+$display)
  }
  $previousArtHash=$newArtHash
 }
 if((Get-FileHash -LiteralPath $packagedGui -Algorithm SHA256).Hash -ne $sameCode){
  throw 'Artwork replacement unexpectedly changed the application code.'
 }
  $tbcReq=New-NaxxPreviewRequest -Mode Plan -ClientPath $game -PatchSourcePath $patches -TbcLogin $true -VanillaLoading $true -RepositoryPath $repoFixture
 if(-not $tbcReq.Parameters.TbcLogin -or $tbcReq.Parameters.ContainsKey('VanillaLogin')) {throw 'TBC login was not sent safely to backend.'}
 $blocked=$false
 try{$null=New-NaxxPreviewRequest -Mode Plan -ClientPath $game -TbcLogin $true -VanillaLogin $true -RepositoryPath $repoFixture}catch{$blocked=$true}
 if(-not $blocked){throw 'GUI helper accepted both J and C.'}
 $downloadReq=New-NaxxSourceDownloadRequest -ClientPath $game -PatchSourcePath $patches -TbcLogin $true -VanillaLoading $true -RepositoryPath $repoFixture
 if($downloadReq.Mode -ne 'Download' -or -not $downloadReq.Parameters.ConfirmDownload -or
    $downloadReq.Parameters.ContainsKey('Apply') -or
    $downloadReq.Parameters.ContainsKey('ConfirmDisposableFixture') -or
    -not $downloadReq.Parameters.TbcLogin){
  throw 'Unsafe or incomplete GUI download request.'
 }
 $blocked=$false
 try{$null=New-NaxxSourceDownloadRequest -ClientPath $game -PatchSourcePath '' -RepositoryPath $repoFixture}catch{$blocked=$true}
 if(-not $blocked){throw 'Source download did not require a separate patch folder.'}
 $blocked=$false
 try{$null=New-NaxxSourceDownloadRequest -ClientPath $game -PatchSourcePath $patches -VanillaLogin $true -TbcLogin $true -RepositoryPath $repoFixture}catch{$blocked=$true}
 if(-not $blocked){throw 'GUI download request accepted simultaneous Vanilla and TBC login options.'}
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
