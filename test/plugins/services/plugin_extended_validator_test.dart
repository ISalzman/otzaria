import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/models/plugin_manifest.dart';
import 'package:otzaria/plugins/services/plugin_extended_validator.dart';
import 'package:path/path.dart' as p;

Map<String, dynamic> _baseManifest({
  List<String> permissions = const [],
  Map<String, dynamic>? network,
  String name = 'Test Plugin',
  String? title,
}) =>
    {
      'schemaVersion': 1,
      'id': 'test.extended.plugin',
      'name': name,
      'version': '1.0.0',
      'description': '',
      'author': '',
      'homepage': '',
      'entrypoint': 'index.html',
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

PluginValidationReport _runOn(
  Directory tempDir, {
  Map<String, dynamic>? manifestOverride,
  Map<String, String> files = const {
    'index.html': '<!doctype html><html lang="he" dir="rtl"></html>',
  },
}) {
  final json = manifestOverride ?? _baseManifest();
  final dir = Directory(p.join(tempDir.path, 'plugin'))..createSync();
  File(p.join(dir.path, 'manifest.json')).writeAsStringSync(jsonEncode(json));
  files.forEach((rel, contents) {
    final file = File(p.join(dir.path, rel));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
  });
  final manifest = PluginManifest.fromJson(json);
  return PluginExtendedValidator.validate(
    manifest: manifest,
    manifestJson: json,
    directoryPath: dir.path,
  );
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir =
        Directory.systemTemp.createTempSync('otzaria_ext_validator_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('network.allowlist (relaxed — warning only)', () {
    test('no warning when network is not declared', () {
      final report = _runOn(tempDir);
      expect(report.errors, isEmpty);
      expect(report.warnings.any((w) => w.contains('network')), isFalse);
    });

    test('warns when network.access is declared without allowlist entries', () {
      final report = _runOn(
        tempDir,
        manifestOverride: _baseManifest(
          permissions: const ['network.access'],
        ),
      );
      expect(report.errors, isEmpty);
      expect(
        report.warnings.any((w) => w.contains('network.allowlist')),
        isTrue,
      );
    });

    test('warns about wildcards in allowlist (not an error)', () {
      final report = _runOn(
        tempDir,
        manifestOverride: _baseManifest(
          permissions: const ['network.access'],
          network: {
            'enabled': true,
            'allowlist': ['https://*.example.com'],
          },
        ),
      );
      expect(report.errors, isEmpty);
      expect(
        report.warnings.any((w) => w.contains('wildcard')),
        isTrue,
      );
    });

    test('no warning for valid explicit URLs', () {
      final report = _runOn(
        tempDir,
        manifestOverride: _baseManifest(
          permissions: const ['network.access'],
          network: {
            'enabled': true,
            'allowlist': ['https://api.example.com'],
          },
        ),
      );
      expect(report.errors, isEmpty);
      expect(report.warnings.any((w) => w.contains('network')), isFalse);
    });
  });

  group('name vs toolTab.title (allowed to differ — per official docs)', () {
    test('accepts different name and title without errors or warnings', () {
      // הדוגמה הרשמית במדריך הפיתוח עצמה משתמשת בשמות שונים.
      final report = _runOn(
        tempDir,
        manifestOverride: _baseManifest(
          name: 'שם התוסף',
          title: 'שם הטאב',
        ),
      );
      expect(report.errors, isEmpty);
      expect(
        report.warnings.any((w) => w.contains('toolTab.title')),
        isFalse,
      );
    });
  });

  group('API/event scanning (warnings)', () {
    test('flags unknown API call', () {
      final report = _runOn(
        tempDir,
        files: {
          'index.html': '<html lang="he" dir="rtl"></html>',
          'app.js': "Otzaria.call('totally.fake_method', {});",
        },
      );
      expect(report.errors, isEmpty);
      expect(
        report.warnings.any((w) => w.contains('totally.fake_method')),
        isTrue,
      );
    });

    test('does not flag known network APIs as unknown', () {
      final report = _runOn(
        tempDir,
        manifestOverride: _baseManifest(
          permissions: const ['network.access'],
          network: const {
            'enabled': true,
            'allowlist': ['https://example.com'],
          },
        ),
        files: {
          'index.html': '<html lang="he" dir="rtl"></html>',
          'app.js': "Otzaria.call('network.fetch', {url: 'x'});"
              "Otzaria.call('network.download', {url: 'y'});",
        },
      );
      // לא מסומנים כ-API לא מוכר, ואין אזהרת הרשאה חסרה (היא הוצהרה).
      expect(
        report.warnings.any((w) => w.contains('network.fetch')),
        isFalse,
      );
      expect(
        report.warnings.any((w) => w.contains('network.download')),
        isFalse,
      );
    });

    test('warns when network.download is used but network.access is missing',
        () {
      final report = _runOn(
        tempDir,
        files: {
          'index.html': '<html lang="he" dir="rtl"></html>',
          'app.js': "Otzaria.call('network.download', {url: 'y'});",
        },
      );
      expect(
        report.warnings.any((w) =>
            w.contains('network.download') && w.contains('network.access')),
        isTrue,
      );
    });

    test('warns when known API is used but its required permission is missing',
        () {
      final report = _runOn(
        tempDir,
        files: {
          'index.html': '<html lang="he" dir="rtl"></html>',
          'app.js': "Otzaria.call('library.findBooks', {});",
        },
      );
      expect(
        report.warnings.any((w) => w.contains('library.books.read')),
        isTrue,
      );
    });

    test('does not warn when required permission is declared', () {
      final report = _runOn(
        tempDir,
        manifestOverride:
            _baseManifest(permissions: const ['library.books.read']),
        files: {
          'index.html': '<html lang="he" dir="rtl"></html>',
          'app.js': "Otzaria.call('library.findBooks', {});",
        },
      );
      expect(
        report.warnings.any((w) => w.contains('library.books.read')),
        isFalse,
      );
    });

    test('shorthand `Otzaria.app.getInfo()` is detected as API usage', () {
      final report = _runOn(
        tempDir,
        files: {
          'index.html': '<html lang="he" dir="rtl"></html>',
          'app.js': 'Otzaria.app.getInfo();',
        },
      );
      // app.getInfo דורש app.info.read; ההרשאה לא הוכרזה -> warning.
      expect(
        report.warnings.any((w) => w.contains('app.info.read')),
        isTrue,
      );
    });

    test('reserved shorthand fields (.call/.on/.off) are NOT treated as API',
        () {
      final report = _runOn(
        tempDir,
        files: {
          'index.html': '<html lang="he" dir="rtl"></html>',
          'app.js':
              "Otzaria.on('plugin.boot', () => {}); Otzaria.call('app.getInfo', {});",
        },
      );
      // אסור שיופיע "Otzaria.on" כקריאה ל-API לא מוכר.
      expect(
        report.warnings.any((w) => w.startsWith('קריאה ל-API לא מוכר: on')),
        isFalse,
      );
    });

    test('comments are stripped before scanning', () {
      final report = _runOn(
        tempDir,
        files: {
          'index.html': '<html lang="he" dir="rtl"></html>',
          'app.js': '''
            // Otzaria.call('totally.fake_method', {})
            /* Otzaria.call('also.fake', {}) */
          ''',
        },
      );
      expect(
        report.warnings.any((w) => w.contains('totally.fake_method')),
        isFalse,
      );
      expect(
        report.warnings.any((w) => w.contains('also.fake')),
        isFalse,
      );
    });

    test('inline // comments (after real code) are stripped', () {
      // רגרסיה: בעבר רק `//` בתחילת שורה הוסר; inline comment גרם
      // ל-warning שווא.
      final report = _runOn(
        tempDir,
        files: {
          'index.html': '<html lang="he" dir="rtl"></html>',
          'app.js': '''
            const x = 1; // Otzaria.call('totally.fake_inline', {});
            doSomething(); // Otzaria.on('fake.event', () => {});
          ''',
        },
      );
      expect(
        report.warnings.any((w) => w.contains('totally.fake_inline')),
        isFalse,
        reason: 'inline // comments must be stripped before scanning',
      );
      expect(
        report.warnings.any((w) => w.contains('fake.event')),
        isFalse,
      );
    });

    test('regex literals containing `//` do not blow away the rest of the line',
        () {
      // רגרסיה: regex literal עם `\/\/` בתוכו (URL pattern). אם המסיר
      // לא מגן על regex literals, הוא יחתוך מ-`//` הראשון שב-regex עד
      // סוף השורה ויבליע את הקריאה האמיתית שאחריו.
      final report = _runOn(
        tempDir,
        manifestOverride:
            _baseManifest(permissions: const ['library.books.read']),
        files: {
          'index.html': '<html lang="he" dir="rtl"></html>',
          'app.js': r'''
            const re = /https?:\/\/example/; Otzaria.call('library.findBooks', {});
          ''',
        },
      );
      // הקריאה ל-library.findBooks אמורה להיתפס (לא לקבל warning
      // "API לא מוכר"), והרשאה הוכרזה.
      expect(
        report.warnings.any((w) => w.contains('library.findBooks')),
        isFalse,
      );
    });

    test(
        'regex literal containing `Otzaria.call` is NOT treated as a real call',
        () {
      // רגרסיה הפוכה: regex literal עם הטקסט "Otzaria.call" בתוכו לא
      // צריך להיחשב כקריאה.
      final report = _runOn(
        tempDir,
        files: {
          'index.html': '<html lang="he" dir="rtl"></html>',
          'app.js': r'''
            const matcher = /Otzaria\.call\('inside.regex'\)/g;
          ''',
        },
      );
      expect(
        report.warnings.any((w) => w.contains('inside.regex')),
        isFalse,
      );
    });

    test('regex with character class containing `/` is handled', () {
      // `/[a-z\/]+/g` — class פנימי עם `/` ברוח. אסור לסיים את ה-regex
      // ב-`/` שבתוך ה-class.
      final report = _runOn(
        tempDir,
        manifestOverride:
            _baseManifest(permissions: const ['library.books.read']),
        files: {
          'index.html': '<html lang="he" dir="rtl"></html>',
          'app.js': r'''
            const re = /[a-z\/]+/g; Otzaria.call('library.findBooks', {});
          ''',
        },
      );
      expect(
        report.warnings.any((w) => w.contains('library.findBooks')),
        isFalse,
      );
    });

    test('division operators are NOT mistaken for regex literals', () {
      // `a / b` הוא חלוקה. אם המסיר חושב שזה תחילת regex, הוא ימשיך
      // עד ה-`/` הבא ויבלע קוד. כאן אין `/` נוסף בשורה, אבל יש בשורה
      // הבאה (כסטרינג). הקריאה ל-getInfo אמורה להישאר.
      final report = _runOn(
        tempDir,
        files: {
          'index.html': '<html lang="he" dir="rtl"></html>',
          'app.js': '''
            const ratio = total / count;
            const url = 'http://example.com/path';
            Otzaria.app.getInfo();
          ''',
        },
      );
      // app.getInfo דורש app.info.read; לא הוכרזה -> warning.
      expect(
        report.warnings.any((w) => w.contains('app.info.read')),
        isTrue,
        reason: 'API call after division/string must still be scanned',
      );
    });

    test('string literals containing `//` (URLs/regex) are not mistakenly cut',
        () {
      // אם _stripCommentsForScan חותך // אגרסיבית מדי, היא תפגע ב-URL
      // וגם תתעלם מקריאה אמיתית אחריו. נוודא שזה לא קורה.
      final report = _runOn(
        tempDir,
        manifestOverride:
            _baseManifest(permissions: const ['library.books.read']),
        files: {
          'index.html': '<html lang="he" dir="rtl"></html>',
          'app.js': '''
            const url = "https://example.com/api";
            Otzaria.call('library.findBooks', { src: url });
          ''',
        },
      );
      // הקריאה האמיתית נסרקה -> אין warning של API לא מוכר.
      expect(
        report.warnings.any((w) => w.contains('library.findBooks')),
        isFalse,
      );
      // וגם לא warning של ההרשאה החסרה (היא הוכרזה).
      expect(
        report.warnings.any((w) => w.contains('library.books.read')),
        isFalse,
      );
    });

    test('event subscription without events.subscribe permission -> warning',
        () {
      final report = _runOn(
        tempDir,
        files: {
          'index.html': '<html lang="he" dir="rtl"></html>',
          'app.js': "Otzaria.on('navigation.changed', () => {});",
        },
      );
      expect(
        report.warnings
            .any((w) => w.contains('events.subscribe:navigation.changed')),
        isTrue,
      );
    });
  });

  group('design compliance', () {
    test('HTML root must declare dir="rtl" lang="he"', () {
      final report = _runOn(
        tempDir,
        files: {
          'index.html': '<!doctype html><html><body></body></html>',
        },
      );
      expect(report.design.compliant, isFalse);
      expect(
        report.design.violations.any((v) => v.contains('dir="rtl"')),
        isTrue,
      );
      expect(
        report.design.violations.any((v) => v.contains('lang="he"')),
        isTrue,
      );
    });

    test(
        ':root CSS variable defaults with hex/rgba/px do NOT trigger false positives',
        () {
      // רגרסיה: DESIGN_GUIDE עצמו ממליץ על #6750A4, rgba(...) ו-18px כברירות
      // מחדל ב-:root. הוולידטור חייב להחריג הגדרות --variable.
      final report = _runOn(
        tempDir,
        files: {
          'index.html': '<html lang="he" dir="rtl"></html>',
          'styles.css': '''
            :root {
              --color-primary: #6750A4;
              --color-on-primary: #FFFFFF;
              --color-primary-subtle: rgba(103, 80, 164, 0.12);
              --font-size-base: 18px;
              --radius-sm: 8px;
            }
            body { color: var(--color-on-primary); background: var(--color-primary); font-size: var(--font-size-base); }
          ''',
        },
      );
      expect(report.design.violations, isEmpty);
      expect(report.design.compliant, isTrue);
    });

    test('flags hex colors that are NOT inside CSS variable declarations', () {
      final report = _runOn(
        tempDir,
        files: {
          'index.html': '<html lang="he" dir="rtl"></html>',
          'styles.css': '''
            body { color: #ff0000; background: var(--color-primary); }
          ''',
        },
      );
      expect(
        report.design.violations.any((v) => v.contains('hex')),
        isTrue,
      );
    });

    test('flags named colors in property values', () {
      final report = _runOn(
        tempDir,
        files: {
          'index.html': '<html lang="he" dir="rtl"></html>',
          'styles.css': '''
            body { color: red; background: var(--color-primary); }
          ''',
        },
      );
      expect(
        report.design.violations.any((v) => v.contains('שם צבע')),
        isTrue,
      );
    });

    test('flags hardcoded font-size in px outside variable definition', () {
      final report = _runOn(
        tempDir,
        files: {
          'index.html': '<html lang="he" dir="rtl"></html>',
          'styles.css': '''
            body { font-size: 14px; color: var(--color-on-primary); }
          ''',
        },
      );
      expect(
        report.design.violations.any((v) => v.contains('font-size')),
        isTrue,
      );
    });

    test('requires at least one var(--color-*) usage', () {
      final report = _runOn(
        tempDir,
        files: {
          'index.html': '<html lang="he" dir="rtl"></html>',
          'styles.css': 'body { font-family: serif; }',
        },
      );
      expect(
        report.design.violations.any((v) => v.contains('var(--color-')),
        isTrue,
      );
    });

    test('marks plugins without any HTML/CSS as non-compliant by default', () {
      // אין מה להוכיח לגבי תאימות עיצוב אם אין HTML/CSS.
      final report = _runOn(
        tempDir,
        files: const {'app.js': '/* logic only */'},
      );
      expect(report.design.compliant, isFalse);
    });
  });
}
