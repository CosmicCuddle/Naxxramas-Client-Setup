@echo off
setlocal
title Naxxramas - Verify N Addon Suite ZIP
echo Read-only verification of the official N Addon Suite ZIP.
echo This will NOT install or extract addons.
echo.
if "%~1"=="" (
 echo Drag your downloaded N Addon Suite ZIP onto this BAT file.
 echo.
 pause
 exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Test-Addon-Release.ps1" -ArchivePath "%~1"
echo.
pause
