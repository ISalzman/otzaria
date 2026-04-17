import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/settings/settings_exports.dart';

enum InstallMode { systemWide, perUser }

/// Utility class for managing application paths.
/// Centralizes path construction logic to avoid duplication.
class AppPaths {
  static String? _cachedDataRootPath;

  /// Returns the default writable root for user-scoped app data.
  static Future<String> getDataRootPath() async {
    if (_cachedDataRootPath != null && _cachedDataRootPath!.isNotEmpty) {
      return _cachedDataRootPath!;
    }

    final Directory rootDir;
    if (Platform.isAndroid || Platform.isIOS) {
      rootDir = await getApplicationDocumentsDirectory();
    } else {
      rootDir = await getApplicationSupportDirectory();
    }

    _cachedDataRootPath = rootDir.path;
    return _cachedDataRootPath!;
  }

  static String? get cachedDataRootPath => _cachedDataRootPath;

  /// Migrates legacy data roots and saved default paths to the current layout.
  static Future<void> migrateLegacyDataToUnifiedRoot() async {
    final newRoot = await getDataRootPath();
    final defaultLibraryPath = await getDefaultLibraryPath();
    final defaultIndexPath = await _getDefaultIndexPath();
    final defaultLockPath = p.join(p.dirname(defaultIndexPath), 'tantivy.lock');

    final legacyRoots = _legacyDataRootsForCurrentPlatform();
    for (final legacyRoot in legacyRoots) {
      await _migrateDirectoryIfNeeded(
        sourcePath: p.join(legacyRoot, 'books'),
        targetPath: defaultLibraryPath,
      );
      await _migrateDirectoryIfNeeded(
        sourcePath: p.join(legacyRoot, 'index'),
        targetPath: defaultIndexPath,
      );
      await _migrateDirectoryIfNeeded(
        sourcePath: p.join(legacyRoot, 'logs'),
        targetPath: p.join(newRoot, 'logs'),
      );
      await _migrateDirectoryIfNeeded(
        sourcePath: p.join(legacyRoot, 'tantivy.lock'),
        targetPath: defaultLockPath,
      );
    }

    final legacyBackupPaths = await _legacyBackupPaths();
    for (final legacyBackupPath in legacyBackupPaths) {
      await _migrateDirectoryIfNeeded(
        sourcePath: legacyBackupPath,
        targetPath: p.join(newRoot, 'backups'),
      );
    }

    await _migrateSettingPath(
      settingKey: SettingsRepository.keyLibraryPath,
      legacyPaths: legacyRoots.map((root) => p.join(root, 'books')).toList(),
      targetPath: defaultLibraryPath,
    );
    await _migrateSettingPath(
      settingKey: SettingsRepository.keyIndexPath,
      legacyPaths: legacyRoots.map((root) => p.join(root, 'index')).toList(),
      targetPath: defaultIndexPath,
    );
    await _migrateSettingPath(
      settingKey: SettingsRepository.keyBackupPath,
      legacyPaths: legacyBackupPaths,
      targetPath: p.join(newRoot, 'backups'),
    );
  }

  /// Detects whether the app is installed system-wide or per-user.
  static Future<InstallMode> detectInstallMode() async {
    if (Platform.isMacOS) {
      if (await Directory('/Library/Application Support/Otzaria').exists()) {
        return InstallMode.systemWide;
      }
    }
    if (Platform.isWindows) {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      if (File(p.join(exeDir, 'system_install.marker')).existsSync()) {
        return InstallMode.systemWide;
      }
    }
    if (Platform.isLinux) {
      if (await Directory('/var/lib/otzaria').exists()) {
        return InstallMode.systemWide;
      }
    }
    return InstallMode.perUser;
  }

  /// Default library path.
  ///
  /// On system-wide desktop installs this remains in the shared data root.
  /// Otherwise it lives under the user-scoped app data root.
  static Future<String> getDefaultLibraryPath() async {
    final systemWideRoot = await _getSystemWideLibraryRootIfNeeded();
    if (systemWideRoot != null) {
      return p.join(systemWideRoot, 'books');
    }

    return p.join(await getDataRootPath(), 'books');
  }

  static Future<String?> _getSystemWideLibraryRootIfNeeded() async {
    if (Platform.isAndroid || Platform.isIOS) {
      return null;
    }

    final mode = await detectInstallMode();
    if (mode != InstallMode.systemWide) {
      return null;
    }

    if (Platform.isWindows) {
      final pd = Platform.environment['ProgramData'] ?? r'C:\ProgramData';
      return p.join(pd, 'otzaria');
    }
    if (Platform.isMacOS) {
      return '/Library/Application Support/otzaria';
    }
    if (Platform.isLinux) {
      return '/var/lib/otzaria';
    }

    return null;
  }

  static Future<String> _getDefaultIndexPath() async {
    final systemWideRoot = await _getSystemWideLibraryRootIfNeeded();
    if (systemWideRoot != null) {
      return p.join(systemWideRoot, 'index');
    }

    return p.join(await getDataRootPath(), 'index');
  }

  static List<String> _legacyDataRootsForCurrentPlatform() {
    final roots = <String>{};

    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        roots.add(p.join(appData, 'otzaria'));
      }

      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData != null && localAppData.isNotEmpty) {
        roots.add(p.join(localAppData, 'otzaria'));
      }

      final programData = Platform.environment['ProgramData'];
      if (programData != null && programData.isNotEmpty) {
        roots.add(p.join(programData, 'otzaria'));
      }
    }

    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        roots.add(p.join(home, 'Library', 'Application Support', 'otzaria'));
      }
      roots.add('/Library/Application Support/otzaria');
    }

    if (Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        roots.add(p.join(home, '.local', 'share', 'otzaria'));
      }
      roots.add('/var/lib/otzaria');
    }

    if (Platform.isAndroid || Platform.isIOS) {
      final documentsPath = _cachedDataRootPath;
      if (documentsPath != null && documentsPath.isNotEmpty) {
        roots.add(p.join(documentsPath, 'otzaria'));
      }
    }

    return roots.toList();
  }

  static Future<List<String>> _legacyBackupPaths() async {
    final backupPaths = <String>{};
    final docs = await getApplicationDocumentsDirectory();

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      backupPaths.add(p.join(docs.path, 'OtzariaBackups'));
    } else {
      backupPaths.add(p.join(docs.path, 'otzaria', 'backups'));
    }

    return backupPaths.toList();
  }

  static Future<void> _migrateSettingPath({
    required String settingKey,
    required List<String> legacyPaths,
    required String targetPath,
  }) async {
    final savedPath = Settings.getValue<String>(settingKey);
    if (savedPath == null || savedPath.isEmpty) {
      return;
    }

    final normalizedSavedPath = p.normalize(savedPath);
    final normalizedTargetPath = p.normalize(targetPath);
    if (normalizedSavedPath == normalizedTargetPath) {
      return;
    }

    final matchesLegacyPath = legacyPaths
        .map(p.normalize)
        .any((legacyPath) => legacyPath == normalizedSavedPath);
    if (!matchesLegacyPath) {
      return;
    }

    if (!await Directory(targetPath).exists()) {
      return;
    }

    await Settings.setValue(settingKey, targetPath);
  }

  static Future<void> _migrateDirectoryIfNeeded({
    required String sourcePath,
    required String targetPath,
  }) async {
    try {
      final normalizedSourcePath = p.normalize(sourcePath);
      final normalizedTargetPath = p.normalize(targetPath);
      if (normalizedSourcePath == normalizedTargetPath) {
        return;
      }

      final sourceDir = Directory(sourcePath);
      if (!await sourceDir.exists()) {
        return;
      }

      final targetDir = Directory(targetPath);
      if (await targetDir.exists()) {
        return;
      }

      await targetDir.parent.create(recursive: true);

      try {
        await sourceDir.rename(targetPath);
        return;
      } catch (_) {}

      await _copyDirectory(sourceDir, targetDir);

      try {
        await sourceDir.delete(recursive: true);
      } catch (_) {}
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'Failed to migrate legacy directory from $sourcePath to $targetPath: $error\n$stackTrace',
        );
      }
    }
  }

  static Future<void> _copyDirectory(
    Directory sourceDir,
    Directory targetDir,
  ) async {
    await targetDir.create(recursive: true);

    await for (final entity in sourceDir.list(recursive: false, followLinks: false)) {
      final name = p.basename(entity.path);
      final targetPath = p.join(targetDir.path, name);

      if (entity is Directory) {
        await _copyDirectory(entity, Directory(targetPath));
        continue;
      }

      if (entity is File) {
        await File(targetPath).parent.create(recursive: true);
        await entity.copy(targetPath);
      }
    }
  }

  /// Gets the main library path from settings, or gracefully falls back to default paths.
  static Future<String> getLibraryPath() async {
    // Check existing library path setting
    final currentPath =
        Settings.getValue<String>(SettingsRepository.keyLibraryPath);

    if (currentPath != null && currentPath.isNotEmpty) {
      return currentPath;
    }

    // Determine default path based on platform
    String libraryPath = await getDefaultLibraryPath();

    await Settings.setValue(SettingsRepository.keyLibraryPath, libraryPath);
    return libraryPath;
  }

  /// Gets the search index path.
  ///
  /// On system-wide desktop installs this remains next to the shared library.
  static Future<String> getIndexPath() async {
    // Check if there is a separate index path assigned
    final savedIndex =
        Settings.getValue<String>(SettingsRepository.keyIndexPath);
    if (savedIndex != null && savedIndex.isNotEmpty) return savedIndex;

    return _getDefaultIndexPath();
  }

  /// Returns the backup path inside the writable app data root.
  static Future<String> getDefaultBackupPath() async {
    return p.join(await getDataRootPath(), 'backups');
  }

  /// Gets backup path from settings.
  static Future<String> getBackupPath() async {
    final saved = Settings.getValue<String>(SettingsRepository.keyBackupPath);
    if (saved != null && saved.isNotEmpty) return saved;
    return getDefaultBackupPath();
  }

  /// Gets the shared directory used for Tantivy lock/state files.
  /// It is kept next to the active index directory.
  static Future<String> getTantivyLockPath() async {
    final indexPath = await getIndexPath();
    final lockDir = Directory(p.join(p.dirname(indexPath), 'tantivy.lock'));
    if (!await lockDir.exists()) {
      await lockDir.create(recursive: true);
    }
    return lockDir.path;
  }

  /// Gets the previous per-user location of the Tantivy lock/state files.
  /// Used only for migration to the shared `tantivy.lock` directory.
  static Future<String> getLegacyIndexStatePath() async {
    final support = await getApplicationSupportDirectory();
    return p.join(support.path, 'index_state');
  }

  /// Gets the manifest file path (library_path/files_manifest.json)
  static Future<String> getManifestPath() async {
    final libraryPath = await getLibraryPath();
    return p.join(libraryPath, 'files_manifest.json');
  }

  /// Resolves the notes database path - for cross-platform compatibility.
  /// Also migrates the DB from the old sqflite location the first time it runs on mobile.
  static Future<String> resolveNotesDbPath(String fileName) async {
    final dbDir = Directory(p.join(await getDataRootPath(), 'databases'));
    if (!await dbDir.exists()) await dbDir.create(recursive: true);
    final newPath = p.join(dbDir.path, fileName);

    // Migrate from old sqflite location on mobile (one-time, idempotent)
    if (!File(newPath).existsSync()) {
      await _migrateNotesDbIfExists(fileName, newPath);
    }

    return newPath;
  }

  /// Copies the old sqflite database file to [newPath] if it exists at the
  /// platform-specific sqflite default location.
  static Future<void> _migrateNotesDbIfExists(
      String fileName, String newPath) async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      // sqflite stored the DB differently per platform:
      //   Android: {app}/databases/ (sibling of the 'files' dir)
      //   iOS:     Library/ (parent of Application Support)
      final oldDir = Platform.isAndroid
          ? p.join(supportDir.parent.path, 'databases')
          : supportDir.parent.path;
      final oldFile = File(p.join(oldDir, fileName));
      if (await oldFile.exists()) {
        await oldFile.copy(newPath);
      }
    } catch (_) {
      // Migration is best-effort; failure should not prevent the app from starting.
    }
  }

  /// Creates startup directories when eagerly required.
  static Future<void> createNecessaryDirectories() async {
    // Directories are created lazily by the services that actually use them.
  }

  /// Gets the root path for all plugin data.
  static Future<String> getPluginsRootPath() async {
    return p.join(await getDataRootPath(), 'plugins');
  }

  /// Gets the root path for user overrides.
  static Future<String> getUserOverridesRootPath() async {
    return p.join(await getDataRootPath(), 'user_overrides');
  }

  /// Gets the root path for per-book settings files.
  static Future<String> getPerBookSettingsPath() async {
    return p.join(await getDataRootPath(), 'per_book_settings');
  }

  /// Gets the path where downloaded/extracted plugins are installed.
  static Future<String> getInstalledPluginsPath() async {
    final root = await getPluginsRootPath();
    return p.join(root, 'installed');
  }

  /// Gets the path for a specific plugin installation.
  static Future<String> getPluginInstallPath(String pluginId) async {
    final installed = await getInstalledPluginsPath();
    return p.join(installed, pluginId, 'current');
  }

  /// Gets the generic data path for a specific plugin.
  static Future<String> getPluginDataPath(String pluginId) async {
    final root = await getPluginsRootPath();
    return p.join(root, 'data', pluginId);
  }

  /// Gets the cache path for a specific plugin.
  static Future<String> getPluginCachePath(String pluginId) async {
    final root = await getPluginsRootPath();
    return p.join(root, 'cache', pluginId);
  }

  /// Resolves the plugin system database path.
  static Future<String> resolvePluginsDbPath() async {
    return resolveNotesDbPath('plugins_host.db');
  }
}
