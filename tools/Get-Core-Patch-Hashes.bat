@echo off
setlocal
title Naxxramas - Core Patch Hashes
echo Read-only: calculates fingerprints for patch-V.mpq and patch-Z.mpq.
echo.
if "%~1"=="" (
  echo Drag your WoW client FOLDER onto this file.
  echo.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Get-Core-Patch-Hashes.ps1" -ClientPath "%~1"
echo.
pause
