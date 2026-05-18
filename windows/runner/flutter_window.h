#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <atomic>
#include <memory>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  // When |headless| is true, the window will not be shown after the first
  // frame — used for CLI commands (e.g. pack-plugin) that expect the Dart
  // entrypoint to call exit() before any UI is rendered.
  explicit FlutterWindow(const flutter::DartProject& project,
                         bool headless = false);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  void ArmForceExitWatchdog(uint32_t timeout_ms);

  // The project to run.
  flutter::DartProject project_;

  // When true, skip Show() in the first-frame callback. Used by CLI commands.
  bool headless_ = false;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      process_control_channel_;
  std::atomic_bool force_exit_watchdog_armed_ = false;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
