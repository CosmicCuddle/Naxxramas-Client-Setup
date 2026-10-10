@echo off
setlocal
title Naxxramas - Offline N Addon Suite Extraction
echo This safely extracts a verified N Addon Suite ZIP into a NEW folder.
echo Do NOT select your WoW directory as the output parent.
echo.
if "%~1"=="" (
 echo Drag the official N Addon Suite ZIP onto this BAT file.
 pause
 exit /b 1
)
set /p OUTPUT=Enter an existing safe output folder path: 
if "%OUTPUT%"=="" exit /b 1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Extract-Verified-Addon-Suite.ps1" -ArchivePath "%~1" -OutputParent "%OUTPUT%" -Extract
echo.
pause
