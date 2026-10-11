#requires -Version 5.1
# End-to-end backup CANDIDATE review with disposable fake files only.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
function Check([bool]$Ok,[string]$Label) {
 if(-not $Ok){throw "TEST FAILED: $Label"}
 Write-Host "PASS: $Label" -ForegroundColor Green
}
function Save([string]$Path,[string]$Value) {
 [IO.File]::WriteAllText($Path,$Value,(New-Object Text.UTF8Encoding($false)))
}
function Sign([string]$Path) {
 return [ordered]@{
  sha256=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
  size_bytes=[long](Get-Item -LiteralPath $Path).Length
 }
}
function Snapshot([string]$Directory){
 return (@(Get-ChildItem -LiteralPath $Directory -Recurse -File -Force |
  Sort-Object FullName | ForEach-Object{
   $_.FullName.Substring($Directory.Length)+':'+
    (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
  }) -join '|')
}
$repo=Split-Path -Parent $PSScriptRoot
$root=Join-Path ([IO.Path]::GetTempPath()) ('NaxxOriginals-'+[guid]::NewGuid().ToString('N'))
$client=Join-Path $root 'client'
$source=Join-Path $root 'source'
$backup=Join-Path $root 'backup'
$tools=Join-Path $root 'tools'
$config=Join-Path $root 'config'
$history=Join-Path $config 'patch-versions'
$checker=Join-Path $tools 'Review-Naxxramas-BackupOriginals.ps1'
$default=@{ClientPath=$client;PatchSourcePath=$source;BackupRoot=$backup;Json=$true}
function Inspect([hashtable]$ArgsMap) {
 return ((& $checker @ArgsMap | Out-String)|ConvertFrom-Json)
}
function Must-Refuse([hashtable]$ArgsMap,[string]$Label) {
 $refused=$false
 try{$null=Inspect $ArgsMap}catch{$refused=$true}
 Check $refused $Label
}
function Has-Reason([object]$Report,[string]$Reason,[string]$Label){
 Check (@($Report.blockers) -ccontains $Reason) $Label
}
try{
 foreach($folder in @($client,$source,$backup,$tools,$history,
   (Join-Path $client 'Data/enUS'),(Join-Path $source 'Data'))){
  $null=New-Item -ItemType Directory -Path $folder -Force
 }
 foreach($name in @('Review-Naxxramas-BackupOriginals.ps1',
   'Plan-Naxxramas-Install.ps1','Inspect-Naxxramas-OpenFileHandles.ps1')){
  Copy-Item -LiteralPath (Join-Path $repo ('tools/'+$name)) -Destination $tools
 }
 $rows=@()
 $paths=@('patch-V.mpq','patch-Z.mpq','Patch-J.mpq','Patch-U.mpq')
 for($i=0;$i -lt 4;$i++){
  $path='Data/'+$paths[$i]
  $srcFile=Join-Path $source $path
  Save $srcFile ('NAXX_FAKE_CURRENT_'+$paths[$i])
  $sign=Sign $srcFile
  $rows+=@{path=$path;required=($i -lt 2);allow_disable=($i -ge 2);
   sha256=$sign.sha256;size_bytes=$sign.size_bytes;public_distribution_approved=$false}
 }
 $manifest=@{schema_version=1;target_client=@{build=12340;locale='enUS'};
  patch_set_revision=1;patch_set_version='patchset-0001';patches=$rows}
 Save (Join-Path $config 'client-patches.json') ($manifest|ConvertTo-Json -Depth 8)
 Save (Join-Path $config 'realm.json') (@{
  schema_version=1;relative_path='Data/enUS/realmlist.wtf';host='naxx.example.test'
 }|ConvertTo-Json -Depth 5)
 $oldV=Join-Path $client 'Data/patch-V.mpq'
 Save $oldV 'NAXX_FAKE_KNOWN_OLD_V'
 $oldSignature=Sign $oldV
 $historyFile=Join-Path $history 'patchset-0000.json'
 Save $historyFile (@{schema_version=1;revision=0;version='patchset-0000';
  patches=@(@{path='Data/patch-V.mpq';sha256=$oldSignature.sha256;
    size_bytes=$oldSignature.size_bytes})}|ConvertTo-Json -Depth 8)
 Copy-Item -LiteralPath (Join-Path $source 'Data/patch-Z.mpq') -Destination (Join-Path $client 'Data/patch-Z.mpq')
 Save (Join-Path $client 'Data/Patch-J.mpq') 'personal unselected optional login patch'
 $realmlist=Join-Path $client 'Data/enUS/realmlist.wtf'
 Save $realmlist 'set realmlist previous.example.test'
 Save (Join-Path $backup 'existing-keep.txt') 'existing backup folder content - leave untouched'
 $fakeExe=@'
using System.Reflection;
[assembly:AssemblyVersion("3.3.5.12340")]
[assembly:AssemblyFileVersion("3.3.5.12340")]
public static class NaxxBackupReadinessFixture {
 public static int Main(){return 0;}
}
'@
 Add-Type -TypeDefinition $fakeExe -OutputAssembly (Join-Path $client 'Wow.exe') -OutputType ConsoleApplication -ErrorAction Stop
 $beforeClient=Snapshot $client
 $beforeSource=Snapshot $source
 $beforeBackup=Snapshot $backup
 $args=$default.Clone()
 $args.VanillaLoading=$true
 $report=Inspect $args
 Check ($report.kind -ceq 'read_only_original_backup_candidate_review') 'Live original review classification'
 Check ($report.status -ceq 'originals_identified_NOT_BACKED_UP_NOT_APPROVED') 'Known older V and changed realmlist yield candidate review, never actual backup'
 Check ($report.current_preflight_status -ceq 'review_only_no_blockers') 'Existing planner reports valid synthetic test policy'
 Check ([int]$report.originals_count -eq 2) 'Exactly two existing originals require future backup'
 $candidates=@($report.originals_to_preserve)
 Check (@($candidates|Where-Object{$_.path -ceq 'Data/patch-V.mpq'}).Count -eq 1) 'Prior V bytes identified for backup'
 Check (@($candidates|Where-Object{$_.path -ceq 'Data/enUS/realmlist.wtf'}).Count -eq 1) 'Changed realmlist bytes identified for backup'
 $expected=[long](Get-Item -LiteralPath $oldV).Length+[long](Get-Item -LiteralPath $realmlist).Length
 Check ([long]$report.originals_total_bytes -eq $expected) 'Original backup bytes are summed from open file handles'
 foreach($entry in $candidates){
  $path=Join-Path $client $entry.path
  $sign=Sign $path
  Check ($entry.original_sha256 -ceq $sign.sha256 -and
    [long]$entry.original_size_bytes -eq $sign.size_bytes) ('Exact original digest and length: '+$entry.path)
  Check ($entry.original_file_object_fingerprint_sha256 -cmatch '^[a-f0-9]{64}$') 'Original observed file object identified'
  Check ($entry.backup_state -ceq 'NOT_CREATED') 'Originals are only candidates; no backup claimed'
 }
 Check (@($report.file_actions|Where-Object{
  $_.path -ceq 'Data/Patch-J.mpq' -and $_.proposed_action -ceq 'leave_existing'}).Count -eq 1) 'Unselected existing J must remain untouched'
 Check (@($report.file_actions|Where-Object{
  $_.path -ceq 'Data/Patch-U.mpq' -and $_.proposed_action -ceq 'install'}).Count -eq 1) 'Selected U is a new file and needs no original backup'
 Check ($report.backup_location_checked_by_planner -and
  -not $report.backup_created -and -not $report.originals_backed_up_and_verified -and
  -not $report.allow_file_writes -and -not $report.authorises_rollback -and
  -not $report.records_real_consent -and -not $report.public_distribution_authorised) 'No backup, real consent, write or rollback permission'
 Check ((Snapshot $client) -ceq $beforeClient -and
  (Snapshot $source) -ceq $beforeSource -and
  (Snapshot $backup) -ceq $beforeBackup) 'Read-only review preserves client/source/existing backup bytes'

 $other=$default.Clone()
 $other.VanillaLoading=$true
 Remove-Item -LiteralPath (Join-Path $client 'Data/patch-Z.mpq') -Force
 $report=Inspect $other
 Check ($report.status -ceq 'originals_identified_NOT_BACKED_UP_NOT_APPROVED') 'Missing Z with verified source can be listed as new installation, not incorrectly require original'
 Check (@($report.file_actions|Where-Object{$_.path -ceq 'Data/patch-Z.mpq' -and
  $_.proposed_action -ceq 'install' -and -not $_.backup_required}).Count -eq 1) 'New Z has no existing original to back up'
 Copy-Item -LiteralPath (Join-Path $source 'Data/patch-Z.mpq') -Destination (Join-Path $client 'Data/patch-Z.mpq')

 Save $oldV 'unknown unexpected V bytes'
 $report=Inspect $other
 Has-Reason $report 'existing_installer_preflight_blocked' 'Unrecognised existing mandatory V blocks review'
 Has-Reason $report 'planned_action_blocked_0' 'Blocked V action propagates to candidate review'
 Save $oldV 'NAXX_FAKE_KNOWN_OLD_V'

 $corrupt=Join-Path $source 'Data/patch-V.mpq'
 Save $corrupt 'BAD_LOCAL_SOURCE_BYTES'
 $report=Inspect $other
 Has-Reason $report 'existing_installer_preflight_blocked' 'Wrong source digest blocks through existing planner'
 Save $corrupt 'NAXX_FAKE_CURRENT_patch-V.mpq'

 $open=New-Object IO.FileStream($oldV,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::ReadWrite)
 try{Must-Refuse $other 'Concurrent writer rejects backup candidate verification'}
 finally{$open.Dispose()}

 $nested=$other.Clone()
 $nested.BackupRoot=$client
 Must-Refuse $nested 'Backup path cannot be same as client'
 $nested=$other.Clone()
 $nested.BackupRoot=$source
 Must-Refuse $nested 'Backup path cannot overlap local source'
 $missing=$other.Clone()
 $missing.Remove('BackupRoot')
 Must-Refuse $missing 'Explicit backup destination is mandatory in this reviewer'

 $raw=(& $checker @other | Out-String)
 Check (-not $raw.Contains($root)) 'Human-readable report omits private absolute temporary paths'
 Check ((Snapshot $backup) -ceq $beforeBackup) 'Backup destination never modified or populated'
 Write-Host 'All read-only original backup readiness fixture tests passed.' -ForegroundColor Green
}finally{
 if(Test-Path -LiteralPath $root){Remove-Item -LiteralPath $root -Recurse -Force}
}
