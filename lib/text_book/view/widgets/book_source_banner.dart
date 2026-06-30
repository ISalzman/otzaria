import 'package:flutter/material.dart';
import 'package:otzaria/data/data_providers/sqlite_data_provider.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/text_book/view/book_source_dialog.dart';

/// הטקסט המוצג בראש ספרי "יד הרמב"ם" (הספרייה הלאומית).
const String kNationalLibraryBannerText =
    'באדיבות הספרייה הלאומית לישראל, ואגודת פרידברג לכתבי יד יהודיים\n'
    'כל הזכויות שמורות';

/// טוען מה-DB האם הספר מקורו "יד הרמב"ם" (הספרייה הלאומית).
/// ספרי משתמש לעולם אינם ממקור זה, ולכן מדלגים על שאילתת DB מיותרת.
Future<bool> isBookFromNationalLibrary(TextBook book) async {
  if (book.isUserBook) return false;
  final sourceName = await SqliteDataProvider.instance.getBookSourceNameFromDb(
    book.title,
    book.categoryId,
    book.fileType,
  );
  return isNationalLibrarySource(sourceName);
}

/// שורה נגללת המוצגת מעל השורה הראשונה בספרי "יד הרמב"ם".
/// אינה חלק מתוכן הספר עצמו — לכן אינה משפיעה על אינדקסי שורות, קישורים או חיפוש.
class BookSourceBanner extends StatelessWidget {
  const BookSourceBanner({super.key, this.fontSize});

  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // גופן קטן ביחס לטקסט הספר — שורת קרדיט, לא חלק מהתוכן.
    final size = fontSize == null ? null : fontSize! * 0.6;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        kNationalLibraryBannerText,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: size,
          height: 1.3,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}
