class TextSearchResult {
  final String snippet;
  final int index;
  final String query;
  final String address;

  TextSearchResult({
    required this.snippet,
    required this.index,
    required this.query,
    required this.address,
  });
}

class BookTextSearchResult extends TextSearchResult {
  final String path;
  BookTextSearchResult(
      {required this.path,
      required super.snippet,
      required super.index,
      required super.query,
      required super.address});
}
