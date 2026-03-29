import 'package:flutter/material.dart';
import 'package:otzaria/history/bloc/history_bloc.dart';
import 'package:otzaria/history/bloc/history_event.dart';
import 'package:otzaria/navigation/bloc/navigation_bloc.dart';
import 'package:otzaria/navigation/bloc/navigation_event.dart';
import 'package:otzaria/navigation/bloc/navigation_state.dart';
import 'package:otzaria/tabs/bloc/tabs_bloc.dart';
import 'package:otzaria/tabs/bloc/tabs_event.dart';
import 'package:otzaria/models/books.dart';
import "package:flutter_bloc/flutter_bloc.dart";
import 'package:otzaria/tabs/models/tab.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:collection/collection.dart';
import 'package:otzaria/text_book/view/page_shape/utils/page_shape_settings_manager.dart';
import 'package:otzaria/text_book/view/page_shape/utils/page_shape_debug_logger.dart';

void openBook(BuildContext context, Book book, int index, String searchQuery,
    {bool ignoreHistory = false}) {
  final scope = PageShapeDebugLogger.newScope(
    'open-book',
    label: book.title,
  );
  final trace = PageShapeDebugLogger.start(
    'OpenBook',
    'פתיחת ספר',
    scope: scope,
    data: {
      'bookTitle': book.title,
      'index': index,
      'searchQueryLength': searchQuery.length,
      'ignoreHistory': ignoreHistory,
      'bookType': book.runtimeType,
    },
  );

  try {
    // שמירת המצב הנוכחי לפני פתיחת ספר חדש כדי למנוע בלבול במיקום
    final tabsState = context.read<TabsBloc>().state;
    trace.step(
      'מצב טאבים לפני פתיחה',
      data: {
        'hasOpenTabs': tabsState.hasOpenTabs,
        'currentTabTitle': tabsState.currentTab?.title,
        'tabsCount': tabsState.tabs.length,
      },
    );
    if (tabsState.hasOpenTabs) {
      context
          .read<HistoryBloc>()
          .add(CaptureStateForHistory(tabsState.currentTab!));
      trace.step(
        'נשלחה בקשה לשמירת מצב נוכחי להיסטוריה',
        data: {
          'capturedTabTitle': tabsState.currentTab?.title,
        },
      );
    }

    final historyState = context.read<HistoryBloc>().state;
    final lastOpened = ignoreHistory
        ? null
        : historyState.history
            .firstWhereOrNull((b) => b.book.title == book.title);
    trace.step(
      'נבדקה היסטוריה לספר',
      data: {
        'historyLength': historyState.history.length,
        'lastOpenedIndex': lastOpened?.index,
        'lastOpenedCommentatorsCount': lastOpened?.commentatorsToShow.length,
      },
    );

    // אם ignoreHistory=true או האינדקס שהועבר הוא מחושב ממעבר בין תצוגות, השתמש בו תמיד
    // רק אם האינדקס הוא 0 (ברירת מחדל) ולא ignoreHistory, השתמש בהיסטוריה
    final int initialIndex =
        (ignoreHistory || index != 0) ? index : (lastOpened?.index ?? 0);
    final List<String>? initialCommentators = lastOpened?.commentatorsToShow;

    final bool shouldOpenLeftPane =
        (Settings.getValue<bool>('key-pin-sidebar') ?? false) ||
            (Settings.getValue<bool>('key-default-sidebar-open') ?? false);

    // טעינת העדפת התצוגה השמורה לספר זה
    final bool? savedViewMode =
        PageShapeSettingsManager.getViewModePreference(book.title);
    trace.step(
      'חושבו פרמטרי הפתיחה',
      data: {
        'initialIndex': initialIndex,
        'initialCommentatorsCount': initialCommentators?.length,
        'shouldOpenLeftPane': shouldOpenLeftPane,
        'savedPageShapeViewMode': savedViewMode,
      },
    );

    final tab = OpenedTab.fromBook(
      book,
      initialIndex,
      searchText: searchQuery,
      commentators: initialCommentators,
      openLeftPane: shouldOpenLeftPane,
      showPageShapeView: savedViewMode, // העברת העדפת התצוגה השמורה
    );
    trace.step(
      'נוצר טאב לפתיחה',
      data: {
        'tabType': tab.runtimeType,
        'tabTitle': tab.title,
      },
    );
    context.read<TabsBloc>().add(OpenOrFocusTab(tab));
    trace.step('נשלח אירוע OpenOrFocusTab');

    context.read<NavigationBloc>().add(const NavigateToScreen(Screen.reading));
    trace.end(
      data: {
        'navigationTarget': Screen.reading.name,
      },
    );
  } catch (error, stackTrace) {
    trace.fail(error, stackTrace);
    rethrow;
  }
}
