import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/text_book/view/page_shape/simple_text_viewer.dart';

void main() {
  test('page shape builds the plugin selection event with reader identity', () {
    final payload = buildPageShapePluginSelectionPayload(
      selectedText: 'רבי אלעזר',
      bookTitle: 'מסילת ישרים',
      sectionIndex: 17,
      currentRef: 'פרק א',
      bookDbId: 42,
      bookType: 'text',
      bookSource: 'library',
    );

    expect(payload['text'], 'רבי אלעזר');
    expect(payload['renderedSelectedText'], 'רבי אלעזר');
    expect(payload['currentBook'], 'מסילת ישרים');
    expect(payload['currentBookId'], 'מסילת ישרים');
    expect(payload['bookId'], 'מסילת ישרים');
    expect(payload['currentIndex'], 17);
    expect(payload['sectionIndex'], 17);
    expect(payload['currentRef'], 'פרק א');
    expect(payload['id'], 42);
    expect(payload['type'], 'text');
    expect(payload['source'], 'library');
  });

  test('זהות ספר חסרה אינה מוסיפה מפתחות null לאירוע', () {
    final payload = buildPageShapePluginSelectionPayload(
      selectedText: 'טקסט',
      bookTitle: 'ספר',
      sectionIndex: 0,
    );

    expect(payload.containsKey('id'), isFalse);
    expect(payload.containsKey('type'), isFalse);
    expect(payload.containsKey('source'), isFalse);
  });
}
