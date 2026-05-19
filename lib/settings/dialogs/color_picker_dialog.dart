import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:otzaria/theme/theme_exports.dart';
import 'package:otzaria/widgets/widgets_exports.dart';

/// שורת הגדרה לבחירת צבע בסיס.
///
/// מציגה את הצבע הנבחר ושמו בעברית. בלחיצה נפתח דיאלוג עם עיגולי הצבע.
class ColorPickerTile extends StatelessWidget {
  final Color currentColor;
  final Color defaultColor;
  final ValueChanged<Color> onChanged;

  const ColorPickerTile({
    super.key,
    required this.currentColor,
    required this.defaultColor,
    required this.onChanged,
  });

  String get _colorName =>
      AppSeedColors.nameOf(currentColor) ?? 'צבע מותאם אישית';

  void _showPicker(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _ColorPickerDialog(
        currentColor: currentColor,
        defaultColor: defaultColor,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      hoverColor: Colors.transparent,
      leading: const Icon(FluentIcons.color_24_regular),
      title: const Text('צבע בסיס', textDirection: TextDirection.rtl),
      subtitle: Text(
        _colorName,
        textDirection: TextDirection.rtl,
        style: AppTextStyles.settingSubtitle,
      ),
      trailing: RecommendedActionButton(
        text: 'שינוי צבע',
        onPressed: () => _showPicker(context),
      ),
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  final Color currentColor;
  final Color defaultColor;
  final ValueChanged<Color> onChanged;

  const _ColorPickerDialog({
    required this.currentColor,
    required this.defaultColor,
    required this.onChanged,
  });

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentColor;
  }

  void _select(Color color) {
    setState(() => _selected = color);
    widget.onChanged(color);
  }

  String get _selectedName =>
      AppSeedColors.nameOf(_selected) ?? 'צבע מותאם אישית';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleActionDialog(
      title: const Text('בחר צבע בסיס', textDirection: TextDirection.rtl),
      confirmText: 'סגור',
      customContent: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // תצוגת הצבע הנבחר ושמו
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _selected,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppTokens.spaceSM),
                  Text(
                    _selectedName,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: AppTokens.fontMD,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.spaceMD),
              // שורת איפוס לברירת מחדל
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  const Expanded(
                    child: Text(
                      'בחר בצבע ברירת מחדל',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(fontSize: AppTokens.fontMD),
                    ),
                  ),
                  const SizedBox(width: AppTokens.spaceSM),
                  NeutralActionButton(
                    text: 'איפוס',
                    icon: FluentIcons.arrow_reset_24_regular,
                    onPressed: () => _select(widget.defaultColor),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.spaceMD),
              // עיגולי הצבעים
              Wrap(
                spacing: AppTokens.spaceSM,
                runSpacing: AppTokens.spaceSM,
                alignment: WrapAlignment.center,
                children: AppSeedColors.options
                    .map(
                      (entry) => _ColorSwatch(
                        color: entry.color,
                        name: entry.name,
                        isSelected:
                            _selected.toARGB32() == entry.color.toARGB32(),
                        onTap: () => _select(entry.color),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// עיגול בחירת צבע יחיד — נגיש למקלדת, עם tooltip ו-Semantics.
class _ColorSwatch extends StatelessWidget {
  final Color color;
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.color,
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // ניגודיות לעיגול: לבן/שחור בהתאם לבהירות הצבע. לא תלוי ב-colorScheme,
    // כי הצבעים כאן קבועים מראש ולא מושפעים מערכת הצבעים של האפליקציה.
    final iconColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black;
    return Semantics(
      label: name,
      button: true,
      selected: isSelected,
      child: Tooltip(
        message: name,
        child: Material(
          color: color,
          shape: CircleBorder(
            side: isSelected
                ? BorderSide(color: cs.onSurface, width: 3)
                : BorderSide.none,
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 40,
              height: 40,
              child: isSelected
                  ? Icon(
                      FluentIcons.checkmark_24_regular,
                      color: iconColor,
                      size: 20,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
