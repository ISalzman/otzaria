import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/library/bloc/library_event.dart';
import 'package:otzaria/library/bloc/library_state.dart';

void main() {
  group('RefreshLibrary.requestIds', () {
    test('ברירת המחדל — קבוצה ריקה, ושוויון לפי המזהים', () {
      expect(const RefreshLibrary().requestIds, isEmpty);
      expect(
        const RefreshLibrary(requestIds: {1}),
        equals(const RefreshLibrary(requestIds: {1})),
      );
      expect(
        const RefreshLibrary(requestIds: {1}),
        isNot(equals(const RefreshLibrary(requestIds: {2}))),
      );
    });
  });

  group('LibraryState.completedRefreshRequestIds', () {
    test('מדווח רק ב-copyWith שהעביר אותו במפורש, ומתאפס בכל copyWith אחר', () {
      const state = LibraryState();
      final completed = state.copyWith(completedRefreshRequestIds: {7, 8});
      expect(completed.completedRefreshRequestIds, {7, 8});

      // copyWith עוקב (למשל עדכון חיפוש) לא גורר את המזהים הלאה — אחרת
      // ה-listener היה מפעיל אינדוקס נוסף על state שאינו סיום רענון.
      final next = completed.copyWith(isSearching: true);
      expect(next.completedRefreshRequestIds, isNull);
    });

    test('משתתף בשוויון ה-state — emit עם מזהים שונה מ-emit בלעדיהם', () {
      const state = LibraryState();
      expect(
        state.copyWith(completedRefreshRequestIds: {1}),
        isNot(equals(state.copyWith())),
      );
    });
  });
}
