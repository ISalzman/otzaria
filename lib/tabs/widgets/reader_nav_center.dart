import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/settings/settings_exports.dart';
import 'package:otzaria/widgets/controls/action_buttons.dart';

/// אזור המרכז האחיד לסרגלי הקריאה: [prev-major] [prev-minor] | כותרת | [next-minor] [next-major].
///
/// [title] — ווידג'ט הכותרת (Text, SelectionArea, LayoutBuilder וכו').
/// [afterTitle] — ווידג'ט אופציונלי אחרי הכותרת (למשל PageNumberDisplay ב-PDF).
class ReaderNavCenter extends StatelessWidget {
  final Widget title;
  final VoidCallback onPrevMajor;
  final VoidCallback onPrevMinor;
  final VoidCallback onNextMinor;
  final VoidCallback onNextMajor;
  final String prevMajorTooltip;
  final String prevMinorTooltip;
  final String nextMinorTooltip;
  final String nextMajorTooltip;
  final Widget? afterTitle;

  const ReaderNavCenter({
    super.key,
    required this.title,
    required this.onPrevMajor,
    required this.onPrevMinor,
    required this.onNextMinor,
    required this.onNextMajor,
    this.prevMajorTooltip = 'הקודם',
    this.prevMinorTooltip = 'הקודם',
    this.nextMinorTooltip = 'הבא',
    this.nextMajorTooltip = 'הבא',
    this.afterTitle,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = context.read<SettingsBloc>().state.compactMenuMode;
    const gap = 4.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ToolbarActionButton(
          tooltip: prevMajorTooltip,
          icon: FluentIcons.arrow_previous_24_filled,
          compact: isCompact,
          onPressed: onPrevMajor,
        ),
        ToolbarActionButton(
          tooltip: prevMinorTooltip,
          icon: FluentIcons.chevron_left_24_regular,
          compact: isCompact,
          onPressed: onPrevMinor,
        ),
        const SizedBox(width: gap),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 80, maxWidth: 340),
          child: title,
        ),
        if (afterTitle != null) afterTitle!,
        const SizedBox(width: gap),
        ToolbarActionButton(
          tooltip: nextMinorTooltip,
          icon: FluentIcons.chevron_right_24_regular,
          compact: isCompact,
          onPressed: onNextMinor,
        ),
        ToolbarActionButton(
          tooltip: nextMajorTooltip,
          icon: FluentIcons.arrow_next_24_filled,
          compact: isCompact,
          onPressed: onNextMajor,
        ),
      ],
    );
  }
}
