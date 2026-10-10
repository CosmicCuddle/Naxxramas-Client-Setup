@echo off
setlocal
if "%~1"=="" (
 echo Drag a private game-files-*.json report onto this BAT file.
 pause
 exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Review-Game-File-Report.ps1" -ReportPath "%~1"
set "code=%errorlevel%"
echo.
pause
exit /b %code%
