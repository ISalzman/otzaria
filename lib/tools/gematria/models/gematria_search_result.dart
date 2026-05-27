import 'package:otzaria/tools/gematria/gematria_search.dart';

class GematriaSearchResult {
  final String bookTitle;
  final String internalPath;
  final String preview;
  final SearchResult data;

  const GematriaSearchResult({
    required this.bookTitle,
    required this.internalPath,
    this.preview = '',
    required this.data,
  });
}
