@echo off
setlocal EnableExtensions
call "%~dp0yuque_notes\installer\build_installer.bat"
set "ERR=%ERRORLEVEL%"
if not "%ERR%"=="0" (
  echo Build failed with code %ERR%
  pause
  exit /b %ERR%
)
pause
endlocal
exit /b 0
