import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/text_book/view/widgets/continuous_reading_paragraph.dart';

void main() {
  test('buildInlineHtmlSpans יוצר recognizer לקישור inline', () async {
    final recognizers = <TapGestureRecognizer>[];

    final spans = buildInlineHtmlSpans(
      '<a href="otzaria://open/book/1">קישור</a>',
      const TextStyle(),
      onTapUrl: (_) async => true,
      recognizerSink: recognizers,
    );

    expect(spans, hasLength(1));
    expect(recognizers, hasLength(1));

    final linkSpan = spans.single as TextSpan;
    expect(linkSpan.recognizer, same(recognizers.single));
    expect(linkSpan.toPlainText(), 'קישור');

    for (final recognizer in recognizers) {
      recognizer.dispose();
    }
  });
}
