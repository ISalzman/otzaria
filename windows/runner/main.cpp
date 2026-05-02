#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <shlobj.h>
#include <windows.h>

#include <chrono>
#include <fstream>
#include <iomanip>
#include <sstream>
#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

static const wchar_t* kSingleInstanceMutexName = L"OtzariaAppSingleInstance";

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

// Appends a URI string to the external-activation queue file so the already-
// running instance can pick it up.
static void EnqueueUri(const std::string& uri_utf8) {
  wchar_t app_data[MAX_PATH];
  if (FAILED(SHGetFolderPathW(nullptr, CSIDL_APPDATA, nullptr, 0, app_data))) {
    return;
  }

  std::wstring queue_path =
      std::wstring(app_data) + L"\\otzaria\\pending_external_activations.jsonl";

  // Ensure the parent directory exists.
  std::wstring dir = std::wstring(app_data) + L"\\otzaria";
  CreateDirectoryW(dir.c_str(), nullptr);

  // Build ISO-8601 timestamp (UTC).
  auto now = std::chrono::system_clock::now();
  std::time_t tt = std::chrono::system_clock::to_time_t(now);
  struct tm utc {};
  gmtime_s(&utc, &tt);
  std::ostringstream ts;
  ts << std::put_time(&utc, "%Y-%m-%dT%H:%M:%SZ");

  std::string record =
      "{\"uri\":\"" + JsonEscape(uri_utf8) + "\",\"createdAt\":\"" + ts.str() + "\"}";

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

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t* command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Single-instance check: must happen before the Flutter engine starts so
  // that the second instance never acquires any shared resources (DB, etc.).
  HANDLE mutex =
      CreateMutexW(nullptr, TRUE, kSingleInstanceMutexName);
  bool is_second_instance =
      (mutex == nullptr || GetLastError() == ERROR_ALREADY_EXISTS);

  if (is_second_instance) {
    // Enqueue any otzaria:// URIs passed on the command line so the first
    // instance can handle them via its file-watcher, then exit immediately.
    std::vector<std::string> args = GetCommandLineArguments();
    for (const auto& arg : args) {
      if (arg.size() >= 8 &&
          _strnicmp(arg.c_str(), "otzaria:", 8) == 0) {
        EnqueueUri(arg);
      }
    }
    if (mutex) CloseHandle(mutex);
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
  if (!window.Create(L"אוצריא", origin, size)) {
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
