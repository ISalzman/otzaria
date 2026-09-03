import 'package:flutter/foundation.dart';
import 'package:otzaria/text_display/models/text_display_profile.dart';
import 'package:otzaria/text_display/models/text_display_slot.dart';

/// שכבת הגדרות: טלאי לכל חריץ. שכבה אחת לכל מקור — עקיפות הכרטיסייה,
/// קובץ הספר, סוג הספר (תנ"ך), וברירת המחדל הגלובלית.
@immutable
class TextDisplayLayer {
  final Map<TextDisplaySlot, TextDisplayPatch> _patches;

  TextDisplayLayer([Map<TextDisplaySlot, TextDisplayPatch>? patches])
    : _patches = Map.unmodifiable({
        for (final entry in (patches ?? const {}).entries)
          if (entry.value.isNotEmpty) entry.key: entry.value,
      });

  static final TextDisplayLayer empty = TextDisplayLayer();

  bool get isEmpty => _patches.isEmpty;
  bool get isNotEmpty => _patches.isNotEmpty;

  Map<TextDisplaySlot, TextDisplayPatch> get patches => _patches;

  /// הטלאי המפורש של [slot] בלבד (בלי ירושה). ריק כשאין.
  TextDisplayPatch patchFor(TextDisplaySlot slot) =>
      _patches[slot] ?? TextDisplayPatch.empty;

  /// מחזיר שכבה חדשה שבה [patch] ממוזג לתוך החריץ [slot].
  TextDisplayLayer merged(TextDisplaySlot slot, TextDisplayPatch patch) =>
      TextDisplayLayer({..._patches, slot: patchFor(slot).merge(patch)});

  /// מחזיר שכבה חדשה שבה החריץ [slot] מוחלף כולו ב-[patch].
  TextDisplayLayer withSlot(TextDisplaySlot slot, TextDisplayPatch patch) =>
      TextDisplayLayer({..._patches, slot: patch});

  /// מחזיר שכבה חדשה שבה כל טלאי עבר דרך [transform]; טלאים שהתרוקנו נמחקים.
  TextDisplayLayer mapPatches(
    TextDisplayPatch Function(TextDisplaySlot slot, TextDisplayPatch patch)
    transform,
  ) => TextDisplayLayer({
    for (final entry in _patches.entries)
      entry.key: transform(entry.key, entry.value),
  });

  /// מחזיר שכבה חדשה בלי החריץ [slot].
  TextDisplayLayer without(TextDisplaySlot slot) =>
      TextDisplayLayer({..._patches}..remove(slot));

  Map<String, dynamic> toJson() => {
    for (final entry in _patches.entries) entry.key.key: entry.value.toJson(),
  };

  /// מפתח לא מוכר או טלאי פגום מדולגים — קובץ ישן/פגום לא מפיל את הטעינה.
  factory TextDisplayLayer.fromJson(Map<String, dynamic>? json) {
    if (json == null) return TextDisplayLayer.empty;
    final patches = <TextDisplaySlot, TextDisplayPatch>{};
    for (final entry in json.entries) {
      final slot = TextDisplaySlot.fromKey(entry.key);
      final value = entry.value;
      if (slot == null || value is! Map) continue;
      patches[slot] = TextDisplayPatch.fromJson(
        Map<String, dynamic>.from(value),
      );
    }
    return TextDisplayLayer(patches);
  }

  @override
  bool operator ==(Object other) =>
      other is TextDisplayLayer && mapEquals(_patches, other._patches);

  @override
  int get hashCode => Object.hashAllUnordered(
    _patches.entries.map((e) => Object.hash(e.key, e.value)),
  );

  @override
  String toString() => 'TextDisplayLayer(${toJson()})';
}
