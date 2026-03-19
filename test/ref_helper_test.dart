import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/utils/ref_helper.dart';

void main() {
  group('formatDisplayReference', () {
    test('adds the book title when resolved reference omits it', () {
      expect(
        formatDisplayReference(
          bookTitle: 'בראשית',
          resolvedRef: 'פרק א',
          fallbackRef: 'א',
        ),
        'בראשית, פרק א',
      );
    });

    test('keeps the resolved reference when it already starts with title', () {
      expect(
        formatDisplayReference(
          bookTitle: 'בראשית',
          resolvedRef: 'בראשית, פרק א',
          fallbackRef: 'פרק א',
        ),
        'בראשית, פרק א',
      );
    });

    test('removes adjacent duplicate toc segments', () {
      expect(
        formatDisplayReference(
          bookTitle: 'לבני מחולקת על כרכות',
          resolvedRef:
              'לבני מחולקת על כרכות, לבני מחולקת על כרכות, כרכות',
        ),
        'לבני מחולקת על כרכות, כרכות',
      );
    });

    test('falls back to the existing link reference when TOC ref is unavailable', () {
      expect(
        formatDisplayReference(
          bookTitle: 'בראשית',
          fallbackRef: 'פרק א',
        ),
        'בראשית, פרק א',
      );
    });

    test('returns only the book title when no reference is available', () {
      expect(
        formatDisplayReference(
          bookTitle: 'בראשית',
        ),
        'בראשית',
      );
    });

    test('normalizes whitespace and keeps only adjacent unique segments', () {
      expect(
        formatDisplayReference(
          bookTitle: 'בראשית',
          resolvedRef: '  פרק א  ,   פרק א , פסוק ב  ',
        ),
        'בראשית, פרק א, פסוק ב',
      );
    });

    test('prefers fallback reference when it is more specific than TOC', () {
      expect(
        formatDisplayReference(
          bookTitle: 'כמלכל',
          resolvedRef: 'פרק ו',
          fallbackRef: 'פרק ו, פסוק ג',
        ),
        'כמלכל, פרק ו, פסוק ג',
      );
    });
  });
}