import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:otzaria/models/support_organization.dart';

/// טוען את רשימת הארגונים של פופאפ "אוצריא מתגייסת" מקובץ נתונים ב-assets.
///
/// הקובץ נטען פעם אחת לכל ריצה. הפרדת הנתונים מקוד התצוגה מאפשרת לעדכן
/// מספרי טלפון, אפשרויות קו וכמות נרשמים בלי לגעת בווידג'ט.
class SupportOrganizationsService {
  static const String assetPath = 'assets/support_organizations.json';

  static Future<SupportOrganizations>? _cached;

  static Future<SupportOrganizations> load() => _cached ??= _loadFromAsset();

  static Future<SupportOrganizations> _loadFromAsset() async {
    final raw = await rootBundle.loadString(assetPath);
    return SupportOrganizations.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  @visibleForTesting
  static void resetCache() => _cached = null;
}
