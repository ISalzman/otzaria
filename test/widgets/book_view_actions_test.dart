import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/widgets/navigation/book_view_actions.dart';
import 'package:otzaria/widgets/navigation/responsive_action_bar.dart';

void main() {
  group('ActionButtonData.simple', () {
    testWidgets('יוצר IconButton כשנבחר visual מתאים', (
      tester,
    ) async {
      var pressed = false;

      final action = ActionButtonData.simple(
        icon: FluentIcons.search_24_regular,
        tooltip: 'חיפוש',
        onPressed: () {
          pressed = true;
        },
        compact: false,
        visual: ActionButtonVisual.iconButton,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: action.widget),
        ),
      );

      expect(action.icon, FluentIcons.search_24_regular);
      expect(action.tooltip, 'חיפוש');
      expect(action.onPressed, isNotNull);

      await tester.tap(find.byType(IconButton));
      await tester.pump();

      expect(pressed, isTrue);
    });
  });

  group('buildBookViewNavigationActions', () {
    test('שומר על סדר כפתורי הניווט בלי אמצע', () {
      final actions = buildBookViewNavigationActions(
        firstAction: _action('ראשון'),
        previousAction: _action('קודם'),
        nextAction: _action('הבא'),
        lastAction: _action('אחרון'),
      );

      expect(actions.map((action) => action.tooltip), [
        'ראשון',
        'קודם',
        'הבא',
        'אחרון',
      ]);
    });

    test('מכניס כפתור אמצעי במקום הנכון כשנשלח', () {
      final actions = buildBookViewNavigationActions(
        firstAction: _action('ראשון'),
        previousAction: _action('קודם'),
        middleAction: _action('אמצע'),
        nextAction: _action('הבא'),
        lastAction: _action('אחרון'),
      );

      expect(actions.map((action) => action.tooltip), [
        'ראשון',
        'קודם',
        'אמצע',
        'הבא',
        'אחרון',
      ]);
    });
  });
}

ActionButtonData _action(String tooltip) {
  return ActionButtonData(
    widget: const SizedBox.shrink(),
    icon: FluentIcons.book_24_regular,
    tooltip: tooltip,
    onPressed: () {},
  );
}
