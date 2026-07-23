@echo off
setlocal EnableExtensions
cd /d "%~dp0\.."

set "PROJECT_DIR=%CD%"
set "INSTALLER_DIR=%PROJECT_DIR%\installer"
set "FLUTTER_BIN=%LOCALAPPDATA%\grok-flutter-sdk\bin"
set "ISCC=%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe"
if not exist "%ISCC%" set "ISCC=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
if not exist "%ISCC%" set "ISCC=%ProgramFiles%\Inno Setup 6\ISCC.exe"

if not exist "%PROJECT_DIR%\pubspec.yaml" (
  echo [ERROR] Project not found: %PROJECT_DIR%
  exit /b 1
)
if not exist "%FLUTTER_BIN%\flutter.bat" (
  echo [ERROR] Flutter not found: %FLUTTER_BIN%\flutter.bat
  exit /b 1
)
if not exist "%ISCC%" (
  echo [ERROR] Inno Setup ISCC.exe not found.
  exit /b 1
)

set "PATH=%FLUTTER_BIN%;%PATH%"

echo [1/3] Bump version...
set "NEW_VER="
for /f "usebackq delims=" %%V in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%INSTALLER_DIR%\bump_version.ps1" -ProjectDir "%PROJECT_DIR%"`) do set "NEW_VER=%%V"
if not defined NEW_VER (
  echo [ERROR] Version bump failed.
  exit /b 1
)
echo       New version: %NEW_VER%

echo [2/3] Kill app and build Release...
taskkill /F /IM NoteYourNeed.exe >nul 2>&1
timeout /t 1 /nobreak >nul
call flutter build windows --release
if errorlevel 1 (
  echo [ERROR] flutter build windows failed.
  exit /b 1
)
if not exist "%PROJECT_DIR%\build\windows\x64\runner\Release\NoteYourNeed.exe" (
  echo [ERROR] NoteYourNeed.exe not found.
  exit /b 1
)

echo [3/3] Compile installer...
"%ISCC%" "%INSTALLER_DIR%\NoteYourNeed.iss"
if errorlevel 1 (
  echo [ERROR] ISCC failed.
  exit /b 1
)

echo.
echo DONE version=%NEW_VER%
dir /b "%INSTALLER_DIR%\output\NoteYourNeed_Setup_*.exe"
endlocal
exit /b 0
