import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:otzaria/settings/dialogs/color_picker_dialog.dart';
import 'package:otzaria/theme/theme_exports.dart';

Future<void> _pumpPicker(
  WidgetTester tester, {
  required Color currentColor,
  required Color defaultColor,
  required ValueChanged<Color> onChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: ColorPickerTile(
            currentColor: currentColor,
            defaultColor: defaultColor,
            onChanged: onChanged,
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('שינוי צבע'));
  await tester.pumpAndSettle();
}

void main() {
  group('ColorPickerTile', () {
    testWidgets('שורה מציגה את שם הצבע הנבחר', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: ColorPickerTile(
                currentColor: AppSeedColors.red,
                defaultColor: AppSeedColors.defaultLight,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('אדום'), findsOneWidget);
      expect(find.text('שינוי צבע'), findsOneWidget);
    });

    testWidgets('צבע לא ידוע מקבל תווית "מותאם אישית"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: ColorPickerTile(
                currentColor: const Color(0xFF123456),
                defaultColor: AppSeedColors.defaultLight,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('צבע מותאם אישית'), findsOneWidget);
    });
  });

  group('Color picker dialog', () {
    testWidgets('לחיצה על swatch מעדכנת onChanged עם הצבע הנכון',
        (tester) async {
      final notified = <Color>[];
      await _pumpPicker(
        tester,
        currentColor: AppSeedColors.defaultLight,
        defaultColor: AppSeedColors.defaultLight,
        onChanged: notified.add,
      );

      await tester.tap(find.byTooltip('כחול'));
      await tester.pump();

      expect(notified, [AppSeedColors.blue]);
    });

    testWidgets('selected swatch מציג checkmark; swatches אחרים לא',
        (tester) async {
      await _pumpPicker(
        tester,
        currentColor: AppSeedColors.green,
        defaultColor: AppSeedColors.defaultLight,
        onChanged: (_) {},
      );

      // ב-state ההתחלתי בדיוק swatch אחד (הנבחר) מציג checkmark.
      expect(find.byIcon(FluentIcons.checkmark_24_regular), findsOneWidget);

      // לחיצה על swatch אחר מעבירה את ה-checkmark.
      await tester.tap(find.byTooltip('אדום'));
      await tester.pump();

      expect(find.byIcon(FluentIcons.checkmark_24_regular), findsOneWidget);
      // ושם הצבע הנבחר בכותרת מתעדכן.
      expect(find.text('אדום'), findsWidgets);
    });

    testWidgets('כפתור "איפוס" בוחר את defaultColor', (tester) async {
      final notified = <Color>[];
      await _pumpPicker(
        tester,
        currentColor: AppSeedColors.red,
        defaultColor: AppSeedColors.defaultDark,
        onChanged: notified.add,
      );

      await tester.tap(find.text('איפוס'));
      await tester.pump();

      expect(notified, [AppSeedColors.defaultDark]);
    });

    testWidgets('swatch חשוף ל-accessibility עם button+selected',
        (tester) async {
      await _pumpPicker(
        tester,
        currentColor: AppSeedColors.purple,
        defaultColor: AppSeedColors.defaultLight,
        onChanged: (_) {},
      );

      // מוודאים שה-swatch הנבחר חשוף כ-button + selected.
      // נחפש Semantics שמכיל גם button וגם isSelected עם הלייבל "סגול".
      final selectedSemantics = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label == 'סגול' &&
            w.properties.button == true &&
            w.properties.selected == true,
      );
      expect(selectedSemantics, findsOneWidget);

      // וגם swatch לא־נבחר נחשף כ-button אבל selected=false.
      final unselectedSemantics = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label == 'אדום' &&
            w.properties.button == true &&
            w.properties.selected == false,
      );
      expect(unselectedSemantics, findsOneWidget);
    });
  });
}
