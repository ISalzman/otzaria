import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/migration/models/book.dart';

void main() {
  test('שומר את התיאור המורחב וההפניה העברית מהמסד', () {
    final book = Book.fromJson({
      'id': 17,
      'categoryId': 4,
      'sourceId': 2,
      'title': 'ספר בדיקה',
      'heShortDesc': 'תיאור קצר',
      'heDesc': 'תיאור מורחב',
      'heRef': 'ספר בדיקה א',
    });

    expect(book.heShortDesc, 'תיאור קצר');
    expect(book.heDesc, 'תיאור מורחב');
    expect(book.heRef, 'ספר בדיקה א');
    expect(book.toJson()['heDesc'], 'תיאור מורחב');
    expect(book.toJson()['heRef'], 'ספר בדיקה א');
  });
}
