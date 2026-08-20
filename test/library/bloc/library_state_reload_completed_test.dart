import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/library/bloc/library_state.dart';
import 'package:otzaria/library/models/library.dart';

/// issue #895 — כרטיס "מערכת" מרענן את גרסת הספרייה לפי המעבר הזה; אם התנאי
/// יישבר, התצוגה תישאר עם גרסה ישנה אחרי עדכון ספרייה.
void main() {
  final library = Library(categories: []);

  group('LibraryState.reloadCompleted', () {
    test('מעבר מטעינה לטעון עם ספרייה — true', () {
      final previous = LibraryState(isLoading: true, library: library);
      final current = LibraryState(isLoading: false, library: library);
      expect(LibraryState.reloadCompleted(previous, current), isTrue);
    });

    test('סיום טעינה בלי ספרייה (כשל) — false', () {
      const previous = LibraryState(isLoading: true);
      const current = LibraryState(isLoading: false, error: 'שגיאה');
      expect(LibraryState.reloadCompleted(previous, current), isFalse);
    });

    test('לא היה בטעינה — false', () {
      final previous = LibraryState(isLoading: false, library: library);
      final current = LibraryState(isLoading: false, library: library);
      expect(LibraryState.reloadCompleted(previous, current), isFalse);
    });

    test('עדיין בטעינה — false', () {
      final previous = LibraryState(isLoading: true, library: library);
      final current = LibraryState(isLoading: true, library: library);
      expect(LibraryState.reloadCompleted(previous, current), isFalse);
    });
  });
}
