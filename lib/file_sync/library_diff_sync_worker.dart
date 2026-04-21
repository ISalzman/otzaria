import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart'
    show BackgroundIsolateBinaryMessenger, RootIsolateToken;
import 'package:http/http.dart' as http;
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:zstandard/zstandard.dart';

import 'package:otzaria/file_sync/file_sync_repository.dart';

// ── Protocol types ────────────────────────────────────────────────────────────

sealed class LibraryDiffSyncUpdate {
  const LibraryDiffSyncUpdate();
}

class LibraryDiffStageChanged extends LibraryDiffSyncUpdate {
  final String stage;
  final String assetName;
  final int assetIndex;
  final int totalAssets;

  const LibraryDiffStageChanged({
    required this.stage,
    required this.assetName,
    required this.assetIndex,
    required this.totalAssets,
  });
}

class LibraryDiffDownloadProgress extends LibraryDiffSyncUpdate {
  final String assetName;
  final int downloadedBytes;
  final int? totalBytes;

  const LibraryDiffDownloadProgress({
    required this.assetName,
    required this.downloadedBytes,
    this.totalBytes,
  });
}

class LibraryDiffApplyProgress extends LibraryDiffSyncUpdate {
  final String assetName;
  final int appliedStatements;
  final int totalStatements;
  final int assetIndex;
  final int totalAssets;

  const LibraryDiffApplyProgress({
    required this.assetName,
    required this.appliedStatements,
    required this.totalStatements,
    required this.assetIndex,
    required this.totalAssets,
  });
}

class LibraryDiffSyncCompleted extends LibraryDiffSyncUpdate {
  final int appliedAssetCount;

  const LibraryDiffSyncCompleted(this.appliedAssetCount);
}

class LibraryDiffSyncFailed extends LibraryDiffSyncUpdate {
  final String message;

  const LibraryDiffSyncFailed(this.message);
}

class LibraryDiffSyncCancelled extends LibraryDiffSyncUpdate {
  const LibraryDiffSyncCancelled();
}

// ── Service ───────────────────────────────────────────────────────────────────

class LibraryDiffSyncWorkerService {
  final http.Client? _testHttpClient;
  final Future<Uint8List?> Function(Uint8List)? _testDecompress;
  final Future<void> Function(Map<String, dynamic>)? _testIsolateEntryPoint;

  bool _cancelledInline = false;
  bool _cancelRequested = false;
  Isolate? _isolate;
  ReceivePort? _receivePort;
  SendPort? _commandPort;
  StreamController<LibraryDiffSyncUpdate>? _controller;

  LibraryDiffSyncWorkerService({
    @visibleForTesting http.Client? httpClient,
    @visibleForTesting Future<Uint8List?> Function(Uint8List)? decompressDiff,
    @visibleForTesting Future<void> Function(Map<String, dynamic>)? isolateEntryPoint,
  })  : _testHttpClient = httpClient,
        _testDecompress = decompressDiff,
        _testIsolateEntryPoint = isolateEntryPoint;

  Stream<LibraryDiffSyncUpdate> start({
    required String dbPath,
    required List<DiffReleaseAsset> assets,
  }) {
    assert(_controller == null, 'Worker already running');
    _controller = StreamController<LibraryDiffSyncUpdate>();
    _cancelledInline = false;
    _cancelRequested = false;

    if (_testHttpClient != null) {
      _startInline(dbPath: dbPath, assets: assets);
    } else {
      _startIsolate(
        dbPath: dbPath,
        assets: assets,
        entryPoint: _testIsolateEntryPoint,
      );
    }

    return _controller!.stream;
  }

  void cancel() {
    _cancelledInline = true;
    _cancelRequested = true;
    final port = _commandPort;
    if (port != null) {
      port.send({'type': 'cancel'});
    }
  }

  void _startInline({
    required String dbPath,
    required List<DiffReleaseAsset> assets,
  }) {
    runDiffSyncLogic(
      dbPath: dbPath,
      assets: assets,
      httpClient: _testHttpClient!,
      decompress: _testDecompress!,
      isCancelled: () => _cancelledInline,
      onProgress: (update) {
        if (!(_controller?.isClosed ?? true)) {
          _controller!.add(update);
        }
      },
    ).then((count) {
      if (!(_controller?.isClosed ?? true)) {
        _controller!.add(LibraryDiffSyncCompleted(count));
        _controller!.close();
      }
    }).catchError((Object e) {
      if (!(_controller?.isClosed ?? true)) {
        if (e is _CancelledException) {
          _controller!.add(const LibraryDiffSyncCancelled());
        } else {
          _controller!.add(LibraryDiffSyncFailed(e.toString()));
        }
        _controller!.close();
      }
    });
  }

  void _startIsolate({
    required String dbPath,
    required List<DiffReleaseAsset> assets,
    Future<void> Function(Map<String, dynamic>)? entryPoint,
  }) {
    _receivePort = ReceivePort();
    final token = RootIsolateToken.instance!;

    Isolate.spawn(
      entryPoint ?? _workerEntry,
      {
        'mainSendPort': _receivePort!.sendPort,
        'token': token,
        'dbPath': dbPath,
        'assets': assets.map(_assetToMap).toList(),
      },
      onError: _receivePort!.sendPort,
    ).then((isolate) => _isolate = isolate);

    _receivePort!.listen(_onIsolateMessage);
  }

  void _onIsolateMessage(dynamic message) {
    final ctrl = _controller;
    if (ctrl == null || ctrl.isClosed) return;

    if (message is List && message.length == 2) {
      // onError list: [errorString, stackTraceString]
      ctrl.add(LibraryDiffSyncFailed(message[0].toString()));
      ctrl.close();
      return;
    }

    if (message is! Map) return;

    final type = message['type'] as String?;
    switch (type) {
      case 'ready':
        _commandPort = message['commandPort'] as SendPort;
        if (_cancelRequested) {
          _commandPort!.send({'type': 'cancel'});
        }

      case 'stageChanged':
        ctrl.add(LibraryDiffStageChanged(
          stage: message['stage'] as String,
          assetName: message['assetName'] as String,
          assetIndex: message['assetIndex'] as int,
          totalAssets: message['totalAssets'] as int,
        ));

      case 'downloadProgress':
        ctrl.add(LibraryDiffDownloadProgress(
          assetName: message['assetName'] as String,
          downloadedBytes: message['downloadedBytes'] as int,
          totalBytes: message['totalBytes'] as int?,
        ));

      case 'applyProgress':
        ctrl.add(LibraryDiffApplyProgress(
          assetName: message['assetName'] as String,
          appliedStatements: message['appliedStatements'] as int,
          totalStatements: message['totalStatements'] as int,
          assetIndex: message['assetIndex'] as int,
          totalAssets: message['totalAssets'] as int,
        ));

      case 'completed':
        ctrl.add(LibraryDiffSyncCompleted(message['appliedAssetCount'] as int));
        ctrl.close();

      case 'cancelled':
        ctrl.add(const LibraryDiffSyncCancelled());
        ctrl.close();

      case 'failed':
        ctrl.add(LibraryDiffSyncFailed(message['message'] as String? ?? 'שגיאה לא ידועה'));
        ctrl.close();
    }
  }

  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _receivePort?.close();
    if (!(_controller?.isClosed ?? true)) {
      _controller?.close();
    }
    _isolate = null;
    _receivePort = null;
    _commandPort = null;
    _controller = null;
  }
}

// ── Worker entry point (top-level, required for Isolate.spawn) ────────────────

Future<void> _workerEntry(Map<String, dynamic> message) async {
  final mainSendPort = message['mainSendPort'] as SendPort;
  final token = message['token'] as RootIsolateToken;
  final dbPath = message['dbPath'] as String;
  final assetsRaw = (message['assets'] as List).cast<Map<String, Object?>>();

  BackgroundIsolateBinaryMessenger.ensureInitialized(token);

  final commandPort = ReceivePort();
  mainSendPort.send({
    'type': 'ready',
    'commandPort': commandPort.sendPort,
  });

  var cancelled = false;
  commandPort.listen((msg) {
    if (msg is Map && msg['type'] == 'cancel') cancelled = true;
  });

  final assets = assetsRaw.map(_assetFromMap).toList();
  final client = http.Client();

  try {
    final count = await runDiffSyncLogic(
      dbPath: dbPath,
      assets: assets,
      httpClient: client,
      decompress: (bytes) async => Zstandard().decompress(bytes),
      isCancelled: () => cancelled,
      onProgress: (update) => mainSendPort.send(_updateToMap(update)),
    );
    mainSendPort.send({'type': 'completed', 'appliedAssetCount': count});
  } on _CancelledException {
    mainSendPort.send({'type': 'cancelled'});
  } catch (e) {
    mainSendPort.send({'type': 'failed', 'message': e.toString()});
  } finally {
    commandPort.close();
    client.close();
  }
}

// ── Core sync logic (testable without isolate) ────────────────────────────────

@visibleForTesting
Future<int> runDiffSyncLogic({
  required String dbPath,
  required List<DiffReleaseAsset> assets,
  required http.Client httpClient,
  required Future<Uint8List?> Function(Uint8List) decompress,
  required bool Function() isCancelled,
  required void Function(LibraryDiffSyncUpdate) onProgress,
}) async {
  final total = assets.length;
  var applied = 0;

  for (var i = 0; i < total; i++) {
    final asset = assets[i];
    _throwIfCancelled(isCancelled);

    // ── 1. Download ──────────────────────────────────────────────────────────
    onProgress(LibraryDiffStageChanged(
      stage: 'downloadStarted',
      assetName: asset.assetName,
      assetIndex: i,
      totalAssets: total,
    ));

    final throttler = _ProgressThrottler();
    final compressedBytes = await _downloadWithProgress(
      client: httpClient,
      uri: Uri.parse(asset.downloadUrl),
      isCancelled: isCancelled,
      onProgress: (downloaded, totalBytes) {
        if (throttler.shouldSend()) {
          onProgress(LibraryDiffDownloadProgress(
            assetName: asset.assetName,
            downloadedBytes: downloaded,
            totalBytes: totalBytes,
          ));
        }
      },
    );
    // Always send final download progress
    onProgress(LibraryDiffDownloadProgress(
      assetName: asset.assetName,
      downloadedBytes: compressedBytes.length,
      totalBytes: compressedBytes.length,
    ));

    _throwIfCancelled(isCancelled);

    // ── 2. Decompress ─────────────────────────────────────────────────────────
    onProgress(LibraryDiffStageChanged(
      stage: 'extractStarted',
      assetName: asset.assetName,
      assetIndex: i,
      totalAssets: total,
    ));

    final extractedBytes = await decompress(compressedBytes);
    if (extractedBytes == null || extractedBytes.isEmpty) {
      throw Exception('קובץ ה-DIFF שחולץ ריק: ${asset.assetName}');
    }

    _throwIfCancelled(isCancelled);

    // ── 3. Split SQL ──────────────────────────────────────────────────────────
    onProgress(LibraryDiffStageChanged(
      stage: 'sqlSplitStarted',
      assetName: asset.assetName,
      assetIndex: i,
      totalAssets: total,
    ));

    final sql = utf8.decode(extractedBytes);
    final statements = FileSyncRepository.splitSqlStatements(sql);
    if (statements.isEmpty) {
      throw Exception('קובץ ה-DIFF אינו מכיל פקודות SQL: ${asset.assetName}');
    }

    _throwIfCancelled(isCancelled);

    // ── 4. Apply SQL ──────────────────────────────────────────────────────────
    onProgress(LibraryDiffStageChanged(
      stage: 'applyStarted',
      assetName: asset.assetName,
      assetIndex: i,
      totalAssets: total,
    ));

    final applyThrottler = _ProgressThrottler();
    final db = sqlite3.sqlite3.open(dbPath);
    try {
      for (var j = 0; j < statements.length; j++) {
        _throwIfCancelled(isCancelled);
        db.execute(statements[j]);

        final isLast = j == statements.length - 1;
        if (isLast || applyThrottler.shouldSend()) {
          onProgress(LibraryDiffApplyProgress(
            assetName: asset.assetName,
            appliedStatements: j + 1,
            totalStatements: statements.length,
            assetIndex: i,
            totalAssets: total,
          ));
        }
      }
    } finally {
      db.close();
    }

    applied++;
    onProgress(LibraryDiffStageChanged(
      stage: 'assetCompleted',
      assetName: asset.assetName,
      assetIndex: i,
      totalAssets: total,
    ));
  }

  return applied;
}

// ── Private helpers ───────────────────────────────────────────────────────────

class _CancelledException implements Exception {
  const _CancelledException();
}

void _throwIfCancelled(bool Function() isCancelled) {
  if (isCancelled()) throw const _CancelledException();
}

Future<Uint8List> _downloadWithProgress({
  required http.Client client,
  required Uri uri,
  required bool Function() isCancelled,
  required void Function(int downloaded, int? total) onProgress,
}) async {
  final request = http.Request('GET', uri)
    ..headers['Accept'] = 'application/octet-stream';

  final response = await client.send(request);

  if (response.statusCode != 200) {
    throw Exception('שגיאה בהורדה (${response.statusCode}): $uri');
  }

  final total = response.contentLength;
  final builder = BytesBuilder(copy: false);
  var downloaded = 0;

  await for (final chunk in response.stream) {
    if (isCancelled()) throw const _CancelledException();
    builder.add(chunk);
    downloaded += chunk.length;
    onProgress(downloaded, total);
  }

  return builder.takeBytes();
}

class _ProgressThrottler {
  DateTime? _lastSentAt;

  bool shouldSend({bool force = false}) {
    if (force) {
      _lastSentAt = DateTime.now();
      return true;
    }
    final now = DateTime.now();
    final last = _lastSentAt;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 100)) {
      return false;
    }
    _lastSentAt = now;
    return true;
  }
}

Map<String, Object?> _updateToMap(LibraryDiffSyncUpdate update) {
  return switch (update) {
    LibraryDiffStageChanged u => {
        'type': 'stageChanged',
        'stage': u.stage,
        'assetName': u.assetName,
        'assetIndex': u.assetIndex,
        'totalAssets': u.totalAssets,
      },
    LibraryDiffDownloadProgress u => {
        'type': 'downloadProgress',
        'assetName': u.assetName,
        'downloadedBytes': u.downloadedBytes,
        'totalBytes': u.totalBytes,
      },
    LibraryDiffApplyProgress u => {
        'type': 'applyProgress',
        'assetName': u.assetName,
        'appliedStatements': u.appliedStatements,
        'totalStatements': u.totalStatements,
        'assetIndex': u.assetIndex,
        'totalAssets': u.totalAssets,
      },
    LibraryDiffSyncCompleted u => {
        'type': 'completed',
        'appliedAssetCount': u.appliedAssetCount,
      },
    LibraryDiffSyncFailed u => {
        'type': 'failed',
        'message': u.message,
      },
    LibraryDiffSyncCancelled _ => {'type': 'cancelled'},
  };
}

Map<String, Object?> _assetToMap(DiffReleaseAsset a) => {
      'fromVersion': a.fromVersion,
      'toVersion': a.toVersion,
      'assetName': a.assetName,
      'downloadUrl': a.downloadUrl,
      'releaseTag': a.releaseTag,
      'releaseName': a.releaseName,
    };

DiffReleaseAsset _assetFromMap(Map<String, Object?> m) => DiffReleaseAsset(
      fromVersion: m['fromVersion'] as int,
      toVersion: m['toVersion'] as int,
      assetName: m['assetName'] as String,
      downloadUrl: m['downloadUrl'] as String,
      releaseTag: m['releaseTag'] as String,
      releaseName: m['releaseName'] as String,
    );
