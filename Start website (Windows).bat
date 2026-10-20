@echo off
title Start website
cd /d "%~dp0"
echo Starting your website...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-website.ps1"
if errorlevel 1 (
  echo.
  echo The website could not be started on this computer.
  echo See https://www.nocodeexport.com/en/blog/run-exported-site-locally
  pause
)
