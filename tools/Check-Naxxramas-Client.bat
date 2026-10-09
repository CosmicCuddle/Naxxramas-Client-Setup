@echo off
setlocal
title Naxxramas Client - Read-Only Preflight
echo This tool checks files. It does NOT change your client.
echo.
if "%~1"=="" (
  echo Drag a WoW client FOLDER onto this file.
  echo.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Test-Naxxramas-Client.ps1" -ClientPath "%~1"
echo.
pause
