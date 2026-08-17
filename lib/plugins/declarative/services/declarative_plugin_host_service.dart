import 'dart:async';
import 'dart:convert';

import 'package:otzaria/models/books.dart';
import 'package:otzaria/plugins/database/plugin_database_service.dart';
import 'package:otzaria/plugins/declarative/compiler/declarative_action_compiler.dart';
import 'package:otzaria/plugins/declarative/compiler/declarative_program_compiler.dart';
import 'package:otzaria/plugins/declarative/compiler/declarative_selection_action.dart';
import 'package:otzaria/plugins/declarative/compiler/declarative_toolbar_template_compiler.dart';
import 'package:otzaria/plugins/declarative/models/declarative_program.dart';
import 'package:otzaria/plugins/declarative/models/declarative_toolbar_template.dart';
import 'package:otzaria/plugins/declarative/repository/declarative_program_repository.dart';
import 'package:otzaria/plugins/declarative/services/declarative_host_action_executor.dart';
import 'package:otzaria/plugins/declarative/services/declarative_program_executor.dart';
import 'package:otzaria/plugins/declarative/services/declarative_toolbar_binding_service.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/models/plugin_book_identity.dart';
import 'package:otzaria/plugins/models/plugin_valid_permissions.dart';
import 'package:otzaria/plugins/services/plugin_toolbar_registry.dart';

typedef DeclarativePluginLoader =
    Future<InstalledPlugin?> Function(String pluginId);
typedef DeclarativePermissionLoader =
    Future<Set<String>> Function(String pluginId);
typedef DeclarativeHostErrorHandler =
    void Function(String pluginId, Object error, StackTrace stackTrace);

abstract interface class DeclarativePluginHost {
  Future<void> syncPlugins(List<InstalledPlugin> plugins);

  void removePlugin(String pluginId);

  Future<void> readerBookChanged(Book? book, {required String context});

  Future<void> dispatchAction(
    String pluginId,
    CompiledDeclarativeAction action,
  );

  Future<void> dispatchSelectionAction(
    String pluginId,
    Map<String, dynamic> actionTemplate,
    Map<String, dynamic> selectionPayload,
  );

  void dispose();
}

class DeclarativePluginHostService implements DeclarativePluginHost {
  final DeclarativePluginLoader _loadPlugin;
  final DeclarativePermissionLoader _loadPermissions;
  final DeclarativeHostErrorHandler? onError;
  final DeclarativeProgramRepository programRepository;
  final DeclarativeToolbarBindingService toolbarBinding;
  final DeclarativeHostActionExecutor _actionExecutor;

  factory DeclarativePluginHostService({
    required DeclarativePluginLoader loadPlugin,
    required DeclarativePermissionLoader loadPermissions,
    required DeclarativeBookResolver bookResolver,
    required DeclarativeBookOpener bookOpener,
    PluginToolbarRegistry? toolbarRegistry,
    PluginDatabaseService? databaseService,
    DeclarativeParallelEditionsFinder? parallelEditionsFinder,
    DeclarativeStorageWriter? storageWriter,
    DeclarativeHostErrorHandler? onError,
  }) {
    final programs = DeclarativeProgramRepository(
      executor: DeclarativeProgramExecutor(
        databaseService: databaseService,
        bookResolver: bookResolver,
        parallelEditionsFinder: parallelEditionsFinder,
      ),
      onError: (pluginId, _, error, stackTrace) {
        onError?.call(pluginId, error, stackTrace);
      },
    );
    final binding = DeclarativeToolbarBindingService(
      programRepository: programs,
      toolbarRegistry: toolbarRegistry ?? PluginToolbarRegistry.instance,
      onError: onError,
    );
    return DeclarativePluginHostService._(
      loadPlugin: loadPlugin,
      loadPermissions: loadPermissions,
      programRepository: programs,
      toolbarBinding: binding,
      actionExecutor: DeclarativeHostActionExecutor(
        bookOpener: bookOpener,
        storageWriter: storageWriter,
      ),
      onError: onError,
    );
  }

  DeclarativePluginHostService._({
    required this._loadPlugin,
    required this._loadPermissions,
    required this.programRepository,
    required this.toolbarBinding,
    required this._actionExecutor,
    required this.onError,
  });

  final Set<String> _registeredPluginIds = {};
  int _syncGeneration = 0;
  String? _readerContextSignature;
  Book? _readerBook;
  String? _readerContext;

  @override
  Future<void> syncPlugins(List<InstalledPlugin> plugins) async {
    final generation = ++_syncGeneration;
    final idsToClear = {
      ..._registeredPluginIds,
      ...plugins.map((plugin) => plugin.pluginId),
    };
    for (final pluginId in idsToClear) {
      programRepository.removePlugin(pluginId);
      toolbarBinding.removePlugin(pluginId);
    }
    _registeredPluginIds.clear();

    final registrations = <_CompiledPluginRegistration>[];
    for (final plugin in plugins) {
      if (!plugin.enabled || plugin.manifest.startup == null) continue;
      try {
        final permissions = await _loadPermissions(plugin.pluginId);
        if (!permissions.contains(pluginStartupContributionsPermission)) {
          continue;
        }
        registrations.add(_compile(plugin, permissions));
      } catch (error, stackTrace) {
        onError?.call(plugin.pluginId, error, stackTrace);
      }
      if (_syncGeneration != generation) return;
    }
    if (_syncGeneration != generation) return;

    for (final registration in registrations) {
      final plugin = registration.plugin;
      programRepository.syncPlugin(
        plugin: plugin,
        programs: registration.programs,
        grantedPermissions: registration.grantedPermissions,
      );
      toolbarBinding.syncPlugin(
        plugin: plugin,
        templates: registration.grantedPermissions.contains('reader.toolbar')
            ? registration.toolbarTemplates
            : const [],
        grantedPermissions: registration.grantedPermissions,
      );
      _registeredPluginIds.add(plugin.pluginId);
    }
    await _evaluateReaderContext(force: true);
  }

  @override
  void removePlugin(String pluginId) {
    _syncGeneration++;
    _registeredPluginIds.remove(pluginId);
    programRepository.removePlugin(pluginId);
    toolbarBinding.removePlugin(pluginId);
  }

  @override
  Future<void> readerBookChanged(Book? book, {required String context}) async {
    _readerBook = book;
    _readerContext = book == null ? null : context;
    await _evaluateReaderContext();
  }

  Future<void> executeAction(
    String pluginId,
    CompiledDeclarativeAction action,
  ) async {
    final plugin = await _loadPlugin(pluginId);
    if (plugin == null) {
      throw const DeclarativeProgramException(
        'declarative.plugin_unavailable',
        'The plugin is no longer installed',
      );
    }
    final permissions = await _loadPermissions(pluginId);
    await _actionExecutor.execute(
      action: action,
      plugin: plugin,
      grantedPermissions: permissions,
      currentContextSignature:
          programRepository.getContextSignature(pluginId) ?? '',
      currentProgramGeneration: programRepository.getGeneration(pluginId),
    );
  }

  @override
  Future<void> dispatchAction(
    String pluginId,
    CompiledDeclarativeAction action,
  ) async {
    try {
      await executeAction(pluginId, action);
    } catch (error, stackTrace) {
      onError?.call(pluginId, error, stackTrace);
    }
  }

  /// חתימה מלאכותית לפעולת סימון: הפתרון והביצוע אטומיים בזמן הלחיצה,
  /// כך שמגן ה-stale_action של ה-executor מסופק תמיד ובצדק.
  static const String _selectionSignature = 'reader.selection';

  @override
  Future<void> dispatchSelectionAction(
    String pluginId,
    Map<String, dynamic> actionTemplate,
    Map<String, dynamic> selectionPayload,
  ) async {
    try {
      final plugin = await _loadPlugin(pluginId);
      if (plugin == null) {
        throw const DeclarativeProgramException(
          'declarative.plugin_unavailable',
          'The plugin is no longer installed',
        );
      }
      final declaredPermissions = plugin.manifest.permissions.toSet();
      DeclarativeSelectionAction.validateTemplate(
        actionTemplate,
        declaredPermissions: declaredPermissions,
      );
      final action =
          DeclarativeActionCompiler(
            declaredPermissions: declaredPermissions,
          ).compileResolved(
            DeclarativeSelectionAction.resolve(
              actionTemplate,
              selectionPayload,
            ),
            contextSignature: _selectionSignature,
            programGeneration: 1,
          );
      final permissions = await _loadPermissions(pluginId);
      await _actionExecutor.execute(
        action: action,
        plugin: plugin,
        grantedPermissions: permissions,
        currentContextSignature: _selectionSignature,
        currentProgramGeneration: 1,
      );
    } catch (error, stackTrace) {
      onError?.call(pluginId, error, stackTrace);
    }
  }

  @override
  void dispose() {
    _syncGeneration++;
    for (final pluginId in _registeredPluginIds.toList()) {
      programRepository.removePlugin(pluginId);
      toolbarBinding.removePlugin(pluginId);
    }
    _registeredPluginIds.clear();
    toolbarBinding.dispose();
    programRepository.dispose();
  }

  _CompiledPluginRegistration _compile(
    InstalledPlugin plugin,
    Set<String> grantedPermissions,
  ) {
    final startup = plugin.manifest.startup!;
    final declaredPermissions = plugin.manifest.permissions.toSet();
    if (!declaredPermissions.contains(pluginStartupContributionsPermission)) {
      throw const DeclarativeProgramException(
        'declarative.permission_not_declared',
        'Host contributions require app.startup_contributions',
      );
    }
    if (startup.toolbarItems.length >
        PluginToolbarRegistry.maxTopLevelItemsPerPlugin) {
      throw const DeclarativeProgramException(
        'declarative.too_many_toolbar_items',
        'A plugin may declare at most 2 toolbar items',
      );
    }
    final toolbarIds = startup.toolbarItems
        .map((item) => item['id'])
        .whereType<String>()
        .toList();
    if (toolbarIds.toSet().length != toolbarIds.length) {
      throw const DeclarativeProgramException(
        'declarative.duplicate_toolbar_item',
        'Toolbar item ids must be unique across all contribution types',
      );
    }
    if (startup.programs.length > 8) {
      throw const DeclarativeProgramException(
        'declarative.too_many_programs',
        'A plugin may declare at most 8 programs',
      );
    }
    final sourceIds = {
      for (final source in plugin.manifest.databaseSources)
        if (source['id'] is String) source['id'] as String,
    };
    final compiler = DeclarativeProgramCompiler(
      declaredPermissions: declaredPermissions,
      declaredSourceIds: sourceIds,
    );
    final programs = <CompiledDeclarativeProgram>[];
    final programsById = <String, CompiledDeclarativeProgram>{};
    for (final rawProgram in startup.programs) {
      final program = compiler.compile(rawProgram);
      if (programsById.containsKey(program.id)) {
        throw DeclarativeProgramException(
          'declarative.duplicate_program',
          'Program "${program.id}" is declared more than once',
        );
      }
      programs.add(program);
      programsById[program.id] = program;
    }
    final rawTemplates = startup.toolbarItems
        .where(DeclarativeToolbarTemplateCompiler.isDeclarative)
        .toList();
    if (rawTemplates.isNotEmpty &&
        !declaredPermissions.contains('reader.toolbar')) {
      throw const DeclarativeProgramException(
        'declarative.permission_not_declared',
        'Declarative toolbar items require reader.toolbar',
      );
    }
    final templates = DeclarativeToolbarTemplateCompiler(
      declaredPermissions: declaredPermissions,
      programs: programsById,
    ).compileAll(plugin.pluginId, rawTemplates);
    return _CompiledPluginRegistration(
      plugin: plugin,
      programs: List.unmodifiable(programs),
      toolbarTemplates: List.unmodifiable(templates),
      grantedPermissions: Set.unmodifiable(grantedPermissions),
    );
  }

  Future<void> _evaluateReaderContext({bool force = false}) async {
    final book = _readerBook;
    final context = _readerContext;
    if (book == null || context == null) {
      _readerContextSignature = null;
      programRepository.clearContexts();
      return;
    }
    final identity = PluginBookIdentity.toJson(book);
    final signature = jsonEncode({'context': context, 'book': identity});
    if (!force && signature == _readerContextSignature) return;
    _readerContextSignature = signature;
    await programRepository.runTrigger(
      trigger: 'reader.activeBookChanged',
      context: {
        'reader': {'context': context, 'book': identity},
      },
      contextSignature: signature,
    );
  }
}

class _CompiledPluginRegistration {
  final InstalledPlugin plugin;
  final List<CompiledDeclarativeProgram> programs;
  final List<CompiledDeclarativeToolbarTemplate> toolbarTemplates;
  final Set<String> grantedPermissions;

  const _CompiledPluginRegistration({
    required this.plugin,
    required this.programs,
    required this.toolbarTemplates,
    required this.grantedPermissions,
  });
}
