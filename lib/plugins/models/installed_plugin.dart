import 'dart:convert';
import 'package:otzaria/plugins/models/plugin_manifest.dart';

class InstalledPlugin {
  final String pluginId;
  final String name;
  final String version;
  final String installPath;
  final String entrypointPath;
  final String? iconPath;
  final bool enabled;
  final bool pinned;
  final bool pinnedToNavRail;

  /// האם התוסף מוסתר לחלוטין מהממשק (לשונית כלים + פאנל צד + nav rail).
  /// בניגוד ל-[enabled] שמשבית את הריצה, [hiddenFromTools] משאיר את התוסף
  /// פעיל אך לא מציג אותו למשתמש.
  final bool hiddenFromTools;

  /// האם המשתמש אישר בפועל לתוסף להופיע לפני כלים מובנים במסך "כלים".
  ///
  /// זהו מתג התקנה/עדכון שנשמר על ההתקנה עצמה. גם אם התוסף מבקש את היכולת
  /// במניפסט, המשתמש יכול לכבות אותה. אם המניפסט לא ביקש את היכולת, הערך
  /// הזה לבדו לא מספיק כדי להפעיל אותה.
  final bool allowOrderBeforeBuiltInsGranted;
  final PluginManifest manifest;
  final DateTime installedAt;
  final DateTime updatedAt;
  final String sourceType;
  final String? devRootPath;

  /// סדר מותאם אישית שנקבע ע"י המשתמש (גרירה ושחרור). `null` = להשתמש
  /// בסדר ברירת המחדל מתוך המניפסט ([PluginManifest.toolTabOrder]).
  ///
  /// הערכים נשמרים כאינדקסים פשוטים (0,1,2...) ומומרים בתצוגה לטווח
  /// גבוה שמונע התנגשות מספרית עם סדרי הכלים המובנים — ראו
  /// [effectiveToolTabOrder] ו-[userOrderToolTabOffset].
  final int? userOrder;

  /// בסיס הסדר עבור תוספים בעלי [userOrder]. ערך גבוה מספיק כדי שכל הכלים
  /// המובנים (`builtin.*`, סדרים 10-100) יישארו בטווח מספרי נפרד.
  static const int userOrderToolTabOffset = 1000;

  /// הסדר האפקטיבי שבו יוצג התוסף ברשימת הכלים. אם המשתמש קבע סדר ידני
  /// משתמשים בו (עם [userOrderToolTabOffset] כדי לשמור על טווח נפרד מהכלים
  /// המובנים); אחרת משתמשים בערך מהמניפסט.
  ///
  /// ההחלטה האם תוסף רשאי בכלל להופיע לפני כלים מובנים נקבעת בנפרד ע"י
  /// [PluginManifest.allowOrderBeforeBuiltIns] במסך "כלים".
  int get effectiveToolTabOrder => userOrder != null
      ? userOrderToolTabOffset + userOrder!
      : manifest.toolTabOrder;

  /// האם התוסף רשאי בפועל להקדים כלים מובנים במסך "כלים".
  bool get allowsOrderBeforeBuiltIns =>
      manifest.allowOrderBeforeBuiltIns && allowOrderBeforeBuiltInsGranted;

  bool get isDevelopment => sourceType == 'development';
  String get resolvedRootPath => isDevelopment ? devRootPath! : installPath;

  /// האם התוסף מצהיר על שימוש ברשת. תוסף כזה מוסתר מהממשק כאשר אוצריא נמצאת
  /// במצב 'מנותק' (`SettingsState.isOfflineMode`).
  bool get requiresNetwork => manifest.networkEnabled;

  InstalledPlugin({
    required this.pluginId,
    required this.name,
    required this.version,
    required this.installPath,
    required this.entrypointPath,
    this.iconPath,
    required this.enabled,
    required this.pinned,
    this.pinnedToNavRail = false,
    this.hiddenFromTools = false,
    bool? allowOrderBeforeBuiltInsGranted,
    required this.manifest,
    required this.installedAt,
    required this.updatedAt,
    this.sourceType = 'packaged',
    this.devRootPath,
    this.userOrder,
  }) : allowOrderBeforeBuiltInsGranted = allowOrderBeforeBuiltInsGranted ??
            manifest.allowOrderBeforeBuiltIns;

  factory InstalledPlugin.fromDbMap(Map<String, dynamic> map) {
    final manifest =
        PluginManifest.fromJson(jsonDecode(map['manifest_json'] as String));
    return InstalledPlugin(
      pluginId: map['plugin_id'] as String,
      name: map['name'] as String,
      version: map['version'] as String,
      installPath: map['install_path'] as String,
      entrypointPath: map['entrypoint_path'] as String,
      iconPath: map['icon_path'] as String?,
      enabled: (map['enabled'] as int) != 0,
      pinned: (map['pinned'] as int) != 0,
      pinnedToNavRail: ((map['pinned_to_nav_rail'] as int?) ?? 0) != 0,
      hiddenFromTools: ((map['hidden_from_tools'] as int?) ?? 0) != 0,
      allowOrderBeforeBuiltInsGranted:
          ((map['allow_order_before_built_ins_granted'] as int?) ??
                  (manifest.allowOrderBeforeBuiltIns ? 1 : 0)) !=
              0,
      manifest: manifest,
      installedAt: DateTime.parse(map['installed_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      sourceType: map['source_type'] as String? ?? 'packaged',
      devRootPath: map['dev_root_path'] as String?,
      userOrder: map['user_order'] as int?,
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'plugin_id': pluginId,
      'name': name,
      'version': version,
      'install_path': installPath,
      'entrypoint_path': entrypointPath,
      'icon_path': iconPath,
      'enabled': enabled ? 1 : 0,
      'pinned': pinned ? 1 : 0,
      'pinned_to_nav_rail': pinnedToNavRail ? 1 : 0,
      'hidden_from_tools': hiddenFromTools ? 1 : 0,
      'allow_order_before_built_ins_granted':
          allowOrderBeforeBuiltInsGranted ? 1 : 0,
      'manifest_json': jsonEncode(manifest.toJson()),
      'installed_at': installedAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'source_type': sourceType,
      'dev_root_path': devRootPath,
      'user_order': userOrder,
    };
  }

  InstalledPlugin copyWith({
    String? pluginId,
    String? name,
    String? version,
    String? installPath,
    String? entrypointPath,
    String? iconPath,
    bool? enabled,
    bool? pinned,
    bool? pinnedToNavRail,
    bool? hiddenFromTools,
    bool? allowOrderBeforeBuiltInsGranted,
    PluginManifest? manifest,
    DateTime? installedAt,
    DateTime? updatedAt,
    String? sourceType,
    String? devRootPath,
    bool clearDevRootPath = false,
    int? userOrder,
    bool clearUserOrder = false,
  }) {
    return InstalledPlugin(
      pluginId: pluginId ?? this.pluginId,
      name: name ?? this.name,
      version: version ?? this.version,
      installPath: installPath ?? this.installPath,
      entrypointPath: entrypointPath ?? this.entrypointPath,
      iconPath: iconPath ?? this.iconPath,
      enabled: enabled ?? this.enabled,
      pinned: pinned ?? this.pinned,
      pinnedToNavRail: pinnedToNavRail ?? this.pinnedToNavRail,
      hiddenFromTools: hiddenFromTools ?? this.hiddenFromTools,
      allowOrderBeforeBuiltInsGranted: allowOrderBeforeBuiltInsGranted ??
          this.allowOrderBeforeBuiltInsGranted,
      manifest: manifest ?? this.manifest,
      installedAt: installedAt ?? this.installedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sourceType: sourceType ?? this.sourceType,
      devRootPath: clearDevRootPath ? null : (devRootPath ?? this.devRootPath),
      userOrder: clearUserOrder ? null : (userOrder ?? this.userOrder),
    );
  }
}

/// סינון תוספים לפי מצב 'מנותק' של אוצריא — תוספים שדורשים אינטרנט מוסתרים
/// מהממשק כאשר המשתמש הפעיל את מצב 'מנותק'.
extension OfflineModePluginFilter on List<InstalledPlugin> {
  List<InstalledPlugin> filterForOfflineMode(bool isOfflineMode) {
    if (!isOfflineMode) return this;
    return where((p) => !p.requiresNetwork).toList();
  }
}
