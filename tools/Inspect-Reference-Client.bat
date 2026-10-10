@echo off
setlocal
title Naxxramas - Verify Existing Reference Client
if "%~1"=="" (
 echo Drag the FOLDER containing Wow.exe onto this BAT file.
 echo This checks V/Z and build 12340 without changing your client.
 pause
 exit /b 1
)
set "REPORT=%~dp0client-reference-%RANDOM%-%RANDOM%.json"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Inspect-Reference-Client.ps1" -ClientPath "%~1" -ReportPath "%REPORT%"
if errorlevel 1 (
 echo.
 echo Check failed. See the error above. Your game has not been changed.
) else (
 echo.
 echo Report created in the tools folder as client-reference-*.json
 echo It contains no account names, game paths, or SavedVariables.
 echo Review the report before sharing it.
)
echo.
pause
