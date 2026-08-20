/// המרת ספרות לגליפים עיליים (¹²³…) — מקור יחיד לכל מסלולי הרינדור.
library;

/// מיפוי ספרה → ספרת-עילית יוניקוד. 1–3 בבלוק Latin-1 (U+00B9/B2/B3),
/// השאר בבלוק Superscripts (U+2070, U+2074–U+2079) — נקודות הקוד הקנוניות.
const Map<String, String> _superscriptDigits = {
  '0': '⁰',
  '1': '¹',
  '2': '²',
  '3': '³',
  '4': '⁴',
  '5': '⁵',
  '6': '⁶',
  '7': '⁷',
  '8': '⁸',
  '9': '⁹',
};

final RegExp _digitsOnly = RegExp(r'^[0-9]+$');

/// מחזיר את [text] כספרות-עיליות יוניקוד, או null אם אינו ספרות בלבד.
String? superscriptDigitsOrNull(String text) {
  if (!_digitsOnly.hasMatch(text)) return null;
  return text.split('').map((d) => _superscriptDigits[d]!).join();
}
