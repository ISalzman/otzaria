import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:otzaria/data/repository/hive_list_repository.dart';
import 'package:otzaria/models/direct_error_report.dart';
import 'package:otzaria/settings/engine/settings_repository.dart';
import 'package:otzaria/services/direct_error_report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Settings.init(cacheProvider: _MemoryCacheProvider());
    await Settings.setValue<bool>(SettingsRepository.keyOfflineMode, false);
    await Settings.setValue<bool>(
      SettingsRepository.keyQueueErrorReportsWhenOffline,
      true,
    );
  });

  group('DirectErrorReport', () {
    test('serializes to json and api payload', () {
      final createdAt = DateTime.parse('2026-03-16T10:15:00Z');
      final report = DirectErrorReport(
        id: 'report-1',
        senderEmail: 'user@example.com',
        subject: 'דיווח על טעות: ספר מבחן',
        bookTitle: 'ספר מבחן',
        currentRef: 'פרק א',
        lineNumber: 12,
        selectedText: 'טקסט עם טעות',
        errorDetails: 'חסר ניקוד',
        contextText: 'הקשר רחב יותר',
        filePath: '/books/test.txt',
        sourceFolder: 'sefaria',
        queueType: DirectErrorReportQueueType.automaticRetry,
        createdAt: createdAt,
      );

      final json = report.toJson();
      final restored = DirectErrorReport.fromJson(json);
      final apiPayload = report.toApiPayload();

      expect(restored, equals(report));
      expect(apiPayload['sender_email'], 'user@example.com');
      expect(apiPayload.containsKey('recipient_email'), isFalse);
      expect(apiPayload['line_number'], 12);
      expect(apiPayload['current_ref'], 'פרק א');
      expect(apiPayload['selected_text'], 'טקסט עם טעות');
      expect(apiPayload['error_details'], 'חסר ניקוד');
      expect(apiPayload['context_text'], 'הקשר רחב יותר');
      expect(apiPayload['file_path'], '/books/test.txt');
      expect(apiPayload['source_folder'], 'sefaria');
      expect(apiPayload['created_at'], createdAt.toIso8601String());
      expect(apiPayload.containsKey('body'), isFalse);
      expect(apiPayload.containsKey('file_name'), isFalse);
      expect(json['queueType'], 'automaticRetry');
      expect(restored.queueType, DirectErrorReportQueueType.automaticRetry);
    });

    test('defaults missing queueType from json to manual', () {
      final report = DirectErrorReport.fromJson({
        'id': 'report-legacy',
        'senderEmail': 'user@example.com',
        'subject': 'legacy',
        'bookTitle': 'legacy book',
        'currentRef': 'legacy ref',
        'lineNumber': 3,
        'createdAt': '2026-03-16T10:15:00Z',
      });

      expect(report.queueType, DirectErrorReportQueueType.manual);
    });
  });

  group('DirectErrorReportService.isValidSenderEmail', () {
    test('accepts valid addresses', () {
      expect(
        DirectErrorReportService.isValidSenderEmail('name@example.com'),
        isTrue,
      );
      expect(
        DirectErrorReportService.isValidSenderEmail('user.name+tag@foo.co.il'),
        isTrue,
      );
    });

    test('rejects invalid addresses', () {
      expect(DirectErrorReportService.isValidSenderEmail(''), isFalse);
      expect(DirectErrorReportService.isValidSenderEmail('invalid'), isFalse);
      expect(
        DirectErrorReportService.isValidSenderEmail('no-domain@localhost'),
        isFalse,
      );
      expect(
        DirectErrorReportService.isValidSenderEmail('with space@example.com '),
        isFalse,
      );
    });
  });

  group('DirectErrorReportService.buildOfflineSendBatchScript', () {
    test('creates bat file with chunked powershell payloads', () {
      final service = DirectErrorReportService(
        queueRepository: HiveListRepository<DirectErrorReport>(
          boxName: 'test_box',
          key: 'test_key',
          fromJson: DirectErrorReport.fromJson,
          toJson: (report) => report.toJson(),
        ),
      );
      final report = DirectErrorReport(
        id: 'report-42',
        senderEmail: 'user@example.com',
        subject: 'בדיקה',
        bookTitle: 'ספר מבחן',
        currentRef: 'פרק ב',
        lineNumber: 7,
        selectedText: 'שגיאה',
        errorDetails: 'פרט',
        contextText: 'הקשר',
        filePath: 'C:/books/book.txt',
        sourceFolder: 'local',
        createdAt: DateTime.parse('2026-03-16T10:15:00Z'),
      );

      final bat = service.buildOfflineSendBatchScript([report]);
      final base64BlockMatch = RegExp(
        r'> "%OTZARIA_PS_B64%" \((.*?)\n\)',
        dotAll: true,
      ).firstMatch(bat);

      expect(bat, contains('@echo off'));
      expect(
          bat,
          contains(
              'powershell.exe -NoProfile -ExecutionPolicy Bypass -Command'));
      expect(base64BlockMatch, isNotNull);

      final base64Lines = RegExp(r'^\s*echo\s+(.+)$', multiLine: true)
          .allMatches(base64BlockMatch!.group(1)!)
          .map((match) => match.group(1)!.trim())
          .join();
      final decodedPowerShell = _decodeUtf8Bom(base64.decode(base64Lines));
      final payloadBase64Match = RegExp(
        r"\$payloadsJsonBase64\s*=\s*(.*?)\n\s*\$payloadsJson\s*=",
        dotAll: true,
      ).firstMatch(decodedPowerShell);

      expect(decodedPowerShell,
          contains('http://otzaria.org/api/reportingerrors'));
      expect(decodedPowerShell, contains('Invoke-WebRequest'));
      expect(payloadBase64Match, isNotNull);
      expect(decodedPowerShell, contains(r'$payloadsJsonBase64 ='));
      expect(decodedPowerShell,
          contains(r'[Convert]::FromBase64String($payloadsJsonBase64)'));
      expect(decodedPowerShell, isNot(contains(r"$payloadsJson = @'")));

      final payloadJson = utf8.decode(
        base64.decode(
          RegExp(r"'([^']+)'")
              .allMatches(payloadBase64Match!.group(1)!)
              .map((match) => match.group(1)!)
              .join(),
        ),
      );

      expect(payloadJson, contains('report-42'));
    });
  });

  group('DirectErrorReportService.flushPendingReports', () {
    test('automatic flush sends only retryable queued reports', () async {
      final repository = InMemoryDirectErrorReportRepository();

      await repository.save([
        _buildReport(
          id: 'manual-report',
          queueType: DirectErrorReportQueueType.manual,
        ),
        _buildReport(
          id: 'retry-report',
          queueType: DirectErrorReportQueueType.automaticRetry,
        ),
      ]);

      final sentReportIds = <String>[];
      final service = DirectErrorReportService(
        client: MockClient((request) async {
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          sentReportIds.add(payload['report_id'] as String);
          return http.Response('', 200);
        }),
        queueRepository: repository,
      );

      final sentCount =
          await service.flushPendingReports(onlyAutomaticRetry: true);
      final remainingReports = await repository.load();

      expect(sentCount, 1);
      expect(sentReportIds, ['retry-report']);
      expect(
        remainingReports.map((report) => report.id).toList(),
        ['manual-report'],
      );
    });

    test('permanent failure is removed and does not block later reports',
        () async {
      final repository = InMemoryDirectErrorReportRepository();

      await repository.save([
        _buildReport(
          id: 'invalid-report',
          queueType: DirectErrorReportQueueType.automaticRetry,
        ),
        _buildReport(
          id: 'valid-report',
          queueType: DirectErrorReportQueueType.automaticRetry,
        ),
        _buildReport(
          id: 'manual-report',
          queueType: DirectErrorReportQueueType.manual,
        ),
      ]);

      final attemptedReportIds = <String>[];
      final service = DirectErrorReportService(
        client: MockClient((request) async {
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          final reportId = payload['report_id'] as String;
          attemptedReportIds.add(reportId);

          if (reportId == 'invalid-report') {
            return http.Response('bad request', 400);
          }

          return http.Response('', 200);
        }),
        queueRepository: repository,
      );

      final sentCount =
          await service.flushPendingReports(onlyAutomaticRetry: true);
      final remainingReports = await repository.load();

      expect(sentCount, 1);
      expect(attemptedReportIds, ['invalid-report', 'valid-report']);
      expect(
        remainingReports.map((report) => report.id).toList(),
        ['manual-report'],
      );
    });
  });

  group('DirectErrorReportService.submitReport', () {
    test('permanent failure does not queue the current report', () async {
      final repository = InMemoryDirectErrorReportRepository();
      final service = DirectErrorReportService(
        client: MockClient((request) async => http.Response('bad request', 400)),
        queueRepository: repository,
      );

      final result = await service.submitReport(
        _buildReport(
          id: 'invalid-current-report',
          queueType: DirectErrorReportQueueType.automaticRetry,
        ),
      );
      final remainingReports = await repository.load();

      expect(result.status, DirectReportDeliveryStatus.failed);
      expect(result.isQueued, isFalse);
      expect(remainingReports, isEmpty);
    });

    test('404 is treated as transient and queues the current report', () async {
      final repository = InMemoryDirectErrorReportRepository();
      final service = DirectErrorReportService(
        client: MockClient((request) async => http.Response('not found', 404)),
        queueRepository: repository,
      );

      final result = await service.submitReport(
        _buildReport(
          id: 'missing-endpoint-report',
          queueType: DirectErrorReportQueueType.automaticRetry,
        ),
      );
      final remainingReports = await repository.load();

      expect(result.status, DirectReportDeliveryStatus.queued);
      expect(result.isQueued, isTrue);
      expect(remainingReports.map((report) => report.id).toList(), [
        'missing-endpoint-report',
      ]);
      expect(
        remainingReports.single.queueType,
        DirectErrorReportQueueType.automaticRetry,
      );
    });
  });
}

DirectErrorReport _buildReport({
  required String id,
  DirectErrorReportQueueType queueType = DirectErrorReportQueueType.manual,
}) {
  return DirectErrorReport(
    id: id,
    senderEmail: 'user@example.com',
    subject: 'בדיקה',
    bookTitle: 'ספר מבחן',
    currentRef: 'פרק ב',
    lineNumber: 7,
    selectedText: 'שגיאה',
    errorDetails: 'פרט',
    contextText: 'הקשר',
    filePath: 'C:/books/book.txt',
    sourceFolder: 'local',
    queueType: queueType,
    createdAt: DateTime.parse('2026-03-16T10:15:00Z'),
  );
}

String _decodeUtf8Bom(List<int> bytes) {
  final bytesWithoutBom = bytes.length >= 3 &&
          bytes[0] == 0xEF &&
          bytes[1] == 0xBB &&
          bytes[2] == 0xBF
      ? bytes.sublist(3)
      : bytes;
  return utf8.decode(bytesWithoutBom);
}

class InMemoryDirectErrorReportRepository
    extends HiveListRepository<DirectErrorReport> {
  List<DirectErrorReport> _items = [];

  InMemoryDirectErrorReportRepository()
      : super(
          boxName: 'in_memory',
          key: 'pending_reports',
          fromJson: DirectErrorReport.fromJson,
          toJson: (report) => report.toJson(),
        );

  @override
  Future<List<DirectErrorReport>> load() async {
    return List<DirectErrorReport>.from(_items);
  }

  @override
  Future<void> save(List<DirectErrorReport> items) async {
    _items = List<DirectErrorReport>.from(items);
  }

  @override
  Future<void> clear() async {
    _items = [];
  }
}

class _MemoryCacheProvider extends CacheProvider {
  final Map<String, Object?> _values = {};

  @override
  Future<void> init() async {}

  @override
  bool containsKey(String key) => _values.containsKey(key);

  @override
  Set getKeys() => _values.keys.toSet();

  @override
  bool? getBool(String key, {bool? defaultValue}) =>
      _values[key] as bool? ?? defaultValue;

  @override
  double? getDouble(String key, {double? defaultValue}) =>
      _values[key] as double? ?? defaultValue;

  @override
  int? getInt(String key, {int? defaultValue}) =>
      _values[key] as int? ?? defaultValue;

  @override
  String? getString(String key, {String? defaultValue}) =>
      _values[key] as String? ?? defaultValue;

  @override
  T? getValue<T>(String key, {T? defaultValue}) {
    final value = _values[key];
    if (value is T) {
      return value;
    }
    return defaultValue;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> removeAll() async {
    _values.clear();
  }

  @override
  Future<void> setBool(String key, bool? value) async {
    _values[key] = value;
  }

  @override
  Future<void> setDouble(String key, double? value) async {
    _values[key] = value;
  }

  @override
  Future<void> setInt(String key, int? value) async {
    _values[key] = value;
  }

  @override
  Future<void> setString(String key, String? value) async {
    _values[key] = value;
  }

  @override
  Future<void> setObject<T>(String key, T? value) async {
    _values[key] = value;
  }
}
