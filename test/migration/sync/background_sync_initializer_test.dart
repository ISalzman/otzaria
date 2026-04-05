import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:otzaria/migration/sync/background_sync_initializer.dart';
import 'package:otzaria/settings/engine/settings_repository.dart';

import '../../unit/mocks/mock_settings_wrapper.mocks.dart';

void main() {
  group('BackgroundSyncInitializer.shouldRunBackgroundSync', () {
    late MockSettingsWrapper mockSettingsWrapper;

    setUp(() {
      mockSettingsWrapper = MockSettingsWrapper();
    });

    test('returns false when offline mode is enabled', () {
      when(
        mockSettingsWrapper.getValue<bool>(
          SettingsRepository.keyOfflineMode,
          defaultValue: false,
        ),
      ).thenReturn(true);
      when(
        mockSettingsWrapper.getValue<bool>(
          SettingsRepository.keySoftwareAndBookUpdatesEnabled,
          defaultValue: true,
        ),
      ).thenReturn(true);

      final result = BackgroundSyncInitializer.shouldRunBackgroundSync(
        settingsWrapper: mockSettingsWrapper,
      );

      expect(result, isFalse);
    });

    test('returns false when software and book updates are disabled', () {
      when(
        mockSettingsWrapper.getValue<bool>(
          SettingsRepository.keyOfflineMode,
          defaultValue: false,
        ),
      ).thenReturn(false);
      when(
        mockSettingsWrapper.getValue<bool>(
          SettingsRepository.keySoftwareAndBookUpdatesEnabled,
          defaultValue: true,
        ),
      ).thenReturn(false);

      final result = BackgroundSyncInitializer.shouldRunBackgroundSync(
        settingsWrapper: mockSettingsWrapper,
      );

      expect(result, isFalse);
    });

    test('returns true when online and updates are enabled', () {
      when(
        mockSettingsWrapper.getValue<bool>(
          SettingsRepository.keyOfflineMode,
          defaultValue: false,
        ),
      ).thenReturn(false);
      when(
        mockSettingsWrapper.getValue<bool>(
          SettingsRepository.keySoftwareAndBookUpdatesEnabled,
          defaultValue: true,
        ),
      ).thenReturn(true);

      final result = BackgroundSyncInitializer.shouldRunBackgroundSync(
        settingsWrapper: mockSettingsWrapper,
      );

      expect(result, isTrue);
    });
  });
}
