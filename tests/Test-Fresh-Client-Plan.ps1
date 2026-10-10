#requires -Version 5.1
# Read-only fresh-client planning tests. Uses ONLY temporary empty directories.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
$engine=Join-Path $repo 'tools/Plan-Fresh-Client.ps1'
$lib=Join-Path $repo 'tools/GUI-Preview-Lib.ps1'
foreach($file in @($engine,$lib)){
 $tokens=$null;$errors=$null
 [Management.Automation.Language.Parser]::ParseFile($file,[ref]$tokens,[ref]$errors)|Out-Null
 if(@($errors).Count -gt 0){throw ("PowerShell parse failed: "+($errors -join '; '))}
}
$base=Join-Path ([IO.Path]::GetTempPath()) ('naxx-fresh-plan-'+[guid]::NewGuid().ToString('N'))
try{
 $fixtureRepo=Join-Path $base 'repo'
 $dest=Join-Path $base 'New WoW Client'
 $occupied=Join-Path $base 'Occupied'
 $nested=Join-Path $fixtureRepo 'Games'
 foreach($dir in @('repo/tools','repo/config','New WoW Client','Occupied','repo/Games')){
  New-Item -ItemType Directory -Path (Join-Path $base $dir) -Force|Out-Null
 }
 Copy-Item -LiteralPath $engine -Destination (Join-Path $fixtureRepo 'tools/Plan-Fresh-Client.ps1')
 Copy-Item -LiteralPath $lib -Destination (Join-Path $fixtureRepo 'tools/GUI-Preview-Lib.ps1')
 Copy-Item -LiteralPath (Join-Path $repo 'config/base-client-source.json') -Destination (Join-Path $fixtureRepo 'config/base-client-source.json')
 [IO.File]::WriteAllText((Join-Path $occupied 'keep-my-data.txt'),'THIS MUST NOT BE CHANGED')
 $before=(Get-FileHash -LiteralPath (Join-Path $occupied 'keep-my-data.txt') -Algorithm SHA256).Hash
 $scriptPath=Join-Path $fixtureRepo 'tools/Plan-Fresh-Client.ps1'
 function Invoke-Fresh([string]$folder,[string[]]$extra){
  $result=(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath -DestinationPath $folder @extra 2>&1|Out-String)
  return [pscustomobject]@{Output=$result;Code=$LASTEXITCODE}
 }
 $r=Invoke-Fresh $dest @('-TbcLogin','-VanillaLoading','-Addons','DungeonJournal')
 if($r.Code -ne 0 -or -not $r.Output.Contains('FRESH CLIENT PLAN COMPLETE') -or
    -not $r.Output.Contains('BASE CLIENT: BLOCKED') -or
    -not $r.Output.Contains('Burning Crusade Patch C') -or
    -not $r.Output.Contains('N-Addon Collection: NCore required') -or
    -not $r.Output.Contains('Data') -and -not $r.Output.Contains('realmlist')){
  throw ('Fresh safe planning failed: '+$r.Output)
 }
 if(@(Get-ChildItem -LiteralPath $dest -Force).Count -ne 0){throw 'Plan wrote into an empty destination.'}
 foreach($folder in @($occupied,$nested,$fixtureRepo)){
  $r=Invoke-Fresh $folder @()
  if($r.Code -eq 0){throw "Fresh plan accepted an unsafe destination: $folder"}
 }
 $r=Invoke-Fresh $dest @('-VanillaLogin','-TbcLogin')
 if($r.Code -eq 0 -or -not $r.Output.Contains('only one login screen')){throw 'Fresh plan allowed J and C together.'}
 $r=Invoke-Fresh (Join-Path $base 'missing-folder') @()
 if($r.Code -eq 0){throw 'Fresh plan accepted a missing destination.'}
 $policy=Join-Path $fixtureRepo 'config/base-client-source.json'
 $data=Get-Content -LiteralPath $policy -Raw|ConvertFrom-Json
 $data.enabled=$true
 $data|ConvertTo-Json -Depth 15|Set-Content -LiteralPath $policy -Encoding UTF8
 $r=Invoke-Fresh $dest @()
 if($r.Code -eq 0 -or -not $r.Output.Contains('enabled unexpectedly')){throw 'A manifest flip enabled the game downloader.'}
 $data.enabled=$false
 $data|ConvertTo-Json -Depth 15|Set-Content -LiteralPath $policy -Encoding UTF8
 . $lib
 $request=New-NaxxFreshPreviewRequest -DestinationPath $dest -VanillaLogin $true -Addons @('MultiBot','DungeonJournal','MultiBot') -RepositoryPath $fixtureRepo
 if($request.Mode -cne 'FreshPlan' -or $request.Parameters.Action -cne 'Plan' -or
    $request.Parameters.ContainsKey('Apply') -or $request.Parameters.ContainsKey('ConfirmDownload') -or
    $request.Parameters.ContainsKey('ClientPath') -or
    @($request.Parameters.Addons).Count -ne 2){
  throw 'Fresh GUI request builder passed an unsafe or incomplete command.'
 }
 $blocked=$false
 try{$null=New-NaxxFreshPreviewRequest -DestinationPath $dest -VanillaLogin $true -TbcLogin $true -RepositoryPath $fixtureRepo}catch{$blocked=$true}
 if(-not $blocked){throw 'Fresh GUI builder allowed conflicting login selections.'}
 if((Get-FileHash -LiteralPath (Join-Path $occupied 'keep-my-data.txt') -Algorithm SHA256).Hash -ne $before){
  throw 'Occupied directory contents were unexpectedly changed.'
 }
 Write-Host 'ALL FRESH-CLIENT READ-ONLY FIXTURE TESTS PASSED' -ForegroundColor Green
}finally{
 if(Test-Path -LiteralPath $base){Remove-Item -LiteralPath $base -Recurse -Force}
}
exit 0
