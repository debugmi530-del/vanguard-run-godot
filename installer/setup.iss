[Setup]
AppId={{B6E2B6B0-6E9A-4F62-9E9E-1D6E7B7D9A11}}
AppName=Vanguard Run
AppVersion=1.0.0
AppPublisher=Vanguard Run
DefaultDirName={autopf}\Vanguard Run
DefaultGroupName=Vanguard Run
OutputDir=Output
OutputBaseFilename=VanguardRun-Setup
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64
DisableProgramGroupPage=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "..\build\windows\VanguardRun.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Vanguard Run"; Filename: "{app}\VanguardRun.exe"
Name: "{autodesktop}\Vanguard Run"; Filename: "{app}\VanguardRun.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Run]
Filename: "{app}\VanguardRun.exe"; Description: "{cm:LaunchProgram,Vanguard Run}"; Flags: nowait postinstall skipifsilent
