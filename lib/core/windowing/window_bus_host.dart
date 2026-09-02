import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/core/windowing/multi_window_service.dart';
import 'package:otzaria/core/windowing/shared_list_store.dart';
import 'package:otzaria/core/windowing/window_bus.dart';
import 'package:otzaria/core/windowing/window_role.dart';
import 'package:otzaria/navigation/bloc/navigation_bloc.dart';
import 'package:otzaria/navigation/bloc/navigation_event.dart';
import 'package:otzaria/navigation/bloc/navigation_state.dart';
import 'package:otzaria/tabs/bloc/tabs_bloc.dart';
import 'package:otzaria/tabs/bloc/tabs_event.dart';
import 'package:otzaria/tabs/models/tab.dart';

/// מחבר את [WindowBus] לחלון שהוא יושב בו.
///
/// תופס משבצת באפיק, עונה על בקשות מחלונות אחרים, ומשחרר בסגירה. חייב
/// לשבת **מתחת** ל-`TabsBloc` ול-`NavigationBloc` — שתי הבקשות הנתמכות
/// זקוקות להם.
///
/// ⚠️ השחרור ב-`dispose` אינו נימוס: משבצת שלא שוחררה נשארת רשומה בלי
/// מאזין, וחלון חדש לא יוכל לתפוס אותה. `WindowBus.peers` אמנם מסנן
/// משבצות מתות לפי timeout, אבל זה עולה המתנה בכל פתיחת תפריט.
class WindowBusHost extends StatefulWidget {
  const WindowBusHost({super.key, required this.child});

  final Widget child;

  @override
  State<WindowBusHost> createState() => _WindowBusHostState();
}

class _WindowBusHostState extends State<WindowBusHost> {
  Timer? _peerRefresh;

  @override
  void initState() {
    super.initState();
    WindowBus.instance.register();
    WindowBus.instance.onRequest = _handleRequest;

    // ⚠️ רענון ברקע ולא לפי דרישה: בניית תפריט ההקשר סינכרונית ואינה
    // יכולה להמתין לסריקה. בלי זה הלחיצה הימנית הראשונה אחרי פתיחת חלון
    // הייתה מציגה תת-תפריט ריק.
    //
    // המחיר זניח — עד שלוש שאילתות port מקומיות, והן נחסכות לגמרי כשאין
    // חלונות אחרים.
    unawaited(_refreshPeers());
    _peerRefresh = Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_refreshPeers()),
    );
  }

  Future<void> _refreshPeers() async {
    final peers = await const MultiWindowService().otherWindows();
    if (!mounted) return;
    MultiWindowService.knownPeers = peers;
  }

  @override
  void dispose() {
    _peerRefresh?.cancel();
    WindowBus.instance.onRequest = null;
    WindowBus.instance.unregister();
    MultiWindowService.knownPeers = const [];
    super.dispose();
  }

  Future<Object?> _handleRequest(Map<String, dynamic> request) async {
    switch (request['type']) {
      case MultiWindowService.requestDescribe:
        return _describe();
      case MultiWindowService.requestReceiveTab:
        return _receiveTab(request['tab']);
      default:
        // המאגרים המשותפים מנותבים לחלון הראשון; הבקשות שלהם מטופלות שם.
        return SharedListStore.instance.handleRequest(request);
    }
  }

  /// תיאור לתצוגה בתת-תפריט של חלון אחר.
  Map<String, Object?> _describe() {
    final state = context.read<TabsBloc>().state;
    final current = state.currentTab;
    return {
      'title': current?.title ?? 'חלון ריק',
      'tabCount': state.tabs.length,
      // מאפשר לחלונות משניים לאתר את הבעלים של המאגרים המשותפים.
      'isOwner': !WindowRole.isSecondary,
    };
  }

  /// קולט כרטיסיה שנשלחה מחלון אחר.
  ///
  /// מחזיר true רק אחרי שהכרטיסיה **פוענחה בהצלחה** ונוספה. השולח מסיר
  /// אותה מעצמו רק על סמך התשובה הזו, ולכן כישלון כאן חייב להיות false
  /// ולא חריגה — אחרת הכרטיסיה נעלמת משני הצדדים.
  bool _receiveTab(Object? tabJson) {
    if (tabJson is! Map) return false;
    final OpenedTab tab;
    try {
      tab = OpenedTab.fromJson(Map<String, dynamic>.from(tabJson));
    } catch (e) {
      debugPrint('WindowBusHost: failed to decode incoming tab: $e');
      return false;
    }
    if (!mounted) return false;
    context.read<TabsBloc>().add(AddTab(tab));
    context.read<NavigationBloc>().add(
      const NavigateToScreen(Screen.reading),
    );
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
