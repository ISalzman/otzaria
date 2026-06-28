import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/plugins/bloc/plugin_system_bloc.dart';
import 'package:otzaria/plugins/bloc/plugin_system_event.dart';
import 'package:otzaria/plugins/bloc/plugin_system_state.dart';
import 'package:otzaria/navigation/bloc/navigation_bloc.dart';
import 'package:otzaria/navigation/bloc/navigation_event.dart';
import 'package:otzaria/navigation/bloc/navigation_state.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/utils/fluent_icon_resolver.dart';
import 'package:otzaria/settings/engine/settings_bloc.dart';
import 'package:otzaria/settings/services/safer_mode/protected_settings_wrapper.dart';
import 'package:otzaria/widgets/dialogs/dialogs_exports.dart';
import 'package:otzaria/widgets/misc/rtl_icon.dart';

class PluginSidePanel extends StatelessWidget {
  final Function(InstalledPlugin)? onPluginSelected;
  final bool showDevTools;
  final VoidCallback? onClose;

  const PluginSidePanel({
    super.key,
    this.onPluginSelected,
    this.showDevTools = kDebugMode,
    this.onClose,
  });

  Future<void> _installPlugin(BuildContext context) async {
    final verified = await verifyPasswordForAction(context);
    if (!verified || !context.mounted) return;

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['otzplugin'],
      lockParentWindow: true,
    );
    if (result != null && result.files.single.path != null) {
      if (context.mounted) {
        context
            .read<PluginSystemBloc>()
            .add(InstallPluginRequested(result.files.single.path!));
      }
    }
  }

  Future<void> _loadDevPlugin(BuildContext context) async {
    final verified = await verifyPasswordForAction(context);
    if (!verified || !context.mounted) return;

    final rootPath = await FilePicker.getDirectoryPath(lockParentWindow: true);
    if (rootPath != null) {
      if (context.mounted) {
        context
            .read<PluginSystemBloc>()
            .add(LoadDevelopmentPluginRequested(rootPath));
      }
    }
  }

  Future<void> _loadLocalhostPlugin(BuildContext context) async {
    final verified = await verifyPasswordForAction(context);
    if (!verified || !context.mounted) return;

    final bloc = context.read<PluginSystemBloc>();
    final url = await showInputDialog(
      context: context,
      title: 'טעינת תוסף מ-localhost',
      labelText: 'Base URL',
      hintText: 'http://localhost:3000',
      initialValue: 'http://localhost:3000',
      cancelText: 'ביטול',
      confirmText: 'טען',
    );
    if (url != null && url.isNotEmpty) {
      bloc.add(LoadLocalhostPluginRequested(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              if (onClose != null)
                IconButton(
                  icon: Icon(FluentIcons.dismiss_24_regular),
                  tooltip: 'סגור',
                  onPressed: onClose,
                  iconSize: 20,
                ),
              const Expanded(
                child: Text(
                  'תוספים',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              IconButton(
                icon: Icon(FluentIcons.add_24_regular),
                tooltip: 'התקן תוסף חדש',
                onPressed: () => _installPlugin(context),
              ),
              if (showDevTools)
                IconButton(
                  icon: Icon(FluentIcons.folder_add_24_regular),
                  tooltip: 'טען תיקיית תוסף',
                  onPressed: () => _loadDevPlugin(context),
                ),
              if (showDevTools)
                IconButton(
                  icon: Icon(FluentIcons.globe_add_24_regular),
                  tooltip: 'טען תוסף מ-localhost',
                  onPressed: () => _loadLocalhostPlugin(context),
                ),
              if (showDevTools)
                IconButton(
                  icon: Icon(FluentIcons.arrow_sync_24_regular),
                  tooltip: 'רענן תוספים',
                  onPressed: () =>
                      context.read<PluginSystemBloc>().add(RefreshPlugins()),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: BlocBuilder<PluginSystemBloc, PluginSystemState>(
            builder: (context, state) {
              if (state is PluginSystemLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is PluginSystemError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'שגיאה: ${state.message}',
                    ),
                  ),
                );
              }
              if (state is PluginSystemLoaded) {
                final isOfflineMode = context
                    .select<SettingsBloc, bool>((b) => b.state.isOfflineMode);
                final plugins =
                    state.activePlugins.filterForOfflineMode(isOfflineMode);
                if (plugins.isEmpty) {
                  return Center(
                    child: Text(
                      isOfflineMode && state.plugins.isNotEmpty
                          ? 'כל התוספים המותקנים דורשים אינטרנט\nוהוסתרו במצב מנותק'
                          : 'לא הותקנו תוספים',
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: plugins.length,
                  itemBuilder: (context, index) {
                    final plugin = plugins[index];
                    return _PluginListTile(
                      key: ValueKey(plugin.pluginId),
                      plugin: plugin,
                      onPluginSelected: onPluginSelected,
                    );
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }
}

class _PluginListTile extends StatelessWidget {
  final InstalledPlugin plugin;
  final Function(InstalledPlugin)? onPluginSelected;

  const _PluginListTile({
    super.key,
    required this.plugin,
    required this.onPluginSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          RtlIcon(fluentIconFromName(plugin.manifest.toolTabIconName) ??
              FluentIcons.puzzle_piece_24_regular),
          if (plugin.isDevelopment)
            Positioned(
              right: -8,
              top: -8,
              child: Tooltip(
                message: 'תוסף פיתוח המוטען מתיקייה מקומית',
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'DEV',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onTertiary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(plugin.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(plugin.version),
      trailing: IconButton(
        icon: Icon(FluentIcons.settings_24_regular),
        tooltip: 'הגדרות תוסף',
        onPressed: () {
          context
              .read<NavigationBloc>()
              .add(const NavigateToScreen(Screen.settings));
        },
      ),
      onTap: () {
        if (onPluginSelected != null) {
          onPluginSelected!(plugin);
        }
      },
    );
  }
}
