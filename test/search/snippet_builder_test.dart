import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/search/utils/snippet_builder.dart';

void main() {
  test('SnippetBuilder שומר גרשיים בתצוגת ראשי תיבות', () {
    final spans = SnippetBuilder.createSnippetSpans(
      fullHtml: '<p>רש"י אומר</p>',
      query: 'רשי',
      defaultStyle: const TextStyle(),
      highlightStyle: const TextStyle(fontWeight: FontWeight.bold),
      availableWidth: 400,
      searchOptions: const {},
      alternativeWords: const {},
    );

    final renderedText =
        spans.whereType<TextSpan>().map((span) => span.text ?? '').join();

    expect(renderedText, contains('רש"י'));
  });

  test('SnippetBuilder מדגיש גם התאמה דומה כשהופעלו שגיאות כתיב', () {
    final spans = SnippetBuilder.createSnippetSpans(
      fullHtml: '<p>שלום לכל העולם</p>',
      query: 'שלומ',
      defaultStyle: const TextStyle(),
      highlightStyle: const TextStyle(fontWeight: FontWeight.bold),
      availableWidth: 400,
      searchOptions: const {},
      alternativeWords: const {},
      typoToleranceEnabled: true,
    );

    final highlighted = spans
        .whereType<TextSpan>()
        .where((span) => span.style?.fontWeight == FontWeight.bold)
        .map((span) => span.text ?? '')
        .join();

    expect(highlighted, contains('שלום'));
  });

  test('SnippetBuilder לא מרחיב את הקטע לטוקנים דומים רחוקים', () {
    final spans = SnippetBuilder.createSnippetSpans(
      fullHtml: '<p>שלון ${'אבגדה ' * 80} שלום לכל העולם</p>',
      query: 'שלומ',
      defaultStyle: const TextStyle(),
      highlightStyle: const TextStyle(fontWeight: FontWeight.bold),
      availableWidth: 220,
      searchOptions: const {},
      alternativeWords: const {},
      typoToleranceEnabled: true,
    );

    final renderedText =
        spans.whereType<TextSpan>().map((span) => span.text ?? '').join();

    expect(renderedText, contains('שלום'));
    expect(renderedText, isNot(contains('שלון')));
  });

  test('SnippetBuilder לא מוסיף התאמה דומה רחוקה כשיש התאמה מדויקת', () {
    final spans = SnippetBuilder.createSnippetSpans(
      fullHtml: '<p>שלומ ${'אבגדה ' * 80} שלום לכל העולם</p>',
      query: 'שלום',
      defaultStyle: const TextStyle(),
      highlightStyle: const TextStyle(fontWeight: FontWeight.bold),
      availableWidth: 220,
      searchOptions: const {},
      alternativeWords: const {},
      typoToleranceEnabled: true,
    );

    final renderedText =
        spans.whereType<TextSpan>().map((span) => span.text ?? '').join();

    expect(renderedText, contains('שלום'));
    expect(renderedText, isNot(contains('שלומ')));
  });

  test('SnippetBuilder מדגיש phrase עם custom spacing בין מילים', () {
    final spans = SnippetBuilder.createSnippetSpans(
      fullHtml: '<p>אבג מילה1 מילה2 דהו</p>',
      query: 'אבג דהו',
      defaultStyle: const TextStyle(),
      highlightStyle: const TextStyle(fontWeight: FontWeight.bold),
      availableWidth: 400,
      searchOptions: const {},
      alternativeWords: const {},
      customSpacing: const {'0-1': '2'},
    );

    final highlighted = spans
        .whereType<TextSpan>()
        .where((span) => span.style?.fontWeight == FontWeight.bold)
        .map((span) => span.text ?? '')
        .join('|');

    expect(highlighted, contains('אבג'));
    expect(highlighted, contains('דהו'));
  });

  test('SnippetBuilder לא מדגיש הופעות בודדות כש-custom spacing לא מספיק', () {
    final spans = SnippetBuilder.createSnippetSpans(
      fullHtml: '<p>אבג מילה1 מילה2 מילה3 דהו</p>',
      query: 'אבג דהו',
      defaultStyle: const TextStyle(),
      highlightStyle: const TextStyle(fontWeight: FontWeight.bold),
      availableWidth: 400,
      searchOptions: const {},
      alternativeWords: const {},
      customSpacing: const {'0-1': '2'},
    );

    final highlighted = spans
        .whereType<TextSpan>()
        .where((span) => span.style?.fontWeight == FontWeight.bold)
        .map((span) => span.text ?? '')
        .join();

    final renderedText =
        spans.whereType<TextSpan>().map((span) => span.text ?? '').join();

    expect(renderedText, contains('אבג'));
    expect(renderedText, contains('דהו'));
    expect(highlighted, isEmpty);
  });
}
