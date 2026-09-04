#ifndef RUNNER_DRAG_PREVIEW_WINDOW_H_
#define RUNNER_DRAG_PREVIEW_WINDOW_H_

#include <windows.h>

#include <string>

// תצוגת הכרטיסיה הנגררת **מחוץ** לחלון.
//
// ⚠️ למה נייטיב ולא Flutter. ה-`feedback` של `Draggable` מצויר בתוך
// ה-Overlay של החלון, ולכן הוא נחתך בגבולותיו: ברגע שהסמן יוצא, הכרטיסיה
// פשוט נעלמת. המשתמש לא רואה שהוא גורר משהו, ולכן גם אינו יכול לכוון
// לשורת המשימות או לחלון אחר.
//
// זהו חלון layered, topmost ו-transparent-to-hit-test שעוקב אחרי הסמן.
// `WS_EX_TRANSPARENT` הוא קריטי: בלעדיו החלון עצמו היה נמצא תחת הסמן,
// ו-`WindowFromPoint` היה מחזיר אותו במקום את היעד האמיתי.
namespace drag_preview {

// ממיר UTF-8 ל-UTF-16. ה-runner ממיר רק בכיוון ההפוך (`Utf8FromUtf16`),
// והכותרת מגיעה מ-Dart כ-UTF-8.
std::wstring Utf16FromUtf8(const std::string& utf8);

// מתחיל להציג תצוגת גרירה עם הכותרת הנתונה.
//
// התצוגה מוסתרת כשהסמן מעל **חלון המקור** [source] — שם ה-`feedback` של
// Flutter כבר עושה את העבודה, ושתי תצוגות במקביל היו נראות כשכפול.
//
// ⚠️ **המקור בלבד, ולא "כל חלון של התהליך".** הגרסה הראשונה הסתירה מעל
// כל חלון אוצריא, וזה יצר חור: ה-`feedback` של Flutter מצויר ב-Overlay
// של חלון המקור ונחתך בגבולותיו, ולכן מעל חלון אוצריא **אחר** לא נראתה
// לא התצוגה הנייטיבית ולא ה-feedback — הכרטיסיה הנגררת פשוט נעלמה, ונשאר
// רק קו ההכנסה הדק. זה בדיוק הרגע שבו המשתמש צריך לראות מה הוא מזיז.
void Begin(const std::wstring& title, HWND source);

// מסיים את הגרירה ומסתיר את התצוגה.
void End();

// האם תצוגת גרירה פעילה כרגע.
bool IsActive();

}  // namespace drag_preview

#endif  // RUNNER_DRAG_PREVIEW_WINDOW_H_
