@echo off
setlocal
rem Naxxramas client setup: read-only preview ONLY.
rem No install, approval, patch copying, backup or rollback.
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Start-Naxxramas-SetupWizard.ps1"
if errorlevel 1 (
    echo The read-only preview could not start. No files were changed.
    pause
)
endlocal
