import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:otzaria/plugins/services/plugin_runtime_dispatcher.dart';

/// תוצאת ספר יחידה ממקור חיפוש חיצוני של תוסף (למשל היברובוקס).
class ExternalSearchResult {
  final String title;

  /// שורת מטא-נתונים להצגה (מחבר · מקום · שנה).
  final String? meta;

  /// קטע טקסט רגיל מסביב להתאמה; ההדגשה נעשית בצד המסך לפי השאילתה.
  final String? snippet;

  final int hitCount;

  /// עמוד ההתאמה הראשונה, מבוסס-1.
  final int? firstPage;

  final String provider;
  final Object externalId;

  const ExternalSearchResult({
    required this.title,
    this.meta,
    this.snippet,
    required this.hitCount,
    this.firstPage,
    required this.provider,
    required this.externalId,
  });
}

/// עמוד תוצאות ממקור חיצוני.
class ExternalSearchPage {
  final List<ExternalSearchResult> results;
  final int totalBooks;
  final int totalHits;
  final bool hasMore;

  const ExternalSearchPage({
    required this.results,
    required this.totalBooks,
    required this.totalHits,
    required this.hasMore,
  });
}

/// ספקי תוצאות חיצוניים למסך החיפוש המובנה.
///
/// אוצריא אינה מדברת עם מנועי חיפוש חיצוניים בעצמה (התקשורת עם שירות
/// HebrewBooks שייכת לתוסף בלבד). תוסף נרשם כספק עבור provider חיצוני,
/// מסך החיפוש שולח אליו בקשה כאירוע ממוקד `search.external.requested`,
/// והתוסף עונה בקריאת bridge `reader.respondExternalSearch` עם עמוד תוצאות.
class PluginExternalSearchService {
  PluginExternalSearchService._();
  static final PluginExternalSearchService instance =
      PluginExternalSearchService._();

  static const requestTopic = 'search.external.requested';

  /// חיפוש מלא מול שירות חיצוני עשוי לקחת זמן (כולל חילוץ קטעי טקסט).
  static const _timeout = Duration(seconds: 45);

  static const _maxResultsPerPage = 50;
  static const _maxTitleLength = 300;
  static const _maxMetaLength = 300;
  static const _maxSnippetLength = 600;

  final Map<String, String> _providerToPlugin = {};
  final Map<String, Completer<ExternalSearchPage>> _pending = {};
  final Map<String, String> _pendingProvider = {};
  int _requestCounter = 0;

  /// רושם את [pluginId] כספק עבור [provider]. רישום חוזר מחליף את הקודם —
  /// תוסף נרשם מחדש בכל boot, כך שאין צורך במנגנון הסרה נפרד.
  void register(String provider, String pluginId) {
    _providerToPlugin[provider] = pluginId;
    debugPrint('PluginExternalSearchService: $pluginId provides "$provider"');
  }

  bool hasProvider(String provider) => _providerToPlugin.containsKey(provider);

  /// שולח שאילתה מעומדת לספק של [provider] ומחזיר עמוד תוצאות.
  /// זורק [TimeoutException] כשהתוסף לא ענה בזמן, או [StateError] כשאין ספק.
  Future<ExternalSearchPage> search({
    required String provider,
    required String query,
    String mode = 'exact',
    int distance = 1,
    int offset = 0,
    int limit = 20,
  }) async {
    final pluginId = _providerToPlugin[provider];
    if (pluginId == null) {
      throw StateError('No external search provider for "$provider"');
    }
    final requestId = 'xs-${++_requestCounter}';
    final completer = Completer<ExternalSearchPage>();
    _pending[requestId] = completer;
    _pendingProvider[requestId] = provider;
    try {
      await PluginRuntimeDispatcher.instance.dispatchEventToPlugin(
        pluginId,
        requestTopic,
        {
          'requestId': requestId,
          'provider': provider,
          'query': query,
          'mode': mode,
          'distance': distance,
          'offset': offset,
          'limit': limit,
        },
        preferBackground: true,
      );
      return await completer.future.timeout(_timeout);
    } finally {
      _pending.remove(requestId);
      _pendingProvider.remove(requestId);
    }
  }

  /// תשובת התוסף לבקשה: רשימת תוצאות גולמית שעוברת ניקוי וקיצוץ כאן.
  /// תשובה לבקשה שכבר פגה מתעלמים ממנה.
  void respond(
    String requestId, {
    List<Object?> results = const [],
    int totalBooks = 0,
    int totalHits = 0,
    bool hasMore = false,
    String? error,
  }) {
    final pending = _pending.remove(requestId);
    final provider = _pendingProvider.remove(requestId);
    if (pending == null || pending.isCompleted || provider == null) return;
    if (error != null && error.isNotEmpty) {
      pending.completeError(StateError(error));
      return;
    }
    final sanitized = <ExternalSearchResult>[];
    for (final raw in results.take(_maxResultsPerPage)) {
      final result = _sanitizeResult(raw, provider);
      if (result != null) sanitized.add(result);
    }
    pending.complete(
      ExternalSearchPage(
        results: sanitized,
        totalBooks: totalBooks < 0 ? 0 : totalBooks,
        totalHits: totalHits < 0 ? 0 : totalHits,
        hasMore: hasMore,
      ),
    );
  }

  ExternalSearchResult? _sanitizeResult(Object? raw, String provider) {
    if (raw is! Map) return null;
    final title = raw['title'];
    final externalId = raw['externalId'];
    if (title is! String || title.isEmpty) return null;
    if (externalId is! num && (externalId is! String || externalId.isEmpty)) {
      return null;
    }
    final hitCount = raw['hitCount'];
    final firstPage = raw['firstPage'];
    return ExternalSearchResult(
      title: _clip(title, _maxTitleLength)!,
      meta: _clip(raw['meta'], _maxMetaLength),
      snippet: _clip(raw['snippet'], _maxSnippetLength),
      hitCount: hitCount is num && hitCount > 0 ? hitCount.toInt() : 0,
      firstPage: firstPage is num && firstPage >= 1 ? firstPage.toInt() : null,
      provider: provider,
      externalId: externalId is num ? externalId.toInt() : externalId!,
    );
  }

  String? _clip(Object? value, int maxLength) {
    if (value is! String) return null;
    final text = value.replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), ' ').trim();
    if (text.isEmpty) return null;
    return text.length <= maxLength ? text : text.substring(0, maxLength);
  }
}
