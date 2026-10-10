@echo off
setlocal
title Naxxramas Client - Read-Only Installation Plan
echo This tool PREVIEWS possible file changes only.
echo It will NOT modify, copy, delete or download files.
echo.
if "%~1"=="" (
  echo Drag the WoW CLIENT FOLDER onto this BAT file.
  echo.
  echo Advanced options are documented in docs\INSTALLER-PLAN.md.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Plan-Naxxramas-Install.ps1" -ClientPath "%~1"
echo.
echo No game files were changed by this preview.
pause
