import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:otzaria/models/support_organization.dart';

/// טוען ומשחרר את נתוני פופאפ "אוצריא מתגייסת" — הרשימה שב-assets והלוגואים.
///
/// הפרדת הנתונים מקוד התצוגה מאפשרת לעדכן מספרי טלפון, אפשרויות קו וכמות
/// נרשמים בלי לגעת בווידג'ט.
class SupportOrganizationsService {
  static const String assetPath = 'assets/support_organizations.json';

  /// הלוגו מוצג ב-50×50 אך חלק מקובצי המקור הם 3000px ומעלה. הפענוח והפינוי
  /// חייבים להשתמש באותו מפתח, ולכן שניהם עוברים דרך [logoImage].
  static const int _logoDecodeWidth = 200;

  static Future<SupportOrganizations>? _cached;

  static Future<SupportOrganizations> load() => _cached ??= _loadFromAsset();

  /// ספק התמונה של לוגו ארגון, מפוענח בגודל התצוגה.
  static ImageProvider logoImage(String assetName) =>
      ResizeImage(AssetImage(assetName), width: _logoDecodeWidth);

  /// משחרר את כל מה שהפופאפ טען. ImageCache הוא גלובלי ואינו מתנקה עם סגירת
  /// הדיאלוג, והפופאפ מוצג פעם אחת בריצה — אין טעם להחזיק את זה עד היציאה.
  static void release() {
    final pending = _cached;
    _cached = null;
    rootBundle.evict(assetPath);
    pending?.then(_evictLogos).ignore();
  }

  static void _evictLogos(SupportOrganizations organizations) {
    for (final org in [
      ...organizations.emergencyLines,
      ...organizations.supportOrgs,
    ]) {
      logoImage(org.logo).evict().ignore();
    }
  }

  static Future<SupportOrganizations> _loadFromAsset() async {
    final raw = await rootBundle.loadString(assetPath);
    return SupportOrganizations.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  @visibleForTesting
  static void resetCache() => _cached = null;
}
