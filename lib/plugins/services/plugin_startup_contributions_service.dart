import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/models/plugin_startup_contributions.dart';
import 'package:otzaria/plugins/models/plugin_valid_permissions.dart';
import 'package:otzaria/plugins/repository/plugin_registry_repository.dart';
import 'package:otzaria/plugins/services/context_menu_registry.dart';
import 'package:otzaria/plugins/services/plugin_lazy_activation_service.dart';
import 'package:otzaria/plugins/services/plugin_toolbar_registry.dart';
import 'package:otzaria/plugins/storage/plugin_system_database.dart';

/// מפעיל את תרומות העלייה הדקלרטיביות של תוספים (`contributes.startup`)
/// בלי להרים מנוע JS: פרסינג המניפסט ב-Dart והזנת ה-registries הקיימים.
///
/// נקרא מ-PluginSystemBloc בכל LoadPlugins, כך שהענקה/שלילה של הרשאה,
/// השבתה, הסרה ועדכון מסונכרנים תמיד עם הרישומים בפועל.
class PluginStartupContributionsService {
  static final PluginStartupContributionsService instance =
      PluginStartupContributionsService._();
  PluginStartupContributionsService._()
    : _toolbar = PluginToolbarRegistry.instance,
      _contextMenu = ContextMenuRegistry.instance,
      _lazyActivation = PluginLazyActivationService.instance;

  @visibleForTesting
  PluginStartupContributionsService.forTesting({
    required PluginToolbarRegistry toolbarRegistry,
    required ContextMenuRegistry contextMenuRegistry,
    required PluginLazyActivationService activationService,
  }) : _toolbar = toolbarRegistry,
       _contextMenu = contextMenuRegistry,
       _lazyActivation = activationService;

  final PluginToolbarRegistry _toolbar;
  final ContextMenuRegistry _contextMenu;
  final PluginLazyActivationService _lazyActivation;

  /// קידומת המפתח של רשומות publishedData שנזרעו מהמניפסט — מבדילה אותן
  /// מרשומות שהתוסף כותב בזמן ריצה, ומאפשרת ניקוי גם אחרי עדכון גרסה.
  static const String seededKeyPrefix = 'manifest:';

  /// מה הוחל בפועל — לצורך הסרה נקייה (בלי לגעת ברישומים דינמיים של
  /// התוסף) ולצורך reapply אחרי reload של תוסף פיתוח.
  final Map<String, List<Map<String, dynamic>>> _appliedToolbar = {};
  final Map<String, List<Map<String, dynamic>>> _appliedContextMenu = {};

  /// תוספים שסונכרנו עם תרומות פעילות בסשן הנוכחי — מאפשר לדלג על ניקוי DB
  /// עבור שאר התוספים (הרוב), שלא נזרע להם דבר.
  final Set<String> _managedPlugins = {};

  /// מסנכרן את כל התרומות מול רשימת התוספים הנוכחית. לעולם אינו זורק —
  /// תוסף עם סעיף פגום נרשם ללוג וממשיכים הלאה.
  Future<void> sync(
    List<InstalledPlugin> plugins,
    PluginRegistryRepository repository,
  ) async {
    try {
      await _syncInternal(plugins, repository);
    } catch (e, stackTrace) {
      debugPrint(
        'PluginStartupContributionsService: sync failed: '
        '$e\n$stackTrace',
      );
    }
  }

  Future<void> _syncInternal(
    List<InstalledPlugin> plugins,
    PluginRegistryRepository repository,
  ) async {
    final seenIds = <String>{};
    for (final plugin in plugins) {
      seenIds.add(plugin.pluginId);
      final startup = plugin.manifest.startup;
      if (startup == null || startup.isEmpty || !plugin.enabled) {
        // ניקוי DB רק אם יש למה — סעיף startup במניפסט או מצב מהסשן הנוכחי.
        if (startup != null || _managedPlugins.contains(plugin.pluginId)) {
          await _removePlugin(plugin.pluginId, repository);
        }
        continue;
      }
      final grants = await repository.getPluginPermissions(plugin.pluginId);
      final granted = grants
          .where((g) => g.granted)
          .map((g) => g.permission)
          .toSet();
      if (!granted.contains(pluginStartupContributionsPermission)) {
        await _removePlugin(plugin.pluginId, repository);
        continue;
      }
      _managedPlugins.add(plugin.pluginId);

      if (startup.toolbarItems.isNotEmpty &&
          granted.contains('reader.toolbar')) {
        _applyItems(
          plugin.pluginId,
          startup.toolbarItems,
          applied: _appliedToolbar,
          register: (id, item) => _toolbar.registerPayload(id, item),
          removeItem: _toolbar.remove,
        );
      } else {
        _removeApplied(plugin.pluginId, _appliedToolbar, _toolbar.remove);
      }

      if (startup.contextMenuItems.isNotEmpty &&
          granted.contains('reader.context_menu')) {
        _applyItems(
          plugin.pluginId,
          startup.contextMenuItems,
          applied: _appliedContextMenu,
          register: (id, item) => _contextMenu.registerPayload(id, item),
          removeItem: _contextMenu.remove,
        );
      } else {
        _removeApplied(
          plugin.pluginId,
          _appliedContextMenu,
          _contextMenu.remove,
        );
      }

      if (startup.publishedData.isNotEmpty &&
          granted.contains('published_data.write')) {
        await _seedPublishedData(
          plugin.pluginId,
          startup.publishedData,
          repository,
        );
      } else {
        await _removeSeededData(plugin.pluginId, repository);
      }

      // כל הדלקת מנוע שלא דרך כניסה לדף התוסף (לחיצה, אירוע, app.startup)
      // דורשת את ההרשאה הרגישה הכבויה כברירת מחדל. בלעדיה הרישומים עדיין
      // חלים, ולחיצה נופלת לפתיחת דף התוסף (ראו PluginRuntimeDispatcher).
      if (!granted.contains(pluginRunOnStartupPermission)) {
        _lazyActivation.removePlugin(plugin.pluginId);
        continue;
      }
      final broadcastTopics = <String>{};
      var scheduleStartup = false;
      for (final topic in startup.activationEvents) {
        if (topic == PluginStartupContributions.startupActivationTopic) {
          scheduleStartup = true;
          continue;
        }
        // נושא שהוגדרה לו הרשאת subscribe מכובד רק אם ההרשאה הוענקה.
        final permission = 'events.subscribe:$topic';
        if (!pluginValidPermissions.contains(permission) ||
            granted.contains(permission)) {
          broadcastTopics.add(topic);
        }
      }
      _lazyActivation.syncPlugin(
        plugin.pluginId,
        broadcastTopics: broadcastTopics,
        scheduleStartup: scheduleStartup,
      );
    }

    final knownIds = <String>{..._managedPlugins};
    for (final pluginId in knownIds) {
      if (!seenIds.contains(pluginId)) {
        await _removePlugin(pluginId, repository);
      }
    }
  }

  /// רושם מחדש את הרישומים הדקלרטיביים של תוסף — אחרי ש-reloadPlugin ניקה
  /// את ה-registries (טעינה מחדש של תוסף פיתוח בלי שינוי מניפסט).
  void reapply(String pluginId) {
    for (final item in _appliedToolbar[pluginId] ?? const []) {
      _tryRegister(pluginId, item, (id, i) => _toolbar.registerPayload(id, i));
    }
    for (final item in _appliedContextMenu[pluginId] ?? const []) {
      _tryRegister(
        pluginId,
        item,
        (id, i) => _contextMenu.registerPayload(id, i),
      );
    }
  }

  void _applyItems(
    String pluginId,
    List<Map<String, dynamic>> items, {
    required Map<String, List<Map<String, dynamic>>> applied,
    required void Function(String pluginId, Map<String, dynamic> item) register,
    required void Function(String pluginId, String itemId) removeItem,
  }) {
    // הסרת פריטי הסבב הקודם שאינם במניפסט הנוכחי — לפני הרישום, אחרת
    // החלפה מלאה של שני פריטים במזהים חדשים נדחית על מכסת שני הפריטים.
    final declaredIds = items.map((item) => item['id']).toSet();
    for (final previous
        in applied[pluginId] ?? const <Map<String, dynamic>>[]) {
      final id = previous['id'];
      if (id is String && !declaredIds.contains(id)) removeItem(pluginId, id);
    }
    final registered = <Map<String, dynamic>>[];
    for (final item in items) {
      if (_tryRegister(pluginId, item, register)) registered.add(item);
    }
    if (registered.isEmpty) {
      applied.remove(pluginId);
    } else {
      applied[pluginId] = registered;
    }
  }

  bool _tryRegister(
    String pluginId,
    Map<String, dynamic> item,
    void Function(String pluginId, Map<String, dynamic> item) register,
  ) {
    try {
      register(pluginId, item);
      return true;
    } catch (e) {
      PluginSystemDatabase.instance.writeLog(
        pluginId,
        'ERROR',
        'startup contribution rejected: $e',
      );
      return false;
    }
  }

  void _removeApplied(
    String pluginId,
    Map<String, List<Map<String, dynamic>>> applied,
    void Function(String pluginId, String itemId) removeItem,
  ) {
    final items = applied.remove(pluginId);
    if (items == null) return;
    for (final item in items) {
      final id = item['id'];
      if (id is String) removeItem(pluginId, id);
    }
  }

  Future<void> _seedPublishedData(
    String pluginId,
    List<Map<String, dynamic>> records,
    PluginRegistryRepository repository,
  ) async {
    // LoadPlugins רץ על כל פעולה (הצמדה, סדר...) — כותבים רק רשומות שהשתנו
    // בפועל, כדי לא לשחוק את ה-DB ולא לאפס updated_at לחינם.
    final existing = await repository.getPluginPublishedRecords(pluginId);
    final existingPayloads = {
      for (final record in existing)
        '${record.type}|${record.scope}|${record.key}': record.payloadJson,
    };
    final currentIds = <String>{};
    for (final record in records) {
      final type = record['type'];
      final key = record['key'];
      final payload = record['payload'];
      if (type is! String || key is! String || payload == null) {
        PluginSystemDatabase.instance.writeLog(
          pluginId,
          'ERROR',
          'startup publishedData record requires type, key and payload',
        );
        continue;
      }
      final scope = record['scope'] as String? ?? 'global';
      final prefixedKey = '$seededKeyPrefix$key';
      final id = '$type|$scope|$prefixedKey';
      currentIds.add(id);
      final payloadJson = jsonEncode(payload);
      if (existingPayloads[id] == payloadJson) continue;
      await repository.publishRecord(
        pluginId,
        type,
        scope,
        prefixedKey,
        payloadJson,
        null,
      );
    }
    for (final record in existing) {
      if (!record.key.startsWith(seededKeyPrefix)) continue;
      final id = '${record.type}|${record.scope}|${record.key}';
      if (currentIds.contains(id)) continue;
      await repository.unpublishRecord(
        pluginId,
        record.type,
        record.scope,
        record.key,
      );
    }
  }

  Future<void> _removeSeededData(
    String pluginId,
    PluginRegistryRepository repository,
  ) async {
    await _removeStaleSeededRecords(pluginId, repository, keep: const {});
  }

  /// מוחק רשומות זרועות-מניפסט (לפי הקידומת) שאינן בסט הנוכחי — מכסה גם
  /// שאריות מגרסה קודמת של התוסף, כי הזיהוי הוא במסד ולא בזיכרון.
  Future<void> _removeStaleSeededRecords(
    String pluginId,
    PluginRegistryRepository repository, {
    required Set<String> keep,
  }) async {
    final existing = await repository.getPluginPublishedRecords(pluginId);
    for (final record in existing) {
      if (!record.key.startsWith(seededKeyPrefix)) continue;
      final id = '${record.type}|${record.scope}|${record.key}';
      if (keep.contains(id)) continue;
      await repository.unpublishRecord(
        pluginId,
        record.type,
        record.scope,
        record.key,
      );
    }
  }

  Future<void> _removePlugin(
    String pluginId,
    PluginRegistryRepository repository,
  ) async {
    _managedPlugins.remove(pluginId);
    _removeApplied(pluginId, _appliedToolbar, _toolbar.remove);
    _removeApplied(pluginId, _appliedContextMenu, _contextMenu.remove);
    _lazyActivation.removePlugin(pluginId);
    await _removeSeededData(pluginId, repository);
  }
}
