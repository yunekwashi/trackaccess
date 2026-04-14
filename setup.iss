    ; Inno Setup Script for TrackAccess
; Generated for Flutter Windows App

[Setup]
AppName=TrackAccess
AppVersion=1.0.0
DefaultDirName={autopf}\TrackAccess
DefaultGroupName=TrackAccess
OutputBaseFilename=TrackAccessInstaller
Compression=lzma
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Main Executable
Source: "build\windows\x64\runner\Release\trackaccess.exe"; DestDir: "{app}"; Flags: ignoreversion
; DLL Dependencies
Source: "build\windows\x64\runner\Release\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\sqlite3.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\serialport.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\flutter_libserialport_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\sqlite3_flutter_libs_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
; Data Folder (Assets/ICU data)
Source: "build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\TrackAccess"; Filename: "{app}\trackaccess.exe"
Name: "{commondesktop}\TrackAccess"; Filename: "{app}\trackaccess.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\trackaccess.exe"; Description: "{cm:LaunchProgram,TrackAccess}"; Flags: nowait postinstall skipifsilent
  