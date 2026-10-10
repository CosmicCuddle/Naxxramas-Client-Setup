#requires -Version 5.1
# M27 external-process mutation tests. TINY SYNTHETIC MARKED FIXTURES ONLY.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
$engine=Join-Path $repo 'tools/Test-Client-Copy-Fixture.ps1'
$tokens=$null;$errors=$null
[Management.Automation.Language.Parser]::ParseFile($engine,[ref]$tokens,[ref]$errors)|Out-Null
if(@($errors).Count -ne 0){throw ('M27 engine syntax error: '+($errors -join '; '))}
$base=Join-Path ([IO.Path]::GetTempPath()) ('naxx-m27-'+[guid]::NewGuid().ToString('N'))
try{
 [IO.Directory]::CreateDirectory($base)|Out-Null
 foreach($which in @('source','stage','destination')){
  $case=Join-Path $base $which
  foreach($d in @('stub/tools','source/Data/enUS','dest','manifests')){
   [IO.Directory]::CreateDirectory((Join-Path $case $d))|Out-Null
  }
  $runner=Join-Path $case 'stub/tools/Test-Client-Copy-Fixture.ps1'
  Copy-Item -LiteralPath $engine -Destination $runner
  $source=Join-Path $case 'source'
  $dest=Join-Path $case 'dest'
  $manifest=Join-Path $case 'manifests/dummy.json'
  $journal=Join-Path $dest '.naxx-fixture-copy-journal.json'
  [IO.File]::WriteAllText((Join-Path $source '.naxx-copy-test-source'),'NAXX_SYNTHETIC_COPY_SOURCE_V1')
  [IO.File]::WriteAllText((Join-Path $dest '.naxx-copy-test-destination'),'NAXX_SYNTHETIC_COPY_DESTINATION_V1')
  $names=@('Wow.exe','Data/common.mpq','Data/enUS/locale-enUS.mpq','Data/patch-V.mpq','Data/patch-Z.mpq')
  $files=@(foreach($name in $names){
   $p=Join-Path $source ($name.Replace('/',[IO.Path]::DirectorySeparatorChar))
   [IO.File]::WriteAllText($p,('M27 DUMMY '+$name))
   [ordered]@{relative_path=$name;byte_size=[long](Get-Item -LiteralPath $p).Length;
    sha256=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant()}
  })
  [ordered]@{schema_version=1;kind='naxx_synthetic_copy_fixture';synthetic_fixture=$true;
   complete_game_client=$false;files=$files}|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $manifest -Encoding UTF8
  $vHash=(Get-FileHash -LiteralPath (Join-Path $source 'Data/patch-V.mpq') -Algorithm SHA256).Hash
  $job=Start-Job -ArgumentList @($runner,$source,$dest,$manifest) -ScriptBlock {
   param($script,$src,$dst,$mf)
   $output=(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script -SourcePath $src -DestinationPath $dst -ManifestPath $mf -Action Copy -ConfirmDisposableFixture -SyntheticExternalPauseBeforePromotionSeconds 10 2>&1|Out-String)
   [pscustomobject]@{Code=$LASTEXITCODE;Output=$output}
  }
  try{
   # The journal is written by the external copy process before it pauses.
   $ready=$false
   $deadline=[DateTime]::UtcNow.AddSeconds(25)
   while([DateTime]::UtcNow -lt $deadline){
    if(Test-Path -LiteralPath $journal -PathType Leaf){
     try{
      $j=Get-Content -LiteralPath $journal -Raw|ConvertFrom-Json
      if($j.status -ceq 'applying' -and $j.destination -ceq $dest){
       $ready=$true;break
      }
     }catch{}
    }
    if(@('Running','NotStarted') -cnotcontains $job.State){break}
    Start-Sleep -Milliseconds 75
   }
   if(-not $ready){throw ('External Copy never reached journal barrier: '+$which)}
   $sourceWow=Join-Path $source 'Wow.exe'
   $destWow=Join-Path $dest 'Wow.exe'
   $external='EXTERNAL M27 CONTENT - PRESERVE'
   $stageDirs=@(Get-ChildItem -LiteralPath $case -Directory -Force|
    Where-Object {$_.Name -cmatch '^\.naxx-test-copy-stage-[0-9a-f]{32}$'})
   if($stageDirs.Count -ne 1){throw 'Expected exactly one disposable stage.'}
   if($which -ceq 'source'){
    [IO.File]::AppendAllText($sourceWow,$external)
   }elseif($which -ceq 'stage'){
    [IO.File]::AppendAllText((Join-Path $stageDirs[0].FullName 'Wow.exe'),$external)
   }else{
    $bytes=[Text.UTF8Encoding]::new($false).GetBytes($external)
    $stream=[IO.File]::Open($destWow,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
   }
   $null=Wait-Job -Job $job -Timeout 35
   if($job.State -ne 'Completed'){throw ('External worker unfinished for '+$which)}
   $result=@(Receive-Job -Job $job)
   if($result.Count -ne 1 -or $result[0].Code -ne 1 -or
    -not ([string]$result[0].Output).Contains('Copy failed:')){
    throw ('Copy did not block external mutation '+$which+': '+($result|Out-String))
   }
   if((Get-FileHash -LiteralPath (Join-Path $source 'Data/patch-V.mpq') -Algorithm SHA256).Hash -cne $vHash){
    throw 'Unrelated synthetic source content was changed.'
   }
   if(Test-Path -LiteralPath $journal){throw 'Unexpected journal retained for safe mutation failure.'}
   $remaining=@(Get-ChildItem -LiteralPath $case -Directory -Force|
    Where-Object {$_.Name -cmatch '^\.naxx-test-copy-stage-[0-9a-f]{32}$'})
   if($which -ceq 'source'){
    if(-not (Get-Content -LiteralPath $sourceWow -Raw).Contains($external) -or
     (Test-Path -LiteralPath $destWow) -or $remaining.Count -ne 0){
     throw 'Changed source was lost or copied into destination.'
    }
   }elseif($which -ceq 'stage'){
    if($remaining.Count -ne 1 -or
     -not (Get-Content -LiteralPath (Join-Path $remaining[0].FullName 'Wow.exe') -Raw).Contains($external) -or
     (Test-Path -LiteralPath $destWow)){
     throw 'Changed staged bytes were erased or promoted.'
    }
   }else{
    if((Get-Content -LiteralPath $destWow -Raw) -cne $external -or $remaining.Count -ne 0){
     throw 'Unowned destination bytes were changed or cleanup became unsafe.'
    }
   }
   Write-Host ('M27 EXTERNAL '+$which.ToUpperInvariant()+' CHANGE: PRESERVED')
  }finally{
   if($job.State -eq 'Running'){Stop-Job -Job $job}
   Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
  }
 }
 Write-Host 'ALL M27 EXTERNAL-PROCESS MUTATION TESTS PASSED'
}finally{
 # A disposable test harness may remove ONLY the temporary folders it created.
 if(Test-Path -LiteralPath $base){Remove-Item -LiteralPath $base -Recurse -Force}
}
exit 0
