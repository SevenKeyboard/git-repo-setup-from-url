@echo off
setlocal

REM Run the PowerShell script located in the same directory as this .bat file
set "SCRIPT_DIR=%~dp0"

powershell.exe ^
  -ExecutionPolicy Bypass ^
  -NoProfile ^
  -File "%SCRIPT_DIR%init-repoworktrees-from-url.ps1"

endlocal
