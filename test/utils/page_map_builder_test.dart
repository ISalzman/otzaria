import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/utils/file/page_map_builder.dart';

void main() {
  // ---------------------------------------------------------------------------
  // normalizeRef
  // ---------------------------------------------------------------------------
  group('normalizeRef', () {
    test('lowercases and trims', () {
      expect(normalizeRef('  Hello  '), 'hello');
    });

    test('collapses multiple spaces', () {
      expect(normalizeRef('a  b'), 'a b');
    });

    test('keeps slashes, dots, dashes', () {
      expect(normalizeRef('ברכות/ב.'), 'ברכות/ב.');
    });

    test('strips colons (amud-bet marker)', () {
      expect(normalizeRef('ב:'), 'ב');
    });

    test('strips other punctuation', () {
      expect(normalizeRef('ב"מ'), 'במ');
    });
  });

  // ---------------------------------------------------------------------------
  // PageMap interpolation
  // ---------------------------------------------------------------------------
  group('PageMap', () {
    test('returns null when empty', () {
      final m = PageMap([], []);
      expect(m.textToPdf(0), isNull);
      expect(m.pdfToText(1), isNull);
      expect(m.hasReliableAnchors, isFalse);
    });

    test('single anchor – always returns that anchor', () {
      final m = PageMap([5], [20]);
      expect(m.textToPdf(0), 5);
      expect(m.textToPdf(20), 5);
      expect(m.textToPdf(100), 5);
      expect(m.pdfToText(1), 20);
      expect(m.pdfToText(5), 20);
      expect(m.pdfToText(99), 20);
      expect(m.hasReliableAnchors, isFalse);
    });

    test('exact anchor hits', () {
      final m = PageMap([1, 10, 20], [0, 100, 200]);
      expect(m.textToPdf(0), 1);
      expect(m.textToPdf(100), 10);
      expect(m.textToPdf(200), 20);
      expect(m.pdfToText(1), 0);
      expect(m.pdfToText(10), 100);
      expect(m.pdfToText(20), 200);
      expect(m.hasReliableAnchors, isTrue);
    });

    test('interpolates midpoint correctly', () {
      // Anchors: pdf[1,11] ↔ text[0,100]
      // Mid text=50 → pdf = 1 + 50*(10/100) = 6
      final m = PageMap([1, 11], [0, 100]);
      expect(m.textToPdf(50), 6);
      // Mid pdf=6 → text = 0 + 5*(100/10) = 50
      expect(m.pdfToText(6), 50);
    });

    test('clamps below first anchor', () {
      final m = PageMap([5, 10], [50, 100]);
      expect(m.textToPdf(10), 5); // below first text anchor
      expect(m.pdfToText(2), 50); // below first pdf anchor
    });

    test('clamps above last anchor', () {
      final m = PageMap([5, 10], [50, 100]);
      expect(m.textToPdf(200), 10); // above last text anchor
      expect(m.pdfToText(99), 100); // above last pdf anchor
    });
  });

  // ---------------------------------------------------------------------------
  // buildPageMapFromAnchors – full-path matching
  // ---------------------------------------------------------------------------
  group('buildPageMapFromAnchors – full-path match', () {
    test('matches when paths are identical', () {
      final pdf = [(page: 3, ref: 'ברכות/ב.')];
      final text = [(index: 0, ref: 'ברכות/ב.')];
      final m = buildPageMapFromAnchors(pdf, text);
      expect(m.pdfPages, [3]);
      expect(m.textIndices, [0]);
    });

    test('no match when no ref or suffix exists in text', () {
      // PDF has "other/unknown" but text has no "unknown" leaf at all.
      final pdf = [(page: 3, ref: 'other/unknown')];
      final text = [(index: 0, ref: 'ברכות/ב.')];
      final m = buildPageMapFromAnchors(pdf, text);
      expect(m.pdfPages, isEmpty);
    });

    test('skips duplicate pdf pages', () {
      final pdf = [
        (page: 3, ref: 'ברכות/ב.'),
        (page: 3, ref: 'ברכות/ג.'), // same page
      ];
      final text = [
        (index: 0, ref: 'ברכות/ב.'),
        (index: 50, ref: 'ברכות/ג.'),
      ];
      final m = buildPageMapFromAnchors(pdf, text);
      expect(m.pdfPages.length, 1);
      expect(m.pdfPages.first, 3);
    });

    test('result is sorted by pdf page', () {
      // Supply in reverse order to verify sorting.
      final pdf = [
        (page: 10, ref: 'ג.'),
        (page: 3, ref: 'ב.'),
      ];
      final text = [
        (index: 90, ref: 'ג.'),
        (index: 0, ref: 'ב.'),
      ];
      final m = buildPageMapFromAnchors(pdf, text);
      expect(m.pdfPages, [3, 10]);
      expect(m.textIndices, [0, 90]);
    });
  });

  // ---------------------------------------------------------------------------
  // buildPageMapFromAnchors – suffix-path fallback (the new logic)
  // ---------------------------------------------------------------------------
  group('buildPageMapFromAnchors – suffix-path fallback', () {
    test('matches when PDF has extra top-level node (Gemara case)', () {
      // PDF outline: "תלמוד בבלי/ברכות/ב."
      // Text TOC:    "ברכות/ב."
      // "ברכות/ב." is a unique suffix → should match.
      final pdf = [
        (page: 3, ref: 'תלמוד בבלי/ברכות/ב.'),
        (page: 4, ref: 'תלמוד בבלי/ברכות/ב'), // amud bet (colon stripped)
        (page: 5, ref: 'תלמוד בבלי/ברכות/ג.'),
      ];
      final text = [
        (index: 0, ref: 'ברכות/ב.'),
        (index: 45, ref: 'ברכות/ב'),
        (index: 90, ref: 'ברכות/ג.'),
      ];
      final m = buildPageMapFromAnchors(pdf, text);
      expect(m.pdfPages, [3, 4, 5]);
      expect(m.textIndices, [0, 45, 90]);
    });

    test('ambiguous leaf is skipped, longer unique suffix is used', () {
      // "הקדמה" appears in both ברכות and שבת → leaf is ambiguous.
      // "ברכות/הקדמה" is unique → should be matched via 2-component suffix.
      final pdf = [
        (page: 2, ref: 'תלמוד בבלי/ברכות/הקדמה'),
        (page: 50, ref: 'תלמוד בבלי/שבת/הקדמה'),
      ];
      final text = [
        (index: 5, ref: 'ברכות/הקדמה'),
        (index: 500, ref: 'שבת/הקדמה'),
      ];
      final m = buildPageMapFromAnchors(pdf, text);
      expect(m.pdfPages, [2, 50]);
      expect(m.textIndices, [5, 500]);
    });

    test('leaf shared across tractates is not used alone', () {
      // "א" is a leaf appearing in two tractates → ambiguous → must be skipped.
      final pdf = [(page: 1, ref: 'תלמוד בבלי/ברכות/א')];
      final text = [
        (index: 0, ref: 'ברכות/א'),
        (index: 999, ref: 'שבת/א'),
      ];
      final m = buildPageMapFromAnchors(pdf, text);
      // "א" is ambiguous, "ברכות/א" is unique → should match via suffix
      expect(m.pdfPages, [1]);
      expect(m.textIndices, [0]);
    });

    test('fully ambiguous anchor produces no match', () {
      // Neither the full path nor any suffix is unique.
      final pdf = [(page: 7, ref: 'x/common')];
      final text = [
        (index: 10, ref: 'a/common'),
        (index: 20, ref: 'b/common'),
      ];
      final m = buildPageMapFromAnchors(pdf, text);
      expect(m.pdfPages, isEmpty);
    });

    test('full-path match takes priority over suffix match', () {
      // The PDF ref matches "ברכות/ב." exactly; there also happens to be a
      // different "שבת/ברכות/ב." in the text which shares the same suffix.
      // The full-path match should win.
      final pdf = [(page: 3, ref: 'ברכות/ב.')];
      final text = [
        (index: 0, ref: 'ברכות/ב.'), // exact match
        (index: 999, ref: 'שבת/ברכות/ב.'), // same suffix but different book
      ];
      final m = buildPageMapFromAnchors(pdf, text);
      expect(m.pdfPages, [3]);
      expect(m.textIndices, [0]); // exact match wins, not 999
    });
  });

  // ---------------------------------------------------------------------------
  // End-to-end: interpolation over suffix-matched anchors
  // ---------------------------------------------------------------------------
  group('end-to-end navigation', () {
    test('Gemara-like scenario: text→pdf and pdf→text', () {
      // 3 dafs matched via suffix fallback.
      // Each daf has 2 amudim (alef + bet).
      // Text indices spaced 45 apart, PDF pages spaced 1 apart.
      final pdf = [
        (page: 3, ref: 'תלמוד בבלי/ברכות/ב.'),
        (page: 4, ref: 'תלמוד בבלי/ברכות/ב'),
        (page: 5, ref: 'תלמוד בבלי/ברכות/ג.'),
        (page: 6, ref: 'תלמוד בבלי/ברכות/ג'),
      ];
      final text = [
        (index: 0, ref: 'ברכות/ב.'),
        (index: 45, ref: 'ברכות/ב'),
        (index: 90, ref: 'ברכות/ג.'),
        (index: 135, ref: 'ברכות/ג'),
      ];
      final m = buildPageMapFromAnchors(pdf, text);

      // Exact anchor points
      expect(m.textToPdf(0), 3);
      expect(m.textToPdf(45), 4);
      expect(m.textToPdf(90), 5);
      expect(m.textToPdf(135), 6);

      // Midpoint interpolation: index 22 is halfway between 0 and 45
      expect(m.textToPdf(22), 3); // still on page 3 (rounds down)
      expect(m.textToPdf(23), 4); // crosses to page 4 (rounds up)

      expect(m.pdfToText(3), 0);
      expect(m.pdfToText(4), 45);
      expect(m.pdfToText(5), 90);
    });
  });
}
