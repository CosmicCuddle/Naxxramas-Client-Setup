#requires -Version 5.1
# Read-only inspector, disposable synthetic JSON input only.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
function Check([bool]$Condition,[string]$Label) {
    if(-not $Condition){throw ('TEST FAILED: '+$Label)}
    Write-Host ('PASS: '+$Label) -ForegroundColor Green
}
function New-Plan {
    $ops=[Array]::CreateInstance([object],5)
    $ops[0]=@('Data/patch-V.mpq','replace_after_backup',('a'*64),('1'*64),$true)
    $ops[1]=@('Data/patch-Z.mpq','install',('b'*64),'-',$false)
    $ops[2]=@('Data/Patch-J.mpq','not_selected','-','-',$false)
    $ops[3]=@('Data/Patch-U.mpq','install',('f'*64),'-',$false)
    $ops[4]=@('Data/enUS/realmlist.wtf','replace_after_backup',('9'*64),('2'*64),$true)
    return ,@(1,'fixture-install-123',('c'*64),('d'*64),('e'*64),'patchset-0001',12340,'enUS',@($false,$true),$ops,'claimed_local_use_reviewed')
}
function Get-TestDigest([array]$Plan) {
    $json=ConvertTo-Json -InputObject $Plan -Depth 16 -Compress
    $bytes=[Text.Encoding]::UTF8.GetBytes('NAXX-PLAN-FIXTURE-1:'+$json)
    $sha=[Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-','').ToLowerInvariant() }
    finally{$sha.Dispose()}
}
function New-V2Receipt([object]$Snapshot=(New-Plan),[string]$Status='explicit_confirmed') {
    return ,@(2,'receipt-digest-123',$Status,$Snapshot,(Get-TestDigest $Snapshot))
}
function Save([string]$File,[object]$Value,[switch]$Indented) {
    $json=ConvertTo-Json -InputObject $Value -Depth 16 -Compress:(-not $Indented)
    [IO.File]::WriteAllText($File,$json,(New-Object Text.UTF8Encoding($false)))
}
function Inspect {
    return ((& $tool -FixturePlanPath $planFile -FixtureApprovalPath $approvalFile -Json | Out-String) | ConvertFrom-Json)
}
function Assert-Review([object]$Plan,[object]$Approval,[string]$Expected,[string[]]$ExpectedReasons,[string]$Label) {
    Save $planFile $Plan
    Save $approvalFile $Approval
    $beforeA=(Get-FileHash -LiteralPath $approvalFile -Algorithm SHA256).Hash
    $beforeP=(Get-FileHash -LiteralPath $planFile -Algorithm SHA256).Hash
    $result=Inspect
    Check ($result.status -ceq $Expected) ($Label+' => '+$result.status)
    foreach($reason in $ExpectedReasons){Check (@($result.blockers) -ccontains $reason) ('Blocker '+$reason)}
    Check ([int]$result.approval_fixture_version -eq 2) 'Recognised v2 synthetic receipt'
    Check ($result.review_required -and -not $result.allow_file_writes -and -not $result.records_real_consent -and -not $result.public_distribution_authorised -and -not $result.allow_automatic_resume -and -not $result.authorises_rollback) 'All outcomes remain non-authoritative and read-only'
    Check ((Get-FileHash -LiteralPath $planFile -Algorithm SHA256).Hash -ceq $beforeP -and (Get-FileHash -LiteralPath $approvalFile -Algorithm SHA256).Hash -ceq $beforeA) 'Reviewer changes neither fixture'
}
function Must-Fail([object]$Plan,[object]$Approval,[string]$Label) {
    Save $planFile $Plan
    Save $approvalFile $Approval
    $failed=$false;try{$null=Inspect}catch{$failed=$true}
    Check $failed $Label
}
$tool=Join-Path (Split-Path -Parent $PSScriptRoot) 'tools/Review-Naxxramas-ApprovalFixture.ps1'
$root=Join-Path ([IO.Path]::GetTempPath()) ('NaxxApprovalDigest-'+[guid]::NewGuid().ToString('N'))
$planFile=Join-Path $root 'plan.json'
$approvalFile=Join-Path $root 'receipt.json'
$consistent='fixture_claims_match_NOT_authenticated'
$blocked='manual_review_approval_snapshot_mismatch'
try {
    $null=New-Item -ItemType Directory -Path $root
    $plan=New-Plan
    $baseDigest=Get-TestDigest $plan
    Check ($baseDigest -ceq '65a32416747a2f400e468cf86f4ab03f9fe2cca19152fe4aed557ca72ff93950') 'Cross-language known SHA-256 of typed canonical test plan'
    $receipt=New-V2Receipt
    Assert-Review $plan $receipt $consistent @() 'Matching v2 digest and snapshot claims'
    $result=Inspect
    Check ($result.approval_digest_matches_claimed_snapshot -and $result.current_plan_digest_matches_claimed_receipt) 'Claimed v2 digest matches both validated snapshots'
    $prettyPlan=New-Plan
    Save $planFile $prettyPlan -Indented
    $result=Inspect
    Check ($result.status -ceq $consistent) 'JSON indentation and whitespace do not alter typed plan digest'
    Check ($result.approval_digest_matches_claimed_snapshot -and $result.current_plan_digest_matches_claimed_receipt) 'V2 receipt digest survives JSON formatting changes'

    $badReceipt=New-V2Receipt
    $badReceipt[4]='0'*64
    Assert-Review (New-Plan) $badReceipt $blocked @('approval_snapshot_digest_invalid','current_plan_digest_differs_from_approval') 'Forged declared digest rejected as inconsistent'

    $changedFrozen=New-V2Receipt
    $changedFrozen[3][3]='0'*64
    Assert-Review (New-Plan) $changedFrozen $blocked @('approval_snapshot_digest_invalid') 'Frozen backup folder changed without updating declared digest'
    $r=Inspect
    Check ($r.current_plan_digest_matches_claimed_receipt -and -not $r.approval_digest_matches_claimed_snapshot) 'Snapshot tampering is distinguished from current-plan drift'

    $changedCurrent=New-Plan
    $changedCurrent[9][0][2]='0'*64
    Assert-Review $changedCurrent (New-V2Receipt) $blocked @('current_plan_digest_differs_from_approval','operation_changed_core_v') 'New V source invalidates prior digest and per-file approval'
    $r=Inspect
    Check ($r.approval_digest_matches_claimed_snapshot -and -not $r.current_plan_digest_matches_claimed_receipt) 'A valid old receipt fails for changed current plan'

    $changedBackup=New-Plan
    $changedBackup[3]='8'*64
    Assert-Review $changedBackup (New-V2Receipt) $blocked @('current_plan_digest_differs_from_approval','backup_directory_changed') 'Backup location change invalidates digest'

    $changedOption=New-Plan
    $changedOption[8][0]=$true
    $changedOption[9][2]=@('Data/Patch-J.mpq','install',('5'*64),'-',$false)
    Assert-Review $changedOption (New-V2Receipt) $blocked @('current_plan_digest_differs_from_approval','optional_j_selection_changed','operation_changed_optional_j') 'J option change invalidates digest'

    $consent=New-V2Receipt -Status 'revoked'
    Assert-Review (New-Plan) $consent $blocked @('approval_not_explicit_or_no_longer_current') 'Revoked v2 consent remains denied'

    $malformed=New-V2Receipt
    $malformed[4]='not-a-hash'
    Must-Fail (New-Plan) $malformed 'Malformed digest rejected'

    $unknown=New-V2Receipt
    $unknown[0]=3
    Must-Fail (New-Plan) $unknown 'Unsupported receipt v3 rejected'

    $extra=New-V2Receipt
    $extra+=@('extra')
    Must-Fail (New-Plan) $extra 'Unexpected receipt fields rejected'

    # Security limitation: caller may forge BOTH digest and receipt.
    $forgedPlan=New-Plan
    $forgedPlan[9][0][2]='4'*64
    $forgedReceipt=New-V2Receipt -Snapshot $forgedPlan
    Assert-Review $forgedPlan $forgedReceipt $consistent @() 'Forged matching plan plus unkeyed digest still not authenticated'
    $r=Inspect
    Check ($r.approval_digest_matches_claimed_snapshot -and $r.current_plan_digest_matches_claimed_receipt -and -not $r.allow_file_writes) 'Correct hash never creates installation authority'

    $raw=(& $tool -FixturePlanPath $planFile -FixtureApprovalPath $approvalFile -Json | Out-String)
    Check (-not $raw.Contains($root)) 'JSON does not expose local fixture paths'
    Check (-not $raw.Contains($baseDigest)) 'JSON does not disclose computed plan digest'
    Check (-not $raw.Contains('fixture-install-123')) 'JSON does not disclose installation identity'
    Write-Host 'All v2 synthetic plan-digest regression tests passed.' -ForegroundColor Green
}
finally {if(Test-Path -LiteralPath $root){Remove-Item -LiteralPath $root -Force -Recurse}}
