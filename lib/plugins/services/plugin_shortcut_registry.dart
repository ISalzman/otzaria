import 'package:flutter/foundation.dart';
import 'package:otzaria/plugins/models/plugin_shortcut.dart';

/// רישום קיצורי המקלדת שתוספים מצהירים עליהם — מהמניפסט
/// (`contributes.startup.shortcuts`) או בזמן ריצה (`app.registerShortcut`).
///
/// כל קיצור חייב לקשר לפחות לאחת משתי הפעולות: [PluginShortcut.command]
/// (פקודה חופשית שנשלחת באירוע `app.command`) או
/// [PluginShortcut.contextMenuItemId] (פעולת תפריט הלחיצה הימנית).
///
/// הרשמה ל-ChangeNotifier מאפשרת למסך הגדרות קיצורי המקשים ולמטפל המקלדת
/// להישאר מעודכנים כשקיצור נוסף/מוסר/מתעדכן בזמן ריצה.
class PluginShortcutRegistry extends ChangeNotifier {
  static final PluginShortcutRegistry instance = PluginShortcutRegistry._();
  PluginShortcutRegistry._();

  @visibleForTesting
  PluginShortcutRegistry.forTesting();

  final Map<String, Map<String, PluginShortcut>> _byPlugin = {};

  /// רושם קיצור [shortcut] עבור [pluginId]. קיצור קיים עם אותו [id] מוחלף.
  /// זורק [PluginShortcutException] אם לקיצור אין גם [command] וגם
  /// [contextMenuItemId] — קיצור כזה לא היה מפעיל דבר.
  void register(String pluginId, PluginShortcut shortcut) {
    _validate(pluginId, shortcut);
    (_byPlugin.putIfAbsent(pluginId, () => {}))[shortcut.id] = shortcut;
    notifyListeners();
  }

  /// רושם קיצור מ-payload גולמי (RPC / מניפסט). מחזיר את הקיצור המפוענח.
  PluginShortcut registerPayload(
    String pluginId,
    Map<String, dynamic> payload,
  ) {
    final shortcut = PluginShortcut.fromJson(payload);
    register(pluginId, shortcut);
    return shortcut;
  }

  /// מעדכן את [id] של קיצור לפי [patch] (נכון לעכשיו רק `key` נתמך).
  PluginShortcut update(
    String pluginId,
    String id,
    Map<String, dynamic> patch,
  ) {
    final current = _byPlugin[pluginId]?[id];
    if (current == null) {
      throw const PluginShortcutException(
        'error.not_found',
        'keyboard shortcut was not found',
      );
    }
    final key = patch['key'];
    final updated = current.copyWith(key: key is String ? key : current.key);
    _validate(pluginId, updated);
    _byPlugin[pluginId]![id] = updated;
    notifyListeners();
    return updated;
  }

  void remove(String pluginId, String id) {
    final list = _byPlugin[pluginId];
    final removed = list?.remove(id);
    if (list?.isEmpty == true) _byPlugin.remove(pluginId);
    if (removed != null) notifyListeners();
  }

  void removeAll(String pluginId) {
    if (_byPlugin.remove(pluginId) != null) notifyListeners();
  }

  List<(String pluginId, PluginShortcut shortcut)> getAll() {
    return List.unmodifiable([
      for (final entry in _byPlugin.entries)
        for (final shortcut in entry.value.values) (entry.key, shortcut),
    ]);
  }

  PluginShortcut? find(String pluginId, String id) => _byPlugin[pluginId]?[id];

  void _validate(String pluginId, PluginShortcut shortcut) {
    if (shortcut.id.isEmpty || shortcut.label.isEmpty) {
      throw const PluginShortcutException(
        'error.invalid_params',
        'shortcut requires id and label',
      );
    }
    if (shortcut.command == null && shortcut.contextMenuItemId == null) {
      throw const PluginShortcutException(
        'error.invalid_params',
        'shortcut requires command or contextMenuItemId',
      );
    }
  }
}

class PluginShortcutException implements Exception {
  final String code;
  final String message;

  const PluginShortcutException(this.code, this.message);

  @override
  String toString() => 'error.$code: $message';
}
