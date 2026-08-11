import 'package:otzaria/data/repository/data_repository.dart';
import 'package:otzaria/external_catalog/repository/external_catalog_repository.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/plugins/declarative/services/declarative_host_action_executor.dart';
import 'package:otzaria/plugins/declarative/services/declarative_program_executor.dart';
import 'package:otzaria/plugins/models/plugin_book_identity.dart';
import 'package:otzaria/utils/navigation/book_open_coordinator.dart';

typedef DeclarativeBookListLoader = Future<List<Book>> Function();
typedef DeclarativeExternalBookListLoader =
    Future<List<Book>> Function(String provider, Set<Object> externalIds);
typedef DeclarativeBookOpen =
    void Function(Book book, int index, String searchQuery);

class DeclarativeLibraryBookAccess
    implements DeclarativeBookResolver, DeclarativeBookOpener {
  final DeclarativeBookListLoader _libraryBooks;
  final DeclarativeExternalBookListLoader _externalBooks;
  final DeclarativeBookOpen _openBook;

  DeclarativeLibraryBookAccess(
    this._libraryBooks,
    this._externalBooks,
    this._openBook,
  );

  factory DeclarativeLibraryBookAccess.otzaria(
    BookOpenCoordinator coordinator,
  ) {
    return DeclarativeLibraryBookAccess(
      () async => (await DataRepository.instance.library).getAllBooks(),
      (provider, externalIds) => switch (provider) {
        'hebrewbooks' => _loadHebrewBooksByIds(externalIds),
        'otzar' => DataRepository.instance.otzarBooks,
        _ => Future.value(const <Book>[]),
      },
      (book, index, searchQuery) => coordinator.openBook(
        book,
        index,
        searchQuery,
        ignoreHistory: true,
        requiresStableLayout: book is PdfBook,
      ),
    );
  }

  @override
  Future<List<Map<String, dynamic>?>> resolveUniqueBatch(
    List<Map<String, dynamic>> identities,
  ) async {
    final books = await findUniqueBooks(identities);
    return [
      for (final book in books)
        if (book == null) null else PluginBookIdentity.toJson(book),
    ];
  }

  Future<Map<String, dynamic>?> resolveUnique(
    Map<String, dynamic> identity,
  ) async {
    final book = (await findUniqueBooks([identity])).single;
    return book == null ? null : PluginBookIdentity.toJson(book);
  }

  @override
  Future<bool> openUnique(
    Map<String, dynamic> identity, {
    required int index,
    required String searchQuery,
  }) async {
    final book = (await findUniqueBooks([identity])).single;
    if (book == null) return false;
    _openBook(book, index, searchQuery);
    return true;
  }

  /// פותר אצווה של זהויות לספרים בלי לחשוף נתיבים או לבצע פתיחה.
  Future<List<Book?>> findUniqueBooks(
    List<Map<String, dynamic>> identities,
  ) async {
    final parsed = [
      for (final identity in identities) _parseIdentity(identity),
    ];
    final needsLibrary = parsed.any(
      (identity) => identity != null && identity.external == null,
    );
    final externalIds = <String, Set<Object>>{};
    for (final identity in parsed) {
      final external = identity?.external;
      if (external != null) {
        externalIds.putIfAbsent(external.provider, () => {}).add(external.id);
      }
    }

    final libraryFuture = needsLibrary ? _libraryBooks() : null;
    final externalFutures = {
      for (final entry in externalIds.entries)
        entry.key: _externalBooks(entry.key, Set.unmodifiable(entry.value)),
    };
    final libraryIndex = libraryFuture == null
        ? null
        : _BookLookupIndex(await libraryFuture);
    final externalIndexes = <String, _BookLookupIndex>{};
    for (final entry in externalFutures.entries) {
      externalIndexes[entry.key] = _BookLookupIndex(await entry.value);
    }

    return [
      for (final identity in parsed)
        if (identity == null)
          null
        else if (identity.external case final external?)
          externalIndexes[external.provider]?.findUnique(identity)
        else
          libraryIndex?.findUnique(identity),
    ];
  }

  _ParsedBookIdentity? _parseIdentity(Map<String, dynamic> identity) {
    const allowed = {'id', 'bookId', 'type', 'source', 'external'};
    if (identity.keys.any((key) => !allowed.contains(key))) return null;
    final id = PluginBookIdentity.parseId(identity['id']);
    if (identity.containsKey('id') && id == null) return null;
    final bookId = identity['bookId'];
    final type = identity['type'];
    final source = identity['source'];
    if ((bookId != null && bookId is! String) ||
        (type != null && type is! String) ||
        (source != null && source is! String)) {
      return null;
    }
    final external = _parseExternal(identity['external']);
    if (identity['external'] != null && external == null) return null;
    if (id == null && bookId == null && external == null) return null;
    return (
      id: id,
      bookId: bookId as String?,
      type: type as String?,
      source: source as String?,
      external: external,
    );
  }

  ({String provider, Object id})? _parseExternal(Object? value) {
    if (value is! Map || value.length != 2) return null;
    final provider = value['provider'];
    final id = value['id'];
    if (provider is! String ||
        !const {'hebrewbooks', 'otzar'}.contains(provider) ||
        (id is! int && (id is! String || id.isEmpty))) {
      return null;
    }
    return (provider: provider, id: id);
  }
}

typedef _ParsedBookIdentity = ({
  int? id,
  String? bookId,
  String? type,
  String? source,
  ({String provider, Object id})? external,
});

class _BookLookupIndex {
  final Map<int, List<Book>> _byId = {};
  final Map<String, List<Book>> _byBookId = {};
  final Map<String, List<Book>> _byExternal = {};

  _BookLookupIndex(List<Book> books) {
    for (final book in books) {
      if (book.id case final id?) {
        _byId.putIfAbsent(id, () => []).add(book);
      }
      _byBookId.putIfAbsent(book.title, () => []).add(book);
      if (PluginBookIdentity.externalOf(book) case final external?) {
        _byExternal.putIfAbsent(_externalKey(external), () => []).add(book);
      }
    }
  }

  Book? findUnique(_ParsedBookIdentity identity) {
    final List<Book>? candidates;
    if (identity.external case final external?) {
      candidates = _byExternal[_externalKey(external)];
    } else if (identity.id case final id?) {
      candidates = _byId[id];
    } else if (identity.bookId case final bookId?) {
      candidates = _byBookId[bookId];
    } else {
      candidates = null;
    }
    if (candidates == null) return null;
    Book? match;
    for (final book in candidates) {
      if (!PluginBookIdentity.matches(
        book,
        id: identity.id,
        bookId: identity.bookId,
        type: identity.type,
        source: identity.source,
      )) {
        continue;
      }
      if (match != null) return null;
      match = book;
    }
    return match;
  }

  static String _externalKey(({String provider, Object id}) external) =>
      '${external.provider}:${external.id}';
}

Future<List<Book>> _loadHebrewBooksByIds(Set<Object> externalIds) async {
  final ids = externalIds.map(PluginBookIdentity.parseId).nonNulls.toSet();
  if (ids.isEmpty) return const [];
  final localMatches = (await DataRepository.instance.localHebrewBooks).where((
    book,
  ) {
    final external = PluginBookIdentity.externalOf(book);
    return external?.provider == 'hebrewbooks' &&
        ids.contains(PluginBookIdentity.parseId(external?.id));
  }).toList();
  final localIds = localMatches
      .map(PluginBookIdentity.externalOf)
      .nonNulls
      .map((external) => PluginBookIdentity.parseId(external.id))
      .nonNulls
      .toSet();
  final missingIds = ids.difference(localIds);
  if (missingIds.isEmpty) return localMatches;
  return [
    ...localMatches,
    ...await ExternalCatalogRepository.instance.getHebrewBooksByIds(
      missingIds,
    ),
  ];
}
