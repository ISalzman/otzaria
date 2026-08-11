import 'package:flutter/material.dart';
import 'package:otzaria/theme/theme_exports.dart';
import 'package:otzaria/widgets/text/otzaria_search_field.dart';

/// פעולת החיפוש של לשונית אחת בחלונית הניווט.
///
/// הלשונית אינה מציירת שדה חיפוש בעצמה — היא מפרסמת את הפעולה שלה
/// ([NavPanelSearchPublisher]), ו-[NavPanelSearchBar] שבסרגל העליון מצייר אותה.
class NavPanelSearchDelegate {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final List<Widget> trailingActions;

  const NavPanelSearchDelegate({
    required this.controller,
    required this.hintText,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.trailingActions = const [],
  });

  /// האם שתי הפעולות מכוונות לאותו שדה (אותו controller/focus/תווית). ה-callbacks
  /// נבנים מחדש בכל build אך קוראים את ה-state העדכני בזמן ההפעלה, ולכן שינוי
  /// שלהם אינו מחייב בנייה מחדש של הסרגל.
  bool sameTargetAs(NavPanelSearchDelegate other) =>
      controller == other.controller &&
      focusNode == other.focusNode &&
      hintText == other.hintText &&
      trailingActions.length == other.trailingActions.length;
}

/// מרכז את פעולות החיפוש של לשוניות החלונית ומזין את הסרגל שבסרגל העליון.
///
/// המסך מחזיק מופע אחד, מעדכן [activeTab] לפי הלשונית הנבחרת, ומעביר אותו
/// גם ל-[NavPanelSearchBar] וגם ל-[NavPanelSearchScope] שעוטף את החלונית.
class NavPanelSearchHost extends ChangeNotifier {
  final Map<int, NavPanelSearchDelegate> _delegates = {};
  int _activeTab = 0;
  bool _disposed = false;
  bool _notifyScheduled = false;

  int get activeTab => _activeTab;

  set activeTab(int value) {
    if (_activeTab == value) return;
    _activeTab = value;
    _scheduleNotify();
  }

  /// פעולת החיפוש של הלשונית הפעילה, או null כשאין לה חיפוש.
  NavPanelSearchDelegate? get active => _delegates[_activeTab];

  void publish(int tab, NavPanelSearchDelegate delegate) {
    if (_disposed) return;
    final previous = _delegates[tab];
    _delegates[tab] = delegate;
    if (tab != _activeTab) return;
    if (previous != null && previous.sameTargetAs(delegate)) return;
    _scheduleNotify();
  }

  void withdraw(int tab) {
    if (_disposed) return;
    if (_delegates.remove(tab) != null && tab == _activeTab) {
      _scheduleNotify();
    }
  }

  /// הפרסום מתרחש בתוך build של הלשונית, ולכן ההודעה נדחית לסוף ה-frame —
  /// אחרת ה-setState של הסרגל נופל על "markNeedsBuild during build".
  void _scheduleNotify() {
    if (_notifyScheduled || _disposed) return;
    _notifyScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// מספק את [NavPanelSearchHost] לצאצאי החלונית.
class NavPanelSearchScope extends InheritedWidget {
  final NavPanelSearchHost host;

  const NavPanelSearchScope({
    super.key,
    required this.host,
    required super.child,
  });

  static NavPanelSearchHost? hostOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NavPanelSearchScope>()?.host;

  @override
  bool updateShouldNotify(NavPanelSearchScope oldWidget) =>
      oldWidget.host != host;
}

/// עזר לזיהוי המצב: בתוך חלונית ניווט שדה החיפוש עולה לסרגל שמעליה, ולכן
/// הלשונית אינה מציירת שדה מקומי. מחוץ לחלונית (דיאלוג, מסך אחר) היא כן.
abstract final class NavPanelSearch {
  static bool isHoisted(BuildContext context) =>
      NavPanelSearchScope.hostOf(context) != null &&
      NavPanelSearchSlot.indexOf(context) != null;
}

/// מסמן את אינדקס הלשונית שבתוכה יושב התוכן — כדי שהפרסום יגיע לסרגל רק
/// כשהלשונית הזו נבחרת. עוטף כל child של ה-TabBarView בחלונית.
class NavPanelSearchSlot extends InheritedWidget {
  final int index;

  const NavPanelSearchSlot({
    super.key,
    required this.index,
    required super.child,
  });

  static int? indexOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NavPanelSearchSlot>()?.index;

  @override
  bool updateShouldNotify(NavPanelSearchSlot oldWidget) =>
      oldWidget.index != index;
}

/// מפרסם את פעולת החיפוש של הלשונית שבתוכה הוא יושב, כל עוד הוא בעץ.
/// מחוץ ל-[NavPanelSearchScope] (למשל בדיאלוג) הוא שקוף לחלוטין.
class NavPanelSearchPublisher extends StatefulWidget {
  final NavPanelSearchDelegate delegate;
  final Widget child;

  const NavPanelSearchPublisher({
    super.key,
    required this.delegate,
    required this.child,
  });

  @override
  State<NavPanelSearchPublisher> createState() =>
      _NavPanelSearchPublisherState();
}

class _NavPanelSearchPublisherState extends State<NavPanelSearchPublisher> {
  NavPanelSearchHost? _host;
  int? _slot;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final host = NavPanelSearchScope.hostOf(context);
    final slot = NavPanelSearchSlot.indexOf(context);
    if (host != _host || slot != _slot) {
      if (_host != null && _slot != null) _host!.withdraw(_slot!);
      _host = host;
      _slot = slot;
    }
    _republish();
  }

  @override
  void didUpdateWidget(NavPanelSearchPublisher oldWidget) {
    super.didUpdateWidget(oldWidget);
    _republish();
  }

  void _republish() {
    final host = _host;
    final slot = _slot;
    if (host == null || slot == null) return;
    host.publish(slot, widget.delegate);
  }

  @override
  void dispose() {
    if (_host != null && _slot != null) _host!.withdraw(_slot!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// שדה החיפוש המקומי של לשונית — לשימוש כשהיא אינה בתוך חלונית ניווט
/// (ואז אין סרגל שמעליה שיצייר אותו).
class NavPanelLocalSearchField extends StatelessWidget {
  final NavPanelSearchDelegate delegate;

  const NavPanelLocalSearchField({super.key, required this.delegate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: OtzariaSearchField(
        controller: delegate.controller,
        focusNode: delegate.focusNode,
        hintText: delegate.hintText,
        onChanged: delegate.onChanged,
        onSubmitted: delegate.onSubmitted,
        onClear: delegate.onClear,
        trailingActions: delegate.trailingActions.isEmpty
            ? null
            : delegate.trailingActions,
      ),
    );
  }
}

/// סרגל החיפוש של חלונית הניווט, בתוך הסרגל העליון.
///
/// נפתח באנימציה מרוחב 0 (מקום אייקון הפתיחה) לרוחב החלונית, ולכן הוא דוחק
/// את האייקון פנימה ו"נמשך" ממנו. הפעולה שבתוכו מתחלפת לפי הלשונית הנבחרת,
/// והסרגל נשאר מעל החלונית כל עוד היא פתוחה.
class NavPanelSearchBar extends StatefulWidget {
  final NavPanelSearchHost host;

  /// האם החלונית פתוחה — הסרגל נפתח ונסגר יחד איתה.
  final bool isOpen;

  /// רוחב החלונית שמעליה הסרגל יושב.
  final double paneWidth;

  const NavPanelSearchBar({
    super.key,
    required this.host,
    required this.isOpen,
    required this.paneWidth,
  });

  @override
  State<NavPanelSearchBar> createState() => _NavPanelSearchBarState();
}

class _NavPanelSearchBarState extends State<NavPanelSearchBar> {
  /// controller קבוע ללשונית שאין בה חיפוש — כדי שהשדה עצמו יישאר אותו
  /// ווידג'ט ולא ייבנה מחדש במעבר בין לשוניות.
  final TextEditingController _idleController = TextEditingController();

  @override
  void dispose() {
    _idleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight: ה-OverflowBox דורש גובה חסום, וסרגל עליון עשוי לתת
    // גובה חופשי (Row בתוך Column).
    return IntrinsicHeight(
      child: AnimatedContainer(
        duration: AppTokens.animPanelSlide,
        curve: Curves.easeInOut,
        width: widget.isOpen ? widget.paneWidth : 0,
        child: ClipRect(
          child: OverflowBox(
            maxWidth: widget.paneWidth,
            minWidth: 0,
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox(
              width: widget.paneWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                // רק תוכן השדה מתחלף לפי הלשונית — הסרגל עצמו נשאר מוצג
                // ומורכב כל עוד החלונית פתוחה, ואינו נבנה מחדש.
                child: ListenableBuilder(
                  listenable: widget.host,
                  builder: (context, _) {
                    final delegate = widget.host.active;
                    return OtzariaSearchField(
                      controller: delegate?.controller ?? _idleController,
                      focusNode: delegate?.focusNode,
                      enabled: delegate != null,
                      hintText: delegate?.hintText ?? 'אין חיפוש בלשונית זו',
                      onChanged: delegate?.onChanged,
                      onSubmitted: delegate?.onSubmitted,
                      onClear: delegate?.onClear,
                      trailingActions:
                          delegate == null || delegate.trailingActions.isEmpty
                          ? null
                          : delegate.trailingActions,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
