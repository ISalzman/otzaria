import 'package:flutter/foundation.dart';
import 'package:otzaria/core/windowing/shared_list_store.dart';
import 'package:otzaria/utils/file/hive_utils.dart';

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

  /// ⚠️ הגישה עוברת דרך [SharedListStore] ולא ישירות ל-`Hive.box`.
  ///
  /// היסטוריה, סימניות, שולחנות עבודה והערות אמורים להיות משותפים לכל
  /// החלונות, אבל `hive_ce` נועל את קובצי ה-`.lock` בלעדית ולכן כל חלון
  /// פותח קבצים משלו. ה-store מנתב את המאגרים האלה לחלון הראשון, שהוא
  /// היחיד שפתח את הקבצים שבשורש הנתונים האמיתי. כל שאר ה-boxes נשארים
  /// מקומיים ועוברים דרכו ללא שינוי.

  /// Load the list from Hive
  Future<List<T>> load() async {
    try {
      final raw = await SharedListStore.instance.read(boxName, key);
      return raw.map((e) => fromJson(castMap(e))).toList();
    } catch (e) {
      debugPrint('⚠️ HiveListRepository.load($boxName/$key) failed: $e');
      // Do NOT overwrite persisted data — return empty so the UI is functional
      // but the raw data on disk stays intact for the next attempt / fix.
      return [];
    }
  }

  /// Save the list to Hive
  Future<void> save(List<T> items) async {
    await SharedListStore.instance.write(
      boxName,
      key,
      items.map(toJson).toList(),
    );
  }

  /// Clear the list
  Future<void> clear() async {
    await SharedListStore.instance.write(boxName, key, const []);
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
