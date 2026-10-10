#requires -Version 5.1
# M26: read-only recovery decisions based on verified M25 results; dummy files only.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
$program=Join-Path $repo 'tools/Plan-Fixture-Recovery.ps1'
$recovery=Join-Path $repo 'tools/Inspect-Fixture-Recovery.ps1'
$stageInspector=Join-Path $repo 'tools/Inspect-Fixture-Stage.ps1'
foreach($s in @($program,$recovery,$stageInspector,(Join-Path $repo 'tools/Inspect-Fixture-Transaction-Status.ps1'))){
 $tok=$null;$err=$null
 [Management.Automation.Language.Parser]::ParseFile($s,[ref]$tok,[ref]$err)|Out-Null
 if(@($err).Count -gt 0){throw ('M25 script failed parsing: '+($err -join '; '))}
}
$base=Join-Path ([IO.Path]::GetTempPath()) ('naxx-m26-'+[guid]::NewGuid().ToString('N'))
try{
 foreach($p in @('fake-repo/tools','src/Data/enUS','dest','manifests','unrelated')){
  New-Item -Path (Join-Path $base $p) -ItemType Directory -Force|Out-Null
 }
 $runner=Join-Path $base 'fake-repo/tools/Plan-Fixture-Recovery.ps1'
 foreach($name in @('Plan-Fixture-Recovery.ps1','Inspect-Fixture-Transaction-Status.ps1','Inspect-Fixture-Recovery.ps1','Inspect-Fixture-Stage.ps1')){
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
  $expectedExit=if($good){0}else{1}
  $blocked=($transaction.StartsWith('BLOCKED_',[StringComparison]::Ordinal) -or
   $stageStatus.StartsWith('BLOCKED_',[StringComparison]::Ordinal))
  $decision=if($blocked){'STOP_PRESERVE_AND_ESCALATE'}
   elseif($transaction -ceq 'EMPTY_MARKED_DESTINATION_NO_JOURNAL' -and
    $stageStatus -ceq 'NOT_SELECTED'){'NO_TRANSACTION_ACTION_SUGGESTED'}
   else{'HUMAN_REVIEW_ONLY'}
  if($r.code -ne $expectedExit -or
    -not $r.text.Contains('TRANSACTION: '+$transaction) -or
    -not $r.text.Contains('STAGE: '+$stageStatus) -or
    -not $r.text.Contains('DECISION: '+$decision) -or
    -not $r.text.Contains('PERMITTED AUTOMATIC ACTIONS: NONE')){
   throw ('M26 decision mismatch in '+$label+': '+$r.text)
  }
  $review=switch($transaction){
   'EMPTY_MARKED_DESTINATION_NO_JOURNAL' {'NO_TRANSACTION_JOURNAL_RECORDED';break}
   'VERIFIED_PARTIAL_APPLYING' {'REVIEW_INTERRUPTED_COPY_AGAINST_BACKUP';break}
   'VERIFIED_COPIED' {'VERIFY_EXPECTED_COPIED_RESULT_MANUALLY';break}
   'VERIFIED_PARTIAL_ROLLBACK' {'REVIEW_INTERRUPTED_ROLLBACK_AGAINST_BACKUP';break}
   default {'STOP_AND_PRESERVE_UNCERTAIN_TRANSACTION';break}
  }
  if(-not $r.text.Contains('TRANSACTION REVIEW: '+$review)){
   throw ('M26 transaction review mismatch in '+$label+': '+$r.text)
  }
  $stageReview=switch($stageStatus){
   'NOT_SELECTED' {'NO_STAGE_SELECTED_OR_DISCOVERED';break}
   'CONSISTENT_REQUIRES_MANUAL_REVIEW' {'INSPECT_NOMINATED_STAGE_NO_CLEANUP_AUTHORISED';break}
   default {'PRESERVE_UNTRUSTED_STAGE_FOR_MANUAL_REVIEW';break}
  }
  if(-not $r.text.Contains('STAGE REVIEW: '+$stageReview)){
   throw ('M26 stage review mismatch in '+$label+': '+$r.text)
  }
  foreach($private in @($base,'FAKE M25 DATA','Account','PRIVATE_SECRET')){
   if($r.text.Contains($private)){throw ('M26 console exposed private dummy data in '+$label)}
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
 # Copied is only consistent when every fixture file exists and hashes match.
 foreach($name in @('Data/common.mpq','Data/patch-Z.mpq','Data/enUS/locale-enUS.mpq')){
  $to=Join-Path $dest ($name.Replace('/',[IO.Path]::DirectorySeparatorChar))
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($to))|Out-Null
  [IO.File]::Copy((Join-Path $src ($name.Replace('/',[IO.Path]::DirectorySeparatorChar))),$to)
 }
 Expect 'fully copied fixture' $true 'VERIFIED_COPIED' 'NOT_SELECTED'
 foreach($name in @('Data/common.mpq','Data/patch-Z.mpq','Data/enUS/locale-enUS.mpq')){
  [IO.File]::Delete((Join-Path $dest ($name.Replace('/',[IO.Path]::DirectorySeparatorChar))))
 }
 [IO.Directory]::Delete((Join-Path $dest 'Data/enUS'))
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
 Write-Host 'ALL M26 READ-ONLY RECOVERY DECISION TESTS PASSED'
}finally{
 if(Test-Path -LiteralPath $base){Remove-Item -LiteralPath $base -Recurse -Force}
}
exit 0
