@echo off
cd /d "%~dp0"
if exist "target\release\bin\main.exe" (
    "target\release\bin\main.exe"
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File tools/build.ps1 -Run
)
if errorlevel 1 pause
