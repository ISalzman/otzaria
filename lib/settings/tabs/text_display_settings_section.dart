import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/settings/engine/settings_engine_exports.dart';
import 'package:otzaria/settings/l10n/settings_l10n_exports.dart';
import 'package:otzaria/settings/widgets/settings_widgets_exports.dart';
import 'package:otzaria/text_display/text_display_exports.dart';
import 'package:otzaria/text_display/view/text_display_profile_editor.dart';
import 'package:otzaria/theme/theme_exports.dart';
import 'package:otzaria/widgets/widgets_exports.dart';

/// כרטיס "תצוגת הטקסט": השורש (גוף הספר, תצוגה רגילה, ערוץ התצוגה) גלוי
/// תמיד; שאר 11 החריצים ושכבת התנ"ך מקופלים תחת "התאמות נוספות", שבה
/// בוחרים חריץ ומחליטים אם הוא יורש או מקבל הגדרות נפרדות.
class TextDisplaySettingsCard extends StatefulWidget {
  const TextDisplaySettingsCard({super.key});

  @override
  State<TextDisplaySettingsCard> createState() =>
      _TextDisplaySettingsCardState();
}

class _TextDisplaySettingsCardState extends State<TextDisplaySettingsCard> {
  bool _advancedOpen = false;
  TextDisplayBookClass _bookClass = TextDisplayBookClass.general;
  TextTarget _target = TextTarget.body;
  TextView _view = TextView.regular;
  TextChannel _channel = TextChannel.display;

  TextDisplaySlot get _slot =>
      TextDisplaySlot(target: _target, view: _view, channel: _channel);

  bool get _isTanach => _bookClass == TextDisplayBookClass.tanach;

  void _update(TextDisplayPolicy policy) {
    context.read<SettingsBloc>().add(UpdateTextDisplayPolicy(policy));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.settingsText;
    final policy = context.select(
      (SettingsBloc bloc) => bloc.state.textDisplayPolicy,
    );
    final rootProfile = policy.resolve(TextDisplaySlot.root);

    return SettingsCard(
      cardId: 'text.nikud',
      title: t('תצוגת הטקסט'),
      subtitle: t('מה מוצג בטקסט, וכיצד הוא מועתק ומיוצא'),
      children: [
        ...TextDisplayProfileEditor.tiles(
          context,
          profile: rootProfile,
          onChanged: (profile) => _update(
            policy.withSlot(
              TextDisplayBookClass.general,
              TextDisplaySlot.root,
              profile.toPatch(),
            ),
          ),
        ),
        ExpandableSection(
          icon: FluentIcons.options_24_regular,
          title: t('התאמות נוספות'),
          subtitle: t('מפרשים, העתקה, ייצוא והדפסה, צורת הדף ותנ"ך'),
          isExpanded: _advancedOpen,
          onTap: () => setState(() => _advancedOpen = !_advancedOpen),
          children: [_buildAdvanced(context, policy)],
        ),
      ],
    );
  }

  Widget _buildAdvanced(BuildContext context, TextDisplayPolicy policy) {
    final t = context.settingsText;
    final slot = _slot;
    final layer = policy.layer(_bookClass);
    final isSeparate = layer.patchFor(slot).isNotEmpty;
    // השורש הכללי נערך למעלה; בחריץ זה המתג מיותר.
    final isGeneralRoot = !_isTanach && slot.isRoot;
    final resolved = policy.resolve(slot, isTanach: _isTanach);
    final hasOverrides =
        policy.tanach.isNotEmpty ||
        policy.general.patches.keys.any((s) => !s.isRoot);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceMD,
        vertical: AppTokens.spaceSM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _selectorRow<TextDisplayBookClass>(
            label: t('ספרים'),
            value: _bookClass,
            options: [
              SegmentOption(
                value: TextDisplayBookClass.general,
                label: t('כל הספרים'),
              ),
              SegmentOption(
                value: TextDisplayBookClass.tanach,
                label: t('תנ"ך'),
              ),
            ],
            onChanged: (v) => setState(() => _bookClass = v),
          ),
          _selectorRow<TextTarget>(
            label: t('יעד'),
            value: _target,
            options: [
              SegmentOption(value: TextTarget.body, label: t('גוף הספר')),
              SegmentOption(value: TextTarget.commentary, label: t('מפרשים')),
            ],
            onChanged: (v) => setState(() => _target = v),
          ),
          _selectorRow<TextView>(
            label: t('תצוגה'),
            value: _view,
            options: [
              SegmentOption(value: TextView.regular, label: t('רגילה')),
              SegmentOption(value: TextView.pageShape, label: t('צורת הדף')),
            ],
            onChanged: (v) => setState(() => _view = v),
          ),
          _selectorRow<TextChannel>(
            label: t('ערוץ'),
            value: _channel,
            options: [
              SegmentOption(value: TextChannel.display, label: t('תצוגה')),
              SegmentOption(value: TextChannel.copy, label: t('העתקה')),
              SegmentOption(
                value: TextChannel.export,
                label: t('ייצוא והדפסה'),
              ),
            ],
            onChanged: (v) => setState(() => _channel = v),
          ),
          const SizedBox(height: AppTokens.spaceSM),
          if (!isGeneralRoot)
            SettingsActionTile.switchTile(
              icon: FluentIcons.branch_fork_24_regular,
              title: t('הגדרות נפרדות'),
              subtitle: isSeparate
                  ? t('לחריץ זה ערכים משלו')
                  : t(
                      'יורש מהחריץ שמעליו: {parent}',
                      args: {
                        'parent': _parentLabel(context, slot),
                      },
                    ),
              value: isSeparate,
              onChanged: (value) => _update(
                value
                    ? policy.withSlot(_bookClass, slot, resolved.toPatch())
                    : policy.withLayer(_bookClass, layer.without(slot)),
              ),
            ),
          if (isGeneralRoot)
            Padding(
              padding: const EdgeInsets.all(AppTokens.spaceSM),
              child: Text(
                t('זהו החריץ הבסיסי — הוא נערך למעלה'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else if (isSeparate)
            TextDisplayProfileEditor(
              profile: resolved,
              onChanged: (profile) =>
                  _update(policy.withSlot(_bookClass, slot, profile.toPatch())),
              showAnchorMarkers: _target == TextTarget.body,
            ),
          if (hasOverrides)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ActionButton.ghost(
                text: t('איפוס כל ההתאמות הנוספות'),
                onPressed: () => _update(
                  TextDisplayPolicy(
                    general: TextDisplayLayer({
                      TextDisplaySlot.root: policy.general.patchFor(
                        TextDisplaySlot.root,
                      ),
                    }),
                    tanach: TextDisplayLayer.empty,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// תווית החריץ שממנו יורש [slot] בפועל — הראשון בשרשרת הירושה.
  String _parentLabel(BuildContext context, TextDisplaySlot slot) {
    final t = context.settingsText;
    final parent = slot.inheritanceChain.length > 1
        ? slot.inheritanceChain[1]
        : TextDisplaySlot.root;
    final target = parent.target == TextTarget.body
        ? t('גוף הספר')
        : t('מפרשים');
    final view = parent.view == TextView.regular ? t('רגילה') : t('צורת הדף');
    final channel = switch (parent.channel) {
      TextChannel.display => t('תצוגה'),
      TextChannel.copy => t('העתקה'),
      TextChannel.export => t('ייצוא והדפסה'),
    };
    final scope = _isTanach && slot.isRoot ? t('כל הספרים') : null;
    return [?scope, target, view, channel].join(' · ');
  }

  Widget _selectorRow<T>({
    required String label,
    required T value,
    required List<SegmentOption<T>> options,
    required ValueChanged<T> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceXS),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: AppSegmentedControl<T>(
              options: options,
              currentValue: value,
              onChanged: onChanged,
              expandToFillWidth: true,
              showSelectedIcon: false,
            ),
          ),
        ],
      ),
    );
  }
}
