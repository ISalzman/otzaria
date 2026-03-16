import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:otzaria/data/repository/hive_list_repository.dart';
import 'package:otzaria/models/direct_error_report.dart';
import 'package:otzaria/settings/engine/settings_repository.dart';

enum DirectReportDeliveryStatus {
  sent,
  queued,
  failed,
}

class DirectReportDeliveryResult {
  final DirectReportDeliveryStatus status;
  final String message;

  const DirectReportDeliveryResult._({
    required this.status,
    required this.message,
  });

  factory DirectReportDeliveryResult.sent(String message) {
    return DirectReportDeliveryResult._(
      status: DirectReportDeliveryStatus.sent,
      message: message,
    );
  }

  factory DirectReportDeliveryResult.queued(String message) {
    return DirectReportDeliveryResult._(
      status: DirectReportDeliveryStatus.queued,
      message: message,
    );
  }

  factory DirectReportDeliveryResult.failed(String message) {
    return DirectReportDeliveryResult._(
      status: DirectReportDeliveryStatus.failed,
      message: message,
    );
  }

  bool get isSent => status == DirectReportDeliveryStatus.sent;

  bool get isQueued => status == DirectReportDeliveryStatus.queued;
}

class DirectErrorReportService {
  static const String _endpoint = 'https://otzaria.org/api/reportingerrors';
  static const String _queueBoxName = 'error_reports_queue';
  static const String _queueKey = 'pending_reports';
  static const Duration _timeout = Duration(seconds: 10);
  static const Duration _flushInterval = Duration(minutes: 5);
  static const int _maxQueuedFlushPerRun = 20;

  static Timer? _flushTimer;
  static bool _isFlushing = false;

  final http.Client _client;
  final HiveListRepository<DirectErrorReport> _queueRepository;

  DirectErrorReportService({
    http.Client? client,
    HiveListRepository<DirectErrorReport>? queueRepository,
  })  : _client = client ?? http.Client(),
        _queueRepository = queueRepository ??
            (() {
              Hive.box(name: _queueBoxName, maxSizeMiB: 20);
              return HiveListRepository<DirectErrorReport>(
                boxName: _queueBoxName,
                key: _queueKey,
                fromJson: DirectErrorReport.fromJson,
                toJson: (report) => report.toJson(),
              );
            })();

  String get senderEmail => (Settings.getValue<String>(
              SettingsRepository.keyErrorReportSenderEmail) ??
          '')
      .trim();

  bool get queueWhenOfflineEnabled =>
      Settings.getValue<bool>(
        SettingsRepository.keyQueueErrorReportsWhenOffline,
      ) ??
      true;

  bool get _isOfflineMode =>
      Settings.getValue<bool>(SettingsRepository.keyOfflineMode) ?? false;

  Future<void> saveSenderEmail(String email) async {
    await Settings.setValue(
      SettingsRepository.keyErrorReportSenderEmail,
      email.trim(),
    );
  }

  Future<void> clearSenderEmail() async {
    await Settings.setValue(SettingsRepository.keyErrorReportSenderEmail, '');
  }

  Future<void> setQueueWhenOfflineEnabled(bool value) async {
    await Settings.setValue(
      SettingsRepository.keyQueueErrorReportsWhenOffline,
      value,
    );
  }

  Future<int> getPendingReportsCount() async {
    final reports = await _queueRepository.load();
    return reports.length;
  }

  Future<List<DirectErrorReport>> getPendingReports() async {
    return _queueRepository.load();
  }

  Future<void> queueReport(
    DirectErrorReport report, {
    DirectErrorReportQueueType queueType = DirectErrorReportQueueType.manual,
  }) async {
    await _enqueueIfNeeded(report, queueType: queueType);
  }

  Future<void> clearPendingReports() async {
    await _queueRepository.clear();
  }

  String buildOfflineSendBatchScript(List<DirectErrorReport> reports) {
    final payloads = reports.map((report) => report.toApiPayload()).toList();
    final payloadJson = const JsonEncoder.withIndent('  ').convert(payloads);
    final powerShellScript = _buildOfflineSendPowerShellScript(payloadJson);
    final encodedScript = base64.encode(
      Uint8List.fromList(_encodeUtf8Bom(powerShellScript)),
    );
    final encodedChunks = _splitIntoChunks(encodedScript, 120);
    final base64EchoLines =
        encodedChunks.map((chunk) => '  echo $chunk').join('\n');

    return '''@echo off
setlocal EnableExtensions DisableDelayedExpansion
  set "OTZARIA_PS_B64=%TEMP%\\otzaria_send_saved_reports.ps1.b64"
  set "OTZARIA_PS1=%TEMP%\\otzaria_send_saved_reports.ps1"
echo Sending saved reports to Otzaria...
> "%OTZARIA_PS_B64%" (
$base64EchoLines
)
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "\$scriptBytes = [Convert]::FromBase64String((Get-Content -Raw \$env:OTZARIA_PS_B64)); [System.IO.File]::WriteAllBytes(\$env:OTZARIA_PS1, \$scriptBytes); & \$env:OTZARIA_PS1"
set "OTZARIA_EXIT_CODE=%ERRORLEVEL%"
del "%OTZARIA_PS_B64%" >nul 2>&1
del "%OTZARIA_PS1%" >nul 2>&1
if not "%OTZARIA_EXIT_CODE%"=="0" (
  echo Script execution failed.
)
pause
exit /b %OTZARIA_EXIT_CODE%
''';
  }

  Future<DirectReportDeliveryResult> submitReport(
    DirectErrorReport report,
  ) async {
    if (_isOfflineMode) {
      if (!queueWhenOfflineEnabled) {
        return DirectReportDeliveryResult.failed(
          'מצב אופליין פעיל, והגדרת התור האוטומטי כבויה.',
        );
      }

      await _enqueueIfNeeded(
        report,
        queueType: DirectErrorReportQueueType.automaticRetry,
      );
      return DirectReportDeliveryResult.queued(
        'אין כרגע חיבור. הדיווח נשמר ויישלח אוטומטית כשהתוכנה תחזור להיות מקוונת. ניתן לנהל את הדיווחים השמורים בהגדרות.',
      );
    }

    final attemptResult = await _trySend(report);
    if (attemptResult.isSuccess) {
      unawaited(flushPendingReports(onlyAutomaticRetry: true));
      return DirectReportDeliveryResult.sent(
          'הדיווח נשלח בהצלחה לצוות אוצריא.');
    }

    await _enqueueIfNeeded(
      report,
      queueType: DirectErrorReportQueueType.automaticRetry,
    );
    return DirectReportDeliveryResult.queued(
      'השליחה לא הצליחה כרגע. הדיווח נשמר להמשך ויישלח אוטומטית בניסיון הבא. ניתן לנהל את הדיווחים השמורים בהגדרות.',
    );
  }

  Future<int> flushPendingReports({
    bool onlyAutomaticRetry = false,
  }) async {
    if (_isOfflineMode || _isFlushing) {
      return 0;
    }

    _isFlushing = true;
    try {
      final pendingReports = await _queueRepository.load();
      if (pendingReports.isEmpty) {
        return 0;
      }

      final reportsToAttempt = onlyAutomaticRetry
          ? pendingReports
              .where(
                (report) =>
                    report.queueType == DirectErrorReportQueueType.automaticRetry,
              )
              .take(_maxQueuedFlushPerRun)
              .toList()
          : pendingReports.take(_maxQueuedFlushPerRun).toList();

      if (reportsToAttempt.isEmpty) {
        return 0;
      }

      final remainingReports = List<DirectErrorReport>.from(pendingReports);
      var sentCount = 0;

      for (final report in reportsToAttempt) {
        final attemptResult = await _trySend(report);

        if (attemptResult.isSuccess) {
          remainingReports.removeWhere((item) => item.id == report.id);
          sentCount++;
          continue;
        }

        break;
      }

      await _queueRepository.save(remainingReports);
      return sentCount;
    } finally {
      _isFlushing = false;
    }
  }

  Future<void> startAutomaticFlush() async {
    if (_flushTimer != null) {
      return;
    }

    unawaited(flushPendingReports(onlyAutomaticRetry: true));
    _flushTimer = Timer.periodic(_flushInterval, (_) {
      unawaited(flushPendingReports(onlyAutomaticRetry: true));
    });
  }

  static bool isValidSenderEmail(String email) {
    final normalized = email.trim();
    if (normalized.isEmpty) {
      return false;
    }

    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalized);
  }

  Future<void> _enqueueIfNeeded(
    DirectErrorReport report, {
    required DirectErrorReportQueueType queueType,
  }) async {
    final pendingReports = await _queueRepository.load();
    final alreadyQueued = pendingReports.any((item) => item.id == report.id);
    if (alreadyQueued) {
      return;
    }

    pendingReports.add(report.copyWith(queueType: queueType));
    await _queueRepository.save(pendingReports);
  }

  Future<_SendAttemptResult> _trySend(DirectErrorReport report) async {
    try {
      final response = await _client
          .post(
            Uri.parse(_endpoint),
            headers: const {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: jsonEncode(report.toApiPayload()),
          )
          .timeout(_timeout);

      if (response.statusCode == HttpStatus.ok) {
        return const _SendAttemptResult.success();
      }

      return _SendAttemptResult.transientFailure(
        'שרת הדיווחים החזיר ${response.statusCode}. הדיווח יישמר להמשך.',
      );
    } on SocketException catch (e) {
      debugPrint('Direct report network error: $e');
      return _SendAttemptResult.transientFailure(
        'אין כרגע חיבור לאינטרנט.',
      );
    } on http.ClientException catch (e) {
      debugPrint('Direct report client error: $e');
      return _SendAttemptResult.transientFailure(
        'שגיאה בשליחת הדיווח.',
      );
    } on TimeoutException {
      return _SendAttemptResult.transientFailure(
        'השרת לא הגיב בזמן.',
      );
    } catch (e) {
      debugPrint('Direct report unexpected error: $e');
      return _SendAttemptResult.transientFailure(
        'אירעה שגיאה לא צפויה בשליחת הדיווח.',
      );
    }
  }

  String _buildOfflineSendPowerShellScript(String payloadJson) {
    final payloadBase64 = base64.encode(utf8.encode(payloadJson));
    final payloadBase64Chunks = _splitIntoChunks(payloadBase64, 120);
    final payloadBase64Expression =
        payloadBase64Chunks.map((chunk) => "'$chunk'").join(' +\n  ');
    const scriptPrefix = r'''
$ErrorActionPreference = 'Continue'
$endpoint = 'https://otzaria.org/api/reportingerrors'
  $payloadsJsonBase64 =
    ''';
    const scriptSuffix = r'''
  $payloadsJson = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payloadsJsonBase64))
$payloads = $payloadsJson | ConvertFrom-Json

$sent = 0
$failed = 0

foreach ($payload in @($payloads)) {
  try {
    $body = $payload | ConvertTo-Json -Depth 10 -Compress
    $response = Invoke-WebRequest -Uri $endpoint -Method Post -ContentType 'application/json; charset=utf-8' -Body $body
    if ($response.StatusCode -eq 200) {
      $sent++
      Write-Host ('נשלח: ' + $payload.report_id) -ForegroundColor Green
    } else {
      $failed++
      Write-Host ('נכשל: ' + $payload.report_id + ' (סטטוס ' + $response.StatusCode + ')') -ForegroundColor Yellow
    }
  } catch {
    $failed++
    Write-Host ('נכשל: ' + $payload.report_id + ' (' + $_.Exception.Message + ')') -ForegroundColor Red
  }
}

Write-Host ''
Write-Host ('נשלחו בהצלחה: ' + $sent)
Write-Host ('נכשלו: ' + $failed)
''';

    return '$scriptPrefix$payloadBase64Expression\n$scriptSuffix';
  }

  List<int> _encodeUtf8Bom(String input) {
    return <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(input)];
  }

  List<String> _splitIntoChunks(String input, int chunkSize) {
    final chunks = <String>[];
    for (var index = 0; index < input.length; index += chunkSize) {
      final end =
          (index + chunkSize < input.length) ? index + chunkSize : input.length;
      chunks.add(input.substring(index, end));
    }
    return chunks;
  }
}

class _SendAttemptResult {
  final bool isSuccess;
  final String message;

  const _SendAttemptResult._({
    required this.isSuccess,
    required this.message,
  });

  const _SendAttemptResult.success() : this._(isSuccess: true, message: '');

  factory _SendAttemptResult.transientFailure(String message) {
    return _SendAttemptResult._(
      isSuccess: false,
      message: message,
    );
  }
}
