import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// מוסר את הסדר הקטלוגי של ספר — המספר שנצרב לחצי העליון של מזהה המסמך
/// באינדקס (`IndexingRepository.buildCatalogueDocumentId`).
///
/// המנוע מגדיר את `id` כמזהה מסמך ייחודי, ולכן סדר משותף לשני ספרים אינו
/// רק מיון לא יציב: כתיבת האחד מוחקת את מסמכי האחר (מחיקה לפי `id`) והם
/// חולקים `sectionId`. ספר שאינו במפת הספרייה מקבל כאן סדר משלו מיד אחרי
/// הספר האחרון שבה, ולא ערך משותף.
class CatalogueOrderResolver {
  CatalogueOrderResolver(this._orderByKey)
    : _nextFallbackOrder = _orderByKey.isEmpty
          ? 0
          : _orderByKey.values.reduce(math.max) + 1;

  /// הסדר הגבוה ביותר שניתן לצרוב: `buildCatalogueDocumentId` מוסיף 1 לפני
  /// ההזזה ב-32 סיביות, וערך גבוה יותר חורג מ-u64 ונחתך בגשר ל-Rust.
  static const int maxCatalogueOrder = 0xFFFFFFFE;

  final Map<String, int> _orderByKey;
  final Map<String, int> _fallbackOrderByKey = {};
  int _nextFallbackOrder;

  /// מפתחות הספרים שלא נמצאו בספרייה וקיבלו סדר חלופי.
  @visibleForTesting
  Iterable<String> get fallbackKeys => _fallbackOrderByKey.keys;

  /// הסדר של [key], או סדר חלופי ייחודי אם הספר אינו בספרייה.
  int orderFor(String key) {
    final known = _orderByKey[key];
    if (known != null) return known;
    return _fallbackOrderByKey.putIfAbsent(key, () => _allocateFallback(key));
  }

  int _allocateFallback(String key) {
    if (_nextFallbackOrder > maxCatalogueOrder) {
      throw StateError(
        'אזל טווח הסדר הקטלוגי בעת הקצאת סדר לספר שאינו בספרייה: $key',
      );
    }
    debugPrint(
      '⚠️ ספר שאינו בקטלוג מקבל סדר חלופי ($_nextFallbackOrder): $key',
    );
    return _nextFallbackOrder++;
  }
}
