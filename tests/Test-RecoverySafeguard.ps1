#requires -Version 5.1
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
function Check([bool]$Good,[string]$Message){
 if(-not $Good){throw 'TEST FAILED: '+$Message}
 Write-Host ('PASS: '+$Message) -ForegroundColor Green
}
function Put([string]$Path,[string]$Value){
 [IO.File]::WriteAllText($Path,$Value,(New-Object Text.UTF8Encoding($false)))
}
function Sig([string]$Path){
 return [pscustomobject]@{
 sha256=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
 size_bytes=[int64](Get-Item -LiteralPath $Path).Length
 }
}
function Snapshot([string]$Path){
 return (@(Get-ChildItem -LiteralPath $Path -Recurse -File|Sort-Object FullName|ForEach-Object{
 $_.FullName.Substring($Path.Length)+':'+(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
 }) -join '|')
}
$repo=Split-Path -Parent $PSScriptRoot
$root=Join-Path ([IO.Path]::GetTempPath()) ('NaxxRecoverySafe-'+[guid]::NewGuid().ToString('N'))
$client=Join-Path $root 'client'
$session=Join-Path $root 'session'
$tools=Join-Path $root 'tools'
$script=Join-Path $tools 'Review-Naxxramas-RecoverySafeguard.ps1'
$legacy=Join-Path $tools 'Review-Naxxramas-Recovery.ps1'
$params=@{ClientPath=$client;SessionDirectory=$session;Json=$true}
function Inspect{ return ((& $script @params | Out-String)|ConvertFrom-Json) }
function Row([object]$Report,[string]$Name){
 return @($Report.files|Where-Object{$_.path -ceq $Name})[0]
}
function Safe([object]$Report){
 Check ($Report.review_required -and $Report.preserve_player_changes -and
 -not $Report.allow_file_writes -and -not $Report.allow_automatic_resume -and
 -not $Report.authorises_rollback -and -not $Report.authorises_file_deletion -and
 -not $Report.records_real_consent -and
 -not $Report.protected_journal_authority_verified -and
 -not $Report.public_distribution_authorised) 'Every result forbids any change or automatic recovery'
}
function Manifest([string]$Status='completed',[string]$VPhase='verified'){
 $m=[ordered]@{
  schema_version=1;kind='local_naxxramas_setup_transaction';
  session_id='fixture-recovery-001';patchset='patchset-0001';
  target_build=12340;locale='enUS';status=$Status;
  operations=@(
   [ordered]@{
    relative_path='Data/patch-V.mpq';action='replace_after_backup';was_present=$true;
    before_sha256=$old.sha256;before_size_bytes=$old.size_bytes;
    installed_sha256=$vInstalled.sha256;installed_size_bytes=$vInstalled.size_bytes;
    backup_relative_path='originals/0001.bin';checkpoint=$VPhase
   },
   [ordered]@{
    relative_path='Data/Patch-U.mpq';action='install';was_present=$false;
    before_sha256=$null;before_size_bytes=$null;backup_relative_path=$null;
    installed_sha256=$uInstalled.sha256;installed_size_bytes=$uInstalled.size_bytes;
    checkpoint='verified'
   }
  )
 }
 Put (Join-Path $session 'session.json') (ConvertTo-Json -InputObject $m -Depth 12)
}
function Expect([string]$VState,[string]$UState,[string]$Why){
 $a=Snapshot $client
 $b=Snapshot $session
 $r=Inspect
 Check ((Row $r 'Data/patch-V.mpq').review_classification -ceq $VState) ($Why+': core V')
 Check ((Row $r 'Data/Patch-U.mpq').review_classification -ceq $UState) ($Why+': optional U')
 Safe $r
 Check ((Snapshot $client) -ceq $a -and (Snapshot $session) -ceq $b) 'Review never changes client or backup/session'
 return $r
}
try{
 foreach($dir in @($client,$session,$tools,(Join-Path $client 'Data'),
    (Join-Path $session 'originals'))){
  $null=New-Item -ItemType Directory -Path $dir -Force
 }
 foreach($name in @('Review-Naxxramas-RecoverySafeguard.ps1',
  'Review-Naxxramas-Recovery.ps1','Inspect-Naxxramas-OpenFileHandles.ps1')){
  Copy-Item -LiteralPath (Join-Path $repo ('tools/'+$name)) -Destination $tools
 }
 $v=Join-Path $client 'Data/patch-V.mpq'
 $u=Join-Path $client 'Data/Patch-U.mpq'
 $backup=Join-Path $session 'originals/0001.bin'
 Put $v 'fake-installed-V'
 Put $u 'fake-installed-U'
 Put $backup 'fake-original-V'
 $vInstalled=Sig $v
 $uInstalled=Sig $u
 $old=Sig $backup
 Manifest
 $r=Expect 'potential_restore_requires_independent_approval' 'potential_removal_requires_independent_approval' 'Matching installed files still not authorised to restore/remove'
 Check (@($r.blockers) -ccontains 'authentic_single_use_consent_and_journal_missing') 'Real user consent and protected journal are absent'
 Put $v 'PLAYER-CUSTOMIZED-V'
 $r=Expect 'preserve_player_changed_file_manual_review' 'potential_removal_requires_independent_approval' 'Player edited core V'
 Check ((Row $r 'Data/patch-V.mpq').preserve_current_data) 'Custom player bytes must be preserved'
 Put $v 'fake-installed-V'
 Remove-Item -LiteralPath $backup -Force
 $null=Expect 'preserve_file_missing_or_wrong_backup' 'potential_removal_requires_independent_approval' 'Missing original backup'
 Put $backup 'corrupt-old-backup'
 $null=Expect 'preserve_file_missing_or_wrong_backup' 'potential_removal_requires_independent_approval' 'Corrupt original backup'
 Put $backup 'fake-original-V'
 Manifest 'failed_recoverable'
 $null=Expect 'preserve_file_incomplete_record' 'preserve_file_incomplete_record' 'Interrupted transaction'
 Manifest 'completed' 'write_started'
 $null=Expect 'preserve_file_incomplete_record' 'potential_removal_requires_independent_approval' 'Incomplete per-file checkpoint'
 Manifest
 Put $v 'fake-original-V'
 Remove-Item -LiteralPath $u -Force
 $r=Expect 'preserve_original_no_action' 'preserve_absence_no_action' 'Already recovered file and absent optional'
 Check ($r.status -ceq 'existing_file_states_need_no_change_NOT_AUTHENTICATED') 'No operations necessary; still not authenticated'
 Put $v 'fake-installed-V'
 Put $u 'fake-installed-U'
 # Race injection is isolated to a temporary copy of the legacy reviewer.
 $originalScript=[IO.File]::ReadAllText($legacy)
 $at=$originalScript.LastIndexOf('if ($Json) {')
 Check ($at -gt 0) 'Located legacy output hook inside disposable copy'
 $trigger=Join-Path $root 'trigger-once.txt'
 $hook=@'
if (Test-Path -LiteralPath 'RACE_TRIGGER') {
 Remove-Item -LiteralPath 'RACE_TRIGGER' -Force
 [IO.File]::WriteAllText('V_FILE','PLAYER_EDIT_BETWEEN_RECOVERY_PASSES')
}
'@
 $hook=$hook.Replace('RACE_TRIGGER',$trigger).Replace('V_FILE',$v)
 try{
  [IO.File]::WriteAllText($legacy,$originalScript.Insert($at,$hook+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
  Put $trigger 'trigger'
  $r=Inspect
  Check (@($r.blockers) -ccontains 'recovery_preview_changed_during_review') 'Drift between recovery observations detected'
  Check ((Row $r 'Data/patch-V.mpq').review_classification -ceq 'preserve_player_changed_file_manual_review') 'Race-edited file protected'
  Safe $r
 }finally{
  [IO.File]::WriteAllText($legacy,$originalScript,(New-Object Text.UTF8Encoding($false)))
  if(Test-Path -LiteralPath $trigger){Remove-Item -LiteralPath $trigger -Force}
  Put $v 'fake-installed-V'
 }
 $m=Get-Content -LiteralPath (Join-Path $session 'session.json') -Raw|ConvertFrom-Json
 $m.operations[0].relative_path='../WTF/Account'
 Put (Join-Path $session 'session.json') (ConvertTo-Json -InputObject $m -Depth 12)
 $rejected=$false
 try{$null=Inspect}catch{$rejected=$true}
 Check $rejected 'Unsafe recovery path is refused'
 Manifest
 $raw=(& $script @params | Out-String)
 Check (-not $raw.Contains($root)) 'No absolute client or temporary paths in JSON'
 Check (-not $raw.Contains($old.sha256)) 'No original backup digest exposed in report'
 Write-Host 'All Windows read-only recovery safeguard tests passed.' -ForegroundColor Green
}finally{
 if(Test-Path -LiteralPath $root){Remove-Item -LiteralPath $root -Recurse -Force}
}
