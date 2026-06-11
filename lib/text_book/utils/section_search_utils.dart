import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:otzaria/text_book/models/search_results.dart';
import 'package:otzaria/text_book/utils/inline_notes_utils.dart' as notes;
import 'package:otzaria/utils/text/text_manipulation.dart' as utils;

const int _maxSearchResults = 1000;
const int _searchChunkSize = 128;

void _updateAddress(List<String> address, String line) {
  if (line.length < 4) {
    address.add(line);
    return;
  }

  final index = address.indexWhere(
    (e) => e.length >= 4 && e.substring(0, 4) == line.substring(0, 4),
  );

  if (index != -1) {
    address.removeRange(index, address.length);
  }
  address.add(line);
}

bool _isHebrewLetter(int codeUnit) {
  return (codeUnit >= 0x05D0 && codeUnit <= 0x05EA) ||
      (codeUnit >= 0x05F0 && codeUnit <= 0x05F4) ||
      (codeUnit >= 0xFB1D && codeUnit <= 0xFBB1);
}

bool _containsWholeWord(String text, String query) {
  if (!text.contains(query)) return false;

  int idx = text.indexOf(query);
  while (idx != -1) {
    final before = idx > 0 ? text.codeUnitAt(idx - 1) : -1;
    final after = idx + query.length < text.length
        ? text.codeUnitAt(idx + query.length)
        : -1;

    if (!_isHebrewLetter(before) && !_isHebrewLetter(after)) return true;

    idx = text.indexOf(query, idx + 1);
  }
  return false;
}

class _SearchWorkerHost {
  _SearchWorkerHost._();

  static final _SearchWorkerHost instance = _SearchWorkerHost._();

  ReceivePort? _receivePort;
  SendPort? _workerSendPort;
  Isolate? _isolate;
  Future<void>? _startFuture;
  Completer<void>? _startCompleter;
  int _nextRequestId = 0;
  final Map<int, Completer<List<TextSearchResult>>> _pending = {};

  // מעקב אחר התוכן האחרון שנשלח ל-worker. כל עוד מדובר באותו אובייקט תוכן
  // (אותו ספר פתוח) שולחים רק את השאילתה — לא את הספר כולו — וה-worker
  // משתמש ב-cache שלו לפי המזהה.
  List<String>? _lastSentContent;
  int _lastContentId = 0;

  Future<List<TextSearchResult>> search({
    required List<String> content,
    required String query,
  }) async {
    await _ensureStarted();

    final requestId = ++_nextRequestId;
    final completer = Completer<List<TextSearchResult>>();
    _pending[requestId] = completer;

    final bool contentChanged = !identical(content, _lastSentContent);
    if (contentChanged) {
      _lastSentContent = content;
      _lastContentId++;
    }

    final message = <String, dynamic>{
      'type': 'search',
      'requestId': requestId,
      'contentId': _lastContentId,
      'query': query,
    };
    if (contentChanged) {
      message['content'] = content;
    }

    _workerSendPort!.send(message);

    return completer.future;
  }

  Future<void> _ensureStarted() {
    if (_workerSendPort != null) {
      return Future.value();
    }

    final existingStart = _startFuture;
    if (existingStart != null) {
      return existingStart;
    }

    final completer = Completer<void>();
    _startCompleter = completer;
    _startFuture = completer.future;
    _receivePort = ReceivePort();
    _receivePort!.listen(_handleMessage);

    Isolate.spawn<SendPort>(
      _searchWorkerMain,
      _receivePort!.sendPort,
    ).then((isolate) {
      _isolate = isolate;
    }).catchError((Object error, StackTrace stackTrace) {
      _startFuture = null;
      final startCompleter = _startCompleter;
      _startCompleter = null;
      _receivePort?.close();
      _receivePort = null;
      if (startCompleter != null && !startCompleter.isCompleted) {
        startCompleter.completeError(error, stackTrace);
      }
    });

    return completer.future;
  }

  void _handleMessage(dynamic message) {
    if (message is SendPort) {
      _workerSendPort = message;
      final startCompleter = _startCompleter;
      _startCompleter = null;
      _startFuture = null;
      if (startCompleter != null && !startCompleter.isCompleted) {
        startCompleter.complete();
      }
      return;
    }

    if (message is! Map) {
      return;
    }

    final requestId = message['requestId'] as int?;
    if (requestId == null) {
      return;
    }

    final completer = _pending.remove(requestId);
    if (completer == null || completer.isCompleted) {
      return;
    }

    final type = message['type'] as String?;
    switch (type) {
      case 'result':
        final rawResults = message['results'] as List<dynamic>? ?? const [];
        completer.complete(
          rawResults
              .cast<Map<dynamic, dynamic>>()
              .map(
                (raw) => TextSearchResult(
                  index: raw['index'] as int,
                  snippet: raw['snippet'] as String,
                  address: raw['address'] as String,
                  query: raw['query'] as String,
                ),
              )
              .toList(growable: false),
        );
        break;
      case 'canceled':
        completer.complete(const []);
        break;
      case 'error':
        completer.completeError(
          StateError(message['message'] as String? ?? 'Search worker failed'),
        );
        break;
    }
  }

  @visibleForTesting
  Future<void> resetForTesting() async {
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.complete(const []);
      }
    }
    _pending.clear();
    _receivePort?.close();
    _receivePort = null;
    _workerSendPort = null;
    _startFuture = null;
    _startCompleter = null;
    _nextRequestId = 0;
    _lastSentContent = null;
    _lastContentId = 0;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
  }
}

void _searchWorkerMain(SendPort mainSendPort) {
  final commandPort = ReceivePort();
  mainSendPort.send(commandPort.sendPort);
  final runtime = SectionSearchWorkerRuntime(mainSendPort);
  commandPort.listen(runtime.onMessage);
}

@visibleForTesting
class SectionSearchWorkerRuntime {
  SectionSearchWorkerRuntime(this._mainSendPort);

  final SendPort _mainSendPort;
  Map<String, dynamic>? _queuedRequest;
  bool _isProcessing = false;

  // Cache של ספר אחד (LRU=1): התוכן הגולמי והשורות לאחר ניקוי. הניקוי
  // (הסרת ניקוד/HTML/הערות) אינו תלוי בשאילתה, ולכן מחושב פעם אחת לכל ספר
  // ולא מחדש בכל הקלדה. מתחלף כשמגיע תוכן עם מזהה שונה.
  int? _cachedContentId;
  List<String>? _cachedRawContent;
  List<String>? _cachedCleanLines;

  void onMessage(dynamic message) {
    if (message is! Map) {
      return;
    }

    final type = message['type'];
    if (type != 'search') {
      return;
    }

    _queuedRequest = Map<String, dynamic>.from(message);
    if (!_isProcessing) {
      unawaited(_processLoop());
    }
  }

  Future<void> _processLoop() async {
    _isProcessing = true;
    try {
      while (_queuedRequest != null) {
        final request = _queuedRequest!;
        _queuedRequest = null;
        final requestId = request['requestId'] as int;

        try {
          final contentId = request['contentId'] as int?;
          final query = request['query'] as String;

          // ודא שה-cache תואם לתוכן המבוקש; אחרת בנה אותו פעם אחת.
          // בקשה ללא contentId (תאימות לאחור) נחשבת תמיד כתוכן חדש.
          final bool cacheValid = contentId != null &&
              contentId == _cachedContentId &&
              _cachedCleanLines != null;
          if (!cacheValid) {
            final rawContent = request.containsKey('content')
                ? (request['content'] as List<dynamic>).cast<String>()
                : _cachedRawContent;
            if (rawContent == null) {
              throw StateError('לא התקבל תוכן לחיפוש (contentId=$contentId)');
            }
            final built = await _buildCache(contentId, rawContent);
            if (!built) {
              // הבנייה הופסקה כי הגיעה בקשה לתוכן אחר — הבקשה הנוכחית מיושנת.
              // מדווחים ביטול וממשיכים אל הבקשה החדשה בלולאה.
              _mainSendPort.send({
                'type': 'canceled',
                'requestId': requestId,
              });
              continue;
            }
          }

          final cleanLines = _cachedCleanLines!;
          final sourceLines = _cachedRawContent!;

          final results = <Map<String, dynamic>>[];
          final address = <String>[];
          bool canceled = false;

          for (int i = 0; i < cleanLines.length; i++) {
            final rawLine = sourceLines[i];

            if (rawLine.contains('<h') && !rawLine.startsWith('<h1')) {
              _updateAddress(address, rawLine);
            }

            if (_containsWholeWord(cleanLines[i], query)) {
              results.add({
                'index': i,
                'snippet': cleanLines[i],
                'address': utils
                    .removeVolwels(utils.stripHtmlIfNeeded(address.join(', '))),
                'query': query,
              });
              if (results.length >= _maxSearchResults) {
                break;
              }
            }

            if ((i + 1) % _searchChunkSize == 0) {
              await Future<void>.delayed(Duration.zero);
              if (_queuedRequest != null) {
                canceled = true;
                break;
              }
            }
          }

          if (canceled) {
            _mainSendPort.send({
              'type': 'canceled',
              'requestId': requestId,
            });
            continue;
          }

          _mainSendPort.send({
            'type': 'result',
            'requestId': requestId,
            'results': results,
          });
        } catch (error) {
          _mainSendPort.send({
            'type': 'error',
            'requestId': requestId,
            'message': error.toString(),
          });
        }
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// מנקה את כל שורות הספר פעם אחת ושומר ב-cache. הניקוי כבד ואינו תלוי
  /// בשאילתה, ולכן מבוצע רק כשמתחלף הספר. ה-yield התקופתי מונע חסימה ארוכה
  /// של ה-isolate ומאפשר לקלוט בקשות חדשות בזמן הבנייה.
  /// מחזיר `false` אם הבנייה הופסקה באמצע כי בינתיים הגיעה בקשה לתוכן אחר
  /// (contentId שונה); במקרה כזה לא נשמר cache חלקי. שינוי שאילתה בלבד על
  /// אותו ספר אינו מפסיק את הבנייה — היא עדיין שימושית לשאילתה החדשה.
  Future<bool> _buildCache(int? contentId, List<String> content) async {
    final clean = List<String>.filled(content.length, '', growable: false);
    for (int i = 0; i < content.length; i++) {
      clean[i] = utils.removeVolwels(
          utils.stripHtmlIfNeeded(notes.stripInlineNotesForSearch(content[i])));
      if ((i + 1) % _searchChunkSize == 0) {
        await Future<void>.delayed(Duration.zero);
        final next = _queuedRequest;
        if (next != null && next['contentId'] != contentId) {
          return false;
        }
      }
    }
    _cachedContentId = contentId;
    _cachedRawContent = content;
    _cachedCleanLines = clean;
    return true;
  }
}

Future<List<TextSearchResult>> searchInContent({
  required List<String> content,
  required String query,
}) async {
  if (query.isEmpty || content.isEmpty) return [];

  return _SearchWorkerHost.instance.search(
    content: content,
    query: query,
  );
}

@visibleForTesting
Future<void> resetSectionSearchWorkerForTesting() {
  return _SearchWorkerHost.instance.resetForTesting();
}
