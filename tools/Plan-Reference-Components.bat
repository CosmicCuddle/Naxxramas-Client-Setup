@echo off
setlocal
title Naxxramas - Reference Component Plan (Read Only)
if "%~1"=="" (
 echo Drag your client-reference-*.json REPORT onto this BAT file.
 echo This does NOT need the WoW client and does not change game files.
 echo.
 pause
 exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Plan-Reference-Components.ps1" -ReportPath "%~1"
if errorlevel 1 (
 echo.
 echo The report could not be classified. No files were changed.
) else (
 echo.
 echo Read-only component plan complete. Your game was not changed.
)
echo.
pause
