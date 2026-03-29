import 'dart:async';
import 'package:otzaria/text_book/bloc/text_book_bloc.dart';
import 'package:otzaria/text_book/text_book_repository.dart';
// [EDITING DISABLED] import 'package:otzaria/text_book/editing/repository/local_overrides_repository.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/data/data_providers/file_system_data_provider.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/tabs/models/tab.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter/foundation.dart';
import 'package:otzaria/search/models/search_configuration.dart';
import 'package:otzaria/text_book/view/page_shape/utils/page_shape_debug_logger.dart';

/// Represents a tab that contains a text book.
///
/// It contains the book itself and a TextBookBloc that manages all the state
/// and business logic for the text book viewing experience.
class TextBookTab extends OpenedTab {
  /// The text book.
  final TextBook book;

  /// The index of the scrollable list.
  int index;

  /// The initial search text for this tab.
  final String searchText;
  final Map<String, Map<String, bool>> searchOptions;
  final Map<int, List<String>> alternativeWords;
  final Map<String, String> spacingValues;
  final SearchMode searchMode;

  /// The bloc that manages the text book state and logic.
  late final TextBookBloc bloc;

  final ItemScrollController scrollController = ItemScrollController();
  final ItemPositionsListener positionsListener =
      ItemPositionsListener.create();
  // בקרים נוספים עבור תצוגה מפוצלת או רשימות מקבילות
  final ItemScrollController auxScrollController = ItemScrollController();
  final ItemPositionsListener auxPositionsListener =
      ItemPositionsListener.create();
  final ScrollOffsetController mainOffsetController = ScrollOffsetController();
  final ScrollOffsetController auxOffsetController = ScrollOffsetController();

  /// הכותרת הנוכחית של המיקום בספר (למשל "בראשית פרק ד")
  final currentTitle = ValueNotifier<String>("");

  List<String>? commentators;
  bool _lastSplitView = false;
  bool _lastShowPageShapeView = false;
  late final String debugScope;

  // StreamSubscription לניהול ה-listener
  StreamSubscription<TextBookState>? _stateSubscription;

  /// Creates a new instance of [TextBookTab].
  ///
  /// The [index] parameter represents the initial index of the item in the scrollable list,
  /// and the [book] parameter represents the text book.
  /// The [searchText] parameter represents the initial search text,
  /// and the [commentators] parameter represents the list of commentaries to show.
  TextBookTab({
    required this.book,
    required this.index,
    this.searchText = '',
    this.searchOptions = const {},
    this.alternativeWords = const {},
    this.spacingValues = const {},
    this.searchMode = SearchMode.exact,
    this.commentators,
    bool openLeftPane = false,
    bool? splitedView,
    bool? showPageShapeView,
    bool isPinned = false,
    String? dedupeKey,
  }) : super(book.title, isPinned: isPinned, dedupeKey: dedupeKey) {
    debugScope = PageShapeDebugLogger.newScope(
      'text-tab',
      label: book.title,
    );
    final trace = PageShapeDebugLogger.start(
      'TextBookTab',
      'יצירת טאב טקסט',
      scope: debugScope,
      data: {
        'bookTitle': book.title,
        'index': index,
        'searchTextLength': searchText.length,
        'commentatorsCount': commentators?.length,
        'openLeftPane': openLeftPane,
        'splitedViewArg': splitedView,
        'showPageShapeViewArg': showPageShapeView,
        'isPinned': isPinned,
        'dedupeKey': dedupeKey,
      },
    );

    // קביעת ברירת המחדל של splitedView מההגדרות אם לא סופק
    final bool effectiveSplitedView =
        splitedView ?? (Settings.getValue<bool>('key-splited-view') ?? false);

    // מצב צורת הדף הוא פר-ספר - ברירת המחדל היא false (תצוגה רגילה)
    // רק אם הספר כבר היה פתוח במצב צורת הדף, הוא יישאר כך
    final bool effectiveShowPageShapeView = showPageShapeView ?? false;

    _lastSplitView = effectiveSplitedView;
    _lastShowPageShapeView = effectiveShowPageShapeView;
    trace.step(
      'חושבו דגלי התצוגה האפקטיביים',
      data: {
        'effectiveSplitedView': effectiveSplitedView,
        'effectiveShowPageShapeView': effectiveShowPageShapeView,
      },
    );

    // Initialize the bloc with initial state
    bloc = TextBookBloc(
      repository: TextBookRepository(
        fileSystem: FileSystemData.instance,
      ),
      // [EDITING DISABLED] overridesRepository: LocalOverridesRepository(),
      initialState: TextBookInitial.named(
        book,
        index,
        openLeftPane,
        commentators ?? [],
        searchText: searchText,
        searchOptions: searchOptions,
        alternativeWords: alternativeWords,
        spacingValues: spacingValues,
        searchMode: searchMode,
        splitedView: effectiveSplitedView,
        showPageShapeView: effectiveShowPageShapeView,
      ),
      scrollController: scrollController,
      positionsListener: positionsListener,
    );
    trace.step(
      'נוצר TextBookBloc',
      data: {
        'blocState': bloc.state.runtimeType,
      },
    );

    // הוספת listener לעדכון האינדקס כשה-state משתנה
    _stateSubscription = bloc.stream.listen((state) {
      if (state is TextBookLoaded && state.visibleIndices.isNotEmpty) {
        final previousIndex = index;
        final previousSplitView = _lastSplitView;
        final previousPageShape = _lastShowPageShapeView;
        index = state.visibleIndices.first;
        _lastSplitView = state.showSplitView;
        _lastShowPageShapeView = state.showPageShapeView;
        // עדכון הכותרת הנוכחית
        if (state.currentTitle != null && state.currentTitle!.isNotEmpty) {
          currentTitle.value = state.currentTitle!;
        }
        PageShapeDebugLogger.log(
          'TextBookTab',
          'עודכן מצב טאב מזרם ה־bloc',
          scope: debugScope,
          data: {
            ...PageShapeDebugLogger.summarizeIndices(state.visibleIndices),
            'selectedIndex': state.selectedIndex,
            'showSplitView': state.showSplitView,
            'showPageShapeView': state.showPageShapeView,
            'showLeftPane': state.showLeftPane,
            'activeCommentatorsCount': state.activeCommentators.length,
            'linksCount': state.links.length,
            'changedIndex': previousIndex != index,
            'changedSplitView': previousSplitView != _lastSplitView,
            'changedPageShapeView':
                previousPageShape != _lastShowPageShapeView,
            'currentTitle': state.currentTitle,
          },
        );
      }
    });
    trace.end(
      data: {
        'initialBlocState': bloc.state.runtimeType,
      },
    );
  }

  /// Cleanup when the tab is disposed
  @override
  void dispose() {
    PageShapeDebugLogger.log(
      'TextBookTab',
      'dispose לטאב טקסט',
      scope: debugScope,
      data: {
        'bookTitle': book.title,
        'index': index,
        'lastSplitView': _lastSplitView,
        'lastShowPageShapeView': _lastShowPageShapeView,
      },
      level: 'END',
    );
    _stateSubscription?.cancel();
    currentTitle.dispose();
    bloc.close();
    super.dispose();
  }

  /// Creates a new instance of [TextBookTab] from a JSON map.
  ///
  /// The JSON map should have 'initalIndex', 'title', 'commentaries',
  /// and 'type' keys.
  factory TextBookTab.fromJson(Map<String, dynamic> json) {
    final scope = PageShapeDebugLogger.newScope(
      'text-tab-from-json',
      label: json['title']?.toString(),
    );
    final trace = PageShapeDebugLogger.start(
      'TextBookTab',
      'שחזור טאב מ־JSON',
      scope: scope,
      data: {
        'title': json['title'],
        'initialIndex': json['initalIndex'],
        'jsonSplitedView': json['splitedView'],
        'jsonShowPageShapeView': json['showPageShapeView'],
        'jsonIsPinned': json['isPinned'],
      },
    );
    // במצב side-by-side, חלונית הצד תמיד סגורה
    // אחרת, לפי ההגדרות
    final bool shouldOpenLeftPane =
        (Settings.getValue<bool>('key-pin-sidebar') ?? false) ||
            (Settings.getValue<bool>('key-default-sidebar-open') ?? false);

    // שחזור מצב התצוגה המפוצלת מה-JSON
    final bool splitedView = json['splitedView'] ??
        (Settings.getValue<bool>('key-splited-view') ?? false);

    final TextBook restoredBook = json['book'] != null
        ? Book.fromJson(Map<String, dynamic>.from(json['book'])) as TextBook
        : TextBook(
            title: json['title'],
          );
    trace.step(
      'פוענח ספר משוחזר',
      data: {
        'restoredBookTitle': restoredBook.title,
        'restoredCategoryId': restoredBook.categoryId,
        'shouldOpenLeftPane': shouldOpenLeftPane,
      },
    );

    try {
      final tab = TextBookTab(
        index: json['initalIndex'],
        book: restoredBook,
        commentators: List<String>.from(json['commentators']),
        splitedView: splitedView,
        showPageShapeView: json['showPageShapeView'] ?? false,
        openLeftPane: shouldOpenLeftPane,
        isPinned: json['isPinned'] ?? false,
      );
      trace.end(
        data: {
          'restoredDebugScope': tab.debugScope,
          'restoredShowPageShapeView': json['showPageShapeView'] ?? false,
        },
      );
      return tab;
    } catch (error, stackTrace) {
      trace.fail(error, stackTrace);
      rethrow;
    }
  }

  /// Converts the [TextBookTab] instance into a JSON map.
  ///
  /// The JSON map contains 'title', 'initalIndex', 'commentaries',
  /// and 'type' keys.
  @override
  Map<String, dynamic> toJson() {
    final trace = PageShapeDebugLogger.start(
      'TextBookTab',
      'שמירת טאב ל־JSON',
      scope: debugScope,
      data: {
        'bookTitle': book.title,
        'currentIndexField': index,
      },
      longTaskAfter: const Duration(milliseconds: 300),
      heartbeatEvery: const Duration(milliseconds: 300),
    );
    List<String> commentators = [];
    bool splitedView = _lastSplitView;
    bool showPageShapeView = _lastShowPageShapeView;
    int currentIndex = index; // שמירת האינדקס הנוכחי כברירת מחדל

    if (bloc.state is TextBookLoaded) {
      final loadedState = bloc.state as TextBookLoaded;
      commentators = loadedState.activeCommentators;
      splitedView = loadedState.showSplitView;
      showPageShapeView = loadedState.showPageShapeView;
      // עדכון האינדקס מה-state הנטען - תמיד לוקחים את האינדקס האחרון שנראה
      if (loadedState.visibleIndices.isNotEmpty) {
        currentIndex = loadedState.visibleIndices.first;
        // עדכון גם את ה-index של הטאב עצמו כדי שישמר
        index = currentIndex;
      }
    }
    trace.step(
      'חושב payload לשמירה',
      data: {
        'currentIndex': currentIndex,
        'commentatorsCount': commentators.length,
        'splitedView': splitedView,
        'showPageShapeView': showPageShapeView,
        'blocState': bloc.state.runtimeType,
      },
    );

    final result = {
      'title': title,
      'book': book.toJson(),
      'initalIndex': currentIndex,
      'commentators': commentators,
      'splitedView': splitedView,
      'showPageShapeView': showPageShapeView,
      'isPinned': isPinned,
      'type': 'TextBookTab'
    };
    trace.end(
      data: {
        'resultKeys': result.keys.toList(),
      },
    );
    return result;
  }
}
