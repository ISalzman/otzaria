/// Converts a Hive-returned [Map] (with dynamic keys) to `Map<String, dynamic>`.
///
/// הפונקציה פועלת רקורסיבית — גם מפות מקוננות ורשימות שמכילות
/// מפות מומרות, כך ש-fromJson יקבל תמיד את הטיפוסים הנכונים.
Map<String, dynamic> castMap(dynamic source) {
  if (source is Map) {
    return source.map<String, dynamic>(
      (key, value) => MapEntry(key.toString(), _castValue(value)),
    );
  }
  throw ArgumentError('Expected a Map, got ${source.runtimeType}');
}

dynamic _castValue(dynamic value) {
  if (value is Map) {
    return value.map<String, dynamic>(
      (key, val) => MapEntry(key.toString(), _castValue(val)),
    );
  }
  if (value is List) {
    return value.map(_castValue).toList();
  }
  return value;
}
