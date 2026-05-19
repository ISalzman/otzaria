import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/find_ref/bloc/find_ref_bloc.dart';
import 'package:otzaria/find_ref/bloc/find_ref_event.dart';
import 'package:otzaria/find_ref/bloc/find_ref_state.dart';
import 'package:otzaria/find_ref/repository/db_reference_result.dart';
import 'package:otzaria/core/focus_repository.dart';
import 'package:otzaria/data/repository/data_repository.dart';
import 'package:otzaria/library/models/library.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/utils/navigation/open_book.dart';
import 'package:otzaria/tour/tour_target_keys.dart';
import 'package:otzaria/library/view/grid_items.dart';
import 'package:otzaria/widgets/text/rtl_text_field.dart';

class FindRefDialog extends StatefulWidget {
  const FindRefDialog({super.key});

  @override
  State<FindRefDialog> createState() => _FindRefDialogState();
}

/// רשומת מפרש מוכנה לפתיחה ישירה ללא שאילתות נוספות.
/// נוצרת בעת טעינת רשימת המפרשים — מאחדת את ה-`title` ו-`targetSegment`
/// מה-DB עם ה-[Book] המתאים מתוך הספרייה.
///
/// `targetSegment` הוא nullable: `non-null` רק כש-DB החזיר `targetLineIndex`
/// מדויק (מסלול segment-level). ב-book-level הוא `null`, והקליק נופל ל-
/// `ref.segment.toInt()`. חשוב: הרשומה הזו משותפת בין refs עם אותו
/// `bookId+sourceLineId` אך `segment` שונה, ולכן אסור לקבע את ה-segment כאן.
class _CommentatorEntry {
  final String title;
  final int? targetSegment;
  final Book book;

  const _CommentatorEntry({
    required this.title,
    required this.targetSegment,
    required this.book,
  });
}

class _FindRefDialogState extends State<FindRefDialog> {
  int _selectedIndex = 0;
  bool _includePersonalBooks = false;
  final Map<int, GlobalKey> _itemKeys = {};
  final Map<int, GlobalKey> _commentatorsButtonKeys = {};
  // מפתח = "bookId:sourceLineId". value=null → טעינה בתהליך.
  // value=[] → אין מפרשים זמינים (לא יוצג כפתור).
  // value=[...] → רשומות מוכנות לפתיחה ישירה (כולל targetSegment ו-Book).
  final Map<String, List<_CommentatorEntry>?> _commentatorsByRef = {};
  FocusRestorer? _focusRestorer;

  @override
  void initState() {
    super.initState();

    // בחירת הטקסט הקיים כאשר חוזרים למסך
    // מבוצע מיד ולא ב-postFrameCallback כדי למנוע אובדן פוקוס באנדרואיד
    final controller = FocusRepository().findRefSearchController;
    if (controller.text.isNotEmpty) {
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      );
    }

    // רישום כ-active restorer כדי שהדיאלוג יקבל שחזור פוקוס לאחר אירועי חלון
    _focusRestorer = FocusRepository().registerActiveRestorer(
      restore: () {
        if (mounted) FocusRepository().findRefSearchFocusNode.requestFocus();
      },
      canRestore: () =>
          mounted &&
          FocusRepository().findRefSearchFocusNode.canRequestFocus &&
          (ModalRoute.of(context)?.isCurrent ?? false),
    );
  }

  @override
  void dispose() {
    final restorer = _focusRestorer;
    if (restorer != null) FocusRepository().unregisterActiveRestorer(restorer);
    super.dispose();
  }

  GlobalKey _getKeyForIndex(int index) {
    if (!_itemKeys.containsKey(index)) {
      _itemKeys[index] = GlobalKey();
    }
    return _itemKeys[index]!;
  }

  GlobalKey _getCommentatorsButtonKey(int index) {
    if (!_commentatorsButtonKeys.containsKey(index)) {
      _commentatorsButtonKeys[index] = GlobalKey();
    }
    return _commentatorsButtonKeys[index]!;
  }

  String _commentatorsKey(DbReferenceResult ref) =>
      '${ref.bookId}:${ref.sourceLineId}';

  /// טוען את רשימת המפרשים ל-[ref] ברקע אם עוד לא נטענה, יחד עם ה-[Book]
  /// המתאים לכל מפרש. רשומות מלאות נשמרות ב-[_commentatorsByRef] כך שהקליק
  /// על מפרש יוכל לפתוח אותו ישירות, בלי `await` וללא שאילתות.
  void _ensureCommentatorsLoaded(DbReferenceResult ref) {
    final key = _commentatorsKey(ref);
    if (_commentatorsByRef.containsKey(key)) return; // נטען / בתהליך טעינה
    _commentatorsByRef[key] = null; // sentinel: בתהליך
    final repository = context.read<FindRefBloc>().findRefRepository;
    () async {
      try {
        final dbEntries = await repository.getCommentatorsForResult(ref);
        if (!mounted) return;
        if (dbEntries.isEmpty) {
          setState(() {
            _commentatorsByRef[key] = const [];
          });
          return;
        }
        // pre-resolve של ה-Book עבור כל מפרש כדי שהקליק יהיה סינכרוני.
        // `library` מוחזק בקאש ב-DataRepository.
        final library = await DataRepository.instance.library;
        if (!mounted) return;
        final entries = <_CommentatorEntry>[
          for (final e in dbEntries)
            _CommentatorEntry(
              title: e.title,
              targetSegment: e.targetSegment,
              book:
                  _findBookInLibrary(library, e.title, preferTextBook: true) ??
                      TextBook(title: e.title),
            ),
        ];
        setState(() {
          _commentatorsByRef[key] = entries;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _commentatorsByRef[key] = const [];
        });
      }
    }();
  }

  void _scrollToSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _getKeyForIndex(_selectedIndex);
      final context = key.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: 0.5, // מרכז המסך
        );
      }
    });
  }

  /// פותח את התוצאה.
  ///
  /// [initialCommentators] סמנטיקה:
  ///   null  → ברירת מחדל: history fallback (התנהגות onTap הרגילה).
  ///   []    → bypass מפורש: ללא מפרשים, גם אם בעבר היו (= "פתח ללא מפרש").
  ///   [...] → רשימה מפורשת (= "פתח עם רש"י").
  Future<void> _openRef(
    DbReferenceResult ref, {
    List<String>? initialCommentators,
  }) async {
    Book? book;

    if (ref.isPdf && ref.filePath.isNotEmpty) {
      // Use filePath directly — library search may return a same-titled text book
      book = PdfBook(title: ref.title, path: ref.filePath);
    } else {
      try {
        final library = await DataRepository.instance.library;
        // ספרים מסוימים (תלמוד בבלי וכו') מופיעים ב-library כ-PdfBook גם כשה-DB
        // מכיר אותם כ-txt. אם המשתמש ביקש מפרש מסוים — חייבים TextBookTab,
        // כי PdfBookTab אינו מקבל commentators כלל.
        final needsTextBook =
            initialCommentators != null && initialCommentators.isNotEmpty;
        book = _findBookInLibrary(library, ref.title,
            preferTextBook: needsTextBook);
      } catch (e) {
        debugPrint('Error searching library: $e');
      }
      book ??= TextBook(title: ref.title);
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    openBook(context, book, ref.segment.toInt(), '',
        ignoreHistory: ref.isPdf,
        requiresStableLayout: ref.isPdf,
        initialCommentators: initialCommentators);
  }

  /// פותח תפריט עם רשימת המפרשים הזמינים ל-[ref] (כבר preloaded — כולל
  /// `Book` לכל רשומה). בחירה פותחת את הספר ישירות. ה-[ref] נחוץ עבור
  /// fallback של `targetSegment` במסלול book-level (ראה [_openCommentator]).
  Future<void> _showCommentatorsMenu(
    DbReferenceResult ref,
    GlobalKey buttonKey,
    List<_CommentatorEntry> commentators,
  ) async {
    if (commentators.isEmpty) return;

    final buttonContext = buttonKey.currentContext;
    if (buttonContext == null || !buttonContext.mounted) return;

    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final box = buttonContext.findRenderObject() as RenderBox;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    final bottomRight = box.localToGlobal(
        box.size.bottomRight(Offset.zero),
        ancestor: overlayBox);

    // אנו רוצים שה-popup ייפתח לכיוון שמאל פיזית: הקצה הימני של ה-popup
    // יסיים בקצה השמאלי של ה-button (=topLeft.dx) וה-popup יתפשט שמאלה.
    // ב-_PopupMenuRouteLayout, fork-1 נבחר כאשר position.left > position.right
    // ואז `x = size.width - position.right - childSize.width`. לכן:
    //   position.right = overlayWidth - topLeft.dx → popup.right == button.left
    //   position.left  = overlayWidth (max possible) → ensures fork-1
    final position = RelativeRect.fromLTRB(
      overlayBox.size.width.toDouble(),
      bottomRight.dy,
      overlayBox.size.width - topLeft.dx,
      overlayBox.size.height - bottomRight.dy,
    );

    final selected = await showMenu<_CommentatorEntry>(
      context: context,
      position: position,
      constraints: const BoxConstraints(maxHeight: 400, minWidth: 220),
      items: [
        for (final e in commentators)
          PopupMenuItem<_CommentatorEntry>(
            value: e,
            child: Text(
              e.title,
              textDirection: TextDirection.rtl,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );

    if (selected == null || !mounted) return;
    _openCommentator(ref, selected);
  }

  /// פותח את ספר המפרש מתוך רשומה שהוכנה מראש: ה-`book` כבר ידוע, וה-
  /// `targetSegment` נלקח מה-[entry] או נופל ל-`ref.segment` כש-DB לא ידע
  /// לפתור (מסלול book-level). הקליק סינכרוני לחלוטין — אין `await`, אין
  /// שאילתות DB ואין מעבר על עץ הספרייה בזמן הקליק.
  void _openCommentator(DbReferenceResult ref, _CommentatorEntry entry) {
    final segment = entry.targetSegment ?? ref.segment.toInt();
    Navigator.of(context).pop();
    openBook(context, entry.book, segment, '');
  }

  Book? _findBookInLibrary(Category category, String title,
      {bool preferTextBook = false}) {
    // עוברים פעמיים אם preferTextBook: ראשונה — רק TextBook; שנייה — כל סוג.
    // כך מקבלים TextBook אם קיים, ובלעדיו מקבלים PdfBook (או אחר).
    for (final passOnlyText in preferTextBook ? [true, false] : [false]) {
      final result =
          _findBookInLibraryPass(category, title, onlyTextBook: passOnlyText);
      if (result != null) return result;
    }
    return null;
  }

  Book? _findBookInLibraryPass(Category category, String title,
      {required bool onlyTextBook}) {
    for (final b in category.books) {
      if (b.title != title) continue;
      if (onlyTextBook && b is! TextBook) continue;
      return b;
    }
    for (final subCat in category.subCategories) {
      final found =
          _findBookInLibraryPass(subCat, title, onlyTextBook: onlyTextBook);
      if (found != null) return found;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final focusRepository = context.read<FocusRepository>();

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(FluentIcons.dismiss_24_regular),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'סגור',
          ),
          const Expanded(
            child: Text(
              'איתור מקורות',
              style: TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48), // מאזן את האייקון בצד השני
        ],
      ),
      content: SizedBox(
        key: tourFindRefDialogTargetKey,
        width: 500,
        height: 600,
        child: Column(
          children: [
            BlocBuilder<FindRefBloc, FindRefState>(
              builder: (context, state) {
                final refs = state is FindRefSuccess ? state.refs : [];
                return Focus(
                  onKeyEvent: (node, event) {
                    // טיפול גם ב-KeyDownEvent וגם ב-KeyRepeatEvent (לחיצה רצופה)
                    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                      return KeyEventResult.ignored;
                    }

                    // טיפול בחיצים רק אם יש תוצאות
                    if (refs.isNotEmpty) {
                      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                        setState(() {
                          _selectedIndex =
                              (_selectedIndex + 1).clamp(0, refs.length - 1);
                        });
                        _scrollToSelected();
                        return KeyEventResult.handled;
                      } else if (event.logicalKey ==
                          LogicalKeyboardKey.arrowUp) {
                        setState(() {
                          _selectedIndex =
                              (_selectedIndex - 1).clamp(0, refs.length - 1);
                        });
                        _scrollToSelected();
                        return KeyEventResult.handled;
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: RtlTextField(
                    focusNode: focusRepository.findRefSearchFocusNode,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText:
                          'הקלד מקור מדוייק, לדוגמה: בראשית פרק א או שוע אוח יב   ',
                      suffixIcon: IconButton(
                        icon: const Icon(FluentIcons.dismiss_24_regular),
                        onPressed: () {
                          focusRepository.findRefSearchController.clear();
                          // קודם מבטלים חיפוש שעדיין רץ (restartable יקטוף
                          // את ה-handler הקודם), ורק אחר-כך מחזירים את
                          // ה-state ל-Initial.
                          BlocProvider.of<FindRefBloc>(context)
                              .add(const SearchRefRequested(''));
                          BlocProvider.of<FindRefBloc>(context)
                              .add(ClearSearchRequested());
                          setState(() {
                            _selectedIndex = 0;
                          });
                        },
                      ),
                    ),
                    controller: focusRepository.findRefSearchController,
                    onChanged: (ref) {
                      setState(() => _selectedIndex = 0);
                      // ההקלדה נשלחת מיידית — ה-debounce עצמו מבוצע בתוך
                      // ה-handler ב-bloc, כך שכל הקלדה חדשה גם מבטלת מיידית
                      // כל handler שכבר רץ (גם אם הוא באמצע fetch).
                      BlocProvider.of<FindRefBloc>(context).add(
                        SearchRefRequested(
                          ref,
                          includePersonalBooks: _includePersonalBooks,
                        ),
                      );
                    },
                    onSubmitted: (value) {
                      // פתיחת המקור הנבחר בלחיצה על אנטר
                      if (refs.isNotEmpty) {
                        _openRef(refs[_selectedIndex]);
                      }
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'כלול ספרים אישיים',
                  textDirection: TextDirection.rtl,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(width: 4),
                Transform.scale(
                  scale: 0.75,
                  alignment: Alignment.centerRight,
                  child: Switch(
                    value: _includePersonalBooks,
                    onChanged: (v) {
                      setState(() => _includePersonalBooks = v);
                      final text = focusRepository.findRefSearchController.text;
                      if (text.length >= 2) {
                        context.read<FindRefBloc>().add(
                              SearchRefRequested(
                                text,
                                includePersonalBooks: v,
                              ),
                            );
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: BlocBuilder<FindRefBloc, FindRefState>(
                builder: (context, state) {
                  if (state is FindRefLoading) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (state is FindRefError) {
                    return Text('Error: ${state.message}');
                  } else if (state is FindRefSuccess && state.refs.isEmpty) {
                    if (focusRepository.findRefSearchController.text.length >=
                        3) {
                      return const Center(
                        child: Text(
                          'אין תוצאות',
                          style: TextStyle(fontSize: 16),
                        ),
                      );
                    } else {
                      return const SizedBox.shrink();
                    }
                  } else if (state is FindRefSuccess) {
                    return ListView.builder(
                      itemCount: state.refs.length,
                      itemBuilder: (context, index) {
                        final ref = state.refs[index];
                        final isSelected = index == _selectedIndex;
                        final eligible =
                            !ref.isPdf && ref.bookId > 0 && !ref.isUserBook;
                        // טעינה lazy בעת רינדור — ListView.builder יפעיל את
                        // ה-itemBuilder רק עבור שורות נראות. ה-cache ב-repository
                        // ימנע קריאות חוזרות.
                        if (eligible) _ensureCommentatorsLoaded(ref);
                        final cached =
                            _commentatorsByRef[_commentatorsKey(ref)];
                        final showButton =
                            eligible && cached != null && cached.isNotEmpty;
                        final menuButtonKey = _getCommentatorsButtonKey(index);
                        return Container(
                          key: _getKeyForIndex(index),
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8.0, vertical: 4.0),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : null,
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: ListTile(
                              hoverColor:
                                  showButton ? Colors.transparent : null,
                              leading: ref.isPdf
                                  ? const Icon(
                                      FluentIcons.document_pdf_24_regular)
                                  : null,
                              title: Text(
                                ref.reference,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              subtitle: ref.bookPath.isEmpty
                                  ? null
                                  : LibraryOverflowTooltipText(
                                      text: ref.bookPath,
                                      maxLines: 1,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                              trailing: showButton
                                  ? IconButton(
                                      key: menuButtonKey,
                                      icon: const Icon(
                                          FluentIcons.library_24_regular),
                                      tooltip: 'הצג מפרשים זמינים',
                                      onPressed: () => _showCommentatorsMenu(
                                          ref, menuButtonKey, cached),
                                    )
                                  : null,
                              onTap: () {
                                _openRef(ref);
                              }),
                        );
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('סגור'),
        ),
      ],
    );
  }
}
