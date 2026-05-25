import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/navigation/bloc/navigation_state.dart';
import 'package:otzaria/navigation/view/main_window_screen.dart';

void main() {
  group('resolveLibraryPageBuildDecision', () {
    test('מחזיר placeholder כשמסך הפתיחה אינו ספרייה והספרייה עוד לא נבנתה',
        () {
      final decision = resolveLibraryPageBuildDecision(
        hasCachedPage: false,
        previousLibraryEmptyState: null,
        isLibraryEmpty: false,
        currentScreen: Screen.reading,
      );

      expect(decision, LibraryPageBuildDecision.usePlaceholder);
    });

    test('בונה את הדף האמיתי כשנכנסים לראשונה למסך הספרייה', () {
      final decision = resolveLibraryPageBuildDecision(
        hasCachedPage: false,
        previousLibraryEmptyState: null,
        isLibraryEmpty: false,
        currentScreen: Screen.library,
      );

      expect(decision, LibraryPageBuildDecision.buildRealPage);
    });

    test('בונה מחדש את דף הספרייה כשמצב הריקות השתנה', () {
      final decision = resolveLibraryPageBuildDecision(
        hasCachedPage: true,
        previousLibraryEmptyState: false,
        isLibraryEmpty: true,
        currentScreen: Screen.reading,
      );

      expect(decision, LibraryPageBuildDecision.buildRealPage);
    });

    test('שומר את הדף הקיים כשאין שינוי מהותי', () {
      final decision = resolveLibraryPageBuildDecision(
        hasCachedPage: true,
        previousLibraryEmptyState: false,
        isLibraryEmpty: false,
        currentScreen: Screen.reading,
      );

      expect(decision, LibraryPageBuildDecision.keepExistingPage);
    });
  });
}
