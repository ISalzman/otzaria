import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import 'package:otzaria/settings/custom_folders/custom_folder.dart';
import 'package:otzaria/settings/settings_repository.dart';
import 'package:otzaria/widgets/confirmation_dialog.dart';
import 'package:otzaria/migration/sync/file_sync_service.dart';
import 'package:otzaria/data/data_providers/sqlite_data_provider.dart';
import 'package:otzaria/library/bloc/library_bloc.dart';
import 'package:otzaria/library/bloc/library_event.dart';

/// Widget להוספה וניהול תיקיות מותאמות אישית
class CustomFoldersTile extends StatefulWidget {
  const CustomFoldersTile({super.key});

  @override
  State<CustomFoldersTile> createState() => _CustomFoldersTileState();
}

class _CustomFoldersTileState extends State<CustomFoldersTile> {
  List<CustomFolder> _folders = [];
  bool _isExpanded = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  void _loadFolders() {
    final jsonString =
        Settings.getValue<String>(SettingsRepository.keyCustomFolders);
    setState(() {
      _folders = CustomFoldersManager.loadFolders(jsonString);
    });
  }

  Future<void> _saveFolders() async {
    final jsonString = CustomFoldersManager.saveFolders(_folders);
    await Settings.setValue(SettingsRepository.keyCustomFolders, jsonString);
  }

  Future<void> _addFolder() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path != null) {
      // בדיקה שהתיקייה קיימת
      final dir = Directory(path);
      if (!await dir.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('התיקייה לא נמצאה')),
        );
        return;
      }

      setState(() {
        _folders = CustomFoldersManager.addFolder(_folders, path);
        if (_folders.length == 1) {
          _isExpanded = true;
        }
      });
      await _saveFolders();

      // רענון הספרייה כדי להציג את הספרים החדשים
      if (mounted) {
        context.read<LibraryBloc>().add(RefreshLibrary());
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'התיקייה "${path.split(Platform.pathSeparator).last}" נוספה בהצלחה')),
      );
    }
  }

  Future<void> _removeFolder(CustomFolder folder) async {
    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'הסרת תיקייה',
      content: 'האם להסיר את התיקייה "${folder.name}" מהרשימה?\n'
          'הקבצים עצמם לא יימחקו.',
    );

    if (confirmed == true) {
      setState(() {
        _folders = CustomFoldersManager.removeFolder(_folders, folder.path);
      });
      await _saveFolders();

      // רענון הספרייה
      if (mounted) {
        context.read<LibraryBloc>().add(RefreshLibrary());
      }
    }
  }

  Future<void> _toggleAddToDatabase(CustomFolder folder, bool value) async {
    if (value) {
      // הצגת אזהרה לפני הפעלה
      final confirmed = await showConfirmationDialog(
        context: context,
        title: 'הכנסת תוכן ל-DB',
        content:
            'שים לב: לאחר הכנסת תוכן התיקייה למסד הנתונים, קבצי הטקסט המקוריים יימחקו.\n\n'
            'האם להמשיך?',
        isDangerous: true,
      );

      if (confirmed != true) return;

      setState(() {
        _folders = CustomFoldersManager.updateFolderDbSetting(
            _folders, folder.path, value);
      });
      await _saveFolders();

      // הפעל סנכרון
      await _syncFolderToDatabase(folder);
    } else {
      // כיבוי - הצגת אזהרה ושחזור קבצים
      final confirmed = await showConfirmationDialog(
        context: context,
        title: 'הסרת תיקייה מה-DB',
        content: 'האם להסיר את התיקייה מהמסד הנתונים ולשחזר את הקבצים?\n\n'
            'הספרים יוחזרו לתיקייה המקורית כקבצי טקסט.',
        isDangerous: true,
      );

      if (confirmed != true) return;

      setState(() {
        _folders = CustomFoldersManager.updateFolderDbSetting(
            _folders, folder.path, value);
      });
      await _saveFolders();

      // שחזר קבצים מה-DB
      await _restoreFolderFromDatabase(folder);
    }
  }

  Future<void> _restoreFolderFromDatabase(CustomFolder folder) async {
    setState(() {
      _isSyncing = true;
    });

    try {
      final sqliteProvider = SqliteDataProvider.instance;
      if (!sqliteProvider.isInitialized) {
        await sqliteProvider.initialize();
      }

      final repository = sqliteProvider.repository;
      if (repository == null) {
        throw Exception('מסד הנתונים לא זמין');
      }

      final syncService = await FileSyncService.getInstance(repository);
      if (syncService == null) {
        throw Exception('שירות הסנכרון לא זמין');
      }

      // שחזור קבצים מה-DB
      final result = await syncService.restoreFolderFromDatabase(
        folder,
        onProgress: (progress, message) {
          debugPrint('Restore progress: $progress - $message');
        },
      );

      if (!mounted) return;

      // רענון הספרייה
      if (mounted) {
        context.read<LibraryBloc>().add(RefreshLibrary());
      }

      if (!mounted) return;

      if (result.errors.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'השחזור הושלם עם שגיאות: ${result.restoredBooks} ספרים שוחזרו',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'השחזור הושלם: ${result.restoredBooks} ספרים שוחזרו',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('שגיאה בשחזור: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Future<void> _syncFolderToDatabase(CustomFolder folder) async {
    setState(() {
      _isSyncing = true;
    });

    try {
      final sqliteProvider = SqliteDataProvider.instance;
      if (!sqliteProvider.isInitialized) {
        await sqliteProvider.initialize();
      }

      final repository = sqliteProvider.repository;
      if (repository == null) {
        throw Exception('מסד הנתונים לא זמין');
      }

      final syncService = await FileSyncService.getInstance(repository);
      if (syncService == null) {
        throw Exception('שירות הסנכרון לא זמין');
      }

      // הפעלת סנכרון לתיקייה הספציפית
      final result = await syncService.syncFiles(
        onProgress: (progress, message) {
          debugPrint('Sync progress: $progress - $message');
        },
      );

      // רענון הספרייה
      if (mounted) {
        context.read<LibraryBloc>().add(RefreshLibrary());
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'הסנכרון הושלם: ${result.addedBooks} ספרים נוספו, '
            '${result.updatedBooks} עודכנו',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('שגיאה בסנכרון: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(FluentIcons.folder_add_24_regular),
          title: const Text('הוסף תיקייה לאוצריא'),
          subtitle: Text(
            _folders.isEmpty
                ? 'לחץ להוספת תיקיות אישיות'
                : '${_folders.length} תיקיות',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(FluentIcons.add_24_regular),
                onPressed: _addFolder,
                tooltip: 'הוסף תיקייה',
              ),
              if (_folders.isNotEmpty)
                IconButton(
                  icon: Icon(
                    _isExpanded
                        ? FluentIcons.chevron_up_24_regular
                        : FluentIcons.chevron_down_24_regular,
                  ),
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  tooltip: _isExpanded ? 'הסתר' : 'הצג תיקיות',
                ),
            ],
          ),
          onTap: _addFolder,
        ),
        if (_isExpanded && _folders.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(right: 16, left: 16, bottom: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: _folders.map((folder) {
                return _buildFolderItem(folder);
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildFolderItem(CustomFolder folder) {
    return ListTile(
      dense: true,
      leading: Icon(
        FluentIcons.folder_24_filled,
        color: Theme.of(context).colorScheme.primary,
        size: 20,
      ),
      title: Text(
        folder.name,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        folder.path,
        style: TextStyle(
          fontSize: 11,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Toggle להכנסה ל-DB
          Tooltip(
            message: 'הכנס תוכן ל-DB',
            child: _isSyncing && folder.addToDatabase
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Switch(
                    value: folder.addToDatabase,
                    onChanged: (value) => _toggleAddToDatabase(folder, value),
                  ),
          ),
          // כפתור הסרה
          IconButton(
            icon: const Icon(FluentIcons.delete_24_regular, size: 18),
            onPressed: () => _removeFolder(folder),
            tooltip: 'הסר תיקייה',
          ),
        ],
      ),
    );
  }
}
