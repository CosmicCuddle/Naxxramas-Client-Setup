#requires -Version 5.1
# M29 junction regression: every file created here is a disposable tiny fixture.
# Junctions only target directories INSIDE this freshly created test root.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
$engine=Join-Path $repo 'tools/Test-Client-Copy-Fixture.ps1'
$tk=$null;$issues=$null
[Management.Automation.Language.Parser]::ParseFile($engine,[ref]$tk,[ref]$issues)|Out-Null
if(@($issues).Count -ne 0){throw ('M29 fixture engine parse failed: '+($issues -join '; '))}
$base=Join-Path ([IO.Path]::GetTempPath()) ('naxx-m29-junction-'+[guid]::NewGuid().ToString('N'))
$junctions=New-Object 'System.Collections.Generic.List[string]'
function CreateSafeJunction([string]$link,[string]$target){
 if(Test-Path -LiteralPath $link){throw 'Test junction destination must not exist.'}
 if(-not (Test-Path -LiteralPath $target -PathType Container)){throw 'Test junction target missing.'}
 $cmd='mklink /J "'+$link+'" "'+$target+'"'
 $output=(& cmd.exe /d /c $cmd 2>&1|Out-String)
 if($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $link -PathType Container)){
  throw ('Windows junction creation failed (CI fixture only): '+$output)
 }
 $item=Get-Item -LiteralPath $link -Force
 if(-not [bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint)){
  throw 'mklink test path is not a Windows reparse point.'
 }
 $junctions.Add($link)
}
function RunDummy([string]$file,[string]$src,[string]$dst,[string]$mf,[string]$mode,[bool]$paused){
 $args=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$file,
  '-SourcePath',$src,'-DestinationPath',$dst,'-ManifestPath',$mf,
  '-Action',$mode,'-ConfirmDisposableFixture')
 if($paused){
  if($mode -ceq 'Rollback'){$args+=@('-SyntheticExternalPauseBeforeRollbackSeconds','10')}
  else{$args+=@('-SyntheticExternalPauseBeforePromotionSeconds','10')}
 }
 $result=(& powershell.exe @args 2>&1|Out-String)
 return [pscustomobject]@{Code=$LASTEXITCODE;Output=$result}
}
try{
 [IO.Directory]::CreateDirectory($base)|Out-Null
 foreach($scenario in @('copy-source-data','copy-stage-data','rollback-destination-data')){
  $case=Join-Path $base $scenario
  foreach($relative in @('stub/tools','source/Data/enUS','destination','manifests')){
   [IO.Directory]::CreateDirectory((Join-Path $case $relative))|Out-Null
  }
  $runner=Join-Path $case 'stub/tools/Test-Client-Copy-Fixture.ps1'
  Copy-Item -LiteralPath $engine -Destination $runner
  $src=Join-Path $case 'source'
  $dest=Join-Path $case 'destination'
  $mf=Join-Path $case 'manifests/dummy.json'
  $journal=Join-Path $dest '.naxx-fixture-copy-journal.json'
  [IO.File]::WriteAllText((Join-Path $src '.naxx-copy-test-source'),'NAXX_SYNTHETIC_COPY_SOURCE_V1')
  [IO.File]::WriteAllText((Join-Path $dest '.naxx-copy-test-destination'),'NAXX_SYNTHETIC_COPY_DESTINATION_V1')
  $names=@('Wow.exe','Data/common.mpq','Data/enUS/locale-enUS.mpq','Data/patch-V.mpq','Data/patch-Z.mpq')
  $files=@(foreach($name in $names){
   $p=Join-Path $src ($name.Replace('/',[IO.Path]::DirectorySeparatorChar))
   [IO.File]::WriteAllText($p,('M29 FAKE '+$name))
   [ordered]@{relative_path=$name;byte_size=[long](Get-Item -LiteralPath $p).Length;
    sha256=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant()}
  })
  [ordered]@{schema_version=1;kind='naxx_synthetic_copy_fixture';synthetic_fixture=$true;
   complete_game_client=$false;files=$files}|ConvertTo-Json -Depth 10|
   Set-Content -LiteralPath $mf -Encoding UTF8
  $isRollback=($scenario -ceq 'rollback-destination-data')
  if($isRollback){
   $setup=RunDummy $runner $src $dest $mf 'Copy' $false
   if($setup.Code -ne 0){throw ('Could not prepare disposable rollback case: '+$setup.Output)}
  }
  $operation=if($isRollback){'Rollback'}else{'Copy'}
  # Start-Job runs in a DIFFERENT PowerShell process. The parent then creates
  # a junction replacing Data while the child is paused after journal update.
  $job=Start-Job -ArgumentList @($runner,$src,$dest,$mf,$operation) -ScriptBlock {
   param($script,$s,$d,$m,$action)
   $args=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$script,
    '-SourcePath',$s,'-DestinationPath',$d,'-ManifestPath',$m,
    '-Action',$action,'-ConfirmDisposableFixture')
   if($action -ceq 'Rollback'){$args+=@('-SyntheticExternalPauseBeforeRollbackSeconds','10')}
   else{$args+=@('-SyntheticExternalPauseBeforePromotionSeconds','10')}
   $out=(& powershell.exe @args 2>&1|Out-String)
   [pscustomobject]@{Code=$LASTEXITCODE;Output=$out}
  }
  try{
   $expectedJournalStatus=if($isRollback){'rolling_back'}else{'applying'}
   $ready=$false
   $deadline=[DateTime]::UtcNow.AddSeconds(35)
   while([DateTime]::UtcNow -lt $deadline){
    if(Test-Path -LiteralPath $journal -PathType Leaf){
     try{
      $j=Get-Content -LiteralPath $journal -Raw|ConvertFrom-Json
      if($j.status -ceq $expectedJournalStatus -and $j.destination -ceq $dest){
       $ready=$true;break
      }
     }catch{}
    }
    if(@('Running','NotStarted') -cnotcontains $job.State){break}
    Start-Sleep -Milliseconds 75
   }
   if(-not $ready){throw ('Child did not reach the synthetic journal checkpoint: '+$scenario)}
   $dataDir=if($scenario -ceq 'copy-source-data'){Join-Path $src 'Data'}
    elseif($scenario -ceq 'copy-stage-data'){
     $stageFolders=@(Get-ChildItem -LiteralPath $case -Directory -Force|
      Where-Object {$_.Name -cmatch '^\.naxx-test-copy-stage-[0-9a-f]{32}$'})
     if($stageFolders.Count -ne 1){throw 'Expected one stage at junction checkpoint.'}
     Join-Path $stageFolders[0].FullName 'Data'
    }else{Join-Path $dest 'Data'}
   $archived=Join-Path $case ('original-Data-'+$scenario)
   [IO.Directory]::Move($dataDir,$archived)
   $sentinel=Join-Path $archived 'EXTERNAL_PRESERVE_SENTINEL.txt'
   [IO.File]::WriteAllText($sentinel,'EXTERNAL DUMMY DATA MUST SURVIVE')
   CreateSafeJunction $dataDir $archived
   $null=Wait-Job -Job $job -Timeout 45
   if($job.State -ne 'Completed'){throw ('Junction test worker unfinished: '+$scenario)}
   $results=@(Receive-Job -Job $job)
   if($results.Count -ne 1 -or $results[0].Code -eq 0){
    throw ('Junction test operation did not fail closed: '+$scenario+' '+($results|Out-String))
   }
   if(-not (Test-Path -LiteralPath $sentinel) -or
    (Get-Content -LiteralPath $sentinel -Raw) -cne 'EXTERNAL DUMMY DATA MUST SURVIVE'){
    throw ('Junction target sentinel changed or disappeared: '+$scenario)
   }
   if(-not (Test-Path -LiteralPath (Join-Path $archived 'common.mpq'))){
    throw ('Original dummy archive unexpectedly erased: '+$scenario)
   }
   if($isRollback){
    if(-not (Test-Path -LiteralPath $journal) -or
     -not (Test-Path -LiteralPath (Join-Path $dest 'Wow.exe'))){
     throw 'Rollback followed junction or destroyed retained rollback journal.'
    }
   }else{
    if(Test-Path -LiteralPath (Join-Path $dest 'Wow.exe')){
     throw ('Copy promoted a file after injected junction: '+$scenario)
    }
   }
   # No production repair, deletion, or source file modification is performed.
   Write-Host ('M29 '+$scenario.ToUpperInvariant()+' JUNCTION SWAP REFUSED')
  }finally{
   if($job.State -eq 'Running'){Stop-Job -Job $job}
   Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
  }
 }
 Write-Host 'ALL M29 DISPOSABLE JUNCTION SWAP TESTS PASSED'
}finally{
 # NEVER recursively delete a directory while it contains junctions: first
 # unlink only verified reparse-point names created by this test harness.
 foreach($path in @($junctions)){
  if(Test-Path -LiteralPath $path){
   $i=Get-Item -LiteralPath $path -Force
   if(-not [bool]($i.Attributes -band [IO.FileAttributes]::ReparsePoint)){
    throw 'Unsafe test cleanup: expected junction replaced by non-junction.'
   }
   [IO.Directory]::Delete($path)
  }
 }
 if(Test-Path -LiteralPath $base){Remove-Item -LiteralPath $base -Recurse -Force}
}
exit 0
