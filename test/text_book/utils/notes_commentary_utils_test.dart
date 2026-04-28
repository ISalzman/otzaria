import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/text_book/utils/notes_commentary_utils.dart';

void main() {
  group('notes commentary utils', () {
    test('matches markers with bidi controls and sup attributes', () {
      const content = [
        '<div>טקסט<sup style="color:blue;">\u2067לט)\u2069</sup></div>',
      ];
      const notesContent = '<sup>לט)</sup> תוכן ההערה';

      expect(
        notesForIndexes(
          content: content,
          indexes: const [0],
          notesByMarker: parseNotesContent(notesContent),
        ),
        const ['<sup>לט)</sup> תוכן ההערה'],
      );
    });

    test('parses notes with sup attributes', () {
      const notesContent =
          '<sup style="color:blue;">\u2067מ)\u2069</sup> הערה <sup>מא)</sup> עוד הערה';

      expect(parseNotesContent(notesContent), {
        'מ)': '<sup style="color:blue;">\u2067מ)\u2069</sup> הערה',
        'מא)': '<sup>מא)</sup> עוד הערה',
      });
    });
  });
}
