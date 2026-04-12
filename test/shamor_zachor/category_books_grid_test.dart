import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:otzaria/tools/shamor_zachor/models/book_model.dart';
import 'package:otzaria/tools/shamor_zachor/models/progress_model.dart';
import 'package:otzaria/tools/shamor_zachor/providers/shamor_zachor_data_provider.dart';
import 'package:otzaria/tools/shamor_zachor/providers/shamor_zachor_progress_provider.dart';
import 'package:otzaria/tools/shamor_zachor/widgets/category_books_grid.dart';

class _FakeDataProvider extends ShamorZachorDataProvider {
  _FakeDataProvider(this.removeCompleter);

  final Completer<void> removeCompleter;
  int? removedBookId;

  @override
  Future<void> removeCustomBook({
    required String categoryName,
    required String bookName,
    int? bookId,
    int? categoryId,
  }) async {
    removedBookId = bookId;
    await removeCompleter.future;
  }
}

class _FakeProgressProvider extends ShamorZachorProgressProvider {
  _FakeProgressProvider(this.clearCompleter);

  final Completer<void> clearCompleter;
  int? clearedBookId;

  @override
  Map<String, PageProgress> getProgressForBookById(int bookId) => {};

  @override
  String? getCompletionDateSyncById(int bookId) => null;

  @override
  bool isBookCompletedById(int bookId, BookDetails bookDetails) => false;

  @override
  bool isBookConsideredInProgressById(int bookId, BookDetails bookDetails) =>
      false;

  @override
  Future<void> clearBookProgressById(
    int bookId, {
    String? categoryName,
    String? bookName,
    BookDetails? bookDetails,
  }) async {
    clearedBookId = bookId;
    await clearCompleter.future;
  }
}

void main() {
  testWidgets('removes book locally before async providers finish',
      (tester) async {
    final removeCompleter = Completer<void>();
    final clearCompleter = Completer<void>();
    final dataProvider = _FakeDataProvider(removeCompleter);
    final progressProvider = _FakeProgressProvider(clearCompleter);

    final category = BookCategory(
      name: 'תלמוד בבלי',
      contentType: 'text',
      books: {
        'ברכות': BookDetails(
          contentType: 'text',
          isCustom: true,
          id: 42,
          categoryPath: 'תלמוד בבלי',
          parts: const [
            BookPart(name: 'ראשי', startPage: 1, endPage: 1),
          ],
        ),
      },
      defaultStartPage: 1,
      isCustom: false,
      sourceFile: 'test',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ShamorZachorDataProvider>.value(
            value: dataProvider,
          ),
          ChangeNotifierProvider<ShamorZachorProgressProvider>.value(
            value: progressProvider,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CategoryBooksGrid(
              categoryName: 'תלמוד בבלי',
              topLevelName: 'תלמוד בבלי',
              category: category,
              onBookSelected: (_, __, ___) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ברכות'), findsOneWidget);

    await tester.tap(find.byTooltip('הסר ספר'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('הסר'));
    await tester.pumpAndSettle();

    expect(find.text('ברכות'), findsNothing);
    expect(progressProvider.clearedBookId, 42);

    clearCompleter.complete();
    removeCompleter.complete();
    await tester.pumpAndSettle();

    expect(dataProvider.removedBookId, 42);
  });
}
