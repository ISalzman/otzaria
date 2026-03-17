import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/migration/core/models/toc_entry.dart';
import 'package:otzaria/tools/gematria/gematria_search.dart';

void main() {
  test('Gematria path extraction keeps chapter in Tanach results', () {
    final path = GimatriaSearch.extractPathFromTocEntries(
      currentLineIndex: 8,
      bookTitle: 'בראשית',
      tocEntries: const [
        TocEntry(
          id: 1,
          bookId: 1,
          text: 'בראשית',
          level: 1,
          lineIndex: 0,
        ),
        TocEntry(
          id: 2,
          bookId: 1,
          parentId: 1,
          text: 'פרק א',
          level: 2,
          lineIndex: 1,
        ),
      ],
    );

    expect(path, 'בראשית, פרק א');
  });

  test('Gematria path extraction keeps nested TOC hierarchy', () {
    final path = GimatriaSearch.extractPathFromTocEntries(
      currentLineIndex: 30,
      bookTitle: 'משנה תורה',
      tocEntries: const [
        TocEntry(
          id: 1,
          bookId: 1,
          text: 'משנה תורה',
          level: 1,
          lineIndex: 0,
        ),
        TocEntry(
          id: 2,
          bookId: 1,
          parentId: 1,
          text: 'הלכות תשובה',
          level: 2,
          lineIndex: 10,
        ),
        TocEntry(
          id: 3,
          bookId: 1,
          parentId: 2,
          text: 'פרק ב',
          level: 3,
          lineIndex: 20,
        ),
      ],
    );

    expect(path, 'משנה תורה, הלכות תשובה, פרק ב');
  });
}
