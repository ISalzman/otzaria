#include "splash_window.h"

#include <limits.h>
#include <unistd.h>

#include <string>

namespace {

// גודל הסמל בפיקסלים לוגיים (תואם ל-Windows/macOS).
constexpr int kIconSize = 160;
// אטימות כוללת ~70% (תואם ל-SplashIcon המקורי).
constexpr double kIconAlpha = 0.70;
// קצב האנימציה.
constexpr guint kFadeIntervalMs = 15;            // ~60fps
constexpr double kFadeInPerTick = kIconAlpha / 13.0;   // ~195ms
constexpr double kFadeOutPerTick = kIconAlpha / 6.0;   // ~90ms
// זמן תצוגה מינימלי (מונע הבזק אם החשיפה מגיעה מוקדם).
constexpr gint64 kMinDisplayUs = 800 * 1000;  // 800ms במיקרו-שניות

GtkWidget* g_splash = nullptr;
GdkPixbuf* g_pixbuf = nullptr;
double g_alpha = 0.0;
bool g_closing = false;
bool g_close_requested = false;
gint64 g_shown_at_us = 0;
guint g_fade_timer = 0;

// נתיב קובץ ההרצה (תיקייה), כדי לאתר את data/flutter_assets שלצדו.
std::string ExecutableDir() {
  char buf[PATH_MAX];
  ssize_t len = readlink("/proc/self/exe", buf, sizeof(buf) - 1);
  if (len <= 0) {
    return std::string();
  }
  buf[len] = '\0';
  std::string path(buf);
  size_t pos = path.find_last_of('/');
  if (pos == std::string::npos) {
    return std::string();
  }
  return path.substr(0, pos);
}

// ציור הסמל הממורכז עם אטימות נוכחית (g_alpha) על רקע שקוף.
gboolean OnDraw(GtkWidget* widget, cairo_t* cr, gpointer) {
  // רקע שקוף לחלוטין.
  cairo_save(cr);
  cairo_set_operator(cr, CAIRO_OPERATOR_CLEAR);
  cairo_paint(cr);
  cairo_restore(cr);

  if (g_pixbuf == nullptr) {
    return FALSE;
  }
  const int w = gtk_widget_get_allocated_width(widget);
  const int h = gtk_widget_get_allocated_height(widget);
  const int pw = gdk_pixbuf_get_width(g_pixbuf);
  const int ph = gdk_pixbuf_get_height(g_pixbuf);
  if (pw <= 0 || ph <= 0) {
    return FALSE;
  }
  const double scale =
      MIN(static_cast<double>(w) / pw, static_cast<double>(h) / ph);
  const double dw = pw * scale;
  const double dh = ph * scale;
  cairo_translate(cr, (w - dw) / 2.0, (h - dh) / 2.0);
  cairo_scale(cr, scale, scale);
  gdk_cairo_set_source_pixbuf(cr, g_pixbuf, 0, 0);
  cairo_paint_with_alpha(cr, g_alpha);
  return FALSE;
}

// click-through: אזור קלט ריק כך שלחיצות עוברות דרך החלון.
void OnRealize(GtkWidget* widget, gpointer) {
  GdkWindow* gdk_window = gtk_widget_get_window(widget);
  if (gdk_window != nullptr) {
    cairo_region_t* empty = cairo_region_create();
    gdk_window_input_shape_combine_region(gdk_window, empty, 0, 0);
    cairo_region_destroy(empty);
  }
}

void DestroySplash() {
  if (g_fade_timer != 0) {
    g_source_remove(g_fade_timer);
    g_fade_timer = 0;
  }
  if (g_splash != nullptr) {
    gtk_widget_destroy(g_splash);
    g_splash = nullptr;
  }
  if (g_pixbuf != nullptr) {
    g_object_unref(g_pixbuf);
    g_pixbuf = nullptr;
  }
}

// טיק אנימציה: fade-in עד kIconAlpha, ואז החזקה; כשהתבקשה סגירה (ועבר זמן
// התצוגה המינימלי) — fade-out עד 0 ואז השמדה.
gboolean FadeTick(gpointer) {
  if (g_splash == nullptr) {
    g_fade_timer = 0;
    return G_SOURCE_REMOVE;
  }

  if (g_closing) {
    g_alpha -= kFadeOutPerTick;
    if (g_alpha <= 0.0) {
      DestroySplash();
      return G_SOURCE_REMOVE;
    }
    gtk_widget_queue_draw(g_splash);
    return G_SOURCE_CONTINUE;
  }

  // עדיין לא בסגירה.
  if (g_alpha < kIconAlpha) {
    g_alpha += kFadeInPerTick;
    if (g_alpha > kIconAlpha) g_alpha = kIconAlpha;
    gtk_widget_queue_draw(g_splash);
  }

  // אם התבקשה סגירה וכבר עבר זמן התצוגה המינימלי — עוברים ל-fade-out.
  if (g_close_requested &&
      (g_get_monotonic_time() - g_shown_at_us) >= kMinDisplayUs) {
    g_closing = true;
  }
  return G_SOURCE_CONTINUE;
}

}  // namespace

void splash_window_show() {
  if (g_splash != nullptr) {
    return;
  }

  const std::string icon_path =
      ExecutableDir() + "/data/flutter_assets/assets/icon/iconnew.png";
  GError* error = nullptr;
  g_pixbuf = gdk_pixbuf_new_from_file_at_scale(icon_path.c_str(), kIconSize,
                                               kIconSize, TRUE, &error);
  if (g_pixbuf == nullptr) {
    if (error != nullptr) g_error_free(error);
    return;  // ללא splash; האפליקציה ממשיכה.
  }

  GtkWidget* win = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_decorated(GTK_WINDOW(win), FALSE);
  gtk_window_set_resizable(GTK_WINDOW(win), FALSE);
  gtk_window_set_skip_taskbar_hint(GTK_WINDOW(win), TRUE);
  gtk_window_set_skip_pager_hint(GTK_WINDOW(win), TRUE);
  gtk_window_set_keep_above(GTK_WINDOW(win), TRUE);
  gtk_window_set_accept_focus(GTK_WINDOW(win), FALSE);
  gtk_window_set_focus_on_map(GTK_WINDOW(win), FALSE);
  gtk_window_set_type_hint(GTK_WINDOW(win), GDK_WINDOW_TYPE_HINT_SPLASHSCREEN);
  gtk_window_set_position(GTK_WINDOW(win), GTK_WIN_POS_CENTER);
  gtk_window_set_default_size(GTK_WINDOW(win), kIconSize, kIconSize);
  gtk_widget_set_app_paintable(win, TRUE);

  // visual עם ערוץ אלפא לשקיפות (דורש compositor).
  GdkScreen* screen = gtk_widget_get_screen(win);
  GdkVisual* rgba = gdk_screen_get_rgba_visual(screen);
  if (rgba != nullptr) {
    gtk_widget_set_visual(win, rgba);
  }

  g_signal_connect(win, "draw", G_CALLBACK(OnDraw), nullptr);
  g_signal_connect(win, "realize", G_CALLBACK(OnRealize), nullptr);

  g_alpha = 0.0;
  g_closing = false;
  g_close_requested = false;
  g_splash = win;

  gtk_widget_show_all(win);
  g_shown_at_us = g_get_monotonic_time();
  g_fade_timer = g_timeout_add(kFadeIntervalMs, FadeTick, nullptr);
}

void splash_window_close() {
  // מסמן בקשת סגירה; ה-FadeTick יעבור ל-fade-out אחרי זמן התצוגה המינימלי.
  // אם הטיימר כבר אינו פעיל (נדיר) — סוגרים מיד.
  g_close_requested = true;
  if (g_splash != nullptr && g_fade_timer == 0) {
    g_closing = true;
    g_fade_timer = g_timeout_add(kFadeIntervalMs, FadeTick, nullptr);
  }
}
