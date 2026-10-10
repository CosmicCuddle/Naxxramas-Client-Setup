#requires -Version 5.1
# Synthetic local downloads only; no network, no MPQs, and no actual WoW client.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
$scriptPath=Join-Path $repo 'tools/Get-Patch-Sources.ps1'
$tokens=$null;$parseErrors=$null
[Management.Automation.Language.Parser]::ParseFile($scriptPath,[ref]$tokens,[ref]$parseErrors)|Out-Null
if(@($parseErrors).Count -gt 0){throw ("Patch downloader parser errors: "+($parseErrors -join '; '))}
$base=Join-Path ([IO.Path]::GetTempPath()) ('naxx-download-test-'+[guid]::NewGuid().ToString('N'))
try{
 $fakeRepo=Join-Path $base 'launcher'
 $client=Join-Path $base 'game'
 $destination=Join-Path $base 'sources'
 $fakeOrigin=Join-Path $base 'origin'
 foreach($folder in @('launcher/tools','launcher/config','game/Data/enUS','sources','origin/Data')){
  New-Item -Path (Join-Path $base $folder) -ItemType Directory -Force|Out-Null
 }
 $marker='NAXX_PATCH_SOURCE_TEST_V1'
 foreach($dir in @($fakeRepo,$client,$fakeOrigin)){
  [IO.File]::WriteAllText((Join-Path $dir '.naxx-download-test-fixture'),$marker)
 }
 [IO.File]::WriteAllBytes((Join-Path $client 'Wow.exe'),[byte[]]@())
 $engine=Join-Path $fakeRepo 'tools/Get-Patch-Sources.ps1'
 Copy-Item -LiteralPath $scriptPath -Destination $engine
 Copy-Item -LiteralPath (Join-Path $repo 'config/patch-downloads.json') -Destination (Join-Path $fakeRepo 'config/patch-downloads.json')
 $reference=Get-Content -LiteralPath (Join-Path $repo 'config/client-patches.json') -Raw|ConvertFrom-Json
 foreach($p in @($reference.patches)){
  $basename=[IO.Path]::GetFileName([string]$p.path)
  $file=Join-Path (Join-Path $fakeOrigin 'Data') $basename
  [IO.File]::WriteAllText($file,"Synthetic bytes for $basename")
  $p.sha256=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
  $p.size_bytes=(Get-Item -LiteralPath $file).Length
 }
 $reference|ConvertTo-Json -Depth 12|Set-Content -LiteralPath (Join-Path $fakeRepo 'config/client-patches.json') -Encoding UTF8
 function Run([string[]]$extra){
  $a=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$engine,'-ClientPath',$client,'-PatchSourcePath',$destination)+@($extra)
  $out=(& powershell.exe @a 2>&1|Out-String)
  return [pscustomobject]@{exit=$LASTEXITCODE;output=$out}
 }
 $r=Run @()
 if($r.exit -ne 0 -or -not $r.output.Contains('NEEDED: 2 patch download(s)')){
  throw "Read-only source plan failed: $($r.output)"
 }
 if(Test-Path -LiteralPath (Join-Path $destination 'Data')){
  throw 'Read-only source plan created a folder.'
 }
 $r=Run @('-Action','Download','-SyntheticFixture','-TestFixtureSourcePath',$fakeOrigin)
 if($r.exit -eq 0 -or -not $r.output.Contains('ConfirmDownload')){
  throw 'Unconfirmed download was accepted.'
 }
 $r=Run @('-Action','Download','-ConfirmDownload','-SyntheticFixture','-TestFixtureSourcePath',$fakeOrigin,'-TbcLogin','-VanillaLoading')
 if($r.exit -ne 0 -or -not $r.output.Contains('PATCH DOWNLOAD COMPLETE')){
  throw "Verified TBC+U source download failed: $($r.output)"
 }
 foreach($name in @('patch-V.mpq','patch-Z.mpq','Patch-C.mpq','Patch-U.mpq')){
  $expected=Join-Path (Join-Path $fakeOrigin 'Data') $name
  $saved=Join-Path (Join-Path $destination 'Data') $name
  if(-not (Test-Path -LiteralPath $saved -PathType Leaf) -or
      (Get-FileHash -LiteralPath $saved -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $expected -Algorithm SHA256).Hash){
   throw "Downloaded file missing or damaged: $name"
  }
 }
 if(Test-Path -LiteralPath (Join-Path $destination 'Data/Patch-J.mpq')){throw 'Unselected J downloaded.'}
 if(Test-Path -LiteralPath (Join-Path $client 'Data/patch-V.mpq')){throw 'Downloader touched game client.'}
 $r=Run @('-Action','Download','-ConfirmDownload','-SyntheticFixture','-TestFixtureSourcePath',$fakeOrigin,'-TbcLogin','-VanillaLoading')
 if($r.exit -ne 0 -or -not $r.output.Contains('NEEDED: 0 patch download(s)')){
  throw 'Second run did not recognise verified sources.'
 }
 $r=Run @('-VanillaLogin','-TbcLogin')
 if($r.exit -eq 0 -or -not $r.output.Contains('Only one login screen')){throw 'J/C selection conflict not blocked.'}
 $r=Run @('-Action','Download','-ConfirmDownload','-TestFixtureSourcePath',$fakeOrigin)
 if($r.exit -eq 0 -or -not $r.output.Contains('both fixture arguments')){
  throw 'Synthetic source bypassed required marker mode.'
 }
 [IO.File]::WriteAllText((Join-Path $destination 'Data/Patch-J.mpq'),'wrong patch bytes')
 $r=Run @('-VanillaLogin')
 if($r.exit -eq 0 -or -not $r.output.Contains('wrong size or hash')){
  throw 'Mismatched existing source was accepted.'
 }
 Remove-Item -LiteralPath (Join-Path $destination 'Data/Patch-J.mpq') -Force
 [IO.File]::WriteAllText((Join-Path $fakeOrigin 'Data/Patch-J.mpq'),'CORRUPT SOURCE DATA')
 $r=Run @('-Action','Download','-ConfirmDownload','-SyntheticFixture','-TestFixtureSourcePath',$fakeOrigin,'-VanillaLogin')
 if($r.exit -eq 0 -or -not $r.output.Contains('failed SHA-256 or size verification')){
  throw 'Downloaded bytes did not pass fingerprint check.'
 }
 if(Test-Path -LiteralPath (Join-Path $destination 'Data/Patch-J.mpq')){throw 'Corrupt source was installed into download folder.'}
 if(@(Get-ChildItem -LiteralPath (Join-Path $destination 'Data') -Filter '*.partial' -Force).Count -gt 0){throw 'Verification failure left partial files.'}
 [IO.File]::WriteAllText((Join-Path $client 'Data/Patch-J.mpq'),'already-installed J')
 $r=Run @('-TbcLogin')
 if($r.exit -eq 0 -or -not $r.output.Contains('while Vanilla J exists')){throw 'Existing incompatible login patch not detected.'}
 if(Test-Path -LiteralPath (Join-Path $client '.naxxramas-setup')){throw 'Downloader created installer state in game.'}
 Write-Host 'ALL VERIFIED PATCH DOWNLOAD FIXTURE TESTS PASSED' -ForegroundColor Green
}finally{
 if(Test-Path -LiteralPath $base){Remove-Item -LiteralPath $base -Recurse -Force}
}
exit 0
