import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/settings/settings_exports.dart';

/// Utility class for managing application paths.
/// Centralizes path construction logic to avoid duplication.
class AppPaths {
  /// Gets the main library path from settings. Defaults to 'C:/אוצריא' for Windows if not set.
  static Future<String> getLibraryPath() async {
    // Check existing library path setting
    final currentPath = Settings.getValue(SettingsRepository.keyLibraryPath);

    if (currentPath != null) {
      return currentPath;
    }

    // Determine default path based on platform
    String libraryPath;
    if (Platform.isIOS) {
      libraryPath = (await getApplicationDocumentsDirectory()).path;
    } else if (Platform.isAndroid) {
      try {
        libraryPath = (await getExternalStorageDirectory())?.path ??
            (await getApplicationDocumentsDirectory()).path;
      } catch (_) {
        libraryPath = (await getApplicationDocumentsDirectory()).path;
      }
    } else if (Platform.isWindows) {
      libraryPath = 'C:/אוצריא';
    } else {
      // Linux, macOS: use application support directory for consistency
      libraryPath = (await getApplicationSupportDirectory()).path;
    }

    await Settings.setValue(SettingsRepository.keyLibraryPath, libraryPath);
    return libraryPath;
  }

  /// Gets the search index path (library_path/index)
  static Future<String> getIndexPath() async {
    final libraryPath = await getLibraryPath();
    return p.join(libraryPath, 'index');
  }

  /// Gets a dedicated path for indexing metadata/state files (Hive, etc.)
  /// Kept separate from Tantivy index files to avoid I/O contention.
  static Future<String> getIndexStatePath() async {
    final support = await getApplicationSupportDirectory();
    final stateDir = Directory(p.join(support.path, 'index_state'));
    if (!await stateDir.exists()) {
      await stateDir.create(recursive: true);
    }
    return stateDir.path;
  }

  /// Gets the manifest file path (library_path/files_manifest.json)
  static Future<String> getManifestPath() async {
    final libraryPath = await getLibraryPath();
    return p.join(libraryPath, 'files_manifest.json');
  }

  /// Resolves the notes database path - for cross-platform compatibility.
  /// Also migrates the DB from the old sqflite location the first time it runs on mobile.
  static Future<String> resolveNotesDbPath(String fileName) async {
    final Directory dbDir;
    if (Platform.isAndroid || Platform.isIOS) {
      final appDir = await getApplicationDocumentsDirectory();
      dbDir = Directory(p.join(appDir.path, 'databases'));
    } else {
      final support = await getApplicationSupportDirectory();
      dbDir = Directory(p.join(support.path, 'databases'));
    }
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

  /// Creates necessary directories for the application
  /// Note: Does NOT create the library path itself - only index directories
  /// The library path should be created by the user or during library download
  static Future<void> createNecessaryDirectories() async {
    // Index directory is created by TantivyDataProvider._initEngine().
    // No other directories need pre-creation at startup.
  }
}
