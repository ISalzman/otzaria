import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/core/internet_connectivity.dart';
import 'package:otzaria/settings/engine/settings_repository.dart';

/// תמונת מצב הקישוריות שאוצריא מדווחת לתוספים.
@immutable
class ConnectivitySnapshot {
  const ConnectivitySnapshot({
    required this.isOfflineMode,
    required this.hasNetwork,
  });

  /// המשתמש סימן "ללא גישה לאינטרנט" בהגדרות.
  final bool isOfflineMode;

  /// נמצא חיבור בפועל בבדיקה. במצב מנותק תמיד `false` — הבדיקה כלל אינה רצה.
  final bool hasNetwork;

  /// הדגל היחיד שתוסף צריך כדי להחליט אם להציג יכולת מקוונת.
  bool get isOnline => !isOfflineMode && hasNetwork;

  Map<String, Object?> toJson() => {
    'isOfflineMode': isOfflineMode,
    'hasNetwork': hasNetwork,
    'isOnline': isOnline,
  };
}

/// מספק מצב קישוריות יציב לתוספים, בלי קריאת רשת לכל שאילתה.
///
/// הבדיקה נקבעת פעם אחת ונשמרת: תוסף שמסתיר כפתור מקוון צריך תשובה קבועה,
/// אחרת הכפתור מהבהב בין רינדורים. במצב מנותק לא מתבצעת בדיקה כלל.
class ConnectivityStatusService {
  ConnectivityStatusService({
    bool Function()? offlineModeReader,
    Future<bool> Function()? networkProbe,
  }) : _offlineModeReader = offlineModeReader ?? _readOfflineModeSetting,
       _networkProbe = networkProbe ?? _probeOtzariaTargets;

  static ConnectivityStatusService instance = ConnectivityStatusService();

  final bool Function() _offlineModeReader;
  final Future<bool> Function() _networkProbe;

  bool? _cachedHasNetwork;
  Future<bool>? _pendingProbe;

  static bool _readOfflineModeSetting() =>
      Settings.getValue<bool>(SettingsRepository.keyOfflineMode) ?? false;

  static Future<bool> _probeOtzariaTargets() =>
      hasInternetConnection(targets: kOtzariaProbeTargets);

  /// מצב הקישוריות הנוכחי. מריצה בדיקת רשת רק בפעם הראשונה שנדרשת.
  Future<ConnectivitySnapshot> snapshot() async {
    if (_offlineModeReader()) {
      // לא מקבעים `false` בקאש: המשתמש עשוי לכבות את המצב המנותק תוך כדי
      // ריצה, ואז הבדיקה הראשונה אמורה לרוץ באמת.
      return const ConnectivitySnapshot(
        isOfflineMode: true,
        hasNetwork: false,
      );
    }
    return ConnectivitySnapshot(
      isOfflineMode: false,
      hasNetwork: await _resolveHasNetwork(),
    );
  }

  /// תמונת המצב אם היא כבר מוכנה, בלי להמתין לבדיקה. `null` = טרם הוכרעה.
  ConnectivitySnapshot? get cached {
    if (_offlineModeReader()) {
      return const ConnectivitySnapshot(isOfflineMode: true, hasNetwork: false);
    }
    final hasNetwork = _cachedHasNetwork;
    if (hasNetwork == null) return null;
    return ConnectivitySnapshot(isOfflineMode: false, hasNetwork: hasNetwork);
  }

  /// מפעילה את הבדיקה ברקע בלי להמתין לה.
  void prewarm() {
    if (_offlineModeReader()) return;
    unawaited(_resolveHasNetwork());
  }

  /// מצב הקישוריות ל-payload של עליית תוסף — **סינכרוני, בלי המתנה לרשת**.
  ///
  /// כשהבדיקה טרם הוכרעה מוחזר `null` והיא מופעלת ברקע. אסור להמתין כאן:
  /// המתנה לרשת מעכבת את הצגת התוסף בכמה שניות אצל מי שאין לו חיבור.
  Map<String, Object?> bootPayload() {
    final snapshot = cached;
    if (snapshot != null) return snapshot.toJson();
    prewarm();
    return {
      'isOfflineMode': false,
      'hasNetwork': null,
      'isOnline': null,
    };
  }

  Future<bool> _resolveHasNetwork() {
    final cached = _cachedHasNetwork;
    if (cached != null) return Future.value(cached);

    // בדיקות מקבילות מתלכדות לבדיקה אחת — פתיחת כמה תוספים יחד לא פותחת
    // כמה חיבורים.
    final pending = _pendingProbe;
    if (pending != null) return pending;

    final probe = _runProbe();
    _pendingProbe = probe;
    // הניקוי אחרי ההשמה בכוונה: כשל סינכרוני של הבדיקה מסיים את `probe` עוד
    // לפני שהושם, ו-finally בתוך `_runProbe` היה משאיר כאן Future תקוע לנצח.
    unawaited(probe.whenComplete(() => _pendingProbe = null));
    return probe;
  }

  Future<bool> _runProbe() async {
    try {
      final result = await _networkProbe();
      _cachedHasNetwork = result;
      return result;
    } catch (_) {
      _cachedHasNetwork = false;
      return false;
    }
  }

  /// איפוס לבדיקות בלבד.
  @visibleForTesting
  void resetCache() {
    _cachedHasNetwork = null;
    _pendingProbe = null;
  }
}
