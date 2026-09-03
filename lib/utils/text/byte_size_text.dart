/// עיצוב נפחי אחסון לתצוגה בתוך טקסט עברי.
library;

/// LEFT-TO-RIGHT ISOLATE ו-POP: בהקשר RTL המספר (תו חלש) ויחידת המידה
/// (תו חזק LTR) נפתרים כשני מקטעים נפרדים, ולכן "87.6 MB" מוצג הפוך.
/// הבידוד מקבע את הצמד כיחידת LTR אחת.
const String _ltrIsolateStart = '\u2066';
const String _ltrIsolateEnd = '\u2069';

/// עוטף ערך מספרי עם יחידת מידה לטינית כיחידת LTR אחת.
String ltrIsolate(String value) => '$_ltrIsolateStart$value$_ltrIsolateEnd';

/// נפח בייטים כמגה-בייט לתצוגה, למשל `87.6 MB`, מבודד לכיוון LTR.
String formatMegabytesLtr(num bytes, {int fractionDigits = 1}) =>
    ltrIsolate('${(bytes / 1024 / 1024).toStringAsFixed(fractionDigits)} MB');

/// התקדמות בייטים בטקסט עברי, למשל `87.6 MB מתוך 1820.4 MB`.
String formatMegabytesProgressHebrew(num done, num total) =>
    '${formatMegabytesLtr(done)} מתוך ${formatMegabytesLtr(total)}';
