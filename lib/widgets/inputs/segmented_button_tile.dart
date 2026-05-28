import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:otzaria/theme/theme_exports.dart';

const _kSegmentBaseWidthWithIcon = 80.0;
const _kSegmentBaseWidthNoIcon = 60.0;
const _kSegmentCharWidthMultiplier = 8.0;
const _kSegmentGroupPadding = 24.0;
const _kSegmentMinTotalWidth = 180.0;
const _kSegmentMaxTotalWidth = 400.0;
const _kSegmentNarrowLayoutThreshold = 200.0;

/// אפשרות יחידה ב-[AppSegmentedControl]
class SegmentOption<T> {
  final T value;
  final String label;
  final IconData? icon;

  const SegmentOption({
    required this.value,
    required this.label,
    this.icon,
  });
}

/// פקד סגמנטד גנרי לשימוש בסרגלי כלים ובהגדרות.
///
/// [height] — גובה קבוע בפיקסלים (ברירת מחדל: null = compact density לסרגלי כלים).
/// [expandToFillWidth] — מלא את כל הרוחב הזמין.
///
/// דוגמה:
/// ```dart
/// AppSegmentedControl<String>(
///   options: const [
///     SegmentOption(value: 'all', label: 'הכל', icon: FluentIcons.library_24_regular),
///     SegmentOption(value: 'done', label: 'הושלם', icon: FluentIcons.checkmark_circle_24_regular),
///   ],
///   currentValue: _filter,
///   onChanged: (v) => setState(() => _filter = v),
/// )
/// ```
class AppSegmentedControl<T> extends StatelessWidget {
  final List<SegmentOption<T>> options;
  final T currentValue;
  final ValueChanged<T> onChanged;
  final bool expandToFillWidth;
  final double? height;

  const AppSegmentedControl({
    super.key,
    required this.options,
    required this.currentValue,
    required this.onChanged,
    this.expandToFillWidth = false,
    this.height,
  });

  List<ButtonSegment<T>> _segments() {
    final hasIcons = options.any((o) => o.icon != null);
    return options
        .map(
          (o) => ButtonSegment<T>(
            value: o.value,
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(o.label, style: AppTextStyles.settingTitle),
            ),
            icon: hasIcons
                ? (o.icon != null
                    ? Icon(o.icon, size: 18)
                    : const SizedBox(width: 18))
                : null,
          ),
        )
        .toList();
  }

  static ButtonStyle _buttonStyle(ColorScheme cs) => ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return cs.onSecondaryContainer;
          }
          return cs.onSurfaceVariant;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return cs.secondaryContainer;
          return cs.surface;
        }),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusSM),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isFixed = height != null;

    return SegmentedButton<T>(
      segments: _segments(),
      selected: {currentValue},
      expandedInsets: expandToFillWidth ? EdgeInsets.zero : null,
      onSelectionChanged: (Set<T> selection) {
        if (selection.isNotEmpty) onChanged(selection.first);
      },
      showSelectedIcon: true,
      selectedIcon: const Icon(FluentIcons.checkmark_24_regular, size: 16),
      style: isFixed
          ? _buttonStyle(cs).copyWith(
              minimumSize: WidgetStateProperty.all(Size(0, height!)),
              maximumSize:
                  WidgetStateProperty.all(Size(double.infinity, height!)),
            )
          : _buttonStyle(cs).copyWith(
              visualDensity: VisualDensity.compact,
            ),
    );
  }
}

/// Widget להגדרה עם [SegmentedButton] — בהתאם לספציפיקציית M3.
class SegmentedSettingsTile<T> extends StatefulWidget {
  final dynamic title;
  final String? subtitle;
  final IconData? icon;
  final List<SegmentOption<T>> options;
  final T currentValue;
  final ValueChanged<T> onChanged;

  const SegmentedSettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.options,
    required this.currentValue,
    required this.onChanged,
  });

  @override
  State<SegmentedSettingsTile<T>> createState() =>
      _SegmentedSettingsTileState<T>();
}

class _SegmentedSettingsTileState<T> extends State<SegmentedSettingsTile<T>> {
  final FocusNode _focusNode = FocusNode();
  int _focusedIndex = 0;

  @override
  void initState() {
    super.initState();
    _focusedIndex =
        widget.options.indexWhere((o) => o.value == widget.currentValue);
    if (_focusedIndex < 0) _focusedIndex = 0;
  }

  @override
  void didUpdateWidget(covariant SegmentedSettingsTile<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentValue != widget.currentValue ||
        oldWidget.options != widget.options) {
      final idx =
          widget.options.indexWhere((o) => o.value == widget.currentValue);
      _focusedIndex = idx < 0 ? 0 : idx;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasIcons = widget.options.any((o) => o.icon != null);
    final maxLen = widget.options
        .map((o) => o.label.length)
        .reduce((a, b) => a > b ? a : b);
    final btnWidth =
        (hasIcons ? _kSegmentBaseWidthWithIcon : _kSegmentBaseWidthNoIcon) +
            maxLen * _kSegmentCharWidthMultiplier;
    final totalW = (btnWidth * widget.options.length + _kSegmentGroupPadding)
        .clamp(_kSegmentMinTotalWidth, _kSegmentMaxTotalWidth);

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isNarrow =
            constraints.maxWidth < totalW + _kSegmentNarrowLayoutThreshold;
        final button = _buildButton(totalW);

        if (isNarrow) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.spaceMD,
              vertical: 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 24),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _titleWidget(),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitle!,
                              style: AppTextStyles.settingSubtitle.copyWith(
                                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: button),
              ],
            ),
          );
        }

        return ListTile(
          leading: widget.icon != null ? Icon(widget.icon) : null,
          title: _titleWidget(),
          subtitle: widget.subtitle != null
              ? Text(widget.subtitle!, style: AppTextStyles.settingSubtitle)
              : null,
          trailing: button,
        );
      },
    );
  }

  Widget _titleWidget() {
    if (widget.title is! String) return widget.title as Widget;
    return Text(widget.title as String, style: AppTextStyles.settingTitle);
  }

  Widget _buildButton(double totalW) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (_, ev) {
        if (ev is! KeyDownEvent) return KeyEventResult.ignored;
        if (ev.logicalKey == LogicalKeyboardKey.arrowRight) {
          setState(
              () => _focusedIndex = (_focusedIndex + 1) % widget.options.length);
          return KeyEventResult.handled;
        }
        if (ev.logicalKey == LogicalKeyboardKey.arrowLeft) {
          setState(() => _focusedIndex =
              (_focusedIndex - 1 + widget.options.length) %
                  widget.options.length);
          return KeyEventResult.handled;
        }
        if (ev.logicalKey == LogicalKeyboardKey.enter ||
            ev.logicalKey == LogicalKeyboardKey.space) {
          widget.onChanged(widget.options[_focusedIndex].value);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: SizedBox(
        width: totalW,
        child: AppSegmentedControl<T>(
          options: widget.options,
          currentValue: widget.currentValue,
          onChanged: widget.onChanged,
          height: 40,
        ),
      ),
    );
  }
}
