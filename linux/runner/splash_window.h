#ifndef RUNNER_SPLASH_WINDOW_H_
#define RUNNER_SPLASH_WINDOW_H_

#include <gtk/gtk.h>

G_BEGIN_DECLS

// חלון splash נייטיב (GTK): חלון שקוף, ללא-מסגרת, keep-above, click-through,
// המציג את סמל האפליקציה הצף ממורכז על המסך, עם fade-in (הופעה) ו-fade-out
// (סגירה). נפרד מחלון ה-Flutter הראשי, שנשאר מוסתר עד שתוכנו מוכן.
//
// הערה: שקיפות דורשת compositor (קיים ברוב שולחנות העבודה; בלי זה הרקע ייראה
// אטום). מבוסס GLib timers על לולאת ה-GTK הראשית (אין thread נפרד — ב-Linux אין
// את בעיית ה-loader-lock של Windows).

// יוצר ומציג את חלון ה-splash עם fade-in. נקרא פעם אחת בעליית האפליקציה.
// no-op אם הסמל לא נטען או אין compositor מתאים.
void splash_window_show();

// מתחיל את אנימציית ה-fade-out; בסיומה החלון נהרס. אידמפוטנטי. נקרא דרך
// ה-method channel "otzaria/splash" בעת חשיפת החלון הראשי.
void splash_window_close();

G_END_DECLS

#endif  // RUNNER_SPLASH_WINDOW_H_
