import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:otzaria/core/error_log_file.dart';
import 'package:otzaria/utils/text/text_manipulation.dart';
import 'package:otzaria_search_engine/otzaria_search_engine.dart' as engine;

class PreparedIndexDocument {
  final String reference;
  final String text;
  final int segment;
  final int ordinal;

  const PreparedIndexDocument({
    required this.reference,
    required this.text,
    required this.segment,
    required this.ordinal,
  });

  factory PreparedIndexDocument.fromMap(Map<dynamic, dynamic> map) {
    return PreparedIndexDocument(
      reference: map['reference'] as String? ?? '',
      text: map['text'] as String? ?? '',
      segment: (map['segment'] as num?)?.toInt() ?? 0,
      ordinal: (map['ordinal'] as num?)?.toInt() ?? 0,
    );
  }
}

abstract class IndexingIsolateUpdate {
  const IndexingIsolateUpdate();
}

class IndexingBatchReady extends IndexingIsolateUpdate {
  final List<PreparedIndexDocument> documents;
  final Future<void> Function() acknowledge;

  const IndexingBatchReady({
    required this.documents,
    required this.acknowledge,
  });
}

class IndexingWorkComplete extends IndexingIsolateUpdate {
  const IndexingWorkComplete();
}

class IndexingDocumentBuilder {
  /// \u05DE\u05E0\u05E8\u05DE\u05DC \u05D8\u05E7\u05E1\u05D8 \u05DC\u05D0\u05D9\u05E0\u05D3\u05D5\u05E7\u05E1. \u05DE\u05D0\u05E6\u05D9\u05DC \u05DC\u05DE\u05E0\u05D5\u05E2 \u05D4-Rust
  /// ([`engine.normalizeTextForIndexing`]) \u05E9\u05D4\u05D5\u05D0 \u05DE\u05E7\u05D5\u05E8 \u05D4\u05D0\u05DE\u05EA \u05D4\u05D9\u05D7\u05D9\u05D3, \u05DB\u05DA \u05E9\u05D8\u05D5\u05E7\u05E0\u05D9
  /// \u05D4\u05D0\u05D9\u05E0\u05D3\u05D5\u05E7\u05E1 \u05D5\u05D8\u05D5\u05E7\u05E0\u05D9 \u05D4\u05E9\u05D0\u05D9\u05DC\u05EA\u05D4 \u05D9\u05D9\u05D5\u05D5\u05E6\u05E8\u05D5 \u05DE\u05D0\u05D5\u05EA\u05DD \u05EA\u05D5\u05D5\u05D9\u05DD \u05DE\u05E0\u05D5\u05E8\u05DE\u05DC\u05D9\u05DD \u05D5\u05DC\u05D0 \u05D9\u05D9\u05E4\u05E8\u05D3\u05D5.
  static String normalizeTextForIndexing(String input) =>
      engine.normalizeTextForIndexing(input: input);

  /// נרמול אצוות שורות בקריאת FFI אחת. ה-overhead הקבוע של קריאת גשר
  /// (קידוד/פענוח מחרוזות) גובר על עלות הנרמול עצמו בשורות קצרות, וספרייה
  /// מלאה היא מיליוני שורות — לכן מסלולי האינדוקס עובדים תמיד באצוות.
  static List<String> normalizeTextsForIndexing(List<String> inputs) =>
      engine.normalizeTextsForIndexing(inputs: inputs);

  /// נרמול + סינון-זבל לאצוות שורות PDF בקריאת FFI אחת (מחליף את שתי
  /// הקריאות-לשורה של [normalizePdfTextForIndexing] + [isProbablyGarbagePdfText]).
  static List<engine.PdfIndexLine> normalizePdfTextsForIndexing(
          List<String> inputs) =>
      engine.normalizePdfTextsForIndexing(inputs: inputs);

  static List<PreparedIndexDocument> buildTextBookDocuments(String text) {
    final texts = text.split('\n');
    final normalized = normalizeTextsForIndexing(texts);
    final documents = <PreparedIndexDocument>[];
    final reference = <String>[];

    for (int i = 0; i < texts.length; i++) {
      final rawLine = texts[i];
      if (rawLine.startsWith('<h')) {
        _updateReferenceTrail(reference, rawLine);
      }
      documents.add(
        PreparedIndexDocument(
          reference: stripHtmlIfNeeded(reference.join(', ')),
          text: normalized[i],
          segment: i,
          ordinal: documents.length,
        ),
      );
    }

    return documents;
  }

  /// מנרמל טקסט PDF לאינדוקס. מאציל למנוע ה-Rust
  /// ([`engine.normalizePdfTextForIndexing`]) — מקור אמת יחיד לצד האינדוקס.
  static String normalizePdfTextForIndexing(String input) =>
      engine.normalizePdfTextForIndexing(input: input);

  /// זיהוי עמוד PDF שנראה כזבל (רעש OCR) שיש לדלג עליו. מאציל למנוע ה-Rust
  /// ([`engine.isProbablyGarbagePdfText`]).
  static bool isProbablyGarbagePdfText(String normalizedText) =>
      engine.isProbablyGarbagePdfText(normalizedText: normalizedText);

  static void _updateReferenceTrail(List<String> reference, String line) {
    if (line.length < 4) {
      reference.add(line);
      return;
    }

    if (reference.isNotEmpty) {
      final prefix = line.substring(0, 4);
      final existingIndex = reference.indexWhere(
        (element) => element.length >= 4 && element.substring(0, 4) == prefix,
      );
      if (existingIndex != -1) {
        reference.removeRange(existingIndex, reference.length);
      }
    }

    reference.add(line);
  }
}

class IndexingIsolateService {
  IndexingIsolateService._(
    this._receivePort,
    this._errorPort,
    this._exitPort,
    this._workerToken,
    this._externalLibraryPath,
  ) {
    _messagesSubscription = _receivePort.listen(_handleMessage);
    _errorSubscription = _errorPort.listen(_handleUnhandledWorkerError);
    _exitSubscription = _exitPort.listen(_handleWorkerExit);
  }

  static const int _batchSize = 200;

  final ReceivePort _receivePort;
  final ReceivePort _errorPort;
  final ReceivePort _exitPort;
  final RootIsolateToken? _workerToken;

  /// נתיב מפורש לספריית המנוע הנייטיבית עבור ה-worker isolate. `null`
  /// ב-production (ה-isolate מאתחל את RustLib בדרך הרגילה); הטסטים מספקים
  /// נתיב לספרייה שנבנתה מקומית.
  final String? _externalLibraryPath;

  late final StreamSubscription<dynamic> _messagesSubscription;
  late final StreamSubscription<dynamic> _errorSubscription;
  late final StreamSubscription<dynamic> _exitSubscription;
  final Completer<void> _readyCompleter = Completer<void>();
  final Completer<void> _shutdownCompleter = Completer<void>();

  StreamController<IndexingIsolateUpdate>? _activeController;
  SendPort? _commandPort;
  Isolate? _isolate;
  bool _disposed = false;
  bool _workerFailureReported = false;

  /// [externalLibraryPath] מיועד לטסטים בלבד: נתיב מפורש לספריית המנוע
  /// הנייטיבית שה-worker isolate יטען. ב-production השאירו `null`.
  static Future<IndexingIsolateService> create({
    @visibleForTesting String? externalLibraryPath,
  }) async {
    final receivePort = ReceivePort();
    final errorPort = ReceivePort();
    final exitPort = ReceivePort();
    final service = IndexingIsolateService._(
      receivePort,
      errorPort,
      exitPort,
      RootIsolateToken.instance,
      externalLibraryPath,
    );

    await service._spawn();
    return service;
  }

  Future<void> _spawn() async {
    _isolate = await Isolate.spawn<_WorkerBootstrapMessage>(
      _indexingWorkerMain,
      _WorkerBootstrapMessage(
        mainSendPort: _receivePort.sendPort,
        rootToken: _workerToken,
        externalLibraryPath: _externalLibraryPath,
      ),
      debugName: 'indexing_worker',
      onError: _errorPort.sendPort,
      onExit: _exitPort.sendPort,
    );
    await _readyCompleter.future;
  }

  Future<Stream<IndexingIsolateUpdate>> processTextBook({
    required String text,
  }) async {
    await _ensureReady();
    _ensureIdle();

    final controller = StreamController<IndexingIsolateUpdate>();
    _activeController = controller;
    _commandPort!.send({
      'type': 'processTextBook',
      'text': text,
    });
    return controller.stream;
  }

  Future<Stream<IndexingIsolateUpdate>> processPdfPages({
    required List<({String reference, String text, int pageIndex})> pages,
  }) async {
    await _ensureReady();
    _ensureIdle();

    final controller = StreamController<IndexingIsolateUpdate>();
    _activeController = controller;
    _commandPort!.send({
      'type': 'processPdfPages',
      'pages': pages
          .map((p) => {
                'reference': p.reference,
                'text': p.text,
                'pageIndex': p.pageIndex,
              })
          .toList(),
    });
    return controller.stream;
  }

  Future<void> cancelActiveWork() async {
    if (_disposed || _commandPort == null) {
      return;
    }

    _commandPort!.send({'type': 'cancel'});
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    _commandPort?.send({'type': 'shutdown'});
    await _shutdownCompleter.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () {},
    );

    await _messagesSubscription.cancel();
    await _errorSubscription.cancel();
    await _exitSubscription.cancel();
    _receivePort.close();
    _errorPort.close();
    _exitPort.close();
    _isolate?.kill(priority: Isolate.immediate);
  }

  Future<void> _ensureReady() async {
    if (_disposed) {
      throw StateError('IndexingIsolateService was disposed');
    }
    await _readyCompleter.future;
  }

  void _ensureIdle() {
    if (_activeController != null) {
      throw StateError('Indexing isolate already processing a book');
    }
  }

  void _handleMessage(dynamic message) {
    if (message is SendPort) {
      _commandPort = message;
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.complete();
      }
      return;
    }

    if (message is! Map) {
      return;
    }

    final type = message['type'] as String?;
    switch (type) {
      case 'batch':
        final rawDocuments =
            (message['documents'] as List<dynamic>? ?? const <dynamic>[]);
        final documents = rawDocuments
            .whereType<Map<dynamic, dynamic>>()
            .map(PreparedIndexDocument.fromMap)
            .toList(growable: false);

        _activeController?.add(
          IndexingBatchReady(
            documents: documents,
            acknowledge: () async {
              _commandPort?.send({'type': 'ackBatch'});
            },
          ),
        );
        break;
      case 'complete':
      case 'cancelled':
        _activeController?.add(const IndexingWorkComplete());
        _closeActiveController();
        break;
      case 'error':
        final error = message['error']?.toString() ?? 'Unknown isolate error';
        _activeController?.addError(StateError(error));
        _closeActiveController();
        break;
      case 'shutdownAck':
        if (!_shutdownCompleter.isCompleted) {
          _shutdownCompleter.complete();
        }
        break;
    }
  }

  void _closeActiveController() {
    final controller = _activeController;
    _activeController = null;
    controller?.close();
  }

  void _handleUnhandledWorkerError(dynamic message) {
    if (_workerFailureReported) {
      return;
    }
    _workerFailureReported = true;

    final parsed = _parseUnhandledIsolateError(message);
    final error = parsed.$1;
    final stackTrace = parsed.$2;

    if (kDebugMode) {
      debugPrint('Unhandled indexing isolate error: $error');
      debugPrintStack(stackTrace: stackTrace);
    } else {
      ErrorLogFile.append(
        title: 'Unhandled Isolate Error',
        error: error,
        stackTrace: stackTrace,
        details: const {
          'Service': 'IndexingIsolateService',
        },
      );
    }

    if (!_readyCompleter.isCompleted) {
      _readyCompleter.completeError(error, stackTrace);
    }

    _activeController?.addError(error, stackTrace);
    _closeActiveController();
  }

  void _handleWorkerExit(dynamic _) {
    if (_disposed) {
      if (!_shutdownCompleter.isCompleted) {
        _shutdownCompleter.complete();
      }
      return;
    }

    if (_workerFailureReported) {
      if (!_shutdownCompleter.isCompleted) {
        _shutdownCompleter.complete();
      }
      return;
    }
    _workerFailureReported = true;

    final error = StateError('Indexing isolate exited unexpectedly');
    final stackTrace = StackTrace.current;

    if (!_readyCompleter.isCompleted) {
      _readyCompleter.completeError(error, stackTrace);
    }

    if (kDebugMode) {
      debugPrint('$error');
      debugPrintStack(stackTrace: stackTrace);
    } else {
      ErrorLogFile.append(
        title: 'Unhandled Isolate Error',
        error: error,
        stackTrace: stackTrace,
        details: const {
          'Service': 'IndexingIsolateService',
        },
      );
    }

    _activeController?.addError(error, stackTrace);
    _closeActiveController();

    if (!_shutdownCompleter.isCompleted) {
      _shutdownCompleter.complete();
    }
  }

  (Object, StackTrace) _parseUnhandledIsolateError(dynamic message) {
    if (message is List && message.length >= 2) {
      final error = message[0] ?? 'Unknown isolate error';
      final rawStackTrace = message[1];
      final stackTrace = rawStackTrace is StackTrace
          ? rawStackTrace
          : StackTrace.fromString(rawStackTrace?.toString() ?? '');
      return (error, stackTrace);
    }

    return (message ?? 'Unknown isolate error', StackTrace.current);
  }
}

class _WorkerBootstrapMessage {
  final SendPort mainSendPort;
  final RootIsolateToken? rootToken;

  /// נתיב מפורש לספריית המנוע הנייטיבית, לשימוש ה-isolate כשאין ברירת מחדל
  /// זמינה (למשל תחת `flutter test`). ב-production זה `null` וה-isolate
  /// מאתחל את RustLib בדרך הרגילה.
  final String? externalLibraryPath;

  const _WorkerBootstrapMessage({
    required this.mainSendPort,
    required this.rootToken,
    this.externalLibraryPath,
  });
}

void _indexingWorkerMain(_WorkerBootstrapMessage bootstrap) {
  final receivePort = ReceivePort();
  bootstrap.mainSendPort.send(receivePort.sendPort);

  var isProcessing = false;
  var shouldCancel = false;
  Completer<void>? pendingBatchAck;

  // נרמול הטקסט לאינדוקס מאציל למנוע ה-Rust (קריאות FRB סינכרוניות), ולכן
  // חובה לאתחל את RustLib ב-isolate הזה — אתחול ה-main isolate לא חל כאן.
  // האתחול עצל וחד-פעמי, לפני עיבוד הספר הראשון.
  var engineInitialized = false;
  Future<void> ensureEngine() async {
    if (engineInitialized) return;
    final path = bootstrap.externalLibraryPath;
    if (path != null) {
      await engine.RustLib.init(
        externalLibrary: engine.ExternalLibrary.open(path),
      );
    } else {
      await engine.RustLib.init();
    }
    engineInitialized = true;
  }

  Future<void> completePendingAck() async {
    final completer = pendingBatchAck;
    pendingBatchAck = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  Future<void> emitBatch(List<Map<String, Object?>> documents) async {
    if (documents.isEmpty) {
      return;
    }

    final ackCompleter = Completer<void>();
    pendingBatchAck = ackCompleter;
    bootstrap.mainSendPort.send({
      'type': 'batch',
      'documents': documents,
    });
    await ackCompleter.future;
  }

  Future<void> processTextBook(String text) async {
    await ensureEngine();
    final texts = text.split('\n');
    final reference = <String>[];
    var ordinal = 0;

    // נרמול בחלונות של _batchSize: קריאת FFI אחת לכל חלון במקום אחת לכל
    // שורה — ה-overhead הקבוע פר-קריאה היה החלק הדומיננטי בזמן ההכנה.
    for (var start = 0;
        start < texts.length;
        start += IndexingIsolateService._batchSize) {
      if (shouldCancel) {
        return;
      }

      final end =
          (start + IndexingIsolateService._batchSize).clamp(0, texts.length);
      final window = texts.sublist(start, end);
      final normalized =
          IndexingDocumentBuilder.normalizeTextsForIndexing(window);

      final batch = <Map<String, Object?>>[];
      for (var j = 0; j < window.length; j++) {
        final rawLine = window[j];
        if (rawLine.startsWith('<h')) {
          IndexingDocumentBuilder._updateReferenceTrail(reference, rawLine);
        }
        batch.add({
          'reference': stripHtmlIfNeeded(reference.join(', ')),
          'text': normalized[j],
          'segment': start + j,
          'ordinal': ordinal++,
        });
      }

      await emitBatch(batch);
    }
  }

  Future<void> processPdfPages(List<dynamic> rawPages) async {
    await ensureEngine();
    var batch = <Map<String, Object?>>[];
    var ordinal = 0;

    for (final rawPage in rawPages) {
      if (shouldCancel) return;

      final page = rawPage as Map<dynamic, dynamic>;
      final reference = page['reference'] as String? ?? '';
      final text = page['text'] as String? ?? '';
      final pageIndex = (page['pageIndex'] as num?)?.toInt() ?? 0;

      final rawLines = text.split('\n');
      // נרמול + סינון זבל בחלונות — קריאת FFI אחת לחלון במקום שתיים לשורה.
      for (var start = 0;
          start < rawLines.length;
          start += IndexingIsolateService._batchSize) {
        if (shouldCancel) return;

        final end = (start + IndexingIsolateService._batchSize)
            .clamp(0, rawLines.length);
        final prepared = IndexingDocumentBuilder.normalizePdfTextsForIndexing(
          rawLines.sublist(start, end),
        );

        for (final line in prepared) {
          if (line.isGarbage) {
            continue;
          }

          batch.add({
            'reference': reference,
            'text': line.text,
            'segment': pageIndex,
            'ordinal': ordinal++,
          });

          if (batch.length >= IndexingIsolateService._batchSize) {
            await emitBatch(batch);
            batch = <Map<String, Object?>>[];
          }
        }
      }
    }

    await emitBatch(batch);
  }

  receivePort.listen((dynamic message) {
    if (message is! Map) {
      return;
    }

    final type = message['type'] as String?;

    switch (type) {
      case 'processTextBook':
        if (isProcessing) {
          bootstrap.mainSendPort.send({
            'type': 'error',
            'error': 'Indexing worker is already processing a book',
          });
          return;
        }

        isProcessing = true;
        shouldCancel = false;
        unawaited(() async {
          try {
            await processTextBook(message['text'] as String? ?? '');
            bootstrap.mainSendPort.send({
              'type': shouldCancel ? 'cancelled' : 'complete',
            });
          } catch (e) {
            bootstrap.mainSendPort.send({
              'type': 'error',
              'error': e.toString(),
            });
          } finally {
            await completePendingAck();
            isProcessing = false;
          }
        }());
        return;
      case 'processPdfPages':
        if (isProcessing) {
          bootstrap.mainSendPort.send({
            'type': 'error',
            'error': 'Indexing worker is already processing a book',
          });
          return;
        }

        isProcessing = true;
        shouldCancel = false;
        unawaited(() async {
          try {
            await processPdfPages(
              (message['pages'] as List<dynamic>?) ?? const [],
            );
            bootstrap.mainSendPort.send({
              'type': shouldCancel ? 'cancelled' : 'complete',
            });
          } catch (e) {
            bootstrap.mainSendPort.send({
              'type': 'error',
              'error': e.toString(),
            });
          } finally {
            await completePendingAck();
            isProcessing = false;
          }
        }());
        return;
      case 'ackBatch':
        unawaited(completePendingAck());
        return;
      case 'cancel':
        shouldCancel = true;
        unawaited(completePendingAck());
        return;
      case 'shutdown':
        shouldCancel = true;
        unawaited(() async {
          await completePendingAck();
          bootstrap.mainSendPort.send({'type': 'shutdownAck'});
          receivePort.close();
        }());
        return;
    }
  });
}
