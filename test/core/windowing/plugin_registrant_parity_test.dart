import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// שומר על התאמה בין טבלת התוספים ב-`RegisterPluginsMasked` לקובץ המיוצר
/// `generated_plugin_registrant.cc`.
///
/// ## למה יש בכלל טבלה כפולה
///
/// במודל A יש מנוע Flutter לכל חלון, וחלק מהתוספים אינם בטוחים לרישום
/// פעמיים באותו תהליך (`printing` בראשם). לכן החלון הראשון מקבל את
/// `RegisterPlugins` המלא, וחלונות נוספים מקבלים תת-קבוצה לפי מסכת ביטים —
/// ולשם כך נדרשת רשימה מפורשת בסדר זהה.
///
/// ## מה נשבר בלי השומר
///
/// תוסף חדש ב-`pubspec.yaml` נכנס לקובץ המיוצר בלבד. החלון הראשון יקבל
/// אותו, החלונות הנוספים לא — ו-`MissingPluginException` יופיע **רק בחלון
/// משני**, בלי שום שגיאת קומפילציה. גם שינוי בסדר שובר את המסכה בשקט:
/// הביטים ממופים למקומות ברשימה.
void main() {
  /// שמות התוספים בסדר שבו הקובץ המיוצר רושם אותם.
  ///
  /// `registry->GetRegistrarForPlugin("Name")` — השם הוא מקור האמת גם
  /// בטבלה הידנית, ולכן ההשוואה עליו ולא על שם הפונקציה.
  List<String> namesIn(String source) => RegExp(
    r'GetRegistrarForPlugin\("([^"]+)"\)',
  ).allMatches(source).map((m) => m.group(1)!).toList();

  /// שמות התוספים בטבלה הידנית: `{"Name", Fn}` בתוך `kEntries`.
  List<String> namesInMaskedTable(String source) {
    final table = RegExp(
      r'static const Entry kEntries\[\] = \{(.*?)\n  \};',
      dotAll: true,
    ).firstMatch(source);
    expect(
      table,
      isNotNull,
      reason:
          'לא נמצאה הטבלה kEntries ב-flutter_window.cpp — אם היא שונתה '
          'או הוסרה, יש לעדכן את השומר הזה יחד איתה.',
    );
    return RegExp(
      r'\{"([^"]+)"',
    ).allMatches(table!.group(1)!).map((m) => m.group(1)!).toList();
  }

  late String generated;
  late String runner;

  setUpAll(() {
    generated = File(
      'windows/flutter/generated_plugin_registrant.cc',
    ).readAsStringSync();
    runner = File('windows/runner/flutter_window.cpp').readAsStringSync();
  });

  test('הסורק מוצא את שתי הרשימות', () {
    // בלי הבדיקה הזאת, regex שנשבר היה הופך את השומר לירוק-תמיד.
    expect(namesIn(generated), isNotEmpty);
    expect(namesInMaskedTable(runner), isNotEmpty);
  });

  test('אותם תוספים, באותו סדר', () {
    expect(
      namesInMaskedTable(runner),
      namesIn(generated),
      reason:
          'טבלת התוספים של החלונות הנוספים אינה תואמת לקובץ המיוצר. יש '
          'לעדכן את kEntries ב-windows/runner/flutter_window.cpp ואת '
          'kAllPluginsMask שלידה.',
    );
  });

  test('kAllPluginsMask מכסה בדיוק את מספר התוספים', () {
    // ⚠️ המסכה היא ביט לכל מקום ברשימה. מסכה שנשארה מאחור מדלגת על התוסף
    // האחרון בשקט.
    final count = namesInMaskedTable(runner).length;
    final mask = RegExp(
      r'kAllPluginsMask = (0x[0-9A-Fa-f]+|\d+)',
    ).firstMatch(runner);
    expect(mask, isNotNull);
    final value = int.parse(
      mask!.group(1)!.startsWith('0x')
          ? mask.group(1)!.substring(2)
          : mask.group(1)!,
      radix: mask.group(1)!.startsWith('0x') ? 16 : 10,
    );
    expect(
      value,
      (1 << count) - 1,
      reason:
          'kAllPluginsMask צריכה להיות $count ביטים דלוקים '
          '(0x${((1 << count) - 1).toRadixString(16).toUpperCase()}).',
    );
  });

  test('ביט ה-printing מצביע על PrintingPlugin', () {
    // ⚠️ הביט הזה הוא ההחרגה היחידה בפועל: `printing` אינו בטוח לרישום
    // פעמיים בתהליך. אם מקומו ברשימה יזוז, החלון הנוסף יאבד תוסף אחר
    // ויקבל דווקא את זה.
    final names = namesInMaskedTable(runner);
    final bit = RegExp(
      r'kPrintingPluginBit = 1UL << (\d+)',
    ).firstMatch(runner);
    expect(bit, isNotNull);
    expect(names[int.parse(bit!.group(1)!)], 'PrintingPlugin');
  });
}
