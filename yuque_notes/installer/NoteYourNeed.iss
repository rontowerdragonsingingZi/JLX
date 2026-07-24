; NoteYourNeed Windows installer (Inno Setup 6+)
; 由 build_windows.bat / installer\build_installer.bat 调用
; AppId 固定：已安装用户再次安装同一安装包时会覆盖升级（保留 AppData 笔记数据）

#define MyAppName "NoteYourNeed"
#define MyAppVersion "1.0.12"
#define MyAppPublisher "NoteYourNeed"
#define MyAppExeName "NoteYourNeed.exe"
#define MyAppSource "..\build\windows\x64\runner\Release"

[Setup]
; 固定 AppId：同一应用升级覆盖，不要改
AppId={{8F3C2A1B-9D4E-4F6A-B7C8-1E2D3A4B5C6D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; 升级时沿用上次安装目录
UsePreviousAppDir=yes
UsePreviousGroup=yes
UsePreviousTasks=yes
; 普通用户也可安装（不强制管理员）
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
; 安装前尽量关闭正在运行的应用，便于覆盖更新
CloseApplications=yes
RestartApplications=no
OutputDir=output
OutputBaseFilename=NoteYourNeed_Setup_{#MyAppVersion}
SetupIconFile=
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}
VersionInfoVersion={#MyAppVersion}.0
VersionInfoProductName={#MyAppName}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} Setup

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut / 创建桌面快捷方式"; GroupDescription: "Additional icons / 附加图标:"; Flags: unchecked

[Files]
; 覆盖安装：ignoreversion 强制用新文件替换旧文件
Source: "{#MyAppSource}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; 仅清理安装目录残留；不删除用户笔记数据（AppData）
Type: filesandordirs; Name: "{app}\*.log"
