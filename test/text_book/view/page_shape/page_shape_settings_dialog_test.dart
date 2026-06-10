// טסטים לדיאלוג הגדרות צורת הדף:
// 1. גופן הדיאלוג מיועד למפרשים התחתונים בלבד (התווית "גופן מפרשים תחתונים:"),
//    והמפרשים הצדדיים נשארים עם גופן המפרשים הגלובלי.
// 2. עדכון חי: כל שינוי (גופן, גודל, הדגשה) נשמר מיידית ומפעיל את
//    onSettingsChanged כדי שהמסך שמתחת לדיאלוג יתרענן בלי לסגור אותו.

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/text_book/view/page_shape/page_shape_settings_dialog.dart';

import '../../../test_helpers/memory_cache_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await Settings.init(cacheProvider: MemoryCacheProvider());
  });

  Future<void> pumpDialog(
    WidgetTester tester, {
    VoidCallback? onSettingsChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: PageShapeSettingsDialog(
            availableCommentators: const ['רש"י על בראשית'],
            bookTitle: 'בראשית',
            onSettingsChanged: onSettingsChanged,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('תווית הגופן מסייגת שהוא למפרשים התחתונים בלבד', (tester) async {
    await pumpDialog(tester);

    expect(find.text('גופן מפרשים תחתונים:'), findsOneWidget);
  });

  testWidgets('ללא בחירה שמורה - מוצג גופן ברירת המחדל', (tester) async {
    await pumpDialog(tester);

    // הדרופדאון הסגור מציג את התווית העברית של AppFonts.defaultFont
    expect(find.text('פרנק-רוהל'), findsOneWidget);
  });

  testWidgets('בחירת גופן נשמרת מיידית ומפעילה עדכון חי', (tester) async {
    var notified = 0;
    await pumpDialog(tester, onSettingsChanged: () => notified++);

    final dropdown = find.byType(DropdownButtonFormField<String>).last;
    await tester.ensureVisible(dropdown);
    await tester.pump();
    await tester.tap(dropdown);
    await tester.pumpAndSettle();

    await tester.tap(find.text('כתר').last);
    await tester.pumpAndSettle();

    expect(Settings.getValue<String>('page_shape_bottom_font'), 'KeterYG');
    expect(notified, greaterThan(0));
  });

  testWidgets('הגדלת גודל הגופן נשמרת מיידית ומפעילה עדכון חי', (tester) async {
    var notified = 0;
    await pumpDialog(tester, onSettingsChanged: () => notified++);

    final addButton =
        find.widgetWithIcon(IconButton, FluentIcons.add_24_regular);
    await tester.ensureVisible(addButton);
    await tester.pump();
    await tester.tap(addButton);
    await tester.pump();

    // ברירת המחדל 16 + לחיצה אחת = 17
    expect(
      Settings.getValue<double>('page_shape_commentary_font_size'),
      17.0,
    );
    expect(notified, greaterThan(0));
  });

  testWidgets('שינוי הדגשת פרשנים קשורים מפעיל עדכון חי', (tester) async {
    var notified = 0;
    await pumpDialog(tester, onSettingsChanged: () => notified++);

    final highlightSwitch =
        find.widgetWithText(SwitchListTile, 'הדגש פרשנים קשורים');
    await tester.ensureVisible(highlightSwitch);
    await tester.pump();
    await tester.tap(highlightSwitch);
    await tester.pump();

    expect(Settings.getValue<bool>('page_shape_global_highlight'), isTrue);
    expect(notified, greaterThan(0));
  });
}
