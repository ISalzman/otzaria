import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/services/book_details_service.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/widgets/dialogs/dialogs_exports.dart';
import 'package:url_launcher/url_launcher.dart';

// ביטוי רגולרי להסרת תווים מפרידים (מקפים, קווים תחתונים, רווחים)
final _sourceNormalizationRegex = RegExp(r'[-_\s]');

// מיפוי שמות המקורות לטקסט בעברית וקישורים (ללא כפילויות)
const _sourceMappings = {
  'sefaria': (text: 'ספריא', url: 'https://www.sefaria.org/texts'),
  'benyehuda': (text: 'פרוייקט בן י.', url: 'https://benyehuda.org/'),
  'dicta': (text: 'ספריית דיקטה', url: 'https://library.dicta.org.il/'),
  'onyourway': (text: 'ובלכתך בדרך', url: 'https://mobile.tora.ws/'),
  'orayta': (text: 'אורייתא', url: 'https://github.com/MosheWagner/Orayta-Books'),
  'tashma': (text: 'תא שמע', url: 'https://tashma.co.il/'),
  'pninim': (text: 'פנינים', url: 'https://pninim.org/'),
  'wikisource': (text: 'ויקיטקסט', url: 'https://he.wikisource.org/wiki'),
  'wikijewishbooks': (
    text: 'אוצר הספרים היהודי השיתופי',
    url: 'https://wiki.jewishbooks.org.il/'
  ),
  'nationallibrary': (text: 'יד הרמב"ם', url: 'https://fjms.genizah.org/'),
  'toratemet': (text: 'תורת אמת', url: 'https://www.toratemetfreeware.com/index.html'),
  'morebooks': (text: 'ספרים פרטיים או מקורות נוספים', url: ''),
  'unknown': (text: 'מקור לא ידוע', url: ''),
};

/// המרת שם המקור לטקסט מתאים עם קישור
/// תומך בשמות המקורות כפי שהם מאוחסנים ב-DB (case-insensitive)
({String text, String url}) getSourceDisplayInfo(String source) {
  // נרמול המחרוזת: הסרת רווחים, המרה לאותיות קטנות והסרת תווים מפרידים
  final normalized =
      source.toLowerCase().replaceAll(_sourceNormalizationRegex, '');

  var key = normalized;

  // טיפול מיוחד ב-ToratEmet (בגלל בעיה עם תווים)
  if (key.contains('toratemet')) {
    key = 'toratemet';
  }
  // טיפול בסיומת 'tootzaria' שנוספה לחלק מהמקורות ב-DB
  else if (key.endsWith('tootzaria') && key != 'tootzaria') {
    key = key.substring(0, key.length - 'tootzaria'.length);
  }

  // חיפוש במיפוי, אם לא נמצא - מחזירים את המקור המקורי
  return _sourceMappings[key] ?? (text: source, url: '');
}

/// קישור הבית של "תא שמע"
const _tashmaUrl = 'https://tashma.co.il/';

/// בודק האם מקור הספר הוא "תא שמע".
/// הזיהוי מבוסס על תיקיית המקור, בדומה ל-error_report_dialog.dart, אך משתמש
/// באותו נרמול כמו getSourceDisplayInfo (הסרת רווחים/מקפים/קווים תחתונים) כדי
/// שכל הווריאנטים שמזוהים כ"תא שמע" בתצוגה יקבלו גם את נוסח הזכויות.
bool isTashmaSource(String? sourceFolder) {
  final normalized = (sourceFolder ?? '')
      .toLowerCase()
      .replaceAll(_sourceNormalizationRegex, '');
  return normalized.contains('tashma');
}

/// בודק האם מקור הספר הוא "יד הרמב"ם" של הספרייה הלאומית
/// (המקור National-LibraryToOtzaria ב-DB). מנורמל כמו [isTashmaSource].
bool isNationalLibrarySource(String? sourceFolder) {
  final normalized = (sourceFolder ?? '')
      .toLowerCase()
      .replaceAll(_sourceNormalizationRegex, '');
  return normalized.contains('nationallibrary');
}

/// הצגת דיאלוג אודות הספר
Future<void> showBookSourceDialog(
  BuildContext context,
  TextBookLoaded state,
) async {
  try {
    final bookDetails = await BookDetailsService().getBookDetails(state.book);
    final bookSource = bookDetails['תיקיית המקור'] ?? 'לא נמצא מקור';

    final sourceInfo = getSourceDisplayInfo(bookSource);
    final displayText = sourceInfo.text;
    final url = sourceInfo.url;
    final isTashma = isTashmaSource(bookSource);

    if (!context.mounted) return;

    final book = state.book;

    await showSingleActionDialog(
      context: context,
      title: 'אודות הספר',
      confirmText: 'סגור',
      customContent: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoSection('שם הספר:', book.title),
              if (book.author != null && book.author!.isNotEmpty)
                _buildInfoSection('מחבר:', book.author!),
              if (book.heEra != null && book.heEra!.isNotEmpty)
                _buildInfoSection('תקופה:', book.heEra!),
              if (book.heCategories != null && book.heCategories!.isNotEmpty)
                _buildInfoSection('קטגוריות:', book.heCategories!),
              if (book.compDateStringHe != null &&
                  book.compDateStringHe!.isNotEmpty)
                _buildInfoSection('תאריך חיבור:', book.compDateStringHe!),
              if (book.compPlaceStringHe != null &&
                  book.compPlaceStringHe!.isNotEmpty)
                _buildInfoSection('מקום חיבור:', book.compPlaceStringHe!),
              if (book.pubDateStringHe != null &&
                  book.pubDateStringHe!.isNotEmpty)
                _buildInfoSection('תאריך פרסום:', book.pubDateStringHe!),
              if (book.pubPlaceStringHe != null &&
                  book.pubPlaceStringHe!.isNotEmpty)
                _buildInfoSection('מקום פרסום:', book.pubPlaceStringHe!),
              if (book.topics.isNotEmpty)
                _buildInfoSection('נושאים:', book.topics),
              if (book.heShortDesc != null && book.heShortDesc!.isNotEmpty)
                _buildInfoSection('תיאור:', book.heShortDesc!),
              if (book.heDesc != null && book.heDesc!.isNotEmpty)
                _buildInfoSection('תיאור מורחב:', book.heDesc!),
              const Divider(height: 24),
              const Text(
                'מקור הספר:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              // ספרי "תא שמע" מציגים נוסח זכויות יוצרים; השאר — קישור/טקסט.
              if (isTashma)
                const _TashmaCopyrightNotice()
              else if (url.isNotEmpty)
                InkWell(
                  onTap: () async {
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                  child: Text(
                    displayText,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                )
              else
                SelectableText(
                  displayText,
                  style: const TextStyle(fontSize: 14),
                ),
            ],
          ),
        ),
      ),
    );
  } catch (e) {
    debugPrint('Error showing book source dialog: $e');
    if (context.mounted) {
      UiSnack.showError('שגיאה בטעינת מידע הספר: ${e.toString()}');
    }
  }
}

/// בניית סעיף מידע עם כותרת וערך
Widget _buildInfoSection(String title, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        SelectableText(
          value,
          style: const TextStyle(fontSize: 14),
        ),
      ],
    ),
  );
}

/// נוסח זכויות היוצרים עבור ספרי "תא שמע".
/// המילים "תא שמע" מוצגות כקישור לאתר תא שמע.
class _TashmaCopyrightNotice extends StatefulWidget {
  const _TashmaCopyrightNotice();

  @override
  State<_TashmaCopyrightNotice> createState() => _TashmaCopyrightNoticeState();
}

class _TashmaCopyrightNoticeState extends State<_TashmaCopyrightNotice> {
  late final TapGestureRecognizer _recognizer;

  @override
  void initState() {
    super.initState();
    _recognizer = TapGestureRecognizer()
      ..onTap = () async {
        final uri = Uri.parse(_tashmaUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      };
  }

  @override
  void dispose() {
    _recognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 14),
        children: [
          const TextSpan(text: 'כל הזכויות שמורות ל'),
          TextSpan(
            text: 'תא שמע',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              decoration: TextDecoration.underline,
            ),
            recognizer: _recognizer,
          ),
          const TextSpan(
            text: '. השימוש מותר במסגרת תוכנת אוצריא בלבד. '
                'אין לבצע שימוש אחר ללא אישור.',
          ),
        ],
      ),
    );
  }
}
