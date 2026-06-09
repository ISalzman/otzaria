import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/services.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/shortcuts/shortcut_helper.dart';
import 'package:otzaria/widgets/misc/rtl_icon.dart';
import 'package:otzaria/widgets/widgets_exports.dart';

/// דיאלוג לקליטת קיצור מקשים מותאם אישית
class CustomShortcutDialog extends StatefulWidget {
  final String? initialShortcut;

  const CustomShortcutDialog({
    super.key,
    this.initialShortcut,
  });

  @override
  State<CustomShortcutDialog> createState() => _CustomShortcutDialogState();
}

class _CustomShortcutDialogState extends State<CustomShortcutDialog> {
  final Set<LogicalKeyboardKey> _pressedKeys = {};
  String _displayText = 'לחץ על המקשים...';
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialShortcut != null) {
      _displayText =
          ShortcutHelper.formatShortcutForDisplay(widget.initialShortcut!);
    }
  }

  void _updateDisplay() {
    if (_pressedKeys.isEmpty) {
      setState(() {
        _displayText = 'לחץ על המקשים...';
      });
      return;
    }

    final shortcut = ShortcutHelper.formatKeysToShortcut(_pressedKeys);
    setState(() {
      _displayText = ShortcutHelper.formatShortcutForDisplay(shortcut);
    });
  }

  void _confirmShortcut() {
    if (_pressedKeys.isEmpty) {
      UiSnack.showError('יש לבחור קיצור');
      return;
    }

    final shortcut = ShortcutHelper.formatKeysToShortcut(_pressedKeys);
    Navigator.pop(context, shortcut);
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (!_isRecording) {
          // אם לא מקליטים, אפשר אנטר לאישור
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.enter) {
            _confirmShortcut();
          }
          return;
        }

        if (event is KeyDownEvent) {
          setState(() {
            _pressedKeys.add(event.logicalKey);
          });
          _updateDisplay();
        } else if (event is KeyUpEvent) {
          // כאשר משחררים מקש, לא מסירים אותו מיד
          // נחכה שכל המקשים ישוחררו
        }
      },
      child: AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        title: const Text(
          'הגדרת קיצור מקשים מותאם אישית',
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'התחל הקלטה ובחר קיצור',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 14),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isRecording
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).dividerColor,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    RtlIcon(
                      _isRecording
                          ? FluentIcons.keyboard_24_filled
                          : FluentIcons.keyboard_24_regular,
                      size: 48,
                      color: _isRecording
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _displayText,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _isRecording
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_isRecording && _pressedKeys.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Enter או אישור',
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (_isRecording)
                NeutralActionButton(
                  onPressed: () {
                    setState(() {
                      _isRecording = false;
                    });
                  },
                  icon: FluentIcons.stop_24_regular,
                  text: 'עצור הקלטה',
                )
              else
                RecommendedActionButton(
                  onPressed: () {
                    setState(() {
                      _pressedKeys.clear();
                      _isRecording = true;
                      _displayText = 'לחץ על המקשים...';
                    });
                  },
                  icon: FluentIcons.record_24_regular,
                  text: 'התחל הקלטה',
                ),
            ],
          ),
        ),
        actions: [
          NeutralActionButton(
            text: 'ביטול',
            onPressed: () => Navigator.pop(context),
          ),
          RecommendedActionButton(
            text: 'אישור',
            onPressed: _confirmShortcut,
          ),
        ],
      ),
    );
  }
}
