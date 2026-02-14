:: SPDX-License-Identifier: MIT
:: Copyright (c) 2026 Steve Chang

@REM run_nptop.bat

@echo off
REM Run a PowerShell script in a SEPARATE window.
REM The window closes AUTOMATICALLY when the script ends.
REM Default target script name:
set "PS1=nptop.ps1"

setlocal
pushd "%~dp0"

if not exist "%PS1%" (
  echo [ERROR] Cannot find "%PS1%"
  pause
  goto :end
)

REM Prefer PowerShell 7 (pwsh), fallback to Windows PowerShell
REM Use "start" to launch in a new window.
REM Use "-NoExit" so the window stays open after Ctrl+C (so you can see "Monitor stopped").
where pwsh >nul 2>nul
if %ERRORLEVEL%==0 (
  @REM start "nptop" pwsh -NoExit -NoProfile -ExecutionPolicy Bypass -File "%~dp0%PS1%" %*
  start "nptop" pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0%PS1%" %*
  goto :end
)

REM Fallback to Windows PowerShell
where powershell >nul 2>nul
if %ERRORLEVEL%==0 (
  @REM start "nptop" powershell -NoExit -NoProfile -ExecutionPolicy Bypass -File "%~dp0%PS1%" %*
  start "nptop" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0%PS1%" %*
  goto :end
)

echo [ERROR] Neither PowerShell 7 (pwsh) nor Windows PowerShell is available.
pause

:end
popd
endlocal
REM Exit the BAT script immediately
exit /b
