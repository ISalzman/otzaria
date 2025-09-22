import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';

/// Utility class for managing application paths.
/// Centralizes path construction logic to avoid duplication.
class AppPaths {
  /// Gets the main library path from settings. Defaults to 'C:/אוצריא' for Windows if not set.
  static Future<String> getLibraryPath() async {
    // Check existing library path setting
    String? libraryPath = Settings.getValue('key-library-path');

    if (Platform.isIOS || Platform.isAndroid) {
      if (libraryPath == null) {
        // Mobile platforms use the app's documents directory
        libraryPath = (await getApplicationDocumentsDirectory()).path;
        await Settings.setValue('key-library-path', libraryPath);
      }
    } else {
      // Desktop platforms default to current directory or specified path
      if (libraryPath == null) {
        if (Platform.isWindows) {
          libraryPath = 'C:/אוצריא';
          await Settings.setValue('key-library-path', libraryPath);
        } else {
          // Linux, macOS: use working directory
          libraryPath = '.';
        }
      }
    }

    return libraryPath;
  }

  /// Gets the search index path (library_path/index)
  static Future<String> getIndexPath() async {
    return p.join(await getLibraryPath(), 'index');
  }

  /// Gets the reference index path (library_path/ref_index)
  static Future<String> getRefIndexPath() async {
    return p.join(await getLibraryPath(), 'ref_index');
  }

  /// Gets the manifest file path (library_path/files_manifest.json)
  static Future<String> getManifestPath() async {
    return p.join(await getLibraryPath(), 'files_manifest.json');
  }

  /// Resolves the notes database path - for cross-platform compatibility
  static Future<String> resolveNotesDbPath(String fileName) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Windows, Linux, macOS: this will go into application support directory
      final support = await getApplicationSupportDirectory();
      final dbDir = Directory(p.join(support.path, 'databases'));
      if (!await dbDir.exists()) await dbDir.create(recursive: true);
      return p.join(dbDir.path, fileName);
    } else {
      // Mobile: the standard path for sqflite
      final dbs = await getDatabasesPath();
      final dbDir = Directory(dbs);
      if (!await dbDir.exists()) await dbDir.create(recursive: true);
      return p.join(dbs, fileName);
    }
  }

  /// Creates necessary directories for the application
  static Future<void> createNecessaryDirectories() async {
    final dirs = [
      await getLibraryPath(),
      await getIndexPath(),
      await getRefIndexPath(),
    ];

    for (final dirPath in dirs) {
      final directory = Directory(dirPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    }
  }
}
