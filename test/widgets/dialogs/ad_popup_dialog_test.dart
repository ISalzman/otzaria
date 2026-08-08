import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/services/support_organizations_service.dart';
import 'package:otzaria/widgets/dialogs/ad_popup_dialog.dart';

void main() {
  // Future שנוצר ב-zone של טסט אחד לא מריץ קולבקים ב-zone של הטסט הבא.
  // גם rootBundle ממטמן את ה-Future שלו, ולכן שניהם מאופסים.
  setUp(() {
    SupportOrganizationsService.resetCache();
    rootBundle.clear();
  });

  final listFinder = find.ancestor(
    of: find.text('קווי חירום'),
    matching: find.byType(SingleChildScrollView),
  );

  /// מרכיב את הדיאלוג ומחכה לרשימה. מטמון השירות משנה מתי ה-FutureBuilder
  /// מתעדכן, ולכן ממתינים לתנאי ולא למספר פעימות קבוע.
  Future<void> pumpUntilListReady(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AdPopupDialog(title: 'כותרת')),
    );
    for (var i = 0; i < 20 && listFinder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(listFinder, findsOneWidget);
  }

  /// מריץ את רצף האנימציות עד הסוף. הרצף משלב Future.delayed עם בקרי
  /// אנימציה, ולכן נדרשות פעימות קצובות — pumpAndSettle לבדו חוזר מיד
  /// בהמתנות שבין האנימציות ומשאיר טיימר תלוי.
  Future<void> finishAnimations(WidgetTester tester) async {
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  group('תצוגה מקובץ הנתונים', () {
    testWidgets('כל הארגונים שבקובץ מוצגים עם שם וטלפון', (tester) async {
      await pumpUntilListReady(tester);

      final organizations = await SupportOrganizationsService.load();
      final all = [
        ...organizations.emergencyLines,
        ...organizations.supportOrgs,
      ];
      expect(all, isNotEmpty);

      for (final org in all) {
        expect(
          find.text(org.name),
          findsOneWidget,
          reason: 'הארגון "${org.name}" לא מוצג',
        );
        expect(
          find.text(org.phone),
          findsOneWidget,
          reason: 'הטלפון של "${org.name}" לא מוצג',
        );
      }

      await finishAnimations(tester);
    });

    testWidgets('פתיחת כרטיס מציגה את אפשרויות הקו', (tester) async {
      await pumpUntilListReady(tester);
      await finishAnimations(tester);

      final organizations = await SupportOrganizationsService.load();
      final org = organizations.supportOrgs.last;
      expect(find.text('אפשרויות הקו:'), findsNothing);

      await tester.ensureVisible(find.text(org.name));
      await tester.pumpAndSettle();
      await tester.tap(find.text(org.name));
      await tester.pumpAndSettle();

      expect(find.text('אפשרויות הקו:'), findsOneWidget);
      expect(find.textContaining(org.details.split('\n').first), findsWidgets);
    });
  });

  group('ביצועים', () {
    testWidgets('לוגואי הארגונים מפוענחים בגודל מוקטן ולא ברזולוציית המקור', (
      tester,
    ) async {
      await pumpUntilListReady(tester);

      final logos = tester
          .widgetList<Image>(find.byType(Image))
          .map((image) => image.image)
          .whereType<ResizeImage>()
          .toList();

      expect(
        logos,
        isNotEmpty,
        reason: 'אף לוגו לא מפוענח מוקטן — הפענוח המוקטן הוסר',
      );
      for (final logo in logos) {
        expect(logo.width, isNotNull);
        expect(logo.width!, lessThanOrEqualTo(400));
      }

      await finishAnimations(tester);
    });

    testWidgets('הפינוי בסגירה משתמש באותו מפתח שבו נטענו הלוגואים', (
      tester,
    ) async {
      await pumpUntilListReady(tester);

      final organizations = await SupportOrganizationsService.load();
      final rendered = tester
          .widgetList<Image>(find.byType(Image))
          .map((image) => image.image)
          .toSet();

      // release מפנה לפי logoImage. מפתח שונה מזה שבו נטענה התמונה לא היה
      // מייצר שגיאה — הוא פשוט היה משאיר אותה ב-ImageCache בשקט.
      for (final org in [
        ...organizations.emergencyLines,
        ...organizations.supportOrgs,
      ]) {
        expect(
          rendered,
          contains(SupportOrganizationsService.logoImage(org.logo)),
        );
      }

      await finishAnimations(tester);
    });

    testWidgets('סגירת הפופאפ משחררת את הנתונים מהמטמון', (tester) async {
      await pumpUntilListReady(tester);
      await finishAnimations(tester);

      final whileOpen = SupportOrganizationsService.load();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();

      expect(
        identical(SupportOrganizationsService.load(), whileOpen),
        isFalse,
        reason: 'הנתונים נשארו במטמון אחרי סגירת הפופאפ',
      );
    });

    testWidgets('רשימת הארגונים לא נבנית מחדש בכל פריים של האנימציה', (
      tester,
    ) async {
      await pumpUntilListReady(tester);

      // דגימה לאורך כל רצף האנימציות — בנייה מחדש בכל פריים הייתה מייצרת
      // מופע ווידג'ט חדש בכל דגימה
      final instances = <SingleChildScrollView>{};
      for (var i = 0; i < 40; i++) {
        instances.add(tester.widget<SingleChildScrollView>(listFinder));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await finishAnimations(tester);

      expect(
        instances,
        hasLength(1),
        reason:
            'הרשימה נבנתה מחדש ${instances.length} פעמים — היא חייבת לעבור '
            'דרך child של AnimatedBuilder',
      );
    });
  });
}
