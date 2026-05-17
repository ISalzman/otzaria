; מתקין שקט עבור אוצריא.
; המשתמש רק מפעיל את ה-EXE — הוא משגר את עצמו מחדש ב-/VERYSILENT ויוצא בשקט.
; אם התהליך רץ עם הרשאות מנהל (Run as administrator) — התקנה לכל המשתמשים;
; אחרת — התקנה למשתמש הנוכחי בלבד (ללא UAC, כי PrivilegesRequired=lowest).
; ההתקנה תמיד מאפסת את ההגדרות הקודמות, וסיומה משיק את אוצריא אוטומטית.

#define MyAppName "אוצריא"
#define MyAppVersion "0.9.91"
#define MyAppPublisher "sivan22"
#define MyAppURL "https://github.com/otzaria/otzaria"
#define MyAppExeName "otzaria.exe"

[Setup]
AppId={{EEC4F712-CD05-4D15-A753-509E840A51A5}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; lowest = לא מבקש UAC כשמפעילים רגיל; אם המשתמש בחר "Run as administrator"
; התהליך כבר מורם, IsAdmin=True, ואז משגרים מחדש עם /ALLUSERS.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=commandline
DefaultDirName={code:GetDefaultInstallDir}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=.\
OutputBaseFilename=otzaria-{#MyAppVersion}-windows-silent
SetupIconFile=white_sketch128x128.ico
Compression=lzma
SolidCompression=yes
; Disable compression for DLL files to prevent corruption
CompressionThreads=1
WizardStyle=modern
DisableDirPage=yes
DisableReadyPage=yes
DisableFinishedPage=yes
DisableWelcomePage=yes

[InstallDelete]
; ניקוי מסד הנתונים הישן של Isar שהוחלף על ידי hive_ce — מחיקה מכוונת בעת שדרוג.
Type: filesandordirs; Name: "{app}\default.isar";

[Dirs]
Name: "{code:GetDataDir}"; Permissions: users-modify
Name: "{code:GetDataDir}\books"; Permissions: users-modify
Name: "{code:GetDataDir}\index"; Permissions: users-modify

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"

[Registry]
Root: HKA; Subkey: "Software\Classes\otzaria"; ValueType: string; ValueName: ""; ValueData: "URL:Otzaria Protocol"; Flags: uninsdeletekeyifempty
Root: HKA; Subkey: "Software\Classes\otzaria"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\otzaria\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName}"; Flags: uninsdeletekeyifempty
Root: HKA; Subkey: "Software\Classes\otzaria\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Flags: uninsdeletekeyifempty

[Run]
; הפעלת התוכנה בסוף ההתקנה — גם במצב שקט (אין skipifsilent).
Filename: "{app}\{#MyAppExeName}"; Flags: nowait postinstall

[Languages]
Name: "hebrew"; MessagesFile: "compiler:Languages\Hebrew.isl"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[INI]
Filename: "{app}\system_install.marker"; Section: "Install"; Key: "Mode"; String: "Admin"; Check: IsAdminInstallMode

[Code]
function TryGetInstallDirFromRegistry(RootKey: Integer; const SubKey: String; var InstallDir: String): Boolean;
begin
  Result := RegQueryStringValue(RootKey, SubKey, 'Inno Setup: App Path', InstallDir);
  if (not Result) or (InstallDir = '') then
    Result := RegQueryStringValue(RootKey, SubKey, 'InstallLocation', InstallDir);

  if Result and DirExists(InstallDir) then
    exit;

  InstallDir := '';
  Result := False;
end;

function FindPreviousInstallDir(): String;
var
  InstallDir: String;
  LegacyDir: String;
  UninstallKey: String;
begin
  UninstallKey := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{EEC4F712-CD05-4D15-A753-509E840A51A5}_is1';

  if TryGetInstallDirFromRegistry(HKLM64, UninstallKey, InstallDir) or
     TryGetInstallDirFromRegistry(HKCU, UninstallKey, InstallDir) then
  begin
    Result := InstallDir;
    exit;
  end;

  LegacyDir := 'C:\אוצריא';
  if DirExists(LegacyDir) then
  begin
    Result := LegacyDir;
    exit;
  end;

  LegacyDir := ExpandConstant('{autopf}\אוצריא');
  if DirExists(LegacyDir) then
  begin
    Result := LegacyDir;
    exit;
  end;

  LegacyDir := ExpandConstant('{autopf}\Otzaria');
  if DirExists(LegacyDir) then
  begin
    Result := LegacyDir;
    exit;
  end;

  Result := '';
end;

function GetDefaultInstallDir(Param: String): String;
begin
  Result := FindPreviousInstallDir();
  if Result = '' then
    Result := ExpandConstant('{autopf}\אוצריא');
end;

function GetDataDir(Param: String): String;
begin
  if IsAdminInstallMode then
    Result := ExpandConstant('{commonappdata}\otzaria')
  else
    Result := ExpandConstant('{userappdata}\otzaria');
end;

procedure DelTreeExceptBooks(Path: String);
var
  FindRec: TFindRec;
  ChildPath: String;
begin
  if not DirExists(Path) then
    exit;

  if FindFirst(Path + '\*', FindRec) then
  begin
    try
      repeat
        if (FindRec.Name <> '.') and (FindRec.Name <> '..') then
        begin
          ChildPath := Path + '\' + FindRec.Name;

          if (FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0 then
          begin
            if Lowercase(FindRec.Name) <> 'books' then
            begin
              DelTreeExceptBooks(ChildPath);
              RemoveDir(ChildPath);
            end;
          end
          else
            DeleteFile(ChildPath);
        end;
      until not FindNext(FindRec);
    finally
      FindClose(FindRec);
    end;
  end;

  RemoveDir(Path);
end;

function InitializeSetup(): Boolean;
var
  ResultCode: Integer;
  PrivilegeFlag: String;
  Launched: Boolean;
begin
  Result := True;

  // אם המשתמש פתח את ה-EXE רגיל (לא דרך command-line שקט), משגרים את
  // עצמנו מחדש ב-/VERYSILENT. בריצה השנייה WizardSilent יהיה True
  // והקוד הזה לא ירוץ שוב.
  if not WizardSilent then
  begin
    if IsAdmin then
      PrivilegeFlag := '/ALLUSERS'
    else
      PrivilegeFlag := '/CURRENTUSER';

    Launched := Exec(ExpandConstant('{srcexe}'),
         '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART ' + PrivilegeFlag,
         '', SW_HIDE, ewNoWait, ResultCode);

    if Launched then
    begin
      // השיגור הצליח — יוצאים מהריצה הנוכחית בשקט (Result := False
      // יוצא ללא הודעת ביטול), והעותק השקט ימשיך מכאן.
      Result := False;
      exit;
    end;

    // ניסיון fallback ב-ShellExec — לפעמים CreateProcess נכשל בגלל
    // אנטי-וירוס/מנעולי קובץ אבל ShellExecute (דרך ה-shell) עובר.
    Launched := ShellExec('open', ExpandConstant('{srcexe}'),
         '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART ' + PrivilegeFlag,
         '', SW_HIDE, ewNoWait, ResultCode);

    if Launched then
    begin
      Result := False;
      exit;
    end;

    // השיגור מחדש נכשל לחלוטין — אל תיצא בשקט (אחרת המשתמש מקבל
    // no-op בלי שום פידבק). ממשיכים את ההתקנה בתהליך הנוכחי
    // (Result נשאר True). כל עמודי האשף מנוטרלים, אז המשתמש יראה
    // רק את חלון ההתקדמות עד לסיום — לא אידיאלי, אבל לא כשל שקט.
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  AppDataPath: string;
  ErrorLogPath: string;
begin
  if CurStep = ssInstall then
  begin
    // מחק את לוג השגיאות הישן בכל התקנה/עדכון
    ErrorLogPath := ExpandConstant('{userappdata}\otzaria\logs\errors.txt');
    if FileExists(ErrorLogPath) then
      DeleteFile(ErrorLogPath);
    ErrorLogPath := ExpandConstant('{commonappdata}\otzaria\logs\errors.txt');
    if FileExists(ErrorLogPath) then
      DeleteFile(ErrorLogPath);

    // המתקין השקט תמיד מאפס את כל ההגדרות הקודמות — בלי משימה אופציונלית.
    AppDataPath := GetDataDir('');
    if DirExists(AppDataPath) then
      DelTreeExceptBooks(AppDataPath);

    AppDataPath := ExpandConstant('{userappdata}\otzaria');
    if DirExists(AppDataPath) then
      DelTreeExceptBooks(AppDataPath);

    AppDataPath := ExpandConstant('{commonappdata}\otzaria');
    if DirExists(AppDataPath) then
      DelTreeExceptBooks(AppDataPath);

    AppDataPath := ExpandConstant('{localappdata}\otzaria');
    if DirExists(AppDataPath) then
      DelTreeExceptBooks(AppDataPath);

    // הגדרות והערות אישיות ישנות (com.example)
    AppDataPath := ExpandConstant('{userappdata}\com.example');
    if DirExists(AppDataPath) then
      DelTreeExceptBooks(AppDataPath);
  end;
end;
