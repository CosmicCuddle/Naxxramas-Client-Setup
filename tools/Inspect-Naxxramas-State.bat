@echo off
setlocal
title Naxxramas - Read-Only Installation State Inspector
echo This checks any Naxxramas setup transaction journal.
echo It NEVER changes, repairs, deletes or rolls back files.
echo.
if "%~1"=="" (
  echo Drag a WoW client FOLDER onto this BAT file.
  echo.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup-Prototype.ps1" -Action Inspect -ClientPath "%~1"
echo.
pause
