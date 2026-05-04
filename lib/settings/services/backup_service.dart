import 'dart:io';
import 'dart:convert';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:logging/logging.dart';
import 'package:otzaria/bookmarks/repository/bookmark_repository.dart';
import 'package:otzaria/bookmarks/models/bookmark.dart';
import 'package:otzaria/data/data_providers/hive_data_provider.dart';
import 'package:otzaria/history/history_repository.dart';
import 'package:otzaria/settings/engine/settings_engine_exports.dart';
import 'package:otzaria/workspaces/workspace_repository.dart';
import 'package:otzaria/workspaces/workspace.dart';
import 'package:otzaria/personal_notes/storage/personal_notes_database.dart';
import 'package:otzaria/personal_notes/models/personal_note.dart';
import 'package:otzaria/core/app_paths.dart';

/// Service for backing up and restoring app data
class BackupService {
  static final Logger _logger = Logger('BackupService');
  static const String backupFolderName = 'backups';

  /// Get the backup directory path
  static Future<String> getBackupDirectory() async {
    final backupPath = await AppPaths.getBackupPath();
    final dir = Directory(backupPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return backupPath;
  }

  /// Open the backup directory in the file explorer
  static Future<void> openBackupDirectory() async {
    final dir = await getBackupDirectory();
    if (Platform.isWindows) {
      await Process.run('explorer', [dir]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [dir]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [dir]);
    }
  }

  /// Create a backup with specified options.
  /// Returns the backup path and a list of sections that were skipped (e.g. when Hive box is not open).
  static Future<({String path, List<String> skippedSections})> createBackup({
    required bool includeSettings,
    required bool includeBookmarks,
    required bool includeHistory,
    required bool includeNotes,
    required bool includeWorkspaces,
    required bool includeShamorZachor,
    required bool includeUserOverrides,
  }) async {
    final skippedSections = <String>[];
    try {
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final backupDir = await getBackupDirectory();
      final backupFileName = 'otzaria_backup_$timestamp.json';
      final backupPath = p.join(backupDir, backupFileName);

      _logger.info('Creating backup at: $backupPath');
      _logger.info('Backup directory: $backupDir');

      final backupData = <String, dynamic>{
        'version': '1.0',
        'timestamp': timestamp,
        'includes': {
          'settings': includeSettings,
          'bookmarks': includeBookmarks,
          'history': includeHistory,
          'notes': includeNotes,
          'workspaces': includeWorkspaces,
          'shamorZachor': includeShamorZachor,
          'userOverrides': includeUserOverrides,
        },
      };

      // Backup settings
      if (includeSettings) {
        backupData['settings'] = await _backupSettings();
      }

      // Backup bookmarks
      if (includeBookmarks) {
        backupData['bookmarks'] = await _backupBookmarks();
      }

      // Backup history
      if (includeHistory) {
        backupData['history'] = await _backupHistory();
      }

      // Backup notes
      if (includeNotes) {
        backupData['notes'] = await _backupNotes();
      }

      // Backup user overrides
      if (includeUserOverrides) {
        backupData['user_overrides'] = await _backupUserOverrides();
      }

      // Backup workspaces
      if (includeWorkspaces) {
        final workspacesData = await _backupWorkspaces();
        backupData['workspaces'] = workspacesData['workspaces'];
        backupData['currentWorkspace'] = workspacesData['currentWorkspace'];
      }

      // Backup Shamor Zachor
      if (includeShamorZachor) {
        if (!Hive.isBoxOpen(HiveCache.keyName)) {
          skippedSections.add('shamorZachor');
        }
        backupData['shamorZachor'] = await _backupShamorZachor();
      }

      if (skippedSections.isNotEmpty) {
        backupData['partial_sections'] = skippedSections;
      }

      // Write backup file
      final file = File(backupPath);
      _logger.info('Writing backup data (${backupData.length} keys)...');

      final jsonString = json.encode(backupData);
      _logger.info('JSON size: ${jsonString.length} characters');

      await file.writeAsString(jsonString);
      _logger.info('Backup file written successfully');

      // Verify file was created
      final exists = await file.exists();
      final size = exists ? await file.length() : 0;
      _logger.info('File exists: $exists, Size: $size bytes');

      return (path: backupPath, skippedSections: skippedSections);
    } catch (e, stackTrace) {
      _logger.severe('Error creating backup: $e');
      _logger.severe('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Backup all settings
  static Future<Map<String, dynamic>> _backupSettings() async {
    final settingsKeys = [
      SettingsRepository.keyDarkMode,
      SettingsRepository.keySwatchColor,
      SettingsRepository.keyFontSize,
      SettingsRepository.keyFontFamily,
      SettingsRepository.keyShowOtzarHachochma,
      SettingsRepository.keyShowHebrewBooks,
      SettingsRepository.keyShowExternalBooks,
      SettingsRepository.keyShowTeamim,
      SettingsRepository.keyReplaceHolyNames,
      SettingsRepository.keyAutoUpdateIndex,
      SettingsRepository.keyDefaultNikud,
      SettingsRepository.keyRemoveNikudFromTanach,
      SettingsRepository.keyDefaultSidebarOpen,
      SettingsRepository.keyPinSidebar,
      SettingsRepository.keySidebarWidth,
      SettingsRepository.keyFacetFilteringWidth,
      SettingsRepository.keyCalendarType,
      SettingsRepository.keySelectedCity,
      SettingsRepository.keyCalendarEvents,
      SettingsRepository.keyCopyWithHeaders,
      SettingsRepository.keyCopyHeaderFormat,
      SettingsRepository.keyLibraryPath,
      SettingsRepository.keyDbEffectivePath,
      SettingsRepository.keyHebrewBooksPath,
      SettingsRepository.keyDevChannel,
      SettingsRepository.keyAutoSync,
      SettingsRepository.keyOfflineMode,
      SettingsRepository.keyPersonalNotesCollapsedByDefault,
    ];

    final settings = <String, dynamic>{};
    for (final key in settingsKeys) {
      final value = Settings.getValue(key);
      if (value != null) {
        settings[key] = value;
      }
    }
    return settings;
  }

  /// Backup bookmarks
  static Future<List<Map<String, dynamic>>> _backupBookmarks() async {
    final repo = BookmarkRepository();
    final bookmarks = await repo.loadBookmarks();
    return bookmarks.map((b) => b.toJson()).toList();
  }

  /// Backup history
  static Future<List<Map<String, dynamic>>> _backupHistory() async {
    final repo = HistoryRepository();
    final history = await repo.loadHistory();
    return history.map((h) => h.toJson()).toList();
  }

  /// Backup notes from SQLite database
  static Future<List<Map<String, dynamic>>> _backupNotes() async {
    final database = PersonalNotesDatabase.instance;
    final booksWithNotes = await database.listBooksWithNotes();

    final List<Map<String, dynamic>> result = [];

    for (final bookInfo in booksWithNotes) {
      try {
        final notes = await database.loadNotes(bookInfo.bookId);
        if (notes.isEmpty) continue;

        result.add({
          'bookId': bookInfo.bookId,
          'notes': notes.map((note) => _noteToBackupJson(note)).toList(),
        });
      } catch (e) {
        _logger.warning(
            'Skipping notes for book ${bookInfo.bookId} due to error: $e');
      }
    }

    return result;
  }

  /// Convert PersonalNote to backup JSON format
  static Map<String, dynamic> _noteToBackupJson(PersonalNote note) {
    return {
      'id': note.id,
      'bookId': note.bookId,
      'lineNumber': note.lineNumber,
      'displayTitle': note.displayTitle,
      'lastKnownLineNumber': note.lastKnownLineNumber,
      'status': note.status.name,
      'content': note.content,
      'contentPlain': note.contentPlain,
      'contentFormat': note.contentFormat.name,
      'createdAt': note.createdAt.toIso8601String(),
      'updatedAt': note.updatedAt.toIso8601String(),
    };
  }

  /// Backup user overrides
  static Future<Map<String, dynamic>> _backupUserOverrides() async {
    final overridesDir = Directory(await AppPaths.getUserOverridesRootPath());

    if (!await overridesDir.exists()) {
      return {};
    }

    final overridesData = <String, dynamic>{};

    await for (final entity in overridesDir.list(recursive: true)) {
      if (entity is File &&
          (entity.path.endsWith('.md') ||
              entity.path.endsWith('.tmp') ||
              entity.path.endsWith('.recovery'))) {
        final relativePath = p.relative(entity.path, from: overridesDir.path);
        try {
          overridesData[relativePath] = await entity.readAsString();
        } catch (e) {
          _logger.warning('Failed to backup override file $relativePath: $e');
        }
      }
    }

    return overridesData;
  }

  /// Backup workspaces
  static Future<Map<String, dynamic>> _backupWorkspaces() async {
    final repo = WorkspaceRepository();
    final (workspaces, currentWorkspace) = repo.loadWorkspaces();
    return {
      'workspaces': workspaces.map((w) => w.toJson()).toList(),
      'currentWorkspace': currentWorkspace,
    };
  }

  /// Backup Shamor Zachor data - backs up all sz: keys found in Hive
  static Future<Map<String, dynamic>> _backupShamorZachor() async {
    if (!Hive.isBoxOpen(HiveCache.keyName)) {
      _logger.warning('_backupShamorZachor: Hive box not open — skipping (partial backup)');
      return {};
    }
    final box = Hive.box<dynamic>(HiveCache.keyName);
    final shamorZachorData = <String, dynamic>{};

    for (final key in box.keys.where((k) => k.toString().startsWith('sz:'))) {
      final value = box.get(key);
      if (value != null) {
        shamorZachorData[key.toString()] = value;
      }
    }

    return shamorZachorData;
  }

  /// Restore from backup file.
  /// Returns a list of sections that were missing in the backup file (partial backup).
  static Future<List<String>> restoreFromBackup(String backupPath) async {
    final file = File(backupPath);
    if (!await file.exists()) {
      throw Exception('קובץ הגיבוי לא נמצא');
    }

    final content = await file.readAsString();
    final backupData = json.decode(content) as Map<String, dynamic>;

    // Validate backup version
    final version = backupData['version'] as String?;
    if (version != '1.0') {
      throw Exception('גרסת גיבוי לא נתמכת');
    }

    final partialSections = (backupData['partial_sections'] as List?)
            ?.cast<String>() ??
        [];
    if (partialSections.isNotEmpty) {
      _logger.warning('Restoring a partial backup — sections missing: ${partialSections.join(", ")}');
    }

    final includes = backupData['includes'] as Map<String, dynamic>;

    // Restore settings
    if (includes['settings'] == true && backupData.containsKey('settings')) {
      await _restoreSettings(backupData['settings'] as Map<String, dynamic>);
    }

    // Restore bookmarks
    if ((includes['bookmarks'] == true ||
            includes['bookmarksAndHistory'] == true) &&
        backupData.containsKey('bookmarks')) {
      await _restoreBookmarks(
        (backupData['bookmarks'] as List).cast<Map<String, dynamic>>(),
      );
    }

    // Restore history
    if ((includes['history'] == true ||
            includes['bookmarksAndHistory'] == true) &&
        backupData.containsKey('history')) {
      await _restoreHistory(
        (backupData['history'] as List).cast<Map<String, dynamic>>(),
      );
    }

    // Restore notes
    if (includes['notes'] == true && backupData.containsKey('notes')) {
      await _restoreNotes(
        (backupData['notes'] as List).cast<Map<String, dynamic>>(),
      );
    }

    // Restore user_overrides
    final includeOverrides =
        includes['userOverrides'] as bool? ?? includes['notes'] == true;
    if (includeOverrides && backupData.containsKey('user_overrides')) {
      await _restoreUserOverrides(
        backupData['user_overrides'] as Map<String, dynamic>,
      );
    }

    // Restore workspaces
    if (includes['workspaces'] == true &&
        backupData.containsKey('workspaces')) {
      await _restoreWorkspaces(
        (backupData['workspaces'] as List).cast<Map<String, dynamic>>(),
        backupData['currentWorkspace'],
      );
    }

    // Restore Shamor Zachor
    final runtimeSkipped = <String>[];
    if (includes['shamorZachor'] == true &&
        backupData.containsKey('shamorZachor')) {
      final skipped = await _restoreShamorZachor(
        backupData['shamorZachor'] as Map<String, dynamic>,
      );
      if (skipped) runtimeSkipped.add('shamorZachor');
    }

    // Merge: sections missing in the backup file + sections skipped at runtime
    final allSkipped = [
      ...partialSections,
      ...runtimeSkipped.where((s) => !partialSections.contains(s)),
    ];
    return allSkipped;
  }

  /// Restore settings
  static Future<void> _restoreSettings(Map<String, dynamic> settings) async {
    for (final entry in settings.entries) {
      // keyDbEffectivePath הוא setting פנימי ל-Android בלבד.
      // אם backup נוצר ב-Android ומשוחזר על macOS/Windows — מדלגים,
      // כדי למנוע נתיב /data/user/0/... להחליף את ה-DB path הנכון.
      if (entry.key == SettingsRepository.keyDbEffectivePath &&
          !Platform.isAndroid) {
        continue;
      }
      await Settings.setValue(entry.key, entry.value);
    }
  }

  /// Restore bookmarks
  static Future<void> _restoreBookmarks(
    List<Map<String, dynamic>> bookmarksData,
  ) async {
    final repo = BookmarkRepository();
    final bookmarks =
        bookmarksData.map((data) => Bookmark.fromJson(data)).toList();
    await repo.saveBookmarks(bookmarks);
  }

  /// Restore history
  static Future<void> _restoreHistory(
    List<Map<String, dynamic>> historyData,
  ) async {
    final repo = HistoryRepository();
    final history = historyData.map((data) => Bookmark.fromJson(data)).toList();
    await repo.saveHistory(history);
  }

  /// Restore notes to SQLite database
  static Future<void> _restoreNotes(
    List<Map<String, dynamic>> notesData,
  ) async {
    final database = PersonalNotesDatabase.instance;

    for (final entry in notesData) {
      try {
        final bookId = (entry['bookId'] as String?)?.trim();
        if (bookId == null || bookId.isEmpty) {
          continue;
        }

        if (entry.containsKey('notes')) {
          final notesList = entry['notes'] as List<dynamic>;
          for (final noteData in notesList) {
            try {
              final note =
                  _noteFromBackupJson(noteData as Map<String, dynamic>);
              await database.insertNote(note);
            } catch (e) {
              _logger.warning('Failed to restore single note from backup: $e');
            }
          }
        }
      } catch (e) {
        _logger.warning('Failed to restore note entry: $e');
      }
    }
  }

  /// Convert backup JSON to PersonalNote
  static PersonalNote _noteFromBackupJson(Map<String, dynamic> json) {
    return PersonalNote(
      id: json['id'] as String,
      bookId: json['bookId'] as String,
      lineNumber: json['lineNumber'] as int?,
      displayTitle: json['displayTitle'] as String?,
      lastKnownLineNumber: json['lastKnownLineNumber'] as int?,
      status: PersonalNoteStatus.values.byName(json['status'] as String),
      content: json['content'] as String,
      contentPlain:
          (json['contentPlain'] as String?) ?? (json['content'] as String),
      contentFormat: PersonalNoteContentFormat.values.byName(
        json['contentFormat'] as String? ??
            PersonalNoteContentFormat.plain.name,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Restore user overrides to files
  static Future<void> _restoreUserOverrides(
      Map<String, dynamic> overridesData) async {
    final overridesDir = Directory(await AppPaths.getUserOverridesRootPath());

    for (final entry in overridesData.entries) {
      try {
        final relativePath = entry.key;
        final content = entry.value as String;

        final filePath = p.join(overridesDir.path, relativePath);
        final file = File(filePath);

        // Ensure parent directory exists
        await file.parent.create(recursive: true);

        // Only restore if file doesn't exist, to not overwrite user's latest edits,
        // or overwrite it if wanted. The standard restore overwrites.
        await file.writeAsString(content);
      } catch (e) {
        _logger.warning('Failed to restore override file ${entry.key}: $e');
      }
    }
  }

  /// Restore workspaces
  static Future<void> _restoreWorkspaces(
    List<Map<String, dynamic>> workspacesData,
    Object? currentWorkspace,
  ) async {
    final repo = WorkspaceRepository();
    final workspaces =
        workspacesData.map((data) => Workspace.fromJson(data)).toList();
    final currentId = _resolveCurrentWorkspaceId(
      workspaces: workspaces,
      currentWorkspace: currentWorkspace,
    );
    await repo.saveWorkspaces(workspaces, currentId);
  }

  static String? _resolveCurrentWorkspaceId({
    required List<Workspace> workspaces,
    required Object? currentWorkspace,
  }) {
    if (currentWorkspace is String &&
        workspaces.any((w) => w.id == currentWorkspace)) {
      return currentWorkspace;
    }

    if (currentWorkspace is int &&
        currentWorkspace >= 0 &&
        currentWorkspace < workspaces.length) {
      return workspaces[currentWorkspace].id;
    }

    return workspaces.isNotEmpty ? workspaces.first.id : null;
  }

  /// Restore Shamor Zachor data - restores ALL backed up keys.
  /// Returns true if the section was skipped (Hive box not open).
  static Future<bool> _restoreShamorZachor(
    Map<String, dynamic> shamorZachorData,
  ) async {
    if (!Hive.isBoxOpen(HiveCache.keyName)) {
      _logger.warning('_restoreShamorZachor: Hive box not open — skipping (partial restore)');
      return true;
    }
    final box = Hive.box<dynamic>(HiveCache.keyName);

    for (final entry in shamorZachorData.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value == null) continue;

      await box.put(key, value);
    }
    return false;
  }

  static const _kLastPartialAutoBackupKey = 'key-last-partial-auto-backup';
  static const _kPartialRetryMinutes = 60;

  /// Check if automatic backup is needed
  static Future<bool> shouldPerformAutoBackup() async {
    final frequency =
        Settings.getValue<String>('key-auto-backup-frequency') ?? 'none';
    if (frequency == 'none') return false;

    final lastBackup = Settings.getValue<String>('key-last-auto-backup');
    final now = DateTime.now();

    // Check normal schedule against the last successful full backup
    if (lastBackup != null) {
      final daysSince = now.difference(DateTime.parse(lastBackup)).inDays;
      final dueAfterDays = switch (frequency) {
        'weekly' => 7,
        'monthly' => 30,
        _ => null,
      };
      if (dueAfterDays == null) return false;
      if (daysSince < dueAfterDays) return false;
    }

    // Cooldown: if a partial attempt happened recently, don't flood the folder
    final lastPartial = Settings.getValue<String>(_kLastPartialAutoBackupKey);
    if (lastPartial != null) {
      final minutesSince =
          now.difference(DateTime.parse(lastPartial)).inMinutes;
      if (minutesSince < _kPartialRetryMinutes) return false;
    }

    return true;
  }

  /// Perform automatic backup
  static Future<void> performAutoBackup() async {
    final includeSettings =
        Settings.getValue<bool>('key-backup-settings') ?? true;
    final includeBookmarks =
        Settings.getValue<bool>('key-backup-bookmarks') ?? true;
    final includeHistory =
        Settings.getValue<bool>('key-backup-history') ?? true;
    final includeNotes = Settings.getValue<bool>('key-backup-notes') ?? true;
    final includeWorkspaces =
        Settings.getValue<bool>('key-backup-workspaces') ?? true;
    final includeShamorZachor =
        Settings.getValue<bool>('key-backup-shamor-zachor') ?? true;
    final includeUserOverrides =
        Settings.getValue<bool>('key-backup-user-overrides') ?? true;

    final result = await createBackup(
      includeSettings: includeSettings,
      includeBookmarks: includeBookmarks,
      includeHistory: includeHistory,
      includeNotes: includeNotes,
      includeWorkspaces: includeWorkspaces,
      includeShamorZachor: includeShamorZachor,
      includeUserOverrides: includeUserOverrides,
    );

    if (result.skippedSections.isNotEmpty) {
      _logger.warning('Auto-backup partial — skipped: ${result.skippedSections.join(", ")} — will retry after ${_kPartialRetryMinutes}min cooldown');
      await Settings.setValue(
          _kLastPartialAutoBackupKey, DateTime.now().toIso8601String());
      return;
    }

    await Settings.setValue(
        'key-last-auto-backup', DateTime.now().toIso8601String());
  }

  /// Get list of available backups
  static Future<List<FileSystemEntity>> getAvailableBackups() async {
    final backupDir = await getBackupDirectory();
    final dir = Directory(backupDir);
    if (!await dir.exists()) return [];

    final files = await dir.list().toList();
    return files.where((f) => f is File && f.path.endsWith('.json')).toList()
      ..sort((a, b) => b.path.compareTo(a.path)); // Sort by date (newest first)
  }
}
