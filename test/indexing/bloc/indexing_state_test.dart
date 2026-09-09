import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/indexing/bloc/indexing_state.dart';
import 'package:otzaria/indexing/models/indexing_run_result.dart';

void main() {
  const failure = IndexingFailure(
    bookTitle: 'ספר',
    bookPath: 'book.pdf',
    kind: IndexingFailureKind.passwordProtected,
    error: 'password',
  );

  group('IndexingComplete', () {
    test('ברירת המחדל נקייה', () {
      const state = IndexingComplete();

      expect(state.isClean, isTrue);
      expect(state.failures, isEmpty);
    });

    test('חושף השלמה עם כשלים', () {
      const state = IndexingComplete(failures: [failure]);

      expect(state.isClean, isFalse);
      expect(state.failureCount, 1);
    });

    test('אזהרת PDF חלקי אינה נספרת ככשל חוסם', () {
      const partial = IndexingFailure(
        bookTitle: 'ברכות',
        bookPath: 'ברכות.pdf',
        kind: IndexingFailureKind.partialPdf,
        error: '12 עמודים נשמטו',
      );
      const state = IndexingComplete(failures: [failure, partial, partial]);

      expect(state.isClean, isFalse);
      expect(state.blockingFailureCount, 1);
      expect(state.warningCount, 2);
    });

    test('השוויון משתנה כאשר רשימת הכשלים משתנה', () {
      expect(
        const IndexingComplete(),
        isNot(const IndexingComplete(failures: [failure])),
      );
    });
  });

  test('IndexingStopped שונה ממצב התחלתי', () {
    expect(IndexingStopped(), isNot(IndexingInitial()));
  });
}
