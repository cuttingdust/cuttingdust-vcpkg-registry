@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "PORT=%~1"
if "%PORT%"=="" set "PORT=mlog"

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%registry_add_version.ps1" -Port "%PORT%"
pause
exit /b %ERRORLEVEL%
