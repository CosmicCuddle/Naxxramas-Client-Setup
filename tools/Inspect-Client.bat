@echo off
setlocal
title Naxxramas Client - Read-Only Inventory

if "%~1"=="" (
    echo Drag your World of Warcraft client FOLDER onto this BAT file.
    echo Your game files will not be changed.
    echo.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Inspect-Client.ps1" -ClientPath "%~1"
if errorlevel 1 (
    echo.
    echo Inventory could not be completed. Read the error above.
) else (
    echo.
    echo Done. Open client-inventory.txt in this tools folder.
)

echo.
pause
