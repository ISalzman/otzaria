import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/text_book/view/toc_filter.dart';

TocEntry _entry({
  required String text,
  required int index,
  required int level,
  TocEntry? parent,
  List<TocEntry> children = const [],
}) {
  final entry = TocEntry(
    text: text,
    index: index,
    level: level,
    parent: parent,
  );
  entry.children = children;
  return entry;
}

void main() {
  test('filterTocEntriesForSearch keeps only matching branches', () {
    final root = _entry(text: 'Book', index: 0, level: 1);
    final chapterA = _entry(text: 'Chapter A', index: 1, level: 2, parent: root);
    final chapterB = _entry(text: 'Chapter B', index: 2, level: 2, parent: root);
    root.children = [chapterA, chapterB];

    final appendixRoot = _entry(text: 'Appendix', index: 3, level: 1);
    final appendixA =
        _entry(text: 'Appendix A', index: 4, level: 2, parent: appendixRoot);
    appendixRoot.children = [appendixA];

    final entries = [root, appendixRoot];

    final filtered = filterTocEntriesForSearch(entries, 'Chapter');

    expect(filtered.length, 1);
    expect(filtered.first.text, 'Book');
    expect(filtered.first.children.length, 2);
    expect(filtered.first.children[0].text, 'Chapter A');
    expect(filtered.first.children[1].text, 'Chapter B');
  });

  test('filterTocEntriesForSearch returns empty list for empty query', () {
    final root = _entry(text: 'Book', index: 0, level: 1);
    final entries = [root];

    final filtered = filterTocEntriesForSearch(entries, '   ');

    expect(filtered, isEmpty);
  });

  test('shouldExpandInSearch defaults to true when no state is stored', () {
    expect(shouldExpandInSearch(null), isTrue);
    expect(shouldExpandInSearch(true), isTrue);
    expect(shouldExpandInSearch(false), isFalse);
  });
}
