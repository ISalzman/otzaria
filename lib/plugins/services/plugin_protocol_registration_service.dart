import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class PluginProtocolRegistrationService {
  static const String scheme = 'otzaria';
  static const Duration _windowsRegistrationTimeout = Duration(seconds: 5);

  Future<void> ensureRegistered() async {
    if (Platform.isWindows) {
      await _ensureWindowsRegistration();
      return;
    }

    if (Platform.isLinux) {
      await _ensureLinuxRegistration();
    }
  }

  Future<void> _ensureWindowsRegistration() async {
    final exePath = Platform.resolvedExecutable;
    final regExecutable = resolveWindowsRegistryExecutable(
      Platform.environment,
    );
    final commands = buildWindowsRegistrationCommands(exePath);

    for (final arguments in commands) {
      final result = await Process.run(
        regExecutable,
        arguments,
      ).timeout(
        _windowsRegistrationTimeout,
        onTimeout: () => ProcessResult(
          0,
          -1,
          '',
          'Timed out after ${_windowsRegistrationTimeout.inSeconds} seconds',
        ),
      );
      if (result.exitCode != 0) {
        throw Exception(
          'רישום פרוטוקול התוספים נכשל: ${result.stderr}'.trim(),
        );
      }
    }
  }

  Future<void> _ensureLinuxRegistration() async {
    final home = Platform.environment['HOME'] ?? '';
    if (home.isEmpty) {
      throw Exception('לא ניתן לאתר את תיקיית הבית לרישום פרוטוקול בלינוקס');
    }

    final applicationsDir =
        Directory(p.join(home, '.local', 'share', 'applications'));
    await applicationsDir.create(recursive: true);

    final desktopFile = File(p.join(applicationsDir.path, 'otzaria.desktop'));
    final executable = Platform.resolvedExecutable;
    final iconPath = p.join(
      p.dirname(executable),
      'data',
      'flutter_assets',
      'assets',
      'icon',
      'iconnew.png',
    );
    final desktopEntry = buildLinuxDesktopEntry(
      executable: executable,
      scheme: scheme,
      iconPath: File(iconPath).existsSync() ? iconPath : null,
    );

    await desktopFile.writeAsString(desktopEntry, flush: true);

    await _runLinuxCommandIfAvailable('update-desktop-database', [
      applicationsDir.path,
    ]);
    await _runLinuxCommandIfAvailable('xdg-mime', [
      'default',
      p.basename(desktopFile.path),
      'x-scheme-handler/$scheme',
    ]);
  }

  Future<void> _runLinuxCommandIfAvailable(
    String executable,
    List<String> arguments,
  ) async {
    final lookup = await Process.run('which', [executable], runInShell: true);
    if (lookup.exitCode != 0) {
      return;
    }

    final result = await Process.run(executable, arguments, runInShell: true);
    if (result.exitCode != 0) {
      throw Exception(
        'רישום פרוטוקול בלינוקס נכשל עבור $executable: ${result.stderr}'.trim(),
      );
    }
  }

  @visibleForTesting
  static String buildLinuxDesktopEntry({
    required String executable,
    required String scheme,
    String? iconPath,
  }) {
    final lines = <String>[
      '[Desktop Entry]',
      'Version=1.0',
      'Type=Application',
      'Name=אוצריא',
      'Exec="$executable" %u',
      'Terminal=false',
      'MimeType=x-scheme-handler/$scheme;',
      'Categories=Education;Utility;',
      'StartupNotify=true',
      if (iconPath != null && iconPath.trim().isNotEmpty) 'Icon=$iconPath',
    ];

    return '${lines.join('\n')}\n';
  }

  @visibleForTesting
  static String resolveWindowsRegistryExecutable(
    Map<String, String> environment,
  ) {
    final windowsDirectory =
        environment['WINDIR'] ?? environment['SystemRoot'] ?? r'C:\Windows';
    return p.windows.join(windowsDirectory, 'System32', 'reg.exe');
  }

  @visibleForTesting
  static List<List<String>> buildWindowsRegistrationCommands(String exePath) {
    final command = '"$exePath" "%1"';
    final protocolRoot = r'HKCU\Software\Classes\otzaria';

    return <List<String>>[
      ['add', protocolRoot, '/ve', '/d', 'URL:Otzaria Protocol', '/f'],
      ['add', protocolRoot, '/v', 'URL Protocol', '/d', '', '/f'],
      ['add', '$protocolRoot\\DefaultIcon', '/ve', '/d', exePath, '/f'],
      [
        'add',
        '$protocolRoot\\shell\\open\\command',
        '/ve',
        '/d',
        command,
        '/f',
      ],
    ];
  }
}
