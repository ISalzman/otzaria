import 'package:file_picker/file_picker.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:path/path.dart' as p;
import 'package:otzaria/core/app_runtime_reset.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/data/constants/database_constants.dart';
import 'package:otzaria/data/repository/data_repository.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/plugins/view/webview_environment_holder.dart';
import 'package:otzaria/settings/engine/settings_engine_exports.dart';
import 'package:otzaria/tabs/tabs_repository.dart';
import 'package:otzaria/settings/widgets/settings_card.dart';
import 'package:otzaria/theme/theme_exports.dart';
import 'package:otzaria/utils/move_directory.dart';
import 'package:otzaria/widgets/dialogs/reusable_items_dialog.dart';
import 'package:otzaria/widgets/misc/restart_widget.dart';
import 'package:otzaria/widgets/widgets_exports.dart';

class ChangeLocationResult {
  final String newPath;
  final bool moveContents;

  const ChangeLocationResult(this.newPath, {required this.moveContents});
}

/// מרכז את לוגיקת הדיאלוג, UiSnack, וביצוע הפעולה.
/// [onPathChanged] — עדכון נתיב ללא העברת קבצים.
/// [onAfterMove] — עדכון state לאחר שהקבצים הועברו (moveDirectory נקרא כאן אוטומטית).
/// [onMoveContents] — מסלול העברה מותאם (למשל הספרייה, שדורש סגירת DB ורענון);
/// כשהוא מסופק הוא מחליף לגמרי את moveDirectory+onAfterMove.
/// [moveContentsWarning] — טקסט אזהרה שיוצג בדיאלוג כשבוחרים "העבר תוכן".
Future<void> Function(BuildContext) makeChangeLocationCallback({
  required String currentPath,
  required String folderName,
  required Future<void> Function(String newPath) onPathChanged,
  Future<void> Function(String newPath)? onAfterMove,
  Future<void> Function(BuildContext ctx, String from, String to)?
      onMoveContents,
  String? moveContentsWarning,
  String? defaultPath,
}) {
  final canMoveContents =
      (onAfterMove != null || onMoveContents != null) && currentPath.isNotEmpty;
  return (ctx) async {
    final result = await showChangeLocationDialog(
      context: ctx,
      currentPath: currentPath,
      folderName: folderName,
      canMoveContents: canMoveContents,
      defaultPath: defaultPath,
      moveContentsWarning: moveContentsWarning,
    );
    if (result == null) return;

    if (!(result.moveContents && canMoveContents)) {
      await onPathChanged(result.newPath);
      return;
    }

    if (onMoveContents != null) {
      if (!ctx.mounted) return;
      await onMoveContents(ctx, currentPath, result.newPath);
      return;
    }

    UiSnack.showChecking(
      'מעביר את קבצי $folderName\nהפעולה עשויה לקחת מספר דקות',
    );
    try {
      final deleteWarning = await moveDirectory(currentPath, result.newPath);
      await onAfterMove!(result.newPath);
      UiSnack.hide();
      if (deleteWarning != null) {
        UiSnack.showWarning(
          '$folderName הועבר בהצלחה, אך לא ניתן למחוק את תיקיית המקור. אנא מחק ידנית: $deleteWarning',
        );
      } else {
        UiSnack.show('$folderName הועבר בהצלחה');
      }
    } catch (e) {
      UiSnack.hide();
      UiSnack.showError('שגיאה בהעברת קבצי $folderName: $e');
    }
  };
}

/// מחזיר את שמות הרשומות העליונות בתיקיית הספרייה [from] שיש להעביר: קבצי
/// ה-DB שהתוכנה מנהלת, וכן כל ספר (PDF/DOCX) שהספרייה מזהה וקובצו יושב בתוך
/// התיקייה. כך מועברים רק ספרים מזוהים, וקבצים אקראיים שהמשתמש הוסיף נשארים.
Future<Set<String>> _libraryMoveIncludeSet(String from) async {
  final include = DatabaseConstants.libraryManagedEntryNames();
  try {
    final library = await DataRepository.instance.library;
    for (final book in library.getAllBooks()) {
      if (book is! FileBook) continue;
      final path = book.path;
      if (path.isEmpty) continue;
      if (!p.equals(from, path) && !p.isWithin(from, path)) continue;
      final segments = p.split(p.relative(path, from: from));
      if (segments.isNotEmpty && segments.first.isNotEmpty) {
        include.add(segments.first);
      }
    }
  } catch (e) {
    debugPrint('[performLibraryMove] library include scan failed: $e');
  }
  return include;
}

/// מעביר את ספריית אוצריא למיקום חדש בסדר בטוח שמתמודד עם נעילת הקבצים ע"י
/// Windows (seforim.db וקובצי PDF פתוחים):
/// מעתיק את הקבצים המזוהים בעוד הם פתוחים, מעדכן את ההגדרה, ממפה את נתיבי
/// הטאבים הפתוחים למיקום החדש, וטוען את התוכנה מחדש (סוגר את הספרים הפתוחים
/// ומשחרר את הנעילה) — ורק לאחר הרענון מוחק את הקבצים הישנים.
Future<void> performLibraryMove({
  required BuildContext context,
  required String from,
  required String to,
}) async {
  if (p.equals(from, to)) return;

  final navigator = Navigator.of(context, rootNavigator: true);
  _showBlockingProgress(
    context,
    'מעביר את הספרייה למיקום החדש…\nהתוכנה לא תהיה פעילה עד לסיום הפעולה.',
  );

  final include = await _libraryMoveIncludeSet(from);
  try {
    // 1. העתקת הקבצים המזוהים בלבד למיקום החדש (גם בעוד ה-DB/PDF פתוחים).
    await copyDirectoryEntries(from, to, includeOnly: include);
    // 2. עדכון הגדרת מיקום הספרייה בקבצי המשתמש.
    await Settings.setValue<String>(SettingsRepository.keyLibraryPath, to);
    await Settings.setValue<String>(
        SettingsRepository.keyLibraryFolderName, '');
    await Settings.setValue<String>(SettingsRepository.keyDbEffectivePath, '');
    // 3. מיפוי נתיבי הספרים הפתוחים כך שייטענו מהמיקום החדש לאחר הרענון.
    await TabsRepository().remapBookPaths(from, to);
    // 4. סגירת חיבורי ה-DB (משחרר את נעילת seforim.db) והפניה למיקום החדש.
    await resetRuntimeStateForAppRestart();
  } catch (e) {
    if (navigator.canPop()) navigator.pop();
    UiSnack.showError('שגיאה בהעברת הספרייה: $e');
    return;
  }

  if (!context.mounted) return;
  if (navigator.canPop()) navigator.pop();

  await showSingleActionDialog(
    context: context,
    title: 'הספרייה הועברה',
    content: 'הספרייה הועברה בהצלחה למיקום החדש. התוכנה תיטען מחדש כעת, '
        'והספרים הפתוחים ייטענו מהמיקום החדש.',
    confirmText: 'טען מחדש',
  );
  if (!context.mounted) return;
  // רענון מלא: בונה מחדש את עץ הווידג'טים, טוען את הספרייה והטאבים מהמיקום
  // החדש, וסוגר את הספרים הפתוחים — מה שמשחרר את נעילת קובצי ה-PDF הישנים.
  RestartWidget.restartApp(
    context,
    afterRestart: () async {
      await WebViewEnvironmentHolder.disposeForAppRestart();
      // המתנה קצרה לשחרור מלא של file-handles של הספרים שנסגרו, לפני המחיקה.
      await Future<void>.delayed(const Duration(milliseconds: 800));
      final leftover = await deleteMovedEntries(from, includeOnly: include);
      if (leftover != null) {
        UiSnack.showWarning(
          'הספרייה הועברה, אך חלק מהקבצים הישנים לא נמחקו. ניתן למחוק אותם '
          'ידנית מהמיקום הישן.',
        );
      }
    },
  );
}

void _showBlockingProgress(BuildContext context, String message) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}

Future<ChangeLocationResult?> showChangeLocationDialog({
  required BuildContext context,
  required String currentPath,
  required String folderName,
  bool canMoveContents = true,
  String? defaultPath,
  String? moveContentsWarning,
}) =>
    showDialog<ChangeLocationResult>(
      context: context,
      builder: (_) => _ChangeLocationDialogContent(
        currentPath: currentPath,
        folderName: folderName,
        canMoveContents: canMoveContents,
        defaultPath: defaultPath,
        moveContentsWarning: moveContentsWarning,
      ),
    );

class _ChangeLocationDialogContent extends StatefulWidget {
  final String currentPath;
  final String folderName;
  final bool canMoveContents;
  final String? defaultPath;
  final String? moveContentsWarning;

  const _ChangeLocationDialogContent({
    required this.currentPath,
    required this.folderName,
    required this.canMoveContents,
    this.defaultPath,
    this.moveContentsWarning,
  });

  @override
  State<_ChangeLocationDialogContent> createState() =>
      _ChangeLocationDialogContentState();
}

class _ChangeLocationDialogContentState
    extends State<_ChangeLocationDialogContent> {
  String? _selectedPath;
  late bool _moveContents;

  @override
  void initState() {
    super.initState();
    _moveContents = widget.canMoveContents;
  }

  // true כשהמיקום האפקטיבי (נבחר או נוכחי) כבר שווה לברירת המחדל
  bool get _isAtDefault =>
      (_selectedPath ?? widget.currentPath) == widget.defaultPath;

  Future<void> _pickFolder() async {
    final path = await FilePicker.getDirectoryPath(lockParentWindow: true);
    if (path != null && mounted) setState(() => _selectedPath = path);
  }

  void _confirm() {
    if (_selectedPath == null) return;
    Navigator.of(context).pop(
      ChangeLocationResult(_selectedPath!, moveContents: _moveContents),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCustomContentDialog(
      title: 'שינוי מיקום ${widget.folderName}',
      onConfirm: _selectedPath != null ? _confirm : null,
      handleEnterKey: _selectedPath != null,
      actions: [
        ActionButton.ghost(
          text: 'ביטול',
          onPressed: () => Navigator.of(context).pop(null),
        ),
        ActionButton.recommended(
          text: 'אישור',
          onPressed: _selectedPath != null ? _confirm : null,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsCard(
            title: 'פעולה',
            subtitle:
                'בחר אם להעביר את קבצי הספרייה למיקום החדש, או לעדכן את ההגדרה בלבד',
            children: [
              if (widget.canMoveContents)
                _OptionTile(
                  icon: FluentIcons.folder_swap_24_regular,
                  title: 'העבר תוכן תיקייה',
                  subtitle: 'כל הקבצים יועברו מהמיקום הנוכחי למיקום החדש',
                  selected: _moveContents,
                  onTap: () => setState(() => _moveContents = true),
                ),
              _OptionTile(
                icon: FluentIcons.folder_arrow_right_24_regular,
                title: 'שנה מיקום בלבד',
                subtitle: 'ההגדרה תעודכן, הקבצים יישארו במיקומם הנוכחי',
                selected: !_moveContents,
                onTap: widget.canMoveContents
                    ? () => setState(() => _moveContents = false)
                    : null,
              ),
            ],
          ),
          if (widget.moveContentsWarning != null && _moveContents)
            _MoveContentsWarning(text: widget.moveContentsWarning!),
          SettingsCard(
            title: 'מיקום חדש',
            subtitle:
                'בחר מיקום מותאם אישית, או חזור למיקום ברירת המחדל של האפליקציה',
            children: [
              SettingsActionTile.path(
                icon: FluentIcons.folder_open_24_regular,
                title: 'בחירת מיקום',
                path: _selectedPath,
                placeholder: 'טרם נבחר מיקום',
                actions: [
                  ActionButton.recommended(
                    text: _selectedPath == null ? 'בחר תיקייה' : 'שנה מיקום',
                    onPressed: _pickFolder,
                    icon: FluentIcons.folder_open_24_regular,
                  ),
                ],
              ),
              if (widget.defaultPath != null)
                SettingsActionTile.path(
                  icon: FluentIcons.home_24_regular,
                  title: 'מיקום ברירת מחדל',
                  path: widget.defaultPath,
                  placeholder: '',
                  enabled: !_isAtDefault,
                  actions: [
                    ActionButton.neutral(
                      text: 'השתמש בברירת מחדל',
                      onPressed: _isAtDefault
                          ? null
                          : () => setState(
                              () => _selectedPath = widget.defaultPath),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoveContentsWarning extends StatelessWidget {
  final String text;

  const _MoveContentsWarning({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(FluentIcons.info_24_regular, color: cs.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.settingSubtitle
                  .copyWith(color: cs.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

// folder_arrow_right_24_regular ו-folder_swap_24_regular אינם בטבלת הנגד של RtlIcon —
// אין להם גרסת RTL ולא מתהפכים, לכן נעשה שימוש ב-Icon הרגיל.
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      onTap: onTap,
      hoverColor: Colors.transparent,
      leading: Icon(icon,
          color: selected ? cs.primary : cs.onSurfaceVariant, size: 24),
      title: Text(
        title,
        style: AppTextStyles.settingTitle.copyWith(
          color: selected ? cs.primary : cs.onSurface,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        subtitle,
        style:
            AppTextStyles.settingSubtitle.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: ExcludeFocus(
        child: IgnorePointer(
          child: Checkbox(
            value: selected,
            onChanged: (_) {},
          ),
        ),
      ),
    );
  }
}
