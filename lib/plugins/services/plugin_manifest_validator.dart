import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:otzaria/plugins/models/plugin_manifest.dart';
import 'package:otzaria/plugins/models/plugin_valid_permissions.dart';

class PluginManifestValidator {
  static Future<void> validateManifest({
    required PluginManifest manifest,
    required String directoryPath,
    String? currentAppVersion,
    bool skipAppVersionValidation = false,
  }) async {
    if (manifest.schemaVersion != 1) {
      throw Exception(
          'גרסת סכמה ${manifest.schemaVersion} של התוסף אינה נתמכת');
    }

    if (!RegExp(r'^[a-z0-9_.-]+$').hasMatch(manifest.id)) {
      throw Exception('מזהה התוסף אינו תקין');
    }

    if (!RegExp(r'^\d+\.\d+\.\d+(?:\+.*)?$').hasMatch(manifest.version)) {
      throw Exception(
          'גרסת התוסף במניפסט אינה חוקית. נדרש פורמט SemVer חוקיות.');
    }

    int compareVersionsStrict(String v1, String v2) {
      final parts1 = v1.split('+')[0].split('.').map(int.parse).toList();
      final parts2 = v2.split('+')[0].split('.').map(int.parse).toList();
      for (var i = 0; i < 3; i++) {
        final p1 = i < parts1.length ? parts1[i] : 0;
        final p2 = i < parts2.length ? parts2[i] : 0;
        if (p1 > p2) return 1;
        if (p1 < p2) return -1;
      }
      return 0;
    }

    if (!skipAppVersionValidation) {
      if (currentAppVersion == null) {
        throw Exception(
            'currentAppVersion is required when skipAppVersionValidation is false');
      }
      if (compareVersionsStrict(currentAppVersion, manifest.minAppVersion) <
          0) {
        throw Exception(
            'התוסף דורש אוצריא בגרסה ${manifest.minAppVersion} לפחות, אך מותקנת $currentAppVersion');
      }
      if (manifest.maxAppVersion != null &&
          compareVersionsStrict(currentAppVersion, manifest.maxAppVersion!) >
              0) {
        throw Exception(
            'התוסף מיועד לאוצריא עד גרסה ${manifest.maxAppVersion} בלבד, אך מותקנת $currentAppVersion');
      }
    }

    for (final perm in manifest.permissions) {
      if (!pluginValidPermissions.contains(perm)) {
        final hint = apiCallToPermissionHint[perm];
        if (hint != null) {
          throw Exception('הרשאה לא חוקית: "$perm". האם התכוונת ל-"$hint"?');
        }
        throw Exception('הרשאה לא חוקית שנדרשת על ידי התוסף: $perm');
      }
    }

    if (manifest.toolTabIconVariant != null &&
        manifest.toolTabIconCodepoint == null) {
      throw Exception(
          'toolTab.iconVariant הוגדר ללא toolTab.iconCodepoint תואם');
    }

    if (manifest.toolTabIconCodepoint != null) {
      if (manifest.toolTabIconCodepoint! < 0) {
        throw Exception('toolTab.iconCodepoint חייב להיות מספר חיובי');
      }

      final variant = manifest.toolTabIconVariant;
      if (variant != null &&
          !PluginManifest.supportedToolTabIconVariants.contains(variant)) {
        throw Exception('toolTab.iconVariant חייב להיות regular או filled');
      }
    }

    final entrypointPath =
        p.normalize(p.join(directoryPath, manifest.entrypoint));
    if (!p.isWithin(directoryPath, entrypointPath)) {
      throw Exception(
          'נתיב קובץ הכניסה ${manifest.entrypoint} חורג מגבולות תיקיית התוסף');
    }
    if (!File(entrypointPath).existsSync()) {
      throw Exception('קובץ הכניסה ${manifest.entrypoint} לא נמצא בתיקייה');
    }
  }
}
