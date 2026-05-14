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
#include <vector>

#include "flutter_window.h"
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

  // Single-instance check: must happen before the Flutter engine starts so
  // that the second instance never acquires any shared resources (DB, etc.).
  // bInitialOwner = FALSE: we don't need ownership, just existence of the object.
  // If CreateMutexW fails (returns NULL), treat as first instance so the app
  // can still start rather than being permanently blocked.
  HANDLE mutex =
      CreateMutexW(nullptr, FALSE, kSingleInstanceMutexName);
  bool is_second_instance =
      (mutex != nullptr && GetLastError() == ERROR_ALREADY_EXISTS);

  if (is_second_instance) {
    // Enqueue any otzaria:// URIs (and .otzplugin file paths) passed on the
    // command line so the first instance can handle them via its file-watcher,
    // then exit immediately.
    std::vector<std::string> args = GetCommandLineArguments();
    for (const auto& arg : args) {
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

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
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
