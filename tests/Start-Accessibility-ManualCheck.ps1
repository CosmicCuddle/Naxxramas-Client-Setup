#requires -Version 5.1
<#
.SYNOPSIS
Run the existing disposable Windows accessibility fixtures in one command.
.DESCRIPTION
Developer/manual QA only. This entrypoint NEVER accepts a client path, patch
source, backup destination or real files. It delegates exclusively to
tests/Test-SetupWizard.ps1, which creates ephemeral FAKE files, compares their
hashes and removes them after the wizard closes.

A successful test proves only that the disposable files were preserved. It
DOES NOT prove physical DPI, screen-reader or contrast accessibility.
.EXAMPLE
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File ".\tests\Start-Accessibility-ManualCheck.ps1" -Interactive
.EXAMPLE
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File ".\tests\Start-Accessibility-ManualCheck.ps1" -Headless -Scenario Both
#>
[CmdletBinding()]
param(
    [switch]$Interactive,
    [switch]$Headless,
    [ValidateSet('Both','Ready','Blocked')]
    [string]$Scenario='Both'
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest

# Fail before inspecting or invoking any fixture if the caller omits a mode
# or requests both. Explicit validation avoids PowerShell 5.1 prompting for
# mandatory parameter-set choices in unattended execution.
if(([bool]$Interactive) -eq ([bool]$Headless)){
    throw 'Specify exactly one QA mode: -Interactive or -Headless.'
}
if([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT){
    throw 'This check requires Windows PowerShell 5.1 on Windows.'
}
if($PSVersionTable.PSEdition -ne 'Desktop' -or
    $PSVersionTable.PSVersion.Major -ne 5 -or
    $PSVersionTable.PSVersion.Minor -lt 1){
    throw 'Run this with Windows PowerShell 5.1 (powershell.exe), not PowerShell 7.'
}
if($Interactive -and ($env:CI -eq 'true' -or $env:GITHUB_ACTIONS -eq 'true')){
    throw 'An interactive accessibility test cannot run unattended in CI.'
}
$fixture=Join-Path $PSScriptRoot 'Test-SetupWizard.ps1'
if(-not (Test-Path -LiteralPath $fixture -PathType Leaf)){
    throw 'Disposable Windows wizard fixture is missing from the source repository.'
}
$engine=Join-Path $PSHOME 'powershell.exe'
if(-not (Test-Path -LiteralPath $engine -PathType Leaf)){
    throw 'The Windows PowerShell 5.1 executable is missing.'
}
$scenarios=if($Scenario -eq 'Both'){@('Ready','Blocked')}else{@($Scenario)}

Write-Host ''
Write-Host 'NAXXRAMAS - WINDOWS ACCESSIBILITY CHECK' -ForegroundColor Cyan
Write-Host 'SOURCE-REPOSITORY QA ONLY. No real WoW client path or patch is accepted.'
Write-Host 'Only automatically generated FAKE client/source/backup files are exercised.'
Write-Host 'The wizard remains REVIEW ONLY: no install, approval, copy, restore or release.'
if($Headless){
    Write-Host 'HEADLESS: no GUI, scaling simulation or screen-reader testing is performed.'
}else{
    Write-Host 'HUMAN CHECK: run again at real Windows display scales 100%, 125%, 150%, 200%.'
    Write-Host 'Record every real result yourself; passing fake files does NOT certify accessibility.'
}
Write-Host ''

foreach($current in $scenarios){
    Write-Host ('SCENARIO: '+$current) -ForegroundColor Cyan
    if($Interactive){
        if($current -eq 'Ready'){
            Write-Host '1. In the opened fake wizard, choose Review Only. Nothing is installed.'
            Write-Host '2. Tab to Read Review Text, press Enter/Space, and read/scroll the result.'
            Write-Host '3. Open View File Details: six read-only file rows, warnings and Close Review.'
        }else{
            Write-Host '1. Press Review Only. The synthetic unrecognised V must remain BLOCKED.'
            Write-Host '2. Navigate the read-only warnings; missing backup is a manual-review concern.'
            Write-Host '3. Change an option. The old result should clear; nothing may be approved.'
        }
        Write-Host 'Check keyboard focus, visible clipping and (if available) Narrator/contrast theme.'
        Write-Host 'Close the wizard normally; synthetic file integrity and cleanup run afterwards.'
        Write-Host ''
    }
    $arguments=@(
        '-NoProfile','-STA','-ExecutionPolicy','Bypass',
        '-File',$fixture,'-ManualReview','-ManualScenario',$current
    )
    if($Headless){$arguments+='-ManualHeadless'}
    # The fixture contains the sole temporary file writer and performs SHA-256
    # comparison of all generated client/source/backup files on close.
    & $engine @arguments
    $code=$LASTEXITCODE
    if($code -ne 0){
        throw ('The disposable '+$current+' accessibility fixture failed (exit '+$code+
            '). Human acceptance must remain NOT TESTED or FAIL as appropriate.')
    }
    Write-Host ('Synthetic '+$current+' fixture completed without detected file changes.') -ForegroundColor Green
    Write-Host ''
}
Write-Host 'SYNTHETIC FIXTURES COMPLETE; actual DPI/keyboard/screen-reader/contrast results are NOT RECORDED.' -ForegroundColor Yellow
Write-Host 'Complete docs/WINDOWS-ACCESSIBILITY-TEST-RECORD.md using your direct observations.'
Write-Host 'No installation, backup, rollback, public release or real client operation was authorised.'
