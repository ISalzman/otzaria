#include <flutter/flutter_engine.h>
#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <initguid.h>
#include <knownfolders.h>
#include <shlobj.h>
#include <windows.h>

#include <chrono>
#include <iomanip>
#include <sstream>
#include <string>
#include <thread>
#include <vector>

#include "flutter_window.h"
#include "splash_window.h"
#include "utils.h"

static const wchar_t* kSingleInstanceMutexName = L"OtzariaAppSingleInstance";
static const wchar_t* kFlutterWindowClassName = L"FLUTTER_RUNNER_WIN32_WINDOW";
static const wchar_t* kMainWindowTitle = L"אוצריא";

// Escapes a UTF-8 string for safe embedding inside a JSON string value.
static std::string JsonEscape(const std::string& s) {
  std::string out;
  out.reserve(s.size());
  for (unsigned char c : s) {
    switch (c) {
      case '"':  out += "\\\""; break;
      case '\\': out += "\\\\"; break;
      case '\b': out += "\\b";  break;
      case '\f': out += "\\f";  break;
      case '\n': out += "\\n";  break;
      case '\r': out += "\\r";  break;
      case '\t': out += "\\t";  break;
      default:
        if (c < 0x20) {
          char buf[8];
          snprintf(buf, sizeof(buf), "\\u%04x", c);
          out += buf;
        } else {
          out += static_cast<char>(c);
        }
    }
  }
  return out;
}

// Percent-encodes a UTF-8 string for safe use as a URL query component.
// Reserves unreserved chars (RFC 3986): A-Z a-z 0-9 - _ . ~
static std::string UrlEncodeQueryComponent(const std::string& s) {
  std::string out;
  out.reserve(s.size() * 3);
  for (unsigned char c : s) {
    const bool unreserved =
        (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
        (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.' || c == '~';
    if (unreserved) {
      out += static_cast<char>(c);
    } else {
      char buf[4];
      snprintf(buf, sizeof(buf), "%%%02X", c);
      out += buf;
    }
  }
  return out;
}

// Case-insensitive ASCII string equality.
static bool EqualsIgnoreCase(const std::string& a, const std::string& b) {
  if (a.size() != b.size()) return false;
  for (size_t i = 0; i < a.size(); ++i) {
    char ca = a[i];
    char cb = b[i];
    if (ca >= 'A' && ca <= 'Z') ca = static_cast<char>(ca - 'A' + 'a');
    if (cb >= 'A' && cb <= 'Z') cb = static_cast<char>(cb - 'A' + 'a');
    if (ca != cb) return false;
  }
  return true;
}

// Returns true when the command-line indicates a CLI sub-command that must
// run without a visible window and without the single-instance guard
// (e.g. `otzaria.exe pack-plugin <path>`). Strips a leading `--` / `/` and
// underscores so `--pack-plugin` and `pack_plugin` are also accepted.
//
// `info` prints a JSON report to stdout: it must skip the single-instance
// guard so it works while the GUI is running, and must never raise or show a
// window — the caller is another program reading our stdout.
//
// Note: |args| is the list returned by GetCommandLineArguments(), which
// already strips argv[0]. The first user-supplied argument is therefore at
// index 0.
static bool IsCliInvocation(const std::vector<std::string>& args) {
  if (args.empty()) return false;
  std::string cmd = args[0];
  while (!cmd.empty() && (cmd.front() == '-' || cmd.front() == '/')) {
    cmd.erase(cmd.begin());
  }
  for (auto& c : cmd) {
    if (c == '_') c = '-';
  }
  return EqualsIgnoreCase(cmd, "pack-plugin") || EqualsIgnoreCase(cmd, "info");
}

// Case-insensitive check whether `s` ends with `suffix` (ASCII only).
static bool EndsWithIgnoreCase(const std::string& s, const std::string& suffix) {
  if (s.size() < suffix.size()) return false;
  for (size_t i = 0; i < suffix.size(); ++i) {
    char a = s[s.size() - suffix.size() + i];
    char b = suffix[i];
    if (a >= 'A' && a <= 'Z') a = static_cast<char>(a - 'A' + 'a');
    if (b >= 'A' && b <= 'Z') b = static_cast<char>(b - 'A' + 'a');
    if (a != b) return false;
  }
  return true;
}

// Appends a URI string to the external-activation queue file so the already-
// running instance can pick it up.
// Path mirrors AppPaths.getDataRootPath() on Windows: %APPDATA%\otzaria
static void EnqueueUri(const std::string& uri_utf8) {
  // Use SHGetKnownFolderPath (Vista+) instead of the deprecated
  // SHGetFolderPathW / CSIDL_APPDATA.
  wchar_t* app_data_raw = nullptr;
  if (FAILED(SHGetKnownFolderPath(FOLDERID_RoamingAppData, KF_FLAG_DEFAULT,
                                   nullptr, &app_data_raw))) {
    return;
  }
  std::wstring app_data(app_data_raw);
  CoTaskMemFree(app_data_raw);

  std::wstring dir = app_data + L"\\otzaria";
  std::wstring queue_path =
      dir + L"\\pending_external_activations.jsonl";

  // Ensure the parent directory exists.
  CreateDirectoryW(dir.c_str(), nullptr);

  // Build ISO-8601 timestamp (UTC).
  auto now = std::chrono::system_clock::now();
  std::time_t tt = std::chrono::system_clock::to_time_t(now);
  struct tm utc {};
  gmtime_s(&utc, &tt);
  std::ostringstream ts;
  ts << std::put_time(&utc, "%Y-%m-%dT%H:%M:%SZ");

  std::string record =
      "{\"uri\":\"" + JsonEscape(uri_utf8) + "\",\"createdAt\":\"" +
      ts.str() + "\"}";

  // Append as a single JSONL line (UTF-8).
  HANDLE fh = CreateFileW(queue_path.c_str(), FILE_APPEND_DATA,
                          FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr,
                          OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (fh != INVALID_HANDLE_VALUE) {
    std::string line = record + "\n";
    DWORD written = 0;
    WriteFile(fh, line.c_str(), static_cast<DWORD>(line.size()), &written,
              nullptr);
    CloseHandle(fh);
  }
}

// Restores a minimized window and brings it to the foreground.
static void BringWindowToFront(HWND hwnd) {
  if (hwnd == nullptr) return;
  if (IsIconic(hwnd)) {
    ShowWindow(hwnd, SW_RESTORE);
  }
  SetForegroundWindow(hwnd);
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t* command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // CLI sub-commands (e.g. `pack-plugin`) must skip the single-instance check
  // so they work even when the GUI is already running, and must not raise the
  // existing GUI window. The Dart entrypoint will call exit() before any UI
  // is rendered.
  std::vector<std::string> early_args = GetCommandLineArguments();
  const bool is_cli_invocation = IsCliInvocation(early_args);

  // ── ספייק P-0 בלבד. אינו מיועד ל-main. ────────────────────────────────
  //
  // `--window-role=secondary` עוקף את בדיקת המופע היחיד, כדי שאפשר יהיה
  // להריץ שני תהליכי אוצריא במקביל ולמדוד מה קורה. זו השאלה שכל מפת
  // הדרכים תלויה בה: האם מודל ריבוי-תהליכים בכלל אפשרי.
  //
  // ⚠️ הרצת שני מופעים על **אותה ספרייה** היא הרסנית: סנטינל האינדקס של
  // Tantivy מוחק את האינדקס אחרי כשלי פתיחה רצופים, ו-`journal_mode=DELETE`
  // אינו מגן על כתיבות מקבילות. להדגמה בטוחה משגרים את המופע השני עם
  // `APPDATA` מופנה לתיקייה זמנית — ואז ההגדרות, ה-Hive והספרייה שלו
  // נפרדים לחלוטין (ראו `app_paths.dart:112`).
  const bool is_secondary_window_role = [&early_args]() {
    for (const auto& arg : early_args) {
      if (EqualsIgnoreCase(arg, "--window-role=secondary")) return true;
    }
    return false;
  }();

  // `--role=broker` — ספייק P-0 שלב 2. גם הוא עוקף את המופע היחיד: broker
  // אמור לרוץ לצד חלון UI, לא במקומו.
  const bool is_broker_role = [&early_args]() {
    for (const auto& arg : early_args) {
      if (EqualsIgnoreCase(arg, "--role=broker")) return true;
    }
    return false;
  }();

  // Single-instance check: must happen before the Flutter engine starts so
  // that the second instance never acquires any shared resources (DB, etc.).
  // bInitialOwner = FALSE: we don't need ownership, just existence of the object.
  // If CreateMutexW fails (returns NULL), treat as first instance so the app
  // can still start rather than being permanently blocked.
  HANDLE mutex = (is_cli_invocation || is_secondary_window_role || is_broker_role)
                     ? nullptr
                     : CreateMutexW(nullptr, FALSE, kSingleInstanceMutexName);
  bool is_second_instance =
      (mutex != nullptr && GetLastError() == ERROR_ALREADY_EXISTS);

  if (is_second_instance) {
    // Enqueue any otzaria:// URIs (and .otzplugin file paths) passed on the
    // command line so the first instance can handle them via its file-watcher,
    // then exit immediately.
    for (const auto& arg : early_args) {
      if (arg.size() >= 8 &&
          _strnicmp(arg.c_str(), "otzaria:", 8) == 0) {
        EnqueueUri(arg);
      } else if (EndsWithIgnoreCase(arg, ".otzplugin")) {
        EnqueueUri("otzaria://plugin/install-local?path=" +
                   UrlEncodeQueryComponent(arg));
      }
    }
    BringWindowToFront(FindWindowW(kFlutterWindowClassName, kMainWindowTitle));
    CloseHandle(mutex);
    return EXIT_SUCCESS;
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // חובה להיות זהה ל-AppUserModelID שבקיצורי המתקין, אחרת קיצור עם פרמטר
  // (למשל לוח שנה) מקבל כפתור נפרד בשורת המשימות במקום להתאחד עם הסמל המוצמד.
  ::SetCurrentProcessExplicitAppUserModelID(L"Otzaria.Otzaria");

  // Show the native floating-icon splash as early as possible (it needs COM
  // for WIC PNG decoding). It is an independent, top-most, click-through
  // layered window centered on the primary monitor — decoupled from the main
  // Flutter window, which stays hidden until its content is ready. This gives
  // immediate visual feedback during heavy init without any window resize,
  // jump, or blank gap. Dart closes it via the "otzaria/splash" channel when
  // the main window is revealed (see FlutterWindow method-call handler).
  // Skipped for CLI invocations (no UI).
  if (!is_cli_invocation) {
    splash::Show();
  }

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  // ── ספייק P-0 שלב 2. אינו מיועד ל-main. ───────────────────────────────
  //
  // מודל C1 מניח תהליך broker שמחזיק את הנתונים ואינו מציג דבר. השאלה
  // שנמדדת כאן: האם `FlutterEngine` **בלי** `FlutterViewController` מריץ
  // Dart בכלל — טיימרים, microtasks, I/O ו-rootBundle — או שהמנוע מצפה
  // ל-view כדי להתקדם.
  //
  // ⚠️ `headless` הקיים אינו זה: הוא יוצר view מלא ורק מדלג על ההצגה.
  // כאן אין view כלל, כמו ב-`examples/multiple_windows` של Flutter.
  if (is_broker_role) {
    // §3.3 של מפת הדרכים — הטיעון המרכזי נגד מודל A — נשען על כך שברירת
    // המחדל ממזגת את ה-platform thread עם ה-UI thread, ולכן N מנועים
    // בתהליך אחד מתחרים על thread יחיד. נמדד כאן ישירות: רושמים את מזהה
    // ה-thread שיצר את המנוע, וה-Dart רושם את שלו. שונים ⇒ אינם ממוזגים.
    //
    // `--ui-thread=platform` מאלץ את המדיניות הממוזגת. הוא קיים כדי להוכיח
    // שהמדידה מבחינה: אם שני המצבים מדווחים אותה תוצאה, המדידה חסרת ערך.
    for (const auto& arg : early_args) {
      if (arg == "--ui-thread=platform") {
        project.set_ui_thread_policy(
            flutter::UIThreadPolicy::RunOnPlatformThread);
      } else if (arg == "--ui-thread=separate") {
        project.set_ui_thread_policy(
            flutter::UIThreadPolicy::RunOnSeparateThread);
      }
    }
    printf("[broker] platform-thread-id = %lu\n", ::GetCurrentThreadId());
    fflush(stdout);

    // ── ספייק P-0 שלב 3: שני מנועים, שני threads, תהליך אחד ──
    // בודק אם מודל A יכול להימנע מתחרות ה-thread של §3.3 מבלי להישען על
    // `RunOnSeparateThread` שהמנוע מכריז שיוסר. כל מנוע נוצר על thread
    // ייעודי עם לולאת `GetMessage` משלו, ולכן ה-platform thread הממוזג
    // שלו הוא thread אחר.
    bool two_engines = false;
    bool two_engines_same_thread = false;
    bool two_windows_ui = false;
    for (const auto& arg : early_args) {
      if (arg == "--engines=2") two_engines = true;
      if (arg == "--engines=2same") two_engines_same_thread = true;
      if (arg == "--engines=2ui") two_windows_ui = true;
    }

    // ── ספייק P-2: שני חלונות **אמיתיים** עם view ──
    // המדידות הקודמות היו חסרות-view. כאן שני `FlutterViewController`
    // מלאים, כל אחד על thread ייעודי עם לולאת הודעות משלו — הצורה שבה
    // מודל A ייראה בפועל. בודק את מה שמנוע חסר-view לא יכול: רינדור
    // מקבילי, `EGLDisplay` משותף (§3.3 סעיף 4), RTL ופעולות חלון.
    if (two_windows_ui) {
      // `--no-plugins` מבודד את בדיקה 1: אם שני חלונות עובדים בלעדיו
      // ונופלים איתו, מקור הכשל הוא התוספים ולא ה-views על שני threads.
      bool skip_plugins = false;
      for (const auto& arg : early_args) {
        if (arg == "--no-plugins") skip_plugins = true;
      }
      auto run_window = [skip_plugins](const flutter::DartProject& base,
                                       const char* entrypoint,
                                       const wchar_t* title, int x) {
        flutter::DartProject p(base);
        p.set_dart_entrypoint(entrypoint);
        FlutterWindow window(p, /*headless=*/false, skip_plugins);
        Win32Window::Point origin(x, 80);
        Win32Window::Size size(560, 640);
        if (!window.Create(title, origin, size)) return;
        // החלון נוצר מוסתר ומתגלה בדרך כלל על ידי Dart דרך window_manager.
        // בספייק אין את הרצף הזה, ולכן מציגים מפורשות.
        ::ShowWindow(window.GetHandle(), SW_SHOW);
        window.SetQuitOnClose(true);
        ::MSG msg;
        while (::GetMessage(&msg, nullptr, 0, 0)) {
          ::TranslateMessage(&msg);
          ::DispatchMessage(&msg);
        }
      };

      std::thread window_b([&]() {
        printf("[B] window thread = %lu\n", ::GetCurrentThreadId());
        fflush(stdout);
        run_window(project, "windowBTest", L"אוצריא — חלון ב'", 640);
      });

      printf("[A] window thread = %lu\n", ::GetCurrentThreadId());
      fflush(stdout);
      run_window(project, "windowATest", L"אוצריא — חלון א'", 40);

      window_b.join();
      ::CoUninitialize();
      return EXIT_SUCCESS;
    }

    // בקרה. שני מנועים על **אותו** thread. קיימת רק כדי להוכיח שהמדידה
    // מבחינה: אם גם כאן הפער המרבי ~100ms, אז המדידה אינה מודדת תחרות
    // כלל והמסקנה מ-`--engines=2` חסרת ערך.
    if (two_engines_same_thread) {
      printf("[A] platform-thread-id = %lu\n", ::GetCurrentThreadId());
      printf("[B] platform-thread-id = %lu\n", ::GetCurrentThreadId());
      fflush(stdout);
      flutter::DartProject project_a(project);
      project_a.set_dart_entrypoint("engineATest");
      flutter::FlutterEngine engine_a(project_a);
      flutter::DartProject project_b(project);
      project_b.set_dart_entrypoint("engineBTest");
      flutter::FlutterEngine engine_b(project_b);
      if (!engine_a.Run("engineATest") || !engine_b.Run("engineBTest")) {
        printf("[control] engine.Run FAILED\n");
        fflush(stdout);
        return EXIT_FAILURE;
      }
      ::MSG msg;
      while (::GetMessage(&msg, nullptr, 0, 0)) {
        ::TranslateMessage(&msg);
        ::DispatchMessage(&msg);
      }
      ::CoUninitialize();
      return EXIT_SUCCESS;
    }

    if (two_engines) {
      std::thread engine_b_thread([&project]() {
        printf("[B] platform-thread-id = %lu\n", ::GetCurrentThreadId());
        fflush(stdout);
        flutter::DartProject project_b(project);
        project_b.set_dart_entrypoint("engineBTest");
        flutter::FlutterEngine engine_b(project_b);
        if (!engine_b.Run("engineBTest")) {
          printf("[B] engine.Run FAILED\n");
          fflush(stdout);
          return;
        }
        ::MSG msg_b;
        while (::GetMessage(&msg_b, nullptr, 0, 0)) {
          ::TranslateMessage(&msg_b);
          ::DispatchMessage(&msg_b);
        }
      });

      printf("[A] platform-thread-id = %lu\n", ::GetCurrentThreadId());
      fflush(stdout);
      flutter::DartProject project_a(project);
      project_a.set_dart_entrypoint("engineATest");
      flutter::FlutterEngine engine_a(project_a);
      if (!engine_a.Run("engineATest")) {
        printf("[A] engine.Run FAILED\n");
        fflush(stdout);
        return EXIT_FAILURE;
      }
      ::MSG msg_a;
      while (::GetMessage(&msg_a, nullptr, 0, 0)) {
        ::TranslateMessage(&msg_a);
        ::DispatchMessage(&msg_a);
      }
      engine_b_thread.join();
      ::CoUninitialize();
      return EXIT_SUCCESS;
    }

    project.set_dart_entrypoint("brokerMain");
    flutter::FlutterEngine engine(project);
    if (!engine.Run("brokerMain")) {
      OutputDebugStringW(L"Otzaria[broker] engine.Run failed\n");
      return EXIT_FAILURE;
    }
    // אין חלון ולכן אין WM_QUIT. ה-Dart מסיים את התהליך ב-exit() כשהמדידה
    // מסתיימת; הלולאה כאן רק מזינה את תור המשימות של המנוע.
    ::MSG broker_msg;
    while (::GetMessage(&broker_msg, nullptr, 0, 0)) {
      ::TranslateMessage(&broker_msg);
      ::DispatchMessage(&broker_msg);
    }
    ::CoUninitialize();
    return EXIT_SUCCESS;
  }

  FlutterWindow window(project, /*headless=*/is_cli_invocation);
  Win32Window::Point origin(10, 10);
  // The main window is created hidden and is NOT shown on the first frame (see
  // FlutterWindow::OnCreate). It stays hidden until Dart reveals it
  // (window_manager.show in presentMainWindow) once the active tab's content is
  // ready, so it appears directly at its final size/position with content — no
  // resize, no jump, no blank gap. The native floating-icon splash
  // (splash::Show above) is the only thing visible until then. Initial size is
  // irrelevant (the window is never shown at this size).
  Win32Window::Size size(240, 240);
  if (!window.Create(kMainWindowTitle, origin, size)) {
    if (mutex) CloseHandle(mutex);
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  if (mutex) CloseHandle(mutex);
  ::CoUninitialize();
  return EXIT_SUCCESS;
}
