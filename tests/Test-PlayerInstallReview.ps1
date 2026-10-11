#requires -Version 5.1
# End-to-end player review using only tiny disposable fake client/patch data.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
function Check([bool]$OK,[string]$Message){
    if(-not $OK){throw ('TEST FAILED: '+$Message)}
    Write-Host ('PASS: '+$Message) -ForegroundColor Green
}
function Save([string]$File,[string]$Contents){
    [IO.File]::WriteAllText($File,$Contents,(New-Object Text.UTF8Encoding($false)))
}
function Fingerprint([string]$File){
    return [pscustomobject]@{
        sha256=(Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash.ToLowerInvariant()
        size_bytes=[int64](Get-Item -LiteralPath $File).Length
    }
}
function TreeHash([string]$Folder){
    return (@(Get-ChildItem -LiteralPath $Folder -Recurse -File -Force |
        Sort-Object FullName | ForEach-Object {
        $_.FullName.Substring($Folder.Length) + ':' +
            (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    }) -join '|')
}
function Review([hashtable]$Options) {
    return ((& $reviewer @Options | Out-String) | ConvertFrom-Json)
}
function Row([object]$Report,[string]$Path){
    return @($Report.file_reviews | Where-Object {$_.relative_path -ceq $Path})[0]
}
function Invariants([object]$R,[string]$Why){
    Check ($R.kind -ceq 'read_only_player_facing_installation_review' -and
        $R.schema_version -eq 1 -and $R.file_count -eq 5 -and
        @($R.file_reviews).Count -eq 5) ($Why+': exact expected report shape')
    Check ($R.read_only -and $R.review_required -and
        -not $R.client_files_modified -and -not $R.original_backups_created -and
        -not $R.file_writes_authorised -and
        -not $R.automatic_resume_authorised -and -not $R.rollback_authorised -and
        -not $R.genuine_user_consent_collected -and
        -not $R.public_patch_distribution_authorised) 'All reports deny file changes, installer consent and redistribution'
}
$repo=Split-Path -Parent $PSScriptRoot
$root=Join-Path ([IO.Path]::GetTempPath()) ('NaxxPlayerReview-'+[guid]::NewGuid().ToString('N'))
$client=Join-Path $root 'client'
$source=Join-Path $root 'source'
$backup=Join-Path $root 'backup'
$tools=Join-Path $root 'tools'
$config=Join-Path $root 'config'
$history=Join-Path $config 'patch-versions'
$reviewer=Join-Path $tools 'Show-Naxxramas-InstallReview.ps1'
$baseOptions=@{ClientPath=$client;PatchSourcePath=$source;BackupRoot=$backup;Json=$true;VanillaLoading=$true}
try{
    foreach($folder in @($client,$source,$backup,$tools,$history,
        (Join-Path $client 'Data/enUS'),(Join-Path $source 'Data'))){
        $null=New-Item -ItemType Directory -Path $folder -Force
    }
    foreach($name in @('Show-Naxxramas-InstallReview.ps1','Plan-Naxxramas-Install.ps1')){
        Copy-Item -LiteralPath (Join-Path $repo ('tools/'+$name)) -Destination $tools
    }
    $patches=@('patch-V.mpq','patch-Z.mpq','Patch-J.mpq','Patch-U.mpq')
    $entries=@()
    for($i=0;$i -lt 4;$i++){
        $relative='Data/'+$patches[$i]
        $path=Join-Path $source $relative
        Save $path ('FAKE_SOURCE_CURRENT_'+$patches[$i])
        $fp=Fingerprint $path
        $entries+=@{path=$relative;required=($i -lt 2);allow_disable=($i -ge 2);
            sha256=$fp.sha256;size_bytes=$fp.size_bytes;public_distribution_approved=$false}
    }
    $manifest=@{
        schema_version=1;target_client=@{build=12340;locale='enUS'};
        patch_set_revision=1;patch_set_version='patchset-0001';patches=$entries
    }
    Save (Join-Path $config 'client-patches.json') ($manifest|ConvertTo-Json -Depth 8)
    Save (Join-Path $config 'realm.json') (@{
        schema_version=1;relative_path='Data/enUS/realmlist.wtf';host='naxx.example.test'
    }|ConvertTo-Json -Depth 5)
    $v=Join-Path $client 'Data/patch-V.mpq'
    Save $v 'FAKE_RECOGNISED_OLDER_V'
    $old=Fingerprint $v
    Save (Join-Path $history 'patchset-0000.json') (@{
        schema_version=1;revision=0;version='patchset-0000';
        patches=@(@{path='Data/patch-V.mpq';sha256=$old.sha256;size_bytes=$old.size_bytes})
    }|ConvertTo-Json -Depth 8)
    Copy-Item -LiteralPath (Join-Path $source 'Data/patch-Z.mpq') -Destination (Join-Path $client 'Data/patch-Z.mpq')
    $j=Join-Path $client 'Data/Patch-J.mpq'
    Save $j 'FAKE_PLAYER_UNSELECTED_J'
    $realm=Join-Path $client 'Data/enUS/realmlist.wtf'
    Save $realm 'set realmlist previous.example.test'
    Save (Join-Path $backup 'KEEP-EXISTING.txt') 'EXISTING BACKUP CONTENT'
    $exe=@'
using System.Reflection;
[assembly:AssemblyVersion("3.3.5.12340")]
[assembly:AssemblyFileVersion("3.3.5.12340")]
public static class NaxxPlayerReviewFixture {
 public static int Main(){return 0;}
}
'@
    Add-Type -TypeDefinition $exe -OutputAssembly (Join-Path $client 'Wow.exe') -OutputType ConsoleApplication -ErrorAction Stop

    $beforeClient=TreeHash $client
    $beforeSource=TreeHash $source
    $beforeBackup=TreeHash $backup
    $r=Review $baseOptions
    Invariants $r 'Known old V, new U, existing J, changed realmlist'
    Check ($r.status -ceq 'read_only_player_review_NO_PREFLIGHT_BLOCKERS_NOT_APPROVED') 'Unblocked preview is still NOT permission'
    Check ($r.proposed_new_file_count -eq 1 -and
        $r.proposed_replace_after_backup_count -eq 2 -and
        $r.unchanged_or_unselected_count -eq 2 -and
        $r.blocked_file_count -eq 0) 'File action count matches actual local plan'
    Check ((Row $r 'Data/patch-V.mpq').original_backup_required) 'Old V would require exact original backup'
    Check ((Row $r 'Data/patch-Z.mpq').proposed_action -ceq 'no_change') 'Current Z unchanged'
    Check ((Row $r 'Data/Patch-J.mpq').proposed_action -ceq 'leave_existing') 'Unselected private J preserved'
    Check ((Row $r 'Data/Patch-U.mpq').proposed_action -ceq 'install') 'Selected absent U would be new file'
    Check ((Row $r 'Data/enUS/realmlist.wtf').original_backup_required) 'Different realmlist would require exact backup'
    $expected=[long](Get-Item -LiteralPath $v).Length+[long](Get-Item -LiteralPath $realm).Length
    Check ($r.original_bytes_that_would_need_backup -eq $expected) 'Required original byte estimate calculated from real local files'
    Check ($r.realm_address -ceq 'naxx.example.test' -and
        -not $r.vanilla_login_selected -and $r.vanilla_loading_selected) 'Player options and realmlist explicitly shown'
    Check ((TreeHash $client) -ceq $beforeClient -and
        (TreeHash $source) -ceq $beforeSource -and
        (TreeHash $backup) -ceq $beforeBackup) 'Review does not modify client/source/existing backup'

    $textOptions=$baseOptions.Clone();$textOptions.Remove('Json')
    $txt=(& $reviewer @textOptions | Out-String)
    Check ($txt.Contains('INSTALLATION REVIEW ONLY - NOTHING WILL BE CHANGED') -and
        $txt.Contains('PROPOSED FILE ACTIONS') -and
        $txt.Contains('Would replace ONLY after an exact original backup') -and
        $txt.Contains('No action button or approval is provided')) 'Plain-language review shows prominent no-write warning'
    Check (-not $txt.Contains($root)) 'Human-readable review does not disclose private absolute paths'
    Check (-not $txt.Contains($old.sha256)) 'Human-readable review does not disclose original SHA-256'

    $noBackup=$baseOptions.Clone();$noBackup.Remove('BackupRoot')
    $r=Review $noBackup
    Invariants $r 'Missing backup selection'
    Check ($r.status -ceq 'read_only_player_review_BLOCKED_MANUAL_REVIEW') 'Write plan without selected separate backup marked for review'
    Check (@($r.concerns | Where-Object {$_ -match 'No separate backup folder'}).Count -eq 1) 'Player told to choose separate backup folder'

    $noSource=$baseOptions.Clone();$noSource.Remove('PatchSourcePath')
    $r=Review $noSource
    Invariants $r 'Missing patch sources'
    Check ($r.status -ceq 'read_only_player_review_BLOCKED_MANUAL_REVIEW') 'Missing required source blocks preview'
    Check ((Row $r 'Data/patch-V.mpq').proposed_action -ceq 'blocked') 'Required V replacement blocked without source'

    $both=$baseOptions.Clone();$both.VanillaLogin=$true
    $r=Review $both
    Invariants $r 'Selected unrecognised J'
    Check ($r.status -ceq 'read_only_player_review_BLOCKED_MANUAL_REVIEW') 'Selected unfamiliar J cannot be silently replaced'
    Check ((Row $r 'Data/Patch-J.mpq').proposed_action -ceq 'blocked') 'J selected with unknown contents triggers preservation'
    Copy-Item -LiteralPath (Join-Path $source 'Data/Patch-J.mpq') -Destination $j -Force
    $r=Review $both
    Invariants $r 'Both Vanilla cosmetic patch choices'
    Check ($r.status -ceq 'read_only_player_review_NO_PREFLIGHT_BLOCKERS_NOT_APPROVED') 'Verified current J and selected U can be previewed without granting consent'
    Check (@($r.notes | Where-Object {$_ -match 'overlapping loading-screen textures'}).Count -eq 1) 'Overlapping J/U textures reported clearly'

    Save $v 'FAKE_UNRECOGNISED_V'
    $r=Review $baseOptions
    Invariants $r 'Unknown mandatory V'
    Check ($r.status -ceq 'read_only_player_review_BLOCKED_MANUAL_REVIEW') 'Unknown core V remains blocked'
    Check ((Row $r 'Data/patch-V.mpq').proposed_action -ceq 'blocked') 'Unknown existing core V never silently overwritten'

    $raw=(& $reviewer @baseOptions | Out-String)
    Check (-not $raw.Contains($root) -and -not $raw.Contains($old.sha256)) 'JSON review omits absolute user paths and source hashes'
    Check ((TreeHash $backup) -ceq $beforeBackup) 'Original backup location sentinel never touched'
    Write-Host 'All player-readable installer review tests passed.' -ForegroundColor Green
}finally{
    if(Test-Path -LiteralPath $root){Remove-Item -LiteralPath $root -Recurse -Force}
}
