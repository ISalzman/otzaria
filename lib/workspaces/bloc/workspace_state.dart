import 'package:equatable/equatable.dart';
import 'package:otzaria/workspaces/workspace.dart';

/// State for the WorkspaceBloc.
///
/// Uses [activeWorkspaceId] instead of index for safer workspace identification.
class WorkspaceState extends Equatable {
  final List<Workspace> workspaces;
  final bool isLoading;
  final String? error;

  /// The ID of the currently active workspace (instead of index)
  final String? activeWorkspaceId;

  const WorkspaceState({
    required this.workspaces,
    this.isLoading = false,
    this.error,
    this.activeWorkspaceId,
  });

  factory WorkspaceState.initial() {
    return const WorkspaceState(
      workspaces: [],
      isLoading: true,
      error: null,
      activeWorkspaceId: null,
    );
  }

  /// Returns the currently active workspace, or null if none.
  Workspace? get activeWorkspace {
    if (activeWorkspaceId == null) return null;
    try {
      return workspaces.firstWhere((w) => w.id == activeWorkspaceId);
    } catch (_) {
      return null;
    }
  }

  /// Returns the index of the active workspace in the list, or null if not found.
  /// Useful for UI components that need index-based operations.
  int? get activeWorkspaceIndex {
    if (activeWorkspaceId == null) return null;
    final index = workspaces.indexWhere((w) => w.id == activeWorkspaceId);
    return index >= 0 ? index : null;
  }

  WorkspaceState copyWith({
    List<Workspace>? workspaces,
    bool? isLoading,
    String? error,
    String? activeWorkspaceId,
  }) {
    return WorkspaceState(
      workspaces: workspaces ?? this.workspaces,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      activeWorkspaceId: activeWorkspaceId ?? this.activeWorkspaceId,
    );
  }

  @override
  List<Object?> get props => [workspaces, isLoading, error, activeWorkspaceId];
}
