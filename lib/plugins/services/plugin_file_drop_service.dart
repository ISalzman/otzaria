import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// גרירת קבצים מהמערכת מעל חלון האפליקציה.
@immutable
class PluginFileDrag {
  /// נתיבי הקבצים הנגררים. ריק בגרירת קבצים וירטואליים (למשל מתוך ZIP).
  final List<String> paths;

  /// מיקום הסמן בפיקסלים פיזיים של אזור הלקוח.
  final Offset physicalPosition;

  const PluginFileDrag({required this.paths, required this.physicalPosition});
}

/// מקבל גרירות קבצים מה-`IDropTarget` של flutter_inappwebview.
///
/// ל-Windows יש `IDropTarget` יחיד לכל חלון, והוא בבעלות הפורק של
/// flutter_inappwebview — לכן הגרירה מגיעה משם ולא מחבילת גרירה נפרדת.
class PluginFileDropService {
  PluginFileDropService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static const String channelName =
      'com.pichillilorenzo/flutter_inappwebview_filedrop';

  static PluginFileDropService instance = PluginFileDropService();

  final MethodChannel _channel;

  /// הגרירה הפעילה, או `null` כשאין גרירת קבצים מעל החלון.
  final ValueNotifier<PluginFileDrag?> drag = ValueNotifier(null);

  final StreamController<PluginFileDrag> _drops =
      StreamController<PluginFileDrag>.broadcast();

  /// שחרור קבצים מעל החלון. אזורי הקליטה מסננים לפי המיקום.
  Stream<PluginFileDrag> get drops => _drops.stream;

  /// הצד ה-native קיים ב-Windows בלבד.
  static bool get isSupported => !kIsWeb && Platform.isWindows;

  int _zones = 0;
  final Set<Object> _accepting = {};
  bool _lastAccepted = false;

  /// מדווח אם [zone] מוכן לקבל את הגרירה הנוכחית. הצד ה-native משתמש בזה
  /// כדי להציג סמן גרירה רק מעל אזור שבאמת יקלוט את הקובץ.
  void setZoneAccepting(Object zone, bool accepting) {
    if (accepting) {
      _accepting.add(zone);
    } else {
      _accepting.remove(zone);
    }
    final accepted = _accepting.isNotEmpty;
    if (accepted == _lastAccepted) return;
    _lastAccepted = accepted;
    _setAccepted(accepted);
  }

  Future<void> _setAccepted(bool accepted) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('setAccepted', {'accepted': accepted});
    } on MissingPluginException {
      // בנייה ללא הצד ה-native של הפורק.
    }
  }

  @visibleForTesting
  bool get acceptedForTest => _lastAccepted;

  /// מפעיל את קליטת הגרירה כל עוד קיים אזור קליטה מותקן. בלי אזור פעיל
  /// החלון ממשיך לדחות קבצים כמקודם.
  Future<void> acquire() async {
    _zones++;
    if (_zones == 1) await _setEnabled(true);
  }

  Future<void> release() async {
    if (_zones == 0) return;
    _zones--;
    if (_zones == 0) {
      drag.value = null;
      await _setEnabled(false);
    }
  }

  Future<void> _setEnabled(bool enabled) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('setEnabled', {'enabled': enabled});
    } on MissingPluginException {
      // בנייה ללא הצד ה-native של הפורק — גרירה פשוט לא תעבוד.
    }
  }

  @visibleForTesting
  Future<void> handleNativeCall(MethodCall call) => _handleNativeCall(call);

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'onFileDrop') return;
    final args = (call.arguments as Map).cast<Object?, Object?>();
    final event = args['event'] as String?;
    if (event == 'leave') {
      drag.value = null;
      return;
    }

    final position = Offset(
      (args['x'] as num?)?.toDouble() ?? 0,
      (args['y'] as num?)?.toDouble() ?? 0,
    );
    final paths = (args['paths'] as List?)?.cast<String>() ?? const <String>[];

    switch (event) {
      case 'enter':
        drag.value = PluginFileDrag(paths: paths, physicalPosition: position);
      case 'over':
        // אירוע ה-over לא נושא נתיבים — שומרים את אלה שהתקבלו ב-enter.
        final current = drag.value;
        if (current != null) {
          drag.value = PluginFileDrag(
            paths: current.paths,
            physicalPosition: position,
          );
        }
      case 'drop':
        drag.value = null;
        _drops.add(
          PluginFileDrag(paths: paths, physicalPosition: position),
        );
    }
  }
}
