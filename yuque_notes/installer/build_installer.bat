@echo off
setlocal
cd /d "%~dp0\.."

set "FLUTTER_BIN=%LOCALAPPDATA%\grok-flutter-sdk\bin"
set "ISCC=%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe"
if not exist "%ISCC%" set "ISCC=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
if not exist "%ISCC%" set "ISCC=%ProgramFiles%\Inno Setup 6\ISCC.exe"

if not exist "%FLUTTER_BIN%\flutter.bat" (
  echo Flutter not found: %FLUTTER_BIN%\flutter.bat
  exit /b 1
)
if not exist "%ISCC%" (
  echo Inno Setup ISCC.exe not found. Install JRSoftware.InnoSetup first.
  exit /b 1
)

set "PATH=%FLUTTER_BIN%;%PATH%"
echo [1/2] Building Windows Release...
call flutter build windows --release
if errorlevel 1 (
  echo flutter build windows failed.
  exit /b 1
)

if not exist "build\windows\x64\runner\Release\NoteYourNeed.exe" (
  echo Release exe not found.
  exit /b 1
)

echo [2/2] Compiling installer with Inno Setup...
"%ISCC%" "%~dp0NoteYourNeed.iss"
if errorlevel 1 (
  echo ISCC failed.
  exit /b 1
)

echo.
echo Installer output:
dir /b "%~dp0output\NoteYourNeed_Setup_*.exe"
echo Done.
endlocal
