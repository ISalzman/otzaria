import 'package:flutter/foundation.dart';
import 'package:otzaria/core/error_log_file.dart';
import 'package:otzaria/indexing/models/indexing_run_result.dart';

class IndexingFailureReporter {
  const IndexingFailureReporter._();

  static void write(IndexingRunResult result) {
    if (result.failures.isEmpty) return;
    try {
      ErrorLogFile.appendText(formatReport(result));
    } catch (error) {
      debugPrint('⚠️ כתיבת דוח כשלי האינדוקס נכשלה: $error');
    }
  }

  @visibleForTesting
  static void writeForTesting(
    IndexingRunResult result, {
    required String tempPath,
    DateTime? timestamp,
    String? version,
  }) {
    if (result.failures.isEmpty) return;
    ErrorLogFile.appendText(
      formatReport(result, timestamp: timestamp, version: version),
      environment: const {},
      platform: ErrorLogPlatform.other,
      tempPath: tempPath,
    );
  }

  static String formatReport(
    IndexingRunResult result, {
    DateTime? timestamp,
    String? version,
  }) {
    final buffer = StringBuffer()
      ..writeln(
        '=== Indexing failures ${(timestamp ?? DateTime.now()).toIso8601String()} ===',
      )
      ..writeln('Version: ${version ?? ErrorLogFile.appVersion}')
      ..writeln('Completed: ${result.completed}')
      ..writeln('Processed: ${result.processedBooks}/${result.totalBooks}')
      ..writeln('Indexed: ${result.indexedBooks}')
      ..writeln('Failures: ${result.failures.length}')
      ..writeln('Retryable: ${result.retryableFailures.length}')
      ..writeln('Warnings: ${result.warningCount}');

    for (var i = 0; i < result.failures.length; i++) {
      final failure = result.failures[i];
      buffer
        ..writeln()
        ..writeln('--- Failure ${i + 1} ---')
        ..writeln('Kind: ${failure.kind.name}')
        ..writeln('Retryable: ${failure.isRetryable}')
        ..writeln('Book: ${failure.bookTitle}')
        ..writeln('Path: ${failure.bookPath}')
        ..writeln('Error: ${failure.error}');
      final stackTrace = failure.stackTrace;
      if (stackTrace != null && stackTrace.trim().isNotEmpty) {
        buffer
          ..writeln('Stack:')
          ..writeln(stackTrace);
      }
    }
    buffer.writeln();
    return buffer.toString();
  }
}
