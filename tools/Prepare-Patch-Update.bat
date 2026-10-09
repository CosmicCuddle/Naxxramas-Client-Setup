@echo off
setlocal
title Naxxramas - Prepare Patch Update
echo This compares your current J/U/V/Z patches against the version in this repository.
echo READ ONLY to your WoW folder. It creates only a small JSON proposal inside tools.
echo.
if "%~1"=="" (
  echo Drag your WoW client FOLDER onto this BAT file.
  echo.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Prepare-Patch-Update.ps1" -ClientPath "%~1"
echo.
pause
