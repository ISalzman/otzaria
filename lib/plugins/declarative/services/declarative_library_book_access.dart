import 'package:otzaria/data/repository/data_repository.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/plugins/declarative/services/declarative_host_action_executor.dart';
import 'package:otzaria/plugins/declarative/services/declarative_program_executor.dart';
import 'package:otzaria/plugins/models/plugin_book_identity.dart';
import 'package:otzaria/utils/navigation/book_open_coordinator.dart';

typedef DeclarativeBookListLoader = Future<List<Book>> Function();
typedef DeclarativeExternalBookListLoader =
    Future<List<Book>> Function(String provider);
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
      (provider) => switch (provider) {
        'hebrewbooks' => DataRepository.instance.hebrewBooks,
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
  Future<Map<String, dynamic>?> resolveUnique(
    Map<String, dynamic> identity,
  ) async {
    final book = await _findUnique(identity);
    return book == null ? null : PluginBookIdentity.toJson(book);
  }

  @override
  Future<bool> openUnique(
    Map<String, dynamic> identity, {
    required int index,
    required String searchQuery,
  }) async {
    final book = await _findUnique(identity);
    if (book == null) return false;
    _openBook(book, index, searchQuery);
    return true;
  }

  Future<Book?> _findUnique(Map<String, dynamic> identity) async {
    const allowed = {'id', 'bookId', 'type', 'source', 'external'};
    if (identity.keys.any((key) => !allowed.contains(key))) return null;
    final id = PluginBookIdentity.parseId(identity['id']);
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

    final books = external == null
        ? await _libraryBooks()
        : await _externalBooks(external.provider);
    final matches = <Book>[];
    for (final book in books) {
      if (!PluginBookIdentity.matches(
        book,
        id: id,
        bookId: bookId as String?,
        type: type as String?,
        source: source as String?,
      )) {
        continue;
      }
      if (external != null) {
        final candidate = PluginBookIdentity.externalOf(book);
        if (candidate == null ||
            candidate.provider != external.provider ||
            candidate.id.toString() != external.id.toString()) {
          continue;
        }
      }
      matches.add(book);
      if (matches.length > 1) return null;
    }
    return matches.isEmpty ? null : matches.first;
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
