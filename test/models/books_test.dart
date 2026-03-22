import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/books.dart';

void main() {
  test('TextBook toJson/fromJson שומר categoryId בשחזור טאב', () {
    final original = TextBook(
      title: 'בראשית',
      categoryId: 7,
      fileType: 'txt',
      categoryPath: 'תנך/תורה',
      filePath: '/tmp/bereshit.txt',
      heCategories: 'תנ"ך, תורה',
    );

    final restored = Book.fromJson(original.toJson()) as TextBook;

    expect(restored.title, 'בראשית');
    expect(restored.categoryId, 7);
    expect(restored.fileType, 'txt');
    expect(restored.categoryPath, 'תנך/תורה');
  });
}
