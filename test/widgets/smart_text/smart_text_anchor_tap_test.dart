import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/widgets/smart_text/render_settings.dart';
import 'package:otzaria/widgets/smart_text/smart_text_widget.dart';

// אימות שהעוגן (<a href="otzaria://anchor...">) מרונדר ב-HtmlWidget עם
// recognizer, ולחיצתו מנתבת ל-onAnchorTap עם ה-URL המלא (בלי WidgetSpan).
void main() {
  testWidgets('לחיצה על עוגן-מילה מפעילה onAnchorTap עם ה-URL', (tester) async {
    String? tappedUrl;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmartTextWidget(
            text: 'לפני <a class="link-anchor link-anchor-0" '
                'href="otzaria://anchor?ref=3_0">(א)</a> אחרי',
            settings: const RenderSettings(fontSize: 20),
            onAnchorTap: (url) => tappedUrl = url,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final recognizer = _findAnchorRecognizer(tester);
    expect(recognizer, isNotNull,
        reason: 'העוגן צריך להיות TextSpan עם TapGestureRecognizer');
    recognizer!.onTap!();
    await tester.pump();

    expect(tappedUrl, 'otzaria://anchor?ref=3_0');
  });
}

TapGestureRecognizer? _findAnchorRecognizer(WidgetTester tester) {
  for (final richText in tester.widgetList<RichText>(find.byType(RichText))) {
    final found = _searchSpan(richText.text);
    if (found != null) return found;
  }
  return null;
}

TapGestureRecognizer? _searchSpan(InlineSpan span) {
  if (span is TextSpan) {
    final recognizer = span.recognizer;
    if (recognizer is TapGestureRecognizer &&
        (span.toPlainText(includeSemanticsLabels: false)).contains('א')) {
      return recognizer;
    }
    for (final child in span.children ?? const <InlineSpan>[]) {
      final found = _searchSpan(child);
      if (found != null) return found;
    }
  }
  return null;
}
