import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/find_ref/view/find_ref_dialog.dart';
import 'package:otzaria/library/models/library.dart';
import 'package:otzaria/models/books.dart';

Category _category(String title, {Category? parent}) {
  final category = Category(
    title: title,
    description: '',
    shortDescription: '',
    order: 0,
    subCategories: [],
    books: [],
    parent: parent,
  );
  parent?.subCategories.add(category);
  return category;
}

void main() {
  // מזהי seforim.db אינם ייחודיים מול user_books.db ומול ייצוגי PDF בעץ —
  // התאמת-id מקרית אסור שתסתיר את ספר הטקסט הרשמי או תוחזר במקומו.
  group('findOfficialTextBookById', () {
    test('מדלג על ספר אישי בעל אותו id ומחזיר את הרשמי', () {
      final root = _category('תלמוד בבלי');
      final personal = _category('ספרים אישיים');
      final userBook = TextBook(id: 7, title: 'ברכות שלי', isUserBook: true);
      final official = TextBook(id: 7, title: 'ברכות');
      personal.books.add(userBook);
      root.books.add(official);

      // הספר האישי ראשון בסדר המעבר — בלי הסינון הוא היה מוחזר.
      final library = Library(categories: [personal, root]);

      expect(findOfficialTextBookById(library, 7), same(official));
    });

    test('מדלג על PdfBook בעל אותו id ומחזיר את ספר הטקסט', () {
      final root = _category('תלמוד בבלי');
      final pdf = PdfBook(id: 7, title: 'ברכות', path: r'C:\ברכות.pdf');
      final text = TextBook(id: 7, title: 'ברכות');
      root.books.addAll([pdf, text]);

      final library = Library(categories: [root]);

      expect(findOfficialTextBookById(library, 7), same(text));
    });

    test('אין ספר רשמי מתאים — מחזיר null גם כשיש התנגשות id', () {
      final personal = _category('ספרים אישיים');
      personal.books.add(TextBook(id: 7, title: 'ברכות שלי', isUserBook: true));

      final library = Library(categories: [personal]);

      expect(findOfficialTextBookById(library, 7), isNull);
    });
  });
}
