import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/update/linux_installer.dart';

void main() {
  group('buildLinuxInstallCommand', () {
    test('builds the right command per package manager', () {
      expect(
        buildLinuxInstallCommand(
          packageManager: 'apt',
          packagePath: '/home/me/Downloads/otzaria-0.9.94.deb',
        ),
        "apt install -y '/home/me/Downloads/otzaria-0.9.94.deb'",
      );
      expect(
        buildLinuxInstallCommand(
          packageManager: 'dnf',
          packagePath: '/home/me/Downloads/otzaria-0.9.94.rpm',
        ),
        "dnf install -y '/home/me/Downloads/otzaria-0.9.94.rpm'",
      );
      expect(
        buildLinuxInstallCommand(
          packageManager: 'zypper',
          packagePath: '/home/me/Downloads/otzaria-0.9.94.rpm',
        ),
        "zypper --non-interactive install '/home/me/Downloads/otzaria-0.9.94.rpm'",
      );
    });

    test('throws on unsupported package manager', () {
      expect(
        () => buildLinuxInstallCommand(
          packageManager: 'pacman',
          packagePath: '/tmp/x.deb',
        ),
        throwsArgumentError,
      );
    });
  });

  group('buildLinuxUpdateScript', () {
    const pkgPath = '/home/me/Downloads/otzaria-0.9.94.deb';
    final installCommand = buildLinuxInstallCommand(
      packageManager: 'apt',
      packagePath: pkgPath,
    );

    test('waits for the app pid, installs with pkexec, and cleans up', () {
      final script = buildLinuxUpdateScript(
        installCommand: installCommand,
        packagePath: pkgPath,
        appPid: 4242,
        relaunchExecutable: '/usr/bin/otzaria',
      );

      expect(script, contains('kill -0 4242'));
      expect(script, contains("pkexec apt install -y '$pkgPath'"));
      expect(script, contains("rm -f '$pkgPath'"));
    });

    test('relaunches the app only when an executable is given', () {
      final withRelaunch = buildLinuxUpdateScript(
        installCommand: installCommand,
        packagePath: pkgPath,
        appPid: 1,
        relaunchExecutable: '/usr/bin/otzaria',
      );
      final withoutRelaunch = buildLinuxUpdateScript(
        installCommand: installCommand,
        packagePath: pkgPath,
        appPid: 1,
        relaunchExecutable: null,
      );

      expect(withRelaunch, contains("nohup '/usr/bin/otzaria'"));
      expect(withoutRelaunch, isNot(contains('nohup')));
    });

    test('escapes single quotes in paths', () {
      final script = buildLinuxUpdateScript(
        installCommand: installCommand,
        packagePath: "/home/o'brien/otzaria.deb",
        appPid: 1,
        relaunchExecutable: null,
      );

      expect(script, contains("'/home/o'\\''brien/otzaria.deb'"));
    });
  });
}
