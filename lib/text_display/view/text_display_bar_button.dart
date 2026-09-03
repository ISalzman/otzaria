import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/settings/engine/settings_bloc.dart';
import 'package:otzaria/settings/engine/settings_state.dart';
import 'package:otzaria/text_book/bloc/text_book_bloc.dart';
import 'package:otzaria/text_book/bloc/text_book_event.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/text_display/text_display_exports.dart';
import 'package:otzaria/text_display/view/text_display_profile_editor.dart';
import 'package:otzaria/theme/theme_exports.dart';
import 'package:otzaria/widgets/misc/app_popup_menu.dart';
import 'package:otzaria/widgets/widgets_exports.dart';
import 'package:otzaria_icons/otzaria_icons.dart';

/// אייקון הניקוד של הכפתור — משקף את מצב הגוף בתצוגה הפעילה.
IconData textDisplayBarIcon(TextBookLoaded state) => state.removeNikud
    ? OtzariaIcons.alef_with_score_24_regular
    : OtzariaIcons.alef_deletion_24_regular;

String textDisplayBarTooltip(TextBookLoaded state) =>
    state.removeNikud ? 'הצג ניקוד' : 'הסתר ניקוד';

/// מחליף את ניקוד הגוף בכרטיסייה (הפעולה הראשית של הכפתור).
void toggleBodyNikud(BuildContext context, TextBookLoaded state) {
  context.read<TextBookBloc>().add(
    ApplyDisplayPatch(
      target: TextTarget.body,
      patch: TextDisplayPatch(
        nikud: state.removeNikud ? MarkVisibility.show : MarkVisibility.hide,
      ),
      persistToBook: context.read<SettingsBloc>().state.enablePerBookSettings,
    ),
  );
}

/// כפתור "תצוגת הטקסט" בסרגל ספר הטקסט: לחיצה ראשית מחליפה ניקוד, והחץ
/// פותח פופאפ עם כל הפרופיל — גוף ומפרשים — לתצוגה הפעילה (רגילה/צורת הדף).
class TextDisplayBarButton extends StatelessWidget {
  final TextBookLoaded state;
  final bool compact;

  const TextDisplayBarButton({
    super.key,
    required this.state,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return BarSplitButton<void>(
      icon: textDisplayBarIcon(state),
      tooltip: textDisplayBarTooltip(state),
      menuTooltip: 'תצוגת הטקסט: ניקוד, טעמים, פיסוק, שם הוי"ה וציונים',
      compact: compact,
      onPressed: () => toggleBodyNikud(context, state),
      entries: const [],
      onSelected: null,
      onArrowPressed: (anchorContext) =>
          showTextDisplayPopup(context, anchorContext: anchorContext),
    );
  }
}

/// פותח את פופאפ תצוגת הטקסט מעל [anchorContext].
Future<void> showTextDisplayPopup(
  BuildContext context, {
  required BuildContext anchorContext,
}) {
  final textBookBloc = context.read<TextBookBloc>();
  final settingsBloc = context.read<SettingsBloc>();
  return showAnchoredAppMenu<void>(
    context: context,
    anchorContext: anchorContext,
    offset: const Offset(0, 8),
    itemsBuilder: (_) => [
      _PanelMenuEntry(
        child: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: textBookBloc),
            BlocProvider.value(value: settingsBloc),
          ],
          child: const TextDisplayPopupPanel(),
        ),
      ),
    ],
  );
}

/// תוכן הפופאפ. נבנה מעל BlocBuilder כדי שהמתגים ישקפו את המצב מיד.
class TextDisplayPopupPanel extends StatelessWidget {
  const TextDisplayPopupPanel({super.key});

  static const double width = 640;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: BlocBuilder<TextBookBloc, TextBookState>(
        builder: (context, state) {
          if (state is! TextBookLoaded) return const SizedBox.shrink();
          final settings = context.watch<SettingsBloc>().state;
          return _PanelBody(state: state, settings: settings);
        },
      ),
    );
  }
}

class _PanelBody extends StatelessWidget {
  final TextBookLoaded state;
  final SettingsState settings;

  const _PanelBody({required this.state, required this.settings});

  void _apply(
    BuildContext context,
    TextTarget target,
    TextDisplayProfile current,
    TextDisplayProfile next,
  ) {
    // רק השדה שהשתנה נכתב כעקיפה — שאר השדות ממשיכים לרשת.
    final patch = next.toPatch().pruneAgainst(current);
    if (patch.isEmpty) return;
    context.read<TextBookBloc>().add(
      ApplyDisplayPatch(
        target: target,
        patch: patch,
        persistToBook: settings.enablePerBookSettings,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = state.bodyDisplayProfile;
    final commentary = state.commentaryDisplayProfile;
    final hasOverrides = state.displayOverrides.isNotEmpty;
    final viewLabel = state.showPageShapeView ? 'צורת הדף' : 'תצוגה רגילה';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceSM),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceMD),
            child: Row(
              children: [
                Text(
                  'תצוגת הטקסט',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(viewLabel, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          _SectionTitle('גוף הספר'),
          ...TextDisplayProfileEditor.tiles(
            context,
            profile: body,
            onChanged: (next) => _apply(context, TextTarget.body, body, next),
          ),
          const Divider(height: 1),
          _SectionTitle('מפרשים'),
          ...TextDisplayProfileEditor.tiles(
            context,
            profile: commentary,
            showAnchorMarkers: false,
            onChanged: (next) =>
                _apply(context, TextTarget.commentary, commentary, next),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.spaceMD,
              AppTokens.spaceSM,
              AppTokens.spaceMD,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    settings.enablePerBookSettings
                        ? 'השינויים נשמרים לספר זה'
                        : 'השינויים חלים על כרטיסייה זו בלבד',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                if (hasOverrides)
                  ActionButton.ghost(
                    text: 'איפוס',
                    onPressed: () => context.read<TextBookBloc>().add(
                      const ClearDisplayOverrides(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppTokens.spaceMD,
      AppTokens.spaceSM,
      AppTokens.spaceMD,
      0,
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

/// פריט תפריט שמארח ווידג'ט חופשי (הפאנל) בתוך תפריט מוצמד.
class _PanelMenuEntry extends PopupMenuEntry<void> {
  final Widget child;
  const _PanelMenuEntry({required this.child});

  @override
  double get height => kMinInteractiveDimension;

  @override
  bool represents(void value) => false;

  @override
  State<_PanelMenuEntry> createState() => _PanelMenuEntryState();
}

class _PanelMenuEntryState extends State<_PanelMenuEntry> {
  @override
  Widget build(BuildContext context) => widget.child;
}
