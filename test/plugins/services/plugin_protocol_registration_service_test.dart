import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/services/plugin_protocol_registration_service.dart';

void main() {
  group('PluginProtocolRegistrationService', () {
    test('resolveWindowsRegistryExecutable prefers WINDIR', () {
      final executable =
          PluginProtocolRegistrationService.resolveWindowsRegistryExecutable({
            'WINDIR': r'D:\Windows',
            'SystemRoot': r'C:\Windows',
          });

      expect(executable, r'D:\Windows\System32\reg.exe');
    });

    test('buildWindowsRegistrationCommands uses executable for icon and open command', () {
      final commands =
          PluginProtocolRegistrationService.buildWindowsRegistrationCommands(
            r'C:\Program Files\Otzaria\otzaria.exe',
          );

      expect(commands, hasLength(4));
      expect(commands[2], [
        'add',
        r'HKCU\Software\Classes\otzaria\DefaultIcon',
        '/ve',
        '/d',
        r'C:\Program Files\Otzaria\otzaria.exe',
        '/f',
      ]);
      expect(commands[3], [
        'add',
        r'HKCU\Software\Classes\otzaria\shell\open\command',
        '/ve',
        '/d',
        r'"C:\Program Files\Otzaria\otzaria.exe" "%1"',
        '/f',
      ]);
    });

    test('buildLinuxDesktopEntry does not add leading or empty lines', () {
      final entry = PluginProtocolRegistrationService.buildLinuxDesktopEntry(
        executable: '/opt/otzaria/otzaria',
        scheme: 'otzaria',
      );

      final lines = entry.split('\n');
      expect(lines.first, '[Desktop Entry]');
      expect(
        lines.where((line) => line.trim().isEmpty).length,
        1,
      );
      expect(lines[lines.length - 2], 'StartupNotify=true');
    });

    test('buildLinuxDesktopEntry includes icon only when provided', () {
      final entry = PluginProtocolRegistrationService.buildLinuxDesktopEntry(
        executable: '/opt/otzaria/otzaria',
        scheme: 'otzaria',
        iconPath: '/opt/otzaria/icon.png',
      );

      expect(entry, contains('Icon=/opt/otzaria/icon.png'));
      expect(
        entry.split('\n').where((line) => line.trim().isEmpty).length,
        1,
      );
    });
  });
}
