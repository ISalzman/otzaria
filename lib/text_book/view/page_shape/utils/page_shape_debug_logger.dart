import 'package:flutter/foundation.dart';

/// שכבת תאימות מינימלית ללכידת שגיאות בצורת הדף.
///
/// מרבית דיבוג החקירה הוסר, ונשאר רק דיווח קומפקטי על שגיאות אמיתיות.
class PageShapeDebugLogger {
  static String newScope(String area, {String? label}) {
    final normalizedLabel = _normalizeText(label);
    if (normalizedLabel == null || normalizedLabel.isEmpty) {
      return area;
    }
    return '$area[$normalizedLabel]';
  }

  static PageShapeDebugTrace start(
    String area,
    String operation, {
    String? scope,
    Map<String, Object?> data = const {},
    Map<String, Object?> Function()? liveData,
    Duration longTaskAfter = const Duration(milliseconds: 700),
    Duration heartbeatEvery = const Duration(milliseconds: 500),
  }) {
    return PageShapeDebugTrace._(
      area: area,
      operation: operation,
      scope: scope,
      initialData: data,
      liveDataProvider: liveData,
    );
  }

  static void log(
    String area,
    String message, {
    String? scope,
    Map<String, Object?> data = const {},
    String level = 'INFO',
  }) {
    if (level != 'ERROR') {
      return;
    }

    final scopePart = scope == null || scope.isEmpty ? '' : '[$scope]';
    final dataPart = data.isEmpty ? '' : ' | ${_formatData(data)}';
    debugPrint(
      '[PageShape][ERROR][${DateTime.now().toIso8601String()}][$area]$scopePart $message$dataPart',
    );
  }

  static Map<String, Object?> summarizeIndices(Iterable<int> values) {
    final list = values.toList(growable: false);
    if (list.isEmpty) {
      return const {
        'count': 0,
        'first': null,
        'last': null,
      };
    }

    return {
      'count': list.length,
      'first': list.first,
      'last': list.last,
      'values': list.length <= 8
          ? list
          : <Object?>[
              ...list.take(4),
              '...',
              ...list.skip(list.length - 3),
            ],
    };
  }

  static String _formatData(Map<String, Object?> data) {
    return data.entries
        .map((entry) => '${entry.key}=${_formatValue(entry.value)}')
        .join(', ');
  }

  static String _formatValue(Object? value) {
    if (value == null) {
      return 'null';
    }

    if (value is Duration) {
      return '${value.inMilliseconds}ms';
    }

    if (value is Iterable) {
      final items = value.toList(growable: false);
      if (items.length <= 8) {
        return '[${items.map(_formatValue).join(', ')}]';
      }
      return '[${items.take(4).map(_formatValue).join(', ')}, ..., ${items.skip(items.length - 3).map(_formatValue).join(', ')}]';
    }

    if (value is Map) {
      final entries = value.entries.toList(growable: false);
      if (entries.length <= 8) {
        return '{${entries.map((entry) => '${entry.key}:${_formatValue(entry.value)}').join(', ')}}';
      }
      final head = entries.take(4);
      final tail = entries.skip(entries.length - 3);
      return '{${head.map((entry) => '${entry.key}:${_formatValue(entry.value)}').join(', ')}, ..., ${tail.map((entry) => '${entry.key}:${_formatValue(entry.value)}').join(', ')}}';
    }

    return _normalizeText(value.toString()) ?? '';
  }

  static String? _normalizeText(String? text) {
    if (text == null) {
      return null;
    }
    final singleLine = text.replaceAll('\n', r'\n').trim();
    if (singleLine.length <= 220) {
      return singleLine;
    }
    return '${singleLine.substring(0, 220)}...';
  }
}

class PageShapeDebugTrace {
  final String area;
  final String operation;
  final String? scope;
  final Map<String, Object?> initialData;
  final Map<String, Object?> Function()? liveDataProvider;

  const PageShapeDebugTrace._({
    required this.area,
    required this.operation,
    required this.scope,
    required this.initialData,
    required this.liveDataProvider,
  });

  Map<String, Object?> _currentData() {
    if (liveDataProvider == null) {
      return initialData;
    }

    try {
      return {
        ...initialData,
        ...liveDataProvider!.call(),
      };
    } catch (error, stackTrace) {
      return {
        ...initialData,
        'liveDataError': error,
        'liveDataStackTrace': stackTrace,
      };
    }
  }

  void step(String message, {Map<String, Object?> data = const {}}) {}

  void warn(String message, {Map<String, Object?> data = const {}}) {}

  void end({Map<String, Object?> data = const {}}) {}

  void fail(
    Object error,
    StackTrace stackTrace, {
    Map<String, Object?> data = const {},
  }) {
    PageShapeDebugLogger.log(
      area,
      'ERROR $operation',
      scope: scope,
      level: 'ERROR',
      data: {
        ..._currentData(),
        'error': error,
        'stackTrace': stackTrace,
        ...data,
      },
    );
  }
}
