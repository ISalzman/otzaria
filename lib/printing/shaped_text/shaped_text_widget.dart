/// A `pw.Widget` that draws shaped text.
///
/// It fits inside an existing document, so a print layout keeps its pages,
/// headers and page breaks and only swaps how the text itself is drawn.
library;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'pdf_shaped_font.dart';
import 'shaped_text_layout.dart';

class ShapedText extends pw.Widget {
  ShapedText(
    this.text, {
    required this.fonts,
    required this.fontSize,
    this.color = PdfColors.black,
    this.align = ShapedTextAlign.start,
    this.rtl = true,
    this.script = 'hebr',
    this.language,
    this.features,
    this.heightFactor,
  }) : assert(fonts.isNotEmpty, 'at least one font is required');

  final String text;

  /// Fonts to try per word, in order. A word goes to the first font that has a
  /// glyph for all of its characters.
  final List<PdfShapedFont> fonts;

  final double fontSize;
  final PdfColor color;
  final ShapedTextAlign align;
  final bool rtl;
  final String script;
  final String? language;
  final String? features;

  /// Line height as a multiple of the font size. Clamped up to the fonts' own
  /// line height so te'amim cannot reach into the next line.
  final double? heightFactor;

  ShapedTextBlock? _block;

  ShapedTextLayout get _layout => ShapedTextLayout(
    fonts: [for (final font in fonts) font.shaper],
    fontSize: fontSize,
    align: align,
    rtl: rtl,
    script: script,
    language: language,
    features: features,
    heightFactor: heightFactor,
  );

  /// The height this text needs at `maxWidth`, without laying it into a page.
  double measureHeight(double maxWidth) =>
      _layout.layout(text, maxWidth: maxWidth).height;

  @override
  void layout(
    pw.Context context,
    pw.BoxConstraints constraints, {
    bool parentUsesSize = false,
  }) {
    final maxWidth = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : constraints.constrainWidth();
    final block = _block = _layout.layout(text, maxWidth: maxWidth);
    box = PdfRect(0, 0, maxWidth, block.height);
  }

  @override
  void paint(pw.Context context) {
    super.paint(context);

    final block = _block;
    if (block == null || block.isEmpty) {
      return;
    }

    final canvas = context.canvas..setFillColor(color);
    final top = box!.bottom + box!.height;

    for (var index = 0; index < block.lines.length; index++) {
      final baseline = top - index * block.lineHeight - block.baselineOffset;
      for (final segment in block.lines[index].segments) {
        fonts[segment.fontIndex].drawShapedRun(
          canvas,
          segment.run,
          x: box!.left + segment.x,
          y: baseline,
          fontSize: fontSize,
        );
      }
    }
  }
}
