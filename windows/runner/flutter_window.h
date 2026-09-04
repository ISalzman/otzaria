#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <atomic>
#include <memory>
#include <queue>
#include <string>

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

  // מציג את החלון ברגע שהפריים הראשון מצויר, ומביא אותו לחזית.
  //
  // ⚠️ נועד לחלונות משניים. החלון הראשון נחשף מ-Dart רק כשהתוכן מוכן, כי
  // ה-splash הנייטיב מכסה את ההמתנה. לחלון משני אין splash, ולכן המתנה
  // עד סיום האתחול נראית למשתמש כאילו הלחיצה לא עשתה כלום — הפריים
  // הראשון הוא מסך הטעינה של האפליקציה, וזו התשובה הוויזואלית המיידית.
  void RevealOnFirstFrame();

  // מחזיר לשימוש חלון שנסגר (הוסתר) עם מטען חדש.
  //
  // ⚠️ זה מה שהופך פתיחת חלון למיידית. המנוע כבר עלה, ה-blocs חיים,
  // הספרייה טעונה — נשאר רק להציג ולשלוח את הכרטיסיה. בלי זה כל פתיחה
  // משלמת שוב את מלוא האתחול, וכל מחזור פתיחה-סגירה מוסיף מנוע לזיכרון.
  // [drop_x]/[drop_y] הם נקודת השחרור בקואורדינטות מסך, או 0 כשאין —
  // ואז המיקום נשאר כשהיה.
  // [bounds] היא מסגרת מדויקת שדוחה את [drop_x]/[drop_y] — כך חלון
  // שהמשתמש הצמיד בגרירה נוצר בדיוק במסגרת שההצמדה נתנה.
  void ReviveWith(const std::string& payload, int width, int height,
                  int drop_x = 0, int drop_y = 0,
                  const RECT* bounds = nullptr);

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  void OnWindowHidden() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  void ArmForceExitWatchdog(uint32_t timeout_ms);

  // שוטף את הכתיבות התלויות של Dart לפני שאנחנו מאשרים סיום סשן.
  //
  // חוסם את ה-platform thread עד שה-Dart מסמן סיום או עד פקיעת הזמן, תוך
  // הרצת לולאת הודעות מצומצמת — בלעדיה ה-Dart לא ירוץ כלל, כי ה-platform
  // thread וה-UI thread ממוזגים. מחזיר true אם ה-flush הושלם.
  bool FlushBeforeSessionEnd();

  // אירוע שה-Dart מסמן דרך "sessionEndFlushDone". manual-reset.
  HANDLE session_end_flush_event_ = nullptr;

  // The project to run.
  flutter::DartProject project_;

  // When true, skip Show() in the first-frame callback. Used by CLI commands.
  bool headless_ = false;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      process_control_channel_;
  // ערוץ ריבוי החלונות (otzaria/multiwindow). Dart קורא "openWindow" עם
  // מטען JSON, וה-runner פותח חלון נוסף על thread ייעודי משלו.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      multiwindow_channel_;
  // בקשת פתיחת חלון שממתינה לאיטרציה הבאה של לולאת ההודעות.
  //
  // ⚠️ ה-`result` נשמר ונענה **אחרי** שהחלון נוצר בפועל. קודם לכן הערוץ
  // החזיר `true` מיד אחרי ההכנסה לתור, וערך ההחזרה של היצירה עצמה נזרק —
  // כלומר Dart קיבל "הצלחה" על חלון שאולי לא קם, ומחק את הכרטיסיה על סמך
  // התשובה הזו.
  struct PendingSecondaryWindow {
    std::string payload;
    int width = 0;
    int height = 0;
    // נקודת השחרור בקואורדינטות מסך, או 0 כשהפתיחה לא באה מגרירה.
    int drop_x = 0;
    int drop_y = 0;
    // מסגרת מדויקת, כשהגרירה הסתיימה בהצמדה של Windows.
    //
    // ⚠️ דוחה את `drop_x`/`drop_y`. חלון שהמשתמש הצמיד לחצי מסך חייב
    // להיווצר באותה מסגרת, אחרת ההצמדה שהוא ראה נעלמת ברגע שהחלון
    // האמיתי מופיע.
    bool has_bounds = false;
    RECT bounds{};
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result;
  };
  // נכתב בטיפול בערוץ ונקרא בלולאת ההודעות של אותו thread, ולכן אין כאן
  // גישה חוצת-threads.
  std::queue<PendingSecondaryWindow> pending_secondary_windows_;
  // בקשות "מסור את הגרירה ל-Windows" שממתינות ללולאת ההודעות.
  //
  // ⚠️ נענות **אחרי** שהמשתמש שחרר, כי התשובה היא המסגרת הסופית — כולל
  // הצמדה. הן אינן מבוצעות בתוך הטיפול בערוץ: `DragWithSystem` נכנס
  // ללולאה מודאלית, וחסימה מתוך קריאת ערוץ היא ריאנטרנטית.
  std::queue<std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>>
      pending_system_drags_;
  // ערוץ לסגירת חלון ה-splash הנייטיב (otzaria/splash) — Dart קורא "close"
  // בעת חשיפת החלון הראשי.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      splash_channel_;
  // ערוץ עדכון ה-Jump List של שורת המשימות (otzaria/jumplist) — Dart שולח
  // "updateTabs" עם כותרות הטאבים הפתוחים בכל שינוי.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      jumplist_channel_;
  std::atomic_bool force_exit_watchdog_armed_ = false;
  // האם החלון עדיין נספר ב-`g_live_window_count`. מונע הפחתה כפולה
  // כשמגיעות שתי בקשות סגירה, **וגם** ספירה כפולה בשימוש חוזר.
  bool counted_ = true;

 public:
  // האם החלון נסגר על ידי המשתמש (הוסתר), להבדיל מחלון חדש שטרם נחשף.
  //
  // ⚠️ אסור להסיק זאת מ-`IsWindowVisible`. חלון נוצר מוסתר ונחשף רק
  // בפריים הראשון — כ-422ms אחר כך. בפער הזה הוא נראה בדיוק כמו חלון
  // סגור, ולכן פתיחה שנייה "מיחזרה" חלון שעוד נטען: המונה נופח לצמיתות,
  // התהליך לא יצא לעולם, והזומבי החזיק את מנעול המופע היחיד — כלומר
  // התוכנה גם לא ניתנת להפעלה מחדש.
  bool IsClosedByUser() const { return hidden_flag_->load(); }

  // דגל משותף עם שעון-הביטחון של החשיפה, שרץ על thread מנותק ואינו יכול
  // להחזיק מצביע לחלון.
  std::shared_ptr<std::atomic<bool>> hidden_flag() const {
    return hidden_flag_;
  }

 private:
  std::shared_ptr<std::atomic<bool>> hidden_flag_ =
      std::make_shared<std::atomic<bool>>(false);

  // Win32 Job Object that contains this process plus any child processes
  // it spawns (notably WebView2's msedgewebview2.exe instances). Configured
  // with JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE so the kernel kills every
  // member when the handle is released — which happens on TerminateProcess
  // of the host. Without this, fast-exit shutdown orphans Edge children.
  //
  // Setup can fail on hardened environments (sandboxed launches, debugger
  // job objects on Win32 versions that don't allow nesting, certain
  // enterprise MDM/AV configurations). `job_object_ready_` reflects whether
  // every setup step succeeded; we only honour forceTerminate when it did,
  // otherwise the Dart side falls back to the existing graceful close path.
  HANDLE job_handle_ = nullptr;
  std::atomic_bool job_object_ready_ = false;
  // סיבת כשל הקמת ה-Job Object (ריק בהצלחה) — מדווח ל-Dart דרך
  // "jobObjectStatus" ונרשם ל-errors.txt לאבחון msedgewebview2 יתומים.
  std::string job_object_failure_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
