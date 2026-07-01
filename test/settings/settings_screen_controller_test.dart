import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/settings/view/settings_screen.dart';

void main() {
  group('SettingsScreenController', () {
    test('takeRequestedTab consumes the pending tab request', () {
      final controller = SettingsScreenController();

      controller.openTab(SettingsTab.library);

      expect(controller.takeRequestedTab(), SettingsTab.library);
      expect(controller.takeRequestedTab(), isNull);
      expect(controller.requestedTab, isNull);
    });
  });
}
