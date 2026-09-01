import 'dart:io';
import 'dart:ui' as ui;

import 'package:custom_mouse_cursor/custom_mouse_cursor.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

/// סמני אחיזה/גרירה משותפים (דפדוף בתצוגת ספר, סידור תוספים וכד').
///
/// ב-Windows אין grab/grabbing במנוע (flutter#99323), לכן נוצר שם סמן
/// מותאם מאייקון Fluent; בשאר הפלטפורמות משתמשים בסמני המערכת.
class AppCursors {
  AppCursors._();

  static MouseCursor _grab = Platform.isWindows
      ? SystemMouseCursors.click
      : SystemMouseCursors.grab;
  static MouseCursor _grabbing = Platform.isWindows
      ? SystemMouseCursors.click
      : SystemMouseCursors.grabbing;
  static bool _initStarted = false;

  /// גודל הסמן בפיקסלים לוגיים.
  static const double _size = 18;

  /// התמונה נוצרת ב-4x כדי שהחבילה תקטין ממנה לכל DPR בפועל.
  static const double _renderDpr = 4;

  /// יד פתוחה — ריחוף על אזור אחיז.
  static MouseCursor get grab => _grab;

  /// בזמן גרירה פעילה (ב-Windows זהה ל-[grab] — אין גליף אגרוף ב-Fluent).
  static MouseCursor get grabbing => _grabbing;

  /// יוצר את הסמנים המותאמים ברקע (חד-פעמי, Windows בלבד).
  /// עד לסיום — ואם היצירה נכשלת — נשארת יד המערכת (IDC_HAND).
  static Future<void> ensureInitialized() async {
    if (_initStarted || !Platform.isWindows) return;
    _initStarted = true;

    try {
      final hotSpot = ((_size / 2) * _renderDpr).round();
      final grabCursor = await CustomMouseCursor.image(
        await _paintHandImage(),
        hotX: hotSpot,
        hotY: hotSpot,
        thisImagesDevicePixelRatio: _renderDpr,
      );
      _grab = grabCursor;
      // אין גליף אגרוף ב-Fluent — אותה יד משמשת גם בזמן גרירה.
      _grabbing = grabCursor;
    } catch (e) {
      debugPrint('AppCursors: falling back to system cursor: $e');
    }
  }

  /// מצייר את היד כמו אייקון שורת הפקדים — קווי המתאר של הגליף הרגיל
  /// בשחור, וכף היד ממולאת לבן (הגליף הממולא מתחתיו כסילואטה).
  static Future<ui.Image> _paintHandImage() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const pixelSize = _size * _renderDpr;

    void draw(IconData icon, Color color) {
      final painter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: pixelSize,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(
          (pixelSize - painter.width) / 2,
          (pixelSize - painter.height) / 2,
        ),
      );
    }

    draw(FluentIcons.hand_left_24_filled, Colors.white);
    draw(FluentIcons.hand_left_24_regular, Colors.black);

    return recorder.endRecording().toImage(
      pixelSize.round(),
      pixelSize.round(),
    );
  }
}
