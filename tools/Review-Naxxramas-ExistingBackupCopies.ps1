#requires -Version 5.1
<#
Naxxramas Client Setup — READ ONLY existing-backup-copy comparison.
Read-only inspection of pre-existing mirrored copies under BackupRoot.
NEVER creates backups, certifies restore safety, installs, writes or rolls back.
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$ClientPath,
 [Parameter(Mandatory=$true)][string]$BackupRoot,
 [string]$PatchSourcePath,
 [switch]$VanillaLogin,[switch]$VanillaLoading,[string]$RealmHost,
 [switch]$Json
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$names=@('Data/patch-V.mpq','Data/patch-Z.mpq',
         'Data/Patch-J.mpq','Data/Patch-U.mpq','Data/enUS/realmlist.wtf')
$root=$PSScriptRoot
$params=@{ClientPath=$ClientPath;BackupRoot=$BackupRoot;Json=$true}
if($PatchSourcePath){$params.PatchSourcePath=$PatchSourcePath}
if($VanillaLogin){$params.VanillaLogin=$true}
if($VanillaLoading){$params.VanillaLoading=$true}
if($RealmHost){$params.RealmHost=$RealmHost}

$readinessTool=Join-Path $root 'Review-Naxxramas-BackupOriginals.ps1'
$readiness=(& $readinessTool @params | Out-String) | ConvertFrom-Json
if($readiness.kind -cne 'read_only_original_backup_candidate_review' -or
   [int]$readiness.schema_version -ne 1 -or
   @($readiness.file_actions).Count -ne 5 -or
   [int]$readiness.originals_count -ne @($readiness.originals_to_preserve).Count){
    throw 'Unexpected read-only original-candidate response.'
}
$inspector=Join-Path $root 'Inspect-Naxxramas-OpenFileHandles.ps1'
$backups=(& $inspector -RootPath $BackupRoot -Scope Client -Json | Out-String) | ConvertFrom-Json
if($backups.kind -cne 'read_only_open_file_handle_inventory' -or
   [int]$backups.schema_version -ne 1 -or
   $backups.scope -cne 'client' -or @($backups.files).Count -ne 5){
    throw 'Unexpected read-only backup file-handle inventory response.'
}
for($i=0;$i -lt 5;$i++){
    if($readiness.file_actions[$i].path -cne $names[$i] -or
       $backups.files[$i].path -cne $names[$i]){
        throw 'Backup inspection allowlist or file order changed.'
    }
}
$blocks=New-Object 'System.Collections.Generic.List[string]'
foreach($reason in @($readiness.blockers)){
    $blocks.Add('original_readiness_blocked')
    break
}
if($readiness.current_preflight_status -cne 'review_only_no_blockers' -or
   $readiness.status -cne 'originals_identified_NOT_BACKED_UP_NOT_APPROVED'){
    if(-not $blocks.Contains('original_readiness_blocked')){
        $blocks.Add('original_readiness_blocked')
    }
}
$copies=New-Object 'System.Collections.Generic.List[object]'
$matched=0
$required=@($readiness.originals_to_preserve)
$seen=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
foreach($candidate in $required){
    $path=[string]$candidate.path
    $index=[Array]::IndexOf($names,$path)
    if($index -lt 0 -or -not $seen.Add($path) -or
       $candidate.backup_state -cne 'NOT_CREATED' -or
       $candidate.original_sha256 -cnotmatch '^[a-f0-9]{64}$' -or
       $candidate.original_file_object_fingerprint_sha256 -cnotmatch '^[a-f0-9]{64}$' -or
       [int64]$candidate.original_size_bytes -le 0){
        throw 'Invalid original preservation candidate.'
    }
    $copy=$backups.files[$index]
    $state='missing'
    if($copy.state -ceq 'observed_untrusted'){
        if($copy.file_object_fingerprint_sha256 -ceq
           $candidate.original_file_object_fingerprint_sha256){
            # A hard link is not a separate original preservation copy.
            $state='same_file_object_as_original'
        }elseif($copy.sha256 -cne $candidate.original_sha256 -or
                [int64]$copy.size_bytes -ne [int64]$candidate.original_size_bytes){
            $state='bytes_do_not_match_original'
        }else{
            $state='same_bytes_distinct_observed_file_object_NOT_CERTIFIED'
            $matched++
        }
    }elseif($copy.state -cne 'missing'){
        throw 'Unrecognized backup copy inspection state.'
    }
    if($state -cne 'same_bytes_distinct_observed_file_object_NOT_CERTIFIED'){
        $blocks.Add('backup_candidate_'+$index+'_'+$state)
    }
    $copies.Add([pscustomobject][ordered]@{
        path=$path
        copy_state=$state
        original_size_bytes=[int64]$candidate.original_size_bytes
        observed_backup_size_bytes=$(if($copy.state -ceq 'observed_untrusted'){
            [int64]$copy.size_bytes
        }else{$null})
        sha256_matches_original=($state -ceq 'same_bytes_distinct_observed_file_object_NOT_CERTIFIED' -or
            $state -ceq 'same_file_object_as_original')
        separate_observed_file_object=($state -ceq 'same_bytes_distinct_observed_file_object_NOT_CERTIFIED' -or
            $state -ceq 'bytes_do_not_match_original')
        authentic_original_provenance_verified=$false
        durable_backup_verified=$false
    })
}
$count=$required.Count
$status=if($blocks.Count){
    'manual_review_existing_backup_copy_blocked'
}elseif($count -eq 0){
    'no_original_replacements_to_compare_NOT_APPROVED'
}else{
    'matching_existing_copies_observed_NOT_RECOVERY_PROOF'
}
$report=[pscustomobject][ordered]@{
    kind='read_only_existing_backup_copy_comparison'
    schema_version=1
    status=$status
    patchset=[string]$readiness.patchset
    original_candidate_count=$count
    observed_separate_matching_copy_count=$matched
    copies=@($copies.ToArray())
    blockers=@($blocks.ToArray())
    blocker_count=$blocks.Count
    review_required=$true
    backup_created=$false
    authentic_backup_provenance_verified=$false
    durable_backup_verified=$false
    originals_backed_up_and_verified=$false
    restores_authorised=$false
    allow_file_writes=$false
    allow_automatic_resume=$false
    authorises_rollback=$false
    records_real_consent=$false
    public_distribution_authorised=$false
    limitations='Checks existing mirrored relative file paths only. Same digest and different file object do not prove original provenance, write durability, storage independence, recovery trust or consent. Separate read-only tool processes close file handles between scans; paths and bytes can change after observation. Missing V/Z in backup root are not errors unless that file is an original candidate.'
}
if($Json){$report | ConvertTo-Json -Depth 6}
else{
    Write-Host 'Naxxramas — READ ONLY EXISTING BACKUP COPIES' -ForegroundColor Cyan
    foreach($copy in $copies){Write-Host ('{0}: {1}' -f $copy.path,$copy.copy_state)}
    foreach($reason in $blocks){Write-Host ('REVIEW: '+$reason)}
    Write-Host ('Result: '+$status)
    Write-Host 'NO BACKUPS CREATED. MATCHING BYTES ARE NOT RESTORE AUTHORITY.' -ForegroundColor Yellow
}
