import 'package:flutter/material.dart';
import 'package:otzaria/data/repository/data_repository.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/utils/file/page_map_builder.dart';
import 'package:pdfrx/pdfrx.dart';

// A cache for the generated page maps to avoid rebuilding them on every conversion.
final _pageMapCache = <String, PageMap>{};

/// Converts a text book page index to the corresponding PDF page number.
///
/// This function uses a cached, anchor-based map with local interpolation for accuracy and performance.
Future<int?> textToPdfPage(TextBook textBook, int textIndex) async {
  final pdfBook = (await DataRepository.instance.library)
      .getCompanionBook(textBook, PdfBook) as PdfBook?;
  if (pdfBook == null) {
    return null;
  }

  final key = '${pdfBook.path}::${textBook.title}';
  final cached = _pageMapCache[key];
  if (cached != null) {
    if (!cached.hasReliableAnchors) {
      return null;
    }
    return cached.textToPdf(textIndex);
  }

  try {
    // It's better to get the outline from a provider/tab if available than to load it every time.
    // For now, we load it directly as a fallback.
    final outline = await PdfDocument.openFile(pdfBook.path)
        .then((doc) => doc.loadOutline());
    final map =
        _pageMapCache[key] ??= await _buildPageMap(pdfBook, outline, textBook);
    if (!map.hasReliableAnchors) {
      return null;
    }

    return map.textToPdf(textIndex);
  } catch (e) {
    // If PDF is password protected or cannot be opened, return null
    // The PDF will open with password dialog when user clicks the button
    return null;
  }
}

/// Converts a PDF page number to the corresponding text book index.
///
/// This function uses a cached, anchor-based map with local interpolation for accuracy and performance.
Future<int?> pdfToTextPage(PdfBook pdfBook, List<PdfOutlineNode> outline,
    int pdfPage, BuildContext ctx) async {
  final textBook = (await DataRepository.instance.library)
      .getCompanionBook(pdfBook, TextBook) as TextBook?;
  if (textBook == null) {
    return null;
  }
  final key = '${pdfBook.path}::${textBook.title}';
  final map =
      _pageMapCache[key] ??= await _buildPageMap(pdfBook, outline, textBook);
  if (!map.hasReliableAnchors) {
    return null;
  }

  return map.pdfToText(pdfPage);
}

/// Builds the synchronized anchor map from PDF outline and text Table of Contents.
Future<PageMap> _buildPageMap(
    PdfBook pdf, List<PdfOutlineNode> outline, TextBook text) async {
  final anchorsPdf = collectPdfAnchors(outline);
  final toc = await text.tableOfContents;
  final anchorsText = collectTextAnchors(toc);

  final map = buildPageMapFromAnchors(anchorsPdf, anchorsText);

  debugPrint(
      '🗺️ [PDF-DEBUG] _buildPageMap "${pdf.title}": pdfAnchors=${anchorsPdf.length}, textAnchors=${anchorsText.length}, matched=${map.pdfPages.length}');
  if (map.pdfPages.isNotEmpty) {
    debugPrint(
        '🗺️ [PDF-DEBUG] First 5 matches: ${List.generate(map.pdfPages.length > 5 ? 5 : map.pdfPages.length, (i) => "pdf${map.pdfPages[i]}→txt${map.textIndices[i]}").join(", ")}');
  }
  if (anchorsPdf.isNotEmpty &&
      anchorsText.isNotEmpty &&
      map.pdfPages.length < 3) {
    debugPrint(
        '🗺️ [PDF-DEBUG] ⚠️ POOR MATCH! PDF sample refs: ${anchorsPdf.take(3).map((a) => '"${a.ref}"').join(", ")}');
    debugPrint(
        '🗺️ [PDF-DEBUG] ⚠️ Text sample refs: ${anchorsText.take(3).map((a) => '"${a.ref}"').join(", ")}');
  }

  // Fallback: if no anchors matched, anchor to page 1 / index 0.
  if (map.pdfPages.isEmpty) {
    return PageMap([1], [0]);
  }

  return map;
}

/// אוסף עוגנים (עמוד + נתיב מנורמל) מתוך ה-outline של ה-PDF, רקורסיבית.
///
/// צמתים ללא יעד (dest) או עם מספר עמוד לא חוקי מדולגים יחד עם תתי-העץ שלהם.
List<({int page, String ref})> collectPdfAnchors(List<PdfOutlineNode> nodes,
    [String prefix = '']) {
  final List<({int page, String ref})> anchors = [];
  for (final node in nodes) {
    final page = node.dest?.pageNumber;
    if (page != null && page > 0) {
      final currentPath =
          prefix.isEmpty ? node.title.trim() : '$prefix/${node.title.trim()}';
      anchors.add((page: page, ref: normalizeRef(currentPath)));
      anchors.addAll(collectPdfAnchors(node.children, currentPath));
    }
  }
  return anchors;
}

/// אוסף עוגנים (אינדקס שורה + נתיב מנורמל) מתוכן העניינים של ספר טקסט, רקורסיבית.
List<({int index, String ref})> collectTextAnchors(List<TocEntry> entries,
    [String prefix = '']) {
  final List<({int index, String ref})> anchors = [];
  for (final entry in entries) {
    final currentPath =
        prefix.isEmpty ? entry.text.trim() : '$prefix/${entry.text.trim()}';
    anchors.add((index: entry.index, ref: normalizeRef(currentPath)));
    anchors.addAll(collectTextAnchors(entry.children, currentPath));
  }
  return anchors;
}
