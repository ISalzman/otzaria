import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:otzaria/plugins/declarative/models/declarative_program.dart';
import 'package:otzaria/plugins/declarative/services/declarative_program_executor.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';

typedef DeclarativeProgramRun =
    Future<DeclarativeProgramResult> Function({
      required CompiledDeclarativeProgram program,
      required InstalledPlugin plugin,
      required Set<String> grantedPermissions,
      required Map<String, dynamic> context,
    });

typedef DeclarativeProgramErrorHandler =
    void Function(
      String pluginId,
      String programId,
      Object error,
      StackTrace stackTrace,
    );

class DeclarativeProgramRepository extends ChangeNotifier {
  final DeclarativeProgramRun _runProgram;
  final DeclarativeProgramErrorHandler? onError;

  DeclarativeProgramRepository({
    DeclarativeProgramExecutor? executor,
    DeclarativeProgramRun? runProgram,
    this.onError,
  }) : assert(executor == null || runProgram == null),
       _runProgram =
           runProgram ?? (executor ?? DeclarativeProgramExecutor()).execute;

  final Map<String, _ProgramRegistration> _registrations = {};
  final Map<String, Map<String, Map<String, dynamic>>> _outputs = {};
  final Map<String, int> _generations = {};
  final Map<String, String> _contextSignatures = {};

  void syncPlugin({
    required InstalledPlugin plugin,
    required List<CompiledDeclarativeProgram> programs,
    required Set<String> grantedPermissions,
  }) {
    _invalidate(plugin.pluginId);
    if (!plugin.enabled || programs.isEmpty) {
      _registrations.remove(plugin.pluginId);
      return;
    }
    _registrations[plugin.pluginId] = _ProgramRegistration(
      plugin: plugin,
      programs: List.unmodifiable(programs),
      grantedPermissions: Set.unmodifiable(grantedPermissions),
    );
  }

  void removePlugin(String pluginId) {
    _invalidate(pluginId);
    _registrations.remove(pluginId);
  }

  void clearContexts() {
    final changed = _outputs.isNotEmpty || _contextSignatures.isNotEmpty;
    for (final pluginId in _registrations.keys) {
      _generations[pluginId] = (_generations[pluginId] ?? 0) + 1;
    }
    _outputs.clear();
    _contextSignatures.clear();
    if (changed) notifyListeners();
  }

  Future<void> runTrigger({
    required String trigger,
    required Map<String, dynamic> context,
    required String contextSignature,
  }) async {
    final pending = <Future<void>>[];
    var clearedAny = false;
    for (final entry in _registrations.entries.toList()) {
      final relevant = entry.value.programs
          .where((program) => program.triggers.contains(trigger))
          .toList();
      if (relevant.isEmpty) continue;
      final pluginId = entry.key;
      final generation = (_generations[pluginId] ?? 0) + 1;
      _generations[pluginId] = generation;
      _contextSignatures[pluginId] = contextSignature;
      if (_outputs.remove(pluginId) != null) clearedAny = true;
      pending.add(
        _runPluginGeneration(
          registration: entry.value,
          programs: relevant,
          generation: generation,
          context: Map.unmodifiable(context),
          contextSignature: contextSignature,
        ),
      );
    }
    if (clearedAny) notifyListeners();
    await Future.wait(pending);
  }

  Map<String, dynamic>? getProgramOutputs(
    String pluginId,
    String programId,
  ) {
    return _outputs[pluginId]?[programId];
  }

  Map<String, Map<String, dynamic>> getPluginOutputs(String pluginId) {
    return UnmodifiableMapView(_outputs[pluginId] ?? const {});
  }

  String? getContextSignature(String pluginId) => _contextSignatures[pluginId];

  int getGeneration(String pluginId) => _generations[pluginId] ?? 0;

  Future<void> _runPluginGeneration({
    required _ProgramRegistration registration,
    required List<CompiledDeclarativeProgram> programs,
    required int generation,
    required Map<String, dynamic> context,
    required String contextSignature,
  }) async {
    final completed = <String, Map<String, dynamic>>{};
    for (final program in programs) {
      try {
        final result = await _runProgram(
          program: program,
          plugin: registration.plugin,
          grantedPermissions: registration.grantedPermissions,
          context: context,
        );
        completed[program.id] = result.outputs;
      } catch (error, stackTrace) {
        onError?.call(
          registration.plugin.pluginId,
          program.id,
          error,
          stackTrace,
        );
        completed[program.id] = const {};
      }
    }

    final pluginId = registration.plugin.pluginId;
    if (_generations[pluginId] != generation ||
        !identical(_registrations[pluginId], registration) ||
        _contextSignatures[pluginId] != contextSignature) {
      return;
    }
    _outputs[pluginId] = Map.unmodifiable(completed);
    notifyListeners();
  }

  void _invalidate(String pluginId) {
    _generations[pluginId] = (_generations[pluginId] ?? 0) + 1;
    _contextSignatures.remove(pluginId);
    if (_outputs.remove(pluginId) != null) notifyListeners();
  }
}

class _ProgramRegistration {
  final InstalledPlugin plugin;
  final List<CompiledDeclarativeProgram> programs;
  final Set<String> grantedPermissions;

  const _ProgramRegistration({
    required this.plugin,
    required this.programs,
    required this.grantedPermissions,
  });
}
