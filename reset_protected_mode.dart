import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/data/data_providers/hive_data_provider.dart';

/// סקריפט חירום לאיפוס מצב מוגן
/// הרץ עם: dart run reset_protected_mode.dart
void main() async {
  // ignore: avoid_print
  print('מאפס מצב מוגן...');
  
  try {
    // אתחול Settings
    await Settings.init(cacheProvider: HiveCache());
    
    // מאפס את המצב המוגן והסיסמה
    await Settings.setValue(SettingsRepository.keyProtectedModeEnabled, false);
    await Settings.setValue(SettingsRepository.keyProtectedModePasswordHash, '');
    
    // ignore: avoid_print
    print('✓ המצב המוגן אופס בהצלחה!');
    // ignore: avoid_print
    print('עכשיו אפשר לפתוח את האפליקציה ולהגדיר סיסמה חדשה אם רוצים.');
  } catch (e) {
    // ignore: avoid_print
    print('✗ שגיאה באיפוס: $e');
  }
}
