import 'package:flutter/material.dart';
import 'dart:io';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:otzaria/settings/settings_bloc.dart';
import 'package:otzaria/settings/settings_event.dart';
import 'package:otzaria/settings/settings_state.dart';
import 'package:otzaria/settings/settings_repository.dart';
import 'package:otzaria/library/bloc/library_bloc.dart';
import 'package:otzaria/library/bloc/library_event.dart';
import 'package:otzaria/navigation/bloc/navigation_bloc.dart';
import 'package:otzaria/navigation/bloc/navigation_event.dart';
import 'package:otzaria/settings/custom_folders/custom_folders_tile.dart';
import 'package:otzaria/utils/zip_extractor_service.dart';

/// טאב הגדרות ספרייה
class LibrarySettingsTab extends StatelessWidget {
  const LibrarySettingsTab({super.key});

  Future<void> _showExtractionDialog(
      BuildContext context, String path, {required bool isLibraryPath}) async {
    final progressNotifier = ValueNotifier<double>(0.0);
    final messageNotifier = ValueNotifier<String>('בודק תיקייה...');
    final isExtractingNotifier = ValueNotifier<bool>(false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('מעבד תיקייה'),
        content: ValueListenableBuilder<bool>(
          valueListenable: isExtractingNotifier,
          builder: (context, isExtracting, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isExtracting) ...[
                  SizedBox(
                    width: 250,
                    child: ValueListenableBuilder<double>(
                      valueListenable: progressNotifier,
                      builder: (context, progress, _) {
                        return LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<String>(
                    valueListenable: messageNotifier,
                    builder: (context, message, _) {
                      return Text(message, textAlign: TextAlign.center);
                    },
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<double>(
                    valueListenable: progressNotifier,
                    builder: (context, progress, _) {
                      return Text(
                        '${(progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      );
                    },
                  ),
                ] else ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<String>(
                    valueListenable: messageNotifier,
                    builder: (context, message, _) {
                      return Text(message);
                    },
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );

    try {
      // בדיקה וחילוץ ZIP
      final extractionResult =
          await ZipExtractorService.checkAndExtractZipIfNeeded(
        path,
        onProgress: (p, m) {
          progressNotifier.value = p;
          messageNotifier.value = m;
          isExtractingNotifier.value = true;
        },
        onAskDeleteZip: () async {
          // סגירת דיאלוג ההתקדמות
          if (context.mounted) {
            Navigator.of(context).pop();
          }

          // שאלת המשתמש
          final shouldDelete = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('מחיקת קובץ דחוס'),
              content: const Text(
                'האם למחוק את קובץ ה-ZIP המקורי?\n\n'
                'הקובץ הדחוס אינו נצרך עבור פעילות התוכנה והוא רק תופס מקום.\n'
                'מומלץ למחוק אותו.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('השאר את הקובץ'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('מחק את הקובץ'),
                ),
              ],
            ),
          );

          // פתיחה מחדש של דיאלוג ההתקדמות
          if (context.mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (dialogContext) => AlertDialog(
                title: const Text('משלים...'),
                content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('משלים חילוץ...'),
                  ],
                ),
              ),
            );
          }

          return shouldDelete ?? false;
        },
      );

      if (!extractionResult.success) {
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(extractionResult.errorMessage ?? 'שגיאה לא ידועה'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }

      // עדכון הנתיב
      if (context.mounted) {
        if (isLibraryPath) {
          context.read<LibraryBloc>().add(UpdateLibraryPath(path));
        } else {
          context.read<LibraryBloc>().add(UpdateHebrewBooksPath(path));
        }
      }

      // המתנה קצרה
      await Future.delayed(const Duration(milliseconds: 500));

      if (context.mounted) {
        Navigator.of(context).pop();
        context.read<NavigationBloc>().add(const CheckLibrary());

        if (extractionResult.successfullyExtracted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'הקובץ "${extractionResult.extractedFileName}" חולץ בהצלחה!'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      progressNotifier.dispose();
      messageNotifier.dispose();
      isExtractingNotifier.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // הגדרות ספרים חיצוניים
              _buildSectionCard(
                context: context,
                title: 'ספרים חיצוניים',
                children: [
                  SwitchListTile(
                    secondary: const Icon(FluentIcons.globe_24_regular),
                    title: const Text('האם להציג ספרים מאתרים חיצוניים?',
                        style: TextStyle(fontSize: 16)),
                    subtitle: Text(
                        state.showExternalBooks
                            ? 'יוצגו גם ספרים מאתרים חיצוניים'
                            : 'יוצגו רק ספרים מספריית אוצריא',
                        style: const TextStyle(fontSize: 13)),
                    value: state.showExternalBooks,
                    onChanged: (value) {
                      context
                          .read<SettingsBloc>()
                          .add(UpdateShowExternalBooks(value));
                      context
                          .read<SettingsBloc>()
                          .add(UpdateShowHebrewBooks(value));
                      context
                          .read<SettingsBloc>()
                          .add(UpdateShowOtzarHachochma(value));
                    },
                  ),
                  if (state.showExternalBooks) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.only(right: 32.0),
                      child: CheckboxListTile(
                        title: const Text('הצג ספרים מאוצר החכמה',
                            style: TextStyle(fontSize: 16)),
                        value: state.showOtzarHachochma,
                        onChanged: (value) {
                          if (value != null) {
                            context
                                .read<SettingsBloc>()
                                .add(UpdateShowOtzarHachochma(value));
                          }
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 32.0),
                      child: CheckboxListTile(
                        title: const Text('הצג ספרים מהיברובוקס',
                            style: TextStyle(fontSize: 16)),
                        value: state.showHebrewBooks,
                        onChanged: (value) {
                          if (value != null) {
                            context
                                .read<SettingsBloc>()
                                .add(UpdateShowHebrewBooks(value));
                          }
                        },
                      ),
                    ),
                  ],
                ],
              ),

              // מיקום ספריות (רק בדסקטופ)
              if (!(Platform.isAndroid || Platform.isIOS)) ...[
                const SizedBox(height: 16),
                _buildSectionCard(
                  context: context,
                  title: 'מיקום ספריות',
                  children: [
                    ListTile(
                      leading: const Icon(FluentIcons.folder_24_regular),
                      title: const Text('מיקום הספרייה',
                          style: TextStyle(fontSize: 16)),
                      subtitle: Text(
                        Settings.getValue<String>(
                                SettingsRepository.keyLibraryPath) ??
                            'לא קיים',
                        style: const TextStyle(fontSize: 13),
                      ),
                      trailing:
                          const Icon(FluentIcons.chevron_right_24_regular),
                      onTap: () async {
                        String? path =
                            await FilePicker.platform.getDirectoryPath();
                        if (path != null && context.mounted) {
                          // הצגת דיאלוג חילוץ
                          _showExtractionDialog(context, path, isLibraryPath: true);
                        }
                      },
                    ),
                    const Divider(height: 1),
                    Tooltip(
                      message: 'במידה וקיימים ברשותך ספרים ממאגר זה',
                      child: ListTile(
                        leading: const Icon(FluentIcons.folder_24_regular),
                        title: const Text('מיקום ספרי היברובוקס',
                            style: TextStyle(fontSize: 16)),
                        subtitle: Text(
                          Settings.getValue<String>(
                                  SettingsRepository.keyHebrewBooksPath) ??
                              'לא קיים',
                          style: const TextStyle(fontSize: 13),
                        ),
                        trailing:
                            const Icon(FluentIcons.chevron_right_24_regular),
                        onTap: () async {
                          String? path =
                              await FilePicker.platform.getDirectoryPath();
                          if (path != null && context.mounted) {
                            // הצגת דיאלוג חילוץ
                            _showExtractionDialog(context, path, isLibraryPath: false);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],

              // תיקיות מותאמות אישית (רק בדסקטופ)
              if (!(Platform.isAndroid || Platform.isIOS)) ...[
                const SizedBox(height: 16),
                _buildSectionCard(
                  context: context,
                  title: 'תיקיות מותאמות אישית',
                  children: const [
                    CustomFoldersTile(),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required List<Widget> children,
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
