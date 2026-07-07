import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/personal_notes/utils/note_link_detection.dart';

void main() {
  group('linkifyDeltaOps', () {
    test('הופך כתובת otzaria:// בטקסט רגיל למקטע מקושר', () {
      final ops = linkifyDeltaOps([
        {'insert': 'ראה otzaria://open/book/2156 בעניין זה'},
        {'insert': '\n'},
      ]);

      expect(ops, [
        {'insert': 'ראה '},
        {
          'insert': 'otzaria://open/book/2156',
          'attributes': {'link': 'otzaria://open/book/2156'},
        },
        {'insert': ' בעניין זה'},
        {'insert': '\n'},
      ]);
    });

    test('מסיר פיסוק נגרר מסוף הכתובת', () {
      final ops = linkifyDeltaOps([
        {'insert': 'קישור: https://example.com/page.'},
      ]);

      expect(ops[1], {
        'insert': 'https://example.com/page',
        'attributes': {'link': 'https://example.com/page'},
      });
      expect(ops[2], {'insert': '.'});
    });

    test('לא נוגע במקטע שכבר מקושר', () {
      final original = [
        {
          'insert': 'otzaria://open/book/5',
          'attributes': {'link': 'otzaria://open/book/999'},
        },
      ];

      expect(linkifyDeltaOps(original), original);
    });

    test('משמר attributes קיימים (מודגש) על כל המקטעים שפוצלו', () {
      final ops = linkifyDeltaOps([
        {
          'insert': 'לפני otzaria://open/notes אחרי',
          'attributes': {'bold': true},
        },
      ]);

      expect(ops, [
        {
          'insert': 'לפני ',
          'attributes': {'bold': true},
        },
        {
          'insert': 'otzaria://open/notes',
          'attributes': {'bold': true, 'link': 'otzaria://open/notes'},
        },
        {
          'insert': ' אחרי',
          'attributes': {'bold': true},
        },
      ]);
    });

    test('טקסט ללא כתובות ואופרציות embed נשמרים כמות שהם', () {
      final original = [
        {'insert': 'סתם טקסט בלי קישור'},
        {
          'insert': {'image': 'x'},
        },
      ];

      expect(linkifyDeltaOps(original), original);
    });

    test('מזהה גם zayit:// וגם http://', () {
      final ops = linkifyDeltaOps([
        {'insert': 'zayit://book/12 וגם http://a.b'},
      ]);

      expect(ops[0], {
        'insert': 'zayit://book/12',
        'attributes': {'link': 'zayit://book/12'},
      });
      expect(ops[2], {
        'insert': 'http://a.b',
        'attributes': {'link': 'http://a.b'},
      });
    });
  });
}
