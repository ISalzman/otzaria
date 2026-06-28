import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/settings/dialogs/change_location_dialog.dart';

Widget _openButton(void Function(BuildContext) onOpen) => MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => onOpen(ctx),
            child: const Text('פתח'),
          ),
        ),
      ),
    );

Future<void> _openDialog(
  WidgetTester tester, {
  String currentPath = '/some/path',
  String folderName = 'ספרייה',
  bool canMoveContents = true,
  String? defaultPath,
  String? moveContentsWarning,
}) async {
  await tester.binding.setSurfaceSize(const Size(1200, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(_openButton((ctx) => showChangeLocationDialog(
        context: ctx,
        currentPath: currentPath,
        folderName: folderName,
        canMoveContents: canMoveContents,
        defaultPath: defaultPath,
        moveContentsWarning: moveContentsWarning,
      )));
  await tester.tap(find.text('פתח'));
  await tester.pumpAndSettle();
}

void main() {
  group('ChangeLocationResult', () {
    test('שומר newPath ו-moveContents=true', () {
      const r = ChangeLocationResult('/new/path', moveContents: true);
      expect(r.newPath, '/new/path');
      expect(r.moveContents, isTrue);
    });

    test('שומר newPath ו-moveContents=false', () {
      const r = ChangeLocationResult('/p', moveContents: false);
      expect(r.moveContents, isFalse);
    });
  });

  group('showChangeLocationDialog — מבנה', () {
    testWidgets('מציג כותרת עם שם התיקייה', (tester) async {
      await _openDialog(tester, folderName: 'ספריית אוצריא');
      expect(find.text('שינוי מיקום ספריית אוצריא'), findsOneWidget);
    });

    testWidgets('canMoveContents=true — שתי האפשרויות מוצגות', (tester) async {
      await _openDialog(tester, canMoveContents: true);
      expect(find.text('העבר תוכן תיקייה'), findsOneWidget);
      expect(find.text('שנה מיקום בלבד'), findsOneWidget);
    });

    testWidgets('canMoveContents=false — רק "שנה מיקום בלבד" מוצג',
        (tester) async {
      await _openDialog(tester, canMoveContents: false);
      expect(find.text('העבר תוכן תיקייה'), findsNothing);
      expect(find.text('שנה מיקום בלבד'), findsOneWidget);
    });

    testWidgets('canMoveContents=true — "העבר תוכן" נבחר כברירת מחדל',
        (tester) async {
      await _openDialog(tester, canMoveContents: true);

      final checkboxes =
          tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
      expect(checkboxes[0].value, isTrue, reason: '"העבר תוכן" — נבחר');
      expect(checkboxes[1].value, isFalse,
          reason: '"שנה מיקום בלבד" — לא נבחר');
    });

    testWidgets('לחיצה על "שנה מיקום בלבד" מחליפה את הבחירה', (tester) async {
      await _openDialog(tester, canMoveContents: true);

      await tester.tap(find.text('שנה מיקום בלבד'));
      await tester.pump();

      final checkboxes =
          tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
      expect(checkboxes[0].value, isFalse, reason: '"העבר תוכן" — בוטל');
      expect(checkboxes[1].value, isTrue, reason: '"שנה מיקום בלבד" — נבחר');
    });

    testWidgets('לחיצה חזרה על "העבר תוכן" משחזרת בחירה', (tester) async {
      await _openDialog(tester, canMoveContents: true);
      await tester.tap(find.text('שנה מיקום בלבד'));
      await tester.pump();
      await tester.tap(find.text('העבר תוכן תיקייה'));
      await tester.pump();

      final checkboxes =
          tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
      expect(checkboxes[0].value, isTrue);
    });

    testWidgets('defaultPath קיים — כרטיס ברירת מחדל מוצג', (tester) async {
      await _openDialog(tester, defaultPath: '/default/path');
      expect(find.text('מיקום ברירת מחדל'), findsOneWidget);
    });

    testWidgets('defaultPath=null — כרטיס ברירת מחדל לא מוצג', (tester) async {
      await _openDialog(tester, defaultPath: null);
      expect(find.text('מיקום ברירת מחדל'), findsNothing);
    });

    testWidgets('כשcurrentPath==defaultPath כפתור "השתמש בברירת מחדל" מושבת',
        (tester) async {
      const path = '/default/path';
      await _openDialog(tester, currentPath: path, defaultPath: path);

      final btnFinder = find.ancestor(
        of: find.text('השתמש בברירת מחדל'),
        matching: find.byType(FilledButton),
      );
      expect(btnFinder, findsOneWidget);
      expect((tester.widget(btnFinder) as FilledButton).onPressed, isNull);
    });

    testWidgets('כשcurrentPath!=defaultPath כפתור "השתמש בברירת מחדל" פעיל',
        (tester) async {
      await _openDialog(tester,
          currentPath: '/other/path', defaultPath: '/default/path');

      final btnFinder = find.ancestor(
        of: find.text('השתמש בברירת מחדל'),
        matching: find.byType(FilledButton),
      );
      expect((tester.widget(btnFinder) as FilledButton).onPressed, isNotNull);
    });

    testWidgets('לחיצת ביטול סוגרת את הדיאלוג', (tester) async {
      await _openDialog(tester, folderName: 'ספרייה');
      await tester.tap(find.text('ביטול'));
      await tester.pumpAndSettle();
      expect(find.text('שינוי מיקום ספרייה'), findsNothing);
    });

    testWidgets('אזהרת העברה מוצגת כש"העבר תוכן" נבחר', (tester) async {
      await _openDialog(tester, moveContentsWarning: 'התוכנה תיטען מחדש');
      expect(find.text('התוכנה תיטען מחדש'), findsOneWidget);
    });

    testWidgets('אזהרת העברה נעלמת כשעוברים ל"שנה מיקום בלבד"', (tester) async {
      await _openDialog(tester, moveContentsWarning: 'התוכנה תיטען מחדש');
      await tester.tap(find.text('שנה מיקום בלבד'));
      await tester.pump();
      expect(find.text('התוכנה תיטען מחדש'), findsNothing);
    });

    testWidgets('ללא moveContentsWarning — אין אזהרה', (tester) async {
      await _openDialog(tester);
      expect(find.byIcon(FluentIcons.info_24_regular), findsNothing);
    });
  });

  group('makeChangeLocationCallback — גזירת canMoveContents', () {
    Future<void> openCallback(
      WidgetTester tester,
      Future<void> Function(BuildContext) cb,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_openButton((ctx) => cb(ctx)));
      await tester.tap(find.text('פתח'));
      await tester.pumpAndSettle();
    }

    testWidgets('onAfterMove=null → אפשרות "העבר תוכן" לא מוצגת',
        (tester) async {
      final cb = makeChangeLocationCallback(
        currentPath: '/some/path',
        folderName: 'ספרייה',
        onPathChanged: (_) async {},
        onAfterMove: null,
      );
      await openCallback(tester, cb);
      expect(find.text('העבר תוכן תיקייה'), findsNothing);
    });

    testWidgets('currentPath ריק → "העבר תוכן" לא מוצג גם כשonAfterMove מוגדר',
        (tester) async {
      final cb = makeChangeLocationCallback(
        currentPath: '',
        folderName: 'ספרייה',
        onPathChanged: (_) async {},
        onAfterMove: (_) async {},
      );
      await openCallback(tester, cb);
      expect(find.text('העבר תוכן תיקייה'), findsNothing);
    });

    testWidgets('onAfterMove מוגדר + currentPath לא ריק → "העבר תוכן" מוצג',
        (tester) async {
      final cb = makeChangeLocationCallback(
        currentPath: '/some/path',
        folderName: 'ספרייה',
        onPathChanged: (_) async {},
        onAfterMove: (_) async {},
      );
      await openCallback(tester, cb);
      expect(find.text('העבר תוכן תיקייה'), findsOneWidget);
    });

    testWidgets('defaultPath מועבר לדיאלוג', (tester) async {
      final cb = makeChangeLocationCallback(
        currentPath: '/some/path',
        folderName: 'ספרייה',
        onPathChanged: (_) async {},
        defaultPath: '/default',
      );
      await openCallback(tester, cb);
      expect(find.text('מיקום ברירת מחדל'), findsOneWidget);
    });
  });
}
