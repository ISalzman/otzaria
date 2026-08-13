// Regression: רוחב עמודת הטקסט חושב כאחוז מהרוחב הפנוי, ולכן פתיחת חלונית צד
// (הערות/מפרשים/ניווט) הצרה את הטקסט. הבסיס הוא רוחב אזור הקריאה המלא,
// והרוחב הפנוי רק מגביל אותו כשאין מקום.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/widgets/layout/adaptive_side_pane.dart';
import 'package:otzaria/widgets/layout/reading_area_width.dart';

void main() {
  group('resolveTextColumnMaxWidth', () {
    test('רמה מחושבת מרוחב אזור הקריאה, לא מהרוחב הפנוי', () {
      expect(
        resolveTextColumnMaxWidth(
          setting: -11,
          availableWidth: 1200,
          baseWidth: 1800,
        ),
        closeTo(810, 0.001),
      );
    });

    test('אותו רוחב עם חלונית פתוחה וסגורה', () {
      double widthFor(double available) => resolveTextColumnMaxWidth(
        setting: -11,
        availableWidth: available,
        baseWidth: 1800,
      );

      expect(widthFor(1800), widthFor(1200));
    });

    test('מצטמצם רק כשאין מקום', () {
      expect(
        resolveTextColumnMaxWidth(
          setting: -2,
          availableWidth: 700,
          baseWidth: 1800,
        ),
        700,
      );
    });

    test('0 = ללא הגבלה', () {
      expect(
        resolveTextColumnMaxWidth(
          setting: 0,
          availableWidth: 1200,
          baseWidth: 1800,
        ),
        0,
      );
    });

    test('ערך חיובי (פורמט ישן) נשמר, ומוגבל לרוחב הפנוי', () {
      expect(
        resolveTextColumnMaxWidth(
          setting: 900,
          availableWidth: 1200,
          baseWidth: 1800,
        ),
        900,
      );
      expect(
        resolveTextColumnMaxWidth(
          setting: 900,
          availableWidth: 600,
          baseWidth: 1800,
        ),
        600,
      );
    });
  });

  testWidgets('AdaptiveSidePane מספק רוחב אזור קריאה קבוע בפתיחת החלונית', (
    tester,
  ) async {
    double? areaWidth;
    double? availableWidth;
    final isOpen = ValueNotifier<bool>(false);
    addTearDown(isOpen.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 800,
            height: 600,
            child: ValueListenableBuilder<bool>(
              valueListenable: isOpen,
              builder: (context, open, _) => AdaptiveSidePane(
                isOpen: open,
                onClose: () => isOpen.value = false,
                paneWidth: 200,
                minMainContentWidth: 300,
                paneContent: const SizedBox.expand(),
                mainContent: Builder(
                  builder: (context) {
                    areaWidth = ReadingAreaWidth.maybeOf(context);
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        availableWidth = constraints.maxWidth;
                        return const SizedBox.expand();
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(areaWidth, 800);
    expect(availableWidth, 800);

    isOpen.value = true;
    await tester.pumpAndSettle();

    expect(availableWidth, lessThan(800));
    expect(areaWidth, 800);
  });

  testWidgets('פאנל מקונן לא דורס את בסיס הפאנל החיצוני', (tester) async {
    double? areaWidth;
    double? availableWidth;
    final outerOpen = ValueNotifier<bool>(false);
    addTearDown(outerOpen.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 800,
            height: 600,
            child: ValueListenableBuilder<bool>(
              valueListenable: outerOpen,
              builder: (context, open, _) => AdaptiveSidePane(
                isOpen: open,
                onClose: () => outerOpen.value = false,
                paneWidth: 200,
                minMainContentWidth: 300,
                paneContent: const SizedBox.expand(),
                mainContent: AdaptiveSidePane(
                  isOpen: false,
                  onClose: () {},
                  paneWidth: 150,
                  minMainContentWidth: 200,
                  paneContent: const SizedBox.expand(),
                  mainContent: Builder(
                    builder: (context) {
                      areaWidth = ReadingAreaWidth.maybeOf(context);
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          availableWidth = constraints.maxWidth;
                          return const SizedBox.expand();
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(areaWidth, 800);

    outerOpen.value = true;
    await tester.pumpAndSettle();

    expect(availableWidth, lessThan(800));
    expect(areaWidth, 800);
  });
}
