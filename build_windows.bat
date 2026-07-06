@echo off
setlocal

set "PROJECT_DIR=C:\MyDemo\bss\yuque_notes"
set "FLUTTER_BIN=%LOCALAPPDATA%\grok-flutter-sdk\bin"

if not exist "%PROJECT_DIR%\pubspec.yaml" (
  echo Project not found: %PROJECT_DIR%
  pause
  exit /b 1
)

if not exist "%FLUTTER_BIN%\flutter.bat" (
  echo Flutter not found: %FLUTTER_BIN%\flutter.bat
  pause
  exit /b 1
)

cd /d "%PROJECT_DIR%"
set "PATH=%LOCALAPPDATA%\grok-flutter-sdk\bin;%PATH%"

flutter build windows
if errorlevel 1 (
  echo.
  echo Windows build failed.
  pause
  exit /b 1
)

echo.
echo Windows build completed.
echo Output: %CD%\build\windows\x64\runner\Release
pause
