#requires -Version 5.1
<#
M26 read-only recovery decision plan for M15 disposable synthetic fixtures.
Uses M25 status inspection. No file writes, copying, deletion, recovery,
network access, automated actions or player-client paths.
Never point this tool at a real World of Warcraft folder.
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$SourcePath,
 [Parameter(Mandatory=$true)][string]$DestinationPath,
 [Parameter(Mandatory=$true)][string]$ManifestPath,
 [string]$StagePath=''
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
function Require([bool]$ok,[string]$reason){if(-not $ok){throw $reason}}
function ExtractSingle([string[]]$lines,[string]$prefix,[string[]]$allowed){
 $matches=@($lines|Where-Object {$_.StartsWith($prefix,[StringComparison]::Ordinal)})
 Require ($matches.Count -eq 1) 'Missing or duplicated status.'
 $value=$matches[0].Substring($prefix.Length).Trim()
 Require ($allowed -ccontains $value) 'Unexpected inspector status.'
 return $value
}
try{
 $inspector=Join-Path $PSScriptRoot 'Inspect-Fixture-Transaction-Status.ps1'
 Require (Test-Path -LiteralPath $inspector -PathType Leaf) 'Read-only status inspector is missing.'
 $argv=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$inspector,
  '-SourcePath',$SourcePath,'-DestinationPath',$DestinationPath,'-ManifestPath',$ManifestPath)
 if(-not [string]::IsNullOrWhiteSpace($StagePath)){$argv+=@('-StagePath',$StagePath)}
 # Never echo raw child output: it may contain local paths if PowerShell itself fails.
 $raw=(& powershell.exe @argv 2>&1|Out-String)
 $exitCode=$LASTEXITCODE
 Require ($null -ne $raw -and $raw.Length -gt 0 -and $raw.Length -le 8192) 'Invalid status-inspector output.'
 $lines=@($raw -split '[\r\n]+'|ForEach-Object {$_.Trim()}|Where-Object {$_ -ne ''})
 Require ($lines -ccontains 'NAXXRAMAS SYNTHETIC TRANSACTION STATUS - READ ONLY') 'Unknown status producer.'
 $transaction=ExtractSingle $lines 'TRANSACTION: ' @(
  'EMPTY_MARKED_DESTINATION_NO_JOURNAL','VERIFIED_PARTIAL_APPLYING',
  'VERIFIED_COPIED','VERIFIED_PARTIAL_ROLLBACK',
  'BLOCKED_JOURNAL_REPLACEMENT_RESIDUE','BLOCKED_JOURNAL_OR_DESTINATION',
  'BLOCKED_UNEXPECTED_DESTINATION_CONTENT','BLOCKED_INVALID_FIXTURE_OR_PATH',
  'BLOCKED_JOURNAL_STATE')
 $stage=ExtractSingle $lines 'STAGE: ' @(
  'NOT_SELECTED','CONSISTENT_REQUIRES_MANUAL_REVIEW',
  'BLOCKED_UNTRUSTED_OR_CHANGED','UNDETERMINED')
 $status=ExtractSingle $lines 'STATUS: ' @('EMPTY_MARKED_FIXTURE','REVIEW_REQUIRED','BLOCKED_MANUAL_REVIEW')
 $blocked=$transaction.StartsWith('BLOCKED_',[StringComparison]::Ordinal) -or
  $stage.StartsWith('BLOCKED_',[StringComparison]::Ordinal) -or $stage -ceq 'UNDETERMINED'
 $expectedStatus=if($blocked){'BLOCKED_MANUAL_REVIEW'}
  elseif($transaction -ceq 'EMPTY_MARKED_DESTINATION_NO_JOURNAL' -and $stage -ceq 'NOT_SELECTED'){'EMPTY_MARKED_FIXTURE'}
  else{'REVIEW_REQUIRED'}
 Require ($status -ceq $expectedStatus) 'Inconsistent inspector status.'
 Require (($exitCode -eq 0) -eq (-not $blocked)) 'Inconsistent inspector result code.'
 $transactionReview=switch($transaction){
  'EMPTY_MARKED_DESTINATION_NO_JOURNAL' {'NO_TRANSACTION_JOURNAL_RECORDED';break}
  'VERIFIED_PARTIAL_APPLYING' {'REVIEW_INTERRUPTED_COPY_AGAINST_BACKUP';break}
  'VERIFIED_COPIED' {'VERIFY_EXPECTED_COPIED_RESULT_MANUALLY';break}
  'VERIFIED_PARTIAL_ROLLBACK' {'REVIEW_INTERRUPTED_ROLLBACK_AGAINST_BACKUP';break}
  default {'STOP_AND_PRESERVE_UNCERTAIN_TRANSACTION';break}
 }
 $stageReview=switch($stage){
  'NOT_SELECTED' {'NO_STAGE_SELECTED_OR_DISCOVERED';break}
  'CONSISTENT_REQUIRES_MANUAL_REVIEW' {'INSPECT_NOMINATED_STAGE_NO_CLEANUP_AUTHORISED';break}
  default {'PRESERVE_UNTRUSTED_STAGE_FOR_MANUAL_REVIEW';break}
 }
 $decision=if($blocked){'STOP_PRESERVE_AND_ESCALATE'}
  elseif($status -ceq 'EMPTY_MARKED_FIXTURE'){'NO_TRANSACTION_ACTION_SUGGESTED'}
  else{'HUMAN_REVIEW_ONLY'}
 Write-Host 'NAXXRAMAS SYNTHETIC RECOVERY DECISION PLAN - READ ONLY'
 Write-Host ('TRANSACTION: '+$transaction)
 Write-Host ('STAGE: '+$stage)
 Write-Host ('DECISION: '+$decision)
 Write-Host ('TRANSACTION REVIEW: '+$transactionReview)
 Write-Host ('STAGE REVIEW: '+$stageReview)
 Write-Host 'PERMITTED AUTOMATIC ACTIONS: NONE'
 Write-Host 'BACKUP: Preserve source, destination and any nominated stage before investigating.'
 Write-Host 'NEXT: Re-check with read-only tools after independent manual review; statuses are snapshots.'
 Write-Host 'The tool did not list sibling stages, issue commands, delete/copy files or save a report.'
 Write-Host 'Do NOT interpret a consistent status as permission to perform rollback or cleanup.'
 if($blocked){exit 1}
 exit 0
}catch{
 # No exception details: these may disclose sensitive absolute paths or names.
 Write-Host 'NAXXRAMAS SYNTHETIC RECOVERY DECISION PLAN - READ ONLY'
 Write-Host 'DECISION: STOP_PRESERVE_AND_ESCALATE'
 Write-Host 'TRANSACTION REVIEW: UNDETERMINED'
 Write-Host 'STAGE REVIEW: UNDETERMINED'
 Write-Host 'PERMITTED AUTOMATIC ACTIONS: NONE'
 Write-Host 'Status check failed. No files were changed; seek manual review.'
 exit 1
}
