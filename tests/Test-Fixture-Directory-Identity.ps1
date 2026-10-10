#requires -Version 5.1
# M28: independent OS process replaces marker-locked disposable folders.
# Do NOT run on game folders. The only files created here are tiny fake data.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
$engine=Join-Path $repo 'tools/Test-Client-Copy-Fixture.ps1'
$tokens=$null;$issues=$null
[Management.Automation.Language.Parser]::ParseFile($engine,[ref]$tokens,[ref]$issues)|Out-Null
if(@($issues).Count -gt 0){throw ('M28 fixture engine parse failure: '+($issues -join '; '))}
$base=Join-Path ([IO.Path]::GetTempPath()) ('naxx-m28-identity-'+[guid]::NewGuid().ToString('N'))
try{
 [IO.Directory]::CreateDirectory($base)|Out-Null
 foreach($which in @('source','destination','stage')){
  $case=Join-Path $base $which
  foreach($relative in @('stub/tools','source/Data/enUS','destination','manifests')){
   [IO.Directory]::CreateDirectory((Join-Path $case $relative))|Out-Null
  }
  $runner=Join-Path $case 'stub/tools/Test-Client-Copy-Fixture.ps1'
  Copy-Item -LiteralPath $engine -Destination $runner
  $sourcePath=Join-Path $case 'source'
  $destPath=Join-Path $case 'destination'
  $manifest=Join-Path $case 'manifests/dummy.json'
  $journal=Join-Path $destPath '.naxx-fixture-copy-journal.json'
  [IO.File]::WriteAllText((Join-Path $sourcePath '.naxx-copy-test-source'),'NAXX_SYNTHETIC_COPY_SOURCE_V1')
  [IO.File]::WriteAllText((Join-Path $destPath '.naxx-copy-test-destination'),'NAXX_SYNTHETIC_COPY_DESTINATION_V1')
  $names=@('Wow.exe','Data/common.mpq','Data/enUS/locale-enUS.mpq','Data/patch-V.mpq','Data/patch-Z.mpq')
  $rows=@(foreach($name in $names){
   $file=Join-Path $sourcePath ($name.Replace('/',[IO.Path]::DirectorySeparatorChar))
   [IO.File]::WriteAllText($file,('M28 DUMMY '+$name))
   [ordered]@{relative_path=$name;byte_size=[long](Get-Item -LiteralPath $file).Length;
    sha256=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()}
  })
  [ordered]@{schema_version=1;kind='naxx_synthetic_copy_fixture';synthetic_fixture=$true;
    complete_game_client=$false;files=$rows}|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $manifest -Encoding UTF8
  $job=Start-Job -ArgumentList @($runner,$sourcePath,$destPath,$manifest) -ScriptBlock {
   param($file,$src,$dst,$mf)
   $output=(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $file -SourcePath $src -DestinationPath $dst -ManifestPath $mf -Action Copy -ConfirmDisposableFixture -SyntheticExternalPauseBeforePromotionSeconds 10 2>&1|Out-String)
   [pscustomobject]@{Code=$LASTEXITCODE;Output=$output}
  }
  try{
   $deadline=[DateTime]::UtcNow.AddSeconds(30)
   $ready=$false
   while([DateTime]::UtcNow -lt $deadline){
    if(Test-Path -LiteralPath $journal -PathType Leaf){
     try{
      $j=Get-Content -LiteralPath $journal -Raw|ConvertFrom-Json
      if($j.status -ceq 'applying' -and $j.destination -ceq $destPath){$ready=$true;break}
     }catch{}
    }
    if(@('Running','NotStarted') -cnotcontains $job.State){break}
    Start-Sleep -Milliseconds 75
   }
   if(-not $ready){throw ('M28 child did not reach journal barrier: '+$which)}
   $stages=@(Get-ChildItem -LiteralPath $case -Directory -Force|
    Where-Object {$_.Name -cmatch '^\.naxx-test-copy-stage-[0-9a-f]{32}$'})
   if($stages.Count -ne 1){throw 'Expected one disposable stage at barrier.'}
   $oldFolder=if($which -ceq 'source'){$sourcePath}
     elseif($which -ceq 'destination'){$destPath}
     else{$stages[0].FullName}
   $archived=Join-Path $case ('archived-'+$which)
   [IO.Directory]::Move($oldFolder,$archived)
   [IO.Directory]::CreateDirectory($oldFolder)|Out-Null
   if($which -ceq 'source'){
    [IO.File]::WriteAllText((Join-Path $oldFolder '.naxx-copy-test-source'),'NAXX_SYNTHETIC_COPY_SOURCE_V1')
   }elseif($which -ceq 'destination'){
    [IO.File]::WriteAllText((Join-Path $oldFolder '.naxx-copy-test-destination'),'NAXX_SYNTHETIC_COPY_DESTINATION_V1')
   }else{
    # Even a same-name empty replacement must not be mistaken for owned stage.
    [IO.File]::WriteAllText((Join-Path $oldFolder 'EXTERNAL-OWNER-DATA.txt'),'DO NOT DELETE')
   }
   $null=Wait-Job -Job $job -Timeout 35
   if($job.State -ne 'Completed'){throw ('M28 child did not finish: '+$which)}
   $result=@(Receive-Job -Job $job)
   if($result.Count -ne 1 -or $result[0].Code -ne 1 -or
     -not ([string]$result[0].Output).Contains('Fixture directory identity changed')){
    throw ('M28 directory replacement went undetected: '+$which+' => '+($result|Out-String))
   }
   if(-not (Test-Path -LiteralPath (Join-Path $archived 'Wow.exe'))){
    if($which -cne 'destination'){throw 'Original dummy file was lost after directory replacement.'}
   }
   if($which -ceq 'destination'){
    if(@(Get-ChildItem -LiteralPath $destPath -Force).Count -ne 1 -or
     -not (Test-Path -LiteralPath (Join-Path $archived '.naxx-fixture-copy-journal.json'))){
     throw 'Destination swap wrote to replacement or destroyed original journal.'
    }
   }elseif($which -ceq 'source'){
    if(-not (Test-Path -LiteralPath $journal) -or
      @(Get-ChildItem -LiteralPath $destPath -Force).Count -ne 2){
     throw 'Source replacement did not preserve the original journal safely.'
    }
    if(-not (Test-Path -LiteralPath (Join-Path $archived 'Wow.exe'))){
     throw 'Original moved source bytes were destroyed.'
    }
   }else{
    if(-not (Test-Path -LiteralPath (Join-Path $oldFolder 'EXTERNAL-OWNER-DATA.txt')) -or
       -not (Test-Path -LiteralPath (Join-Path $archived 'Wow.exe')) -or
       -not (Test-Path -LiteralPath $journal)){
     throw 'Stage replacement was cleaned or original stage lost.'
    }
   }
   Write-Host ('M28 EXTERNAL '+$which.ToUpperInvariant()+' DIRECTORY REPLACEMENT DETECTED')
  }finally{
   if($job.State -eq 'Running'){Stop-Job -Job $job}
   Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
  }
 }
 Write-Host 'ALL M28 DIRECTORY IDENTITY SWAP TESTS PASSED'
}finally{
 # This recursive deletion is exclusively in the CI dummy-fixture test harness.
 if(Test-Path -LiteralPath $base){Remove-Item -LiteralPath $base -Recurse -Force}
}
exit 0
