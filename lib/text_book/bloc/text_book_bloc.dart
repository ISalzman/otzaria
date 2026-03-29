import 'dart:async';
import 'package:otzaria/models/books.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:otzaria/models/links.dart';
import 'package:otzaria/models/link_types.dart';
import 'package:otzaria/text_book/bloc/text_book_event.dart';
import 'package:otzaria/text_book/text_book_repository.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/text_book/models/commentator_group.dart';
import 'package:otzaria/utils/ref_helper.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:otzaria/utils/text_manipulation.dart' as utils;
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/data/data_providers/file_system_data_provider.dart';
import 'package:otzaria/data/data_providers/sqlite_data_provider.dart';
// [EDITING DISABLED] import 'package:otzaria/text_book/editing/repository/overrides_repository.dart';
// [EDITING DISABLED] import 'package:otzaria/text_book/editing/models/section_identifier.dart';
import 'package:otzaria/search/models/search_configuration.dart';
import 'package:otzaria/settings/services/nikud_display_service.dart';
import 'package:otzaria/text_book/view/page_shape/utils/default_commentators.dart';
import 'package:otzaria/text_book/view/page_shape/utils/page_shape_commentary_selection.dart';
import 'package:otzaria/text_book/view/page_shape/utils/page_shape_settings_manager.dart';
import 'package:otzaria/text_book/view/page_shape/utils/page_shape_debug_logger.dart';
import 'package:otzaria/migration/core/models/category.dart' as db;

List<Link> _mergeLinksByIdentity(
  List<Link> existing,
  List<Link> incoming, {
  String? debugScope,
}) {
  final stopwatch = Stopwatch()..start();
  final merged = <String, Link>{
    for (final link in existing) _linkIdentityKey(link): link,
  };
  final seededCount = merged.length;
  final seedElapsedMs = stopwatch.elapsedMilliseconds;

  for (final link in incoming) {
    merged[_linkIdentityKey(link)] = link;
  }
  final mergeElapsedMs = stopwatch.elapsedMilliseconds;

  final links = merged.values.toList();
  final preSortCount = links.length;
  final sortStartedAtMs = stopwatch.elapsedMilliseconds;
  links.sort((a, b) {
    final indexCompare = a.index1.compareTo(b.index1);
    if (indexCompare != 0) return indexCompare;

    final pathCompare = a.path2.compareTo(b.path2);
    if (pathCompare != 0) return pathCompare;

    final targetCompare = a.index2.compareTo(b.index2);
    if (targetCompare != 0) return targetCompare;

    return a.connectionType.compareTo(b.connectionType);
  });

  if (debugScope != null) {
    PageShapeDebugLogger.log(
      'TextBookBloc',
      'הושלם _mergeLinksByIdentity',
      scope: debugScope,
      data: {
        'existingCount': existing.length,
        'incomingCount': incoming.length,
        'seededUniqueCount': seededCount,
        'preSortCount': preSortCount,
        'seedElapsedMs': seedElapsedMs,
        'mergeElapsedMs': mergeElapsedMs - seedElapsedMs,
        'sortElapsedMs': stopwatch.elapsedMilliseconds - sortStartedAtMs,
        'totalElapsedMs': stopwatch.elapsedMilliseconds,
      },
      level: 'STEP',
    );
  }

  return links;
}

String _linkIdentityKey(Link link) {
  return '${link.index1}|${link.path2}|${link.index2}|${link.connectionType}|${link.start}|${link.end}';
}

List<String> _buildPreviewLines(String previewContent, int previewStartLine) {
  final previewLines = previewContent.split('\n');
  if (previewStartLine <= 0) {
    return previewLines;
  }

  return List<String>.filled(previewStartLine, '', growable: true)
    ..addAll(previewLines);
}

class TextBookBloc extends Bloc<TextBookEvent, TextBookState> {
  static const int _linkLookBehindLines = 25;
  static const int _linkLookAheadLines = 50;
  static const String _allTargetBookTitlesSignature =
      '__all_target_book_titles__';

  final TextBookRepository repository;
  // [EDITING DISABLED] final OverridesRepository _overridesRepository;
  final ItemScrollController scrollController;
  final ItemPositionsListener positionsListener;

  Timer? _debounceTimer;
  Timer? _highlightTimer;
  VoidCallback? _positionListenerCallback;
  int? _loadedLinksStart;
  int? _loadedLinksEnd;
  String? _loadedLinksBookTitle;
  String? _loadedLinksTargetBookTitlesSignature;
  String? _activeLinksTargetBookTitlesSignature;
  bool _isLoadingLinks = false;
  bool _pendingLinksReload = false; // בקשת טעינה שנדחתה בגלל _isLoadingLinks
  final String _debugScope;
  int _visibleIndicesUpdateCount = 0;
  int _rawPositionListenerCallbackCount = 0;
  int _debounceScheduleCount = 0;
  int _debounceCancelCount = 0;
  bool _didLogFirstRawPositionsSnapshot = false;
  String? _lastRawPositionsSignature;
  bool _awaitingInitialPageShapeVisibleSync = false;

  TextBookBloc({
    required this.repository,
    // [EDITING DISABLED] required OverridesRepository overridesRepository,
    required TextBookInitial initialState,
    required this.scrollController,
    required this.positionsListener,
  })  : // [EDITING DISABLED] _overridesRepository = overridesRepository,
        _debugScope = PageShapeDebugLogger.newScope(
          'text-book-bloc',
          label: initialState.book.title,
        ),
        super(initialState) {
    PageShapeDebugLogger.log(
      'TextBookBloc',
      'נוצר bloc חדש',
      scope: _debugScope,
      data: _stateSummary(initialState),
    );
    on<LoadContent>(_onLoadContent);
    on<UpdateFontSize>(_onUpdateFontSize);
    on<ToggleLeftPane>(_onToggleLeftPane);
    on<ToggleSplitView>(_onToggleSplitView);
    on<ToggleTzuratHadafView>(_onToggleTzuratHadafView);
    on<TogglePageShapeView>(_onTogglePageShapeView);
    on<UpdateCommentators>(_onUpdateCommentators);
    on<ToggleNikud>(_onToggleNikud);
    on<TogglePunctuation>(_onTogglePunctuation);
    on<UpdateVisibleIndecies>(_onUpdateVisibleIndecies);
    on<UpdateSelectedIndex>(_onUpdateSelectedIndex);
    on<HighlightLine>(_onHighlightLine);
    on<ClearHighlightedLine>(_onClearHighlightedLine);
    on<TogglePinLeftPane>(_onTogglePinLeftPane);
    on<UpdateSearchText>(_onUpdateSearchText);
    on<ApplyFullBookContent>(_onApplyFullBookContent);
    on<CreateNoteFromToolbar>(_onCreateNoteFromToolbar);
    on<UpdateSelectedTextForNote>(_onUpdateSelectedTextForNote);

    // [EDITING DISABLED] Editor events
    // on<OpenEditor>(_onOpenEditor);
    // on<OpenFullFileEditor>(_onOpenFullFileEditor);
    // on<SaveEditedSection>(_onSaveEditedSection);
    // on<LoadDraftIfAny>(_onLoadDraftIfAny);
    // on<DiscardDraft>(_onDiscardDraft);
    // on<CloseEditor>(_onCloseEditor);
    // on<UpdateEditorText>(_onUpdateEditorText);
    // on<AutoSaveDraft>(_onAutoSaveDraft);
    on<UpdateLinks>(_onUpdateLinks);
    on<UpdateAvailableCommentators>(_onUpdateAvailableCommentators);
    on<RefreshLinksForCurrentWindow>(_onRefreshLinksForCurrentWindow);
  }

  @visibleForTesting
  static int? expectedInitialPageShapeVisibleIndexForTesting({
    required List<int> visibleIndices,
    required int? selectedIndex,
  }) {
    if (visibleIndices.isNotEmpty) {
      return visibleIndices.first;
    }
    return selectedIndex;
  }

  int? _expectedInitialPageShapeVisibleIndex(TextBookLoaded state) {
    return expectedInitialPageShapeVisibleIndexForTesting(
      visibleIndices: state.visibleIndices,
      selectedIndex: state.selectedIndex,
    );
  }

  @visibleForTesting
  static bool isInitialPageShapeVisibleSyncAlignedForTesting({
    required List<int> currentVisibleIndices,
    required int? selectedIndex,
    required List<int> nextVisibleIndices,
  }) {
    final expectedIndex = expectedInitialPageShapeVisibleIndexForTesting(
      visibleIndices: currentVisibleIndices,
      selectedIndex: selectedIndex,
    );
    if (expectedIndex == null || nextVisibleIndices.isEmpty) {
      return true;
    }

    final minVisible = nextVisibleIndices.reduce((a, b) => a < b ? a : b);
    final maxVisible = nextVisibleIndices.reduce((a, b) => a > b ? a : b);
    const tolerance = 2;

    return expectedIndex >= (minVisible - tolerance) &&
        expectedIndex <= (maxVisible + tolerance);
  }

  bool _isInitialPageShapeVisibleSyncAligned(
    TextBookLoaded state,
    List<int> nextVisibleIndices,
  ) {
    return isInitialPageShapeVisibleSyncAlignedForTesting(
      currentVisibleIndices: state.visibleIndices,
      selectedIndex: state.selectedIndex,
      nextVisibleIndices: nextVisibleIndices,
    );
  }

  @visibleForTesting
  static ({bool shouldIgnore, bool shouldDispatchImmediately})
      classifyRawPositionsDuringInitialPageShapeVisibleSyncForTesting({
    required bool awaitingInitialPageShapeVisibleSync,
    required bool showPageShapeView,
    required List<int> currentVisibleIndices,
    required int? selectedIndex,
    required List<int> nextVisibleIndices,
  }) {
    if (!awaitingInitialPageShapeVisibleSync ||
        !showPageShapeView ||
        nextVisibleIndices.isEmpty) {
      return (
        shouldIgnore: false,
        shouldDispatchImmediately: false,
      );
    }

    final isAligned = isInitialPageShapeVisibleSyncAlignedForTesting(
      currentVisibleIndices: currentVisibleIndices,
      selectedIndex: selectedIndex,
      nextVisibleIndices: nextVisibleIndices,
    );
    return (
      shouldIgnore: !isAligned,
      shouldDispatchImmediately: isAligned,
    );
  }

  void _setAwaitingInitialPageShapeVisibleSync(
    bool value, {
    TextBookLoaded? stateForExpectedIndex,
    String? reason,
  }) {
    _awaitingInitialPageShapeVisibleSync = value;
    PageShapeDebugLogger.log(
      'TextBookBloc',
      value
          ? 'הופעל מצב המתנה ליישור גלילה ראשוני בצורת הדף'
          : 'כובה מצב המתנה ליישור גלילה ראשוני בצורת הדף',
      scope: _debugScope,
      data: {
        'reason': reason,
        'expectedIndex': stateForExpectedIndex == null
            ? null
            : _expectedInitialPageShapeVisibleIndex(stateForExpectedIndex),
      },
      level: 'SCROLL',
    );
  }

  static Map<String, Object?> _stateSummary(TextBookState state) {
    if (state is TextBookInitial) {
      return {
        'stateType': state.runtimeType,
        'bookTitle': state.book.title,
        'index': state.index,
        'showLeftPane': state.showLeftPane,
        'commentatorsCount': state.commentators.length,
        'splitedView': state.splitedView,
        'showPageShapeView': state.showPageShapeView,
        'searchTextLength': state.searchText.length,
      };
    }

    if (state is TextBookLoading) {
      return {
        'stateType': state.runtimeType,
        'bookTitle': state.book.title,
        'index': state.index,
        'showLeftPane': state.showLeftPane,
        'commentatorsCount': state.commentators.length,
      };
    }

    if (state is TextBookError) {
      return {
        'stateType': state.runtimeType,
        'bookTitle': state.book.title,
        'index': state.index,
        'showLeftPane': state.showLeftPane,
        'message': state.message,
      };
    }

    if (state is TextBookLoaded) {
      return {
        'stateType': state.runtimeType,
        'bookTitle': state.book.title,
        'contentLines': state.content.length,
        'linksCount': state.links.length,
        'visibleLinksCount': state.visibleLinks.length,
        'availableCommentatorsCount': state.availableCommentators.length,
        'activeCommentatorsCount': state.activeCommentators.length,
        'showSplitView': state.showSplitView,
        'showPageShapeView': state.showPageShapeView,
        'showLeftPane': state.showLeftPane,
        'selectedIndex': state.selectedIndex,
        ...PageShapeDebugLogger.summarizeIndices(state.visibleIndices),
      };
    }

    return {
      'stateType': state.runtimeType,
      'bookTitle': state.book.title,
      'index': state.index,
    };
  }

  static Map<String, Object?> _eventSummary(TextBookEvent event) {
    switch (event) {
      case LoadContent():
        return {
          'eventType': event.runtimeType,
          'fontSize': event.fontSize,
          'showSplitView': event.showSplitView,
          'removeNikud': event.removeNikud,
          'preserveState': event.preserveState,
          'loadCommentators': event.loadCommentators,
          'forceCloseLeftPane': event.forceCloseLeftPane,
        };
      case TogglePageShapeView():
        return {
          'eventType': event.runtimeType,
          'show': event.show,
        };
      case ToggleSplitView():
        return {
          'eventType': event.runtimeType,
          'show': event.show,
        };
      case ToggleLeftPane():
        return {
          'eventType': event.runtimeType,
          'show': event.show,
        };
      case UpdateVisibleIndecies():
        return {
          'eventType': event.runtimeType,
          ...PageShapeDebugLogger.summarizeIndices(event.visibleIndecies),
        };
      case UpdateSelectedIndex():
        return {
          'eventType': event.runtimeType,
          'index': event.index,
        };
      case HighlightLine():
        return {
          'eventType': event.runtimeType,
          'lineIndex': event.lineIndex,
        };
      case ClearHighlightedLine():
        return {
          'eventType': event.runtimeType,
          'lineIndex': event.lineIndex,
        };
      case UpdateCommentators():
        return {
          'eventType': event.runtimeType,
          'commentatorsCount': event.commentators.length,
          'commentators': event.commentators,
        };
      case UpdateLinks():
        return {
          'eventType': event.runtimeType,
          'incomingLinksCount': event.links.length,
          'replaceExisting': event.replaceExisting,
          'targetBookTitlesSignature': event.targetBookTitlesSignature,
        };
      case UpdateAvailableCommentators():
        return {
          'eventType': event.runtimeType,
          'availableCommentatorsCount': event.availableCommentators.length,
          'commentatorGroupsCount': event.commentatorGroups.length,
        };
      case RefreshLinksForCurrentWindow():
        return {
          'eventType': event.runtimeType,
          'reason': event.reason,
        };
      case UpdateSearchText():
        return {
          'eventType': event.runtimeType,
          'textLength': event.text.length,
          'textPreview': event.text,
        };
      case ApplyFullBookContent():
        return {
          'eventType': event.runtimeType,
          'bookTitle': event.bookTitle,
          'contentLines': event.content.length,
        };
      default:
        return {
          'eventType': event.runtimeType,
        };
    }
  }

  @visibleForTesting
  static List<Link> mergeLinksForTesting(
      List<Link> existing, List<Link> incoming) {
    return _mergeLinksByIdentity(existing, incoming);
  }

  @visibleForTesting
  static List<String> buildPreviewLinesForTesting(
      String previewContent, int previewStartLine) {
    return _buildPreviewLines(previewContent, previewStartLine);
  }

  @override
  void onEvent(TextBookEvent event) {
    PageShapeDebugLogger.log(
      'TextBookBloc',
      'EVENT ${event.runtimeType}',
      scope: _debugScope,
      data: _eventSummary(event),
      level: 'EVENT',
    );
    super.onEvent(event);
  }

  @override
  void onChange(Change<TextBookState> change) {
    PageShapeDebugLogger.log(
      'TextBookBloc',
      'STATE CHANGE',
      scope: _debugScope,
      data: {
        'currentStateType': change.currentState.runtimeType,
        'nextStateType': change.nextState.runtimeType,
        'nextState': _stateSummary(change.nextState),
      },
      level: 'STATE',
    );
    super.onChange(change);
  }

  Future<void> _onLoadContent(
    LoadContent event,
    Emitter<TextBookState> emit,
  ) async {
    final trace = PageShapeDebugLogger.start(
      'TextBookBloc',
      'LoadContent',
      scope: _debugScope,
      data: {
        ..._eventSummary(event),
        'stateBefore': _stateSummary(state),
      },
    );
    TextBook book;
    String searchText;
    Map<String, Map<String, bool>> searchOptions = {};
    Map<int, List<String>> alternativeWords = {};
    Map<String, String> spacingValues = {};
    SearchMode searchMode = SearchMode.exact;
    bool showLeftPane;
    List<String> commentators;
    late final List<int> visibleIndices;

    bool initialShowPageShapeView = false;

    // שמירת מפרשים קיימים כדי לא לאבד אותם ב-preserveState reload
    List<String> existingAvailableCommentators = const [];
    List<CommentatorGroup> existingCommentatorGroups = const [];

    if (state is TextBookLoaded && event.preserveState) {
      // Preserve current state when reloading
      final currentState = state as TextBookLoaded;
      book = currentState.book;
      searchText = currentState.searchText;
      searchOptions = currentState.searchOptions;
      alternativeWords = currentState.alternativeWords;
      spacingValues = currentState.spacingValues;
      searchMode = currentState.searchMode;
      showLeftPane = currentState.showLeftPane;
      commentators = currentState.activeCommentators;
      visibleIndices = currentState.visibleIndices;
      initialShowPageShapeView = currentState.showPageShapeView;
      existingAvailableCommentators = currentState.availableCommentators;
      existingCommentatorGroups = currentState.commentatorGroups;
      trace.step(
        'מצב preserveState אותר',
        data: {
          'bookTitle': book.title,
          'visibleIndices': visibleIndices,
          'existingAvailableCommentatorsCount':
              existingAvailableCommentators.length,
          'existingCommentatorGroupsCount': existingCommentatorGroups.length,
          'initialShowPageShapeView': initialShowPageShapeView,
        },
      );
    } else if (state is TextBookInitial) {
      // Normal initial load
      final initial = state as TextBookInitial;
      book = initial.book;
      searchText = initial.searchText;
      searchOptions = initial.searchOptions;
      alternativeWords = initial.alternativeWords;
      spacingValues = initial.spacingValues;
      searchMode = initial.searchMode;
      showLeftPane = initial.showLeftPane;
      commentators = initial.commentators;
      visibleIndices = [initial.index < 0 ? 0 : initial.index];
      initialShowPageShapeView = initial.showPageShapeView;

      emit(TextBookLoading(
          book, initial.index, initial.showLeftPane, initial.commentators));
      trace.step(
        'זוהתה טעינה ראשונית ונפלט TextBookLoading',
        data: {
          'bookTitle': book.title,
          'initialIndex': initial.index,
          'visibleIndices': visibleIndices,
          'initialShowPageShapeView': initialShowPageShapeView,
        },
      );
    } else if (!event.preserveState) {
      // Not preserving state and not initial, just emit current state
      if (state is TextBookLoaded) {
        emit(state);
        trace.warn(
          'התקבל LoadContent ללא preserveState כשה־state כבר Loaded; נפלט אותו state',
          data: _stateSummary(state),
        );
      }
      trace.end(data: {'reason': 'state not initial and preserveState=false'});
      return;
    } else {
      trace.warn(
        'שילוב מצב/אירוע לא תקין עבור LoadContent',
        data: {
          'stateType': state.runtimeType,
          'preserveState': event.preserveState,
        },
      );
      trace.end(data: {'reason': 'invalid state combination'});
      return; // Invalid state combination
    }

    try {
      // ── שלב 1: התחלת טעינות מקבילות ──
      // מתחילים את טעינת TOC במקביל לטעינת התוכן כדי לחסוך זמן
      final tocFuture = repository.getTableOfContents(book);
      trace.step(
        'התחילה טעינת TOC במקביל',
        data: {
          'bookTitle': book.title,
        },
      );

      // טעינת תוכן הספר (עם fallback ל-preview אם ריק)
      final sqliteProvider = SqliteDataProvider.instance;
      String content = await repository.getBookContent(book);
      trace.step(
        'התקבלה תשובת תוכן ראשונית',
        data: {
          'bookTitle': book.title,
          'contentLength': content.length,
        },
      );
      if (content.isEmpty) {
        trace.warn(
          'תוכן הספר חזר ריק; מנסים quick preview',
          data: {
            'bookTitle': book.title,
            'visibleIndex': visibleIndices.first,
          },
        );
        // Load quick preview (40 lines) for instant display
        final preview = await sqliteProvider.getBookQuickPreview(
          book.title,
          visibleIndices.first,
        );
        trace.step(
          'התקבלה תשובת quick preview',
          data: {
            'previewLength': preview?.length ?? 0,
            'previewWasNull': preview == null,
          },
        );

        if (preview != null && preview.isNotEmpty) {
          final previewStartLine =
              (visibleIndices.first - 10).clamp(0, visibleIndices.first);
          content = _buildPreviewLines(preview, previewStartLine).join('\n');
          trace.step(
            'נעשה שימוש ב־preview ונקבעה טעינת רקע מלאה',
            data: {
              'previewStartLine': previewStartLine,
              'contentLengthAfterPreview': content.length,
            },
          );

          // Load full book in background
          _loadFullBookInBackground(book);
        } else {
          // Preview failed, load full book normally
          trace.warn('quick preview נכשל או חזר ריק; נטען תוכן מלא מחדש');
          content = await repository.getBookContent(book);
          trace.step(
            'הושלמה טעינת תוכן מלא חוזרת אחרי כשל preview',
            data: {
              'contentLength': content.length,
            },
          );
        }
      }

      // ── שלב 2: המתנה ל-TOC (כבר רץ במקביל, צפוי להיות מוכן) ──
      final tableOfContents = await tocFuture;
      trace.step(
        'TOC נטען',
        data: {
          'tocEntries': tableOfContents.length,
        },
      );

      // ── שלב 3: חישובים מהירים שלא דורשים I/O כבד ──
      // חישוב כותרת נוכחית (תלוי ב-TOC שכבר מוכן)
      String? currentTitle;
      if (visibleIndices.isNotEmpty) {
        try {
          trace.step(
            'לפני חישוב currentTitle באמצעות refFromIndex',
            data: {
              'visibleIndex': visibleIndices.first,
              'tocEntries': tableOfContents.length,
            },
          );
          currentTitle = await refFromIndex(
              visibleIndices.first, Future.value(tableOfContents));
          trace.step(
            'הסתיים חישוב currentTitle באמצעות refFromIndex',
            data: {
              'visibleIndex': visibleIndices.first,
              'currentTitle': currentTitle,
            },
          );
        } catch (_) {
          currentTitle = null;
          trace.warn(
            'נכשל חישוב currentTitle',
            data: {
              'visibleIndex': visibleIndices.first,
            },
          );
        }
      }
      trace.step(
        'חושב currentTitle',
        data: {
          'currentTitle': currentTitle,
        },
      );

      // הגדרות ניקוד (קריאות Settings סינכרוניות + בדיקת נתיב קלה)
      final defaultRemoveNikud =
          Settings.getValue<bool>('key-default-nikud') ?? false;
      final removeNikudFromTanach =
          Settings.getValue<bool>('key-remove-nikud-tanach') ?? false;
      final isTanach = await FileSystemData.instance.isTanachBook(
        book.title,
        categoryId: book.categoryId,
        fileType: book.fileType,
      );
      final removeNikud = shouldRemoveNikudForBook(
        defaultRemoveNikud: defaultRemoveNikud,
        removeNikudFromTanach: removeNikudFromTanach,
        isTanach: isTanach,
      );
      trace.step(
        'חושבו הגדרות ניקוד/תנ"ך',
        data: {
          'defaultRemoveNikud': defaultRemoveNikud,
          'removeNikudFromTanach': removeNikudFromTanach,
          'isTanach': isTanach,
          'removeNikud': removeNikud,
        },
      );

      // קישורים מתחילים ריקים - יטענו ברקע אחרי הצגת הספר
      const List<Link> emptyLinks = [];
      const List<Link> emptyVisibleLinks = [];

      // Set up position listener with debouncing to prevent excessive updates
      // Remove old listener if exists
      if (_positionListenerCallback != null) {
        positionsListener.itemPositions
            .removeListener(_positionListenerCallback!);
        trace.step('listener ישן של positionsListener הוסר');
      }

      _positionListenerCallback = () {
        final rawPositions = positionsListener.itemPositions.value.toList()
          ..sort((a, b) => a.index.compareTo(b.index));
        final visibleIndicesNow =
            rawPositions.map((position) => position.index).toList();
        final rawSignature = _itemPositionsSignature(rawPositions);
        final isSameAsPreviousRawPositions =
            rawSignature == _lastRawPositionsSignature;
        _rawPositionListenerCallbackCount++;
        PageShapeDebugLogger.log(
          'TextBookBloc',
          'positionsListener raw callback נורה',
          scope: _debugScope,
          data: {
            'rawCallbackCount': _rawPositionListenerCallbackCount,
            'sameAsPreviousRawPositions': isSameAsPreviousRawPositions,
            'debounceActive': _debounceTimer?.isActive ?? false,
            ..._summarizeItemPositions(rawPositions),
          },
          level: 'SCROLL',
        );
        if (!_didLogFirstRawPositionsSnapshot && rawPositions.isNotEmpty) {
          _didLogFirstRawPositionsSnapshot = true;
          PageShapeDebugLogger.log(
            'TextBookBloc',
            'התקבל snapshot ראשון של positionsListener',
            scope: _debugScope,
            data: {
              'rawCallbackCount': _rawPositionListenerCallbackCount,
              ..._summarizeItemPositions(rawPositions),
            },
            level: 'SCROLL',
          );
        }
        _lastRawPositionsSignature = rawSignature;

        final currentState = state;
        if (currentState is TextBookLoaded) {
          final initialSyncClassification =
              classifyRawPositionsDuringInitialPageShapeVisibleSyncForTesting(
            awaitingInitialPageShapeVisibleSync:
                _awaitingInitialPageShapeVisibleSync,
            showPageShapeView: currentState.showPageShapeView,
            currentVisibleIndices: currentState.visibleIndices,
            selectedIndex: currentState.selectedIndex,
            nextVisibleIndices: visibleIndicesNow,
          );
          if (initialSyncClassification.shouldIgnore ||
              initialSyncClassification.shouldDispatchImmediately) {
            final expectedIndex =
                _expectedInitialPageShapeVisibleIndex(currentState);

            if (initialSyncClassification.shouldIgnore) {
              PageShapeDebugLogger.log(
                'TextBookBloc',
                'raw positions דולגו לפני debounce בזמן המתנה ליישור גלילה ראשוני בצורת הדף',
                scope: _debugScope,
                data: {
                  'expectedIndex': expectedIndex,
                  ...PageShapeDebugLogger.summarizeIndices(visibleIndicesNow),
                },
                level: 'SCROLL',
              );
              return;
            }

            if (_debounceTimer?.isActive ?? false) {
              _debounceCancelCount++;
              PageShapeDebugLogger.log(
                'TextBookBloc',
                'debounce קיים בוטל לפני שליחת יישור ראשוני מיידי',
                scope: _debugScope,
                data: {
                  'rawCallbackCount': _rawPositionListenerCallbackCount,
                  'debounceCancelCount': _debounceCancelCount,
                },
                level: 'SCROLL',
              );
            }
            _debounceTimer?.cancel();
            PageShapeDebugLogger.log(
              'TextBookBloc',
              'raw positions מיושרים נשלחו מיידית ללא debounce בצורת הדף',
              scope: _debugScope,
              data: {
                'expectedIndex': expectedIndex,
                ...PageShapeDebugLogger.summarizeIndices(visibleIndicesNow),
              },
              level: 'SCROLL',
            );
            add(UpdateVisibleIndecies(visibleIndicesNow));
            return;
          }
        }

        // Cancel previous timer if exists
        if (_debounceTimer?.isActive ?? false) {
          _debounceCancelCount++;
          PageShapeDebugLogger.log(
            'TextBookBloc',
            'debounce קיים בוטל לפני תזמון חדש',
            scope: _debugScope,
            data: {
              'rawCallbackCount': _rawPositionListenerCallbackCount,
              'debounceCancelCount': _debounceCancelCount,
            },
            level: 'SCROLL',
          );
        }
        _debounceTimer?.cancel();

        // Set new timer with 100ms delay
        final debounceScheduleId = ++_debounceScheduleCount;
        PageShapeDebugLogger.log(
          'TextBookBloc',
          'תוזמן debounce חדש ל־positionsListener',
          scope: _debugScope,
          data: {
            'debounceScheduleCount': _debounceScheduleCount,
            'debounceScheduleId': debounceScheduleId,
            'delayMs': 100,
            ...PageShapeDebugLogger.summarizeIndices(visibleIndicesNow),
          },
          level: 'SCROLL',
        );
        _debounceTimer = Timer(const Duration(milliseconds: 100), () {
          if (isClosed) {
            PageShapeDebugLogger.log(
              'TextBookBloc',
              'debounce של positionsListener בוטל כי ה־bloc סגור',
              scope: _debugScope,
              data: {
                'debounceScheduleId': debounceScheduleId,
              },
              level: 'SCROLL',
            );
            return;
          }

          final debouncedRawPositions = positionsListener.itemPositions.value
              .toList()
            ..sort((a, b) => a.index.compareTo(b.index));
          final visibleIndicesNow =
              debouncedRawPositions.map((e) => e.index).toList();
          if (visibleIndicesNow.isNotEmpty) {
            PageShapeDebugLogger.log(
              'TextBookBloc',
              'positionsListener debounce הסתיים ונשלח UpdateVisibleIndecies',
              scope: _debugScope,
              data: {
                'debounceScheduleId': debounceScheduleId,
                'rawCallbackCountAtFire': _rawPositionListenerCallbackCount,
                ...PageShapeDebugLogger.summarizeIndices(visibleIndicesNow),
                'rawPositions':
                    _summarizeItemPositions(debouncedRawPositions)['items'],
              },
              level: 'SCROLL',
            );
            add(UpdateVisibleIndecies(visibleIndicesNow));
          }
        });
      };

      positionsListener.itemPositions.addListener(_positionListenerCallback!);
      trace.step('listener חדש של positionsListener נוסף');

      _setAwaitingInitialPageShapeVisibleSync(
        initialShowPageShapeView,
        reason: 'LoadContent',
      );

      // ── שלב 4: EMIT ראשוני - הצגת הספר מיידית! ──
      // בטעינה ראשונית: מפרשים ריקים, ייטענו ברקע
      // ב-preserveState: שימור מפרשים קיימים כדי למנוע הבהוב
      emit(TextBookLoaded(
        book: book,
        content: content.split('\n'),
        links: emptyLinks,
        linksByLine: const {},
        availableCommentators: existingAvailableCommentators,
        tableOfContents: tableOfContents,
        fontSize: event.fontSize,
        showLeftPane: event.forceCloseLeftPane
            ? false
            : (showLeftPane || searchText.isNotEmpty),
        showSplitView: event.showSplitView,
        showPageShapeView: initialShowPageShapeView,
        activeCommentators: commentators,
        commentatorGroups: existingCommentatorGroups,
        removeNikud: removeNikud,
        isTanach: isTanach,
        visibleIndices: visibleIndices,
        pinLeftPane: Settings.getValue<bool>('key-pin-sidebar') ?? false,
        searchText: searchText,
        searchOptions: searchOptions,
        alternativeWords: alternativeWords,
        spacingValues: spacingValues,
        searchMode: searchMode,
        scrollController: scrollController,
        positionsListener: positionsListener,
        currentTitle: currentTitle,
        visibleLinks: emptyVisibleLinks,
        selectedTextForNote: state is TextBookLoaded
            ? (state as TextBookLoaded).selectedTextForNote
            : null,
        selectedTextStart: state is TextBookLoaded
            ? (state as TextBookLoaded).selectedTextStart
            : null,
        selectedTextEnd: state is TextBookLoaded
            ? (state as TextBookLoaded).selectedTextEnd
            : null,
      ));
      trace.step(
        'נפלט TextBookLoaded ראשוני',
        data: {
          'contentLines': content.split('\n').length,
          'visibleIndices': visibleIndices,
          'showSplitView': event.showSplitView,
          'showPageShapeView': initialShowPageShapeView,
          'showLeftPane': event.forceCloseLeftPane
              ? false
              : (showLeftPane || searchText.isNotEmpty),
        },
      );

      // ── שלב 5: טעינות ברקע - לא חוסמות את ה-UI ──
      _resetLoadedLinksWindow(book);
      trace.step('אופס חלון הקישורים הטעון');

      // טעינת קישורים ברקע אחרי הצגת הספר
      _loadLinksInBackground(
        book,
        visibleIndices,
      );
      trace.step(
        'הוזנקה טעינת קישורים ברקע',
        data: {
          'visibleIndices': visibleIndices,
        },
      );

      // טעינת מפרשים ברקע (רשימת מפרשים זמינים + חלוקה לתקופות)
      if (event.loadCommentators) {
        _loadCommentatorsInBackground(book);
        trace.step('הוזנקה טעינת מפרשים ברקע');
      } else {
        trace.warn('טעינת מפרשים ברקע דולגה לפי event.loadCommentators');
      }

      // העשרת heCategories ברקע (אם חסר)
      _enrichHeCategoriesInBackground(book);
      trace.end(
        data: {
          'bookTitle': book.title,
          'loadCommentators': event.loadCommentators,
        },
      );
    } catch (e, st) {
      trace.fail(
        e,
        st,
        data: {
          'bookTitle': book.title,
        },
      );
      debugPrint('Error loading textbook: $e\n$st');
      if (state is TextBookInitial) {
        final initial = state as TextBookInitial;
        emit(TextBookError(e.toString(), initial.book, initial.index,
            initial.showLeftPane, initial.commentators));
      } else if (state is TextBookLoading) {
        final loading = state as TextBookLoading;
        emit(TextBookError(e.toString(), loading.book, loading.index,
            loading.showLeftPane, loading.commentators));
      } else if (state is TextBookLoaded && event.preserveState) {
        final current = state as TextBookLoaded;
        emit(TextBookError(
            e.toString(),
            current.book,
            current.visibleIndices.isNotEmpty
                ? current.visibleIndices.first
                : 0,
            current.showLeftPane,
            current.activeCommentators));
      }
    }
  }

  void _onUpdateFontSize(
    UpdateFontSize event,
    Emitter<TextBookState> emit,
  ) {
    if (state is TextBookLoaded) {
      final currentState = state as TextBookLoaded;
      emit(currentState.copyWith(
        fontSize: event.fontSize,
        selectedIndex: currentState.selectedIndex,
      ));
    }
  }

  void _onToggleLeftPane(
    ToggleLeftPane event,
    Emitter<TextBookState> emit,
  ) {
    if (state is TextBookLoaded) {
      final currentState = state as TextBookLoaded;
      if (currentState.showLeftPane == event.show) {
        PageShapeDebugLogger.log(
          'TextBookBloc',
          'ToggleLeftPane דולג כי אין שינוי אמיתי',
          scope: _debugScope,
          data: {
            'showLeftPane': currentState.showLeftPane,
          },
          level: 'SCROLL',
        );
        return;
      }
      emit(currentState.copyWith(
        showLeftPane: event.show,
        selectedIndex: currentState.selectedIndex,
      ));
    }
  }

  void _onToggleSplitView(
    ToggleSplitView event,
    Emitter<TextBookState> emit,
  ) {
    if (state is TextBookLoaded) {
      final currentState = state as TextBookLoaded;
      PageShapeDebugLogger.log(
        'TextBookBloc',
        'ToggleSplitView מטופל',
        scope: _debugScope,
        data: {
          'previousShowSplitView': currentState.showSplitView,
          'nextShowSplitView': event.show,
          'showPageShapeView': currentState.showPageShapeView,
        },
      );
      // שמירת ההגדרה ב-Settings כדי שתישמר כברירת מחדל
      Settings.setValue<bool>('key-splited-view', event.show);
      emit(currentState.copyWith(
        showSplitView: event.show,
        selectedIndex: currentState.selectedIndex,
      ));
    }
  }

  void _onToggleTzuratHadafView(
    ToggleTzuratHadafView event,
    Emitter<TextBookState> emit,
  ) {
    if (state is TextBookLoaded) {
      final currentState = state as TextBookLoaded;

      emit(currentState.copyWith(
        showTzuratHadafView: event.show,
        showPageShapeView: false, // כיבוי התצוגה החדשה
        selectedIndex: currentState.selectedIndex,
        // סגור את חלונית הניווט/חיפוש כשעוברים לצורת הדף
        showLeftPane: event.show ? false : currentState.showLeftPane,
      ));
    }
  }

  void _onTogglePageShapeView(
    TogglePageShapeView event,
    Emitter<TextBookState> emit,
  ) {
    if (state is TextBookLoaded) {
      final currentState = state as TextBookLoaded;
      final trace = PageShapeDebugLogger.start(
        'TextBookBloc',
        'TogglePageShapeView',
        scope: _debugScope,
        data: {
          'bookTitle': currentState.book.title,
          'previousShowPageShapeView': currentState.showPageShapeView,
          'nextShowPageShapeView': event.show,
          'previousShowLeftPane': currentState.showLeftPane,
          'selectedIndex': currentState.selectedIndex,
          ...PageShapeDebugLogger.summarizeIndices(currentState.visibleIndices),
        },
        longTaskAfter: const Duration(milliseconds: 300),
        heartbeatEvery: const Duration(milliseconds: 300),
      );

      // שמירת העדפת התצוגה לספר זה
      PageShapeSettingsManager.saveViewModePreference(
        currentState.book.title,
        event.show,
      );
      trace.step('נשמרה העדפת תצוגת צורת הדף לספר');

      // מצב צורת הדף נשמר פר-ספר (ב-toJson של הטאב), לא גלובלית
      _setAwaitingInitialPageShapeVisibleSync(
        event.show,
        stateForExpectedIndex: currentState,
        reason: 'TogglePageShapeView',
      );
      emit(currentState.copyWith(
        showPageShapeView: event.show,
        showTzuratHadafView: false, // כיבוי התצוגה הישנה
        selectedIndex: currentState.selectedIndex,
        // סגור את חלונית הניווט/חיפוש כשעוברים לצורת הדף
        showLeftPane: event.show ? false : currentState.showLeftPane,
      ));
      trace.step(
        'נפלט state אחרי שינוי מצב צורת הדף',
        data: {
          'showLeftPaneAfterEmit':
              event.show ? false : currentState.showLeftPane,
        },
      );
      _loadLinksInBackground(currentState.book, currentState.visibleIndices);

      // כשיוצאים ממצב צורת הדף למצב רגיל, גלול למיקום הנוכחי
      if (!event.show && currentState.selectedIndex != null) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (scrollController.isAttached) {
            PageShapeDebugLogger.log(
              'TextBookBloc',
              'מתבצעת גלילת שחזור אחרי יציאה מצורת הדף',
              scope: _debugScope,
              data: {
                'selectedIndex': currentState.selectedIndex,
              },
              level: 'SCROLL',
            );
            scrollController.scrollTo(
              index: currentState.selectedIndex!,
              duration: const Duration(milliseconds: 300),
            );
          }
        });
      }
      trace.end();
    }
  }

  void _onUpdateCommentators(
    UpdateCommentators event,
    Emitter<TextBookState> emit,
  ) async {
    if (state is TextBookLoaded) {
      final currentState = state as TextBookLoaded;

      // עדכון המפרשים הפעילים בלבד, ללא שינוי של סוג התצוגה
      emit(currentState.copyWith(
        activeCommentators: event.commentators,
        selectedIndex: currentState.selectedIndex,
      ));
    }
  }

  void _onToggleNikud(
    ToggleNikud event,
    Emitter<TextBookState> emit,
  ) {
    if (state is TextBookLoaded) {
      final currentState = state as TextBookLoaded;
      emit(currentState.copyWith(
        removeNikud: event.remove,
        selectedIndex: currentState.selectedIndex,
      ));
    }
  }

  void _onTogglePunctuation(
    TogglePunctuation event,
    Emitter<TextBookState> emit,
  ) {
    if (state is TextBookLoaded) {
      final currentState = state as TextBookLoaded;
      emit(currentState.copyWith(
        removePunctuation: event.remove,
        selectedIndex: currentState.selectedIndex,
      ));
    }
  }

  void _onUpdateVisibleIndecies(
    UpdateVisibleIndecies event,
    Emitter<TextBookState> emit,
  ) async {
    if (state is TextBookLoaded) {
      final currentState = state as TextBookLoaded;
      final trace = PageShapeDebugLogger.start(
        'TextBookBloc',
        'עיבוד UpdateVisibleIndecies',
        scope: _debugScope,
        data: {
          'selectedIndexBefore': currentState.selectedIndex,
          'showPageShapeView': currentState.showPageShapeView,
          'previousVisibleIndices': PageShapeDebugLogger.summarizeIndices(
              currentState.visibleIndices),
          'nextVisibleIndices':
              PageShapeDebugLogger.summarizeIndices(event.visibleIndecies),
        },
        liveData: () {
          final runtimeState = state;
          final runtimeLoadedState =
              runtimeState is TextBookLoaded ? runtimeState : null;
          return {
            'runtimeStateType': runtimeState.runtimeType,
            'runtimeIsLoadingLinks': _isLoadingLinks,
            'runtimeLoadedLinksStart': _loadedLinksStart,
            'runtimeLoadedLinksEnd': _loadedLinksEnd,
            'runtimeLoadedLinksBookTitle': _loadedLinksBookTitle,
            if (runtimeLoadedState != null)
              'runtimeVisibleIndices': PageShapeDebugLogger.summarizeIndices(
                runtimeLoadedState.visibleIndices,
              ),
          };
        },
        longTaskAfter: const Duration(milliseconds: 50),
        heartbeatEvery: const Duration(milliseconds: 50),
      );
      _visibleIndicesUpdateCount++;
      PageShapeDebugLogger.log(
        'TextBookBloc',
        'טופל UpdateVisibleIndecies',
        scope: _debugScope,
        data: {
          'updateCount': _visibleIndicesUpdateCount,
          'showPageShapeView': currentState.showPageShapeView,
          'selectedIndexBefore': currentState.selectedIndex,
          'previousVisibleIndices': PageShapeDebugLogger.summarizeIndices(
              currentState.visibleIndices),
          'nextVisibleIndices':
              PageShapeDebugLogger.summarizeIndices(event.visibleIndecies),
        },
        level: 'SCROLL',
      );

      if (_awaitingInitialPageShapeVisibleSync &&
          currentState.showPageShapeView) {
        final expectedIndex =
            _expectedInitialPageShapeVisibleIndex(currentState);
        final isAligned = _isInitialPageShapeVisibleSyncAligned(
          currentState,
          event.visibleIndecies,
        );
        if (!isAligned) {
          PageShapeDebugLogger.log(
            'TextBookBloc',
            'UpdateVisibleIndecies דולג בזמן המתנה ליישור גלילה ראשוני בצורת הדף',
            scope: _debugScope,
            data: {
              'expectedIndex': expectedIndex,
              'incomingVisibleIndices':
                  PageShapeDebugLogger.summarizeIndices(event.visibleIndecies),
            },
            level: 'SCROLL',
          );
          trace.end(
            data: {
              'reason': 'awaiting initial page-shape visible sync',
              'expectedIndex': expectedIndex,
            },
          );
          return;
        }

        _setAwaitingInitialPageShapeVisibleSync(
          false,
          stateForExpectedIndex: currentState,
          reason: 'initial positions aligned',
        );
      }

      // בדיקה אם האינדקסים באמת השתנו
      if (_listsEqual(currentState.visibleIndices, event.visibleIndecies)) {
        PageShapeDebugLogger.log(
          'TextBookBloc',
          'UpdateVisibleIndecies דולג כי אין שינוי אמיתי',
          scope: _debugScope,
          data: {
            'updateCount': _visibleIndicesUpdateCount,
          },
          level: 'SCROLL',
        );
        trace.end(data: {'reason': 'same indices'});
        return; // אין שינוי, לא צריך לעדכן
      }

      try {
        String? newTitle = currentState.currentTitle;

        // עדכון הכותרת רק אם האינדקס הראשון השתנה
        if (event.visibleIndecies.isNotEmpty &&
            (currentState.visibleIndices.isEmpty ||
                currentState.visibleIndices.first !=
                    event.visibleIndecies.first)) {
          trace.step(
            'לפני refFromIndex עבור UpdateVisibleIndecies',
            data: {
              'requestedIndex': event.visibleIndecies.first,
              'tocEntries': currentState.tableOfContents.length,
            },
          );
          newTitle = await refFromIndex(event.visibleIndecies.first,
              Future.value(currentState.tableOfContents));
          trace.step(
            'אחרי refFromIndex עבור UpdateVisibleIndecies',
            data: {
              'requestedIndex': event.visibleIndecies.first,
              'newTitle': newTitle,
            },
          );
        }

        int? index = currentState.selectedIndex;
        // איפוס selectedIndex רק אם היתה גלילה משמעותית (יותר מ-3 שורות)
        // כדי למנוע איפוס כשפשוט עוברים בין tabs
        if (index != null && !event.visibleIndecies.contains(index)) {
          final oldFirst = currentState.visibleIndices.isNotEmpty
              ? currentState.visibleIndices.first
              : 0;
          final newFirst = event.visibleIndecies.isNotEmpty
              ? event.visibleIndecies.first
              : 0;

          // רק אם גללנו יותר מ-3 שורות, נאפס את הבחירה
          if ((oldFirst - newFirst).abs() > 3) {
            trace.step(
              'selectedIndex אופס בגלל גלילה משמעותית',
              data: {
                'selectedIndexBeforeReset': index,
                'oldFirst': oldFirst,
                'newFirst': newFirst,
                'distance': (oldFirst - newFirst).abs(),
              },
            );
            index = null;
          }
        }
        trace.step(
          'לפני חישוב visibleLinks עבור UpdateVisibleIndecies',
          data: {
            'linksCount': currentState.links.length,
            'selectedIndexForVisibleLinks': index,
          },
        );
        final visibleLinks = _getVisibleLinks(
          links: currentState.links,
          visibleIndices: event.visibleIndecies,
          selectedIndex: index,
          debugReason: 'UpdateVisibleIndecies',
          debugContext: {
            'updateCount': _visibleIndicesUpdateCount,
          },
        );
        trace.step(
          'הסתיים חישוב visibleLinks עבור UpdateVisibleIndecies',
          data: {
            'visibleLinksCount': visibleLinks.length,
          },
        );

        emit(currentState.copyWith(
          visibleIndices: event.visibleIndecies,
          currentTitle: newTitle,
          selectedIndex: index,
          visibleLinks: visibleLinks,
        ));
        PageShapeDebugLogger.log(
          'TextBookBloc',
          'נפלט state חדש אחרי UpdateVisibleIndecies',
          scope: _debugScope,
          data: {
            'updateCount': _visibleIndicesUpdateCount,
            'newTitle': newTitle,
            'selectedIndexAfter': index,
            'visibleLinksCount': visibleLinks.length,
          },
          level: 'SCROLL',
        );
        trace.step(
          'נפלט state חדש עבור UpdateVisibleIndecies',
          data: {
            'newTitle': newTitle,
            'selectedIndexAfter': index,
            'visibleLinksCount': visibleLinks.length,
          },
        );

        _loadLinksInBackground(
          currentState.book,
          event.visibleIndecies,
        );
        trace.end(
          data: {
            'updateCount': _visibleIndicesUpdateCount,
            'visibleLinksCount': visibleLinks.length,
          },
        );
      } catch (error, stackTrace) {
        trace.fail(
          error,
          stackTrace,
          data: {
            'updateCount': _visibleIndicesUpdateCount,
          },
        );
        rethrow;
      }
    }
  }

  void _resetLoadedLinksWindow(TextBook book) {
    _loadedLinksBookTitle = book.title;
    _loadedLinksStart = null;
    _loadedLinksEnd = null;
    _loadedLinksTargetBookTitlesSignature = null;
    _activeLinksTargetBookTitlesSignature = null;
    _isLoadingLinks = false;
    _pendingLinksReload = false;
  }

  ({int start, int end}) _calculateLinksWindow(List<int> visibleIndices) {
    if (visibleIndices.isEmpty) {
      return (start: 0, end: _linkLookAheadLines);
    }

    final minVisible = visibleIndices.reduce((a, b) => a < b ? a : b);
    final maxVisible = visibleIndices.reduce((a, b) => a > b ? a : b);

    return (
      start: (minVisible - _linkLookBehindLines).clamp(0, minVisible),
      end: maxVisible + _linkLookAheadLines,
    );
  }

  bool _isLinksWindowLoaded(
    String bookTitle,
    int start,
    int end,
    String targetBookTitlesSignature,
  ) {
    return _loadedLinksBookTitle == bookTitle &&
        _loadedLinksStart != null &&
        _loadedLinksEnd != null &&
        _loadedLinksTargetBookTitlesSignature == targetBookTitlesSignature &&
        start >= _loadedLinksStart! &&
        end <= _loadedLinksEnd!;
  }

  List<String>? _normalizeTargetBookTitles(Iterable<String>? targetBookTitles) {
    if (targetBookTitles == null) {
      return null;
    }

    final normalized = targetBookTitles
        .map((title) => title.trim())
        .where((title) => title.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return normalized;
  }

  String _targetBookTitlesSignature(Iterable<String>? targetBookTitles) {
    final normalizedTargetBookTitles =
        _normalizeTargetBookTitles(targetBookTitles);
    if (normalizedTargetBookTitles == null) {
      return _allTargetBookTitlesSignature;
    }

    return normalizedTargetBookTitles.join('||');
  }

  Future<List<String>?> _resolvePageShapeTargetBookTitlesForLinks(
    TextBookLoaded state,
    PageShapeDebugTrace trace,
  ) async {
    final candidateCommentators = {
      ...state.availableCommentators,
      ...state.activeCommentators,
    }.where((commentator) => commentator.trim().isNotEmpty).toList()
      ..sort();

    if (candidateCommentators.isEmpty) {
      trace.warn(
        'לא חושב פילטר מפרשים לצורת הדף כי אין כלל מועמדים זמינים',
        data: {
          'availableCommentatorsCount': state.availableCommentators.length,
          'activeCommentatorsCount': state.activeCommentators.length,
        },
      );
      return null;
    }

    final configuration = PageShapeSettingsManager.loadConfiguration(
          state.book.title,
          heCategories: state.book.heCategories,
        ) ??
        await DefaultCommentators.getDefaults(
          state.book,
          availableCommentators: candidateCommentators,
        );
    final columnVisibility =
        PageShapeSettingsManager.getColumnVisibility(state.book.title);

    final selectedCommentators = resolvePageShapeDisplayedCommentators(
      leftSelection: configuration['left'],
      rightSelection: configuration['right'],
      bottomSelection: configuration['bottom'],
      bottomRightSelection: configuration['bottomRight'],
      availableCommentators: candidateCommentators,
      columnVisibility: columnVisibility,
    );

    trace.step(
      'חושב פילטר מפרשים לטעינת קישורים בצורת הדף',
      data: {
        'configuration': configuration,
        'columnVisibility': columnVisibility,
        'selectedCommentatorsCount': selectedCommentators.length,
        'selectedCommentators': selectedCommentators,
      },
    );

    return selectedCommentators;
  }

  /// בדיקה אם שתי רשימות שוות
  bool _listsEqual(List<int> list1, List<int> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  Map<String, Object?> _summarizeItemPositions(
    Iterable<ItemPosition> positions,
  ) {
    final list = positions.toList(growable: false);
    return {
      'itemPositionsCount': list.length,
      'indices': PageShapeDebugLogger.summarizeIndices(
        list.map((position) => position.index),
      ),
      'items': list
          .take(6)
          .map((position) => {
                'index': position.index,
                'leadingEdge': position.itemLeadingEdge,
                'trailingEdge': position.itemTrailingEdge,
              })
          .toList(growable: false),
    };
  }

  String _itemPositionsSignature(Iterable<ItemPosition> positions) {
    return positions
        .map(
          (position) =>
              '${position.index}:${position.itemLeadingEdge.toStringAsFixed(3)}:${position.itemTrailingEdge.toStringAsFixed(3)}',
        )
        .join('|');
  }

  void _onUpdateSelectedIndex(
    UpdateSelectedIndex event,
    Emitter<TextBookState> emit,
  ) {
    if (state is TextBookLoaded) {
      final currentState = state as TextBookLoaded;
      PageShapeDebugLogger.log(
        'TextBookBloc',
        'טופל UpdateSelectedIndex',
        scope: _debugScope,
        data: {
          'previousSelectedIndex': currentState.selectedIndex,
          'nextSelectedIndex': event.index,
          'showPageShapeView': currentState.showPageShapeView,
        },
      );
      final visibleLinks = _getVisibleLinks(
        links: currentState.links,
        visibleIndices: currentState.visibleIndices,
        selectedIndex: event.index,
        debugReason: 'UpdateSelectedIndex',
        debugContext: {
          'nextSelectedIndex': event.index,
        },
      );
      emit(currentState.copyWith(
        selectedIndex: event.index,
        visibleLinks: visibleLinks,
      ));
    }
  }

  void _onHighlightLine(
    HighlightLine event,
    Emitter<TextBookState> emit,
  ) {
    if (state is! TextBookLoaded) return;
    final currentState = state as TextBookLoaded;
    PageShapeDebugLogger.log(
      'TextBookBloc',
      'טופל HighlightLine',
      scope: _debugScope,
      data: {
        'lineIndex': event.lineIndex,
        'showPageShapeView': currentState.showPageShapeView,
      },
    );
    emit(currentState.copyWith(highlightedLine: event.lineIndex));

    // Cancel previous highlight timer if exists
    _highlightTimer?.cancel();

    _highlightTimer = Timer(const Duration(seconds: 2), () {
      if (!isClosed) {
        add(ClearHighlightedLine(event.lineIndex));
      }
    });
  }

  void _onClearHighlightedLine(
    ClearHighlightedLine event,
    Emitter<TextBookState> emit,
  ) {
    if (state is! TextBookLoaded) return;
    final currentState = state as TextBookLoaded;
    if (currentState.highlightedLine == null) return;
    if (event.lineIndex != null &&
        currentState.highlightedLine != event.lineIndex) {
      return;
    }
    PageShapeDebugLogger.log(
      'TextBookBloc',
      'טופל ClearHighlightedLine',
      scope: _debugScope,
      data: {
        'currentHighlightedLine': currentState.highlightedLine,
        'requestedLineIndex': event.lineIndex,
      },
    );
    emit(currentState.copyWith(clearHighlight: true));
  }

  void _onTogglePinLeftPane(
    TogglePinLeftPane event,
    Emitter<TextBookState> emit,
  ) {
    if (state is TextBookLoaded) {
      final currentState = state as TextBookLoaded;
      emit(currentState.copyWith(
        pinLeftPane: event.pin,
        selectedIndex: currentState.selectedIndex,
      ));
    }
  }

  void _onUpdateSearchText(
    UpdateSearchText event,
    Emitter<TextBookState> emit,
  ) {
    if (state is TextBookLoaded) {
      final currentState = state as TextBookLoaded;
      emit(currentState.copyWith(
        searchText: event.text,
        selectedIndex: currentState.selectedIndex,
      ));
    }
  }

  void _onApplyFullBookContent(
    ApplyFullBookContent event,
    Emitter<TextBookState> emit,
  ) {
    if (state is! TextBookLoaded) {
      return;
    }

    final currentState = state as TextBookLoaded;
    if (currentState.book.title != event.bookTitle) {
      return;
    }

    if (listEquals(currentState.content, event.content)) {
      return;
    }

    emit(currentState.copyWith(content: event.content));
  }

  void _onCreateNoteFromToolbar(
    CreateNoteFromToolbar event,
    Emitter<TextBookState> emit,
  ) {
    // כרגע זה רק מציין שהאירוע התקבל
    // הלוגיקה האמיתית תהיה בכפתור בשורת הכלים
  }

  void _onUpdateSelectedTextForNote(
    UpdateSelectedTextForNote event,
    Emitter<TextBookState> emit,
  ) {
    if (state is TextBookLoaded) {
      final currentState = state as TextBookLoaded;
      emit(currentState.copyWith(
        selectedTextForNote: event.text,
        selectedTextStart: event.start,
        selectedTextEnd: event.end,
      ));
    }
  }

  List<Link> _getVisibleLinks({
    required List<Link> links,
    required List<int> visibleIndices,
    int? selectedIndex,
    String debugReason = 'unknown',
    Map<String, Object?> debugContext = const {},
  }) {
    final stopwatch = Stopwatch()..start();
    final targetIndices =
        selectedIndex != null ? [selectedIndex] : visibleIndices;

    final visibleLinks = <Link>[];
    final perTargetMatches = <Map<String, Object?>>[];

    for (final index in targetIndices) {
      final perIndexStopwatch = Stopwatch()..start();
      final indexLinks = links
          .where(
            (link) =>
                link.index1 == index + 1 &&
                !LinkTypes.isCommentaryOrTargum(link.connectionType) &&
                // מסנן קישורים מבוססי תווים (inline links) - הם אמורים להופיע רק בתוך הטקסט
                link.start == null &&
                link.end == null,
          )
          .toList();
      perTargetMatches.add({
        'index': index,
        'matches': indexLinks.length,
        'elapsedMs': perIndexStopwatch.elapsedMilliseconds,
      });
      visibleLinks.addAll(indexLinks);
    }

    final preSortCount = visibleLinks.length;
    final sortStartedAtMs = stopwatch.elapsedMilliseconds;
    visibleLinks.sort(
      (a, b) => a.path2
          .split(Platform.pathSeparator)
          .last
          .compareTo(b.path2.split(Platform.pathSeparator).last),
    );
    PageShapeDebugLogger.log(
      'TextBookBloc',
      'הושלם חישוב visibleLinks',
      scope: _debugScope,
      data: {
        'reason': debugReason,
        ...debugContext,
        'linksInputCount': links.length,
        'selectedIndex': selectedIndex,
        'estimatedScanOperations': links.length * targetIndices.length,
        'perTargetMatches': perTargetMatches,
        'preSortCount': preSortCount,
        'sortElapsedMs': stopwatch.elapsedMilliseconds - sortStartedAtMs,
        'outputCount': visibleLinks.length,
        'elapsedMs': stopwatch.elapsedMilliseconds,
        'targetIndices': PageShapeDebugLogger.summarizeIndices(targetIndices),
      },
      level: 'STEP',
    );

    return visibleLinks;
  }

  // [EDITING DISABLED] - All editor event handlers commented out
  // Future<void> _onOpenEditor(
  //   OpenEditor event,
  //   Emitter<TextBookState> emit,
  // ) async {
  //   if (state is! TextBookLoaded) return;
  //
  //   final currentState = state as TextBookLoaded;
  //
  //   try {
  //     // Generate section identifier
  //     final content = currentState.content[event.index];
  //     final sectionId = SectionIdentifier.fromContent(
  //       content: content,
  //       index: event.index,
  //     );
  //
  //     // Check if book has links file
  //     final hasLinks =
  //         await _overridesRepository.hasLinksFile(currentState.book.title);
  //
  //     // Load existing override or original content
  //     final override = await _overridesRepository.readOverride(
  //       currentState.book.title,
  //       sectionId.sectionId,
  //     );
  //
  //     final editorText = override?.markdownContent ?? content;
  //
  //     // Check for draft
  //     final hasDraft = await _overridesRepository.hasNewerDraftThanOverride(
  //       currentState.book.title,
  //       sectionId.sectionId,
  //     );
  //
  //     emit(currentState.copyWith(
  //       isEditorOpen: true,
  //       editorIndex: event.index,
  //       editorSectionId: sectionId.sectionId,
  //       editorText: editorText,
  //       hasDraft: hasDraft,
  //       hasLinksFile: hasLinks,
  //     ));
  //   } catch (e) {
  //     // Handle error - could emit error state or show notification
  //   }
  // }
  //
  // Future<void> _onOpenFullFileEditor(
  //   OpenFullFileEditor event,
  //   Emitter<TextBookState> emit,
  // ) async {
  //   if (state is! TextBookLoaded) return;
  //
  //   final currentState = state as TextBookLoaded;
  //
  //   try {
  //     // Combine all content into one string
  //     final fullContent = currentState.content.join('\n\n');
  //
  //     // We don't need section identifier for full file - using fixed ID
  //
  //     // Check if book has links file
  //     final hasLinks =
  //         await _overridesRepository.hasLinksFile(currentState.book.title);
  //
  //     // Load existing override or original content
  //     final override = await _overridesRepository.readOverride(
  //       currentState.book.title,
  //       'full_file',
  //     );
  //
  //     final editorText = override?.markdownContent ?? fullContent;
  //
  //     // Check for draft
  //     final hasDraft = await _overridesRepository.hasNewerDraftThanOverride(
  //       currentState.book.title,
  //       'full_file',
  //     );
  //
  //     emit(currentState.copyWith(
  //       isEditorOpen: true,
  //       editorIndex: -1, // Special index for full file
  //       editorSectionId: 'full_file',
  //       editorText: editorText,
  //       hasDraft: hasDraft,
  //       hasLinksFile: hasLinks,
  //     ));
  //   } catch (e) {
  //     // Debug: Error in _onOpenFullFileEditor: $e
  //     // Handle error - could emit error state or show notification
  //   }
  // }
  //
  // Future<void> _onSaveEditedSection(
  //   SaveEditedSection event,
  //   Emitter<TextBookState> emit,
  // ) async {
  //   if (state is! TextBookLoaded) return;
  //
  //   final currentState = state as TextBookLoaded;
  //
  //   try {
  //     // Handle full file editing differently
  //     if (event.sectionId == 'full_file' && event.index == -1) {
  //       // For full file editing, save the entire content to the original file
  //       await repository.saveBookContent(currentState.book, event.markdown);
  //
  //       // Split the content back into sections for display
  //       final sections = event.markdown
  //           .split('\n\n')
  //           .where((s) => s.trim().isNotEmpty)
  //           .toList();
  //
  //       // If we have fewer sections than before, pad with empty strings
  //       while (sections.length < currentState.content.length) {
  //         sections.add('');
  //       }
  //
  //       // Reload content to ensure we have the latest version
  //       add(LoadContent(
  //         fontSize: currentState.fontSize,
  //         showSplitView: currentState.showSplitView,
  //         removeNikud: currentState.removeNikud,
  //         preserveState: true,
  //       ));
  //
  //       return;
  //     }
  //
  //     // Regular section editing - update the specific section and save the entire file
  //     final updatedContent = List<String>.from(currentState.content);
  //     updatedContent[event.index] = event.markdown;
  //
  //     // Join all sections back together and save to original file
  //     final fullContent = updatedContent.join('\n\n');
  //     await repository.saveBookContent(currentState.book, fullContent);
  //
  //     // Close editor immediately
  //     emit(currentState.copyWith(
  //       isEditorOpen: false,
  //       editorIndex: null,
  //       editorSectionId: null,
  //       editorText: null,
  //       hasDraft: false,
  //     ));
  //
  //     // Reload content to ensure we have the latest version from the file system
  //     add(LoadContent(
  //       fontSize: currentState.fontSize,
  //       showSplitView: currentState.showSplitView,
  //       removeNikud: currentState.removeNikud,
  //       preserveState: true,
  //     ));
  //   } catch (e) {
  //     // Debug: Error in _onSaveEditedSection: $e
  //     // Handle error - could show error message to user
  //   }
  // }
  //
  // Future<void> _onLoadDraftIfAny(
  //   LoadDraftIfAny event,
  //   Emitter<TextBookState> emit,
  // ) async {
  //   if (state is! TextBookLoaded) return;
  //
  //   final currentState = state as TextBookLoaded;
  //
  //   try {
  //     final draft = await _overridesRepository.readDraft(
  //       currentState.book.title,
  //       event.sectionId,
  //     );
  //
  //     if (draft != null) {
  //       emit(currentState.copyWith(
  //         editorText: draft.markdownContent,
  //         hasDraft: false, // Draft is now loaded, so no longer "pending"
  //       ));
  //     }
  //   } catch (e) {
  //     // Handle error
  //   }
  // }
  //
  // Future<void> _onDiscardDraft(
  //   DiscardDraft event,
  //   Emitter<TextBookState> emit,
  // ) async {
  //   if (state is! TextBookLoaded) return;
  //
  //   final currentState = state as TextBookLoaded;
  //
  //   try {
  //     await _overridesRepository.deleteDraft(
  //       currentState.book.title,
  //       event.sectionId,
  //     );
  //
  //     emit(currentState.copyWith(hasDraft: false));
  //   } catch (e) {
  //     // Handle error
  //   }
  // }
  //
  // Future<void> _onCloseEditor(
  //   CloseEditor event,
  //   Emitter<TextBookState> emit,
  // ) async {
  //   if (state is! TextBookLoaded) return;
  //
  //   final currentState = state as TextBookLoaded;
  //
  //   emit(currentState.copyWith(
  //     isEditorOpen: false,
  //     editorIndex: null,
  //     editorSectionId: null,
  //     editorText: null,
  //     hasDraft: false,
  //   ));
  // }
  //
  // Future<void> _onUpdateEditorText(
  //   UpdateEditorText event,
  //   Emitter<TextBookState> emit,
  // ) async {
  //   if (state is! TextBookLoaded) return;
  //
  //   final currentState = state as TextBookLoaded;
  //
  //   emit(currentState.copyWith(editorText: event.text));
  // }
  //
  // Future<void> _onAutoSaveDraft(
  //   AutoSaveDraft event,
  //   Emitter<TextBookState> emit,
  // ) async {
  //   if (state is! TextBookLoaded) return;
  //
  //   final currentState = state as TextBookLoaded;
  //
  //   try {
  //     await _overridesRepository.writeDraft(
  //       currentState.book.title,
  //       event.sectionId,
  //       event.markdown,
  //     );
  //
  //     // Don't emit state change for auto-save to avoid unnecessary rebuilds
  //   } catch (e) {
  //     // Handle error silently for auto-save
  //   }
  // }

  @override
  Future<void> close() {
    PageShapeDebugLogger.log(
      'TextBookBloc',
      'close ל־TextBookBloc',
      scope: _debugScope,
      data: {
        'stateBeforeClose': _stateSummary(state),
      },
      level: 'END',
    );
    // Cancel all timers
    _debounceTimer?.cancel();
    _highlightTimer?.cancel();

    // Remove position listener
    if (_positionListenerCallback != null) {
      positionsListener.itemPositions
          .removeListener(_positionListenerCallback!);
    }

    return super.close();
  }

  /// Loads the full book in the background and updates the state
  void _loadFullBookInBackground(
    TextBook book,
  ) async {
    final trace = PageShapeDebugLogger.start(
      'TextBookBloc',
      'טעינת תוכן מלא ברקע',
      scope: _debugScope,
      data: {
        'bookTitle': book.title,
      },
    );
    try {
      // Load full content
      final fullContent = await repository.getBookContent(book);
      trace.step(
        'הוחזר תוכן מלא ברקע',
        data: {
          'contentLength': fullContent.length,
        },
      );

      if (fullContent.isEmpty) {
        trace.warn('טעינת תוכן מלא ברקע חזרה ריקה');
        trace.end(data: {'reason': 'empty full content'});
        return;
      }

      // Check if still in the same book (user might have navigated away)
      if (isClosed || state is! TextBookLoaded) {
        trace.warn(
          'ה־bloc נסגר או שה־state כבר לא Loaded; תוצאת הרקע תידחה',
          data: {
            'isClosed': isClosed,
            'stateType': state.runtimeType,
          },
        );
        trace.end(data: {'reason': 'bloc closed or state changed'});
        return;
      }

      final currentState = state as TextBookLoaded;
      if (currentState.book.title != book.title) {
        trace.warn(
          'טעינת הרקע חזרה לספר אחר מזה שפתוח כעת',
          data: {
            'currentBookTitle': currentState.book.title,
          },
        );
        trace.end(data: {'reason': 'book changed'});
        return;
      }

      add(ApplyFullBookContent(
        bookTitle: book.title,
        content: fullContent.split('\n'),
      ));
      trace.end(
        data: {
          'contentLines': fullContent.split('\n').length,
        },
      );
    } catch (e) {
      // Silent fail - user already has preview
      trace.warn(
        'נכשלה טעינת תוכן מלא ברקע',
        data: {
          'error': e,
        },
      );
      trace.end(data: {'reason': 'background full content load failed'});
    }
  }

  /// Loads links in the background after the book is displayed
  void _loadLinksInBackground(
    TextBook book,
    List<int> visibleIndices,
  ) async {
    final window = _calculateLinksWindow(visibleIndices);
    final trace = PageShapeDebugLogger.start(
      'TextBookBloc',
      'טעינת קישורים ברקע',
      scope: _debugScope,
      data: {
        'bookTitle': book.title,
        ...PageShapeDebugLogger.summarizeIndices(visibleIndices),
        'windowStart': window.start,
        'windowEnd': window.end,
        'loadedLinksStart': _loadedLinksStart,
        'loadedLinksEnd': _loadedLinksEnd,
        'loadedLinksBookTitle': _loadedLinksBookTitle,
        'loadedLinksTargetBookTitlesSignature':
            _loadedLinksTargetBookTitlesSignature,
        'activeLinksTargetBookTitlesSignature':
            _activeLinksTargetBookTitlesSignature,
        'isLoadingLinks': _isLoadingLinks,
      },
      liveData: () {
        final runtimeState = state;
        final runtimeLoadedState =
            runtimeState is TextBookLoaded ? runtimeState : null;
        return {
          'loadedLinksStart': _loadedLinksStart,
          'loadedLinksEnd': _loadedLinksEnd,
          'loadedLinksBookTitle': _loadedLinksBookTitle,
          'loadedLinksTargetBookTitlesSignature':
              _loadedLinksTargetBookTitlesSignature,
          'activeLinksTargetBookTitlesSignature':
              _activeLinksTargetBookTitlesSignature,
          'isLoadingLinks': _isLoadingLinks,
          'runtimeStateType': runtimeState.runtimeType,
          if (runtimeLoadedState != null)
            'runtimeVisibleIndices': PageShapeDebugLogger.summarizeIndices(
              runtimeLoadedState.visibleIndices,
            ),
        };
      },
      longTaskAfter: const Duration(milliseconds: 400),
      heartbeatEvery: const Duration(milliseconds: 400),
    );

    List<String>? targetBookTitles;
    var targetBookTitlesSignature = _allTargetBookTitlesSignature;
    final runtimeState = state;
    if (runtimeState is TextBookLoaded && runtimeState.showPageShapeView) {
      targetBookTitles =
          await _resolvePageShapeTargetBookTitlesForLinks(runtimeState, trace);
      targetBookTitlesSignature = _targetBookTitlesSignature(targetBookTitles);
    } else {
      trace.step(
        'טעינת הקישורים תתבצע ללא פילטר מפרשים של צורת הדף',
        data: {
          'stateType': runtimeState.runtimeType,
          'showPageShapeView': runtimeState is TextBookLoaded
              ? runtimeState.showPageShapeView
              : null,
        },
      );
    }

    if (_isLoadingLinks) {
      // בקשה חדשה הגיעה בזמן שטעינה אחרת רצה — מסמנים לנסות שוב אחריה
      _pendingLinksReload = true;
      trace.warn(
        'טעינת קישורים ברקע דולגה (טעינה כבר פעילה)',
        data: {
          'targetBookTitlesSignature': targetBookTitlesSignature,
          'targetBookTitlesCount': targetBookTitles?.length,
        },
      );
      trace.end(data: {'reason': 'skip_loading_in_progress'});
      return;
    }

    if (_isLinksWindowLoaded(
      book.title,
      window.start,
      window.end,
      targetBookTitlesSignature,
    )) {
      trace.warn(
        'טעינת קישורים ברקע דולגה (חלון כבר נטען)',
        data: {
          'targetBookTitlesSignature': targetBookTitlesSignature,
          'targetBookTitlesCount': targetBookTitles?.length,
        },
      );
      _pendingLinksReload = false;
      trace.end(data: {'reason': 'skip_window_already_loaded'});
      return;
    }

    _isLoadingLinks = true;
    _pendingLinksReload = false;
    trace.step('סומן _isLoadingLinks=true');

    try {
      trace.step(
        'נשלחה בקשה ל־repository.getBookLinksInRange',
        data: {
          'rangeLength': window.end - window.start + 1,
          'targetBookTitlesSignature': targetBookTitlesSignature,
          'targetBookTitlesCount': targetBookTitles?.length,
          'targetBookTitles': targetBookTitles,
        },
      );
      final links = await repository.getBookLinksInRange(
        book,
        startIndex: window.start,
        endIndex: window.end,
        targetBookTitles: targetBookTitles,
      );
      trace.step(
        'הוחזרו קישורים מה־repository',
        data: {
          'linksCount': links.length,
        },
      );

      // Check if still in the same book
      if (isClosed || state is! TextBookLoaded) {
        _isLoadingLinks = false;
        trace.warn(
          'טעינת קישורים ברקע נדחתה כי ה־bloc נסגר או שה־state השתנה',
          data: {
            'isClosed': isClosed,
            'stateType': state.runtimeType,
          },
        );
        trace.end(data: {'reason': 'bloc closed or state changed'});
        return;
      }

      final currentState = state as TextBookLoaded;
      if (currentState.book.title != book.title) {
        _isLoadingLinks = false;
        trace.warn(
          'טעינת קישורים ברקע חזרה לספר אחר מזה שפתוח כעת',
          data: {
            'currentBookTitle': currentState.book.title,
          },
        );
        trace.end(data: {'reason': 'book changed'});
        return;
      }

      _loadedLinksBookTitle = book.title;
      _loadedLinksStart = window.start;
      _loadedLinksEnd = window.end;
      _loadedLinksTargetBookTitlesSignature = targetBookTitlesSignature;
      _isLoadingLinks = false;
      final replaceExistingLinks = currentState.links.isNotEmpty &&
          _activeLinksTargetBookTitlesSignature != targetBookTitlesSignature;
      trace.step(
        'עודכן חלון הקישורים הטעון',
        data: {
          'loadedLinksStart': _loadedLinksStart,
          'loadedLinksEnd': _loadedLinksEnd,
          'loadedLinksTargetBookTitlesSignature':
              _loadedLinksTargetBookTitlesSignature,
          'isLoadingLinks': _isLoadingLinks,
          'replaceExistingLinks': replaceExistingLinks,
        },
      );

      // Use event to update links
      add(UpdateLinks(
        links,
        replaceExisting: replaceExistingLinks,
        targetBookTitlesSignature: targetBookTitlesSignature,
      ));
      trace.step(
        'נשלח UpdateLinks',
        data: {
          'replaceExistingLinks': replaceExistingLinks,
          'targetBookTitlesSignature': targetBookTitlesSignature,
        },
      );

      if (state is TextBookLoaded) {
        final latestState = state as TextBookLoaded;
        final latestWindow = _calculateLinksWindow(latestState.visibleIndices);
        final windowOutdated = !_isLinksWindowLoaded(
          latestState.book.title,
          latestWindow.start,
          latestWindow.end,
          targetBookTitlesSignature,
        );
        if (_pendingLinksReload || windowOutdated) {
          trace.warn(
            'אחרי טעינת הקישורים עדיין חסר חלון עדכני; מתחילים טעינה נוספת',
            data: {
              'reason': _pendingLinksReload ? 'pending_reload' : 'window_outdated',
              'latestWindowStart': latestWindow.start,
              'latestWindowEnd': latestWindow.end,
              ...PageShapeDebugLogger.summarizeIndices(
                latestState.visibleIndices,
              ),
            },
          );
          _loadLinksInBackground(
            latestState.book,
            latestState.visibleIndices,
          );
        }
      }
      trace.end(
        data: {
          'linksCount': links.length,
        },
      );
    } catch (e) {
      _isLoadingLinks = false;
      // Silent fail - user already has the book displayed
      trace.fail(e, StackTrace.current);
    }
  }

  void _onUpdateLinks(
    UpdateLinks event,
    Emitter<TextBookState> emit,
  ) {
    if (state is TextBookLoaded) {
      final currentState = state as TextBookLoaded;
      final trace = PageShapeDebugLogger.start(
        'TextBookBloc',
        'עיבוד UpdateLinks',
        scope: _debugScope,
        data: {
          'incomingLinksCount': event.links.length,
          'existingLinksCount': currentState.links.length,
          'selectedIndex': currentState.selectedIndex,
          ...PageShapeDebugLogger.summarizeIndices(currentState.visibleIndices),
        },
        longTaskAfter: const Duration(milliseconds: 16),
        heartbeatEvery: const Duration(milliseconds: 16),
      );
      final links = _mergeLinksByIdentity(
        event.replaceExisting ? const [] : currentState.links,
        event.links.cast<Link>(),
        debugScope: _debugScope,
      );
      trace.step(
        'הסתיים מיזוג קישורים לפי זהות',
        data: {
          'mergedLinksCount': links.length,
        },
      );

      // Build linksByLine map for O(1) lookups
      final Map<int, List<Link>> linksByLine = {};
      for (final link in links) {
        final list = linksByLine[link.index1];
        if (list == null) {
          linksByLine[link.index1] = [link];
        } else {
          list.add(link);
        }
      }
      trace.step(
        'נבנתה מפת linksByLine',
        data: {
          'linksByLineCount': linksByLine.length,
        },
      );

      // Calculate visible links
      final visibleLinks = _getVisibleLinks(
        links: links,
        visibleIndices: currentState.visibleIndices,
        selectedIndex: currentState.selectedIndex,
        debugReason: 'UpdateLinks',
        debugContext: {
          'incomingLinksCount': event.links.length,
          'mergedLinksCount': links.length,
        },
      );
      trace.step(
        'הסתיים חישוב visibleLinks עבור UpdateLinks',
        data: {
          'visibleLinksCount': visibleLinks.length,
        },
      );

      emit(currentState.copyWith(
        links: links,
        linksByLine: linksByLine,
        visibleLinks: visibleLinks,
      ));
      PageShapeDebugLogger.log(
        'TextBookBloc',
        'טופל UpdateLinks',
        scope: _debugScope,
        data: {
          'incomingLinksCount': event.links.length,
          'replaceExisting': event.replaceExisting,
          'targetBookTitlesSignature': event.targetBookTitlesSignature,
          'mergedLinksCount': links.length,
          'linksByLineCount': linksByLine.length,
          'visibleLinksCount': visibleLinks.length,
        },
      );
      _activeLinksTargetBookTitlesSignature =
          event.targetBookTitlesSignature ?? _allTargetBookTitlesSignature;
      trace.end(
        data: {
          'mergedLinksCount': links.length,
          'linksByLineCount': linksByLine.length,
          'visibleLinksCount': visibleLinks.length,
        },
      );
    }
  }

  /// Handler for updating available commentators after background loading
  void _onUpdateAvailableCommentators(
    UpdateAvailableCommentators event,
    Emitter<TextBookState> emit,
  ) {
    if (state is TextBookLoaded) {
      final currentState = state as TextBookLoaded;
      final updatedState = currentState.copyWith(
        availableCommentators: event.availableCommentators,
        commentatorGroups: event.commentatorGroups.cast<CommentatorGroup>(),
      );
      emit(updatedState);
      PageShapeDebugLogger.log(
        'TextBookBloc',
        'טופל UpdateAvailableCommentators',
        scope: _debugScope,
        data: {
          'availableCommentatorsCount': event.availableCommentators.length,
          'commentatorGroupsCount': event.commentatorGroups.length,
        },
      );

      if (updatedState.showPageShapeView) {
        _loadLinksInBackground(updatedState.book, updatedState.visibleIndices);
      }
    }
  }

  void _onRefreshLinksForCurrentWindow(
    RefreshLinksForCurrentWindow event,
    Emitter<TextBookState> emit,
  ) {
    if (state is! TextBookLoaded) {
      return;
    }

    final currentState = state as TextBookLoaded;
    PageShapeDebugLogger.log(
      'TextBookBloc',
      'טופל RefreshLinksForCurrentWindow',
      scope: _debugScope,
      data: {
        'reason': event.reason,
        'showPageShapeView': currentState.showPageShapeView,
        ...PageShapeDebugLogger.summarizeIndices(currentState.visibleIndices),
      },
      level: 'EVENT',
    );
    _loadLinksInBackground(currentState.book, currentState.visibleIndices);
  }

  /// Loads available commentators in the background after the book is displayed
  void _loadCommentatorsInBackground(TextBook book) async {
    final trace = PageShapeDebugLogger.start(
      'TextBookBloc',
      'טעינת מפרשים זמינים ברקע',
      scope: _debugScope,
      data: {
        'bookTitle': book.title,
      },
    );
    try {
      final availableCommentators =
          await repository.getAvailableCommentators(book);
      trace.step(
        'הוחזרה רשימת מפרשים זמינים',
        data: {
          'availableCommentatorsCount': availableCommentators.length,
        },
      );
      final eras = await utils.splitByEra(availableCommentators);
      trace.step(
        'בוצעה חלוקה לתקופות',
        data: {
          'erasCount': eras.length,
        },
      );
      final groups = _buildCommentatorGroups(eras, availableCommentators);
      trace.step(
        'נבנו קבוצות מפרשים',
        data: {
          'groupsCount': groups.length,
        },
      );

      if (isClosed || state is! TextBookLoaded) {
        trace.warn(
          'טעינת מפרשים ברקע נדחתה כי ה־bloc נסגר או שה־state השתנה',
          data: {
            'isClosed': isClosed,
            'stateType': state.runtimeType,
          },
        );
        trace.end(data: {'reason': 'bloc closed or state changed'});
        return;
      }

      final currentState = state as TextBookLoaded;
      if (currentState.book.title != book.title) {
        trace.warn(
          'טעינת מפרשים ברקע חזרה עבור ספר שאינו פתוח עוד',
          data: {
            'currentBookTitle': currentState.book.title,
          },
        );
        trace.end(data: {'reason': 'book changed'});
        return;
      }

      add(UpdateAvailableCommentators(availableCommentators, groups));
      trace.end(
        data: {
          'availableCommentatorsCount': availableCommentators.length,
          'groupsCount': groups.length,
        },
      );
    } catch (e) {
      debugPrint('⚠️ Failed to load commentators in background: $e');
      // Silent fail - user already has the book displayed
      trace.fail(e, StackTrace.current);
    }
  }

  /// Enriches heCategories metadata in the background after the book is displayed
  void _enrichHeCategoriesInBackground(TextBook book) async {
    if (book.heCategories != null && book.heCategories!.isNotEmpty) {
      PageShapeDebugLogger.log(
        'TextBookBloc',
        'דולגה העשרת heCategories כי הערך כבר קיים',
        scope: _debugScope,
        data: {
          'bookTitle': book.title,
          'heCategories': book.heCategories,
        },
      );
      return;
    }

    try {
      // ניסיון 1: טעינה ממסד הנתונים
      final sqliteProvider = SqliteDataProvider.instance;
      if (await sqliteProvider.databaseExists() &&
          sqliteProvider.isInitialized) {
        final dbRepo = sqliteProvider.repository;
        if (dbRepo != null) {
          final dbBook = await dbRepo.getBookByTitle(book.title);
          if (dbBook != null) {
            final category = await dbRepo.getCategory(dbBook.categoryId);
            if (category != null) {
              final categoryParts = <String>[];
              db.Category? currentCategory = category;
              while (currentCategory != null) {
                categoryParts.insert(0, currentCategory.title);
                if (currentCategory.parentId != null) {
                  currentCategory =
                      await dbRepo.getCategory(currentCategory.parentId!);
                } else {
                  break;
                }
              }
              book.heCategories = categoryParts.join(', ');
              debugPrint(
                  '📚 Background: נטען heCategories מה-DB: "${book.heCategories}"');
              PageShapeDebugLogger.log(
                'TextBookBloc',
                'heCategories הועשרו מהרקע מתוך DB',
                scope: _debugScope,
                data: {
                  'bookTitle': book.title,
                  'heCategories': book.heCategories,
                  'source': 'db',
                },
              );
              return;
            }
          }
        }
      }

      // ניסיון 2: טעינה מ-metadata
      if (book.heCategories == null || book.heCategories!.isEmpty) {
        final metadata = await FileSystemData.instance.metadata;
        final bookMetadata = metadata[book.title];
        if (bookMetadata != null) {
          book.heCategories = bookMetadata['heCategories'];
          book.author ??= bookMetadata['author'];
          book.heEra ??= bookMetadata['heEra'];
          if (book.heCategories != null && book.heCategories!.isNotEmpty) {
            debugPrint(
                '📚 Background: נטען heCategories מ-metadata: "${book.heCategories}"');
            PageShapeDebugLogger.log(
              'TextBookBloc',
              'heCategories הועשרו מהרקע מתוך metadata',
              scope: _debugScope,
              data: {
                'bookTitle': book.title,
                'heCategories': book.heCategories,
                'source': 'metadata',
              },
            );
            return;
          }
        }
      }

      // ניסיון 3: חילוץ מהנתיב
      if (book.heCategories == null || book.heCategories!.isEmpty) {
        final titleToPath = await FileSystemData.instance.titleToPath;
        final bookPath = titleToPath[book.title];
        if (bookPath != null) {
          // titleToPath יכול להכיל נתיב קובץ (FS) או נתיב קטגוריה מה-DB.
          if (bookPath.contains(Platform.pathSeparator)) {
            final pathParts = bookPath.split(Platform.pathSeparator);
            final otzariaIndex = pathParts.indexOf('אוצריא');
            if (otzariaIndex >= 0 && otzariaIndex < pathParts.length - 2) {
              final categories =
                  pathParts.sublist(otzariaIndex + 1, pathParts.length - 1);
              book.heCategories = categories.join(', ');
              debugPrint(
                  '📚 Background: נטען heCategories מהנתיב: "${book.heCategories}"');
              PageShapeDebugLogger.log(
                'TextBookBloc',
                'heCategories הועשרו מהרקע מתוך נתיב קובץ',
                scope: _debugScope,
                data: {
                  'bookTitle': book.title,
                  'heCategories': book.heCategories,
                  'source': 'path-file',
                },
              );
            }
          } else {
            final normalizedCategories = bookPath
                .split(',')
                .map((part) => part.trim())
                .where((part) => part.isNotEmpty)
                .join(', ');
            if (normalizedCategories.isNotEmpty) {
              book.heCategories = normalizedCategories;
              debugPrint(
                  '📚 Background: נטען heCategories מנתיב קטגוריה: "${book.heCategories}"');
              PageShapeDebugLogger.log(
                'TextBookBloc',
                'heCategories הועשרו מהרקע מתוך נתיב קטגוריה',
                scope: _debugScope,
                data: {
                  'bookTitle': book.title,
                  'heCategories': book.heCategories,
                  'source': 'path-category',
                },
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Failed to enrich heCategories in background: $e');
      PageShapeDebugLogger.log(
        'TextBookBloc',
        'נכשלה העשרת heCategories ברקע',
        scope: _debugScope,
        data: {
          'bookTitle': book.title,
          'error': e,
        },
        level: 'WARN',
      );
    }
  }

  List<CommentatorGroup> _buildCommentatorGroups(
      Map<String, List<String>> eras, List<String> availableCommentators) {
    final known = <String>{
      ...?eras['תורה שבכתב'],
      ...?eras['חז"ל'],
      ...?eras['ראשונים'],
      ...?eras['אחרונים'],
      ...?eras['מחברי זמננו'],
    };

    final others = (eras['מפרשים נוספים'] ?? [])
        .toSet()
        .union(availableCommentators
            .where((c) => !known.contains(c))
            .toList()
            .toSet())
        .toList();

    return [
      CommentatorGroup(
        title: 'תורה שבכתב',
        commentators: eras['תורה שבכתב'] ?? const [],
      ),
      CommentatorGroup(
        title: 'חז"ל',
        commentators: eras['חז"ל'] ?? const [],
      ),
      CommentatorGroup(
        title: 'ראשונים',
        commentators: eras['ראשונים'] ?? const [],
      ),
      CommentatorGroup(
        title: 'אחרונים',
        commentators: eras['אחרונים'] ?? const [],
      ),
      CommentatorGroup(
        title: 'מחברי זמננו',
        commentators: eras['מחברי זמננו'] ?? const [],
      ),
      CommentatorGroup(
        title: 'שאר מפרשים',
        commentators: others,
      ),
    ];
  }
}
