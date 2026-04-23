import 'package:flutter/foundation.dart';
import 'package:otzaria/text_book/models/search_results.dart';
import 'package:otzaria/utils/text_manipulation.dart' as utils;

/// Maximum number of search results to return
const int _maxSearchResults = 1000;

/// Updates the address list with a new header line
void _updateAddress(List<String> address, String line) {
  if (line.length < 4) {
    address.add(line);
    return;
  }

  final index = address.indexWhere(
      (e) => e.length >= 4 && e.substring(0, 4) == line.substring(0, 4));

  if (index != -1) {
    address.removeRange(index, address.length);
  }
  address.add(line);
}

/// Search logic executed in isolate for better performance
List<TextSearchResult> _searchIsolate(Map<String, dynamic> args) {
  final List<String> content = args['content'] as List<String>;
  final String query = args['query'] as String;

  final results = <TextSearchResult>[];
  const searchStart = 0;
  final searchEnd = content.length - 1;

  final address = <String>[];
  for (int i = 0; i <= searchStart && i < content.length; i++) {
    final line = content[i];
    if (line.contains('<h') && !line.startsWith('<h1')) {
      _updateAddress(address, line);
    }
  }

  for (int i = searchStart; i <= searchEnd && i < content.length; i++) {
    final line = content[i];

    if (line.contains('<h') && !line.startsWith('<h1')) {
      _updateAddress(address, line);
    }

    final cleanLine = utils.removeVolwels(utils.stripHtmlIfNeeded(line));
    if (cleanLine.contains(query)) {
      results.add(TextSearchResult(
        index: i,
        snippet: cleanLine,
        address:
            utils.removeVolwels(utils.stripHtmlIfNeeded(address.join(', '))),
        query: query,
      ));
      if (results.length >= _maxSearchResults) break;
    }
  }

  return results;
}

/// Performs search within the provided content
Future<List<TextSearchResult>> searchInContent({
  required List<String> content,
  required String query,
}) async {
  if (query.isEmpty || content.isEmpty) return [];

  return compute(_searchIsolate, {
    'content': content,
    'query': query,
  });
}
