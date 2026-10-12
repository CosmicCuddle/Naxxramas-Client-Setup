@echo off
setlocal
rem Naxxramas client setup: read-only preview ONLY.
rem No install, approval, patch copying, backup or rollback.
rem Developer/CI-only diagnostic: --diagnostics. Ordinary double-click
rem behaviour is unchanged; no arbitrary options are passed to PowerShell.
if /I "%~1"=="--diagnostics" goto diagnostics
if not "%~1"=="" goto invalid
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Start-Naxxramas-SetupWizard.ps1"
set "NAXX_EXIT=%ERRORLEVEL%"
if not "%NAXX_EXIT%"=="0" (
    echo The read-only preview could not start. No files were changed.
    pause
)
endlocal & exit /b %NAXX_EXIT%

:diagnostics
if not "%~2"=="" goto invalid
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Start-Naxxramas-SetupWizard.ps1" -Diagnostics
set "NAXX_EXIT=%ERRORLEVEL%"
endlocal & exit /b %NAXX_EXIT%

:invalid
echo Only --diagnostics is supported. No files were changed.
endlocal & exit /b 2
