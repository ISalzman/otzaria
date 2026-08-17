/// עיצוב מספרי-סידור לרשימות ממוספרות. משותף לכל הממירים — Word ו-ODT
/// מגדירים שמות שונים לאותם פורמטים, אך המספרים עצמם זהים.
library;

/// 1→a, 26→z, 27→aa … (bijective base-26).
String toLatinLetters(int n, {required bool upper}) {
  if (n <= 0) return '$n';
  final base = upper ? 65 : 97;
  final chars = <int>[];
  var x = n;
  while (x > 0) {
    x--;
    chars.add(base + (x % 26));
    x ~/= 26;
  }
  return String.fromCharCodes(chars.reversed);
}

/// ממיר מספר למספרה רומית (1–3999), אחרת מחזיר ספרות.
String toRomanNumeral(int n) {
  if (n <= 0 || n > 3999) return '$n';
  const vals = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
  const syms = [
    'M',
    'CM',
    'D',
    'CD',
    'C',
    'XC',
    'L',
    'XL',
    'X',
    'IX',
    'V',
    'IV',
    'I',
  ];
  final buf = StringBuffer();
  var x = n;
  for (var i = 0; i < vals.length; i++) {
    while (x >= vals[i]) {
      buf.write(syms[i]);
      x -= vals[i];
    }
  }
  return buf.toString();
}

/// ממיר מספר לאות עברית (גימטרייה) ללא גרשיים.
/// מדויק עד 499; מעבר לכך נופל לספרות (רשימות ארוכות כאלה נדירות).
String toHebrewNumeral(int n) {
  if (n <= 0 || n > 499) return '$n';
  const ones = ['', 'א', 'ב', 'ג', 'ד', 'ה', 'ו', 'ז', 'ח', 'ט'];
  const tens = ['', 'י', 'כ', 'ל', 'מ', 'נ', 'ס', 'ע', 'פ', 'צ'];
  const hundreds = ['', 'ק', 'ר', 'ש', 'ת'];
  final buf = StringBuffer();
  var x = n;
  if (x >= 100) {
    buf.write(hundreds[x ~/ 100]);
    x %= 100;
  }
  if (x == 15) {
    buf.write('טו');
  } else if (x == 16) {
    buf.write('טז');
  } else {
    if (x >= 10) {
      buf.write(tens[x ~/ 10]);
      x %= 10;
    }
    if (x > 0) buf.write(ones[x]);
  }
  return buf.toString();
}
