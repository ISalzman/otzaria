import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/core/app_paths.dart';

/// A cache access provider class for shared preferences using Hive library
class HiveCache extends CacheProvider {
  Box? _preferences;
  static const String keyName = 'app_preferences';

  @override
  Future<void> init() async {
    if (!kIsWeb) {
      final defaultDirectory = await AppPaths.getDataRootPath();
      _preferences = await Hive.openBox<dynamic>(
        keyName,
        path: defaultDirectory,
      );
    }
  }

  Set get keys => getKeys();

  @override
  bool? getBool(String key, {bool? defaultValue}) {
    return _preferences?.get(key, defaultValue: defaultValue) ?? defaultValue;
  }

  @override
  double? getDouble(String key, {double? defaultValue}) {
    return _preferences?.get(key, defaultValue: defaultValue) ?? defaultValue;
  }

  @override
  int? getInt(String key, {int? defaultValue}) {
    return _preferences?.get(key, defaultValue: defaultValue) ?? defaultValue;
  }

  @override
  String? getString(String key, {String? defaultValue}) {
    return _preferences?.get(key, defaultValue: defaultValue) ?? defaultValue;
  }

  @override
  Future<void> setBool(String key, bool? value) async {
    await _preferences?.put(key, value);
  }

  @override
  Future<void> setDouble(String key, double? value) async {
    await _preferences?.put(key, value);
  }

  @override
  Future<void> setInt(String key, int? value) async {
    await _preferences?.put(key, value);
  }

  @override
  Future<void> setString(String key, String? value) async {
    await _preferences?.put(key, value);
  }

  @override
  Future<void> setObject<T>(String key, T? value) async {
    await _preferences?.put(key, value);
  }

  @override
  bool containsKey(String key) {
    return _preferences?.containsKey(key) ?? false;
  }

  @override
  Set getKeys() {
    return _preferences?.keys.toSet() ?? {};
  }

  @override
  Future<void> remove(String key) async {
    if (containsKey(key)) {
      await _preferences?.delete(key);
    }
  }

  @override
  Future<void> removeAll() async {
    final keys = getKeys();
    await _preferences?.deleteAll(keys.cast<String>());
  }

  /// מחיקת כל ההגדרות, בהמתנה לסיומה.
  ///
  /// `Settings.clearCache` של החבילה הוא `void` ואינו ממתין ל-Future של
  /// המחיקה: איפוס דרכו מתחיל בנייה מחדש בזמן שהמחיקה עוד רצה, וברירות
  /// המחדל שנכתבות מיד אחריו נמחקות איתה.
  static Future<void> clearAllPreferences() async {
    if (!Hive.isBoxOpen(keyName)) return;
    await Hive.box<dynamic>(keyName).clear();
  }

  @override
  T? getValue<T>(String key, {T? defaultValue}) {
    var value = _preferences?.get(key);
    if (value is T) {
      return value;
    }
    return defaultValue;
  }
}
