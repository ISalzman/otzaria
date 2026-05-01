import 'dart:async';
import 'package:hive_ce/hive.dart';
import 'package:otzaria/tabs/models/tab.dart';
import 'package:otzaria/tabs/bloc/tabs_state.dart';
import 'package:otzaria/utils/file/hive_utils.dart';
import 'package:flutter/foundation.dart';

class TabsRepository {
  static const String _tabsBoxKey = 'key-tabs';
  static const String _currentTabKey = 'key-current-tab';
  static const String _sideBySideModeKey = 'key-side-by-side-mode';

  List<OpenedTab> loadTabs() {
    try {
      final box = Hive.box('tabs');
      final rawTabs = box.get(_tabsBoxKey, defaultValue: []) as List;
      return List<OpenedTab>.from(
        rawTabs.map((e) => OpenedTab.fromJson(castMap(e))).toList(),
      );
    } catch (e) {
      debugPrint('⚠️ Error loading tabs from disk: $e');
      return [];
    }
  }

  int loadCurrentTabIndex() {
    return Hive.box('tabs').get(_currentTabKey, defaultValue: 0);
  }

  SideBySideMode? loadSideBySideMode() {
    try {
      final box = Hive.box('tabs');
      final rawMode = box.get(_sideBySideModeKey);
      if (rawMode == null) return null;
      return SideBySideMode.fromJson(castMap(rawMode));
    } catch (e) {
      debugPrint('Error loading side-by-side mode from disk: $e');
      return null;
    }
  }

  Future<void> saveTabs(List<OpenedTab> tabs, int currentTabIndex,
      [SideBySideMode? sideBySideMode]) async {
    final box = Hive.box('tabs');
    await box.put(_tabsBoxKey, tabs.map((tab) => tab.toJson()).toList());
    await box.put(_currentTabKey, currentTabIndex);
    if (sideBySideMode != null) {
      await box.put(_sideBySideModeKey, sideBySideMode.toJson());
    } else {
      await box.delete(_sideBySideModeKey);
    }
  }
}
