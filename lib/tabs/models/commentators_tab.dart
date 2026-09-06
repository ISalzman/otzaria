import 'package:flutter/foundation.dart';
import 'package:otzaria/tabs/models/tab.dart';
import 'package:otzaria/tabs/models/text_tab.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/text_book/bloc/text_book_bloc.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/text_book/text_book_repository.dart';
import 'package:otzaria/data/data_providers/file_system_data_provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/// טאב המציג מפרשים לספר טקסט ספציפי עם בחירת פרק/פסוק עצמאית.
///
/// יוצר BLoC עצמאי שמאותחל מאותו ספר ומיקום כמו sourceTab,
/// אך פועל לגמרי בנפרד ואינו משפיע על sourceTab כלל.
class CommentatorsTab extends OpenedTab {
  final TextBookTab sourceTab;
  final bool _disposeSourceTabOnDispose;
  late final TextBookBloc bloc;
  final ItemScrollController scrollController = ItemScrollController();
  final ItemPositionsListener positionsListener =
      ItemPositionsListener.create();

  /// השורה שנבחרה ב-sourceTab בעת הפתיחה (אם הייתה), null אם לא הייתה בחירה
  final int? initialSelectedLine;

  /// בחירת המפרשים של הכרטיסייה. null = ללא בחירה (מוצגים כל מפרשי הספר).
  /// נשמר ב-toJson — בלעדיו הבחירה אבדה בסגירת התוכנה ושוחזרו "כל המפרשים".
  List<String>? selectedCommentators;

  static int? _resolveSelectedLine(TextBookTab tab) {
    final s = tab.bloc.state;
    return s is TextBookLoaded ? s.selectedIndex : null;
  }

  CommentatorsTab({
    required this.sourceTab,
    this._disposeSourceTabOnDispose = false,
    // שכפול בונה sourceTab חדש, שה-bloc שלו עדיין ב-TextBookInitial; בלי
    // העברה מפורשת _resolveSelectedLine היה מחזיר null והשורה הנבחרת
    // הייתה נעלמת בשכפול. null = "גזור מה-sourceTab", כמו קודם.
    int? initialSelectedLine,
    @visibleForTesting TextBookBloc? blocOverride,
  }) : initialSelectedLine =
           initialSelectedLine ?? _resolveSelectedLine(sourceTab),
       super('מפרשים | ${sourceTab.title}') {
    // קורא מיקום התחלתי מה-state הנוכחי של sourceTab
    final sourceState = sourceTab.bloc.state;
    if (sourceState is TextBookLoaded &&
        sourceState.activeCommentators.isNotEmpty) {
      selectedCommentators = List<String>.from(sourceState.activeCommentators);
    }
    final int startIndex = sourceState is TextBookLoaded
        ? (sourceState.selectedIndex ??
              (sourceState.visibleIndices.isNotEmpty
                  ? sourceState.visibleIndices.first
                  : sourceTab.index))
        : sourceTab.index;

    // ב-production תמיד נבנה bloc חדש; blocOverride קיים רק לטסטים שצריכים
    // להזריק bloc עם repository מזויף ולהביאו ל-Loaded ללא תשתית קבצים אמיתית.
    bloc =
        blocOverride ??
        TextBookBloc(
          repository: TextBookRepository(
            fileSystem: FileSystemData.instance,
          ),
          initialState: TextBookInitial.named(
            sourceTab.book,
            startIndex,
            false, // openLeftPane
            const [], // commentators — ייטען אחרי availableCommentators
          ),
          scrollController: scrollController,
          positionsListener: positionsListener,
        );
  }

  /// שחזור מ-JSON — יוצר sourceTab מדומה על בסיס הנתונים השמורים
  factory CommentatorsTab.fromJson(Map<String, dynamic> json) {
    // Hive מחזיר nested maps כ-Map<dynamic, dynamic> — צריך להמיר
    final rawSourceTab = json['sourceTab'];
    final Map<String, dynamic>? sourceJson = rawSourceTab is Map
        ? Map<String, dynamic>.from(rawSourceTab)
        : null;
    final TextBookTab sourceTab = sourceJson != null
        ? TextBookTab.fromJson(sourceJson)
        : TextBookTab(
            index: json['initialIndex'] ?? 0,
            book: TextBook(title: json['bookTitle'] ?? ''),
            commentators: const [],
          );

    final tab = CommentatorsTab(
      sourceTab: sourceTab,
      disposeSourceTabOnDispose: true,
    )..isPinned = json['isPinned'] ?? false;
    if (json.containsKey('selectedCommentators')) {
      final saved = json['selectedCommentators'];
      tab.selectedCommentators = saved is List
          ? List<String>.from(saved)
          : null;
    } else {
      // JSON מגרסה שלא שמרה את בחירת הכרטיסייה — הבחירה של טאב המקור קרובה יותר
      // מאשר "כל המפרשים".
      final sourceCommentators = sourceTab.commentators;
      if (sourceCommentators != null && sourceCommentators.isNotEmpty) {
        tab.selectedCommentators = List<String>.from(sourceCommentators);
      }
    }
    return tab;
  }

  /// המקור והשכפול חייבים לקבל [sourceTab] נפרד: קודם שניהם הצביעו על אותו
  /// [TextBookTab], ו-[dispose] של האחד סגר את ה-BLoC ואת הבקרים של השני.
  @override
  OpenedTab clone() =>
      CommentatorsTab(
          // `OpenedTab.from` מוצהר כמחזיר OpenedTab; הענף של TextBookTab מחזיר
          // תמיד את אותו טיפוס, ובדיקת השכפול מוודאת שזה נשאר נכון.
          sourceTab: OpenedTab.from(sourceTab) as TextBookTab,
          // השכפול הוא הבעלים של ה-sourceTab שנוצר כאן; בלי זה ה-BLoC והבקרים
          // שלו לא משוחררים לעולם.
          disposeSourceTabOnDispose: true,
          initialSelectedLine: initialSelectedLine,
        )
        ..isPinned = isPinned
        ..selectedCommentators = selectedCommentators == null
            ? null
            : List<String>.from(selectedCommentators!);

  @override
  void dispose() {
    bloc.close();
    if (_disposeSourceTabOnDispose) {
      sourceTab.dispose();
    }
    super.dispose();
  }

  @override
  Map<String, dynamic> toJson() {
    // שמור את ה-sourceTab כדי לשחזר אחרי הפעלה מחדש
    int currentIndex = sourceTab.index;
    if (bloc.state is TextBookLoaded) {
      final s = bloc.state as TextBookLoaded;
      if (s.visibleIndices.isNotEmpty) currentIndex = s.visibleIndices.first;
    }
    return {
      'title': title,
      'type': 'CommentatorsTab',
      'isPinned': isPinned,
      'initialIndex': currentIndex,
      'bookTitle': sourceTab.book.title,
      'sourceTab': sourceTab.toJson(),
      'selectedCommentators': selectedCommentators,
    };
  }
}
