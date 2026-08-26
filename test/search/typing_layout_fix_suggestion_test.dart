import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/search/view/layout_fix_suggestion_banner.dart';

/// issue #975 — הצעת תיקון-מקלדת חיה תוך כדי הקלדה, על הטקסט הגולמי.
/// כך פסיק ונקודה (המקשים של ת ו-ץ) נכללים בהצעה — בניגוד לשאילתה
/// המנורמלת של החיפוש, שממנה הם כבר נמחקו.
Widget _host(
  TextEditingController controller, {
  ValueChanged<String>? onApplied,
}) {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: TypingLayoutFixSuggestion(
          controller: controller,
          onApplied: onApplied,
        ),
      ),
    ),
  );
}

void main() {
  late TextEditingController controller;

  setUp(() {
    controller = TextEditingController();
  });

  tearDown(() {
    controller.dispose();
  });

  testWidgets('ההצעה מופיעה ונעלמת בעקבות ההקלדה', (tester) async {
    await tester.pumpWidget(_host(controller));
    expect(find.textContaining('האם התכוונת'), findsNothing);

    controller.text = 'akuo';
    await tester.pump();
    expect(find.textContaining('שלום'), findsOneWidget);

    controller.text = 'שלום';
    await tester.pump();
    expect(find.textContaining('האם התכוונת'), findsNothing);
  });

  testWidgets('פסיק ונקודה נכללים בהצעה — cshe, → בדיקת', (tester) async {
    // "בדיקת" במצב מקלדת אנגלי: ב=c ד=s י=h ק=e ת=פסיק
    controller.text = 'cshe,';
    await tester.pumpWidget(_host(controller));
    expect(find.textContaining('בדיקת'), findsOneWidget);
  });

  testWidgets('לחיצה מחליפה את תוכן השדה, מציבה סמן בסוף וקוראת ל-onApplied', (
    tester,
  ) async {
    String? applied;
    controller.text = ',urv';
    await tester.pumpWidget(_host(controller, onApplied: (s) => applied = s));

    // עצם ההצגה לא נוגעת בשדה — ההחלפה רק בלחיצה.
    expect(controller.text, ',urv');
    expect(applied, isNull);

    await tester.tap(find.byType(InkWell));
    await tester.pump();

    expect(controller.text, 'תורה');
    expect(controller.selection.baseOffset, 'תורה'.length);
    expect(applied, 'תורה');

    // אחרי ההחלפה הטקסט עברי — ההצעה נעלמת.
    expect(find.textContaining('האם התכוונת'), findsNothing);
  });
}
