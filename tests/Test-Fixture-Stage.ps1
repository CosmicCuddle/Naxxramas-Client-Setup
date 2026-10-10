#requires -Version 5.1
# Disposable M22 read-only stage audit. Fake bytes and folder names only.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
$tool=Join-Path $repo 'tools/Inspect-Fixture-Stage.ps1'
$t=$null;$err=$null
[Management.Automation.Language.Parser]::ParseFile($tool,[ref]$t,[ref]$err)|Out-Null
if(@($err).Count -ne 0){throw ('M22 script parse error: '+($err -join '; '))}
$base=Join-Path ([IO.Path]::GetTempPath()) ('naxx-stage-audit-'+[guid]::NewGuid().ToString('N'))
try{
 foreach($relative in @('repo/tools','source/Data/enUS','destination','manifests','other-stage')){
  New-Item -Path (Join-Path $base $relative) -ItemType Directory -Force|Out-Null
 }
 $runner=Join-Path $base 'repo/tools/Inspect-Fixture-Stage.ps1'
 Copy-Item -LiteralPath $tool -Destination $runner
 $src=Join-Path $base 'source'
 $dest=Join-Path $base 'destination'
 $stage=Join-Path $base '.naxx-test-copy-stage-1234567890abcdef1234567890abcdef'
 [IO.Directory]::CreateDirectory($stage)|Out-Null
 $manifest=Join-Path $base 'manifests/synthetic.json'
 $ownerPath=Join-Path $stage '.naxx-fixture-stage-owner.json'
 [IO.File]::WriteAllText((Join-Path $src '.naxx-copy-test-source'),'NAXX_SYNTHETIC_COPY_SOURCE_V1')
 [IO.File]::WriteAllText((Join-Path $dest '.naxx-copy-test-destination'),'NAXX_SYNTHETIC_COPY_DESTINATION_V1')
 $names=@('Wow.exe','Data/common.mpq','Data/patch-V.mpq','Data/patch-Z.mpq','Data/enUS/locale-enUS.mpq')
 $rows=@(foreach($name in $names){
  $p=Join-Path $src ($name.Replace('/',[IO.Path]::DirectorySeparatorChar))
  [IO.File]::WriteAllText($p,('SYNTHETIC ONLY '+$name))
  [ordered]@{relative_path=$name;byte_size=[long](Get-Item -LiteralPath $p).Length;sha256=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant()}
 })
 $data=[ordered]@{schema_version=1;kind='naxx_synthetic_copy_fixture';synthetic_fixture=$true;complete_game_client=$false;files=$rows}
 $owner=[ordered]@{schema_version=1;kind='naxx_synthetic_stage_marker';synthetic_fixture=$true;source=$src;destination=$dest;stage=$stage;files=$rows}
 function Save([object]$item,[string]$path){$item|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $path -Encoding UTF8}
 Save $data $manifest
 Save $owner $ownerPath
 function InvokeAudit([string]$stagePath){
  $o=(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -SourcePath $src -DestinationPath $dest -ManifestPath $manifest -StagePath $stagePath 2>&1 | Out-String)
  return [pscustomobject]@{code=$LASTEXITCODE;text=$o}
 }
 function Expect([string]$label,[bool]$valid,[string]$detail){
  $a=InvokeAudit $stage
  $status=if($valid){'CONSISTENT_FOR_MANUAL_REVIEW'}else{'STAGE AUDIT: BLOCKED'}
  if(($a.code -eq 0) -ne $valid -or -not $a.text.Contains($status) -or
    -not $a.text.Contains($detail)){throw ('Unexpected '+$label+': '+$a.text)}
 }
 $sourceDigest=(Get-FileHash -LiteralPath (Join-Path $src 'Data/patch-Z.mpq') -Algorithm SHA256).Hash
 $stageMarkerDigest=(Get-FileHash -LiteralPath $ownerPath -Algorithm SHA256).Hash
 Expect 'empty stage' $true 'HASH-VERIFIED STAGED FILES: 0; ABSENT EXPECTED FILES: 5'
 foreach($name in @('Wow.exe','Data/patch-V.mpq')){
  $target=Join-Path $stage ($name.Replace('/',[IO.Path]::DirectorySeparatorChar))
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))|Out-Null
  [IO.File]::Copy((Join-Path $src ($name.Replace('/',[IO.Path]::DirectorySeparatorChar))),$target)
 }
 Expect 'partially staged' $true 'HASH-VERIFIED STAGED FILES: 2; ABSENT EXPECTED FILES: 3'
 [IO.File]::AppendAllText((Join-Path $stage 'Data/patch-V.mpq'),'CHANGED')
 Expect 'modified staged file' $false 'Staged dummy file size differs'
 [IO.File]::Delete((Join-Path $stage 'Data/patch-V.mpq'))
 [IO.File]::Copy((Join-Path $src 'Data/patch-V.mpq'),(Join-Path $stage 'Data/patch-V.mpq'))
 [IO.Directory]::CreateDirectory((Join-Path $stage 'Data/unknown-empty'))|Out-Null
 Expect 'unknown empty folder' $false 'Unexpected stage content'
 [IO.Directory]::Delete((Join-Path $stage 'Data/unknown-empty'))
 [IO.File]::WriteAllText((Join-Path $stage 'extra.txt'),'NOT OWNED')
 Expect 'unknown file' $false 'Unexpected stage content'
 [IO.File]::Delete((Join-Path $stage 'extra.txt'))
 $owner.destination='DIFFERENT';Save $owner $ownerPath
 Expect 'wrong owner destination' $false 'ownership claim'
 $owner.destination=$dest;Save $owner $ownerPath
 [IO.File]::Delete($ownerPath)
 Expect 'missing marker' $false 'Required fixture metadata is absent'
 Save $owner $ownerPath
 $outside=InvokeAudit (Join-Path $base 'other-stage')
 if($outside.code -eq 0 -or -not $outside.text.Contains('STAGE AUDIT: BLOCKED')){throw 'Unrelated stage was accepted.'}
 Expect 'restored stage' $true 'HASH-VERIFIED STAGED FILES: 2'
 if((Get-FileHash -LiteralPath (Join-Path $src 'Data/patch-Z.mpq') -Algorithm SHA256).Hash -cne $sourceDigest){throw 'Inspector changed source.'}
 if(@(Get-ChildItem -LiteralPath $stage -Recurse -File -Force).Count -ne 3){throw 'Inspector unexpectedly created or removed stage files.'}
 if((Get-FileHash -LiteralPath $ownerPath -Algorithm SHA256).Hash -ne $stageMarkerDigest){throw 'Inspector changed stage owner marker.'}
 Write-Host 'ALL SYNTHETIC STAGE READ-ONLY AUDIT TESTS PASSED'
}finally{
 if(Test-Path -LiteralPath $base){Remove-Item -LiteralPath $base -Recurse -Force}
}
exit 0
