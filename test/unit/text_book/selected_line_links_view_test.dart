import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/settings/engine/settings_state.dart';
import 'package:otzaria/text_book/view/selected_line_links_view.dart';

void main() {
  group('buildSelectedLinkRenderSettings', () {
    test('passes removeNikud through to link content rendering', () {
      final settings = SettingsState.initial();

      final renderSettings = buildSelectedLinkRenderSettings(
        settingsState: settings,
        removeNikud: true,
        searchText: '',
      );

      expect(renderSettings.removeNikud, isTrue);
    });

    test('follows teamim visibility setting for link content rendering', () {
      final settings = SettingsState.initial().copyWith(showTeamim: false);

      final renderSettings = buildSelectedLinkRenderSettings(
        settingsState: settings,
        removeNikud: false,
        searchText: 'שלום',
      );

      expect(renderSettings.removeTeamim, isTrue);
      expect(renderSettings.searchText, 'שלום');
    });

    test('disables justify for link content rendering', () {
      final settings = SettingsState.initial();

      final renderSettings = buildSelectedLinkRenderSettings(
        settingsState: settings,
        removeNikud: false,
        searchText: '',
      );

      expect(renderSettings.justifyText, isFalse);
    });
  });

  group('normalizeSelectedLinkText', () {
    test('collapses tabs into a single space', () {
      expect(
        normalizeSelectedLinkText('ודר\t\t\tשאל'),
        'ודר שאל',
      );
    });

    test('collapses nbsp and repeated spaces', () {
      expect(
        normalizeSelectedLinkText('ודר&nbsp;  שאל'),
        'ודר שאל',
      );
    });
  });
}
