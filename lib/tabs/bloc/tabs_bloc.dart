import 'dart:math';
import 'package:flutter/foundation.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/tabs/bloc/tabs_event.dart';
import 'package:otzaria/tabs/tabs_repository.dart';
import 'package:otzaria/tabs/bloc/tabs_state.dart';
import 'package:otzaria/tabs/models/tab.dart';

class TabsBloc extends Bloc<TabsEvent, TabsState> {
  final TabsRepository _repository;

  TabsBloc({
    required TabsRepository repository,
  })  : _repository = repository,
        super(TabsState.initial()) {
    on<LoadTabs>(_onLoadTabs);
    on<AddTab>(_onAddTab);
    on<RemoveTab>(_onRemoveTab);
    on<SetCurrentTab>(_onSetCurrentTab);
    on<CloseAllTabs>(_onCloseAllTabs);
    on<CloseOtherTabs>(_onCloseOtherTabs);
    on<CloneTab>(_onCloneTab);
    on<MoveTab>(_onMoveTab);
    on<NavigateToNextTab>(_onNavigateToNextTab);
    on<NavigateToPreviousTab>(_onNavigateToPreviousTab);
    on<CloseCurrentTab>(_onCloseCurrentTab);
    on<SaveTabs>(_onSaveTabs);
    on<TogglePinTab>(_onTogglePinTab);
    on<EnableSideBySideMode>(_onEnableSideBySideMode);
    on<DisableSideBySideMode>(_onDisableSideBySideMode);
    on<UpdateSplitRatio>(_onUpdateSplitRatio);
    on<SwapSideBySideTabs>(_onSwapSideBySideTabs);
  }

  void _onLoadTabs(LoadTabs event, Emitter<TabsState> emit) {
    final tabs = _repository.loadTabs();
    final currentTabIndex = _repository.loadCurrentTabIndex();
    final sideBySideMode = _repository.loadSideBySideMode();

    // וידוא שהאינדקסים של side-by-side תקינים
    SideBySideMode? validatedMode;
    if (sideBySideMode != null && tabs.isNotEmpty) {
      if (sideBySideMode.leftTabIndex < tabs.length &&
          sideBySideMode.rightTabIndex < tabs.length &&
          sideBySideMode.leftTabIndex != sideBySideMode.rightTabIndex) {
        validatedMode = sideBySideMode;
      } else {
        debugPrint('DEBUG: מצב side-by-side לא תקין, מתעלם');
      }
    }

    emit(state.copyWith(
      tabs: tabs,
      currentTabIndex: currentTabIndex,
      sideBySideMode: validatedMode,
    ));
  }

  void _onSaveTabs(SaveTabs event, Emitter<TabsState> emit) {
    _repository.saveTabs(
        state.tabs, state.currentTabIndex, state.sideBySideMode);
  }

  void _onAddTab(AddTab event, Emitter<TabsState> emit) {
    debugPrint('DEBUG: הוספת טאב חדש - ${event.tab.title}');
    final newTabs = List<OpenedTab>.from(state.tabs);
    final newIndex = min(state.currentTabIndex + 1, newTabs.length);
    newTabs.insert(newIndex, event.tab);

    // עדכון אינדקסים במצב side-by-side אם קיים
    SideBySideMode? newSideBySideMode = state.sideBySideMode;
    if (state.sideBySideMode != null) {
      var newLeftIndex = state.sideBySideMode!.leftTabIndex;
      var newRightIndex = state.sideBySideMode!.rightTabIndex;

      // אם הטאב החדש נוסף לפני אחד מהטאבים במצב side-by-side, מעדכנים את האינדקס
      if (newIndex <= newLeftIndex) newLeftIndex++;
      if (newIndex <= newRightIndex) newRightIndex++;

      newSideBySideMode = state.sideBySideMode!.copyWith(
        leftTabIndex: newLeftIndex,
        rightTabIndex: newRightIndex,
      );

      debugPrint(
          'DEBUG: עדכון אינדקסים במצב side-by-side: left=$newLeftIndex, right=$newRightIndex');
    }

    _repository.saveTabs(newTabs, newIndex, newSideBySideMode);
    emit(state.copyWith(
      tabs: newTabs,
      currentTabIndex: newIndex,
      sideBySideMode: newSideBySideMode,
    ));
  }

  void _onRemoveTab(RemoveTab event, Emitter<TabsState> emit) async {
    final removedTabIndex = state.tabs.indexOf(event.tab);

    // ניקוי משאבים של הטאב שנסגר
    event.tab.dispose();

    final newTabs = List<OpenedTab>.from(state.tabs)..remove(event.tab);

    // בדיקה אם הטאב שנסגר היה חלק ממצב side-by-side
    SideBySideMode? newSideBySideMode = state.sideBySideMode;
    if (state.sideBySideMode != null) {
      if (removedTabIndex == state.sideBySideMode!.leftTabIndex ||
          removedTabIndex == state.sideBySideMode!.rightTabIndex) {
        // אם סגרנו אחד מהטאבים במצב side-by-side, מבטלים את המצב
        debugPrint('DEBUG: ביטול מצב side-by-side כי נסגר טאב שהיה חלק ממנו');
        newSideBySideMode = null;
      } else {
        // עדכון האינדקסים אם הם השתנו
        var newLeftIndex = state.sideBySideMode!.leftTabIndex;
        var newRightIndex = state.sideBySideMode!.rightTabIndex;

        if (removedTabIndex < newLeftIndex) newLeftIndex--;
        if (removedTabIndex < newRightIndex) newRightIndex--;

        newSideBySideMode = state.sideBySideMode!.copyWith(
          leftTabIndex: newLeftIndex,
          rightTabIndex: newRightIndex,
        );
      }
    }

    // אם אין טאבים נותרים, נשאיר את האינדקס ב-0
    if (newTabs.isEmpty) {
      _repository.saveTabs(newTabs, 0, null);
      emit(state.copyWith(
        tabs: newTabs,
        currentTabIndex: 0,
        clearSideBySide: true,
      ));
      return;
    }

    // חישוב האינדקס החדש - אם סגרנו טאב לפני או בדיוק על הטאב הפעיל, זזים אינדקס אחד אחורה
    var newIndex = removedTabIndex <= state.currentTabIndex
        ? max(state.currentTabIndex - 1, 0)
        : state.currentTabIndex;

    // וידוא שהאינדקס תקין (לא חורג מגבולות הרשימה)
    newIndex = min(newIndex, newTabs.length - 1);

    _repository.saveTabs(newTabs, newIndex, newSideBySideMode);
    emit(state.copyWith(
      tabs: newTabs,
      currentTabIndex: newIndex,
      sideBySideMode: newSideBySideMode,
      clearSideBySide: newSideBySideMode == null,
    ));
  }

  void _onSetCurrentTab(SetCurrentTab event, Emitter<TabsState> emit) {
    if (event.index >= 0 && event.index < state.tabs.length) {
      debugPrint(
          'DEBUG: מעבר לטאב ${event.index} - ${state.tabs[event.index].title}');

      // לא מבטלים את מצב side-by-side - פשוט עוברים לטאב
      // הפונקציה _shouldShowSideBySideView תחליט אם להציג side-by-side או TabBarView
      _repository.saveTabs(state.tabs, event.index, state.sideBySideMode);
      emit(state.copyWith(currentTabIndex: event.index));
    }
  }

  void _onCloseCurrentTab(CloseCurrentTab event, Emitter<TabsState> emit) {
    add(RemoveTab(state.tabs[state.currentTabIndex]));
  }

  void _onCloseAllTabs(CloseAllTabs event, Emitter<TabsState> emit) {
    // שמירת טאבים מוצמדים בלבד
    final pinnedTabs = state.tabs.where((tab) => tab.isPinned).toList();

    // ניקוי משאבים של כל הטאבים שאינם מוצמדים
    for (final tab in state.tabs) {
      if (!tab.isPinned) {
        tab.dispose();
      }
    }

    // אם יש טאבים מוצמדים, נשאיר אותם
    final newIndex = pinnedTabs.isNotEmpty ? 0 : 0;
    // ביטול מצב side-by-side כי סגרנו טאבים
    _repository.saveTabs(pinnedTabs, newIndex, null);
    emit(state.copyWith(
      tabs: pinnedTabs,
      currentTabIndex: newIndex,
      clearSideBySide: true,
    ));
  }

  void _onCloseOtherTabs(CloseOtherTabs event, Emitter<TabsState> emit) {
    // ניקוי משאבים של כל הטאבים מלבד זה שנשאר
    for (final tab in state.tabs) {
      if (tab != event.keepTab) {
        tab.dispose();
      }
    }

    final newTabs = [event.keepTab];
    // ביטול מצב side-by-side כי נשאר רק טאב אחד
    _repository.saveTabs(newTabs, 0, null);
    emit(state.copyWith(
      tabs: newTabs,
      currentTabIndex: 0,
      clearSideBySide: true,
    ));
  }

  void _onCloneTab(CloneTab event, Emitter<TabsState> emit) {
    add(AddTab(OpenedTab.from(event.tab)));
  }

  void _onMoveTab(MoveTab event, Emitter<TabsState> emit) {
    final newTabs = List<OpenedTab>.from(state.tabs);
    final currentTab = newTabs[state.currentTabIndex];
    final oldIndex = newTabs.indexOf(event.tab);
    newTabs.remove(event.tab);
    newTabs.insert(event.newIndex, event.tab);
    final newIndex = newTabs.indexOf(currentTab);

    // עדכון אינדקסים במצב side-by-side אם קיים
    SideBySideMode? newSideBySideMode = state.sideBySideMode;
    if (state.sideBySideMode != null) {
      var newLeftIndex = state.sideBySideMode!.leftTabIndex;
      var newRightIndex = state.sideBySideMode!.rightTabIndex;

      // עדכון האינדקסים לפי התזוזה
      if (oldIndex == newLeftIndex) {
        newLeftIndex = event.newIndex;
      } else if (oldIndex < newLeftIndex && event.newIndex >= newLeftIndex) {
        newLeftIndex--;
      } else if (oldIndex > newLeftIndex && event.newIndex <= newLeftIndex) {
        newLeftIndex++;
      }

      if (oldIndex == newRightIndex) {
        newRightIndex = event.newIndex;
      } else if (oldIndex < newRightIndex && event.newIndex >= newRightIndex) {
        newRightIndex--;
      } else if (oldIndex > newRightIndex && event.newIndex <= newRightIndex) {
        newRightIndex++;
      }

      newSideBySideMode = state.sideBySideMode!.copyWith(
        leftTabIndex: newLeftIndex,
        rightTabIndex: newRightIndex,
      );
    }

    _repository.saveTabs(newTabs, state.currentTabIndex, newSideBySideMode);
    emit(state.copyWith(
      tabs: newTabs,
      currentTabIndex: newIndex,
      sideBySideMode: newSideBySideMode,
    ));
  }

  void _onNavigateToNextTab(NavigateToNextTab event, Emitter<TabsState> emit) {
    if (state.currentTabIndex < state.tabs.length - 1) {
      final newIndex = state.currentTabIndex + 1;
      _repository.saveTabs(state.tabs, newIndex);
      emit(state.copyWith(currentTabIndex: newIndex));
    }
  }

  void _onNavigateToPreviousTab(
      NavigateToPreviousTab event, Emitter<TabsState> emit) {
    if (state.currentTabIndex > 0) {
      final newIndex = state.currentTabIndex - 1;
      _repository.saveTabs(state.tabs, newIndex);
      emit(state.copyWith(currentTabIndex: newIndex));
    }
  }

  void _onTogglePinTab(TogglePinTab event, Emitter<TabsState> emit) {
    final tabIndex = state.tabs.indexOf(event.tab);
    if (tabIndex == -1) return;

    // החלפת מצב ההצמדה
    event.tab.isPinned = !event.tab.isPinned;

    debugPrint(
        'DEBUG: הצמדת טאב ${event.tab.title} - isPinned: ${event.tab.isPinned}');

    // יצירת רשימה חדשה לחלוטין כדי לגרום ל-Equatable לזהות שינוי
    final newTabs = List<OpenedTab>.from(state.tabs);

    // שמירת השינויים
    _repository.saveTabs(newTabs, state.currentTabIndex);

    // עדכון ה-state כדי לגרום ל-rebuild - עם forceUpdate
    emit(state.copyWith(
      tabs: newTabs,
      currentTabIndex: state.currentTabIndex,
      forceUpdate: true,
    ));
  }

  void _onEnableSideBySideMode(
      EnableSideBySideMode event, Emitter<TabsState> emit) {
    final rightIndex = state.tabs.indexOf(event.rightTab);
    final leftIndex = state.tabs.indexOf(event.leftTab);

    if (rightIndex == -1 || leftIndex == -1) {
      debugPrint('ERROR: לא נמצאו הטאבים למצב side-by-side');
      return;
    }

    final sideBySideMode = SideBySideMode(
      rightTabIndex: rightIndex,
      leftTabIndex: leftIndex,
    );

    debugPrint(
        'DEBUG: הפעלת מצב side-by-side: right=${event.rightTab.title}, left=${event.leftTab.title}');

    _repository.saveTabs(state.tabs, state.currentTabIndex, sideBySideMode);

    emit(state.copyWith(
      sideBySideMode: sideBySideMode,
      forceUpdate: true,
    ));
  }

  void _onDisableSideBySideMode(
      DisableSideBySideMode event, Emitter<TabsState> emit) {
    debugPrint('DEBUG: ביטול מצב side-by-side');

    _repository.saveTabs(state.tabs, state.currentTabIndex, null);

    emit(state.copyWith(
      clearSideBySide: true,
      forceUpdate: true,
    ));
  }

  void _onUpdateSplitRatio(UpdateSplitRatio event, Emitter<TabsState> emit) {
    if (state.sideBySideMode == null) return;

    final updatedMode = state.sideBySideMode!.copyWith(splitRatio: event.ratio);

    _repository.saveTabs(state.tabs, state.currentTabIndex, updatedMode);

    emit(state.copyWith(
      sideBySideMode: updatedMode,
    ));
  }

  void _onSwapSideBySideTabs(
      SwapSideBySideTabs event, Emitter<TabsState> emit) {
    if (state.sideBySideMode == null) return;

    debugPrint('DEBUG: החלפת צדדים במצב side-by-side');

    final swappedMode = SideBySideMode(
      leftTabIndex: state.sideBySideMode!.rightTabIndex,
      rightTabIndex: state.sideBySideMode!.leftTabIndex,
      splitRatio: 1.0 - state.sideBySideMode!.splitRatio,
    );

    _repository.saveTabs(state.tabs, state.currentTabIndex, swappedMode);

    emit(state.copyWith(
      sideBySideMode: swappedMode,
      forceUpdate: true,
    ));
  }
}
