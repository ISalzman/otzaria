# מצב מוגן (Protected Mode)

## תיאור
מצב מוגן מאפשר להגן על ההגדרות של האפליקציה באמצעות סיסמה. כאשר המצב מופעל, המשתמש יידרש להזין סיסמה לפני כניסה למסך ההגדרות.

## קבצים רלוונטיים

### מודלים ו-Repository
- `settings_repository.dart` - מכיל את הלוגיקה לשמירה ואימות סיסמה (hash)
- `settings_event.dart` - מכיל את האירועים `UpdateProtectedModeEnabled` ו-`UpdateProtectedModePassword`
- `settings_state.dart` - מכיל את השדה `protectedModeEnabled`
- `settings_bloc.dart` - מטפל באירועים של מצב מוגן

### UI Components
- `password_verification_dialog.dart` - דיאלוגים לאימות והגדרת סיסמה
  - `PasswordVerificationDialog` - לאימות סיסמה קיימת
  - `SetPasswordDialog` - להגדרת סיסמה חדשה
- `protected_mode_settings.dart` - Widget להגדרות מצב מוגן (מופיע בטאב המתקדם)
- `protected_settings_wrapper.dart` - Wrapper שבודק סיסמה לפני כניסה למסך ההגדרות

### Integration
- `settings_screen.dart` - עטוף ב-`ProtectedSettingsWrapper`
- `tabs/advanced_settings_tab.dart` - מכיל את `ProtectedModeSettings`

## איך זה עובד

1. **הגדרת סיסמה**: המשתמש נכנס להגדרות > מתקדם > מצב מוגן ולוחץ על "הגדר סיסמה"
2. **הפעלת המצב**: לאחר הגדרת הסיסמה, המשתמש יכול להפעיל את המצב המוגן
3. **הגנה**: כאשר המצב מופעל, כל כניסה למסך ההגדרות תדרוש אימות סיסמה
4. **אבטחה**: הסיסמה נשמרת כ-SHA256 hash, לא בטקסט פשוט

## שימוש בקוד

### בדיקה האם מצב מוגן פעיל
```dart
final repository = context.read<SettingsRepository>();
final state = context.read<SettingsBloc>().state;

if (state.protectedModeEnabled && repository.hasProtectedModePassword()) {
  // מצב מוגן פעיל
}
```

### אימות סיסמה לפעולה מסוימת
```dart
final verified = await verifyPasswordForAction(context);
if (verified) {
  // בצע פעולה מוגנת
}
```

## הרחבות עתידיות אפשריות

1. הוספת הגנה על פעולות נוספות (לא רק הגדרות)
2. תמיכה בביומטריה (טביעת אצבע, זיהוי פנים)
3. נעילה אוטומטית אחרי זמן מסוים
4. היסטוריית ניסיונות כניסה כושלים
5. שאלות אבטחה לשחזור סיסמה
