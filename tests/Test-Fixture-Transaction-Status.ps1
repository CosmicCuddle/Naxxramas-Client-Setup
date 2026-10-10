#requires -Version 5.1
# M25: disposable synthetic fixtures, no actual game files or player information.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
$program=Join-Path $repo 'tools/Inspect-Fixture-Transaction-Status.ps1'
$recovery=Join-Path $repo 'tools/Inspect-Fixture-Recovery.ps1'
$stageInspector=Join-Path $repo 'tools/Inspect-Fixture-Stage.ps1'
foreach($s in @($program,$recovery,$stageInspector)){
 $tok=$null;$err=$null
 [Management.Automation.Language.Parser]::ParseFile($s,[ref]$tok,[ref]$err)|Out-Null
 if(@($err).Count -gt 0){throw ('M25 script failed parsing: '+($err -join '; '))}
}
$base=Join-Path ([IO.Path]::GetTempPath()) ('naxx-m25-'+[guid]::NewGuid().ToString('N'))
try{
 foreach($p in @('fake-repo/tools','src/Data/enUS','dest','manifests','unrelated')){
  New-Item -Path (Join-Path $base $p) -ItemType Directory -Force|Out-Null
 }
 $runner=Join-Path $base 'fake-repo/tools/Inspect-Fixture-Transaction-Status.ps1'
 foreach($name in @('Inspect-Fixture-Transaction-Status.ps1','Inspect-Fixture-Recovery.ps1','Inspect-Fixture-Stage.ps1')){
  Copy-Item -LiteralPath (Join-Path $repo ('tools/'+$name)) -Destination (Join-Path $base ('fake-repo/tools/'+$name))
 }
 $src=Join-Path $base 'src'
 $dest=Join-Path $base 'dest'
 $mf=Join-Path $base 'manifests/fake.json'
 $journal=Join-Path $dest '.naxx-fixture-copy-journal.json'
 $stage=Join-Path $base '.naxx-test-copy-stage-1234567890abcdef1234567890abcdef'
 [IO.Directory]::CreateDirectory($stage)|Out-Null
 [IO.File]::WriteAllText((Join-Path $src '.naxx-copy-test-source'),'NAXX_SYNTHETIC_COPY_SOURCE_V1')
 [IO.File]::WriteAllText((Join-Path $dest '.naxx-copy-test-destination'),'NAXX_SYNTHETIC_COPY_DESTINATION_V1')
 $names=@('Wow.exe','Data/common.mpq','Data/patch-V.mpq','Data/patch-Z.mpq','Data/enUS/locale-enUS.mpq')
 $rows=@(foreach($name in $names){
  $file=Join-Path $src ($name.Replace('/',[IO.Path]::DirectorySeparatorChar))
  [IO.File]::WriteAllText($file,('FAKE M25 DATA '+$name))
  [ordered]@{relative_path=$name;byte_size=[long](Get-Item -LiteralPath $file).Length;
   sha256=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()}
 })
 $m=[ordered]@{schema_version=1;kind='naxx_synthetic_copy_fixture';synthetic_fixture=$true;
  complete_game_client=$false;files=$rows}
 $j=[ordered]@{schema_version=1;kind='naxx_fixture_copy_journal';
  source=$src;destination=$dest;status='applying';files=$rows}
 $owner=[ordered]@{schema_version=1;kind='naxx_synthetic_stage_marker';
  synthetic_fixture=$true;source=$src;destination=$dest;stage=$stage;files=$rows}
 function SaveJson([object]$data,[string]$path){
  $data|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $path -Encoding UTF8
 }
 SaveJson $m $mf
 function Audit([string]$stageArg=''){
  $arguments=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$runner,
   '-SourcePath',$src,'-DestinationPath',$dest,'-ManifestPath',$mf)
  if(-not [string]::IsNullOrWhiteSpace($stageArg)){$arguments+=@('-StagePath',$stageArg)}
  $output=(& powershell.exe @arguments 2>&1|Out-String)
  return [pscustomobject]@{code=$LASTEXITCODE;text=$output}
 }
 function Expect([string]$label,[bool]$good,[string]$transaction,[string]$stageStatus){
  $r=Audit $(if($stageStatus -ceq 'NOT_SELECTED'){''}else{$stage})
  $expect=if($good){0}else{1}
  if($r.code -ne $expect -or -not $r.text.Contains('TRANSACTION: '+$transaction) -or
   -not $r.text.Contains('STAGE: '+$stageStatus) -or
   -not $r.text.Contains('STATUS: '+$(if($good){
    if($transaction -ceq 'EMPTY_MARKED_DESTINATION_NO_JOURNAL' -and $stageStatus -ceq 'NOT_SELECTED'){'EMPTY_MARKED_FIXTURE'}
    else{'REVIEW_REQUIRED'}
   }else{'BLOCKED_MANUAL_REVIEW'}))){
   throw ('M25 status mismatch for '+$label+': '+$r.text)
  }
  foreach($private in @($base,'FAKE M25 DATA','Account','PRIVATE_SECRET')){
   if($r.text.Contains($private)){throw ('M25 console exposed private fixture data for '+$label)}
  }
 }
 $srcHash=(Get-FileHash -LiteralPath (Join-Path $src 'Data/patch-Z.mpq') -Algorithm SHA256).Hash
 Expect 'empty fixture' $true 'EMPTY_MARKED_DESTINATION_NO_JOURNAL' 'NOT_SELECTED'
 [IO.File]::WriteAllText((Join-Path $dest 'unexpected.txt'),'PRIVATE_SECRET')
 Expect 'unowned destination' $false 'BLOCKED_UNEXPECTED_DESTINATION_CONTENT' 'NOT_SELECTED'
 [IO.File]::Delete((Join-Path $dest 'unexpected.txt'))
 SaveJson $j $journal
 Expect 'empty applying journal' $true 'VERIFIED_PARTIAL_APPLYING' 'NOT_SELECTED'
 foreach($name in @('Wow.exe','Data/patch-V.mpq')){
  $to=Join-Path $dest ($name.Replace('/',[IO.Path]::DirectorySeparatorChar))
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($to))|Out-Null
  [IO.File]::Copy((Join-Path $src ($name.Replace('/',[IO.Path]::DirectorySeparatorChar))),$to)
 }
 Expect 'partially applied fixture' $true 'VERIFIED_PARTIAL_APPLYING' 'NOT_SELECTED'
 $j.status='copied';SaveJson $j $journal
 Expect 'false completed' $false 'BLOCKED_JOURNAL_OR_DESTINATION' 'NOT_SELECTED'
 $j.status='rolling_back';SaveJson $j $journal
 Expect 'partially rolled back' $true 'VERIFIED_PARTIAL_ROLLBACK' 'NOT_SELECTED'
 $j.status='applying';SaveJson $j $journal
 [IO.File]::WriteAllText(($journal+'.previous'),'UNTRUSTED BACKUP')
 Expect 'journal residue' $false 'BLOCKED_JOURNAL_REPLACEMENT_RESIDUE' 'NOT_SELECTED'
 [IO.File]::Delete(($journal+'.previous'))
 [IO.File]::WriteAllText($journal,'{')
 Expect 'truncated journal' $false 'BLOCKED_JOURNAL_OR_DESTINATION' 'NOT_SELECTED'
 SaveJson $j $journal
 [IO.File]::AppendAllText((Join-Path $dest 'Data/patch-V.mpq'),'OWNER CHANGE')
 Expect 'modified expected file' $false 'BLOCKED_JOURNAL_OR_DESTINATION' 'NOT_SELECTED'
 [IO.File]::Delete((Join-Path $dest 'Data/patch-V.mpq'))
 [IO.File]::Copy((Join-Path $src 'Data/patch-V.mpq'),(Join-Path $dest 'Data/patch-V.mpq'))
 Expect 'restored partial' $true 'VERIFIED_PARTIAL_APPLYING' 'NOT_SELECTED'
 [IO.File]::Delete($journal)
 [IO.File]::Delete((Join-Path $dest 'Wow.exe'))
 [IO.File]::Delete((Join-Path $dest 'Data/patch-V.mpq'))
 [IO.Directory]::Delete((Join-Path $dest 'Data'))
 SaveJson $owner (Join-Path $stage '.naxx-fixture-stage-owner.json')
 Expect 'valid selected stage' $true 'EMPTY_MARKED_DESTINATION_NO_JOURNAL' 'CONSISTENT_REQUIRES_MANUAL_REVIEW'
 [IO.Directory]::CreateDirectory((Join-Path $stage 'Data/unknown-empty'))|Out-Null
 Expect 'unknown empty stage folder' $false 'EMPTY_MARKED_DESTINATION_NO_JOURNAL' 'BLOCKED_UNTRUSTED_OR_CHANGED'
 [IO.Directory]::Delete((Join-Path $stage 'Data/unknown-empty'))
 [IO.File]::WriteAllText((Join-Path $stage '.naxx-fixture-stage-owner.json'),'{')
 Expect 'truncated stage marker' $false 'EMPTY_MARKED_DESTINATION_NO_JOURNAL' 'BLOCKED_UNTRUSTED_OR_CHANGED'
 SaveJson $owner (Join-Path $stage '.naxx-fixture-stage-owner.json')
 $beforeFiles=@(Get-ChildItem -LiteralPath $base -File -Recurse -Force).Count
 Expect 'unchanged final stage' $true 'EMPTY_MARKED_DESTINATION_NO_JOURNAL' 'CONSISTENT_REQUIRES_MANUAL_REVIEW'
 if(@(Get-ChildItem -LiteralPath $base -File -Recurse -Force).Count -ne $beforeFiles){
  throw 'M25 read-only audit created or removed a file.'
 }
 if((Get-FileHash -LiteralPath (Join-Path $src 'Data/patch-Z.mpq') -Algorithm SHA256).Hash -cne $srcHash){
  throw 'M25 read-only audit changed synthetic source bytes.'
 }
 Write-Host 'ALL M25 SYNTHETIC TRANSACTION STATUS TESTS PASSED'
}finally{
 if(Test-Path -LiteralPath $base){Remove-Item -LiteralPath $base -Recurse -Force}
}
exit 0
