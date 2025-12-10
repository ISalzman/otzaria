import 'dart:convert';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';

/// Utility class for managing Tzurat Hadaf configuration settings
class TzuratHadafSettingsManager {
  /// Load configuration for a specific book
  static Map<String, String?>? loadConfiguration(String bookTitle) {
    final settingsKey = 'tzurat_hadaf_config_$bookTitle';
    final configString = Settings.getValue<String>(settingsKey);

    if (configString != null) {
      try {
        final config = json.decode(configString) as Map<String, dynamic>;
        return {
          'left': config['left'] as String?,
          'right': config['right'] as String?,
          'bottom': config['bottom'] as String?,
          'bottomRight': config['bottomRight'] as String?,
        };
      } catch (e) {
        // Return null if JSON is malformed
        return null;
      }
    }
    return null;
  }

  /// Save configuration for a specific book
  static void saveConfiguration(
    String bookTitle,
    Map<String, String?> config,
  ) {
    final settingsKey = 'tzurat_hadaf_config_$bookTitle';
    final configString = json.encode(config);
    Settings.setValue<String>(settingsKey, configString);
  }

  /// Get settings key for a book
  static String getSettingsKey(String bookTitle) {
    return 'tzurat_hadaf_config_$bookTitle';
  }
}
