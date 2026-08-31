@echo off
set PYTHONIOENCODING=utf-8
set PYTHONUTF8=1
chcp 65001 >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ocr.ps1" %*
