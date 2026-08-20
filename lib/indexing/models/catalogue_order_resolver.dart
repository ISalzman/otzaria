import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// מוסר את הסדר הקטלוגי של ספר — המספר שנצרב לחצי העליון של מזהה המסמך
/// באינדקס (`IndexingRepository.buildCatalogueDocumentId`).
///
/// המנוע מגדיר את `id` כמזהה מסמך ייחודי, ולכן סדר משותף לשני ספרים אינו
/// רק מיון לא יציב: כתיבת האחד מוחקת את מסמכי האחר (מחיקה לפי `id`) והם
/// חולקים `sectionId`. ספר שאינו במפת הספרייה מקבל כאן סדר משלו בטווח
/// שמור שמעל כל הספרייה, נגזר מהמפתח בלבד.
class CatalogueOrderResolver {
  CatalogueOrderResolver(this._orderByKey)
    : _fallbackBase = _orderByKey.isEmpty
          ? _reservedFallbackBase
          : math.max(
              _reservedFallbackBase,
              _orderByKey.values.reduce(math.max) + 1,
            );

  /// הסדר הגבוה ביותר שניתן לצרוב: `buildCatalogueDocumentId` מוסיף 1 לפני
  /// ההזזה ב-32 סיביות, וערך גבוה יותר חורג מ-u64 ונחתך בגשר ל-Rust.
  static const int maxCatalogueOrder = 0xFFFFFFFE;

  /// תחילת הטווח השמור לספרים שאינם בספרייה — מעל כל גודל ספרייה אפשרי,
  /// כדי שהם ימוינו אחרונים בלי תלות בגודלה.
  static const int _reservedFallbackBase = 0x80000000;

  /// תקרת הדפסה: ספרייה שנטענה חלקית הייתה מציפה את תור ההדפסה של Flutter.
  static const int _maxLoggedFallbacks = 20;

  final Map<String, int> _orderByKey;
  final Map<String, int> _fallbackOrderByKey = {};
  final Set<int> _takenFallbackOrders = {};
  final int _fallbackBase;

  /// מפתחות הספרים שלא נמצאו בספרייה וקיבלו סדר חלופי.
  @visibleForTesting
  Iterable<String> get fallbackKeys => _fallbackOrderByKey.keys;

  /// הסדר של [key], או סדר חלופי ייחודי אם הספר אינו בספרייה.
  int orderFor(String key) {
    final known = _orderByKey[key];
    if (known != null) return known;
    return _fallbackOrderByKey.putIfAbsent(key, () => _allocateFallback(key));
  }

  /// הסדר החלופי נגזר מהמפתח בלבד ולא ממונה רץ, כדי שאותו ספר יקבל את אותו
  /// סדר בכל ריצה — אחרת ריצה אחרת הייתה מחלקת אותו לספר אחר.
  int _allocateFallback(String key) {
    final range = maxCatalogueOrder - _fallbackBase + 1;
    var order = _fallbackBase + stableFallbackHash(key) % range;
    for (var probe = 0; _takenFallbackOrders.contains(order); probe++) {
      if (probe >= range) {
        throw StateError(
          'אזל טווח הסדר הקטלוגי בעת הקצאת סדר לספר שאינו בספרייה: $key',
        );
      }
      order = _fallbackBase + (order - _fallbackBase + 1) % range;
    }
    _takenFallbackOrders.add(order);
    if (_fallbackOrderByKey.length < _maxLoggedFallbacks) {
      debugPrint('⚠️ ספר שאינו בקטלוג מקבל סדר חלופי ($order): $key');
    }
    return order;
  }

  /// FNV-1a על 32 סיביות. מימוש מפורש ולא `hashCode`, שאינו מובטח יציב בין
  /// ריצות — והסדר נצרב לאינדקס ולטביעת האצבע ולכן חייב לשרוד הפעלה מחדש.
  @visibleForTesting
  static int stableFallbackHash(String key) {
    var hash = 0x811C9DC5;
    for (final unit in key.codeUnits) {
      hash = ((hash ^ (unit & 0xFF)) * 0x01000193) & 0xFFFFFFFF;
      hash = ((hash ^ ((unit >> 8) & 0xFF)) * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }
}
