@echo off
setlocal EnableExtensions DisableDelayedExpansion
rem Source-repository-only HUMAN accessibility QA launcher.
rem Opens existing disposable FAKE Windows wizard fixtures; never accepts game paths.
rem NOT an installer, game test, or proof of visual/accessibility acceptance.
if not "%~1"=="" goto invalid
if /I "%CI%"=="true" goto ci
if /I "%GITHUB_ACTIONS%"=="true" goto ci
if not exist "%~dp0Start-Accessibility-ManualCheck.ps1" goto missing
if not exist "%~dp0Test-SetupWizard.ps1" goto missing
echo.
echo NAXXRAMAS - HUMAN WINDOWS ACCESSIBILITY REVIEW
echo This opens disposable FAKE client scenarios only: Ready, then Blocked.
echo No real World of Warcraft client, patch or account data is used.
echo Change Windows display scaling yourself and repeat the test at
echo 100%%, 125%%, 150%% and 200%%; record your own observations.
echo.
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Start-Accessibility-ManualCheck.ps1" -Interactive -Scenario Both
set "NAXX_EXIT=%ERRORLEVEL%"
if "%NAXX_EXIT%"=="0" (
    echo.
    echo Disposable fake-file checks finished; physical accessibility is NOT VERIFIED.
) else (
    echo.
    echo The disposable review failed or was stopped. Record FAIL or NOT TESTED.
)
echo Complete docs\WINDOWS-ACCESSIBILITY-TEST-RECORD.md using what you saw.
echo Press any key to close this window.
pause >nul
endlocal & exit /b %NAXX_EXIT%

:invalid
echo This QA launcher accepts no arguments, client paths or patch locations.
endlocal & exit /b 2

:ci
echo Interactive human accessibility review is refused in CI.
endlocal & exit /b 2

:missing
echo Source-repository disposable QA fixture is missing. No client was accessed.
endlocal & exit /b 2
