import 'package:file_picker/file_picker.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/settings/widgets/settings_card.dart';
import 'package:otzaria/theme/theme_exports.dart';
import 'package:otzaria/utils/move_directory.dart';
import 'package:otzaria/widgets/controls/action_buttons.dart';
import 'package:otzaria/widgets/dialogs/reusable_items_dialog.dart';

class ChangeLocationResult {
  final String newPath;
  final bool moveContents;

  const ChangeLocationResult(this.newPath, {required this.moveContents});
}

/// מרכז את לוגיקת הדיאלוג, UiSnack, וביצוע הפעולה.
/// [onPathChanged] — עדכון נתיב ללא העברת קבצים.
/// [onAfterMove] — עדכון state לאחר שהקבצים הועברו (moveDirectory נקרא כאן אוטומטית).
Future<void> Function(BuildContext) makeChangeLocationCallback({
  required String currentPath,
  required String folderName,
  required Future<void> Function(String newPath) onPathChanged,
  Future<void> Function(String newPath)? onAfterMove,
  String? defaultPath,
}) {
  final canMoveContents = onAfterMove != null && currentPath.isNotEmpty;
  return (ctx) async {
    final result = await showChangeLocationDialog(
      context: ctx,
      currentPath: currentPath,
      folderName: folderName,
      canMoveContents: canMoveContents,
      defaultPath: defaultPath,
    );
    if (result == null) return;

    if (result.moveContents && canMoveContents) {
      UiSnack.showChecking(
        'מעביר את קבצי $folderName\nהפעולה עשויה לקחת מספר דקות',
      );
      try {
        final deleteWarning =
            await moveDirectory(currentPath, result.newPath);
        await onAfterMove(result.newPath);
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
    } else {
      await onPathChanged(result.newPath);
    }
  };
}

Future<ChangeLocationResult?> showChangeLocationDialog({
  required BuildContext context,
  required String currentPath,
  required String folderName,
  bool canMoveContents = true,
  String? defaultPath,
}) =>
    showDialog<ChangeLocationResult>(
      context: context,
      builder: (_) => _ChangeLocationDialogContent(
        currentPath: currentPath,
        folderName: folderName,
        canMoveContents: canMoveContents,
        defaultPath: defaultPath,
      ),
    );

class _ChangeLocationDialogContent extends StatefulWidget {
  final String currentPath;
  final String folderName;
  final bool canMoveContents;
  final String? defaultPath;

  const _ChangeLocationDialogContent({
    required this.currentPath,
    required this.folderName,
    required this.canMoveContents,
    this.defaultPath,
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          SettingsCard(
            title: 'פעולה',
            subtitle: 'בחר אם להעביר את קבצי הספרייה למיקום החדש, או לעדכן את ההגדרה בלבד',
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
          SettingsCard(
            title: 'מיקום חדש',
            subtitle: 'בחר מיקום מותאם אישית, או חזור למיקום ברירת המחדל של האפליקציה',
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
        style: AppTextStyles.settingSubtitle.copyWith(
            color: cs.onSurfaceVariant),
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
