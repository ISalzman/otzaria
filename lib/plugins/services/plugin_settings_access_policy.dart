import 'package:otzaria/settings/engine/settings_repository.dart';

/// המקור היחיד לקביעה אילו הגדרות תוכנה תוסף רשאי לקרוא — משמש גם את
/// `settings.get` בגשר וגם את הערכת תנאי `when` ללא מנוע.
class PluginSettingsAccessPolicy {
  const PluginSettingsAccessPolicy._();

  /// מפתחות שתוסף רשאי לקרוא (plugin_system_plan.md#L954).
  static const Set<String> allowlist = {
    SettingsRepository.keyDarkMode,
    SettingsRepository.keyFollowSystemTheme,
    SettingsRepository.keySwatchColor,
    SettingsRepository.keyDarkSwatchColor,
    SettingsRepository.keyFontSize,
    SettingsRepository.keyFontFamily,
    SettingsRepository.keyCommentatorsFontFamily,
    SettingsRepository.keyCommentatorsFontSize,
    SettingsRepository.keyLineHeight,
    SettingsRepository.keySelectedCity,
    SettingsRepository.keyCalendarType,
    SettingsRepository.keySettingsLanguage,
    SettingsRepository.keyShowTeamim,
    SettingsRepository.keyDefaultNikud,
    SettingsRepository.keyRemoveNikudFromTanach,
    SettingsRepository.keyReplaceHolyNames,
    SettingsRepository.keyLibraryViewMode,
    SettingsRepository.keyCopyWithHeaders,
    SettingsRepository.keyCopyHeaderFormat,
    SettingsRepository.keyHebrewBooksPath,
  };

  /// מפתחות חסומים לקריאה גם אם הופיעו ב-[allowlist].
  static const Set<String> blocklist = {
    SettingsRepository.keyProtectedModePasswordHash,
    SettingsRepository.keyGoogleCalendarClientSecret,
    SettingsRepository.keyGoogleCalendarCredentialsJson,
    SettingsRepository.keyDbEffectivePath,
    SettingsRepository.keyLibraryPath,
    SettingsRepository.keyIndexPath,
    SettingsRepository.keyBackupPath,
    SettingsRepository.keyErrorReportSenderEmail,
  };

  static bool isReadable(String key) =>
      allowlist.contains(key) && !blocklist.contains(key);
}
