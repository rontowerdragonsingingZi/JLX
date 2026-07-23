# Bump Flutter pubspec patch version and build number, sync Inno Setup MyAppVersion.
# Example: 1.0.1+1 -> 1.0.2+2

param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectDir
)

$ErrorActionPreference = "Stop"
$pubspec = Join-Path $ProjectDir "pubspec.yaml"
$iss = Join-Path $ProjectDir "installer\NoteYourNeed.iss"

if (-not (Test-Path $pubspec)) {
  throw "pubspec.yaml not found: $pubspec"
}

$content = Get-Content -Path $pubspec -Raw -Encoding UTF8
if ($content -notmatch '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$') {
  throw "Cannot parse version in pubspec.yaml (expect x.y.z+build)"
}

$major = [int]$Matches[1]
$minor = [int]$Matches[2]
$patch = [int]$Matches[3]
$build = [int]$Matches[4]

# 小版本：patch +1，同时 build number +1（Android/安装识别）
$patch++
$build++
$newName = "$major.$minor.$patch"
$newFull = "$newName+$build"

$newContent = [regex]::Replace(
  $content,
  '(?m)^version:\s*\d+\.\d+\.\d+\+\d+\s*$',
  "version: $newFull"
)
[System.IO.File]::WriteAllText($pubspec, $newContent, [System.Text.UTF8Encoding]::new($false))

if (Test-Path $iss) {
  $issText = Get-Content -Path $iss -Raw -Encoding UTF8
  $issText = [regex]::Replace(
    $issText,
    '(?m)^#define MyAppVersion ".*"$',
    "#define MyAppVersion `"$newName`""
  )
  [System.IO.File]::WriteAllText($iss, $issText, [System.Text.UTF8Encoding]::new($false))
}

Write-Output $newFull
