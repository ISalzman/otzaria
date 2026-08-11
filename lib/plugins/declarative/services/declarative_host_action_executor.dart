import 'package:otzaria/plugins/declarative/models/declarative_program.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';

abstract interface class DeclarativeBookOpener {
  Future<bool> openUnique(
    Map<String, dynamic> identity, {
    required int index,
    required String searchQuery,
  });
}

class DeclarativeHostActionExecutor {
  final DeclarativeBookOpener bookOpener;

  const DeclarativeHostActionExecutor({required this.bookOpener});

  Future<bool> execute({
    required CompiledDeclarativeAction action,
    required InstalledPlugin plugin,
    required Set<String> grantedPermissions,
    required String currentContextSignature,
  }) async {
    if (!plugin.enabled) {
      throw const DeclarativeProgramException(
        'declarative.plugin_disabled',
        'The plugin is disabled',
      );
    }
    if (!grantedPermissions.contains(action.requiredPermission)) {
      throw const DeclarativeProgramException(
        'declarative.permission_denied',
        'The action permission is no longer granted',
      );
    }
    if (currentContextSignature != action.contextSignature) {
      throw const DeclarativeProgramException(
        'declarative.stale_action',
        'The action belongs to an outdated reader context',
      );
    }
    switch (action.type) {
      case 'reader.openBook':
        return bookOpener.openUnique(
          Map<String, dynamic>.from(action.args['identity'] as Map),
          index: action.args['index'] as int? ?? 0,
          searchQuery: action.args['searchQuery'] as String? ?? '',
        );
      default:
        throw DeclarativeProgramException(
          'declarative.unknown_command',
          'Unknown Host action "${action.type}"',
        );
    }
  }
}
