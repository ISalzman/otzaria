import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/utils/highlight_click_resolver.dart';

void main() {
  List<String> chars(String text) => text.characters.toList(growable: false);

  group('displayTextOccurrence', () {
    test('מזהה את המופע השני של מילה חוזרת לפי מיקום ההדגשה', () {
      const rendered = 'מילה באמצע מילה בסוף';
      final occurrence = displayTextOccurrence(
        renderedChars: chars(rendered),
        startGrapheme: 11,
        displayText: 'מילה',
      );

      expect(occurrence, (index: 1, count: 2));
    });

    test('מופע ראשון של מילה חוזרת', () {
      const rendered = 'מילה באמצע מילה בסוף';
      final occurrence = displayTextOccurrence(
        renderedChars: chars(rendered),
        startGrapheme: 0,
        displayText: 'מילה',
      );

      expect(occurrence, (index: 0, count: 2));
    });

    test('מופע יחיד — אינדקס 0 בלי חישוב מיקום', () {
      final occurrence = displayTextOccurrence(
        renderedChars: chars('שלום עולם'),
        startGrapheme: 5,
        displayText: 'עולם',
      );

      expect(occurrence, (index: 0, count: 1));
    });

    test('טקסט שאינו קיים מחזיר null', () {
      final occurrence = displayTextOccurrence(
        renderedChars: chars('שלום עולם'),
        startGrapheme: 0,
        displayText: 'אחר',
      );

      expect(occurrence, isNull);
    });

    test('רווחים כפולים לפני ההדגשה לא מסיטים את בחירת המופע', () {
      // המרחב המכווץ קצר מהמקורי — הקרבה למיקום המכווץ עדיין בוחרת נכון.
      const rendered = 'מילה  באמצע  מילה';
      final occurrence = displayTextOccurrence(
        renderedChars: chars(rendered),
        startGrapheme: 13,
        displayText: 'מילה',
      );

      expect(occurrence, (index: 1, count: 2));
    });
  });
}
