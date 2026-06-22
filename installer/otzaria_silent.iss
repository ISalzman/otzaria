; מתקין שקט עבור אוצריא.
; המשתמש רק מפעיל את ה-EXE — הוא משגר את עצמו מחדש ב-/VERYSILENT ויוצא בשקט.
; אם התהליך רץ עם הרשאות מנהל (Run as administrator) — התקנה לכל המשתמשים;
; אחרת — התקנה למשתמש הנוכחי בלבד (ללא UAC, כי PrivilegesRequired=lowest).
; ההתקנה משמרת את ההגדרות הקודמות, וסיומה משיק את אוצריא אוטומטית.

#define MyAppName "אוצריא"
#define MyAppVersion "0.9.94"
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
; לוג אוטומטי ל-%TEMP% של המשתמש המריץ — חיוני לאבחון עדכונים שקטים שנכשלים בשטח.
SetupLogging=yes

[InstallDelete]
; ניקוי מסד הנתונים הישן של Isar שהוחלף על ידי hive_ce — מחיקה מכוונת בעת שדרוג.
Type: filesandordirs; Name: "{app}\default.isar";

[Dirs]
Name: "{code:GetDataDir}"; Permissions: users-modify
Name: "{code:GetDataDir}\books"; Permissions: users-modify
Name: "{code:GetDataDir}\index"; Permissions: users-modify

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; AppUserModelID: "Otzaria.Otzaria"

[Registry]
Root: HKA; Subkey: "Software\Classes\otzaria"; ValueType: string; ValueName: ""; ValueData: "URL:Otzaria Protocol"; Flags: uninsdeletekeyifempty
Root: HKA; Subkey: "Software\Classes\otzaria"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\otzaria\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName}"; Flags: uninsdeletekeyifempty
Root: HKA; Subkey: "Software\Classes\otzaria\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Flags: uninsdeletekeyifempty
; הוספת {app} ל-PATH של המשתמש — אוטומטית במתקין השקט (אין tasks אופציונליים).
; ה-Check מונע כפילויות בהתקנה חוזרת; ההסרה מהPATH ב-CurUninstallStepChanged.
Root: HKCU; Subkey: "Environment"; ValueType: expandsz; ValueName: "Path"; ValueData: "{olddata};{app}"; Flags: preservestringtype; Check: NeedsAddPath(ExpandConstant('{app}'))

[Run]
; אסור postinstall — רשומות postinstall תלויות בדף הסיום שלא מוצג ב-VERYSILENT,
; ולכן לא ירוצו לעולם. runasoriginaluser מונע הרצת אוצריא מורמת אחרי עדכון עם UAC.
; מדולג כאשר הועבר /NOLAUNCH=1 — מנגנון העדכון הפנימי מעביר אותו כשהעדכון
; מותקן בעת סגירת התוכנה, כדי שאוצריא לא תיפתח מחדש בניגוד לכוונת המשתמש.
Filename: "{app}\{#MyAppExeName}"; Flags: nowait runasoriginaluser; Check: ShouldLaunchAppAfterInstall

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
  // אם המשתמש בחר במהלך ההסרה למחוק גם את כל הנתונים והספרים, לא רק את
  // קבצי האפליקציה. ברירת המחדל False — נשמר כדי לא לאבד נתונים בעדכון
  // שקט (Inno Setup מריץ את ה-uninstaller הישן עם /SILENT).
  DeleteUserDataOnUninstall: Boolean;

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

function PathStartsWith(PathValue: String; Prefix: String): Boolean;
var
  NormalizedPath: String;
  NormalizedPrefix: String;
begin
  NormalizedPath := Lowercase(PathValue);
  if (NormalizedPath <> '') and (Copy(NormalizedPath, Length(NormalizedPath), 1) <> '\') then
    NormalizedPath := NormalizedPath + '\';

  NormalizedPrefix := Lowercase(Prefix);
  if (NormalizedPrefix <> '') and (Copy(NormalizedPrefix, Length(NormalizedPrefix), 1) <> '\') then
    NormalizedPrefix := NormalizedPrefix + '\';

  Result := Pos(NormalizedPrefix, NormalizedPath) = 1;
end;

// מזהה נתיבים מערכתיים שמחייבים UAC לשדרוג. זה נותן לנו לבקש הרשאות
// מראש עבור התקנות ישנות שנרשמו ב-HKCU אבל הותקנו בפועל תחת Program Files.
// הסיווג הוא לפי מיקום ידוע, לא לפי ניסיון כתיבה, כדי להימנע מ-false-positive
// בגלל AV / מנעולי קבצים / דיסק מלא.
function PathLikelyRequiresAdmin(PathDir: String): Boolean;
begin
  Result :=
    PathStartsWith(PathDir, ExpandConstant('{commonpf}')) or
    PathStartsWith(PathDir, ExpandConstant('{commonpf32}')) or
    PathStartsWith(PathDir, ExpandConstant('{commonpf64}'));
end;

// האם להפעיל את אוצריא בסיום ההתקנה (ראה הערה ב-[Run]).
function ShouldLaunchAppAfterInstall(): Boolean;
begin
  Result := ExpandConstant('{param:NOLAUNCH|0}') <> '1';
end;

// פרמטרים שיש להעביר הלאה כשהמתקין משגר את עצמו מחדש ב-InitializeSetup,
// כדי ש-/NOLAUNCH=1 לא יאבד במעבר לריצה השקטה/המורמת.
function PropagatedParams(): String;
begin
  Result := '';
  if ExpandConstant('{param:NOLAUNCH|0}') = '1' then
    Result := ' /NOLAUNCH=1';
end;

// Exec/ShellExec המובנות מסרבות להריץ את קובץ ה-Setup עצמו מתוך InitializeSetup;
// ייבוא ישיר של ה-API עוקף זאת, וכך ה-UAC מציג את מתקין אוצריא ולא את cmd.exe.
function ShellExecuteW(hwnd: HWND; lpOperation, lpFile, lpParameters,
  lpDirectory: String; nShowCmd: Integer): THandle;
  external 'ShellExecuteW@shell32.dll stdcall';

function RelaunchSetupElevated(Params: String; var ErrorCode: Integer): Boolean;
var
  InstanceHandle: THandle;
begin
  InstanceHandle :=
    ShellExecuteW(0, 'runas', ExpandConstant('{srcexe}'), Params, '', SW_HIDE);
  // ערך מעל 32 = הצלחה; אחרת זהו קוד שגיאת SE_ERR, נשמר לדיווח הכשל.
  Result := InstanceHandle > 32;
  if not Result then
    ErrorCode := InstanceHandle;
end;

// מחזירה את תיקיית ההתקנה הקודמת. RequiresAdmin נקבע לפי מקור הזיהוי
// ובמקרי HKCU גם לפי הנתיב בפועל, כדי לבקש UAC לפני כשל בכתיבה.
function FindPreviousInstallDir(var RequiresAdmin: Boolean): String;
var
  InstallDir: String;
  LegacyDir: String;
  UninstallKey: String;
begin
  RequiresAdmin := False;
  UninstallKey := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{EEC4F712-CD05-4D15-A753-509E840A51A5}_is1';

  // HKLM64 = התקנה מערכתית קודמת ⇒ דורשת מנהל לשדרוג.
  if TryGetInstallDirFromRegistry(HKLM64, UninstallKey, InstallDir) then
  begin
    Result := InstallDir;
    RequiresAdmin := True;
    exit;
  end;

  // בדרך כלל HKCU = התקנת משתמש. אם הנתיב בפועל תחת Program Files,
  // מבקשים UAC מראש כדי לא ליפול לכשל כתיבה מאוחר יותר.
  if TryGetInstallDirFromRegistry(HKCU, UninstallKey, InstallDir) then
  begin
    Result := InstallDir;
    RequiresAdmin := PathLikelyRequiresAdmin(InstallDir);
    exit;
  end;

  // C:\אוצריא = שורש דרייב מערכתי ⇒ יצירה/שכתוב דורשים מנהל.
  LegacyDir := 'C:\אוצריא';
  if DirExists(LegacyDir) then
  begin
    Result := LegacyDir;
    RequiresAdmin := True;
    exit;
  end;

  // {autopf} בריצת non-admin מתפענח ל-%LocalAppData%\Programs (נתיב משתמש).
  // בריצת admin זה Program Files, אבל אז IsAdmin=True ב-InitializeSetup
  // ולא נכנסים לענף ההסלמה ממילא — כך ש-RequiresAdmin נשאר False בבטחה.
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
var
  Dummy: Boolean;
begin
  Result := FindPreviousInstallDir(Dummy);
  if Result = '' then
    Result := ExpandConstant('{autopf}\Otzaria');
end;

function GetDataDir(Param: String): String;
begin
  if IsAdminInstallMode then
    Result := ExpandConstant('{commonappdata}\otzaria')
  else
    Result := ExpandConstant('{userappdata}\otzaria');
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
  RequiresAdmin: Boolean;
  PreviousDir: String;
begin
  Result := True;

  // אם המשתמש פתח את ה-EXE רגיל (לא דרך command-line שקט), משגרים את
  // עצמנו מחדש ב-/VERYSILENT. בריצה השנייה WizardSilent יהיה True
  // והקוד הזה לא ירוץ שוב.
  if not WizardSilent then
  begin
    PreviousDir := FindPreviousInstallDir(RequiresAdmin);

    if IsAdmin then
    begin
      PrivilegeFlag := '/ALLUSERS';
    end
    else if RequiresAdmin then
    begin
      // ההתקנה הקודמת בנתיב הדורש הרשאות מנהל. משגרים מחדש עם 'runas'
      // כדי לקבל UAC; המתקין המורם ירוץ עם /ALLUSERS.
      PrivilegeFlag := '/ALLUSERS';
      Launched := RelaunchSetupElevated(
        '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART ' + PrivilegeFlag +
        PropagatedParams(),
        ResultCode);

      if Launched then
      begin
        Result := False;
        exit;
      end;

      // אם גם השיגור המורם נכשל, המשתמש דחה את ה-UAC (ERROR_CANCELLED)
      // או שהייתה שגיאת מערכת. לא נופלים ל-/CURRENTUSER, כי ההתקנה
      // הייתה נכשלת בכתיבה לנתיב המוגן.
      MsgBox(
        'אוצריא הותקנה בעבר בנתיב הדורש הרשאות מנהל:' + #13#10 +
        PreviousDir + #13#10 + #13#10 +
        'כדי לשדרג, יש להפעיל את המתקין כמנהל' + #13#10 +
        '(קליק ימני על קובץ ההתקנה ↦ "Run as administrator").',
        mbError, MB_OK);
      Result := False;
      exit;
    end
    else
    begin
      PrivilegeFlag := '/CURRENTUSER';
    end;

    Launched := Exec(ExpandConstant('{srcexe}'),
         '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART ' + PrivilegeFlag +
         PropagatedParams(),
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
         '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART ' + PrivilegeFlag +
         PropagatedParams(),
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

// קריאת shared_preferences.json לקובץ טקסט אחד; משמש לחילוץ נתיב הספרים
// המותאם אישית של המשתמש לפני שמוחקים את ספריית הנתונים.
function UninstallReadTextFile(const FileName: String): String;
var
  Lines: TArrayOfString;
  i: Integer;
begin
  Result := '';
  if not LoadStringsFromFile(FileName, Lines) then
    exit;
  for i := 0 to GetArrayLength(Lines) - 1 do
  begin
    if i > 0 then
      Result := Result + #13#10;
    Result := Result + Lines[i];
  end;
end;

// מחזיר את נתיב תיקיית הספרים שהמשתמש בחר (אם שונה מברירת המחדל),
// כפי שנשמר ב-shared_preferences.json תחת המפתח flutter.key-library-path.
function GetCustomLibraryPath(): String;
var
  PrefsFile, JsonContent, KeyStr, Value: String;
  KeyPos, ValueStart, ValueEnd: Integer;
begin
  Result := '';
  PrefsFile := ExpandConstant('{userappdata}\otzaria\shared_preferences.json');
  if not FileExists(PrefsFile) then
    exit;

  JsonContent := UninstallReadTextFile(PrefsFile);
  if JsonContent = '' then
    exit;

  KeyStr := '"flutter.key-library-path":';
  KeyPos := Pos(KeyStr, JsonContent);
  if KeyPos = 0 then
  begin
    KeyStr := '"key-library-path":';
    KeyPos := Pos(KeyStr, JsonContent);
  end;
  if KeyPos = 0 then
    exit;

  ValueStart := KeyPos + Length(KeyStr);
  while (ValueStart <= Length(JsonContent)) and
        (JsonContent[ValueStart] <> '"') do
    ValueStart := ValueStart + 1;
  if ValueStart > Length(JsonContent) then
    exit;
  ValueStart := ValueStart + 1;

  ValueEnd := ValueStart;
  while ValueEnd <= Length(JsonContent) do
  begin
    if (JsonContent[ValueEnd] = '"') and (JsonContent[ValueEnd - 1] <> '\') then
      Break;
    ValueEnd := ValueEnd + 1;
  end;
  if ValueEnd > Length(JsonContent) then
    exit;

  Value := Copy(JsonContent, ValueStart, ValueEnd - ValueStart);
  StringChangeEx(Value, '\\', '\', True);
  StringChangeEx(Value, '\"', '"', True);
  Result := Value;
end;

// בודק שהתיקייה נראית כמו תיקיית ספרים של אוצריא — כלומר מכילה לפחות
// אחד מהסימנים הייחודיים שמותקנים ע"י המתקין FULL. נחוץ לפני DelTree על
// נתיב שמגיע מהמשתמש (prefs), כדי שלא נמחק תיקייה אישית רחבה שהמשתמש
// בחר בטעות כנתיב ספרים (למשל D:\, Downloads, Documents).
function IsOtzariaBooksFolder(const Path: String): Boolean;
begin
  Result := False;
  // אורך מינימלי 6 פוסל גם 'C:\' וגם 'C:\X'; מונע מחיקה בקרבת שורש כונן.
  if (Path = '') or (Length(Path) < 6) then
    exit;
  if not DirExists(Path) then
    exit;
  if FileExists(Path + '\seforim.db') or
     FileExists(Path + '\otzar-HB_catalog.db') or
     DirExists(Path + '\תלמוד בבלי') then
    Result := True;
end;

// מוחק את כל הנתונים והספרים של אוצריא: ספריית הספרים המותאמת אישית
// (רק אם היא מזוהה כתיקיית אוצריא — ראה IsOtzariaBooksFolder), כל תיקיות
// הנתונים הסטנדרטיות וגם נתיבי legacy. קוראים את הנתיב המותאם מה-prefs
// לפני שמוחקים את ה-prefs עצמו.
procedure DeleteAllUserData();
var
  Path: String;
begin
  Path := GetCustomLibraryPath();
  if IsOtzariaBooksFolder(Path) then
    DelTree(Path, True, True, True);

  Path := ExpandConstant('{commonappdata}\otzaria');
  if DirExists(Path) then
    DelTree(Path, True, True, True);

  Path := ExpandConstant('{userappdata}\otzaria');
  if DirExists(Path) then
    DelTree(Path, True, True, True);

  Path := ExpandConstant('{localappdata}\otzaria');
  if DirExists(Path) then
    DelTree(Path, True, True, True);

  // נתיבים ישנים: מזהה חבילה לפני שינוי (com.example) ושמות עבריים.
  Path := ExpandConstant('{userappdata}\com.example');
  if DirExists(Path) then
    DelTree(Path, True, True, True);

  Path := ExpandConstant('{localappdata}\אוצריא');
  if DirExists(Path) then
    DelTree(Path, True, True, True);

  // הערה: C:\אוצריא לא נמחק כאן כי זה היה נתיב התקנה legacy (לא נתונים).
  // אם נשארה שם התקנה ישנה — היא תוסר על ידי ה-uninstaller שלה.
end;

// שאלה בתחילת ההסרה: האם למחוק גם את הנתונים והספרים?
// בהסרה שקטה (כולל עדכון שמריץ unins000.exe /SILENT) MsgBox מחזיר אוטומטית
// את ברירת המחדל; MB_DEFBUTTON2 דואג שברירת המחדל היא "לא" כך שנתוני
// המשתמש נשמרים אם הוא לא בחר במפורש למחוק.
function InitializeUninstall(): Boolean;
var
  CustomPath, Msg: String;
begin
  Result := True;
  DeleteUserDataOnUninstall := False;

  CustomPath := GetCustomLibraryPath();

  Msg := 'האם למחוק גם את הספרים וכל הנתונים של אוצריא?' + #13#10 + #13#10 +
         'בכל מקרה תוסר התוכנה. בחירה ב"כן" תמחק בנוסף:' + #13#10;

  // אם יש נתיב ספרים מותאם והוא מזוהה כתיקיית אוצריא — נציג אותו במפורש.
  // אחרת לא מציינים נתיב חיצוני; תיקיית הספרים שתחת AppData ממילא נמחקת
  // כחלק מ-{userappdata}\otzaria / {commonappdata}\otzaria.
  if IsOtzariaBooksFolder(CustomPath) then
    Msg := Msg + '• תיקיית הספרים:' + #13#10 +
                 '   ' + CustomPath + #13#10
  else
    Msg := Msg + '• תיקיית הספרים שתחת תיקיית הנתונים' + #13#10;

  Msg := Msg +
         '• מסדי הנתונים, אינדקס החיפוש, הגדרות,' + #13#10 +
         '   סימניות, היסטוריה והערות אישיות' + #13#10 + #13#10 +
         'בחר "לא" כדי לשמור את הנתונים לקראת התקנה עתידית.';

  if MsgBox(Msg, mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES then
  begin
    if MsgBox(
         'שים לב: לא ניתן יהיה לשחזר את הנתונים לאחר המחיקה.' + #13#10 + #13#10 +
         'האם אתה בטוח שברצונך למחוק את כל הספרים והנתונים?',
         mbCriticalError, MB_YESNO or MB_DEFBUTTON2) = IDYES then
      DeleteUserDataOnUninstall := True;
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
  begin
    RemoveAppFromUserPath(ExpandConstant('{app}'));
    if DeleteUserDataOnUninstall then
      DeleteAllUserData();
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ErrorLogPath: string;
begin
  if CurStep = ssInstall then
  begin
    // מחק את לוג השגיאות הישן בכל התקנה/עדכון.
    // הערה: זו אינה הגדרת משתמש — זה לוג מצטבר שמתנקה בכל עדכון.
    // המתקין השקט אינו מאפס הגדרות אחרות (הערות, בוקמרקים, היסטוריה וכו').
    ErrorLogPath := ExpandConstant('{userappdata}\otzaria\logs\errors.txt');
    if FileExists(ErrorLogPath) then
      DeleteFile(ErrorLogPath);
    ErrorLogPath := ExpandConstant('{commonappdata}\otzaria\logs\errors.txt');
    if FileExists(ErrorLogPath) then
      DeleteFile(ErrorLogPath);
  end;
end;
