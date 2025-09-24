import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/core/scaffold_messenger.dart';
import '../models/editor_settings.dart';

/// Widget for configuring text editor settings
class EditorSettingsWidget extends StatelessWidget {
  const EditorSettingsWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SettingsGroup(
      title: 'עורך טקסטים',
      children: [
        SwitchSettingsTile(
          settingKey: 'key-editor-enabled',
          title: 'הפעל עורך טקסטים',
          subtitle: 'אפשר עריכת טקסטים בספרים',
          defaultValue: true,
          leading: const Icon(Icons.edit),
        ),
        SliderSettingsTile(
          settingKey: 'key-editor-autosave-interval',
          title: 'מרווח שמירה אוטומטית',
          subtitle: 'כמה שניות בין שמירות אוטומטיות',
          min: 5,
          max: 60,
          step: 5,
          defaultValue: 10,
          leading: const Icon(Icons.timer),
        ),
        SliderSettingsTile(
          settingKey: 'key-editor-max-section-size',
          title: 'גודל מקסימלי לקטע',
          subtitle: 'גודל מקסימלי בקילובייט לעריכת קטע',
          min: 50,
          max: 500,
          step: 50,
          defaultValue: 200,
          leading: const Icon(Icons.storage),
        ),
        SwitchSettingsTile(
          settingKey: 'key-editor-show-badges',
          title: 'הצג תגיות "נערך"',
          subtitle: 'הצג תגיות לצד קטעים שנערכו',
          defaultValue: true,
          leading: const Icon(Icons.label),
        ),
        SliderSettingsTile(
          settingKey: 'key-editor-preview-debounce',
          title: 'עיכוב תצוגה מקדימה',
          subtitle: 'זמן עיכוב במילישניות לעדכון תצוגה מקדימה',
          min: 50,
          max: 500,
          step: 50,
          defaultValue: 150,
          leading: const Icon(Icons.preview),
        ),
        DropDownSettingsTile<String>(
          settingKey: 'key-editor-sanitization-level',
          title: 'רמת אבטחה',
          subtitle: 'רמת הסינון של תוכן HTML',
          values: const {
            'standard': 'רגילה',
            'strict': 'מחמירה',
          },
          selected: 'standard',
          leading: const Icon(Icons.security),
        ),
        SwitchSettingsTile(
          settingKey: 'key-editor-enable-formatting',
          title: 'אפשר עיצוב טקסט',
          subtitle: 'אפשר תכונות עיצוב כמו מודגש, נטוי וכותרות',
          defaultValue: true,
          leading: const Icon(Icons.format_paint),
        ),
        SliderSettingsTile(
          settingKey: 'key-editor-drafts-quota',
          title: 'מכסת טיוטות',
          subtitle: 'גודל מקסימלי במגהבייט לכל הטיוטות',
          min: 50,
          max: 500,
          step: 50,
          defaultValue: 100,
          leading: const Icon(Icons.drafts),
        ),
        SliderSettingsTile(
          settingKey: 'key-editor-draft-cleanup-days',
          title: 'ניקוי טיוטות ישנות',
          subtitle: 'מחק טיוטות ישנות מ-X ימים',
          min: 7,
          max: 90,
          step: 7,
          defaultValue: 30,
          leading: const Icon(Icons.cleaning_services),
        ),
        SimpleSettingsTile(
          title: 'נקה טיוטות עכשיו',
          subtitle: 'מחק את כל הטיוטות הישנות',
          leading: const Icon(Icons.delete_sweep),
          onTap: () => _showCleanupDialog(context),
        ),
        SimpleSettingsTile(
          title: 'סטטיסטיקות עורך',
          subtitle: 'הצג מידע על שימוש בעורך',
          leading: const Icon(Icons.analytics),
          onTap: () => _showStatsDialog(context),
        ),
      ],
    );
  }

  void _showCleanupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ניקוי טיוטות'),
        content: const Text(
          'האם אתה בטוח שברצונך למחוק את כל הטיוטות הישנות?\n'
          'פעולה זו אינה ניתנת לביטול.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ביטול'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _performCleanup(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('מחק'),
          ),
        ],
      ),
    );
  }

  void _performCleanup(BuildContext context) {
    // TODO: Implement actual cleanup
    UiSnack.show(UiSnack.cleanupCompleted);
  }

  void _showStatsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('סטטיסטיקות עורך'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('קטעים ערוכים: 0'),
            Text('טיוטות פעילות: 0'),
            Text('גודל טיוטות: 0 MB'),
            Text('גודל מטמון: 0 MB'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('סגור'),
          ),
        ],
      ),
    );
  }
}

/// Helper class to get editor settings from SharedPreferences
class EditorSettingsHelper {
  static EditorSettings getSettings() {
    return EditorSettings(
      enableEditor: Settings.getValue<bool>('key-editor-enabled') ?? true,
      previewDebounce: Duration(
        milliseconds:
            Settings.getValue<double>('key-editor-preview-debounce')?.toInt() ??
                150,
      ),
      maxSectionSizeKB:
          Settings.getValue<double>('key-editor-max-section-size')?.toInt() ??
              200,
      autosaveIntervalSec:
          Settings.getValue<double>('key-editor-autosave-interval')?.toInt() ??
              10,
      globalDraftsQuotaMB:
          Settings.getValue<double>('key-editor-drafts-quota')?.toInt() ?? 100,
      draftCleanupDays:
          Settings.getValue<double>('key-editor-draft-cleanup-days')?.toInt() ??
              30,
      showEditedBadge:
          Settings.getValue<bool>('key-editor-show-badges') ?? true,
      enabledMarkdownFeatures:
          Settings.getValue<Set<String>>('key-editor-enabled-features')
                  ?.toList() ??
              ['bold', 'italic', 'headers', 'lists', 'links', 'code', 'quotes'],
      sanitizationLevel:
          Settings.getValue<String>('key-editor-sanitization-level') == 'strict'
              ? SanitizationLevel.strict
              : SanitizationLevel.standard,
    );
  }
}
