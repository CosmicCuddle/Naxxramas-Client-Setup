#requires -Version 5.1
# Generated JSON only: no game files, actual consent, backups or installer writes.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest

function Check([bool]$Ok,[string]$Name) {
    if(-not $Ok){throw "TEST FAILED: $Name"}
    Write-Host "PASS: $Name" -ForegroundColor Green
}
function Plan {
    $ops=[Array]::CreateInstance([object],5)
    $ops[0]=@('Data/patch-V.mpq','replace_after_backup',('a'*64),('1'*64),$true)
    $ops[1]=@('Data/patch-Z.mpq','install',('b'*64),'-',$false)
    $ops[2]=@('Data/Patch-J.mpq','not_selected','-','-',$false)
    $ops[3]=@('Data/Patch-U.mpq','install',('f'*64),'-',$false)
    $ops[4]=@('Data/enUS/realmlist.wtf','replace_after_backup',('9'*64),('2'*64),$true)
    return ,@(1,'fixture-install-123',('c'*64),('d'*64),('e'*64),'patchset-0001',12340,'enUS',@($false,$true),$ops,'claimed_local_use_reviewed')
}
function Receipt([object]$Snapshot=(Plan),[string]$Consent='explicit_confirmed'){
    return ,@(1,'receipt-12345',$Consent,$Snapshot)
}
function Save([string]$Path,[object]$Value){
    [IO.File]::WriteAllText($Path,(ConvertTo-Json -InputObject $Value -Compress -Depth 12),(New-Object Text.UTF8Encoding($false)))
}
function Inspect {
    $argsMap=@{FixturePlanPath=$planPath;FixtureApprovalPath=$receiptPath;Json=$true}
    return ((& $inspector @argsMap | Out-String) | ConvertFrom-Json)
}
function Review([object]$Current,[object]$Frozen,[string]$Want,[string[]]$Required,[string]$Description){
    Save $planPath $Current
    if($null -eq $Frozen){
        if(Test-Path -LiteralPath $receiptPath){Remove-Item -LiteralPath $receiptPath}
    }else{Save $receiptPath $Frozen}
    $beforePlan=(Get-FileHash -LiteralPath $planPath -Algorithm SHA256).Hash
    $beforeReceipt=if($null -ne $Frozen){(Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash}else{$null}
    $result=Inspect
    Check ($result.status -ceq $Want) ($Description+': '+$result.status)
    $safe=$result.review_required -and -not $result.allow_file_writes -and -not $result.allow_automatic_resume -and -not $result.authorises_rollback -and -not $result.records_real_consent -and -not $result.public_distribution_authorised
    Check $safe 'Never authorises client writes, auto-resume, rollback or redistribution'
    $blockers=@($result.blockers)
    Check ($blockers.Count -eq [int]$result.blocker_count) 'Blocker count is accurate'
    foreach($block in $Required){ Check ($blockers -ccontains $block) ('Blocker: '+$block) }
    Check ($beforePlan -ceq (Get-FileHash -LiteralPath $planPath -Algorithm SHA256).Hash) 'Plan fixture is byte-exact unchanged'
    if($null -ne $Frozen){
        Check ($beforeReceipt -ceq (Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash) 'Approval fixture remains unchanged'
    }else{Check (-not (Test-Path -LiteralPath $receiptPath)) 'Missing receipt was not recreated'}
}
function Invalid([object]$Current,[object]$Frozen,[string]$Description){
    Save $planPath $Current
    Save $receiptPath $Frozen
    $bad=$false
    try{$null=Inspect}catch{$bad=$true}
    Check $bad $Description
}
$repo=Split-Path -Parent $PSScriptRoot
$inspector=Join-Path $repo 'tools/Review-Naxxramas-ApprovalFixture.ps1'
$temp=Join-Path ([IO.Path]::GetTempPath()) ('NaxxApprovalFixture-'+[guid]::NewGuid().ToString('N'))
$planPath=Join-Path $temp 'current-plan.json'
$receiptPath=Join-Path $temp 'approval-receipt.json'
$blocked='manual_review_approval_snapshot_mismatch'
try{
    $null=New-Item -ItemType Directory -Path $temp
    Review (Plan) (Receipt) 'fixture_claims_match_NOT_authenticated' @() 'Matching approval claims are never authenticated'
    Review (Plan) $null $blocked @('approval_record_missing') 'Missing receipt'
    foreach($state in @('pending','revoked','expired')){
        Review (Plan) (Receipt -Consent $state) $blocked @('approval_not_explicit_or_no_longer_current') ('Consent '+$state)
    }
    $f=Plan;$f[1]='other-install-123'
    Review $f (Receipt) $blocked @('installation_identity_changed') 'Installation identity changed'
    $f=Plan;$f[2]='0'*64
    Review $f (Receipt) $blocked @('client_directory_changed') 'Client copy or folder swap'
    $f=Plan;$f[3]='0'*64
    Review $f (Receipt) $blocked @('backup_directory_changed') 'Backup destination changed'
    $f=Plan;$f[4]='0'*64
    Review $f (Receipt) $blocked @('patch_source_directory_changed') 'Local source directory changed'
    $f=Plan;$f[5]='patchset-0002'
    Review $f (Receipt) $blocked @('patchset_changed') 'Patchset changed'
    $f=Plan;$f[8][0]=$true;$f[9][2]=@('Data/Patch-J.mpq','install',('3'*64),'-',$false)
    Review $f (Receipt) $blocked @('optional_j_selection_changed','operation_changed_optional_j') 'J enabled'
    $f=Plan;$f[8][1]=$false;$f[9][3]=@('Data/Patch-U.mpq','not_selected','-','-',$false)
    Review $f (Receipt) $blocked @('optional_u_selection_changed','operation_changed_optional_u') 'U disabled'
    $f=Plan;$f[9][0][2]='0'*64
    Review $f (Receipt) $blocked @('operation_changed_core_v') 'V source digest changed'
    $f=Plan;$f[9][1][2]='0'*64
    Review $f (Receipt) $blocked @('operation_changed_core_z') 'Z source digest changed'
    $f=Plan;$f[9][0][3]='0'*64
    Review $f (Receipt) $blocked @('operation_changed_core_v') 'Existing V changed after consent'
    $f=Plan;$f[9][4][2]='0'*64
    Review $f (Receipt) $blocked @('operation_changed_realmlist') 'Realm config changed'
    $f=Plan;$f[9][2][3]='0'*64
    Review $f (Receipt) $blocked @('operation_changed_optional_j') 'Unselected existing optional patch changed'
    $f=Plan;$f[10]='unverified'
    Review $f (Receipt) $blocked @('source_provenance_claim_changed','patch_source_provenance_not_reviewed') 'Provenance status changed'
    $f=Plan;$f[10]='unverified'
    Review $f (Receipt -Snapshot $f) $blocked @('patch_source_provenance_not_reviewed') 'Unreviewed provenance never becomes valid just by matching'

    $f=Plan;$f[9][0][4]=$false
    Invalid $f (Receipt) 'V replacement missing backup requirement rejected'
    $f=Plan;$f[9][1][3]='1'*64
    Invalid $f (Receipt) 'Install action may not overwrite a preexisting Z file'
    $f=Plan;$f[9][0][1]='not_selected'
    Invalid $f (Receipt) 'Mandatory V cannot be deselected'
    $f=Plan;$f[9][1][0]='../patch-Z.mpq'
    Invalid $f (Receipt) 'Path traversal blocked'
    $f=Plan;$f[9][2][1]='install'
    Invalid $f (Receipt) 'J selection and operation must agree'
    $f=Plan;$f[7]='enGB'
    Invalid $f (Receipt) 'Wrong locale rejected'
    $f=Plan;$f[6]=99999
    Invalid $f (Receipt) 'Wrong game build rejected'
    $f=Plan;$f[8][0]='false'
    Invalid $f (Receipt) 'Optional selection must be a JSON boolean'
    $r=Receipt;$r[0]=2
    Invalid (Plan) $r 'Wrong receipt schema rejected'
    $r=Receipt;$r[2]='silently_approved'
    Invalid (Plan) $r 'Unexpected consent state rejected'
    $r=Receipt;$r[3]=@(1)
    Invalid (Plan) $r 'Malformed frozen snapshot rejected'
    $r=Receipt;$r[3][9][1][1]='not_selected'
    Invalid (Plan) $r 'Frozen snapshot cannot disable mandatory Z'
    $f=Plan;$f[10]='public_distribution_approved'
    Invalid $f (Receipt) 'Unapproved redistribution claim rejected'

    Save $planPath (Plan)
    [IO.File]::WriteAllText($receiptPath,'{"status":1,"status":2}')
    $wrong=$false;try{$null=Inspect}catch{$wrong=$true}
    Check $wrong 'Duplicate JSON object properties rejected'
    [IO.File]::WriteAllText($receiptPath,('x'*16385))
    $wrong=$false;try{$null=Inspect}catch{$wrong=$true}
    Check $wrong 'Oversized receipt rejected'
    Save $receiptPath (Receipt)
    [IO.File]::WriteAllText($planPath,('x'*16385))
    $wrong=$false;try{$null=Inspect}catch{$wrong=$true}
    Check $wrong 'Oversized current plan rejected'
    Save $planPath (Plan)
    $raw=(& $inspector -FixturePlanPath $planPath -FixtureApprovalPath $receiptPath -Json | Out-String)
    Check (-not $raw.Contains($temp)) 'Output does not expose paths'
    Check (-not $raw.Contains('fixture-install-123')) 'Output omits installation ID'
    Check (-not $raw.Contains('a'*64)) 'Output omits source SHA'
    Write-Host 'All read-only approval snapshot tests passed.' -ForegroundColor Green
}finally{
    if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp -Recurse -Force}
}
