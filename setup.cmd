@echo off
setlocal
set SCRIPT_DIR=%~dp0
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%setup.ps1" %*
if %ERRORLEVEL% NEQ 0 (
  echo.
  echo setup.ps1 failed with exit code %ERRORLEVEL%.
  echo Supported modes: ^<none^> (full setup) or validate
  echo Examples:
  echo   setup.cmd
  echo   setup.cmd validate
  echo If execution policy or shell restrictions persist, run this manually:
  echo   powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1 %*
  exit /b %ERRORLEVEL%
)
endlocal
