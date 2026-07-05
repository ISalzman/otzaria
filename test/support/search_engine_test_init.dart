import 'dart:convert';
import 'dart:io';

import 'package:otzaria_search_engine/otzaria_search_engine.dart';

/// מאתר את שורש חבילת המנוע דרך package_config.json (תחת `flutter test`
/// ‏Isolate.resolvePackageUri מחזיר null, ולכן קוראים את הקובץ ישירות;
/// ה-CWD של flutter test הוא שורש הפרויקט).
String? _searchEnginePackageRoot() {
  final configFile = File('.dart_tool/package_config.json');
  if (!configFile.existsSync()) return null;
  final config = jsonDecode(configFile.readAsStringSync());
  final packages = config['packages'] as List<dynamic>;
  for (final package in packages) {
    if (package['name'] == 'otzaria_search_engine') {
      final rootUri = Uri.parse(package['rootUri'] as String);
      final resolved = rootUri.hasScheme
          ? rootUri
          : configFile.absolute.parent.uri.resolveUri(rootUri);
      return resolved.toFilePath();
    }
  }
  return null;
}

/// מאתר את הנתיב לספריית מנוע החיפוש הנייטיבית שנבנתה מקומית (`cargo build`),
/// או `null` אם אין build זמין (למשל ב-CI ללא Rust).
String? searchEngineLibraryPath() {
  final packageRoot = _searchEnginePackageRoot();
  if (packageRoot == null) return null;
  const names = [
    'search_engine.dll',
    'libsearch_engine.so',
    'libsearch_engine.dylib',
  ];
  for (final profile in ['release', 'debug']) {
    for (final name in names) {
      final path = '$packageRoot/rust/target/$profile/$name'
          .replaceAll('\\', '/')
          .replaceAll('//', '/');
      if (File(path).existsSync()) {
        return path;
      }
    }
  }
  return null;
}

bool? _initResult;

/// טוען את ספריית מנוע החיפוש הנייטיבית ומאתחל את [RustLib]. פונקציות כמו
/// `sanitizeQuery`/`splitQueryWords`/`normalizeTextForIndexing` מאצילות למנוע,
/// כך שהטסטים שלהן דורשים את הספרייה; כשאין build זמין מוחזר `false` והקבוצה
/// תדולג. אידמפוטנטי — האתחול קורה פעם אחת ל-isolate ותוצאתו נשמרת, כך
/// שאפשר לקרוא גם מ-`flutter_test_config.dart` וגם מ-`main` של כל טסט.
Future<bool> tryInitSearchEngine() async {
  if (_initResult != null) return _initResult!;
  try {
    final path = searchEngineLibraryPath();
    if (path == null) return _initResult = false;
    await RustLib.init(externalLibrary: ExternalLibrary.open(path));
    return _initResult = true;
  } catch (_) {
    return _initResult = false;
  }
}

/// הודעת דילוג אחידה לקבוצות טסט שתלויות במנוע הנייטיבי.
const String searchEngineSkipReason =
    'ספריית מנוע החיפוש הנייטיבית לא נמצאה — הריצו cargo build בחבילה';
