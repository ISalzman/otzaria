import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:otzaria/tools/calendar/models/zman_definition.dart';
import 'package:otzaria/tools/calendar/helpers/zmanim_helpers.dart';
import 'package:otzaria/tools/calendar/utils/calendar_cubit.dart';
import 'package:otzaria/widgets/dialogs/dialogs_exports.dart';

/// תוכן דיאלוג "זמנים נוספים" — טבלה קומפקטית מקובצת לפי קטגוריות של כל
/// הזמנים הזמינים. כל שורה מציגה את שם הזמן ואת זמנו ביום הנוכחי;
/// העמודה הימנית היא תיבת סימון להצגה/הסתרה בלוח, ויש כפתור מידע
/// המציג את אופן החישוב (בריחוף או בלחיצה).
class ZmanimSettingsContent extends StatelessWidget {
  const ZmanimSettingsContent({super.key});

  /// מחזיר את זמן ההגדרה ליום הנוכחי, או "—" אם אינו זמין/רלוונטי.
  static String _timeFor(ZmanDefinition def, Map<String, String> dailyTimes) {
    final t = dailyTimes[def.id];
    return (t == null || t.isEmpty) ? '—' : t;
  }

  @override
  Widget build(BuildContext context) {
    // קיבוץ הרישום לפי קטגוריה, בשמירה על סדר ההופעה.
    final categories = <String, List<ZmanDefinition>>{};
    for (final def in kZmanimRegistry) {
      categories.putIfAbsent(def.category, () => []).add(def);
    }

    return SizedBox(
      width: 440,
      height: 540,
      child: BlocBuilder<CalendarCubit, CalendarState>(
        buildWhen: (a, b) =>
            a.enabledZmanim != b.enabledZmanim || a.dailyTimes != b.dailyTimes,
        builder: (context, state) {
          final dailyTimes = state.dailyTimes;
          // מיון כל קטגוריה לפי זמן היום (זמן חסר — בסוף).
          int byTime(ZmanDefinition a, ZmanDefinition b) {
            final ta = dailyTimes[a.id] ?? '';
            final tb = dailyTimes[b.id] ?? '';
            if (ta.isEmpty && tb.isEmpty) return 0;
            if (ta.isEmpty) return 1;
            if (tb.isEmpty) return -1;
            return ta.compareTo(tb);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SourceCredit(),
              const _TableHeader(),
              const Divider(height: 1),
              Expanded(
                child: Scrollbar(
                  child: ListView(
                    primary: true,
                    // מרווח בקצה (שמאל ב-RTL) כדי שסרגל הגלילה לא יכסה
                    // את אייקוני המידע.
                    padding: const EdgeInsetsDirectional.only(end: 14),
                    children: [
                      for (final entry in categories.entries) ...[
                        _CategoryHeader(title: entry.key),
                        for (final (i, def)
                            in ([...entry.value]..sort(byTime)).indexed)
                          _ZmanTableRow(
                            definition: def,
                            enabled: state.enabledZmanim.contains(def.id),
                            timeLabel: _timeFor(def, dailyTimes),
                            striped: i.isOdd,
                            onChanged: (value) => context
                                .read<CalendarCubit>()
                                .setZmanEnabled(def.id, value),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// שורת קרדיט למקור הזמנים — מציגה "לוח עתים לבינה" כקישור לאתר.
class _SourceCredit extends StatelessWidget {
  const _SourceCredit();

  static final Uri _url = Uri.parse('https://itimlabina.co.il');

  Future<void> _open() async {
    if (await canLaunchUrl(_url)) {
      await launchUrl(_url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: _open,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Text.rich(
            TextSpan(
              text: 'חלק ניכר מהמידע על הזמנים באדיבות ',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              children: [
                TextSpan(
                  text: 'לוח עתים לבינה',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
            textDirection: TextDirection.rtl,
          ),
        ),
      ),
    );
  }
}

/// שורת כותרת העמודות של הטבלה.
class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.bold,
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          SizedBox(
            width: 36,
            child: Text('הצג', style: style, textAlign: TextAlign.center),
          ),
          Expanded(child: Text('זמן', style: style)),
          SizedBox(
            width: 96,
            child: Text('היום', style: style, textAlign: TextAlign.center),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  final String title;
  const _CategoryHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Text(
        title,
        textDirection: TextDirection.rtl,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

/// שורת זמן בטבלה — קומפקטית, עם רקע זברה לסירוגין.
class _ZmanTableRow extends StatelessWidget {
  final ZmanDefinition definition;
  final bool enabled;
  final String timeLabel;
  final bool striped;
  final ValueChanged<bool> onChanged;

  const _ZmanTableRow({
    required this.definition,
    required this.enabled,
    required this.timeLabel,
    required this.striped,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      // רקע זברה: שורה מודגשת מקבלת את גוון ה-surface הגבוה ביותר, ושאר
      // השורות שקופות (על רקע הדיאלוג).
      color: striped ? scheme.surfaceContainerHighest : Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!enabled),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              // עמודה ימנית — תיבת סימון (V / ביטול)
              SizedBox(
                width: 36,
                child: Checkbox(
                  value: enabled,
                  onChanged: (v) => onChanged(v ?? false),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              Expanded(
                child: Text(
                  definition.fullName,
                  textDirection: TextDirection.rtl,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
              SizedBox(
                width: 96,
                child: Text(
                  timeLabel,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: timeLabel == '—'
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                  ),
                ),
              ),
              _ZmanInfoButton(
                name: definition.fullName,
                explanation: definition.explanation,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// כפתור מידע — מציג את הסבר החישוב בריחוף (Tooltip) ובלחיצה (חלונית).
class _ZmanInfoButton extends StatelessWidget {
  final String name;
  final String explanation;
  final Color color;

  const _ZmanInfoButton({
    required this.name,
    required this.explanation,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: explanation,
      textAlign: TextAlign.right,
      waitDuration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.all(12),
      constraints: const BoxConstraints(maxWidth: 320),
      textStyle: TextStyle(color: scheme.onSurface, fontSize: 13),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: IconButton(
        icon: Icon(FluentIcons.info_24_regular, size: 16, color: color),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        onPressed: () => showSingleActionDialog(
          context: context,
          title: name,
          content: explanation,
          confirmText: 'הבנתי',
        ),
      ),
    );
  }
}

/// עוזר להצגת הדיאלוג. ה-context חייב לכלול CalendarCubit ב-tree.
/// משתמש ברכיב הדיאלוג הסטנדרטי [SingleActionDialog] של הפרויקט.
Future<void> showZmanimSettingsDialog(BuildContext context) {
  final cubit = context.read<CalendarCubit>();
  return showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: const SingleActionDialog(
        title: Row(
          textDirection: TextDirection.rtl,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FluentIcons.clock_24_regular),
            SizedBox(width: 8),
            Text('זמנים נוספים', textDirection: TextDirection.rtl),
          ],
        ),
        customContent: ZmanimSettingsContent(),
        confirmText: 'סגור',
      ),
    ),
  );
}
