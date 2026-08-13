import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/search/view/external_result_title_row.dart';
import 'package:otzaria/search/view/search_result_source_tag.dart';

/// רוחב שורת הכותרת בפריסה הצרה ביותר שהמסך מייצר: אזור התוכן המזערי
/// (300) פחות שולי הרשימה, שולי הכרטיס, האייקון והרווח שאחריו.
const _narrowRowWidth = 208.0;
const _wideRowWidth = 700.0;

const _rowKey = Key('row-host');

Widget _host({required double width, required Widget child}) => MaterialApp(
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      body: Center(
        child: SizedBox(key: _rowKey, width: width, child: child),
      ),
    ),
  ),
);

/// המרחק של הווידג'ט מקצה השורה השמאלי — שם יושבים התגית וכפתור ההעתקה.
double _distanceFromLeftEdge(WidgetTester tester, Finder finder) {
  return tester.getTopLeft(finder).dx -
      tester.getTopLeft(find.byKey(_rowKey)).dx;
}

void main() {
  group('ExternalResultTitleRow', () {
    testWidgets('התגית וכפתור ההעתקה נעולים לקצה השורה בכל אורך כותרת', (
      tester,
    ) async {
      final distances = <double>[];
      for (final title in ['אב', 'שבת', 'ליקוטי מוהר"ן תניינא']) {
        await tester.pumpWidget(
          _host(
            width: _wideRowWidth,
            child: ExternalResultTitleRow(
              title: title,
              hitCount: 12,
              sourceTag: 'היברובוקס',
              copyText: 'גזיר',
            ),
          ),
        );
        distances.add(
          _distanceFromLeftEdge(tester, find.byType(SearchResultSourceTag)),
        );
      }
      expect(distances.toSet(), hasLength(1));
    });

    testWidgets('שורה צרה אינה גולשת — הכיתוב מתקצר למספר בלבד', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          width: _narrowRowWidth,
          child: const ExternalResultTitleRow(
            title: 'ספר עם שם ארוך במיוחד שאינו נכנס לשורה',
            hitCount: 128,
            sourceTag: 'היברובוקס',
            copyText: 'גזיר',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('128'), findsOneWidget);
      expect(find.text('128 תוצאות בספר'), findsNothing);
    });

    testWidgets('שם מדור ארוך מהתוסף אינו מגלש את השורה', (tester) async {
      await tester.pumpWidget(
        _host(
          width: _narrowRowWidth,
          child: ExternalResultTitleRow(
            title: 'ספר',
            hitCount: 3,
            sourceTag: 'מ' * 120,
            copyText: 'גזיר',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(SearchResultSourceTag)).width,
        lessThanOrEqualTo(_narrowRowWidth * 0.3 + 0.5),
      );
    });

    testWidgets('שורה רחבה נושאת את הכיתוב המלא', (tester) async {
      await tester.pumpWidget(
        _host(
          width: _wideRowWidth,
          child: const ExternalResultTitleRow(
            title: 'ספר',
            hitCount: 128,
            sourceTag: 'היברובוקס',
          ),
        ),
      );
      expect(find.text('128 תוצאות בספר'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('מופע יחיד מנוסח ביחיד', (tester) async {
      await tester.pumpWidget(
        _host(
          width: _wideRowWidth,
          child: const ExternalResultTitleRow(
            title: 'ספר',
            hitCount: 1,
            sourceTag: 'היברובוקס',
          ),
        ),
      );
      expect(find.text('תוצאה אחת בספר'), findsOneWidget);
    });

    testWidgets('בלי גזיר אין כפתור העתקה; עם גזיר הוא מעתיק אותו ללוח', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          width: _wideRowWidth,
          child: const ExternalResultTitleRow(
            title: 'ספר',
            hitCount: 2,
            sourceTag: 'היברובוקס',
          ),
        ),
      );
      expect(find.byType(IconButton), findsNothing);

      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(
        _host(
          width: _wideRowWidth,
          child: const ExternalResultTitleRow(
            title: 'ספר',
            hitCount: 2,
            sourceTag: 'היברובוקס',
            copyText: 'גזיר הטקסט שנמצא',
          ),
        ),
      );
      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(copied, 'גזיר הטקסט שנמצא');
    });
  });
}
