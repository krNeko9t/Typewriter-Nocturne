@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1" %*
set "code=%ERRORLEVEL%"
echo.
if "%~1"=="" pause
endlocal & exit /b %code%