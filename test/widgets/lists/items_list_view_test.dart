import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/widgets/lists/items_list_view.dart';

class _Item {
  final String ref;
  final String? workspaceName;
  const _Item(this.ref, {this.workspaceName});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const items = [
    _Item('שבת עד:', workspaceName: 'גמרא'),
    _Item('ברכות ב.', workspaceName: 'גמרא'),
    _Item('הלכות שבת', workspaceName: 'הלכה'),
  ];

  Widget buildWidget({
    List<dynamic> testItems = items,
    bool Function(dynamic)? additionalFilter,
    String Function(dynamic)? searchKeyBuilder,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ItemsListView(
          items: testItems,
          onItemTap: (_, __, ___) {},
          onDelete: (_, __) {},
          onClearAll: (_) {},
          hintText: 'חיפוש...',
          emptyText: 'ריק',
          notFoundText: 'לא נמצא',
          clearAllText: 'נקה',
          additionalFilter: additionalFilter,
          searchKeyBuilder: searchKeyBuilder,
        ),
      ),
    );
  }

  group('ItemsListView', () {
    testWidgets('מציג את כל הפריטים כשאין additionalFilter', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildWidget());
      await tester.pump();

      expect(find.text('שבת עד:'), findsOneWidget);
      expect(find.text('ברכות ב.'), findsOneWidget);
      expect(find.text('הלכות שבת'), findsOneWidget);
    });

    testWidgets('additionalFilter מסנן פריטים לפי תנאי', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildWidget(
        additionalFilter: (item) => item.workspaceName == 'גמרא',
      ));
      await tester.pump();

      expect(find.text('שבת עד:'), findsOneWidget);
      expect(find.text('ברכות ב.'), findsOneWidget);
      expect(find.text('הלכות שבת'), findsNothing);
    });

    testWidgets('additionalFilter שמחזיר false לכל הפריטים מציג הודעת "לא נמצא"',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildWidget(
        additionalFilter: (_) => false,
      ));
      await tester.pump();

      expect(find.text('לא נמצא'), findsOneWidget);
      expect(find.text('שבת עד:'), findsNothing);
    });

    testWidgets('searchKeyBuilder מאפשר חיפוש לפי workspaceName', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildWidget(
        searchKeyBuilder: (item) =>
            '${item.ref as String} ${item.workspaceName as String? ?? ''}',
      ));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'הלכה');
      await tester.pump();

      expect(find.text('הלכות שבת'), findsOneWidget);
      expect(find.text('שבת עד:'), findsNothing);
      expect(find.text('ברכות ב.'), findsNothing);
    });

    testWidgets('ללא searchKeyBuilder - workspaceName לא נכלל בחיפוש',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildWidget());
      await tester.pump();

      // 'גמרא' מופיע רק ב-workspaceName, לא ב-ref
      await tester.enterText(find.byType(TextField).first, 'גמרא');
      await tester.pump();

      expect(find.text('לא נמצא'), findsOneWidget);
      expect(find.text('שבת עד:'), findsNothing);
      expect(find.text('ברכות ב.'), findsNothing);
    });

    testWidgets('additionalFilter ו-searchKeyBuilder פועלים יחדיו', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildWidget(
        additionalFilter: (item) => item.workspaceName == 'גמרא',
        searchKeyBuilder: (item) =>
            '${item.ref as String} ${item.workspaceName as String? ?? ''}',
      ));
      await tester.pump();

      // additionalFilter לגמרא בלבד
      expect(find.text('שבת עד:'), findsOneWidget);
      expect(find.text('ברכות ב.'), findsOneWidget);
      expect(find.text('הלכות שבת'), findsNothing);

      // חיפוש טקסט על גבי הסינון
      await tester.enterText(find.byType(TextField).first, 'שבת');
      await tester.pump();

      expect(find.text('שבת עד:'), findsOneWidget);
      expect(find.text('ברכות ב.'), findsNothing);
      expect(find.text('הלכות שבת'), findsNothing);
    });
  });
}
