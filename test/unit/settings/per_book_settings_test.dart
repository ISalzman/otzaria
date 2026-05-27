import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/settings/services/per_book_settings_service.dart';

void main() {
  group('TextBookPerBookSettings JSON', () {
    test('round-trip שומר את כל השדות כולל continuousReadingMode', () {
      final original = TextBookPerBookSettings(
        fontSize: 22.5,
        commentatorsBelow: true,
        removeNikud: false,
        removePunctuation: true,
        continuousReadingMode: true,
      );

      final restored = TextBookPerBookSettings.fromJson(original.toJson());

      expect(restored.fontSize, 22.5);
      expect(restored.commentatorsBelow, isTrue);
      expect(restored.removeNikud, isFalse);
      expect(restored.removePunctuation, isTrue);
      expect(restored.continuousReadingMode, isTrue);
    });

    test('toJson משמיט שדות null', () {
      final settings = TextBookPerBookSettings(continuousReadingMode: true);
      final json = settings.toJson();

      expect(json.containsKey('continuousReadingMode'), isTrue);
      expect(json.containsKey('fontSize'), isFalse);
      expect(json.containsKey('commentatorsBelow'), isFalse);
      expect(json.containsKey('removeNikud'), isFalse);
      expect(json.containsKey('removePunctuation'), isFalse);
    });

    test('fromJson עם שדה חסר מחזיר null עבור continuousReadingMode', () {
      // תאימות לאחור: הגדרות שנשמרו לפני הפיצ'ר אינן מכילות את השדה.
      final restored = TextBookPerBookSettings.fromJson({
        'fontSize': 18.0,
        'removeNikud': true,
      });
      expect(restored.continuousReadingMode, isNull);
      expect(restored.fontSize, 18.0);
      expect(restored.removeNikud, isTrue);
    });

    test('continuousReadingMode=false שורד round-trip', () {
      // toJson משמיט רק null (לא false). אם בעתיד מישהו ירצה לשמור
      // false במפורש — הוא חייב לעבוד. _savePerBookSettingsDirectly
      // הוא זה שמחליט אם להמיר false ל-null (אופטימיזציה של אחסון),
      // לא ה-JSON עצמו.
      final settings = TextBookPerBookSettings(continuousReadingMode: false);
      final json = settings.toJson();
      expect(json['continuousReadingMode'], isFalse);

      final restored = TextBookPerBookSettings.fromJson(json);
      expect(restored.continuousReadingMode, isFalse);
    });
  });
}
