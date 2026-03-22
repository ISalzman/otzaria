import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:otzaria/utils/ref_helper.dart';
import 'package:otzaria/utils/text_manipulation.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

class PreparedIndexDocument {
  final String reference;
  final String text;
  final int segment;

  const PreparedIndexDocument({
    required this.reference,
    required this.text,
    required this.segment,
  });

  factory PreparedIndexDocument.fromMap(Map<dynamic, dynamic> map) {
    return PreparedIndexDocument(
      reference: map['reference'] as String? ?? '',
      text: map['text'] as String? ?? '',
      segment: (map['segment'] as num?)?.toInt() ?? 0,
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
  static final RegExp _pdfInvisibleChars = RegExp(
    r'[\u200B-\u200F\u202A-\u202E\u2066-\u2069]'
    r'|\uFEFF',
  );

  static final RegExp _pdfLettersAndDigits =
      RegExp(r'[\u05D0-\u05EAa-zA-Z0-9]');
  static final RegExp _pdfNonLettersNonSpace =
      RegExp(r'[^\s\u05D0-\u05EAa-zA-Z0-9]');

  static List<PreparedIndexDocument> buildTextBookDocuments(String text) {
    final texts = text.split('\n');
    final documents = <PreparedIndexDocument>[];
    final reference = <String>[];

    for (int i = 0; i < texts.length; i++) {
      final rawLine = texts[i];
      if (rawLine.startsWith('<h')) {
        _updateReferenceTrail(reference, rawLine);
        final headerLine = removeVolwels(stripHtmlIfNeeded(rawLine));
        documents.add(
          PreparedIndexDocument(
            reference: stripHtmlIfNeeded(reference.join(', ')),
            text: headerLine,
            segment: i,
          ),
        );
        continue;
      }

      final line = removeVolwels(stripHtmlIfNeeded(rawLine));
      documents.add(
        PreparedIndexDocument(
          reference: stripHtmlIfNeeded(reference.join(', ')),
          text: line,
          segment: i,
        ),
      );
    }

    return documents;
  }

  static String normalizePdfTextForIndexing(String input) {
    var text = stripHtmlIfNeeded(input);
    text = text.replaceAll(_pdfInvisibleChars, '');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    text = removeVolwels(text);
    return text;
  }

  static bool isProbablyGarbagePdfText(String normalizedText) {
    final compact = normalizedText.replaceAll(RegExp(r'\s+'), '');
    if (compact.isEmpty) return true;

    final letters = _pdfLettersAndDigits.allMatches(compact).length;
    if (letters == 0) return true;

    final nonLetters = _pdfNonLettersNonSpace.allMatches(compact).length;
    final ratioLetters = letters / compact.length;

    if (compact.length >= 50 && ratioLetters < 0.10) return true;
    if (compact.length >= 20 && ratioLetters < 0.20 && nonLetters > letters) {
      return true;
    }

    return false;
  }

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
  IndexingIsolateService._(this._receivePort, this._workerToken) {
    _messagesSubscription = _receivePort.listen(_handleMessage);
  }

  static const int _batchSize = 200;

  final ReceivePort _receivePort;
  final RootIsolateToken? _workerToken;

  late final StreamSubscription<dynamic> _messagesSubscription;
  final Completer<void> _readyCompleter = Completer<void>();
  final Completer<void> _shutdownCompleter = Completer<void>();

  StreamController<IndexingIsolateUpdate>? _activeController;
  SendPort? _commandPort;
  Isolate? _isolate;
  bool _disposed = false;

  static Future<IndexingIsolateService> create() async {
    final receivePort = ReceivePort();
    final service = IndexingIsolateService._(
      receivePort,
      RootIsolateToken.instance,
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
      ),
      debugName: 'indexing_worker',
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

  Future<Stream<IndexingIsolateUpdate>> processPdfBook({
    required String title,
    required String path,
  }) async {
    await _ensureReady();
    _ensureIdle();

    final controller = StreamController<IndexingIsolateUpdate>();
    _activeController = controller;
    _commandPort!.send({
      'type': 'processPdfBook',
      'title': title,
      'path': path,
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
    _receivePort.close();
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
}

class _WorkerBootstrapMessage {
  final SendPort mainSendPort;
  final RootIsolateToken? rootToken;

  const _WorkerBootstrapMessage({
    required this.mainSendPort,
    required this.rootToken,
  });
}

void _indexingWorkerMain(_WorkerBootstrapMessage bootstrap) {
  final receivePort = ReceivePort();
  bootstrap.mainSendPort.send(receivePort.sendPort);

  var isProcessing = false;
  var shouldCancel = false;
  var pdfrxInitialized = false;
  Completer<void>? pendingBatchAck;

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

  Future<void> ensurePdfrxInitialized() async {
    if (pdfrxInitialized) {
      return;
    }

    final rootToken = bootstrap.rootToken;
    if (rootToken != null) {
      BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);
    }

    Pdfrx.getCacheDirectory ??= () => Directory.systemTemp.path;
    await pdfrxFlutterInitialize(dismissPdfiumWasmWarnings: true);
    pdfrxInitialized = true;
  }

  Future<void> processTextBook(String text) async {
    final texts = text.split('\n');
    final reference = <String>[];
    var batch = <Map<String, Object?>>[];

    for (int i = 0; i < texts.length; i++) {
      if (shouldCancel) {
        return;
      }

      final rawLine = texts[i];
      if (rawLine.startsWith('<h')) {
        IndexingDocumentBuilder._updateReferenceTrail(reference, rawLine);
        final headerLine = removeVolwels(stripHtmlIfNeeded(rawLine));
        batch.add({
          'reference': stripHtmlIfNeeded(reference.join(', ')),
          'text': headerLine,
          'segment': i,
        });
      } else {
        batch.add({
          'reference': stripHtmlIfNeeded(reference.join(', ')),
          'text': removeVolwels(stripHtmlIfNeeded(rawLine)),
          'segment': i,
        });
      }

      if (batch.length >= IndexingIsolateService._batchSize) {
        await emitBatch(batch);
        batch = <Map<String, Object?>>[];
      }
    }

    await emitBatch(batch);
  }

  Future<void> processPdfBook({
    required String title,
    required String path,
  }) async {
    await ensurePdfrxInitialized();

    PdfDocument? document;
    try {
      final file = File(path);
      if (!await file.exists()) {
        return;
      }

      document = await PdfDocument.openFile(path).timeout(
        const Duration(seconds: 60),
      );

      final outline = await document.loadOutline().timeout(
            const Duration(seconds: 15),
            onTimeout: () => <PdfOutlineNode>[],
          );

      var batch = <Map<String, Object?>>[];
      var addedAny = false;

      for (int i = 0; i < document.pages.length; i++) {
        if (shouldCancel) {
          return;
        }

        final pageText = await document.pages[i].loadText().timeout(
              const Duration(seconds: 5),
              onTimeout: () => null,
            );
        if (pageText == null) {
          continue;
        }

        final bookmark = await refFromPageNumber(i + 1, outline, title);
        final ref = bookmark.isNotEmpty
            ? '$title, $bookmark, עמוד ${i + 1}'
            : '$title, עמוד ${i + 1}';

        final rawLines = pageText.fullText.split('\n');
        for (final rawLine in rawLines) {
          if (shouldCancel) {
            return;
          }

          final normalized =
              IndexingDocumentBuilder.normalizePdfTextForIndexing(rawLine);
          if (IndexingDocumentBuilder.isProbablyGarbagePdfText(normalized)) {
            continue;
          }

          batch.add({
            'reference': ref,
            'text': normalized,
            'segment': i,
          });
          addedAny = true;

          if (batch.length >= IndexingIsolateService._batchSize) {
            await emitBatch(batch);
            batch = <Map<String, Object?>>[];
          }
        }
      }

      if (!addedAny) {
        final candidates = <String>{
          '$path.txt',
          p.setExtension(path, '.txt'),
        };

        File? sidecar;
        for (final candidate in candidates) {
          final file = File(candidate);
          if (await file.exists()) {
            sidecar = file;
            break;
          }
        }

        if (sidecar != null) {
          final ocrText = await sidecar.readAsString();
          final pagesText =
              ocrText.contains('\f') ? ocrText.split('\f') : <String>[ocrText];

          for (int pageIndex = 0; pageIndex < pagesText.length; pageIndex++) {
            if (shouldCancel) {
              return;
            }

            final bookmark =
                await refFromPageNumber(pageIndex + 1, outline, title);
            final ref = bookmark.isNotEmpty
                ? '$title, $bookmark, עמוד ${pageIndex + 1}'
                : '$title, עמוד ${pageIndex + 1}';

            final lines = pagesText[pageIndex].split('\n');
            for (final line in lines) {
              if (shouldCancel) {
                return;
              }

              final normalized =
                  IndexingDocumentBuilder.normalizePdfTextForIndexing(line);
              if (IndexingDocumentBuilder.isProbablyGarbagePdfText(
                  normalized)) {
                continue;
              }

              batch.add({
                'reference': ref,
                'text': normalized,
                'segment': pageIndex,
              });

              if (batch.length >= IndexingIsolateService._batchSize) {
                await emitBatch(batch);
                batch = <Map<String, Object?>>[];
              }
            }
          }
        }
      }

      await emitBatch(batch);
    } finally {
      document?.dispose();
    }
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
      case 'processPdfBook':
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
            await processPdfBook(
              title: message['title'] as String? ?? '',
              path: message['path'] as String? ?? '',
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
