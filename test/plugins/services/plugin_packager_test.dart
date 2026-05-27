import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/services/plugin_packager.dart';
import 'package:path/path.dart' as p;

/// Manifest מינימלי ותקין לבדיקות. שדות שלא חיוניים יושמטו.
Map<String, dynamic> _minimalManifest({
  String id = 'test.packager.plugin',
  String name = 'Packager Test',
  String version = '1.0.0',
  String entrypoint = 'index.html',
  String? title,
  List<String> permissions = const [],
  Map<String, dynamic>? network,
}) =>
    {
      'schemaVersion': 1,
      'id': id,
      'name': name,
      'version': version,
      'description': '',
      'author': '',
      'homepage': '',
      'entrypoint': entrypoint,
      'minAppVersion': '0.0.0',
      'sdkVersion': '1.x',
      'permissions': permissions,
      if (network != null) 'network': network,
      'contributes': {
        'toolTab': {
          'title': title ?? name,
          'order': 900,
          'defaultPinned': true,
        },
        'publishedDataTypes': const [],
      },
    };

/// יוצר תיקיית תוסף בדיסק עם manifest + index.html. מחזיר נתיב מוחלט.
String _writePluginDir(
  Directory parent, {
  String dirName = 'plugin',
  Map<String, dynamic>? manifestOverride,
  String indexHtml = '<!doctype html><html lang="he" dir="rtl"></html>',
  Map<String, String> extraFiles = const {},
}) {
  final dir = Directory(p.join(parent.path, dirName))..createSync();
  File(p.join(dir.path, 'manifest.json'))
      .writeAsStringSync(jsonEncode(manifestOverride ?? _minimalManifest()));
  File(p.join(dir.path, 'index.html')).writeAsStringSync(indexHtml);
  extraFiles.forEach((rel, contents) {
    final f = File(p.join(dir.path, rel));
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(contents);
  });
  return dir.path;
}

void main() {
  group('PluginPackager.packDirectory', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('otzaria_packager_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {
          // ב-Windows יכולה להיות נעילה רגעית — לא חוסם את הטסט.
        }
      }
    });

    test('packs a minimal valid plugin into ‎.otzplugin', () async {
      final pluginDir = _writePluginDir(tempDir);

      final result = await PluginPackager.packDirectory(
        directoryPath: pluginDir,
        outputPath: p.join(tempDir.path, 'out.otzplugin'),
      );

      expect(File(result.outputPath).existsSync(), isTrue);
      expect(result.fileCount, 2); // manifest.json + index.html
      expect(result.bytes, greaterThan(0));
      expect(result.manifest.id, 'test.packager.plugin');
    });

    test('throws when the directory does not exist', () async {
      expect(
        () => PluginPackager.packDirectory(
          directoryPath: p.join(tempDir.path, 'no-such-dir'),
        ),
        throwsA(isA<PluginPackagerException>()),
      );
    });

    test('throws when manifest.json is missing', () async {
      final dir = Directory(p.join(tempDir.path, 'no-manifest'))..createSync();
      File(p.join(dir.path, 'index.html')).writeAsStringSync('x');

      expect(
        () => PluginPackager.packDirectory(directoryPath: dir.path),
        throwsA(isA<PluginPackagerException>()),
      );
    });

    test('throws when manifest.json is not valid JSON', () async {
      final dir = Directory(p.join(tempDir.path, 'bad-json'))..createSync();
      File(p.join(dir.path, 'manifest.json')).writeAsStringSync('{not json');
      File(p.join(dir.path, 'index.html')).writeAsStringSync('x');

      expect(
        () => PluginPackager.packDirectory(directoryPath: dir.path),
        throwsA(isA<PluginPackagerException>()
            .having((e) => e.message, 'message', contains('manifest.json'))),
      );
    });

    test('throws when output exists and force is false', () async {
      final pluginDir = _writePluginDir(tempDir);
      final outPath = p.join(tempDir.path, 'out.otzplugin');
      File(outPath).writeAsStringSync('stale');

      expect(
        () => PluginPackager.packDirectory(
          directoryPath: pluginDir,
          outputPath: outPath,
        ),
        throwsA(isA<PluginPackagerException>()
            .having((e) => e.message, 'message', contains('--force'))),
      );
    });

    test('overwrites existing output when force is true', () async {
      final pluginDir = _writePluginDir(tempDir);
      final outPath = p.join(tempDir.path, 'out.otzplugin');
      File(outPath).writeAsStringSync('stale');

      final result = await PluginPackager.packDirectory(
        directoryPath: pluginDir,
        outputPath: outPath,
        force: true,
      );

      expect(result.fileCount, 2);
      // הקובץ נדרס: כעת זה ZIP תקין ולא הטקסט "stale".
      final bytes = File(outPath).readAsBytesSync();
      expect(bytes.length, greaterThan(5));
      // ZIP header אמור להתחיל ב-‎PK
      expect(bytes[0], 0x50);
      expect(bytes[1], 0x4B);
    });

    test(
        'does NOT pack the output .otzplugin into itself when it lives inside the source dir',
        () async {
      // רגרסיה: באג שהמשתמש זיהה. כש--output מצביע לתוך תיקיית התוסף,
      // הקובץ הנוצר היה נסרק ע"י listSync ונכנס לארכיון של עצמו.
      final pluginDir = _writePluginDir(tempDir);
      final outPath = p.join(pluginDir, 'my.otzplugin');

      final result = await PluginPackager.packDirectory(
        directoryPath: pluginDir,
        outputPath: outPath,
      );

      // רק 2 קבצים אמורים להיכנס — manifest.json + index.html — לא הקובץ
      // .otzplugin עצמו.
      expect(result.fileCount, 2);

      // ולוודא שהארכיון לא מכיל ערך בשם my.otzplugin
      final bytes = File(outPath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);
      final names = archive.files.map((f) => f.name).toList();
      expect(names, isNot(contains('my.otzplugin')));
      expect(names, containsAll(<String>['manifest.json', 'index.html']));
    });

    test('default output path lands in parent dir as {id}-{version}.otzplugin',
        () async {
      final pluginDir = _writePluginDir(tempDir);

      final result = await PluginPackager.packDirectory(
        directoryPath: pluginDir,
      );

      expect(
        p.basename(result.outputPath),
        'test.packager.plugin-1.0.0.otzplugin',
      );
      expect(p.dirname(result.outputPath), tempDir.path);
    });

    test('allows name and toolTab.title to differ (per official docs)',
        () async {
      // לפי `docs/plugin-development-guide.md`, contributes.toolTab.title
      // הוא שדה אופציונלי שברירת המחדל שלו היא שם התוסף — שני השדות יכולים
      // להיות שונים. הוולידטור החדש לא חוסם.
      final manifest = _minimalManifest(name: 'שם התוסף', title: 'שם הטאב');
      final pluginDir = _writePluginDir(tempDir, manifestOverride: manifest);

      final result =
          await PluginPackager.packDirectory(directoryPath: pluginDir);

      expect(result.validation.hasErrors, isFalse);
    });

    test('blocks packaging when manifest validator throws (bad permission)',
        () async {
      // הרשאה לא קיימת ברשימה הרשמית => PluginManifestValidator זורק.
      final manifest = _minimalManifest(
        permissions: const ['this.is.not.a.real.permission'],
      );
      final pluginDir = _writePluginDir(tempDir, manifestOverride: manifest);

      expect(
        () => PluginPackager.packDirectory(directoryPath: pluginDir),
        throwsA(isA<PluginPackagerException>()),
      );
    });

    test('packing succeeds despite warnings; warnings are surfaced in report',
        () async {
      // קריאה ל-API לא מוכר -> warning בלבד, האריזה צריכה לעבור.
      final manifest = _minimalManifest();
      final pluginDir = _writePluginDir(
        tempDir,
        manifestOverride: manifest,
        extraFiles: {
          'app.js': '''
            // קריאה ל-API לא מוכר
            Otzaria.call('totally.fake_method', {});
          ''',
        },
      );

      final result = await PluginPackager.packDirectory(
        directoryPath: pluginDir,
      );

      expect(result.validation.hasErrors, isFalse);
      expect(result.validation.hasWarnings, isTrue);
      expect(
        result.validation.warnings
            .any((w) => w.contains('totally.fake_method')),
        isTrue,
      );
    });
  });
}
