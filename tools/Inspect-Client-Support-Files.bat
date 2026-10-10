@echo off
setlocal
if "%~1"=="" (
 echo Drag your backed-up DEVELOPMENT WoW client folder onto this BAT file.
 pause
 exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Inspect-Client-Support-Files.ps1" -ClientPath "%~1"
set "result=%errorlevel%"
echo.
pause
exit /b %result%
