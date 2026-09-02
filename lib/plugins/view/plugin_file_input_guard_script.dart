import 'package:flutter_inappwebview/flutter_inappwebview.dart';

// חסימת פתיחת סייר קבצים דרך אלמנט <input type="file"> ב-HTML של תוספים.
// בדפדפנים, לחיצה על input[type=file] פותחת את סייר הקבצים של מערכת ההפעלה.
// במצב סייפר ועמדות ציבוריות מדובר בפרצת אבטחה (kiosk escape).
// מניעת ברירת המחדל (preventDefault) בשלב ה-capture חוסמת את פתיחת הסייר.
const String _fileInputGuardJs = r'''
(function () {
  function isFileInput(target) {
    if (!target) return false;
    if (target.tagName === 'INPUT' && target.type === 'file') return true;
    if (target.closest && target.closest('input[type="file"]')) return true;
    return false;
  }
  window.addEventListener('click', function (e) {
    if (isFileInput(e.target)) {
      e.preventDefault();
      e.stopPropagation();
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        window.flutter_inappwebview.callHandler('otzaria_file_input_clicked');
      }
    }
  }, true);
})();
''';

/// סקריפט שחוסם פתיחת סייר קבצים מתוך אלמנט HTML input type=file בתוסף.
UserScript buildPluginFileInputGuardScript() {
  return UserScript(
    source: _fileInputGuardJs,
    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
    forMainFrameOnly: false,
  );
}
