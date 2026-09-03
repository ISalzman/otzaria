import 'package:otzaria/data/repository/hive_list_repository.dart';

/// Base class for repositories that use HiveListRepository with common operations
abstract class BaseListRepository<T> {
  final HiveListRepository<T> _repo;

  BaseListRepository({
    required String boxName,
    required String key,
    required T Function(Map<String, dynamic>) fromJson,
    required Map<String, dynamic> Function(T) toJson,
  }) : _repo = HiveListRepository<T>(
         boxName: boxName,
         key: key,
         fromJson: fromJson,
         toJson: toJson,
       );

  Future<List<T>> load() async => _repo.load();

  /// נתיב הכתיבה. ראו [HiveListRepository.mutate] — [apply] חייב להיות טהור.
  Future<List<T>> mutate(List<T> Function(List<T> current) apply) async =>
      _repo.mutate(apply);

  /// דריסה מוחלטת, בלי מיזוג ובלי בדיקת גרסה. שחזור מגיבוי בלבד.
  Future<void> overwrite(List<T> items) async => _repo.overwrite(items);

  Future<void> clear() async => _repo.clear();
  Future<void> addItem(T item) async => _repo.addItem(item);
  Future<void> removeAt(int index) async => _repo.removeAt(index);

  /// אות שהרשימה שונתה בחלון אחר.
  Stream<void> get remoteChanges => _repo.remoteChanges;
}
