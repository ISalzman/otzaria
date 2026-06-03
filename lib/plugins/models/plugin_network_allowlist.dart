/// רשימת ה-URLs המאושרים גישה לרשת עבור תוספים.
///
/// **מקור האמת היחיד** עבור כל גישת רשת של תוספים. גם אם תוסף
/// מצהיר ב-manifest על דומיין מסוים — הגישה תיחסם אם ה-URL לא
/// נמצא ברשימה כאן.
///
/// כל ערך הוא **קידומת** (prefix) — מאושרים ה-URL עצמו וכל
/// תתי-הנתיבים תחתיו, ולא שאר הדומיין.
///
/// ## דוגמה
/// אם הרשימה מכילה: `https://github.com/Otzaria/otzaria-library`
///
/// יותרו:
/// - `https://github.com/Otzaria/otzaria-library`
/// - `https://github.com/Otzaria/otzaria-library/`
/// - `https://github.com/Otzaria/otzaria-library/releases/latest`
/// - `https://github.com/Otzaria/otzaria-library?tab=readme`
///
/// ייחסמו:
/// - `https://github.com/` (נתיב הורה)
/// - `https://github.com/Otzaria/another-repo` (נתיב אחר)
/// - `https://github.com/Otzaria/otzaria-library2` (קידומת תואמת חלקית)
///
/// ## כללים
/// - חובה לכלול scheme מלא (`https://` או `http://`).
/// - מותר לציין דומיין שלם כדי להתיר את כולו: `https://api.example.com`
///   יתיר כל URL שמתחיל ב-`https://api.example.com/`.
/// - אין להשאיר `/` סופי — הוא לא משנה את ההתנהגות אך מבלבל.
const List<String> pluginNetworkAllowlist = <String>[
  // הוסיפו כאן URLs מאושרים — דוגמה (להסיר/להשאיר לפי הצורך):
  // אתר אוצריא — חנות תוספים ודפים ציבוריים
  'https://otzaria.org',
  // אתר אוצר החכמה
  'https://tablet.otzar.org',
  // אתר היברבוקס
  'https://hebrewbooks.org',
  // ספריית על התורה
  'https://library.alhatorah.org',
  //על התורה - מקראות גדולות, רמבם, שס, טור
  'https://mg.alhatorah.org',
  'https://rambam.alhatorah.org',
  'https://shas.alhatorah.org',
  'https://turshulchanarukh.alhatorah.org',
  // Google Apps Script — תוסף ספריית אוצריא
  'https://script.google.com/macros/s/AKfycbwU7ktk7_VdSqIxlMBnj4L8dIOKX7C5XIYxxyJsr2gohCtJuLEKA4RPUWO6d88Ry8TAoA/exec',
  // GitHub API — ספריית YairDaniel123/Otzarya-Library
  'https://api.github.com/repos/YairDaniel123/Otzarya-Library',
  // GitHub Releases — הורדת קבצי ZIP של מאגר YairDaniel123/Otzarya-Library
  // (מכסה את כל הנתיבים תחת המאגר, כולל /releases/latest/download/...).
  'https://github.com/YairDaniel123/Otzarya-Library',
];

/// דומייני ה-CDN שאליהם GitHub מפנה (redirect) בהורדת asset של release.
///
/// אינם ברשימת ההיתר הגלובלית בכוונה — אסור לאפשר אליהם גישה *ישירה*
/// (`network.fetch`/`network.download`), אלא רק כיעד של redirect שמקורו
/// ב-URL מורשה של GitHub Releases. ראו [isGithubReleaseRedirectAllowed].
const Set<String> _githubReleaseCdnHosts = <String>{
  'objects.githubusercontent.com',
  'release-assets.githubusercontent.com',
};

/// בודקת האם מותר לעקוב אחרי redirect מ-[previous] אל [target].
///
/// מתירה אך ורק את התרחיש של הורדת asset מ-GitHub Releases: ה-hop הקודם
/// הוא URL מורשה (לפי [isUriAllowedForPluginNetwork]) של `github.com`,
/// והיעד הוא אחד מדומייני ה-CDN של גיטהאב. מאחר שלא ניתן להגיע לדומיין
/// CDN ככתובת התחלתית (הוא אינו ברשימה הגלובלית), שרשרת redirect שכבר
/// הגיעה ל-CDN לגיטימית רשאית להמשיך בין דומייני CDN בלבד.
///
/// כך נסגרת עקיפת ה-allowlist דרך redirects, מבלי לפתוח את ה-CDN לגישה
/// ישירה מצד תוספים.
bool isGithubReleaseRedirectAllowed(Uri previous, Uri target) {
  if (target.scheme != 'https') return false;
  if (!_githubReleaseCdnHosts.contains(target.host.toLowerCase())) return false;

  final previousHost = previous.host.toLowerCase();
  if (previousHost == 'github.com') {
    return isUriAllowedForPluginNetwork(previous);
  }
  return _githubReleaseCdnHosts.contains(previousHost);
}

/// בודקת האם [uri] מורשה לגישה על-ידי תוספים.
///
/// מחזירה `true` רק אם ה-URL הוא בדיוק אחת מהקידומות ברשימה
/// [pluginNetworkAllowlist], או נתיב תחתיה (מופרד ב-`/`, `?` או `#`).
///
/// השוואת קידומת מתבצעת case-insensitive על ה-scheme וה-host
/// (תקני URI), ו-case-sensitive על הנתיב.
bool isUriAllowedForPluginNetwork(Uri uri) {
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return false;
  }

  // מנרמלים scheme + host ל-lowercase כפי שדורש תקן ה-URI,
  // ושומרים על נתיב/query/fragment כמו שהם (case-sensitive).
  final normalizedHost = uri.host.toLowerCase();
  final normalizedUrl = StringBuffer()
    ..write(uri.scheme.toLowerCase())
    ..write('://')
    ..write(normalizedHost);
  if (uri.hasPort) {
    normalizedUrl
      ..write(':')
      ..write(uri.port);
  }
  normalizedUrl.write(uri.path);
  if (uri.hasQuery) {
    normalizedUrl
      ..write('?')
      ..write(uri.query);
  }
  if (uri.hasFragment) {
    normalizedUrl
      ..write('#')
      ..write(uri.fragment);
  }
  final fullUrl = normalizedUrl.toString();

  for (final rawPrefix in pluginNetworkAllowlist) {
    // מנרמלים את הקידומת באותו אופן.
    final prefixUri = Uri.tryParse(rawPrefix);
    if (prefixUri == null) continue;
    if (prefixUri.scheme != 'http' && prefixUri.scheme != 'https') continue;

    final normalizedPrefix = StringBuffer()
      ..write(prefixUri.scheme.toLowerCase())
      ..write('://')
      ..write(prefixUri.host.toLowerCase());
    if (prefixUri.hasPort) {
      normalizedPrefix
        ..write(':')
        ..write(prefixUri.port);
    }
    normalizedPrefix.write(prefixUri.path);
    final prefix = normalizedPrefix.toString();

    if (fullUrl == prefix) return true;
    if (fullUrl.startsWith('$prefix/')) return true;
    if (fullUrl.startsWith('$prefix?')) return true;
    if (fullUrl.startsWith('$prefix#')) return true;
  }

  return false;
}
