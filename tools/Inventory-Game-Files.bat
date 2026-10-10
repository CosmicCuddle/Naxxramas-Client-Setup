@echo off
setlocal
title Naxxramas - Read-Only Game File Inventory
if "%~1"=="" (
 echo Drag the FOLDER containing Wow.exe onto this BAT file.
 echo Only approved game binaries and MPQ archives are hashed.
 echo No personal files are read. Your WoW client is not changed.
 echo SHA-256 hashing of a full client may take several minutes.
 echo.
 pause
 exit /b 1
)
set "REPORT=%~dp0game-files-%RANDOM%-%RANDOM%.json"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Inventory-Game-Files.ps1" -ClientPath "%~1" -ReportPath "%REPORT%"
if errorlevel 1 (
 echo.
 echo Inventory failed. Your WoW client was NOT modified.
) else (
 echo.
 echo Inventory report saved in this tools folder as game-files-*.json.
 echo Review before sharing; do not upload it to a public GitHub repo.
)
echo.
pause
