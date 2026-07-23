@echo off
setlocal
title SearXNG for Windows
cd /d "%~dp0"

set "PYTHON=%~dp0python\python.exe"
set "SEARXNG_SETTINGS_PATH=%~dp0config\settings.yml"
set "PYTHONUTF8=1"
set "PYTHONIOENCODING=utf-8"

if not exist "%PYTHON%" (
    echo [ERROR] python.exe was not found:
    echo         %PYTHON%
    pause
    exit /b 1
)

if not exist "%~dp0python\Lib\site-packages\searx\webapp.py" (
    echo [ERROR] SearXNG was not found in the portable Python runtime.
    pause
    exit /b 1
)

if not exist "%SEARXNG_SETTINGS_PATH%" (
    echo [ERROR] settings.yml was not found:
    echo         %SEARXNG_SETTINGS_PATH%
    pause
    exit /b 1
)

if not exist "%~dp0config\.secret" (
    "%PYTHON%" -c "from pathlib import Path; import secrets; Path(r'%~dp0config\.secret').write_text(secrets.token_hex(32), encoding='ascii')"
)
set /p "SEARXNG_SECRET="<"%~dp0config\.secret"

echo Starting SearXNG for Windows...
echo   Web address : http://127.0.0.1:3001/
echo   Settings    : %SEARXNG_SETTINGS_PATH%
echo   Search proxy: http://127.0.0.1:7897
echo.

"%PYTHON%" -m searx.webapp
set "EXIT_CODE=%ERRORLEVEL%"

echo.
echo SearXNG stopped with exit code %EXIT_CODE%.
pause
exit /b %EXIT_CODE%
