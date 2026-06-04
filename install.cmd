@echo off
where pwsh >nul 2>nul
if errorlevel 1 (
  echo PowerShell 7+ ^(pwsh^) is required. Install it from https://aka.ms/powershell and re-run.
  pause
  exit /b 1
)
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
pause
