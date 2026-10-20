@echo off
setlocal
REM Launch this file from a Git clone to check origin/main before building and running.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\start.ps1" %*
set "ieexit=%ERRORLEVEL%"
if "%~1"=="" pause
exit /b %ieexit%
