import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/library/bloc/library_state.dart';
import 'package:otzaria/navigation/view/main_window_screen.dart';
import 'package:otzaria/settings/engine/settings_repository.dart';

void main() {
  group('HebrewBooks settings.changed', () {
    test('שולח את הנתיב החדש עם מפתח ההגדרה הציבורי', () {
      const path = '/books/hebrewbooks';
      final state = const LibraryState().copyWith(
        changedHebrewBooksPath: path,
      );

      expect(shouldDispatchHebrewBooksPathChange(state), isTrue);
      expect(hebrewBooksPathSettingsChangedPayload(path), {
        'key': SettingsRepository.keyHebrewBooksPath,
        'newValue': path,
      });
    });

    test('שולח גם ניקוי נתיב', () {
      const state = LibraryState(changedHebrewBooksPath: '');

      expect(shouldDispatchHebrewBooksPathChange(state), isTrue);
      expect(hebrewBooksPathSettingsChangedPayload(''), {
        'key': SettingsRepository.keyHebrewBooksPath,
        'newValue': '',
      });
    });

    test('מתעלם ממצב ספרייה שאינו שינוי נתיב', () {
      expect(
        shouldDispatchHebrewBooksPathChange(const LibraryState()),
        isFalse,
      );
    });
  });
}
