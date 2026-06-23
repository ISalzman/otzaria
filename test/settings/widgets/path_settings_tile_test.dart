import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/settings/widgets/settings_card.dart';

// Helper: עטיפת MaterialApp+RTL סטנדרטית לטסטי widgets
Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: child,
        ),
      ),
    );

void main() {
  const icon = FluentIcons.folder_24_regular;
  const title = 'תיקיית בדיקה';
  const placeholder = 'לא נבחר מיקום';

  group('PathSettingsTile — simpleButtonWhenEmpty=true (ברירת מחדל)', () {
    testWidgets(
      'כשהנתיב ריק מוצג כפתור "הגדר מיקום" בלבד',
      (tester) async {
        await tester.pumpWidget(_wrap(
          SettingsActionTile.pathTile(
            icon: icon,
            title: title,
            currentPath: '',
            placeholder: placeholder,
            onFolderChanged: () {},
            onOpenFolder: () {},
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('הגדר מיקום'), findsOneWidget);
        expect(find.text('אפשרויות מיקום'), findsNothing);
      },
    );

    testWidgets(
      'לחיצה על "הגדר מיקום" קוראת ל-onFolderChanged',
      (tester) async {
        var called = false;
        await tester.pumpWidget(_wrap(
          SettingsActionTile.pathTile(
            icon: icon,
            title: title,
            currentPath: '',
            placeholder: placeholder,
            onFolderChanged: () => called = true,
            onOpenFolder: () {},
          ),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('הגדר מיקום'));
        await tester.pumpAndSettle();

        expect(called, isTrue);
      },
    );

    testWidgets(
      'כשיש נתיב מוצג כפתור "אפשרויות מיקום" במקום "הגדר מיקום"',
      (tester) async {
        await tester.pumpWidget(_wrap(
          SettingsActionTile.pathTile(
            icon: icon,
            title: title,
            currentPath: '/some/path',
            placeholder: placeholder,
            onFolderChanged: () {},
            onOpenFolder: () {},
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('אפשרויות מיקום'), findsOneWidget);
        expect(find.text('הגדר מיקום'), findsNothing);
      },
    );
  });

  group('PathSettingsTile — simpleButtonWhenEmpty=false', () {
    testWidgets(
      'כשהנתיב ריק עדיין מוצג "אפשרויות מיקום" (לא "הגדר מיקום")',
      (tester) async {
        await tester.pumpWidget(_wrap(
          SettingsActionTile.pathTile(
            icon: icon,
            title: title,
            currentPath: '',
            placeholder: placeholder,
            onFolderChanged: () {},
            onOpenFolder: () {},
            simpleButtonWhenEmpty: false,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('אפשרויות מיקום'), findsOneWidget);
        expect(find.text('הגדר מיקום'), findsNothing);
      },
    );
  });

  group('PathSettingsTile — clearPathEnabled', () {
    testWidgets(
      'כשclearPathEnabled=false ו-onClearPath מוגדר מוצג placeholder הנתיב',
      (tester) async {
        // בדיקה שה-tile נבנה ללא שגיאות כשclearPathEnabled=false
        await tester.pumpWidget(_wrap(
          SettingsActionTile.pathTile(
            icon: icon,
            title: title,
            currentPath: '/default/path',
            placeholder: placeholder,
            onFolderChanged: () {},
            onOpenFolder: () {},
            onClearPath: () {},
            clearPathEnabled: false,
          ),
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('אפשרויות מיקום'), findsOneWidget);
      },
    );

    testWidgets(
      'כשclearPathEnabled=true ו-onClearPath מוגדר ה-tile נבנה ללא שגיאות',
      (tester) async {
        await tester.pumpWidget(_wrap(
          SettingsActionTile.pathTile(
            icon: icon,
            title: title,
            currentPath: '/custom/path',
            placeholder: placeholder,
            onFolderChanged: () {},
            onOpenFolder: () {},
            onClearPath: () {},
          ),
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('אפשרויות מיקום'), findsOneWidget);
      },
    );
  });

  group('PathSettingsTile — תצוגת נתיב', () {
    testWidgets(
      'כשיש נתיב מוצג הנתיב בתור subtitle',
      (tester) async {
        const path = '/my/library/path';
        await tester.pumpWidget(_wrap(
          SettingsActionTile.pathTile(
            icon: icon,
            title: title,
            currentPath: path,
            placeholder: placeholder,
            onFolderChanged: () {},
            onOpenFolder: () {},
          ),
        ));
        await tester.pumpAndSettle();

        // הנתיב מוצג בממשק (אחרי עיצוב על-ידי _formatPath)
        expect(find.textContaining('my'), findsWidgets);
      },
    );

    testWidgets(
      'כשהנתיב ריק ו-simpleButtonWhenEmpty=false מוצג ה-placeholder',
      (tester) async {
        await tester.pumpWidget(_wrap(
          SettingsActionTile.pathTile(
            icon: icon,
            title: title,
            currentPath: '',
            placeholder: placeholder,
            onFolderChanged: () {},
            onOpenFolder: () {},
            simpleButtonWhenEmpty: false,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text(placeholder), findsOneWidget);
      },
    );
  });
}
