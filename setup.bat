@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
set "result=%ERRORLEVEL%"
if not "%result%"=="0" echo Installation failed (exit code %result%).
echo.
pause
exit /b %result%
