#requires -Version 5.1
<#
Developer/CI only: safe, disposable negative-path tests for the one-command
accessibility coordinator. This test copies ONLY its script under a new temp
directory and supplies a fake exit-code-only fixture. No genuine game paths,
MPQs, client files, installed addons or player WTF data are ever used.
#>
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest

function Check([bool]$Condition,[string]$Description){
    if(-not $Condition){throw ('TEST FAILED: '+$Description)}
    Write-Host ('PASS: '+$Description) -ForegroundColor Green
}
$launcherSource=Join-Path $PSScriptRoot 'Start-Accessibility-ManualCheck.ps1'
$temporary=Join-Path ([IO.Path]::GetTempPath()) ('NaxxQA-Negative-'+[guid]::NewGuid().ToString('N'))
$launcher=Join-Path $temporary 'Start-Accessibility-ManualCheck.ps1'
$fixture=Join-Path $temporary 'Test-SetupWizard.ps1'
$log=Join-Path $temporary 'fake-scenario-calls.txt'
$engine=Join-Path $PSHOME 'powershell.exe'
$previousCi=$env:CI
$previousGitHub=$env:GITHUB_ACTIONS
$previousFailure=$env:NAXX_SYNTHETIC_QA_TEST_FAIL
try{
    [void](New-Item -Path $temporary -ItemType Directory -ErrorAction Stop)
    Copy-Item -LiteralPath $launcherSource -Destination $launcher -ErrorAction Stop

    # The stub performs no file writes except its own FAKE call log.
    # Its controlled exit code proves the wrapper aborts immediately when
    # the first or second child fails.
    $stub=@'
param(
    [switch]$ManualReview,
    [ValidateSet('Ready','Blocked')][string]$ManualScenario='Ready',
    [switch]$ManualHeadless
)
$record=Join-Path $PSScriptRoot 'fake-scenario-calls.txt'
[IO.File]::AppendAllText($record,($ManualScenario+[Environment]::NewLine))
if($env:NAXX_SYNTHETIC_QA_TEST_FAIL -ceq $ManualScenario){exit 17}
exit 0
'@
    [IO.File]::WriteAllText($fixture,$stub,(New-Object Text.UTF8Encoding($false)))
    $env:CI='true'
    $env:GITHUB_ACTIONS='true'
    $env:NAXX_SYNTHETIC_QA_TEST_FAIL=$null

    function Run-QA([string[]]$Arguments){
        if(Test-Path -LiteralPath $log){Remove-Item -LiteralPath $log -Force}
        $previousPreference=$ErrorActionPreference
        try{
            # Capture native child errors without allowing Windows PowerShell
            # 5.1 stderr formatting to skip the intended exit-code assertion.
            $ErrorActionPreference='Continue'
            $output=(& $engine -NoProfile -STA -ExecutionPolicy Bypass -File $launcher @Arguments 2>&1 | Out-String)
            $exitCode=$LASTEXITCODE
        }finally{
            $ErrorActionPreference=$previousPreference
        }
        $calls=if(Test-Path -LiteralPath $log){
            @([IO.File]::ReadAllLines($log))
        }else{@()}
        return [pscustomobject]@{
            exit_code=[int]$exitCode
            calls=@($calls)
            output=[string]$output
        }
    }

    $pass=Run-QA @('-Headless','-Scenario','Both')
    Check ($pass.exit_code -eq 0 -and ($pass.calls -join '|') -ceq 'Ready|Blocked' -and
        $pass.output.Contains('SYNTHETIC FIXTURES COMPLETE')) 'Headless Both runs Ready then Blocked and returns success only afterward'

    $ready=Run-QA @('-Headless','-Scenario','Ready')
    Check ($ready.exit_code -eq 0 -and ($ready.calls -join '|') -ceq 'Ready') 'Explicit Ready does not invoke Blocked'

    $blocked=Run-QA @('-Headless','-Scenario','Blocked')
    Check ($blocked.exit_code -eq 0 -and ($blocked.calls -join '|') -ceq 'Blocked') 'Explicit Blocked does not invoke Ready'

    $env:NAXX_SYNTHETIC_QA_TEST_FAIL='Ready'
    $failedReady=Run-QA @('-Headless','-Scenario','Both')
    Check ($failedReady.exit_code -ne 0 -and ($failedReady.calls -join '|') -ceq 'Ready' -and
        -not $failedReady.output.Contains('SYNTHETIC FIXTURES COMPLETE')) 'Failed Ready aborts before any Blocked scenario and cannot report overall completion'

    $env:NAXX_SYNTHETIC_QA_TEST_FAIL='Blocked'
    $failedBlocked=Run-QA @('-Headless','-Scenario','Both')
    Check ($failedBlocked.exit_code -ne 0 -and ($failedBlocked.calls -join '|') -ceq 'Ready|Blocked' -and
        -not $failedBlocked.output.Contains('SYNTHETIC FIXTURES COMPLETE')) 'Failed Blocked returns nonzero after Ready and cannot report overall completion'

    $env:NAXX_SYNTHETIC_QA_TEST_FAIL=$null
    $noMode=Run-QA @()
    Check ($noMode.exit_code -ne 0 -and $noMode.calls.Count -eq 0) 'Missing explicit mode fails before fixture execution'

    $bothModes=Run-QA @('-Interactive','-Headless')
    Check ($bothModes.exit_code -ne 0 -and $bothModes.calls.Count -eq 0) 'Conflicting mode switches fail before fixture execution'

    $badScenario=Run-QA @('-Headless','-Scenario','Never')
    Check ($badScenario.exit_code -ne 0 -and $badScenario.calls.Count -eq 0) 'Unknown scenario is refused before fixture execution'

    $unknownInput=Run-QA @('-Headless','-Scenario','Both','-ClientPath','C:\NOT_A_CLIENT')
    Check ($unknownInput.exit_code -ne 0 -and $unknownInput.calls.Count -eq 0) 'Client path input is not accepted by QA launcher'

    $interactiveCi=Run-QA @('-Interactive','-Scenario','Ready')
    Check ($interactiveCi.exit_code -ne 0 -and $interactiveCi.calls.Count -eq 0) 'Interactive GUI is refused under CI before fixture execution'

    Remove-Item -LiteralPath $fixture -Force
    $missingFixture=Run-QA @('-Headless','-Scenario','Ready')
    Check ($missingFixture.exit_code -ne 0 -and $missingFixture.calls.Count -eq 0) 'Missing disposable fixture fails closed'

    Write-Host 'All accessibility launcher negative-path tests passed; only temporary fake files were used.' -ForegroundColor Green
}finally{
    $env:CI=$previousCi
    $env:GITHUB_ACTIONS=$previousGitHub
    $env:NAXX_SYNTHETIC_QA_TEST_FAIL=$previousFailure
    if(Test-Path -LiteralPath $temporary){Remove-Item -LiteralPath $temporary -Recurse -Force}
}
