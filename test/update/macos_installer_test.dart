import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/update/macos_installer.dart';

void main() {
  group('findInstalledMacAppBundlePath', () {
    test('derives the bundle path from the executable path', () {
      expect(
        findInstalledMacAppBundlePath(
          executablePath: '/Applications/אוצריא.app/Contents/MacOS/אוצריא',
        ),
        '/Applications/אוצריא.app',
      );
    });

    test('rejects translocated apps (read-only randomized path)', () {
      expect(
        findInstalledMacAppBundlePath(
          executablePath:
              '/private/var/folders/ab/xyz/T/AppTranslocation/1234/d/אוצריא.app/Contents/MacOS/אוצריא',
        ),
        isNull,
      );
    });

    test('rejects apps running from a mounted DMG', () {
      expect(
        findInstalledMacAppBundlePath(
          executablePath:
              '/Volumes/Otzaria Installer/אוצריא.app/Contents/MacOS/אוצריא',
        ),
        isNull,
      );
    });

    test('rejects executables that are not inside an app bundle', () {
      expect(
        findInstalledMacAppBundlePath(
          executablePath: '/usr/local/bin/otzaria',
        ),
        isNull,
      );
    });
  });

  group('buildMacUpdateScript', () {
    const zipPath = '/Users/me/Downloads/otzaria-0.9.94.zip';
    const appPath = '/Applications/אוצריא.app';

    test('waits for the app pid and swaps the bundle', () {
      final script = buildMacUpdateScript(
        zipPath: zipPath,
        appBundlePath: appPath,
        appPid: 4242,
        relaunchApp: true,
      );

      expect(script, contains('kill -0 4242'));
      expect(script, contains("ditto -x -k '$zipPath'"));
      expect(script, contains("mv '$appPath'"));
      expect(script, contains("ditto \"\$NEW_APP\" '$appPath'"));
    });

    test('relaunches the app only when requested', () {
      final withRelaunch = buildMacUpdateScript(
        zipPath: zipPath,
        appBundlePath: appPath,
        appPid: 1,
        relaunchApp: true,
      );
      final withoutRelaunch = buildMacUpdateScript(
        zipPath: zipPath,
        appBundlePath: appPath,
        appPid: 1,
        relaunchApp: false,
      );

      expect(withRelaunch, contains("open -n '$appPath'"));
      expect(withoutRelaunch, isNot(contains('open -n')));
    });

    test('escapes single quotes in paths', () {
      final script = buildMacUpdateScript(
        zipPath: "/Users/o'brien/Downloads/otzaria.zip",
        appBundlePath: appPath,
        appPid: 1,
        relaunchApp: false,
      );

      expect(script, contains("'/Users/o'\\''brien/Downloads/otzaria.zip'"));
    });
  });
}
