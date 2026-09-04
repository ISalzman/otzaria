#include "drag_preview_window.h"

#include <atomic>
#include <mutex>
#include <string>
#include <vector>

// `AlphaBlend` — נדרש כדי לצייר את תמונת הכרטיסיה עם ערוץ האלפא שלה, כך
// שהפינות המעוגלות יישבו על הרקע שלנו ולא ייצבעו שחור.
#pragma comment(lib, "msimg32.lib")

namespace drag_preview {
namespace {

constexpr const wchar_t kClassName[] = L"OtzariaDragPreview";

// מידות התצוגה — **חלון מוקטן, לא תווית**.
//
// ⚠️ הגרסה הראשונה הייתה מלבן 190×34 עם כותרת, והמשתמש תיאר אותה כ"ריבוע
// מוזר" ולא ככרטיסיה. מה שהמשתמש עומד לקבל הוא **חלון**, ולכן זה מה
// שהתצוגה מראה: רצועת כרטיסיות עם הכרטיסיה שנגררת, וגוף מתחתיה.
constexpr int kWidth = 300;
constexpr int kHeight = 196;
constexpr int kStripHeight = 34;
constexpr int kTabWidth = 176;
constexpr int kTabRadius = 8;
constexpr int kTabInset = 8;

// מרחק הסמן מפינת התצוגה.
//
// ⚠️ הסמן מחזיק את **הכרטיסיה**, לא את פינת החלון — ולכן ההיסט מכוון כך
// שהכרטיסיה תשב תחת הסמן, בדיוק כמו בדפדפן. ב-RTL הכרטיסיה בצד ימין,
// ולכן ההיסט האופקי שלילי.
constexpr int kCursorOffsetX = -(kWidth - kTabInset - kTabWidth / 2);
constexpr int kCursorOffsetY = -kStripHeight / 2;

constexpr UINT_PTR kFollowTimerId = 1;
constexpr UINT kFollowIntervalMs = 16;

// ⚠️ רשת ביטחון להקפאה. התצוגה נשארת גלויה עד שהחלון האמיתי נחשף, ואם
// היצירה נכשלה בשקט היא הייתה נשארת תלויה על המסך לנצח.
constexpr UINT_PTR kHoldTimerId = 2;
constexpr UINT kHoldTimeoutMs = 4000;

std::mutex g_mutex;
HWND g_window = nullptr;
std::wstring g_title;
std::atomic<bool> g_active{false};

// החלון שממנו הגרירה התחילה. התצוגה מוסתרת רק מעליו.
std::atomic<HWND> g_source{nullptr};

// צבעי הערכה הנוכחית, שמגיעים מ-Dart.
//
// ⚠️ קודם הם היו מקודדים קשיח בגוונים בהירים. בערכה כהה זה נראה כמו
// מלבן לבן זוהר על מסך כהה — הפוך בדיוק ממה שהמשתמש מצפה שייגרר.
struct Palette {
  COLORREF strip = RGB(0xF2, 0xEB, 0xE0);
  COLORREF tab = RGB(0xF7, 0xF2, 0xEA);
  COLORREF body = RGB(0xFD, 0xFB, 0xF7);
  COLORREF border = RGB(0xC9, 0xBA, 0xA4);
  COLORREF text = RGB(0x3A, 0x2E, 0x1E);
};
Palette g_palette;

// תמונת הכרטיסיה כפי שהיא בחלון המקור, אם הגיעה.
//
// ⚠️ DIB ולא `HBITMAP` תואם-מכשיר: צריך גישה ישירה לפיקסלים כדי להמיר
// RGBA (מה ש-Flutter מחזיר) ל-BGRA (מה ש-GDI מצפה לו).
HBITMAP g_tab_bitmap = nullptr;
int g_tab_bitmap_w = 0;
int g_tab_bitmap_h = 0;
// הגודל **הלוגי** שבו התמונה תצויר — פיקסלים חלקי ה-DPR שבו צולמה.
int g_tab_logical_w = 0;
int g_tab_logical_h = 0;

void ReleaseTabBitmap() {
  if (g_tab_bitmap) {
    ::DeleteObject(g_tab_bitmap);
    g_tab_bitmap = nullptr;
  }
  g_tab_bitmap_w = 0;
  g_tab_bitmap_h = 0;
  g_tab_logical_w = 0;
  g_tab_logical_h = 0;
}

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

void FillRoundedTop(HDC hdc, RECT rect, COLORREF color, int radius) {
  const HBRUSH brush = ::CreateSolidBrush(color);
  const HGDIOBJ old_brush = ::SelectObject(hdc, brush);
  const HPEN pen = ::CreatePen(PS_SOLID, 1, color);
  const HGDIOBJ old_pen = ::SelectObject(hdc, pen);
  // פינות עליונות מעוגלות ותחתונות מרובעות: ה-`RoundRect` מעגל את
  // ארבעתן, והמלבן שאחריו מרבע את התחתונות — כך הכרטיסיה מתמזגת בגוף
  // בלי תפר, וזה בדיוק מה שהופך אותה לכרטיסיה ולא לכפתור.
  ::RoundRect(hdc, rect.left, rect.top, rect.right, rect.bottom + radius,
              radius * 2, radius * 2);
  ::Rectangle(hdc, rect.left, rect.bottom - radius, rect.right, rect.bottom);
  ::SelectObject(hdc, old_pen);
  ::DeleteObject(pen);
  ::SelectObject(hdc, old_brush);
  ::DeleteObject(brush);
}

void Paint(HWND hwnd) {
  PAINTSTRUCT ps;
  const HDC hdc = ::BeginPaint(hwnd, &ps);

  Palette palette;
  std::wstring title;
  {
    std::lock_guard<std::mutex> lock(g_mutex);
    palette = g_palette;
    title = g_title;
  }

  // גוף החלון.
  RECT body{0, kStripHeight, kWidth, kHeight};
  const HBRUSH body_brush = ::CreateSolidBrush(palette.body);
  ::FillRect(hdc, &body, body_brush);
  ::DeleteObject(body_brush);

  // רצועת הכרטיסיות.
  RECT strip{0, 0, kWidth, kStripHeight};
  const HBRUSH strip_brush = ::CreateSolidBrush(palette.strip);
  ::FillRect(hdc, &strip, strip_brush);
  ::DeleteObject(strip_brush);

  // הכרטיסיה עצמה, בצד ימין — RTL.
  //
  // ⚠️ אם התמונה האמיתית הגיעה — מציירים אותה, ולא שרטוט מחדש. שרטוט GDI
  // אינו יכול להיות זהה (גופן, אייקון סוג, כפתור X, סימון בחירה), והמשתמש
  // ביקש שזה ייראה כמו בכרום.
  HBITMAP bitmap = nullptr;
  int bmp_w = 0, bmp_h = 0, logical_w = 0, logical_h = 0;
  {
    std::lock_guard<std::mutex> lock(g_mutex);
    bitmap = g_tab_bitmap;
    bmp_w = g_tab_bitmap_w;
    bmp_h = g_tab_bitmap_h;
    logical_w = g_tab_logical_w;
    logical_h = g_tab_logical_h;
  }

  if (bitmap && bmp_w > 0 && bmp_h > 0) {
    const int draw_w = logical_w > 0 ? logical_w : bmp_w;
    const int draw_h = logical_h > 0 ? logical_h : bmp_h;
    const int left = kWidth - kTabInset - draw_w;
    const int top = kStripHeight - draw_h;

    const HDC mem = ::CreateCompatibleDC(hdc);
    const HGDIOBJ old = ::SelectObject(mem, bitmap);
    // ⚠️ `AlphaBlend` ולא `BitBlt`: לכרטיסיה יש פינות מעוגלות, ובלי ערוץ
    // האלפא הן היו נצבעות שחור על הרקע שלנו.
    BLENDFUNCTION blend{};
    blend.BlendOp = AC_SRC_OVER;
    blend.SourceConstantAlpha = 255;
    blend.AlphaFormat = AC_SRC_ALPHA;
    ::SetStretchBltMode(hdc, HALFTONE);
    ::AlphaBlend(hdc, left, top, draw_w, draw_h, mem, 0, 0, bmp_w, bmp_h,
                 blend);
    ::SelectObject(mem, old);
    ::DeleteDC(mem);
  } else {
    RECT tab{kWidth - kTabInset - kTabWidth, 4, kWidth - kTabInset,
             kStripHeight};
    FillRoundedTop(hdc, tab, palette.tab, kTabRadius);
  }

  // מסגרת חיצונית.
  const HPEN border = ::CreatePen(PS_SOLID, 1, palette.border);
  const HGDIOBJ old_pen = ::SelectObject(hdc, border);
  const HGDIOBJ old_brush = ::SelectObject(hdc, ::GetStockObject(NULL_BRUSH));
  ::Rectangle(hdc, 0, 0, kWidth, kHeight);
  ::SelectObject(hdc, old_brush);
  ::SelectObject(hdc, old_pen);
  ::DeleteObject(border);

  // הכותרת מצוירת רק כשאין תמונה — בתמונה היא כבר בפנים, ובכתיבה מעליה
  // היינו מקבלים טקסט כפול.
  if (!bitmap) {
    // ⚠️ `DT_RTLREADING` — הכותרות בעברית, ובלעדיו סימני פיסוק ומספרים
    // מופיעים בצד הלא נכון.
    const HFONT font = ::CreateFontW(
        15, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
        OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
        DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");
    const HGDIOBJ old_font = ::SelectObject(hdc, font);
    ::SetBkMode(hdc, TRANSPARENT);
    ::SetTextColor(hdc, palette.text);

    RECT text_rect{kWidth - kTabInset - kTabWidth + 9, 4,
                   kWidth - kTabInset - 9, kStripHeight};
    ::DrawTextW(hdc, title.c_str(), -1, &text_rect,
                DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_END_ELLIPSIS |
                    DT_RTLREADING | DT_NOPREFIX);

    ::SelectObject(hdc, old_font);
    ::DeleteObject(font);
  }
  ::EndPaint(hwnd, &ps);
}

void MoveToCursor(HWND hwnd) {
  POINT pt{};
  ::GetCursorPos(&pt);
  ::SetWindowPos(hwnd, HWND_TOPMOST, pt.x + kCursorOffsetX,
                 pt.y + kCursorOffsetY, 0, 0, SWP_NOSIZE | SWP_NOACTIVATE);
}

LRESULT CALLBACK WndProc(HWND hwnd, UINT message, WPARAM wparam,
                         LPARAM lparam) {
  switch (message) {
    case WM_PAINT:
      Paint(hwnd);
      return 0;
    case WM_TIMER: {
      if (wparam == kHoldTimerId) {
        // החלון האמיתי לא נחשף בזמן. עדיף להסתיר מלהשאיר תלוי.
        ::KillTimer(hwnd, kHoldTimerId);
        End();
        return 0;
      }
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

void Begin(const std::wstring& title, HWND source, const Colors& colors) {
  {
    std::lock_guard<std::mutex> lock(g_mutex);
    g_title = title;
    if (colors.valid) {
      g_palette.strip = colors.strip;
      g_palette.tab = colors.tab;
      g_palette.body = colors.body;
      g_palette.border = colors.border;
      g_palette.text = colors.text;
    }
  }
  g_source.store(source);
  // התמונה של הגרירה הקודמת אינה שייכת לזו — עד שתגיע חדשה, שרטוט GDI.
  {
    std::lock_guard<std::mutex> lock(g_mutex);
    ReleaseTabBitmap();
  }
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
    ::SetLayeredWindowAttributes(g_window, 0, 225, LWA_ALPHA);
  }

  ::KillTimer(g_window, kHoldTimerId);
  ::InvalidateRect(g_window, nullptr, TRUE);
  ::SetTimer(g_window, kFollowTimerId, kFollowIntervalMs, nullptr);
  g_active.store(true);

  // מיקום ראשוני מיידי, כדי שהתצוגה לא תקפוץ מהפינה בפעימה הראשונה.
  MoveToCursor(g_window);
}

void SetImage(const unsigned char* rgba, int width, int height, double dpr) {
  if (!rgba || width <= 0 || height <= 0) return;

  BITMAPINFO info{};
  info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  info.bmiHeader.biWidth = width;
  // ⚠️ שלילי = top-down. `toByteData` מחזיר שורות מלמעלה למטה, ו-DIB
  // ברירת מחדל הוא bottom-up — בלי המינוס התמונה מגיעה הפוכה.
  info.bmiHeader.biHeight = -height;
  info.bmiHeader.biPlanes = 1;
  info.bmiHeader.biBitCount = 32;
  info.bmiHeader.biCompression = BI_RGB;

  void* bits = nullptr;
  const HDC screen = ::GetDC(nullptr);
  const HBITMAP bitmap = ::CreateDIBSection(screen, &info, DIB_RGB_COLORS,
                                            &bits, nullptr, 0);
  ::ReleaseDC(nullptr, screen);
  if (!bitmap || !bits) {
    if (bitmap) ::DeleteObject(bitmap);
    return;
  }

  // RGBA → BGRA. שני הפורמטים מוכפלים-מראש, ולכן די בהחלפת האדום והכחול.
  auto* dst = static_cast<unsigned char*>(bits);
  const size_t pixels = static_cast<size_t>(width) * height;
  for (size_t i = 0; i < pixels; ++i) {
    dst[i * 4 + 0] = rgba[i * 4 + 2];
    dst[i * 4 + 1] = rgba[i * 4 + 1];
    dst[i * 4 + 2] = rgba[i * 4 + 0];
    dst[i * 4 + 3] = rgba[i * 4 + 3];
  }

  const double scale = dpr > 0.1 ? dpr : 1.0;
  {
    std::lock_guard<std::mutex> lock(g_mutex);
    ReleaseTabBitmap();
    g_tab_bitmap = bitmap;
    g_tab_bitmap_w = width;
    g_tab_bitmap_h = height;
    g_tab_logical_w = static_cast<int>(width / scale + 0.5);
    g_tab_logical_h = static_cast<int>(height / scale + 0.5);
  }
  if (g_window) ::InvalidateRect(g_window, nullptr, TRUE);
}

void Freeze() {
  if (!g_window || !g_active.load()) return;
  // מפסיק לעקוב אחרי הסמן, אבל **נשאר גלוי במקום שבו שוחרר**.
  //
  // ⚠️ זה מה שמכסה את הפער שהמשתמש תיאר: פתיחת חלון לוקחת מאות
  // מילישניות, ובלי ההקפאה המסך ריק בדיוק בפרק הזמן שבו המשתמש מחכה
  // לראות תוצאה. עכשיו הרוח נשארת במקום שגררו אליו, והחלון האמיתי מחליף
  // אותה במקום להופיע אחרי כלום.
  ::KillTimer(g_window, kFollowTimerId);
  ::ShowWindow(g_window, SW_SHOWNOACTIVATE);
  ::SetTimer(g_window, kHoldTimerId, kHoldTimeoutMs, nullptr);
}

void End() {
  g_active.store(false);
  g_source.store(nullptr);
  if (!g_window) return;
  ::KillTimer(g_window, kFollowTimerId);
  ::KillTimer(g_window, kHoldTimerId);
  ::ShowWindow(g_window, SW_HIDE);
}

bool IsActive() { return g_active.load(); }

}  // namespace drag_preview
