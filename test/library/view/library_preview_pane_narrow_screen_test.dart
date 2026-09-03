import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/library/view/library_browser.dart';
import 'package:otzaria/widgets/layout/adaptive_side_pane.dart';

/// מדמה את `_buildBodyRow` של [LibraryBrowser]: אותה חלונית, אותם פרמטרים
/// ואותו חישוב פתיחה — בלי כל ה-BLoCs שהמסך המלא דורש.
Widget _libraryBody({required bool preferenceEnabled}) {
  return MaterialApp(
    locale: const Locale('he', 'IL'),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Builder(
          builder: (context) {
            final isOpen = libraryPreviewPaneEnabled(
              screenWidth: MediaQuery.sizeOf(context).width,
              preferenceEnabled: preferenceEnabled,
            );
            return LayoutBuilder(
              builder: (ctx, constraints) {
                final widths = calculateLibraryPreviewPaneWidths(
                  availableWidth: constraints.maxWidth,
                  viewMode: 'grid',
                );
                return AdaptiveSidePane(
                  isOpen: isOpen,
                  alignment: AlignmentDirectional.centerStart,
                  mainContent: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: SizedBox(
                      key: const Key('grid'),
                      height: 80,
                      width: double.infinity,
                      child: Builder(
                        builder: (ctx) => GestureDetector(
                          onTap: () => _tappedBooks.add('ספר'),
                          child: const ColoredBox(
                            color: Color(0xFF00FF00),
                            child: Text('רשת הספרים'),
                          ),
                        ),
                      ),
                    ),
                  ),
                  paneContent: const Text('תצוגה מקדימה'),
                  paneWidth: widths.paneWidth,
                  minMainContentWidth: 200,
                  onClose: () {},
                  paneColor: Theme.of(ctx).colorScheme.surface,
                  isResizable: true,
                  minPaneWidth: widths.minPaneWidth,
                  maxPaneWidth: widths.maxPaneWidth,
                  onPaneWidthChanged: (_) {},
                  autoHandleResponsiveVisibility: false,
                  wrapPaneInFloatingPanel: false,
                );
              },
            );
          },
        ),
      ),
    ),
  );
}

final List<String> _tappedBooks = [];

void main() {
  setUp(_tappedBooks.clear);

  group('libraryPreviewPaneEnabled', () {
    test('מסך טלפון: החלונית כבויה גם כשההעדפה דולקת', () {
      expect(
        libraryPreviewPaneEnabled(screenWidth: 412, preferenceEnabled: true),
        isFalse,
      );
    });

    test('מסך רחב: ההעדפה קובעת', () {
      expect(
        libraryPreviewPaneEnabled(screenWidth: 1000, preferenceEnabled: true),
        isTrue,
      );
      expect(
        libraryPreviewPaneEnabled(screenWidth: 1000, preferenceEnabled: false),
        isFalse,
      );
    });
  });

  group('חלונית התצוגה המקדימה במסך צר', () {
    testWidgets('ברוחב טלפון רשת הספרים מקבלת את כל הרוחב ונשארת לחיצה', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_libraryBody(preferenceEnabled: true));
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byKey(const Key('grid'))).width,
        412,
        reason: 'החלונית חולקת את רוחב הטלפון עם הרשת',
      );

      await tester.tap(find.text('רשת הספרים'));
      expect(
        _tappedBooks,
        ['ספר'],
        reason: 'שכבת החלונית חוסמת את ההקשה על הרשת',
      );
    });

    testWidgets('ברוחב שולחני החלונית נפתחת לצד הרשת', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_libraryBody(preferenceEnabled: true));
      await tester.pumpAndSettle();

      final gridWidth = tester.getSize(find.byKey(const Key('grid'))).width;
      expect(gridWidth, lessThan(1200));
      expect(gridWidth, greaterThan(600));
      expect(find.text('תצוגה מקדימה'), findsOneWidget);
    });
  });
}
