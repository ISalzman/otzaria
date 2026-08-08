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
