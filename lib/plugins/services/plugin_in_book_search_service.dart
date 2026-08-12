import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:otzaria/plugins/services/plugin_runtime_dispatcher.dart';
import 'package:otzaria/tabs/models/external_book_matches.dart';

/// ספקי חיפוש-בתוך-ספר של תוספים.
///
/// אוצריא אינה מדברת עם מנועי חיפוש חיצוניים בעצמה (ראו למשל שירות
/// HebrewBooks — התקשורת איתו שייכת לתוסף בלבד). במקום זאת תוסף נרשם כספק
/// עבור provider חיצוני ('hebrewbooks'), הקורא שולח אליו בקשה כאירוע ממוקד
/// `reader.inBookSearch.requested`, והתוסף עונה בקריאת bridge
/// `reader.respondInBookSearch` עם עמודי ההתאמה.
class PluginInBookSearchService {
  PluginInBookSearchService._();
  static final PluginInBookSearchService instance =
      PluginInBookSearchService._();

  static const requestTopic = 'reader.inBookSearch.requested';
  static const _timeout = Duration(seconds: 30);

  final Map<String, String> _providerToPlugin = {};
  final Map<String, Completer<ExternalBookMatches>> _pending = {};
  int _requestCounter = 0;

  /// רושם את [pluginId] כספק עבור [provider]. רישום חוזר מחליף את הקודם —
  /// תוסף נרשם מחדש בכל boot, כך שאין צורך במנגנון הסרה נפרד.
  void register(String provider, String pluginId) {
    _providerToPlugin[provider] = pluginId;
    debugPrint('PluginInBookSearchService: $pluginId provides "$provider"');
  }

  bool hasProvider(String provider) => _providerToPlugin.containsKey(provider);

  /// שולח שאילתה לספק של [provider] ומחזיר את עמודי ההתאמה שלו.
  /// זורק [TimeoutException] כשהתוסף לא ענה בזמן, או [StateError] כשאין ספק.
  Future<ExternalBookMatches> search({
    required String provider,
    required Object externalId,
    required String query,
  }) async {
    final pluginId = _providerToPlugin[provider];
    if (pluginId == null) {
      throw StateError('No in-book search provider for "$provider"');
    }
    final requestId = 'ibs-${++_requestCounter}';
    final completer = Completer<ExternalBookMatches>();
    _pending[requestId] = completer;
    final eventPayload = {
      'requestId': requestId,
      'provider': provider,
      'externalId': externalId,
      'query': query,
    };
    Timer? retryTimer;
    try {
      // לא ממתינים ל-dispatch לפני ההאזנה: מסלול ההעֲרָה של התוסף עשוי
      // לקחת זמן, והטיימאאוט חייב למדוד את הבקשה כולה עם מאזין מחובר.
      final dispatch = PluginRuntimeDispatcher.instance.dispatchEventToPlugin(
        pluginId,
        requestTopic,
        eventPayload,
        preferBackground: true,
      );
      unawaited(
        dispatch.catchError((Object error, StackTrace stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        }),
      );
      // אירוע שנמסר לדף שעוד לא רשם מאזינים (טעינה-מחדש בזמן העֲרָה) אובד
      // בשקט — משגרים שוב פעם אחת אחרי שקט קצר; הבקשה אידמפוטנטית.
      retryTimer = Timer(const Duration(seconds: 8), () {
        if (completer.isCompleted) return;
        debugPrint('PluginInBookSearchService: retrying $requestId');
        unawaited(
          PluginRuntimeDispatcher.instance
              .dispatchEventToPlugin(
                pluginId,
                requestTopic,
                eventPayload,
                preferBackground: true,
              )
              .catchError((_) {}),
        );
      });
      return await completer.future.timeout(_timeout);
    } finally {
      retryTimer?.cancel();
      _pending.remove(requestId);
    }
  }

  /// תשובת התוסף לבקשה. [pages] מבוססי-1; תשובה לבקשה שכבר פגה מתעלמים ממנה.
  void respond(
    String requestId, {
    List<int> pages = const [],
    List<String> matchedTerms = const [],
    String query = '',
    String? error,
  }) {
    final pending = _pending.remove(requestId);
    if (pending == null || pending.isCompleted) return;
    if (error != null && error.isNotEmpty) {
      pending.completeError(StateError(error));
      return;
    }
    pending.complete(
      ExternalBookMatches(
        pages: pages,
        matchedTerms: matchedTerms,
        query: query,
      ),
    );
  }
}
