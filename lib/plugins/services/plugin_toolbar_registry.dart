import 'package:flutter/foundation.dart';
import 'package:otzaria/plugins/models/plugin_toolbar_item.dart';

/// סוגי פקד שילדיהם הם פריטי תפריט.
const _typesWithChildren = {'menu', 'split'};

/// רישום פקדי שורת הפקדים שתוספים הוסיפו (reader.addToolbarItem).
class PluginToolbarRegistry extends ChangeNotifier {
  static const int maxTopLevelItemsPerPlugin = 2;
  static const int maxMenuChildren = 20;

  static final PluginToolbarRegistry instance = PluginToolbarRegistry._();
  PluginToolbarRegistry._();

  @visibleForTesting
  PluginToolbarRegistry.forTesting();

  /// מופע מנותק לפרסינג-יבש בוולידציה (אריזה/התקנה) — לא נוגע ב-UI.
  PluginToolbarRegistry.detached();

  final Map<String, List<PluginToolbarItem>> _items = {};

  void register(String pluginId, PluginToolbarItem item) {
    final list = _items.putIfAbsent(pluginId, () => []);
    final index = list.indexWhere((existing) => existing.id == item.id);
    if (index >= 0) {
      list[index] = item;
    } else {
      if (list.length >= maxTopLevelItemsPerPlugin) {
        throw const PluginToolbarException(
          'error.invalid_params',
          'a plugin can register at most 2 toolbar items',
        );
      }
      list.add(item);
    }
    notifyListeners();
  }

  PluginToolbarItem registerPayload(
    String pluginId,
    Map<String, dynamic> payload,
  ) {
    final item = _parseItem(payload, isChild: false);
    register(pluginId, item);
    return item;
  }

  PluginToolbarItem update(
    String pluginId,
    String itemId,
    Map<String, dynamic> patch,
  ) {
    final list = _items[pluginId];
    final index = list?.indexWhere((item) => item.id == itemId) ?? -1;
    if (list == null || index < 0) {
      throw const PluginToolbarException(
        'error.not_found',
        'toolbar item was not found',
      );
    }
    final merged = {...list[index].toJson(), ...patch, 'id': itemId};
    final updated = _parseItem(merged, isChild: false);
    list[index] = updated;
    notifyListeners();
    return updated;
  }

  void remove(String pluginId, String itemId) {
    final list = _items[pluginId];
    final previousLength = list?.length ?? 0;
    list?.removeWhere((item) => item.id == itemId);
    if (list?.isEmpty == true) _items.remove(pluginId);
    if ((list?.length ?? 0) != previousLength) notifyListeners();
  }

  void removeAll(String pluginId) {
    if (_items.remove(pluginId) != null) notifyListeners();
  }

  /// מחליף קבוצת פריטים מנוהלת בעדכון יחיד, בלי לגעת בפריטים אחרים.
  void replaceManagedItems(
    String pluginId, {
    required Set<String> managedIds,
    required List<PluginToolbarItem> items,
  }) {
    if (items.any((item) => !managedIds.contains(item.id)) ||
        items.map((item) => item.id).toSet().length != items.length) {
      throw const PluginToolbarException(
        'error.invalid_params',
        'managed toolbar items must have unique declared ids',
      );
    }
    final next = [
      for (final item in _items[pluginId] ?? const <PluginToolbarItem>[])
        if (!managedIds.contains(item.id)) item,
      ...items,
    ];
    if (next.length > maxTopLevelItemsPerPlugin ||
        next.map((item) => item.id).toSet().length != next.length) {
      throw const PluginToolbarException(
        'error.invalid_params',
        'a plugin can register at most 2 unique toolbar items',
      );
    }
    if (next.isEmpty) {
      _items.remove(pluginId);
    } else {
      _items[pluginId] = next;
    }
    notifyListeners();
  }

  List<(String pluginId, PluginToolbarItem item)> getAll() {
    return List.unmodifiable([
      for (final entry in _items.entries)
        for (final item in entry.value) (entry.key, item),
    ]);
  }

  PluginToolbarItem _parseItem(
    Map<String, dynamic> json, {
    required bool isChild,
    List<String>? inheritedContexts,
  }) {
    final id = _safeText(json['id'], field: 'id', maxLength: 128);
    final type = json['type'] as String? ?? 'button';
    final allowedTypes = isChild
        ? const {'button'}
        : const {'button', 'menu', 'split'};
    if (!allowedTypes.contains(type)) {
      throw const PluginToolbarException(
        'error.invalid_params',
        'unsupported toolbar item type',
      );
    }
    final title = _safeText(json['title'], field: 'title', maxLength: 100);
    final contextsValue = json['contexts'];
    if (contextsValue != null &&
        (contextsValue is! List ||
            contextsValue.any((value) => value is! String))) {
      throw const PluginToolbarException(
        'error.invalid_params',
        'contexts must be an array of strings',
      );
    }
    final contexts = contextsValue == null
        ? inheritedContexts ?? const ['reader-text', 'reader-pdf']
        : List<String>.from(contextsValue as List);
    const supportedContexts = {'reader-text', 'reader-pdf'};
    if (contexts.isEmpty ||
        contexts.toSet().length != contexts.length ||
        (contextsValue != null &&
            inheritedContexts != null &&
            contexts.any((context) => !inheritedContexts.contains(context))) ||
        contexts.any((context) => !supportedContexts.contains(context))) {
      throw const PluginToolbarException(
        'error.unsupported_context',
        'contexts must be unique, supported, and within the parent contexts',
      );
    }

    final icon = _optionalSafeText(json['icon'], maxLength: 100);
    if (!isChild && (icon == null || icon.isEmpty)) {
      throw const PluginToolbarException(
        'error.invalid_params',
        'a toolbar item requires an icon',
      );
    }

    final children = <PluginToolbarItem>[];
    final childrenValue = json['children'];
    if (childrenValue != null) {
      if (!_typesWithChildren.contains(type)) {
        throw const PluginToolbarException(
          'error.invalid_params',
          'only menu or split items may declare children',
        );
      }
      if (childrenValue is! List || childrenValue.length > maxMenuChildren) {
        throw const PluginToolbarException(
          'error.invalid_params',
          'children must contain at most 20 items',
        );
      }
      for (final child in childrenValue) {
        if (child is! Map) {
          throw const PluginToolbarException(
            'error.invalid_params',
            'child must be an object',
          );
        }
        children.add(
          _parseItem(
            Map<String, dynamic>.from(child),
            isChild: true,
            inheritedContexts: contexts,
          ),
        );
      }
    }
    if (_typesWithChildren.contains(type) && children.isEmpty) {
      throw PluginToolbarException(
        'error.invalid_params',
        '$type requires children',
      );
    }
    if (children.map((child) => child.id).toSet().length != children.length) {
      throw const PluginToolbarException(
        'error.invalid_params',
        'children ids must be unique',
      );
    }

    return PluginToolbarItem(
      id: id,
      type: type,
      title: title,
      icon: icon,
      contexts: contexts,
      onClickEvent: _optionalEventName(json['onClickEvent']),
      children: children,
      openPlugin: json['openPlugin'] == true,
      param: json['param'],
    );
  }

  String _safeText(
    Object? value, {
    required String field,
    required int maxLength,
  }) {
    final text = _optionalSafeText(value, maxLength: maxLength);
    if (text == null || text.isEmpty) {
      throw PluginToolbarException(
        'error.invalid_params',
        '$field is required',
      );
    }
    return text;
  }

  String? _optionalSafeText(Object? value, {required int maxLength}) {
    if (value == null) return null;
    if (value is! String ||
        value.length > maxLength ||
        RegExp(r'[\u0000-\u001F\u007F]').hasMatch(value)) {
      throw const PluginToolbarException(
        'error.invalid_params',
        'text field has an invalid type or content',
      );
    }
    return value;
  }

  String? _optionalEventName(Object? value) {
    final event = _optionalSafeText(value, maxLength: 128);
    if (event != null && !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(event)) {
      throw const PluginToolbarException(
        'error.invalid_params',
        'event name contains unsupported characters',
      );
    }
    return event;
  }
}
