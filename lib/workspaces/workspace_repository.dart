import 'dart:developer' as developer;
import 'package:hive/hive.dart';
import 'package:otzaria/workspaces/workspace.dart';

/// Repository for persisting and loading workspaces.
///
/// Uses Hive for local storage. Now stores active workspace by ID
/// instead of index for safer identification.
class WorkspaceRepository {
  static const String _boxName = 'workspaces';
  static const String _workspacesKey = 'key-workspaces';
  static const String _currentWorkspaceIdKey = 'key-current-workspace-id';
  // Legacy key - kept for migration
  static const String _legacyCurrentWorkspaceKey = 'key-current-workspace';

  Box _getBox() {
    return Hive.box(name: _boxName);
  }

  /// Loads all workspaces and returns tuple of (workspaces, activeWorkspaceId).
  ///
  /// Handles migration from old index-based storage to new ID-based storage.
  (List<Workspace>, String?) loadWorkspaces() {
    try {
      final box = _getBox();
      final rawWorkspaces = box.get(_workspacesKey, defaultValue: []) as List;

      final workspaces = rawWorkspaces
          .map((e) => Workspace.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      // Try new ID-based key first
      String? currentId = box.get(_currentWorkspaceIdKey) as String?;

      // If no ID stored, try to migrate from old index-based storage
      if (currentId == null && workspaces.isNotEmpty) {
        final legacyIndex =
            box.get(_legacyCurrentWorkspaceKey, defaultValue: 0) as int;
        if (legacyIndex >= 0 && legacyIndex < workspaces.length) {
          currentId = workspaces[legacyIndex].id;
          // Save migrated ID
          box.put(_currentWorkspaceIdKey, currentId);
        }
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
      _getBox().put(_workspacesKey, []);
      return (<Workspace>[], null);
    }
  }

  /// Saves workspaces and the active workspace ID.
  void saveWorkspaces(List<Workspace> workspaces, String? currentWorkspaceId) {
    try {
      final box = _getBox();
      box.put(
        _workspacesKey,
        workspaces.map((workspace) => workspace.toJson()).toList(),
      );
      if (currentWorkspaceId != null) {
        box.put(_currentWorkspaceIdKey, currentWorkspaceId);
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error saving workspaces to disk',
        error: e,
        stackTrace: stackTrace,
        name: 'WorkspaceRepository',
      );
    }
  }
}
