import 'dart:async';
import 'dart:developer' as developer;
import 'package:hive_ce/hive.dart';
import 'package:otzaria/data/repository/hive_list_repository.dart';
import 'package:otzaria/utils/file/hive_utils.dart';
import 'package:otzaria/workspaces/workspace.dart';

/// Repository for persisting and loading workspaces.
///
/// ## מה משותף בין החלונות ומה לא
///
/// **רשימת השולחנות משותפת** — שולחן שנשמר בחלון אחד צריך להיות פתיח מכל
/// חלון, ולכן היא עוברת דרך [HiveListRepository] אל הבעלים.
///
/// **השולחן הפעיל הוא מצב פר-חלון**, ונשמר מקומית. "על איזה שולחן אני עובד
/// עכשיו" הוא בדיוק כמו "אילו כרטיסיות פתוחות לי": ניתוב שלו לבעלים היה
/// גורם למעבר שולחן בחלון אחד להחליף את התוכן של השני.
class WorkspaceRepository {
  static const String boxName = 'workspaces';
  static const String workspacesKey = 'key-workspaces';
  static const String _currentWorkspaceIdKey = 'key-current-workspace-id';
  // Legacy key - kept for migration
  static const String _legacyCurrentWorkspaceKey = 'key-current-workspace';

  final HiveListRepository<Workspace> _list = HiveListRepository<Workspace>(
    boxName: boxName,
    key: workspacesKey,
    fromJson: Workspace.fromJson,
    toJson: (workspace) => workspace.toJson(),
  );

  /// אות שרשימת השולחנות שונתה בחלון אחר.
  Stream<void> get remoteChanges => _list.remoteChanges;

  Box _getBox() => Hive.box(boxName);

  /// Loads all workspaces and returns tuple of (workspaces, activeWorkspaceId).
  ///
  /// Handles migration from old index-based storage to new ID-based storage.
  Future<(List<Workspace>, String?)> loadWorkspaces() async {
    try {
      // רשומה פגומה מדולגת ואינה מוחקת את השאר — [HiveListRepository.load].
      final workspaces = await _list.load();

      // Try new ID-based key first
      String? currentId = _readLocal(_currentWorkspaceIdKey) as String?;

      // If no ID stored, try to migrate from old index-based storage.
      if (currentId == null && workspaces.isNotEmpty) {
        currentId = _migrateLegacyActiveIndex(workspaces);
      }

      // Validate that the ID exists in the list
      if (currentId != null && !workspaces.any((w) => w.id == currentId)) {
        currentId = workspaces.isNotEmpty ? workspaces.first.id : null;
      }

      return (workspaces, currentId);
    } catch (e, stackTrace) {
      developer.log(
        'Error loading workspaces from disk',
        error: e,
        stackTrace: stackTrace,
        name: 'WorkspaceRepository',
      );
      // Do NOT overwrite persisted data — leave raw data intact
      return (<Workspace>[], null);
    }
  }

  /// מיגרציה מהמפתח הישן, שהחזיק **אינדקס** ולא מזהה.
  ///
  /// ⚠️ קוראת את הרשימה הגולמית מה-box המקומי ולא את הרשימה המפוענחת:
  /// האינדקס הישן מתייחס למקומות המקוריים, ורשומה פגומה שקדמה לשולחן
  /// הפעיל הייתה מזיזה אותו.
  String? _migrateLegacyActiveIndex(List<Workspace> workspaces) {
    final legacyIndex = _readLocal(_legacyCurrentWorkspaceKey) as int?;
    Workspace? atLegacy;
    if (legacyIndex != null) {
      final raw = _readLocal(workspacesKey);
      if (raw is List && legacyIndex >= 0 && legacyIndex < raw.length) {
        try {
          atLegacy = Workspace.fromJson(castMap(raw[legacyIndex]));
        } catch (_) {
          // רשומה פגומה במקום הישן — נופלים לראשון.
        }
      }
    }
    final resolved = (atLegacy ?? workspaces.first).id;
    unawaited(saveActiveWorkspaceId(resolved));
    return resolved;
  }

  Object? _readLocal(String key) {
    try {
      return _getBox().get(key);
    } catch (e) {
      developer.log(
        'Error reading $key',
        error: e,
        name: 'WorkspaceRepository',
      );
      return null;
    }
  }

  /// מחיל [apply] על רשימת השולחנות **הטרייה** ושומר. מחזיר את מה שנשמר.
  ///
  /// ⚠️ [apply] חייב להיות טהור — הוא עשוי לרוץ שוב אם חלון אחר כתב
  /// בינתיים. חישוב מ-`state` בתוכו מחזיר בדיוק את הבאג שהוא בא למנוע.
  Future<List<Workspace>> mutateWorkspaces(
    List<Workspace> Function(List<Workspace> current) apply,
  ) => _list.mutate(apply);

  /// שומר את מזהה השולחן הפעיל **של החלון הזה**. מקומי, לא מנותב.
  Future<void> saveActiveWorkspaceId(String? id) async {
    if (id == null) return;
    try {
      await _getBox().put(_currentWorkspaceIdKey, id);
    } catch (e, stackTrace) {
      developer.log(
        'Error saving active workspace id',
        error: e,
        stackTrace: stackTrace,
        name: 'WorkspaceRepository',
      );
    }
  }

  /// דריסה מוחלטת של רשימת השולחנות. שחזור מגיבוי בלבד.
  Future<void> replaceWorkspaces(
    List<Workspace> workspaces,
    String? currentWorkspaceId,
  ) async {
    await _list.overwrite(workspaces);
    await saveActiveWorkspaceId(currentWorkspaceId);
  }
}
