@echo off
setlocal
if "%~1"=="" (
 echo Drag your backed-up DEVELOPMENT WoW client folder onto this BAT file.
 pause
 exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Inspect-Unclassified-MPQs.ps1" -ClientPath "%~1"
set "rc=%errorlevel%"
echo.
pause
exit /b %rc%
