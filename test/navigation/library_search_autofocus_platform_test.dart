import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/navigation/view/main_window_screen.dart';

/// מיקוד אוטומטי של שדה החיפוש בכניסה למסך הספרייה — שולחני בלבד.
///
/// המסך עצמו כבד מדי לבנייה בטסט, ולכן נבדק כאן התנאי שדרכו עוברות שתי
/// הכניסות לספרייה ב-MainWindowScreen (מעבר מסך, ולחיצה על פריט הניווט).
void main() {
  group('shouldAutofocusLibrarySearch', () {
    test('במובייל השדה אינו ממוקד — המקלדת לא נפתחת בכל כניסה', () {
      expect(shouldAutofocusLibrarySearch(TargetPlatform.android), isFalse);
      expect(shouldAutofocusLibrarySearch(TargetPlatform.iOS), isFalse);
    });

    test('בשולחני השדה ממוקד — המשתמש מקליד מיד', () {
      expect(shouldAutofocusLibrarySearch(TargetPlatform.windows), isTrue);
      expect(shouldAutofocusLibrarySearch(TargetPlatform.linux), isTrue);
      expect(shouldAutofocusLibrarySearch(TargetPlatform.macOS), isTrue);
    });
  });
}
