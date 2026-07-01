#Requires -RunAsAdministrator
$ErrorActionPreference = 'Continue'
$env:PATH = "$env:LOCALAPPDATA\grok-flutter-sdk\bin;$env:PATH"

$installPath = 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools'
$setup = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\setup.exe"
$installer = "$env:TEMP\vs_BuildTools.exe"

if (-not (Test-Path $installer)) {
    Invoke-WebRequest -Uri 'https://aka.ms/vs/17/release/vs_buildtools.exe' -OutFile $installer
}

function Wait-InstallerProcesses {
    param([int]$Minutes = 45)
    $deadline = (Get-Date).AddMinutes($Minutes)
    while ((Get-Date) -lt $deadline) {
        $busy = Get-Process msiexec, setup, vs_installer -ErrorAction SilentlyContinue
        if (-not $busy) { return }
        Start-Sleep -Seconds 10
    }
}

Write-Host 'Step 1/2: Repair canceled Build Tools installation...'
$repair = Start-Process -FilePath $setup -ArgumentList @(
    'repair',
    '--installPath', $installPath,
    '--passive',
    '--norestart'
) -PassThru -Wait
Write-Host "Repair launcher exit: $($repair.ExitCode)"
Wait-InstallerProcesses

Write-Host 'Step 2/2: Install C++ build tools for Flutter...'
$modify = Start-Process -FilePath $installer -ArgumentList @(
    'modify',
    '--installPath', $installPath,
    '--add', 'Microsoft.VisualStudio.Workload.VCTools',
    '--add', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
    '--add', 'Microsoft.VisualStudio.Component.VC.CMake.Project',
    '--add', 'Microsoft.VisualStudio.Component.Windows11SDK.22621',
    '--includeRecommended',
    '--passive',
    '--norestart',
    '--wait'
) -PassThru -Wait
Write-Host "Modify exit: $($modify.ExitCode)"
Wait-InstallerProcesses

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
Write-Host '--- VS status ---'
& $vswhere -all -products * -property isComplete,isLaunchable,displayName

$cmake = Test-Path "$installPath\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
Write-Host "CMake installed: $cmake"

if (Test-Path "$env:LOCALAPPDATA\grok-flutter-sdk\bin\flutter.bat") {
    & "$env:LOCALAPPDATA\grok-flutter-sdk\bin\flutter.bat" doctor
}

if ($modify.ExitCode -ne 0) {
    Write-Host ''
    Write-Host 'Automatic install failed. Open Visual Studio Installer manually:'
    Write-Host '  1. Start menu -> search "Visual Studio Installer"'
    Write-Host '  2. Build Tools 2022 -> Modify'
    Write-Host '  3. Check workload: "C++ build tools" / "Desktop development with C++"'
    Write-Host '  4. Install and wait until finished'
    Start-Process -FilePath $setup
}