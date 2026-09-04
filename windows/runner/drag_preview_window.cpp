#include "drag_preview_window.h"

#include <atomic>
#include <mutex>
#include <string>

namespace drag_preview {
namespace {

constexpr const wchar_t kClassName[] = L"OtzariaDragPreview";

// מידות התצוגה. רוחב כרטיסיה טיפוסי, כדי שההרגשה תהיה של הכרטיסיה עצמה
// ולא של תווית כללית.
constexpr int kWidth = 190;
constexpr int kHeight = 34;

// מרחק הסמן מפינת התצוגה. הסמן "מחזיק" את הכרטיסיה קרוב לקצה שלה, כמו
// בדפדפן, ולא במרכזה — אחרת התצוגה מסתירה את מה שמתחתיה.
constexpr int kCursorOffsetX = 18;
constexpr int kCursorOffsetY = 14;

constexpr UINT_PTR kFollowTimerId = 1;
constexpr UINT kFollowIntervalMs = 16;

std::mutex g_mutex;
HWND g_window = nullptr;
std::wstring g_title;
std::atomic<bool> g_active{false};

// החלון שממנו הגרירה התחילה. התצוגה מוסתרת רק מעליו.
std::atomic<HWND> g_source{nullptr};

// האם הנקודה נמצאת מעל חלון המקור.
//
// ⚠️ המקור בלבד, ולא "כל חלון של התהליך" — ראו ההערה ב-[Begin] שבכותרת.
// העלייה ל-root חיונית: `WindowFromPoint` מחזיר את החלון הפנימי ביותר,
// בדרך כלל ה-view של Flutter או חלון של WebView2.
bool IsOverSourceWindow(POINT pt) {
  const HWND source = g_source.load();
  if (!source) return false;
  const HWND under = ::WindowFromPoint(pt);
  if (!under) return false;
  return ::GetAncestor(under, GA_ROOT) == source;
}

void Paint(HWND hwnd) {
  PAINTSTRUCT ps;
  const HDC hdc = ::BeginPaint(hwnd, &ps);

  RECT rect{0, 0, kWidth, kHeight};

  // רקע בצבע כרטיסיה, עם מסגרת עדינה. GDI ולא Direct2D: התצוגה קטנה,
  // קצרת-חיים, ואינה מצדיקה תלות נוספת ב-runner.
  const HBRUSH background = ::CreateSolidBrush(RGB(0xF7, 0xF2, 0xEA));
  ::FillRect(hdc, &rect, background);
  ::DeleteObject(background);

  const HPEN border = ::CreatePen(PS_SOLID, 1, RGB(0xC9, 0xBA, 0xA4));
  const HGDIOBJ old_pen = ::SelectObject(hdc, border);
  const HGDIOBJ old_brush = ::SelectObject(hdc, ::GetStockObject(NULL_BRUSH));
  ::RoundRect(hdc, 0, 0, kWidth, kHeight, 8, 8);
  ::SelectObject(hdc, old_brush);
  ::SelectObject(hdc, old_pen);
  ::DeleteObject(border);

  // ⚠️ `DT_RTLREADING` — הכותרות בעברית, ובלעדיו סימני פיסוק ומספרים
  // מופיעים בצד הלא נכון.
  const HFONT font = ::CreateFontW(
      16, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
      OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
      DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");
  const HGDIOBJ old_font = ::SelectObject(hdc, font);
  ::SetBkMode(hdc, TRANSPARENT);
  ::SetTextColor(hdc, RGB(0x3A, 0x2E, 0x1E));

  RECT text_rect{10, 0, kWidth - 10, kHeight};
  std::wstring title;
  {
    std::lock_guard<std::mutex> lock(g_mutex);
    title = g_title;
  }
  ::DrawTextW(hdc, title.c_str(), -1, &text_rect,
              DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_END_ELLIPSIS |
                  DT_RTLREADING | DT_NOPREFIX);

  ::SelectObject(hdc, old_font);
  ::DeleteObject(font);
  ::EndPaint(hwnd, &ps);
}

LRESULT CALLBACK WndProc(HWND hwnd, UINT message, WPARAM wparam,
                         LPARAM lparam) {
  switch (message) {
    case WM_PAINT:
      Paint(hwnd);
      return 0;
    case WM_TIMER: {
      if (wparam != kFollowTimerId) break;
      POINT pt{};
      ::GetCursorPos(&pt);
      ::SetWindowPos(hwnd, HWND_TOPMOST, pt.x + kCursorOffsetX,
                     pt.y + kCursorOffsetY, 0, 0,
                     SWP_NOSIZE | SWP_NOACTIVATE);
      // מעל חלון המקור ה-`feedback` של Flutter כבר מוצג, ולכן התצוגה
      // הנייטיבית מוסתרת כדי שלא ייראו שתי כרטיסיות. מעל כל מקום אחר —
      // כולל חלון אוצריא אחר — היא **חייבת** להיראות, כי ה-feedback
      // נחתך בגבולות חלון המקור.
      const bool should_show = !IsOverSourceWindow(pt);
      const bool visible = ::IsWindowVisible(hwnd) != FALSE;
      if (should_show != visible) {
        ::ShowWindow(hwnd, should_show ? SW_SHOWNOACTIVATE : SW_HIDE);
      }
      return 0;
    }
    case WM_DESTROY:
      return 0;
  }
  return ::DefWindowProc(hwnd, message, wparam, lparam);
}

void EnsureClass() {
  static bool registered = false;
  if (registered) return;
  WNDCLASSW wc{};
  wc.lpfnWndProc = WndProc;
  wc.hInstance = ::GetModuleHandle(nullptr);
  wc.lpszClassName = kClassName;
  wc.hCursor = ::LoadCursor(nullptr, IDC_ARROW);
  ::RegisterClassW(&wc);
  registered = true;
}

}  // namespace

std::wstring Utf16FromUtf8(const std::string& utf8) {
  if (utf8.empty()) return std::wstring();
  const int size = ::MultiByteToWideChar(
      CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()), nullptr, 0);
  if (size <= 0) return std::wstring();
  std::wstring result(size, L'\0');
  ::MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                        static_cast<int>(utf8.size()), result.data(), size);
  return result;
}

void Begin(const std::wstring& title, HWND source) {
  {
    std::lock_guard<std::mutex> lock(g_mutex);
    g_title = title;
  }
  g_source.store(source);
  EnsureClass();

  if (!g_window) {
    // WS_EX_TRANSPARENT — חובה. בלעדיו החלון הזה היה מחזיר את עצמו
    // מ-`WindowFromPoint`, ושחרור הכרטיסיה מעל חלון אחר לא היה מזוהה.
    // WS_EX_NOACTIVATE — כדי שהמעקב לא יגנוב פוקוס מהחלון הנגרר ממנו.
    g_window = ::CreateWindowExW(
        WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW |
            WS_EX_TOPMOST | WS_EX_NOACTIVATE,
        kClassName, L"", WS_POPUP, 0, 0, kWidth, kHeight, nullptr, nullptr,
        ::GetModuleHandle(nullptr), nullptr);
    if (!g_window) return;
    ::SetLayeredWindowAttributes(g_window, 0, 235, LWA_ALPHA);
  }

  ::InvalidateRect(g_window, nullptr, TRUE);
  ::SetTimer(g_window, kFollowTimerId, kFollowIntervalMs, nullptr);
  g_active.store(true);

  // מיקום ראשוני מיידי, כדי שהתצוגה לא תקפוץ מהפינה בפעימה הראשונה.
  POINT pt{};
  ::GetCursorPos(&pt);
  ::SetWindowPos(g_window, HWND_TOPMOST, pt.x + kCursorOffsetX,
                 pt.y + kCursorOffsetY, 0, 0, SWP_NOSIZE | SWP_NOACTIVATE);
}

void End() {
  g_active.store(false);
  g_source.store(nullptr);
  if (!g_window) return;
  ::KillTimer(g_window, kFollowTimerId);
  ::ShowWindow(g_window, SW_HIDE);
}

bool IsActive() { return g_active.load(); }

}  // namespace drag_preview
