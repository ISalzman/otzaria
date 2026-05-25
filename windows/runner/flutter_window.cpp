#include "flutter_window.h"

#include <algorithm>
#include <chrono>
#include <limits>
#include <optional>
#include <thread>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project, bool headless)
    : project_(project), headless_(headless) {
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
  job_handle_ = CreateJobObjectW(nullptr, nullptr);
  if (!job_handle_) {
    OutputDebugStringW(L"Otzaria: CreateJobObjectW failed; Edge child "
                       L"processes will not be contained on fast-exit.\n");
    return;
  }
  JOBOBJECT_EXTENDED_LIMIT_INFORMATION info{};
  info.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
  if (!SetInformationJobObject(job_handle_,
                               JobObjectExtendedLimitInformation, &info,
                               sizeof(info))) {
    OutputDebugStringW(L"Otzaria: SetInformationJobObject failed; not "
                       L"honouring forceTerminate.\n");
    CloseHandle(job_handle_);
    job_handle_ = nullptr;
    return;
  }
  if (!AssignProcessToJobObject(job_handle_, GetCurrentProcess())) {
    // The most common failure mode: the launching environment (debugger,
    // sandbox, AppContainer, certain enterprise/MDM tooling) has already
    // placed our process in a non-nestable job. We have no way to break
    // out, so we discard the job we created and stay on the graceful
    // close path — forceTerminate will report not-ready and Dart will
    // fall back to windowManager.destroy() + exit(0).
    OutputDebugStringW(L"Otzaria: AssignProcessToJobObject failed; likely "
                       L"already in a non-nestable job. Falling back to "
                       L"graceful shutdown on close.\n");
    CloseHandle(job_handle_);
    job_handle_ = nullptr;
    return;
  }
  job_object_ready_.store(true);
}

FlutterWindow::~FlutterWindow() {
  if (job_handle_) {
    // Closing the job handle while our process is the only member triggers
    // KILL_ON_JOB_CLOSE for every other member (the WebView2 children). For
    // our own process, the handle close is a no-op since the kernel keeps
    // the job alive until all members are reaped.
    CloseHandle(job_handle_);
    job_handle_ = nullptr;
  }
}

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
  RegisterPlugins(flutter_controller_->engine());
  process_control_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "otzaria/process_control",
          &flutter::StandardMethodCodec::GetInstance());
  process_control_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
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
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  if (!headless_) {
    flutter_controller_->engine()->SetNextFrameCallback([&]() {
      this->Show();
    });

    // Flutter can complete the first frame before the "show window" callback is
    // registered. The following call ensures a frame is pending to ensure the
    // window is shown. It is a no-op if the first frame hasn't completed yet.
    flutter_controller_->ForceRedraw();
  }
  // In headless mode the window stays invisible — CLI commands are expected
  // to invoke exit() from Dart before any UI work happens.

  return true;
}

void FlutterWindow::OnDestroy() {
  process_control_channel_.reset();
  if (flutter_controller_) {
    // Reset the controller properly - no need to call Shutdown explicitly
    flutter_controller_.reset();
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      if (flutter_controller_ && flutter_controller_->engine()) {
        flutter_controller_->engine()->ReloadSystemFonts();
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
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
