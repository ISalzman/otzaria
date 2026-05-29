import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/update/my_update_widget.dart';
import 'package:updat/updat.dart';

void main() {
  group('supportsManagedUpdatePlatform', () {
    test('supports desktop platforms only', () {
      expect(
        supportsManagedUpdatePlatform(
          isWeb: false,
          operatingSystem: 'windows',
        ),
        isTrue,
      );
      expect(
        supportsManagedUpdatePlatform(
          isWeb: false,
          operatingSystem: 'macos',
        ),
        isTrue,
      );
      expect(
        supportsManagedUpdatePlatform(
          isWeb: false,
          operatingSystem: 'linux',
        ),
        isTrue,
      );
      expect(
        supportsManagedUpdatePlatform(
          isWeb: false,
          operatingSystem: 'android',
        ),
        isFalse,
      );
      expect(
        supportsManagedUpdatePlatform(
          isWeb: false,
          operatingSystem: 'ios',
        ),
        isFalse,
      );
      expect(
        supportsManagedUpdatePlatform(
          isWeb: true,
          operatingSystem: 'windows',
        ),
        isFalse,
      );
    });
  });

  group('shouldLaunchInstallerOnExit', () {
    test('requires installer file and a completed download state', () {
      expect(
        shouldLaunchInstallerOnExit(
          status: UpdatStatus.readyToInstall,
          hasInstallerFile: true,
        ),
        isTrue,
      );
      expect(
        shouldLaunchInstallerOnExit(
          status: UpdatStatus.dismissed,
          hasInstallerFile: true,
        ),
        isTrue,
      );
      expect(
        shouldLaunchInstallerOnExit(
          status: UpdatStatus.downloading,
          hasInstallerFile: true,
        ),
        isFalse,
      );
      expect(
        shouldLaunchInstallerOnExit(
          status: UpdatStatus.readyToInstall,
          hasInstallerFile: false,
        ),
        isFalse,
      );
    });
  });

  group('pickPreferredReleaseForDevChannel', () {
    test('selects stable when stable core version is newer than dev', () {
      final selected = pickPreferredReleaseForDevChannel(
        stableRelease: {'tag_name': '0.9.93+674'},
        devRelease: {'tag_name': '0.9.92+631'},
      );

      expect(selected['tag_name'], '0.9.93+674');
    });

    test('selects dev when dev core version is newer than stable', () {
      final selected = pickPreferredReleaseForDevChannel(
        stableRelease: {'tag_name': '0.9.93+674'},
        devRelease: {'tag_name': '0.9.94+10'},
      );

      expect(selected['tag_name'], '0.9.94+10');
    });

    test('selects stable release metadata when core versions are equal', () {
      final selected = pickPreferredReleaseForDevChannel(
        stableRelease: {'tag_name': '0.9.92'},
        devRelease: {'tag_name': '0.9.92+631'},
      );

      expect(selected['tag_name'], '0.9.92');
    });
  });
}
