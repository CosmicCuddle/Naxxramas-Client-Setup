@echo off
setlocal
title Naxxramas - Read-Only Setup Preview
echo Opening the read-only setup interface.
echo This interface cannot install, download or modify game files.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Naxxramas-Preview.ps1"
if errorlevel 1 (
 echo The preview could not start. Windows PowerShell 5.1 is required.
 pause
)
