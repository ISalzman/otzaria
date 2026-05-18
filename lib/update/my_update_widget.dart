import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:updat/updat.dart';
import 'package:updat/updat_window_manager.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import 'hebrew_update_widgets.dart';
import 'linux_installer.dart';
import 'package:otzaria/settings/settings_exports.dart';

/// סוג ההתקנה המוגדר בזמן build (אופציונלי)
/// להגדרה: --dart-define=INSTALL_KIND=exe/zip
const _kInstallKind =
    String.fromEnvironment('INSTALL_KIND', defaultValue: 'auto');

const _githubOwner = 'Otzaria';
const _githubRepository = 'otzaria';
const _changelogAssetPath = 'assets/יומן שינויים.md';

/// מטמון של תוצאות GitHub API. המפתח כולל גם את הערוץ (stable/dev) כדי למנוע
/// דליפה בין ערוצים אם המשתמש מחליף הגדרה באותו סשן, וגם כדי שלא יחזרו
/// תוצאות ישנות כאשר שני release-ים בערוץ dev חולקים אותה core version
/// (כגון `0.9.92+628` ו-`0.9.92+629`).
@visibleForTesting
final Map<String, Map<String, dynamic>> releaseCacheForTesting = {};

bool _isDevChannelEnabled() =>
    Settings.getValue<bool>('key-dev-channel') ?? false;

String _cacheKey(String version, {bool? isDev}) {
  final dev = isDev ?? _isDevChannelEnabled();
  return '${dev ? 'dev' : 'stable'}:$version';
}

/// מאחסן release ב-cache עבור גרסה נתונה. נקרא מ-`getLatestVersion` כדי
/// להבטיח ש-`getChangelog`/`getBinaryUrl` מקבלים בדיוק את ה-release שזוהה
/// כ"החדש ביותר", ולא נבחר מחדש לפי prefix.
void _cacheRelease(String version, Map<String, dynamic> release,
    {bool? isDev}) {
  releaseCacheForTesting[_cacheKey(version, isDev: isDev)] = release;
}

/// בוחר את ה-release ה-pre-release האחרון ברשימה שמתאים לערוץ dev:
/// pre-release אמיתי, לא draft, ולא PR preview (tag שלא מכיל `-pr`).
/// אם אין התאמה — נופל ל-release הראשון ברשימה (כדי להתאים להתנהגות הקודמת).
/// מקבלת `List<dynamic>` ישירות מ-`jsonDecode` ולא מסתמכת על הסקה גנרית
/// של `firstWhere` שמשתנה לפי הטיפוס בזמן ריצה.
@visibleForTesting
Map<String, dynamic> pickLatestDevRelease(List<dynamic> releases) {
  for (final r in releases) {
    if (r is Map &&
        r["prerelease"] == true &&
        r["draft"] == false &&
        !r["tag_name"].toString().contains('-pr')) {
      return r.cast<String, dynamic>();
    }
  }
  return (releases.first as Map).cast<String, dynamic>();
}

/// שולפת את מידע ה-release מ-GitHub עבור גרסה נתונה ושומרת אותו במטמון.
/// אם `getLatestVersion` כבר הקדים לאחסן את ה-release המדויק שזוהה, נחזיר
/// אותו ישירות — כך מובטח עקביות בין ה-release שזוהה כ"חדש" לבין
/// ה-changelog וקובץ ההתקנה.
Future<Map<String, dynamic>> _fetchRelease(String version) async {
  final cached = releaseCacheForTesting[_cacheKey(version)];
  if (cached != null) return cached;

  final isDev = _isDevChannelEnabled();
  Map<String, dynamic> release;

  if (isDev) {
    final data = await http.get(Uri.parse(
      "https://api.github.com/repos/$_githubOwner/$_githubRepository/releases",
    ));
    final releases = jsonDecode(data.body) as List;
    final byPrefix = releases
        .where((r) => r["tag_name"].toString().startsWith(version))
        .toList();
    final pool = byPrefix.isNotEmpty ? byPrefix : releases;
    release = pickLatestDevRelease(pool);
  } else {
    var resp = await http.get(Uri.parse(
      "https://api.github.com/repos/$_githubOwner/$_githubRepository/releases/tags/$version",
    ));
    if (resp.statusCode == 404) {
      resp = await http.get(Uri.parse(
        "https://api.github.com/repos/$_githubOwner/$_githubRepository/releases/tags/v$version",
      ));
    }
    if (resp.statusCode >= 400) {
      throw Exception(
          'Release "$version" not found (status ${resp.statusCode})');
    }
    release = (jsonDecode(resp.body) as Map).cast<String, dynamic>();
  }

  _cacheRelease(version, release, isDev: isDev);
  return release;
}

/// בונה URL לקובץ raw בריפו, צמוד לתג הספציפי של ה-release.
/// שימוש ב-`pathSegments` מבטיח קידוד נכון של תווים מיוחדים כמו `+` שבתגים
/// בערוץ dev (לדוגמה `0.9.92+628`) ושל תווי יוניקוד בנתיב.
@visibleForTesting
Uri rawAssetUrlForTag(String tagName, String relativePath) {
  final segments = <String>[
    _githubOwner,
    _githubRepository,
    'refs',
    'tags',
    tagName,
    ...relativePath.split('/'),
  ];
  return Uri(
    scheme: 'https',
    host: 'raw.githubusercontent.com',
    pathSegments: segments,
  );
}

final _changelogHeadingPattern = RegExp(
  r'^\s*(?:(?:#{1,6}|[*-])\s*)?\*{0,2}v?(\d+(?:\.\d+){1,2}(?:[-+][^\s*]+)?)\*{0,2}\s*$',
);

class _ParsedVersion implements Comparable<_ParsedVersion> {
  final int major;
  final int minor;
  final int patch;

  const _ParsedVersion(this.major, this.minor, this.patch);

  @override
  int compareTo(_ParsedVersion other) {
    final majorCompare = major.compareTo(other.major);
    if (majorCompare != 0) return majorCompare;

    final minorCompare = minor.compareTo(other.minor);
    if (minorCompare != 0) return minorCompare;

    return patch.compareTo(other.patch);
  }

  bool operator >(_ParsedVersion other) => compareTo(other) > 0;

  bool operator <=(_ParsedVersion other) => compareTo(other) <= 0;

  @override
  String toString() => '$major.$minor.$patch';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ParsedVersion &&
          runtimeType == other.runtimeType &&
          major == other.major &&
          minor == other.minor &&
          patch == other.patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);
}

/// זיהוי סוג ההתקנה ב-Windows
/// אם הוגדר INSTALL_KIND בזמן build - משתמש בו
/// אחרת - מזהה לפי נתיב הקובץ
String _preferredWindowsFormat() {
  if (!Platform.isWindows) return 'unknown';

  // אם הוגדר סוג התקנה בזמן build - משתמש בו
  if (_kInstallKind != 'auto') return _kInstallKind; // 'exe' | 'zip'

  try {
    // זיהוי אוטומטי לפי נתיב הקובץ
    final executablePath = Platform.resolvedExecutable.toLowerCase();

    if (executablePath.contains('\\program files\\') ||
        executablePath.contains('\\program files (x86)\\')) {
      return 'exe'; // התקנה תקנית
    }

    return 'zip'; // גרסה ניידת/ידנית
  } catch (e) {
    // במקרה של שגיאה, ברירת מחדל היא EXE
    return 'exe';
  }
}

String _normalizeVersion(String version) {
  var normalized = version.trim();
  if (normalized.startsWith('v')) {
    normalized = normalized.substring(1);
  }

  final plusIndex = normalized.indexOf('+');
  if (plusIndex != -1) {
    normalized = normalized.substring(0, plusIndex);
  }

  return normalized;
}

_ParsedVersion? _tryParseVersion(String version) {
  final core = _normalizeVersion(version).split('-').first;
  final parts = core.split('.');
  if (parts.length < 2 || parts.length > 3) return null;

  final major = int.tryParse(parts[0]);
  final minor = int.tryParse(parts[1]);
  final patch = parts.length == 3 ? int.tryParse(parts[2]) : 0;
  if (major == null || minor == null || patch == null) return null;

  return _ParsedVersion(major, minor, patch);
}

/// מחזירה את פריטי יומן השינויים שבין הגרסה הנוכחית לגרסה הזמינה.
@visibleForTesting
String changelogBetweenVersionsForUpdateDialog({
  required String changelog,
  required String currentVersion,
  required String latestVersion,
}) {
  final current = _tryParseVersion(currentVersion);
  final latest = _tryParseVersion(latestVersion);
  if (current == null || latest == null || latest <= current) {
    return changelog;
  }

  final lines = changelog.split('\n');
  final selected = <String>[];
  var includeCurrentSection = false;
  var sawVersionHeading = false;

  for (final line in lines) {
    final match = _changelogHeadingPattern.firstMatch(line);
    if (match != null) {
      sawVersionHeading = true;
      final headingVersion = _tryParseVersion(match.group(1)!);
      includeCurrentSection = headingVersion != null &&
          headingVersion > current &&
          headingVersion <= latest;

      if (includeCurrentSection) {
        if (selected.isNotEmpty && selected.last.trim().isNotEmpty) {
          selected.add('');
        }
        selected.add(line);
      }
      continue;
    }

    if (!sawVersionHeading) {
      continue;
    }

    if (includeCurrentSection) {
      selected.add(line);
    }
  }

  final result = selected.join('\n').trim();
  if (result.isEmpty) {
    return 'לא נמצאו פריטי יומן שינויים בין גרסה $currentVersion לגרסה $latestVersion.';
  }
  return result;
}

/// עוטף את [hebrewFlatChip] ומבטל אוטומטית שגיאות עדכון לאחר השהיה קצרה.
Widget _hebrewFlatChipAutoHideError({
  required BuildContext context,
  required String? latestVersion,
  required String appVersion,
  required UpdatStatus status,
  required void Function() checkForUpdate,
  required void Function() openDialog,
  required void Function() startUpdate,
  required Future<void> Function() launchInstaller,
  required void Function() dismissUpdate,
}) {
  if (status == UpdatStatus.error) {
    Future.delayed(const Duration(seconds: 3), dismissUpdate);
  }

  // Wrap launchInstaller for Linux
  final wrappedLaunchInstaller = wrapLinuxInstaller(launchInstaller, 'otzaria');

  return hebrewFlatChip(
    context: context,
    latestVersion: latestVersion,
    appVersion: appVersion,
    status: status,
    checkForUpdate: checkForUpdate,
    openDialog: openDialog,
    startUpdate: startUpdate,
    launchInstaller: wrappedLaunchInstaller,
    dismissUpdate: dismissUpdate,
  );
}

class MyUpdatWidget extends StatelessWidget {
  const MyUpdatWidget({super.key, required this.child});

  final Widget child;
  @override
  Widget build(BuildContext context) {
    // Don't show update widget in debug mode or offline mode
    final isOfflineMode =
        Settings.getValue<bool>(SettingsRepository.keyOfflineMode) ?? false;
    final softwareAndBookUpdatesEnabled = Settings.getValue<bool>(
          SettingsRepository.keySoftwareAndBookUpdatesEnabled,
          defaultValue: true,
        ) ??
        true;
    if (kDebugMode || isOfflineMode || !softwareAndBookUpdatesEnabled) {
      return child;
    }

    return FutureBuilder(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return child;
          }
          return UpdatWindowManager(
            getLatestVersion: () async {
              // ניקוי המטמון מבדיקת עדכון קודמת — אנו רוצים נתונים טריים
              // עבור ה-flow הנוכחי (ובכך גם להבטיח שלא יוחזר release מיושן
              // אם פורסם release חדש מאז הבדיקה הקודמת).
              releaseCacheForTesting.clear();

              final isDevChannel = _isDevChannelEnabled();

              if (isDevChannel) {
                // For dev channel, get the latest pre-release from the main repo
                final data = await http.get(Uri.parse(
                  "https://api.github.com/repos/$_githubOwner/$_githubRepository/releases",
                ));
                final releases = jsonDecode(data.body) as List;
                final preRelease = pickLatestDevRelease(releases);
                final normalized =
                    _normalizeVersion(preRelease["tag_name"] as String);
                // אחסון ה-release המדויק שזוהה — כדי ש-getChangelog ו-
                // getBinaryUrl לא יבחרו מחדש לפי prefix ויתפסו release אחר.
                _cacheRelease(normalized, preRelease, isDev: true);
                return normalized;
              } else {
                // For stable channel, get the latest stable release
                final data = await http.get(Uri.parse(
                  "https://api.github.com/repos/$_githubOwner/$_githubRepository/releases/latest",
                ));
                final release =
                    (jsonDecode(data.body) as Map).cast<String, dynamic>();
                final normalized =
                    _normalizeVersion(release["tag_name"] as String);
                _cacheRelease(normalized, release, isDev: false);
                return normalized;
              }
            },
            getBinaryUrl: (version) async {
              final release = await _fetchRelease(version ?? '');
              final assets =
                  (release["assets"] as List).cast<Map<String, dynamic>>();
              final platform = Platform.operatingSystem.toLowerCase();

              String? assetUrl;

              // פונקציה לבחירת קובץ Windows לפי סדר עדיפות
              // חשוב: לא לבחור קובץ -full.exe כי הוא מכיל את הספרייה המלאה
              // ומיועד רק למשתמשים חדשים, לא לעדכונים
              // allowZipFallback: האם לאפשר נפילה ל-ZIP אם לא נמצא התאמה
              String? pickWindows(List<String> extsInOrder,
                  {bool allowZipFallback = true}) {
                String? foundZip;
                for (final a in assets) {
                  final name = (a["name"] as String).toLowerCase();
                  final url = a["browser_download_url"] as String;
                  final isWin = name.contains('win') ||
                      name.contains('windows') ||
                      name.endsWith('.exe');
                  if (!isWin) continue;

                  // דלג על קובץ full - מיועד להתקנה ראשונית בלבד
                  if (name.contains('-full.exe') ||
                      name.contains('_full.exe')) {
                    continue;
                  }

                  for (final ext in extsInOrder) {
                    if (name.endsWith(ext)) return url;
                  }
                  // רק אם מותר fallback ל-ZIP
                  if (allowZipFallback &&
                      name.endsWith('.zip') &&
                      foundZip == null) {
                    foundZip = url;
                  }
                }
                return foundZip;
              }

              if (platform == 'windows') {
                // בחירת סדר עדיפות לפי סוג ההתקנה
                final pref = _preferredWindowsFormat();
                final order = switch (pref) {
                  'zip' => ['.zip', '.exe'],
                  _ => ['.exe', '.zip'],
                };
                assetUrl = pickWindows(order, allowZipFallback: true);
              } else if (platform == 'macos') {
                // macOS - חיפוש קובץ zip
                for (final a in assets) {
                  final n = (a["name"] as String).toLowerCase();
                  if ((n.contains('macos') ||
                          n.contains('darwin') ||
                          n.contains('mac')) &&
                      n.endsWith('.zip')) {
                    assetUrl = a["browser_download_url"] as String;
                    break;
                  }
                }
              } else if (platform == 'linux') {
                // Linux - עדיפות: DEB -> RPM -> ZIP
                for (final a in assets) {
                  final n = (a["name"] as String).toLowerCase();
                  final u = a["browser_download_url"] as String;
                  if (n.endsWith('.deb')) {
                    assetUrl = u;
                    break;
                  }
                }
                if (assetUrl == null) {
                  for (final a in assets) {
                    final n = (a["name"] as String).toLowerCase();
                    final u = a["browser_download_url"] as String;
                    if (n.endsWith('.rpm')) {
                      assetUrl = u;
                      break;
                    }
                  }
                }
                if (assetUrl == null) {
                  for (final a in assets) {
                    final n = (a["name"] as String).toLowerCase();
                    final u = a["browser_download_url"] as String;
                    if ((n.contains('linux') || n.contains('gnu')) &&
                        n.endsWith('.zip')) {
                      assetUrl = u;
                      break;
                    }
                  }
                }
              }

              if (assetUrl == null) {
                throw Exception('No suitable binary found for $platform');
              }
              return assetUrl;
            },
            appName: "otzaria", // This is used to name the downloaded files.
            getChangelog: (latestVersion, appVersion) async {
              // טעינת יומן השינויים מהתג של ה-release עצמו, כך שהיומן יוצמד
              // לקומיט שמכיל את כותרת הגרסה החדשה — ללא תלות בענף שממנו נבנתה.
              try {
                final release = await _fetchRelease(latestVersion);
                final tagName = release['tag_name'] as String;
                final url = rawAssetUrlForTag(tagName, _changelogAssetPath);
                final response =
                    await http.get(url).timeout(const Duration(seconds: 10));

                if (response.statusCode == 200) {
                  return changelogBetweenVersionsForUpdateDialog(
                    changelog: response.body,
                    currentVersion: appVersion,
                    latestVersion: latestVersion,
                  );
                } else {
                  return 'שגיאה בטעינת יומן השינויים.\nקוד שגיאה: ${response.statusCode}';
                }
              } catch (e) {
                return 'שגיאה בטעינת יומן השינויים: $e';
              }
            },
            currentVersion: snapshot.data!.version,
            updateChipBuilder: _hebrewFlatChipAutoHideError,
            updateDialogBuilder: hebrewDefaultDialog,

            callback: (status) {},
            child: child,
          );
        });
  }
}
