import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class PdfTextRasterizer {
  PdfTextRasterizer._();

  static final RegExp _hebrewMarks = RegExp(r'[\u0591-\u05C7]');

  static bool containsHebrewMarks(String text) => _hebrewMarks.hasMatch(text);

  static Future<List<Uint8List>> renderRtlTextLines({
    required String text,
    required TextStyle style,
    required double maxWidth,
    TextAlign textAlign = TextAlign.justify,
    double pixelRatio = 3,
  }) async {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: textAlign,
      textDirection: TextDirection.rtl,
    )..layout(minWidth: maxWidth, maxWidth: maxWidth);

    final lines = painter.computeLineMetrics();
    if (lines.isEmpty) return const [];

    final logicalWidth = math.max(1.0, maxWidth);
    final imageWidth = math.max(1, (logicalWidth * pixelRatio).ceil());
    final result = <Uint8List>[];

    for (final line in lines) {
      final lineTop = math.max(0.0, line.baseline - line.ascent - 1);
      final logicalHeight = math.max(1.0, line.height + 2);
      final imageHeight = math.max(1, (logicalHeight * pixelRatio).ceil());

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.scale(pixelRatio);
      painter.paint(canvas, Offset(0, -lineTop));

      final picture = recorder.endRecording();
      final image = await picture.toImage(imageWidth, imageHeight);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();

      if (bytes != null) {
        result.add(bytes.buffer.asUint8List());
      }
    }

    return result;
  }
}
