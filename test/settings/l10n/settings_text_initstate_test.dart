import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// גוף `async` רץ סינכרונית עד ה-`await` הראשון, ולכן מתודה שנקראת מ-
/// `initState` מריצה את הקטע הזה בתוך `initState` עצמו. רישום תלות ב-
/// InheritedWidget שם זורק, ה-Future נכשל בשקט, והמסך נתקע על מצב הטעינה.
void main() {
  final forbidden = <RegExp>[
    RegExp(r'context\.settingsText\('),
    RegExp(r'context\.watch<'),
    RegExp(r'Theme\.of\(context\)'),
    RegExp(r'MediaQuery\.(of|sizeOf)\(context\)'),
    RegExp(r'Directionality\.of\(context\)'),
    RegExp(r'dependOnInheritedWidgetOfExactType<'),
  ];

  test('אין רישום תלות ב-InheritedWidget בקטע הסינכרוני שנקרא מ-initState', () {
    final violations = <String>[];

    for (final file in _dartFiles(Directory('lib'))) {
      final source = file.readAsStringSync();
      final initState = _bodyAfter(source, RegExp(r'void initState\(\)\s*\{'));
      if (initState == null) continue;

      final called = RegExp(
        r'(_[A-Za-z0-9_]+)\(',
      ).allMatches(initState).map((m) => m.group(1)!).toSet();

      for (final name in called) {
        final declaration = RegExp(
          r'\s' + RegExp.escape(name) + r'\([^)]*\)\s*(?:async\s*)?\{',
        );
        final body = _bodyAfter(source, declaration);
        if (body == null) continue;

        final syncPrefix = _beforeFirstAwait(body);
        for (final pattern in forbidden) {
          if (pattern.hasMatch(syncPrefix)) {
            violations.add('${file.path} :: $name → ${pattern.pattern}');
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'הקריאות האלו רצות בתוך initState ויזרקו. יש להזיז אותן אחרי ה-await '
          'הראשון, או לקרוא את הערך ב-build:\n${violations.join('\n')}',
    );
  });
}

Iterable<File> _dartFiles(Directory dir) => dir
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

/// גוף הבלוק שאחרי ההתאמה הראשונה ל-[start], לפי איזון סוגריים מסולסלים.
String? _bodyAfter(String source, RegExp start) {
  final match = start.firstMatch(source);
  if (match == null) return null;

  var depth = 0;
  for (var i = match.end - 1; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) return source.substring(match.end, i);
    }
  }
  return null;
}

String _beforeFirstAwait(String body) {
  final index = body.indexOf('await ');
  return index < 0 ? body : body.substring(0, index);
}
