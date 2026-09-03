import 'package:flutter/foundation.dart';
import 'package:otzaria/utils/text/text_manipulation.dart' show HolyNameStyle;

/// הצגה/הסתרה של קבוצת סימנים (ניקוד, פיסוק, ציוני מפרשים).
enum MarkVisibility {
  show,
  hide;

  static MarkVisibility? fromJson(Object? value) => switch (value) {
    'show' => MarkVisibility.show,
    'hide' => MarkVisibility.hide,
    _ => null,
  };
}

/// הצגת הטעמים. [followNikud] — הטעמים מוסתרים יחד עם הניקוד ומוצגים איתו.
enum TeamimVisibility {
  show,
  hide,
  followNikud;

  static TeamimVisibility? fromJson(Object? value) => switch (value) {
    'show' => TeamimVisibility.show,
    'hide' => TeamimVisibility.hide,
    'followNikud' => TeamimVisibility.followNikud,
    _ => null,
  };
}

/// הצגת שם הוי"ה: ככתבו, או מוחלף באחד הסגנונות של [HolyNameStyle].
enum HolyNameDisplay {
  asIs,
  kufKuf,
  hehApostrophe;

  /// null = הצגה ככתבו (אין החלפה).
  HolyNameStyle? get style => switch (this) {
    HolyNameDisplay.asIs => null,
    HolyNameDisplay.kufKuf => HolyNameStyle.kufKuf,
    HolyNameDisplay.hehApostrophe => HolyNameStyle.hehApostrophe,
  };

  static HolyNameDisplay fromLegacy({
    required bool replaceHolyNames,
    required HolyNameStyle style,
  }) {
    if (!replaceHolyNames) return HolyNameDisplay.asIs;
    return style == HolyNameStyle.hehApostrophe
        ? HolyNameDisplay.hehApostrophe
        : HolyNameDisplay.kufKuf;
  }

  static HolyNameDisplay? fromJson(Object? value) => switch (value) {
    'asIs' => HolyNameDisplay.asIs,
    'kufKuf' => HolyNameDisplay.kufKuf,
    'hehApostrophe' => HolyNameDisplay.hehApostrophe,
    _ => null,
  };
}

/// פרופיל תצוגת טקסט מלא — מה מוצג ומה מוסתר בטקסט עברי.
///
/// זהו הערך שכל צרכן (רינדור, העתקה, ייצוא) מקבל פתור, בלי שדות חסרים.
/// הרכבתו מטלאים חלקיים נעשית ב-`TextDisplayResolver`.
@immutable
class TextDisplayProfile {
  final MarkVisibility nikud;
  final TeamimVisibility teamim;
  final MarkVisibility punctuation;
  final HolyNameDisplay holyName;

  /// ציוני המפרשים בגוף הטקסט — אותיות העוגן, למשל (א).
  final MarkVisibility anchorMarkers;

  const TextDisplayProfile({
    this.nikud = MarkVisibility.show,
    this.teamim = TeamimVisibility.followNikud,
    this.punctuation = MarkVisibility.show,
    this.holyName = HolyNameDisplay.kufKuf,
    this.anchorMarkers = MarkVisibility.show,
  });

  /// ברירת המחדל של התוכנה: הכול מוצג, שם הוי"ה מוחלף ביקוק.
  static const TextDisplayProfile defaults = TextDisplayProfile();

  bool get removeNikud => nikud == MarkVisibility.hide;

  bool get removeTeamim => switch (teamim) {
    TeamimVisibility.show => false,
    TeamimVisibility.hide => true,
    TeamimVisibility.followNikud => removeNikud,
  };

  bool get removePunctuation => punctuation == MarkVisibility.hide;
  bool get replaceHolyNames => holyName != HolyNameDisplay.asIs;
  HolyNameStyle get holyNameStyle => holyName.style ?? HolyNameStyle.kufKuf;
  bool get showAnchorMarkers => anchorMarkers == MarkVisibility.show;

  TextDisplayProfile copyWith({
    MarkVisibility? nikud,
    TeamimVisibility? teamim,
    MarkVisibility? punctuation,
    HolyNameDisplay? holyName,
    MarkVisibility? anchorMarkers,
  }) {
    return TextDisplayProfile(
      nikud: nikud ?? this.nikud,
      teamim: teamim ?? this.teamim,
      punctuation: punctuation ?? this.punctuation,
      holyName: holyName ?? this.holyName,
      anchorMarkers: anchorMarkers ?? this.anchorMarkers,
    );
  }

  /// הטלאי שמייצג את הפרופיל במלואו (כל השדות מלאים).
  TextDisplayPatch toPatch() => TextDisplayPatch(
    nikud: nikud,
    teamim: teamim,
    punctuation: punctuation,
    holyName: holyName,
    anchorMarkers: anchorMarkers,
  );

  @override
  bool operator ==(Object other) =>
      other is TextDisplayProfile &&
      nikud == other.nikud &&
      teamim == other.teamim &&
      punctuation == other.punctuation &&
      holyName == other.holyName &&
      anchorMarkers == other.anchorMarkers;

  @override
  int get hashCode =>
      Object.hash(nikud, teamim, punctuation, holyName, anchorMarkers);

  @override
  String toString() =>
      'TextDisplayProfile(nikud: ${nikud.name}, teamim: ${teamim.name}, '
      'punctuation: ${punctuation.name}, holyName: ${holyName.name}, '
      'anchorMarkers: ${anchorMarkers.name})';
}

/// טלאי חלקי על פרופיל: שדה null = "ירש מלמעלה".
@immutable
class TextDisplayPatch {
  final MarkVisibility? nikud;
  final TeamimVisibility? teamim;
  final MarkVisibility? punctuation;
  final HolyNameDisplay? holyName;
  final MarkVisibility? anchorMarkers;

  const TextDisplayPatch({
    this.nikud,
    this.teamim,
    this.punctuation,
    this.holyName,
    this.anchorMarkers,
  });

  static const TextDisplayPatch empty = TextDisplayPatch();

  bool get isEmpty =>
      nikud == null &&
      teamim == null &&
      punctuation == null &&
      holyName == null &&
      anchorMarkers == null;

  bool get isNotEmpty => !isEmpty;

  /// מיזוג: השדות של [other] גוברים על השדות של הטלאי הנוכחי.
  TextDisplayPatch merge(TextDisplayPatch other) => TextDisplayPatch(
    nikud: other.nikud ?? nikud,
    teamim: other.teamim ?? teamim,
    punctuation: other.punctuation ?? punctuation,
    holyName: other.holyName ?? holyName,
    anchorMarkers: other.anchorMarkers ?? anchorMarkers,
  );

  /// הפרופיל שמתקבל מהחלת הטלאי על [base].
  TextDisplayProfile applyTo(TextDisplayProfile base) => base.copyWith(
    nikud: nikud,
    teamim: teamim,
    punctuation: punctuation,
    holyName: holyName,
    anchorMarkers: anchorMarkers,
  );

  /// עותק שבו השדות ששווים ל-[base] נמחקים — כך שהטלאי מכיל רק סטיות
  /// אמיתיות והספר יירש שינויים עתידיים בברירת המחדל.
  TextDisplayPatch pruneAgainst(TextDisplayProfile base) => TextDisplayPatch(
    nikud: nikud == base.nikud ? null : nikud,
    teamim: teamim == base.teamim ? null : teamim,
    punctuation: punctuation == base.punctuation ? null : punctuation,
    holyName: holyName == base.holyName ? null : holyName,
    anchorMarkers: anchorMarkers == base.anchorMarkers ? null : anchorMarkers,
  );

  TextDisplayPatch copyWith({
    MarkVisibility? nikud,
    TeamimVisibility? teamim,
    MarkVisibility? punctuation,
    HolyNameDisplay? holyName,
    MarkVisibility? anchorMarkers,
    bool clearNikud = false,
    bool clearTeamim = false,
    bool clearPunctuation = false,
    bool clearHolyName = false,
    bool clearAnchorMarkers = false,
  }) {
    return TextDisplayPatch(
      nikud: clearNikud ? null : (nikud ?? this.nikud),
      teamim: clearTeamim ? null : (teamim ?? this.teamim),
      punctuation: clearPunctuation ? null : (punctuation ?? this.punctuation),
      holyName: clearHolyName ? null : (holyName ?? this.holyName),
      anchorMarkers: clearAnchorMarkers
          ? null
          : (anchorMarkers ?? this.anchorMarkers),
    );
  }

  Map<String, dynamic> toJson() => {
    if (nikud != null) 'nikud': nikud!.name,
    if (teamim != null) 'teamim': teamim!.name,
    if (punctuation != null) 'punctuation': punctuation!.name,
    if (holyName != null) 'holyName': holyName!.name,
    if (anchorMarkers != null) 'anchorMarkers': anchorMarkers!.name,
  };

  /// ערך לא מוכר בשדה נחשב null (ירושה) — קובץ פגום לא מפיל את הטעינה.
  factory TextDisplayPatch.fromJson(Map<String, dynamic> json) =>
      TextDisplayPatch(
        nikud: MarkVisibility.fromJson(json['nikud']),
        teamim: TeamimVisibility.fromJson(json['teamim']),
        punctuation: MarkVisibility.fromJson(json['punctuation']),
        holyName: HolyNameDisplay.fromJson(json['holyName']),
        anchorMarkers: MarkVisibility.fromJson(json['anchorMarkers']),
      );

  @override
  bool operator ==(Object other) =>
      other is TextDisplayPatch &&
      nikud == other.nikud &&
      teamim == other.teamim &&
      punctuation == other.punctuation &&
      holyName == other.holyName &&
      anchorMarkers == other.anchorMarkers;

  @override
  int get hashCode =>
      Object.hash(nikud, teamim, punctuation, holyName, anchorMarkers);

  @override
  String toString() => 'TextDisplayPatch(${toJson()})';
}
