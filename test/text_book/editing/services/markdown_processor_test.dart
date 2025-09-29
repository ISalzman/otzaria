import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/text_book/editing/services/markdown_processor.dart';

void main() {
  group('MarkdownProcessor', () {
    late MarkdownProcessor processor;

    setUp(() {
      processor = const MarkdownProcessor();
    });

    group('Basic Markdown Conversion', () {
      test('should convert headers', () {
        const markdown = '''# Header 1
## Header 2
### Header 3''';

        final html = processor.markdownToHtml(markdown);

        expect(html, contains('<h1>Header 1</h1>'));
        expect(html, contains('<h2>Header 2</h2>'));
        expect(html, contains('<h3>Header 3</h3>'));
      });

      test('should convert bold and italic', () {
        const markdown = '**bold text** and *italic text*';

        final html = processor.markdownToHtml(markdown);

        expect(html, contains('<strong>bold text</strong>'));
        expect(html, contains('<em>italic text</em>'));
      });

      test('should convert links', () {
        const markdown = '[link text](https://example.com)';

        final html = processor.markdownToHtml(markdown);

        expect(html, contains('<a href="https://example.com">link text</a>'));
      });

      test('should convert code blocks', () {
        const markdown = '''```
code block
```''';

        final html = processor.markdownToHtml(markdown);

        expect(html, contains('<pre><code>'));
        expect(html, contains('code block'));
        expect(html, contains('</code></pre>'));
      });

      test('should convert inline code', () {
        const markdown = 'This is `inline code` text';

        final html = processor.markdownToHtml(markdown);

        expect(html, contains('<code>inline code</code>'));
      });

      test('should convert blockquotes', () {
        const markdown = '> This is a quote';

        final html = processor.markdownToHtml(markdown);

        expect(html, contains('<blockquote>This is a quote</blockquote>'));
      });

      test('should convert lists', () {
        const markdown = '''- Item 1
- Item 2''';

        final html = processor.markdownToHtml(markdown);

        expect(html, contains('<ul>'));
        expect(html, contains('<li>Item 1</li>'));
        expect(html, contains('<li>Item 2</li>'));
        expect(html, contains('</ul>'));
      });
    });

    group('HTML Sanitization', () {
      test('should remove script tags', () {
        const html = '<p>Safe content</p><script>alert("xss")</script>';

        final sanitized = processor.sanitizeHtml(html);

        expect(sanitized, contains('Safe content'));
        expect(sanitized, isNot(contains('<script>')));
        expect(sanitized, isNot(contains('alert')));
      });

      test('should remove dangerous attributes', () {
        const html = '<p onclick="alert(\'xss\')">Content</p>';

        final sanitized = processor.sanitizeHtml(html);

        expect(sanitized, contains('Content'));
        expect(sanitized, isNot(contains('onclick')));
      });

      test('should allow safe tags and attributes', () {
        const html =
            '<p dir="rtl"><strong>Bold</strong> and <em>italic</em></p>';

        final sanitized = processor.sanitizeHtml(html);

        expect(sanitized, contains('<p dir="rtl">'));
        expect(sanitized, contains('<strong>Bold</strong>'));
        expect(sanitized, contains('<em>italic</em>'));
      });

      test('should handle empty input', () {
        final result = processor.markdownToHtml('');
        expect(result, equals(''));
      });

      test('should escape HTML in plain text', () {
        const markdown = 'Text with <script> tags';

        final html = processor.markdownToHtml(markdown);

        expect(html, contains('&lt;script&gt;'));
        expect(html, isNot(contains('<script>')));
      });
    });

    group('RTL Text Direction', () {
      test('should wrap content in RTL container', () {
        const markdown = 'Hebrew text';

        final html = processor.markdownToHtml(markdown);

        expect(html, contains('dir="rtl"'));
      });

      test('should set code blocks to LTR', () {
        const markdown = '`code`';

        final html = processor.markdownToHtml(markdown);

        expect(html, contains('<code dir="ltr">'));
      });
    });

    group('Error Handling', () {
      test('should handle malformed HTML gracefully', () {
        const malformed = '<p>Unclosed tag';

        final sanitized = processor.sanitizeHtml(malformed);

        expect(sanitized, isA<String>());
        expect(sanitized, isNot(isEmpty));
      });
    });
  });
}
