import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/tools/calendar/utils/calendar_cubit.dart';
import 'package:otzaria/settings/panels/settings_panels_exports.dart';
import 'package:otzaria/settings/panels/tools_management_panel.dart';
import 'package:otzaria/widgets/misc/tool_ui_helpers.dart';

/// טאב כלים — לוח שנה, גימטריות, עורך.
///
/// [calendarCubit] — העברה מפורשת של CalendarCubit כדי לתקן את הבאג שבו
/// הגדרות לוח השנה לא נשמרות כאשר ההגדרות נפתחות כ-route חדש (ה-context
/// של המסך החדש לא מכיל את ה-CalendarCubit ממסך הניווט).
class ToolsSettingsTab extends StatelessWidget {
  /// CalendarCubit שמגיע מה-context של המסך שפתח את ההגדרות.
  /// אם null, מנסה לקרוא מה-context (תואמות לאחור).
  final CalendarCubit? calendarCubit;

  const ToolsSettingsTab({super.key, this.calendarCubit});

  @override
  Widget build(BuildContext context) {
    // CustomScrollView (ולא SingleChildScrollView) כדי ש-ToolsManagementPanel
    // יוכל להחזיר sliver עם סרגל פעולות מוצמד (PinnedHeaderSliver) לאזור התוספים.
    final content = CustomScrollView(
      primary: true,
      slivers: [
        const ToolsManagementPanel(),
        SliverToBoxAdapter(
          child: ToolPanelWrapper(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                SizedBox(height: 16),
                CalendarSettingsTab(),
                GematriaSettingsTab(),
                // [EDITING DISABLED] EditorSettingsTab(),
                SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );

    // אם קיבלנו CalendarCubit במפורש — עטוף כדי להבטיח שהשינויים יישמרו
    if (calendarCubit != null) {
      return BlocProvider<CalendarCubit>.value(
        value: calendarCubit!,
        child: content,
      );
    }

    return content;
  }
}
