; מתקין שקט עבור אוצריא.
; המשתמש רק מפעיל את ה-EXE — הוא משגר את עצמו מחדש ב-/VERYSILENT ויוצא בשקט.
; אם התהליך רץ עם הרשאות מנהל (Run as administrator) — התקנה לכל המשתמשים;
; אחרת — התקנה למשתמש הנוכחי בלבד (ללא UAC, כי PrivilegesRequired=lowest).
; ההתקנה תמיד מאפסת את ההגדרות הקודמות, וסיומה משיק את אוצריא אוטומטית.

#define MyAppName "אוצריא"
#define MyAppVersion "0.9.92"
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
; ChangesEnvironment=yes נדרש כדי שעדכון ה-PATH (registration אוטומטית של
; otzaria pack-plugin) ייכנס לתוקף מיד עבור תהליכים חדשים ללא logoff.
ChangesEnvironment=yes

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
; הוספת {app} ל-PATH של המשתמש — אוטומטית במתקין השקט (אין tasks אופציונליים).
; ה-Check מונע כפילויות בהתקנה חוזרת; ההסרה מהPATH ב-CurUninstallStepChanged.
Root: HKCU; Subkey: "Environment"; ValueType: expandsz; ValueName: "Path"; ValueData: "{olddata};{app}"; Flags: preservestringtype; Check: NeedsAddPath(ExpandConstant('{app}'))

[Run]
; הפעלת התוכנה בסוף ההתקנה — גם במצב שקט (אין skipifsilent).
Filename: "{app}\{#MyAppExeName}"; Flags: nowait postinstall

[Languages]
Name: "hebrew"; MessagesFile: "compiler:Languages\Hebrew.isl"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; צילומי מסך להצגה בדף ההתקנה (במקרה שהמתקין מציג ממשק — ראה InitializeSlideshow)
Source: "feature1.bmp"; Flags: dontcopy
Source: "feature2.bmp"; Flags: dontcopy
Source: "feature3.bmp"; Flags: dontcopy
Source: "feature4.bmp"; Flags: dontcopy

[INI]
Filename: "{app}\system_install.marker"; Section: "Install"; Key: "Mode"; String: "Admin"; Check: IsAdminInstallMode

[Code]
var
  SlideshowImage: TBitmapImage;
  SlideshowTimerId: LongWord;
  SlideshowTimerCallback: LongWord;
  SlideshowIndex: Integer;

// TTimer לא זמין ב-Pascal Script של Inno Setup; נשתמש ב-Windows API.
function SetTimer(hWnd, nIDEvent, uElapse, lpTimerFunc: LongWord): LongWord;
  external 'SetTimer@user32.dll stdcall';
function KillTimer(hWnd, nIDEvent: LongWord): LongWord;
  external 'KillTimer@user32.dll stdcall';

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

procedure OnSlideshowTimer(H: LongWord; Msg: LongWord; IdEvent: LongWord; Time: LongWord);
var
  NextFile: String;
begin
  if SlideshowImage = nil then
    exit;
  SlideshowIndex := (SlideshowIndex + 1) mod 4;
  case SlideshowIndex of
    0: NextFile := 'feature1.bmp';
    1: NextFile := 'feature2.bmp';
    2: NextFile := 'feature3.bmp';
    3: NextFile := 'feature4.bmp';
  end;
  SlideshowImage.Bitmap.LoadFromFile(ExpandConstant('{tmp}\') + NextFile);
end;

procedure InitializeSlideshow;
var
  GaugeBottom, AvailH, ImgH: Integer;
begin
  if WizardForm = nil then
    exit;
  SlideshowIndex := 0;
  ExtractTemporaryFile('feature1.bmp');
  ExtractTemporaryFile('feature2.bmp');
  ExtractTemporaryFile('feature3.bmp');
  ExtractTemporaryFile('feature4.bmp');
  GaugeBottom := WizardForm.ProgressGauge.Top + WizardForm.ProgressGauge.Height;
  AvailH := WizardForm.InstallingPage.Height - GaugeBottom;
  if AvailH < ScaleY(60) then
    exit;
  ImgH := AvailH - ScaleY(10);
  SlideshowImage := TBitmapImage.Create(WizardForm.InstallingPage);
  SlideshowImage.Parent := WizardForm.InstallingPage;
  SlideshowImage.Stretch := True;
  SlideshowImage.Left := 0;
  SlideshowImage.Top := GaugeBottom + ScaleY(8);
  SlideshowImage.Width := WizardForm.InstallingPage.Width;
  SlideshowImage.Height := ImgH;
  SlideshowImage.Bitmap.LoadFromFile(ExpandConstant('{tmp}\feature1.bmp'));
  SlideshowTimerCallback := CreateCallback(@OnSlideshowTimer);
end;

procedure InitializeWizard;
begin
  InitializeSlideshow;
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if SlideshowTimerCallback = 0 then
    exit;
  if CurPageID = wpInstalling then
  begin
    if SlideshowTimerId = 0 then
      SlideshowTimerId := SetTimer(0, 0, 1500, SlideshowTimerCallback);
  end
  else if SlideshowTimerId <> 0 then
  begin
    KillTimer(0, SlideshowTimerId);
    SlideshowTimerId := 0;
  end;
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

// בודק האם הנתיב NewPath כבר נמצא ב-PATH של המשתמש. מחזיר True אם
// יש להוסיף (לא קיים). מטפל גם בגרסה עם backslash סופי. case-insensitive
// כי Windows מתייחס ל-PATH ככזה.
function NeedsAddPath(NewPath: String): Boolean;
var
  CurrentPath: String;
  Needle1, Needle2, Haystack: String;
begin
  Result := True;
  if not RegQueryStringValue(HKCU, 'Environment', 'Path', CurrentPath) then
    exit;

  Haystack  := ';' + Lowercase(CurrentPath) + ';';
  Needle1   := ';' + Lowercase(NewPath) + ';';
  Needle2   := ';' + Lowercase(NewPath) + '\;';
  if (Pos(Needle1, Haystack) > 0) or (Pos(Needle2, Haystack) > 0) then
    Result := False;
end;

// מסיר את PathToRemove מ-PATH של המשתמש (ב-uninstall). מטפל בשני
// הוריאנטים — עם וללא backslash סופי — **בנפרד**, כדי שכפילות
// היסטורית (גם 'C:\app' וגם 'C:\app\') תוסר במלואה. גם מסיר כל
// מופע חוזר.
procedure RemoveAppFromUserPath(PathToRemove: String);
var
  CurrentPath, LowerCurrent: String;
  Needles: array[0..1] of String;
  LowerNeedle: String;
  P, i: Integer;
  Changed: Boolean;
begin
  if not RegQueryStringValue(HKCU, 'Environment', 'Path', CurrentPath) then
    exit;

  Changed := False;
  CurrentPath := ';' + CurrentPath + ';';

  Needles[0] := ';' + Lowercase(PathToRemove) + ';';
  Needles[1] := ';' + Lowercase(PathToRemove) + '\;';

  for i := 0 to 1 do
  begin
    LowerNeedle := Needles[i];
    LowerCurrent := Lowercase(CurrentPath);
    P := Pos(LowerNeedle, LowerCurrent);
    while P > 0 do
    begin
      Delete(CurrentPath, P, Length(LowerNeedle) - 1);
      LowerCurrent := Lowercase(CurrentPath);
      Changed := True;
      P := Pos(LowerNeedle, LowerCurrent);
    end;
  end;

  if not Changed then
    exit;

  if (Length(CurrentPath) > 0) and (CurrentPath[1] = ';') then
    Delete(CurrentPath, 1, 1);
  if (Length(CurrentPath) > 0) and (CurrentPath[Length(CurrentPath)] = ';') then
    Delete(CurrentPath, Length(CurrentPath), 1);

  RegWriteExpandStringValue(HKCU, 'Environment', 'Path', CurrentPath);
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
    RemoveAppFromUserPath(ExpandConstant('{app}'));
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
