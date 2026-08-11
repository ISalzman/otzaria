import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/declarative/models/declarative_program.dart';
import 'package:otzaria/plugins/models/plugin_toolbar_item.dart';
import 'package:otzaria/plugins/utils/plugin_toolbar_actions.dart';
import 'package:otzaria/widgets/misc/app_popup_menu.dart';
import 'package:otzaria/widgets/controls/bar_button.dart';

void main() {
  Future<Map<String, dynamic>> emptyLocation() async => const {};

  test('builds a simple button with tooltip, icon, and BarButton widget', () {
    const item = PluginToolbarItem(
      id: 'mark',
      title: 'Mark section',
      icon: 'bookmark_24_regular',
    );

    final action = buildPluginToolbarActions(
      records: const [('marker', item)],
      context: 'reader-text',
      compact: false,
      locationPayload: emptyLocation,
    ).single;

    expect(action.tooltip, 'Mark section');
    expect(action.icon, isNotNull);
    expect(action.widget, isA<BarButton>());
    expect(action.onPressed, isNotNull);
    expect(action.submenuItems, isNull);
  });

  test('unknown icon name falls back to the puzzle piece icon', () {
    const item = PluginToolbarItem(
      id: 'mark',
      title: 'Mark',
      icon: 'no_such_icon_24_regular',
    );

    final action = buildPluginToolbarActions(
      records: const [('marker', item)],
      context: 'reader-text',
      compact: false,
      locationPayload: emptyLocation,
    ).single;

    expect(action.icon, FluentIcons.puzzle_piece_24_regular);
  });

  test('builds a dropdown with entries and mirrored submenu items', () {
    const item = PluginToolbarItem(
      id: 'menu',
      type: 'menu',
      title: 'Marker',
      icon: 'highlight_24_regular',
      children: [
        PluginToolbarItem(id: 'add', title: 'Add'),
        PluginToolbarItem(id: 'clear', title: 'Clear'),
      ],
    );

    final action = buildPluginToolbarActions(
      records: const [('marker', item)],
      context: 'reader-text',
      compact: false,
      locationPayload: emptyLocation,
    ).single;

    expect(action.tooltip, 'Marker');
    expect(action.widget, isA<AppPopupMenuButton<String>>());
    final menu = action.widget as AppPopupMenuButton<String>;
    expect(menu.entries!.map((entry) => entry.label), ['Add', 'Clear']);
    expect(
      action.submenuItems!.map((child) => child.tooltip),
      ['Add', 'Clear'],
    );
    expect(action.submenuItems!.first.onPressed, isNotNull);
  });

  test('filters top-level items and menu children by reader context', () {
    const textOnly = PluginToolbarItem(
      id: 'text-only',
      title: 'Text only',
      icon: 'apps_24_regular',
      contexts: ['reader-text'],
    );
    const menu = PluginToolbarItem(
      id: 'menu',
      type: 'menu',
      title: 'Menu',
      icon: 'apps_24_regular',
      children: [
        PluginToolbarItem(id: 'both', title: 'Both'),
        PluginToolbarItem(
          id: 'pdf-only',
          title: 'PDF only',
          contexts: ['reader-pdf'],
        ),
      ],
    );

    final pdfActions = buildPluginToolbarActions(
      records: const [('marker', textOnly), ('marker', menu)],
      context: 'reader-pdf',
      compact: false,
      locationPayload: emptyLocation,
    );

    expect(pdfActions, hasLength(1));
    expect(
      pdfActions.single.submenuItems!.map((child) => child.tooltip),
      ['Both', 'PDF only'],
    );

    final textActions = buildPluginToolbarActions(
      records: const [('marker', textOnly), ('marker', menu)],
      context: 'reader-text',
      compact: false,
      locationPayload: emptyLocation,
    );

    expect(textActions, hasLength(2));
    expect(
      textActions.last.submenuItems!.map((child) => child.tooltip),
      ['Both'],
    );
  });

  test('פעולת Host אינה בונה payload ואינה נשלחת למנוע התוסף', () async {
    const hostAction = CompiledDeclarativeAction(
      type: 'reader.openBook',
      args: {
        'identity': {'id': 10},
      },
      requiredPermission: 'reader.open',
      contextSignature: 'book-7',
    );
    const item = PluginToolbarItem(
      id: 'open-default',
      title: 'Open default',
      icon: 'book_24_regular',
      hostAction: hostAction,
    );
    var locationCalls = 0;
    final dispatched = <CompiledDeclarativeAction>[];
    final action = buildPluginToolbarActions(
      records: const [('marker', item)],
      context: 'reader-text',
      compact: false,
      locationPayload: () async {
        locationCalls++;
        throw StateError('legacy payload must not be built');
      },
      hostActionDispatcher: (pluginId, action) async {
        expect(pluginId, 'marker');
        dispatched.add(action);
      },
    ).single;

    action.onPressed!();
    await Future<void>.delayed(Duration.zero);

    expect(dispatched, [hostAction]);
    expect(locationCalls, 0);
  });
}
