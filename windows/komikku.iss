; Inno Setup script. Compile after windows/build.sh:
;   ISCC.exe /DAppVersion=<version> windows\komikku.iss
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppId={{8E1B7C54-5D3A-4F0E-9B67-2A4C1D9E7F30}
AppName=Komikku
AppVersion={#AppVersion}
AppPublisher=Komikku (unofficial Windows build)
DefaultDirName={autopf}\Komikku
DefaultGroupName=Komikku
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\_winbuild
OutputBaseFilename=Komikku-{#AppVersion}-windows-x64-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayName=Komikku
LicenseFile=..\_winbuild\Komikku\LICENSES\GPL-3.0-or-later.txt

[Files]
Source: "..\_winbuild\Komikku\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{autoprograms}\Komikku"; Filename: "{sys}\wscript.exe"; Parameters: """{app}\Komikku.vbs"""; WorkingDir: "{app}"; IconFilename: "{app}\komikku.ico"
Name: "{autodesktop}\Komikku"; Filename: "{sys}\wscript.exe"; Parameters: """{app}\Komikku.vbs"""; WorkingDir: "{app}"; IconFilename: "{app}\komikku.ico"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked

[Run]
Filename: "{sys}\wscript.exe"; Parameters: """{app}\Komikku.vbs"""; WorkingDir: "{app}"; Description: "Launch Komikku"; Flags: nowait postinstall skipifsilent
