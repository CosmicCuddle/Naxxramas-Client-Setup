#requires -Version 5.1
# All files are tiny disposable text fixtures. NO copyrighted WoW data.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
function Check([bool]$Ok,[string]$Message) {
 if(-not $Ok){throw "TEST FAILED: $Message"}
 Write-Host ("PASS: "+$Message) -ForegroundColor Green
}
function Save([string]$File,[string]$Contents) {
 [IO.File]::WriteAllText($File,$Contents,(New-Object Text.UTF8Encoding($false)))
}
function Snap([string]$Folder) {
 return (@(Get-ChildItem -LiteralPath $Folder -Recurse -File -Force |
  Sort-Object FullName | ForEach-Object {
   $_.FullName.Substring($Folder.Length) + ':' +
      (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
  }) -join '|')
}
function Inspect([string]$Folder,[string]$Kind='Client') {
 return ((& $inspector -RootPath $Folder -Scope $Kind -Json | Out-String) |
  ConvertFrom-Json)
}
function Reject([string]$Folder,[string]$Kind,[string]$Label) {
 $refused=$false
 try{$null=Inspect $Folder $Kind}catch{$refused=$true}
 Check $refused $Label
}
$root=Join-Path ([IO.Path]::GetTempPath()) ('NaxxOpenHandles-'+[guid]::NewGuid().ToString('N'))
$client=Join-Path $root 'client'
$source=Join-Path $root 'source'
$inspector=Join-Path (Split-Path -Parent $PSScriptRoot) 'tools/Inspect-Naxxramas-OpenFileHandles.ps1'
$junction=$null
$junctionMade=$false
try {
 foreach($dir in @($client,$source,(Join-Path $client 'Data/enUS'),
  (Join-Path $source 'Data'))){
  $null=New-Item -ItemType Directory -Path $dir -Force
 }
 $expectedNames=@('patch-V.mpq','patch-Z.mpq','Patch-J.mpq','Patch-U.mpq')
 for($i=0;$i -lt $expectedNames.Count;$i++){
  $item='Data/'+$expectedNames[$i]
  Save (Join-Path $client $item) ('fake-client-'+$expectedNames[$i])
  Save (Join-Path $source $item) ('fake-source-'+$expectedNames[$i])
 }
 Save (Join-Path $client 'Data/enUS/realmlist.wtf') 'set realmlist example.test'
 $first=Snap $client
 $second=Snap $source
 $scan=Inspect $client
 Check ($scan.kind -ceq 'read_only_open_file_handle_inventory' -and
   $scan.status -ceq 'observed_NOT_authenticated') 'Client read-only handle inventory finishes'
 Check (@($scan.files).Count -eq 5) 'Exactly five allowlisted client paths'
 Check ((@($scan.files | Where-Object {$_.state -ceq 'observed_untrusted'}).Count) -eq 5) 'All five fixture files observed under read-only handles'
 Check ($scan.file_share -ceq 'read_only_read_sharing') 'Scan declares read-only file sharing'
 foreach($item in $scan.files){
  $expected=Get-FileHash -LiteralPath (Join-Path $client $item.path) -Algorithm SHA256
  Check ($item.sha256 -ceq $expected.Hash.ToLowerInvariant()) ('Read-through-handle SHA matches disk '+$item.path)
  Check ($item.file_object_fingerprint_sha256 -cmatch '^[a-f0-9]{64}$') 'Open Win32 file ID has a pseudonymous fingerprint'
 }
 Check ($scan.review_required -and -not $scan.allow_file_writes -and
  -not $scan.allow_automatic_resume -and -not $scan.authorises_rollback -and
  -not $scan.records_real_consent -and -not $scan.public_distribution_authorised) 'No result permits write, rollback, consent or redistribution'
 Check ((Snap $client) -ceq $first) 'Client files byte-identical after scanner'

 $src=Inspect $source 'Source'
 Check (@($src.files).Count -eq 4) 'Source mode allows four known patch paths only'
 Check ($src.status -ceq 'observed_NOT_authenticated') 'Local source file scan classified as unauthenticated'
 Check ((Snap $source) -ceq $second) 'Source files byte-identical after scanner'

 Remove-Item -LiteralPath (Join-Path $client 'Data/Patch-J.mpq') -Force
 $scan=Inspect $client
 Check ((@($scan.files | Where-Object {$_.path -ceq 'Data/Patch-J.mpq'})[0].state) -ceq 'missing') 'Missing optional J recorded without an install action'
 Check ($scan.status -ceq 'observed_NOT_authenticated') 'Missing optional file does not imply a required patch'
 Remove-Item -LiteralPath (Join-Path $client 'Data/patch-Z.mpq') -Force
 $scan=Inspect $client
 Check ($scan.status -ceq 'missing_mandatory_patches_manual_review') 'Missing mandatory Z triggers manual review'
 Check (@($scan.missing_mandatory_patch_paths) -ccontains 'Data/patch-Z.mpq') 'Missing Z explicitly named'
 Save (Join-Path $client 'Data/patch-Z.mpq') 'fake-client-patch-Z.mpq'

 # An ordinary concurrent writer that has not granted FileShare.Read-only
 # cannot coexist with the scanner's read handles.
 $v=Join-Path $client 'Data/patch-V.mpq'
 $writer=New-Object IO.FileStream($v,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::ReadWrite)
 try{ Reject $client 'Client' 'Concurrent writable handle makes scanner fail closed' }
 finally{$writer.Dispose()}
 $scan=Inspect $client
 Check ($scan.status -ceq 'observed_NOT_authenticated') 'After writer closes, read-only inspection recovers'

 $file=Join-Path $client 'Data/patch-V.mpq'
 $held=New-Object IO.FileStream($file,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
 try {
  $attemptDenied=$false
  try{
   $edit=New-Object IO.FileStream($file,[IO.FileMode]::Open,[IO.FileAccess]::Write,[IO.FileShare]::ReadWrite)
   $edit.Dispose()
  }catch{$attemptDenied=$true}
  Check $attemptDenied 'FileShare.Read handle refuses a simultaneous ordinary writable open'
 }finally{$held.Dispose()}
 Check ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() -ceq
  (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()) 'File remains readable after handle released'

 # Junction under known Data path must be rejected; safe cleanup deletes
 # link only, never recursively traverses it.
 $data=Join-Path $source 'Data'
 $originalData=Join-Path $source 'Data-original'
 [IO.Directory]::Move($data,$originalData)
 $junction=$data
 try {
  $null=New-Item -ItemType Junction -Path $junction -Target $originalData -ErrorAction Stop
  $junctionMade=$true
 }catch {
  Write-Host 'SKIP: junction fixture unavailable on this Windows runner.'
 }
 if($junctionMade) {
  Reject $source 'Source' 'Junction-backed Data directory rejected'
  [IO.Directory]::Delete($junction,$false)
  $junctionMade=$false
 }
 [IO.Directory]::Move($originalData,$data)

 $raw=(& $inspector -RootPath $client -Scope Client -Json | Out-String)
 Check (-not $raw.Contains($root)) 'Report omits absolute client and temp paths'
 Check (-not $raw.Contains('fake-client')) 'Report omits raw fixture file contents'
 Write-Host 'All read-only Windows open-file handle tests passed.' -ForegroundColor Green
}finally{
 $clean=$true
 if($junctionMade -and $junction -and (Test-Path -LiteralPath $junction)) {
  try{
   $info=Get-Item -LiteralPath $junction -Force
   if(($info.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0){
    throw 'Unsafe junction cleanup; leaving fixture for manual inspection.'
   }
   [IO.Directory]::Delete($junction,$false)
  }catch{$clean=$false;Write-Warning 'Refused unsafe fixture cleanup.'}
 }
 if($clean -and (Test-Path -LiteralPath $root)){
  Remove-Item -LiteralPath $root -Recurse -Force
 }
}
