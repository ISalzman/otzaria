#include "flutter_window.h"

#include <dwmapi.h>

#include <algorithm>
#include <atomic>
#include <chrono>
#include <limits>
#include <mutex>
#include <optional>
#include <string>
#include <thread>

#include <cstdlib>

// ספייק P-2 בלבד — נדרשים ל-`RegisterPluginsMasked`. בקוד היצור רק
// `generated_plugin_registrant.h` נכלל.
#include <file_selector_windows/file_selector_windows.h>
#include <flutter_inappwebview_windows/flutter_inappwebview_windows_plugin_c_api.h>
#include <irondash_engine_context/irondash_engine_context_plugin_c_api.h>
#include <printing/printing_plugin.h>
#include <screen_retriever_windows/screen_retriever_windows_plugin_c_api.h>
// ⚠️ `sentry_flutter_plugin.h` מגדיר את ה-registrar inline, ולכן הכללתו
// כאן **וגם** ב-generated_plugin_registrant.cc יוצרת LNK2005. הוא ממילא
// stub ריק ב-Windows (כפי שהמסמך קובע), ולכן הוא מדולג במסכה.
#include <super_native_extensions/super_native_extensions_plugin_c_api.h>
#include <url_launcher_windows/url_launcher_windows.h>
#include <window_manager/window_manager_plugin.h>
#include <zstandard_windows/zstandard_windows_plugin_c_api.h>

#include "flutter/generated_plugin_registrant.h"
#include "jump_list_manager.h"
#include "splash_window.h"
#include "utils.h"

namespace {

// ── דיאגנוסטיקה של סיום סשן (כיבוי / יציאת משתמש) ────────────────────────
//
// כותבת ל-`%TEMP%\otzaria_session_end.log`. המסלול הזה אינו ניתן לבדיקה
// אוטומטית — מריצים אותו רק כיבוי אמיתי — ולכן שורת לוג היא האמצעי היחיד
// לאבחון תלונה עתידית של "הכרטיסיות שלי לא נשמרו בכיבוי". השורות:
//
//   flush-begin / flush-ok / flush-timeout   מצב השטיפה
//   session-ending / session-cancelled       מה המערכת החליטה בסוף
//   swallowed-by-flutter                     גלאי רגרסיה, ראו MessageHandler
//
// כותבת גם ל-OutputDebugStringW, לניפוי חי ב-DebugView.
void LogSessionEndDiagnostic(const wchar_t* stage, UINT message, WPARAM wparam,
                             LPARAM lparam) {
  wchar_t buffer[200];
  _snwprintf_s(buffer, _TRUNCATE,
               L"Otzaria[session-end] %ls msg=%ls wparam=%llu lparam=0x%llX\n", stage,
               message == WM_QUERYENDSESSION ? L"WM_QUERYENDSESSION"
                                             : L"WM_ENDSESSION",
               static_cast<unsigned long long>(wparam),
               static_cast<unsigned long long>(lparam));
  OutputDebugStringW(buffer);

  // גם לקובץ, ולא רק ל-OutputDebugStringW: קריאת הפלט של OutputDebugString
  // מחייבת DebugView שרץ כמנהל, ומשתמש שמדווח על תקלה לא יעשה זאת. הדפוס
  // זהה ל-`_logForceTerminateFailure` שכותב ל-%TEMP%.
  //
  // ⚠️ פתיחה וסגירה בכל שורה, ולא handle מתמשך: הקוד הזה רץ בזמן כיבוי,
  // ובאפר שלא נשטף לפני שהמערכת הורגת אותנו הופך את הלוג לחסר ערך בדיוק
  // במקרה שבגללו הוא קיים.
  wchar_t temp_path[MAX_PATH];
  const DWORD temp_len = GetTempPathW(MAX_PATH, temp_path);
  if (temp_len == 0 || temp_len > MAX_PATH) {
    return;
  }
  std::wstring log_path(temp_path);
  log_path += L"otzaria_session_end.log";

  const HANDLE file =
      CreateFileW(log_path.c_str(), FILE_APPEND_DATA, FILE_SHARE_READ, nullptr,
                  OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (file == INVALID_HANDLE_VALUE) {
    return;
  }
  const std::string utf8 = Utf8FromUtf16(buffer);
  DWORD written = 0;
  WriteFile(file, utf8.data(), static_cast<DWORD>(utf8.size()), &written,
            nullptr);
  CloseHandle(file);
}

// כמה זמן מחכים ל-Dart לפני שמוותרים ומאשרים את סיום הסשן. Windows נותן
// לאפליקציה מספר שניות להשיב ל-WM_QUERYENDSESSION לפני שהיא מסומנת כלא-
// מגיבה ומוצגת למשתמש כמעכבת כיבוי. שלוש שניות מספיקות לשטיפת Hive וקצרות
// דיין שלא ייראו כתקיעה.
constexpr DWORD kSessionEndFlushTimeoutMs = 3000;

// חלון-ההודעות של תור המשימות של Flutter, אם הוא שייך ל-thread הזה.
//
// `TaskRunnerWindow` מפרסם `WM_NULL` ומשתמש ב-`SetTimer` כדי להריץ את תורי
// המשימות של המנוע, ולכן שאיבה **ממנו בלבד** מריצה את ה-Dart בלי לגעת
// בהודעות של חלונות אחרים. `HWND_MESSAGE` מחזיר חלונות של כל התהליכים,
// ולכן חובה לאמת גם תהליך וגם thread.
//
// שם המחלקה הוא פרט פנימי של המנוע ועלול להשתנות בשדרוג. כשלא נמצא —
// נופלים לשאיבה לפי **סוג הודעה** (posted/timer בלבד), שגם היא חוסמת קלט
// ו-WM_PAINT מלהיכנס re-entrantly.
HWND FindFlutterTaskRunnerWindow() {
  const DWORD our_pid = GetCurrentProcessId();
  const DWORD our_tid = GetCurrentThreadId();
  HWND hwnd = nullptr;
  while ((hwnd = FindWindowExW(HWND_MESSAGE, hwnd, L"FlutterTaskRunnerWindow",
                               nullptr)) != nullptr) {
    DWORD pid = 0;
    const DWORD tid = GetWindowThreadProcessId(hwnd, &pid);
    if (pid == our_pid && tid == our_tid) {
      return hwnd;
    }
  }
  return nullptr;
}

// מפעיל/מבטל DWM cloaking: החלון נשאר "מוצג" מבחינת המערכת (WS_VISIBLE,
// מיקסום, פוקוס והצגת פריימים עובדים כרגיל) אבל ה-DWM לא מצייר אותו כלל.
// ביטול ה-cloak הוא אטומי — פריים קומפוזיציה אחד עם התוכן העדכני.
void SetWindowCloaked(HWND hwnd, bool cloaked) {
  if (!hwnd) {
    return;
  }
  BOOL value = cloaked ? TRUE : FALSE;
  DwmSetWindowAttribute(hwnd, DWMWA_CLOAK, &value, sizeof(value));
}

// מגדיר את מגבלות ה-Job ומשייך אליו את התהליך. מחזיר true בהצלחה; במקרה
// כשל ממלא |failure| וסוגר את ה-handle.
bool ConfigureProcessJob(HANDLE job, std::string& failure) {
  // BREAKAWAY_OK: ילד שנוצר עם CREATE_BREAKAWAY_FROM_JOB מתנתק מה-Job
  // ושורד את סגירת אוצריא (מתקין העדכון); ילדים רגילים (WebView2) נשארים
  // מוכלים ונהרגים בסגירה כרצוי.
  JOBOBJECT_EXTENDED_LIMIT_INFORMATION info{};
  info.BasicLimitInformation.LimitFlags =
      JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE | JOB_OBJECT_LIMIT_BREAKAWAY_OK;
  if (!SetInformationJobObject(job, JobObjectExtendedLimitInformation, &info,
                               sizeof(info))) {
    failure = "SetInformationJobObject failed (error " +
              std::to_string(GetLastError()) + ")";
    OutputDebugStringW(L"Otzaria: SetInformationJobObject failed; not "
                       L"honouring forceTerminate.\n");
    CloseHandle(job);
    return false;
  }
  if (!AssignProcessToJobObject(job, GetCurrentProcess())) {
    failure = "AssignProcessToJobObject failed (error " +
              std::to_string(GetLastError()) +
              "); likely already in a non-nestable job";
    // The most common failure mode: the launching environment (debugger,
    // sandbox, AppContainer, certain enterprise/MDM tooling) has already
    // placed our process in a non-nestable job. We have no way to break
    // out, so we discard the job we created and stay on the graceful
    // close path — forceTerminate will report not-ready and Dart will
    // fall back to windowManager.destroy() + exit(0).
    OutputDebugStringW(L"Otzaria: AssignProcessToJobObject failed; likely "
                       L"already in a non-nestable job. Falling back to "
                       L"graceful shutdown on close.\n");
    CloseHandle(job);
    return false;
  }
  return true;
}

// הודעה פרטית שמבקשת מה-thread של החלון לפתוח חלון אוצריא נוסף **על
// עצמו**. ראו `CreateSecondaryWindowOnThisThread`.
constexpr UINT kMsgOpenSecondaryWindow = WM_APP + 0x101;

// החלונות המשניים שנוצרו על ה-thread הזה. `FlutterWindow` חייב לחיות כל
// עוד החלון שלו קיים, ולכן הבעלות נשמרת כאן ולא במחסנית.
std::vector<std::unique_ptr<FlutterWindow>>& SecondaryWindowsOnThisThread() {
  static thread_local std::vector<std::unique_ptr<FlutterWindow>> windows;
  return windows;
}

// יוצר חלון אוצריא נוסף **על ה-thread הקורא**, ומשתמש בלולאת ההודעות
// הקיימת שלו.
//
// ⚠️ ה-thread אינו שרירותי. ניסיון ליצור את המנוע על thread ייעודי חדש
// קרס באופן עקבי ברגע שהחלון הראשון כבר רץ:
//
//   "Isolate main is already scheduled on mutator thread ...,
//    failed to schedule from os thread ..."   isolate=(nil)
//
// הכשל אינו תלוי בתוספים (נבדק בלי `RegisterPlugins` כלל) ולא ב-
// `RustLib.init` — כלומר הוא ביצירת המנוע עצמה. זהו גם מה שעושה
// `desktop_multi_window`, מימוש ההתייחסות: כל המנועים על ה-thread הראשי.
//
// המחיר ידוע ומדוד: ה-platform thread וה-UI thread ממוזגים ב-3.47, ולכן
// כל המנועים חולקים scheduler אחד — חלון עסוק מקפיא את השני
// (docs/P-0-stage3-result.md §2). זה חוב פתוח, לא פתרון סופי.
void CreateSecondaryWindowOnThisThread(const flutter::DartProject& base,
                                       const std::string& payload) {
  // ניקוי חלונות שנסגרו, כדי שהרשימה לא תגדל בלי גבול.
  auto& windows = SecondaryWindowsOnThisThread();
  windows.erase(
      std::remove_if(windows.begin(), windows.end(),
                     [](const std::unique_ptr<FlutterWindow>& w) {
                       return w == nullptr || w->GetHandle() == nullptr;
                     }),
      windows.end());

  flutter::DartProject project(base);
  project.set_dart_entrypoint("secondaryWindowMain");
  project.set_dart_entrypoint_arguments({payload});

  char no_plugins[8] = {};
  const bool skip_plugins =
      ::GetEnvironmentVariableA("OTZARIA_SECONDARY_NO_PLUGINS", no_plugins,
                                sizeof(no_plugins)) > 0;

  auto window = std::make_unique<FlutterWindow>(project, /*headless=*/false,
                                                skip_plugins);
  static int spawn_index = 0;
  const int offset = 40 + (spawn_index++ % 6) * 32;
  Win32Window::Point origin(offset, offset);
  Win32Window::Size size(1100, 760);
  if (!window->Create(L"אוצריא", origin, size)) {
    return;
  }
  // ⚠️ `false` במפורש: סגירת חלון משני אסור לה לפרסם `WM_QUIT` ל-thread
  // הראשי — זה היה סוגר את כל האפליקציה.
  window->SetQuitOnClose(false);
  ::ShowWindow(window->GetHandle(), SW_SHOW);
  windows.push_back(std::move(window));
}


}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project, bool headless,
                             bool skip_plugins)
    : project_(project), headless_(headless), skip_plugins_(skip_plugins) {
  // Create a Job Object early — before any child processes can spawn. We
  // assign our own process to it with JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
  // so that *any* child process created from this point onward (WebView2's
  // msedgewebview2.exe browser/GPU/renderer/utility processes, in particular)
  // is automatically terminated when the job is closed — which happens
  // when this process dies, including via TerminateProcess.
  //
  // The Job Object is the standard Win32 mechanism for containing process
  // trees; without it, WebView2's Edge child processes have been observed
  // orphaning after fast-exit shutdown (13 zombie msedgewebview2.exe
  // instances persisting for days, holding the user data folder locked and
  // breaking subsequent WebView2 initialization with a silent blank-tab
  // failure).
  //
  // ⚠️ ה-Job שייך ל**תהליך**, לא לחלון. במודל A יש `FlutterWindow` לכל
  // חלון, וגרסה קודמת יצרה Job לכל אחד וסגרה אותו בדסטרקטור. עם
  // `KILL_ON_JOB_CLOSE` והתהליך שלנו כחבר, סגירת ה-handle כשחלון **משני**
  // נסגר מורה לגרעין להרוג את כל חברי ה-Job — כלומר אותנו. נמדד: הדסטרקטור
  // של החלון המשני נכנס ל-`~FlutterWindow` ולעולם אינו חוזר
  // (docs/P-2-two-windows.md §9). לכן: נוצר פעם אחת, ואינו נסגר לעולם —
  // סגירת ה-handle בעת יציאת התהליך היא בדיוק הרגע שבו KILL_ON_JOB_CLOSE
  // אמור לפעול.
  static std::once_flag job_once;
  static HANDLE process_job = nullptr;
  static std::string process_job_failure;

  std::call_once(job_once, [&]() {
    process_job = CreateJobObjectW(nullptr, nullptr);
    if (!process_job) {
      process_job_failure = "CreateJobObjectW failed (error " +
                            std::to_string(GetLastError()) + ")";
      OutputDebugStringW(L"Otzaria: CreateJobObjectW failed; Edge child "
                         L"processes will not be contained on fast-exit.\n");
      return;
    }
    if (!ConfigureProcessJob(process_job, process_job_failure)) {
      process_job = nullptr;
    }
  });

  job_handle_ = process_job;
  job_object_failure_ = process_job_failure;
  job_object_ready_.store(process_job != nullptr &&
                          process_job_failure.empty());
  return;
}

FlutterWindow::~FlutterWindow() {
  // ⚠️ ה-Job **אינו** נסגר כאן. הוא משאב של התהליך, ולא של החלון: סגירתו
  // מפעילה `KILL_ON_JOB_CLOSE` על כל החברים, והתהליך שלנו הוא אחד מהם.
  // כשחלון משני נסגר, זה פירושו הריגה עצמית. ראו ההערה בקונסטרוקטור.
  // יציאת התהליך סוגרת את ה-handle ממילא — וזה בדיוק העיתוי הנכון.
  job_handle_ = nullptr;
  if (session_end_flush_event_) {
    CloseHandle(session_end_flush_event_);
    session_end_flush_event_ = nullptr;
  }
}

namespace {

// האם כבר נרשמו תוספים למנוע כלשהו בתהליך. במודל A יש מנוע לכל חלון,
// והחלון הראשון מקבל את מסלול היצור המלא בעוד הנוספים מקבלים תת-קבוצה.
std::atomic<bool> g_first_engine_registered{false};

// מסכת כל התוספים ב-`RegisterPluginsMasked`, וביט ה-`printing` בתוכה.
constexpr unsigned long kAllPluginsMask = 0x3FF;  // עשרה תוספים
constexpr unsigned long kPrintingPluginBit = 1UL << 3;

// מונע מ-`flutter_inappwebview_windows` לבטל רישום של מחלקות חלון שחלונות
// אחרים עדיין צריכים.
//
// הבעיה: `InAppWebViewManager` רושם את המחלקה `CustomPlatformView`
// בקונסטרוקטור ומבטל אותה בדסטרקטור **ללא תנאי וללא מונה הפניות**
// (in_app_webview_manager.cpp:259), ואותו דפוס חוזר עבור
// `HeadlessInAppWebView` (headless_in_app_webview_manager.cpp:145). עם מנוע
// לכל חלון נוצר manager לכל חלון: הרישום השני נכשל בשקט (ערך ההחזרה
// מתעלם), וסגירת חלון אחד מסירה את המחלקה מתחת לרגליו של האחר. התוצאה
// היא WebView שבור עד סוף הריצה — ורק כשאין חלון פתוח מאותה מחלקה, ולכן
// בדיקה תמימה של "פתח WebView בחלון שני" תעבור ותחמיץ אותה.
//
// התיקון: מחזיקים חלון message-only יחיד מכל מחלקה לכל אורך חיי התהליך.
// `UnregisterClass` נכשל כל עוד קיים חלון מהמחלקה, ולכן ביטול הרישום של
// התוסף הופך ל-no-op. אומת ב-`--check2`: בלי חלון שומר ביטול הרישום
// מצליח והמחלקה נעלמת; עם חלון שומר הוא נכשל והמחלקה שורדת.
//
// נדרש **אחרי** `RegisterPlugins`, כי המחלקה חייבת להיות רשומה כדי שאפשר
// יהיה ליצור ממנה חלון.
void KeepWebViewWindowClassesAlive() {
  static std::once_flag once;
  std::call_once(once, []() {
    static const wchar_t* kClasses[] = {L"CustomPlatformView",
                                        L"HeadlessInAppWebView"};
    for (const wchar_t* cls : kClasses) {
      // המחלקה נרשמת על ידי ה-DLL של התוסף, ולכן ה-hInstance שלה אינו
      // בהכרח שלנו. מנסים את שתי האפשרויות ומדווחים.
      HWND keeper = ::CreateWindowExW(0, cls, L"", 0, 0, 0, 0, 0, HWND_MESSAGE,
                                      nullptr, nullptr, nullptr);
      if (!keeper) {
        keeper = ::CreateWindowExW(0, cls, L"", 0, 0, 0, 0, 0, HWND_MESSAGE,
                                   nullptr, ::GetModuleHandle(nullptr),
                                   nullptr);
      }
      if (keeper) {
        // דולף בכוונה: אורך החיים הוא אורך חיי התהליך.
        printf("[webview-class-keeper] %ls ok\n", cls);
      } else {
        printf("[webview-class-keeper] %ls FAILED err=%lu\n", cls,
               ::GetLastError());
      }
    }
    fflush(stdout);
  });
}

// ספייק P-2 בלבד. רושם תת-קבוצה של התוספים לפי מסכת ביטים, בסדר של
// `generated_plugin_registrant.cc`. משמש לחיפוש בינארי אחר התוסף ששובר
// שני חלונות על שני threads.
void RegisterPluginsMasked(flutter::PluginRegistry* registry,
                           unsigned long mask) {
  struct Entry {
    const char* name;
    void (*fn)(FlutterDesktopPluginRegistrarRef);
  };
  static const Entry kEntries[] = {
      {"FileSelectorWindows", FileSelectorWindowsRegisterWithRegistrar},
      {"FlutterInappwebviewWindowsPluginCApi",
       FlutterInappwebviewWindowsPluginCApiRegisterWithRegistrar},
      {"IrondashEngineContextPluginCApi",
       IrondashEngineContextPluginCApiRegisterWithRegistrar},
      {"PrintingPlugin", PrintingPluginRegisterWithRegistrar},
      {"ScreenRetrieverWindowsPluginCApi",
       ScreenRetrieverWindowsPluginCApiRegisterWithRegistrar},
      {"SentryFlutterPlugin", nullptr},  // stub ריק — ראו ההערה בהכללות
      {"SuperNativeExtensionsPluginCApi",
       SuperNativeExtensionsPluginCApiRegisterWithRegistrar},
      {"UrlLauncherWindows", UrlLauncherWindowsRegisterWithRegistrar},
      {"WindowManagerPlugin", WindowManagerPluginRegisterWithRegistrar},
      {"ZstandardWindowsPluginCApi",
       ZstandardWindowsPluginCApiRegisterWithRegistrar},
  };
  for (size_t i = 0; i < sizeof(kEntries) / sizeof(kEntries[0]); ++i) {
    if ((mask & (1UL << i)) && kEntries[i].fn != nullptr) {
      kEntries[i].fn(registry->GetRegistrarForPlugin(kEntries[i].name));
      printf("[plugin] registered %s\n", kEntries[i].name);
    }
  }
  fflush(stdout);
}

}  // namespace

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  // ספייק P-2 בדיקה 1: בלי תוספים ובלי ערוצי runner, כדי לבודד את מקור
  // הכשל בשני חלונות. ראו docs/P-2-two-windows.md.
  if (skip_plugins_) {
    return true;
  }
  // ספייק P-2: `OTZARIA_SPIKE_PLUGIN_MASK` רושם תת-קבוצה של התוספים,
  // ביט לכל אחד לפי הסדר ב-generated_plugin_registrant.cc. קיים כדי
  // לאתר בחיפוש בינארי איזה תוסף שובר שני חלונות.
  // ⚠️ רישום התוספים מסוריאלי בין חלונות.
  //
  // רבים מה-registrar-ים כותבים למצב process-global (`printing_plugin.cpp:35`
  // הוא הדוגמה המובהקת, אך לא היחידה). כששני חלונות נוצרים על שני threads
  // בו-זמנית, שתי הכתיבות מתערבבות והתוצאה שנמדדה היא קריסה בשיעור ~1%:
  // "Isolate main is owned by os thread X, failed to schedule from os
  // thread Y" — thread אחד שמנסה להריץ Dart של ה-isolate של האחר.
  // ראו docs/P-2-two-windows.md §3.
  static std::mutex plugin_registration_mutex;
  std::lock_guard<std::mutex> plugin_registration_lock(
      plugin_registration_mutex);

  char mask_env[32] = {};
  if (::GetEnvironmentVariableA("OTZARIA_SPIKE_PLUGIN_MASK", mask_env,
                                sizeof(mask_env)) > 0) {
    RegisterPluginsMasked(flutter_controller_->engine(),
                          std::strtoul(mask_env, nullptr, 0));
  } else if (!g_first_engine_registered.exchange(true)) {
    // החלון הראשון עובר במסלול היצור המדויק, ללא שינוי.
    RegisterPlugins(flutter_controller_->engine());
  } else {
    // ⚠️ חלון נוסף — `printing` מדולג.
    //
    // `printing_plugin.cpp:35` מחזיק `std::unique_ptr<MethodChannel> channel`
    // יחיד ב-**namespace scope**, ומשייך אליו מחדש בכל `RegisterWithRegistrar`
    // (:41). `printing.cpp:24` מכריז עליו `extern` ושולח דרכו את כל
    // הקולבקים — `onLayout` (:102) ועוד שלושה (:43, :66, :137). עם מנוע לכל
    // חלון, רישום המנוע השני דורס את הערוץ, וכל קולבק הדפסה — גם של החלון
    // הראשון — מנותב ל-isolate שנרשם אחרון. התוצאה: הדפסה שנתקעת בשקט.
    //
    // עד שההדפסה תנותב ל-host (פרק 3), עדיף שהדפסה מחלון משני תיכשל מיד
    // מאשר שתשבור את החלון הראשון.
    RegisterPluginsMasked(flutter_controller_->engine(),
                          kAllPluginsMask & ~kPrintingPluginBit);
  }
  KeepWebViewWindowClassesAlive();
  // ── ריבוי חלונות ──
  // Dart קורא `openWindow` עם מטען JSON (בדרך כלל טאב מסוריאל), וה-runner
  // פותח חלון נוסף על thread ייעודי. המטען עובר כארגומנט לנקודת הכניסה
  // `secondaryWindowMain`, ולא דרך ערוץ — החלון החדש עוד לא קיים בזמן
  // הקריאה, ואין למי לשלוח.
  multiwindow_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "otzaria/multiwindow",
          &flutter::StandardMethodCodec::GetInstance());
  multiwindow_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() != "openWindow") {
          result->NotImplemented();
          return;
        }
        std::string payload;
        if (const auto* value = std::get_if<std::string>(call.arguments())) {
          payload = *value;
        }
        // ⚠️ הבקשה מתפרסמת ל-thread של החלון ואינה מבוצעת כאן ישירות.
        // הקריאה מגיעה מתוך טיפול בערוץ, כלומר מתוך ריצת ה-Dart של החלון
        // הזה; יצירת מנוע נוסף באמצע היא ריאנטרנטית. `PostMessage` דוחה
        // אותה לאיטרציה הבאה של לולאת ההודעות, כשה-isolate כבר לא בתוך
        // הקריאה.
        pending_secondary_payloads_.push(payload);
        ::PostMessageW(GetHandle(), kMsgOpenSecondaryWindow, 0, 0);
        result->Success();
      });

  // כלי בידוד זמני: פותח חלון שני אוטומטית אחרי N אלפיות, כדי שאפשר יהיה
  // לשחזר את קריסת הפתיחה בלי אינטראקציה ידנית.
  char auto_ms[16] = {};
  if (::GetEnvironmentVariableA("OTZARIA_AUTO_SECOND_WINDOW_MS", auto_ms,
                                sizeof(auto_ms)) > 0) {
    const unsigned long delay = std::strtoul(auto_ms, nullptr, 10);
    const HWND self = GetHandle();
    std::thread([self, delay]() {
      ::Sleep(delay);
      ::PostMessageW(self, kMsgOpenSecondaryWindow, 0, 0);
    }).detach();
  }

  process_control_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "otzaria/process_control",
          &flutter::StandardMethodCodec::GetInstance());
  process_control_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "jobObjectStatus") {
          flutter::EncodableMap status;
          status[flutter::EncodableValue("ready")] =
              flutter::EncodableValue(job_object_ready_.load());
          status[flutter::EncodableValue("failure")] =
              job_object_failure_.empty()
                  ? flutter::EncodableValue()
                  : flutter::EncodableValue(job_object_failure_);
          result->Success(flutter::EncodableValue(status));
          return;
        }
        if (call.method_name() == "forceTerminate") {
          // Only honour forceTerminate when the Job Object containment is
          // verifiably in place. Without it, TerminateProcess would still
          // skip atexit / DLL_PROCESS_DETACH / Dart VM teardown — but it
          // would also orphan every msedgewebview2.exe child process the
          // user has spawned, which is the exact pathology we're trying
          // to avoid. Returning false here lets the Dart caller fall back
          // to the existing graceful close path (windowManager.destroy +
          // exit(0)), trading shutdown speed for child-process cleanup.
          if (!job_object_ready_.load()) {
            OutputDebugStringW(L"Otzaria: forceTerminate refused — Job "
                               L"Object not ready. Falling back to "
                               L"graceful close.\n");
            result->Success(flutter::EncodableValue(false));
            return;
          }
          // Instant process kill — skips C runtime atexit handlers (notably
          // sentry-native's pending-event flush, which adds several seconds
          // on plain exit(0) paths), DLL_PROCESS_DETACH, static destructors,
          // and Dart VM isolate teardown. The Job Object created in our
          // ctor guarantees that WebView2 Edge child processes die with us.
          //
          // Hive (write-through with per-record checksums) and SQLite in WAL
          // mode survive this kind of dirty shutdown by design; the existing
          // window_listener.dart shutdown sequence already flushes any
          // remaining in-memory state before calling us.
          TerminateProcess(GetCurrentProcess(), 0);
          // Unreachable in practice.
          result->Success(flutter::EncodableValue(true));
          return;
        }
        if (call.method_name() == "sessionEndFlushDone") {
          // ה-Dart סיים לשטוף. משחררים את ההמתנה ב-FlushBeforeSessionEnd,
          // שרצה כרגע על ה-thread הזה ושואבת הודעות — ולכן הקריאה הזו
          // בכלל הגיעה אלינו.
          if (session_end_flush_event_) {
            SetEvent(session_end_flush_event_);
          }
          result->Success();
          return;
        }
        if (call.method_name() != "armForceExitWatchdog") {
          result->NotImplemented();
          return;
        }

        uint32_t timeout_ms = 15000;
        if (const auto* arguments =
                std::get_if<flutter::EncodableMap>(call.arguments())) {
          auto timeout_it = arguments->find(flutter::EncodableValue("timeoutMs"));
          if (timeout_it != arguments->end()) {
            if (const auto* timeout_value =
                    std::get_if<int32_t>(&timeout_it->second)) {
              if (*timeout_value > 0) {
                timeout_ms = static_cast<uint32_t>(*timeout_value);
              }
            } else if (const auto* timeout_value64 =
                           std::get_if<int64_t>(&timeout_it->second)) {
              if (*timeout_value64 > 0 &&
                  *timeout_value64 <
                      static_cast<int64_t>(std::numeric_limits<uint32_t>::max())) {
                timeout_ms = static_cast<uint32_t>(*timeout_value64);
              }
            }
          }
        }

        timeout_ms = std::clamp<uint32_t>(timeout_ms, 5000, 60000);
        ArmForceExitWatchdog(timeout_ms);
        result->Success(flutter::EncodableValue(true));
      });

  // Channel for closing the native floating-icon splash window (created in
  // main.cpp before the engine started). Dart invokes "close" when it reveals
  // the main window, so the splash icon disappears exactly as the main window
  // appears with content.
  splash_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "otzaria/splash",
          &flutter::StandardMethodCodec::GetInstance());
  splash_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "cloak") {
          // הצד של Dart קורא לזה לפני windowManager.show() בחשיפה הראשונה:
          // החלון יוצג, ימוקסם ויקבל פוקוס בעודו בלתי-נראה, וכל שינויי הגודל
          // (שזורקים את ה-swapchain ומשאירים חלון שקוף עד לפריים הבא)
          // מתרחשים מאחורי הקלעים. החשיפה בפועל היא ביטול ה-cloak ב-"close".
          SetWindowCloaked(GetHandle(), true);
          result->Success();
          return;
        }
        if (call.method_name() == "close") {
          // Defer the actual reveal until the engine *presents* the next
          // frame (raster output reaching the swapchain) — by then the
          // window is at its final size/state (Dart sends "close" after
          // show/maximize/fullscreen). Uncloaking on that callback makes the
          // reveal atomic: one DWM composition with the final content, and
          // the splash icon's fade-out starts at that exact moment. The Dart
          // side can only observe UI-thread frame completion (endOfFrame),
          // never the actual present — hence the native callback.
          // ForceRedraw guarantees a frame is produced even if the previous
          // one was already presented before the callback was registered.
          if (flutter_controller_ && flutter_controller_->engine()) {
            HWND hwnd = GetHandle();
            flutter_controller_->engine()->SetNextFrameCallback([hwnd]() {
              SetWindowCloaked(hwnd, false);
              splash::Close();
            });
            flutter_controller_->ForceRedraw();
          } else {
            SetWindowCloaked(GetHandle(), false);
            splash::Close();
          }
          result->Success();
          return;
        }
        result->NotImplemented();
      });

  // ערוץ עדכון ה-Jump List: Dart שולח "updateTabs" עם רשימת כותרות הטאבים.
  // ה-handler רץ על ה-UI thread (אותו STA שאיתחל COM ב-main.cpp), כנדרש
  // ל-ICustomDestinationList.
  jumplist_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "otzaria/jumplist",
          &flutter::StandardMethodCodec::GetInstance());
  jumplist_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        if (call.method_name() != "updateTabs") {
          result->NotImplemented();
          return;
        }

        std::vector<std::string> titles;
        if (const auto* arguments =
                std::get_if<flutter::EncodableMap>(call.arguments())) {
          auto titles_it =
              arguments->find(flutter::EncodableValue("titles"));
          if (titles_it != arguments->end()) {
            if (const auto* list =
                    std::get_if<flutter::EncodableList>(&titles_it->second)) {
              for (const auto& entry : *list) {
                if (const auto* title = std::get_if<std::string>(&entry)) {
                  titles.push_back(*title);
                }
              }
            }
          }
        }

        result->Success(
            flutter::EncodableValue(jump_list::UpdateOpenTabs(titles)));
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // NOTE: the main window is intentionally NOT shown here. It stays hidden
  // until Dart reveals it (window_manager.show in presentMainWindow) once the
  // active tab's content is ready — so it appears directly at its final
  // size/position with content already painted, with no resize, no jump, and
  // no blank gap. The native splash window (see main.cpp) provides the visible
  // floating icon meanwhile. ForceRedraw drives the engine to render frames
  // into the (hidden) window surface, so content is ready when Dart shows it.
  if (!headless_) {
    flutter_controller_->ForceRedraw();
  }
  // In headless mode the window stays invisible — CLI commands are expected
  // to invoke exit() from Dart before any UI work happens.

  return true;
}

void FlutterWindow::OnDestroy() {
  // NOTE: do NOT close the splash here. Win32Window::Create() calls Destroy()
  // (→ OnDestroy()) at its very start to clear any prior state — even on the
  // first creation, before any window exists — so OnDestroy fires spuriously
  // during window.Create(), which would close the splash prematurely (long
  // before the main window is revealed). The splash is closed via the
  // "otzaria/splash" channel when Dart reveals the main window (or its 8s
  // failsafe). On process exit the OS tears down the splash thread/window.
  splash_channel_.reset();
  multiwindow_channel_.reset();
  jumplist_channel_.reset();
  process_control_channel_.reset();
  if (flutter_controller_) {
    // ⚠️ הריסת המנוע קורית **בתוך** ה-window proc של WM_DESTROY. נמדד
    // שהריסת שני מנועים במקביל, משני threads, ננעלת — ולכן סגירת חלונות
    // חייבת להיות מסוריאלית. ראו docs/P-2-two-windows.md §9.
    flutter_controller_.reset();
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // נפתח לפני שמעבירים ל-Flutter: זו הודעה פרטית שלנו, ואין לתוספים מה
  // לעשות איתה.
  if (message == kMsgOpenSecondaryWindow) {
    std::string payload;
    if (!pending_secondary_payloads_.empty()) {
      payload = pending_secondary_payloads_.front();
      pending_secondary_payloads_.pop();
    }
    CreateSecondaryWindowOnThisThread(project_, payload);
    return 0;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      // גלאי רגרסיה: היום `window_manager` אינו בולע את הודעות סיום הסשן
      // (נמדד), ולכן ה-flush שלנו רץ. אם שדרוג של המנוע או של התוסף ישנה
      // זאת, השטיפה תפסיק לקרות **בשקט** — והשורה הזו תהיה הרמז היחיד.
      if (message == WM_QUERYENDSESSION || message == WM_ENDSESSION) {
        LogSessionEndDiagnostic(L"swallowed-by-flutter", message, wparam,
                                lparam);
      }
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      if (flutter_controller_ && flutter_controller_->engine()) {
        flutter_controller_->engine()->ReloadSystemFonts();
      }
      break;

    case WM_QUERYENDSESSION: {
      // ⚠️ ה-flush חייב לרוץ **כאן**, לפני ההחזרה. החזרת TRUE היא הבטחה
      // מחייבת: מרגע שנתנו אותה המערכת רשאית להרוג אותנו בכל רגע, ולכן
      // שטיפה מאוחרת ב-WM_ENDSESSION אינה מובטחת לרוץ. נמדד: לפני השינוי
      // הזה `DefWindowProc` כבר החזיר TRUE.
      LogSessionEndDiagnostic(L"flush-begin", message, wparam, lparam);
      const bool flushed = FlushBeforeSessionEnd();
      LogSessionEndDiagnostic(flushed ? L"flush-ok" : L"flush-timeout", message,
                              wparam, lparam);
      // תמיד מסכימים לסיום. עיכוב הכיבוי דורש ShutdownBlockReasonCreate,
      // שמציג למשתמש שאנחנו מעכבים — החלטת UX שלא התקבלה.
      return TRUE;
    }

    case WM_ENDSESSION:
      if (wparam == FALSE) {
        // בוטל (למשל `shutdown /a`). מאפסים כדי שכיבוי עתידי ישטוף מחדש
        // את מה שנכתב בינתיים — בלי זה שטיפה אחת מחסנת את כל שאר הסשן.
        LogSessionEndDiagnostic(L"session-cancelled", message, wparam, lparam);
        if (session_end_flush_event_) {
          ResetEvent(session_end_flush_event_);
        }
        if (process_control_channel_) {
          process_control_channel_->InvokeMethod("sessionEndCancelled",
                                                 nullptr);
        }
      } else {
        LogSessionEndDiagnostic(L"session-ending", message, wparam, lparam);
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

bool FlutterWindow::FlushBeforeSessionEnd() {
  if (!process_control_channel_ || !flutter_controller_) {
    return false;
  }

  if (!session_end_flush_event_) {
    // manual-reset: הסימון נשאר דלוק גם אם ההודעה תגיע שוב.
    session_end_flush_event_ = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    if (!session_end_flush_event_) {
      return false;
    }
  }
  if (WaitForSingleObject(session_end_flush_event_, 0) == WAIT_OBJECT_0) {
    // כבר נשטף בהודעה קודמת — WM_QUERYENDSESSION מגיע לא פעם יותר מפעם אחת.
    return true;
  }

  process_control_channel_->InvokeMethod("prepareForSessionEnd", nullptr);

  const HWND task_runner = FindFlutterTaskRunnerWindow();
  const ULONGLONG deadline = GetTickCount64() + kSessionEndFlushTimeoutMs;
  while (true) {
    const ULONGLONG now = GetTickCount64();
    if (now >= deadline) {
      break;
    }
    // QS_POSTMESSAGE|QS_TIMER בלבד: אלה הערוצים שבהם תור המשימות של Flutter
    // מתעורר. מסכה רחבה יותר הייתה מעירה אותנו על כל תזוזת עכבר וגורמת
    // ללולאה עמוסה שסתם שורפת את שלוש השניות.
    const DWORD wait = MsgWaitForMultipleObjects(
        1, &session_end_flush_event_, FALSE,
        static_cast<DWORD>(deadline - now), QS_POSTMESSAGE | QS_TIMER);
    if (wait == WAIT_OBJECT_0) {
      return true;
    }
    if (wait != WAIT_OBJECT_0 + 1) {
      break;  // WAIT_TIMEOUT או כשל
    }

    MSG msg;
    if (task_runner != nullptr) {
      while (PeekMessageW(&msg, task_runner, 0, 0, PM_REMOVE)) {
        DispatchMessageW(&msg);
      }
    } else {
      // נפילה חזרה: אותו סוג הודעות, בלי הגבלה לחלון מסוים.
      while (PeekMessageW(&msg, nullptr, 0, 0,
                          PM_REMOVE | PM_QS_POSTMESSAGE | PM_QS_SENDMESSAGE)) {
        DispatchMessageW(&msg);
      }
    }
  }

  return WaitForSingleObject(session_end_flush_event_, 0) == WAIT_OBJECT_0;
}

void FlutterWindow::ArmForceExitWatchdog(uint32_t timeout_ms) {
  bool expected = false;
  if (!force_exit_watchdog_armed_.compare_exchange_strong(expected, true)) {
    return;
  }

  std::thread([timeout_ms]() {
    std::this_thread::sleep_for(std::chrono::milliseconds(timeout_ms));
    OutputDebugStringW(
        L"Otzaria force-exit watchdog expired; terminating process.\n");
    TerminateProcess(GetCurrentProcess(), 0);
  }).detach();
}
