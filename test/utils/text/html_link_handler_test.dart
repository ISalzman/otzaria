import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/utils/text/html_link_handler.dart';

void main() {
  group('HtmlLinkHandler Markdown anchors', () {
    test('משווה slug של Markdown לכותרת עם פיסוק ורווחים', () {
      expect(
        HtmlLinkHandler.isHeaderMatch('0. מפה מהירה', '0-מפה-מהירה'),
        isTrue,
      );
      expect(
        HtmlLinkHandler.isHeaderMatch('פרק: מבוא כללי', 'פרק-מבוא-כללי'),
        isTrue,
      );
    });

    test('מוצא עוגן בכותרת מקוננת', () {
      final root = TocEntry(text: 'ראשי', index: 0, level: 1);
      root.children.add(
        TocEntry(
          text: '0. מפה מהירה',
          index: 7,
          level: 2,
          parent: root,
        ),
      );

      expect(
        HtmlLinkHandler.findHeaderIndexInToc([root], '0-מפה-מהירה'),
        7,
      );
    });

    test('אינו מחזיר התאמת substring לכותרת קצרה', () {
      expect(HtmlLinkHandler.isHeaderMatch('פרק ב', 'ב'), isFalse);
    });

    test('מוצא עוגן יעד מפורש שהוגדר ב-<a name>', () {
      expect(
        HtmlLinkHandler.findAnchorIndex(
          const [
            '<p>פתיחה</p>',
            '<a name="3a-סוגי-קשר"></a>',
            '<h2 id="3א-סוגי-קשר-connection-type">3א. סוגי קשר</h2>',
          ],
          '3a-סוגי-קשר',
        ),
        1,
      );
    });

    test('עוגן יעד שאינו קיים אינו מוחזר', () {
      expect(
        HtmlLinkHandler.findAnchorIndex(
          const ['<a name="אחר"></a>'],
          'לא-קיים',
        ),
        isNull,
      );
    });

    test('מעדיף id מפורש של כותרת גם כשהטקסט שונה', () {
      expect(
        HtmlLinkHandler.findAnchorIndex(
          const ['<p>פתיחה</p>', '<h2 id="2-ספירת-db">נוסח אחר</h2>'],
          '2-ספירת-db',
        ),
        1,
      );
    });
  });
}
