import 'package:hive/hive.dart';

/// Generic repository for managing lists of objects in Hive.
/// T must have `fromJson(Map<String, dynamic>)` and `toJson()` methods.
class HiveListRepository<T> {
  final String boxName;
  final String key;
  final T Function(Map<String, dynamic>) fromJson;
  final Map<String, dynamic> Function(T) toJson;

  HiveListRepository({
    required this.boxName,
    required this.key,
    required this.fromJson,
    required this.toJson,
  });

  Box<dynamic> get _box => Hive.box(name: boxName);

  /// Load the list from Hive
  Future<List<T>> load() async {
    try {
      final List<dynamic> raw =
          _box.get(key, defaultValue: []) as List<dynamic>;
      return raw.map((e) => fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      _box.put(key, []);
      return [];
    }
  }

  /// Save the list to Hive
  Future<void> save(List<T> items) async {
    _box.put(key, items.map(toJson).toList());
  }

  /// Clear the list
  Future<void> clear() async {
    _box.put(key, []);
  }

  /// Add an item at the beginning of the list
  Future<void> addItem(T item) async {
    final list = await load();
    list.insert(0, item);
    await save(list);
  }

  /// Remove item at index
  Future<void> removeAt(int index) async {
    final list = await load();
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      await save(list);
    }
  }
}
