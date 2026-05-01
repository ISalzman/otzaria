import 'package:otzaria/models/books.dart';
import 'package:otzaria/search/models/search_configuration.dart';
import 'package:otzaria/utils/file/hive_utils.dart';

/// Represents a bookmark in the application.
class Bookmark {
  final String ref;
  final Book book;
  final List<String> commentatorsToShow;
  final int index;
  final bool isSearch;
  final Map<String, Map<String, bool>>? searchOptions;
  final Map<int, List<String>>? alternativeWords;
  final Map<String, String>? spacingValues;
  final String? workspaceName;
  final List<String>? searchScopeFacets;
  final SearchMode? searchMode;
  final bool typoToleranceEnabled;

  /// A stable key for history management, unique per book title.
  String get historyKey => isSearch ? ref : book.title;

  Bookmark({
    required this.ref,
    required this.book,
    required this.index,
    this.commentatorsToShow = const [],
    this.isSearch = false,
    this.searchOptions,
    this.alternativeWords,
    this.spacingValues,
    this.workspaceName,
    this.searchScopeFacets,
    this.searchMode,
    this.typoToleranceEnabled = false,
  });

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    final rawCommentators = json['commentatorsToShow'] as List<dynamic>?;
    return Bookmark(
      ref: json['ref'] as String,
      index: json['index'] as int,
      book: Book.fromJson(castMap(json['book'])),
      commentatorsToShow:
          (rawCommentators ?? []).map((e) => e.toString()).toList(),
      isSearch: json['isSearch'] ?? false,
      searchOptions: json['searchOptions'] != null
          ? castMap(json['searchOptions']).map(
              (key, value) => MapEntry(
                key,
                (castMap(value)).map((k, v) => MapEntry(k, v as bool)),
              ),
            )
          : null,
      alternativeWords: json['alternativeWords'] != null
          ? castMap(json['alternativeWords']).map(
              (key, value) => MapEntry(
                int.parse(key),
                (value as List<dynamic>).map((e) => e.toString()).toList(),
              ),
            )
          : null,
      spacingValues: json['spacingValues'] != null
          ? castMap(json['spacingValues'])
              .map((key, value) => MapEntry(key, value.toString()))
          : null,
      workspaceName: json['workspaceName'] as String?,
      searchScopeFacets: json['searchScopeFacets'] != null
          ? List<String>.from(json['searchScopeFacets'] as List)
          : null,
      searchMode: json['searchMode'] != null
          ? SearchMode.values.firstWhere(
              (mode) => mode.name == json['searchMode'],
              orElse: () => SearchMode.advanced,
            )
          : null,
      typoToleranceEnabled: json['typoToleranceEnabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ref': ref,
      'book': book.toJson(),
      'index': index,
      'commentatorsToShow': commentatorsToShow,
      'isSearch': isSearch,
      'searchOptions': searchOptions,
      'alternativeWords': alternativeWords
          ?.map((key, value) => MapEntry(key.toString(), value)),
      'spacingValues': spacingValues,
      'workspaceName': workspaceName,
      'searchScopeFacets': searchScopeFacets,
      'searchMode': searchMode?.name,
      'typoToleranceEnabled': typoToleranceEnabled,
    };
  }
}
