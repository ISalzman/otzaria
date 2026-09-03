import 'package:flutter/foundation.dart';
import 'package:otzaria/text_display/models/text_display_layer.dart';
import 'package:otzaria/text_display/models/text_display_profile.dart';
import 'package:otzaria/text_display/models/text_display_slot.dart';
import 'package:otzaria/text_display/text_display_resolver.dart';
import 'package:otzaria/utils/text/text_manipulation.dart' show HolyNameStyle;

/// סוג הספר שמקבל שכבת הגדרות משלו במדיניות הגלובלית.
enum TextDisplayBookClass { general, tanach }

/// המדיניות הגלובלית של תצוגת הטקסט: שכבה כללית ושכבת תנ"ך שגוברת עליה.
///
/// זהו הערך שנשמר בהגדרות (`key-text-display-policy`). שכבת התנ"ך מחליפה את
/// ההחרגות הישנות ("הצג ניקוד בתנ"ך", "פיסוק לא חל על תנ"ך"): החרגה נכתבת
/// כטלאי על חריץ הגוף, ולצדו טלאי מפורש על המפרשים כדי שלא יירשו אותה.
@immutable
class TextDisplayPolicy {
  final TextDisplayLayer general;
  final TextDisplayLayer tanach;

  const TextDisplayPolicy({required this.general, required this.tanach});

  static final TextDisplayPolicy empty = TextDisplayPolicy(
    general: TextDisplayLayer.empty,
    tanach: TextDisplayLayer.empty,
  );

  /// השכבות הגלובליות לספר, מהספציפי לכללי.
  List<TextDisplayLayer> layersFor({required bool isTanach}) => [
    if (isTanach) tanach,
    general,
  ];

  TextDisplayLayer layer(TextDisplayBookClass bookClass) =>
      bookClass == TextDisplayBookClass.tanach ? tanach : general;

  TextDisplayPolicy withLayer(
    TextDisplayBookClass bookClass,
    TextDisplayLayer layer,
  ) => bookClass == TextDisplayBookClass.tanach
      ? TextDisplayPolicy(general: general, tanach: layer)
      : TextDisplayPolicy(general: layer, tanach: tanach);

  /// ממזג [patch] לחריץ [slot] בשכבת [bookClass].
  TextDisplayPolicy merged(
    TextDisplayBookClass bookClass,
    TextDisplaySlot slot,
    TextDisplayPatch patch,
  ) => withLayer(bookClass, layer(bookClass).merged(slot, patch));

  /// מחליף את החריץ כולו (בלי מיזוג) — לעריכה מלאה מעורך ההגדרות.
  TextDisplayPolicy withSlot(
    TextDisplayBookClass bookClass,
    TextDisplaySlot slot,
    TextDisplayPatch patch,
  ) => withLayer(bookClass, layer(bookClass).withSlot(slot, patch));

  /// הפרופיל הפתור לחריץ, בלי שכבות ספר/כרטיסייה.
  TextDisplayProfile resolve(TextDisplaySlot slot, {bool isTanach = false}) =>
      TextDisplayResolver.resolve(
        slot: slot,
        layers: layersFor(isTanach: isTanach),
      );

  // ─── תאימות למפתחות הישנים ─────────────────────────────────────────────────

  /// בונה מדיניות מששת המפתחות הישנים. `showTeamim=true` ממופה ל-followNikud
  /// כי בפועל הסרת ניקוד תמיד הסירה גם טעמים.
  factory TextDisplayPolicy.fromLegacy({
    required bool defaultRemoveNikud,
    required bool removeNikudFromTanach,
    required bool defaultRemovePunctuation,
    required bool showTeamim,
    required bool replaceHolyNames,
    required HolyNameStyle holyNameStyle,
  }) {
    var policy = TextDisplayPolicy(
      general: TextDisplayLayer({
        TextDisplaySlot.root: TextDisplayPatch(
          nikud: defaultRemoveNikud ? MarkVisibility.hide : MarkVisibility.show,
          teamim: showTeamim
              ? TeamimVisibility.followNikud
              : TeamimVisibility.hide,
          punctuation: defaultRemovePunctuation
              ? MarkVisibility.hide
              : MarkVisibility.show,
          holyName: HolyNameDisplay.fromLegacy(
            replaceHolyNames: replaceHolyNames,
            style: holyNameStyle,
          ),
        ),
      }),
      tanach: TextDisplayLayer.empty,
    );
    policy = policy.withLegacyNikudFromTanach(
      removeFromTanach: !defaultRemoveNikud || removeNikudFromTanach,
    );
    return policy.withLegacyPunctuation(defaultRemovePunctuation);
  }

  bool get defaultRemoveNikud => resolve(TextDisplaySlot.root).removeNikud;

  /// משמעותי רק כש-[defaultRemoveNikud] פעיל, כמו המפתח הישן.
  bool get removeNikudFromTanach =>
      resolve(TextDisplaySlot.root, isTanach: true).removeNikud;

  bool get defaultRemovePunctuation =>
      resolve(TextDisplaySlot.root).removePunctuation;

  bool get showTeamim =>
      resolve(TextDisplaySlot.root).teamim != TeamimVisibility.hide;

  bool get replaceHolyNames => resolve(TextDisplaySlot.root).replaceHolyNames;

  HolyNameStyle get holyNameStyle =>
      resolve(TextDisplaySlot.root).holyNameStyle;

  /// "הסתר ניקוד כברירת מחדל". כיבוי מנקה גם את החרגת התנ"ך, כי אין ממה להחריג.
  TextDisplayPolicy withLegacyDefaultRemoveNikud(bool remove) {
    final next = merged(
      TextDisplayBookClass.general,
      TextDisplaySlot.root,
      TextDisplayPatch(
        nikud: remove ? MarkVisibility.hide : MarkVisibility.show,
      ),
    );
    return remove ? next : next._clearTanachField(_Field.nikud);
  }

  /// [removeFromTanach]=false ⇒ "הצג ניקוד בתנ"ך": הגוף מנוקד, המפרשים לא.
  TextDisplayPolicy withLegacyNikudFromTanach({
    required bool removeFromTanach,
  }) {
    if (removeFromTanach) return _clearTanachField(_Field.nikud);
    return merged(
      TextDisplayBookClass.tanach,
      TextDisplaySlot.root,
      const TextDisplayPatch(nikud: MarkVisibility.show),
    ).merged(
      TextDisplayBookClass.tanach,
      TextDisplaySlot.commentaryDisplay,
      const TextDisplayPatch(nikud: MarkVisibility.hide),
    );
  }

  /// הסרת פיסוק אינה חלה על התנ"ך (אך כן על מפרשיו).
  TextDisplayPolicy withLegacyPunctuation(bool remove) {
    final next = merged(
      TextDisplayBookClass.general,
      TextDisplaySlot.root,
      TextDisplayPatch(
        punctuation: remove ? MarkVisibility.hide : MarkVisibility.show,
      ),
    );
    if (!remove) return next._clearTanachField(_Field.punctuation);
    return next
        .merged(
          TextDisplayBookClass.tanach,
          TextDisplaySlot.root,
          const TextDisplayPatch(punctuation: MarkVisibility.show),
        )
        .merged(
          TextDisplayBookClass.tanach,
          TextDisplaySlot.commentaryDisplay,
          const TextDisplayPatch(punctuation: MarkVisibility.hide),
        );
  }

  TextDisplayPolicy withLegacyShowTeamim(bool show) => merged(
    TextDisplayBookClass.general,
    TextDisplaySlot.root,
    TextDisplayPatch(
      teamim: show ? TeamimVisibility.followNikud : TeamimVisibility.hide,
    ),
  );

  TextDisplayPolicy withLegacyHolyName(HolyNameDisplay display) => merged(
    TextDisplayBookClass.general,
    TextDisplaySlot.root,
    TextDisplayPatch(holyName: display),
  );

  TextDisplayPolicy _clearTanachField(_Field field) {
    var layer = tanach;
    for (final entry in tanach.patches.entries) {
      final cleared = switch (field) {
        _Field.nikud => entry.value.copyWith(clearNikud: true),
        _Field.punctuation => entry.value.copyWith(clearPunctuation: true),
      };
      layer = cleared.isEmpty
          ? layer.without(entry.key)
          : layer.withSlot(entry.key, cleared);
    }
    return TextDisplayPolicy(general: general, tanach: layer);
  }

  Map<String, dynamic> toJson() => {
    'general': general.toJson(),
    'tanach': tanach.toJson(),
  };

  factory TextDisplayPolicy.fromJson(Map<String, dynamic> json) =>
      TextDisplayPolicy(
        general: TextDisplayLayer.fromJson(_map(json['general'])),
        tanach: TextDisplayLayer.fromJson(_map(json['tanach'])),
      );

  static Map<String, dynamic>? _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  @override
  bool operator ==(Object other) =>
      other is TextDisplayPolicy &&
      general == other.general &&
      tanach == other.tanach;

  @override
  int get hashCode => Object.hash(general, tanach);

  @override
  String toString() => 'TextDisplayPolicy(${toJson()})';
}

enum _Field { nikud, punctuation }
