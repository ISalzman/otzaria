import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/library/view/grid_items.dart';
import 'package:otzaria/models/books.dart';

void main() {
  Widget buildTestWidget({
    required Book book,
    bool showTopics = false,
    double width = 140,
  }) {
    return MaterialApp(
      home: Material(
        child: Center(
          child: SizedBox(
            width: width,
            child: BookGridItem(
              book: book,
              showTopics: showTopics,
              onBookClickCallback: () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('מציג tooltip כשהכותרת נחתכת עם ellipsis בתוך המילה האחרונה',
      (tester) async {
    final book = PdfBook(
      title: 'ספר עם שם ארוך מאודמאודשנחתךבאמצעהמילה',
      path: r'C:\library\folder\book.pdf',
      categoryPath: 'קטגוריה/פנימית/ארוכה',
    );

    await tester.pumpWidget(buildTestWidget(book: book, width: 100));
    await tester.pumpAndSettle();

    expect(find.byType(Tooltip), findsOneWidget);
  });

  testWidgets('מציג tooltip כשהנתיב או הנושאים נחתכים גם אם הכותרת קצרה',
      (tester) async {
    final book = PdfBook(
      title: 'א',
      path: r'C:\library\folder\book.pdf',
      topics: 'נתיב ארוך מאוד מאוד שנחתך בתצוגת הספריה ומחייב tooltip',
      categoryPath: 'קטגוריה ראשית, קטגוריה משנית, נתיב מלא ארוך',
    );

    await tester.pumpWidget(
      buildTestWidget(book: book, showTopics: true, width: 150),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip(r'C:\library\folder\book.pdf'), findsOneWidget);
    expect(find.byTooltip('א'), findsNothing);
  });
}
