import 'package:flutter/material.dart';
import 'dart:io';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager/window_manager.dart';
import 'package:otzaria/settings/settings_bloc.dart';
import 'package:otzaria/settings/settings_event.dart';
import 'package:otzaria/settings/settings_state.dart';

/// טאב הגדרות עיצוב
class AppearanceSettingsTab extends StatelessWidget {
  const AppearanceSettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // מסך מלא (רק בדסקטופ)
              if (!(Platform.isAndroid || Platform.isIOS))
                _buildSectionCard(
                  context: context,
                  title: 'תצוגה',
                  children: [
                    ListTile(
                      leading: Icon(state.isFullscreen
                          ? FluentIcons.full_screen_minimize_24_regular
                          : FluentIcons.full_screen_maximize_24_regular),
                      title: const Text('מסך מלא', style: TextStyle(fontSize: 16)),
                      subtitle: const Text('החלף מצב מסך מלא', style: TextStyle(fontSize: 13)),
                      trailing: Switch(
                        value: state.isFullscreen,
                        onChanged: (value) async {
                          context
                              .read<SettingsBloc>()
                              .add(UpdateIsFullscreen(value));
                          await windowManager.setFullScreen(value);
                        },
                      ),
                    ),
                  ],
                ),

              if (!(Platform.isAndroid || Platform.isIOS))
                const SizedBox(height: 16),

              // מצב כהה וצבע בסיס
              _buildSectionCard(
                context: context,
                title: 'ערכת נושא',
                children: [
                  SwitchListTile(
                    secondary: const Icon(FluentIcons.weather_moon_24_regular),
                    title: const Text('מצב כהה', style: TextStyle(fontSize: 16)),
                    subtitle: Text(state.isDarkMode ? 'מופעל' : 'לא מופעל', style: const TextStyle(fontSize: 13)),
                    value: state.isDarkMode,
                    onChanged: (value) {
                      context.read<SettingsBloc>().add(UpdateDarkMode(value));
                    },
                  ),
                  ClipRect(
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: 0.92,
                      child: ColorPickerSettingsTile(
                        key: ValueKey('color-picker-${state.isDarkMode ? 'dark' : 'light'}'),
                        title: 'צבע בסיס',
                        leading: const Icon(FluentIcons.color_24_regular),
                        settingKey: state.isDarkMode
                            ? 'key-dark-swatch-color'
                            : 'key-swatch-color',
                        onChange: (color) {
                          if (state.isDarkMode) {
                            context
                                .read<SettingsBloc>()
                                .add(UpdateDarkSeedColor(color));
                          } else {
                            context
                                .read<SettingsBloc>()
                                .add(UpdateSeedColor(color));
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // הסתרת שמות קודש
              _buildSectionCard(
                context: context,
                title: 'שמות קודש',
                children: [
                  SwitchListTile(
                    secondary: const Icon(FluentIcons.eye_off_24_regular),
                    title: const Text('הסתרת שמות הקודש', style: TextStyle(fontSize: 16)),
                    subtitle: Text(state.replaceHolyNames
                        ? 'השמות הקדושים יוחלפו מפאת קדושתם'
                        : 'השמות הקדושים יוצגו ככתיבתם', style: const TextStyle(fontSize: 13)),
                    value: state.replaceHolyNames,
                    onChanged: (value) {
                      context
                          .read<SettingsBloc>()
                          .add(UpdateReplaceHolyNames(value));
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required List<Widget> children,
    String? title,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(11)),
              ),
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ...children,
        ],
      ),
    );
  }
}
