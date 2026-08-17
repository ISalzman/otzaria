import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/tools/shamor_zachor/models/book_model.dart';
import 'package:otzaria/tools/shamor_zachor/widgets/mark_range_dialog.dart';

BookDetails _dafBook() => BookDetails(
  contentType: 'דף',
  parts: const [BookPart(name: 'ברכות', startPage: 2, endPage: 3)],
);

void main() {
  group('markRangeItemLabel', () {
    test('daf items get an amud mark', () {
      final book = _dafBook();
      final items = book.learnableItems;

      expect(markRangeItemLabel(book, items.first), 'ב׳.');
      expect(markRangeItemLabel(book, items[1]), 'ב׳:');
    });

    test('hierarchical items show their section path', () {
      final book = BookDetails(
        contentType: 'סעיף',
        parts: const [],
        sections: const [
          BookSection(
            id: 'a',
            title: 'פרק א',
            level: 1,
            startPage: 1,
            endPage: 1,
            children: [
              BookSection(
                id: 'a1',
                title: 'משנה א',
                level: 2,
                startPage: 1,
                endPage: 1,
              ),
            ],
          ),
        ],
      );

      expect(
        markRangeItemLabel(book, book.learnableItems.first),
        'פרק א · משנה א',
      );
    });
  });

  testWidgets('dialog returns the full range by default', (tester) async {
    final book = _dafBook();
    MarkRangeSelection? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showMarkRangeDialog(
                context: context,
                bookDetails: book,
                columnLabel: 'לימוד',
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('סימון טווח בעמודה "לימוד"'), findsOneWidget);
    expect(find.text('4 פריטים יסומנו'), findsOneWidget);

    await tester.tap(find.text('החל'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.fromIndex, 0);
    expect(result!.toIndex, book.learnableItems.last.absoluteIndex);
    expect(result!.value, isTrue);
  });

  testWidgets('cancelling returns null', (tester) async {
    final book = _dafBook();
    MarkRangeSelection? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showMarkRangeDialog(
                context: context,
                bookDetails: book,
                columnLabel: 'לימוד',
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ביטול'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
